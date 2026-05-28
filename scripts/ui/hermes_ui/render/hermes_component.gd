class_name HermesComponent
extends RefCounted

var tag_name: String = ""
var render_callable: Callable = Callable()
var render_children: bool = true

func _init(p_tag_name: String = "", p_render_callable: Callable = Callable(), p_render_children: bool = true) -> void:
	tag_name = p_tag_name
	render_callable = p_render_callable
	render_children = p_render_children

func render(element, context, renderer) -> Control:
	if render_callable.is_valid():
		return render_callable.call(element, context, renderer)
	return renderer.make_unknown_control(element)
