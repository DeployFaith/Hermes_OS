class_name AgentCapabilityRegistry
extends RefCounted

var _metadata_by_operation: Dictionary = {}

func capability_registry_init() -> void:
	_metadata_by_operation.clear()
	_register_operation("files.list_dir", "filesystem.read", "low", false, "List directory entries for a virtual filesystem path", false)
	_register_operation("files.read_file", "filesystem.read", "low", false, "Read file content from the virtual filesystem", false)
	_register_operation("files.write_file", "filesystem.write", "high", true, "Write file content to the virtual filesystem", true)
	_register_operation("files.mkdir", "filesystem.write", "medium", true, "Create a virtual filesystem directory", true)
	_register_operation("files.delete", "filesystem.write", "high", true, "Delete a virtual filesystem path", true)
	_register_operation("files.move", "filesystem.write", "medium", true, "Move or rename a virtual filesystem path", true)
	_register_operation("files.copy", "filesystem.write", "medium", true, "Copy a virtual filesystem path", true)
	_register_operation("windows.list", "windows.read", "low", false, "List open windows and focus state", false)
	_register_operation("windows.open_app", "windows.manage", "medium", true, "Open an application window", false)
	_register_operation("windows.focus", "windows.manage", "low", true, "Focus an existing application window", false)
	_register_operation("notifications.create", "notifications.create", "low", true, "Create a desktop notification", false)
	_register_operation("system.get_state", "system.read", "medium", false, "Get a HermesOS state snapshot", false)
	_register_operation("browser.get_state", "browser.read", "low", false, "Get Browser URL/title/history/navigation state", false)
	_register_operation("browser.navigate", "browser.navigate", "medium", true, "Navigate Browser to a bundled Hermes Internet page", false)
	_register_operation("browser.back", "browser.navigate", "low", true, "Navigate Browser back in history", false)
	_register_operation("browser.forward", "browser.navigate", "low", true, "Navigate Browser forward in history", false)
	_register_operation("browser.reload", "browser.navigate", "low", true, "Reload the current Browser page", false)
	_register_operation("browser.list_links", "browser.read", "low", false, "List links on the current Browser page", false)
	_register_operation("browser.activate_link", "browser.navigate", "medium", true, "Activate a declared link on the current Browser page", false)
	_register_operation("input.press_key", "input.keyboard", "medium", true, "Press a key into focused Hermes_OS window", false)
	_register_operation("input.type_text", "input.keyboard", "medium", true, "Type text into focused Hermes_OS window", false)
	_register_operation("input.scroll", "input.pointer", "low", true, "Scroll within focused Hermes_OS window", false)
	_register_operation("input.drag_window", "windows.manage", "medium", true, "Drag/reposition Hermes_OS window with bounded deltas", false)
	_register_operation("windows.focus_window", "windows.manage", "low", true, "Compatibility alias for windows.focus", false)
	_register_operation("desktop.show_notification", "notifications.create", "low", true, "Compatibility alias for notifications.create", false)
	_register_operation("files.create_folder", "filesystem.write", "medium", true, "Compatibility alias for files.mkdir", true)
	_register_operation("readfile", "filesystem.read", "low", false, "Compatibility alias for files.read_file", false)
	_register_operation("writefile", "filesystem.write", "high", true, "Compatibility alias for files.write_file", true)
	_register_operation("listdir", "filesystem.read", "low", false, "Compatibility alias for files.list_dir", false)
	_register_operation("mkdir", "filesystem.write", "medium", true, "Compatibility alias for files.mkdir", true)

func get_supported_operations() -> Array[String]:
	var operations: Array[String] = []
	for op in _metadata_by_operation.keys():
		operations.append(str(op))
	operations.sort()
	return operations

func get_metadata(operation: String) -> Dictionary:
	var key: String = operation.strip_edges()
	if _metadata_by_operation.has(key):
		return (_metadata_by_operation[key] as Dictionary).duplicate(true)
	return _generic_metadata(key)

func describe_operation(operation: String) -> Dictionary:
	return get_metadata(operation)

func has_operation(operation: String) -> bool:
	return _metadata_by_operation.has(operation.strip_edges())

func _register_operation(operation: String, capability: String, risk: String, mutates_state: bool, description: String, requires_approval: bool) -> void:
	_metadata_by_operation[operation] = {
		"operation": operation,
		"capability": capability,
		"risk": risk,
		"mutates_state": mutates_state,
		"description": description,
		"requires_approval": requires_approval
	}

func _generic_metadata(operation: String) -> Dictionary:
	return {
		"operation": operation,
		"capability": "legacy.compat",
		"risk": "medium",
		"mutates_state": false,
		"description": "Legacy or unknown operation routed through compatibility dispatch",
		"requires_approval": false
	}
