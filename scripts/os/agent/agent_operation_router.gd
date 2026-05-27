class_name AgentOperationRouter
extends RefCounted

const OSEventBus = preload("res://scripts/os/core/os_event_bus.gd")
const HermesProtocol = preload("res://scripts/hermes/hermes_protocol.gd")
const AgentCapabilityRegistry = preload("res://scripts/os/agent/agent_capability_registry.gd")

var _shell: Node
var _event_bus: OSEventBus
var _filesystem: RefCounted
var _window_manager: RefCounted
var _app_registry: RefCounted
var _notification_center: RefCounted
var _capability_registry: AgentCapabilityRegistry
var _initialized: bool = false

func agent_router_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_event_bus = context.get("event_bus", null) as OSEventBus
	_filesystem = context.get("filesystem", null) as RefCounted
	_window_manager = context.get("window_manager", null) as RefCounted
	_app_registry = context.get("app_registry", null) as RefCounted
	_notification_center = context.get("notification_center", null) as RefCounted
	_capability_registry = AgentCapabilityRegistry.new()
	_capability_registry.capability_registry_init()
	_initialized = true

func is_initialized() -> bool:
	return _initialized

func execute_operation(op: String, args: Dictionary = {}) -> Dictionary:
	var normalized: Dictionary = _normalize_operation(op, args)
	var operation: String = str(normalized.get("op", "")).strip_edges()
	var operation_args: Dictionary = normalized.get("args", {}) if normalized.get("args", {}) is Dictionary else {}
	if operation == "":
		var missing: Dictionary = _make_error("", "MISSING_OPERATION", "Operation name is required")
		_emit_operation_event(OSEventBus.AGENT_OPERATION_FAILED, missing)
		return missing

	_emit_operation_event(OSEventBus.AGENT_OPERATION_REQUESTED, {
		"operation": operation,
		"args": operation_args.duplicate(true)
	})
	var routed: Dictionary = _route_operation(operation, operation_args)
	var shaped: Dictionary = _shape_result(operation, routed)
	if bool(shaped.get("ok", false)):
		_emit_operation_event(OSEventBus.AGENT_OPERATION_COMPLETED, shaped)
	else:
		_emit_operation_event(OSEventBus.AGENT_OPERATION_FAILED, shaped)
	return shaped

func get_supported_operations() -> Array[String]:
	if _capability_registry != null:
		return _capability_registry.get_supported_operations()
	return [
		"files.list_dir",
		"files.read_file",
		"files.write_file",
		"windows.list",
		"windows.open_app",
		"windows.focus",
		"notifications.create",
		"system.get_state"
	]

func get_operation_metadata(operation: String) -> Dictionary:
	var normalized: Dictionary = _normalize_operation(operation, {})
	var clean_operation: String = str(normalized.get("op", operation)).strip_edges()
	if _capability_registry != null:
		return _capability_registry.get_metadata(clean_operation)
	return {
		"operation": clean_operation,
		"capability": "legacy.compat",
		"risk": "medium",
		"mutates_state": false,
		"description": "Legacy or unknown operation routed through compatibility dispatch",
		"requires_approval": false
	}

func describe_operation(operation: String) -> Dictionary:
	return get_operation_metadata(operation)

func _route_operation(operation: String, args: Dictionary) -> Dictionary:
	if operation == "hermes.propose_operation":
		return _route_proposed_operation(args)
	match operation:
		"files.list_dir", "files.list_directory":
			return _route_files_list_dir(operation, args)
		"files.read_file":
			return _route_files_read_file(operation, args)
		"files.write_file":
			return _route_files_write_file(operation, args)
		"files.mkdir", "files.create_folder":
			return _route_files_mkdir(operation, args)
		"files.delete":
			return _route_files_delete(operation, args)
		"files.move":
			return _route_files_move(operation, args)
		"files.copy":
			return _route_files_copy(operation, args)
		"windows.list":
			return _route_windows_list(operation, args)
		"windows.open_app":
			return _route_windows_open_app(operation, args)
		"windows.focus", "windows.focus_window":
			return _route_windows_focus(operation, args)
		"notifications.create", "desktop.show_notification":
			return _route_notifications_create(operation, args)
		"system.get_state":
			return _route_system_get_state(operation, args)
		_:
			return _route_legacy_shell(operation, args)

func _route_proposed_operation(args: Dictionary) -> Dictionary:
	var proposed_op: String = str(args.get("op", "")).strip_edges()
	var proposed_args: Dictionary = {}
	var proposed_args_value: Variant = args.get("args", {})
	if proposed_args_value is Dictionary:
		proposed_args = (proposed_args_value as Dictionary).duplicate(true)
	if proposed_op == "":
		return _make_error("hermes.propose_operation", "MISSING_ARG", "hermes.propose_operation requires op")
	if proposed_op == "hermes.propose_operation":
		return _make_error("hermes.propose_operation", "INVALID_PROPOSAL", "Nested hermes.propose_operation is not allowed")
	var normalized: Dictionary = _normalize_operation(proposed_op, proposed_args)
	proposed_op = str(normalized.get("op", "")).strip_edges()
	proposed_args = normalized.get("args", {}) if normalized.get("args", {}) is Dictionary else {}
	if _shell != null and _shell.has_method("_append_hermes_terminal_output"):
		_shell.call("_append_hermes_terminal_output", "Executing proposed operation: %s" % proposed_op, str(args.get("source", "Hermes")))
	return execute_operation(proposed_op, proposed_args)

func _route_files_list_dir(operation: String, args: Dictionary) -> Dictionary:
	if _filesystem == null:
		return _make_error(operation, "FILESYSTEM_UNAVAILABLE", "Filesystem service is unavailable")
	var list_path: String = _normalize_path(str(args.get("path", _home_path())))
	if not bool(_filesystem.call("is_dir", list_path)):
		return _make_error(operation, "DIR_NOT_FOUND", "Directory not found: " + list_path)
	return _make_result(operation, {"path": list_path, "entries": _filesystem.call("list_dir", list_path)})

func _route_files_read_file(operation: String, args: Dictionary) -> Dictionary:
	if _filesystem == null:
		return _make_error(operation, "FILESYSTEM_UNAVAILABLE", "Filesystem service is unavailable")
	var read_path: String = _normalize_path(str(args.get("path", "")))
	if read_path == "":
		return _make_error(operation, "MISSING_ARG", "files.read_file requires path")
	var read_result: Dictionary = _filesystem.call("read_file_result", read_path)
	if not bool(read_result.get("ok", false)):
		return _make_error(operation, "READ_FAILED", str(read_result.get("error", "Could not read file")))
	return _make_result(operation, {"path": read_path, "content": str(read_result.get("content", ""))})

func _route_files_write_file(operation: String, args: Dictionary) -> Dictionary:
	if _filesystem == null:
		return _make_error(operation, "FILESYSTEM_UNAVAILABLE", "Filesystem service is unavailable")
	var write_path: String = _normalize_path(str(args.get("path", "")))
	if write_path == "":
		return _make_error(operation, "MISSING_ARG", "files.write_file requires path")
	var had_file: bool = bool(_filesystem.call("exists", write_path))
	var write_message: String = str(_filesystem.call("write_file", write_path, str(args.get("content", ""))))
	if write_message != "":
		return _make_error(operation, "WRITE_FAILED", write_message)
	_emit_shell_event("file.updated" if had_file else "file.created", {"path": write_path})
	return _make_result(operation, {"path": write_path, "saved": true})

func _route_files_mkdir(operation: String, args: Dictionary) -> Dictionary:
	if _filesystem == null:
		return _make_error(operation, "FILESYSTEM_UNAVAILABLE", "Filesystem service is unavailable")
	var dir_path: String = _normalize_path(str(args.get("path", args.get("directory", args.get("dir", "")))))
	if dir_path == "":
		return _make_error(operation, "MISSING_ARG", "files.mkdir requires path")
	var mkdir_message: String = str(_filesystem.call("make_dir", dir_path))
	if mkdir_message != "":
		return _make_error(operation, "MKDIR_FAILED", mkdir_message)
	_emit_shell_event("file.created", {"path": dir_path, "type": "dir"})
	return _make_result(operation, {"path": dir_path, "created": true, "type": "dir"})

func _route_files_delete(operation: String, args: Dictionary) -> Dictionary:
	if _filesystem == null:
		return _make_error(operation, "FILESYSTEM_UNAVAILABLE", "Filesystem service is unavailable")
	var delete_path: String = _normalize_path(str(args.get("path", args.get("target", ""))))
	if delete_path == "":
		return _make_error(operation, "MISSING_ARG", "files.delete requires path")
	var delete_message: String = str(_filesystem.call("delete_path", delete_path))
	if delete_message != "":
		return _make_error(operation, "DELETE_FAILED", delete_message)
	_emit_shell_event("file.deleted", {"path": delete_path})
	return _make_result(operation, {"path": delete_path, "deleted": true})

func _route_files_move(operation: String, args: Dictionary) -> Dictionary:
	if _filesystem == null:
		return _make_error(operation, "FILESYSTEM_UNAVAILABLE", "Filesystem service is unavailable")
	var source_path: String = _normalize_path(str(args.get("source", args.get("src", args.get("from", "")))))
	var destination_path: String = _normalize_path(str(args.get("destination", args.get("dest", args.get("to", "")))))
	if source_path == "" or destination_path == "":
		return _make_error(operation, "MISSING_ARG", "files.move requires source and destination")
	var move_message: String = str(_filesystem.call("move_path", source_path, destination_path))
	if move_message != "":
		return _make_error(operation, "MOVE_FAILED", move_message)
	_emit_shell_event("file.moved", {"source": source_path, "destination": destination_path})
	return _make_result(operation, {"source": source_path, "destination": destination_path, "moved": true})

func _route_files_copy(operation: String, args: Dictionary) -> Dictionary:
	if _filesystem == null:
		return _make_error(operation, "FILESYSTEM_UNAVAILABLE", "Filesystem service is unavailable")
	var source_path: String = _normalize_path(str(args.get("source", args.get("src", args.get("from", "")))))
	var destination_path: String = _normalize_path(str(args.get("destination", args.get("dest", args.get("to", "")))))
	if source_path == "" or destination_path == "":
		return _make_error(operation, "MISSING_ARG", "files.copy requires source and destination")
	var copy_message: String = str(_filesystem.call("copy_path", source_path, destination_path))
	if copy_message != "":
		return _make_error(operation, "COPY_FAILED", copy_message)
	_emit_shell_event("file.copied", {"source": source_path, "destination": destination_path})
	return _make_result(operation, {"source": source_path, "destination": destination_path, "copied": true})

func _route_windows_list(operation: String, _args: Dictionary) -> Dictionary:
	if _window_manager != null and _window_manager.has_method("get_windows"):
		var windows_value: Variant = _window_manager.call("get_windows")
		var windows: Array = windows_value.duplicate(true) if windows_value is Array else []
		return _make_result(operation, {"windows": windows})
	if _shell != null and _shell.has_method("hermes_get_state"):
		var state: Variant = _shell.call("hermes_get_state", {"include_apps": false, "include_windows": true, "include_filesystem": false})
		if state is Dictionary:
			return _make_result(operation, {"windows": (state as Dictionary).get("windows", [])})
	return _make_result(operation, {"windows": []})

func _route_windows_open_app(operation: String, args: Dictionary) -> Dictionary:
	if _shell == null or not _shell.has_method("launch_app"):
		return _make_error(operation, "SHELL_UNAVAILABLE", "Shell launch_app boundary is unavailable")
	var app_id: String = str(args.get("app_id", ""))
	if app_id == "":
		return _make_error(operation, "MISSING_ARG", "windows.open_app requires app_id")
	var window: Variant = _shell.call("launch_app", app_id)
	if window == null:
		return _make_error(operation, "OPEN_FAILED", "Could not open app: " + app_id)
	return _make_result(operation, {"window_id": _window_id_for(window), "app_id": app_id})

func _route_windows_focus(operation: String, args: Dictionary) -> Dictionary:
	if _shell == null:
		return _make_error(operation, "SHELL_UNAVAILABLE", "Shell focus boundary is unavailable")
	var focus_window_id: String = str(args.get("window_id", ""))
	var focus_app_id: String = str(args.get("app_id", ""))
	var target_window: Variant = null
	if focus_window_id != "" and _shell.has_method("_find_window_by_id"):
		target_window = _shell.call("_find_window_by_id", focus_window_id)
	if target_window == null and focus_app_id != "" and _window_manager != null and _window_manager.has_method("get_window_for_app"):
		target_window = _window_manager.call("get_window_for_app", StringName(focus_app_id))
	if target_window == null:
		return _make_error(operation, "WINDOW_NOT_FOUND", "Window not found")
	if _shell.has_method("_focus_window"):
		_shell.call("_focus_window", target_window)
	elif _window_manager != null and _window_manager.has_method("get_window_id") and _window_manager.has_method("focus_window"):
		_window_manager.call("focus_window", int(_window_manager.call("get_window_id", target_window)))
	return _make_result(operation, {"window_id": _window_id_for(target_window), "app_id": str(target_window.get("app_id")) if target_window is Object else focus_app_id})

func _route_notifications_create(operation: String, args: Dictionary) -> Dictionary:
	if _shell == null or not _shell.has_method("notify"):
		return _make_error(operation, "SHELL_UNAVAILABLE", "Shell notify boundary is unavailable")
	var title: String = str(args.get("title", "Hermes"))
	var body: String = str(args.get("body", ""))
	var level: String = str(args.get("level", "info"))
	var notification_id: String = str(_shell.call("notify", {"title": title, "body": body, "level": level, "app_id": str(args.get("app_id", "hermes"))}))
	return _make_result(operation, {"displayed": true, "notification_id": notification_id})

func _route_system_get_state(operation: String, args: Dictionary) -> Dictionary:
	if _shell == null or not _shell.has_method("hermes_get_state"):
		return _make_error(operation, "SHELL_UNAVAILABLE", "Shell state boundary is unavailable")
	var state_options: Dictionary = {
		"include_apps": bool(args.get("include_apps", true)),
		"include_windows": bool(args.get("include_windows", true)),
		"include_filesystem": bool(args.get("include_filesystem", false))
	}
	var state: Variant = _shell.call("hermes_get_state", state_options)
	if not (state is Dictionary):
		return _make_error(operation, "STATE_UNAVAILABLE", "HermesOS state snapshot unavailable")
	return _make_result(operation, (state as Dictionary).duplicate(true))

func _route_legacy_shell(operation: String, args: Dictionary) -> Dictionary:
	if _shell != null and _shell.has_method("_hermes_execute_operation_legacy_dispatch"):
		var legacy_result: Variant = _shell.call("_hermes_execute_operation_legacy_dispatch", operation, args.duplicate(true))
		if legacy_result is Dictionary:
			return legacy_result as Dictionary
	return _make_error(operation, "UNKNOWN_OPERATION", "No registered operation: " + operation)

func _normalize_operation(op: String, args: Dictionary) -> Dictionary:
	if _shell != null and _shell.has_method("_normalize_v1_operation"):
		var normalized: Variant = _shell.call("_normalize_v1_operation", op, args.duplicate(true))
		if normalized is Dictionary:
			return normalized as Dictionary
	return {"op": op.strip_edges(), "args": args.duplicate(true)}

func _shape_result(operation: String, response: Dictionary) -> Dictionary:
	var ok: bool = bool(response.get("ok", false))
	var result_value: Variant = response.get("result", {})
	var result: Dictionary = result_value.duplicate(true) if result_value is Dictionary else {"value": result_value}
	var error_value: Variant = response.get("error", {})
	var error: Dictionary = error_value.duplicate(true) if error_value is Dictionary else {}
	if not ok and error.is_empty():
		error = HermesProtocol.make_error("OPERATION_FAILED", "Operation failed: " + operation)
	return {
		"ok": ok,
		"error": {} if ok else error,
		"result": result,
		"operation": str(response.get("operation", operation))
	}

func _make_result(operation: String, result: Dictionary = {}) -> Dictionary:
	return {"ok": true, "error": {}, "result": result.duplicate(true), "operation": operation}

func _make_error(operation: String, code: String, message: String, details: Dictionary = {}) -> Dictionary:
	return {"ok": false, "error": HermesProtocol.make_error(code, message, details), "result": {}, "operation": operation}

func _emit_operation_event(event_name: StringName, payload: Dictionary) -> void:
	var safe_payload: Dictionary = payload.duplicate(true)
	if _event_bus != null:
		_event_bus.emit_event(event_name, safe_payload)
		return
	_emit_shell_event(str(event_name), safe_payload)

func _emit_shell_event(event_name: String, payload: Dictionary = {}) -> void:
	if _shell != null and _shell.has_method("_emit_hermes_event"):
		_shell.call("_emit_hermes_event", event_name, payload.duplicate(true))

func _normalize_path(path: String) -> String:
	if _filesystem != null and _filesystem.has_method("normalize_path"):
		return str(_filesystem.call("normalize_path", path))
	return path

func _home_path() -> String:
	if _filesystem != null and _filesystem.has_method("home_path"):
		return str(_filesystem.call("home_path"))
	return "/home/player"

func _window_id_for(window: Variant) -> String:
	if window == null:
		return ""
	if _shell != null and _shell.has_method("_window_id"):
		return str(_shell.call("_window_id", window))
	if _window_manager != null and _window_manager.has_method("get_window_id"):
		return str(_window_manager.call("get_window_id", window))
	if window is Object:
		return "win_%s" % str((window as Object).get_instance_id())
	return ""
