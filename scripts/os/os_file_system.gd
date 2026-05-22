class_name OSFileSystem
extends RefCounted

const SAVE_PATH := "user://godot_os_files.json"
const ROOT_USER := "root"
const DEFAULT_USERNAME := "user"
const DEFAULT_UID := 1000

var _state: Dictionary = {}
var _tree: Dictionary = {}

func load_or_create() -> void:
	_state = _empty_state()
	_tree = _state["tree"]
	if not FileAccess.file_exists(SAVE_PATH):
		_ensure_system_layout()
		save()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_ensure_system_layout()
		return
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var parsed_dict: Dictionary = parsed
		if _is_valid_state(parsed_dict):
			_state = parsed_dict
			_tree = _state["tree"]
		elif _is_valid_tree(parsed_dict):
			_state = _empty_state()
			_state["tree"] = parsed_dict
			_tree = _state["tree"]
		else:
			_state = _empty_state()
			_tree = _state["tree"]
	else:
		_state = _empty_state()
		_tree = _state["tree"]
	_ensure_system_layout()
	save()

func save() -> void:
	_state["tree"] = _tree
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save virtual filesystem")
		return
	file.store_string(JSON.stringify(_state, "\t"))

func reset() -> void:
	_state = _empty_state()
	_tree = _state["tree"]
	_ensure_system_layout()
	save()

func export_state() -> Dictionary:
	_state["tree"] = _tree
	return _state.duplicate(true)

func import_state(state: Dictionary) -> String:
	if not _is_valid_state(state):
		return "Invalid Godot OS filesystem state"
	_state = state.duplicate(true)
	_tree = _state["tree"]
	_ensure_system_layout()
	save()
	return ""

func current_user() -> String:
	return str(_state.get("current_user", DEFAULT_USERNAME))

func set_current_user(username: String) -> String:
	var clean := clean_username(username)
	if clean == "":
		return "Usage: su <user>"
	if not user_exists(clean):
		return "Unknown user: " + clean
	_state["current_user"] = clean
	save()
	return ""

func authenticate_user(username: String, password: String) -> Dictionary:
	var clean := clean_username(username)
	if clean == "" or not user_exists(clean):
		return {"ok": false, "error": "Unknown user"}
	var users: Dictionary = _state.get("users", {})
	var account: Dictionary = users[clean]
	var expected := str(account.get("password_hash", _password_hash("")))
	if expected != _password_hash(password):
		return {"ok": false, "error": "Incorrect password"}
	return {"ok": true, "error": "", "user": clean}

func set_current_user_authenticated(username: String, password: String) -> String:
	var auth := authenticate_user(username, password)
	if not bool(auth.get("ok", false)):
		return str(auth.get("error", "Authentication failed"))
	return set_current_user(str(auth.get("user", username)))

func set_user_password(username: String, new_password: String, current_password := "") -> String:
	var clean := clean_username(username)
	if clean == "" or not user_exists(clean):
		return "Unknown user: " + username
	if current_user() != ROOT_USER:
		if clean != current_user():
			return "Permission denied: passwd can only change your own password"
		var auth := authenticate_user(clean, current_password)
		if not bool(auth.get("ok", false)):
			return str(auth.get("error", "Authentication failed"))
	var users: Dictionary = _state.get("users", {})
	var account: Dictionary = users[clean]
	account["password_hash"] = _password_hash(new_password)
	users[clean] = account
	_state["users"] = users
	_sync_system_files()
	save()
	return ""

func user_exists(username: String) -> bool:
	var users: Dictionary = _state.get("users", {})
	return users.has(username)

func add_user(username: String) -> String:
	if current_user() != ROOT_USER:
		return "Permission denied: useradd requires root"
	var clean := clean_username(username)
	if clean == "":
		return "Username must contain only letters, numbers, '_' or '-'"
	if user_exists(clean):
		return "User already exists: " + clean
	var users: Dictionary = _state.get("users", {})
	var next_uid := DEFAULT_UID
	for key in users.keys():
		var account: Dictionary = users[key]
		next_uid = maxi(next_uid, int(account.get("uid", DEFAULT_UID)) + 1)
	users[clean] = {
		"uid": next_uid,
		"gid": next_uid,
		"group": clean,
		"home": "/home/" + clean,
		"shell": "/bin/sh",
		"groups": [clean],
		"password_hash": _password_hash("")
	}
	_state["users"] = users
	_force_dir("/home/" + clean, clean, clean, "0755")
	_sync_system_files()
	save()
	return ""

func get_users() -> Array[String]:
	var users: Dictionary = _state.get("users", {})
	var result: Array[String] = []
	for key in users.keys():
		result.append(str(key))
	result.sort()
	return result

func home_path(username := "") -> String:
	var target := username if username != "" else current_user()
	var users: Dictionary = _state.get("users", {})
	if users.has(target):
		var account: Dictionary = users[target]
		return str(account.get("home", "/home/" + target))
	return "/home/" + target

func user_id_text(username := "") -> String:
	var target := username if username != "" else current_user()
	var users: Dictionary = _state.get("users", {})
	if not users.has(target):
		return "Unknown user: " + target
	var account: Dictionary = users[target]
	var group := str(account.get("group", target))
	return "uid=%d(%s) gid=%d(%s) groups=%s" % [
		int(account.get("uid", 0)),
		target,
		int(account.get("gid", 0)),
		group,
		_groups_text(account)
	]

func list_dir(path: String) -> Array[Dictionary]:
	var node := get_node_at(path)
	var result: Array[Dictionary] = []
	if node.is_empty() or str(node.get("type", "")) != "dir":
		return result
	if not _can_read(node, current_user()) or not _can_execute(node, current_user()):
		return result

	var children: Dictionary = node.get("children", {})
	var names: Array[String] = []
	for key in children.keys():
		names.append(str(key))
	names.sort()

	for name in names:
		var child: Dictionary = children[name]
		var type := str(child.get("type", "file"))
		result.append({
			"name": name,
			"type": type,
			"path": join_path(normalize_path(path), name),
			"size": _node_size(child),
			"owner": str(child.get("owner", DEFAULT_USERNAME)),
			"group": str(child.get("group", str(child.get("owner", DEFAULT_USERNAME)))),
			"mode": str(child.get("mode", "0644" if type == "file" else "0755"))
		})
	return result

func exists(path: String) -> bool:
	return not get_node_at(path).is_empty()

func is_dir(path: String) -> bool:
	var node := get_node_at(path)
	return not node.is_empty() and str(node.get("type", "")) == "dir"

func is_file(path: String) -> bool:
	var node := get_node_at(path)
	return not node.is_empty() and str(node.get("type", "")) == "file"

func can_list_dir(path: String) -> bool:
	var node := get_node_at(path)
	return not node.is_empty() and str(node.get("type", "")) == "dir" and _can_read(node, current_user()) and _can_execute(node, current_user())

func read_file(path: String) -> String:
	var result := read_file_result(path)
	if not bool(result.get("ok", false)):
		return ""
	return str(result.get("content", ""))

func read_file_result(path: String) -> Dictionary:
	var normalized := normalize_path(path)
	var node := get_node_at(normalized)
	if node.is_empty() or str(node.get("type", "")) != "file":
		return {"ok": false, "error": "File not found: " + normalized, "content": ""}
	if not _can_read(node, current_user()):
		return {"ok": false, "error": "Permission denied: " + normalized, "content": ""}
	return {"ok": true, "error": "", "content": str(node.get("content", ""))}

func write_file(path: String, content: String) -> String:
	var normalized := normalize_path(path)
	var info := _parent_info(normalized)
	if not bool(info.get("ok", false)):
		return str(info.get("error", "Invalid path"))

	var parent: Dictionary = info["parent"]
	var parent_path_text := parent_path(normalized)
	var name := str(info["name"])
	var children: Dictionary = parent.get("children", {})
	if children.has(name):
		var existing: Dictionary = children[name]
		if str(existing.get("type", "")) == "dir":
			return "A folder already exists at " + normalized
		if not _can_write(existing, current_user()):
			return "Permission denied: " + normalized
		existing["content"] = content
		children[name] = existing
	else:
		if not _can_write(parent, current_user()) or not _can_execute(parent, current_user()):
			return "Permission denied: " + parent_path_text
		children[name] = _file_node(content, current_user(), _primary_group(current_user()), "0644")
	parent["children"] = children
	save()
	return ""

func make_dir(path: String) -> String:
	var normalized := normalize_path(path)
	var info := _parent_info(normalized)
	if not bool(info.get("ok", false)):
		return str(info.get("error", "Invalid path"))

	var parent: Dictionary = info["parent"]
	var parent_path_text := parent_path(normalized)
	if not _can_write(parent, current_user()) or not _can_execute(parent, current_user()):
		return "Permission denied: " + parent_path_text
	var name := str(info["name"])
	var children: Dictionary = parent.get("children", {})
	if children.has(name):
		return "Path already exists: " + normalized
	children[name] = _dir_node(current_user(), _primary_group(current_user()), "0755")
	parent["children"] = children
	save()
	return ""

func delete_path(path: String) -> String:
	var normalized := normalize_path(path)
	if normalized == "/":
		return "Cannot delete root"
	if _is_protected_system_path(normalized):
		return "Cannot delete protected system path: " + normalized
	var info := _parent_info(normalized)
	if not bool(info.get("ok", false)):
		return str(info.get("error", "Invalid path"))

	var parent: Dictionary = info["parent"]
	var parent_path_text := parent_path(normalized)
	if not _can_write(parent, current_user()) or not _can_execute(parent, current_user()):
		return "Permission denied: " + parent_path_text
	var name := str(info["name"])
	var children: Dictionary = parent.get("children", {})
	if not children.has(name):
		return "Path not found: " + normalized
	var target: Dictionary = children[name]
	if _has_sticky_bit(parent) and current_user() != ROOT_USER and current_user() != str(target.get("owner", "")) and current_user() != str(parent.get("owner", "")):
		return "Permission denied: " + normalized
	children.erase(name)
	parent["children"] = children
	save()
	return ""

func rename_path(path: String, new_name: String) -> String:
	var normalized := normalize_path(path)
	if normalized == "/":
		return "Cannot rename root"
	if _is_protected_system_path(normalized):
		return "Cannot rename protected system path: " + normalized
	var clean_name := _clean_name(new_name)
	if clean_name == "":
		return "Name is required"

	var info := _parent_info(normalized)
	if not bool(info.get("ok", false)):
		return str(info.get("error", "Invalid path"))

	var parent: Dictionary = info["parent"]
	var parent_path_text := parent_path(normalized)
	if not _can_write(parent, current_user()) or not _can_execute(parent, current_user()):
		return "Permission denied: " + parent_path_text
	var old_name := str(info["name"])
	var children: Dictionary = parent.get("children", {})
	if not children.has(old_name):
		return "Path not found: " + normalized
	if children.has(clean_name):
		return "Path already exists: " + join_path(parent_path_text, clean_name)

	children[clean_name] = children[old_name]
	children.erase(old_name)
	parent["children"] = children
	save()
	return ""

func copy_path(source_path: String, destination_path: String) -> String:
	var source := normalize_path(source_path)
	var destination := normalize_path(destination_path)
	if source == "/":
		return "Cannot copy root"
	var source_node := get_node_at(source)
	if source_node.is_empty():
		return "Path not found: " + source
	if not _can_read(source_node, current_user()):
		return "Permission denied: " + source
	if str(source_node.get("type", "")) == "dir" and not _can_execute(source_node, current_user()):
		return "Permission denied: " + source

	var info := _parent_info(destination)
	if not bool(info.get("ok", false)):
		return str(info.get("error", "Invalid path"))
	var parent: Dictionary = info["parent"]
	var parent_path_text := parent_path(destination)
	if not _can_write(parent, current_user()) or not _can_execute(parent, current_user()):
		return "Permission denied: " + parent_path_text
	var name := str(info["name"])
	var children: Dictionary = parent.get("children", {})
	if children.has(name):
		return "Path already exists: " + destination
	children[name] = _copy_node(source_node, current_user(), _primary_group(current_user()))
	parent["children"] = children
	save()
	return ""

func move_path(source_path: String, destination_path: String) -> String:
	var source := normalize_path(source_path)
	var destination := normalize_path(destination_path)
	if source == "/":
		return "Cannot move root"
	if _is_protected_system_path(source):
		return "Cannot move protected system path: " + source
	if destination == source or destination.begins_with(source + "/"):
		return "Cannot move a folder into itself"

	var source_info := _parent_info(source)
	if not bool(source_info.get("ok", false)):
		return str(source_info.get("error", "Invalid path"))
	var source_parent: Dictionary = source_info["parent"]
	var source_parent_path := parent_path(source)
	if not _can_write(source_parent, current_user()) or not _can_execute(source_parent, current_user()):
		return "Permission denied: " + source_parent_path
	var source_name := str(source_info["name"])
	var source_children: Dictionary = source_parent.get("children", {})
	if not source_children.has(source_name):
		return "Path not found: " + source
	var source_node: Dictionary = source_children[source_name]
	if _has_sticky_bit(source_parent) and current_user() != ROOT_USER and current_user() != str(source_node.get("owner", "")) and current_user() != str(source_parent.get("owner", "")):
		return "Permission denied: " + source

	var destination_info := _parent_info(destination)
	if not bool(destination_info.get("ok", false)):
		return str(destination_info.get("error", "Invalid path"))
	var destination_parent: Dictionary = destination_info["parent"]
	var destination_parent_path := parent_path(destination)
	if not _can_write(destination_parent, current_user()) or not _can_execute(destination_parent, current_user()):
		return "Permission denied: " + destination_parent_path
	var destination_name := str(destination_info["name"])
	var destination_children: Dictionary = destination_parent.get("children", {})
	if destination_children.has(destination_name):
		return "Path already exists: " + destination

	if source_parent_path == destination_parent_path:
		source_children.erase(source_name)
		source_children[destination_name] = source_node
		source_parent["children"] = source_children
	else:
		destination_children[destination_name] = source_node
		destination_parent["children"] = destination_children
		source_children.erase(source_name)
		source_parent["children"] = source_children
	save()
	return ""

func set_mode(path: String, mode: String) -> String:
	var normalized := normalize_path(path)
	var clean_mode := _clean_mode(mode)
	if clean_mode == "":
		return "Mode must be 3 or 4 numeric digits"
	var node := get_node_at(normalized)
	if node.is_empty():
		return "Path not found: " + normalized
	if current_user() != ROOT_USER and current_user() != str(node.get("owner", "")):
		return "Permission denied: chmod requires owner or root"
	node["mode"] = clean_mode
	save()
	return ""

func set_owner(path: String, username: String) -> String:
	if current_user() != ROOT_USER:
		return "Permission denied: chown requires root"
	var normalized := normalize_path(path)
	var clean := clean_username(username)
	if not user_exists(clean):
		return "Unknown user: " + clean
	var node := get_node_at(normalized)
	if node.is_empty():
		return "Path not found: " + normalized
	node["owner"] = clean
	node["group"] = _primary_group(clean)
	save()
	return ""

func stat_text(path: String) -> String:
	var normalized := normalize_path(path)
	var node := get_node_at(normalized)
	if node.is_empty():
		return "Path not found: " + normalized
	return "%s %s %s %s %d %s" % [
		str(node.get("mode", "0644")),
		str(node.get("owner", DEFAULT_USERNAME)),
		str(node.get("group", str(node.get("owner", DEFAULT_USERNAME)))),
		str(node.get("type", "file")),
		_node_size(node),
		normalized
	]

func get_node_at(path: String) -> Dictionary:
	var normalized := normalize_path(path)
	if normalized == "/":
		return _tree

	var parts := _path_parts(normalized)
	var node: Dictionary = _tree
	for part in parts:
		if str(node.get("type", "")) != "dir":
			return {}
		var children: Dictionary = node.get("children", {})
		if not children.has(part):
			return {}
		node = children[part]
	return node

func resolve_path(path: String, base_path := "") -> String:
	var clean := path.strip_edges().replace("\\", "/")
	var base := normalize_path(base_path if base_path != "" else home_path())
	if clean == "":
		return base
	if clean == "~":
		return home_path()
	if clean.begins_with("~/"):
		return _collapse_path(home_path() + clean.substr(1))
	if clean.begins_with("/"):
		return _collapse_path(clean)
	return _collapse_path(join_path(base, clean))

func normalize_path(path: String) -> String:
	var clean := path.strip_edges().replace("\\", "/")
	if clean == "" or clean == "/":
		return "/"
	if clean == "~" or clean.begins_with("~/"):
		return resolve_path(clean)
	if not clean.begins_with("/"):
		clean = "/" + clean
	return _collapse_path(clean)

func parent_path(path: String) -> String:
	var normalized := normalize_path(path)
	if normalized == "/":
		return "/"
	var parts := _path_parts(normalized)
	if parts.size() <= 1:
		return "/"
	parts.remove_at(parts.size() - 1)
	return "/" + "/".join(parts)

func join_path(base: String, child: String) -> String:
	var clean_base := normalize_path(base)
	var clean_child := _clean_name(child)
	if clean_child == "":
		return clean_base
	if clean_base == "/":
		return "/" + clean_child
	return clean_base + "/" + clean_child

func clean_username(value: String) -> String:
	var clean := value.strip_edges().to_lower()
	if clean == "":
		return ""
	for index in clean.length():
		var code := clean.unicode_at(index)
		var valid_number := code >= 48 and code <= 57
		var valid_lower := code >= 97 and code <= 122
		var valid_symbol := code == 45 or code == 95
		if not valid_number and not valid_lower and not valid_symbol:
			return ""
	return clean

func _parent_info(path: String) -> Dictionary:
	var normalized := normalize_path(path)
	if normalized == "/":
		return {"ok": false, "error": "Path must include a name"}

	var name := _clean_name(normalized.get_file())
	if name == "":
		return {"ok": false, "error": "Name is required"}
	var parent_path_text := parent_path(normalized)
	var parent := get_node_at(parent_path_text)
	if parent.is_empty() or str(parent.get("type", "")) != "dir":
		return {"ok": false, "error": "Parent folder not found: " + parent_path_text}
	return {"ok": true, "parent": parent, "name": name}

func _path_parts(path: String) -> Array[String]:
	var normalized := normalize_path(path)
	var result: Array[String] = []
	if normalized == "/":
		return result
	var raw_parts := normalized.substr(1).split("/", false)
	for part in raw_parts:
		result.append(str(part))
	return result

func _clean_name(value: String) -> String:
	var clean := value.strip_edges().replace("\\", "").replace("/", "")
	return clean

func _clean_mode(mode: String) -> String:
	var clean := mode.strip_edges()
	if clean.length() != 3 and clean.length() != 4:
		return ""
	for index in clean.length():
		var digit := int(clean.substr(index, 1))
		if digit < 0 or digit > 7 or clean.substr(index, 1) != str(digit):
			return ""
	return clean

func _collapse_path(path: String) -> String:
	var clean := path.strip_edges().replace("\\", "/")
	while clean.contains("//"):
		clean = clean.replace("//", "/")
	if clean == "" or clean == "/":
		return "/"
	if not clean.begins_with("/"):
		clean = "/" + clean
	var result: Array[String] = []
	var raw_parts := clean.substr(1).split("/", false)
	for raw_part in raw_parts:
		var part := str(raw_part)
		if part == "." or part == "":
			continue
		if part == "..":
			if not result.is_empty():
				result.remove_at(result.size() - 1)
			continue
		result.append(part)
	if result.is_empty():
		return "/"
	return "/" + "/".join(result)

func _node_size(node: Dictionary) -> int:
	if str(node.get("type", "")) == "file":
		return str(node.get("content", "")).length()
	var children: Dictionary = node.get("children", {})
	return children.size()

func _empty_state() -> Dictionary:
	var state := {
		"version": 2,
		"current_user": DEFAULT_USERNAME,
		"users": {},
		"tree": _dir_node(ROOT_USER, ROOT_USER, "0755")
	}
	state["users"] = {
		ROOT_USER: {"uid": 0, "gid": 0, "group": ROOT_USER, "home": "/root", "shell": "/bin/sh", "groups": [ROOT_USER], "password_hash": _password_hash("")},
		DEFAULT_USERNAME: {"uid": DEFAULT_UID, "gid": DEFAULT_UID, "group": DEFAULT_USERNAME, "home": "/home/" + DEFAULT_USERNAME, "shell": "/bin/sh", "groups": [DEFAULT_USERNAME], "password_hash": _password_hash("")}
	}
	return state

func _dir_node(owner: String, group: String, mode: String) -> Dictionary:
	return {"type": "dir", "owner": owner, "group": group, "mode": mode, "children": {}}

func _file_node(content: String, owner: String, group: String, mode: String) -> Dictionary:
	return {"type": "file", "owner": owner, "group": group, "mode": mode, "content": content}

func _copy_node(node: Dictionary, owner: String, group: String) -> Dictionary:
	var type := str(node.get("type", "file"))
	if type == "dir":
		var copy := _dir_node(owner, group, str(node.get("mode", "0755")))
		var source_children: Dictionary = node.get("children", {})
		var copied_children: Dictionary = {}
		for key in source_children.keys():
			if source_children[key] is Dictionary:
				copied_children[key] = _copy_node(source_children[key], owner, group)
		copy["children"] = copied_children
		return copy
	return _file_node(str(node.get("content", "")), owner, group, str(node.get("mode", "0644")))

func _is_valid_tree(value: Dictionary) -> bool:
	return str(value.get("type", "")) == "dir" and value.has("children") and value["children"] is Dictionary

func _is_valid_state(value: Dictionary) -> bool:
	return value.has("tree") and value["tree"] is Dictionary and _is_valid_tree(value["tree"]) and value.has("users") and value["users"] is Dictionary

func _ensure_system_layout() -> void:
	if _tree.is_empty() or not _is_valid_tree(_tree):
		_tree = _dir_node(ROOT_USER, ROOT_USER, "0755")
	_state["tree"] = _tree
	_add_metadata_recursive(_tree, DEFAULT_USERNAME, DEFAULT_USERNAME)
	_tree["owner"] = ROOT_USER
	_tree["group"] = ROOT_USER
	_tree["mode"] = "0755"
	if not _state.has("users") or not (_state["users"] is Dictionary):
		_state["users"] = _empty_state()["users"]
	var users: Dictionary = _state["users"]
	if not users.has(ROOT_USER):
		users[ROOT_USER] = {"uid": 0, "gid": 0, "group": ROOT_USER, "home": "/root", "shell": "/bin/sh", "groups": [ROOT_USER], "password_hash": _password_hash("")}
	if not users.has(DEFAULT_USERNAME):
		users[DEFAULT_USERNAME] = {"uid": DEFAULT_UID, "gid": DEFAULT_UID, "group": DEFAULT_USERNAME, "home": "/home/" + DEFAULT_USERNAME, "shell": "/bin/sh", "groups": [DEFAULT_USERNAME], "password_hash": _password_hash("")}
	for key in users.keys():
		var account: Dictionary = users[key]
		if not account.has("password_hash"):
			account["password_hash"] = _password_hash("")
		users[key] = account
	_state["users"] = users
	_force_dir("/home", ROOT_USER, ROOT_USER, "0755")
	_force_dir("/root", ROOT_USER, ROOT_USER, "0700")
	_force_dir("/tmp", ROOT_USER, ROOT_USER, "1777")
	_force_dir("/etc", ROOT_USER, ROOT_USER, "0755")
	_force_dir("/bin", ROOT_USER, ROOT_USER, "0755")
	_force_dir("/usr", ROOT_USER, ROOT_USER, "0755")
	_force_dir("/var", ROOT_USER, ROOT_USER, "0755")
	for key in users.keys():
		var username := str(key)
		if username == ROOT_USER:
			continue
		_force_dir(home_path(username), username, _primary_group(username), "0755")
	if not user_exists(current_user()):
		_state["current_user"] = DEFAULT_USERNAME
	_sync_system_files()

func _force_dir(path: String, owner: String, group: String, mode: String) -> void:
	var normalized := normalize_path(path)
	if normalized == "/":
		return
	var parts := _path_parts(normalized)
	var node: Dictionary = _tree
	var current := ""
	for part in parts:
		current += "/" + part
		var children: Dictionary = node.get("children", {})
		if not children.has(part) or not (children[part] is Dictionary) or str((children[part] as Dictionary).get("type", "")) != "dir":
			children[part] = _dir_node(owner, group, mode)
			node["children"] = children
		node = children[part]
		if current == normalized:
			node["owner"] = owner
			node["group"] = group
			node["mode"] = mode

func _sync_system_files() -> void:
	var etc := get_node_at("/etc")
	if etc.is_empty():
		return
	var children: Dictionary = etc.get("children", {})
	children["passwd"] = _file_node(_passwd_text(), ROOT_USER, ROOT_USER, "0644")
	children["group"] = _file_node(_group_text(), ROOT_USER, ROOT_USER, "0644")
	children["shadow"] = _file_node(_shadow_text(), ROOT_USER, ROOT_USER, "0640")
	etc["children"] = children

func _passwd_text() -> String:
	var lines: Array[String] = []
	for username in get_users():
		var users: Dictionary = _state.get("users", {})
		var account: Dictionary = users[username]
		lines.append("%s:x:%d:%d:%s:%s:%s" % [
			username,
			int(account.get("uid", 0)),
			int(account.get("gid", 0)),
			username,
			str(account.get("home", "/home/" + username)),
			str(account.get("shell", "/bin/sh"))
		])
	return "\n".join(lines) + "\n"

func _group_text() -> String:
	var lines: Array[String] = []
	for username in get_users():
		var users: Dictionary = _state.get("users", {})
		var account: Dictionary = users[username]
		lines.append("%s:x:%d:%s" % [str(account.get("group", username)), int(account.get("gid", 0)), username])
	return "\n".join(lines) + "\n"

func _shadow_text() -> String:
	var lines: Array[String] = []
	var users: Dictionary = _state.get("users", {})
	for username in get_users():
		var account: Dictionary = users[username]
		lines.append("%s:%s:0:0:99999:7:::" % [username, str(account.get("password_hash", _password_hash("")))])
	return "\n".join(lines) + "\n"

func _password_hash(password: String) -> String:
	return password.sha256_text()

func _add_metadata_recursive(node: Dictionary, owner: String, group: String) -> void:
	var type := str(node.get("type", "dir"))
	if not node.has("owner"):
		node["owner"] = owner
	if not node.has("group"):
		node["group"] = group
	if not node.has("mode"):
		node["mode"] = "0644" if type == "file" else "0755"
	if type == "dir":
		if not node.has("children") or not (node["children"] is Dictionary):
			node["children"] = {}
		var children: Dictionary = node.get("children", {})
		for key in children.keys():
			if children[key] is Dictionary:
				_add_metadata_recursive(children[key], owner, group)
	if type == "file" and not node.has("content"):
		node["content"] = ""

func _can_read(node: Dictionary, username: String) -> bool:
	return _has_permission(node, username, 4)

func _can_write(node: Dictionary, username: String) -> bool:
	return _has_permission(node, username, 2)

func _can_execute(node: Dictionary, username: String) -> bool:
	return _has_permission(node, username, 1)

func _has_permission(node: Dictionary, username: String, bit: int) -> bool:
	if username == ROOT_USER:
		return true
	var mode := str(node.get("mode", "0644"))
	var perms := mode.substr(maxi(mode.length() - 3, 0), 3)
	if perms.length() < 3:
		return false
	var digit_index := 2
	if username == str(node.get("owner", "")):
		digit_index = 0
	elif _user_in_group(username, str(node.get("group", ""))):
		digit_index = 1
	var digit := int(perms.substr(digit_index, 1))
	return (digit & bit) == bit

func _has_sticky_bit(node: Dictionary) -> bool:
	var mode := str(node.get("mode", ""))
	return mode.length() == 4 and mode.begins_with("1")

func _primary_group(username: String) -> String:
	var users: Dictionary = _state.get("users", {})
	if users.has(username):
		var account: Dictionary = users[username]
		return str(account.get("group", username))
	return username

func _user_in_group(username: String, group: String) -> bool:
	if group == "":
		return false
	var users: Dictionary = _state.get("users", {})
	if not users.has(username):
		return false
	var account: Dictionary = users[username]
	if str(account.get("group", username)) == group:
		return true
	var groups: Array = account.get("groups", [])
	for item in groups:
		if str(item) == group:
			return true
	return false

func _groups_text(account: Dictionary) -> String:
	var groups: Array = account.get("groups", [])
	var result: Array[String] = []
	for group in groups:
		result.append(str(group))
	return ",".join(result)

func _is_protected_system_path(path: String) -> bool:
	return path == "/home" or path == "/etc" or path == "/bin" or path == "/usr" or path == "/var" or path == "/tmp" or path == "/root"
