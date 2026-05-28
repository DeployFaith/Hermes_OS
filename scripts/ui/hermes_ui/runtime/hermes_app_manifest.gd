class_name HermesAppManifest
extends RefCounted

var manifest_path: String = ""
var app_dir: String = ""
var app_id: String = ""
var name: String = ""
var version: String = ""
var hermes_ui_version: String = ""
var icon_path: String = ""
var entry_path: String = ""
var styles_paths: Array[String] = []
var controller_path: String = ""
var surface: String = "window"
var window_config: Dictionary = {}
var permissions: Array[String] = []
var raw_data: Dictionary = {}

func load_from_dictionary(data: Dictionary, source_path: String) -> void:
	manifest_path = source_path
	app_dir = source_path.get_base_dir()
	raw_data = data.duplicate(true)
	app_id = str(data.get("id", "")).strip_edges()
	name = str(data.get("name", app_id)).strip_edges()
	version = str(data.get("version", "0.1.0")).strip_edges()
	hermes_ui_version = str(data.get("hermes_ui", "0.1")).strip_edges()
	icon_path = _normalize_path(str(data.get("icon", "")).strip_edges())
	entry_path = _normalize_path(str(data.get("entry", "")).strip_edges())
	controller_path = _normalize_path(str(data.get("controller", "")).strip_edges())
	surface = str(data.get("surface", "window")).strip_edges()
	window_config = (data.get("window", {}) as Dictionary).duplicate(true)
	styles_paths.clear()
	var styles_value: Variant = data.get("styles", [])
	if styles_value is Array:
		for item in styles_value:
			styles_paths.append(_normalize_path(str(item).strip_edges()))
	permissions.clear()
	var permissions_value: Variant = data.get("permissions", [])
	if permissions_value is Array:
		for item in permissions_value:
			permissions.append(str(item).strip_edges())
	if window_config.is_empty():
		window_config = {
			"title": name,
			"default_width": 720,
			"default_height": 520,
			"min_width": 520,
			"min_height": 360,
			"resizable": true,
			"chromed": true,
		}
	if str(window_config.get("title", "")).strip_edges() == "":
		window_config["title"] = name

func _normalize_path(value: String) -> String:
	if value == "":
		return ""
	if value.begins_with("res://") or value.begins_with("user://"):
		return value
	return app_dir.path_join(value)
