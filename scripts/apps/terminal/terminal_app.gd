class_name TerminalApp
extends VBoxContainer

var _shell: Node
var _state: Dictionary = {}
var _output: TextEdit
var _input: LineEdit

func os_app_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_state = context.get("state", {}) if context.get("state", {}) is Dictionary else {}
	if _state.is_empty() and _shell != null:
		_state = {"cwd": _shell._fs.home_path()}
	_build()

func os_app_focus() -> void:
	if _input != null:
		_input.grab_focus()

func os_app_get_state() -> Dictionary:
	return _state.duplicate(true)

func _exit_tree() -> void:
	if _shell != null and _output != null:
		_shell._unregister_console_output(_output)

func _build() -> void:
	if _shell == null:
		return
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)

	_output = TextEdit.new()
	_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.editable = false
	_shell._style_text_edit(_output)
	_shell._register_console_output(_output)
	_output.text = _shell._console_history_text()
	add_child(_output)

	_input = LineEdit.new()
	_input.placeholder_text = _shell._console_prompt(_state)
	_shell._style_line_edit(_input)
	_input.text_submitted.connect(func(command: String) -> void:
		_shell._handle_console_command(command, _input, _state)
	)
	add_child(_input)
