class_name SystemSettingsApp
extends "res://scripts/ui/hermes_ui/hermes_app.gd"

const OSFileSystem = preload("res://scripts/os/os_file_system.gd")

var _shell: Node
var _fs: Object

var _tab_host: VBoxContainer
var _sidebar_list: ScrollContainer
var _tabs_row: Control
var _system_page: Control
var _appearance_page: Control
var _active_tab_id: String = "system"

var _info_label: Label
var _gateway_status_label: Label
var _gateway_status_badge: Control
var _toolbar_mcp_badge: Control
var _gateway_model_value: Label
var _gateway_source_value: Label
var _mcp_status_label: Label
var _mcp_endpoint_value: Label
var _mcp_tools_value: Label
var _alpha_value_label: Label
var _theme_dropdown: OptionButton
var _preset_dropdown: OptionButton
var _alpha_slider: HSlider

func setup(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	if _fs == null and _shell != null:
		_fs = _shell._fs

func render() -> void:
	if _shell == null:
		return
	var toolbar: Control = _build_toolbar()
	var sidebar: Control = _build_sidebar()
	var content: Control = _build_content_area()
	var status_bar: Control = ui.status_bar("System settings ready.", "info", {"name": "SystemSettingsStatusBar"})
	set_status_control(status_bar)
	var root: Control = layout.sidebar_app(toolbar, sidebar, content, status_bar, {"sidebar_width": 220})
	root.name = "SystemSettingsRoot"
	root.custom_minimum_size = Vector2(780, 500)
	root.set_meta("window_min_size", Vector2(700, 440))
	set_root(root)
	_refresh_sidebar_nav()

func on_close_requested() -> bool:
	return true

func get_state() -> Dictionary:
	if _shell == null:
		return {}
	return {
		"theme_mode": _shell._theme_mode,
		"wallpaper_index": _shell._wallpaper_index,
		"desktop_highlight_color": [_shell._desktop_highlight_color.r, _shell._desktop_highlight_color.g, _shell._desktop_highlight_color.b, _shell._desktop_highlight_color.a],
		"gateway": _gateway_state(),
		"mcp": _mcp_state(),
		"active_tab": _active_tab_id
	}

func restore_state(state: Dictionary) -> void:
	_active_tab_id = str(state.get("active_tab", _active_tab_id))
	if _active_tab_id != "appearance" and _active_tab_id != "system":
		_active_tab_id = "system"
	_refresh_sidebar_nav()

func _build_sidebar() -> Control:
	var items: Array = [
		{"id": "system", "text": "System"},
		{"id": "appearance", "text": "Appearance"}
	]
	_sidebar_list = ui.list_view(items, {"name": "SystemSettingsSidebarList", "selected_id": _active_tab_id, "on_select": Callable(self, "_on_sidebar_select"), "expand_h": true, "expand_v": true})
	return ui.sidebar([_sidebar_list], 220, {"name": "SystemSettingsSidebar"})

func _on_sidebar_select(item_id: String) -> void:
	if item_id != "system" and item_id != "appearance":
		return
	_active_tab_id = item_id
	_refresh_sidebar_nav()

func _refresh_sidebar_nav() -> void:
	if _sidebar_list != null and is_instance_valid(_sidebar_list):
		ui.set_selected_id(_sidebar_list, _active_tab_id)
	if _system_page != null:
		_system_page.visible = _active_tab_id == "system"
	if _appearance_page != null:
		_appearance_page.visible = _active_tab_id == "appearance"
	_refresh_system_info()
	_refresh_gateway_mcp_status()

func _build_toolbar() -> Control:
	var title: Control = ui.label("System Settings", {"variant": "heading", "name": "SystemSettingsTitle"})
	var subtitle: Control = ui.label("System diagnostics, Hermes Gateway, and MCP controls", {"variant": "muted", "name": "SystemSettingsSubtitle"})
	var title_block: Control = ui.vbox([title, subtitle], hermes_theme.spacing("space_1"), {"expand_h": true})
	_gateway_status_badge = ui.badge("Gateway: Checking", {"kind": "checking", "name": "SystemSettingsToolbarGatewayStatusLabel"})
	_toolbar_mcp_badge = ui.badge("MCP: Checking", {"kind": "checking", "name": "SystemSettingsToolbarMcpStatusLabel"})
	var status_cluster: Control = ui.hbox([_gateway_status_badge, _toolbar_mcp_badge], hermes_theme.spacing("space_3"), {"name": "SystemSettingsToolbarStatusCluster"})
	return ui.toolbar([title_block, status_cluster], {"name": "SystemSettingsToolbar"})

func _build_content_area() -> Control:
	var pages: VBoxContainer = ui.vbox([], hermes_theme.spacing("space_3"), {"name": "SystemSettingsPages", "expand_h": true, "expand_v": true})
	_system_page = _build_system_page()
	_appearance_page = _build_appearance_page()
	pages.add_child(_system_page)
	pages.add_child(_appearance_page)
	# Wrap in scroll for long pages
	return ui.scroll_container(pages, {"name": "SystemSettingsContentScroll", "expand_h": true, "expand_v": true})

func _refresh_tabs() -> void:
	if _tab_host == null:
		return
	if _tabs_row != null and is_instance_valid(_tabs_row):
		_tabs_row.queue_free()
	_tabs_row = ui.tabs([
		{"id": "system", "text": "System"},
		{"id": "appearance", "text": "Appearance"}
	], {"active_id": _active_tab_id, "on_change": Callable(self, "_on_tab_selected"), "name": "SystemSettingsTabs"})
	_tabs_row.name = "SystemSettingsTabs"
	_tab_host.add_child(_tabs_row)
	if _system_page != null:
		_system_page.visible = _active_tab_id == "system"
	if _appearance_page != null:
		_appearance_page.visible = _active_tab_id == "appearance"

func _on_tab_selected(tab_id: String) -> void:
	if tab_id != "system" and tab_id != "appearance":
		return
	_active_tab_id = tab_id
	_refresh_tabs()

func _build_system_page() -> Control:
	var page: Control = ui.vbox([], hermes_theme.spacing("space_3"), {"name": "SystemSettingsSystemPage", "expand_h": true, "expand_v": true})

	# Overview card with system info
	var info_title: Control = ui.label("System Overview", {"variant": "heading"})
	_info_label = ui.label("", {"variant": "body", "name": "SystemSettingsInfoLabel", "expand_h": true})
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var info_scroll: Control = ui.scroll_container(_info_label, {"name": "SystemSettingsInfoScroll", "expand_h": true, "expand_v": true, "min_size": Vector2(0, 100)})
	page.add_child(ui.card([info_title, info_scroll], hermes_theme.spacing("card"), {"name": "SystemSettingsInfoCard", "expand_h": true}))

	# Gateway card: primary architecture, polished
	var gateway_card: Control = ui.card([], hermes_theme.spacing("card"), {"name": "SystemSettingsGatewayPanel", "expand_h": true})
	ui.add_many(gateway_card, [
		ui.section_header("Hermes Gateway", "Primary chat and Terminal transport via Docker gateway"),
		_build_gateway_status_row(),
		ui.settings_row("Model", ui.label("Unknown", {"variant": "body", "name": "SystemSettingsGatewayModel", "expand_h": true}), {"expand_h": true}),
		ui.settings_row("Source", ui.label("runtime/hermes_gateway/compose.env", {"variant": "muted", "name": "SystemSettingsGatewaySource", "expand_h": true}), {"expand_h": true}),
		ui.flow_row([
			ui.button("Test Gateway", {"variant": "primary", "on_pressed": Callable(self, "_test_gateway"), "name": "SystemSettingsGatewayTest", "height": 30}),
			ui.button("Reload Config", {"variant": "secondary", "on_pressed": Callable(self, "_reload_gateway_config"), "name": "SystemSettingsGatewayReload", "height": 30})
		], {"name": "SystemSettingsGatewayButtons", "expand_h": true})
	])
	page.add_child(gateway_card)
	_gateway_model_value = gateway_card.find_child("SystemSettingsGatewayModel", true, false) as Label
	_gateway_source_value = gateway_card.find_child("SystemSettingsGatewaySource", true, false) as Label

	# MCP card: primary architecture
	var mcp_card: Control = ui.card([], hermes_theme.spacing("card"), {"name": "SystemSettingsMcpPanel", "expand_h": true})
	ui.add_many(mcp_card, [
		ui.section_header("Hermes_OS MCP", "Godot endpoint for OS tools and UI interaction"),
		_build_mcp_status_row(),
		ui.settings_row("Endpoint", ui.label("127.0.0.1:9090", {"variant": "body", "name": "SystemSettingsMcpEndpoint", "expand_h": true}), {"expand_h": true}),
		ui.settings_row("Tools", ui.label("ping, observe, ui tree, click, filesystem", {"variant": "muted", "name": "SystemSettingsMcpTools", "expand_h": true}), {"expand_h": true}),
		ui.flow_row([
			ui.button("Test MCP", {"variant": "secondary", "on_pressed": Callable(self, "_test_mcp"), "name": "SystemSettingsMcpTest", "height": 30})
		], {"name": "SystemSettingsMcpButtons", "expand_h": true})
	])
	page.add_child(mcp_card)
	_mcp_endpoint_value = mcp_card.find_child("SystemSettingsMcpEndpoint", true, false) as Label
	_mcp_tools_value = mcp_card.find_child("SystemSettingsMcpTools", true, false) as Label

	return page

func _build_gateway_status_row() -> Control:
	_gateway_status_label = ui.label("Gateway: Checking", {"variant": "status", "name": "SystemSettingsGatewayStatus", "expand_h": true})
	return ui.hbox([_gateway_status_label], hermes_theme.spacing("space_2"), {"expand_h": true})

func _build_mcp_status_row() -> Control:
	_mcp_status_label = ui.label("MCP: Checking", {"variant": "status", "name": "SystemSettingsMcpStatus", "expand_h": true})
	return ui.hbox([_mcp_status_label], hermes_theme.spacing("space_2"), {"expand_h": true})

func _build_appearance_page() -> Control:
	var page: Control = ui.vbox([], hermes_theme.spacing("space_3"), {"name": "SystemSettingsAppearancePage", "expand_h": true, "expand_v": true})
	var appearance_card: Control = ui.card([], hermes_theme.spacing("card"), {"name": "SystemSettingsAppearanceCard", "min_size": Vector2(430, 0)})
	_theme_dropdown = ui.dropdown([
		{"id": "dark", "text": "Dark"},
		{"id": "light", "text": "Light"}
	], {"name": "SystemSettingsThemeMode", "selected_id": _shell._theme_mode, "on_change": Callable(self, "_on_theme_mode_changed")})
	var presets := _desktop_highlight_presets()
	_preset_dropdown = ui.dropdown(presets.map(func(item: Dictionary) -> Dictionary:
		return {"id": str(item.get("label", "Color")), "text": str(item.get("label", "Color"))}
	), {"name": "SystemSettingsHighlightPreset", "on_change": Callable(self, "_on_highlight_preset_changed")})
	_alpha_slider = ui.slider({"name": "SystemSettingsHighlightOpacity", "min": 0.14, "max": 0.7, "step": 0.01, "value": _shell._desktop_highlight_color.a, "on_change": Callable(self, "_on_highlight_alpha_changed")})
	_alpha_value_label = ui.label("%d%%" % int(round(_shell._desktop_highlight_color.a * 100.0)), {"variant": "status", "name": "SystemSettingsAlphaValue", "min_size": Vector2(44, 0)})
	var opacity_row: Control = ui.hbox([_alpha_slider, _alpha_value_label], hermes_theme.spacing("space_2"), {"expand_h": true})
	var actions_row: Control = ui.flow_row([
		ui.button("Cycle wallpaper", {"variant": "secondary", "on_pressed": Callable(self, "_on_cycle_wallpaper_pressed"), "name": "SystemSettingsCycleWallpaper", "width": 132, "height": 30}),
		ui.button("Reset icon layout", {"variant": "secondary", "on_pressed": Callable(self, "_on_reset_layout_pressed"), "name": "SystemSettingsResetIconLayout", "width": 132, "height": 30}),
		ui.button("Reset highlight", {"variant": "ghost", "on_pressed": Callable(self, "_on_reset_highlight_pressed"), "name": "SystemSettingsResetHighlight", "width": 120, "height": 30})
	], {"name": "SystemSettingsAppearanceActions", "expand_h": true})
	ui.add_many(appearance_card, [
		ui.section_header("Desktop appearance", "Theme, wallpaper, selection and drag highlight"),
		ui.form_group("Appearance", [
			ui.settings_row("Mode", _theme_dropdown, {"expand_h": true}),
			ui.settings_row("Highlight", _preset_dropdown, {"expand_h": true}),
			ui.settings_row("Opacity", opacity_row, {"expand_h": true})
		], {"name": "SystemSettingsAppearanceGroup"}),
		actions_row
	])
	var shell_row: Control = ui.hbox([Control.new(), appearance_card, Control.new()], hermes_theme.spacing("space_3"), {"expand_h": true, "expand_v": true})
	(shell_row.get_child(0) as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(shell_row.get_child(2) as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(shell_row)
	_select_current_preset()
	return page

func _refresh_gateway_mcp_status() -> void:
	var gateway_state: Dictionary = _gateway_state()
	var gateway_kind: String = _gateway_kind(gateway_state)
	var gateway_label: String = _gateway_label(gateway_kind)
	if _gateway_status_label != null:
		_gateway_status_label.text = "Gateway: " + gateway_label.capitalize()
		_gateway_status_label.add_theme_color_override("font_color", hermes_theme.color(_status_color_token(gateway_kind)))
	if _gateway_status_badge != null:
		_apply_badge_kind(_gateway_status_badge, "Gateway: " + gateway_label.capitalize(), gateway_kind)
	if _gateway_model_value != null:
		var display_model: String = _display_model_name(gateway_state)
		_gateway_model_value.text = display_model if display_model != "" else "Unknown"
	if _gateway_source_value != null:
		_gateway_source_value.text = _gateway_source_path(gateway_state)
	var mcp_state: Dictionary = _mcp_state()
	var mcp_kind: String = str(mcp_state.get("kind", "unavailable"))
	var mcp_label: String = str(mcp_state.get("label", "unavailable"))
	if _mcp_status_label != null:
		_mcp_status_label.text = "MCP: " + mcp_label.capitalize()
		_mcp_status_label.add_theme_color_override("font_color", hermes_theme.color(_status_color_token(mcp_kind)))
	if _toolbar_mcp_badge != null:
		_apply_badge_kind(_toolbar_mcp_badge, "MCP: " + mcp_label.capitalize(), mcp_kind)
	if _mcp_endpoint_value != null:
		_mcp_endpoint_value.text = str(mcp_state.get("endpoint", "127.0.0.1:9090"))
	if _mcp_tools_value != null:
		_mcp_tools_value.text = "ping, observe, ui tree, click, filesystem"
	_refresh_system_info()

func _test_gateway() -> void:
	set_status("Testing Hermes Gateway status…", "info")
	_refresh_gateway_mcp_status()

func _reload_gateway_config() -> void:
	if _shell == null or _shell._hermes_agent_service == null:
		set_status("Hermes agent service unavailable", "error")
		return
	if not _shell.has_method("_hermes_gateway_config"):
		set_status("Gateway config loader unavailable", "error")
		return
	var config: Dictionary = _shell.call("_hermes_gateway_config") as Dictionary
	var service: Object = _shell._hermes_agent_service
	var gateway_client: Variant = service.get("_gateway_client") if service != null else null
	if gateway_client == null or not gateway_client.has_method("configure"):
		set_status("Gateway client unavailable", "error")
		return
	gateway_client.call("configure", config)
	set_status("Gateway config reloaded", "info")
	_refresh_gateway_mcp_status()

func _test_mcp() -> void:
	set_status("Testing MCP endpoint…", "info")
	var state: Dictionary = {"kind": "checking", "label": "checking", "endpoint": "127.0.0.1:9090", "ok": false}
	var peer := StreamPeerTCP.new()
	var err: int = peer.connect_to_host("127.0.0.1", 9090)
	if err != OK:
		state["kind"] = "unavailable"
		state["label"] = "unavailable"
		state["error"] = "connect_failed"
		set_status("MCP endpoint unavailable", "error")
	else:
		state["kind"] = "available"
		state["label"] = "available"
		state["ok"] = true
		peer.put_data((JSON.stringify({"command": "get_ui_elements", "params": {}}) + "\n").to_utf8_buffer())
		var started_msec: int = Time.get_ticks_msec()
		var has_response: bool = false
		while Time.get_ticks_msec() - started_msec < 450:
			peer.poll()
			if peer.get_available_bytes() > 0:
				has_response = true
				break
			OS.delay_msec(10)
		state["response_seen"] = has_response
		set_status("MCP endpoint reachable" if has_response else "MCP endpoint reachable (no response yet)", "info")
		peer.disconnect_from_host()
	set_meta("last_mcp_state", state)
	_refresh_gateway_mcp_status()

func _refresh_system_info() -> void:
	if _info_label == null or _shell == null or _fs == null:
		return
	var viewport_size: Vector2 = _shell.get_viewport_rect().size if _shell != null else Vector2.ZERO
	var window_size: Vector2i = DisplayServer.window_get_size()
	var mode: int = DisplayServer.window_get_mode()
	var gateway: Dictionary = _gateway_state()
	var gateway_kind: String = _gateway_kind(gateway)
	var mcp_state: Dictionary = _mcp_state()
	_info_label.text = "Viewport: %s\nGame window: %s\nWindow mode: %s\nCurrent user: %s\nHome: %s\nUsers: %s\nFilesystem save: %s\nApps: %s\nOpen windows: %s\nGateway status: %s\nGateway endpoint: %s\nGateway model: %s\nMCP status: %s\nMCP endpoint: %s" % [
		str(viewport_size), str(window_size), str(mode), str(_fs.call("current_user")), str(_fs.call("home_path")), ", ".join(_fs.call("get_users")), OSFileSystem.SAVE_PATH, _app_ids_text(), _windows_text(), _gateway_label(gateway_kind), str(gateway.get("endpoint", "http://127.0.0.1:8643/v1/chat/completions")), (_display_model_name(gateway) if _display_model_name(gateway) != "" else "Unknown"), str(mcp_state.get("label", "unavailable")), str(mcp_state.get("endpoint", "127.0.0.1:9090"))
	]

func _on_theme_mode_changed(_index: int, selected_id: String) -> void:
	_apply_theme_mode(selected_id, true)
	_set_desktop_context_status("Light mode enabled" if _shell._theme_mode == "light" else "Dark mode enabled")
	_refresh_system_info()

func _on_highlight_preset_changed(_index: int, selected_label: String) -> void:
	for preset in _desktop_highlight_presets():
		if str(preset.get("label", "")) == selected_label:
			var color: Color = preset.get("color", _shell._desktop_highlight_color)
			_set_desktop_highlight_color(Color(color.r, color.g, color.b, _shell._desktop_highlight_color.a))
			_set_desktop_context_status("Desktop highlight color updated")
			_refresh_system_info()
			return

func _on_highlight_alpha_changed(value: float) -> void:
	_set_desktop_highlight_color(Color(_shell._desktop_highlight_color.r, _shell._desktop_highlight_color.g, _shell._desktop_highlight_color.b, value))
	if _alpha_value_label != null:
		_alpha_value_label.text = "%d%%" % int(round(value * 100.0))

func _on_cycle_wallpaper_pressed() -> void:
	_cycle_wallpaper()
	_refresh_system_info()

func _on_reset_layout_pressed() -> void:
	_shell._desktop_icon_positions.clear()
	_refresh_desktop_icons()
	_set_desktop_context_status("Desktop icon layout reset")

func _on_reset_highlight_pressed() -> void:
	_set_desktop_highlight_color(Color(0.34, 0.45, 0.62, 0.32))
	if _alpha_slider != null:
		_alpha_slider.value = _shell._desktop_highlight_color.a
	if _alpha_value_label != null:
		_alpha_value_label.text = "%d%%" % int(round(_shell._desktop_highlight_color.a * 100.0))
	_set_desktop_context_status("Desktop highlight color reset")
	_refresh_system_info()
	_select_current_preset()

func _select_current_preset() -> void:
	if _preset_dropdown == null:
		return
	var current := Color(_shell._desktop_highlight_color.r, _shell._desktop_highlight_color.g, _shell._desktop_highlight_color.b, 1.0)
	for i in _desktop_highlight_presets().size():
		var preset: Dictionary = _desktop_highlight_presets()[i]
		if (preset.get("color", Color.WHITE) as Color).is_equal_approx(current):
			_preset_dropdown.select(i)
			return

func _desktop_highlight_presets() -> Array[Dictionary]:
	return [
		{"label": "Ocean blue", "color": Color(0.34, 0.45, 0.62, 1.0)},
		{"label": "Mint green", "color": Color(0.35, 0.63, 0.46, 1.0)},
		{"label": "Amber", "color": Color(0.73, 0.53, 0.27, 1.0)},
		{"label": "Rose", "color": Color(0.71, 0.39, 0.54, 1.0)}
	]

func _gateway_state() -> Dictionary:
	var fallback: Dictionary = {
		"configured": true,
		"busy": false,
		"endpoint": "http://127.0.0.1:8643/v1/chat/completions",
		"host": "127.0.0.1",
		"port": 8643,
		"path": "/v1/chat/completions",
		"model": "",
		"profile_hint": "hermesos",
		"api_key_present": false,
		"last_error": {},
		"last_response": {}
	}
	if _shell == null:
		return fallback
	var service: Variant = _shell.get("_hermes_agent_service")
	if service != null and service.has_method("get_status"):
		var status: Variant = service.call("get_status")
		if status is Dictionary:
			var gateway: Variant = (status as Dictionary).get("gateway", {})
			if gateway is Dictionary:
				var snapshot: Dictionary = (gateway as Dictionary).duplicate(true)
				snapshot["source_path"] = _gateway_source_path(snapshot)
				if str(snapshot.get("endpoint", "")).strip_edges() == "":
					snapshot["endpoint"] = fallback["endpoint"]
				if str(snapshot.get("model", "")).strip_edges() == "":
					snapshot["model"] = fallback["model"]
				return snapshot
	return fallback

func _gateway_source_path(gateway_state: Dictionary) -> String:
	var direct: String = str(gateway_state.get("source_path", "")).strip_edges()
	if direct != "":
		return direct
	if _shell != null and _shell.has_method("_hermes_gateway_config"):
		var config: Variant = _shell.call("_hermes_gateway_config")
		if config is Dictionary:
			var path_text: String = str((config as Dictionary).get("gateway_config_path", "")).strip_edges()
			if path_text != "":
				if path_text.begins_with("res://"):
					return path_text.trim_prefix("res://")
				return path_text
	return "runtime/hermes_gateway/compose.env"

func _gateway_kind(gateway_state: Dictionary) -> String:
	if bool(gateway_state.get("busy", false)):
		return "busy"
	var last_error: Dictionary = gateway_state.get("last_error", {}) if gateway_state.get("last_error", {}) is Dictionary else {}
	var error_code: String = str(last_error.get("code", "")).strip_edges()
	if error_code == "GATEWAY_UNAUTHORIZED":
		return "warning"
	if error_code != "":
		return "danger"
	if bool(gateway_state.get("configured", false)):
		return "success" if bool(gateway_state.get("api_key_present", false)) else "warning"
	return "muted"

func _gateway_label(kind: String) -> String:
	match kind:
		"success": return "online"
		"warning": return "unauthorized"
		"danger": return "error"
		"busy": return "checking"
		_: return "offline"

func _display_model_name(gateway_state: Dictionary) -> String:
	var model_name: String = str(gateway_state.get("model", "")).strip_edges()
	if model_name.to_lower() == "hermesos":
		return ""
	return model_name

func _status_color_token(kind: String) -> String:
	match kind:
		"success": return "success"
		"warning": return "warning"
		"danger": return "danger"
		"busy": return "info"
		_: return "text_muted"

func _mcp_state() -> Dictionary:
	if has_meta("last_mcp_state"):
		var cached: Variant = get_meta("last_mcp_state")
		if cached is Dictionary:
			var snap: Dictionary = (cached as Dictionary).duplicate(true)
			if str(snap.get("endpoint", "")).strip_edges() == "":
				snap["endpoint"] = "127.0.0.1:9090"
			if str(snap.get("label", "")).strip_edges() == "":
				snap["label"] = "checking"
			if str(snap.get("kind", "")).strip_edges() == "":
				snap["kind"] = "checking"
			return snap
	return {"kind": "checking", "label": "checking", "endpoint": "127.0.0.1:9090", "ok": false}

func _apply_badge_kind(badge: Control, text: String, kind: String) -> void:
	if badge == null:
		return
	if badge is Label:
		var label := badge as Label
		label.text = text
		label.add_theme_color_override("font_color", hermes_theme.kind_text_color(kind))
		return
	if badge is PanelContainer:
		(badge as PanelContainer).add_theme_stylebox_override("panel", hermes_theme.badge_style(kind))
	var label_node: Variant = badge.find_child("HermesBadgeLabel", true, false)
	if label_node is Label:
		(label_node as Label).text = text
		(label_node as Label).add_theme_color_override("font_color", hermes_theme.kind_text_color(kind))

func _apply_theme_mode(mode: String, refresh_ui: bool = true) -> void:
	if _shell != null and _shell.has_method("_apply_theme_mode"):
		_shell.call("_apply_theme_mode", mode, refresh_ui)

func _cycle_wallpaper() -> void:
	if _shell != null and _shell.has_method("_cycle_wallpaper"):
		_shell.call("_cycle_wallpaper")

func _set_desktop_highlight_color(color: Color) -> void:
	if _shell != null and _shell.has_method("_set_desktop_highlight_color"):
		_shell.call("_set_desktop_highlight_color", color)

func _refresh_desktop_icons() -> void:
	if _shell != null and _shell.has_method("_refresh_desktop_icons"):
		_shell.call("_refresh_desktop_icons")

func _set_desktop_context_status(message: String, is_error: bool = false) -> void:
	if _shell != null and _shell.has_method("_set_desktop_context_status"):
		_shell.call("_set_desktop_context_status", message, is_error)

func _app_ids_text() -> String:
	if _shell != null and _shell.has_method("_app_ids_text"):
		return str(_shell.call("_app_ids_text"))
	return ""

func _windows_text() -> String:
	if _shell != null and _shell.has_method("_windows_text"):
		return str(_shell.call("_windows_text"))
	return "none"
