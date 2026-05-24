class_name FilesApp
extends Control

const Tokens = preload("res://scripts/os/design_tokens.gd")
const StyleFactory = preload("res://scripts/os/style_factory.gd")

var _shell: Node
var _fs = null
var _root: Control
var _state: Dictionary = {}
var _ui: Dictionary = {}
var _files_shortcuts: Array[Dictionary] = []
var _open_file_callback: Callable
var _shortcuts_changed_callback: Callable
var _state_save_callback: Callable

func os_app_init(context: Dictionary) -> void:
	_shell = context.get("shell", null) as Node
	_fs = context.get("filesystem", null)
	if _fs == null and _shell != null:
		_fs = _shell._fs
	_open_file_callback = context.get("open_file_callback", Callable()) if context.get("open_file_callback", Callable()) is Callable else Callable()
	_shortcuts_changed_callback = context.get("shortcuts_changed_callback", Callable()) if context.get("shortcuts_changed_callback", Callable()) is Callable else Callable()
	_state_save_callback = context.get("state_save_callback", Callable()) if context.get("state_save_callback", Callable()) is Callable else Callable()
	var shortcuts_variant: Variant = context.get("shortcuts", [])
	if _fs != null:
		_files_shortcuts = _files_sanitize_shortcuts(shortcuts_variant, _fs.home_path())
	_build()
	var initial_state: Dictionary = context.get("state", {}) if context.get("state", {}) is Dictionary else {}
	if not initial_state.is_empty():
		os_app_restore_state(initial_state)

func os_app_focus() -> void:
	if _ui.has("tree") and is_instance_valid(_ui["tree"]):
		(_ui["tree"] as Tree).grab_focus()

func os_app_close_requested() -> bool:
	return true

func os_app_get_state() -> Dictionary:
	return _state.duplicate(true)

func os_app_restore_state(state: Dictionary) -> void:
	if _fs == null:
		return
	if state.has("shortcuts"):
		_files_shortcuts = _files_sanitize_shortcuts(state.get("shortcuts", []), _fs.home_path())
		_emit_shortcuts_changed()
	var path := str(state.get("current_path", _fs.home_path()))
	open_path(path)

func _build() -> void:
	for child in get_children():
		child.queue_free()
	var root := _app_root()
	root.name = "FilesRoot"
	_root = root
	add_child(root)
	root.clip_contents = true
	root.custom_minimum_size = Vector2(860, 500)
	var home: String = _fs.home_path()
	var state := {
		"current_path": home,
		"selected_path": "",
		"selected_type": "",
		"clipboard_path": "",
		"clipboard_mode": "",
		"history": [home],
		"history_index": 0,
		"shortcuts": _files_initial_shortcuts(home),
		"shortcut_selected_index": -1,
		"shortcut_dialog_mode": "add",
		"shortcut_dialog_index": -1
	}

	var menu_bar := HBoxContainer.new()
	menu_bar.add_theme_constant_override("separation", 4)
	root.add_child(menu_bar)
	for menu_name in ["File", "Edit", "View", "Sort"]:
		menu_bar.add_child(_files_menu_button(menu_name))

	var frame := HSplitContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.split_offset = 228
	root.add_child(frame)

	var sidebar_panel := PanelContainer.new()
	sidebar_panel.custom_minimum_size = Vector2(230, 0)
	var sidebar_style := _style(Tokens.SURFACE, Tokens.SURFACE_HOVER, 1, 10)
	sidebar_style.content_margin_left = 12
	sidebar_style.content_margin_right = 12
	sidebar_style.content_margin_top = 10
	sidebar_style.content_margin_bottom = 10
	sidebar_panel.add_theme_stylebox_override("panel", StyleFactory.solid_panel(Tokens.alpha(Tokens.SURFACE, 0.7), Tokens.alpha(Tokens.WHITE, 0.06), 1, 10))
	frame.add_child(sidebar_panel)

	var sidebar := VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 4)
	sidebar_panel.add_child(sidebar)

	var shortcuts_list := ItemList.new()
	shortcuts_list.custom_minimum_size = Vector2(0, 220)
	shortcuts_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shortcuts_list.select_mode = ItemList.SELECT_SINGLE
	shortcuts_list.allow_reselect = true
	_style_item_list(shortcuts_list)
	sidebar.add_child(shortcuts_list)
	var shortcuts_context_menu := PopupMenu.new()
	shortcuts_context_menu.hide_on_item_selection = true
	shortcuts_context_menu.add_item("Open", 0)
	shortcuts_context_menu.add_separator()
	shortcuts_context_menu.add_item("Add shortcut…", 1)
	shortcuts_context_menu.add_item("Edit shortcut…", 2)
	shortcuts_context_menu.add_item("Delete shortcut", 3)
	shortcuts_context_menu.add_separator()
	shortcuts_context_menu.add_item("Move up", 4)
	shortcuts_context_menu.add_item("Move down", 5)
	sidebar.add_child(shortcuts_context_menu)

	var side_separator_1 := HSeparator.new()
	sidebar.add_child(side_separator_1)
	var shortcuts_dialog := PopupPanel.new()
	shortcuts_dialog.visible = false
	shortcuts_dialog.size = Vector2(360, 154)
	shortcuts_dialog.add_theme_stylebox_override("panel", _style(Tokens.SURFACE, Tokens.BORDER_ACTIVE, 1, 8))
	sidebar.add_child(shortcuts_dialog)

	var shortcuts_dialog_body := VBoxContainer.new()
	shortcuts_dialog_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	shortcuts_dialog_body.offset_left = 10
	shortcuts_dialog_body.offset_right = -10
	shortcuts_dialog_body.offset_top = 10
	shortcuts_dialog_body.offset_bottom = -10
	shortcuts_dialog_body.add_theme_constant_override("separation", 8)
	shortcuts_dialog.add_child(shortcuts_dialog_body)

	var shortcut_dialog_title := Label.new()
	shortcut_dialog_title.text = "Add shortcut"
	shortcut_dialog_title.add_theme_font_size_override("font_size", 14)
	shortcut_dialog_title.add_theme_color_override("font_color", Tokens.TEXT)
	shortcuts_dialog_body.add_child(shortcut_dialog_title)

	var shortcut_dialog_label_input := LineEdit.new()
	shortcut_dialog_label_input.placeholder_text = "Shortcut name"
	shortcut_dialog_label_input.custom_minimum_size = Vector2(0, 28)
	_style_line_edit(shortcut_dialog_label_input)
	shortcuts_dialog_body.add_child(shortcut_dialog_label_input)

	var shortcut_dialog_path_input := LineEdit.new()
	shortcut_dialog_path_input.placeholder_text = "Shortcut path"
	shortcut_dialog_path_input.custom_minimum_size = Vector2(0, 28)
	_style_line_edit(shortcut_dialog_path_input)
	shortcuts_dialog_body.add_child(shortcut_dialog_path_input)

	var shortcut_dialog_actions := HBoxContainer.new()
	shortcut_dialog_actions.add_theme_constant_override("separation", 6)
	shortcuts_dialog_body.add_child(shortcut_dialog_actions)
	var shortcut_dialog_cancel_button := _button("Cancel", Vector2(70, 28))
	shortcut_dialog_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcut_dialog_actions.add_child(shortcut_dialog_cancel_button)
	var shortcut_dialog_save_button := _button("Save", Vector2(70, 28))
	shortcut_dialog_save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcut_dialog_actions.add_child(shortcut_dialog_save_button)

	var shortcuts_hint := _label("Double-click a shortcut to open it", 11, Tokens.MUTED)
	shortcuts_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	shortcuts_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sidebar.add_child(shortcuts_hint)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	frame.add_child(content)

	var nav_bar := HBoxContainer.new()
	nav_bar.add_theme_constant_override("separation", 6)
	content.add_child(nav_bar)

	var back_button := _files_chrome_button("◀", Vector2(34, 30))
	nav_bar.add_child(back_button)
	var forward_button := _files_chrome_button("▶", Vector2(34, 30))
	nav_bar.add_child(forward_button)
	var up_button := _files_chrome_button("↑", Vector2(34, 30))
	nav_bar.add_child(up_button)

	var breadcrumb_label := Label.new()
	breadcrumb_label.text = home
	breadcrumb_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	breadcrumb_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	breadcrumb_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	breadcrumb_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	breadcrumb_label.add_theme_font_size_override("font_size", 15)
	breadcrumb_label.add_theme_color_override("font_color", Tokens.TEXT)
	nav_bar.add_child(breadcrumb_label)

	var refresh_button := _files_chrome_button("Refresh", Vector2(74, 30))
	nav_bar.add_child(refresh_button)

	var path_input := LineEdit.new()
	path_input.text = home
	path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_input.custom_minimum_size = Vector2(0, 30)
	path_input.placeholder_text = "Path"
	_style_line_edit(path_input)
	content.add_child(path_input)

	var table_header := HBoxContainer.new()
	table_header.add_theme_constant_override("separation", 0)
	content.add_child(table_header)

	var header_name := _files_table_header_label("Name")
	header_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_header.add_child(header_name)
	var header_modified := _files_table_header_label("Modified")
	header_modified.custom_minimum_size = Vector2(220, 0)
	table_header.add_child(header_modified)
	var header_size := _files_table_header_label("Size")
	header_size.custom_minimum_size = Vector2(120, 0)
	table_header.add_child(header_size)

	var tree := Tree.new()
	tree.name = "FilesTree"
	tree.columns = 3
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_SINGLE
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.column_titles_visible = false
	tree.set_column_expand(0, true)
	tree.set_column_expand(1, false)
	tree.set_column_expand(2, false)
	tree.set_column_custom_minimum_width(1, 220)
	tree.set_column_custom_minimum_width(2, 120)
	_style_files_tree(tree)
	content.add_child(tree)

	var action_bar := HFlowContainer.new()
	action_bar.add_theme_constant_override("h_separation", 6)
	action_bar.add_theme_constant_override("v_separation", 6)
	content.add_child(action_bar)

	var create_input := LineEdit.new()
	create_input.placeholder_text = "New name"
	create_input.custom_minimum_size = Vector2(164, 30)
	_style_line_edit(create_input)
	action_bar.add_child(create_input)

	var new_folder_button := _button("New folder", Vector2(92, 30))
	action_bar.add_child(new_folder_button)
	var new_file_button := _button("New file", Vector2(82, 30))
	action_bar.add_child(new_file_button)

	var rename_input := LineEdit.new()
	rename_input.placeholder_text = "Rename selected"
	rename_input.custom_minimum_size = Vector2(190, 30)
	_style_line_edit(rename_input)
	action_bar.add_child(rename_input)

	var rename_button := _button("Rename", Vector2(74, 30))
	action_bar.add_child(rename_button)
	var open_button := _button("Open", Vector2(62, 30))
	action_bar.add_child(open_button)
	var delete_button := _button("Delete", Vector2(72, 30))
	action_bar.add_child(delete_button)
	var copy_button := _button("Copy", Vector2(60, 30))
	action_bar.add_child(copy_button)
	var cut_button := _button("Cut", Vector2(54, 30))
	action_bar.add_child(cut_button)
	var paste_button := _button("Paste", Vector2(62, 30))
	action_bar.add_child(paste_button)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 10)
	content.add_child(status_row)

	var selected_label := _label("Selected: none", 12, Tokens.MUTED)
	selected_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	selected_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selected_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(selected_label)

	var clipboard_label := _label("clip: empty", 12, Tokens.MUTED)
	clipboard_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	clipboard_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	clipboard_label.custom_minimum_size = Vector2(280, 0)
	status_row.add_child(clipboard_label)

	var details_label := _label("", 11, Tokens.MUTED)
	details_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	details_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(details_label)

	var status := _label("", 12, Tokens.MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(status)

	var ui := {
		"path_input": path_input,
		"breadcrumb_label": breadcrumb_label,
		"tree": tree,
		"shortcuts_list": shortcuts_list,
		"shortcuts_context_menu": shortcuts_context_menu,
		"shortcuts_dialog": shortcuts_dialog,
		"shortcut_dialog_title": shortcut_dialog_title,
		"shortcut_dialog_label_input": shortcut_dialog_label_input,
		"shortcut_dialog_path_input": shortcut_dialog_path_input,
		"shortcut_dialog_save_button": shortcut_dialog_save_button,
		"create_input": create_input,
		"rename_input": rename_input,
		"selected_label": selected_label,
		"details_label": details_label,
		"clipboard_label": clipboard_label,
		"status": status,
		"new_folder_button": new_folder_button,
		"new_file_button": new_file_button,
		"rename_button": rename_button,
		"open_button": open_button,
		"delete_button": delete_button,
		"copy_button": copy_button,
		"cut_button": cut_button,
		"paste_button": paste_button,
		"back_button": back_button,
		"forward_button": forward_button,
		"up_button": up_button
	}

	refresh_button.pressed.connect(func() -> void:
		_refresh_files(state, ui, false, false)
	)
	back_button.pressed.connect(func() -> void:
		_files_navigate_history(-1, state, ui)
	)
	forward_button.pressed.connect(func() -> void:
		_files_navigate_history(1, state, ui)
	)
	up_button.pressed.connect(func() -> void:
		path_input.text = _fs.parent_path(str(state["current_path"]))
		_refresh_files(state, ui)
	)
	path_input.text_submitted.connect(func(_submitted: String) -> void:
		_refresh_files(state, ui)
	)
	create_input.text_changed.connect(func(_t: String) -> void:
		_update_files_action_state(state, ui)
	)
	rename_input.text_changed.connect(func(_t: String) -> void:
		_update_files_action_state(state, ui)
	)
	shortcut_dialog_label_input.text_changed.connect(func(_t: String) -> void:
		_update_files_action_state(state, ui)
	)
	shortcut_dialog_path_input.text_changed.connect(func(_t: String) -> void:
		_update_files_action_state(state, ui)
	)
	shortcuts_list.item_selected.connect(func(index: int) -> void:
		_files_select_shortcut(index, state, ui)
	)
	shortcuts_list.item_activated.connect(func(index: int) -> void:
		_files_activate_shortcut(index, state, ui)
	)
	shortcuts_list.gui_input.connect(func(event: InputEvent) -> void:
		_files_shortcuts_gui_input(event, state, ui)
	)
	shortcuts_context_menu.id_pressed.connect(func(action_id: int) -> void:
		_files_shortcuts_context_action(action_id, state, ui)
	)
	shortcut_dialog_save_button.pressed.connect(func() -> void:
		_files_commit_shortcut_dialog(state, ui)
	)
	shortcut_dialog_cancel_button.pressed.connect(func() -> void:
		(shortcuts_dialog as PopupPanel).hide()
	)
	shortcut_dialog_label_input.text_submitted.connect(func(_submitted: String) -> void:
		_files_commit_shortcut_dialog(state, ui)
	)
	shortcut_dialog_path_input.text_submitted.connect(func(_submitted: String) -> void:
		_files_commit_shortcut_dialog(state, ui)
	)

	new_folder_button.pressed.connect(func() -> void:
		var name := create_input.text.strip_edges()
		if name == "":
			_set_status(status, "Enter a folder name", true)
			return
		var message: String = _fs.make_dir(_fs.join_path(str(state["current_path"]), name))
		_set_status(status, message if message != "" else "Folder created")
		if message == "":
			create_input.text = ""
		_refresh_files(state, ui, false)
	)
	new_file_button.pressed.connect(func() -> void:
		var name := create_input.text.strip_edges()
		if name == "":
			_set_status(status, "Enter a file name", true)
			return
		var message: String = _fs.write_file(_fs.join_path(str(state["current_path"]), name), "")
		_set_status(status, message if message != "" else "File created")
		if message == "":
			create_input.text = ""
		_refresh_files(state, ui, false)
	)
	open_button.pressed.connect(func() -> void:
		var selected := str(state["selected_path"])
		if selected == "":
			_set_status(status, "Select an item first", true)
			return
		if str(state["selected_type"]) == "dir":
			path_input.text = selected
			_refresh_files(state, ui)
		else:
			_route_open_file(selected)
			_set_status(status, "Opened in Text: " + selected.get_file())
	)
	rename_button.pressed.connect(func() -> void:
		var selected := str(state["selected_path"])
		if selected == "":
			_set_status(status, "Select an item first", true)
			return
		var target_name := rename_input.text.strip_edges()
		if target_name == "":
			_set_status(status, "Enter a new name", true)
			return
		var message: String = _fs.rename_path(selected, target_name)
		_set_status(status, message if message != "" else "Renamed", message != "")
		if message == "":
			state["selected_path"] = ""
			state["selected_type"] = ""
			rename_input.text = ""
		_refresh_files(state, ui, false)
	)
	copy_button.pressed.connect(func() -> void:
		var selected := str(state["selected_path"])
		if selected == "":
			_set_status(status, "Select an item first", true)
			return
		state["clipboard_path"] = selected
		state["clipboard_mode"] = "copy"
		_set_status(status, "Copied to clipboard: " + selected)
		_update_files_action_state(state, ui)
	)
	cut_button.pressed.connect(func() -> void:
		var selected := str(state["selected_path"])
		if selected == "":
			_set_status(status, "Select an item first", true)
			return
		state["clipboard_path"] = selected
		state["clipboard_mode"] = "move"
		_set_status(status, "Cut to clipboard: " + selected)
		_update_files_action_state(state, ui)
	)
	paste_button.pressed.connect(func() -> void:
		var clipboard_path := str(state["clipboard_path"])
		var clipboard_mode := str(state["clipboard_mode"])
		if clipboard_path == "" or clipboard_mode == "":
			_set_status(status, "Clipboard is empty", true)
			return
		var destination := _paste_destination_path(clipboard_path, str(state["current_path"]))
		var message: String = _fs.move_path(clipboard_path, destination) if clipboard_mode == "move" else _fs.copy_path(clipboard_path, destination)
		_set_status(status, message if message != "" else (("Moved to " if clipboard_mode == "move" else "Copied to ") + destination), message != "")
		if message == "" and clipboard_mode == "move":
			state["clipboard_path"] = ""
			state["clipboard_mode"] = ""
		_refresh_files(state, ui, false)
	)
	delete_button.pressed.connect(func() -> void:
		var selected := str(state["selected_path"])
		if selected == "":
			_set_status(status, "Select an item first", true)
			return
		var message: String = _fs.delete_path(selected)
		_set_status(status, message if message != "" else "Deleted", message != "")
		if message == "":
			state["selected_path"] = ""
			state["selected_type"] = ""
		_refresh_files(state, ui, false)
	)
	tree.item_selected.connect(func() -> void:
		var selected_item := tree.get_selected()
		if selected_item == null:
			return
		_select_file_item(selected_item, state, ui)
	)
	tree.item_activated.connect(func() -> void:
		var selected_item := tree.get_selected()
		if selected_item == null:
			return
		var metadata: Dictionary = selected_item.get_metadata(0) as Dictionary
		if str(metadata.get("type", "")) == "dir":
			path_input.text = str(metadata.get("path", "/"))
			_refresh_files(state, ui)
		else:
			_select_file_item(selected_item, state, ui)
			_route_open_file(str(metadata.get("path", "")))
			_set_status(status, "Opened in Text: " + str(metadata.get("name", "")))
	)

	_state = state
	_ui = ui
	_refresh_files_shortcuts(state, ui)
	_refresh_files(state, ui)
	return

func refresh(clear_status := true, push_history := true) -> void:
	_refresh_files(_state, _ui, clear_status, push_history)

func _refresh_files(state: Dictionary, ui: Dictionary, clear_status := true, push_history := true) -> void:
	var path_input := ui["path_input"] as LineEdit
	var breadcrumb_label := ui["breadcrumb_label"] as Label
	var tree := ui["tree"] as Tree
	var selected_label := ui["selected_label"] as Label
	var details_label := ui["details_label"] as Label
	var status := ui["status"] as Label
	var rename_input := ui["rename_input"] as LineEdit
	var path: String = _fs.resolve_path(path_input.text, str(state["current_path"]))
	if not _fs.is_dir(path):
		_set_status(status, "Folder not found: " + path, true)
		path_input.text = str(state["current_path"])
		return
	if not _fs.can_list_dir(path):
		_set_status(status, "Permission denied: " + path, true)
		path_input.text = str(state["current_path"])
		return

	state["current_path"] = path
	state["selected_path"] = ""
	state["selected_type"] = ""
	path_input.text = path
	breadcrumb_label.text = _files_breadcrumb_text(path)
	breadcrumb_label.tooltip_text = path
	rename_input.text = ""
	selected_label.text = "Selected: none"
	details_label.text = ""
	tree.clear()
	var root_item := tree.create_item()

	var entries: Array = _fs.list_dir(path)
	for entry in entries:
		var item: Dictionary = entry
		var is_dir := str(item.get("type", "")) == "dir"
		var row := tree.create_item(root_item)
		var name_text := ("📁 " if is_dir else "📄 ") + str(item.get("name", ""))
		row.set_text(0, name_text)
		row.set_text(1, _files_modified_text(item))
		row.set_text(2, _files_size_text(item))
		row.set_metadata(0, item)
		row.set_tooltip_text(0, "%s\nmode: %s\nowner: %s:%s" % [str(item.get("path", "")), str(item.get("mode", "")), str(item.get("owner", "")), str(item.get("group", ""))])
		row.set_tooltip_text(1, str(item.get("path", "")))
		row.set_tooltip_text(2, str(item.get("path", "")))

	if push_history:
		_files_push_history(path, state)

	if clear_status:
		_set_status(status, "Empty folder" if entries.is_empty() else "")
	_update_files_action_state(state, ui)

func _select_file_item(item: TreeItem, state: Dictionary, ui: Dictionary) -> void:
	var selected_label := ui["selected_label"] as Label
	var details_label := ui["details_label"] as Label
	var rename_input := ui["rename_input"] as LineEdit
	var status := ui["status"] as Label
	var metadata: Dictionary = item.get_metadata(0) as Dictionary
	var selected_path := str(metadata.get("path", ""))
	var selected_type := str(metadata.get("type", ""))
	state["selected_path"] = selected_path
	state["selected_type"] = selected_type
	rename_input.text = str(metadata.get("name", ""))
	selected_label.text = "Selected: " + selected_path
	details_label.text = "Type: %s   Owner: %s:%s   Mode: %s   Size: %s" % [selected_type, str(metadata.get("owner", "")), str(metadata.get("group", "")), str(metadata.get("mode", "")), _files_size_text(metadata)]
	_set_status(status, "Folder selected. Double-click or Open to enter." if selected_type == "dir" else "")
	_update_files_action_state(state, ui)

func _update_files_action_state(state: Dictionary, ui: Dictionary) -> void:
	var create_input := ui["create_input"] as LineEdit
	var rename_input := ui["rename_input"] as LineEdit
	var clipboard_label := ui["clipboard_label"] as Label
	var new_folder_button := ui["new_folder_button"] as Button
	var new_file_button := ui["new_file_button"] as Button
	var rename_button := ui["rename_button"] as Button
	var open_button := ui["open_button"] as Button
	var delete_button := ui["delete_button"] as Button
	var copy_button := ui["copy_button"] as Button
	var cut_button := ui["cut_button"] as Button
	var paste_button := ui["paste_button"] as Button
	var back_button := ui["back_button"] as Button
	var forward_button := ui["forward_button"] as Button
	var shortcut_dialog_label_input := ui["shortcut_dialog_label_input"] as LineEdit
	var shortcut_dialog_path_input := ui["shortcut_dialog_path_input"] as LineEdit
	var shortcut_dialog_save_button := ui["shortcut_dialog_save_button"] as Button
	var has_name := create_input.text.strip_edges() != ""
	new_folder_button.disabled = not has_name
	new_file_button.disabled = not has_name
	var selected := str(state.get("selected_path", "")) != ""
	rename_button.disabled = not selected or rename_input.text.strip_edges() == ""
	open_button.disabled = not selected
	delete_button.disabled = not selected
	copy_button.disabled = not selected
	cut_button.disabled = not selected
	var clipboard_path := str(state.get("clipboard_path", ""))
	var clipboard_mode := str(state.get("clipboard_mode", ""))
	paste_button.disabled = clipboard_path == "" or clipboard_mode == ""
	clipboard_label.text = "clip: empty" if clipboard_path == "" else ("clip: " + clipboard_mode + " " + clipboard_path)
	var history_variant: Variant = state.get("history", [])
	var history: Array = history_variant if history_variant is Array else []
	var history_index := int(state.get("history_index", -1))
	back_button.disabled = history_index <= 0
	forward_button.disabled = history_index < 0 or history_index >= history.size() - 1
	var has_shortcut_dialog_values := shortcut_dialog_label_input.text.strip_edges() != "" and shortcut_dialog_path_input.text.strip_edges() != ""
	shortcut_dialog_save_button.disabled = not has_shortcut_dialog_values

func _files_initial_shortcuts(home: String) -> Array[Dictionary]:
	if _files_shortcuts.is_empty():
		_files_shortcuts = _files_default_shortcuts(home)
	else:
		_files_shortcuts = _files_sanitize_shortcuts(_files_shortcuts, home)
	return _files_shortcuts.duplicate(true)

func _files_default_shortcuts(home: String) -> Array[Dictionary]:
	return [
		{"label": "Recents", "path": home},
		{"label": "Home", "path": home},
		{"label": "Documents", "path": _fs.join_path(home, "Documents")},
		{"label": "Downloads", "path": _fs.join_path(home, "Downloads")},
		{"label": "Music", "path": _fs.join_path(home, "Music")},
		{"label": "Pictures", "path": _fs.join_path(home, "Pictures")},
		{"label": "Videos", "path": _fs.join_path(home, "Videos")},
		{"label": "Create", "path": _fs.join_path(home, "Create")},
		{"label": "Trash", "path": home},
		{"label": "Networks", "path": home}
	]

func _files_sanitize_shortcuts(value: Variant, home: String) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if not (item is Dictionary):
				continue
			var shortcut: Dictionary = item
			var label := str(shortcut.get("label", "")).strip_edges()
			var path := str(shortcut.get("path", "")).strip_edges()
			if label == "" or path == "":
				continue
			output.append({
				"label": label,
				"path": _fs.normalize_path(path)
			})
	if output.is_empty():
		output = _files_default_shortcuts(home)
	return output

func _files_sync_shortcuts_from_state(state: Dictionary) -> Array[Dictionary]:
	var shortcuts_variant: Variant = state.get("shortcuts", [])
	var sanitized := _files_sanitize_shortcuts(shortcuts_variant, _fs.home_path())
	state["shortcuts"] = sanitized.duplicate(true)
	_files_shortcuts = sanitized.duplicate(true)
	return sanitized

func _refresh_files_shortcuts(state: Dictionary, ui: Dictionary) -> void:
	var shortcuts_list := ui["shortcuts_list"] as ItemList
	var shortcuts := _files_sync_shortcuts_from_state(state)
	shortcuts_list.clear()
	for shortcut in shortcuts:
		shortcuts_list.add_item(str(shortcut.get("label", "")))
	var selected_index := clampi(int(state.get("shortcut_selected_index", -1)), -1, shortcuts.size() - 1)
	state["shortcut_selected_index"] = selected_index
	shortcuts_list.deselect_all()
	if selected_index >= 0 and selected_index < shortcuts.size():
		shortcuts_list.select(selected_index)
	_update_files_action_state(state, ui)

func _files_select_shortcut(index: int, state: Dictionary, ui: Dictionary) -> void:
	state["shortcut_selected_index"] = index
	_refresh_files_shortcuts(state, ui)

func _files_activate_shortcut(index: int, state: Dictionary, ui: Dictionary) -> void:
	state["shortcut_selected_index"] = index
	var shortcuts := _files_sync_shortcuts_from_state(state)
	if index < 0 or index >= shortcuts.size():
		return
	var shortcut: Dictionary = shortcuts[index]
	var target_path: String = _fs.normalize_path(str(shortcut.get("path", "")))
	if not _fs.is_dir(target_path):
		_set_status(ui["status"] as Label, "Folder not found: " + target_path, true)
		_update_files_action_state(state, ui)
		return
	var path_input := ui["path_input"] as LineEdit
	path_input.text = target_path
	_refresh_files(state, ui)

func _files_shortcuts_gui_input(event: InputEvent, state: Dictionary, ui: Dictionary) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_RIGHT or not mouse.pressed:
		return
	var shortcuts_list := ui["shortcuts_list"] as ItemList
	var index := shortcuts_list.get_item_at_position(mouse.position, true)
	state["shortcut_selected_index"] = index
	if index >= 0:
		shortcuts_list.select(index)
	else:
		shortcuts_list.deselect_all()
	_files_show_shortcuts_context_menu(mouse.global_position, state, ui)
	get_viewport().set_input_as_handled()

func _files_show_shortcuts_context_menu(global_position: Vector2, state: Dictionary, ui: Dictionary) -> void:
	var menu := ui["shortcuts_context_menu"] as PopupMenu
	var shortcuts := _files_sync_shortcuts_from_state(state)
	var index := int(state.get("shortcut_selected_index", -1))
	var has_selection := index >= 0 and index < shortcuts.size()
	menu.set_item_disabled(menu.get_item_index(0), not has_selection)
	menu.set_item_disabled(menu.get_item_index(2), not has_selection)
	menu.set_item_disabled(menu.get_item_index(3), not has_selection)
	menu.set_item_disabled(menu.get_item_index(4), not has_selection or index <= 0)
	menu.set_item_disabled(menu.get_item_index(5), not has_selection or index >= shortcuts.size() - 1)
	menu.popup(Rect2i(int(global_position.x), int(global_position.y), 1, 1))

func _files_shortcuts_context_action(action_id: int, state: Dictionary, ui: Dictionary) -> void:
	match action_id:
		0:
			_files_activate_shortcut(int(state.get("shortcut_selected_index", -1)), state, ui)
		1:
			_files_open_shortcut_dialog("add", -1, state, ui)
		2:
			_files_open_shortcut_dialog("edit", int(state.get("shortcut_selected_index", -1)), state, ui)
		3:
			_files_delete_shortcut(state, ui)
		4:
			_files_move_shortcut(-1, state, ui)
		5:
			_files_move_shortcut(1, state, ui)

func _files_open_shortcut_dialog(mode: String, index: int, state: Dictionary, ui: Dictionary) -> void:
	var dialog := ui["shortcuts_dialog"] as PopupPanel
	var title := ui["shortcut_dialog_title"] as Label
	var label_input := ui["shortcut_dialog_label_input"] as LineEdit
	var path_input := ui["shortcut_dialog_path_input"] as LineEdit
	var shortcuts := _files_sync_shortcuts_from_state(state)
	if mode == "edit":
		if index < 0 or index >= shortcuts.size():
			_set_status(ui["status"] as Label, "Select a shortcut first", true)
			return
		var shortcut: Dictionary = shortcuts[index]
		state["shortcut_dialog_mode"] = "edit"
		state["shortcut_dialog_index"] = index
		title.text = "Edit shortcut"
		label_input.text = str(shortcut.get("label", ""))
		path_input.text = str(shortcut.get("path", ""))
	else:
		state["shortcut_dialog_mode"] = "add"
		state["shortcut_dialog_index"] = -1
		title.text = "Add shortcut"
		label_input.text = ""
		path_input.text = str(state.get("current_path", _fs.home_path()))
	dialog.popup_centered()
	label_input.grab_focus()
	label_input.select_all()
	_update_files_action_state(state, ui)

func _files_commit_shortcut_dialog(state: Dictionary, ui: Dictionary) -> void:
	var dialog := ui["shortcuts_dialog"] as PopupPanel
	var label_input := ui["shortcut_dialog_label_input"] as LineEdit
	var path_input := ui["shortcut_dialog_path_input"] as LineEdit
	var label := label_input.text.strip_edges()
	var path := path_input.text.strip_edges()
	if label == "" or path == "":
		_set_status(ui["status"] as Label, "Shortcut name and path are required", true)
		_update_files_action_state(state, ui)
		return
	var mode := str(state.get("shortcut_dialog_mode", "add"))
	if mode == "edit":
		_files_rename_shortcut(state, ui, label, path)
	else:
		_files_add_shortcut(state, ui, label, path)
	dialog.hide()

func _files_add_shortcut(state: Dictionary, ui: Dictionary, label: String, path: String) -> void:
	var shortcuts := _files_sync_shortcuts_from_state(state)
	shortcuts.append({"label": label, "path": _fs.normalize_path(path)})
	state["shortcuts"] = shortcuts
	state["shortcut_selected_index"] = shortcuts.size() - 1
	_files_shortcuts = shortcuts.duplicate(true)
	_set_status(ui["status"] as Label, "Shortcut added")
	_refresh_files_shortcuts(state, ui)
	_queue_state_save()

func _files_rename_shortcut(state: Dictionary, ui: Dictionary, label: String, path: String) -> void:
	var status := ui["status"] as Label
	var index := int(state.get("shortcut_selected_index", -1))
	var shortcuts := _files_sync_shortcuts_from_state(state)
	if index < 0 or index >= shortcuts.size():
		_set_status(status, "Select a shortcut first", true)
		return
	shortcuts[index] = {"label": label, "path": _fs.normalize_path(path)}
	state["shortcuts"] = shortcuts
	_files_shortcuts = shortcuts.duplicate(true)
	_set_status(status, "Shortcut updated")
	_refresh_files_shortcuts(state, ui)
	_queue_state_save()

func _files_delete_shortcut(state: Dictionary, ui: Dictionary) -> void:
	var status := ui["status"] as Label
	var index := int(state.get("shortcut_selected_index", -1))
	var shortcuts := _files_sync_shortcuts_from_state(state)
	if index < 0 or index >= shortcuts.size():
		_set_status(status, "Select a shortcut first", true)
		return
	shortcuts.remove_at(index)
	state["shortcuts"] = shortcuts
	state["shortcut_selected_index"] = clampi(index, -1, shortcuts.size() - 1)
	_files_shortcuts = shortcuts.duplicate(true)
	_set_status(status, "Shortcut deleted")
	_refresh_files_shortcuts(state, ui)
	_queue_state_save()

func _files_move_shortcut(direction: int, state: Dictionary, ui: Dictionary) -> void:
	var status := ui["status"] as Label
	var index := int(state.get("shortcut_selected_index", -1))
	var shortcuts := _files_sync_shortcuts_from_state(state)
	if index < 0 or index >= shortcuts.size():
		_set_status(status, "Select a shortcut first", true)
		return
	var target_index := index + direction
	if target_index < 0 or target_index >= shortcuts.size():
		return
	var moving: Dictionary = shortcuts[index]
	shortcuts.remove_at(index)
	shortcuts.insert(target_index, moving)
	state["shortcuts"] = shortcuts
	state["shortcut_selected_index"] = target_index
	_files_shortcuts = shortcuts.duplicate(true)
	_set_status(status, "Shortcut order updated")
	_refresh_files_shortcuts(state, ui)
	_queue_state_save()

func _files_navigate_history(direction: int, state: Dictionary, ui: Dictionary) -> void:
	var history_variant: Variant = state.get("history", [])
	var history: Array = history_variant if history_variant is Array else []
	if history.is_empty():
		return
	var index := int(state.get("history_index", history.size() - 1))
	var target_index := clampi(index + direction, 0, history.size() - 1)
	if target_index == index:
		return
	state["history_index"] = target_index
	var target := str(history[target_index])
	var path_input := ui["path_input"] as LineEdit
	path_input.text = target
	_refresh_files(state, ui, false, false)

func _files_push_history(path: String, state: Dictionary) -> void:
	var history_variant: Variant = state.get("history", [])
	var history: Array = history_variant if history_variant is Array else []
	var index := int(state.get("history_index", history.size() - 1))
	if index < history.size() - 1:
		history = history.slice(0, index + 1)
	if history.is_empty() or str(history[history.size() - 1]) != path:
		history.append(path)
		index = history.size() - 1
	else:
		index = history.size() - 1
	state["history"] = history
	state["history_index"] = index

func _files_breadcrumb_text(path: String) -> String:
	var normalized: String = _fs.normalize_path(path)
	if normalized == "/":
		return "Home"
	var pieces: PackedStringArray = normalized.trim_prefix("/").split("/", false)
	if pieces.is_empty():
		return "Home"
	if pieces.size() >= 2 and pieces[0] == "home":
		pieces[0] = "Home"
	return " › ".join(PackedStringArray(pieces))

func _files_modified_text(_item: Dictionary) -> String:
	return "—"

func _files_size_text(item: Dictionary) -> String:
	if str(item.get("type", "")) == "dir":
		var children: Array = _fs.list_dir(str(item.get("path", "")))
		var child_count: int = children.size()
		return "%d item%s" % [child_count, "" if child_count == 1 else "s"]
	var size_bytes := int(item.get("size", 0))
	if size_bytes < 1024:
		return "%d B" % size_bytes
	var size_kb := float(size_bytes) / 1024.0
	if size_kb < 1024.0:
		return "%.1f KB" % size_kb
	var size_mb := size_kb / 1024.0
	if size_mb < 1024.0:
		return "%.1f MB" % size_mb
	return "%.1f GB" % (size_mb / 1024.0)


func open_path(path: String) -> void:
	if _fs == null or _state.is_empty() or _ui.is_empty():
		return
	var target: String = _fs.normalize_path(path)
	var folder_path: String = target
	var select_path := ""
	if _fs.is_file(target):
		folder_path = _fs.parent_path(target)
		select_path = target
	elif not _fs.is_dir(target):
		folder_path = _fs.home_path()
	var path_input := _ui.get("path_input", null) as LineEdit
	if path_input == null:
		return
	path_input.text = folder_path
	_refresh_files(_state, _ui)
	if select_path != "":
		_select_files_item_by_path(select_path, _state, _ui)

func select_path(path: String) -> bool:
	if _state.is_empty() or _ui.is_empty():
		return false
	return _select_files_item_by_path(path, _state, _ui)

func get_current_path() -> String:
	return str(_state.get("current_path", ""))

func get_selected_path() -> String:
	return str(_state.get("selected_path", ""))

func get_visible_entries() -> Array:
	if _fs == null or _state.is_empty():
		return []
	return _fs.list_dir(str(_state.get("current_path", _fs.home_path())))

func open_selected() -> void:
	if _state.is_empty():
		return
	var selected := str(_state.get("selected_path", ""))
	if selected == "":
		_set_status(_ui.get("status", null) as Label, "Select an item first", true)
		return
	if str(_state.get("selected_type", "")) == "dir":
		open_path(selected)
	else:
		_route_open_file(selected)

func _select_files_item_by_path(target_path: String, state: Dictionary, ui: Dictionary) -> bool:
	var tree := ui.get("tree", null) as Tree
	if tree == null:
		return false
	var root_item := tree.get_root()
	if root_item == null:
		return false
	var item := root_item.get_first_child()
	while item != null:
		var metadata: Dictionary = item.get_metadata(0) as Dictionary
		if str(metadata.get("path", "")) == target_path:
			tree.set_selected(item, 0)
			_select_file_item(item, state, ui)
			return true
		item = item.get_next()
	return false

func _paste_destination_path(source_path: String, destination_dir: String) -> String:
	var clean_source: String = _fs.normalize_path(source_path)
	var clean_destination_dir: String = _fs.normalize_path(destination_dir)
	var base_name: String = clean_source.get_file()
	var stem: String = base_name.get_basename()
	var extension: String = base_name.get_extension()
	var candidate_name: String = base_name
	var index := 1
	while _fs.exists(_fs.join_path(clean_destination_dir, candidate_name)):
		if extension == "":
			candidate_name = "%s copy%s" % [stem, "" if index == 1 else " " + str(index)]
		else:
			candidate_name = "%s copy%s.%s" % [stem, "" if index == 1 else " " + str(index), extension]
		index += 1
	return _fs.join_path(clean_destination_dir, candidate_name)


func _route_open_file(path: String) -> void:
	if _open_file_callback.is_valid():
		_open_file_callback.call(path)
		return
	if _shell != null and _shell.has_method("_open_text_file"):
		_shell.call("_open_text_file", path)

func _emit_shortcuts_changed() -> void:
	if _shortcuts_changed_callback.is_valid():
		_shortcuts_changed_callback.call(_files_shortcuts.duplicate(true))

func _queue_state_save() -> void:
	if _state_save_callback.is_valid():
		_state_save_callback.call()
		return
	if _shell != null and _shell.has_method("_queue_state_save"):
		_shell.call("_queue_state_save")

func _app_root() -> VBoxContainer:
	if _shell != null and _shell.has_method("_app_root"):
		return _shell.call("_app_root") as VBoxContainer
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	return root

func _label(text_value: String, font_size: int, color: Color) -> Label:
	if _shell != null and _shell.has_method("_label"):
		return _shell.call("_label", text_value, font_size, color) as Label
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _set_status(label: Label, message: String, is_error: bool = false) -> void:
	if label == null:
		return
	if _shell != null and _shell.has_method("_set_status"):
		_shell.call("_set_status", label, message, is_error)
		return
	label.text = message
	label.add_theme_color_override("font_color", Tokens.ERROR if is_error else Tokens.MUTED)

func _button(text_value: String, min_size: Vector2) -> Button:
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

func _files_menu_button(text_value: String) -> Button:
	if _shell != null and _shell.has_method("_files_menu_button"):
		return _shell.call("_files_menu_button", text_value) as Button
	return _button(text_value, Vector2(60, 28))

func _files_chrome_button(text_value: String, min_size: Vector2) -> Button:
	if _shell != null and _shell.has_method("_files_chrome_button"):
		return _shell.call("_files_chrome_button", text_value, min_size) as Button
	var button := _button(text_value, min_size)
	button.add_theme_font_size_override("font_size", 13)
	return button

func _files_table_header_label(text_value: String) -> Label:
	if _shell != null and _shell.has_method("_files_table_header_label"):
		return _shell.call("_files_table_header_label", text_value) as Label
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Tokens.MUTED)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _style_files_tree(tree: Tree) -> void:
	if _shell != null and _shell.has_method("_style_files_tree"):
		_shell.call("_style_files_tree", tree)
		return
	tree.add_theme_color_override("font_color", Tokens.TEXT)
	tree.add_theme_color_override("font_selected_color", Tokens.TEXT)
	tree.add_theme_stylebox_override("panel", StyleFactory.input_normal(10))
	tree.add_theme_stylebox_override("focus", StyleFactory.build(Color(0, 0, 0, 0), Tokens.FOCUS, 2, 10))

func _style_line_edit(input: LineEdit) -> void:
	if _shell != null and _shell.has_method("_style_line_edit"):
		_shell.call("_style_line_edit", input)
		return
	input.add_theme_color_override("font_color", Tokens.TEXT)
	input.add_theme_color_override("caret_color", Tokens.TEXT)
	input.add_theme_stylebox_override("normal", StyleFactory.input_normal(8))
	input.add_theme_stylebox_override("focus", StyleFactory.input_focus(8))
	input.add_theme_stylebox_override("read_only", StyleFactory.build(Tokens.alpha(Tokens.PANEL, 0.5), Tokens.BORDER, 1, 8))

func _style_item_list(list: ItemList) -> void:
	if _shell != null and _shell.has_method("_style_item_list"):
		_shell.call("_style_item_list", list)
		return
	list.add_theme_color_override("font_color", Tokens.TEXT)
	list.add_theme_color_override("font_selected_color", Tokens.TEXT)
	list.add_theme_stylebox_override("panel", StyleFactory.input_normal(10))
	list.add_theme_stylebox_override("selected", StyleFactory.list_selected())
	list.add_theme_stylebox_override("selected_focus", StyleFactory.list_selected())

func _style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	if _shell != null and _shell.has_method("_style"):
		return _shell.call("_style", bg, border, border_width, radius) as StyleBoxFlat
	return StyleFactory.build(bg, border, border_width, radius)
