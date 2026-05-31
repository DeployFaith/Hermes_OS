extends "res://scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

const DEFAULT_URL := "http://home.hermes/"
const NEW_TAB_URL := DEFAULT_URL

var _shell: Node = null
var _fs: Object = null
var _browser_app: Object = null
var _surface: Control = null
var _address_input: LineEdit = null
var _address_context_menu: PopupMenu = null

const ADDRESS_MENU_CUT := 1001
const ADDRESS_MENU_COPY := 1002
const ADDRESS_MENU_PASTE := 1003
const ADDRESS_MENU_SELECT_ALL := 1004
const ADDRESS_MENU_CLEAR := 1005

func configure_app_context(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	var browser_value: Variant = context.get("browser_app", null)
	if browser_value is Object:
		_browser_app = browser_value as Object
	_setup_address_context_menu()
	_setup_surface()
	sync_from_surface()

func _app_ready() -> void:
	if state != null:
		state.set_many({
			"address": DEFAULT_URL,
			"current_url": DEFAULT_URL,
			"title": "Browser",
			"status": "initializing",
			"loading": false,
			"back_disabled": true,
			"forward_disabled": true
		})
	_setup_surface()
	_setup_address_context_menu()
	sync_from_surface()

func get_browser_surface() -> Control:
	_setup_surface()
	return _surface

func handle_address_input(event) -> void:
	if state != null:
		state.set("address", str(event.value))

func load_address(event = null) -> void:
	_setup_surface()
	var value: String = _event_or_address(event)
	if value.strip_edges() == "":
		value = DEFAULT_URL
	if _surface == null:
		_set_status("browser surface unavailable")
		return
	if value.strip_edges().contains(" ") and _surface.has_method("search"):
		_surface.call("search", value)
	elif _surface.has_method("open_url"):
		_surface.call("open_url", value)
	sync_from_surface()

func go_back(_event = null) -> void:
	_setup_surface()
	if _surface != null and _surface.has_method("go_back"):
		_surface.call("go_back")
	sync_from_surface()

func go_forward(_event = null) -> void:
	_setup_surface()
	if _surface != null and _surface.has_method("go_forward"):
		_surface.call("go_forward")
	sync_from_surface()

func reload_page(_event = null) -> void:
	_setup_surface()
	if _surface != null and _surface.has_method("reload"):
		_surface.call("reload")
	sync_from_surface()

func open_home(_event = null) -> void:
	_setup_surface()
	if _surface != null and _surface.has_method("open_home"):
		_surface.call("open_home")
	elif _surface != null and _surface.has_method("open_url"):
		_surface.call("open_url", DEFAULT_URL)
	sync_from_surface()

func new_tab(_event = null) -> void:
	_setup_surface()
	if _surface != null and _surface.has_method("new_tab"):
		_surface.call("new_tab", NEW_TAB_URL)
	sync_from_surface()

func show_settings(_event = null) -> void:
	_setup_surface()
	if _surface != null and _surface.has_method("show_settings"):
		_surface.call("show_settings")
	sync_from_surface()

func sync_from_surface() -> void:
	_setup_surface()
	if _surface == null or state == null:
		return
	var current_url: String = DEFAULT_URL
	var title: String = "Browser"
	if _surface.has_method("get_current_url"):
		current_url = str(_surface.call("get_current_url"))
	if _surface.has_method("get_current_title"):
		title = str(_surface.call("get_current_title"))
	var snapshot: Dictionary = {}
	if _surface.has_method("debug_get_state"):
		var value: Variant = _surface.call("debug_get_state")
		if value is Dictionary:
			snapshot = (value as Dictionary).duplicate(true)
	var loading: bool = bool(snapshot.get("loading", false))
	var load_state: String = str(snapshot.get("load_state", "ready"))
	var status_text: String = load_state if load_state != "" else "ready"
	if current_url != "":
		status_text += " — " + current_url
	state.set_many({
		"current_url": current_url,
		"address": current_url,
		"title": title,
		"status": status_text,
		"loading": loading,
		"back_disabled": not _surface_can("can_go_back"),
		"forward_disabled": not _surface_can("can_go_forward")
	})
	if ui != null:
		ui.set_value("browser-address", current_url)

func _setup_surface() -> void:
	if _surface != null and is_instance_valid(_surface):
		return
	if ui == null:
		return
	_surface = ui.by_id("browser-surface")
	if _surface != null:
		if _surface.has_signal("navigation_state_changed"):
			var sync_callable := Callable(self, "sync_from_surface")
			if not _surface.is_connected("navigation_state_changed", sync_callable):
				_surface.connect("navigation_state_changed", sync_callable)
		if _surface.has_method("set_chrome_visible"):
			_surface.call("set_chrome_visible", false)

func _setup_address_context_menu() -> void:
	if ui == null:
		return
	if _address_input != null and is_instance_valid(_address_input):
		return
	var node_value: Variant = ui.by_id("browser-address")
	if not (node_value is LineEdit):
		return
	_address_input = node_value as LineEdit
	var popup := PopupMenu.new()
	popup.name = "BrowserAddressContextMenu"
	popup.add_item("Cut", ADDRESS_MENU_CUT)
	popup.add_item("Copy", ADDRESS_MENU_COPY)
	popup.add_item("Paste", ADDRESS_MENU_PASTE)
	popup.add_separator()
	popup.add_item("Select All", ADDRESS_MENU_SELECT_ALL)
	popup.add_item("Clear", ADDRESS_MENU_CLEAR)
	popup.id_pressed.connect(_on_address_context_id_pressed)
	if _address_input.get_parent() != null:
		_address_input.get_parent().add_child(popup)
	_address_context_menu = popup
	var input_cb := Callable(self, "_on_address_input_gui_input")
	if not _address_input.gui_input.is_connected(input_cb):
		_address_input.gui_input.connect(input_cb)

func _on_address_input_gui_input(event: InputEvent) -> void:
	if _address_input == null or _address_context_menu == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_show_address_context_menu(mouse_event.global_position)
			if not _address_input.has_focus():
				_address_input.grab_focus()
			var viewport := _address_input.get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()

func _show_address_context_menu(global_position: Vector2) -> void:
	if _address_input == null or _address_context_menu == null:
		return
	var has_text: bool = _address_input.text != ""
	var has_selection: bool = _address_input.has_selection()
	var can_edit: bool = _address_input.editable
	var clipboard_available: bool = _clipboard_is_available()
	var can_paste: bool = can_edit and clipboard_available and DisplayServer.clipboard_get() != ""
	_address_context_menu.set_item_disabled(_address_context_menu.get_item_index(ADDRESS_MENU_CUT), (not can_edit) or (not has_selection))
	_address_context_menu.set_item_disabled(_address_context_menu.get_item_index(ADDRESS_MENU_COPY), (not clipboard_available) or (not has_selection))
	_address_context_menu.set_item_disabled(_address_context_menu.get_item_index(ADDRESS_MENU_PASTE), not can_paste)
	_address_context_menu.set_item_disabled(_address_context_menu.get_item_index(ADDRESS_MENU_SELECT_ALL), not has_text)
	_address_context_menu.set_item_disabled(_address_context_menu.get_item_index(ADDRESS_MENU_CLEAR), (not can_edit) or (not has_text))
	_address_context_menu.position = Vector2i(int(global_position.x), int(global_position.y))
	_address_context_menu.popup()

func _on_address_context_id_pressed(id: int) -> void:
	if _address_input == null:
		return
	match id:
		ADDRESS_MENU_CUT:
			_address_input.cut_text()
		ADDRESS_MENU_COPY:
			_address_input.copy_text()
		ADDRESS_MENU_PASTE:
			if _clipboard_is_available():
				_address_input.paste_text()
		ADDRESS_MENU_SELECT_ALL:
			_address_input.select_all()
		ADDRESS_MENU_CLEAR:
			_address_input.clear()
	if state != null:
		state.set("address", _address_input.text)

func _clipboard_is_available() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)

func debug_get_address_context_actions() -> Array[String]:
	if _address_context_menu == null:
		return []
	var labels: Array[String] = []
	for index in _address_context_menu.item_count:
		if _address_context_menu.is_item_separator(index):
			continue
		labels.append(_address_context_menu.get_item_text(index))
	return labels

func _event_or_address(event) -> String:
	if event != null and "value" in event and "target_id" in event and str(event.target_id) == "browser-address":
		var event_value: String = str(event.value).strip_edges()
		if event_value != "":
			return event_value
	if ui != null:
		var ui_value: Variant = ui.get_value("browser-address")
		if ui_value != null:
			return str(ui_value)
	if state != null:
		return str(state.get_value("address", DEFAULT_URL))
	return DEFAULT_URL

func _surface_can(method_name: String) -> bool:
	if _surface != null and _surface.has_method(method_name):
		return bool(_surface.call(method_name))
	return false

func _set_status(text: String) -> void:
	if state != null:
		state.set("status", text)
