class_name OSShell
extends Control

const OSWindow = preload("res://scripts/os/os_window.gd")
const OSFileSystem = preload("res://scripts/os/os_file_system.gd")
const HermesProtocol = preload("res://scripts/hermes/hermes_protocol.gd")

signal notification_created(notification_id: String)
signal notification_clicked(notification_id: String)
signal notification_dismissed(notification_id: String)
signal hermes_event(event_name: String, payload: Dictionary)

var _apps: Dictionary = {}
var _app_order: Array[String] = []
var _open_windows: Dictionary = {}
var _task_buttons: Dictionary = {}
var _active_window: OSWindow
var _window_cascade := 0
var _fs: OSFileSystem

var _desktop_bg: ColorRect
var _desktop_layer: Control
var _desktop_icons: Control
var _desktop_context_menu: Panel
var _desktop_status_label: Label
var _desktop_actions_separator: HSeparator
var _desktop_rename_input: LineEdit
var _desktop_rename_button: Button
var _desktop_delete_button: Button
var _desktop_selected_path := ""
var _desktop_selected_paths: Dictionary = {}
var _desktop_icon_positions: Dictionary = {}
var _desktop_file_icon: Texture2D
var _desktop_folder_icon: Texture2D
var _desktop_drag_rect: ColorRect
var _desktop_drag_selecting := false
var _desktop_drag_start := Vector2.ZERO
var _desktop_drag_current := Vector2.ZERO
var _desktop_dragging_icon: Button
var _desktop_drag_icon_offset := Vector2.ZERO
var _desktop_drag_icon_moved := false
var _desktop_highlight_color := Color(0.34, 0.45, 0.62, 0.32)
var _window_layer: Control
var _taskbar_windows: HBoxContainer
var _launcher: Panel
var _session_menu: Panel
var _auth_overlay: Control
var _user_button: Button
var _clock_label: Label
var _notification_button: Button
var _notification_layer: Control
var _notification_history_panel: Panel
var _notification_list: VBoxContainer
var _notifications: Array[Dictionary] = []
var _notification_sequence := 0
var _session_active := false
var _wallpaper_index := 0
var _files_app_state: Dictionary = {}
var _files_app_ui: Dictionary = {}
var _text_app_editor: TextEdit
var _text_app_path_label: Label
var _text_app_status_label: Label
var _text_app_current_path := ""
var _files_shortcuts: Array[Dictionary] = []
var _notes_list: ItemList
var _notes_editor: TextEdit
var _notes_status_label: Label
var _notes_active_note_id := ""
var _notes_open_notes: Array[String] = []
var _terminal_sessions: Dictionary = {}
var _terminal_session_sequence := 0
var _console_outputs: Array[TextEdit] = []
var _console_history: Array[String] = ["Type 'help' for commands. Current user: user"]

const CONSOLE_HISTORY_MAX_LINES := 400

const TASKBAR_HEIGHT := 46.0
const BG := Color("181a1f")
const PANEL := Color("22252b")
const SURFACE := Color("2b2f38")
const SURFACE_HOVER := Color("353a45")
const BORDER := Color("3f4652")
const BORDER_ACTIVE := Color("7b8494")
const TEXT := Color("eceff4")
const MUTED := Color("a9b0bd")
const FOCUS := Color("8aa4d6")
const ERROR := Color("e06c75")
const DESKTOP_ICON_SIZE := Vector2(118, 86)
const DESKTOP_ICON_GAP := Vector2(14, 10)
const DESKTOP_ICON_MARGIN := Vector2(14, 14)
const WALLPAPERS: Array[Color] = [Color("181a1f"), Color("20242b"), Color("1c2424"), Color("211f25"), Color("24221d")]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	position = Vector2.ZERO
	_fs = OSFileSystem.new()
	_fs.load_or_create()
	_console_history = ["Type 'help' for commands. Current user: " + _fs.current_user()]
	_register_apps()
	_build_ui()
	_update_clock()
	_show_auth_screen("login")
	if has_node("/root/HermesOSKernel"):
		var kernel := get_node("/root/HermesOSKernel")
		if kernel and kernel.has_method("register_shell"):
			kernel.call("register_shell", self)

	var clock_timer := Timer.new()
	clock_timer.wait_time = 10.0
	clock_timer.autostart = true
	clock_timer.timeout.connect(_update_clock)
	add_child(clock_timer)

	resized.connect(_layout)

func launch_app(app_id: String) -> OSWindow:
	if not _session_active or _auth_overlay != null:
		return null
	if not _apps.has(app_id):
		push_warning("Unknown app: %s" % app_id)
		return null

	if _open_windows.has(app_id) and is_instance_valid(_open_windows[app_id]):
		var existing := _open_windows[app_id] as OSWindow
		existing.visible = true
		_focus_window(existing)
		_update_task_button(app_id, true)
		return existing

	var app: Dictionary = _apps[app_id]
	var builder := app["builder"] as Callable
	var content := builder.call() as Control
	var window := OSWindow.new()
	_window_layer.add_child(window)
	window.setup(app_id, str(app["title"]), content)
	window.set_window_size(_default_window_size(app_id))
	window.position = _center_window_position(window)
	_clamp_window_to_layer(window)
	window.close_requested.connect(_on_window_close_requested)
	window.minimize_requested.connect(_on_window_minimize_requested)
	window.focused.connect(_focus_window)

	_open_windows[app_id] = window
	_create_task_button(app_id)
	_focus_window(window)
	_emit_hermes_event("window.opened", {
		"window_id": _window_id(window),
		"app_id": app_id,
		"title": str(app.get("title", app_id))
	})
	_emit_hermes_event("app.opened", {"app_id": app_id})
	return window

func close_app(app_id: String) -> void:
	if _open_windows.has(app_id) and is_instance_valid(_open_windows[app_id]):
		_on_window_close_requested(_open_windows[app_id])

func _unhandled_key_input(event: InputEvent) -> void:
	if not _session_active or _auth_overlay != null:
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		_hide_desktop_context_menu()
		if _launcher:
			_launcher.visible = false
		if _session_menu:
			_session_menu.visible = false
		if _notification_history_panel:
			_notification_history_panel.visible = false
		get_viewport().set_input_as_handled()
	elif key_event.alt_pressed and key_event.keycode == KEY_TAB:
		_focus_next_window()
		get_viewport().set_input_as_handled()
	elif key_event.ctrl_pressed and key_event.keycode == KEY_W:
		_close_active_window()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_DELETE:
		if _delete_selected_desktop_items():
			get_viewport().set_input_as_handled()

func export_state() -> Dictionary:
	return {
		"filesystem": _fs.export_state(),
		"notifications": _notifications.duplicate(true),
		"session": {
			"active": _session_active,
			"wallpaper_index": _wallpaper_index,
			"desktop_icon_positions": _desktop_icon_positions.duplicate(true),
			"desktop_highlight_color": [_desktop_highlight_color.r, _desktop_highlight_color.g, _desktop_highlight_color.b, _desktop_highlight_color.a],
			"files_shortcuts": _files_shortcuts.duplicate(true)
		}
	}

func import_state(state: Dictionary) -> String:
	if not state.has("filesystem") or not (state["filesystem"] is Dictionary):
		return "Invalid HermesOS state: missing filesystem"
	var message := _fs.import_state(state["filesystem"])
	if message != "":
		return message
	var notification_state: Variant = state.get("notifications", [])
	_notifications.clear()
	_notification_sequence = 0
	if notification_state is Array:
		for item in notification_state:
			if item is Dictionary:
				var notification: Dictionary = item
				_notifications.append(notification.duplicate(true))
				_notification_sequence = maxi(_notification_sequence, int(str(notification.get("id", "0")).trim_prefix("n_")))
	_refresh_notifications()
	var session: Dictionary = state.get("session", {}) if state.get("session", {}) is Dictionary else {}
	_wallpaper_index = clampi(int(session.get("wallpaper_index", _wallpaper_index)), 0, WALLPAPERS.size() - 1)
	_session_active = bool(session.get("active", _session_active))
	_desktop_icon_positions = session.get("desktop_icon_positions", {}).duplicate(true) if session.get("desktop_icon_positions", {}) is Dictionary else {}
	_set_desktop_highlight_color(_color_from_variant(session.get("desktop_highlight_color", []), _desktop_highlight_color))
	_files_shortcuts = _files_sanitize_shortcuts(session.get("files_shortcuts", []), _fs.home_path())
	_close_all_windows()
	_hide_desktop_context_menu()
	if _launcher:
		_launcher.visible = false
	if _session_menu:
		_session_menu.visible = false
	if _desktop_bg:
		_desktop_bg.color = WALLPAPERS[_wallpaper_index]
	_refresh_desktop_icons()
	_update_clock()
	if _session_active:
		_hide_auth_screen()
	else:
		_show_auth_screen("login")
	return ""

func reset_state() -> void:
	_fs.reset()
	_notifications.clear()
	_notification_sequence = 0
	_refresh_notifications()
	_wallpaper_index = 0
	_desktop_icon_positions.clear()
	_files_shortcuts.clear()
	_set_desktop_highlight_color(Color(0.34, 0.45, 0.62, 0.32))
	_session_active = false
	_close_all_windows()
	_hide_desktop_context_menu()
	if _desktop_bg:
		_desktop_bg.color = WALLPAPERS[_wallpaper_index]
	_refresh_desktop_icons()
	_update_clock()
	_show_auth_screen("login")

func _register_apps() -> void:
	_app_order = ["files", "notes", "text", "console", "system"]
	_apps = {
		"files": {"title": "Files", "builder": Callable(self, "_build_files_app")},
		"notes": {"title": "Notes", "builder": Callable(self, "_build_notes_app")},
		"text": {"title": "Text", "builder": Callable(self, "_build_text_app")},
		"console": {"title": "Terminal", "builder": Callable(self, "_build_console_app")},
		"system": {"title": "System", "builder": Callable(self, "_build_system_app")}
	}

func _build_ui() -> void:
	_desktop_bg = ColorRect.new()
	_desktop_bg.color = WALLPAPERS[_wallpaper_index]
	_desktop_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_desktop_bg)

	_desktop_layer = Control.new()
	_desktop_layer.name = "DesktopLayer"
	_desktop_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desktop_layer.offset_bottom = -TASKBAR_HEIGHT
	_desktop_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_desktop_layer.gui_input.connect(_on_desktop_gui_input)
	add_child(_desktop_layer)
	_build_desktop_icons()

	_window_layer = Control.new()
	_window_layer.name = "WindowLayer"
	_window_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_window_layer.offset_bottom = -TASKBAR_HEIGHT
	_window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_window_layer)

	_build_taskbar()
	_build_launcher()
	_build_session_menu()
	_build_desktop_context_menu()
	_build_notification_history_panel()
	_build_notification_layer()
	_layout()

func _build_taskbar() -> void:
	var taskbar := Panel.new()
	taskbar.name = "Taskbar"
	taskbar.anchor_left = 0.0
	taskbar.anchor_right = 1.0
	taskbar.anchor_top = 1.0
	taskbar.anchor_bottom = 1.0
	taskbar.offset_top = -TASKBAR_HEIGHT
	taskbar.add_theme_stylebox_override("panel", _style(PANEL, BORDER, 1, 0))
	add_child(taskbar)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.offset_top = 6
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 6)
	taskbar.add_child(row)

	var start_button := _button("Start", Vector2(84, 0))
	start_button.pressed.connect(_toggle_launcher)
	row.add_child(start_button)

	var divider := VSeparator.new()
	row.add_child(divider)

	_taskbar_windows = HBoxContainer.new()
	_taskbar_windows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_taskbar_windows.add_theme_constant_override("separation", 6)
	row.add_child(_taskbar_windows)

	_notification_button = _button("Notifications", Vector2(128, 0))
	_notification_button.tooltip_text = "Notification history"
	_notification_button.pressed.connect(_toggle_notification_history)
	row.add_child(_notification_button)

	_user_button = _button("", Vector2(160, 0))
	_user_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_user_button.tooltip_text = "Session options"
	_user_button.pressed.connect(_toggle_session_menu)
	row.add_child(_user_button)

	_clock_label = Label.new()
	_clock_label.custom_minimum_size = Vector2(88, 0)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock_label.add_theme_color_override("font_color", TEXT)
	row.add_child(_clock_label)

func _build_launcher() -> void:
	_launcher = Panel.new()
	_launcher.name = "Launcher"
	_launcher.visible = false
	_launcher.size = Vector2(260, 222)
	_launcher.add_theme_stylebox_override("panel", _style(PANEL, BORDER_ACTIVE, 1, 8))
	add_child(_launcher)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 10
	column.offset_right = -10
	column.offset_top = 10
	column.offset_bottom = -10
	column.add_theme_constant_override("separation", 7)
	_launcher.add_child(column)

	var label := _label("Applications", 14, TEXT)
	column.add_child(label)

	for app_id in _app_order:
		var button := _app_button(app_id, Vector2(0, 36))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		column.add_child(button)

func _build_session_menu() -> void:
	_session_menu = Panel.new()
	_session_menu.name = "SessionMenu"
	_session_menu.visible = false
	_session_menu.size = Vector2(220, 176)
	_session_menu.add_theme_stylebox_override("panel", _style(PANEL, BORDER_ACTIVE, 1, 8))
	add_child(_session_menu)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 10
	column.offset_right = -10
	column.offset_top = 10
	column.offset_bottom = -10
	column.add_theme_constant_override("separation", 7)
	_session_menu.add_child(column)

	column.add_child(_label("Session", 14, TEXT))

	var lock_button := _button("Lock", Vector2(0, 34))
	lock_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	lock_button.pressed.connect(func() -> void:
		_session_menu.visible = false
		lock_session()
	)
	column.add_child(lock_button)

	var switch_button := _button("Switch user", Vector2(0, 34))
	switch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	switch_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	switch_button.pressed.connect(func() -> void:
		_session_menu.visible = false
		switch_user_session()
	)
	column.add_child(switch_button)

	var logout_button := _button("Log out", Vector2(0, 34))
	logout_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logout_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	logout_button.pressed.connect(func() -> void:
		_session_menu.visible = false
		logout_session()
	)
	column.add_child(logout_button)

func _build_desktop_context_menu() -> void:
	_desktop_context_menu = Panel.new()
	_desktop_context_menu.name = "DesktopContextMenu"
	_desktop_context_menu.visible = false
	_desktop_context_menu.size = Vector2(272, 352)
	_desktop_context_menu.clip_contents = true
	_desktop_context_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_desktop_context_menu.add_theme_stylebox_override("panel", _style(PANEL, BORDER_ACTIVE, 1, 8))
	add_child(_desktop_context_menu)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 10
	column.offset_right = -10
	column.offset_top = 10
	column.offset_bottom = -10
	column.add_theme_constant_override("separation", 5)
	_desktop_context_menu.add_child(column)

	column.add_child(_label("Desktop", 14, TEXT))

	var new_file_button := _context_menu_button("New file")
	new_file_button.pressed.connect(func() -> void:
		_create_desktop_item(false)
	)
	column.add_child(new_file_button)

	var new_folder_button := _context_menu_button("New folder")
	new_folder_button.pressed.connect(func() -> void:
		_create_desktop_item(true)
	)
	column.add_child(new_folder_button)

	var open_files_button := _context_menu_button("Open files")
	open_files_button.pressed.connect(func() -> void:
		_hide_desktop_context_menu()
		launch_app("files")
	)
	column.add_child(open_files_button)

	var wallpaper_button := _context_menu_button("Change wallpaper")
	wallpaper_button.pressed.connect(func() -> void:
		_cycle_wallpaper()
	)
	column.add_child(wallpaper_button)

	var settings_button := _context_menu_button("Desktop settings")
	settings_button.pressed.connect(func() -> void:
		_hide_desktop_context_menu()
		launch_app("system")
	)
	column.add_child(settings_button)

	_desktop_actions_separator = HSeparator.new()
	column.add_child(_desktop_actions_separator)

	_desktop_rename_input = LineEdit.new()
	_desktop_rename_input.placeholder_text = "Rename selected item"
	_desktop_rename_input.custom_minimum_size = Vector2(0, 30)
	_style_line_edit(_desktop_rename_input)
	_desktop_rename_input.text_submitted.connect(func(_submitted: String) -> void:
		_rename_selected_desktop_item()
	)
	column.add_child(_desktop_rename_input)

	_desktop_rename_button = _context_menu_button("Rename selected")
	_desktop_rename_button.pressed.connect(func() -> void:
		_rename_selected_desktop_item()
	)
	column.add_child(_desktop_rename_button)

	_desktop_delete_button = _context_menu_button("Delete selected")
	_desktop_delete_button.pressed.connect(func() -> void:
		_delete_selected_desktop_items()
	)
	column.add_child(_desktop_delete_button)

	_desktop_status_label = Label.new()
	_desktop_status_label.add_theme_font_size_override("font_size", 12)
	_desktop_status_label.add_theme_color_override("font_color", MUTED)
	_desktop_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_desktop_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_desktop_status_label.custom_minimum_size = Vector2(0, 18)
	_desktop_status_label.visible = false
	column.add_child(_desktop_status_label)
	_update_desktop_context_actions()

func notify(data: Dictionary) -> String:
	_notification_sequence += 1
	var notification_id := "n_" + str(_notification_sequence)
	var notification := {
		"id": notification_id,
		"title": str(data.get("title", "Notification")).strip_edges(),
		"body": str(data.get("body", "")).strip_edges(),
		"app_id": str(data.get("app_id", "system")).strip_edges(),
		"level": str(data.get("level", "info")).strip_edges().to_lower(),
		"timestamp": _time_text(),
		"action": data.get("action", {}) if data.get("action", {}) is Dictionary else {}
	}
	if str(notification["title"]) == "":
		notification["title"] = "Notification"
	_notifications.push_front(notification)
	while _notifications.size() > 50:
		_notifications.pop_back()
	_refresh_notifications()
	_show_notification_toast(notification)
	notification_created.emit(notification_id)
	_emit_hermes_event("notification.shown", {
		"notification_id": notification_id,
		"title": str(notification.get("title", "")),
		"level": str(notification.get("level", "info"))
	})
	return notification_id

func clear_notifications() -> void:
	var dismissed_ids: Array[String] = []
	for notification in _notifications:
		var item: Dictionary = notification
		dismissed_ids.append(str(item.get("id", "")))
	_notifications.clear()
	_refresh_notifications()
	for notification_id in dismissed_ids:
		if notification_id != "":
			notification_dismissed.emit(notification_id)

func _build_notification_layer() -> void:
	_notification_layer = Control.new()
	_notification_layer.name = "NotificationLayer"
	_notification_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_notification_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notification_layer)
	_notification_layer.move_to_front()

func _build_notification_history_panel() -> void:
	_notification_history_panel = Panel.new()
	_notification_history_panel.name = "NotificationHistory"
	_notification_history_panel.visible = false
	_notification_history_panel.size = Vector2(352, 320)
	_notification_history_panel.add_theme_stylebox_override("panel", _style(PANEL, BORDER_ACTIVE, 1, 8))
	add_child(_notification_history_panel)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 10
	column.offset_right = -10
	column.offset_top = 10
	column.offset_bottom = -10
	column.add_theme_constant_override("separation", 6)
	_notification_history_panel.add_child(column)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 30)
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	var header_title := Label.new()
	header_title.text = "Notifications"
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	header_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_title.add_theme_font_size_override("font_size", 13)
	header_title.add_theme_color_override("font_color", TEXT)
	header.add_child(header_title)
	var clear_button := _button("Clear", Vector2(60, 30))
	clear_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clear_button.pressed.connect(clear_notifications)
	header.add_child(clear_button)

	var divider := HSeparator.new()
	column.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_notification_list = VBoxContainer.new()
	_notification_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notification_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_notification_list)
	_refresh_notifications()

func _toggle_notification_history() -> void:
	if not _session_active:
		return
	_hide_desktop_context_menu()
	if _launcher:
		_launcher.visible = false
	if _session_menu:
		_session_menu.visible = false
	_notification_history_panel.visible = not _notification_history_panel.visible
	if _notification_history_panel.visible:
		_notification_history_panel.move_to_front()

func _refresh_notifications() -> void:
	if _notification_button:
		_notification_button.text = "Notifications" if _notifications.is_empty() else "Notifications (" + str(_notifications.size()) + ")"
	if not _notification_list:
		return
	for child in _notification_list.get_children():
		child.queue_free()
	if _notifications.is_empty():
		_notification_list.add_child(_label("No notifications", 12, MUTED))
		return
	for notification in _notifications:
		var item: Dictionary = notification
		_notification_list.add_child(_notification_row(item))

func _notification_row(notification: Dictionary) -> Control:
	var button := _button(_notification_summary(notification), Vector2(0, 48))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 12)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = str(notification.get("body", ""))
	var normal := _style(SURFACE, BORDER, 1, 6)
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover := _style(SURFACE_HOVER, BORDER_ACTIVE, 1, 6)
	hover.content_margin_left = 6
	hover.content_margin_right = 6
	hover.content_margin_top = 4
	hover.content_margin_bottom = 4
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(func() -> void:
		_handle_notification_clicked(notification)
	)
	return button

func _notification_summary(notification: Dictionary) -> String:
	var title := str(notification.get("title", "Notification")).strip_edges()
	if title == "":
		title = "Notification"
	var level := str(notification.get("level", "info"))
	var body := str(notification.get("body", "")).strip_edges().replace("\n", " ")
	if body.length() > 42:
		body = body.substr(0, 42) + "…"
	var detail := str(notification.get("timestamp", ""))
	if body != "":
		detail += " · " + body
	return "[%s] %s\n%s" % [level, title, detail]

func _show_notification_toast(notification: Dictionary) -> void:
	if not _notification_layer:
		return
	var toast := Panel.new()
	toast.name = "Toast_" + str(notification.get("id", ""))
	toast.size = Vector2(330, 92)
	toast.position = Vector2(maxf(size.x - toast.size.x - 16.0, 16.0), 18.0 + minf(float(_notification_layer.get_child_count()) * 102.0, 306.0))
	toast.mouse_filter = Control.MOUSE_FILTER_STOP
	toast.add_theme_stylebox_override("panel", _style(SURFACE, _notification_level_color(str(notification.get("level", "info"))), 1, 8))
	_notification_layer.add_child(toast)
	toast.move_to_front()

	var button := _button(_notification_summary(notification), toast.size)
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(func() -> void:
		_handle_notification_clicked(notification)
		if is_instance_valid(toast):
			toast.queue_free()
	)
	toast.add_child(button)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 4.0
	timer.timeout.connect(func() -> void:
		if is_instance_valid(toast):
			toast.queue_free()
	)
	toast.add_child(timer)
	timer.start()

func _handle_notification_clicked(notification: Dictionary) -> void:
	var notification_id := str(notification.get("id", ""))
	notification_clicked.emit(notification_id)
	var action: Dictionary = notification.get("action", {}) if notification.get("action", {}) is Dictionary else {}
	if str(action.get("type", "")) == "launch_app":
		var app_id := str(action.get("app_id", ""))
		if app_id != "":
			launch_app(app_id)
	if _notification_history_panel:
		_notification_history_panel.visible = false

func _notification_level_color(level: String) -> Color:
	match level:
		"success":
			return Color("7fb069")
		"warning":
			return Color("d19a66")
		"error":
			return ERROR
		"message":
			return FOCUS
		_:
			return BORDER_ACTIVE

func _notifications_text() -> String:
	if _notifications.is_empty():
		return "No notifications"
	var lines: Array[String] = []
	for notification in _notifications:
		var item: Dictionary = notification
		lines.append("%s %s [%s] %s - %s" % [str(item.get("id", "")), str(item.get("timestamp", "")), str(item.get("level", "info")), str(item.get("title", "Notification")), str(item.get("body", ""))])
	return "\n".join(lines)

func _build_desktop_icons() -> void:
	_desktop_icons = Control.new()
	_desktop_icons.name = "DesktopIcons"
	_desktop_icons.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desktop_icons.offset_left = DESKTOP_ICON_MARGIN.x
	_desktop_icons.offset_top = DESKTOP_ICON_MARGIN.y
	_desktop_icons.offset_right = -DESKTOP_ICON_MARGIN.x
	_desktop_icons.offset_bottom = -DESKTOP_ICON_MARGIN.y
	_desktop_icons.mouse_filter = Control.MOUSE_FILTER_PASS
	_desktop_layer.add_child(_desktop_icons)
	_desktop_folder_icon = _desktop_icon_texture(true)
	_desktop_file_icon = _desktop_icon_texture(false)
	_desktop_drag_rect = ColorRect.new()
	_desktop_drag_rect.visible = false
	_desktop_drag_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop_drag_rect.color = _desktop_highlight_color
	_desktop_layer.add_child(_desktop_drag_rect)

func _refresh_desktop_icons() -> void:
	if not _desktop_icons:
		return
	for child in _desktop_icons.get_children():
		child.queue_free()
	_desktop_drag_selecting = false
	_desktop_dragging_icon = null
	if _desktop_drag_rect:
		_desktop_drag_rect.visible = false
	_desktop_selected_paths.clear()
	_desktop_selected_path = ""
	if not _session_active:
		_update_desktop_context_actions()
		return
	var message := _ensure_desktop_folder()
	if message != "":
		_set_desktop_context_status(message, true)
		_update_desktop_context_actions()
		return
	var index := 0
	for entry in _fs.list_dir(_desktop_folder_path()):
		var item: Dictionary = entry
		var button := _desktop_icon_button(item)
		_desktop_icons.add_child(button)
		var item_path := str(item.get("path", ""))
		if _desktop_icon_positions.has(item_path):
			_set_desktop_icon_position(button, _desktop_icon_positions[item_path], false)
		else:
			_set_desktop_icon_position(button, _desktop_icon_slot_position(index), false)
		index += 1
	_clamp_all_desktop_icon_positions()
	_update_desktop_context_actions()

func _desktop_icon_button(entry: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = DESKTOP_ICON_SIZE
	button.size = DESKTOP_ICON_SIZE
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = str(entry.get("name", "Item"))
	button.icon = _desktop_folder_icon if str(entry.get("type", "file")) == "dir" else _desktop_file_icon
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = str(entry.get("path", ""))
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_color_override("font_focus_color", TEXT)
	button.add_theme_constant_override("icon_max_width", 34)
	button.set_meta("desktop_path", str(entry.get("path", "")))
	button.set_meta("desktop_is_dir", bool(str(entry.get("type", "file")) == "dir"))
	button.pressed.connect(_on_desktop_icon_pressed.bind(button, false))
	button.gui_input.connect(_on_desktop_icon_gui_input.bind(button, bool(str(entry.get("type", "file")) == "dir")))
	_apply_desktop_icon_style(button, false)
	return button

func _desktop_icon_slot_position(index: int) -> Vector2:
	if not _desktop_icons:
		return Vector2.ZERO
	var cell := DESKTOP_ICON_SIZE + DESKTOP_ICON_GAP
	var columns := maxi(int((_desktop_icons.size.x + DESKTOP_ICON_GAP.x) / cell.x), 1)
	var row := int(index / columns)
	var column := int(index % columns)
	return Vector2(column * cell.x, row * cell.y)

func _desktop_icon_bounds() -> Rect2:
	if not _desktop_icons:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return Rect2(Vector2.ZERO, _desktop_icons.size)

func _set_desktop_icon_position(button: Button, desired_position: Vector2, save_position := true) -> void:
	var bounds := _desktop_icon_bounds()
	var max_x := maxf(bounds.size.x - button.size.x, 0.0)
	var max_y := maxf(bounds.size.y - button.size.y, 0.0)
	button.position = Vector2(clampf(desired_position.x, 0.0, max_x), clampf(desired_position.y, 0.0, max_y))
	if save_position:
		var item_path := str(button.get_meta("desktop_path", ""))
		if item_path != "":
			_desktop_icon_positions[item_path] = button.position

func _clamp_all_desktop_icon_positions() -> void:
	if not _desktop_icons:
		return
	for child in _desktop_icons.get_children():
		if child is Button:
			_set_desktop_icon_position(child as Button, (child as Button).position, true)

func _apply_desktop_icon_style(button: Button, selected: bool) -> void:
	var border_color := _desktop_highlight_border_color()
	var normal_color := _desktop_highlight_color if selected else Color(0, 0, 0, 0)
	button.add_theme_stylebox_override("normal", _style(normal_color, border_color if selected else Color(0, 0, 0, 0), 1 if selected else 0, 6))
	button.add_theme_stylebox_override("hover", _style(Color(1, 1, 1, 0.08), BORDER_ACTIVE, 1, 6))
	button.add_theme_stylebox_override("pressed", _style(_desktop_highlight_color, border_color, 1, 6))
	button.add_theme_stylebox_override("focus", _style(_desktop_highlight_color, border_color, 2, 6))

func _desktop_highlight_border_color() -> Color:
	return Color(minf(_desktop_highlight_color.r + 0.16, 1.0), minf(_desktop_highlight_color.g + 0.16, 1.0), minf(_desktop_highlight_color.b + 0.16, 1.0), 0.95)

func _on_desktop_icon_pressed(button: Button, additive := false) -> void:
	var path := str(button.get_meta("desktop_path", ""))
	if path == "":
		return
	if not additive:
		_desktop_selected_paths.clear()
	_desktop_selected_paths[path] = true
	_desktop_selected_path = path
	_update_desktop_icon_selection()

func _on_desktop_icon_gui_input(event: InputEvent, button: Button, is_dir: bool) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_on_desktop_icon_pressed(button)
			_show_desktop_context_menu(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_on_desktop_icon_pressed(button, mouse_event.ctrl_pressed)
			if mouse_event.double_click:
				_open_desktop_item(_desktop_icon_path(button), is_dir)
				get_viewport().set_input_as_handled()
				return
			_desktop_drag_selecting = false
			_desktop_dragging_icon = button
			_desktop_drag_icon_offset = mouse_event.position
			_desktop_drag_icon_moved = false
			_hide_desktop_context_menu()
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed and _desktop_dragging_icon == button:
			if _desktop_drag_icon_moved:
				var drop_target := _desktop_folder_drop_target(button, mouse_event.global_position)
				if drop_target != null:
					_move_desktop_item_to_folder(button, drop_target)
				else:
					_set_desktop_context_status("Moved " + _desktop_icon_path(button))
			_desktop_dragging_icon = null
			_desktop_drag_icon_moved = false
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _desktop_dragging_icon == button:
		var motion := event as InputEventMouseMotion
		var target := motion.global_position - _desktop_icons.global_position - _desktop_drag_icon_offset
		if button.position.distance_to(target) > 1.0:
			_desktop_drag_icon_moved = true
		_set_desktop_icon_position(button, target, true)
		get_viewport().set_input_as_handled()

func _update_desktop_icon_selection() -> void:
	if not _desktop_icons:
		return
	for child in _desktop_icons.get_children():
		if child is Button:
			var button := child as Button
			var selected := _desktop_selected_paths.has(_desktop_icon_path(button))
			button.button_pressed = selected
			_apply_desktop_icon_style(button, selected)
	if _desktop_selected_path == "" and not _desktop_selected_paths.is_empty():
		_desktop_selected_path = str(_desktop_selected_paths.keys()[0])
	_update_desktop_context_actions()

func _clear_desktop_icon_selection() -> void:
	_desktop_selected_paths.clear()
	_desktop_selected_path = ""
	_update_desktop_icon_selection()

func _desktop_icon_path(button: Button) -> String:
	return str(button.get_meta("desktop_path", ""))

func _desktop_selected_path_list() -> Array[String]:
	var paths: Array[String] = []
	for key in _desktop_selected_paths.keys():
		paths.append(str(key))
	paths.sort()
	return paths

func _open_desktop_item(path: String, is_dir: bool) -> void:
	if path == "":
		return
	_hide_desktop_context_menu()
	if is_dir:
		_open_files_to_path(path)
		_set_desktop_context_status("Opened folder: " + path.get_file())
		return
	_open_text_file(path)
	_set_desktop_context_status("Opened file in Text: " + path.get_file())

func _delete_selected_desktop_items() -> bool:
	var paths := _desktop_selected_path_list()
	if paths.is_empty():
		if _desktop_selected_path != "":
			paths.append(_desktop_selected_path)
	if paths.is_empty():
		_set_desktop_context_status("Select an icon first", true)
		_update_desktop_context_actions()
		return false
	var deleted := 0
	for item_path in paths:
		var message := _fs.delete_path(item_path)
		if message != "":
			_set_desktop_context_status(message, true)
			continue
		deleted += 1
		_desktop_icon_positions.erase(item_path)
	if deleted == 0:
		return false
	_refresh_desktop_icons()
	_hide_desktop_context_menu()
	_set_desktop_context_status("Deleted %d item(s)" % deleted)
	return true

func _rename_selected_desktop_item() -> bool:
	var paths := _desktop_selected_path_list()
	if paths.is_empty() and _desktop_selected_path != "":
		paths.append(_desktop_selected_path)
	if paths.size() != 1:
		_set_desktop_context_status("Select a single item to rename", true)
		_update_desktop_context_actions()
		return false
	var source_path := paths[0]
	var source_name := source_path.get_file()
	var target_name := _desktop_rename_input.text.strip_edges() if _desktop_rename_input else ""
	if target_name == "":
		_set_desktop_context_status("Enter a new name", true)
		return false
	if _fs.is_file(source_path):
		var source_extension := source_name.get_extension()
		if source_extension != "" and target_name.get_extension() == "":
			target_name += "." + source_extension
	if target_name == source_name:
		_set_desktop_context_status("Name unchanged")
		return false
	var message := _fs.rename_path(source_path, target_name)
	if message != "":
		_set_desktop_context_status(message, true)
		return false
	var target_path := _fs.normalize_path(_fs.join_path(_fs.parent_path(source_path), target_name))
	if _desktop_icon_positions.has(source_path):
		_desktop_icon_positions[target_path] = _desktop_icon_positions[source_path]
		_desktop_icon_positions.erase(source_path)
	_refresh_desktop_icons()
	_select_desktop_icon_by_path(target_path)
	if _desktop_rename_input:
		_desktop_rename_input.text = target_name
	_set_desktop_context_status("Renamed to " + target_name)
	return true

func _select_desktop_icon_by_path(target_path: String) -> void:
	if target_path == "":
		return
	if not _desktop_icons:
		return
	for child in _desktop_icons.get_children():
		if child is Button:
			var button := child as Button
			if _desktop_icon_path(button) == target_path:
				_desktop_selected_paths.clear()
				_desktop_selected_paths[target_path] = true
				_desktop_selected_path = target_path
				_update_desktop_icon_selection()
				return

func _desktop_folder_drop_target(source_button: Button, drop_global: Vector2) -> Button:
	if not _desktop_icons:
		return null
	var drop_local := drop_global - _desktop_icons.global_position
	for child in _desktop_icons.get_children():
		if child is Button:
			var target := child as Button
			if target == source_button:
				continue
			if not bool(target.get_meta("desktop_is_dir", false)):
				continue
			if Rect2(target.position, target.size).has_point(drop_local):
				return target
	return null

func _move_desktop_item_to_folder(source_button: Button, target_folder_button: Button) -> bool:
	var source_path := _desktop_icon_path(source_button)
	var target_folder_path := _desktop_icon_path(target_folder_button)
	if source_path == "" or target_folder_path == "":
		return false
	var destination := _paste_destination_path(source_path, target_folder_path)
	var message := _fs.move_path(source_path, destination)
	if message != "":
		_set_desktop_context_status(message, true)
		return false
	_desktop_icon_positions.erase(source_path)
	_refresh_desktop_icons()
	_set_desktop_context_status("Moved to " + target_folder_path.get_file())
	return true

func _update_desktop_context_actions() -> void:
	if not _desktop_delete_button:
		return
	var selected_count := _desktop_selected_paths.size()
	if selected_count == 0 and _desktop_selected_path != "":
		selected_count = 1
	var single_selected_path := _desktop_selected_path
	if selected_count == 1 and single_selected_path == "" and not _desktop_selected_paths.is_empty():
		single_selected_path = str(_desktop_selected_paths.keys()[0])
	if _desktop_actions_separator:
		_desktop_actions_separator.visible = selected_count > 0
	if _desktop_rename_input:
		_desktop_rename_input.visible = selected_count == 1
		if selected_count == 1:
			var selected_name := single_selected_path.get_file()
			var previous_source_path := str(_desktop_rename_input.get_meta("source_path", ""))
			if _desktop_rename_input.text.strip_edges() == "" or previous_source_path != single_selected_path:
				_desktop_rename_input.text = selected_name
				var selected_extension := selected_name.get_extension()
				if selected_extension != "":
					var stem_length := maxi(selected_name.length() - selected_extension.length() - 1, 0)
					_desktop_rename_input.select(0, stem_length)
				else:
					_desktop_rename_input.select_all()
			_desktop_rename_input.set_meta("source_path", single_selected_path)
		else:
			_desktop_rename_input.text = ""
			_desktop_rename_input.set_meta("source_path", "")
	if _desktop_rename_button:
		_desktop_rename_button.visible = selected_count == 1
	_desktop_delete_button.visible = selected_count > 0
	_desktop_delete_button.disabled = selected_count == 0
	_desktop_delete_button.text = "Delete selected" if selected_count <= 1 else "Delete selected (%d)" % selected_count

func _set_desktop_highlight_color(color: Color) -> void:
	_desktop_highlight_color = Color(color.r, color.g, color.b, clampf(color.a, 0.14, 0.7))
	if _desktop_drag_rect:
		_desktop_drag_rect.color = _desktop_highlight_color
	_update_desktop_icon_selection()

func _desktop_icon_texture(is_folder: bool) -> Texture2D:
	var image := Image.create(36, 36, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	if is_folder:
		image.fill_rect(Rect2i(3, 10, 30, 20), Color("c7a45b"))
		image.fill_rect(Rect2i(5, 8, 12, 4), Color("ddc074"))
		image.fill_rect(Rect2i(5, 15, 26, 2), Color("edd7a0"))
		image.fill_rect(Rect2i(3, 29, 30, 1), Color("9b7f46"))
	else:
		image.fill_rect(Rect2i(8, 4, 20, 28), Color("d7dee9"))
		image.fill_rect(Rect2i(20, 4, 8, 8), Color("edf2f8"))
		image.fill_rect(Rect2i(8, 4, 20, 1), Color("a7b3c6"))
		image.fill_rect(Rect2i(11, 14, 14, 2), Color("a2afc2"))
		image.fill_rect(Rect2i(11, 19, 14, 2), Color("a2afc2"))
		image.fill_rect(Rect2i(11, 24, 12, 2), Color("a2afc2"))
	return ImageTexture.create_from_image(image)

func _context_menu_button(text_value: String) -> Button:
	var button := _button(text_value, Vector2(0, 30))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var normal := _style(SURFACE, BORDER, 1, 6)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 3
	normal.content_margin_bottom = 3
	var hover := _style(SURFACE_HOVER, BORDER_ACTIVE, 1, 6)
	hover.content_margin_left = 8
	hover.content_margin_right = 8
	hover.content_margin_top = 3
	hover.content_margin_bottom = 3
	var pressed := _style(Color("3b414d"), FOCUS, 1, 6)
	pressed.content_margin_left = 8
	pressed.content_margin_right = 8
	pressed.content_margin_top = 3
	pressed.content_margin_bottom = 3
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), FOCUS, 2, 6))
	button.add_theme_stylebox_override("disabled", _style(Color("252830"), Color("333842"), 1, 6))
	return button

func _on_desktop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _desktop_drag_selecting:
		var motion := event as InputEventMouseMotion
		_desktop_drag_current = motion.position
		_update_desktop_drag_rect_visual()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_show_desktop_context_menu(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_hide_desktop_context_menu()
				if _launcher:
					_launcher.visible = false
				if _session_menu:
					_session_menu.visible = false
				if _notification_history_panel:
					_notification_history_panel.visible = false
				_clear_desktop_icon_selection()
				_desktop_drag_selecting = true
				_desktop_drag_start = mouse_event.position
				_desktop_drag_current = mouse_event.position
				_update_desktop_drag_rect_visual()
				get_viewport().set_input_as_handled()
			elif _desktop_drag_selecting:
				_desktop_drag_selecting = false
				_select_icons_in_drag_rect()
				if _desktop_drag_rect:
					_desktop_drag_rect.visible = false
				get_viewport().set_input_as_handled()

func _update_desktop_drag_rect_visual() -> void:
	if not _desktop_drag_rect:
		return
	var top_left := Vector2(minf(_desktop_drag_start.x, _desktop_drag_current.x), minf(_desktop_drag_start.y, _desktop_drag_current.y))
	var size_value := Vector2(absf(_desktop_drag_current.x - _desktop_drag_start.x), absf(_desktop_drag_current.y - _desktop_drag_start.y))
	_desktop_drag_rect.position = top_left
	_desktop_drag_rect.size = size_value
	_desktop_drag_rect.visible = size_value.length() >= 4.0

func _select_icons_in_drag_rect() -> void:
	if not _desktop_icons:
		return
	var rect := Rect2(_desktop_drag_rect.position, _desktop_drag_rect.size)
	if rect.size.length() < 4.0:
		return
	_desktop_selected_paths.clear()
	for child in _desktop_icons.get_children():
		if child is Button:
			var button := child as Button
			if rect.intersects(Rect2(button.position, button.size), true):
				_desktop_selected_paths[_desktop_icon_path(button)] = true
	if _desktop_selected_paths.is_empty():
		_desktop_selected_path = ""
	else:
		_desktop_selected_path = str(_desktop_selected_paths.keys()[0])
	_update_desktop_icon_selection()

func _show_desktop_context_menu(global_pos: Vector2) -> void:
	if not _session_active or _auth_overlay != null:
		return
	if _launcher:
		_launcher.visible = false
	if _session_menu:
		_session_menu.visible = false
	if _notification_history_panel:
		_notification_history_panel.visible = false
	_desktop_context_menu.position = Vector2(
		clampf(global_pos.x, 8.0, maxf(size.x - _desktop_context_menu.size.x - 8.0, 8.0)),
		clampf(global_pos.y, 8.0, maxf(size.y - TASKBAR_HEIGHT - _desktop_context_menu.size.y - 8.0, 8.0))
	)
	_set_desktop_context_status("")
	_update_desktop_context_actions()
	_desktop_context_menu.visible = true
	_desktop_context_menu.move_to_front()

func _hide_desktop_context_menu() -> void:
	if _desktop_context_menu:
		_desktop_context_menu.visible = false

func _desktop_folder_path() -> String:
	return _fs.join_path(_fs.home_path(), "Desktop")

func _ensure_desktop_folder() -> String:
	var desktop_path := _desktop_folder_path()
	if _fs.is_dir(desktop_path):
		return ""
	return _fs.make_dir(desktop_path)

func _create_desktop_item(is_folder: bool) -> void:
	var message := _ensure_desktop_folder()
	if message != "":
		_set_desktop_context_status(message, true)
		return
	var desktop_path := _desktop_folder_path()
	var base_name := "New Folder" if is_folder else "New File.txt"
	var target_path := _unique_child_path(desktop_path, base_name)
	message = _fs.make_dir(target_path) if is_folder else _fs.write_file(target_path, "")
	if message != "":
		_set_desktop_context_status(message, true)
		return
	_refresh_desktop_icons()
	_set_desktop_context_status("Created " + target_path)

func _unique_child_path(parent_path: String, base_name: String) -> String:
	var clean_parent := _fs.normalize_path(parent_path)
	var stem := base_name.get_basename()
	var extension := base_name.get_extension()
	var candidate_name := base_name
	var index := 2
	while _fs.exists(_fs.join_path(clean_parent, candidate_name)):
		if extension == "":
			candidate_name = "%s %d" % [stem, index]
		else:
			candidate_name = "%s %d.%s" % [stem, index, extension]
		index += 1
	return _fs.join_path(clean_parent, candidate_name)

func _cycle_wallpaper() -> void:
	_wallpaper_index = (_wallpaper_index + 1) % WALLPAPERS.size()
	if _desktop_bg:
		_desktop_bg.color = WALLPAPERS[_wallpaper_index]
	_set_desktop_context_status("Wallpaper changed")

func _set_desktop_context_status(message: String, is_error := false) -> void:
	if not _desktop_status_label:
		return
	var clean_message := message.strip_edges()
	if clean_message == "":
		_desktop_status_label.text = ""
		_desktop_status_label.tooltip_text = ""
		_desktop_status_label.visible = false
		return
	var short_message := clean_message
	if short_message.length() > 64:
		short_message = short_message.substr(0, 64) + "…"
	_desktop_status_label.text = short_message
	_desktop_status_label.tooltip_text = clean_message
	_desktop_status_label.visible = true
	_desktop_status_label.add_theme_color_override("font_color", ERROR if is_error else MUTED)

func _app_button(app_id: String, min_size: Vector2) -> Button:
	var app: Dictionary = _apps[app_id]
	var button := _button(str(app["title"]), min_size)
	button.tooltip_text = "Open " + str(app["title"])
	button.pressed.connect(func() -> void:
		_launcher.visible = false
		launch_app(app_id)
	)
	return button

func _layout() -> void:
	if _launcher:
		_launcher.position = Vector2(8, maxf(size.y - TASKBAR_HEIGHT - _launcher.size.y - 6.0, 8.0))
	if _session_menu:
		_session_menu.position = Vector2(maxf(size.x - _session_menu.size.x - 96.0, 8.0), maxf(size.y - TASKBAR_HEIGHT - _session_menu.size.y - 6.0, 8.0))
	if _notification_history_panel:
		_notification_history_panel.position = Vector2(maxf(size.x - _notification_history_panel.size.x - 8.0, 8.0), maxf(size.y - TASKBAR_HEIGHT - _notification_history_panel.size.y - 6.0, 8.0))
	_clamp_all_desktop_icon_positions()
	if _desktop_drag_rect and _desktop_drag_selecting:
		_update_desktop_drag_rect_visual()
	for key in _open_windows.keys():
		var window := _open_windows[key] as OSWindow
		if is_instance_valid(window) and window.visible:
			_clamp_window_to_layer(window)

func _default_window_size(app_id: String) -> Vector2:
	match app_id:
		"files":
			return Vector2(820, 520)
		"console":
			return Vector2(680, 430)
		"system":
			return Vector2(560, 240)
		_:
			return Vector2(560, 380)

func _center_window_position(window: OSWindow) -> Vector2:
	if not _window_layer:
		return Vector2.ZERO
	return Vector2(
		maxf((_window_layer.size.x - window.size.x) * 0.5, 0.0),
		maxf((_window_layer.size.y - window.size.y) * 0.5, 0.0)
	)

func _clamp_window_to_layer(window: OSWindow) -> void:
	if not _window_layer:
		return
	var max_x := maxf(_window_layer.size.x - window.size.x, 0.0)
	var max_y := maxf(_window_layer.size.y - window.size.y, 0.0)
	window.position = Vector2(clampf(window.position.x, 0.0, max_x), clampf(window.position.y, 0.0, max_y))

func _focus_window(window: OSWindow) -> void:
	_active_window = window
	for key in _open_windows.keys():
		var other := _open_windows[key] as OSWindow
		if is_instance_valid(other):
			other.set_active(other == window)
	window.visible = true
	window.move_to_front()
	_update_task_button(window.app_id, true)
	_emit_hermes_event("window.focused", {
		"window_id": _window_id(window),
		"app_id": window.app_id
	})

func _on_window_close_requested(window: OSWindow) -> void:
	var app_id := window.app_id
	var window_id := _window_id(window)
	if _active_window == window:
		_active_window = null
	if _open_windows.has(app_id):
		_open_windows.erase(app_id)
	if _task_buttons.has(app_id):
		var button := _task_buttons[app_id] as Button
		if is_instance_valid(button):
			button.queue_free()
		_task_buttons.erase(app_id)
	window.queue_free()
	_emit_hermes_event("window.closed", {"window_id": window_id, "app_id": app_id})
	_emit_hermes_event("app.closed", {"app_id": app_id})

func _on_window_minimize_requested(window: OSWindow) -> void:
	if _active_window == window:
		_active_window = null
	window.visible = false
	_update_task_button(window.app_id, false)
	_emit_hermes_event("window.minimized", {"window_id": _window_id(window), "app_id": window.app_id})

func _create_task_button(app_id: String) -> void:
	if _task_buttons.has(app_id):
		return
	var app: Dictionary = _apps[app_id]
	var button := _button(str(app["title"]), Vector2(112, 0))
	button.pressed.connect(_on_task_button_pressed.bind(app_id))
	_taskbar_windows.add_child(button)
	_task_buttons[app_id] = button

func _update_task_button(app_id: String, active: bool) -> void:
	if not _task_buttons.has(app_id):
		return
	var button := _task_buttons[app_id] as Button
	if not is_instance_valid(button):
		return
	if active:
		button.add_theme_stylebox_override("normal", _style(SURFACE_HOVER, FOCUS, 1, 6))
		button.add_theme_color_override("font_color", TEXT)
	else:
		button.add_theme_stylebox_override("normal", _style(SURFACE, BORDER, 1, 6))
		button.add_theme_color_override("font_color", MUTED)

func _on_task_button_pressed(app_id: String) -> void:
	if not _open_windows.has(app_id):
		launch_app(app_id)
		return
	var window := _open_windows[app_id] as OSWindow
	if window.visible:
		_on_window_minimize_requested(window)
	else:
		_focus_window(window)

func _close_active_window() -> void:
	if _active_window and is_instance_valid(_active_window):
		_on_window_close_requested(_active_window)

func _focus_next_window() -> void:
	var visible_windows: Array[OSWindow] = []
	for app_id in _app_order:
		if _open_windows.has(app_id):
			var window := _open_windows[app_id] as OSWindow
			if is_instance_valid(window) and window.visible:
				visible_windows.append(window)
	if visible_windows.is_empty():
		return
	var next_index := 0
	if _active_window and is_instance_valid(_active_window):
		var current_index := visible_windows.find(_active_window)
		if current_index != -1:
			next_index = (current_index + 1) % visible_windows.size()
	_focus_window(visible_windows[next_index])

func _toggle_launcher() -> void:
	if not _session_active:
		return
	_hide_desktop_context_menu()
	if _session_menu:
		_session_menu.visible = false
	_launcher.visible = not _launcher.visible
	if _launcher.visible:
		_launcher.move_to_front()

func _toggle_session_menu() -> void:
	if not _session_active:
		return
	_hide_desktop_context_menu()
	if _launcher:
		_launcher.visible = false
	_session_menu.visible = not _session_menu.visible
	if _session_menu.visible:
		_session_menu.move_to_front()

func _update_clock() -> void:
	if _user_button:
		_user_button.text = _fs.current_user() + "  " + _fs.home_path()
	if not _clock_label:
		return
	var now := Time.get_datetime_dict_from_system()
	_clock_label.text = "%02d:%02d" % [now.hour, now.minute]

func login_session(username: String, password := "") -> String:
	var clean := _fs.clean_username(username)
	var auth := _fs.authenticate_user(clean, password)
	if not bool(auth.get("ok", false)):
		return str(auth.get("error", "Authentication failed"))
	var previous_user := _fs.current_user()
	var was_active := _session_active
	var message := _fs.set_current_user(clean)
	if message != "":
		return message
	if previous_user != clean or not was_active:
		_close_all_windows()
	_session_active = true
	_hide_auth_screen()
	_refresh_desktop_icons()
	_update_clock()
	return ""

func lock_session() -> void:
	if not _session_active:
		_show_auth_screen("login")
		return
	_show_auth_screen("locked", "Locked as " + _fs.current_user())

func switch_user_session() -> void:
	_show_auth_screen("switch", "Choose another account")

func logout_session() -> void:
	_close_all_windows()
	_session_active = false
	_refresh_desktop_icons()
	_show_auth_screen("login", "Signed out")

func _show_auth_screen(mode: String, message := "") -> void:
	_hide_auth_screen()
	_hide_desktop_context_menu()
	if _launcher:
		_launcher.visible = false
	if _session_menu:
		_session_menu.visible = false
	if _notification_history_panel:
		_notification_history_panel.visible = false

	_auth_overlay = Control.new()
	_auth_overlay.name = "AuthOverlay"
	_auth_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_auth_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_auth_overlay)
	_auth_overlay.move_to_front()

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.045, 0.055, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_auth_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 24
	center.offset_right = -24
	center.offset_top = 24
	center.offset_bottom = -24
	_auth_overlay.add_child(center)

	var card := Panel.new()
	card.custom_minimum_size = Vector2(440, 430)
	card.add_theme_stylebox_override("panel", _style(PANEL, BORDER_ACTIVE, 1, 10))
	center.add_child(card)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 22
	column.offset_right = -22
	column.offset_top = 22
	column.offset_bottom = -22
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)

	var title_text := "Sign in"
	if mode == "locked":
		title_text = "Session locked"
	elif mode == "switch":
		title_text = "Switch user"
	column.add_child(_label(title_text, 22, TEXT))

	var subtitle := _label("Choose an account and enter its password.", 13, MUTED)
	if mode == "login":
		subtitle.text = "Choose an account to start a session. Blank passwords are accepted until a password is set."
	elif mode == "locked":
		subtitle.text = "Unlock the current session, or sign in as another user."
	elif mode == "switch":
		subtitle.text = "Sign in as another user. Switching users closes the current user's app windows."
	column.add_child(subtitle)

	var users := ItemList.new()
	users.custom_minimum_size = Vector2(0, 120)
	users.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_item_list(users)
	column.add_child(users)

	for username in _fs.get_users():
		users.add_item(username + "  " + _fs.home_path(username))
		users.set_item_metadata(users.item_count - 1, username)

	var username_input := LineEdit.new()
	username_input.placeholder_text = "username"
	username_input.text = _fs.current_user()
	_style_line_edit(username_input)
	column.add_child(username_input)

	for index in users.item_count:
		if str(users.get_item_metadata(index)) == _fs.current_user():
			users.select(index)
			break

	var password_input := LineEdit.new()
	password_input.placeholder_text = "password"
	password_input.secret = true
	_style_line_edit(password_input)
	column.add_child(password_input)

	var status := _label(message, 12, MUTED)
	column.add_child(status)

	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 8)
	column.add_child(buttons)

	var sign_in_button := _button("Sign in", Vector2(110, 36))
	buttons.add_child(sign_in_button)

	if mode == "switch" and _session_active:
		var cancel_button := _button("Cancel", Vector2(90, 36))
		cancel_button.pressed.connect(_hide_auth_screen)
		buttons.add_child(cancel_button)

	if mode != "login":
		var logout_button := _button("Log out", Vector2(90, 36))
		logout_button.pressed.connect(logout_session)
		buttons.add_child(logout_button)

	users.item_selected.connect(func(index: int) -> void:
		username_input.text = str(users.get_item_metadata(index))
		password_input.grab_focus()
	)

	var attempt_login := func() -> void:
		var result := login_session(username_input.text, password_input.text)
		if result != "":
			_set_status(status, result, true)
			password_input.text = ""
			password_input.grab_focus()

	sign_in_button.pressed.connect(attempt_login)
	password_input.text_submitted.connect(func(_submitted: String) -> void:
		attempt_login.call()
	)
	username_input.text_submitted.connect(func(_submitted: String) -> void:
		password_input.grab_focus()
	)
	password_input.grab_focus()

func _hide_auth_screen() -> void:
	if _auth_overlay and is_instance_valid(_auth_overlay):
		_auth_overlay.queue_free()
	_auth_overlay = null

func _close_all_windows() -> void:
	_active_window = null
	for key in _open_windows.keys():
		var window := _open_windows[key] as OSWindow
		if is_instance_valid(window):
			window.queue_free()
	_open_windows.clear()
	for key in _task_buttons.keys():
		var button := _task_buttons[key] as Button
		if is_instance_valid(button):
			button.queue_free()
	_task_buttons.clear()

func _build_files_app() -> Control:
	var root := _app_root()
	root.clip_contents = true
	root.custom_minimum_size = Vector2(860, 500)
	var home := _fs.home_path()
	var state := {
		"current_path": home,
		"selected_path": "",
		"selected_type": "",
		"clipboard_path": "",
		"clipboard_mode": "",
		"history": [home],
		"history_index": 0,
		"shortcuts": _files_initial_shortcuts(home),
		"shortcut_selected_index": -1,
		"shortcut_dialog_mode": "add",
		"shortcut_dialog_index": -1
	}

	var menu_bar := HBoxContainer.new()
	menu_bar.add_theme_constant_override("separation", 4)
	root.add_child(menu_bar)
	for menu_name in ["File", "Edit", "View", "Sort"]:
		menu_bar.add_child(_files_menu_button(menu_name))

	var frame := HSplitContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.split_offset = 228
	root.add_child(frame)

	var sidebar_panel := PanelContainer.new()
	sidebar_panel.custom_minimum_size = Vector2(230, 0)
	var sidebar_style := _style(Color("252932"), Color("2f3440"), 1, 10)
	sidebar_style.content_margin_left = 12
	sidebar_style.content_margin_right = 12
	sidebar_style.content_margin_top = 10
	sidebar_style.content_margin_bottom = 10
	sidebar_panel.add_theme_stylebox_override("panel", sidebar_style)
	frame.add_child(sidebar_panel)

	var sidebar := VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 4)
	sidebar_panel.add_child(sidebar)

	var shortcuts_list := ItemList.new()
	shortcuts_list.custom_minimum_size = Vector2(0, 220)
	shortcuts_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shortcuts_list.select_mode = ItemList.SELECT_SINGLE
	shortcuts_list.allow_reselect = true
	_style_item_list(shortcuts_list)
	sidebar.add_child(shortcuts_list)
	var shortcuts_context_menu := PopupMenu.new()
	shortcuts_context_menu.hide_on_item_selection = true
	shortcuts_context_menu.add_item("Open", 0)
	shortcuts_context_menu.add_separator()
	shortcuts_context_menu.add_item("Add shortcut…", 1)
	shortcuts_context_menu.add_item("Edit shortcut…", 2)
	shortcuts_context_menu.add_item("Delete shortcut", 3)
	shortcuts_context_menu.add_separator()
	shortcuts_context_menu.add_item("Move up", 4)
	shortcuts_context_menu.add_item("Move down", 5)
	sidebar.add_child(shortcuts_context_menu)

	var side_separator_1 := HSeparator.new()
	sidebar.add_child(side_separator_1)
	var shortcuts_dialog := PopupPanel.new()
	shortcuts_dialog.visible = false
	shortcuts_dialog.size = Vector2(360, 154)
	shortcuts_dialog.add_theme_stylebox_override("panel", _style(Color("252932"), BORDER_ACTIVE, 1, 8))
	sidebar.add_child(shortcuts_dialog)

	var shortcuts_dialog_body := VBoxContainer.new()
	shortcuts_dialog_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	shortcuts_dialog_body.offset_left = 10
	shortcuts_dialog_body.offset_right = -10
	shortcuts_dialog_body.offset_top = 10
	shortcuts_dialog_body.offset_bottom = -10
	shortcuts_dialog_body.add_theme_constant_override("separation", 8)
	shortcuts_dialog.add_child(shortcuts_dialog_body)

	var shortcut_dialog_title := Label.new()
	shortcut_dialog_title.text = "Add shortcut"
	shortcut_dialog_title.add_theme_font_size_override("font_size", 14)
	shortcut_dialog_title.add_theme_color_override("font_color", TEXT)
	shortcuts_dialog_body.add_child(shortcut_dialog_title)

	var shortcut_dialog_label_input := LineEdit.new()
	shortcut_dialog_label_input.placeholder_text = "Shortcut name"
	shortcut_dialog_label_input.custom_minimum_size = Vector2(0, 28)
	_style_line_edit(shortcut_dialog_label_input)
	shortcuts_dialog_body.add_child(shortcut_dialog_label_input)

	var shortcut_dialog_path_input := LineEdit.new()
	shortcut_dialog_path_input.placeholder_text = "Shortcut path"
	shortcut_dialog_path_input.custom_minimum_size = Vector2(0, 28)
	_style_line_edit(shortcut_dialog_path_input)
	shortcuts_dialog_body.add_child(shortcut_dialog_path_input)

	var shortcut_dialog_actions := HBoxContainer.new()
	shortcut_dialog_actions.add_theme_constant_override("separation", 6)
	shortcuts_dialog_body.add_child(shortcut_dialog_actions)
	var shortcut_dialog_cancel_button := _button("Cancel", Vector2(70, 28))
	shortcut_dialog_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcut_dialog_actions.add_child(shortcut_dialog_cancel_button)
	var shortcut_dialog_save_button := _button("Save", Vector2(70, 28))
	shortcut_dialog_save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcut_dialog_actions.add_child(shortcut_dialog_save_button)

	var shortcuts_hint := _label("Double-click a shortcut to open it", 11, MUTED)
	shortcuts_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	shortcuts_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sidebar.add_child(shortcuts_hint)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	frame.add_child(content)

	var nav_bar := HBoxContainer.new()
	nav_bar.add_theme_constant_override("separation", 6)
	content.add_child(nav_bar)

	var back_button := _files_chrome_button("◀", Vector2(34, 30))
	nav_bar.add_child(back_button)
	var forward_button := _files_chrome_button("▶", Vector2(34, 30))
	nav_bar.add_child(forward_button)
	var up_button := _files_chrome_button("↑", Vector2(34, 30))
	nav_bar.add_child(up_button)

	var breadcrumb_label := Label.new()
	breadcrumb_label.text = home
	breadcrumb_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	breadcrumb_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	breadcrumb_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	breadcrumb_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	breadcrumb_label.add_theme_font_size_override("font_size", 15)
	breadcrumb_label.add_theme_color_override("font_color", TEXT)
	nav_bar.add_child(breadcrumb_label)

	var refresh_button := _files_chrome_button("Refresh", Vector2(74, 30))
	nav_bar.add_child(refresh_button)

	var path_input := LineEdit.new()
	path_input.text = home
	path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_input.custom_minimum_size = Vector2(0, 30)
	path_input.placeholder_text = "Path"
	_style_line_edit(path_input)
	content.add_child(path_input)

	var table_header := HBoxContainer.new()
	table_header.add_theme_constant_override("separation", 0)
	content.add_child(table_header)

	var header_name := _files_table_header_label("Name")
	header_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_header.add_child(header_name)
	var header_modified := _files_table_header_label("Modified")
	header_modified.custom_minimum_size = Vector2(220, 0)
	table_header.add_child(header_modified)
	var header_size := _files_table_header_label("Size")
	header_size.custom_minimum_size = Vector2(120, 0)
	table_header.add_child(header_size)

	var tree := Tree.new()
	tree.name = "FilesTree"
	tree.columns = 3
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_SINGLE
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.column_titles_visible = false
	tree.set_column_expand(0, true)
	tree.set_column_expand(1, false)
	tree.set_column_expand(2, false)
	tree.set_column_custom_minimum_width(1, 220)
	tree.set_column_custom_minimum_width(2, 120)
	_style_files_tree(tree)
	content.add_child(tree)

	var action_bar := HFlowContainer.new()
	action_bar.add_theme_constant_override("h_separation", 6)
	action_bar.add_theme_constant_override("v_separation", 6)
	content.add_child(action_bar)

	var create_input := LineEdit.new()
	create_input.placeholder_text = "New name"
	create_input.custom_minimum_size = Vector2(164, 30)
	_style_line_edit(create_input)
	action_bar.add_child(create_input)

	var new_folder_button := _button("New folder", Vector2(92, 30))
	action_bar.add_child(new_folder_button)
	var new_file_button := _button("New file", Vector2(82, 30))
	action_bar.add_child(new_file_button)

	var rename_input := LineEdit.new()
	rename_input.placeholder_text = "Rename selected"
	rename_input.custom_minimum_size = Vector2(190, 30)
	_style_line_edit(rename_input)
	action_bar.add_child(rename_input)

	var rename_button := _button("Rename", Vector2(74, 30))
	action_bar.add_child(rename_button)
	var open_button := _button("Open", Vector2(62, 30))
	action_bar.add_child(open_button)
	var delete_button := _button("Delete", Vector2(72, 30))
	action_bar.add_child(delete_button)
	var copy_button := _button("Copy", Vector2(60, 30))
	action_bar.add_child(copy_button)
	var cut_button := _button("Cut", Vector2(54, 30))
	action_bar.add_child(cut_button)
	var paste_button := _button("Paste", Vector2(62, 30))
	action_bar.add_child(paste_button)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 10)
	content.add_child(status_row)

	var selected_label := _label("Selected: none", 12, MUTED)
	selected_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	selected_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selected_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(selected_label)

	var clipboard_label := _label("clip: empty", 12, MUTED)
	clipboard_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	clipboard_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	clipboard_label.custom_minimum_size = Vector2(280, 0)
	status_row.add_child(clipboard_label)

	var details_label := _label("", 11, MUTED)
	details_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	details_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(details_label)

	var status := _label("", 12, MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(status)

	var ui := {
		"path_input": path_input,
		"breadcrumb_label": breadcrumb_label,
		"tree": tree,
		"shortcuts_list": shortcuts_list,
		"shortcuts_context_menu": shortcuts_context_menu,
		"shortcuts_dialog": shortcuts_dialog,
		"shortcut_dialog_title": shortcut_dialog_title,
		"shortcut_dialog_label_input": shortcut_dialog_label_input,
		"shortcut_dialog_path_input": shortcut_dialog_path_input,
		"shortcut_dialog_save_button": shortcut_dialog_save_button,
		"create_input": create_input,
		"rename_input": rename_input,
		"selected_label": selected_label,
		"details_label": details_label,
		"clipboard_label": clipboard_label,
		"status": status,
		"new_folder_button": new_folder_button,
		"new_file_button": new_file_button,
		"rename_button": rename_button,
		"open_button": open_button,
		"delete_button": delete_button,
		"copy_button": copy_button,
		"cut_button": cut_button,
		"paste_button": paste_button,
		"back_button": back_button,
		"forward_button": forward_button,
		"up_button": up_button
	}

	refresh_button.pressed.connect(func() -> void:
		_refresh_files(state, ui, false, false)
	)
	back_button.pressed.connect(func() -> void:
		_files_navigate_history(-1, state, ui)
	)
	forward_button.pressed.connect(func() -> void:
		_files_navigate_history(1, state, ui)
	)
	up_button.pressed.connect(func() -> void:
		path_input.text = _fs.parent_path(str(state["current_path"]))
		_refresh_files(state, ui)
	)
	path_input.text_submitted.connect(func(_submitted: String) -> void:
		_refresh_files(state, ui)
	)
	create_input.text_changed.connect(func(_t: String) -> void:
		_update_files_action_state(state, ui)
	)
	rename_input.text_changed.connect(func(_t: String) -> void:
		_update_files_action_state(state, ui)
	)
	shortcut_dialog_label_input.text_changed.connect(func(_t: String) -> void:
		_update_files_action_state(state, ui)
	)
	shortcut_dialog_path_input.text_changed.connect(func(_t: String) -> void:
		_update_files_action_state(state, ui)
	)
	shortcuts_list.item_selected.connect(func(index: int) -> void:
		_files_select_shortcut(index, state, ui)
	)
	shortcuts_list.item_activated.connect(func(index: int) -> void:
		_files_activate_shortcut(index, state, ui)
	)
	shortcuts_list.gui_input.connect(func(event: InputEvent) -> void:
		_files_shortcuts_gui_input(event, state, ui)
	)
	shortcuts_context_menu.id_pressed.connect(func(action_id: int) -> void:
		_files_shortcuts_context_action(action_id, state, ui)
	)
	shortcut_dialog_save_button.pressed.connect(func() -> void:
		_files_commit_shortcut_dialog(state, ui)
	)
	shortcut_dialog_cancel_button.pressed.connect(func() -> void:
		(shortcuts_dialog as PopupPanel).hide()
	)
	shortcut_dialog_label_input.text_submitted.connect(func(_submitted: String) -> void:
		_files_commit_shortcut_dialog(state, ui)
	)
	shortcut_dialog_path_input.text_submitted.connect(func(_submitted: String) -> void:
		_files_commit_shortcut_dialog(state, ui)
	)

	new_folder_button.pressed.connect(func() -> void:
		var name := create_input.text.strip_edges()
		if name == "":
			_set_status(status, "Enter a folder name", true)
			return
		var message := _fs.make_dir(_fs.join_path(str(state["current_path"]), name))
		_set_status(status, message if message != "" else "Folder created")
		if message == "":
			create_input.text = ""
		_refresh_files(state, ui, false)
	)
	new_file_button.pressed.connect(func() -> void:
		var name := create_input.text.strip_edges()
		if name == "":
			_set_status(status, "Enter a file name", true)
			return
		var message := _fs.write_file(_fs.join_path(str(state["current_path"]), name), "")
		_set_status(status, message if message != "" else "File created")
		if message == "":
			create_input.text = ""
		_refresh_files(state, ui, false)
	)
	open_button.pressed.connect(func() -> void:
		var selected := str(state["selected_path"])
		if selected == "":
			_set_status(status, "Select an item first", true)
			return
		if str(state["selected_type"]) == "dir":
			path_input.text = selected
			_refresh_files(state, ui)
		else:
			_open_text_file(selected)
			_set_status(status, "Opened in Text: " + selected.get_file())
	)
	rename_button.pressed.connect(func() -> void:
		var selected := str(state["selected_path"])
		if selected == "":
			_set_status(status, "Select an item first", true)
			return
		var target_name := rename_input.text.strip_edges()
		if target_name == "":
			_set_status(status, "Enter a new name", true)
			return
		var message := _fs.rename_path(selected, target_name)
		_set_status(status, message if message != "" else "Renamed", message != "")
		if message == "":
			state["selected_path"] = ""
			state["selected_type"] = ""
			rename_input.text = ""
		_refresh_files(state, ui, false)
	)
	copy_button.pressed.connect(func() -> void:
		var selected := str(state["selected_path"])
		if selected == "":
			_set_status(status, "Select an item first", true)
			return
		state["clipboard_path"] = selected
		state["clipboard_mode"] = "copy"
		_set_status(status, "Copied to clipboard: " + selected)
		_update_files_action_state(state, ui)
	)
	cut_button.pressed.connect(func() -> void:
		var selected := str(state["selected_path"])
		if selected == "":
			_set_status(status, "Select an item first", true)
			return
		state["clipboard_path"] = selected
		state["clipboard_mode"] = "move"
		_set_status(status, "Cut to clipboard: " + selected)
		_update_files_action_state(state, ui)
	)
	paste_button.pressed.connect(func() -> void:
		var clipboard_path := str(state["clipboard_path"])
		var clipboard_mode := str(state["clipboard_mode"])
		if clipboard_path == "" or clipboard_mode == "":
			_set_status(status, "Clipboard is empty", true)
			return
		var destination := _paste_destination_path(clipboard_path, str(state["current_path"]))
		var message := _fs.move_path(clipboard_path, destination) if clipboard_mode == "move" else _fs.copy_path(clipboard_path, destination)
		_set_status(status, message if message != "" else (("Moved to " if clipboard_mode == "move" else "Copied to ") + destination), message != "")
		if message == "" and clipboard_mode == "move":
			state["clipboard_path"] = ""
			state["clipboard_mode"] = ""
		_refresh_files(state, ui, false)
	)
	delete_button.pressed.connect(func() -> void:
		var selected := str(state["selected_path"])
		if selected == "":
			_set_status(status, "Select an item first", true)
			return
		var message := _fs.delete_path(selected)
		_set_status(status, message if message != "" else "Deleted", message != "")
		if message == "":
			state["selected_path"] = ""
			state["selected_type"] = ""
		_refresh_files(state, ui, false)
	)
	tree.item_selected.connect(func() -> void:
		var selected_item := tree.get_selected()
		if selected_item == null:
			return
		_select_file_item(selected_item, state, ui)
	)
	tree.item_activated.connect(func() -> void:
		var selected_item := tree.get_selected()
		if selected_item == null:
			return
		var metadata: Dictionary = selected_item.get_metadata(0) as Dictionary
		if str(metadata.get("type", "")) == "dir":
			path_input.text = str(metadata.get("path", "/"))
			_refresh_files(state, ui)
		else:
			_select_file_item(selected_item, state, ui)
			_open_text_file(str(metadata.get("path", "")))
			_set_status(status, "Opened in Text: " + str(metadata.get("name", "")))
	)

	_files_app_state = state
	_files_app_ui = ui
	_refresh_files_shortcuts(state, ui)
	_refresh_files(state, ui)
	return root

func _refresh_files(state: Dictionary, ui: Dictionary, clear_status := true, push_history := true) -> void:
	var path_input := ui["path_input"] as LineEdit
	var breadcrumb_label := ui["breadcrumb_label"] as Label
	var tree := ui["tree"] as Tree
	var selected_label := ui["selected_label"] as Label
	var details_label := ui["details_label"] as Label
	var status := ui["status"] as Label
	var rename_input := ui["rename_input"] as LineEdit
	var path := _fs.resolve_path(path_input.text, str(state["current_path"]))
	if not _fs.is_dir(path):
		_set_status(status, "Folder not found: " + path, true)
		path_input.text = str(state["current_path"])
		return
	if not _fs.can_list_dir(path):
		_set_status(status, "Permission denied: " + path, true)
		path_input.text = str(state["current_path"])
		return

	state["current_path"] = path
	state["selected_path"] = ""
	state["selected_type"] = ""
	path_input.text = path
	breadcrumb_label.text = _files_breadcrumb_text(path)
	breadcrumb_label.tooltip_text = path
	rename_input.text = ""
	selected_label.text = "Selected: none"
	details_label.text = ""
	tree.clear()
	var root_item := tree.create_item()

	var entries := _fs.list_dir(path)
	for entry in entries:
		var item: Dictionary = entry
		var is_dir := str(item.get("type", "")) == "dir"
		var row := tree.create_item(root_item)
		var name_text := ("📁 " if is_dir else "📄 ") + str(item.get("name", ""))
		row.set_text(0, name_text)
		row.set_text(1, _files_modified_text(item))
		row.set_text(2, _files_size_text(item))
		row.set_metadata(0, item)
		row.set_tooltip_text(0, "%s\nmode: %s\nowner: %s:%s" % [str(item.get("path", "")), str(item.get("mode", "")), str(item.get("owner", "")), str(item.get("group", ""))])
		row.set_tooltip_text(1, str(item.get("path", "")))
		row.set_tooltip_text(2, str(item.get("path", "")))

	if push_history:
		_files_push_history(path, state)

	if clear_status:
		_set_status(status, "Empty folder" if entries.is_empty() else "")
	_update_files_action_state(state, ui)

func _select_file_item(item: TreeItem, state: Dictionary, ui: Dictionary) -> void:
	var selected_label := ui["selected_label"] as Label
	var details_label := ui["details_label"] as Label
	var rename_input := ui["rename_input"] as LineEdit
	var status := ui["status"] as Label
	var metadata: Dictionary = item.get_metadata(0) as Dictionary
	var selected_path := str(metadata.get("path", ""))
	var selected_type := str(metadata.get("type", ""))
	state["selected_path"] = selected_path
	state["selected_type"] = selected_type
	rename_input.text = str(metadata.get("name", ""))
	selected_label.text = "Selected: " + selected_path
	details_label.text = "Type: %s   Owner: %s:%s   Mode: %s   Size: %s" % [selected_type, str(metadata.get("owner", "")), str(metadata.get("group", "")), str(metadata.get("mode", "")), _files_size_text(metadata)]
	_set_status(status, "Folder selected. Double-click or Open to enter." if selected_type == "dir" else "")
	_update_files_action_state(state, ui)

func _update_files_action_state(state: Dictionary, ui: Dictionary) -> void:
	var create_input := ui["create_input"] as LineEdit
	var rename_input := ui["rename_input"] as LineEdit
	var clipboard_label := ui["clipboard_label"] as Label
	var new_folder_button := ui["new_folder_button"] as Button
	var new_file_button := ui["new_file_button"] as Button
	var rename_button := ui["rename_button"] as Button
	var open_button := ui["open_button"] as Button
	var delete_button := ui["delete_button"] as Button
	var copy_button := ui["copy_button"] as Button
	var cut_button := ui["cut_button"] as Button
	var paste_button := ui["paste_button"] as Button
	var back_button := ui["back_button"] as Button
	var forward_button := ui["forward_button"] as Button
	var shortcut_dialog_label_input := ui["shortcut_dialog_label_input"] as LineEdit
	var shortcut_dialog_path_input := ui["shortcut_dialog_path_input"] as LineEdit
	var shortcut_dialog_save_button := ui["shortcut_dialog_save_button"] as Button
	var has_name := create_input.text.strip_edges() != ""
	new_folder_button.disabled = not has_name
	new_file_button.disabled = not has_name
	var selected := str(state.get("selected_path", "")) != ""
	rename_button.disabled = not selected or rename_input.text.strip_edges() == ""
	open_button.disabled = not selected
	delete_button.disabled = not selected
	copy_button.disabled = not selected
	cut_button.disabled = not selected
	var clipboard_path := str(state.get("clipboard_path", ""))
	var clipboard_mode := str(state.get("clipboard_mode", ""))
	paste_button.disabled = clipboard_path == "" or clipboard_mode == ""
	clipboard_label.text = "clip: empty" if clipboard_path == "" else ("clip: " + clipboard_mode + " " + clipboard_path)
	var history_variant: Variant = state.get("history", [])
	var history: Array = history_variant if history_variant is Array else []
	var history_index := int(state.get("history_index", -1))
	back_button.disabled = history_index <= 0
	forward_button.disabled = history_index < 0 or history_index >= history.size() - 1
	var has_shortcut_dialog_values := shortcut_dialog_label_input.text.strip_edges() != "" and shortcut_dialog_path_input.text.strip_edges() != ""
	shortcut_dialog_save_button.disabled = not has_shortcut_dialog_values

func _files_initial_shortcuts(home: String) -> Array[Dictionary]:
	if _files_shortcuts.is_empty():
		_files_shortcuts = _files_default_shortcuts(home)
	else:
		_files_shortcuts = _files_sanitize_shortcuts(_files_shortcuts, home)
	return _files_shortcuts.duplicate(true)

func _files_default_shortcuts(home: String) -> Array[Dictionary]:
	return [
		{"label": "Recents", "path": home},
		{"label": "Home", "path": home},
		{"label": "Documents", "path": _fs.join_path(home, "Documents")},
		{"label": "Downloads", "path": _fs.join_path(home, "Downloads")},
		{"label": "Music", "path": _fs.join_path(home, "Music")},
		{"label": "Pictures", "path": _fs.join_path(home, "Pictures")},
		{"label": "Videos", "path": _fs.join_path(home, "Videos")},
		{"label": "Create", "path": _fs.join_path(home, "Create")},
		{"label": "Trash", "path": home},
		{"label": "Networks", "path": home}
	]

func _files_sanitize_shortcuts(value: Variant, home: String) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if not (item is Dictionary):
				continue
			var shortcut: Dictionary = item
			var label := str(shortcut.get("label", "")).strip_edges()
			var path := str(shortcut.get("path", "")).strip_edges()
			if label == "" or path == "":
				continue
			output.append({
				"label": label,
				"path": _fs.normalize_path(path)
			})
	if output.is_empty():
		output = _files_default_shortcuts(home)
	return output

func _files_sync_shortcuts_from_state(state: Dictionary) -> Array[Dictionary]:
	var shortcuts_variant: Variant = state.get("shortcuts", [])
	var sanitized := _files_sanitize_shortcuts(shortcuts_variant, _fs.home_path())
	state["shortcuts"] = sanitized.duplicate(true)
	_files_shortcuts = sanitized.duplicate(true)
	return sanitized

func _refresh_files_shortcuts(state: Dictionary, ui: Dictionary) -> void:
	var shortcuts_list := ui["shortcuts_list"] as ItemList
	var shortcuts := _files_sync_shortcuts_from_state(state)
	shortcuts_list.clear()
	for shortcut in shortcuts:
		shortcuts_list.add_item(str(shortcut.get("label", "")))
	var selected_index := clampi(int(state.get("shortcut_selected_index", -1)), -1, shortcuts.size() - 1)
	state["shortcut_selected_index"] = selected_index
	shortcuts_list.deselect_all()
	if selected_index >= 0 and selected_index < shortcuts.size():
		shortcuts_list.select(selected_index)
	_update_files_action_state(state, ui)

func _files_select_shortcut(index: int, state: Dictionary, ui: Dictionary) -> void:
	state["shortcut_selected_index"] = index
	_refresh_files_shortcuts(state, ui)

func _files_activate_shortcut(index: int, state: Dictionary, ui: Dictionary) -> void:
	state["shortcut_selected_index"] = index
	var shortcuts := _files_sync_shortcuts_from_state(state)
	if index < 0 or index >= shortcuts.size():
		return
	var shortcut: Dictionary = shortcuts[index]
	var target_path := _fs.normalize_path(str(shortcut.get("path", "")))
	if not _fs.is_dir(target_path):
		_set_status(ui["status"] as Label, "Folder not found: " + target_path, true)
		_update_files_action_state(state, ui)
		return
	var path_input := ui["path_input"] as LineEdit
	path_input.text = target_path
	_refresh_files(state, ui)

func _files_shortcuts_gui_input(event: InputEvent, state: Dictionary, ui: Dictionary) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_RIGHT or not mouse.pressed:
		return
	var shortcuts_list := ui["shortcuts_list"] as ItemList
	var index := shortcuts_list.get_item_at_position(mouse.position, true)
	state["shortcut_selected_index"] = index
	if index >= 0:
		shortcuts_list.select(index)
	else:
		shortcuts_list.deselect_all()
	_files_show_shortcuts_context_menu(mouse.global_position, state, ui)
	get_viewport().set_input_as_handled()

func _files_show_shortcuts_context_menu(global_position: Vector2, state: Dictionary, ui: Dictionary) -> void:
	var menu := ui["shortcuts_context_menu"] as PopupMenu
	var shortcuts := _files_sync_shortcuts_from_state(state)
	var index := int(state.get("shortcut_selected_index", -1))
	var has_selection := index >= 0 and index < shortcuts.size()
	menu.set_item_disabled(menu.get_item_index(0), not has_selection)
	menu.set_item_disabled(menu.get_item_index(2), not has_selection)
	menu.set_item_disabled(menu.get_item_index(3), not has_selection)
	menu.set_item_disabled(menu.get_item_index(4), not has_selection or index <= 0)
	menu.set_item_disabled(menu.get_item_index(5), not has_selection or index >= shortcuts.size() - 1)
	menu.popup(Rect2i(int(global_position.x), int(global_position.y), 1, 1))

func _files_shortcuts_context_action(action_id: int, state: Dictionary, ui: Dictionary) -> void:
	match action_id:
		0:
			_files_activate_shortcut(int(state.get("shortcut_selected_index", -1)), state, ui)
		1:
			_files_open_shortcut_dialog("add", -1, state, ui)
		2:
			_files_open_shortcut_dialog("edit", int(state.get("shortcut_selected_index", -1)), state, ui)
		3:
			_files_delete_shortcut(state, ui)
		4:
			_files_move_shortcut(-1, state, ui)
		5:
			_files_move_shortcut(1, state, ui)

func _files_open_shortcut_dialog(mode: String, index: int, state: Dictionary, ui: Dictionary) -> void:
	var dialog := ui["shortcuts_dialog"] as PopupPanel
	var title := ui["shortcut_dialog_title"] as Label
	var label_input := ui["shortcut_dialog_label_input"] as LineEdit
	var path_input := ui["shortcut_dialog_path_input"] as LineEdit
	var shortcuts := _files_sync_shortcuts_from_state(state)
	if mode == "edit":
		if index < 0 or index >= shortcuts.size():
			_set_status(ui["status"] as Label, "Select a shortcut first", true)
			return
		var shortcut: Dictionary = shortcuts[index]
		state["shortcut_dialog_mode"] = "edit"
		state["shortcut_dialog_index"] = index
		title.text = "Edit shortcut"
		label_input.text = str(shortcut.get("label", ""))
		path_input.text = str(shortcut.get("path", ""))
	else:
		state["shortcut_dialog_mode"] = "add"
		state["shortcut_dialog_index"] = -1
		title.text = "Add shortcut"
		label_input.text = ""
		path_input.text = str(state.get("current_path", _fs.home_path()))
	dialog.popup_centered()
	label_input.grab_focus()
	label_input.select_all()
	_update_files_action_state(state, ui)

func _files_commit_shortcut_dialog(state: Dictionary, ui: Dictionary) -> void:
	var dialog := ui["shortcuts_dialog"] as PopupPanel
	var label_input := ui["shortcut_dialog_label_input"] as LineEdit
	var path_input := ui["shortcut_dialog_path_input"] as LineEdit
	var label := label_input.text.strip_edges()
	var path := path_input.text.strip_edges()
	if label == "" or path == "":
		_set_status(ui["status"] as Label, "Shortcut name and path are required", true)
		_update_files_action_state(state, ui)
		return
	var mode := str(state.get("shortcut_dialog_mode", "add"))
	if mode == "edit":
		_files_rename_shortcut(state, ui, label, path)
	else:
		_files_add_shortcut(state, ui, label, path)
	dialog.hide()

func _files_add_shortcut(state: Dictionary, ui: Dictionary, label: String, path: String) -> void:
	var shortcuts := _files_sync_shortcuts_from_state(state)
	shortcuts.append({"label": label, "path": _fs.normalize_path(path)})
	state["shortcuts"] = shortcuts
	state["shortcut_selected_index"] = shortcuts.size() - 1
	_files_shortcuts = shortcuts.duplicate(true)
	_set_status(ui["status"] as Label, "Shortcut added")
	_refresh_files_shortcuts(state, ui)

func _files_rename_shortcut(state: Dictionary, ui: Dictionary, label: String, path: String) -> void:
	var status := ui["status"] as Label
	var index := int(state.get("shortcut_selected_index", -1))
	var shortcuts := _files_sync_shortcuts_from_state(state)
	if index < 0 or index >= shortcuts.size():
		_set_status(status, "Select a shortcut first", true)
		return
	shortcuts[index] = {"label": label, "path": _fs.normalize_path(path)}
	state["shortcuts"] = shortcuts
	_files_shortcuts = shortcuts.duplicate(true)
	_set_status(status, "Shortcut updated")
	_refresh_files_shortcuts(state, ui)

func _files_delete_shortcut(state: Dictionary, ui: Dictionary) -> void:
	var status := ui["status"] as Label
	var index := int(state.get("shortcut_selected_index", -1))
	var shortcuts := _files_sync_shortcuts_from_state(state)
	if index < 0 or index >= shortcuts.size():
		_set_status(status, "Select a shortcut first", true)
		return
	shortcuts.remove_at(index)
	state["shortcuts"] = shortcuts
	state["shortcut_selected_index"] = clampi(index, -1, shortcuts.size() - 1)
	_files_shortcuts = shortcuts.duplicate(true)
	_set_status(status, "Shortcut deleted")
	_refresh_files_shortcuts(state, ui)

func _files_move_shortcut(direction: int, state: Dictionary, ui: Dictionary) -> void:
	var status := ui["status"] as Label
	var index := int(state.get("shortcut_selected_index", -1))
	var shortcuts := _files_sync_shortcuts_from_state(state)
	if index < 0 or index >= shortcuts.size():
		_set_status(status, "Select a shortcut first", true)
		return
	var target_index := index + direction
	if target_index < 0 or target_index >= shortcuts.size():
		return
	var moving: Dictionary = shortcuts[index]
	shortcuts.remove_at(index)
	shortcuts.insert(target_index, moving)
	state["shortcuts"] = shortcuts
	state["shortcut_selected_index"] = target_index
	_files_shortcuts = shortcuts.duplicate(true)
	_set_status(status, "Shortcut order updated")
	_refresh_files_shortcuts(state, ui)

func _files_navigate_history(direction: int, state: Dictionary, ui: Dictionary) -> void:
	var history_variant: Variant = state.get("history", [])
	var history: Array = history_variant if history_variant is Array else []
	if history.is_empty():
		return
	var index := int(state.get("history_index", history.size() - 1))
	var target_index := clampi(index + direction, 0, history.size() - 1)
	if target_index == index:
		return
	state["history_index"] = target_index
	var target := str(history[target_index])
	var path_input := ui["path_input"] as LineEdit
	path_input.text = target
	_refresh_files(state, ui, false, false)

func _files_push_history(path: String, state: Dictionary) -> void:
	var history_variant: Variant = state.get("history", [])
	var history: Array = history_variant if history_variant is Array else []
	var index := int(state.get("history_index", history.size() - 1))
	if index < history.size() - 1:
		history = history.slice(0, index + 1)
	if history.is_empty() or str(history[history.size() - 1]) != path:
		history.append(path)
		index = history.size() - 1
	else:
		index = history.size() - 1
	state["history"] = history
	state["history_index"] = index

func _files_breadcrumb_text(path: String) -> String:
	var normalized := _fs.normalize_path(path)
	if normalized == "/":
		return "Home"
	var pieces := normalized.trim_prefix("/").split("/", false)
	if pieces.is_empty():
		return "Home"
	if pieces.size() >= 2 and pieces[0] == "home":
		pieces[0] = "Home"
	return " › ".join(PackedStringArray(pieces))

func _files_modified_text(_item: Dictionary) -> String:
	return "—"

func _files_size_text(item: Dictionary) -> String:
	if str(item.get("type", "")) == "dir":
		var children := _fs.list_dir(str(item.get("path", "")))
		var child_count := children.size()
		return "%d item%s" % [child_count, "" if child_count == 1 else "s"]
	var size_bytes := int(item.get("size", 0))
	if size_bytes < 1024:
		return "%d B" % size_bytes
	var size_kb := float(size_bytes) / 1024.0
	if size_kb < 1024.0:
		return "%.1f KB" % size_kb
	var size_mb := size_kb / 1024.0
	if size_mb < 1024.0:
		return "%.1f MB" % size_mb
	return "%.1f GB" % (size_mb / 1024.0)

func _open_files_to_path(path: String) -> void:
	var target := _fs.normalize_path(path)
	var folder_path := target
	var select_path := ""
	if _fs.is_file(target):
		folder_path = _fs.parent_path(target)
		select_path = target
	elif not _fs.is_dir(target):
		folder_path = _fs.home_path()
	var window := launch_app("files")
	if window == null:
		return
	if _files_app_state.is_empty() or _files_app_ui.is_empty():
		return
	var path_input := _files_app_ui.get("path_input", null) as LineEdit
	if path_input == null:
		return
	path_input.text = folder_path
	_refresh_files(_files_app_state, _files_app_ui)
	if select_path != "":
		_select_files_item_by_path(select_path, _files_app_state, _files_app_ui)
	_focus_window(window)

func _select_files_item_by_path(target_path: String, state: Dictionary, ui: Dictionary) -> bool:
	var tree := ui.get("tree", null) as Tree
	if tree == null:
		return false
	var root_item := tree.get_root()
	if root_item == null:
		return false
	var item := root_item.get_first_child()
	while item != null:
		var metadata: Dictionary = item.get_metadata(0) as Dictionary
		if str(metadata.get("path", "")) == target_path:
			tree.set_selected(item, 0)
			_select_file_item(item, state, ui)
			return true
		item = item.get_next()
	return false

func _paste_destination_path(source_path: String, destination_dir: String) -> String:
	var clean_source := _fs.normalize_path(source_path)
	var clean_destination_dir := _fs.normalize_path(destination_dir)
	var base_name := clean_source.get_file()
	var stem := base_name.get_basename()
	var extension := base_name.get_extension()
	var candidate_name := base_name
	var index := 1
	while _fs.exists(_fs.join_path(clean_destination_dir, candidate_name)):
		if extension == "":
			candidate_name = "%s copy%s" % [stem, "" if index == 1 else " " + str(index)]
		else:
			candidate_name = "%s copy%s.%s" % [stem, "" if index == 1 else " " + str(index), extension]
		index += 1
	return _fs.join_path(clean_destination_dir, candidate_name)

func _build_notes_app() -> Control:
	var root := _build_text_app()
	if _text_app_path_label:
		_text_app_path_label.text = "No note opened"
		_text_app_path_label.tooltip_text = ""
	if _text_app_status_label:
		_set_status(_text_app_status_label, "Notes stored in " + _notes_directory_path())
	return root

func _build_text_app() -> Control:
	var root := _app_root()

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	_text_app_path_label = Label.new()
	_text_app_path_label.text = "No file opened"
	_text_app_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_app_path_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text_app_path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_text_app_path_label.add_theme_color_override("font_color", MUTED)
	header.add_child(_text_app_path_label)

	var save_button := _button("Save", Vector2(70, 30))
	save_button.pressed.connect(func() -> void:
		if _text_app_current_path == "" or _text_app_editor == null:
			if _text_app_status_label:
				_set_status(_text_app_status_label, "No file selected", true)
			return
		var message := _fs.write_file(_text_app_current_path, _text_app_editor.text)
		if _text_app_status_label:
			_set_status(_text_app_status_label, message if message != "" else "Saved", message != "")
	)
	header.add_child(save_button)

	_text_app_editor = TextEdit.new()
	_text_app_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_app_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_app_editor.text = ""
	_text_app_editor.editable = true
	_style_text_edit(_text_app_editor)
	root.add_child(_text_app_editor)

	_text_app_status_label = _label("", 12, MUTED)
	root.add_child(_text_app_status_label)
	return root

func _open_text_file(path: String, app_id := "text") -> void:
	var target_path := _fs.normalize_path(path)
	if not _fs.is_file(target_path):
		_set_desktop_context_status("File not found: " + target_path, true)
		return
	var window := launch_app(app_id)
	if window == null:
		return
	if _text_app_editor == null:
		return
	var read_result := _fs.read_file_result(target_path)
	if not bool(read_result.get("ok", false)):
		if _text_app_status_label:
			_set_status(_text_app_status_label, str(read_result.get("error", "Could not read file")), true)
		return
	_text_app_current_path = target_path
	_text_app_editor.text = str(read_result.get("content", ""))
	_text_app_editor.editable = true
	if _text_app_path_label:
		_text_app_path_label.text = target_path
		_text_app_path_label.tooltip_text = target_path
	if _text_app_status_label:
		_set_status(_text_app_status_label, "Opened " + target_path.get_file())
	_focus_window(window)

func _build_console_app() -> Control:
	var root := _app_root()
	var state := {"cwd": _fs.home_path()}

	var output := TextEdit.new()
	output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.editable = false
	_style_text_edit(output)
	_register_console_output(output)
	output.text = _console_history_text()
	root.add_child(output)
	root.tree_exited.connect(func() -> void:
		_unregister_console_output(output)
	)

	var input := LineEdit.new()
	input.placeholder_text = _console_prompt(state)
	_style_line_edit(input)
	input.text_submitted.connect(func(command: String) -> void:
		_handle_console_command(command, input, state)
	)
	root.add_child(input)
	return root

func _handle_console_command(command: String, input: LineEdit, state: Dictionary) -> void:
	var clean := command.strip_edges()
	if clean == "":
		return
	var parts := clean.split(" ", false)
	var cmd := parts[0].to_lower()
	var result := ""

	match cmd:
		"help":
			result = "apps\nopen <app_id>\nclose <app_id>\nwindows\nnotify <title> | <body>\nnotifications\ndismiss_notifications\npwd\ncd [path]\nls [path]\nmkdir <path>\ntouch <path>\nread <path>\nwrite <path> <text>\ncp <source> <destination>\nmv <source> <destination>\nrm <path>\nstat <path>\nchmod <mode> <path>\nchown <user> <path>\nwhoami\nid [user]\nusers\nsu <user> [password]\nuseradd <user>\npasswd <new_password>\npasswd <user> <new_password>\nlock\nswitch\nlogout\ntime\nstate\nhermes <prompt>\nclear"
		"apps":
			result = _apps_text()
		"open":
			if parts.size() < 2:
				result = "Usage: open <app_id>"
			else:
				var app_id := parts[1]
				if _apps.has(app_id):
					launch_app(app_id)
					result = "Opened " + app_id
				else:
					result = "Unknown app: " + app_id
		"close":
			if parts.size() < 2:
				result = "Usage: close <app_id>"
			else:
				close_app(parts[1])
				result = "Closed " + parts[1]
		"windows":
			result = _windows_text()
		"notify":
			var body_start := clean.find("|")
			var title := clean.substr(cmd.length()).strip_edges()
			var body := ""
			if body_start >= 0:
				title = clean.substr(cmd.length(), body_start - cmd.length()).strip_edges()
				body = clean.substr(body_start + 1).strip_edges()
			if title == "":
				result = "Usage: notify <title> | <body>"
			else:
				var notification_id := notify({"title": title, "body": body, "app_id": "console", "level": "info"})
				result = "Notification created: " + notification_id
		"notifications":
			result = _notifications_text()
		"dismiss_notifications":
			clear_notifications()
			result = "Notifications dismissed"
		"pwd":
			result = str(state["cwd"])
		"cd":
			var target := _fs.home_path()
			if parts.size() >= 2:
				target = _resolve_command_path(parts[1], state)
			if not _fs.is_dir(target):
				result = "Folder not found: " + target
			elif not _fs.can_list_dir(target):
				result = "Permission denied: " + target
			else:
				state["cwd"] = target
				result = target
		"ls", "files":
			var path := str(state["cwd"])
			if parts.size() >= 2:
				path = _resolve_command_path(parts[1], state)
			result = _virtual_files_text(path)
		"mkdir":
			result = _command_requires_path(parts, "mkdir")
			if result == "":
				var message := _fs.make_dir(_resolve_command_path(parts[1], state))
				result = message if message != "" else "Folder created"
		"touch":
			result = _command_requires_path(parts, "touch")
			if result == "":
				var message := _fs.write_file(_resolve_command_path(parts[1], state), "")
				result = message if message != "" else "File created"
		"read", "cat":
			result = _command_requires_path(parts, "read")
			if result == "":
				var read_result := _fs.read_file_result(_resolve_command_path(parts[1], state))
				result = str(read_result.get("content", "")) if bool(read_result.get("ok", false)) else str(read_result.get("error", "Could not read file"))
		"write":
			if parts.size() < 3:
				result = "Usage: write <path> <text>"
			else:
				var target_path := parts[1]
				var marker_position := clean.find(target_path) + target_path.length()
				var text := clean.substr(marker_position).strip_edges()
				var message := _fs.write_file(_resolve_command_path(target_path, state), text)
				result = message if message != "" else "Saved"
		"cp":
			if parts.size() < 3:
				result = "Usage: cp <source> <destination>"
			else:
				var source := _resolve_command_path(parts[1], state)
				var destination := _resolve_command_path(parts[2], state)
				var message := _fs.copy_path(source, destination)
				result = message if message != "" else "Copied"
		"mv":
			if parts.size() < 3:
				result = "Usage: mv <source> <destination>"
			else:
				var source := _resolve_command_path(parts[1], state)
				var destination := _resolve_command_path(parts[2], state)
				var message := _fs.move_path(source, destination)
				result = message if message != "" else "Moved"
		"rm":
			result = _command_requires_path(parts, "rm")
			if result == "":
				var message := _fs.delete_path(_resolve_command_path(parts[1], state))
				result = message if message != "" else "Deleted"
		"stat":
			result = _command_requires_path(parts, "stat")
			if result == "":
				result = _fs.stat_text(_resolve_command_path(parts[1], state))
		"chmod":
			if parts.size() < 3:
				result = "Usage: chmod <mode> <path>"
			else:
				var message := _fs.set_mode(_resolve_command_path(parts[2], state), parts[1])
				result = message if message != "" else "Mode changed"
		"chown":
			if parts.size() < 3:
				result = "Usage: chown <user> <path>"
			else:
				var message := _fs.set_owner(_resolve_command_path(parts[2], state), parts[1])
				result = message if message != "" else "Owner changed"
		"whoami":
			result = _fs.current_user()
		"id":
			result = _fs.user_id_text(parts[1] if parts.size() >= 2 else "")
		"users":
			result = "\n".join(_fs.get_users())
		"su":
			if parts.size() < 2:
				result = "Usage: su <user> [password]"
			else:
				var target_user := _fs.clean_username(parts[1])
				var password := parts[2] if parts.size() >= 3 else ""
				var message := ""
				if _fs.current_user() == OSFileSystem.ROOT_USER:
					message = _fs.set_current_user(target_user)
				else:
					message = _fs.set_current_user_authenticated(target_user, password)
				if message == "":
					state["cwd"] = _fs.home_path()
					_update_clock()
					result = "Switched to " + _fs.current_user()
				else:
					result = message
		"useradd":
			if parts.size() < 2:
				result = "Usage: useradd <user>"
			else:
				var message := _fs.add_user(parts[1])
				result = message if message != "" else "User created: " + _fs.clean_username(parts[1])
		"passwd":
			if parts.size() < 2:
				result = "Usage: passwd <new_password> or passwd <user> <new_password>"
			else:
				var target_user := _fs.current_user()
				var new_password := parts[1]
				var current_password := parts[2] if parts.size() >= 3 else ""
				if _fs.current_user() == OSFileSystem.ROOT_USER and parts.size() >= 3:
					target_user = parts[1]
					new_password = parts[2]
					current_password = ""
				var message := _fs.set_user_password(target_user, new_password, current_password)
				result = message if message != "" else "Password updated for " + _fs.clean_username(target_user)
		"lock":
			lock_session()
			result = "Session locked"
		"switch":
			switch_user_session()
			result = "Switch user"
		"logout":
			logout_session()
			result = "Logged out"
		"time":
			result = _time_text()
		"state":
			result = JSON.stringify(hermes_get_state({"include_apps": true, "include_windows": true, "include_filesystem": false}), "\t")
		"hermes":
			var prompt := clean.substr(cmd.length()).strip_edges()
			if prompt == "":
				result = "Usage: hermes <prompt>"
			else:
				var bridge_state := _kernel_bridge_state()
				if not bool(bridge_state.get("connected", false)):
					result = "Hermes bridge is disconnected. Open System app and connect first."
				else:
					_emit_hermes_event("terminal.chat_prompt", {
						"prompt": prompt,
						"cwd": str(state.get("cwd", _fs.home_path())),
						"user": _fs.current_user(),
						"timestamp": int(Time.get_unix_time_from_system())
					})
					result = "Sent to Hermes: " + prompt
		"clear":
			_console_history.clear()
			_refresh_console_outputs()
			input.text = ""
			input.placeholder_text = _console_prompt(state)
			return
		_:
			result = "Unknown command: " + cmd

	_append_console_entry(_console_prompt(state), clean, result)
	input.text = ""
	input.placeholder_text = _console_prompt(state)

func _register_console_output(output: TextEdit) -> void:
	if output == null:
		return
	if not _console_outputs.has(output):
		_console_outputs.append(output)

func _unregister_console_output(output: TextEdit) -> void:
	if output == null:
		return
	_console_outputs.erase(output)

func _console_history_text() -> String:
	if _console_history.is_empty():
		return ""
	return "\n".join(_console_history)

func _refresh_console_outputs() -> void:
	var history_text := _console_history_text()
	for i in range(_console_outputs.size() - 1, -1, -1):
		var output := _console_outputs[i]
		if output == null or not is_instance_valid(output):
			_console_outputs.remove_at(i)
			continue
		output.text = history_text
		output.scroll_vertical = max(output.get_line_count() - 1, 0)

func _append_console_entry(prompt: String, command: String, result: String) -> void:
	if _console_history.is_empty():
		_console_history.append("Type 'help' for commands. Current user: " + _fs.current_user())
	var command_line := prompt
	if command.strip_edges() != "":
		command_line += " " + command
	_console_history.append(command_line)
	_console_history.append(result)
	if _console_history.size() > CONSOLE_HISTORY_MAX_LINES:
		_console_history = _console_history.slice(_console_history.size() - CONSOLE_HISTORY_MAX_LINES, _console_history.size())
	_refresh_console_outputs()

func _append_hermes_terminal_output(text: String, source := "Hermes") -> void:
	var clean_source := source.strip_edges()
	if clean_source == "":
		clean_source = "Hermes"
	var message := text.strip_edges()
	_append_console_entry("[" + clean_source + "]", "", message if message != "" else "(no output)")

func _console_prompt(state: Dictionary) -> String:
	var symbol := "#" if _fs.current_user() == OSFileSystem.ROOT_USER else "$"
	return _fs.current_user() + ":" + str(state.get("cwd", _fs.home_path())) + symbol

func _resolve_command_path(path: String, state: Dictionary) -> String:
	return _fs.resolve_path(path, str(state.get("cwd", _fs.home_path())))

func _build_system_app() -> Control:
	var root := _app_root()
	root.custom_minimum_size = Vector2(520, 280)
	root.set_meta("window_min_size", Vector2(500, 280))

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

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

	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_theme_color_override("font_color", TEXT)
	info_scroll.add_child(info)
	_update_system_info(info)

	var bridge_panel := VBoxContainer.new()
	bridge_panel.add_theme_constant_override("separation", 6)
	system_tab.add_child(bridge_panel)
	bridge_panel.add_child(_label("Hermes bridge", 12, TEXT))

	var bridge_row := HBoxContainer.new()
	bridge_row.add_theme_constant_override("separation", 8)
	bridge_panel.add_child(bridge_row)

	var bridge_endpoint_input := LineEdit.new()
	bridge_endpoint_input.placeholder_text = "ws://127.0.0.1:8787/hermesos/ws"
	bridge_endpoint_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(bridge_endpoint_input)
	bridge_row.add_child(bridge_endpoint_input)

	var bridge_connect_button := _button("Connect", Vector2(92, 30))
	bridge_row.add_child(bridge_connect_button)
	var bridge_disconnect_button := _button("Disconnect", Vector2(104, 30))
	bridge_row.add_child(bridge_disconnect_button)

	var bridge_status_label := _label("Bridge: unavailable", 11, MUTED)
	bridge_panel.add_child(bridge_status_label)

	var refresh_bridge_status := func() -> void:
		var state := _kernel_bridge_state()
		bridge_endpoint_input.text = str(state.get("endpoint", ""))
		var connected := bool(state.get("connected", false))
		bridge_status_label.text = "Bridge: connected" if connected else "Bridge: disconnected"
		bridge_status_label.add_theme_color_override("font_color", TEXT if connected else MUTED)
		_update_system_info(info)

	refresh_bridge_status.call()
	var bridge_kernel := _hermes_kernel_node()
	if bridge_kernel != null:
		if bridge_kernel.has_signal("bridge_connected") and not bridge_kernel.bridge_connected.is_connected(refresh_bridge_status):
			bridge_kernel.bridge_connected.connect(refresh_bridge_status)
		if bridge_kernel.has_signal("bridge_disconnected") and not bridge_kernel.bridge_disconnected.is_connected(refresh_bridge_status):
			bridge_kernel.bridge_disconnected.connect(refresh_bridge_status)
	bridge_connect_button.pressed.connect(func() -> void:
		var kernel := _hermes_kernel_node()
		if kernel == null or not kernel.has_method("connect_bridge"):
			_set_status(bridge_status_label, "Hermes kernel unavailable", true)
			return
		var endpoint := bridge_endpoint_input.text.strip_edges()
		var message := str(kernel.call("connect_bridge", endpoint))
		if message != "":
			_set_status(bridge_status_label, message, true)
		else:
			_set_status(bridge_status_label, "Connecting...", false)
		refresh_bridge_status.call()
	)
	bridge_disconnect_button.pressed.connect(func() -> void:
		var kernel := _hermes_kernel_node()
		if kernel == null or not kernel.has_method("disconnect_bridge"):
			_set_status(bridge_status_label, "Hermes kernel unavailable", true)
			return
		kernel.call("disconnect_bridge")
		_set_status(bridge_status_label, "Disconnected", false)
		refresh_bridge_status.call()
	)

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

	appearance_card.add_child(_label("Desktop appearance", 13, TEXT))
	appearance_card.add_child(_label("Selection and drag highlight", 11, MUTED))

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 8)
	appearance_card.add_child(preset_row)
	var preset_label := _label("Highlight", 12, TEXT)
	preset_label.custom_minimum_size = Vector2(104, 0)
	preset_row.add_child(preset_label)

	var preset_option := OptionButton.new()
	preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_option.custom_minimum_size = Vector2(220, 30)
	preset_option.add_theme_color_override("font_color", TEXT)
	preset_option.add_theme_stylebox_override("normal", _style(SURFACE, BORDER, 1, 6))
	preset_option.add_theme_stylebox_override("hover", _style(SURFACE_HOVER, BORDER_ACTIVE, 1, 6))
	preset_option.add_theme_stylebox_override("focus", _style(SURFACE_HOVER, FOCUS, 2, 6))
	var presets := _desktop_highlight_presets()
	for preset in presets:
		preset_option.add_item(str(preset.get("label", "Color")))
	preset_option.item_selected.connect(func(index: int) -> void:
		if index < 0 or index >= presets.size():
			return
		var preset: Dictionary = presets[index]
		var color: Color = preset.get("color", _desktop_highlight_color)
		_set_desktop_highlight_color(Color(color.r, color.g, color.b, _desktop_highlight_color.a))
		_set_desktop_context_status("Desktop highlight color updated")
	)
	preset_row.add_child(preset_option)

	var alpha_row := HBoxContainer.new()
	alpha_row.add_theme_constant_override("separation", 8)
	appearance_card.add_child(alpha_row)
	var alpha_label := _label("Opacity", 12, TEXT)
	alpha_label.custom_minimum_size = Vector2(104, 0)
	alpha_row.add_child(alpha_label)
	var alpha_slider := HSlider.new()
	alpha_slider.min_value = 0.14
	alpha_slider.max_value = 0.7
	alpha_slider.step = 0.01
	alpha_slider.value = _desktop_highlight_color.a
	alpha_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alpha_slider.custom_minimum_size = Vector2(190, 0)
	alpha_row.add_child(alpha_slider)
	var alpha_value := _label("%d%%" % int(round(_desktop_highlight_color.a * 100.0)), 12, MUTED)
	alpha_value.custom_minimum_size = Vector2(44, 0)
	alpha_row.add_child(alpha_value)
	alpha_slider.value_changed.connect(func(value: float) -> void:
		_set_desktop_highlight_color(Color(_desktop_highlight_color.r, _desktop_highlight_color.g, _desktop_highlight_color.b, value))
		alpha_value.text = "%d%%" % int(round(value * 100.0))
	)

	var controls_row := HFlowContainer.new()
	controls_row.add_theme_constant_override("h_separation", 8)
	controls_row.add_theme_constant_override("v_separation", 8)
	appearance_card.add_child(controls_row)
	var wallpaper_button := _button("Cycle wallpaper", Vector2(132, 30))
	wallpaper_button.pressed.connect(_cycle_wallpaper)
	controls_row.add_child(wallpaper_button)
	var reset_layout_button := _button("Reset icon layout", Vector2(132, 30))
	reset_layout_button.pressed.connect(func() -> void:
		_desktop_icon_positions.clear()
		_refresh_desktop_icons()
		_set_desktop_context_status("Desktop icon layout reset")
	)
	controls_row.add_child(reset_layout_button)
	var reset_highlight_button := _button("Reset highlight", Vector2(120, 30))
	reset_highlight_button.pressed.connect(func() -> void:
		_set_desktop_highlight_color(Color(0.34, 0.45, 0.62, 0.32))
		alpha_slider.value = _desktop_highlight_color.a
		alpha_value.text = "%d%%" % int(round(_desktop_highlight_color.a * 100.0))
		_set_desktop_context_status("Desktop highlight color reset")
	)
	controls_row.add_child(reset_highlight_button)

	for i in presets.size():
		var preset: Dictionary = presets[i]
		if (preset.get("color", Color.WHITE) as Color).is_equal_approx(Color(_desktop_highlight_color.r, _desktop_highlight_color.g, _desktop_highlight_color.b, 1.0)):
			preset_option.select(i)
			break

	return root

func _desktop_highlight_presets() -> Array[Dictionary]:
	return [
		{"label": "Ocean blue", "color": Color(0.34, 0.45, 0.62, 1.0)},
		{"label": "Mint green", "color": Color(0.35, 0.63, 0.46, 1.0)},
		{"label": "Amber", "color": Color(0.73, 0.53, 0.27, 1.0)},
		{"label": "Rose", "color": Color(0.71, 0.39, 0.54, 1.0)}
	]

func _update_system_info(info: Label) -> void:
	var viewport_size := get_viewport_rect().size
	var window_size := DisplayServer.window_get_size()
	var mode := DisplayServer.window_get_mode()
	var bridge := _kernel_bridge_state()
	var bridge_status := "connected" if bool(bridge.get("connected", false)) else "disconnected"
	info.text = "Viewport: %s\nGame window: %s\nWindow mode: %s\nCurrent user: %s\nHome: %s\nUsers: %s\nFilesystem save: %s\nApps: %s\nOpen windows: %s\nBridge: %s\nBridge endpoint: %s" % [
		str(viewport_size),
		str(window_size),
		str(mode),
		_fs.current_user(),
		_fs.home_path(),
		", ".join(_fs.get_users()),
		OSFileSystem.SAVE_PATH,
		_app_ids_text(),
		_windows_text(),
		bridge_status,
		str(bridge.get("endpoint", ""))
	]

func _apps_text() -> String:
	var lines: Array[String] = []
	for app_id in _app_order:
		var app: Dictionary = _apps[app_id]
		lines.append(app_id + " - " + str(app["title"]))
	return "\n".join(lines)

func _app_ids_text() -> String:
	return ", ".join(_app_order)

func _windows_text() -> String:
	if _open_windows.is_empty():
		return "none"
	var lines: Array[String] = []
	for key in _open_windows.keys():
		var window := _open_windows[key] as OSWindow
		if is_instance_valid(window):
			lines.append(str(key) + (" visible" if window.visible else " minimized"))
	return "\n".join(lines)

func _virtual_files_text(path: String) -> String:
	var normalized := _fs.normalize_path(path)
	if not _fs.is_dir(normalized):
		return "Folder not found: " + normalized
	if not _fs.can_list_dir(normalized):
		return "Permission denied: " + normalized
	var entries := _fs.list_dir(normalized)
	if entries.is_empty():
		return "Empty folder"
	var lines: Array[String] = []
	for entry in entries:
		var item: Dictionary = entry
		var name := str(item["name"])
		if str(item["type"]) == "dir":
			name += "/"
		lines.append("%s %s %s %d %s" % [str(item["mode"]), str(item["owner"]), str(item["group"]), int(item["size"]), name])
	return "\n".join(lines)

func _command_requires_path(parts: PackedStringArray, command_name: String) -> String:
	if parts.size() < 2:
		return "Usage: " + command_name + " <path>"
	return ""

func _time_text() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [now.year, now.month, now.day, now.hour, now.minute, now.second]

func _emit_hermes_event(event_name: String, payload: Dictionary = {}) -> void:
	hermes_event.emit(event_name, payload)

func _hermes_kernel_node() -> Node:
	return get_node_or_null("/root/HermesOSKernel")

func _kernel_bridge_state() -> Dictionary:
	var kernel := _hermes_kernel_node()
	if kernel == null or not kernel.has_method("get_bridge_state"):
		return {
			"connected": false,
			"endpoint": "",
			"session_id": "",
			"last_message_at": 0,
			"last_error": {},
			"metrics": {}
		}
	var state: Variant = kernel.call("get_bridge_state")
	if state is Dictionary:
		return state
	return {
		"connected": false,
		"endpoint": "",
		"session_id": "",
		"last_message_at": 0,
		"last_error": {},
		"metrics": {}
	}

func _window_id(window: OSWindow) -> String:
	return "win_%s" % str(window.get_instance_id())

func _find_window_by_id(window_id: String) -> OSWindow:
	for key in _open_windows.keys():
		var window := _open_windows[key] as OSWindow
		if is_instance_valid(window) and _window_id(window) == window_id:
			return window
	return null

func _window_state_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in _open_windows.keys():
		var window := _open_windows[key] as OSWindow
		if not is_instance_valid(window):
			continue
		result.append({
			"id": _window_id(window),
			"app_id": window.app_id,
			"title": window.app_title,
			"focused": _active_window == window,
			"minimized": not window.visible,
			"maximized": false,
			"position": [window.position.x, window.position.y],
			"size": [window.size.x, window.size.y],
			"z_index": window.get_index()
		})
	return result

func _notes_directory_path() -> String:
	return _fs.join_path(_fs.home_path(), "notes")

func _ensure_notes_directory() -> String:
	var path := _notes_directory_path()
	if _fs.is_dir(path):
		return ""
	var message := _fs.make_dir(path)
	if message.begins_with("Path already exists"):
		return ""
	return message

func _notes_slug(title: String) -> String:
	var clean := title.strip_edges().to_lower()
	if clean == "":
		clean = "untitled"
	clean = clean.replace("/", "-").replace("\\", "-").replace(":", "-").replace("*", "-").replace("?", "-").replace("\"", "-").replace("<", "-").replace(">", "-").replace("|", "-")
	while clean.find("  ") != -1:
		clean = clean.replace("  ", " ")
	clean = clean.replace(" ", "-")
	while clean.find("--") != -1:
		clean = clean.replace("--", "-")
	return clean.strip_edges()

func _note_path_from_id(note_id: String) -> String:
	if note_id.begins_with("/"):
		return _fs.normalize_path(note_id)
	var file_name := note_id.strip_edges()
	if file_name == "":
		file_name = "untitled"
	if not file_name.ends_with(".txt"):
		file_name += ".txt"
	return _fs.join_path(_notes_directory_path(), file_name)

func _create_unique_note_path(title: String) -> String:
	var slug := _notes_slug(title)
	if slug == "":
		slug = "untitled"
	var candidate := _note_path_from_id(slug)
	var suffix := 2
	while _fs.exists(candidate):
		candidate = _note_path_from_id("%s-%d" % [slug, suffix])
		suffix += 1
	return candidate

func _list_notes_state() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var notes_path := _notes_directory_path()
	if not _fs.is_dir(notes_path):
		return output
	var entries := _fs.list_dir(notes_path)
	for entry in entries:
		var item: Dictionary = entry
		if str(item.get("type", "")) != "file":
			continue
		output.append({
			"note_id": str(item.get("name", "")),
			"path": str(item.get("path", "")),
			"size": int(item.get("size", 0)),
			"owner": str(item.get("owner", ""))
		})
	return output

func _notes_create_note(title: String, content: String) -> Dictionary:
	var dir_message := _ensure_notes_directory()
	if dir_message != "":
		return {"ok": false, "error": HermesProtocol.make_error("NOTES_DIR_FAILED", dir_message)}
	var target_path := _create_unique_note_path(title)
	var write_message := _fs.write_file(target_path, content)
	if write_message != "":
		return {"ok": false, "error": HermesProtocol.make_error("WRITE_FAILED", write_message)}
	var note_id := target_path.get_file()
	_notes_active_note_id = note_id
	if not _notes_open_notes.has(note_id):
		_notes_open_notes.append(note_id)
	_emit_hermes_event("note.created", {"note_id": note_id, "path": target_path})
	_emit_hermes_event("file.created", {"path": target_path})
	return {"ok": true, "result": {"note_id": note_id, "path": target_path}}

func _notes_open_note(note_id_or_path: String) -> Dictionary:
	var dir_message := _ensure_notes_directory()
	if dir_message != "":
		return {"ok": false, "error": HermesProtocol.make_error("NOTES_DIR_FAILED", dir_message)}
	var target_path := _note_path_from_id(note_id_or_path)
	if not _fs.is_file(target_path):
		return {"ok": false, "error": HermesProtocol.make_error("NOTE_NOT_FOUND", "Note not found: " + target_path)}
	_open_text_file(target_path, "notes")
	var note_id := target_path.get_file()
	_notes_active_note_id = note_id
	if not _notes_open_notes.has(note_id):
		_notes_open_notes.append(note_id)
	var read_result := _fs.read_file_result(target_path)
	if not bool(read_result.get("ok", false)):
		return {"ok": false, "error": HermesProtocol.make_error("READ_FAILED", str(read_result.get("error", "Could not read note")))}
	return {
		"ok": true,
		"result": {
			"note_id": note_id,
			"path": target_path,
			"content": str(read_result.get("content", ""))
		}
	}

func _notes_update_note(note_id_or_path: String, content: String) -> Dictionary:
	var target_path := _note_path_from_id(note_id_or_path)
	var write_message := _fs.write_file(target_path, content)
	if write_message != "":
		return {"ok": false, "error": HermesProtocol.make_error("WRITE_FAILED", write_message)}
	var note_id := target_path.get_file()
	_notes_active_note_id = note_id
	if _text_app_current_path == target_path and _text_app_editor:
		_text_app_editor.text = content
	if not _notes_open_notes.has(note_id):
		_notes_open_notes.append(note_id)
	_emit_hermes_event("note.updated", {"note_id": note_id, "path": target_path})
	_emit_hermes_event("file.updated", {"path": target_path})
	return {"ok": true, "result": {"note_id": note_id, "path": target_path}}

func hermes_get_state(options := {}) -> Dictionary:
	var include_apps := bool(options.get("include_apps", true)) if options is Dictionary else true
	var include_windows := bool(options.get("include_windows", true)) if options is Dictionary else true
	var include_filesystem := bool(options.get("include_filesystem", false)) if options is Dictionary else false
	var snapshot := {
		"desktop": {
			"focused_window_id": _window_id(_active_window) if _active_window and is_instance_valid(_active_window) else "",
			"session_active": _session_active,
			"current_user": _fs.current_user()
		},
		"notifications": _notifications.duplicate(true),
		"bridge": _kernel_bridge_state()
	}
	if include_windows:
		snapshot["windows"] = _window_state_snapshot()
	if include_apps:
		snapshot["apps"] = {
			"notes": {
				"active_note_id": _notes_active_note_id,
				"open_notes": _notes_open_notes.duplicate(),
				"notes": _list_notes_state()
			},
			"terminal": {
				"sessions": _terminal_sessions.duplicate(true)
			}
		}
	if include_filesystem:
		snapshot["filesystem"] = _fs.export_state()
	return snapshot

func hermes_get_manifest_apps() -> Array[Dictionary]:
	return [
		{
			"id": "desktop",
			"name": "Desktop",
			"description": "Desktop shell actions",
			"actions": {
				"desktop.show_notification": {
					"description": "Display an in-OS notification",
					"args_schema": {"title": "string", "body": "string", "level": "string"}
				}
			}
		},
		{
			"id": "windows",
			"name": "Window Manager",
			"description": "Window operations",
			"actions": {
				"windows.open_app": {"description": "Open app window", "args_schema": {"app_id": "string"}},
				"windows.focus_window": {"description": "Focus a window", "args_schema": {"window_id": "string", "app_id": "string"}},
				"windows.close_window": {"description": "Close a window", "args_schema": {"window_id": "string", "app_id": "string"}}
			}
		},
		{
			"id": "files",
			"name": "Files",
			"description": "Virtual filesystem browser",
			"actions": {
				"files.list_dir": {"description": "List a directory", "args_schema": {"path": "string"}},
				"files.read_file": {"description": "Read a file", "args_schema": {"path": "string"}},
				"files.write_file": {"description": "Write a file", "args_schema": {"path": "string", "content": "string"}}
			}
		},
		{
			"id": "notes",
			"name": "Notes",
			"description": "Create and open notes",
			"actions": {
				"notes.create_note": {"description": "Create note", "args_schema": {"title": "string", "content": "string"}},
				"notes.open_note": {"description": "Open note", "args_schema": {"note_id": "string"}},
				"notes.update_note": {"description": "Update note", "args_schema": {"note_id": "string", "content": "string"}},
				"notes.list_notes": {"description": "List notes", "args_schema": {}}
			}
		},
		{
			"id": "terminal",
			"name": "Terminal",
			"description": "In-game terminal commands",
			"actions": {
				"terminal.open_session": {"description": "Open terminal session", "args_schema": {"cwd": "string"}},
				"terminal.run_command": {"description": "Run command", "args_schema": {"session_id": "string", "command": "string"}},
				"terminal.append_output": {"description": "Append text to in-game terminal transcript", "args_schema": {"text": "string", "source": "string"}}
			}
		}
	]

func hermes_execute_operation(op: String, args: Dictionary) -> Dictionary:
	match op:
		"desktop.show_notification":
			var title := str(args.get("title", "Hermes"))
			var body := str(args.get("body", ""))
			var level := str(args.get("level", "info"))
			var notification_id := notify({"title": title, "body": body, "level": level, "app_id": "hermes"})
			return {"ok": true, "result": {"displayed": true, "notification_id": notification_id}}
		"windows.open_app":
			var app_id := str(args.get("app_id", ""))
			if app_id == "":
				return {"ok": false, "error": HermesProtocol.make_error("MISSING_ARG", "windows.open_app requires app_id")}
			var window := launch_app(app_id)
			if window == null:
				return {"ok": false, "error": HermesProtocol.make_error("OPEN_FAILED", "Could not open app: " + app_id)}
			return {"ok": true, "result": {"window_id": _window_id(window), "app_id": app_id}}
		"windows.focus_window":
			var focus_window_id := str(args.get("window_id", ""))
			var focus_app_id := str(args.get("app_id", ""))
			var target_window: OSWindow = null
			if focus_window_id != "":
				target_window = _find_window_by_id(focus_window_id)
			elif focus_app_id != "" and _open_windows.has(focus_app_id):
				target_window = _open_windows[focus_app_id] as OSWindow
			if target_window == null or not is_instance_valid(target_window):
				return {"ok": false, "error": HermesProtocol.make_error("WINDOW_NOT_FOUND", "Window not found")}
			_focus_window(target_window)
			return {"ok": true, "result": {"window_id": _window_id(target_window), "app_id": target_window.app_id}}
		"windows.close_window":
			var close_window_id := str(args.get("window_id", ""))
			var close_app_id := str(args.get("app_id", ""))
			var close_window: OSWindow = null
			if close_window_id != "":
				close_window = _find_window_by_id(close_window_id)
			elif close_app_id != "" and _open_windows.has(close_app_id):
				close_window = _open_windows[close_app_id] as OSWindow
			if close_window == null or not is_instance_valid(close_window):
				return {"ok": false, "error": HermesProtocol.make_error("WINDOW_NOT_FOUND", "Window not found")}
			_on_window_close_requested(close_window)
			return {"ok": true, "result": {"closed": true}}
		"files.list_dir":
			var list_path := _fs.normalize_path(str(args.get("path", _fs.home_path())))
			if not _fs.is_dir(list_path):
				return {"ok": false, "error": HermesProtocol.make_error("DIR_NOT_FOUND", "Directory not found: " + list_path)}
			return {"ok": true, "result": {"path": list_path, "entries": _fs.list_dir(list_path)}}
		"files.read_file":
			var read_path := _fs.normalize_path(str(args.get("path", "")))
			if read_path == "":
				return {"ok": false, "error": HermesProtocol.make_error("MISSING_ARG", "files.read_file requires path")}
			var read_result := _fs.read_file_result(read_path)
			if not bool(read_result.get("ok", false)):
				return {"ok": false, "error": HermesProtocol.make_error("READ_FAILED", str(read_result.get("error", "Could not read file")))}
			return {"ok": true, "result": {"path": read_path, "content": str(read_result.get("content", ""))}}
		"files.write_file":
			var write_path := _fs.normalize_path(str(args.get("path", "")))
			if write_path == "":
				return {"ok": false, "error": HermesProtocol.make_error("MISSING_ARG", "files.write_file requires path")}
			var had_file := _fs.exists(write_path)
			var write_message := _fs.write_file(write_path, str(args.get("content", "")))
			if write_message != "":
				return {"ok": false, "error": HermesProtocol.make_error("WRITE_FAILED", write_message)}
			_emit_hermes_event("file.updated" if had_file else "file.created", {"path": write_path})
			return {"ok": true, "result": {"path": write_path, "saved": true}}
		"notes.create_note":
			return _notes_create_note(str(args.get("title", "Untitled")), str(args.get("content", "")))
		"notes.open_note":
			return _notes_open_note(str(args.get("note_id", args.get("path", ""))))
		"notes.update_note":
			return _notes_update_note(str(args.get("note_id", args.get("path", ""))), str(args.get("content", "")))
		"notes.list_notes":
			return {"ok": true, "result": {"notes": _list_notes_state(), "path": _notes_directory_path()}}
		"terminal.open_session":
			var cwd := _fs.resolve_path(str(args.get("cwd", "~")), _fs.home_path())
			if not _fs.is_dir(cwd):
				cwd = _fs.home_path()
			_terminal_session_sequence += 1
			var session_id := str(args.get("session_id", "t_%d" % _terminal_session_sequence))
			_terminal_sessions[session_id] = {"cwd": cwd, "opened_at": int(Time.get_unix_time_from_system())}
			launch_app("console")
			_emit_hermes_event("terminal.session_opened", {"session_id": session_id, "cwd": cwd})
			return {"ok": true, "result": {"session_id": session_id, "cwd": cwd}}
		"terminal.run_command":
			var command := str(args.get("command", "")).strip_edges()
			if command == "":
				return {"ok": false, "error": HermesProtocol.make_error("MISSING_ARG", "terminal.run_command requires command")}
			var terminal_session_id := str(args.get("session_id", ""))
			var terminal_state := {"cwd": _fs.home_path()}
			if terminal_session_id != "" and _terminal_sessions.has(terminal_session_id):
				terminal_state = _terminal_sessions[terminal_session_id]
			_emit_hermes_event("terminal.command_started", {"session_id": terminal_session_id, "command": command})
			var terminal_result := _execute_terminal_command(command, terminal_state)
			if terminal_session_id != "":
				_terminal_sessions[terminal_session_id] = terminal_state
			_emit_hermes_event("terminal.command_finished", {
				"session_id": terminal_session_id,
				"command": command,
				"exit_code": int(terminal_result.get("exit_code", 1))
			})
			_append_console_entry("[Hermes:" + (terminal_session_id if terminal_session_id != "" else "session") + "]", command, str(terminal_result.get("stdout", "")).strip_edges() if str(terminal_result.get("stdout", "")).strip_edges() != "" else str(terminal_result.get("stderr", "")).strip_edges())
			launch_app("console")
			return {"ok": true, "result": terminal_result}
		"terminal.append_output":
			var text := str(args.get("text", "")).strip_edges()
			if text == "":
				return {"ok": false, "error": HermesProtocol.make_error("MISSING_ARG", "terminal.append_output requires text")}
			_append_hermes_terminal_output(text, str(args.get("source", "Hermes")))
			launch_app("console")
			return {"ok": true, "result": {"appended": true}}
		_:
			return {"ok": false, "error": HermesProtocol.make_error("UNKNOWN_OPERATION", "No registered operation: " + op)}

func _execute_terminal_command(command: String, state: Dictionary) -> Dictionary:
	var clean := command.strip_edges()
	var parts := clean.split(" ", false)
	if parts.is_empty():
		return {"stdout": "", "stderr": "", "exit_code": 0, "cwd": str(state.get("cwd", _fs.home_path()))}
	var cmd := parts[0].to_lower()
	var stdout := ""
	var stderr := ""
	var exit_code := 0
	match cmd:
		"help":
			stdout = "help\nls [path]\ncat <path>\ntouch <path>\nwrite <path> <text>\nrm <path>\nclear\napps\nopen <app_id>\nstate\npwd\ncd [path]"
		"pwd":
			stdout = str(state.get("cwd", _fs.home_path()))
		"cd":
			var destination := _fs.home_path()
			if parts.size() >= 2:
				destination = _fs.resolve_path(parts[1], str(state.get("cwd", _fs.home_path())))
			if not _fs.is_dir(destination):
				exit_code = 1
				stderr = "Folder not found: " + destination
			elif not _fs.can_list_dir(destination):
				exit_code = 1
				stderr = "Permission denied: " + destination
			else:
				state["cwd"] = destination
				stdout = destination
		"ls":
			var list_path := str(state.get("cwd", _fs.home_path()))
			if parts.size() >= 2:
				list_path = _fs.resolve_path(parts[1], str(state.get("cwd", _fs.home_path())))
			if not _fs.is_dir(list_path):
				exit_code = 1
				stderr = "Folder not found: " + list_path
			else:
				var names: Array[String] = []
				for entry in _fs.list_dir(list_path):
					var item: Dictionary = entry
					var name := str(item.get("name", ""))
					if str(item.get("type", "")) == "dir":
						name += "/"
					names.append(name)
				stdout = "\n".join(names)
		"cat", "read":
			if parts.size() < 2:
				exit_code = 1
				stderr = "Usage: cat <path>"
			else:
				var target := _fs.resolve_path(parts[1], str(state.get("cwd", _fs.home_path())))
				var read_result := _fs.read_file_result(target)
				if not bool(read_result.get("ok", false)):
					exit_code = 1
					stderr = str(read_result.get("error", "Could not read file"))
				else:
					stdout = str(read_result.get("content", ""))
		"touch":
			if parts.size() < 2:
				exit_code = 1
				stderr = "Usage: touch <path>"
			else:
				var target := _fs.resolve_path(parts[1], str(state.get("cwd", _fs.home_path())))
				var message := _fs.write_file(target, "")
				if message != "":
					exit_code = 1
					stderr = message
				else:
					stdout = "File created"
		"write":
			if parts.size() < 3:
				exit_code = 1
				stderr = "Usage: write <path> <text>"
			else:
				var target_path := parts[1]
				var marker_position := clean.find(target_path) + target_path.length()
				var text := clean.substr(marker_position).strip_edges()
				var target := _fs.resolve_path(target_path, str(state.get("cwd", _fs.home_path())))
				var message := _fs.write_file(target, text)
				if message != "":
					exit_code = 1
					stderr = message
				else:
					stdout = "Saved"
		"rm":
			if parts.size() < 2:
				exit_code = 1
				stderr = "Usage: rm <path>"
			else:
				var target := _fs.resolve_path(parts[1], str(state.get("cwd", _fs.home_path())))
				var message := _fs.delete_path(target)
				if message != "":
					exit_code = 1
					stderr = message
				else:
					stdout = "Deleted"
		"apps":
			stdout = _apps_text()
		"open":
			if parts.size() < 2:
				exit_code = 1
				stderr = "Usage: open <app_id>"
			else:
				var app_id := parts[1]
				if launch_app(app_id) == null:
					exit_code = 1
					stderr = "Unknown app: " + app_id
				else:
					stdout = "Opened " + app_id
		"state":
			stdout = JSON.stringify(hermes_get_state({"include_apps": true, "include_windows": true, "include_filesystem": false}), "\t")
		"clear":
			stdout = ""
		_:
			exit_code = 1
			stderr = "Unknown command: " + cmd
	return {
		"stdout": stdout,
		"stderr": stderr,
		"exit_code": exit_code,
		"cwd": str(state.get("cwd", _fs.home_path()))
	}

func _color_from_variant(value: Variant, fallback: Color) -> Color:
	if value is Array:
		var parts: Array = value
		if parts.size() >= 3:
			var alpha := float(parts[3]) if parts.size() >= 4 else fallback.a
			return Color(float(parts[0]), float(parts[1]), float(parts[2]), alpha)
	if value is Dictionary:
		var data: Dictionary = value
		if data.has("r") and data.has("g") and data.has("b"):
			return Color(float(data.get("r", fallback.r)), float(data.get("g", fallback.g)), float(data.get("b", fallback.b)), float(data.get("a", fallback.a)))
	return fallback

func _app_root() -> VBoxContainer:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	return root

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _set_status(label: Label, message: String, is_error := false) -> void:
	label.text = message
	label.add_theme_color_override("font_color", ERROR if is_error else MUTED)

func _button(text_value: String, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = min_size
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_stylebox_override("normal", _style(SURFACE, BORDER, 1, 6))
	button.add_theme_stylebox_override("hover", _style(SURFACE_HOVER, BORDER_ACTIVE, 1, 6))
	button.add_theme_stylebox_override("pressed", _style(Color("3b414d"), FOCUS, 1, 6))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), FOCUS, 2, 6))
	button.add_theme_stylebox_override("disabled", _style(Color("252830"), Color("333842"), 1, 6))
	return button

func _files_menu_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(52, 28)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", MUTED)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_stylebox_override("hover", _style(Color("2a2f39"), Color("2a2f39"), 1, 6))
	button.add_theme_stylebox_override("pressed", _style(Color("313743"), Color("313743"), 1, 6))
	return button

func _files_sidebar_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", MUTED)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_stylebox_override("normal", _style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6))
	button.add_theme_stylebox_override("hover", _style(Color("2f3440"), Color("2f3440"), 1, 6))
	button.add_theme_stylebox_override("pressed", _style(Color("363d4a"), Color("3d4554"), 1, 6))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), FOCUS, 1, 6))
	return button

func _files_chrome_button(text_value: String, min_size: Vector2) -> Button:
	var button := _button(text_value, min_size)
	button.add_theme_font_size_override("font_size", 13)
	return button

func _files_table_header_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.custom_minimum_size = Vector2(0, 26)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT)
	return label

func _style_files_tree(tree: Tree) -> void:
	tree.add_theme_color_override("font_color", TEXT)
	tree.add_theme_color_override("font_selected_color", TEXT)
	tree.add_theme_color_override("guide_color", Color("303642"))
	tree.add_theme_stylebox_override("panel", _style(Color("171a20"), Color("2e3440"), 1, 8))
	tree.add_theme_stylebox_override("selected", _style(Color("2f3541"), Color("3d4658"), 1, 4))
	tree.add_theme_stylebox_override("selected_focus", _style(Color("334055"), FOCUS, 1, 4))
	tree.add_theme_stylebox_override("cursor", _style(Color("334055"), FOCUS, 1, 4))
	tree.add_theme_stylebox_override("cursor_unfocused", _style(Color("2b313d"), Color("3a414e"), 1, 4))
	tree.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), FOCUS, 2, 8))

func _style_line_edit(input: LineEdit) -> void:
	input.add_theme_color_override("font_color", TEXT)
	input.add_theme_color_override("caret_color", TEXT)
	input.add_theme_color_override("font_placeholder_color", MUTED)
	input.add_theme_stylebox_override("normal", _style(Color("1d2026"), BORDER, 1, 6))
	input.add_theme_stylebox_override("focus", _style(Color("1d2026"), FOCUS, 2, 6))

func _style_text_edit(input: TextEdit) -> void:
	input.add_theme_color_override("font_color", TEXT)
	input.add_theme_color_override("font_readonly_color", MUTED)
	input.add_theme_color_override("caret_color", TEXT)
	input.add_theme_stylebox_override("normal", _style(Color("1d2026"), BORDER, 1, 6))
	input.add_theme_stylebox_override("focus", _style(Color("1d2026"), FOCUS, 2, 6))
	input.add_theme_stylebox_override("read_only", _style(Color("1b1d22"), BORDER, 1, 6))

func _style_item_list(list: ItemList) -> void:
	list.add_theme_color_override("font_color", TEXT)
	list.add_theme_color_override("font_selected_color", TEXT)
	list.add_theme_stylebox_override("panel", _style(Color("1d2026"), BORDER, 1, 6))
	list.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), FOCUS, 2, 6))
	list.add_theme_stylebox_override("selected", _style(SURFACE_HOVER, FOCUS, 1, 4))
	list.add_theme_stylebox_override("selected_focus", _style(SURFACE_HOVER, FOCUS, 1, 4))

func _style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
