class_name IconAtlas
extends RefCounted

const Tokens := preload("res://scripts/os/design_tokens.gd")

var _cache: Dictionary = {}

func get_icon(name: String, size: int = 20) -> Texture2D:
	var key := "%s_%d" % [name, size]
	if _cache.has(key):
		return _cache[key]
	var tex := _draw_icon(name, size)
	_cache[key] = tex
	return tex

func _draw_icon(name: String, size: int) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Headless-safe: only draw in non-headless; otherwise return blank
	if DisplayServer.get_name() == "headless":
		return ImageTexture.create_from_image(image)
	match name:
		"files", "folder":
			_draw_folder(image, size)
		"file":
			_draw_file(image, size)
		"notes":
			_draw_notes(image, size)
		"text":
			_draw_text(image, size)
		"browser", "web":
			_draw_browser(image, size)
		"console", "terminal":
			_draw_terminal(image, size)
		"system", "settings":
			_draw_settings(image, size)
		"user", "account":
			_draw_user(image, size)
		"start":
			_draw_start(image, size)
		"notification":
			_draw_notification(image, size)
		"wifi", "network":
			_draw_wifi(image, size)
		"volume", "audio", "sound":
			_draw_volume(image, size)
		"bluetooth":
			_draw_bluetooth(image, size)
		"battery", "power":
			_draw_battery(image, size)
		"session":
			_draw_session(image, size)
		"search":
			_draw_search(image, size)
		"close":
			_draw_close(image, size)
		"minimize":
			_draw_minimize(image, size)
		"maximize":
			_draw_maximize(image, size)
		"lock":
			_draw_lock(image, size)
		"home":
			_draw_home(image, size)
		"trash":
			_draw_trash(image, size)
		_:
			_draw_placeholder(image, size)
	return ImageTexture.create_from_image(image)

# ── Drawing Helpers ──
func _rounded_rect(image: Image, rect: Rect2i, color: Color, radius: int) -> void:
	var points := PackedVector2Array()
	var cx := rect.position.x + rect.size.x / 2
	var cy := rect.position.y + rect.size.y / 2
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var dx := absf(x - cx) - (rect.size.x / 2 - radius)
			var dy := absf(y - cy) - (rect.size.y / 2 - radius)
			if maxf(dx, 0.0) * maxf(dx, 0.0) + maxf(dy, 0.0) * maxf(dy, 0.0) <= radius * radius:
				image.set_pixel(x, y, color)

func _draw_folder(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.alpha(Color("c7a45b"), 1.0)
	var tab := Rect2i(int(s * 0.12), int(s * 0.18), int(s * 0.35), int(s * 0.15))
	var body := Rect2i(int(s * 0.12), int(s * 0.30), int(s * 0.76), int(s * 0.52))
	_rounded_rect(image, tab, c, 2)
	_rounded_rect(image, body, c, 3)
	# Highlight
	var hl := Rect2i(int(s * 0.14), int(s * 0.32), int(s * 0.72), int(s * 0.04))
	image.fill_rect(hl, Tokens.alpha(Color("edd7a0"), 0.5))

func _draw_file(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.alpha(Color("d7dee9"), 1.0)
	var body := Rect2i(int(s * 0.18), int(s * 0.12), int(s * 0.64), int(s * 0.76))
	_rounded_rect(image, body, c, 3)
	# Folded corner
	var fold := Rect2i(int(s * 0.58), int(s * 0.12), int(s * 0.24), int(s * 0.22))
	image.fill_rect(fold, Tokens.alpha(Color("edf2f8"), 1.0))
	# Lines
	for i in range(3):
		var line := Rect2i(int(s * 0.28), int(s * 0.42 + i * s * 0.14), int(s * 0.44), int(s * 0.04))
		image.fill_rect(line, Tokens.alpha(Color("a2afc2"), 1.0))

func _draw_notes(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.alpha(Color("e8d5a3"), 1.0)
	var body := Rect2i(int(s * 0.15), int(s * 0.12), int(s * 0.70), int(s * 0.76))
	_rounded_rect(image, body, c, 3)
	# Lines
	for i in range(4):
		var line := Rect2i(int(s * 0.22), int(s * 0.28 + i * s * 0.14), int(s * 0.56), int(s * 0.03))
		image.fill_rect(line, Tokens.alpha(Color("b8a87a"), 0.7))

func _draw_text(image: Image, size: int) -> void:
	_draw_file(image, size)

func _draw_browser(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.ACCENT
	# Globe circle
	var cx := int(s * 0.5)
	var cy := int(s * 0.5)
	var r := int(s * 0.36)
	for y in range(size):
		for x in range(size):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r * r:
				image.set_pixel(x, y, c)
	# Cross lines
	image.fill_rect(Rect2i(int(s * 0.15), int(s * 0.47), int(s * 0.70), int(s * 0.06)), Tokens.BG)
	image.fill_rect(Rect2i(int(s * 0.47), int(s * 0.15), int(s * 0.06), int(s * 0.70)), Tokens.BG)

func _draw_terminal(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.alpha(Color("7ab88a"), 1.0)
	# Prompt symbol: >_
	image.fill_rect(Rect2i(int(s * 0.20), int(s * 0.30), int(s * 0.18), int(s * 0.06)), c)
	image.fill_rect(Rect2i(int(s * 0.20), int(s * 0.30), int(s * 0.06), int(s * 0.18)), c)
	image.fill_rect(Rect2i(int(s * 0.32), int(s * 0.58), int(s * 0.24), int(s * 0.06)), c)

func _draw_settings(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.TEXT_MUTED
	var cx := int(s * 0.5)
	var cy := int(s * 0.5)
	# Gear teeth approximated with small rects
	for angle in range(0, 360, 45):
		var rad := deg_to_rad(angle)
		var tx := int(cx + cos(rad) * s * 0.30)
		var ty := int(cy + sin(rad) * s * 0.30)
		image.fill_rect(Rect2i(tx - 2, ty - 2, 5, 5), c)
	# Center circle
	for y in range(size):
		for x in range(size):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= int(s * 0.12) * int(s * 0.12):
				image.set_pixel(x, y, c)

func _draw_user(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.ACCENT
	var cx := int(s * 0.5)
	# Head
	for y in range(size):
		for x in range(size):
			var dx := x - cx
			var dy := y - int(s * 0.38)
			if dx * dx + dy * dy <= int(s * 0.14) * int(s * 0.14):
				image.set_pixel(x, y, c)
	# Shoulders
	var body := Rect2i(int(s * 0.18), int(s * 0.52), int(s * 0.64), int(s * 0.36))
	_rounded_rect(image, body, c, int(s * 0.18))

func _draw_start(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.ACCENT
	# 4-square grid
	var sq := int(s * 0.18)
	var gap := int(s * 0.06)
	for row in range(2):
		for col in range(2):
			var rx := int(s * 0.5) - sq - gap // 2 + col * (sq + gap)
			var ry := int(s * 0.5) - sq - gap // 2 + row * (sq + gap)
			image.fill_rect(Rect2i(rx, ry, sq, sq), c)

func _draw_notification(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.TEXT_MUTED
	# Bell body
	var body := Rect2i(int(s * 0.30), int(s * 0.22), int(s * 0.40), int(s * 0.52))
	_rounded_rect(image, body, c, 4)
	# Top knob
	var knob := Rect2i(int(s * 0.42), int(s * 0.12), int(s * 0.16), int(s * 0.14))
	_rounded_rect(image, knob, c, 3)
	# Bottom clapper
	var clap := Rect2i(int(s * 0.38), int(s * 0.70), int(s * 0.24), int(s * 0.12))
	_rounded_rect(image, clap, c, 2)

func _draw_wifi(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.TEXT_MUTED
	# 3 ascending arcs
	for i in range(3):
		var r := int(s * (0.12 + i * 0.10))
		var y := int(s * 0.72)
		for x in range(size):
			var dx := x - int(s * 0.5)
			var dy := y - int(s * 0.72)
			var dist := absf(sqrt(dx * dx + dy * dy) - r)
			if dist < 1.5 and dy < 0:
				image.set_pixel(x, y, c)
	# Dot at bottom
	var dot := Rect2i(int(s * 0.44), int(s * 0.74), int(s * 0.12), int(s * 0.12))
	_rounded_rect(image, dot, c, 2)

func _draw_volume(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.TEXT_MUTED
	# Speaker cone
	var body := Rect2i(int(s * 0.22), int(s * 0.32), int(s * 0.28), int(s * 0.36))
	image.fill_rect(body, c)
	# Triangle flare
	for i in range(int(s * 0.18)):
		var y1 := int(s * 0.28 + i)
		var y2 := int(s * 0.72 - i)
		image.set_pixel(int(s * 0.50) + i, y1, c)
		image.set_pixel(int(s * 0.50) + i, y2, c)
	# Sound waves
	for i in range(2):
		var arc_r := int(s * (0.22 + i * 0.08))
		var cx := int(s * 0.62)
		var cy := int(s * 0.50)
		for ang in range(-30, 31, 2):
			var rad := deg_to_rad(ang)
			var px := int(cx + cos(rad) * arc_r)
			var py := int(cy + sin(rad) * arc_r)
			if px >= 0 and px < size and py >= 0 and py < size:
				image.set_pixel(px, py, c)

func _draw_bluetooth(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.TEXT_MUTED
	var cx := int(s * 0.5)
	# Vertical line
	image.fill_rect(Rect2i(cx - 1, int(s * 0.18), 3, int(s * 0.64)), c)
	# Two diagonal triangles
	for i in range(int(s * 0.22)):
		image.set_pixel(cx - i, int(s * 0.22) + i, c)
		image.set_pixel(cx + i, int(s * 0.22) + i, c)
		image.set_pixel(cx - i, int(s * 0.62) - i, c)
		image.set_pixel(cx + i, int(s * 0.62) - i, c)

func _draw_battery(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.TEXT_MUTED
	var body := Rect2i(int(s * 0.20), int(s * 0.28), int(s * 0.56), int(s * 0.44))
	_rounded_rect(image, body, Color.TRANSPARENT, 3)
	# Border
	image.fill_rect(Rect2i(int(s * 0.20), int(s * 0.28), int(s * 0.56), 2), c)
	image.fill_rect(Rect2i(int(s * 0.20), int(s * 0.70), int(s * 0.56), 2), c)
	image.fill_rect(Rect2i(int(s * 0.20), int(s * 0.28), 2, int(s * 0.44)), c)
	image.fill_rect(Rect2i(int(s * 0.74), int(s * 0.28), 2, int(s * 0.44)), c)
	# Cap
	image.fill_rect(Rect2i(int(s * 0.78), int(s * 0.38), int(s * 0.08), int(s * 0.24)), c)
	# Fill level (75%)
	image.fill_rect(Rect2i(int(s * 0.24), int(s * 0.32), int(s * 0.36), int(s * 0.36)), Tokens.SUCCESS)

func _draw_session(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.TEXT_MUTED
	# Power symbol
	var cx := int(s * 0.5)
	var cy := int(s * 0.5)
	var r := int(s * 0.28)
	for y in range(size):
		for x in range(size):
			var dx := x - cx
			var dy := y - cy
			var dist := sqrt(dx * dx + dy * dy)
			if absf(dist - r) < 1.5 and dy < r * 0.6:
				image.set_pixel(x, y, c)
	# Vertical line
	image.fill_rect(Rect2i(cx - 1, int(s * 0.22), 3, int(s * 0.32)), c)

func _draw_search(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.TEXT_MUTED
	var cx := int(s * 0.42)
	var cy := int(s * 0.42)
	var r := int(s * 0.22)
	for y in range(size):
		for x in range(size):
			var dx := x - cx
			var dy := y - cy
			var dist := sqrt(dx * dx + dy * dy)
			if absf(dist - r) < 1.5:
				image.set_pixel(x, y, c)
	# Handle
	for i in range(int(s * 0.18)):
		image.set_pixel(int(s * 0.58) + i, int(s * 0.58) + i, c)

func _draw_close(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.TEXT_MUTED
	var t := int(s * 0.30)
	for i in range(int(s * 0.22)):
		image.set_pixel(t + i, t + i, c)
		image.set_pixel(t + i, int(s * 0.70) - i, c)

func _draw_minimize(image: Image, size: int) -> void:
	var s := float(size)
	image.fill_rect(Rect2i(int(s * 0.28), int(s * 0.46), int(s * 0.44), int(s * 0.08)), Tokens.TEXT_MUTED)

func _draw_maximize(image: Image, size: int) -> void:
	var s := float(size)
	var t := int(s * 0.24)
	image.fill_rect(Rect2i(t, t, int(s * 0.52), int(s * 0.52)), Color.TRANSPARENT)
	image.fill_rect(Rect2i(t, t, int(s * 0.52), 2), Tokens.TEXT_MUTED)
	image.fill_rect(Rect2i(t, t, 2, int(s * 0.52)), Tokens.TEXT_MUTED)
	image.fill_rect(Rect2i(t, t + int(s * 0.50), int(s * 0.52), 2), Tokens.TEXT_MUTED)
	image.fill_rect(Rect2i(t + int(s * 0.50), t, 2, int(s * 0.52)), Tokens.TEXT_MUTED)

func _draw_lock(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.TEXT_MUTED
	var body := Rect2i(int(s * 0.22), int(s * 0.38), int(s * 0.56), int(s * 0.42))
	_rounded_rect(image, body, c, 3)
	# Arch
	for ang in range(180, 361, 2):
		var rad := deg_to_rad(ang)
		var px := int(s * 0.50) + int(cos(rad) * s * 0.18)
		var py := int(s * 0.38) + int(sin(rad) * s * 0.18)
		if px >= 0 and px < size and py >= 0 and py < size:
			image.set_pixel(px, py, c)
	# Keyhole
	image.fill_rect(Rect2i(int(s * 0.46), int(s * 0.50), int(s * 0.08), int(s * 0.16)), Tokens.BG)

func _draw_home(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.TEXT_MUTED
	var cx := int(s * 0.5)
	# Roof
	for i in range(int(s * 0.24)):
		image.set_pixel(cx - i, int(s * 0.28) + i, c)
		image.set_pixel(cx + i, int(s * 0.28) + i, c)
	# Body
	image.fill_rect(Rect2i(int(s * 0.22), int(s * 0.52), int(s * 0.56), int(s * 0.36)), c)

func _draw_trash(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.TEXT_MUTED
	var body := Rect2i(int(s * 0.24), int(s * 0.32), int(s * 0.52), int(s * 0.54))
	_rounded_rect(image, body, c, 3)
	# Lid
	image.fill_rect(Rect2i(int(s * 0.20), int(s * 0.26), int(s * 0.60), int(s * 0.08)), c)

func _draw_placeholder(image: Image, size: int) -> void:
	var s := float(size)
	var c := Tokens.TEXT_MUTED
	var cx := int(s * 0.5)
	var cy := int(s * 0.5)
	var r := int(s * 0.30)
	for y in range(size):
		for x in range(size):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r * r:
				image.set_pixel(x, y, c)
