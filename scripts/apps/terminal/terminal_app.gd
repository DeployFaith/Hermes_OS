class_name TerminalApp
extends VBoxContainer

const TerminalView = preload("res://scripts/apps/terminal/terminal_view.gd")
const TerminalBuffer = preload("res://scripts/apps/terminal/terminal_buffer.gd")
const TerminalShellBackend = preload("res://scripts/apps/terminal/terminal_shell_backend.gd")

var _shell: Node
var _fs: Object
var _state: Dictionary = {}
var _session_id: String = ""
var _view: TerminalView
var _buffer: TerminalBuffer
var _backend: TerminalShellBackend
var _output: TextEdit
var _input: LineEdit
var _history_cursor: int = -1

func os_app_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	if _fs == null and _shell != null:
		_fs = _shell.get("_fs") as Object
	_state = context.get("state", {}) if context.get("state", {}) is Dictionary else {}
	if _state.is_empty():
		_state = {"cwd": _home_path(), "history": []}
	if not _state.has("cwd"):
		_state["cwd"] = _home_path()
	if not _state.has("history"):
		_state["history"] = []
	_session_id = str(context.get("session_id", _state.get("session_id", "")))
	if _session_id == "":
		_session_id = "terminal_%d" % int(Time.get_ticks_usec())
	_state["session_id"] = _session_id
	_build()
	_register_terminal_session()

func os_app_focus() -> void:
	if _view != null:
		_view.focus_input()

func os_app_get_state() -> Dictionary:
	if _backend != null:
		return _backend.export_state()
	return _state.duplicate(true)

func append_external_output(text: String, source: String = "Hermes") -> void:
	if _buffer == null:
		return
	var clean_source := source.strip_edges()
	if clean_source == "":
		clean_source = "Hermes"
	_buffer.append_prompt_command("[" + clean_source + "]", "")
	_buffer.append_output(text if text.strip_edges() != "" else "(no output)")
	_render()

func get_terminal_session_id() -> String:
	return _session_id

func _exit_tree() -> void:
	_unregister_terminal_session()

func _build() -> void:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)

	_buffer = TerminalBuffer.new()
	_buffer.terminal_buffer_init({"max_lines": 800, "intro": "Type 'help' for commands. Current user: " + _current_user()})

	_backend = TerminalShellBackend.new()
	_backend.terminal_shell_init({
		"shell": _shell,
		"filesystem": _fs,
		"state": _state,
		"session_id": _session_id
	})

	_view = TerminalView.new()
	_view.name = "TerminalView"
	_view.terminal_view_init({"shell": _shell})
	_view.command_submitted.connect(_on_command_submitted)
	_view.history_previous_requested.connect(_on_history_previous_requested)
	_view.history_next_requested.connect(_on_history_next_requested)
	_view.interrupt_requested.connect(_on_interrupt_requested)
	_view.clear_requested.connect(_on_clear_requested)
	_view.paste_requested.connect(_on_paste_requested)
	_view.copy_requested.connect(_on_copy_requested)
	add_child(_view)

	_output = _view.get_output()
	_input = _view.get_input()
	_update_prompt()
	_render()

func _on_command_submitted(command: String) -> void:
	var clean := command.strip_edges()
	if clean == "":
		_view.clear_input()
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
	_state = _backend.export_state()
	_history_cursor = -1
	_view.clear_input()
	_update_prompt()
	_render()

func _on_history_previous_requested() -> void:
	var history := _backend.get_history()
	if history.is_empty():
		return
	if _history_cursor < 0:
		_history_cursor = history.size() - 1
	else:
		_history_cursor = maxi(_history_cursor - 1, 0)
	_view.set_input_text(history[_history_cursor])

func _on_history_next_requested() -> void:
	var history := _backend.get_history()
	if history.is_empty() or _history_cursor < 0:
		_view.set_input_text("")
		_history_cursor = -1
		return
	_history_cursor += 1
	if _history_cursor >= history.size():
		_history_cursor = -1
		_view.set_input_text("")
		return
	_view.set_input_text(history[_history_cursor])

func _on_interrupt_requested() -> void:
	var current := _view.get_input_text()
	_buffer.append_prompt_command(_backend.get_prompt(), current)
	_buffer.append_line("^C")
	_view.clear_input()
	_history_cursor = -1
	_render()
	_update_prompt()

func _on_clear_requested() -> void:
	_buffer.clear()
	_view.clear_input()
	_render()
	_update_prompt()

func _on_paste_requested() -> void:
	var pasted := DisplayServer.clipboard_get()
	if pasted == "":
		return
	var input_text := _view.get_input_text()
	_view.set_input_text(input_text + pasted)

func _on_copy_requested() -> void:
	if _output == null:
		return
	var selected := _output.get_selected_text()
	if selected != "":
		DisplayServer.clipboard_set(selected)

func _render() -> void:
	if _view != null and _buffer != null:
		_view.render_text(_buffer.get_text())

func _update_prompt() -> void:
	if _view != null and _backend != null:
		_view.set_prompt(_backend.get_prompt())

func _register_terminal_session() -> void:
	if _shell != null and _shell.has_method("_register_terminal_instance"):
		_shell.call("_register_terminal_instance", _session_id, self)

func _unregister_terminal_session() -> void:
	if _shell != null and _shell.has_method("_unregister_terminal_instance"):
		_shell.call("_unregister_terminal_instance", _session_id, self)

func _home_path() -> String:
	if _fs != null and _fs.has_method("home_path"):
		return str(_fs.call("home_path"))
	return "/root"

func _current_user() -> String:
	if _fs != null and _fs.has_method("current_user"):
		return str(_fs.call("current_user"))
	return "user"
