extends "res://scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

const OSEventBus = preload("res://scripts/os/core/os_event_bus.gd")

var ready_called: bool = false
var input_events: Array[String] = []
var send_invocations: Array[String] = []
var gateway_results: Array[Dictionary] = []
var last_event = null
var _event_bus = null

func _app_ready() -> void:
	ready_called = true
	_attach_agent_events()
	if state == null:
		return
	state.set_many({
		"draft": "",
		"can_send": false,
		"is_sending": false,
		"has_messages": false,
		"has_user_message": false,
		"has_gateway_message": false,
		"last_user_message": "",
		"last_gateway_message": "",
		"gateway": _gateway_status_state()
	})
	state.watch("draft", Callable(self, "_on_draft_changed"))

func _on_draft_changed(value) -> void:
	if state == null:
		return
	var clean: String = str(value).strip_edges()
	state.set("can_send", clean != "" and not state.get_bool("is_sending", false))

func handle_input(event) -> void:
	last_event = event
	input_events.append(str(event.value))

func send_message(event = null) -> void:
	last_event = event
	if state == null:
		return
	var draft: String = state.get_string("draft", "").strip_edges()
	if draft == "":
		state.set("gateway", {"label": "Gateway: enter a message", "variant": "warning"})
		return
	if state.get_bool("is_sending", false):
		return
	send_invocations.append(draft)
	state.set_many({
		"is_sending": true,
		"can_send": false,
		"gateway": {"label": "Gateway: Sending", "variant": "warning"}
	})
	var result: Dictionary = _send_to_gateway(draft)
	gateway_results.append(result.duplicate(true))
	var ok: bool = bool(result.get("ok", false))
	if ok:
		if ui != null:
			ui.set_value("message-input", "")
			ui.focus("message-input")
		if _gateway_result_is_async(result):
			state.set_many({
				"draft": "",
				"is_sending": true,
				"can_send": false,
				"has_messages": true,
				"has_user_message": true,
				"has_gateway_message": true,
				"last_user_message": draft,
				"last_gateway_message": "Waiting for Hermes Gateway response…",
				"gateway": {"label": "Gateway: Sending", "variant": "warning"}
			})
			return
		state.set_many({
			"draft": "",
			"is_sending": false,
			"can_send": false,
			"has_messages": true,
			"has_user_message": true,
			"has_gateway_message": true,
			"last_user_message": draft,
			"last_gateway_message": _gateway_result_text(result),
			"gateway": _gateway_status_state()
		})
		return
	state.set_many({
		"is_sending": false,
		"can_send": draft != "",
		"has_messages": true,
		"has_user_message": true,
		"has_gateway_message": true,
		"last_user_message": draft,
		"last_gateway_message": _gateway_error_text(result),
		"gateway": {"label": "Gateway: Offline", "variant": "danger"}
	})

func _send_to_gateway(prompt: String) -> Dictionary:
	if os != null and os.gateway != null and os.gateway.has_method("send_chat"):
		var value = os.gateway.send_chat(prompt)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {
		"ok": false,
		"terminal_result": "Hermes Gateway service is unavailable",
		"error": {"code": "GATEWAY_UNAVAILABLE", "message": "Hermes Gateway service is unavailable"}
	}

func _gateway_result_is_async(result: Dictionary) -> bool:
	var result_value = result.get("result", null)
	if result_value is Dictionary and bool((result_value as Dictionary).get("queued", false)):
		return true
	var terminal_result: String = str(result.get("terminal_result", "")).strip_edges().to_lower()
	return terminal_result.contains("sent to hermes gateway")

func _attach_agent_events() -> void:
	if os == null or not (os.context is Dictionary):
		return
	var bus_value = os.context.get("event_bus", null)
	if bus_value == null or not bus_value.has_method("subscribe"):
		return
	_event_bus = bus_value
	_event_bus.subscribe(OSEventBus.AGENT_RESPONSE_RECEIVED, self, "_on_agent_event")
	_event_bus.subscribe(OSEventBus.AGENT_ERROR, self, "_on_agent_event")
	_event_bus.subscribe(OSEventBus.AGENT_STATUS_CHANGED, self, "_on_agent_event")

func app_unmounted() -> void:
	if _event_bus != null and _event_bus.has_method("unsubscribe"):
		_event_bus.unsubscribe(OSEventBus.AGENT_RESPONSE_RECEIVED, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_ERROR, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_STATUS_CHANGED, self, "_on_agent_event")
	_event_bus = null
	super.app_unmounted()

func _on_agent_event(event_name: StringName, payload: Dictionary) -> void:
	if state == null:
		return
	match event_name:
		OSEventBus.AGENT_RESPONSE_RECEIVED:
			if not state.get_bool("is_sending", false):
				return
			var assistant_text: String = str(payload.get("assistant_text", "")).strip_edges()
			state.set_many({
				"is_sending": false,
				"can_send": state.get_string("draft", "").strip_edges() != "",
				"has_messages": true,
				"has_gateway_message": true,
				"last_gateway_message": assistant_text if assistant_text != "" else "(no output)",
				"gateway": _gateway_status_state()
			})
		OSEventBus.AGENT_ERROR:
			if not state.get_bool("is_sending", false):
				return
			state.set_many({
				"is_sending": false,
				"can_send": state.get_string("draft", "").strip_edges() != "",
				"has_messages": true,
				"has_gateway_message": true,
				"last_gateway_message": str(payload.get("message", "Hermes Gateway error")),
				"gateway": {"label": "Gateway: Offline", "variant": "danger"}
			})
		OSEventBus.AGENT_STATUS_CHANGED:
			if not state.get_bool("is_sending", false):
				state.set("gateway", _gateway_status_state())

func _gateway_status_state() -> Dictionary:
	var status: Dictionary = _agent_gateway_status()
	var configured: bool = bool(status.get("configured", false))
	var busy: bool = bool(status.get("busy", false))
	if busy:
		return {"label": "Gateway: Checking", "variant": "warning"}
	if configured:
		return {"label": "Gateway: Online", "variant": "success"}
	return {"label": "Gateway: Offline", "variant": "danger"}

func _agent_gateway_status() -> Dictionary:
	var agent_service = null
	if os != null and os.context is Dictionary:
		agent_service = os.context.get("agent_service", null)
	if agent_service != null and agent_service.has_method("get_status"):
		var value = agent_service.call("get_status")
		if value is Dictionary:
			var gateway_value = (value as Dictionary).get("gateway", {})
			if gateway_value is Dictionary:
				return (gateway_value as Dictionary).duplicate(true)
	return {"configured": false, "busy": false, "model": ""}

func _gateway_result_text(result: Dictionary) -> String:
	var terminal_result: String = str(result.get("terminal_result", "")).strip_edges()
	if terminal_result != "":
		return terminal_result
	var result_value = result.get("result", null)
	if result_value is Dictionary:
		var text: String = str((result_value as Dictionary).get("assistant_text", "")).strip_edges()
		if text != "":
			return text
	return "Message sent to Hermes Gateway."

func _gateway_error_text(result: Dictionary) -> String:
	var terminal_result: String = str(result.get("terminal_result", "")).strip_edges()
	if terminal_result != "":
		return terminal_result
	var error_value = result.get("error", null)
	if error_value is Dictionary:
		return str((error_value as Dictionary).get("message", "Hermes Gateway request failed"))
	return "Hermes Gateway request failed"
