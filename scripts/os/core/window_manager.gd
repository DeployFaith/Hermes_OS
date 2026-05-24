class_name WindowManager
extends RefCounted

const OSWindow = preload("res://scripts/os/os_window.gd")
const OSEventBus = preload("res://scripts/os/core/os_event_bus.gd")
const Tokens = preload("res://scripts/os/design_tokens.gd")
const UIAnimator = preload("res://scripts/os/ui_animator.gd")

signal window_opened(window: OSWindow, window_id: int)
signal window_closed(window_id: int, app_id: String)
signal window_focused(window: OSWindow, window_id: int)
signal window_minimized(window: OSWindow, window_id: int)
signal window_restored(window: OSWindow, window_id: int)

var _window_layer: Control
var _event_bus: OSEventBus
var _windows_by_id: Dictionary = {}
var _window_ids_by_app: Dictionary = {}
var _focused_window_id: int = 0
var _next_window_id: int = 1

func setup(window_layer: Control, event_bus: OSEventBus) -> void:
	_window_layer = window_layer
	_event_bus = event_bus

func create_window(app_id: StringName, title: String, content: Control, options: Dictionary = {}) -> OSWindow:
	if _window_layer == null:
		push_warning("WindowManager cannot create a window without a window layer")
		return null
	var window_id := _next_window_id
	_next_window_id += 1
	var window := OSWindow.new()
	_window_layer.add_child(window)
	window.setup(str(app_id), title, content)
	window.set_meta("window_id", window_id)
	var size: Vector2 = options.get("size", Vector2(560, 380))
	window.set_window_size(size)
	if options.has("position") and options["position"] is Vector2:
		window.position = options["position"]
	else:
		window.position = _center_window_position(window)
	clamp_window_to_layer(window)
	window.close_requested.connect(_on_window_close_requested)
	window.minimize_requested.connect(_on_window_minimize_requested)
	window.focused.connect(_on_window_focused)
	_windows_by_id[window_id] = window
	if not _window_ids_by_app.has(str(app_id)):
		_window_ids_by_app[str(app_id)] = []
	var app_window_ids: Array = _window_ids_by_app[str(app_id)]
	app_window_ids.append(window_id)
	_window_ids_by_app[str(app_id)] = app_window_ids
	if DisplayServer.get_name() != "headless":
		var animator := UIAnimator.new()
		animator.scale_in(window, Tokens.TIME["normal"])
	focus_window(window_id)
	_emit_window_event(OSEventBus.WINDOW_OPENED, window, {"title": title})
	window_opened.emit(window, window_id)
	return window

func close_window(window_id: int) -> void:
	var window := get_window(window_id)
	if window == null:
		return
	var app_id := window.app_id
	var legacy_window_id := _public_window_id(window)
	if not _content_allows_close(window):
		return
	_prepare_window_content_for_close(window)
	if _focused_window_id == window_id:
		_focused_window_id = 0
	_windows_by_id.erase(window_id)
	if _window_ids_by_app.has(app_id):
		var app_window_ids: Array = _window_ids_by_app[app_id]
		app_window_ids.erase(window_id)
		if app_window_ids.is_empty():
			_window_ids_by_app.erase(app_id)
		else:
			_window_ids_by_app[app_id] = app_window_ids
	window.visible = false
	_emit_window_event_by_id(OSEventBus.WINDOW_CLOSED, window_id, app_id, legacy_window_id)
	window_closed.emit(window_id, app_id)
	if app_id == "browser":
		_queue_browser_close_poll(window, Time.get_ticks_msec() + 1800)
	else:
		var tree := window.get_tree()
		if tree == null:
			window.queue_free()
			return
		var close_timer := tree.create_timer(0.12)
		close_timer.timeout.connect(func() -> void:
			if is_instance_valid(window):
				_prepare_window_content_for_close(window)
				window.queue_free()
		)

func focus_window(window_id: int) -> void:
	var window := get_window(window_id)
	if window == null:
		return
	_focused_window_id = window_id
	for id in _windows_by_id.keys():
		var other := _windows_by_id[id] as OSWindow
		if is_instance_valid(other):
			other.set_active(int(id) == window_id)
	window.visible = true
	window.move_to_front()
	_emit_window_event(OSEventBus.WINDOW_FOCUSED, window)
	window_focused.emit(window, window_id)

func minimize_window(window_id: int) -> void:
	var window := get_window(window_id)
	if window == null:
		return
	if _focused_window_id == window_id:
		_focused_window_id = 0
	window.visible = false
	_emit_window_event(OSEventBus.WINDOW_MINIMIZED, window)
	window_minimized.emit(window, window_id)

func restore_window(window_id: int) -> void:
	var window := get_window(window_id)
	if window == null:
		return
	window.visible = true
	focus_window(window_id)
	_emit_window_event(OSEventBus.WINDOW_RESTORED, window)
	window_restored.emit(window, window_id)

func get_window(window_id: int) -> OSWindow:
	var window := _windows_by_id.get(window_id, null) as OSWindow
	if window != null and is_instance_valid(window):
		return window
	return null

func get_window_for_app(app_id: StringName) -> OSWindow:
	var ids := get_window_ids_for_app(app_id)
	if ids.is_empty():
		return null
	return get_window(int(ids[ids.size() - 1]))

func get_window_ids_for_app(app_id: StringName) -> Array[int]:
	var result: Array[int] = []
	var ids_variant: Variant = _window_ids_by_app.get(str(app_id), [])
	if not (ids_variant is Array):
		return result
	for id_variant in ids_variant:
		var window_id := int(id_variant)
		if get_window(window_id) != null:
			result.append(window_id)
	return result

func get_window_id(window: OSWindow) -> int:
	if window == null or not is_instance_valid(window):
		return 0
	return int(window.get_meta("window_id", 0))

func get_windows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in _windows_by_id.keys():
		var window := _windows_by_id[id] as OSWindow
		if not is_instance_valid(window):
			continue
		result.append({
			"window_id": int(id),
			"app_id": window.app_id,
			"title": window.app_title,
			"focused": int(id) == _focused_window_id,
			"visible": window.visible
		})
	return result

func get_open_windows_by_app() -> Dictionary:
	var result: Dictionary = {}
	for app_id in _window_ids_by_app.keys():
		var window := get_window_for_app(StringName(str(app_id)))
		if window != null:
			result[str(app_id)] = window
	return result

func get_focused_window_id() -> int:
	return _focused_window_id

func get_focused_window() -> OSWindow:
	return get_window(_focused_window_id)

func clamp_window_to_layer(window: OSWindow) -> void:
	if _window_layer == null or window == null or not is_instance_valid(window):
		return
	var max_x := maxf(_window_layer.size.x - window.size.x, 0.0)
	var max_y := maxf(_window_layer.size.y - window.size.y, 0.0)
	window.position = Vector2(clampf(window.position.x, 0.0, max_x), clampf(window.position.y, 0.0, max_y))

func clamp_all_windows() -> void:
	for id in _windows_by_id.keys():
		var window := _windows_by_id[id] as OSWindow
		if is_instance_valid(window) and window.visible:
			clamp_window_to_layer(window)

func close_all(emit_events: bool = false) -> void:
	if emit_events:
		var ids := _windows_by_id.keys().duplicate()
		for id in ids:
			close_window(int(id))
		_windows_by_id.clear()
		_window_ids_by_app.clear()
		_focused_window_id = 0
		return
	for id in _windows_by_id.keys():
		var window := _windows_by_id[id] as OSWindow
		if is_instance_valid(window):
			_prepare_window_content_for_close(window)
			window.queue_free()
	_windows_by_id.clear()
	_window_ids_by_app.clear()
	_focused_window_id = 0

func _center_window_position(window: OSWindow) -> Vector2:
	if _window_layer == null:
		return Vector2.ZERO
	return Vector2(maxf((_window_layer.size.x - window.size.x) * 0.5, 0.0), maxf((_window_layer.size.y - window.size.y) * 0.5, 0.0))

func _on_window_close_requested(window: OSWindow) -> void:
	close_window(get_window_id(window))

func _on_window_minimize_requested(window: OSWindow) -> void:
	minimize_window(get_window_id(window))

func _on_window_focused(window: OSWindow) -> void:
	focus_window(get_window_id(window))

func _emit_window_event(event_name: StringName, window: OSWindow, extra: Dictionary = {}) -> void:
	if _event_bus == null or window == null:
		return
	var manager_window_id := get_window_id(window)
	var payload := extra.duplicate(true)
	payload["window_id"] = _public_window_id(window)
	payload["manager_window_id"] = manager_window_id
	payload["app_id"] = window.app_id
	_event_bus.emit_event(event_name, payload)

func _emit_window_event_by_id(event_name: StringName, manager_window_id: int, app_id: String, legacy_window_id: String = "") -> void:
	if _event_bus != null:
		_event_bus.emit_event(event_name, {"window_id": legacy_window_id if legacy_window_id != "" else str(manager_window_id), "manager_window_id": manager_window_id, "app_id": app_id})

func _public_window_id(window: OSWindow) -> String:
	if window == null or not is_instance_valid(window):
		return ""
	return "win_%s" % str(window.get_instance_id())

func _queue_browser_close_poll(window: OSWindow, deadline_msec: int) -> void:
	if window == null or not is_instance_valid(window):
		return
	var tree := window.get_tree()
	if tree == null:
		window.queue_free()
		return
	var poll := tree.create_timer(0.05)
	poll.timeout.connect(func() -> void:
		if not is_instance_valid(window):
			return
		_prepare_window_content_for_close(window)
		if _window_content_ready_for_close(window) or Time.get_ticks_msec() >= deadline_msec:
			window.queue_free()
		else:
			_queue_browser_close_poll(window, deadline_msec)
	)

func _window_content_ready_for_close(root: Node) -> bool:
	if root == null or not is_instance_valid(root):
		return true
	var ready := true
	if root.has_method("is_native_teardown_complete"):
		ready = bool(root.call("is_native_teardown_complete"))
	for child in root.get_children():
		ready = ready and _window_content_ready_for_close(child)
	return ready

func _content_allows_close(root: Node) -> bool:
	if root == null or not is_instance_valid(root):
		return true
	if root.has_method("os_app_close_requested"):
		var result: Variant = root.call("os_app_close_requested")
		if result is bool and not bool(result):
			return false
	for child in root.get_children():
		if not _content_allows_close(child):
			return false
	return true

func _prepare_window_content_for_close(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root.has_method("prepare_for_close"):
		root.call("prepare_for_close")
	for child in root.get_children():
		_prepare_window_content_for_close(child)
