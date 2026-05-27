class_name TerminalFSCommands
extends RefCounted

const COMMANDS: Array[String] = ["pwd", "ls", "cd", "mkdir", "touch", "cat", "read", "echo", "rm", "clear"]

func has_command(command: String) -> bool:
	return COMMANDS.has(command)

func help_entries() -> Array[String]:
	return [
		"pwd",
		"ls [path]",
		"cd [path]",
		"mkdir <path>",
		"touch <path>",
		"cat <path>",
		"echo <text> [> path]",
		"rm <path>",
		"clear"
	]

func execute(command: String, parsed: Dictionary, backend: Object) -> Dictionary:
	match command:
		"pwd":
			return backend.call("make_result", [backend.call("get_cwd")])
		"ls":
			return _cmd_ls(parsed, backend)
		"cd":
			return _cmd_cd(parsed, backend)
		"mkdir":
			return _cmd_mkdir(parsed, backend)
		"touch":
			return _cmd_touch(parsed, backend)
		"cat", "read":
			return _cmd_cat(parsed, backend)
		"echo":
			return _cmd_echo(parsed, backend)
		"rm":
			return _cmd_rm(parsed, backend)
		"clear":
			return backend.call("make_result", [], [], 0, true)
	return backend.call("make_result", [], ["Unknown command: " + command], 1)

func _args(parsed: Dictionary) -> Array:
	return parsed.get("args", []) if parsed.get("args", []) is Array else []

func _cmd_ls(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	var target := str(backend.call("get_cwd"))
	if args.size() >= 1:
		target = str(backend.call("resolve_path", str(args[0])))
	if not bool(backend.call("is_dir", target)):
		return backend.call("make_result", [], ["Folder not found: " + target], 1)
	if not bool(backend.call("can_list_dir", target)):
		return backend.call("make_result", [], ["Permission denied: " + target], 1)
	var entries_value: Variant = backend.call("list_dir", target)
	var entries: Array = entries_value if entries_value is Array else []
	var lines: Array[String] = []
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var name := str(entry.get("name", ""))
		if str(entry.get("type", "")) == "dir":
			name += "/"
		lines.append(name)
	return backend.call("make_result", lines)

func _cmd_cd(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	var target := str(backend.call("home_path"))
	if args.size() >= 1:
		target = str(backend.call("resolve_path", str(args[0])))
	if not bool(backend.call("is_dir", target)):
		return backend.call("make_result", [], ["Folder not found: " + target], 1)
	if not bool(backend.call("can_list_dir", target)):
		return backend.call("make_result", [], ["Permission denied: " + target], 1)
	backend.call("set_cwd", target)
	return backend.call("make_result", [target])

func _cmd_mkdir(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	if args.is_empty():
		return backend.call("make_result", [], ["Usage: mkdir <path>"], 1)
	var target := str(backend.call("resolve_path", str(args[0])))
	var result: Dictionary = backend.call("make_dir", target)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("error", "Could not create folder"))], 1)
	return backend.call("make_result", ["Folder created"])

func _cmd_touch(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	if args.is_empty():
		return backend.call("make_result", [], ["Usage: touch <path>"], 1)
	var target := str(backend.call("resolve_path", str(args[0])))
	var content := ""
	if bool(backend.call("is_file", target)):
		var existing: Dictionary = backend.call("read_file", target)
		if bool(existing.get("ok", false)):
			content = str(existing.get("content", ""))
	var result: Dictionary = backend.call("write_file", target, content)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("error", "Could not touch file"))], 1)
	return backend.call("make_result", ["File touched"])

func _cmd_cat(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	if args.is_empty():
		return backend.call("make_result", [], ["Usage: cat <path>"], 1)
	var target := str(backend.call("resolve_path", str(args[0])))
	var result: Dictionary = backend.call("read_file", target)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("error", "Could not read file"))], 1)
	return backend.call("make_result", [str(result.get("content", ""))])

func _cmd_echo(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	var content := " ".join(args)
	var redirect_path := str(parsed.get("redirect_path", ""))
	if redirect_path != "":
		var target := str(backend.call("resolve_path", redirect_path))
		var result: Dictionary = backend.call("write_file", target, content)
		if not bool(result.get("ok", false)):
			return backend.call("make_result", [], [str(result.get("error", "Could not write file"))], 1)
		return backend.call("make_result", [])
	return backend.call("make_result", [content])

func _cmd_rm(parsed: Dictionary, backend: Object) -> Dictionary:
	var args := _args(parsed)
	if args.is_empty():
		return backend.call("make_result", [], ["Usage: rm <path>"], 1)
	var target := str(backend.call("resolve_path", str(args[0])))
	var result: Dictionary = backend.call("delete_path", target)
	if not bool(result.get("ok", false)):
		return backend.call("make_result", [], [str(result.get("error", "Could not delete path"))], 1)
	return backend.call("make_result", ["Deleted"])
