class_name HermesComponentFactory
extends RefCounted

const HermesThemeScript = preload("res://scripts/ui/hermes_ui/hermes_theme.gd")
const HermesRefsScript = preload("res://scripts/ui/hermes_ui/hermes_refs.gd")
const DesignTokens = preload("res://scripts/os/design_tokens.gd")

var theme = null

func _init(p_theme = null) -> void:
	theme = p_theme if p_theme != null else HermesThemeScript.new()

func vbox(children: Array = [], gap: int = -1, options: Dictionary = {}) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", theme.spacing("space_3") if gap < 0 else gap)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child in children:
		_add_child_if_control(box, child)
	_apply_common_options(box, options)
	return box

func hbox(children: Array = [], gap: int = -1, options: Dictionary = {}) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", theme.spacing("space_3") if gap < 0 else gap)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child in children:
		_add_child_if_control(box, child)
	_apply_common_options(box, options)
	return box

func spacer(size: int = 8, vertical: bool = false) -> Control:
	var node := Control.new()
	if vertical:
		node.custom_minimum_size = Vector2(1, size)
	else:
		node.custom_minimum_size = Vector2(size, 1)
	return node

func split_view(left: Control, right: Control, sidebar_width: int = -1, options: Dictionary = {}) -> Control:
	var root := HBoxContainer.new()
	root.name = "HermesSplitView"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	var width: int = theme.size("sidebar_width") if sidebar_width < 0 else sidebar_width
	if left != null:
		left.custom_minimum_size = Vector2(width, left.custom_minimum_size.y)
		left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(left)
	var separator := ColorRect.new()
	separator.name = "HermesSplitSeparator"
	separator.color = theme.color("border_soft")
	separator.custom_minimum_size = Vector2(1, 0)
	separator.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(separator)
	if right != null:
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(right)
	_apply_common_options(root, options)
	return root

func panel(children: Array = [], padding: int = -1, variant: String = "base", options: Dictionary = {}) -> PanelContainer:
	var panel_node := PanelContainer.new()
	panel_node.name = "HermesPanel"
	var style_options := options.duplicate(true)
	if padding >= 0:
		style_options["padding"] = padding
	if variant == "elevated":
		style_options["bg"] = theme.color("surface_2")
	panel_node.add_theme_stylebox_override("panel", theme.panel_style(style_options))
	panel_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := vbox(children, int(options.get("gap", theme.spacing("space_3"))))
	body.name = "HermesPanelBody"
	panel_node.add_child(body)
	_apply_common_options(panel_node, options)
	return panel_node

func card(children: Array = [], padding: int = -1, options: Dictionary = {}) -> PanelContainer:
	var card_node := PanelContainer.new()
	card_node.name = "HermesCard"
	var style_options := options.duplicate(true)
	if padding >= 0:
		style_options["padding"] = padding
	card_node.add_theme_stylebox_override("panel", theme.card_style(style_options))
	card_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := vbox(children, int(options.get("gap", theme.spacing("space_3"))))
	body.name = "HermesCardBody"
	card_node.add_child(body)
	_apply_common_options(card_node, options)
	return card_node

func label(text: String = "", variant: String = "body", options: Dictionary = {}) -> Label:
	var node := Label.new()
	node.text = text
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if bool(options.get("autowrap", false)) else TextServer.AUTOWRAP_OFF
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_label_variant(node, variant)
	_apply_common_options(node, options)
	return node

func badge(text: String = "", kind: String = "info", options: Dictionary = {}) -> Control:
	var holder := PanelContainer.new()
	holder.name = "HermesBadge"
	holder.add_theme_stylebox_override("panel", theme.badge_style(kind, options))
	var text_label := label(text, "status", {"name": "HermesBadgeLabel"})
	text_label.add_theme_color_override("font_color", theme.color("text" if kind == "muted" else _kind_text_color_name(kind)))
	holder.add_child(text_label)
	_apply_common_options(holder, options)
	return holder

func message_item(sender: String = "", text: String = "", kind: String = "user", options: Dictionary = {}) -> Control:
	var style_options := options.duplicate(true)
	match kind:
		"user":
			style_options["bg"] = theme.color("surface_3")
			style_options["border"] = theme.color("border")
		"hermes":
			style_options["bg"] = theme.color("surface_2")
			style_options["border"] = theme.color("accent")
		"system":
			style_options["bg"] = DesignTokens.alpha(theme.color("warning"), 0.12)
			style_options["border"] = DesignTokens.alpha(theme.color("warning"), 0.45)
		"error":
			style_options["bg"] = DesignTokens.alpha(theme.color("danger"), 0.12)
			style_options["border"] = DesignTokens.alpha(theme.color("danger"), 0.45)
		_:
			style_options["bg"] = theme.color("surface_2")
	var sender_label := label(sender, "status", {"name": "HermesMessageSender"})
	sender_label.add_theme_color_override("font_color", theme.color("accent") if kind == "hermes" else theme.color("text_muted"))
	var body_label := label(text, "body", {"name": "HermesMessageBody", "autowrap": true})
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wrapper := card([sender_label, body_label], int(options.get("padding", theme.spacing("card"))), style_options)
	wrapper.name = "HermesMessageItem"
	return wrapper

func button(text: String = "", on_pressed: Callable = Callable(), variant: String = "secondary", disabled: bool = false, options: Dictionary = {}) -> Button:
	var node := Button.new()
	node.text = text
	node.disabled = disabled or bool(options.get("disabled", false))
	node.custom_minimum_size = Vector2(int(options.get("width", 0)), int(options.get("height", theme.size("button_height"))))
	node.add_theme_color_override("font_color", theme.color("text"))
	node.add_theme_color_override("font_disabled_color", theme.color("text_disabled"))
	_apply_button_styles(node, variant, options)
	if on_pressed.is_valid():
		node.pressed.connect(on_pressed)
	_attach_interactive_meta(node, text, "button", options)
	_apply_common_options(node, options)
	return node

func icon_button(icon: String = "", on_pressed: Callable = Callable(), variant: String = "ghost", disabled: bool = false, options: Dictionary = {}) -> Button:
	var icon_options := options.duplicate(true)
	icon_options["width"] = int(icon_options.get("width", theme.size("button_height")))
	icon_options["height"] = int(icon_options.get("height", theme.size("button_height")))
	var node := button(icon, on_pressed, variant, disabled, icon_options)
	node.name = str(options.get("name", "HermesIconButton"))
	return node

func input(value: String = "", placeholder: String = "", on_change: Callable = Callable(), on_submit: Callable = Callable(), options: Dictionary = {}) -> LineEdit:
	var node := LineEdit.new()
	node.text = value
	node.placeholder_text = placeholder
	node.custom_minimum_size = Vector2(0, int(options.get("height", theme.size("input_height"))))
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.editable = not bool(options.get("disabled", false))
	node.add_theme_color_override("font_color", theme.color("text"))
	node.add_theme_color_override("font_placeholder_color", theme.color("text_faint"))
	node.add_theme_stylebox_override("normal", theme.input_style("normal"))
	node.add_theme_stylebox_override("focus", theme.input_style("focused"))
	node.add_theme_stylebox_override("read_only", theme.input_style("disabled"))
	if on_change.is_valid():
		node.text_changed.connect(on_change)
	if on_submit.is_valid():
		node.text_submitted.connect(on_submit)
	_attach_interactive_meta(node, placeholder if placeholder != "" else value, "input", options)
	_apply_common_options(node, options)
	return node

func text_area(value: String = "", placeholder: String = "", on_change: Callable = Callable(), options: Dictionary = {}) -> TextEdit:
	var node := TextEdit.new()
	node.text = value
	node.placeholder_text = placeholder
	node.custom_minimum_size = Vector2(0, int(options.get("height", 96)))
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL if bool(options.get("expand_v", false)) else Control.SIZE_FILL
	node.editable = not bool(options.get("readonly", false)) and not bool(options.get("disabled", false))
	node.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	node.add_theme_color_override("font_color", theme.color("text"))
	node.add_theme_color_override("font_placeholder_color", theme.color("text_faint"))
	node.add_theme_stylebox_override("normal", theme.text_area_style("normal"))
	node.add_theme_stylebox_override("focus", theme.text_area_style("focused"))
	node.add_theme_stylebox_override("read_only", theme.text_area_style("disabled"))
	if on_change.is_valid():
		node.text_changed.connect(on_change)
	_attach_interactive_meta(node, placeholder if placeholder != "" else "text area", "text_area", options)
	_apply_common_options(node, options)
	return node

func toolbar(children: Array = [], options: Dictionary = {}) -> Control:
	var bar := PanelContainer.new()
	bar.name = "HermesToolbar"
	var style_options := {"bg": theme.color("surface"), "border": theme.color("border_soft"), "radius": 0, "padding": 0}
	bar.add_theme_stylebox_override("panel", theme.panel_style(style_options))
	bar.custom_minimum_size = Vector2(0, int(options.get("height", theme.size("toolbar_height"))))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := hbox(children, int(options.get("gap", theme.spacing("toolbar_gap"))))
	row.name = "HermesToolbarRow"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", int(options.get("gap", theme.spacing("toolbar_gap"))))
	row.set_meta("padding_h", int(options.get("padding_h", 12)))
	bar.add_child(row)
	_apply_common_options(bar, options)
	return bar

func sidebar(children: Array = [], width: int = -1, options: Dictionary = {}) -> Control:
	var node := panel(children, int(options.get("padding", theme.spacing("panel"))), "base", {"bg": theme.color("bg_elevated"), "radius": 0, "gap": int(options.get("gap", theme.spacing("space_2")))})
	node.name = "HermesSidebar"
	node.custom_minimum_size = Vector2(theme.size("sidebar_width") if width < 0 else width, 0)
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_common_options(node, options)
	return node

func status_bar(text: String = "", kind: String = "info", options: Dictionary = {}) -> Control:
	var bar := PanelContainer.new()
	bar.name = "HermesStatusBar"
	bar.custom_minimum_size = Vector2(0, int(options.get("height", theme.size("status_bar_height"))))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("panel", theme.panel_style({"bg": theme.color("surface"), "border": theme.color("border_soft"), "radius": 0, "padding": 0}))
	var row := hbox([], int(options.get("gap", theme.spacing("space_2"))))
	row.name = "HermesStatusRow"
	var status_label := label(text, "status", {"name": "HermesStatusText"})
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_color_override("font_color", theme.color(_kind_text_color_name(kind)))
	row.add_child(status_label)
	bar.add_child(row)
	bar.set_meta("status_label", status_label)
	_apply_common_options(bar, options)
	return bar

func list(items: Array = [], selected_id: String = "", on_select: Callable = Callable(), options: Dictionary = {}) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "HermesList"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rows := VBoxContainer.new()
	rows.name = "HermesListRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", int(options.get("gap", 2)))
	scroll.add_child(rows)
	if items.is_empty():
		rows.add_child(label(str(options.get("empty_text", "No items")), "muted", {"name": "HermesListEmpty"}))
	else:
		for item in items:
			var data := _item_to_dictionary(item)
			if data.has("node") and data["node"] is Control:
				var custom_row := data["node"] as Control
				custom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rows.add_child(custom_row)
				continue
			var item_id := str(data.get("id", data.get("text", "")))
			var row_button := button(str(data.get("text", item_id)), Callable(), "ghost", false, {"name": "HermesListRow", "height": theme.size("list_row_height"), "ref": data.get("ref", ""), "mcp_role": "listitem"})
			row_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row_button.add_theme_stylebox_override("normal", theme.list_row_style("selected" if item_id == selected_id else "normal"))
			row_button.add_theme_stylebox_override("hover", theme.list_row_style("hover"))
			row_button.add_theme_stylebox_override("pressed", theme.list_row_style("selected"))
			if on_select.is_valid():
				row_button.pressed.connect(func() -> void:
					on_select.call(item_id)
				)
			rows.add_child(row_button)
	_apply_common_options(scroll, options)
	return scroll

func tabs(tabs: Array = [], active_id: String = "", on_change: Callable = Callable(), options: Dictionary = {}) -> Control:
	var row := hbox([], int(options.get("gap", 4)), options)
	row.name = "HermesTabs"
	row.custom_minimum_size = Vector2(0, theme.size("tab_height"))
	for item in tabs:
		var data := _item_to_dictionary(item)
		var tab_id := str(data.get("id", data.get("text", "")))
		var variant := "secondary" if tab_id == active_id else "ghost"
		var tab_button := button(str(data.get("text", tab_id)), Callable(), variant, false, {"height": theme.size("tab_height"), "mcp_role": "tab", "ref": data.get("ref", "")})
		if on_change.is_valid():
			tab_button.pressed.connect(func() -> void:
				on_change.call(tab_id)
			)
		row.add_child(tab_button)
	return row

func _apply_button_styles(node: Button, variant: String, options: Dictionary) -> void:
	node.add_theme_stylebox_override("normal", theme.button_style(variant, "normal", options))
	node.add_theme_stylebox_override("hover", theme.button_style(variant, "hover", options))
	node.add_theme_stylebox_override("pressed", theme.button_style(variant, "pressed", options))
	node.add_theme_stylebox_override("disabled", theme.button_style(variant, "disabled", options))
	node.add_theme_stylebox_override("focus", theme.button_style(variant, "focused", options))

func _apply_label_variant(node: Label, variant: String) -> void:
	var color_name := "text"
	var size_name: Variant = "text_base"
	match variant:
		"title":
			size_name = "text_xl"
		"heading":
			size_name = "text_lg"
		"muted":
			color_name = "text_muted"
		"faint":
			color_name = "text_faint"
		"mono":
			size_name = "terminal"
		"status":
			size_name = "status"
			color_name = "text_muted"
		"danger":
			color_name = "danger"
		"success":
			color_name = "success"
		"warning":
			color_name = "warning"
		"info":
			color_name = "info"
		_:
			size_name = "text_base"
	node.add_theme_font_size_override("font_size", theme.font_size(size_name))
	node.add_theme_color_override("font_color", theme.color(color_name))

func _apply_common_options(node: Control, options: Dictionary) -> void:
	if options.has("name"):
		node.name = str(options["name"])
	if options.has("tooltip"):
		node.tooltip_text = str(options["tooltip"])
	if options.has("visible"):
		node.visible = bool(options["visible"])
	if options.has("min_size") and options["min_size"] is Vector2:
		node.custom_minimum_size = options["min_size"]
	if bool(options.get("expand_h", false)):
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if bool(options.get("expand_v", false)):
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if options.has("size_flags_h"):
		node.size_flags_horizontal = int(options["size_flags_h"])
	if options.has("size_flags_v"):
		node.size_flags_vertical = int(options["size_flags_v"])
	if options.has("ref") or options.has("mcp_role") or options.has("mcp_actions"):
		var meta := {
			"ref": str(options.get("ref", "")),
			"role": str(options.get("mcp_role", "")),
			"label": str(options.get("label", node.name)),
			"actions": options.get("mcp_actions", []),
			"enabled": not bool(options.get("disabled", false)),
			"visible": node.visible
		}
		HermesRefsScript.attach_meta(node, meta)

func _attach_interactive_meta(node: Control, label_text: String, role: String, options: Dictionary) -> void:
	var meta := {
		"ref": str(options.get("ref", "")),
		"role": str(options.get("mcp_role", role)),
		"label": str(options.get("label", label_text)),
		"actions": options.get("mcp_actions", ["press"] if role == "button" else []),
		"enabled": not bool(options.get("disabled", false)),
		"visible": node.visible
	}
	if meta["ref"] != "" or meta["role"] != "":
		HermesRefsScript.attach_meta(node, meta)

func _add_child_if_control(parent: Container, child: Variant) -> void:
	if child is Control:
		parent.add_child(child)

func _item_to_dictionary(item: Variant) -> Dictionary:
	if item is Dictionary:
		return (item as Dictionary).duplicate(true)
	return {"id": str(item), "text": str(item)}

func _kind_text_color_name(kind: String) -> String:
	match kind:
		"success":
			return "success"
		"warning", "busy":
			return "warning"
		"danger", "error":
			return "danger"
		"muted":
			return "text_muted"
		_:
			return "info"
