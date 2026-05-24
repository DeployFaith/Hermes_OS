class_name TextEditorApp
extends Control

var _shell: Node
var _inner: Control

func os_app_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_build()

func os_app_get_state() -> Dictionary:
	if _shell == null:
		return {}
	return {"current_path": _shell._text_app_current_path}

func _build() -> void:
	if _shell == null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inner = _shell._build_text_app_legacy()
	if _inner == null:
		return
	_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_inner)
