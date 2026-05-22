class_name BrowserApp
extends VBoxContainer

const URLResolver = preload("res://scripts/os/url_resolver.gd")
const WRY_EXTENSION_PATH := "res://addons/godot_wry/WRY.gdextension"
const WRY_LINUX_LIBRARY_PATH := "res://addons/godot_wry/bin/x86_64-unknown-linux-gnu/libgodot_wry.so"
const WRY_CLASS_CANDIDATES := ["WebView", "GodotWebView", "GDExtensionWebView", "WryWebView"]
const SESSION_PATH := "user://browser_session.cfg"
const DEFAULT_URL := "http://news.grid/"
const SETTINGS_PATH := "user://browser_settings.cfg"

var _resolver := URLResolver.new()
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

var _tabs: Array[Dictionary] = []
var _closed_tabs: Array[Dictionary] = []
var _active_tab := -1
var _navigating_history := false
var _home_url := DEFAULT_URL
var _restore_session_enabled := true
var _search_template := "http://news.grid/search?q=%s"

func _ready() -> void:
	set_meta("window_min_size", Vector2(760, 540))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	set_process_unhandled_input(true)
	_load_settings()
	_build_toolbar()
	_build_surface()
	if _tabs.is_empty():
		_new_tab(_home_url, true)
	if _restore_session_enabled:
		_restore_session()
	_sync_active_tab_to_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_L:
			if _address:
				_address.grab_focus()
				_address.select_all()
			accept_event()
			return
		if event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_T:
			_reopen_closed_tab()
			accept_event()
			return
		if event.ctrl_pressed and event.keycode == KEY_T:
			_new_tab(_home_url, true)
			accept_event()
			return
		if event.ctrl_pressed and event.keycode == KEY_W:
			_close_tab(_active_tab)
			accept_event()
			return
		if event.ctrl_pressed and event.keycode == KEY_TAB:
			if not _tabs.is_empty():
				var next := (_active_tab + 1) % _tabs.size()
				_activate_tab(next, true)
			accept_event()
			return
		if event.keycode == KEY_ESCAPE:
			if _address and _address.has_focus():
				_address.text = get_current_url()
				_release_address_focus()
			accept_event()

func _build_toolbar() -> void:
	var top_accent := ColorRect.new()
	top_accent.custom_minimum_size = Vector2(0, 2)
	top_accent.color = Color("ff5f14")
	top_accent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(top_accent)

	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 4)
	add_child(tabs_row)
	_tab_bar = TabBar.new()
	_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ALWAYS
	_tab_bar.tab_changed.connect(func(index: int) -> void:
		_activate_tab(index, true)
	)
	_tab_bar.tab_close_pressed.connect(func(index: int) -> void:
		_close_tab(index)
	)
	if _tab_bar.has_signal("tab_rmb_clicked"):
		_tab_bar.connect("tab_rmb_clicked", Callable(self, "_on_tab_rmb_clicked"))
	tabs_row.add_child(_tab_bar)
	var new_tab_button := Button.new()
	new_tab_button.text = "+"
	new_tab_button.tooltip_text = "New tab"
	new_tab_button.pressed.connect(func() -> void:
		_new_tab(_home_url, true)
	)
	tabs_row.add_child(new_tab_button)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
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
	_address.text_submitted.connect(func(text: String) -> void: open_url(text))
	_address.focus_entered.connect(func() -> void:
		_address.select_all()
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
	_settings_menu.add_item("Reset Home to news.grid", 103)
	_settings_menu.id_pressed.connect(_on_settings_menu_id_pressed)
	add_child(_settings_menu)

func _build_surface() -> void:
	var host := PanelContainer.new()
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(host)

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
		host.add_child(blocker)
		_set_status_text("blocked: " + str(diagnosis.get("code", "webview unavailable")))
		return

	_webview = view
	_configure_webview_layout()
	_webview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_webview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.add_child(_webview)
	_bind_webview_signals()
	_set_status_text("ready")

func _configure_webview_layout() -> void:
	if _webview == null:
		return
	if "full_window_size" in _webview:
		_webview.set("full_window_size", false)
	elif _webview.has_method("set_full_window_size"):
		_webview.call("set_full_window_size", false)

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
				_set_active_tab_title(str(value))
			)
	for sig_name in ["url_changed", "uri_changed"]:
		if _webview.has_signal(sig_name):
			_webview.connect(sig_name, func(value) -> void:
				var maybe := str(value)
				if maybe == "":
					return
				var display := _resolver.display_url_from_backend(maybe)
				_set_active_tab_url(display, not _navigating_history)
			)
	for sig_name in ["load_started", "navigation_started"]:
		if _webview.has_signal(sig_name):
			_webview.connect(sig_name, func(_v = null) -> void:
				_set_loading_state(true)
			)
	for sig_name in ["load_finished", "navigation_finished"]:
		if _webview.has_signal(sig_name):
			_webview.connect(sig_name, func(_v = null) -> void:
				_set_loading_state(false)
				_set_status_text("ready")
			)
	for sig_name in ["load_failed", "navigation_failed", "load_error"]:
		if _webview.has_signal(sig_name):
			_webview.connect(sig_name, func(_v = null) -> void:
				_set_loading_state(false)
				_set_status_text("load failed")
			)

func _new_tab(url: String, activate := true) -> void:
	var normalized := _resolver.normalize_user_url(url)
	var tab := {
		"title": "New tab",
		"url": normalized,
		"history": [normalized],
		"history_index": 0,
		"loading": false,
		"started_msec": 0
	}
	_tabs.append(tab)
	var index := _tabs.size() - 1
	_tab_bar.add_tab("New tab")
	if activate:
		_activate_tab(index, true)
	_save_session()

func _close_tab(index: int) -> void:
	if index < 0 or index >= _tabs.size():
		return
	var closing: Dictionary = _tabs[index]
	_closed_tabs.append(closing.duplicate(true))
	if _closed_tabs.size() > 20:
		_closed_tabs.remove_at(0)
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
	_save_session()

func _activate_tab(index: int, load := false) -> void:
	if index < 0 or index >= _tabs.size():
		return
	_active_tab = index
	if _tab_bar.current_tab != index:
		_tab_bar.current_tab = index
	_sync_active_tab_to_ui()
	if load:
		_navigating_history = true
		open_url(str(_tabs[index].get("url", DEFAULT_URL)))
		_navigating_history = false
	_save_session()

func _sync_active_tab_to_ui() -> void:
	var tab := _active_tab_data()
	if tab.is_empty():
		return
	var url := str(tab.get("url", DEFAULT_URL))
	if _address:
		_address.text = url
	_current_title_from_tab(tab)
	_refresh_nav_buttons()
	_set_loading_state(bool(tab.get("loading", false)), false)

func open_url(input_url: String) -> void:
	var normalized := _resolver.normalize_user_url(input_url)
	_set_active_tab_url(normalized, not _navigating_history)
	var resolved := _resolver.resolve_to_backend(normalized)
	if _webview == null:
		_set_status_text("blocked")
		return
	if _call_first(["load_url", "navigate", "load_uri", "set_url"], [resolved]):
		_set_loading_state(true)
	else:
		_set_loading_state(false)
		_set_status_text("plugin API mismatch")

func search(query: String) -> void:
	var q := query.strip_edges()
	if q == "":
		return
	var template := _search_template if _search_template.contains("%s") else "http://news.grid/search?q=%s"
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
		_set_loading_state(true)

func stop_loading() -> void:
	if _call_first(["stop", "stop_loading"]):
		_set_loading_state(false)
		_set_status_text("stopped")

func get_current_url() -> String:
	var tab := _active_tab_data()
	return str(tab.get("url", DEFAULT_URL))

func get_current_title() -> String:
	var tab := _active_tab_data()
	return str(tab.get("title", "Browser"))

func _set_active_tab_url(display_url: String, record_history: bool) -> void:
	if _active_tab < 0 or _active_tab >= _tabs.size():
		return
	var tab := _tabs[_active_tab]
	tab["url"] = display_url
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
	if _address:
		_address.text = display_url
	_refresh_nav_buttons()
	_save_session()

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
	_save_session()

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
		var url := str(tab.get("url", ""))
		var is_secure := url.begins_with("https://")
		_security_badge.text = "🔒" if is_secure else "⚠"
		_security_badge.tooltip_text = "Secure connection" if is_secure else "Non-HTTPS page"

func _set_loading_state(loading: bool, update_status := true) -> void:
	if _active_tab >= 0 and _active_tab < _tabs.size():
		var tab := _tabs[_active_tab]
		tab["loading"] = loading
		if loading:
			tab["started_msec"] = Time.get_ticks_msec()
		_tabs[_active_tab] = tab
	if _reload_button:
		_reload_button.visible = not loading
	if _stop_button:
		_stop_button.visible = loading
	if _loading_bar:
		_loading_bar.visible = loading
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
		_set_status_text("loading" if loading else "ready")
	_save_session()

func _poll_page_load_state() -> void:
	var tab := _active_tab_data()
	if tab.is_empty() or not bool(tab.get("loading", false)):
		if _load_poll_timer:
			_load_poll_timer.stop()
		return
	if _loading_bar:
		_loading_bar.value = minf(_loading_bar.value + 0.04, 0.92)
	var elapsed := Time.get_ticks_msec() - int(tab.get("started_msec", 0))
	if elapsed > 9000:
		_set_loading_state(false, false)
		_set_status_text("ready")

func _set_status_text(text: String) -> void:
	if _status:
		_status.text = text

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
			_new_tab(_home_url, true)
		2:
			_duplicate_tab(_active_tab)
		3:
			_reopen_closed_tab()
		4:
			_close_tab(_active_tab)
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
			_close_tab(_active_tab)
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
		_closed_tabs.append((_tabs[i] as Dictionary).duplicate(true))
	while _closed_tabs.size() > 20:
		_closed_tabs.remove_at(0)
	_tabs = [keep_tab]
	while _tab_bar.tab_count > 0:
		_tab_bar.remove_tab(_tab_bar.tab_count - 1)
	_tab_bar.add_tab(_trim_tab_title(str(keep_tab.get("title", "New tab"))))
	_active_tab = 0
	_activate_tab(0, true)

func _reopen_closed_tab() -> void:
	if _closed_tabs.is_empty():
		return
	var tab := _closed_tabs.pop_back() as Dictionary
	var url := str(tab.get("url", DEFAULT_URL))
	_new_tab(url, true)

func _show_settings_menu() -> void:
	if _settings_menu == null:
		return
	_settings_menu.set_item_checked(_settings_menu.get_item_index(101), _restore_session_enabled)
	var popup_pos := _menu_button.get_screen_position() + Vector2(0, _menu_button.size.y + 4)
	_settings_menu.position = popup_pos
	_settings_menu.popup()

func _on_settings_menu_id_pressed(id: int) -> void:
	match id:
		101:
			_restore_session_enabled = not _restore_session_enabled
			_save_settings()
		102:
			_home_url = get_current_url()
			_save_settings()
			_set_status_text("home set")
		103:
			_home_url = DEFAULT_URL
			_save_settings()
			_set_status_text("home reset")

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_home_url = str(cfg.get_value("browser", "home_url", DEFAULT_URL))
	_restore_session_enabled = bool(cfg.get_value("browser", "restore_session", true))
	_search_template = str(cfg.get_value("browser", "search_template", "http://news.grid/search?q=%s"))
	if not _search_template.contains("%s"):
		_search_template = "http://news.grid/search?q=%s"

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("browser", "home_url", _home_url)
	cfg.set_value("browser", "restore_session", _restore_session_enabled)
	cfg.set_value("browser", "search_template", _search_template)
	cfg.save(SETTINGS_PATH)

func _restore_session() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SESSION_PATH) != OK:
		return
	var urls: Array = cfg.get_value("session", "tab_urls", []) as Array
	var active := int(cfg.get_value("session", "active_tab", 0))
	if urls is Array and not urls.is_empty():
		_tabs.clear()
		while _tab_bar.tab_count > 0:
			_tab_bar.remove_tab(_tab_bar.tab_count - 1)
		for u in urls:
			_new_tab(str(u), false)
		_activate_tab(clampi(active, 0, _tabs.size() - 1), true)

func _save_session() -> void:
	var cfg := ConfigFile.new()
	var urls: Array = []
	for t in _tabs:
		urls.append(str((t as Dictionary).get("url", DEFAULT_URL)))
	cfg.set_value("session", "tab_urls", urls)
	cfg.set_value("session", "active_tab", _active_tab)
	cfg.save(SESSION_PATH)

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
