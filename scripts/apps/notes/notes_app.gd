class_name NotesApp
extends Control

const Tokens = preload("res://scripts/os/design_tokens.gd")
const StyleFactory = preload("res://scripts/os/style_factory.gd")

var _shell: Node
var _fs: Object
var _root: VBoxContainer
var _path_label: Label
var _editor: TextEdit
var _status_label: Label
var _current_path: String = ""
var _active_note_id: String = ""
var _open_notes: Array[String] = []
var _dirty: bool = false

func os_app_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null) as Object
	if _fs == null and _shell != null:
		_fs = _shell._fs
	_build()
	var initial_state: Dictionary = context.get("state", {}) if context.get("state", {}) is Dictionary else {}
	if not initial_state.is_empty():
		os_app_restore_state(initial_state)

func os_app_focus() -> void:
	if _editor != null:
		_editor.grab_focus()

func os_app_close_requested() -> bool:
	# Preserve existing behavior: closing Notes never prompts or blocks.
	return true

func os_app_get_state() -> Dictionary:
	return {
		"active_note_id": _active_note_id,
		"open_notes": _open_notes.duplicate(),
		"current_path": _current_path,
		"dirty": _dirty,
		"content": _editor.text if _editor != null else ""
	}

func os_app_restore_state(state: Dictionary) -> void:
	var path := str(state.get("current_path", ""))
	if path != "" and _fs != null and bool(_fs.call("is_file", path)):
		open_file(path)
		return
	_active_note_id = str(state.get("active_note_id", ""))
	_open_notes.clear()
	var restored_open_notes: Variant = state.get("open_notes", [])
	if restored_open_notes is Array:
		for note_id in restored_open_notes:
			_open_note_id(str(note_id))
	if _editor != null:
		_editor.text = str(state.get("content", ""))
	_dirty = bool(state.get("dirty", false))
	_update_path_label()

func open_note(note_id_or_path: String) -> Dictionary:
	return open_file(_note_path_from_id(note_id_or_path))

func open_file(path: String) -> Dictionary:
	if _fs == null:
		_set_status("Filesystem unavailable", true)
		return {"ok": false, "error": "Filesystem unavailable"}
	var target_path := str(_fs.call("normalize_path", path))
	if not bool(_fs.call("is_file", target_path)):
		_set_status("Note not found: " + target_path, true)
		return {"ok": false, "error": "Note not found: " + target_path}
	var read_result: Dictionary = _fs.call("read_file_result", target_path)
	if not bool(read_result.get("ok", false)):
		var error := str(read_result.get("error", "Could not read note"))
		_set_status(error, true)
		return {"ok": false, "error": error}
	_current_path = target_path
	_active_note_id = target_path.get_file()
	_open_note_id(_active_note_id)
	if _editor != null:
		_editor.text = str(read_result.get("content", ""))
		_editor.editable = true
	_dirty = false
	_update_path_label()
	_set_status("Opened " + _active_note_id)
	return {"ok": true, "path": target_path, "note_id": _active_note_id}

func save_note() -> Dictionary:
	if _fs == null:
		_set_status("Filesystem unavailable", true)
		return {"ok": false, "error": "Filesystem unavailable"}
	if _current_path == "" or _editor == null:
		_set_status("No note selected", true)
		return {"ok": false, "error": "No note selected"}
	var message := str(_fs.call("write_file", _current_path, _editor.text))
	var ok := message == ""
	if ok:
		_dirty = false
		_active_note_id = _current_path.get_file()
		_open_note_id(_active_note_id)
	_set_status(message if message != "" else "Saved", not ok)
	return {"ok": ok, "error": message, "path": _current_path, "note_id": _active_note_id}

func save_file() -> Dictionary:
	return save_note()

func set_note_content(content: String, dirty: bool = false) -> void:
	if _editor != null:
		_editor.text = content
	_dirty = dirty

func get_current_path() -> String:
	return _current_path

func get_active_note_id() -> String:
	return _active_note_id

func is_dirty() -> bool:
	return _dirty

func _build() -> void:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_root = VBoxContainer.new()
	_root.name = "NotesRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 8)
	add_child(_root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_root.add_child(header)

	_path_label = Label.new()
	_path_label.name = "NotesPathLabel"
	_path_label.text = "No note opened"
	_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_path_label.add_theme_color_override("font_color", Tokens.MUTED)
	header.add_child(_path_label)

	var save_button := _make_button("Save", Vector2(70, 30))
	save_button.name = "NotesSaveButton"
	save_button.pressed.connect(func() -> void:
		save_note()
	)
	header.add_child(save_button)

	_editor = TextEdit.new()
	_editor.name = "NotesEditor"
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor.text = ""
	_editor.editable = true
	_style_text_edit(_editor)
	_editor.text_changed.connect(func() -> void:
		_dirty = true
	)
	_root.add_child(_editor)

	_status_label = _make_label("", 12, Tokens.MUTED)
	_status_label.name = "NotesStatusLabel"
	_root.add_child(_status_label)
	_set_status("Notes stored in " + _notes_directory_path())

func _notes_directory_path() -> String:
	if _fs == null:
		return "/notes"
	return str(_fs.call("join_path", str(_fs.call("home_path")), "notes"))

func _note_path_from_id(note_id: String) -> String:
	if _fs == null:
		return note_id
	if note_id.begins_with("/"):
		return str(_fs.call("normalize_path", note_id))
	var file_name := note_id.strip_edges()
	if file_name == "":
		file_name = "untitled"
	if not file_name.ends_with(".txt"):
		file_name += ".txt"
	return str(_fs.call("join_path", _notes_directory_path(), file_name))

func _open_note_id(note_id: String) -> void:
	if note_id == "" or _open_notes.has(note_id):
		return
	_open_notes.append(note_id)

func _update_path_label() -> void:
	if _path_label == null:
		return
	if _current_path == "":
		_path_label.text = "No note opened"
		_path_label.tooltip_text = ""
	else:
		_path_label.text = _current_path
		_path_label.tooltip_text = _current_path

func _set_status(message: String, is_error: bool = false) -> void:
	if _status_label == null:
		return
	if _shell != null and _shell.has_method("_set_status"):
		_shell.call("_set_status", _status_label, message, is_error)
		return
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Tokens.ERROR if is_error else Tokens.MUTED)

func _make_button(text_value: String, min_size: Vector2) -> Button:
	if _shell != null and _shell.has_method("_button"):
		return _shell.call("_button", text_value, min_size) as Button
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = min_size
	button.add_theme_color_override("font_color", Tokens.TEXT)
	button.add_theme_stylebox_override("normal", StyleFactory.button_normal(8))
	button.add_theme_stylebox_override("hover", StyleFactory.button_hover(8))
	button.add_theme_stylebox_override("pressed", StyleFactory.button_pressed(8))
	button.add_theme_stylebox_override("focus", StyleFactory.button_focus(8))
	button.add_theme_stylebox_override("disabled", StyleFactory.button_disabled(8))
	return button

func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	if _shell != null and _shell.has_method("_label"):
		return _shell.call("_label", text_value, font_size, color) as Label
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _style_text_edit(input: TextEdit) -> void:
	if _shell != null and _shell.has_method("_style_text_edit"):
		_shell.call("_style_text_edit", input)
		return
	input.add_theme_color_override("font_color", Tokens.TEXT)
	input.add_theme_color_override("font_readonly_color", Tokens.MUTED)
	input.add_theme_color_override("caret_color", Tokens.TEXT)
	input.add_theme_stylebox_override("normal", StyleFactory.input_normal(8))
	input.add_theme_stylebox_override("focus", StyleFactory.input_focus(8))
	input.add_theme_stylebox_override("read_only", StyleFactory.build(Tokens.alpha(Tokens.PANEL, 0.5), Tokens.BORDER, 1, 8))
