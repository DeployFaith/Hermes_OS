class_name IconAtlas
extends RefCounted

const Tokens := preload("res://scripts/os/design_tokens.gd")

var _cache: Dictionary = {}

func get_icon(name: String, size: int = 20) -> Texture2D:
	var key: String = "%s_%d" % [name, size]
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = _make_icon(name, size)
	_cache[key] = tex
	return tex

func _make_icon(name: String, size: int) -> Texture2D:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var color: Color = _icon_color(name)
	var pad: int = maxi(2, int(size * 0.18))
	var rect: Rect2i = Rect2i(pad, pad, size - pad * 2, size - pad * 2)
	image.fill_rect(rect, color)

	# subtle top highlight
	image.fill_rect(Rect2i(rect.position.x, rect.position.y, rect.size.x, max(1, int(size * 0.08))), Tokens.alpha(Tokens.WHITE, 0.25))

	return ImageTexture.create_from_image(image)

func _icon_color(name: String) -> Color:
	match name:
		"folder", "files":
			return Color("c7a45b")
		"file", "text":
			return Color("d7dee9")
		"browser", "web", "wifi", "network":
			return Tokens.ACCENT
		"terminal", "console":
			return Color("7ab88a")
		"notification":
			return Color("a98fff")
		"battery", "power":
			return Color("7ab88a")
		"user", "account":
			return Color("8db0e8")
		"settings", "system":
			return Tokens.TEXT_MUTED
		"close":
			return Tokens.ERROR
		"minimize":
			return Tokens.WARNING
		"maximize":
			return Tokens.SUCCESS
		_:
			return Tokens.TEXT_MUTED
