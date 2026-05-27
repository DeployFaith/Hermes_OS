class_name TerminalView
extends VBoxContainer

signal command_submitted(command: String)
signal history_previous_requested
signal history_next_requested
signal interrupt_requested
signal clear_requested
signal paste_requested
signal copy_requested

var _shell: Node
var _output: TextEdit
var _input: LineEdit

func terminal_view_init(context: Dictionary = {}) -> void:
	_shell = context.get("shell", null) as Node
	_build()

func focus_input() -> void:
	if _input != null:
		_input.grab_focus()

func get_output() -> TextEdit:
	return _output

func get_input() -> LineEdit:
	return _input

func get_input_text() -> String:
	return _input.text if _input != null else ""

func set_input_text(text: String, move_to_end: bool = true) -> void:
	if _input == null:
		return
	_input.text = text
	if move_to_end:
		_input.caret_column = _input.text.length()

func set_prompt(prompt: String) -> void:
	if _input != null:
		_input.placeholder_text = prompt

func render_text(text: String) -> void:
	if _output == null:
		return
	_output.text = text
	_output.scroll_vertical = max(_output.get_line_count() - 1, 0)

func clear_input() -> void:
	if _input != null:
		_input.text = ""

func _build() -> void:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)

	_output = TextEdit.new()
	_output.name = "TerminalOutput"
	_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.editable = false
	_output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_output.selecting_enabled = true
	_style_output(_output)
	_output.gui_input.connect(_on_output_gui_input)
	add_child(_output)

	_input = LineEdit.new()
	_input.name = "TerminalInput"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_input(_input)
	_input.text_submitted.connect(func(command: String) -> void:
		command_submitted.emit(command)
	)
	_input.gui_input.connect(_on_input_gui_input)
	add_child(_input)

func _on_input_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var command_key := key_event.ctrl_pressed or key_event.meta_pressed
	if command_key:
		match key_event.keycode:
			KEY_C:
				interrupt_requested.emit()
				accept_event()
			KEY_L:
				clear_requested.emit()
				accept_event()
			KEY_A:
				if _input != null:
					_input.caret_column = 0
				accept_event()
			KEY_E:
				if _input != null:
					_input.caret_column = _input.text.length()
				accept_event()
			KEY_V:
				paste_requested.emit()
				accept_event()
		return
	match key_event.keycode:
		KEY_UP:
			history_previous_requested.emit()
			accept_event()
		KEY_DOWN:
			history_next_requested.emit()
			accept_event()

func _on_output_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if (key_event.ctrl_pressed or key_event.meta_pressed) and key_event.keycode == KEY_C:
		copy_requested.emit()
		accept_event()

func _style_output(output: TextEdit) -> void:
	if _shell != null and _shell.has_method("_style_text_edit"):
		_shell.call("_style_text_edit", output)
		return
	output.add_theme_color_override("font_color", Color("d8dee9"))
	output.add_theme_color_override("font_readonly_color", Color("d8dee9"))
	output.add_theme_color_override("caret_color", Color("d8dee9"))

func _style_input(input: LineEdit) -> void:
	if _shell != null and _shell.has_method("_style_line_edit"):
		_shell.call("_style_line_edit", input)
		return
	input.add_theme_color_override("font_color", Color("d8dee9"))
	input.add_theme_color_override("caret_color", Color("d8dee9"))
	input.add_theme_color_override("font_placeholder_color", Color("7f8ea3"))
