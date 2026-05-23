class_name DesignTokens
extends RefCounted

# ── Color Palette ──
static var BG := Color("0d0f14")
static var BG_ELEVATED := Color("13151c")
static var PANEL := Color("181a22")
static var SURFACE := Color("1e2029")
static var SURFACE_HOVER := Color("272a36")
static var SURFACE_ACTIVE := Color("2f3342")
static var BORDER := Color("2d3140")
static var BORDER_ACTIVE := Color("3f4558")
static var TEXT := Color("e8eaf0")
static var TEXT_MUTED := Color("8b92a8")
static var TEXT_DISABLED := Color("5a6075")
static var ACCENT := Color("7b9dd6")
static var ACCENT_HOVER := Color("9ab8e8")
static var ERROR := Color("d76c7a")
static var WARNING := Color("d1a36a")
static var SUCCESS := Color("7ab88a")
static var FOCUS := Color("7b9dd6")
static var WHITE := Color.WHITE

# ── Opacity Helpers ──
static func alpha(color: Color, a: float) -> Color:
	return Color(color.r, color.g, color.b, a)

# ── Spacing ──
static var SPACE := {
	"xs": 4,
	"sm": 8,
	"md": 12,
	"lg": 16,
	"xl": 24,
	"xxl": 32
}

# ── Corner Radii ──
static var RADIUS := {
	"sm": 6,
	"md": 10,
	"lg": 14,
	"xl": 18,
	"full": 999
}

# ── Animation Timing ──
static var TIME := {
	"fast": 0.10,
	"normal": 0.18,
	"slow": 0.28
}

# ── Shadow Presets ──
static func shadow_small() -> Dictionary:
	return {"size": 6, "color": Color(0, 0, 0, 0.25), "offset": Vector2(0, 2)}

static func shadow_medium() -> Dictionary:
	return {"size": 12, "color": Color(0, 0, 0, 0.35), "offset": Vector2(0, 4)}

static func shadow_large() -> Dictionary:
	return {"size": 22, "color": Color(0, 0, 0, 0.45), "offset": Vector2(0, 8)}

# ── Typography ──
static var TYPE := {
	"display": {"size": 22, "color": TEXT},
	"title": {"size": 16, "color": TEXT},
	"body": {"size": 13, "color": TEXT},
	"caption": {"size": 11, "color": TEXT_MUTED},
	"label": {"size": 12, "color": TEXT_MUTED}
}
