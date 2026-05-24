class_name SystemSettingsApp
extends Control

const Tokens = preload("res://scripts/os/design_tokens.gd")
const StyleFactory = preload("res://scripts/os/style_factory.gd")
const OSFileSystem = preload("res://scripts/os/os_file_system.gd")

var _shell: Node
var _fs: Object
var _root: VBoxContainer
var _info_label: Label
var _bridge_status_label: Label
var _bridge_endpoint_input: LineEdit
var _bridge_auto_connect: CheckBox
var _alpha_value_label: Label

func os_app_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	if _fs == null and _shell != null:
		_fs = _shell._fs
	_build()
	var initial_state: Dictionary = context.get("state", {}) if context.get("state", {}) is Dictionary else {}
	if not initial_state.is_empty():
		os_app_restore_state(initial_state)

func os_app_focus() -> void:
	if _bridge_endpoint_input != null:
		_bridge_endpoint_input.grab_focus()

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
		"bridge": _kernel_bridge_state()
	}

func os_app_restore_state(_state: Dictionary) -> void:
	_refresh_system_info()
	_refresh_bridge_status()

func _build() -> void:
	if _shell == null:
		return
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root = _app_root()
	_root.name = "SystemSettingsRoot"
	_root.custom_minimum_size = Vector2(760, 460)
	_root.set_meta("window_min_size", Vector2(720, 420))
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_root)

	var tabs := TabContainer.new()
	tabs.name = "SystemSettingsTabs"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(tabs)

	_build_system_tab(tabs)
	_build_appearance_tab(tabs)

func _build_system_tab(tabs: TabContainer) -> void:
	var system_tab := VBoxContainer.new()
	system_tab.name = "System"
	system_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	system_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(system_tab)

	var info_scroll := ScrollContainer.new()
	info_scroll.custom_minimum_size = Vector2(0, 96)
	info_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	system_tab.add_child(info_scroll)

	_info_label = Label.new()
	_info_label.name = "SystemSettingsInfoLabel"
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_info_label.add_theme_color_override("font_color", Tokens.TEXT)
	info_scroll.add_child(_info_label)
	_refresh_system_info()

	var bridge_panel := VBoxContainer.new()
	bridge_panel.name = "SystemSettingsBridgePanel"
	bridge_panel.add_theme_constant_override("separation", 6)
	system_tab.add_child(bridge_panel)
	bridge_panel.add_child(_label("Hermes bridge", 12, Tokens.TEXT))

	var bridge_row := HBoxContainer.new()
	bridge_row.add_theme_constant_override("separation", 8)
	bridge_panel.add_child(bridge_row)

	_bridge_endpoint_input = LineEdit.new()
	_bridge_endpoint_input.name = "SystemSettingsBridgeEndpoint"
	_bridge_endpoint_input.placeholder_text = "ws://127.0.0.1:8788/hermesos/ws"
	_bridge_endpoint_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(_bridge_endpoint_input)
	bridge_row.add_child(_bridge_endpoint_input)

	var bridge_connect_button := _button("Connect", Vector2(92, 30))
	bridge_connect_button.name = "SystemSettingsBridgeConnect"
	bridge_row.add_child(bridge_connect_button)
	var bridge_disconnect_button := _button("Disconnect", Vector2(104, 30))
	bridge_disconnect_button.name = "SystemSettingsBridgeDisconnect"
	bridge_row.add_child(bridge_disconnect_button)

	_bridge_status_label = _label("Bridge: unavailable", 11, Tokens.MUTED)
	_bridge_status_label.name = "SystemSettingsBridgeStatus"
	bridge_panel.add_child(_bridge_status_label)
	_bridge_auto_connect = CheckBox.new()
	_bridge_auto_connect.name = "SystemSettingsBridgeAutoConnect"
	_bridge_auto_connect.text = "Auto-connect on boot"
	_bridge_auto_connect.add_theme_color_override("font_color", Tokens.TEXT)
	bridge_panel.add_child(_bridge_auto_connect)

	_refresh_bridge_status()
	var bridge_kernel := _hermes_kernel_node()
	if bridge_kernel != null:
		if bridge_kernel.has_signal("bridge_connected") and not bridge_kernel.bridge_connected.is_connected(_refresh_bridge_status):
			bridge_kernel.bridge_connected.connect(_refresh_bridge_status)
		if bridge_kernel.has_signal("bridge_disconnected") and not bridge_kernel.bridge_disconnected.is_connected(_refresh_bridge_status):
			bridge_kernel.bridge_disconnected.connect(_refresh_bridge_status)
	bridge_connect_button.pressed.connect(_connect_bridge)
	_bridge_auto_connect.toggled.connect(_set_bridge_auto_connect)
	bridge_disconnect_button.pressed.connect(_disconnect_bridge)

func _build_appearance_tab(tabs: TabContainer) -> void:
	var appearance_tab := VBoxContainer.new()
	appearance_tab.name = "Appearance"
	appearance_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	appearance_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	appearance_tab.add_theme_constant_override("separation", 8)
	tabs.add_child(appearance_tab)

	var appearance_shell := HBoxContainer.new()
	appearance_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	appearance_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	appearance_tab.add_child(appearance_shell)

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	appearance_shell.add_child(left_spacer)

	var appearance_card := VBoxContainer.new()
	appearance_card.custom_minimum_size = Vector2(430, 0)
	appearance_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	appearance_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	appearance_card.add_theme_constant_override("separation", 6)
	appearance_shell.add_child(appearance_card)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	appearance_shell.add_child(right_spacer)

	appearance_card.add_child(_label("Desktop appearance", 13, Tokens.TEXT))
	appearance_card.add_child(_label("Theme, wallpaper, selection and drag highlight", 11, Tokens.MUTED))

	var theme_row := HBoxContainer.new()
	theme_row.add_theme_constant_override("separation", 8)
	appearance_card.add_child(theme_row)
	var theme_label := _label("Mode", 12, Tokens.TEXT)
	theme_label.custom_minimum_size = Vector2(104, 0)
	theme_row.add_child(theme_label)
	var theme_option := OptionButton.new()
	theme_option.name = "SystemSettingsThemeMode"
	theme_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	theme_option.custom_minimum_size = Vector2(220, 30)
	theme_option.add_item("Dark")
	theme_option.add_item("Light")
	theme_option.select(1 if _shell._theme_mode == "light" else 0)
	theme_option.add_theme_color_override("font_color", Tokens.TEXT)
	theme_option.add_theme_stylebox_override("normal", _style(Tokens.SURFACE, Tokens.BORDER, 1, 6))
	theme_option.add_theme_stylebox_override("hover", _style(Tokens.SURFACE_HOVER, Tokens.BORDER_ACTIVE, 1, 6))
	theme_option.add_theme_stylebox_override("focus", _style(Tokens.SURFACE_HOVER, Tokens.FOCUS, 2, 6))
	theme_option.item_selected.connect(func(index: int) -> void:
		_apply_theme_mode("light" if index == 1 else "dark", true)
		_set_desktop_context_status("Light mode enabled" if _shell._theme_mode == "light" else "Dark mode enabled")
		_refresh_system_info()
	)
	theme_row.add_child(theme_option)

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 8)
	appearance_card.add_child(preset_row)
	var preset_label := _label("Highlight", 12, Tokens.TEXT)
	preset_label.custom_minimum_size = Vector2(104, 0)
	preset_row.add_child(preset_label)

	var preset_option := OptionButton.new()
	preset_option.name = "SystemSettingsHighlightPreset"
	preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_option.custom_minimum_size = Vector2(220, 30)
	preset_option.add_theme_color_override("font_color", Tokens.TEXT)
	preset_option.add_theme_stylebox_override("normal", _style(Tokens.SURFACE, Tokens.BORDER, 1, 6))
	preset_option.add_theme_stylebox_override("hover", _style(Tokens.SURFACE_HOVER, Tokens.BORDER_ACTIVE, 1, 6))
	preset_option.add_theme_stylebox_override("focus", _style(Tokens.SURFACE_HOVER, Tokens.FOCUS, 2, 6))
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

	var alpha_row := HBoxContainer.new()
	alpha_row.add_theme_constant_override("separation", 8)
	appearance_card.add_child(alpha_row)
	var alpha_label := _label("Opacity", 12, Tokens.TEXT)
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
	_alpha_value_label = _label("%d%%" % int(round(_shell._desktop_highlight_color.a * 100.0)), 12, Tokens.MUTED)
	_alpha_value_label.custom_minimum_size = Vector2(44, 0)
	alpha_row.add_child(_alpha_value_label)
	alpha_slider.value_changed.connect(func(value: float) -> void:
		_set_desktop_highlight_color(Color(_shell._desktop_highlight_color.r, _shell._desktop_highlight_color.g, _shell._desktop_highlight_color.b, value))
		_alpha_value_label.text = "%d%%" % int(round(value * 100.0))
	)

	var controls_row := HFlowContainer.new()
	controls_row.add_theme_constant_override("h_separation", 8)
	controls_row.add_theme_constant_override("v_separation", 8)
	appearance_card.add_child(controls_row)
	var wallpaper_button := _button("Cycle wallpaper", Vector2(132, 30))
	wallpaper_button.name = "SystemSettingsCycleWallpaper"
	wallpaper_button.pressed.connect(func() -> void:
		_cycle_wallpaper()
		_refresh_system_info()
	)
	controls_row.add_child(wallpaper_button)
	var reset_layout_button := _button("Reset icon layout", Vector2(132, 30))
	reset_layout_button.name = "SystemSettingsResetIconLayout"
	reset_layout_button.pressed.connect(func() -> void:
		_shell._desktop_icon_positions.clear()
		_refresh_desktop_icons()
		_set_desktop_context_status("Desktop icon layout reset")
	)
	controls_row.add_child(reset_layout_button)
	var reset_highlight_button := _button("Reset highlight", Vector2(120, 30))
	reset_highlight_button.name = "SystemSettingsResetHighlight"
	reset_highlight_button.pressed.connect(func() -> void:
		_set_desktop_highlight_color(Color(0.34, 0.45, 0.62, 0.32))
		alpha_slider.value = _shell._desktop_highlight_color.a
		_alpha_value_label.text = "%d%%" % int(round(_shell._desktop_highlight_color.a * 100.0))
		_set_desktop_context_status("Desktop highlight color reset")
		_refresh_system_info()
	)
	controls_row.add_child(reset_highlight_button)

	for i in presets.size():
		var preset: Dictionary = presets[i]
		if (preset.get("color", Color.WHITE) as Color).is_equal_approx(Color(_shell._desktop_highlight_color.r, _shell._desktop_highlight_color.g, _shell._desktop_highlight_color.b, 1.0)):
			preset_option.select(i)
			break

func _refresh_bridge_status() -> void:
	if _bridge_endpoint_input == null or _bridge_auto_connect == null or _bridge_status_label == null:
		return
	var state := _kernel_bridge_state()
	_bridge_endpoint_input.text = str(state.get("endpoint", ""))
	_bridge_auto_connect.button_pressed = bool(state.get("auto_connect", false))
	var connected := bool(state.get("connected", false))
	_bridge_status_label.text = "Bridge: connected" if connected else "Bridge: disconnected"
	_bridge_status_label.add_theme_color_override("font_color", Tokens.TEXT if connected else Tokens.MUTED)
	_refresh_system_info()

func _connect_bridge() -> void:
	var kernel := _hermes_kernel_node()
	if kernel == null or not kernel.has_method("connect_bridge"):
		_set_status(_bridge_status_label, "Hermes kernel unavailable", true)
		return
	var endpoint := _bridge_endpoint_input.text.strip_edges()
	if kernel.has_method("set_bridge_settings"):
		kernel.call("set_bridge_settings", {
			"endpoint": endpoint,
			"auto_connect": _bridge_auto_connect.button_pressed
		})
	var message := str(kernel.call("connect_bridge", endpoint))
	if message != "":
		_set_status(_bridge_status_label, message, true)
	else:
		_set_status(_bridge_status_label, "Connecting...", false)
	_refresh_bridge_status()

func _set_bridge_auto_connect(enabled: bool) -> void:
	var kernel := _hermes_kernel_node()
	if kernel == null or not kernel.has_method("set_bridge_settings"):
		_set_status(_bridge_status_label, "Hermes kernel unavailable", true)
		return
	kernel.call("set_bridge_settings", {
		"endpoint": _bridge_endpoint_input.text.strip_edges(),
		"auto_connect": enabled
	})
	if enabled and kernel.has_method("is_bridge_connected") and not bool(kernel.call("is_bridge_connected")) and kernel.has_method("connect_bridge"):
		var message := str(kernel.call("connect_bridge", _bridge_endpoint_input.text.strip_edges()))
		if message != "":
			_set_status(_bridge_status_label, message, true)
		else:
			_set_status(_bridge_status_label, "Connecting...", false)
	_refresh_bridge_status()

func _disconnect_bridge() -> void:
	var kernel := _hermes_kernel_node()
	if kernel == null or not kernel.has_method("disconnect_bridge"):
		_set_status(_bridge_status_label, "Hermes kernel unavailable", true)
		return
	kernel.call("disconnect_bridge")
	_set_status(_bridge_status_label, "Disconnected", false)
	_refresh_bridge_status()

func _refresh_system_info() -> void:
	if _info_label == null or _shell == null or _fs == null:
		return
	var viewport_size: Vector2 = _shell.get_viewport_rect().size if _shell != null else Vector2.ZERO
	var window_size := DisplayServer.window_get_size()
	var mode := DisplayServer.window_get_mode()
	var bridge := _kernel_bridge_state()
	var bridge_status := "connected" if bool(bridge.get("connected", false)) else "disconnected"
	_info_label.text = "Viewport: %s
Game window: %s
Window mode: %s
Current user: %s
Home: %s
Users: %s
Filesystem save: %s
Apps: %s
Open windows: %s
Bridge: %s
Bridge endpoint: %s" % [
		str(viewport_size),
		str(window_size),
		str(mode),
		str(_fs.call("current_user")),
		str(_fs.call("home_path")),
		", ".join(_fs.call("get_users")),
		OSFileSystem.SAVE_PATH,
		_app_ids_text(),
		_windows_text(),
		bridge_status,
		str(bridge.get("endpoint", ""))
	]

func _desktop_highlight_presets() -> Array[Dictionary]:
	return [
		{"label": "Ocean blue", "color": Color(0.34, 0.45, 0.62, 1.0)},
		{"label": "Mint green", "color": Color(0.35, 0.63, 0.46, 1.0)},
		{"label": "Amber", "color": Color(0.73, 0.53, 0.27, 1.0)},
		{"label": "Rose", "color": Color(0.71, 0.39, 0.54, 1.0)}
	]

func _kernel_bridge_state() -> Dictionary:
	if _shell != null and _shell.has_method("_kernel_bridge_state"):
		return _shell.call("_kernel_bridge_state") as Dictionary
	return {"connected": false, "endpoint": "", "auto_connect": false}

func _hermes_kernel_node() -> Node:
	if _shell != null and _shell.has_method("_hermes_kernel_node"):
		return _shell.call("_hermes_kernel_node") as Node
	return null

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

func _app_root() -> VBoxContainer:
	if _shell != null and _shell.has_method("_app_root"):
		return _shell.call("_app_root") as VBoxContainer
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	return root

func _label(text_value: String, font_size: int, color: Color) -> Label:
	if _shell != null and _shell.has_method("_label"):
		return _shell.call("_label", text_value, font_size, color) as Label
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(text_value: String, min_size: Vector2) -> Button:
	if _shell != null and _shell.has_method("_button"):
		return _shell.call("_button", text_value, min_size) as Button
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = min_size
	button.add_theme_color_override("font_color", Tokens.TEXT)
	button.add_theme_stylebox_override("normal", StyleFactory.button_normal(8))
	button.add_theme_stylebox_override("hover", StyleFactory.button_hover(8))
	button.add_theme_stylebox_override("pressed", StyleFactory.button_pressed(8))
	button.add_theme_stylebox_override("focus", StyleFactory.button_focus(8))
	button.add_theme_stylebox_override("disabled", StyleFactory.button_disabled(8))
	return button

func _set_status(label: Label, message: String, is_error: bool = false) -> void:
	if label == null:
		return
	if _shell != null and _shell.has_method("_set_status"):
		_shell.call("_set_status", label, message, is_error)
		return
	label.text = message
	label.add_theme_color_override("font_color", Tokens.ERROR if is_error else Tokens.MUTED)

func _style_line_edit(input: LineEdit) -> void:
	if _shell != null and _shell.has_method("_style_line_edit"):
		_shell.call("_style_line_edit", input)
		return
	input.add_theme_color_override("font_color", Tokens.TEXT)
	input.add_theme_color_override("caret_color", Tokens.TEXT)
	input.add_theme_stylebox_override("normal", StyleFactory.input_normal(8))
	input.add_theme_stylebox_override("focus", StyleFactory.input_focus(8))

func _style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	if _shell != null and _shell.has_method("_style"):
		return _shell.call("_style", bg, border, border_width, radius) as StyleBoxFlat
	return StyleFactory.build(bg, border, border_width, radius)
