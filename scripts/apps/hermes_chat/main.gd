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
		"has_action_status": true,
		"action_status": "Ready for Hermes_OS actions",
		"action_status_detail": "Try an example: see the OS, open Browser, go to home.hermes, click, type, or scroll.",
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
		"has_action_status": true,
		"action_status": "Attempting Hermes_OS action…",
		"action_status_detail": _action_intent_text(draft),
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
				"has_action_status": true,
				"action_status": "Hermes is working in Hermes_OS…",
				"action_status_detail": "Waiting for Gateway/MCP tool results. If blocked, Hermes will report the exact Hermes_OS tool or gate.",
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
			"has_action_status": true,
			"action_status": "Hermes reported a result",
			"action_status_detail": _gateway_result_text(result),
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
		"has_action_status": true,
		"action_status": "Hermes_OS action blocked",
		"action_status_detail": _gateway_error_text(result),
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
	_event_bus.subscribe(OSEventBus.AGENT_OPERATION_REQUESTED, self, "_on_agent_event")
	_event_bus.subscribe(OSEventBus.AGENT_OPERATION_COMPLETED, self, "_on_agent_event")
	_event_bus.subscribe(OSEventBus.AGENT_OPERATION_FAILED, self, "_on_agent_event")

func app_unmounted() -> void:
	if _event_bus != null and _event_bus.has_method("unsubscribe"):
		_event_bus.unsubscribe(OSEventBus.AGENT_RESPONSE_RECEIVED, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_ERROR, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_STATUS_CHANGED, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_OPERATION_REQUESTED, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_OPERATION_COMPLETED, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_OPERATION_FAILED, self, "_on_agent_event")
	_event_bus = null
	super.app_unmounted()

func _on_agent_event(event_name: StringName, payload: Dictionary) -> void:
	if state == null:
		return
	match event_name:
		OSEventBus.AGENT_RESPONSE_RECEIVED:
			if not state.get_bool("is_sending", false):
				return
			var assistant_text: String = _clean_user_facing_text(str(payload.get("assistant_text", "")).strip_edges())
			var response_text: String = assistant_text if assistant_text != "" else "(no output)"
			state.set_many({
				"is_sending": false,
				"can_send": state.get_string("draft", "").strip_edges() != "",
				"has_messages": true,
				"has_gateway_message": true,
				"last_gateway_message": response_text,
				"has_action_status": true,
				"action_status": "Hermes reported a result",
				"action_status_detail": _compact_status_detail(response_text),
				"gateway": _gateway_status_state()
			})
		OSEventBus.AGENT_ERROR:
			if not state.get_bool("is_sending", false):
				return
			var error_text: String = _clean_user_facing_text(str(payload.get("message", "Hermes Gateway error")))
			state.set_many({
				"is_sending": false,
				"can_send": state.get_string("draft", "").strip_edges() != "",
				"has_messages": true,
				"has_gateway_message": true,
				"last_gateway_message": error_text,
				"has_action_status": true,
				"action_status": "Hermes_OS action blocked",
				"action_status_detail": error_text,
				"gateway": {"label": "Gateway: Offline", "variant": "danger"}
			})
		OSEventBus.AGENT_STATUS_CHANGED:
			if not state.get_bool("is_sending", false):
				state.set("gateway", _gateway_status_state())
		OSEventBus.AGENT_OPERATION_REQUESTED:
			state.set_many({
				"has_action_status": true,
				"action_status": "Using Hermes_OS tool: " + _payload_operation(payload),
				"action_status_detail": _format_operation_detail(payload, false)
			})
		OSEventBus.AGENT_OPERATION_COMPLETED:
			state.set_many({
				"has_action_status": true,
				"action_status": "Succeeded: " + _payload_operation(payload),
				"action_status_detail": _format_operation_detail(payload, false)
			})
		OSEventBus.AGENT_OPERATION_FAILED:
			state.set_many({
				"has_action_status": true,
				"action_status": "Blocked: " + _payload_operation(payload),
				"action_status_detail": _format_operation_detail(payload, true)
			})

func ask_what_can_see(event = null) -> void:
	last_event = event
	_send_example("what can you see?")

func example_open_browser(event = null) -> void:
	last_event = event
	_send_example("open the browser")

func example_go_home(event = null) -> void:
	last_event = event
	_send_example("go to home.hermes")

func example_list_windows(event = null) -> void:
	last_event = event
	_send_example("what apps are open?")

func example_click_first_link(event = null) -> void:
	last_event = event
	_send_example("click the first link")

func example_type_hello(event = null) -> void:
	last_event = event
	_send_example("type hello from Hermes")

func example_scroll_down(event = null) -> void:
	last_event = event
	_send_example("scroll down")

func _send_example(prompt: String) -> void:
	if state == null:
		return
	if state.get_bool("is_sending", false):
		state.set_many({
			"has_action_status": true,
			"action_status": "Hermes_OS action already running",
			"action_status_detail": "Wait for the current Gateway/MCP request to finish before starting another example."
		})
		return
	state.set("draft", prompt)
	if ui != null:
		ui.set_value("message-input", prompt)
	send_message({"source": "example", "prompt": prompt})

func _action_intent_text(prompt: String) -> String:
	var lower := prompt.to_lower()
	if lower.contains("what can you see") or lower.contains("apps and windows"):
		return "Expected tools: hermes_os_observe / hermes_os_get_ui_tree / window-app state."
	if lower.contains("open") and lower.contains("browser"):
		return "Expected tool: hermes_os_open_app with app_id=browser."
	if lower.contains("navigate") or lower.contains("home.hermes"):
		return "Expected tool: hermes_os_browser_navigate to a bundled Hermes Internet page."
	if lower.contains("click"):
		return "Expected tool: hermes_os_browser_activate_link or hermes_os_click, scoped to Hermes_OS."
	if lower.contains("type"):
		return "Expected tool: hermes_os_type_text, scoped to the focused Hermes_OS surface."
	if lower.contains("scroll"):
		return "Expected tool: hermes_os_scroll or hermes_os_browser_test_scroll, scoped to Hermes_OS."
	return "Hermes will use Hermes_OS MCP tools when the request involves OS state or visible control."

func _payload_operation(payload: Dictionary) -> String:
	var operation: String = str(payload.get("operation", "")).strip_edges()
	if operation == "":
		operation = str(payload.get("op", "")).strip_edges()
	return operation if operation != "" else "Hermes_OS operation"

func _format_operation_detail(payload: Dictionary, prefer_error: bool) -> String:
	if prefer_error:
		var error_value = payload.get("error", {})
		if error_value is Dictionary:
			var message: String = str((error_value as Dictionary).get("message", "")).strip_edges()
			var code: String = str((error_value as Dictionary).get("code", "")).strip_edges()
			if message != "" and code != "":
				return code + ": " + message
			if message != "":
				return message
			if code != "":
				return code
	var result_value = payload.get("result", {})
	if result_value is Dictionary and not (result_value as Dictionary).is_empty():
		return _dictionary_to_user_text(result_value as Dictionary)
	var args_value = payload.get("args", {})
	if args_value is Dictionary and not (args_value as Dictionary).is_empty():
		return "Args: " + _format_key_values(args_value as Dictionary)
	return "Hermes_OS operation state changed."

func _clean_user_facing_text(text: String) -> String:
	var clean := text.strip_edges()
	if clean == "":
		return ""
	if (clean.begins_with("{") and clean.ends_with("}")) or (clean.begins_with("[") and clean.ends_with("]")):
		var parsed: Variant = JSON.parse_string(clean)
		if parsed is Dictionary:
			return _dictionary_to_user_text(parsed as Dictionary)
	return _compact_status_detail(clean)

func _dictionary_to_user_text(data: Dictionary) -> String:
	var error_value = data.get("error", null)
	if error_value is Dictionary:
		return _format_blocker(error_value as Dictionary)
	var assistant_text: String = str(data.get("assistant_text", "")).strip_edges()
	if assistant_text != "":
		return _clean_user_facing_text(assistant_text)
	var message: String = str(data.get("message", "")).strip_edges()
	if message != "":
		return _ensure_sentence(message)
	var terminal_result: String = str(data.get("terminal_result", "")).strip_edges()
	if terminal_result != "":
		return _ensure_sentence(terminal_result)
	var result_value = data.get("result", null)
	if result_value is Dictionary and not (result_value as Dictionary).is_empty():
		return _dictionary_to_user_text(result_value as Dictionary)
	var state_parts := PackedStringArray()
	for key in ["app_id", "window_id", "title", "url", "status", "focused"]:
		if data.has(key):
			state_parts.append(str(key) + "=" + str(data.get(key)))
	if state_parts.size() > 0:
		return _compact_status_detail("Hermes_OS result: " + ", ".join(state_parts))
	return "Hermes_OS operation completed."

func _format_blocker(error: Dictionary) -> String:
	var code: String = str(error.get("code", "")).strip_edges()
	var message: String = str(error.get("message", "")).strip_edges()
	if code != "" and message != "":
		return "Blocked: " + code + " — " + _ensure_sentence(message)
	if message != "":
		return "Blocked: " + _ensure_sentence(message)
	if code != "":
		return "Blocked: " + code
	return "Blocked: Hermes_OS operation failed."

func _format_key_values(values: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in values.keys():
		parts.append(str(key) + "=" + str(values.get(key)))
	return _compact_status_detail(", ".join(parts))

func _ensure_sentence(text: String) -> String:
	var clean := text.strip_edges()
	if clean == "":
		return clean
	var last := clean.substr(clean.length() - 1, 1)
	if last == "." or last == "!" or last == "?":
		return clean
	return clean + "."

func _compact_status_detail(text: String) -> String:
	var clean := text.strip_edges().replace("\n", " ")
	while clean.contains("  "):
		clean = clean.replace("  ", " ")
	if clean.length() > 220:
		return clean.substr(0, 217) + "…"
	return clean

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
