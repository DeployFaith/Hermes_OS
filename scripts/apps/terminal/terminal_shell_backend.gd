class_name TerminalShellBackend
extends RefCounted

const TerminalCommandRegistry = preload("res://scripts/apps/terminal/terminal_command_registry.gd")

var _shell: Node
var _fs: Object
var _registry: TerminalCommandRegistry
var _state: Dictionary = {}
var _session_id: String = ""
var _history: Array[String] = []

func terminal_shell_init(context: Dictionary = {}) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	if _fs == null and _shell != null:
		_fs = _shell.get("_fs") as Object
	_state = context.get("state", {}) if context.get("state", {}) is Dictionary else {}
	_session_id = str(context.get("session_id", _session_id))
	if not _state.has("cwd"):
		_state["cwd"] = home_path()
	else:
		_state["cwd"] = resolve_path(str(_state.get("cwd", home_path())))
	if not _state.has("history"):
		_state["history"] = []
	var history_value: Variant = _state.get("history", [])
	if history_value is Array:
		for item in history_value:
			_history.append(str(item))
	_registry = TerminalCommandRegistry.new()
	_registry.command_registry_init({})

func run_command(command_line: String) -> Dictionary:
	var clean := command_line.strip_edges()
	if clean == "":
		return make_result()
	_add_history(clean)
	var parsed := parse_command_line(clean)
	if not bool(parsed.get("ok", false)):
		return make_result([], [str(parsed.get("error", "Could not parse command"))], 1)
	var result: Dictionary = _registry.execute(parsed, self)
	result["cwd"] = get_cwd()
	result["session_id"] = _session_id
	return result

func parse_command_line(command_line: String) -> Dictionary:
	var tokens_result := _tokenize(command_line)
	if not bool(tokens_result.get("ok", false)):
		return tokens_result
	var tokens: Array = tokens_result.get("tokens", []) if tokens_result.get("tokens", []) is Array else []
	if tokens.is_empty():
		return {"ok": true, "command": "", "args": [], "tail": "", "redirect_path": "", "raw": command_line}
	var command := str(tokens[0]).to_lower()
	var args: Array[String] = []
	var redirect_path := ""
	var index := 1
	while index < tokens.size():
		var token := str(tokens[index])
		if token == ">":
			if index + 1 >= tokens.size():
				return {"ok": false, "error": "Missing redirect path", "raw": command_line}
			redirect_path = str(tokens[index + 1])
			break
		args.append(token)
		index += 1
	var tail := command_line.substr(command.length()).strip_edges()
	return {"ok": true, "command": command, "args": args, "tail": tail, "redirect_path": redirect_path, "raw": command_line}

func make_result(stdout_lines: Array = [], stderr_lines: Array = [], exit_code: int = 0, clear_screen: bool = false) -> Dictionary:
	var out: Array[String] = []
	var err: Array[String] = []
	for line in stdout_lines:
		out.append(str(line))
	for line in stderr_lines:
		err.append(str(line))
	return {
		"ok": exit_code == 0,
		"stdout_lines": out,
		"stderr_lines": err,
		"stdout": "\n".join(out),
		"stderr": "\n".join(err),
		"exit_code": exit_code,
		"clear_screen": clear_screen,
		"cwd": get_cwd(),
		"session_id": _session_id
	}

func get_help_text() -> String:
	return _registry.get_help_text() if _registry != null else ""

func export_state() -> Dictionary:
	_state["cwd"] = get_cwd()
	_state["history"] = _history.duplicate()
	_state["session_id"] = _session_id
	return _state.duplicate(true)

func get_history() -> Array[String]:
	var result: Array[String] = []
	for item in _history:
		result.append(item)
	return result

func get_session_id() -> String:
	return _session_id

func get_prompt() -> String:
	var symbol := "#" if current_user() == "root" else "$"
	return current_user() + ":" + get_cwd() + symbol

func get_cwd() -> String:
	return str(_state.get("cwd", home_path()))

func set_cwd(path: String) -> void:
	_state["cwd"] = resolve_path(path)

func home_path() -> String:
	if _fs != null and _fs.has_method("home_path"):
		return str(_fs.call("home_path"))
	return "/root"

func current_user() -> String:
	if _fs != null and _fs.has_method("current_user"):
		return str(_fs.call("current_user"))
	return "user"

func resolve_path(path: String) -> String:
	if _fs != null and _fs.has_method("resolve_path"):
		return str(_fs.call("resolve_path", path, get_cwd()))
	return path

func is_dir(path: String) -> bool:
	return bool(_fs.call("is_dir", path)) if _fs != null and _fs.has_method("is_dir") else false

func is_file(path: String) -> bool:
	return bool(_fs.call("is_file", path)) if _fs != null and _fs.has_method("is_file") else false

func exists(path: String) -> bool:
	return bool(_fs.call("exists", path)) if _fs != null and _fs.has_method("exists") else is_dir(path) or is_file(path)

func can_list_dir(path: String) -> bool:
	return bool(_fs.call("can_list_dir", path)) if _fs != null and _fs.has_method("can_list_dir") else is_dir(path)

func list_dir(path: String) -> Array:
	if _fs == null or not _fs.has_method("list_dir"):
		return []
	var value: Variant = _fs.call("list_dir", path)
	return value if value is Array else []

func read_file(path: String) -> Dictionary:
	if _fs == null or not _fs.has_method("read_file_result"):
		return {"ok": false, "error": "Filesystem unavailable", "content": ""}
	var result: Variant = _fs.call("read_file_result", path)
	return result if result is Dictionary else {"ok": false, "error": "Could not read file", "content": ""}

func write_file(path: String, content: String) -> Dictionary:
	if _fs == null or not _fs.has_method("write_file"):
		return {"ok": false, "error": "Filesystem unavailable", "path": path}
	var had_file := exists(path)
	var message := str(_fs.call("write_file", path, content))
	if message != "":
		return {"ok": false, "error": message, "path": path}
	_emit_file_event("file.updated" if had_file else "file.created", {"path": path, "type": "file"})
	return {"ok": true, "path": path, "created": not had_file}

func make_dir(path: String) -> Dictionary:
	if _fs == null or not _fs.has_method("make_dir"):
		return {"ok": false, "error": "Filesystem unavailable", "path": path}
	var message := str(_fs.call("make_dir", path))
	if message != "":
		return {"ok": false, "error": message, "path": path}
	_emit_file_event("file.created", {"path": path, "type": "dir"})
	return {"ok": true, "path": path, "created": true}

func delete_path(path: String) -> Dictionary:
	if _fs == null or not _fs.has_method("delete_path"):
		return {"ok": false, "error": "Filesystem unavailable", "path": path}
	var message := str(_fs.call("delete_path", path))
	if message != "":
		return {"ok": false, "error": message, "path": path}
	_emit_file_event("file.deleted", {"path": path})
	return {"ok": true, "path": path, "deleted": true}

func open_target(target: String) -> Dictionary:
	var resolved := resolve_path(target)
	if is_file(resolved):
		if _shell != null and _shell.has_method("_open_text_file"):
			_shell.call("_open_text_file", resolved, "text")
			return {"ok": true, "message": "Opened " + resolved, "path": resolved}
		return {"ok": false, "error": "Text app unavailable"}
	if _shell != null and _shell.has_method("launch_app"):
		var apps_value: Variant = _shell.get("_apps")
		var apps: Dictionary = apps_value if apps_value is Dictionary else {}
		if apps.has(target):
			var window: Variant = _shell.call("launch_app", target)
			if window != null:
				return {"ok": true, "message": "Opened " + target, "app_id": target}
	return {"ok": false, "error": "Unknown app or file: " + target}

func send_hermes(prompt: String) -> Dictionary:
	if _shell == null:
		return {"ok": false, "terminal_result": "Hermes shell unavailable"}
	var service: Variant = _shell.get("_hermes_agent_service")
	if service == null:
		return {"ok": false, "terminal_result": "Hermes agent service is unavailable."}
	if not (service is Object) or not (service as Object).has_method("send_terminal_message"):
		return {"ok": false, "terminal_result": "Hermes agent service is unavailable."}
	return (service as Object).call("send_terminal_message", prompt, {
		"cwd": get_cwd(),
		"user": current_user(),
		"timestamp": int(Time.get_unix_time_from_system()),
		"terminal_session_id": _session_id,
		"source": "terminal"
	})

func _add_history(command_line: String) -> void:
	_history.append(command_line)
	_state["history"] = _history.duplicate()

func _emit_file_event(event_name: String, payload: Dictionary) -> void:
	if _shell != null and _shell.has_method("_emit_hermes_event"):
		_shell.call("_emit_hermes_event", event_name, payload)

func _tokenize(command_line: String) -> Dictionary:
	var tokens: Array[String] = []
	var current := ""
	var quote := ""
	var index := 0
	while index < command_line.length():
		var ch := command_line[index]
		if quote != "":
			if ch == quote:
				quote = ""
			elif ch == "\\" and quote == "\"" and index + 1 < command_line.length():
				index += 1
				current += command_line[index]
			else:
				current += ch
		elif ch == "\"" or ch == "'":
			quote = ch
		elif ch == ">":
			if current != "":
				tokens.append(current)
				current = ""
			tokens.append(">")
		elif ch == " " or ch == "\t":
			if current != "":
				tokens.append(current)
				current = ""
		else:
			current += ch
		index += 1
	if quote != "":
		return {"ok": false, "error": "Unclosed quote", "tokens": []}
	if current != "":
		tokens.append(current)
	return {"ok": true, "tokens": tokens}
