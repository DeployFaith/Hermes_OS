class_name TerminalBuffer
extends RefCounted

const DEFAULT_MAX_LINES := 800
const ESC := ""

var _lines: Array[String] = []
var _max_lines: int = DEFAULT_MAX_LINES

func terminal_buffer_init(options: Dictionary = {}) -> void:
	_max_lines = maxi(int(options.get("max_lines", DEFAULT_MAX_LINES)), 1)
	var intro := str(options.get("intro", "")).strip_edges()
	if intro != "":
		append_line(intro)

func clear() -> void:
	_lines.clear()

func append_prompt_command(prompt: String, command: String) -> void:
	var line := prompt
	if command.strip_edges() != "":
		line += " " + command
	append_line(line)

func append_output(text: String) -> void:
	var decoded: Dictionary = _decode_ansi(text)
	if bool(decoded.get("clear_screen", false)):
		clear()
	var plain := str(decoded.get("text", ""))
	if plain == "":
		return
	var parts := plain.split("\n", true)
	for part in parts:
		append_line(str(part))

func append_line(text: String) -> void:
	_lines.append(text)
	_trim_scrollback()

func append_lines(lines: Array) -> void:
	for line in lines:
		append_line(str(line))

func get_text() -> String:
	return "\n".join(_lines)

func get_lines() -> Array[String]:
	var result: Array[String] = []
	for line in _lines:
		result.append(line)
	return result

func line_count() -> int:
	return _lines.size()

func _trim_scrollback() -> void:
	if _lines.size() <= _max_lines:
		return
	_lines = _lines.slice(_lines.size() - _max_lines, _lines.size())

func _decode_ansi(text: String) -> Dictionary:
	var clear_screen := false
	var output := ""
	var index := 0
	while index < text.length():
		var ch := text[index]
		if ch == ESC and index + 1 < text.length() and text[index + 1] == "[":
			var sequence_start := index
			index += 2
			while index < text.length():
				var code := text.unicode_at(index)
				if code >= 64 and code <= 126:
					var command := text[index]
					var params := text.substr(sequence_start + 2, index - sequence_start - 2)
					if command == "J" and (params == "2" or params == "3"):
						clear_screen = true
					index += 1
					break
				index += 1
			continue
		output += ch
		index += 1
	return {"clear_screen": clear_screen, "text": output}
