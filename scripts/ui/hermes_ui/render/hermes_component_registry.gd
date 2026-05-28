class_name HermesComponentRegistry
extends RefCounted

const HermesComponent = preload("res://scripts/ui/hermes_ui/render/hermes_component.gd")

var _components: Dictionary = {}

func register_component(tag_name: String, component) -> void:
	if tag_name.strip_edges() == "" or component == null:
		return
	_components[tag_name] = component

func has_component(tag_name: String) -> bool:
	return _components.has(tag_name)

func resolve(tag_name: String):
	return _components.get(tag_name, null)

func register_defaults(renderer) -> void:
	if not _components.is_empty():
		return
	register_component("App", HermesComponent.new("App", Callable(renderer, "_render_app"), true, "application"))
	register_component("Window", HermesComponent.new("Window", Callable(renderer, "_render_window"), true, "window"))
	register_component("Column", HermesComponent.new("Column", Callable(renderer, "_render_column"), true, "group"))
	register_component("Row", HermesComponent.new("Row", Callable(renderer, "_render_row"), true, "group"))
	register_component("Panel", HermesComponent.new("Panel", Callable(renderer, "_render_panel"), true, "region"))
	register_component("Grid", HermesComponent.new("Grid", Callable(renderer, "_render_grid"), true, "group"))
	register_component("ScrollView", HermesComponent.new("ScrollView", Callable(renderer, "_render_scroll_view"), true, "scrollarea"))
	register_component("Text", HermesComponent.new("Text", Callable(renderer, "_render_text"), false, "text"))
	register_component("Title", HermesComponent.new("Title", Callable(renderer, "_render_title"), false, "heading"))
	register_component("Button", HermesComponent.new("Button", Callable(renderer, "_render_button"), false, "button"))
	register_component("TextInput", HermesComponent.new("TextInput", Callable(renderer, "_render_text_input"), false, "textbox"))
	register_component("Badge", HermesComponent.new("Badge", Callable(renderer, "_render_badge"), false, "status"))
