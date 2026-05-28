class_name HermesChatApp
extends "res://scripts/ui/hermes_ui/hermes_app.gd"

const OSEventBus = preload("res://scripts/os/core/os_event_bus.gd")
const HermesRefs = preload("res://scripts/ui/hermes_ui/hermes_refs.gd")

var _shell: Node
var _event_bus: OSEventBus
var _agent_service: Object
var _messages: Array[Dictionary] = []
var _awaiting_response: bool = false

var _toolbar: Control
var _message_panel: Control
var _message_scroll: ScrollContainer
var _message_column: VBoxContainer
var _composer_input: LineEdit
var _send_button: Button
var _clear_button: Button
var _gateway_badge: Control
var _mcp_badge: Control

func setup(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_event_bus = context.get("event_bus", null) as OSEventBus
	if _event_bus == null and _shell != null:
		var bus_value: Variant = _shell.get("_event_bus")
		if bus_value is OSEventBus:
			_event_bus = bus_value as OSEventBus
	_agent_service = context.get("agent_service", null)
	if _agent_service == null and _shell != null:
		_agent_service = _shell.get("_hermes_agent_service")
	if _event_bus != null:
		_event_bus.subscribe(OSEventBus.AGENT_STATUS_CHANGED, self, &"_on_agent_event")
		_event_bus.subscribe(OSEventBus.AGENT_RESPONSE_RECEIVED, self, &"_on_agent_event")
		_event_bus.subscribe(OSEventBus.AGENT_ERROR, self, &"_on_agent_event")

func _exit_tree() -> void:
	if _event_bus != null:
		_event_bus.unsubscribe(OSEventBus.AGENT_STATUS_CHANGED, self, &"_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_RESPONSE_RECEIVED, self, &"_on_agent_event")
		_event_bus.unsubscribe(OSEventBus.AGENT_ERROR, self, &"_on_agent_event")

func render() -> void:
	_toolbar = _build_toolbar()
	_message_panel = _build_message_panel()
	var composer := _build_composer()
	var status_bar: Control = ui.status_bar("", "info", {"name": "HermesChatStatusBar"})
	set_status_control(status_bar)
	set_root(layout.chat_app(_toolbar, _message_panel, composer, status_bar))
	_render_messages()
	_refresh_gateway_status()

func on_focus() -> void:
	if _composer_input != null:
		_composer_input.grab_focus()

func get_state() -> Dictionary:
	return {
		"messages": _messages.duplicate(true),
		"draft": _composer_input.text if _composer_input != null else "",
		"awaiting_response": _awaiting_response
	}

func restore_state(state: Dictionary) -> void:
	_messages.clear()
	var saved_messages: Variant = state.get("messages", [])
	if saved_messages is Array:
		for item in saved_messages:
			if item is Dictionary:
				_messages.append((item as Dictionary).duplicate(true))
	if _composer_input != null:
		_composer_input.text = str(state.get("draft", ""))
	_awaiting_response = bool(state.get("awaiting_response", false))
	_render_messages()
	_refresh_gateway_status()

func get_mcp_actions() -> Array:
	return [
		{
			"id": "chat.send",
			"label": "Send chat message",
			"description": "Send a message to Hermes Chat",
			"args_schema": {"message": "string"}
		},
		{
			"id": "chat.clear",
			"label": "Clear chat",
			"description": "Clear Hermes Chat history",
			"args_schema": {}
		}
	]

func handle_mcp_action(action: String, args: Dictionary) -> Dictionary:
	match action:
		"chat.send":
			var message := str(args.get("message", "")).strip_edges()
			if message == "":
				return {"ok": false, "error": "Missing message"}
			_send_message(message)
			return {"ok": true}
		"chat.clear":
			_clear_messages()
			return {"ok": true}
		_:
			return {"ok": false, "error": "Unsupported action"}

func _build_toolbar() -> Control:
	var title: Control = ui.label("Hermes Chat", "heading", {"name": "HermesChatTitle"})
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gateway_badge = ui.badge("Gateway: unknown", "muted", {"name": "HermesChatGatewayBadge"})
	_mcp_badge = ui.badge("MCP: ready", "info", {"name": "HermesChatMcpBadge"})
	return ui.toolbar([title, filler, _gateway_badge, _mcp_badge], {"name": "HermesChatToolbar"})

func _build_message_panel() -> Control:
	_message_scroll = ui.list([], "", Callable(), {
		"name": "HermesChatMessageScroll",
		"empty_text": "Ask Hermes to help with this OS."
	}) as ScrollContainer
	_message_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rows := _find_list_rows(_message_scroll)
	if rows != null:
		_message_column = rows
		_message_column.name = "HermesChatMessageColumn"
		_message_column.add_theme_constant_override("separation", hermes_theme.spacing("space_3"))
	else:
		_message_column = ui.vbox([], hermes_theme.spacing("space_3"), {"name": "HermesChatMessageColumn", "expand_h": true})
		_message_scroll.add_child(_message_column)
	return ui.panel([_message_scroll], hermes_theme.spacing("panel"), "base", {"name": "HermesChatMessagePanel", "expand_v": true})

func _build_composer() -> Control:
	_composer_input = ui.input("", "Ask Hermes to help with this OS.", Callable(), Callable(self, "_on_input_submitted"), {
		"name": "HermesChatComposerInput",
		"ref": HermesRefs.make_ref("hermes_chat", "composer"),
		"expand_h": true,
		"mcp_role": "textbox",
		"mcp_actions": ["type", "submit"]
	})
	_send_button = ui.button("Send", Callable(self, "_send_from_input"), "primary", false, {
		"name": "HermesChatSendButton",
		"ref": HermesRefs.make_ref("hermes_chat", "send"),
		"mcp_actions": ["press"]
	})
	_clear_button = ui.button("Clear", Callable(self, "_clear_messages"), "ghost", false, {
		"name": "HermesChatClearButton",
		"ref": HermesRefs.make_ref("hermes_chat", "clear"),
		"mcp_actions": ["press"]
	})
	var row: Control = ui.hbox([_composer_input, _send_button, _clear_button], hermes_theme.spacing("space_2"), {"name": "HermesChatComposerRow"})
	return ui.card([row], hermes_theme.spacing("card"), {"name": "HermesChatComposerCard"})

func _send_from_input() -> void:
	if _composer_input == null:
		return
	_send_message(_composer_input.text)

func _on_input_submitted(_text: String) -> void:
	_send_from_input()

func _send_message(message: String) -> void:
	var clean := message.strip_edges()
	if clean == "":
		set_status("Enter a message first.", "warning")
		return
	if _awaiting_response:
		set_status("Hermes is still responding.", "busy")
		return
	if _agent_service == null or not (_agent_service is Object) or not (_agent_service as Object).has_method("send_user_message"):
		_append_message("System", "Hermes Gateway client is unavailable in this app context.", "error")
		set_status("Gateway unavailable.", "error")
		return
	_append_message("You", clean, "user")
	_awaiting_response = true
	_set_composer_enabled(false)
	set_status("Sending to Hermes Gateway…", "busy")
	if _composer_input != null:
		_composer_input.text = ""
	var result: Variant = (_agent_service as Object).call("send_user_message", clean, {"source": "hermes_chat"})
	if result is Dictionary and not bool((result as Dictionary).get("ok", false)):
		var terminal_result := str((result as Dictionary).get("terminal_result", "Hermes Gateway request failed"))
		_append_message("System", terminal_result, "error")
		_awaiting_response = false
		_set_composer_enabled(true)
		set_status(terminal_result, "error")
	_refresh_gateway_status()

func _clear_messages() -> void:
	_messages.clear()
	_render_messages()
	set_status("Chat cleared.", "info")

func _append_message(sender: String, text: String, kind: String) -> void:
	_messages.append({"sender": sender, "text": text, "kind": kind})
	_render_messages()

func _render_messages() -> void:
	if _message_column == null:
		return
	for child in _message_column.get_children():
		child.queue_free()
	if _messages.is_empty():
		_message_column.add_child(ui.label("Ask Hermes to help with this OS.", "muted", {"name": "HermesChatEmpty", "autowrap": true}))
	else:
		for item in _messages:
			var message := item as Dictionary
			_message_column.add_child(ui.message_item(str(message.get("sender", "")), str(message.get("text", "")), str(message.get("kind", "hermes")), {"name": "HermesChatMessage"}))
	call_deferred("_scroll_messages_to_bottom")

func _scroll_messages_to_bottom() -> void:
	if _message_scroll == null:
		return
	_message_scroll.scroll_vertical = 1000000

func _find_list_rows(list_scroll: ScrollContainer) -> VBoxContainer:
	if list_scroll == null:
		return null
	var rows := list_scroll.find_child("HermesListRows", true, false)
	if rows != null and rows is VBoxContainer:
		return rows as VBoxContainer
	return null

func _refresh_gateway_status() -> void:
	var gateway_state := _gateway_state()
	var configured := bool(gateway_state.get("configured", false))
	var busy := bool(gateway_state.get("busy", false))
	var gateway_kind := "success" if configured else "danger"
	if busy:
		gateway_kind = "busy"
	var endpoint := str(gateway_state.get("endpoint", ""))
	var model := str(gateway_state.get("model", ""))
	var key_present := bool(gateway_state.get("api_key_present", false))
	_update_badge(_gateway_badge, "Gateway: " + ("busy" if busy else "ready" if configured else "offline"), gateway_kind)
	_update_badge(_mcp_badge, "MCP: placeholder", "muted")
	set_status("endpoint=%s | model=%s | key=%s" % [endpoint if endpoint != "" else "n/a", model if model != "" else "n/a", "yes" if key_present else "no"], "info")

func _update_badge(control: Control, text: String, kind: String) -> void:
	if control == null:
		return
	if control is PanelContainer:
		(control as PanelContainer).add_theme_stylebox_override("panel", hermes_theme.badge_style(kind))
	var label_node := control.find_child("HermesBadgeLabel", true, false)
	if label_node != null and label_node is Label:
		(label_node as Label).text = text
		(label_node as Label).add_theme_color_override("font_color", hermes_theme.color("text"))

func _gateway_state() -> Dictionary:
	if _agent_service != null and (_agent_service is Object) and (_agent_service as Object).has_method("get_status"):
		var state: Variant = (_agent_service as Object).call("get_status")
		if state is Dictionary:
			var gateway: Variant = (state as Dictionary).get("gateway", {})
			if gateway is Dictionary:
				return (gateway as Dictionary).duplicate(true)
	return {
		"configured": false,
		"busy": false,
		"endpoint": "",
		"model": "",
		"api_key_present": false
	}

func _set_composer_enabled(enabled: bool) -> void:
	if _composer_input != null:
		_composer_input.editable = enabled
	if _send_button != null:
		_send_button.disabled = not enabled

func _on_agent_event(event_name: StringName, payload: Dictionary) -> void:
	match String(event_name):
		"agent.status_changed":
			_refresh_gateway_status()
		"agent.response_received":
			if _awaiting_response:
				var assistant_text := str(payload.get("assistant_text", "")).strip_edges()
				_append_message("Hermes", assistant_text if assistant_text != "" else "(no output)", "hermes")
				_awaiting_response = false
				_set_composer_enabled(true)
				set_status("Response received.", "success")
				_refresh_gateway_status()
		"agent.error":
			if _awaiting_response:
				_append_message("System", str(payload.get("message", "Hermes Gateway error")), "error")
				_awaiting_response = false
				_set_composer_enabled(true)
				set_status(str(payload.get("message", "Hermes Gateway error")), "error")
				_refresh_gateway_status()
