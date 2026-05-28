class_name DesignTokens
extends RefCounted

# HermesUI v2 design tokens.
# Single source for the calm, dark, Linux-like desktop palette used by shell chrome,
# HermesUI components, and app surfaces. Keep these values quiet and legible: use
# layer contrast, spacing, and elevation before adding outlines/glow.

# ── Surface Colors ──
static var BG := Color("0b0d12")
static var BG_ELEVATED := Color("11141b")
static var PANEL := Color("171a22")
static var SURFACE := Color("1f2430")
static var SURFACE_HOVER := Color("272d3a")
static var SURFACE_ACTIVE := Color("303747")
static var WINDOW := BG_ELEVATED
static var INPUT_BG := Color("0f131a")
static var OVERLAY := Color("05070b")

# ── Border / Focus Colors ──
static var BORDER_SOFT := Color("252b38")
static var BORDER := Color("3b4355")
static var BORDER_ACTIVE := Color("4b556d")
static var BORDER_STRONG := Color("616d88")
static var FOCUS := Color("8cbcff")

# ── Text Colors ──
static var TEXT := Color("eceff6")
static var TEXT_MUTED := Color("9aa3b8")
# Back-compat alias used in existing shell code
static var MUTED := TEXT_MUTED
static var TEXT_FAINT := Color("737d94")
static var TEXT_DISABLED := Color("5f687d")

# ── Accent / Status Colors ──
static var ACCENT := Color("6fa8f7")
static var ACCENT_HOVER := Color("8bbcff")
static var ACCENT_PRESSED := Color("4f86d9")
# Dark text for use on accent/primary surfaces
static var ON_ACCENT := Color("08111f")
static var INFO := Color("6fa8f7")
static var SUCCESS := Color("6fbd8a")
static var WARNING := Color("d7a95f")
static var ERROR := Color("e06f7f")
static var WHITE := Color.WHITE

# ── Opacity Helpers ──
static func alpha(color: Color, a: float) -> Color:
	return Color(color.r, color.g, color.b, a)

# ── Spacing ──
static var SPACE := {
	"xxs": 2,
	"xs": 4,
	"sm": 8,
	"md": 12,
	"lg": 16,
	"xl": 24,
	"xxl": 32,
	"xxxl": 48
}

# ── Corner Radii ──
static var RADIUS := {
	"xs": 4,
	"sm": 6,
	"md": 10,
	"lg": 14,
	"xl": 18,
	"full": 999
}

# ── Animation Timing ──
static var TIME := {
	"instant": 0.06,
	"fast": 0.10,
	"normal": 0.18,
	"slow": 0.28,
	"slower": 0.42
}

# ── Elevation / Shadow Presets ──
static var ELEVATION := {
	"flat": 0,
	"raised": 1,
	"floating": 2,
	"modal": 3
}

static func shadow_small() -> Dictionary:
	return {"size": 6, "color": Color(0, 0, 0, 0.22), "offset": Vector2(0, 2)}

static func shadow_medium() -> Dictionary:
	return {"size": 12, "color": Color(0, 0, 0, 0.32), "offset": Vector2(0, 4)}

static func shadow_large() -> Dictionary:
	return {"size": 22, "color": Color(0, 0, 0, 0.42), "offset": Vector2(0, 8)}

# ── Typography ──
static var TYPE := {
	"display": {"size": 22, "color": TEXT, "line_height": 28},
	"title": {"size": 16, "color": TEXT, "line_height": 22},
	"body": {"size": 13, "color": TEXT, "line_height": 19},
	"caption": {"size": 11, "color": TEXT_MUTED, "line_height": 16},
	"label": {"size": 12, "color": TEXT_MUTED, "line_height": 18},
	"mono": {"size": 13, "color": TEXT, "line_height": 19}
}
