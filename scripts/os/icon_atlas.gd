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

	var bg: Color = _icon_color(name)
	var fg: Color = Tokens.alpha(Tokens.WHITE, 0.92)
	var pad: int = maxi(2, int(size * 0.12))
	var body: Rect2i = Rect2i(pad, pad, size - pad * 2, size - pad * 2)
	if body.size.x < 4 or body.size.y < 4:
		body = Rect2i(1, 1, maxi(size - 2, 2), maxi(size - 2, 2))

	image.fill_rect(body, bg)
	_draw_glyph(image, name, body, fg)

	# subtle top highlight
	var shine_h: int = maxi(1, int(body.size.y * 0.14))
	image.fill_rect(Rect2i(body.position.x, body.position.y, body.size.x, shine_h), Tokens.alpha(Tokens.WHITE, 0.18))

	return ImageTexture.create_from_image(image)

func _draw_glyph(image: Image, name: String, rect: Rect2i, fg: Color) -> void:
	match name:
		"folder", "files":
			_draw_folder_glyph(image, rect, fg)
		"file", "text":
			_draw_file_glyph(image, rect, fg)
		"notes":
			_draw_notes_glyph(image, rect, fg)
		"browser", "web", "wifi", "network":
			_draw_browser_glyph(image, rect, fg)
		"terminal", "console":
			_draw_terminal_glyph(image, rect, fg)
		"settings", "system":
			_draw_settings_glyph(image, rect, fg)
		"start", "home":
			_draw_home_glyph(image, rect, fg)
		"notification":
			_draw_notification_glyph(image, rect, fg)
		"battery", "power":
			_draw_battery_glyph(image, rect, fg)
		_:
			_draw_file_glyph(image, rect, fg)

func _draw_folder_glyph(image: Image, rect: Rect2i, fg: Color) -> void:
	var tab_w: int = maxi(3, int(rect.size.x * 0.42))
	var tab_h: int = maxi(2, int(rect.size.y * 0.22))
	var tab_x: int = rect.position.x + maxi(1, int(rect.size.x * 0.10))
	var tab_y: int = rect.position.y + maxi(1, int(rect.size.y * 0.12))
	image.fill_rect(Rect2i(tab_x, tab_y, tab_w, tab_h), fg)
	var body_y: int = tab_y + tab_h
	var body_h: int = rect.position.y + rect.size.y - body_y - 1
	if body_h > 1:
		image.fill_rect(Rect2i(rect.position.x + 1, body_y, rect.size.x - 2, body_h), fg)

func _draw_file_glyph(image: Image, rect: Rect2i, fg: Color) -> void:
	var inset: int = maxi(2, int(rect.size.x * 0.18))
	var x: int = rect.position.x + inset
	var y: int = rect.position.y + inset
	var w: int = rect.size.x - inset * 2
	var h: int = rect.size.y - inset * 2
	if w < 4 or h < 4:
		return
	image.fill_rect(Rect2i(x, y, w, h), fg)
	var fold: int = maxi(2, int(mini(w, h) * 0.28))
	image.fill_rect(Rect2i(x + w - fold, y, fold, fold), Tokens.alpha(_icon_color("file"), 0.95))

func _draw_notes_glyph(image: Image, rect: Rect2i, fg: Color) -> void:
	_draw_file_glyph(image, rect, fg)
	var left: int = rect.position.x + maxi(2, int(rect.size.x * 0.24))
	var right: int = rect.position.x + rect.size.x - maxi(2, int(rect.size.x * 0.22))
	var y: int = rect.position.y + maxi(3, int(rect.size.y * 0.34))
	var step: int = maxi(2, int(rect.size.y * 0.16))
	for i in range(3):
		var yy: int = y + i * step
		image.fill_rect(Rect2i(left, yy, maxi(right - left, 2), 1), Tokens.alpha(_icon_color("notes"), 0.95))

func _draw_browser_glyph(image: Image, rect: Rect2i, fg: Color) -> void:
	var inset: int = maxi(2, int(rect.size.x * 0.20))
	var x: int = rect.position.x + inset
	var y: int = rect.position.y + inset
	var w: int = rect.size.x - inset * 2
	var h: int = rect.size.y - inset * 2
	if w < 4 or h < 4:
		return
	image.fill_rect(Rect2i(x, y, w, h), fg)
	var bar_h: int = maxi(1, int(h * 0.22))
	image.fill_rect(Rect2i(x, y, w, bar_h), Tokens.alpha(_icon_color("browser"), 0.95))

func _draw_terminal_glyph(image: Image, rect: Rect2i, fg: Color) -> void:
	var x: int = rect.position.x + maxi(2, int(rect.size.x * 0.20))
	var y: int = rect.position.y + maxi(2, int(rect.size.y * 0.26))
	var w: int = rect.size.x - maxi(4, int(rect.size.x * 0.40))
	var h: int = rect.size.y - maxi(4, int(rect.size.y * 0.52))
	if w < 3 or h < 3:
		return
	image.fill_rect(Rect2i(x, y + h / 2, w, 1), fg)
	image.fill_rect(Rect2i(x, y + h / 2 + 2, w - 1, 1), fg)
	image.fill_rect(Rect2i(x + w + 1, y + h / 2 + 2, maxi(2, int(rect.size.x * 0.12)), 1), fg)

func _draw_settings_glyph(image: Image, rect: Rect2i, fg: Color) -> void:
	var cx: int = rect.position.x + rect.size.x / 2
	var cy: int = rect.position.y + rect.size.y / 2
	var r: int = maxi(2, int(mini(rect.size.x, rect.size.y) * 0.18))
	image.fill_rect(Rect2i(cx - r, cy - 1, r * 2, 2), fg)
	image.fill_rect(Rect2i(cx - 1, cy - r, 2, r * 2), fg)
	image.fill_rect(Rect2i(cx - r / 2, cy - r / 2, maxi(r, 2), maxi(r, 2)), fg)

func _draw_home_glyph(image: Image, rect: Rect2i, fg: Color) -> void:
	var x: int = rect.position.x + maxi(2, int(rect.size.x * 0.24))
	var y: int = rect.position.y + maxi(2, int(rect.size.y * 0.32))
	var w: int = rect.size.x - maxi(4, int(rect.size.x * 0.48))
	var h: int = rect.size.y - maxi(4, int(rect.size.y * 0.44))
	if w < 3 or h < 3:
		return
	image.fill_rect(Rect2i(x, y, w, h), fg)
	image.fill_rect(Rect2i(x + w / 2 - 1, y + h / 2, 2, h / 2), Tokens.alpha(_icon_color("home"), 0.95))

func _draw_notification_glyph(image: Image, rect: Rect2i, fg: Color) -> void:
	var x: int = rect.position.x + maxi(2, int(rect.size.x * 0.28))
	var y: int = rect.position.y + maxi(2, int(rect.size.y * 0.24))
	var w: int = rect.size.x - maxi(4, int(rect.size.x * 0.56))
	var h: int = rect.size.y - maxi(4, int(rect.size.y * 0.42))
	if w < 3 or h < 4:
		return
	image.fill_rect(Rect2i(x, y, w, h), fg)
	image.fill_rect(Rect2i(x + w / 2, y + h + 1, 1, 1), fg)

func _draw_battery_glyph(image: Image, rect: Rect2i, fg: Color) -> void:
	var x: int = rect.position.x + maxi(2, int(rect.size.x * 0.20))
	var y: int = rect.position.y + maxi(2, int(rect.size.y * 0.34))
	var w: int = rect.size.x - maxi(4, int(rect.size.x * 0.35))
	var h: int = rect.size.y - maxi(4, int(rect.size.y * 0.56))
	if w < 4 or h < 3:
		return
	image.fill_rect(Rect2i(x, y, w, h), fg)
	image.fill_rect(Rect2i(x + w, y + h / 3, 1, maxi(1, h / 3)), fg)
	image.fill_rect(Rect2i(x + 1, y + 1, maxi(1, w - 2), maxi(1, h - 2)), Tokens.alpha(_icon_color("battery"), 0.95))

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
