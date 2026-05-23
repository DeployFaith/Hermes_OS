class_name IconAtlas
extends RefCounted

const Tokens := preload("res://scripts/os/design_tokens.gd")

var _cache: Dictionary = {}

func get_icon(name: String, size: int = 20) -> Texture2D:
	var clean_size: int = maxi(size, 12)
	var key: String = "%s_%d" % [name.to_lower(), clean_size]
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = _make_icon(name.to_lower(), clean_size)
	_cache[key] = tex
	return tex

func _make_icon(name: String, size: int) -> Texture2D:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var primary: Color = _icon_color(name)
	var accent: Color = Tokens.alpha(Tokens.WHITE, 0.92)
	var pad: int = maxi(1, int(size * 0.10))
	var body: Rect2i = Rect2i(pad, pad, size - pad * 2, size - pad * 2)
	if body.size.x < 4 or body.size.y < 4:
		body = Rect2i(1, 1, maxi(size - 2, 2), maxi(size - 2, 2))

	_draw_glyph(image, name, body, primary, accent)
	return ImageTexture.create_from_image(image)

func _draw_glyph(image: Image, name: String, rect: Rect2i, primary: Color, accent: Color) -> void:
	match name:
		"folder", "files":
			_draw_folder_glyph(image, rect, primary, accent)
		"file", "text":
			_draw_file_glyph(image, rect, primary, accent)
		"notes":
			_draw_notes_glyph(image, rect, primary, accent)
		"browser", "web", "wifi", "network":
			_draw_browser_glyph(image, rect, primary, accent)
		"terminal", "console":
			_draw_terminal_glyph(image, rect, primary, accent)
		"settings", "system":
			_draw_settings_glyph(image, rect, primary, accent)
		"start", "home":
			_draw_home_glyph(image, rect, primary, accent)
		"notification":
			_draw_notification_glyph(image, rect, primary, accent)
		"battery", "power":
			_draw_battery_glyph(image, rect, primary, accent)
		_:
			_draw_file_glyph(image, rect, primary, accent)

func _draw_folder_glyph(image: Image, rect: Rect2i, primary: Color, accent: Color) -> void:
	var tab_w: int = maxi(4, int(rect.size.x * 0.40))
	var tab_h: int = maxi(3, int(rect.size.y * 0.22))
	var tab_x: int = rect.position.x + maxi(1, int(rect.size.x * 0.08))
	var tab_y: int = rect.position.y + maxi(1, int(rect.size.y * 0.12))
	image.fill_rect(Rect2i(tab_x, tab_y, tab_w, tab_h), Tokens.alpha(primary, 0.85))
	var body_y: int = tab_y + tab_h - 1
	var body_h: int = rect.position.y + rect.size.y - body_y
	image.fill_rect(Rect2i(rect.position.x, body_y, rect.size.x, body_h), primary)
	image.fill_rect(Rect2i(rect.position.x, body_y, rect.size.x, 1), accent)

func _draw_file_glyph(image: Image, rect: Rect2i, primary: Color, accent: Color) -> void:
	var x: int = rect.position.x + maxi(2, int(rect.size.x * 0.18))
	var y: int = rect.position.y + maxi(2, int(rect.size.y * 0.12))
	var w: int = rect.size.x - maxi(4, int(rect.size.x * 0.30))
	var h: int = rect.size.y - maxi(4, int(rect.size.y * 0.20))
	if w < 5 or h < 5:
		return
	image.fill_rect(Rect2i(x, y, w, h), primary)
	var fold: int = maxi(2, int(mini(w, h) * 0.28))
	image.fill_rect(Rect2i(x + w - fold, y, fold, fold), Tokens.alpha(accent, 0.95))
	image.fill_rect(Rect2i(x + 1, y + 2, maxi(w - fold - 2, 1), 1), accent)

func _draw_notes_glyph(image: Image, rect: Rect2i, primary: Color, accent: Color) -> void:
	_draw_file_glyph(image, rect, primary, accent)
	var left: int = rect.position.x + maxi(3, int(rect.size.x * 0.24))
	var right: int = rect.position.x + rect.size.x - maxi(3, int(rect.size.x * 0.22))
	var y: int = rect.position.y + maxi(4, int(rect.size.y * 0.40))
	var step: int = maxi(2, int(rect.size.y * 0.14))
	for i in range(3):
		var yy: int = y + i * step
		image.fill_rect(Rect2i(left, yy, maxi(right - left, 2), 1), accent)

func _draw_browser_glyph(image: Image, rect: Rect2i, primary: Color, accent: Color) -> void:
	var x: int = rect.position.x + maxi(2, int(rect.size.x * 0.14))
	var y: int = rect.position.y + maxi(2, int(rect.size.y * 0.18))
	var w: int = rect.size.x - maxi(4, int(rect.size.x * 0.28))
	var h: int = rect.size.y - maxi(4, int(rect.size.y * 0.30))
	if w < 5 or h < 5:
		return
	image.fill_rect(Rect2i(x, y, w, h), primary)
	var bar_h: int = maxi(2, int(h * 0.24))
	image.fill_rect(Rect2i(x + 1, y + 1, w - 2, bar_h), accent)
	var dot_y: int = y + 1 + bar_h / 2
	image.fill_rect(Rect2i(x + 3, dot_y, 1, 1), primary)
	image.fill_rect(Rect2i(x + 6, dot_y, 1, 1), primary)

func _draw_terminal_glyph(image: Image, rect: Rect2i, primary: Color, accent: Color) -> void:
	var x: int = rect.position.x + maxi(2, int(rect.size.x * 0.12))
	var y: int = rect.position.y + maxi(2, int(rect.size.y * 0.18))
	var w: int = rect.size.x - maxi(4, int(rect.size.x * 0.24))
	var h: int = rect.size.y - maxi(4, int(rect.size.y * 0.36))
	if w < 6 or h < 5:
		return
	image.fill_rect(Rect2i(x, y, w, h), primary)
	var gx: int = x + maxi(1, int(w * 0.18))
	var gy: int = y + h / 2
	image.fill_rect(Rect2i(gx, gy - 1, 2, 1), accent)
	image.fill_rect(Rect2i(gx + 1, gy, 1, 1), accent)
	image.fill_rect(Rect2i(gx + 4, gy, maxi(2, int(w * 0.34)), 1), accent)

func _draw_settings_glyph(image: Image, rect: Rect2i, primary: Color, accent: Color) -> void:
	var cx: int = rect.position.x + rect.size.x / 2
	var cy: int = rect.position.y + rect.size.y / 2
	image.fill_rect(Rect2i(cx - 1, cy - 4, 2, 8), primary)
	image.fill_rect(Rect2i(cx - 4, cy - 1, 8, 2), primary)
	image.fill_rect(Rect2i(cx - 3, cy - 3, 6, 6), Tokens.alpha(primary, 0.65))
	image.fill_rect(Rect2i(cx - 1, cy - 1, 2, 2), accent)

func _draw_home_glyph(image: Image, rect: Rect2i, primary: Color, accent: Color) -> void:
	var x: int = rect.position.x + maxi(2, int(rect.size.x * 0.18))
	var y: int = rect.position.y + maxi(2, int(rect.size.y * 0.28))
	var w: int = rect.size.x - maxi(4, int(rect.size.x * 0.36))
	var h: int = rect.size.y - maxi(4, int(rect.size.y * 0.34))
	if w < 5 or h < 5:
		return
	image.fill_rect(Rect2i(x, y + 2, w, h - 2), primary)
	image.fill_rect(Rect2i(x + 1, y + 1, w - 2, 1), accent)
	image.fill_rect(Rect2i(x + w / 2 - 1, y + h - 4, 2, 3), accent)

func _draw_notification_glyph(image: Image, rect: Rect2i, primary: Color, accent: Color) -> void:
	var x: int = rect.position.x + maxi(2, int(rect.size.x * 0.28))
	var y: int = rect.position.y + maxi(2, int(rect.size.y * 0.20))
	var w: int = rect.size.x - maxi(4, int(rect.size.x * 0.56))
	var h: int = rect.size.y - maxi(4, int(rect.size.y * 0.34))
	if w < 4 or h < 5:
		return
	image.fill_rect(Rect2i(x, y, w, h), primary)
	image.fill_rect(Rect2i(x + 1, y + 1, maxi(w - 2, 1), 1), accent)
	image.fill_rect(Rect2i(x + w / 2, y + h, 1, 1), accent)

func _draw_battery_glyph(image: Image, rect: Rect2i, primary: Color, accent: Color) -> void:
	var x: int = rect.position.x + maxi(2, int(rect.size.x * 0.18))
	var y: int = rect.position.y + maxi(2, int(rect.size.y * 0.34))
	var w: int = rect.size.x - maxi(4, int(rect.size.x * 0.30))
	var h: int = rect.size.y - maxi(4, int(rect.size.y * 0.56))
	if w < 5 or h < 4:
		return
	image.fill_rect(Rect2i(x, y, w, h), primary)
	image.fill_rect(Rect2i(x + w, y + h / 3, 1, maxi(1, h / 3)), primary)
	image.fill_rect(Rect2i(x + 1, y + 1, maxi(1, w - 2), maxi(1, h - 2)), accent)

func _icon_color(name: String) -> Color:
	match name:
		"folder", "files":
			return Color("c7a45b")
		"file", "text":
			return Color("d7dee9")
		"notes":
			return Color("8cc2ff")
		"start", "home":
			return Color("a9b7ff")
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
			return Color("a4b0c8")
		"placeholder":
			return Color("c0c8d8")
		"close":
			return Tokens.ERROR
		"minimize":
			return Tokens.WARNING
		"maximize":
			return Tokens.SUCCESS
		_:
			return Color("c0c8d8")
