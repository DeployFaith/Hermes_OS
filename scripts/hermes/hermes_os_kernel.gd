extends Node

const HermesProtocol = preload("res://scripts/hermes/hermes_protocol.gd")
const HermesBridgeClientScript = preload("res://scripts/hermes/hermes_bridge_client.gd")
const HermesOperationRouterScript = preload("res://scripts/hermes/hermes_operation_router.gd")

signal os_event(event_name: String, payload: Dictionary)
signal bridge_connected
signal bridge_disconnected

@export var auto_connect := false
@export var endpoint_url := "ws://127.0.0.1:8787/hermesos/ws"
@export var project_id := "hermesos_demo"

var session_id := "game_session_%d" % int(Time.get_unix_time_from_system())
var _booted := false
var _shell: Node
var _bridge
var _router
var _game_actions: Dictionary = {}

func _ready() -> void:
	_bridge = HermesBridgeClientScript.new()
	_bridge.name = "HermesBridgeClient"
	add_child(_bridge)
	_bridge.connected.connect(_on_bridge_connected)
	_bridge.disconnected.connect(_on_bridge_disconnected)
	_bridge.message_received.connect(_on_bridge_message_received)
	_bridge.protocol_error.connect(_on_bridge_protocol_error)

	_router = HermesOperationRouterScript.new()
	_router.setup(self)

	if auto_connect:
		connect_bridge()

func register_shell(shell_node: Node) -> void:
	_shell = shell_node
	if _shell.has_signal("hermes_event") and not _shell.hermes_event.is_connected(_on_shell_event):
		_shell.hermes_event.connect(_on_shell_event)
	boot()

func boot() -> void:
	if _booted:
		return
	_booted = true
	emit_os_event("os.booted", {"session_id": session_id})

func shutdown() -> void:
	if not _booted:
		return
	disconnect_bridge()
	_booted = false
	emit_os_event("os.shutdown", {"session_id": session_id})

func connect_bridge(url := "") -> String:
	var target := endpoint_url if url.strip_edges() == "" else url.strip_edges()
	if target == "":
		return "Missing endpoint URL"
	return _bridge.connect_to_endpoint(target)

func disconnect_bridge() -> void:
	if _bridge:
		_bridge.close_connection()

func is_bridge_connected() -> bool:
	return _bridge != null and _bridge.is_connected_to_backend()

func register_game_action(operation_name: String, metadata: Dictionary) -> void:
	_game_actions[operation_name] = metadata.duplicate(true)

func get_manifest() -> Dictionary:
	var apps: Array = []
	if _shell and _shell.has_method("hermes_get_manifest_apps"):
		apps = _shell.call("hermes_get_manifest_apps")
	var game_actions := {}
	for key in _game_actions.keys():
		game_actions[key] = _game_actions[key]
	return {
		"protocol_version": HermesProtocol.PROTOCOL_VERSION,
		"os": {"name": "HermesOS", "version": "0.1.0"},
		"session": {
			"session_id": session_id,
			"project_id": project_id
		},
		"capabilities": {
			"full_hermesos_control": true,
			"game_control": not _game_actions.is_empty(),
			"filesystem": true,
			"terminal": true,
			"notifications": true,
			"windows": true
		},
		"apps": apps,
		"game_actions": game_actions,
		"actions": _kernel_actions()
	}

func _kernel_actions() -> Dictionary:
	return {
		"os.get_state": {
			"description": "Get HermesOS state snapshot.",
			"args_schema": {
				"include_apps": "bool",
				"include_windows": "bool",
				"include_filesystem": "bool"
			}
		},
		"os.get_manifest": {
			"description": "Get HermesOS manifest.",
			"args_schema": {}
		}
	}

func get_state(options := {}) -> Dictionary:
	if _shell and _shell.has_method("hermes_get_state"):
		return _shell.call("hermes_get_state", options)
	return {
		"desktop": {},
		"windows": [],
		"apps": {},
		"notifications": []
	}

func execute_operation(op: String, args: Dictionary, request_id := "") -> Dictionary:
	return _router.execute(op, args, request_id)

func route_os_operation(op: String, args: Dictionary, _request_id := "") -> Dictionary:
	match op:
		"os.get_state":
			return {"ok": true, "result": get_state(args)}
		"os.get_manifest":
			return {"ok": true, "result": get_manifest()}
		_:
			return {"ok": false, "error": HermesProtocol.make_error("UNKNOWN_OPERATION", "No registered operation: " + op)}

func route_game_operation(op: String, args: Dictionary, _request_id := "") -> Dictionary:
	if not _game_actions.has(op):
		return {"ok": false, "error": HermesProtocol.make_error("GAME_ACTION_NOT_EXPOSED", "No registered game action: " + op)}
	var entry: Dictionary = _game_actions[op]
	if not entry.has("handler"):
		return {"ok": false, "error": HermesProtocol.make_error("GAME_HANDLER_MISSING", "Game action has no handler: " + op)}
	var handler: Callable = entry["handler"]
	if not handler.is_valid():
		return {"ok": false, "error": HermesProtocol.make_error("GAME_HANDLER_INVALID", "Game action handler invalid: " + op)}
	var response: Variant = handler.call(args)
	if response is Dictionary:
		return response
	return {"ok": true, "result": {"value": response}}

func route_shell_operation(op: String, args: Dictionary, _request_id := "") -> Dictionary:
	if _shell == null or not _shell.has_method("hermes_execute_operation"):
		return {"ok": false, "error": HermesProtocol.make_error("SHELL_UNAVAILABLE", "HermesOS shell is not registered")}
	var response: Variant = _shell.call("hermes_execute_operation", op, args)
	if response is Dictionary:
		return response
	return {"ok": false, "error": HermesProtocol.make_error("INVALID_OPERATION_RESULT", "Shell returned invalid operation result")}

func emit_os_event(event_name: String, payload: Dictionary = {}) -> void:
	os_event.emit(event_name, payload)
	if is_bridge_connected():
		_send_bridge_message(HermesProtocol.make_event(event_name, payload))

func _on_bridge_connected() -> void:
	bridge_connected.emit()
	emit_os_event("bridge.connected", {"endpoint": endpoint_url})
	_send_bridge_message(HermesProtocol.make_hello(session_id, project_id))
	_send_bridge_message(HermesProtocol.make_manifest(session_id, get_manifest()))
	emit_os_event("manifest.sent", {})

func _on_bridge_disconnected() -> void:
	bridge_disconnected.emit()
	emit_os_event("bridge.disconnected", {})

func _on_bridge_protocol_error(error_data: Dictionary) -> void:
	emit_os_event("bridge.error", error_data)

func _on_bridge_message_received(message: Dictionary) -> void:
	var message_type := str(message.get("type", ""))
	match message_type:
		"operation":
			_handle_operation_message(message)
		"request":
			_handle_request_message(message)
		"ping":
			_send_bridge_message({"type": "pong", "timestamp": HermesProtocol.timestamp_unix()})
		_:
			emit_os_event("bridge.message_ignored", {"type": message_type})

func _handle_operation_message(message: Dictionary) -> void:
	var operation_id := str(message.get("id", ""))
	var op := str(message.get("op", ""))
	var args: Dictionary = message.get("args", {}) if message.get("args", {}) is Dictionary else {}
	emit_os_event("operation.received", {"id": operation_id, "op": op})
	var response := execute_operation(op, args, operation_id)
	if bool(response.get("ok", false)):
		emit_os_event("operation.completed", {"id": operation_id, "op": op})
		_send_bridge_message(HermesProtocol.make_operation_result(operation_id, true, response.get("result", {}), {}))
	else:
		var error_data: Dictionary = response.get("error", HermesProtocol.make_error("OPERATION_FAILED", "Operation failed"))
		emit_os_event("operation.failed", {"id": operation_id, "op": op, "error": error_data})
		_send_bridge_message(HermesProtocol.make_operation_result(operation_id, false, {}, error_data))

func _handle_request_message(message: Dictionary) -> void:
	var request_id := str(message.get("id", ""))
	var op := str(message.get("op", ""))
	var args: Dictionary = message.get("args", {}) if message.get("args", {}) is Dictionary else {}
	var response := execute_operation(op, args, request_id)
	if bool(response.get("ok", false)):
		_send_bridge_message(HermesProtocol.make_response(request_id, true, response.get("result", {}), {}))
	else:
		var error_data: Dictionary = response.get("error", HermesProtocol.make_error("REQUEST_FAILED", "Request failed"))
		_send_bridge_message(HermesProtocol.make_response(request_id, false, {}, error_data))

func _send_bridge_message(message: Dictionary) -> void:
	if _bridge == null:
		return
	var send_error: String = _bridge.send_message(message)
	if send_error != "":
		emit_os_event("bridge.send_error", HermesProtocol.make_error("SEND_FAILED", send_error))

func _on_shell_event(event_name: String, payload: Dictionary) -> void:
	emit_os_event(event_name, payload)
