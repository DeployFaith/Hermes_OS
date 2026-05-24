class_name StyleFactory
extends RefCounted

const Tokens := preload("res://scripts/os/design_tokens.gd")

static func build(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.anti_aliasing = true
	return style

static func glass_panel(bg_alpha: float, border_color_override: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.PANEL, bg_alpha)
	var border := border_color_override
	if border == Color.TRANSPARENT:
		border = Tokens.alpha(Tokens.WHITE, 0.08)
	var style := build(bg, border, border_width, radius)
	var shadow := Tokens.shadow_medium()
	style.shadow_size = shadow["size"]
	style.shadow_color = shadow["color"]
	style.shadow_offset = shadow["offset"]
	return style

static func solid_panel(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	return build(bg, border, border_width, radius)

static func elevated_panel(elevation: int, bg_alpha: float, radius: int) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.PANEL, bg_alpha)
	var border := Tokens.alpha(Tokens.WHITE, 0.06 + elevation * 0.04)
	var style := build(bg, border, 1, radius)
	var shadow: Dictionary
	match elevation:
		0:
			shadow = Tokens.shadow_small()
		1:
			shadow = Tokens.shadow_medium()
		2:
			shadow = Tokens.shadow_large()
		_:
			shadow = Tokens.shadow_medium()
	style.shadow_size = shadow["size"]
	style.shadow_color = shadow["color"]
	style.shadow_offset = shadow["offset"]
	return style

static func window_active(radius: int) -> StyleBoxFlat:
	var style := build(Tokens.BG_ELEVATED, Tokens.BORDER_ACTIVE, 1, radius)
	var shadow := Tokens.shadow_large()
	style.shadow_size = shadow["size"]
	style.shadow_color = shadow["color"]
	style.shadow_offset = shadow["offset"]
	return style

static func window_inactive(radius: int) -> StyleBoxFlat:
	var style := build(Tokens.BG_ELEVATED, Tokens.BORDER, 1, radius)
	var shadow := Tokens.shadow_medium()
	style.shadow_size = shadow["size"]
	style.shadow_color = Color(shadow["color"].r, shadow["color"].g, shadow["color"].b, 0.25)
	style.shadow_offset = Vector2(0, 4)
	return style

static func title_bar(active: bool, radius: int) -> StyleBoxFlat:
	var bg := Tokens.SURFACE if active else Tokens.PANEL
	var style := build(bg, Color.TRANSPARENT, 0, radius)
	style.border_width_top = 1
	style.border_color = Tokens.alpha(Tokens.WHITE, 0.06)
	return style

static func body_panel(active: bool, radius: int) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.SURFACE, 1.0) if active else Tokens.alpha(Tokens.PANEL, 1.0)
	var border := Tokens.alpha(Tokens.WHITE, 0.03)
	var style := build(bg, border, 1, radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

static func button_normal(radius: int) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.SURFACE, 0.6), Tokens.alpha(Tokens.WHITE, 0.06), 1, radius)

static func button_hover(radius: int) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.SURFACE_HOVER, 0.75), Tokens.alpha(Tokens.WHITE, 0.10), 1, radius)

static func button_pressed(radius: int) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.SURFACE_ACTIVE, 0.9), Tokens.alpha(Tokens.WHITE, 0.04), 1, radius)

static func button_focus(radius: int) -> StyleBoxFlat:
	return build(Color.TRANSPARENT, Tokens.FOCUS, 2, radius)

static func button_disabled(radius: int) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.PANEL, 0.4), Tokens.alpha(Tokens.WHITE, 0.02), 1, radius)

static func traffic_light_default() -> StyleBoxFlat:
	var style := build(Tokens.alpha(Tokens.TEXT_MUTED, 0.35), Color.TRANSPARENT, 0, 15)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

static func traffic_light_close() -> StyleBoxFlat:
	var style := build(Tokens.ERROR, Color.TRANSPARENT, 0, 15)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

static func traffic_light_maximize() -> StyleBoxFlat:
	var style := build(Tokens.SUCCESS, Color.TRANSPARENT, 0, 15)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

static func input_normal(radius: int) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.BG, 0.8), Tokens.alpha(Tokens.WHITE, 0.08), 1, radius)

static func input_focus(radius: int) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.BG, 0.9), Tokens.FOCUS, 2, radius)

static func list_panel(radius: int) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.BG, 1.0), Tokens.alpha(Tokens.WHITE, 0.05), 1, radius)

static func list_selected() -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.ACCENT, 0.12), Tokens.alpha(Tokens.ACCENT, 0.25), 1, 4)

static func context_menu(radius: int) -> StyleBoxFlat:
	var style := build(Tokens.alpha(Tokens.PANEL, 0.94), Tokens.alpha(Tokens.WHITE, 0.10), 1, radius)
	var shadow := Tokens.shadow_large()
	style.shadow_size = shadow["size"]
	style.shadow_color = shadow["color"]
	style.shadow_offset = shadow["offset"]
	return style

static func toast(level: String, radius: int) -> StyleBoxFlat:
	var border_color: Color
	match level:
		"success": border_color = Tokens.SUCCESS
		"warning": border_color = Tokens.WARNING
		"error": border_color = Tokens.ERROR
		_: border_color = Tokens.BORDER_ACTIVE
	var style := build(Tokens.alpha(Tokens.SURFACE, 0.95), border_color, 2, radius)
	var shadow := Tokens.shadow_medium()
	style.shadow_size = shadow["size"]
	style.shadow_color = shadow["color"]
	style.shadow_offset = shadow["offset"]
	style.border_width_left = 4
	return style

static func dock_pill(radius: int) -> StyleBoxFlat:
	var style := build(Tokens.alpha(Tokens.PANEL, 0.78), Tokens.alpha(Tokens.WHITE, 0.08), 1, radius)
	style.shadow_size = 16
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func top_panel() -> StyleBoxFlat:
	var style := build(Tokens.alpha(Tokens.PANEL, 0.72), Color.TRANSPARENT, 0, 0)
	style.border_width_top = 1
	style.border_color = Tokens.alpha(Tokens.WHITE, 0.06)
	return style

static func desktop_icon_selected(radius: int) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.ACCENT, 0.18), Tokens.alpha(Tokens.ACCENT, 0.50), 1, radius)

static func desktop_icon_hover(radius: int) -> StyleBoxFlat:
	return build(Tokens.alpha(Tokens.WHITE, 0.06), Color.TRANSPARENT, 0, radius)
