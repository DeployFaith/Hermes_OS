class_name HermesTheme
extends RefCounted

const DesignTokens = preload("res://scripts/os/design_tokens.gd")
const StyleFactory = preload("res://scripts/os/style_factory.gd")

const FALLBACK_COLORS: Dictionary = {
	"bg": Color("0D0F14"),
	"bg_elevated": Color("121722"),
	"surface": Color("171D2A"),
	"surface_2": Color("1E2636"),
	"surface_3": Color("263044"),
	"border": Color("344055"),
	"border_soft": Color("283348"),
	"focus_ring": Color("7B9DD6"),
	"text": Color("E8EDF5"),
	"text_muted": Color("A4AEC0"),
	"text_faint": Color("6F7A8E"),
	"text_disabled": Color("4B5568"),
	"accent": Color("7B9DD6"),
	"accent_hover": Color("9BB7E6"),
	"accent_pressed": Color("6387C4"),
	"accent_soft": Color("253149"),
	"success": Color("22C55E"),
	"warning": Color("F59E0B"),
	"danger": Color("EF4444"),
	"info": Color("38BDF8"),
	"terminal_bg": Color("0D1117"),
	"terminal_text": Color("D6DEE8"),
	"terminal_prompt": Color("7B9DD6"),
	"terminal_muted": Color("7D8796"),
	"terminal_error": Color("F87171"),
	"terminal_success": Color("4ADE80")
}

const SPACING: Dictionary = {
	"space_0": 0,
	"space_1": 4,
	"space_2": 8,
	"space_3": 12,
	"space_4": 16,
	"space_5": 20,
	"space_6": 24,
	"space_8": 32,
	"space_10": 40,
	"space_12": 48,
	"space_16": 64,
	"xs": 4,
	"sm": 8,
	"md": 12,
	"lg": 16,
	"xl": 24,
	"xxl": 32,
	"app_outer": 16,
	"panel": 16,
	"card": 14,
	"toolbar_gap": 8,
	"form_row_gap": 10,
	"section_gap": 16,
	"major_gap": 24
}

const RADII: Dictionary = {
	"radius_sm": 6,
	"radius_md": 10,
	"radius_lg": 14,
	"radius_xl": 18,
	"radius_pill": 999,
	"sm": 6,
	"md": 10,
	"lg": 14,
	"xl": 18,
	"pill": 999,
	"full": 999
}

const FONT_SIZES: Dictionary = {
	"text_xs": 11,
	"text_sm": 12,
	"text_base": 14,
	"text_md": 15,
	"text_lg": 18,
	"text_xl": 22,
	"text_title": 26,
	"app_title": 22,
	"toolbar_title": 18,
	"section_heading": 15,
	"body": 14,
	"helper": 12,
	"status": 12,
	"terminal": 13
}

const SIZES: Dictionary = {
	"button_height_sm": 28,
	"button_height": 34,
	"button_height_lg": 40,
	"input_height": 34,
	"toolbar_height": 44,
	"status_bar_height": 28,
	"tab_height": 36,
	"sidebar_width": 220,
	"sidebar_width_sm": 180,
	"list_row_height": 34,
	"table_row_height": 32,
	"icon_size_sm": 16,
	"icon_size": 20,
	"icon_size_lg": 28
}

const DURATIONS: Dictionary = {
	"duration_fast": 0.10,
	"duration_normal": 0.18,
	"duration_slow": 0.28,
	"fast": 0.10,
	"normal": 0.18,
	"slow": 0.28
}

func color(name: String) -> Color:
	match name:
		"bg":
			return DesignTokens.BG
		"bg_elevated":
			return DesignTokens.BG_ELEVATED
		"surface":
			return DesignTokens.PANEL
		"surface_2":
			return DesignTokens.SURFACE
		"surface_3":
			return DesignTokens.SURFACE_ACTIVE
		"border":
			return DesignTokens.BORDER_ACTIVE
		"border_soft":
			return DesignTokens.BORDER
		"focus_ring":
			return DesignTokens.FOCUS
		"text":
			return DesignTokens.TEXT
		"text_muted":
			return DesignTokens.TEXT_MUTED
		"text_faint":
			return DesignTokens.alpha(DesignTokens.TEXT_MUTED, 0.76)
		"text_disabled":
			return DesignTokens.TEXT_DISABLED
		"accent":
			return DesignTokens.ACCENT
		"accent_hover":
			return DesignTokens.ACCENT_HOVER
		"accent_pressed":
			return DesignTokens.alpha(DesignTokens.ACCENT, 0.78)
		"accent_soft":
			return DesignTokens.alpha(DesignTokens.ACCENT, 0.16)
		"success":
			return DesignTokens.SUCCESS
		"warning":
			return DesignTokens.WARNING
		"danger":
			return DesignTokens.ERROR
		"info":
			return Color("38BDF8")
		"terminal_bg":
			return Color("0D1117")
		"terminal_text":
			return Color("D6DEE8")
		"terminal_prompt":
			return DesignTokens.ACCENT
		"terminal_muted":
			return Color("7D8796")
		"terminal_error":
			return Color("F87171")
		"terminal_success":
			return Color("4ADE80")
		_:
			return FALLBACK_COLORS.get(name, Color.MAGENTA)

func spacing(name_or_value: Variant) -> int:
	if name_or_value is int:
		return int(name_or_value)
	if name_or_value is float:
		return int(round(float(name_or_value)))
	return int(SPACING.get(str(name_or_value), 0))

func radius(name_or_value: Variant) -> int:
	if name_or_value is int:
		return int(name_or_value)
	if name_or_value is float:
		return int(round(float(name_or_value)))
	return int(RADII.get(str(name_or_value), 0))

func font_size(name_or_value: Variant) -> int:
	if name_or_value is int:
		return int(name_or_value)
	if name_or_value is float:
		return int(round(float(name_or_value)))
	return int(FONT_SIZES.get(str(name_or_value), FONT_SIZES["text_base"]))

func duration(name: String) -> float:
	return float(DURATIONS.get(name, DURATIONS["duration_normal"]))

func easing(name: String) -> int:
	match name:
		"in":
			return Tween.EASE_IN
		"out":
			return Tween.EASE_OUT
		"in_out", "normal":
			return Tween.EASE_IN_OUT
		_:
			return Tween.EASE_OUT

func size(name: String) -> int:
	return int(SIZES.get(name, 0))

func build_theme() -> Theme:
	var theme := Theme.new()
	theme.set_color("font_color", "Label", color("text"))
	theme.set_color("font_color", "Button", color("text"))
	theme.set_color("font_hover_color", "Button", color("text"))
	theme.set_color("font_pressed_color", "Button", color("text"))
	theme.set_color("font_disabled_color", "Button", color("text_disabled"))
	theme.set_color("font_color", "LineEdit", color("text"))
	theme.set_color("font_placeholder_color", "LineEdit", color("text_faint"))
	theme.set_color("font_color", "TextEdit", color("text"))
	theme.set_color("font_placeholder_color", "TextEdit", color("text_faint"))
	theme.set_font_size("font_size", "Label", font_size("text_base"))
	theme.set_font_size("font_size", "Button", font_size("text_base"))
	theme.set_font_size("font_size", "LineEdit", font_size("text_base"))
	theme.set_font_size("font_size", "TextEdit", font_size("text_base"))
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("normal", "Button", button_style("secondary", "normal"))
	theme.set_stylebox("hover", "Button", button_style("secondary", "hover"))
	theme.set_stylebox("pressed", "Button", button_style("secondary", "pressed"))
	theme.set_stylebox("disabled", "Button", button_style("secondary", "disabled"))
	theme.set_stylebox("focus", "Button", button_style("secondary", "focused"))
	theme.set_stylebox("normal", "LineEdit", input_style("normal"))
	theme.set_stylebox("focus", "LineEdit", input_style("focused"))
	theme.set_stylebox("read_only", "LineEdit", input_style("disabled"))
	theme.set_stylebox("normal", "TextEdit", text_area_style("normal"))
	theme.set_stylebox("focus", "TextEdit", text_area_style("focused"))
	theme.set_stylebox("read_only", "TextEdit", text_area_style("disabled"))
	return theme

func apply_to(control: Control) -> void:
	if control == null:
		return
	control.theme = build_theme()

func panel_style(options: Dictionary = {}) -> StyleBoxFlat:
	var bg: Color = options.get("bg", color("surface"))
	var border: Color = options.get("border", color("border_soft"))
	var style := _base_style(bg, border, int(options.get("border_width", 1)), radius(options.get("radius", "lg")))
	_set_padding(style, int(options.get("padding", spacing("panel"))))
	return style

func card_style(options: Dictionary = {}) -> StyleBoxFlat:
	var bg: Color = options.get("bg", color("surface_2"))
	var border: Color = options.get("border", color("border_soft"))
	var style := _base_style(bg, border, int(options.get("border_width", 1)), radius(options.get("radius", "lg")))
	_set_padding(style, int(options.get("padding", spacing("card"))))
	return style

func button_style(variant: String = "secondary", state: String = "normal", options: Dictionary = {}) -> StyleBoxFlat:
	var radius_value := radius(options.get("radius", "md"))
	var bg := color("surface_2")
	var border := color("border_soft")
	var border_width := 1
	match variant:
		"primary":
			bg = color("accent")
			border = color("accent_hover")
		"ghost":
			bg = Color.TRANSPARENT
			border = Color.TRANSPARENT
		"danger":
			bg = DesignTokens.alpha(color("danger"), 0.24)
			border = DesignTokens.alpha(color("danger"), 0.52)
		"success":
			bg = DesignTokens.alpha(color("success"), 0.22)
			border = DesignTokens.alpha(color("success"), 0.50)
		_:
			bg = DesignTokens.alpha(color("surface_2"), 0.92)
			border = color("border_soft")
	match state:
		"hover":
			if variant == "primary":
				bg = color("accent_hover")
			elif variant == "ghost":
				bg = DesignTokens.alpha(color("surface_3"), 0.55)
			else:
				bg = color("surface_3")
			border = color("border")
		"pressed":
			bg = color("accent_pressed") if variant == "primary" else DesignTokens.alpha(bg, 0.74)
		"disabled":
			bg = DesignTokens.alpha(color("surface"), 0.34)
			border = DesignTokens.alpha(color("border_soft"), 0.45)
		"focused":
			bg = Color.TRANSPARENT if variant == "ghost" else bg
			border = color("focus_ring")
			border_width = 2
	var style := _base_style(bg, border, border_width, radius_value)
	style.content_margin_left = int(options.get("padding_h", 12))
	style.content_margin_right = int(options.get("padding_h", 12))
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func input_style(state: String = "normal", options: Dictionary = {}) -> StyleBoxFlat:
	var bg := color("bg_elevated")
	var border := color("border")
	var border_width := 1
	if state == "focused":
		border = color("focus_ring")
		border_width = 2
	elif state == "disabled":
		bg = DesignTokens.alpha(color("bg_elevated"), 0.55)
		border = color("border_soft")
	var style := _base_style(bg, border, border_width, radius(options.get("radius", "md")))
	style.content_margin_left = int(options.get("padding_h", 10))
	style.content_margin_right = int(options.get("padding_h", 10))
	style.content_margin_top = int(options.get("padding_v", 6))
	style.content_margin_bottom = int(options.get("padding_v", 6))
	return style

func text_area_style(state: String = "normal", options: Dictionary = {}) -> StyleBoxFlat:
	var style := input_style(state, options)
	_set_padding(style, int(options.get("padding", 10)))
	return style

func list_row_style(state: String = "normal", options: Dictionary = {}) -> StyleBoxFlat:
	var bg := Color.TRANSPARENT
	var border := Color.TRANSPARENT
	var border_width := 0
	match state:
		"hover":
			bg = DesignTokens.alpha(color("surface_3"), 0.45)
		"selected":
			bg = color("accent_soft")
			border = DesignTokens.alpha(color("accent"), 0.35)
			border_width = 1
		"disabled":
			bg = DesignTokens.alpha(color("surface"), 0.28)
		_:
			bg = options.get("bg", Color.TRANSPARENT)
	var style := _base_style(bg, border, border_width, radius(options.get("radius", "sm")))
	style.content_margin_left = int(options.get("padding_h", 10))
	style.content_margin_right = int(options.get("padding_h", 10))
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func badge_style(kind: String = "info", options: Dictionary = {}) -> StyleBoxFlat:
	var c := _kind_color(kind)
	var style := _base_style(DesignTokens.alpha(c, 0.16), DesignTokens.alpha(c, 0.38), 1, radius(options.get("radius", "pill")))
	style.content_margin_left = int(options.get("padding_h", 8))
	style.content_margin_right = int(options.get("padding_h", 8))
	style.content_margin_top = int(options.get("padding_v", 3))
	style.content_margin_bottom = int(options.get("padding_v", 3))
	return style

func _kind_color(kind: String) -> Color:
	match kind:
		"success":
			return color("success")
		"warning", "busy":
			return color("warning")
		"danger", "error":
			return color("danger")
		"muted":
			return color("text_muted")
		_:
			return color("info")

func _base_style(bg: Color, border: Color, border_width: int, radius_value: int) -> StyleBoxFlat:
	return StyleFactory.build(bg, border, border_width, radius_value)

func _set_padding(style: StyleBoxFlat, padding: int) -> void:
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
