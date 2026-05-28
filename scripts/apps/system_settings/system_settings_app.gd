class_name SystemSettingsApp
extends Control

const OSFileSystem = preload("res://scripts/os/os_file_system.gd")
const HermesThemeScript = preload("res://scripts/ui/hermes_ui/hermes_theme.gd")
const HermesComponentFactoryScript = preload("res://scripts/ui/hermes_ui/hermes_component_factory.gd")
const HermesLayoutScript = preload("res://scripts/ui/hermes_ui/hermes_layout.gd")

var _shell: Node
var _fs: Object

var _hermes_theme = null
var _ui = null
var _layout = null

var _root: Control
var _content: VBoxContainer
var _tab_host: VBoxContainer
var _tabs_row: Control
var _status_bar: Control
var _status_label: Label

var _system_page: Control
var _appearance_page: Control
var _active_tab_id: String = "system"

var _info_label: Label
var _gateway_status_label: Label
var _gateway_status_badge: Control
var _gateway_status_pill: Control
var _gateway_endpoint_value: Label
var _gateway_model_value: Label
var _gateway_api_key_value: Label
var _gateway_source_value: Label
var _mcp_status_label: Label
var _mcp_status_pill: Control
var _mcp_endpoint_value: Label
var _mcp_tools_value: Label
var _alpha_value_label: Label

func os_app_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	if _fs == null and _shell != null:
		_fs = _shell._fs
	_setup_hermes_ui(context)
	_build()
	var initial_state: Dictionary = context.get("state", {}) if context.get("state", {}) is Dictionary else {}
	if not initial_state.is_empty():
		os_app_restore_state(initial_state)

func os_app_focus() -> void:
	pass

func os_app_blur() -> void:
	pass

func os_app_close_requested() -> bool:
	return true

func os_app_get_state() -> Dictionary:
	if _shell == null:
		return {}
	return {
		"theme_mode": _shell._theme_mode,
		"wallpaper_index": _shell._wallpaper_index,
		"desktop_highlight_color": [
			_shell._desktop_highlight_color.r,
			_shell._desktop_highlight_color.g,
			_shell._desktop_highlight_color.b,
			_shell._desktop_highlight_color.a
		],
		"gateway": _gateway_state(),
		"mcp": _mcp_state(),
		"active_tab": _active_tab_id
	}

func os_app_restore_state(state: Dictionary) -> void:
	_active_tab_id = str(state.get("active_tab", _active_tab_id))
	if _active_tab_id != "appearance":
		_active_tab_id = "system"
	_refresh_tabs()
	_refresh_system_info()
	_refresh_gateway_mcp_status()

func _exit_tree() -> void:
	pass

func _setup_hermes_ui(context: Dictionary) -> void:
	_hermes_theme = context.get("theme", null)
	if _hermes_theme == null:
		_hermes_theme = HermesThemeScript.new()
	_ui = context.get("ui", null)
	if _ui == null:
		_ui = HermesComponentFactoryScript.new(_hermes_theme)
	_layout = context.get("layout", null)
	if _layout == null:
		_layout = HermesLayoutScript.new(_hermes_theme, _ui)
	_hermes_theme.apply_to(self)

func _build() -> void:
	if _shell == null:
		return
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var toolbar := _build_toolbar()
	var content := _build_content()
	_status_bar = _ui.status_bar("System settings ready.", "info", {"name": "SystemSettingsStatusBar"})
	if _status_bar.has_meta("status_label"):
		var status_variant: Variant = _status_bar.get_meta("status_label")
		if status_variant is Label:
			_status_label = status_variant as Label

	_root = _layout.basic_app(toolbar, content, _status_bar)
	_root.name = "SystemSettingsRoot"
	_root.custom_minimum_size = Vector2(760, 460)
	_root.set_meta("window_min_size", Vector2(720, 420))
	add_child(_root)

	_refresh_tabs()
	_refresh_system_info()
	_refresh_gateway_mcp_status()

func _build_toolbar() -> Control:
	var title: Label = _ui.label("System Settings", "heading", {"name": "SystemSettingsTitle"})
	var subtitle: Label = _ui.label("System diagnostics, Hermes Gateway, and MCP controls", "muted", {"name": "SystemSettingsSubtitle"})
	var title_block: VBoxContainer = _ui.vbox([title, subtitle], _hermes_theme.spacing("space_1"), {"expand_h": true})
	_gateway_status_badge = _ui.badge("Gateway: checking", "busy", {"name": "SystemSettingsGatewayBadge"})
	return _ui.toolbar([title_block, _gateway_status_badge], {"name": "SystemSettingsToolbar"})

func _build_content() -> Control:
	_content = _ui.vbox([], _hermes_theme.spacing("space_3"), {
		"name": "SystemSettingsContent",
		"expand_h": true,
		"expand_v": true
	})

	_tab_host = VBoxContainer.new()
	_tab_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_host.size_flags_vertical = Control.SIZE_FILL
	_content.add_child(_tab_host)

	var pages := VBoxContainer.new()
	pages.name = "SystemSettingsPages"
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_theme_constant_override("separation", _hermes_theme.spacing("space_3"))
	_content.add_child(pages)

	_system_page = _build_system_page()
	_appearance_page = _build_appearance_page()
	pages.add_child(_system_page)
	pages.add_child(_appearance_page)
	return _content

func _refresh_tabs() -> void:
	if _tab_host == null:
		return
	if _tabs_row != null and is_instance_valid(_tabs_row):
		_tabs_row.queue_free()
	_tabs_row = _ui.tabs([
		{"id": "system", "text": "System"},
		{"id": "appearance", "text": "Appearance"}
	], _active_tab_id, Callable(self, "_on_tab_selected"), {"name": "SystemSettingsTabs"})
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
	var page: VBoxContainer = _ui.vbox([], _hermes_theme.spacing("space_3"), {
		"name": "SystemSettingsSystemPage",
		"expand_h": true,
		"expand_v": true
	})

	var info_title: Label = _ui.label("System diagnostics", "heading")
	var info_scroll := ScrollContainer.new()
	info_scroll.custom_minimum_size = Vector2(0, 118)
	info_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_label = _ui.label("", "body", {
		"name": "SystemSettingsInfoLabel",
		"autowrap": false,
		"expand_h": true
	})
	_info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_scroll.add_child(_info_label)
	var info_card: PanelContainer = _ui.card([info_title, info_scroll], _hermes_theme.spacing("card"), {
		"name": "SystemSettingsInfoCard",
		"expand_h": true,
		"expand_v": true
	})
	page.add_child(info_card)

	var gateway_card: PanelContainer = _ui.card([], _hermes_theme.spacing("card"), {
		"name": "SystemSettingsGatewayPanel",
		"expand_h": true
	})
	var gateway_body := gateway_card.find_child("HermesCardBody", true, false) as VBoxContainer
	if gateway_body != null:
		gateway_body.add_theme_constant_override("separation", _hermes_theme.spacing("space_2"))
		gateway_body.add_child(_ui.label("Hermes Gateway", "heading"))
		gateway_body.add_child(_ui.label("Primary Terminal/Hermes Chat transport (Docker gateway)", "muted"))

		var gateway_status_row: HBoxContainer = _ui.hbox([], _hermes_theme.spacing("space_2"), {"expand_h": true})
		_gateway_status_label = _ui.label("Status: checking", "status", {"name": "SystemSettingsGatewayStatus", "expand_h": true})
		_gateway_status_pill = _ui.badge("checking", "busy", {"name": "SystemSettingsGatewayStatusPill"})
		gateway_status_row.add_child(_gateway_status_label)
		gateway_status_row.add_child(_gateway_status_pill)
		gateway_body.add_child(gateway_status_row)

		_gateway_endpoint_value = _ui.label("Endpoint: http://127.0.0.1:8643/v1/chat/completions", "body", {"name": "SystemSettingsGatewayEndpoint", "expand_h": true})
		_gateway_model_value = _ui.label("Model: hermesos", "body", {"name": "SystemSettingsGatewayModel", "expand_h": true})
		_gateway_api_key_value = _ui.label("API key: configured no", "body", {"name": "SystemSettingsGatewayApiKey", "expand_h": true})
		_gateway_source_value = _ui.label("Source: runtime/hermes_gateway/compose.env", "muted", {"name": "SystemSettingsGatewaySource", "expand_h": true})
		gateway_body.add_child(_gateway_endpoint_value)
		gateway_body.add_child(_gateway_model_value)
		gateway_body.add_child(_gateway_api_key_value)
		gateway_body.add_child(_gateway_source_value)

		var gateway_button_row: HBoxContainer = _ui.hbox([], _hermes_theme.spacing("space_2"), {"expand_h": true})
		var gateway_test_button: Button = _ui.button("Test Gateway", Callable(self, "_test_gateway"), "primary", false, {
			"name": "SystemSettingsGatewayTest",
			"width": 118,
			"height": 30
		})
		var gateway_reload_button: Button = _ui.button("Reload Gateway Config", Callable(self, "_reload_gateway_config"), "secondary", false, {
			"name": "SystemSettingsGatewayReload",
			"width": 170,
			"height": 30
		})
		gateway_button_row.add_child(gateway_test_button)
		gateway_button_row.add_child(gateway_reload_button)
		gateway_body.add_child(gateway_button_row)

	page.add_child(gateway_card)

	var mcp_card: PanelContainer = _ui.card([], _hermes_theme.spacing("card"), {
		"name": "SystemSettingsMcpPanel",
		"expand_h": true
	})
	var mcp_body := mcp_card.find_child("HermesCardBody", true, false) as VBoxContainer
	if mcp_body != null:
		mcp_body.add_theme_constant_override("separation", _hermes_theme.spacing("space_2"))
		mcp_body.add_child(_ui.label("Hermes_OS MCP", "heading"))
		mcp_body.add_child(_ui.label("Godot McpInteractionServer endpoint for OS tools", "muted"))

		var mcp_status_row: HBoxContainer = _ui.hbox([], _hermes_theme.spacing("space_2"), {"expand_h": true})
		_mcp_status_label = _ui.label("Status: checking", "status", {"name": "SystemSettingsMcpStatus", "expand_h": true})
		_mcp_status_pill = _ui.badge("checking", "busy", {"name": "SystemSettingsMcpStatusPill"})
		mcp_status_row.add_child(_mcp_status_label)
		mcp_status_row.add_child(_mcp_status_pill)
		mcp_body.add_child(mcp_status_row)

		_mcp_endpoint_value = _ui.label("Endpoint: 127.0.0.1:9090", "body", {"name": "SystemSettingsMcpEndpoint", "expand_h": true})
		_mcp_tools_value = _ui.label("Tools: ping, observe, ui tree, click, list/read/write/create folder", "muted", {"name": "SystemSettingsMcpTools", "expand_h": true})
		mcp_body.add_child(_mcp_endpoint_value)
		mcp_body.add_child(_mcp_tools_value)

		var mcp_buttons: HBoxContainer = _ui.hbox([], _hermes_theme.spacing("space_2"), {"expand_h": true})
		var mcp_test_button: Button = _ui.button("Test MCP", Callable(self, "_test_mcp"), "secondary", false, {
			"name": "SystemSettingsMcpTest",
			"width": 110,
			"height": 30
		})
		mcp_buttons.add_child(mcp_test_button)
		mcp_body.add_child(mcp_buttons)
	page.add_child(mcp_card)

	var legacy_card: PanelContainer = _ui.card([], _hermes_theme.spacing("card"), {
		"name": "SystemSettingsLegacyBridgePanel",
		"expand_h": true
	})
	var legacy_body := legacy_card.find_child("HermesCardBody", true, false) as VBoxContainer
	if legacy_body != null:
		legacy_body.add_theme_constant_override("separation", _hermes_theme.spacing("space_1"))
		legacy_body.add_child(_ui.label("Advanced / Legacy", "heading"))
		legacy_body.add_child(_ui.label("Legacy live_bridge is deprecated and not used by the primary HermesOS Gateway path.", "muted"))
		legacy_body.add_child(_ui.label("Legacy endpoint: ws://127.0.0.1:8788/hermesos/ws (legacy only)", "faint"))
	page.add_child(legacy_card)

	return page

func _build_appearance_page() -> Control:
	var page: VBoxContainer = _ui.vbox([], _hermes_theme.spacing("space_3"), {
		"name": "SystemSettingsAppearancePage",
		"expand_h": true,
		"expand_v": true
	})

	var shell_row: HBoxContainer = _ui.hbox([], _hermes_theme.spacing("space_3"), {"expand_h": true, "expand_v": true})
	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_row.add_child(left_spacer)

	var appearance_card: PanelContainer = _ui.card([], _hermes_theme.spacing("card"), {
		"name": "SystemSettingsAppearanceCard",
		"min_size": Vector2(430, 0)
	})
	appearance_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	appearance_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var appearance_card_body := appearance_card.find_child("HermesCardBody", true, false) as VBoxContainer
	if appearance_card_body != null:
		appearance_card_body.add_theme_constant_override("separation", _hermes_theme.spacing("space_2"))
		appearance_card_body.add_child(_ui.label("Desktop appearance", "heading"))
		appearance_card_body.add_child(_ui.label("Theme, wallpaper, selection and drag highlight", "muted"))

		var theme_row: HBoxContainer = _ui.hbox([], _hermes_theme.spacing("space_2"), {"expand_h": true})
		var theme_label: Label = _ui.label("Mode", "body")
		theme_label.custom_minimum_size = Vector2(104, 0)
		theme_row.add_child(theme_label)
		var theme_option := OptionButton.new()
		theme_option.name = "SystemSettingsThemeMode"
		theme_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		theme_option.custom_minimum_size = Vector2(220, 30)
		theme_option.add_item("Dark")
		theme_option.add_item("Light")
		theme_option.select(1 if _shell._theme_mode == "light" else 0)
		theme_option.add_theme_color_override("font_color", _hermes_theme.color("text"))
		theme_option.add_theme_stylebox_override("normal", _hermes_theme.input_style("normal"))
		theme_option.add_theme_stylebox_override("hover", _hermes_theme.input_style("normal"))
		theme_option.add_theme_stylebox_override("focus", _hermes_theme.input_style("focused"))
		theme_option.item_selected.connect(func(index: int) -> void:
			_apply_theme_mode("light" if index == 1 else "dark", true)
			_set_desktop_context_status("Light mode enabled" if _shell._theme_mode == "light" else "Dark mode enabled")
			_refresh_system_info()
		)
		theme_row.add_child(theme_option)
		appearance_card_body.add_child(theme_row)

		var preset_row: HBoxContainer = _ui.hbox([], _hermes_theme.spacing("space_2"), {"expand_h": true})
		var preset_label: Label = _ui.label("Highlight", "body")
		preset_label.custom_minimum_size = Vector2(104, 0)
		preset_row.add_child(preset_label)
		var preset_option := OptionButton.new()
		preset_option.name = "SystemSettingsHighlightPreset"
		preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preset_option.custom_minimum_size = Vector2(220, 30)
		preset_option.add_theme_color_override("font_color", _hermes_theme.color("text"))
		preset_option.add_theme_stylebox_override("normal", _hermes_theme.input_style("normal"))
		preset_option.add_theme_stylebox_override("hover", _hermes_theme.input_style("normal"))
		preset_option.add_theme_stylebox_override("focus", _hermes_theme.input_style("focused"))
		var presets := _desktop_highlight_presets()
		for preset in presets:
			preset_option.add_item(str(preset.get("label", "Color")))
		preset_option.item_selected.connect(func(index: int) -> void:
			if index < 0 or index >= presets.size():
				return
			var preset: Dictionary = presets[index]
			var color: Color = preset.get("color", _shell._desktop_highlight_color)
			_set_desktop_highlight_color(Color(color.r, color.g, color.b, _shell._desktop_highlight_color.a))
			_set_desktop_context_status("Desktop highlight color updated")
			_refresh_system_info()
		)
		preset_row.add_child(preset_option)
		appearance_card_body.add_child(preset_row)

		var alpha_row: HBoxContainer = _ui.hbox([], _hermes_theme.spacing("space_2"), {"expand_h": true})
		var alpha_label: Label = _ui.label("Opacity", "body")
		alpha_label.custom_minimum_size = Vector2(104, 0)
		alpha_row.add_child(alpha_label)
		var alpha_slider := HSlider.new()
		alpha_slider.name = "SystemSettingsHighlightOpacity"
		alpha_slider.min_value = 0.14
		alpha_slider.max_value = 0.7
		alpha_slider.step = 0.01
		alpha_slider.value = _shell._desktop_highlight_color.a
		alpha_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		alpha_slider.custom_minimum_size = Vector2(190, 0)
		alpha_row.add_child(alpha_slider)
		_alpha_value_label = _ui.label("%d%%" % int(round(_shell._desktop_highlight_color.a * 100.0)), "status", {"name": "SystemSettingsAlphaValue"})
		_alpha_value_label.custom_minimum_size = Vector2(44, 0)
		alpha_row.add_child(_alpha_value_label)
		alpha_slider.value_changed.connect(func(value: float) -> void:
			_set_desktop_highlight_color(Color(_shell._desktop_highlight_color.r, _shell._desktop_highlight_color.g, _shell._desktop_highlight_color.b, value))
			_alpha_value_label.text = "%d%%" % int(round(value * 100.0))
		)
		appearance_card_body.add_child(alpha_row)

		var controls_row := HFlowContainer.new()
		controls_row.add_theme_constant_override("h_separation", _hermes_theme.spacing("space_2"))
		controls_row.add_theme_constant_override("v_separation", _hermes_theme.spacing("space_2"))
		var wallpaper_button: Button = _ui.button("Cycle wallpaper", Callable(), "secondary", false, {
			"name": "SystemSettingsCycleWallpaper",
			"width": 132,
			"height": 30
		})
		wallpaper_button.pressed.connect(func() -> void:
			_cycle_wallpaper()
			_refresh_system_info()
		)
		controls_row.add_child(wallpaper_button)

		var reset_layout_button: Button = _ui.button("Reset icon layout", Callable(), "secondary", false, {
			"name": "SystemSettingsResetIconLayout",
			"width": 132,
			"height": 30
		})
		reset_layout_button.pressed.connect(func() -> void:
			_shell._desktop_icon_positions.clear()
			_refresh_desktop_icons()
			_set_desktop_context_status("Desktop icon layout reset")
		)
		controls_row.add_child(reset_layout_button)

		var reset_highlight_button: Button = _ui.button("Reset highlight", Callable(), "ghost", false, {
			"name": "SystemSettingsResetHighlight",
			"width": 120,
			"height": 30
		})
		reset_highlight_button.pressed.connect(func() -> void:
			_set_desktop_highlight_color(Color(0.34, 0.45, 0.62, 0.32))
			alpha_slider.value = _shell._desktop_highlight_color.a
			_alpha_value_label.text = "%d%%" % int(round(_shell._desktop_highlight_color.a * 100.0))
			_set_desktop_context_status("Desktop highlight color reset")
			_refresh_system_info()
		)
		controls_row.add_child(reset_highlight_button)
		appearance_card_body.add_child(controls_row)

		for i in presets.size():
			var preset: Dictionary = presets[i]
			if (preset.get("color", Color.WHITE) as Color).is_equal_approx(Color(_shell._desktop_highlight_color.r, _shell._desktop_highlight_color.g, _shell._desktop_highlight_color.b, 1.0)):
				preset_option.select(i)
				break

	shell_row.add_child(appearance_card)
	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_row.add_child(right_spacer)
	page.add_child(shell_row)
	return page

func _refresh_gateway_mcp_status() -> void:
	var gateway_state: Dictionary = _gateway_state()
	var gateway_kind: String = _gateway_kind(gateway_state)
	var gateway_label: String = _gateway_label(gateway_kind)
	if _gateway_status_label != null:
		_gateway_status_label.text = "Status: " + gateway_label
		_gateway_status_label.add_theme_color_override("font_color", _hermes_theme.color(_status_color_token(gateway_kind)))
	if _gateway_status_pill != null:
		_apply_badge_kind(_gateway_status_pill, gateway_label, gateway_kind)
	if _gateway_status_badge != null:
		_apply_badge_kind(_gateway_status_badge, "Gateway: " + gateway_label, gateway_kind)
	if _gateway_endpoint_value != null:
		_gateway_endpoint_value.text = "Endpoint: %s" % str(gateway_state.get("endpoint", "http://127.0.0.1:8643/v1/chat/completions"))
	if _gateway_model_value != null:
		_gateway_model_value.text = "Model: %s" % str(gateway_state.get("model", "hermesos"))
	if _gateway_api_key_value != null:
		var has_key: bool = bool(gateway_state.get("api_key_present", false))
		_gateway_api_key_value.text = "API key: configured %s" % ("yes" if has_key else "no")
	if _gateway_source_value != null:
		_gateway_source_value.text = "Source: %s" % _gateway_source_path(gateway_state)

	var mcp_state: Dictionary = _mcp_state()
	var mcp_kind: String = str(mcp_state.get("kind", "unavailable"))
	var mcp_label: String = str(mcp_state.get("label", "unavailable"))
	if _mcp_status_label != null:
		_mcp_status_label.text = "Status: " + mcp_label
		_mcp_status_label.add_theme_color_override("font_color", _hermes_theme.color(_status_color_token(mcp_kind)))
	if _mcp_status_pill != null:
		_apply_badge_kind(_mcp_status_pill, mcp_label, mcp_kind)
	if _mcp_endpoint_value != null:
		_mcp_endpoint_value.text = "Endpoint: %s" % str(mcp_state.get("endpoint", "127.0.0.1:9090"))
	if _mcp_tools_value != null:
		_mcp_tools_value.text = "Tools: ping, observe, ui tree, click, list/read/write/create folder"
	_refresh_system_info()

func _test_gateway() -> void:
	_set_status("Testing Hermes Gateway status…", false)
	_refresh_gateway_mcp_status()

func _reload_gateway_config() -> void:
	if _shell == null or _shell._hermes_agent_service == null:
		_set_status("Hermes agent service unavailable", true)
		return
	if not _shell.has_method("_hermes_gateway_config"):
		_set_status("Gateway config loader unavailable", true)
		return
	var config: Dictionary = _shell.call("_hermes_gateway_config") as Dictionary
	var service: Object = _shell._hermes_agent_service
	var gateway_client: Variant = service.get("_gateway_client") if service != null else null
	if gateway_client == null or not gateway_client.has_method("configure"):
		_set_status("Gateway client unavailable", true)
		return
	gateway_client.call("configure", config)
	_set_status("Gateway config reloaded", false)
	_refresh_gateway_mcp_status()

func _test_mcp() -> void:
	_set_status("Testing MCP endpoint…", false)
	var state: Dictionary = {
		"kind": "checking",
		"label": "checking",
		"endpoint": "127.0.0.1:9090",
		"ok": false
	}
	var peer := StreamPeerTCP.new()
	var err: int = peer.connect_to_host("127.0.0.1", 9090)
	if err != OK:
		state["kind"] = "unavailable"
		state["label"] = "unavailable"
		state["error"] = "connect_failed"
		_set_status("MCP endpoint unavailable", true)
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
		_set_status("MCP endpoint reachable" if has_response else "MCP endpoint reachable (no response yet)", false)
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
		str(viewport_size),
		str(window_size),
		str(mode),
		str(_fs.call("current_user")),
		str(_fs.call("home_path")),
		", ".join(_fs.call("get_users")),
		OSFileSystem.SAVE_PATH,
		_app_ids_text(),
		_windows_text(),
		_gateway_label(gateway_kind),
		str(gateway.get("endpoint", "http://127.0.0.1:8643/v1/chat/completions")),
		str(gateway.get("model", "hermesos")),
		str(mcp_state.get("label", "unavailable")),
		str(mcp_state.get("endpoint", "127.0.0.1:9090"))
	]

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
		"model": "hermesos",
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
		"success":
			return "online"
		"warning":
			return "unauthorized"
		"danger":
			return "error"
		"busy":
			return "checking"
		_:
			return "offline"

func _status_color_token(kind: String) -> String:
	match kind:
		"success":
			return "success"
		"warning":
			return "warning"
		"danger":
			return "danger"
		"busy":
			return "info"
		_:
			return "text_muted"

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
	return {
		"kind": "checking",
		"label": "checking",
		"endpoint": "127.0.0.1:9090",
		"ok": false
	}

func _apply_badge_kind(badge: Control, text: String, kind: String) -> void:
	if badge == null:
		return
	if badge is PanelContainer:
		(badge as PanelContainer).add_theme_stylebox_override("panel", _hermes_theme.badge_style(kind))
	var label_node: Variant = badge.find_child("HermesBadgeLabel", true, false)
	if label_node is Label:
		(label_node as Label).text = text

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

func _set_status(message: String, is_error: bool = false) -> void:
	if _gateway_status_label != null:
		_gateway_status_label.text = message
		_gateway_status_label.add_theme_color_override("font_color", _hermes_theme.color("danger" if is_error else "text_muted"))
	if _status_label != null:
		_status_label.text = message
		_status_label.add_theme_color_override("font_color", _hermes_theme.color("danger" if is_error else "text_muted"))
