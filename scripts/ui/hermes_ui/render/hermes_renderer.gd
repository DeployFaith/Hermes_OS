class_name HermesRenderer
extends RefCounted

const HermesRenderContext = preload("res://scripts/ui/hermes_ui/render/hermes_render_context.gd")
const HermesFlexContainer = preload("res://scripts/ui/hermes_ui/layout/hermes_flex_container.gd")
const HermesGridContainer = preload("res://scripts/ui/hermes_ui/layout/hermes_grid_container.gd")
const HermesScrollView = preload("res://scripts/ui/hermes_ui/layout/hermes_scroll_view.gd")

var context = null

func setup(render_context) -> void:
	context = render_context if render_context != null else HermesRenderContext.new()
	if context.registry == null:
		var registry_script = load("res://scripts/ui/hermes_ui/render/hermes_component_registry.gd")
		context.registry = registry_script.new()
	context.registry.register_defaults(self)

func render_tree(root_element, host: Control) -> Control:
	if context == null:
		setup(null)
	var control: Control = render_element(root_element)
	if control != null and host != null:
		host.add_child(control)
	if root_element != null and context.style_resolver != null and not context.stylesheets.is_empty():
		context.style_resolver.apply_tree(root_element, context.stylesheets)
	return control

func render_element(element) -> Control:
	if element == null:
		return null
	if element.node_type == "text":
		var text_label := Label.new()
		text_label.text = element.text_content
		element.control = text_label
		return text_label
	var component = context.registry.resolve(element.tag)
	var control: Control = null
	if component == null:
		control = make_unknown_control(element)
	else:
		control = component.render(element, context, self)
	if control == null:
		control = make_unknown_control(element)
	element.control = control
	control.set_meta("hermes_tag", element.tag)
	if element.id != "":
		control.set_meta("hermes_id", element.id)
	if component != null and bool(component.render_children):
		for child in element.children:
			var child_control: Control = render_element(child)
			if child_control != null:
				context.ui.add(control, child_control)
	return control

func find_by_id(root_element, target_id: String):
	if root_element == null:
		return null
	if root_element.id == target_id:
		return root_element
	for child in root_element.children:
		var found = find_by_id(child, target_id)
		if found != null:
			return found
	return null

func make_unknown_control(element) -> Control:
	var label := Label.new()
	label.name = "HermesUnknownComponent"
	label.text = "Unknown component <%s>" % element.tag
	return label

func _render_app(element, render_context, _renderer) -> Control:
	return render_context.ui.vbox([], render_context.theme.spacing("space_3"), {"name": "HermesRenderApp", "expand_h": true, "expand_v": true})

func _render_window(element, render_context, _renderer) -> Control:
	return render_context.ui.panel([], render_context.theme.spacing("panel"), "base", {"name": "HermesRenderWindow", "expand_h": true, "expand_v": true})

func _render_column(element, render_context, _renderer) -> Control:
	var control := HermesFlexContainer.new("column")
	control.name = "HermesRenderColumn"
	return control

func _render_row(element, render_context, _renderer) -> Control:
	var control := HermesFlexContainer.new("row")
	control.name = "HermesRenderRow"
	return control

func _render_panel(element, render_context, _renderer) -> Control:
	return render_context.ui.panel([], render_context.theme.spacing("panel"), "base", {"name": "HermesRenderPanel", "expand_h": true, "expand_v": true})

func _render_grid(element, _render_context, _renderer) -> Control:
	var control := HermesGridContainer.new()
	control.name = "HermesRenderGrid"
	return control

func _render_scroll_view(element, _render_context, _renderer) -> Control:
	var control := HermesScrollView.new()
	control.name = "HermesRenderScrollView"
	return control

func _render_text(element, render_context, _renderer) -> Control:
	return render_context.ui.label(element.get_text_content(), {"name": "HermesRenderText", "autowrap": true, "expand_h": true})

func _render_title(element, render_context, _renderer) -> Control:
	return render_context.ui.label(element.get_text_content(), {"variant": "heading", "name": "HermesRenderTitle", "expand_h": true})

func _render_button(element, render_context, _renderer) -> Control:
	return render_context.ui.button(element.get_text_content(), {"variant": str(element.props.get("variant", "secondary")), "disabled": str(element.props.get("disabled", "false")).to_lower() == "true", "name": "HermesRenderButton"})

func _render_text_input(element, render_context, _renderer) -> Control:
	return render_context.ui.input({"value": str(element.props.get("value", "")), "placeholder": str(element.props.get("placeholder", "")), "disabled": str(element.props.get("disabled", "false")).to_lower() == "true", "name": "HermesRenderTextInput", "expand_h": true})

func _render_badge(element, render_context, _renderer) -> Control:
	return render_context.ui.badge(element.get_text_content(), {"kind": str(element.props.get("variant", "info")), "name": "HermesRenderBadge"})
