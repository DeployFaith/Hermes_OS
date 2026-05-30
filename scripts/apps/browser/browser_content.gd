class_name BrowserContentSurface
extends VBoxContainer

const URLResolver = preload("res://scripts/os/url_resolver.gd")
const HermesInternetDocumentLoader = preload("res://scripts/os/hermes_internet/hermes_internet_document_loader.gd")
const WRY_EXTENSION_PATH := "res://addons/godot_wry/WRY.gdextension"
const WRY_LINUX_LIBRARY_PATH := "res://addons/godot_wry/bin/x86_64-unknown-linux-gnu/libgodot_wry.so"
const WRY_CLASS_CANDIDATES := ["WebView", "GodotWebView", "GDExtensionWebView", "WryWebView"]
const SESSION_PATH := "user://browser_session.cfg"
const DEFAULT_URL := "http://home.hermes/"
const NEW_TAB_URL := DEFAULT_URL
const SETTINGS_PATH := "user://browser_settings.cfg"
const LOAD_IDLE := "idle"
const LOAD_LOADING := "loading"
const LOAD_TRANSFERRING := "transferring"
const LOAD_DONE := "done"
const LOAD_FAILED := "failed"
const LOAD_STOPPED := "stopped"

var _resolver := URLResolver.new()
var _document_loader = HermesInternetDocumentLoader.new()
var _chrome_visible: bool = true
var _top_accent: ColorRect
var _tabs_row: HBoxContainer
var _toolbar_row: HBoxContainer
var _address: LineEdit
var _status: Label
var _webview: Node
var _back_button: Button
var _forward_button: Button
var _reload_button: Button
var _stop_button: Button
var _security_badge: Label
var _menu_button: Button
var _loading_bar: ProgressBar
var _load_poll_timer: Timer
var _tab_bar: TabBar
var _main_menu: PopupMenu
var _tab_context_menu: PopupMenu
var _settings_menu: PopupMenu
var _session_save_timer: Timer
var _content_host: PanelContainer
var _interactive_fallback_panel: PanelContainer
var _interactive_fallback_status: Label
var _interactive_fallback_clicks: Label
var _interactive_fallback_typed: Label
var _interactive_fallback_last_key: Label
var _interactive_fallback_channel: Label
var _new_tab_page: PanelContainer
var _settings_panel: PanelContainer
var _settings_home_input: LineEdit
var _settings_restore_check: CheckButton
var _settings_search_input: LineEdit
var _settings_confirm_close_check: CheckButton
var _settings_max_closed_spin: SpinBox
var _settings_feedback: Label
var _bridge_endpoint_input: LineEdit
var _bridge_auto_check: CheckButton
var _bridge_status_label: Label
var _diagnostics_panel: PanelContainer
var _diagnostics_text: TextEdit
var _last_webview_signals: Array[String] = []
var _last_status_text := ""
var _last_window_title := ""
var _close_confirm_dialog: ConfirmationDialog
var _pending_close_tab_index := -1
var _native_teardown_started := false
var _native_teardown_done := false
var _native_teardown_started_msec := 0
var _local_document_active := false
var _last_loaded_document: Dictionary = {}
var _native_webview_window_visible := true
var _native_webview_last_rect := Rect2()
var _last_browser_input_proof: Dictionary = {
	"connected": false,
	"last_action": "",
	"click_count": 0,
	"typed_text": "",
	"last_key": "",
	"updated_msec": 0,
	"source": ""
}

var _tabs: Array[Dictionary] = []
var _closed_tabs: Array[Dictionary] = []
var _icon_cache: Dictionary = {}
var _active_tab := -1
var _navigating_history := false
var _address_is_editing := false
var _address_valid := true
var _home_url := DEFAULT_URL
var _restore_session_enabled := true
var _search_template := "http://home.hermes/search?q=%s"
var _max_closed_tabs := 30
var _confirm_close_tabs := false

func _ready() -> void:
	set_meta("window_min_size", Vector2(760, 540))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	set_process(true)
	set_process_unhandled_input(true)
	_setup_session_save_timer()
	_load_settings()
	_build_toolbar()
	_build_surface()
	if _tabs.is_empty():
		_new_tab(_home_url, true)
	if _restore_session_enabled:
		_restore_session()
	_sync_active_tab_to_ui()
	_sync_native_webview_window_state(true)

func _process(_delta: float) -> void:
	_sync_native_webview_window_state()

func _exit_tree() -> void:
	_teardown_embedded_webview()
	if _session_save_timer and not _session_save_timer.is_stopped():
		_session_save_timer.stop()
		_save_session()

func set_chrome_visible(visible: bool) -> void:
	_chrome_visible = visible
	if _top_accent:
		_top_accent.visible = visible
	if _tabs_row:
		_tabs_row.visible = visible
	if _toolbar_row:
		_toolbar_row.visible = visible
	if _loading_bar:
		_loading_bar.visible = visible and bool(_active_tab_data().get("loading", false))

func prepare_for_close() -> void:
	if _settings_panel:
		_settings_panel.visible = false
	if _diagnostics_panel:
		_diagnostics_panel.visible = false
	if _new_tab_page:
		_show_new_tab_page()
	if _content_host:
		_content_host.visible = true
	_begin_native_teardown()

func is_native_teardown_complete() -> bool:
	if not _native_teardown_started:
		return true
	if _native_teardown_done:
		return true
	if Time.get_ticks_msec() - _native_teardown_started_msec > 1400:
		_record_webview_signal("teardown_timeout", "fallback finalize")
		_finalize_webview_node()
		_native_teardown_done = true
		return true
	return false

func _begin_native_teardown() -> void:
	if _native_teardown_started:
		return
	_native_teardown_started = true
	_native_teardown_done = false
	_native_teardown_started_msec = Time.get_ticks_msec()
	if _webview == null or not is_instance_valid(_webview):
		_native_teardown_done = true
		return
	_record_webview_signal("teardown", "window closing")
	_call_first(["stop", "stop_loading"])
	if _webview is CanvasItem:
		(_webview as CanvasItem).visible = false
	if _webview.has_method("update_visibility"):
		_webview.call("update_visibility")
	if _webview.has_method("set_visible"):
		_webview.call("set_visible", false)
	if _webview.has_method("close_devtools"):
		_webview.call("close_devtools")
	if _webview.has_method("load_html"):
		_webview.call("load_html", "")
	_call_first(["load_url", "navigate", "load_uri", "set_url"], ["about:blank"])
	var webview_node: Node = _webview
	if webview_node.has_method("destroy_webview"):
		webview_node.call("destroy_webview")
		if _webview != null and is_instance_valid(_webview) and _webview.has_method("is_destroyed") and bool(_webview.call("is_destroyed")):
			_on_native_teardown_completed()
	elif webview_node.has_method("close"):
		webview_node.call("close")
		_on_native_teardown_completed()
	else:
		_on_native_teardown_completed()

func _on_native_teardown_completed() -> void:
	if _native_teardown_done:
		return
	_native_teardown_done = true
	_record_webview_signal("teardown_completed", "ok")
	_finalize_webview_node()

func _finalize_webview_node() -> void:
	if _webview == null or not is_instance_valid(_webview):
		_webview = null
		return
	if _webview.get_parent() != null:
		_webview.get_parent().remove_child(_webview)
	if _webview.has_method("free"):
		_webview.call_deferred("free")
	else:
		_webview.queue_free()
	_webview = null

func _teardown_embedded_webview() -> void:
	_begin_native_teardown()
	if not _native_teardown_done:
		_on_native_teardown_completed()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _handle_key_shortcut(event):
			accept_event()
			return

func _handle_key_shortcut(event: InputEventKey) -> bool:
	if event.ctrl_pressed and event.keycode == KEY_L:
		_focus_address_bar()
		return true
	if event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_T:
		_reopen_closed_tab()
		return true
	if event.ctrl_pressed and event.keycode == KEY_T:
		_new_tab(NEW_TAB_URL, true)
		_set_status_text("new tab")
		return true
	if event.ctrl_pressed and event.keycode == KEY_W:
		_request_close_tab(_active_tab)
		return true
	if event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_D:
		_toggle_diagnostics_panel()
		return true
	if event.ctrl_pressed and event.keycode == KEY_TAB:
		if not _tabs.is_empty():
			var delta := -1 if event.shift_pressed else 1
			_activate_tab((_active_tab + delta + _tabs.size()) % _tabs.size(), true)
		return true
	if event.alt_pressed and event.keycode == KEY_LEFT:
		go_back()
		return true
	if event.alt_pressed and event.keycode == KEY_RIGHT:
		go_forward()
		return true
	if event.ctrl_pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		if not _tabs.is_empty():
			var desired := 8 if event.keycode == KEY_9 else int(event.keycode - KEY_1)
			_activate_tab(mini(desired, _tabs.size() - 1), true)
		return true
	if event.keycode == KEY_ESCAPE:
		if _address and (_address.has_focus() or _address_is_editing):
			_address.text = get_current_url()
			_address_is_editing = false
			_validate_address_text()
			_release_address_focus()
		return true
	return false

func _build_toolbar() -> void:
	_top_accent = ColorRect.new()
	var top_accent: ColorRect = _top_accent
	top_accent.custom_minimum_size = Vector2(0, 2)
	top_accent.color = Color("ff5f14")
	top_accent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_accent.visible = _chrome_visible
	add_child(top_accent)

	_tabs_row = HBoxContainer.new()
	var tabs_row: HBoxContainer = _tabs_row
	tabs_row.add_theme_constant_override("separation", 4)
	tabs_row.visible = _chrome_visible
	add_child(tabs_row)
	_tab_bar = TabBar.new()
	_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ALWAYS
	_tab_bar.tab_changed.connect(func(index: int) -> void:
		_activate_tab(index, true)
	)
	_tab_bar.tab_close_pressed.connect(func(index: int) -> void:
		_request_close_tab(index)
	)
	if _tab_bar.has_signal("tab_rmb_clicked"):
		_tab_bar.connect("tab_rmb_clicked", Callable(self, "_on_tab_rmb_clicked"))
	tabs_row.add_child(_tab_bar)
	var new_tab_button := Button.new()
	new_tab_button.text = "+"
	new_tab_button.tooltip_text = "New tab"
	new_tab_button.pressed.connect(func() -> void:
		_new_tab(NEW_TAB_URL, true)
	)
	tabs_row.add_child(new_tab_button)

	_toolbar_row = HBoxContainer.new()
	var row: HBoxContainer = _toolbar_row
	row.add_theme_constant_override("separation", 6)
	row.visible = _chrome_visible
	add_child(row)

	_back_button = Button.new(); _back_button.text = "←"; _back_button.pressed.connect(go_back); row.add_child(_back_button)
	_forward_button = Button.new(); _forward_button.text = "→"; _forward_button.pressed.connect(go_forward); row.add_child(_forward_button)
	_reload_button = Button.new(); _reload_button.text = "⟳"; _reload_button.pressed.connect(reload); row.add_child(_reload_button)
	_stop_button = Button.new(); _stop_button.text = "✕"; _stop_button.tooltip_text = "Stop"; _stop_button.visible = false; _stop_button.pressed.connect(stop_loading); row.add_child(_stop_button)
	var home := Button.new(); home.text = "Home"; home.pressed.connect(func() -> void: open_url(_home_url)); row.add_child(home)

	_security_badge = Label.new()
	_security_badge.text = "🔒"
	_security_badge.tooltip_text = "Secure connection"
	row.add_child(_security_badge)

	_address = LineEdit.new()
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.placeholder_text = DEFAULT_URL
	_address.text_submitted.connect(func(text: String) -> void:
		if _validate_address_text():
			_address_is_editing = false
			open_url(text)
			_release_address_focus()
		elif text.strip_edges().contains(" "):
			_address_is_editing = false
			search(text)
			_release_address_focus()
		else:
			_set_status_text("invalid address")
	)
	_address.text_changed.connect(func(_text: String) -> void:
		_address_is_editing = true
		_validate_address_text()
	)
	_address.focus_entered.connect(func() -> void:
		_address_is_editing = true
		_address.select_all()
	)
	_address.focus_exited.connect(func() -> void:
		_address_is_editing = false
		_validate_address_text()
	)
	row.add_child(_address)

	_menu_button = Button.new()
	_menu_button.text = "⋮"
	_menu_button.disabled = false
	_menu_button.tooltip_text = "Browser menu"
	_menu_button.pressed.connect(_show_main_menu)
	row.add_child(_menu_button)

	_status = Label.new()
	_status.text = "idle"
	_status.custom_minimum_size = Vector2(190, 0)
	row.add_child(_status)

	_loading_bar = ProgressBar.new()
	_loading_bar.min_value = 0.0
	_loading_bar.max_value = 1.0
	_loading_bar.step = 0.001
	_loading_bar.value = 0.0
	_loading_bar.custom_minimum_size = Vector2(120, 6)
	_loading_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loading_bar.visible = false
	add_child(_loading_bar)

	_load_poll_timer = Timer.new()
	_load_poll_timer.wait_time = 0.2
	_load_poll_timer.autostart = false
	_load_poll_timer.one_shot = false
	_load_poll_timer.timeout.connect(_poll_page_load_state)
	add_child(_load_poll_timer)

	_main_menu = PopupMenu.new()
	_main_menu.add_item("New tab", 1)
	_main_menu.add_item("Duplicate tab", 2)
	_main_menu.add_separator()
	_main_menu.add_item("Reopen closed tab", 3)
	_main_menu.add_separator()
	_main_menu.add_item("Close tab", 4)
	_main_menu.add_item("Close other tabs", 5)
	_main_menu.add_separator()
	_main_menu.add_item("Settings", 6)
	_main_menu.id_pressed.connect(_on_main_menu_id_pressed)
	add_child(_main_menu)

	_tab_context_menu = PopupMenu.new()
	_tab_context_menu.add_item("Duplicate tab", 21)
	_tab_context_menu.add_item("Close tab", 22)
	_tab_context_menu.add_item("Close other tabs", 23)
	_tab_context_menu.add_separator()
	_tab_context_menu.add_item("Reopen closed tab", 24)
	_tab_context_menu.id_pressed.connect(_on_tab_context_id_pressed)
	add_child(_tab_context_menu)

	_settings_menu = PopupMenu.new()
	_settings_menu.add_check_item("Restore previous session", 101)
	_settings_menu.add_item("Set current page as Home", 102)
	_settings_menu.add_item("Reset Home to home.hermes", 103)
	_settings_menu.id_pressed.connect(_on_settings_menu_id_pressed)
	add_child(_settings_menu)

	_close_confirm_dialog = ConfirmationDialog.new()
	_close_confirm_dialog.title = "Close tab?"
	_close_confirm_dialog.dialog_text = "Close the current tab?"
	_close_confirm_dialog.confirmed.connect(func() -> void:
		var idx := _pending_close_tab_index
		_pending_close_tab_index = -1
		_close_tab(idx)
	)
	add_child(_close_confirm_dialog)

func _build_surface() -> void:
	_content_host = PanelContainer.new()
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_content_host)

	var view := _create_webview_node()
	if view == null:
		var diagnosis := _classify_webview_failure()
		var blocker := Label.new()
		blocker.text = _format_webview_blocker_text(diagnosis)
		blocker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blocker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		blocker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blocker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		blocker.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content_host.add_child(blocker)
		_set_status_text("blocked: " + str(diagnosis.get("code", "webview unavailable")))
	else:
		_webview = view
		_configure_webview_layout()
		_webview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_webview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content_host.add_child(_webview)
		_bind_webview_signals()
		_set_status_text("ready")
	_build_interactive_fallback_panel()
	_build_new_tab_page()
	_build_diagnostics_panel()
	_build_settings_panel()
	_update_interactive_fallback_state()
	_sync_interactive_fallback_visibility()

func _build_interactive_fallback_panel() -> void:
	_interactive_fallback_panel = PanelContainer.new()
	_interactive_fallback_panel.name = "InteractiveFallbackPanel"
	_interactive_fallback_panel.visible = false
	_interactive_fallback_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_interactive_fallback_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_host.add_child(_interactive_fallback_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	_interactive_fallback_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Interactive BrowserView Test"
	title.add_theme_font_size_override("font_size", 23)
	box.add_child(title)

	_interactive_fallback_status = Label.new()
	_interactive_fallback_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_interactive_fallback_status)

	_interactive_fallback_clicks = Label.new()
	box.add_child(_interactive_fallback_clicks)

	_interactive_fallback_typed = Label.new()
	_interactive_fallback_typed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_interactive_fallback_typed)

	_interactive_fallback_last_key = Label.new()
	box.add_child(_interactive_fallback_last_key)

	_interactive_fallback_channel = Label.new()
	_interactive_fallback_channel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_interactive_fallback_channel)

func _build_diagnostics_panel() -> void:
	_diagnostics_panel = PanelContainer.new()
	_diagnostics_panel.name = "BrowserDiagnosticsPanel"
	_diagnostics_panel.visible = false
	_diagnostics_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diagnostics_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_diagnostics_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_diagnostics_panel.add_child(box)
	var title := Label.new()
	title.text = "Browser Diagnostics"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	_diagnostics_text = TextEdit.new()
	_diagnostics_text.editable = false
	_diagnostics_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diagnostics_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_diagnostics_text)
	var close := Button.new()
	close.text = "Close diagnostics"
	close.pressed.connect(_toggle_diagnostics_panel)
	box.add_child(close)

func _build_new_tab_page() -> void:
	_new_tab_page = PanelContainer.new()
	_new_tab_page.name = "BrowserNewTabPage"
	_new_tab_page.visible = false
	_new_tab_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_tab_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_host.add_child(_new_tab_page)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	_new_tab_page.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "HermesOS Browser"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "Search or enter a Hermes Internet URL above. home.hermes is bundled with Hermes_OS."
	box.add_child(hint)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var home_button := Button.new()
	home_button.text = "Open Home"
	home_button.pressed.connect(func() -> void: open_url(_home_url))
	actions.add_child(home_button)
	var settings_button := Button.new()
	settings_button.text = "Settings"
	settings_button.pressed.connect(_show_settings_panel)
	actions.add_child(settings_button)
	var reopen_button := Button.new()
	reopen_button.text = "Reopen Closed Tab"
	reopen_button.pressed.connect(_reopen_closed_tab)
	actions.add_child(reopen_button)
	box.add_child(actions)

	var internet := Label.new()
	internet.text = "Hermes Internet: bundled local pages, no localhost service required"
	box.add_child(internet)

func _build_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "BrowserSettingsPanel"
	_settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_panel.visible = false
	add_child(_settings_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	_settings_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)

	var title := Label.new()
	title.text = "Browser Settings"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	_settings_home_input = LineEdit.new()
	_settings_home_input.placeholder_text = DEFAULT_URL
	box.add_child(_settings_field_row("Homepage", _settings_home_input))

	_settings_restore_check = CheckButton.new()
	_settings_restore_check.text = "Restore previous session on startup"
	box.add_child(_settings_restore_check)

	_settings_search_input = LineEdit.new()
	_settings_search_input.placeholder_text = "http://home.hermes/search?q=%s"
	box.add_child(_settings_field_row("Search template (%s required)", _settings_search_input))

	_settings_confirm_close_check = CheckButton.new()
	_settings_confirm_close_check.text = "Confirm before closing tabs"
	box.add_child(_settings_confirm_close_check)

	_settings_max_closed_spin = SpinBox.new()
	_settings_max_closed_spin.min_value = 0
	_settings_max_closed_spin.max_value = 200
	_settings_max_closed_spin.step = 1
	box.add_child(_settings_field_row("Max reopen stack", _settings_max_closed_spin))

	var bridge_heading := Label.new()
	bridge_heading.text = "Hermes Bridge"
	bridge_heading.add_theme_font_size_override("font_size", 18)
	box.add_child(bridge_heading)

	_bridge_status_label = Label.new()
	box.add_child(_bridge_status_label)

	_bridge_endpoint_input = LineEdit.new()
	_bridge_endpoint_input.placeholder_text = "Managed by System Settings"
	box.add_child(_settings_field_row("Bridge endpoint", _bridge_endpoint_input))

	_bridge_auto_check = CheckButton.new()
	_bridge_auto_check.text = "Auto-connect bridge on startup"
	box.add_child(_bridge_auto_check)

	var bridge_buttons := HBoxContainer.new()
	bridge_buttons.add_theme_constant_override("separation", 8)
	var bridge_connect := Button.new()
	bridge_connect.text = "Connect"
	bridge_connect.pressed.connect(_connect_bridge_from_settings)
	bridge_buttons.add_child(bridge_connect)
	var bridge_disconnect := Button.new()
	bridge_disconnect.text = "Disconnect"
	bridge_disconnect.pressed.connect(_disconnect_bridge_from_settings)
	bridge_buttons.add_child(bridge_disconnect)
	box.add_child(bridge_buttons)

	_settings_feedback = Label.new()
	_settings_feedback.text = ""
	box.add_child(_settings_feedback)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	var apply := Button.new()
	apply.text = "Apply"
	apply.pressed.connect(_apply_settings_panel)
	buttons.add_child(apply)
	var reset_home := Button.new()
	reset_home.text = "Reset Home"
	reset_home.pressed.connect(func() -> void:
		_settings_home_input.text = DEFAULT_URL
		_apply_settings_panel()
	)
	buttons.add_child(reset_home)
	var close := Button.new()
	close.text = "Done"
	close.pressed.connect(_hide_settings_panel)
	buttons.add_child(close)
	box.add_child(buttons)

func _settings_field_row(label_text: String, field: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(190, 0)
	row.add_child(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	return row

func _configure_webview_layout() -> void:
	if _webview == null:
		return
	if "full_window_size" in _webview:
		_webview.set("full_window_size", false)
	elif _webview.has_method("set_full_window_size"):
		_webview.call("set_full_window_size", false)
	_sync_native_webview_window_state(true)

func _sync_native_webview_window_state(force := false) -> void:
	if _webview == null or not is_instance_valid(_webview):
		return
	var should_show := _should_show_native_webview()
	var current_rect := get_global_rect()
	var rect_changed := current_rect != _native_webview_last_rect
	if force or should_show != _native_webview_window_visible:
		_native_webview_window_visible = should_show
		if _webview is CanvasItem:
			(_webview as CanvasItem).visible = should_show
		if _webview.has_method("set_visible"):
			_webview.call("set_visible", should_show)
		if _webview.has_method("update_visibility"):
			_webview.call("update_visibility")
		_record_webview_signal("native_visibility", should_show)
	if force or rect_changed:
		_native_webview_last_rect = current_rect
		if _webview.has_method("resize"):
			_webview.call("resize")

func _should_show_native_webview() -> bool:
	if _webview == null or not is_instance_valid(_webview):
		return false
	if not is_visible_in_tree():
		return false
	if _content_host != null and not _content_host.is_visible_in_tree():
		return false
	if _settings_panel != null and _settings_panel.visible:
		return false
	if _diagnostics_panel != null and _diagnostics_panel.visible:
		return false
	if _new_tab_page != null and _new_tab_page.visible:
		return false
	var window := _find_os_window_ancestor()
	if window == null:
		return true
	if not window.visible or not window.is_visible_in_tree():
		return false
	return _is_topmost_visible_window(window)

func _find_os_window_ancestor() -> Control:
	var node: Node = self
	while node != null:
		if node is OSWindow:
			return node as Control
		node = node.get_parent()
	return null

func _is_topmost_visible_window(window: Control) -> bool:
	var parent := window.get_parent()
	if parent == null:
		return true
	for sibling in parent.get_children():
		if sibling == window:
			continue
		if not (sibling is Control):
			continue
		var other := sibling as Control
		if not other.visible:
			continue
		if str(other.get("app_id")) == "":
			continue
		if other.get_index() > window.get_index():
			return false
	return true

func _create_webview_node() -> Node:
	for c in WRY_CLASS_CANDIDATES:
		if ClassDB.class_exists(c):
			return ClassDB.instantiate(c)
	return null

func _bind_webview_signals() -> void:
	if _webview == null:
		return
	for sig_name in ["title_changed", "page_title_changed"]:
		if _webview.has_signal(sig_name):
			_webview.connect(sig_name, func(value) -> void:
				_record_webview_signal(sig_name, value)
				_set_active_tab_title(str(value))
			)
	for sig_name in ["url_changed", "uri_changed"]:
		if _webview.has_signal(sig_name):
			_webview.connect(sig_name, func(value) -> void:
				_record_webview_signal(sig_name, value)
				var maybe := str(value)
				if maybe == "":
					return
				var display := _resolver.display_url_from_backend(maybe)
				_set_active_tab_url(display, not _navigating_history)
				var tab := _active_tab_data()
				var pending := str(tab.get("pending_navigation", ""))
				if pending != "" and _resolver.normalize_user_url(pending) == _resolver.normalize_user_url(display):
					_set_tab_load_state(LOAD_DONE)
					_set_status_text("ready")
			)
	for sig_name in ["load_started", "navigation_started", "page_load_started"]:
		if _webview.has_signal(sig_name):
			_webview.connect(sig_name, func(_v = null) -> void:
				_record_webview_signal(sig_name, _v)
				_set_tab_load_state(LOAD_TRANSFERRING)
			)
	for sig_name in ["load_finished", "navigation_finished", "page_load_finished"]:
		if _webview.has_signal(sig_name):
			_webview.connect(sig_name, func(_v = null) -> void:
				_record_webview_signal(sig_name, _v)
				if _local_document_active:
					_apply_document_load_state(_last_loaded_document)
					return
				_set_tab_load_state(LOAD_DONE)
				_set_status_text("ready")
			)
	for sig_name in ["load_failed", "navigation_failed", "load_error"]:
		if _webview.has_signal(sig_name):
			_webview.connect(sig_name, func(_v = null) -> void:
				_record_webview_signal(sig_name, _v)
				_set_tab_load_state(LOAD_FAILED, "webview signal")
				_set_status_text("load failed")
			)
	if _webview.has_signal("teardown_completed"):
		_webview.connect("teardown_completed", func() -> void:
			_record_webview_signal("teardown_completed", "signal")
			_on_native_teardown_completed()
		)
	if _webview.has_signal("ipc_message"):
		_webview.connect("ipc_message", func(value) -> void:
			_record_webview_signal("ipc_message", value)
			_consume_browser_ipc_message(value)
		)

func _new_tab(url: String, activate := true) -> void:
	var normalized := _migrate_legacy_browser_url(url)
	_append_tab(_make_tab_state(normalized), activate)

func _make_tab_state(url: String, title := "New tab") -> Dictionary:
	var normalized := _migrate_legacy_browser_url(url)
	return {
		"title": title,
		"url": normalized,
		"history": [normalized],
		"history_index": 0,
		"loading": false,
		"load_state": LOAD_IDLE,
		"timeout_reason": "",
		"started_msec": 0,
		"last_active_msec": Time.get_ticks_msec(),
		"security_state": _security_state_for_url(normalized),
		"pending_navigation": "",
		"backend_url": _resolver.resolve_to_backend(normalized),
		"icon_key": _icon_key_for_url(normalized)
	}

func _append_tab(tab: Dictionary, activate := true, load_on_activate := true) -> void:
	var safe_tab := _normalize_tab_state(tab)
	_tabs.append(safe_tab)
	var index := _tabs.size() - 1
	_tab_bar.add_tab(_tab_label_for(safe_tab))
	_tab_bar.set_tab_icon(index, _icon_for_key(str(safe_tab.get("icon_key", ""))))
	if activate:
		_activate_tab(index, load_on_activate)
	_queue_session_save()

func _normalize_tab_state(tab: Dictionary) -> Dictionary:
	var url := _migrate_legacy_browser_url(str(tab.get("url", DEFAULT_URL)))
	var history: Array = tab.get("history", []) as Array
	if history.is_empty():
		history = [url]
	for i in range(history.size()):
		history[i] = _migrate_legacy_browser_url(str(history[i]))
	var idx := clampi(int(tab.get("history_index", history.size() - 1)), 0, history.size() - 1)
	return {
		"title": str(tab.get("title", "New tab")),
		"url": url,
		"history": history.duplicate(true),
		"history_index": idx,
		"loading": _is_loading_state(str(tab.get("load_state", LOAD_IDLE))),
		"load_state": str(tab.get("load_state", LOAD_IDLE)),
		"timeout_reason": str(tab.get("timeout_reason", "")),
		"started_msec": int(tab.get("started_msec", 0)),
		"last_active_msec": int(tab.get("last_active_msec", Time.get_ticks_msec())),
		"security_state": str(tab.get("security_state", _security_state_for_url(url))),
		"pending_navigation": str(tab.get("pending_navigation", "")),
		"backend_url": str(tab.get("backend_url", _resolver.resolve_to_backend(url))),
		"icon_key": str(tab.get("icon_key", _icon_key_for_url(url)))
	}

func _close_tab(index: int) -> void:
	if index < 0 or index >= _tabs.size():
		return
	var closing: Dictionary = _tabs[index]
	_push_closed_tab(closing)
	_tabs.remove_at(index)
	_tab_bar.remove_tab(index)
	if _tabs.is_empty():
		_new_tab(_home_url, true)
		return
	if _active_tab >= _tabs.size():
		_active_tab = _tabs.size() - 1
	elif _active_tab > index:
		_active_tab -= 1
	_activate_tab(_active_tab, true)
	_queue_session_save()

func _activate_tab(index: int, load := false) -> void:
	if index < 0 or index >= _tabs.size():
		return
	_active_tab = index
	var tab: Dictionary = _tabs[_active_tab]
	tab["last_active_msec"] = Time.get_ticks_msec()
	_tabs[_active_tab] = tab
	if _tab_bar.current_tab != index:
		_tab_bar.current_tab = index
	_sync_active_tab_to_ui()
	if load:
		_navigating_history = true
		open_url(str(_tabs[index].get("url", DEFAULT_URL)))
		_navigating_history = false
	_queue_session_save()

func _sync_active_tab_to_ui() -> void:
	var tab := _active_tab_data()
	if tab.is_empty():
		return
	var url := str(tab.get("url", DEFAULT_URL))
	if _address and not _address_is_editing and not _address.has_focus():
		_address.text = url
		_validate_address_text()
	_current_title_from_tab(tab)
	_refresh_nav_buttons()
	_set_tab_load_state(str(tab.get("load_state", LOAD_IDLE)), str(tab.get("timeout_reason", "")), false)

func open_url(input_url: String) -> void:
	var normalized := _resolver.normalize_user_url(input_url)
	var document: Dictionary = _document_loader.load(normalized)
	var resolved := str(document.get("local_url", _resolver.resolve_to_backend(normalized)))
	if resolved == "":
		resolved = _resolver.resolve_to_backend(normalized)
	_local_document_active = true
	_last_loaded_document = document.duplicate(true)
	_set_active_tab_url(normalized, not _navigating_history)
	_set_active_tab_backend_url(resolved)
	_set_active_tab_pending_navigation(normalized)
	_hide_new_tab_page()
	_set_active_tab_title(str(document.get("title", "Hermes Internet")))
	if _webview == null:
		_apply_document_load_state(document, "webview unavailable")
		return
	var html := str(document.get("html", ""))
	if _call_first(["load_html"], [html]):
		_set_tab_load_state(LOAD_LOADING, "")
		_set_status_text("loading Hermes Internet document")
	else:
		_apply_document_load_state(document, "load_html unavailable")
		_set_status_text("Hermes Internet document ready; native load_html unavailable")
	_update_interactive_fallback_state()
	_sync_interactive_fallback_visibility()

func _show_new_tab_page() -> void:
	if _new_tab_page == null or _content_host == null:
		return
	for child in _content_host.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = child == _new_tab_page
	_new_tab_page.visible = true
	_sync_interactive_fallback_visibility()
	_set_status_text("new tab")

func _hide_new_tab_page() -> void:
	if _new_tab_page == null or _content_host == null:
		return
	for child in _content_host.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = child != _new_tab_page
	_new_tab_page.visible = false
	_sync_interactive_fallback_visibility()

func search(query: String) -> void:
	var q := query.strip_edges()
	if q == "":
		return
	var template := _search_template if _search_template.contains("%s") else "http://home.hermes/search?q=%s"
	open_url(template % q.uri_encode())

func go_back() -> void:
	var tab := _active_tab_data()
	if tab.is_empty():
		return
	var idx := int(tab.get("history_index", 0))
	if idx <= 0:
		_refresh_nav_buttons()
		return
	tab["history_index"] = idx - 1
	_tabs[_active_tab] = tab
	_navigating_history = true
	open_url(str((tab.get("history", []) as Array)[idx - 1]))
	_navigating_history = false
	_refresh_nav_buttons()
	_save_session()

func go_forward() -> void:
	var tab := _active_tab_data()
	if tab.is_empty():
		return
	var history := tab.get("history", []) as Array
	var idx := int(tab.get("history_index", 0))
	if idx >= history.size() - 1:
		_refresh_nav_buttons()
		return
	tab["history_index"] = idx + 1
	_tabs[_active_tab] = tab
	_navigating_history = true
	open_url(str(history[idx + 1]))
	_navigating_history = false
	_refresh_nav_buttons()
	_save_session()

func reload() -> void:
	if _call_first(["reload", "refresh"]):
		_set_tab_load_state(LOAD_LOADING, "reload")

func stop_loading() -> void:
	if _call_first(["stop", "stop_loading"]):
		_set_tab_load_state(LOAD_STOPPED, "user stopped")
		_set_status_text("stopped")
	else:
		_set_tab_load_state(LOAD_STOPPED, "stop unavailable")

func get_current_url() -> String:
	var tab := _active_tab_data()
	return str(tab.get("url", DEFAULT_URL))

func get_current_title() -> String:
	var tab := _active_tab_data()
	return str(tab.get("title", "Browser"))

func open_home() -> void:
	open_url(_home_url)

func new_tab(url: String = NEW_TAB_URL) -> void:
	_new_tab(url, true)

func show_settings() -> void:
	_show_settings_panel()

func hide_settings() -> void:
	_hide_settings_panel()

func can_go_back() -> bool:
	var tab := _active_tab_data()
	return not tab.is_empty() and int(tab.get("history_index", 0)) > 0

func can_go_forward() -> bool:
	var tab := _active_tab_data()
	var history := tab.get("history", []) as Array
	return not tab.is_empty() and int(tab.get("history_index", 0)) < history.size() - 1

func agent_get_state(_args: Dictionary = {}) -> Dictionary:
	var state := debug_get_state()
	state["success"] = true
	state["operation"] = "browser.get_state"
	state["url"] = get_current_url()
	state["title"] = get_current_title()
	state["can_go_back"] = can_go_back()
	state["can_go_forward"] = can_go_forward()
	state["links"] = agent_list_links({}).get("links", [])
	state["browser_input_proof"] = _last_browser_input_proof.duplicate(true)
	return state

func agent_browser_test_press_key(args: Dictionary = {}) -> Dictionary:
	var key_name := str(args.get("key", "")).strip_edges()
	if key_name == "":
		return _agent_error("browser.test_press_key", "MISSING_KEY", "browser.test_press_key requires key")
	return _send_browser_test_input("key", {"key": key_name}, "browser.test_press_key")

func agent_browser_test_type_text(args: Dictionary = {}) -> Dictionary:
	if not args.has("text"):
		return _agent_error("browser.test_type_text", "MISSING_TEXT", "browser.test_type_text requires text")
	var text := str(args.get("text", ""))
	return _send_browser_test_input("type", {"text": text}, "browser.test_type_text")

func agent_browser_test_click(args: Dictionary = {}) -> Dictionary:
	var target := str(args.get("target", "increment")).strip_edges().to_lower()
	if target == "":
		target = "increment"
	if target != "increment":
		return _agent_error("browser.test_click", "UNSUPPORTED_TARGET", "browser.test_click supports only target=increment")
	return _send_browser_test_input("click", {"target": target}, "browser.test_click")

func _send_browser_test_input(action: String, payload: Dictionary, operation: String) -> Dictionary:
	if not _is_interactive_test_page_active():
		return _agent_error(operation, "PAGE_NOT_READY", "Browser test input requires http://home.hermes/interactive", {"url": get_current_url()})
	if _webview == null or not is_instance_valid(_webview) or not _webview.has_method("post_message"):
		return {
			"success": false,
			"operation": operation,
			"code": "BROWSER_TEST_CHANNEL_UNAVAILABLE",
			"error": "Native BrowserView does not expose bounded post_message test channel",
			"limitation": {
				"native_input_supported": false,
				"reason": "WRY/Godot input events do not reliably reach native WebKit in this runtime",
				"workaround": "BrowserView test-channel input unavailable (post_message missing)"
			}
		}
	var message := {
		"source": "hermes_os",
		"type": "browser_test_input",
		"action": action,
		"payload": payload
	}
	_webview.call("post_message", JSON.stringify(message))
	_last_browser_input_proof["last_action"] = action
	_last_browser_input_proof["source"] = "browser_test_channel"
	_last_browser_input_proof["updated_msec"] = Time.get_ticks_msec()
	if action == "click":
		_last_browser_input_proof["click_count"] = int(_last_browser_input_proof.get("click_count", 0)) + 1
	elif action == "type":
		_last_browser_input_proof["typed_text"] = str(_last_browser_input_proof.get("typed_text", "")) + str(payload.get("text", ""))
	elif action == "key":
		_last_browser_input_proof["last_key"] = str(payload.get("key", ""))
	_update_interactive_fallback_state()
	_sync_interactive_fallback_visibility()
	return {
		"success": true,
		"operation": operation,
		"input_channel": "browser_test_channel",
		"native_input": false,
		"limitation": {
			"native_input_supported": false,
			"reason": "uses bounded BrowserView post_message test channel; not host/native OS input"
		},
		"proof": _last_browser_input_proof.duplicate(true)
	}

func _is_interactive_test_page_active() -> bool:
	var current := _resolver.normalize_user_url(get_current_url())
	if current.begins_with("http://home.hermes/interactive"):
		return true
	var backend := _resolver.resolve_to_backend(current)
	return backend.find("/interactive") >= 0

func _consume_browser_ipc_message(raw_value: Variant) -> void:
	var payload: Variant = raw_value
	if raw_value is String:
		payload = JSON.parse_string(str(raw_value))
	if not (payload is Dictionary):
		return
	var message: Dictionary = payload
	if str(message.get("type", "")) != "browser_test_state":
		return
	if str(message.get("source", "")) != "hermes_interactive":
		return
	_last_browser_input_proof["connected"] = true
	_last_browser_input_proof["last_action"] = str(message.get("last_action", _last_browser_input_proof.get("last_action", "")))
	_last_browser_input_proof["click_count"] = int(message.get("click_count", _last_browser_input_proof.get("click_count", 0)))
	_last_browser_input_proof["typed_text"] = str(message.get("typed_text", _last_browser_input_proof.get("typed_text", "")))
	_last_browser_input_proof["last_key"] = str(message.get("last_key", _last_browser_input_proof.get("last_key", "")))
	_last_browser_input_proof["updated_msec"] = Time.get_ticks_msec()
	_last_browser_input_proof["source"] = "hermes_interactive"
	_update_interactive_fallback_state()
	_sync_interactive_fallback_visibility()

func _sync_interactive_fallback_visibility() -> void:
	if _interactive_fallback_panel == null:
		return
	var show := _is_interactive_test_page_active() and _content_host != null and _content_host.visible and (_new_tab_page == null or not _new_tab_page.visible)
	_interactive_fallback_panel.visible = show
	if _webview and _webview is CanvasItem:
		(_webview as CanvasItem).visible = not show

func _update_interactive_fallback_state() -> void:
	if _interactive_fallback_status == null:
		return
	var connected := bool(_last_browser_input_proof.get("connected", false))
	var clicks := int(_last_browser_input_proof.get("click_count", 0))
	var typed := str(_last_browser_input_proof.get("typed_text", ""))
	var last_key := str(_last_browser_input_proof.get("last_key", ""))
	var source := str(_last_browser_input_proof.get("source", ""))
	var channel_state := "connected" if connected else "not confirmed"
	_interactive_fallback_status.text = "Deterministic fallback preview for http://home.hermes/interactive. Native WRY/WebKit rendering may appear blank/black in this runtime."
	_interactive_fallback_clicks.text = "click count: %d" % clicks
	_interactive_fallback_typed.text = "typed text: %s" % (typed if typed != "" else "(empty)")
	_interactive_fallback_last_key.text = "last key: %s" % (last_key if last_key != "" else "(none)")
	_interactive_fallback_channel.text = "test channel: %s (source: %s)" % [channel_state, source if source != "" else "none"]

func agent_navigate(args: Dictionary = {}) -> Dictionary:
	var target := _agent_navigation_target(args)
	if target == "":
		return _agent_error("browser.navigate", "MISSING_ARG", "browser.navigate requires url, page, route, or target")
	var normalized := _resolver.normalize_user_url(target)
	var document: Dictionary = _document_loader.load(normalized)
	var status_code := int(document.get("status_code", 0))
	var mode := str(document.get("mode", ""))
	if status_code >= 400:
		var label := _agent_target_label(args, normalized)
		if mode == "real_internet_unavailable":
			return _agent_error("browser.navigate", "EXTERNAL_NAVIGATION_BLOCKED", "browser navigation blocked: external internet unavailable", {"url": normalized, "mode": mode})
		return _agent_error("browser.navigate", "PAGE_NOT_FOUND", "browser page not found: %s" % label, {"url": normalized, "mode": mode, "status_code": status_code})
	open_url(normalized)
	return {
		"success": true,
		"operation": "browser.navigate",
		"url": get_current_url(),
		"title": get_current_title(),
		"status_code": status_code,
		"mode": mode,
		"source_path": str(document.get("source_path", ""))
	}

func agent_back(_args: Dictionary = {}) -> Dictionary:
	if not can_go_back():
		return _agent_error("browser.back", "NO_HISTORY", "browser has no back history")
	go_back()
	return _agent_success("browser.back")

func agent_forward(_args: Dictionary = {}) -> Dictionary:
	if not can_go_forward():
		return _agent_error("browser.forward", "NO_HISTORY", "browser has no forward history")
	go_forward()
	return _agent_success("browser.forward")

func agent_reload(_args: Dictionary = {}) -> Dictionary:
	reload()
	return _agent_success("browser.reload")

func agent_list_links(_args: Dictionary = {}) -> Dictionary:
	var html := str(_last_loaded_document.get("html", ""))
	var links: Array[Dictionary] = []
	if html != "":
		var regex := RegEx.new()
		if regex.compile("(?is)<a\\b([^>]*)\\bhref\\s*=\\s*([\"'])([^\"']+)\\2([^>]*)>(.*?)</a>") == OK:
			for match in regex.search_all(html):
				var href := str(match.get_string(3)).strip_edges()
				var text := _strip_html(str(match.get_string(5))).strip_edges()
				if href == "":
					continue
				links.append({
					"id": _link_id_for(href, links.size()),
					"href": _resolve_link_href(href),
					"label": text if text != "" else href
				})
	return {
		"success": true,
		"operation": "browser.list_links",
		"url": get_current_url(),
		"title": get_current_title(),
		"links": links
	}

func agent_activate_link(args: Dictionary = {}) -> Dictionary:
	var requested := str(args.get("id", args.get("link_id", args.get("label", "")))).strip_edges().to_lower()
	if requested == "":
		return _agent_error("browser.activate_link", "MISSING_ARG", "browser.activate_link requires id, link_id, or label")
	var links: Array = agent_list_links({}).get("links", [])
	for link_value in links:
		if not (link_value is Dictionary):
			continue
		var link: Dictionary = link_value
		if str(link.get("id", "")).to_lower() == requested or str(link.get("label", "")).to_lower() == requested:
			return agent_navigate({"url": str(link.get("href", "")), "target": str(link.get("label", requested))})
	return _agent_error("browser.activate_link", "LINK_NOT_FOUND", "browser link not found: %s" % requested, {"links": links})

func _agent_navigation_target(args: Dictionary) -> String:
	var raw := str(args.get("url", args.get("page", args.get("route", args.get("target", ""))))).strip_edges()
	var lower := raw.to_lower()
	match lower:
		"games", "game", "games page", "the games page":
			return "http://home.hermes/games"
		"snake", "snake game", "the snake game", "open snake", "open snake game":
			return "http://home.hermes/games/snake"
		"home", "home page", "home.hermes":
			return DEFAULT_URL
	if lower.begins_with("/"):
		return "http://home.hermes%s" % raw
	if (args.has("page") or args.has("route")) and not lower.contains("://"):
		return "http://home.hermes/%s" % lower.replace(" ", "-")
	return raw

func _agent_target_label(args: Dictionary, fallback_url: String) -> String:
	var raw := str(args.get("page", args.get("route", args.get("target", args.get("url", ""))))).strip_edges()
	if raw != "":
		return raw.to_lower().replace(" page", "").replace("the ", "")
	var path := _resolver.extract_path_and_query(fallback_url).strip_edges().trim_prefix("/")
	return path if path != "" else fallback_url

func _agent_success(operation: String) -> Dictionary:
	return {
		"success": true,
		"operation": operation,
		"url": get_current_url(),
		"title": get_current_title(),
		"can_go_back": can_go_back(),
		"can_go_forward": can_go_forward()
	}

func _agent_error(operation: String, code: String, message: String, details: Dictionary = {}) -> Dictionary:
	var out := details.duplicate(true)
	out["success"] = false
	out["operation"] = operation
	out["code"] = code
	out["error"] = message
	return out

func _resolve_link_href(href: String) -> String:
	var clean := href.strip_edges()
	if clean.begins_with("#"):
		return get_current_url() + clean
	if clean.begins_with("/"):
		return "http://%s%s" % [_host_for_url(get_current_url()), clean]
	if clean.contains("://"):
		return clean
	var current := get_current_url()
	var base_path := _resolver.extract_path_and_query(current)
	if base_path.find("?") >= 0:
		base_path = base_path.substr(0, base_path.find("?"))
	var base_dir := base_path.get_base_dir()
	if base_dir == "." or base_dir == "":
		base_dir = "/"
	return "http://%s/%s" % [_host_for_url(current), (base_dir.rstrip("/") + "/" + clean).trim_prefix("/")]

func _link_id_for(href: String, index: int) -> String:
	var clean := href.strip_edges().to_lower().replace("http://", "").replace("https://", "")
	clean = clean.replace("/", "_").replace("#", "_").replace("?", "_").replace("=", "_").replace("&", "_")
	while clean.begins_with("_"):
		clean = clean.substr(1)
	while clean.ends_with("_"):
		clean = clean.substr(0, clean.length() - 1)
	return clean if clean != "" else "link_%d" % index

func _strip_html(value: String) -> String:
	var regex := RegEx.new()
	if regex.compile("(?is)<[^>]+>") != OK:
		return value
	return regex.sub(value, "", true).replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'")

func _set_active_tab_url(display_url: String, record_history: bool) -> void:
	if _active_tab < 0 or _active_tab >= _tabs.size():
		return
	var tab := _tabs[_active_tab]
	tab["url"] = display_url
	tab["security_state"] = _security_state_for_url(display_url)
	tab["backend_url"] = _resolver.resolve_to_backend(display_url)
	tab["icon_key"] = _icon_key_for_url(display_url)
	if _tab_bar and _active_tab >= 0 and _active_tab < _tab_bar.tab_count:
		_tab_bar.set_tab_icon(_active_tab, _icon_for_key(str(tab.get("icon_key", ""))))
	if record_history:
		var history := tab.get("history", []) as Array
		var idx := int(tab.get("history_index", -1))
		if idx >= 0 and idx < history.size() and str(history[idx]) == display_url:
			pass
		else:
			if idx < history.size() - 1:
				history = history.slice(0, idx + 1)
			history.append(display_url)
			idx = history.size() - 1
			tab["history"] = history
			tab["history_index"] = idx
	_tabs[_active_tab] = tab
	if _address and not _address_is_editing and not _address.has_focus():
		_address.text = display_url
		_validate_address_text()
	_refresh_nav_buttons()
	_queue_session_save()

func _set_active_tab_backend_url(backend_url: String) -> void:
	if _active_tab < 0 or _active_tab >= _tabs.size():
		return
	var tab: Dictionary = _tabs[_active_tab]
	tab["backend_url"] = backend_url
	_tabs[_active_tab] = tab

func _set_active_tab_title(title: String) -> void:
	if _active_tab < 0 or _active_tab >= _tabs.size():
		return
	var t := title.strip_edges()
	if t == "":
		t = get_current_url()
	var tab := _tabs[_active_tab]
	tab["title"] = t
	_tabs[_active_tab] = tab
	_tab_bar.set_tab_title(_active_tab, _trim_tab_title(t))
	_apply_window_title("Browser — %s" % t)
	_queue_session_save()

func _current_title_from_tab(tab: Dictionary) -> void:
	var title := str(tab.get("title", "Browser"))
	if title == "":
		title = "Browser"
	_apply_window_title("Browser — %s" % title)
	if _active_tab >= 0 and _active_tab < _tab_bar.tab_count:
		_tab_bar.set_tab_title(_active_tab, _trim_tab_title(title))

func _refresh_nav_buttons() -> void:
	var tab := _active_tab_data()
	if tab.is_empty():
		return
	var history := tab.get("history", []) as Array
	var idx := int(tab.get("history_index", 0))
	if _back_button:
		_back_button.disabled = idx <= 0
	if _forward_button:
		_forward_button.disabled = idx >= history.size() - 1
	if _security_badge:
		var security_state := str(tab.get("security_state", _security_state_for_url(str(tab.get("url", "")))))
		match security_state:
			"secure":
				_security_badge.text = "🔒"
				_security_badge.tooltip_text = "Secure HTTPS connection"
			"local":
				_security_badge.text = "⌂"
				_security_badge.tooltip_text = "Local/internal HermesOS page"
			"insecure":
				_security_badge.text = "⚠"
				_security_badge.tooltip_text = "Insecure HTTP page"
			"error":
				_security_badge.text = "!"
				_security_badge.tooltip_text = "Page load failed"
			_:
				_security_badge.text = "?"
				_security_badge.tooltip_text = "Unknown security state"

func _set_loading_state(loading: bool, update_status := true) -> void:
	_set_tab_load_state(LOAD_LOADING if loading else LOAD_DONE, "", update_status)

func _set_tab_load_state(state: String, reason := "", update_status := true) -> void:
	var normalized := state
	if not [LOAD_IDLE, LOAD_LOADING, LOAD_TRANSFERRING, LOAD_DONE, LOAD_FAILED, LOAD_STOPPED].has(normalized):
		normalized = LOAD_IDLE
	var loading := _is_loading_state(normalized)
	if _active_tab >= 0 and _active_tab < _tabs.size():
		var tab := _tabs[_active_tab]
		tab["load_state"] = normalized
		tab["loading"] = loading
		tab["timeout_reason"] = reason
		if loading:
			tab["started_msec"] = Time.get_ticks_msec()
		else:
			tab["pending_navigation"] = ""
		if normalized == LOAD_FAILED:
			tab["security_state"] = "error"
		_tabs[_active_tab] = tab
	if _reload_button:
		_reload_button.visible = not loading
	if _stop_button:
		_stop_button.visible = loading
	if _loading_bar:
		_loading_bar.visible = loading and _chrome_visible
		if loading:
			_loading_bar.value = maxf(_loading_bar.value, 0.08)
		else:
			_loading_bar.value = 0.0
	if _load_poll_timer:
		if loading and _load_poll_timer.is_stopped():
			_load_poll_timer.start()
		elif not loading:
			_load_poll_timer.stop()
	if update_status:
		_set_status_text(normalized if reason == "" else "%s: %s" % [normalized, reason])
	if _tab_bar and _active_tab >= 0 and _active_tab < _tab_bar.tab_count and _active_tab < _tabs.size():
		_tab_bar.set_tab_title(_active_tab, _tab_label_for(_tabs[_active_tab]))
		_tab_bar.set_tab_icon(_active_tab, _icon_for_key(str(_tabs[_active_tab].get("icon_key", ""))))
	_refresh_nav_buttons()
	_queue_session_save()

func _is_loading_state(state: String) -> bool:
	return state == LOAD_LOADING or state == LOAD_TRANSFERRING

func _poll_page_load_state() -> void:
	var tab := _active_tab_data()
	if tab.is_empty() or not bool(tab.get("loading", false)):
		if _load_poll_timer:
			_load_poll_timer.stop()
		return
	var elapsed := Time.get_ticks_msec() - int(tab.get("started_msec", 0))
	if _loading_bar:
		_loading_bar.value = minf(_loading_bar.value + 0.07, 0.97)
		if _loading_bar.value >= 0.97 and elapsed > 2500:
			_loading_bar.value = 0.995
	if elapsed > 9000:
		_set_tab_load_state(LOAD_STOPPED, "load timeout", false)
		_set_status_text("stopped: load timeout")

func _set_status_text(text: String) -> void:
	if text == _last_status_text:
		return
	_last_status_text = text
	if _status:
		_status.text = text
	if _diagnostics_panel and _diagnostics_panel.visible:
		_refresh_diagnostics_panel()

func _record_webview_signal(signal_name: String, value = null) -> void:
	_last_webview_signals.append("%d %s %s" % [Time.get_ticks_msec(), signal_name, str(value)])
	while _last_webview_signals.size() > 20:
		_last_webview_signals.remove_at(0)
	if _diagnostics_panel and _diagnostics_panel.visible:
		_refresh_diagnostics_panel()

func _toggle_diagnostics_panel() -> void:
	if _diagnostics_panel == null:
		return
	var next_visible := not _diagnostics_panel.visible
	_diagnostics_panel.visible = next_visible
	if _content_host:
		_content_host.visible = not next_visible
	if _settings_panel:
		_settings_panel.visible = false
	if next_visible:
		_refresh_diagnostics_panel()
		_set_status_text("diagnostics")
	else:
		_set_status_text(str(_active_tab_data().get("load_state", LOAD_IDLE)))

func _refresh_diagnostics_panel() -> void:
	if _diagnostics_text == null:
		return
	_diagnostics_text.text = JSON.stringify({
		"active_tab": _active_tab_data().duplicate(true),
		"active_tab_index": _active_tab,
		"tab_count": _tabs.size(),
		"closed_tab_count": _closed_tabs.size(),
		"last_loaded_document": _last_loaded_document.duplicate(true),
		"bridge": _bridge_state_snapshot(),
		"last_webview_signals": _last_webview_signals.duplicate(),
		"load_timing": {
			"now_msec": Time.get_ticks_msec(),
			"started_msec": int(_active_tab_data().get("started_msec", 0)),
			"completed_msec": int(_active_tab_data().get("completed_msec", 0))
		}
	}, "	")

func _apply_document_load_state(document: Dictionary, suffix: String = "") -> void:
	var mode := str(document.get("mode", "hermes_internet"))
	var status_code := int(document.get("status_code", 200))
	var reason := str(document.get("description", ""))
	if reason == "":
		reason = mode
	if status_code >= 500 or mode == "real_internet_unavailable" or mode == "hermes_internet_error":
		_set_tab_load_state(LOAD_FAILED, reason if suffix == "" else "%s; %s" % [reason, suffix])
	elif status_code >= 400:
		_set_tab_load_state(LOAD_FAILED, reason if suffix == "" else "%s; %s" % [reason, suffix])
	else:
		_set_tab_load_state(LOAD_DONE, suffix)
	match mode:
		"hermes_internet":
			_set_status_text("Hermes Internet — %s" % str(document.get("display_url", get_current_url())))
		"hermes_internet_page_not_found", "hermes_internet_site_not_found":
			_set_status_text("Hermes Internet not found — %s" % str(document.get("display_url", get_current_url())))
		"real_internet_unavailable":
			_set_status_text("Real Internet mode is not enabled")
		_:
			_set_status_text(reason)

func _html_escape(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;")

func _active_tab_data() -> Dictionary:
	if _active_tab < 0 or _active_tab >= _tabs.size():
		return {}
	return _tabs[_active_tab]

func _trim_tab_title(title: String) -> String:
	var t := title.strip_edges()
	if t == "":
		t = "New tab"
	if t.length() > 28:
		return t.substr(0, 27) + "…"
	return t

func _apply_window_title(title: String) -> void:
	if not _chrome_visible:
		return
	if title == _last_window_title:
		return
	_last_window_title = title
	var node: Node = self
	while node != null:
		if node.has_method("set_app_title"):
			node.call("set_app_title", title)
			break
		node = node.get_parent()

func _release_address_focus() -> void:
	var viewport := get_viewport()
	if viewport:
		viewport.gui_release_focus()

func _show_main_menu() -> void:
	if _main_menu == null:
		return
	_main_menu.set_item_disabled(_main_menu.get_item_index(3), _closed_tabs.is_empty())
	var popup_pos := _menu_button.get_screen_position() + Vector2(0, _menu_button.size.y + 4)
	_main_menu.position = popup_pos
	_main_menu.popup()

func _on_main_menu_id_pressed(id: int) -> void:
	match id:
		1:
			_new_tab(NEW_TAB_URL, true)
		2:
			_duplicate_tab(_active_tab)
		3:
			_reopen_closed_tab()
		4:
			_request_close_tab(_active_tab)
		5:
			_close_other_tabs(_active_tab)
		6:
			_show_settings_menu()

func _on_tab_rmb_clicked(index: int) -> void:
	if index < 0 or index >= _tabs.size():
		return
	_activate_tab(index, false)
	if _tab_context_menu == null:
		return
	_tab_context_menu.set_item_disabled(_tab_context_menu.get_item_index(24), _closed_tabs.is_empty())
	var mouse := get_viewport().get_mouse_position()
	_tab_context_menu.position = Vector2i(mouse.x, mouse.y)
	_tab_context_menu.popup()

func _on_tab_context_id_pressed(id: int) -> void:
	match id:
		21:
			_duplicate_tab(_active_tab)
		22:
			_request_close_tab(_active_tab)
		23:
			_close_other_tabs(_active_tab)
		24:
			_reopen_closed_tab()

func _duplicate_tab(index: int) -> void:
	if index < 0 or index >= _tabs.size():
		return
	var tab: Dictionary = _tabs[index]
	_new_tab(str(tab.get("url", DEFAULT_URL)), true)

func _close_other_tabs(keep_index: int) -> void:
	if keep_index < 0 or keep_index >= _tabs.size():
		return
	var keep_tab: Dictionary = _tabs[keep_index].duplicate(true)
	for i in range(_tabs.size()):
		if i == keep_index:
			continue
		_push_closed_tab(_tabs[i] as Dictionary)
	_tabs = [keep_tab]
	while _tab_bar.tab_count > 0:
		_tab_bar.remove_tab(_tab_bar.tab_count - 1)
	_tab_bar.add_tab(_trim_tab_title(str(keep_tab.get("title", "New tab"))))
	_tab_bar.set_tab_icon(0, _icon_for_key(str(keep_tab.get("icon_key", ""))))
	_active_tab = 0
	_activate_tab(0, true)

func _request_close_tab(index: int) -> void:
	if index < 0 or index >= _tabs.size():
		_set_status_text("no tab to close")
		return
	if _confirm_close_tabs and _close_confirm_dialog:
		_pending_close_tab_index = index
		_close_confirm_dialog.dialog_text = "Close tab '%s'?" % str(_tabs[index].get("title", "New tab"))
		_close_confirm_dialog.popup_centered()
		_set_status_text("confirm close tab")
		return
	_close_tab(index)

func _reopen_closed_tab() -> void:
	if _closed_tabs.is_empty():
		_set_status_text("no closed tab")
		return
	var tab := _closed_tabs.pop_back() as Dictionary
	_append_tab(tab, true, true)
	_set_status_text("reopened tab")

func _show_settings_menu() -> void:
	_show_settings_panel()

func _on_settings_menu_id_pressed(id: int) -> void:
	match id:
		101:
			_restore_session_enabled = not _restore_session_enabled
			_save_settings()
			_sync_settings_panel_from_state()
		102:
			_home_url = get_current_url()
			_save_settings()
			_sync_settings_panel_from_state()
			_set_status_text("home set")
		103:
			_home_url = DEFAULT_URL
			_save_settings()
			_sync_settings_panel_from_state()
			_set_status_text("home reset")

func _show_settings_panel() -> void:
	if _settings_panel == null:
		return
	_sync_settings_panel_from_state()
	if _diagnostics_panel:
		_diagnostics_panel.visible = false
	if _content_host:
		_content_host.visible = false
	_settings_panel.visible = true
	_set_status_text("settings")

func _hide_settings_panel() -> void:
	if _settings_panel:
		_settings_panel.visible = false
	if _content_host and (_diagnostics_panel == null or not _diagnostics_panel.visible):
		_content_host.visible = true
	_set_status_text(str(_active_tab_data().get("load_state", LOAD_IDLE)))

func _sync_settings_panel_from_state() -> void:
	if _settings_home_input:
		_settings_home_input.text = _home_url
	if _settings_restore_check:
		_settings_restore_check.button_pressed = _restore_session_enabled
	if _settings_search_input:
		_settings_search_input.text = _search_template
	if _settings_confirm_close_check:
		_settings_confirm_close_check.button_pressed = _confirm_close_tabs
	if _settings_max_closed_spin:
		_settings_max_closed_spin.value = _max_closed_tabs
	if _settings_feedback:
		_settings_feedback.text = ""
	_sync_bridge_panel_from_kernel()

func _apply_settings_panel() -> void:
	if _settings_home_input == null:
		return
	var next_home := _resolver.normalize_user_url(_settings_home_input.text)
	var next_template := _settings_search_input.text.strip_edges()
	var valid := true
	var feedback := ""
	if next_home.strip_edges() == "":
		valid = false
		feedback = "Homepage is required."
	elif not next_template.contains("%s"):
		valid = false
		feedback = "Search template must include %s."
	if not valid:
		if _settings_feedback:
			_settings_feedback.text = feedback
		_set_status_text("settings invalid")
		return
	_home_url = next_home
	_restore_session_enabled = _settings_restore_check.button_pressed
	_search_template = next_template
	_confirm_close_tabs = _settings_confirm_close_check.button_pressed
	_max_closed_tabs = maxi(0, int(_settings_max_closed_spin.value))
	while _closed_tabs.size() > _max_closed_tabs:
		_closed_tabs.remove_at(0)
	_apply_bridge_panel_settings(false)
	_save_settings()
	if _settings_feedback:
		_settings_feedback.text = "Saved."
	_set_status_text("settings saved")

func _find_kernel() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("get_bridge_state") and node.has_method("set_bridge_settings"):
			return node
		node = node.get_parent()
	return null

func _bridge_state_snapshot() -> Dictionary:
	var kernel := _find_kernel()
	if kernel and kernel.has_method("get_bridge_state"):
		var state = kernel.call("get_bridge_state")
		if state is Dictionary:
			return state
	return {
		"connected": false,
		"auto_connect": false,
		"endpoint": "",
		"available": false
	}

func _sync_bridge_panel_from_kernel() -> void:
	var state := _bridge_state_snapshot()
	if _bridge_endpoint_input:
		_bridge_endpoint_input.text = str(state.get("endpoint", ""))
	if _bridge_auto_check:
		_bridge_auto_check.button_pressed = bool(state.get("auto_connect", false))
	if _bridge_status_label:
		var availability := "unavailable" if not bool(state.get("available", true)) else ("connected" if bool(state.get("connected", false)) else "disconnected")
		_bridge_status_label.text = "Bridge: %s" % availability

func _apply_bridge_panel_settings(connect_now := false) -> void:
	var kernel := _find_kernel()
	if kernel == null:
		_sync_bridge_panel_from_kernel()
		return
	var endpoint := _bridge_endpoint_input.text.strip_edges() if _bridge_endpoint_input else ""
	var auto_connect := _bridge_auto_check.button_pressed if _bridge_auto_check else false
	if kernel.has_method("set_bridge_settings"):
		kernel.call("set_bridge_settings", {"endpoint": endpoint, "auto_connect": auto_connect})
	if connect_now and kernel.has_method("connect_bridge"):
		var message := str(kernel.call("connect_bridge", endpoint))
		if message != "":
			_set_status_text(message)
	_sync_bridge_panel_from_kernel()

func _connect_bridge_from_settings() -> void:
	_apply_bridge_panel_settings(true)
	_set_status_text("bridge connect requested")

func _disconnect_bridge_from_settings() -> void:
	var kernel := _find_kernel()
	if kernel and kernel.has_method("disconnect_bridge"):
		kernel.call("disconnect_bridge")
	_sync_bridge_panel_from_kernel()
	_set_status_text("bridge disconnected")

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_home_url = _migrate_legacy_browser_url(str(cfg.get_value("browser", "home_url", DEFAULT_URL)))
	_restore_session_enabled = bool(cfg.get_value("browser", "restore_session", true))
	_search_template = _migrate_legacy_search_template(str(cfg.get_value("browser", "search_template", "http://home.hermes/search?q=%s")))
	_confirm_close_tabs = bool(cfg.get_value("browser", "confirm_close_tabs", false))
	_max_closed_tabs = maxi(0, int(cfg.get_value("browser", "max_closed_tabs", 30)))
	if not _search_template.contains("%s"):
		_search_template = "http://home.hermes/search?q=%s"

func _migrate_legacy_browser_url(value: String) -> String:
	# Obsolete fake-domain routes from the retired Browser prototype are migrated to the official Hermes Internet home.
	var lower := value.strip_edges().to_lower()
	if lower == "" or lower.contains("news.grid") or lower.contains("atlas.node") or lower.contains("vault.corp") or lower.contains("newtab.grid"):
		return DEFAULT_URL
	return _resolver.normalize_user_url(value)

func _migrate_legacy_search_template(value: String) -> String:
	# Obsolete fake-domain search templates are not kept active; searches now stay under home.hermes.
	var clean := value.strip_edges()
	var lower := clean.to_lower()
	if clean == "" or lower.contains("news.grid") or lower.contains("atlas.node") or lower.contains("vault.corp") or lower.contains("newtab.grid"):
		return "http://home.hermes/search?q=%s"
	return clean if clean.contains("%s") else "http://home.hermes/search?q=%s"

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("browser", "home_url", _home_url)
	cfg.set_value("browser", "restore_session", _restore_session_enabled)
	cfg.set_value("browser", "search_template", _search_template)
	cfg.set_value("browser", "confirm_close_tabs", _confirm_close_tabs)
	cfg.set_value("browser", "max_closed_tabs", _max_closed_tabs)
	_save_config_atomic(cfg, SETTINGS_PATH)

func _restore_session() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SESSION_PATH) != OK:
		return
	var restored_tabs: Array = cfg.get_value("session", "tabs", []) as Array
	if restored_tabs.is_empty():
		var urls: Array = cfg.get_value("session", "tab_urls", []) as Array
		for u in urls:
			restored_tabs.append(_make_tab_state(str(u)))
	var active := int(cfg.get_value("session", "active_tab", 0))
	if not restored_tabs.is_empty():
		var valid_tabs: Array = []
		for tab in restored_tabs:
			if tab is Dictionary:
				valid_tabs.append(tab)
		if valid_tabs.is_empty():
			return
		_tabs.clear()
		while _tab_bar.tab_count > 0:
			_tab_bar.remove_tab(_tab_bar.tab_count - 1)
		for tab in valid_tabs:
			_append_tab(tab, false, false)
		var closed: Array = cfg.get_value("session", "closed_tabs", []) as Array
		_closed_tabs.clear()
		for tab in closed:
			if tab is Dictionary:
				_push_closed_tab(tab as Dictionary)
		_activate_tab(clampi(active, 0, _tabs.size() - 1), true)

func _save_session() -> void:
	var cfg := ConfigFile.new()
	var tab_states: Array = []
	var urls: Array = []
	for t in _tabs:
		var tab: Dictionary = _normalize_tab_state(t as Dictionary)
		tab_states.append(tab)
		urls.append(str(tab.get("url", DEFAULT_URL)))
	cfg.set_value("session", "tabs", tab_states)
	cfg.set_value("session", "tab_urls", urls)
	cfg.set_value("session", "active_tab", _active_tab)
	cfg.set_value("session", "closed_tabs", _closed_tabs.duplicate(true))
	_save_config_atomic(cfg, SESSION_PATH)

func _setup_session_save_timer() -> void:
	_session_save_timer = Timer.new()
	_session_save_timer.wait_time = 0.25
	_session_save_timer.one_shot = true
	_session_save_timer.timeout.connect(_save_session)
	add_child(_session_save_timer)

func _queue_session_save() -> void:
	if _session_save_timer == null:
		_save_session()
		return
	_session_save_timer.start()

func _save_config_atomic(cfg: ConfigFile, path: String) -> void:
	var tmp_path := path + ".tmp"
	var err := cfg.save(tmp_path)
	if err != OK:
		push_warning("Could not save temp config %s: %s" % [tmp_path, err])
		return
	var abs_tmp := ProjectSettings.globalize_path(tmp_path)
	var abs_target := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
		DirAccess.copy_absolute(abs_target, ProjectSettings.globalize_path(path + ".bak"))
	var rename_err := DirAccess.rename_absolute(abs_tmp, abs_target)
	if rename_err == OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	else:
		push_warning("Could not atomically replace config %s: %s" % [path, rename_err])
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(abs_target)
		DirAccess.rename_absolute(abs_tmp, abs_target)

func _push_closed_tab(tab: Dictionary) -> void:
	if _max_closed_tabs <= 0:
		return
	_closed_tabs.append(_normalize_tab_state(tab).duplicate(true))
	while _closed_tabs.size() > _max_closed_tabs:
		_closed_tabs.remove_at(0)
	_queue_session_save()

func _set_active_tab_pending_navigation(url: String) -> void:
	if _active_tab < 0 or _active_tab >= _tabs.size():
		return
	var tab: Dictionary = _tabs[_active_tab]
	tab["pending_navigation"] = url
	_tabs[_active_tab] = tab

func _security_state_for_url(url: String) -> String:
	var lower := url.to_lower()
	if lower.begins_with("https://"):
		return "secure"
	if _resolver.is_hermes_internet_route(lower) or _resolver.is_internal_route(lower) or lower.begins_with("file://") or lower.begins_with("about:") or lower.begins_with("hermes-internet://"):
		return "local"
	if lower.begins_with("http://"):
		return "insecure"
	return "unknown"

func _host_for_url(url: String) -> String:
	var without_scheme := url
	var scheme_pos := without_scheme.find("://")
	if scheme_pos >= 0:
		without_scheme = without_scheme.substr(scheme_pos + 3)
	var slash := without_scheme.find("/")
	if slash >= 0:
		without_scheme = without_scheme.substr(0, slash)
	var colon := without_scheme.find(":")
	if colon >= 0:
		without_scheme = without_scheme.substr(0, colon)
	return without_scheme

func _icon_key_for_url(url: String) -> String:
	var normalized := _resolver.normalize_user_url(url)
	var without_scheme := normalized.replace("https://", "").replace("http://", "")
	var slash := without_scheme.find("/")
	return without_scheme.substr(0, slash) if slash >= 0 else without_scheme

func _tab_label_for(tab: Dictionary) -> String:
	var load_prefix := "◌ " if _is_loading_state(str(tab.get("load_state", LOAD_IDLE))) else ""
	return load_prefix + _trim_tab_title(str(tab.get("title", "New tab")))

func _icon_for_key(key: String) -> Texture2D:
	var safe_key := key if key.strip_edges() != "" else "new-tab"
	if _icon_cache.has(safe_key):
		return _icon_cache[safe_key]
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var hue := float(abs(hash(safe_key)) % 360) / 360.0
	var color := Color.from_hsv(hue, 0.62, 0.82, 1.0)
	image.fill(color)
	for x in range(16):
		image.set_pixel(x, 0, Color(1, 1, 1, 0.35))
		image.set_pixel(x, 15, Color(0, 0, 0, 0.25))
	for y in range(16):
		image.set_pixel(0, y, Color(1, 1, 1, 0.25))
		image.set_pixel(15, y, Color(0, 0, 0, 0.22))
	var texture := ImageTexture.create_from_image(image)
	_icon_cache[safe_key] = texture
	return texture

func _focus_address_bar() -> void:
	if _address:
		_address_is_editing = true
		_address.grab_focus()
		_address.select_all()

func _validate_address_text() -> bool:
	if _address == null:
		_address_valid = true
		return true
	var text := _address.text.strip_edges()
	_address_valid = text == "" or text.begins_with("http://") or text.begins_with("https://") or text.begins_with("browser://") or text.begins_with("hermes://") or (not text.contains(" ") and text.contains(".")) or text == "home.hermes"
	_address.modulate = Color(1, 1, 1, 1) if _address_valid else Color(1, 0.72, 0.72, 1)
	return _address_valid

func debug_get_state() -> Dictionary:
	var tab := _active_tab_data()
	return {
		"tab_count": _tabs.size(),
		"active_tab": _active_tab,
		"closed_tab_count": _closed_tabs.size(),
		"url": get_current_url(),
		"title": get_current_title(),
		"load_state": str(tab.get("load_state", LOAD_IDLE)),
		"loading": bool(tab.get("loading", false)),
		"timeout_reason": str(tab.get("timeout_reason", "")),
		"address_valid": _address_valid,
		"active_tab_state": tab.duplicate(true),
		"last_loaded_document": _last_loaded_document.duplicate(true),
		"settings_panel_visible": _settings_panel != null and _settings_panel.visible,
		"new_tab_page_visible": _new_tab_page != null and _new_tab_page.visible,
		"diagnostics_panel_visible": _diagnostics_panel != null and _diagnostics_panel.visible,
		"native_teardown": {
			"started": _native_teardown_started,
			"done": _native_teardown_done,
			"started_msec": _native_teardown_started_msec
		},
		"bridge": _bridge_state_snapshot(),
		"settings": {
			"home_url": _home_url,
			"restore_session": _restore_session_enabled,
			"search_template": _search_template,
			"confirm_close_tabs": _confirm_close_tabs,
			"max_closed_tabs": _max_closed_tabs
		},
		"browser_visible_fallback": {
			"enabled": _is_interactive_test_page_active(),
			"visible": _interactive_fallback_panel != null and _interactive_fallback_panel.visible,
			"title": "Interactive BrowserView Test",
			"note": "Deterministic local fallback preview for /interactive due native WebView blank/black runtime limitation"
		},
		"browser_input_proof": _last_browser_input_proof.duplicate(true)
	}

func debug_apply_settings(values: Dictionary) -> void:
	if values.has("home_url"):
		_home_url = _resolver.normalize_user_url(str(values.get("home_url", DEFAULT_URL)))
	if values.has("restore_session"):
		_restore_session_enabled = bool(values.get("restore_session", true))
	if values.has("confirm_close_tabs"):
		_confirm_close_tabs = bool(values.get("confirm_close_tabs", false))
	if values.has("search_template"):
		var template := str(values.get("search_template", _search_template))
		_search_template = template if template.contains("%s") else "http://home.hermes/search?q=%s"
	if values.has("max_closed_tabs"):
		_max_closed_tabs = maxi(0, int(values.get("max_closed_tabs", 30)))
		while _closed_tabs.size() > _max_closed_tabs:
			_closed_tabs.remove_at(0)
	_save_settings()

func debug_trigger_shortcut(name: String) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	match name:
		"ctrl+l":
			event.ctrl_pressed = true; event.keycode = KEY_L
		"ctrl+t":
			event.ctrl_pressed = true; event.keycode = KEY_T
		"ctrl+w":
			event.ctrl_pressed = true; event.keycode = KEY_W
		"ctrl+shift+t":
			event.ctrl_pressed = true; event.shift_pressed = true; event.keycode = KEY_T
		"ctrl+shift+d":
			event.ctrl_pressed = true; event.shift_pressed = true; event.keycode = KEY_D
		"ctrl+shift+tab":
			event.ctrl_pressed = true; event.shift_pressed = true; event.keycode = KEY_TAB
		"ctrl+tab":
			event.ctrl_pressed = true; event.keycode = KEY_TAB
		"alt+left":
			event.alt_pressed = true; event.keycode = KEY_LEFT
		"alt+right":
			event.alt_pressed = true; event.keycode = KEY_RIGHT
		"escape":
			event.keycode = KEY_ESCAPE
		_:
			if name.begins_with("ctrl+"):
				event.ctrl_pressed = true
				event.keycode = KEY_0 + int(name.trim_prefix("ctrl+"))
	_handle_key_shortcut(event)

func _call_first(methods: Array[String], args: Array = []) -> bool:
	if _webview == null:
		return false
	for m in methods:
		if _webview.has_method(m):
			_webview.callv(m, args)
			return true
	return false

func _classify_webview_failure() -> Dictionary:
	if not FileAccess.file_exists(WRY_EXTENSION_PATH):
		return {
			"code": "extension_missing",
			"detail": "Missing WRY extension descriptor: %s" % WRY_EXTENSION_PATH,
			"hint": "Add the Godot WRY addon under res://addons/godot_wry/."
		}

	var has_linux_library := FileAccess.file_exists(WRY_LINUX_LIBRARY_PATH)
	for c in WRY_CLASS_CANDIDATES:
		if ClassDB.class_exists(c):
			return {
				"code": "class_registered_but_instantiate_failed",
				"detail": "WRY class '%s' is registered, but BrowserApp could not instantiate it." % c,
				"hint": "Check the Godot output log for the native extension error."
			}

	if has_linux_library:
		return {
			"code": "extension_present_but_not_loaded",
			"detail": "WRY files are present, but no WebView class is registered in this Godot runtime.",
			"hint": "Common cause with Flatpak Godot: the native library fails to load because WebKitGTK 4.1 is unavailable inside the Flatpak runtime (libwebkit2gtk-4.1.so.0). Run Godot from a runtime that can load WebKitGTK 4.1, or install/provide that dependency inside the runtime."
		}

	return {
		"code": "native_library_missing",
		"detail": "WRY extension descriptor exists, but the Linux library is missing: %s" % WRY_LINUX_LIBRARY_PATH,
		"hint": "Install or rebuild the Godot WRY native library for linux x86_64."
	}

func _format_webview_blocker_text(diagnosis: Dictionary) -> String:
	return "Embedded WebView unavailable: WRY extension failed to load in this runtime.\n\nReason: %s\n%s\n\n%s\n\nHermesOS Browser requires real WebView rendering; fallback mode is active until the runtime dependency/load issue is resolved." % [
		str(diagnosis.get("code", "unknown_runtime_error")),
		str(diagnosis.get("detail", "No WebView class is registered.")),
		str(diagnosis.get("hint", "Check Godot startup logs for GDExtension loader errors."))
	]
