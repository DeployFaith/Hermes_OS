extends "res://scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

const OSEventBus = preload("res://scripts/os/core/os_event_bus.gd")

var ready_called: bool = false
var input_events: Array[String] = []
var send_invocations: Array[String] = []
var gateway_results: Array[Dictionary] = []
var last_event = null
var _event_bus = null
var _agent_service = null

func _app_ready() -> void:
	ready_called = true
	_attach_agent_events()
	if state == null:
		return
	var gateway_status: Dictionary = _agent_gateway_status()
	var current_model: String = str(gateway_status.get("model", "")).strip_edges()
	var current_profile: String = _gateway_profile_from_status(gateway_status)
	var display_model: String = _display_model_id(current_model)
	state.set_many({
		"draft": "",
		"can_send": false,
		"is_sending": false,
		"is_streaming": false,
		"current_model": display_model,
		"model_options": _model_options(current_model),
		"model_label": "Model: " + display_model,
		"is_switching_model": false,
		"current_profile": current_profile,
		"profile_draft": current_profile,
		"profile_label": "Profile: " + current_profile,
		"is_switching_profile": false,
		"streaming_text": "",
		"streaming_status": "",
		"has_messages": false,
		"has_user_message": false,
		"has_gateway_message": false,
		"last_user_message": "",
		"last_gateway_message": "",
		"has_action_status": true,
		"action_status": "Ready for Hermes_OS actions",
		"action_status_detail": "Try an example: see the OS, open Browser, go to home.hermes, click, type, or scroll.",
		"gateway": _gateway_status_state(),
		"gateway_display_label": _gateway_status_state().get("label", "Gateway: Offline")
	})
	_configure_model_selector()
	_configure_profile_input()
	state.watch("draft", Callable(self, "_on_draft_changed"))

func _on_draft_changed(value) -> void:
	if state == null:
		return
	var clean: String = str(value).strip_edges()
	state.set("can_send", clean != "" and not state.get_bool("is_sending", false) and not state.get_bool("is_streaming", false))

func handle_input(event) -> void:
	last_event = event
	input_events.append(str(event.value))

func set_model(event = null) -> void:
	last_event = event
	if state == null:
		return
	var model_id: String = _event_model_id(event)
	if model_id == "":
		model_id = state.get_string("current_model", "").strip_edges()
	if model_id == "hermesos":
		state.set_many({
			"has_action_status": true,
			"action_status": "Model switch blocked",
			"action_status_detail": "hermesos is a Gateway profile hint, not a selectable model."
		})
		if ui != null:
			ui.set_value("model-selector", state.get_string("current_model", ""))
		return
	if state.get_bool("is_sending", false) or state.get_bool("is_streaming", false):
		state.set_many({
			"has_action_status": true,
			"action_status": "Cannot change model during active request",
			"action_status_detail": "Wait for the current Gateway/MCP request to finish before switching models."
		})
		return
	state.set("is_switching_model", true)
	var result := {"ok": false, "error": "Gateway client unavailable"}
	var agent_service = _resolve_agent_service()
	if agent_service != null and agent_service.has_method("set_gateway_model"):
		var value = agent_service.call("set_gateway_model", model_id)
		if value is Dictionary:
			result = (value as Dictionary).duplicate(true)
	if bool(result.get("ok", false)):
		var next_model: String = str(result.get("model", model_id)).strip_edges()
		if next_model == "":
			next_model = model_id
		state.set_many({
			"current_model": next_model,
			"model_label": "Model: " + next_model,
			"has_action_status": true,
			"action_status": "Model switched",
			"action_status_detail": "Hermes Gateway model is now " + next_model + "."
		})
		_set_gateway_state(_gateway_status_state())
	else:
		var error_text: String = _model_switch_error_text(result)
		state.set_many({
			"has_action_status": true,
			"action_status": "Model switch blocked",
			"action_status_detail": error_text,
			"current_model": state.get_string("current_model", "")
		})
		if ui != null:
			ui.set_value("model-selector", state.get_string("current_model", ""))
	state.set("is_switching_model", false)

func set_profile(event = null) -> void:
	last_event = event
	if state == null:
		return
	var profile_id: String = _event_profile_id(event)
	if profile_id == "":
		profile_id = state.get_string("profile_draft", "").strip_edges()
	if profile_id == "":
		profile_id = state.get_string("current_profile", "").strip_edges()
	if profile_id == "":
		return
	if state.get_bool("is_sending", false) or state.get_bool("is_streaming", false):
		state.set_many({
			"has_action_status": true,
			"action_status": "Cannot change profile during active request",
			"action_status_detail": "Wait for the current Gateway/MCP request to finish before switching profiles."
		})
		return
	state.set("is_switching_profile", true)
	var result := {"ok": false, "error": "Gateway client unavailable"}
	var agent_service = _resolve_agent_service()
	if agent_service != null and agent_service.has_method("set_gateway_profile"):
		var value = agent_service.call("set_gateway_profile", profile_id)
		if value is Dictionary:
			result = (value as Dictionary).duplicate(true)
	if bool(result.get("ok", false)):
		var next_profile: String = str(result.get("profile_hint", profile_id)).strip_edges()
		if next_profile == "":
			next_profile = profile_id
		state.set_many({
			"current_profile": next_profile,
			"profile_draft": next_profile,
			"profile_label": "Profile: " + next_profile,
			"has_action_status": true,
			"action_status": "Profile switched",
			"action_status_detail": "Hermes Gateway profile hint is now " + next_profile + "."
		})
		_set_gateway_state(_gateway_status_state())
	else:
		state.set_many({
			"has_action_status": true,
			"action_status": "Profile switch blocked",
			"action_status_detail": _model_switch_error_text(result),
			"profile_draft": state.get_string("current_profile", "")
		})
		if ui != null:
			ui.set_value("profile-input", state.get_string("current_profile", ""))
	state.set("is_switching_profile", false)

func send_message(event = null) -> void:
	last_event = event
	if state == null:
		return
	var draft: String = state.get_string("draft", "").strip_edges()
	if draft == "":
		_set_gateway_state({"label": "Gateway: enter a message", "variant": "warning"})
		return
	if state.get_bool("is_sending", false) or state.get_bool("is_streaming", false):
		return
	send_invocations.append(draft)
	print("HermesChat: send_message start streaming_attempt=true prompt_len=", draft.length())
	state.set_many({
		"is_sending": true,
		"is_streaming": false,
		"streaming_text": "",
		"streaming_status": "",
		"can_send": false,
		"has_action_status": true,
		"action_status": "Attempting Hermes_OS action…",
		"action_status_detail": _action_intent_text(draft)
	})
	_set_gateway_state({"label": "Gateway: Sending", "variant": "warning"})

	var stream_result: Dictionary = _send_to_gateway_stream(draft)
	print("HermesChat: stream request result available=", bool(stream_result.get("available", false)), " ok=", bool(stream_result.get("ok", false)))
	if bool(stream_result.get("available", false)):
		gateway_results.append(stream_result.duplicate(true))
		if bool(stream_result.get("ok", false)):
			if ui != null:
				ui.set_value("message-input", "")
				ui.focus("message-input")
			state.set_many({
				"draft": "",
				"is_sending": true,
				"is_streaming": true,
				"streaming_text": "",
				"streaming_status": "Hermes is responding…",
				"can_send": false,
				"has_messages": true,
				"has_user_message": true,
				"has_gateway_message": true,
				"last_user_message": draft,
				"last_gateway_message": "",
				"has_action_status": true,
				"action_status": "Hermes is responding…",
				"action_status_detail": "Receiving live response chunks from Hermes Gateway."
			})
			_set_gateway_state({"label": "Gateway: Streaming", "variant": "warning"})
			return
		state.set_many({
			"is_sending": false,
			"is_streaming": false,
			"streaming_text": "",
			"streaming_status": ""
		})

	print("HermesChat: falling back to non-streaming gateway send")
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
				"is_streaming": false,
				"streaming_text": "",
				"streaming_status": "",
				"can_send": false,
				"has_messages": true,
				"has_user_message": true,
				"has_gateway_message": true,
				"last_user_message": draft,
				"last_gateway_message": "Waiting for Hermes Gateway response…",
				"has_action_status": true,
				"action_status": "Hermes is working in Hermes_OS…",
				"action_status_detail": "Waiting for Gateway/MCP tool results. If blocked, Hermes will report the exact Hermes_OS tool or gate."
			})
			_set_gateway_state({"label": "Gateway: Sending", "variant": "warning"})
			return
		state.set_many({
			"draft": "",
			"is_sending": false,
			"is_streaming": false,
			"streaming_text": "",
			"streaming_status": "",
			"can_send": false,
			"has_messages": true,
			"has_user_message": true,
			"has_gateway_message": true,
			"last_user_message": draft,
			"last_gateway_message": _gateway_result_text(result),
			"has_action_status": true,
			"action_status": "Hermes reported a result",
			"action_status_detail": _gateway_result_text(result)
		})
		_set_gateway_state(_gateway_status_state())
		return
	state.set_many({
		"is_sending": false,
		"is_streaming": false,
		"streaming_text": "",
		"streaming_status": "",
		"can_send": draft != "",
		"has_messages": true,
		"has_user_message": true,
		"has_gateway_message": true,
		"last_user_message": draft,
		"last_gateway_message": _gateway_error_text(result),
		"has_action_status": true,
		"action_status": "Hermes_OS action blocked",
		"action_status_detail": _gateway_error_text(result)
	})
	_set_gateway_state({"label": "Gateway: Offline", "variant": "danger"})

func _send_to_gateway_stream(prompt: String) -> Dictionary:
	var agent_service = _resolve_agent_service()
	if agent_service == null or not agent_service.has_method("send_user_message_stream"):
		print("HermesChat: send_user_message_stream unavailable")
		return {"available": false, "ok": false}
	print("HermesChat: calling send_user_message_stream")
	var value = agent_service.call("send_user_message_stream", prompt, {"source": "hermes_chat"})
	if value is Dictionary:
		var result: Dictionary = (value as Dictionary).duplicate(true)
		result["available"] = true
		return result
	return {"available": true, "ok": false, "terminal_result": "Hermes Gateway stream request failed", "error": {"code": "STREAM_RESULT_INVALID", "message": "Hermes Gateway stream request failed"}}

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
	_attach_streaming_events()
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

func _attach_streaming_events() -> void:
	var agent_service = _resolve_agent_service()
	if agent_service == null:
		return
	_agent_service = agent_service
	if agent_service.has_signal("stream_delta_received"):
		var delta_callable := Callable(self, "_on_stream_delta")
		if not agent_service.is_connected("stream_delta_received", delta_callable):
			agent_service.connect("stream_delta_received", delta_callable)
	if agent_service.has_signal("stream_completed"):
		var completed_callable := Callable(self, "_on_stream_completed")
		if not agent_service.is_connected("stream_completed", completed_callable):
			agent_service.connect("stream_completed", completed_callable)
	if agent_service.has_signal("stream_error"):
		var error_callable := Callable(self, "_on_stream_error")
		if not agent_service.is_connected("stream_error", error_callable):
			agent_service.connect("stream_error", error_callable)

func _detach_streaming_events() -> void:
	if _agent_service == null:
		return
	var delta_callable := Callable(self, "_on_stream_delta")
	if _agent_service.has_signal("stream_delta_received") and _agent_service.is_connected("stream_delta_received", delta_callable):
		_agent_service.disconnect("stream_delta_received", delta_callable)
	var completed_callable := Callable(self, "_on_stream_completed")
	if _agent_service.has_signal("stream_completed") and _agent_service.is_connected("stream_completed", completed_callable):
		_agent_service.disconnect("stream_completed", completed_callable)
	var error_callable := Callable(self, "_on_stream_error")
	if _agent_service.has_signal("stream_error") and _agent_service.is_connected("stream_error", error_callable):
		_agent_service.disconnect("stream_error", error_callable)
	_agent_service = null

func app_unmounted() -> void:
	if _event_bus != null and _event_bus.has_method("unsubscribe"):
		_event_bus.unsubscribe(OSEventBus.AGENT_RESPONSE_RECEIVED, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_ERROR, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_STATUS_CHANGED, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_OPERATION_REQUESTED, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_OPERATION_COMPLETED, self, "_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_OPERATION_FAILED, self, "_on_agent_event")
	_event_bus = null
	_detach_streaming_events()
	super.app_unmounted()

func _on_agent_event(event_name: StringName, payload: Dictionary) -> void:
	if state == null:
		return
	match event_name:
		OSEventBus.AGENT_RESPONSE_RECEIVED:
			if not state.get_bool("is_sending", false) and not state.get_bool("is_streaming", false):
				return
			var assistant_text: String = _clean_user_facing_text(str(payload.get("assistant_text", "")).strip_edges())
			var response_text: String = assistant_text if assistant_text != "" else "(no output)"
			state.set_many({
				"is_sending": false,
				"is_streaming": false,
				"streaming_text": "",
				"streaming_status": "",
				"can_send": state.get_string("draft", "").strip_edges() != "",
				"has_messages": true,
				"has_gateway_message": true,
				"last_gateway_message": response_text,
				"has_action_status": true,
				"action_status": "Hermes reported a result",
				"action_status_detail": _compact_status_detail(response_text)
			})
			_set_gateway_state(_gateway_status_state())
		OSEventBus.AGENT_ERROR:
			if not state.get_bool("is_sending", false) and not state.get_bool("is_streaming", false):
				return
			var error_text: String = _clean_user_facing_text(str(payload.get("message", "Hermes Gateway error")))
			state.set_many({
				"is_sending": false,
				"is_streaming": false,
				"streaming_text": "",
				"streaming_status": "",
				"can_send": state.get_string("draft", "").strip_edges() != "",
				"has_messages": true,
				"has_gateway_message": true,
				"last_gateway_message": error_text,
				"has_action_status": true,
				"action_status": "Hermes_OS action blocked",
				"action_status_detail": error_text
			})
			_set_gateway_state({"label": "Gateway: Offline", "variant": "danger"})
		OSEventBus.AGENT_STATUS_CHANGED:
			if not state.get_bool("is_sending", false) and not state.get_bool("is_streaming", false):
				_set_gateway_state(_gateway_status_state())
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

func _on_stream_delta(payload: Dictionary) -> void:
	print("HermesChat: stream_delta_received")
	if state == null:
		return
	var partial: String = str(payload.get("assistant_text_partial", ""))
	if partial == "":
		return
	var accumulated: String = state.get_string("streaming_text", "") + partial
	state.set_many({
		"is_streaming": true,
		"is_sending": true,
		"streaming_text": accumulated,
		"streaming_status": "Hermes is responding…",
		"has_messages": true,
		"has_gateway_message": true,
		"last_gateway_message": accumulated,
		"has_action_status": true,
		"action_status": "Hermes is responding…",
		"action_status_detail": "Receiving live response chunks from Hermes Gateway."
	})
	_set_gateway_state({"label": "Gateway: Streaming", "variant": "warning"})

func _on_stream_completed(payload: Dictionary) -> void:
	if state == null:
		return
	var assistant_text: String = _clean_user_facing_text(str(payload.get("assistant_text", "")).strip_edges())
	if assistant_text == "":
		assistant_text = state.get_string("streaming_text", "").strip_edges()
	if assistant_text == "":
		assistant_text = "(no output)"
	state.set_many({
		"is_streaming": false,
		"is_sending": false,
		"streaming_text": "",
		"streaming_status": "",
		"can_send": state.get_string("draft", "").strip_edges() != "",
		"has_messages": true,
		"has_gateway_message": true,
		"last_gateway_message": assistant_text,
		"has_action_status": true,
		"action_status": "Hermes reported a result",
		"action_status_detail": _compact_status_detail(assistant_text)
	})
	_set_gateway_state(_gateway_status_state())

func _on_stream_error(payload: Dictionary) -> void:
	if state == null:
		return
	var error_text: String = _clean_user_facing_text(str(payload.get("message", payload.get("error", "Hermes Gateway stream error"))))
	if error_text == "":
		error_text = "Hermes Gateway stream error"
	state.set_many({
		"is_streaming": false,
		"is_sending": false,
		"streaming_text": "",
		"streaming_status": "",
		"can_send": state.get_string("draft", "").strip_edges() != "",
		"has_messages": true,
		"has_gateway_message": true,
		"last_gateway_message": error_text,
		"has_action_status": true,
		"action_status": "Hermes_OS action blocked",
		"action_status_detail": error_text
	})
	_set_gateway_state({"label": "Gateway: Offline", "variant": "danger"})

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

func _set_gateway_state(value: Dictionary) -> void:
	if state == null:
		return
	var next: Dictionary = value.duplicate(true)
	state.set("gateway", next)
	state.set("gateway_display_label", str(next.get("label", "Gateway: Offline")))
	var gateway_status: Dictionary = _agent_gateway_status()
	var model: String = _display_model_id(str(gateway_status.get("model", state.get_string("current_model", ""))).strip_edges())
	state.set("current_model", model)
	state.set("model_options", _model_options(model))
	state.set("model_label", "Model: " + model)
	var profile: String = _gateway_profile_from_status(gateway_status)
	state.set("current_profile", profile)
	state.set("profile_draft", profile)
	state.set("profile_label", "Profile: " + profile)
	if ui != null:
		_configure_model_selector()
		ui.set_value("model-selector", model)
		ui.set_value("profile-input", profile)

func _display_model_id(model_id: String) -> String:
	var clean: String = model_id.strip_edges()
	if clean == "" or clean == "hermesos":
		return "Gateway default"
	return clean

func _model_options(current_model: String = "") -> Array[String]:
	var options: Array[String] = ["gpt-5.5", "gpt-5.4", "gpt-5.4-mini", "gpt-5.3-codex-spark"]
	var clean: String = current_model.strip_edges()
	if clean != "" and clean != "hermesos" and clean != "Gateway default" and not options.has(clean):
		options.insert(0, clean)
	return options

func _gateway_profile_from_status(status: Dictionary) -> String:
	var profile: String = str(status.get("profile_hint", "")).strip_edges()
	if profile == "":
		profile = "hermesos"
	return profile

func _configure_profile_input() -> void:
	if state == null or ui == null:
		return
	ui.set_value("profile-input", state.get_string("profile_draft", state.get_string("current_profile", "")))

func _configure_model_selector() -> void:
	if state == null or ui == null:
		return
	var control: Control = ui.by_id("model-selector")
	if not (control is OptionButton):
		return
	var dropdown := control as OptionButton
	dropdown.clear()
	var options = state.get_value("model_options", [])
	if not (options is Array):
		options = []
	for option in options:
		var model_id: String = str(option).strip_edges()
		if model_id == "":
			continue
		dropdown.add_item(model_id)
		var idx: int = dropdown.item_count - 1
		dropdown.set_item_metadata(idx, model_id)
	ui.set_value("model-selector", state.get_string("current_model", ""))

func _event_model_id(event) -> String:
	if event == null:
		return ""
	if event is Dictionary:
		for key in ["value", "model", "model_id", "id"]:
			if (event as Dictionary).has(key):
				return str((event as Dictionary).get(key, "")).strip_edges()
	if event is HermesEvent:
		return str((event as HermesEvent).value).strip_edges()
	return str(event).strip_edges()

func _event_profile_id(event) -> String:
	if event == null:
		return ""
	if event is Dictionary:
		for key in ["value", "profile", "profile_hint", "profile_id", "id"]:
			if (event as Dictionary).has(key):
				return str((event as Dictionary).get(key, "")).strip_edges()
	if event is HermesEvent:
		return str((event as HermesEvent).value).strip_edges()
	return str(event).strip_edges()

func _model_switch_error_text(result: Dictionary) -> String:
	var error_value = result.get("error", "Model switch failed")
	if error_value is Dictionary:
		return str((error_value as Dictionary).get("message", "Model switch failed")).strip_edges()
	return str(error_value).strip_edges()

func _resolve_agent_service():
	if os != null:
		if os.context is Dictionary:
			var context_service = os.context.get("agent_service", null)
			if context_service != null:
				return context_service
		if os.has_method("hermes_agent_service"):
			return os.call("hermes_agent_service")
	return null

func _agent_gateway_status() -> Dictionary:
	var agent_service = _resolve_agent_service()
	if agent_service != null and agent_service.has_method("get_status"):
		var value = agent_service.call("get_status")
		if value is Dictionary:
			var gateway_value = (value as Dictionary).get("gateway", {})
			if gateway_value is Dictionary:
				return (gateway_value as Dictionary).duplicate(true)
	return {"configured": false, "busy": false, "model": "", "profile_hint": "hermesos"}

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
