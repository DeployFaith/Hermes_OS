extends "res://scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

const TerminalBuffer = preload("res://scripts/apps/terminal/terminal_buffer.gd")
const TerminalShellBackend = preload("res://scripts/apps/terminal/terminal_shell_backend.gd")

var _shell: Node = null
var _fs: Object = null
var _terminal_app: Object = null

var _state_data: Dictionary = {}
var _session_id: String = ""

var _surface: Control = null
var _buffer: TerminalBuffer = null
var _backend: TerminalShellBackend = null
var _output: TextEdit = null
var _input: LineEdit = null
var _history_cursor: int = -1

func configure_app_context(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	if _fs == null and _shell != null:
		_fs = _shell.get("_fs") as Object
	var terminal_value: Variant = context.get("terminal_app", null)
	if terminal_value is Object:
		_terminal_app = terminal_value as Object
	_state_data = context.get("state", {}) if context.get("state", {}) is Dictionary else {}
	if _state_data.is_empty():
		_state_data = {"cwd": _home_path(), "history": []}
	if not _state_data.has("cwd"):
		_state_data["cwd"] = _home_path()
	if not _state_data.has("history"):
		_state_data["history"] = []
	_session_id = str(context.get("session_id", _state_data.get("session_id", "")))
	if _session_id == "":
		_session_id = "terminal_%d" % int(Time.get_ticks_usec())
	_state_data["session_id"] = _session_id
	if _surface != null and _surface.has_method("set_shell"):
		_surface.call("set_shell", _shell)
	if _backend != null:
		_backend.terminal_shell_init({
			"shell": _shell,
			"filesystem": _fs,
			"state": _state_data,
			"session_id": _session_id
		})
		_history_cursor = -1
		_update_prompt()
		_render()
		_sync_terminal_app()

func _app_ready() -> void:
	_hydrate_context_from_os_bridge()
	if state != null:
		state.set_many({
			"prompt": "",
			"draft": "",
			"status": "Type 'help' for commands. Current user: " + _current_user(),
			"session_id": _session_id,
			"session_label": "session: " + _session_id,
			"transcript_preview": "",
			"transcript": ""
		})
	_buffer = TerminalBuffer.new()
	_buffer.terminal_buffer_init({"max_lines": 800, "intro": "Type 'help' for commands. Current user: " + _current_user()})
	_backend = TerminalShellBackend.new()
	_backend.terminal_shell_init({
		"shell": _shell,
		"filesystem": _fs,
		"state": _state_data,
		"session_id": _session_id
	})
	_setup_surface()
	_history_cursor = -1
	_update_prompt()
	_render()
	_sync_terminal_app()

func focus_terminal_input() -> void:
	if _surface != null and _surface.has_method("focus_input"):
		_surface.call("focus_input")

func export_terminal_state() -> Dictionary:
	if _backend != null:
		_state_data = _backend.export_state()
	if not _state_data.has("session_id"):
		_state_data["session_id"] = _session_id
	return _state_data.duplicate(true)

func restore_terminal_state(restored_state: Dictionary) -> void:
	_state_data = restored_state.duplicate(true)
	if _state_data.is_empty():
		_state_data = {"cwd": _home_path(), "history": []}
	if not _state_data.has("cwd"):
		_state_data["cwd"] = _home_path()
	if not _state_data.has("history"):
		_state_data["history"] = []
	_state_data["session_id"] = _session_id
	if _backend != null:
		_backend.terminal_shell_init({
			"shell": _shell,
			"filesystem": _fs,
			"state": _state_data,
			"session_id": _session_id
		})
	_history_cursor = -1
	_update_prompt()
	_render()
	_sync_terminal_app()

func append_external_output(text: String, source: String = "Hermes") -> void:
	if _buffer == null:
		return
	var clean_source: String = source.strip_edges()
	if clean_source == "":
		clean_source = "Hermes"
	_buffer.append_prompt_command("[" + clean_source + "]", "")
	_buffer.append_output(text if text.strip_edges() != "" else "(no output)")
	_render()
	if state != null:
		state.set("status", "External output from " + clean_source)

func handle_input(event) -> void:
	if state == null:
		return
	state.set("draft", str(event.value))
	_sync_terminal_surface_props()

func submit_command(event) -> void:
	_on_command_submitted(str(event.value))

func interrupt_command(_event = null) -> void:
	_on_interrupt_requested()

func clear_terminal(_event = null) -> void:
	_on_clear_requested()

func paste_input(_event = null) -> void:
	_on_paste_requested()

func copy_output(_event = null) -> void:
	_on_copy_requested()

func history_previous(_event = null) -> void:
	_on_history_previous_requested()

func history_next(_event = null) -> void:
	_on_history_next_requested()

func _setup_surface() -> void:
	if ui == null:
		return
	_surface = ui.by_id("terminal-surface")
	if _surface == null:
		return
	if _surface.has_method("set_shell"):
		_surface.call("set_shell", _shell)
	if _surface.has_signal("command_submitted"):
		var submit_cb := Callable(self, "_on_command_submitted")
		if not _surface.is_connected("command_submitted", submit_cb):
			_surface.connect("command_submitted", submit_cb)
	if _surface.has_signal("history_previous_requested"):
		var prev_cb := Callable(self, "_on_history_previous_requested")
		if not _surface.is_connected("history_previous_requested", prev_cb):
			_surface.connect("history_previous_requested", prev_cb)
	if _surface.has_signal("history_next_requested"):
		var next_cb := Callable(self, "_on_history_next_requested")
		if not _surface.is_connected("history_next_requested", next_cb):
			_surface.connect("history_next_requested", next_cb)
	if _surface.has_signal("interrupt_requested"):
		var interrupt_cb := Callable(self, "_on_interrupt_requested")
		if not _surface.is_connected("interrupt_requested", interrupt_cb):
			_surface.connect("interrupt_requested", interrupt_cb)
	if _surface.has_signal("clear_requested"):
		var clear_cb := Callable(self, "_on_clear_requested")
		if not _surface.is_connected("clear_requested", clear_cb):
			_surface.connect("clear_requested", clear_cb)
	if _surface.has_signal("paste_requested"):
		var paste_cb := Callable(self, "_on_paste_requested")
		if not _surface.is_connected("paste_requested", paste_cb):
			_surface.connect("paste_requested", paste_cb)
	if _surface.has_signal("copy_requested"):
		var copy_cb := Callable(self, "_on_copy_requested")
		if not _surface.is_connected("copy_requested", copy_cb):
			_surface.connect("copy_requested", copy_cb)
	if _surface.has_method("get_output"):
		var output_value: Variant = _surface.call("get_output")
		if output_value is TextEdit:
			_output = output_value as TextEdit
	if _surface.has_method("get_input"):
		var input_value: Variant = _surface.call("get_input")
		if input_value is LineEdit:
			_input = input_value as LineEdit
	if _input != null:
		var input_change_cb := Callable(self, "_on_input_text_changed")
		if not _input.text_changed.is_connected(input_change_cb):
			_input.text_changed.connect(input_change_cb)

func _on_command_submitted(command: String) -> void:
	if _buffer == null or _backend == null:
		return
	var clean: String = command.strip_edges()
	if clean == "":
		if _surface != null and _surface.has_method("clear_input"):
			_surface.call("clear_input")
		if state != null:
			state.set("draft", "")
			state.set("status", "")
		return
	_buffer.append_prompt_command(_backend.get_prompt(), command)
	var result: Dictionary = _backend.run_command(command)
	if bool(result.get("clear_screen", false)):
		_buffer.clear()
	else:
		var stdout_lines: Array = result.get("stdout_lines", []) if result.get("stdout_lines", []) is Array else []
		var stderr_lines: Array = result.get("stderr_lines", []) if result.get("stderr_lines", []) is Array else []
		_buffer.append_lines(stdout_lines)
		_buffer.append_lines(stderr_lines)
	_state_data = _backend.export_state()
	_history_cursor = -1
	if _surface != null and _surface.has_method("clear_input"):
		_surface.call("clear_input")
	if state != null:
		state.set_many({
			"draft": "",
			"status": "",
			"session_label": "session: " + _session_id
		})
	_update_prompt()
	_render()
	_sync_terminal_app()

func _on_history_previous_requested() -> void:
	if _backend == null:
		return
	var history: Array[String] = _backend.get_history()
	if history.is_empty():
		return
	if _history_cursor < 0:
		_history_cursor = history.size() - 1
	else:
		_history_cursor = maxi(_history_cursor - 1, 0)
	if _surface != null and _surface.has_method("set_input_text"):
		_surface.call("set_input_text", history[_history_cursor])
	if state != null:
		state.set("draft", history[_history_cursor])
	_sync_terminal_app()

func _on_history_next_requested() -> void:
	if _backend == null:
		return
	var history: Array[String] = _backend.get_history()
	if history.is_empty() or _history_cursor < 0:
		if _surface != null and _surface.has_method("set_input_text"):
			_surface.call("set_input_text", "")
		_history_cursor = -1
		if state != null:
			state.set("draft", "")
		_sync_terminal_app()
		return
	_history_cursor += 1
	if _history_cursor >= history.size():
		_history_cursor = -1
		if _surface != null and _surface.has_method("set_input_text"):
			_surface.call("set_input_text", "")
		if state != null:
			state.set("draft", "")
		_sync_terminal_app()
		return
	if _surface != null and _surface.has_method("set_input_text"):
		_surface.call("set_input_text", history[_history_cursor])
	if state != null:
		state.set("draft", history[_history_cursor])
	_sync_terminal_app()

func _on_interrupt_requested() -> void:
	if _buffer == null or _backend == null:
		return
	var current: String = _surface.call("get_input_text") if _surface != null and _surface.has_method("get_input_text") else ""
	_buffer.append_prompt_command(_backend.get_prompt(), current)
	_buffer.append_line("^C")
	if _surface != null and _surface.has_method("clear_input"):
		_surface.call("clear_input")
	_history_cursor = -1
	if state != null:
		state.set_many({"draft": "", "status": "Interrupted"})
	_render()
	_update_prompt()
	_sync_terminal_app()

func _on_clear_requested() -> void:
	if _buffer == null:
		return
	_buffer.clear()
	if _surface != null and _surface.has_method("clear_input"):
		_surface.call("clear_input")
	if state != null:
		state.set_many({"draft": "", "status": "Cleared"})
	_render()
	_update_prompt()
	_sync_terminal_app()

func _on_paste_requested() -> void:
	var pasted: String = DisplayServer.clipboard_get()
	if pasted == "":
		return
	var input_text: String = _surface.call("get_input_text") if _surface != null and _surface.has_method("get_input_text") else ""
	if _surface != null and _surface.has_method("set_input_text"):
		_surface.call("set_input_text", input_text + pasted)
	if state != null:
		state.set("draft", input_text + pasted)
	_sync_terminal_app()

func _on_copy_requested() -> void:
	if _output == null:
		return
	var selected: String = _output.get_selected_text()
	if selected != "":
		DisplayServer.clipboard_set(selected)

func _on_input_text_changed(value: String) -> void:
	if state != null:
		state.set("draft", value)
	_sync_terminal_surface_props()

func _render() -> void:
	if _surface != null and _surface.has_method("render_text") and _buffer != null:
		_surface.call("render_text", _buffer.get_text())
	if state != null and _buffer != null:
		state.set("transcript", _buffer.get_text())
		state.set("transcript_preview", _transcript_preview(_buffer.get_lines()))
	_sync_terminal_surface_props()

func _update_prompt() -> void:
	if _surface != null and _surface.has_method("set_prompt") and _backend != null:
		var prompt: String = _backend.get_prompt()
		_surface.call("set_prompt", prompt)
		if state != null:
			state.set("prompt", prompt)
	_sync_terminal_surface_props()

func _sync_terminal_surface_props() -> void:
	if ui == null or state == null:
		return
	ui.set_prop("terminal-surface", "prompt", state.get_string("prompt", ""))
	ui.set_prop("terminal-surface", "input", state.get_string("draft", ""))
	ui.set_prop("terminal-surface", "transcript", state.get_string("transcript_preview", ""))
	ui.set_prop("terminal-surface", "session-id", _session_id)
	ui.set_prop("terminal-surface", "value", {
		"prompt": state.get_string("prompt", ""),
		"input": state.get_string("draft", ""),
		"session_id": _session_id,
		"transcript": state.get_string("transcript_preview", "")
	})

func _sync_terminal_app() -> void:
	if _terminal_app == null or not _terminal_app.has_method("_sync_terminal_runtime"):
		return
	_terminal_app.call("_sync_terminal_runtime", _surface, _buffer, _backend, _output, _input, _history_cursor, export_terminal_state())

func _transcript_preview(lines: Array[String]) -> String:
	if lines.is_empty():
		return ""
	var start: int = maxi(lines.size() - 3, 0)
	return "\n".join(lines.slice(start, lines.size()))

func _home_path() -> String:
	if _fs != null and _fs.has_method("home_path"):
		return str(_fs.call("home_path"))
	if os != null and os.files != null and os.files.has_method("home_path"):
		return str(os.files.home_path())
	return "/root"

func _current_user() -> String:
	if _fs != null and _fs.has_method("current_user"):
		return str(_fs.call("current_user"))
	return "user"

func _hydrate_context_from_os_bridge() -> void:
	if os == null:
		return
	var bridge_context: Dictionary = os.context if os.context is Dictionary else {}
	if _shell == null:
		var shell_value: Variant = bridge_context.get("shell", null)
		if shell_value is Node:
			_shell = shell_value as Node
	if _fs == null:
		var fs_value: Variant = bridge_context.get("filesystem", null)
		if fs_value is Object:
			_fs = fs_value as Object
