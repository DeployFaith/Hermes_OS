class_name NotesApp
extends Control

var _shell: Node
var _inner: Control

func os_app_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_build()

func os_app_get_state() -> Dictionary:
	if _shell == null:
		return {}
	return {
		"active_note_id": _shell._notes_active_note_id,
		"open_notes": _shell._notes_open_notes.duplicate()
	}

func _build() -> void:
	if _shell == null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inner = _shell._build_notes_app_legacy()
	if _inner == null:
		return
	_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_inner)
