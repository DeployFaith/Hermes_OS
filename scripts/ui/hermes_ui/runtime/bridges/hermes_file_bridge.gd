class_name HermesFileBridge
extends RefCounted

var _filesystem = null

func setup(context: Dictionary) -> HermesFileBridge:
	_filesystem = context.get("filesystem", null)
	return self

func pick() -> Dictionary:
	return {"ok": false, "error": {"code": "FILE_PICKER_UNAVAILABLE", "message": "HermesOS does not expose a controller-safe file picker yet", "details": {}}}

func read(path: String) -> Dictionary:
	if _filesystem == null:
		return _fail("FILES_UNAVAILABLE", "HermesOS filesystem service is unavailable")
	if _filesystem.has_method("read_file_result"):
		var result: Variant = _filesystem.call("read_file_result", path)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	if _filesystem.has_method("read_file"):
		return {"ok": true, "path": path, "content": str(_filesystem.call("read_file", path))}
	return _fail("FILES_READ_UNAVAILABLE", "HermesOS filesystem read API is unavailable")

func write(path: String, content: String) -> Dictionary:
	if _filesystem == null:
		return _fail("FILES_UNAVAILABLE", "HermesOS filesystem service is unavailable")
	if _filesystem.has_method("write_file"):
		var result: Variant = _filesystem.call("write_file", path, content)
		var message: String = str(result)
		return {"ok": message == "", "path": path, "error": {"code": "FILES_WRITE_FAILED", "message": message, "details": {}} if message != "" else {}}
	return _fail("FILES_WRITE_UNAVAILABLE", "HermesOS filesystem write API is unavailable")

func _fail(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message, "details": {}}}
