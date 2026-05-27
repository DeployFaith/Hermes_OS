class_name TerminalAppCommands
extends RefCounted

const COMMANDS: Array[String] = ["help", "open"]

func has_command(command: String) -> bool:
	return COMMANDS.has(command)

func help_entries() -> Array[String]:
	return [
		"help",
		"open <path|app_id>"
	]

func execute(command: String, parsed: Dictionary, backend: Object) -> Dictionary:
	match command:
		"help":
			return backend.call("make_result", [str(backend.call("get_help_text"))])
		"open":
			return _cmd_open(parsed, backend)
	return backend.call("make_result", [], ["Unknown command: " + command], 1)

func _cmd_open(parsed: Dictionary, backend: Object) -> Dictionary:
	var args: Array = parsed.get("args", []) if parsed.get("args", []) is Array else []
	if args.is_empty():
		return backend.call("make_result", [], ["Usage: open <path|app_id>"], 1)
	var target := str(args[0])
	var result: Dictionary = backend.call("open_target", target)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("error", "Could not open target"))], 1)
	return backend.call("make_result", [str(result.get("message", "Opened " + target))])
