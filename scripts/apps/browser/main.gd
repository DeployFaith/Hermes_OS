extends "res://scripts/ui/hermes_ui/runtime/hermes_app_controller.gd"

const DEFAULT_URL := "http://home.hermes/"
const NEW_TAB_URL := DEFAULT_URL

var _shell: Node = null
var _fs: Object = null
var _browser_app: Object = null
var _surface: Control = null

func configure_app_context(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	var browser_value: Variant = context.get("browser_app", null)
	if browser_value is Object:
		_browser_app = browser_value as Object
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
	if _surface != null and _surface.has_method("set_chrome_visible"):
		_surface.call("set_chrome_visible", false)

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
