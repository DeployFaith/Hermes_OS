class_name StyleFactory
extends RefCounted

const Tokens := preload("res://scripts/os/design_tokens.gd")

# ── Base Style Builder ──
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

# ── Glass Panel (translucent acrylic) ──
static func glass_panel(bg_alpha: float = 0.82, border_color_override: Color = Color.TRANSPARENT, border_width: int = 1, radius: int = 12) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.PANEL, bg_alpha)
	var border: Color = border_color_override
	if border == Color.TRANSPARENT:
		border = Tokens.alpha(Tokens.WHITE, 0.08)
	var style := build(bg, border, border_width, radius)
	var shadow := Tokens.shadow_medium()
	style.shadow_size = shadow["size"]
	style.shadow_color = shadow["color"]
	style.shadow_offset = shadow["offset"]
	return style

# ── Solid Panel (opaque fallback) ──
static func solid_panel(bg: Color = Tokens.PANEL, border: Color = Tokens.BORDER, border_width: int = 1, radius: int = 12) -> StyleBoxFlat:
	return build(bg, border, border_width, radius)

# ── Elevated Panel (varies shadow by level) ──
static func elevated_panel(elevation: int = 0, bg_alpha: float = 0.85, radius: int = 12) -> StyleBoxFlat:
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

# ── Window Chrome ──
static func window_active(radius: int = 16) -> StyleBoxFlat:
	var style := build(Tokens.BG_ELEVATED, Tokens.BORDER_ACTIVE, 1, radius)
	var shadow := Tokens.shadow_large()
	style.shadow_size = shadow["size"]
	style.shadow_color = shadow["color"]
	style.shadow_offset = shadow["offset"]
	return style

static func window_inactive(radius: int = 16) -> StyleBoxFlat:
	var style := build(Tokens.BG_ELEVATED, Tokens.BORDER, 1, radius)
	var shadow := Tokens.shadow_medium()
	style.shadow_size = shadow["size"]
	style.shadow_color = Color(shadow["color"].r, shadow["color"].g, shadow["color"].b, 0.25)
	style.shadow_offset = Vector2(0, 4)
	return style

# ── Title Bar ──
static func title_bar(active: bool = true, radius: int = 16) -> StyleBoxFlat:
	var bg := Tokens.SURFACE if active else Tokens.PANEL
	var style := build(bg, Color.TRANSPARENT, 0, radius)
	# Top highlight line effect
	style.border_width_top = 1
	style.border_color = Tokens.alpha(Tokens.WHITE, 0.06)
	return style

# ── Body Panel ──
static func body_panel(active: bool = true, radius: int = 12) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.SURFACE, 1.0) if active else Tokens.alpha(Tokens.PANEL, 1.0)
	var border := Tokens.alpha(Tokens.WHITE, 0.03)
	var style := build(bg, border, 1, radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

# ── Button Styles ──
static func button_normal(radius: int = 8) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.SURFACE, 0.6)
	var border := Tokens.alpha(Tokens.WHITE, 0.06)
	var style := build(bg, border, 1, radius)
	return style

static func button_hover(radius: int = 8) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.SURFACE_HOVER, 0.75)
	var border := Tokens.alpha(Tokens.WHITE, 0.10)
	var style := build(bg, border, 1, radius)
	return style

static func button_pressed(radius: int = 8) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.SURFACE_ACTIVE, 0.9)
	var border := Tokens.alpha(Tokens.WHITE, 0.04)
	var style := build(bg, border, 1, radius)
	return style

static func button_focus(radius: int = 8) -> StyleBoxFlat:
	var style := build(Color.TRANSPARENT, Tokens.FOCUS, 2, radius)
	return style

static func button_disabled(radius: int = 8) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.PANEL, 0.4)
	var border := Tokens.alpha(Tokens.WHITE, 0.02)
	var style := build(bg, border, 1, radius)
	return style

# ── Traffic Light Buttons ──
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

static func traffic_light_minimize() -> StyleBoxFlat:
	var style := build(Tokens.WARNING, Color.TRANSPARENT, 0, 15)
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

# ── Input Styles ──
static func input_normal(radius: int = 8) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.BG, 0.8)
	var border := Tokens.alpha(Tokens.WHITE, 0.08)
	var style := build(bg, border, 1, radius)
	return style

static func input_focus(radius: int = 8) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.BG, 0.9)
	var border := Tokens.FOCUS
	var style := build(bg, border, 2, radius)
	return style

# ── List / Tree ──
static func list_panel(radius: int = 10) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.BG, 1.0)
	var border := Tokens.alpha(Tokens.WHITE, 0.05)
	var style := build(bg, border, 1, radius)
	return style

static func list_selected() -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.ACCENT, 0.12)
	var border := Tokens.alpha(Tokens.ACCENT, 0.25)
	var style := build(bg, border, 1, 4)
	return style

# ── Context Menu ──
static func context_menu(radius: int = 12) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.PANEL, 0.94)
	var border := Tokens.alpha(Tokens.WHITE, 0.10)
	var style := build(bg, border, 1, radius)
	var shadow := Tokens.shadow_large()
	style.shadow_size = shadow["size"]
	style.shadow_color = shadow["color"]
	style.shadow_offset = shadow["offset"]
	return style

# ── Notification Toast ──
static func toast(level: String = "info", radius: int = 10) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.SURFACE, 0.95)
	var border_color: Color
	match level:
		"success":
			border_color = Tokens.SUCCESS
		"warning":
			border_color = Tokens.WARNING
		"error":
			border_color = Tokens.ERROR
		_:
			border_color = Tokens.BORDER_ACTIVE
	var style := build(bg, border_color, 2, radius)
	var shadow := Tokens.shadow_medium()
	style.shadow_size = shadow["size"]
	style.shadow_color = shadow["color"]
	style.shadow_offset = shadow["offset"]
	# Left accent strip effect via border_width_left
	style.border_width_left = 4
	return style

# ── Dock / Taskbar ──
static func dock_pill(radius: int = 24) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.PANEL, 0.78)
	var border := Tokens.alpha(Tokens.WHITE, 0.08)
	var style := build(bg, border, 1, radius)
	var shadow := Tokens.shadow_large()
	style.shadow_size = 16
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

# ── Top Panel ──
static func top_panel() -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.PANEL, 0.72)
	var style := build(bg, Color.TRANSPARENT, 0, 0)
	# Subtle top highlight
	style.border_width_top = 1
	style.border_color = Tokens.alpha(Tokens.WHITE, 0.06)
	return style

# ── Scrollbar ──
static func scrollbar_thumb() -> StyleBoxFlat:
	var style := build(Tokens.alpha(Tokens.ACCENT, 0.7), Color.TRANSPARENT, 0, 3)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

static func scrollbar_track() -> StyleBoxFlat:
	var style := build(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

# ── Desktop Icon ──
static func desktop_icon_selected(radius: int = 10) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.ACCENT, 0.18)
	var border := Tokens.alpha(Tokens.ACCENT, 0.50)
	var style := build(bg, border, 1, radius)
	return style

static func desktop_icon_hover(radius: int = 10) -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.WHITE, 0.06)
	var border := Color.TRANSPARENT
	var style := build(bg, border, 0, radius)
	return style

static func drag_select_rect() -> StyleBoxFlat:
	var bg := Tokens.alpha(Tokens.ACCENT, 0.12)
	var border := Tokens.alpha(Tokens.WHITE, 0.25)
	var style := build(bg, border, 1, 4)
	return style

# ── Wallpaper Overlay ──
static func noise_overlay() -> StyleBoxFlat:
	# Not applicable for StyleBoxFlat — will use TextureRect instead
	return StyleBoxFlat.new()
