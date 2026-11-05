extends RefCounted
## Draws every boss from shapes, at any size: the same character appears in the field,
## in its entrance and in the codex. `mood` is "idle", "hurt", "angry" or "dead".

const Bosses := preload("res://data/bosses.gd")
const INK := Color("17122b")
const SKIN_LIGHT := Color(1.0, 1.0, 1.0, 0.22)


static func draw(canvas: CanvasItem, id: String, rect: Rect2, mood: String, time: float) -> void:
	# Faces work from the rect's height, so the wide field rect and tall portraits agree.
	var h := rect.size.y
	var c := rect.get_center()
	var color := Bosses.color(id)
	match id:
		"purun":
			_purun(canvas, c, h, color, mood, time)
		"mogu":
			_mogu(canvas, c, h, color, mood, time)
		"gantetsu":
			_gantetsu(canvas, c, h, color, mood, time)
		"dokan":
			_dokan(canvas, c, h, color, mood, time)
		"lumina":
			_lumina(canvas, c, h, color, mood, time)
		"zero":
			_zero(canvas, c, h, color, mood, time)
		"mirage":
			_mirage(canvas, c, h, color, mood, time)
		"chrono":
			_chrono(canvas, c, h, color, mood, time)
		"hyoga":
			_hyoga(canvas, c, h, color, mood, time)
		"homura":
			_homura(canvas, c, h, color, mood, time)
		"tsukuyo":
			_tsukuyo(canvas, c, h, color, mood, time)
		"void":
			_void(canvas, c, h, color, mood, time)


static func _ellipse(center: Vector2, radius: Vector2, from := 0.0, to := TAU, steps := 40) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var a := lerpf(from, to, float(i) / steps)
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points


static func _fill(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	canvas.draw_colored_polygon(points, color)


static func _oval(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	var points := _ellipse(center, radius)
	points.remove_at(points.size() - 1)
	_fill(canvas, points, color)


## Two eyes that share one expression, so moods read the same on every character.
static func _eyes(canvas: CanvasItem, c: Vector2, gap: float, r: float, mood: String, time: float, iris := INK) -> void:
	for side in [-1.0, 1.0]:
		var p: Vector2 = c + Vector2(gap * side, 0.0)
		match mood:
			"dead":
				var d := r * 0.75
				canvas.draw_line(p + Vector2(-d, -d), p + Vector2(d, d), INK, r * 0.38, true)
				canvas.draw_line(p + Vector2(-d, d), p + Vector2(d, -d), INK, r * 0.38, true)
			"hurt":
				var d := r * 0.8
				canvas.draw_line(p + Vector2(-d * side, -d), p + Vector2(d * side, 0.0), INK, r * 0.38, true)
				canvas.draw_line(p + Vector2(d * side, 0.0), p + Vector2(-d * side, d), INK, r * 0.38, true)
			_:
				if fmod(time + 0.37 * gap, 3.4) < 0.11:
					canvas.draw_line(p + Vector2(-r, 0.0), p + Vector2(r, 0.0), INK, r * 0.34, true)
					continue
				canvas.draw_circle(p, r, Color.WHITE)
				var look := Vector2(sin(time * 0.9) * r * 0.22, 0.0)
				canvas.draw_circle(p + look, r * 0.58, iris)
				canvas.draw_circle(p + look + Vector2(-r * 0.2, -r * 0.24), r * 0.2, Color.WHITE)
				if mood == "angry":
					var brow := r * 1.25
					canvas.draw_line(p + Vector2(-brow * side * -1.0, -r * 0.55), p + Vector2(-brow * side, -r * 1.25), INK, r * 0.42, true)


static func _smile(canvas: CanvasItem, c: Vector2, r: float, width: float, color := INK) -> void:
	canvas.draw_polyline(_ellipse(c, Vector2(r, r * 0.7), 0.2, PI - 0.2, 14), color, width, true)


static func _frown(canvas: CanvasItem, c: Vector2, r: float, width: float, color := INK) -> void:
	canvas.draw_polyline(_ellipse(c + Vector2(0.0, r * 0.7), Vector2(r, r * 0.7), PI + 0.2, TAU - 0.2, 14), color, width, true)


## A slime that wobbles and always looks a little too pleased with itself.
static func _purun(canvas: CanvasItem, c: Vector2, h: float, color: Color, mood: String, time: float) -> void:
	var wobble := sin(time * 3.2) * 0.05
	var w := h * (0.86 + wobble)
	var tall := h * (0.46 - wobble * 0.8)
	var base := c + Vector2(0.0, h * 0.36)
	var points := _ellipse(base + Vector2(0.0, -tall * 0.1), Vector2(w, tall * 1.5), PI, TAU, 28)
	# The hem ripples smoothly, tucking in at both ends so it meets the dome cleanly.
	for i in range(24, -1, -1):
		var along := float(i) / 24.0
		var drip := h * 0.05 * (1.0 + sin(time * 2.0 + along * 11.0)) * sin(along * PI)
		points.append(base + Vector2(w * (along * 2.0 - 1.0), h * 0.02 + drip - tall * 0.1))
	_fill(canvas, points, color)
	_oval(canvas, base + Vector2(-w * 0.42, -tall * 1.1), Vector2(w * 0.22, tall * 0.2), SKIN_LIGHT)
	canvas.draw_circle(base + Vector2(w * 0.5, -tall * 1.05), h * 0.035, SKIN_LIGHT)
	var face := c + Vector2(0.0, h * 0.02)
	_eyes(canvas, face, h * 0.26, h * 0.13, mood, time)
	_oval(canvas, face + Vector2(-h * 0.46, h * 0.13), Vector2(h * 0.08, h * 0.045), Color("ff7fa8", 0.65))
	_oval(canvas, face + Vector2(h * 0.46, h * 0.13), Vector2(h * 0.08, h * 0.045), Color("ff7fa8", 0.65))
	var mouth := face + Vector2(0.0, h * 0.14)
	if mood == "idle":
		_smile(canvas, mouth, h * 0.09, h * 0.035)
	elif mood == "dead":
		_oval(canvas, mouth + Vector2(0.0, h * 0.03), Vector2(h * 0.07, h * 0.03), INK)
	else:
		_oval(canvas, mouth + Vector2(0.0, h * 0.05), Vector2(h * 0.07, h * 0.08), INK)


## All mouth: it chews constantly and never stops thinking about lunch.
static func _mogu(canvas: CanvasItem, c: Vector2, h: float, color: Color, mood: String, time: float) -> void:
	var bob := sin(time * 2.4) * h * 0.02
	var body := c + Vector2(0.0, bob)
	for side in [-1.0, 1.0]:
		var ear: Vector2 = body + Vector2(h * 0.58 * side, -h * 0.34)
		_fill(canvas, PackedVector2Array([ear + Vector2(-h * 0.11, h * 0.1), ear + Vector2(h * 0.12 * side, -h * 0.2), ear + Vector2(h * 0.11, h * 0.1)]), color.darkened(0.22))
	_oval(canvas, body, Vector2(h * 0.92, h * 0.5), color)
	_oval(canvas, body + Vector2(0.0, -h * 0.34), Vector2(h * 0.52, h * 0.09), SKIN_LIGHT)
	_eyes(canvas, body + Vector2(0.0, -h * 0.25), h * 0.3, h * 0.105, mood, time)
	var open := 0.09 + (0.5 + sin(time * 7.0) * 0.5) * 0.09
	if mood == "hurt":
		open = 0.2
	elif mood == "dead":
		open = 0.03
	var mouth := body + Vector2(0.0, h * 0.14)
	var mouth_r := Vector2(h * 0.56, h * open + h * 0.03)
	_oval(canvas, mouth, mouth_r, Color("5a1f33"))
	if open > 0.08:
		_oval(canvas, mouth + Vector2(0.0, mouth_r.y * 0.48), Vector2(h * 0.25, mouth_r.y * 0.42), Color("ff7f9d"))
		for i in 5:
			var x := (float(i) - 2.0) * h * 0.18
			var y := mouth.y - mouth_r.y * sqrt(maxf(1.0 - pow(x / mouth_r.x, 2.0), 0.0))
			var tooth := Vector2(c.x + x, y)
			_fill(canvas, PackedVector2Array([tooth + Vector2(-h * 0.055, -1.0), tooth + Vector2(h * 0.055, -1.0), tooth + Vector2(0.0, h * 0.09)]), Color.WHITE)


## A gruff old turtle captain who hides behind his shell and his men.
static func _gantetsu(canvas: CanvasItem, c: Vector2, h: float, color: Color, mood: String, time: float) -> void:
	var base := c + Vector2(0.0, h * 0.38)
	var shell := color.darkened(0.3)
	var dome := _ellipse(base, Vector2(h * 1.02, h * 0.82), PI, TAU, 30)
	_fill(canvas, dome, shell)
	for i in 5:
		var plate: Vector2 = base + Vector2((float(i) - 2.0) * h * 0.4, -h * (0.34 - absf(float(i) - 2.0) * 0.07))
		var plate_points := PackedVector2Array()
		for corner in 6:
			plate_points.append(plate + Vector2.from_angle(corner * TAU / 6.0) * h * 0.14)
		_fill(canvas, plate_points, color.darkened(0.12))
	var peek := 0.0 if mood == "idle" else h * 0.03
	var head := c + Vector2(0.0, h * 0.08 + sin(time * 1.3) * h * 0.012 + peek)
	_oval(canvas, head, Vector2(h * 0.46, h * 0.36), color)
	var helmet := _ellipse(head + Vector2(0.0, -h * 0.05), Vector2(h * 0.5, h * 0.34), PI, TAU, 22)
	_fill(canvas, helmet, Color("8d97ad"))
	canvas.draw_rect(Rect2(head + Vector2(-h * 0.54, -h * 0.09), Vector2(h * 1.08, h * 0.07)), Color("646d84"))
	canvas.draw_circle(head + Vector2(0.0, -h * 0.26), h * 0.045, Color("ffd166"))
	_eyes(canvas, head + Vector2(0.0, h * 0.06), h * 0.2, h * 0.085, "angry" if mood == "idle" else mood, time)
	if mood == "dead":
		_frown(canvas, head + Vector2(0.0, h * 0.2), h * 0.1, h * 0.03)
	else:
		_frown(canvas, head + Vector2(0.0, h * 0.2), h * 0.09, h * 0.035)


## A bomb with a big white moustache who treats explosions as fireworks.
static func _dokan(canvas: CanvasItem, c: Vector2, h: float, color: Color, mood: String, time: float) -> void:
	var r := h * 0.47
	var body := c + Vector2(0.0, h * 0.05 + sin(time * 2.0) * h * 0.015)
	canvas.draw_rect(Rect2(body + Vector2(-h * 0.14, -r - h * 0.08), Vector2(h * 0.28, h * 0.12)), color.darkened(0.45))
	var fuse_end := body + Vector2(h * 0.26, -r - h * 0.24)
	canvas.draw_polyline(PackedVector2Array([body + Vector2(0.0, -r - h * 0.08), body + Vector2(h * 0.12, -r - h * 0.2), fuse_end]), Color("c9b48a"), h * 0.035, true)
	if mood != "dead":
		var spark := 0.7 + sin(time * 22.0) * 0.3
		canvas.draw_circle(fuse_end, h * 0.07 * spark, Color("ffb347"))
		canvas.draw_circle(fuse_end, h * 0.035 * spark, Color.WHITE)
	canvas.draw_circle(body, r, color)
	_oval(canvas, body + Vector2(-r * 0.36, -r * 0.5), Vector2(r * 0.34, r * 0.2), SKIN_LIGHT)
	var white := Color("f6f2e8")
	var face := body + Vector2(0.0, -h * 0.07)
	_eyes(canvas, face, h * 0.17, h * 0.085, mood, time)
	for side in [-1.0, 1.0]:
		var lift := h * 0.05 if mood == "angry" else 0.0
		_oval(canvas, face + Vector2(h * 0.2 * side, -h * 0.13 + lift), Vector2(h * 0.14, h * 0.038), white)
		var tip := face + Vector2(h * 0.36 * side, h * 0.15 - (0.5 + sin(time * 3.0) * 0.5) * h * 0.02)
		_fill(canvas, PackedVector2Array([
			face + Vector2(0.0, h * 0.13),
			face + Vector2(h * 0.14 * side, h * 0.09),
			tip,
			face + Vector2(h * 0.14 * side, h * 0.22),
			face + Vector2(0.0, h * 0.21),
		]), white)
	canvas.draw_circle(face + Vector2(0.0, h * 0.11), h * 0.05, Color("ff9e8a"))


## A queen who has decided she will not be defeated today, or any day.
static func _lumina(canvas: CanvasItem, c: Vector2, h: float, color: Color, mood: String, time: float) -> void:
	var sway := sin(time * 1.6) * h * 0.02
	var head := c + Vector2(0.0, h * 0.08)
	var hair := color.darkened(0.25)
	for side in [-1.0, 1.0]:
		var points := PackedVector2Array([
			head + Vector2(h * 0.2 * side, -h * 0.34),
			head + Vector2(h * 0.62 * side, -h * 0.26),
			head + Vector2((h * 0.86 + sway) * side, h * 0.12),
			head + Vector2((h * 0.72 + sway) * side, h * 0.42),
			head + Vector2(h * 0.34 * side, h * 0.32),
		])
		if side > 0.0:
			points.reverse()
		_fill(canvas, points, hair)
	_oval(canvas, head, Vector2(h * 0.43, h * 0.4), Color("ffe3ee"))
	var fringe := _ellipse(head + Vector2(0.0, -h * 0.09), Vector2(h * 0.45, h * 0.3), PI, TAU, 20)
	_fill(canvas, fringe, color)
	var band := head.y - h * 0.34
	var crown := PackedVector2Array([
		Vector2(head.x - h * 0.3, band + h * 0.03),
		Vector2(head.x - h * 0.37, band - h * 0.2),
		Vector2(head.x - h * 0.14, band - h * 0.05),
		Vector2(head.x, band - h * 0.27),
		Vector2(head.x + h * 0.14, band - h * 0.05),
		Vector2(head.x + h * 0.37, band - h * 0.2),
		Vector2(head.x + h * 0.3, band + h * 0.03),
	])
	_fill(canvas, crown, Color("ffd166"))
	canvas.draw_circle(Vector2(head.x, band - h * 0.08), h * 0.04, Color("ff5c8a"))
	var eyes := head + Vector2(0.0, h * 0.06)
	_eyes(canvas, eyes, h * 0.18, h * 0.088, mood, time, Color("6a2fb5"))
	if mood == "idle" or mood == "angry":
		for side in [-1.0, 1.0]:
			var corner: Vector2 = eyes + Vector2(h * 0.25 * side, -h * 0.05)
			canvas.draw_line(corner, corner + Vector2(h * 0.07 * side, -h * 0.05), INK, h * 0.02, true)
	var lips := head + Vector2(0.0, h * 0.25)
	if mood == "idle":
		_smile(canvas, lips, h * 0.055, h * 0.025, Color("d6336c"))
	else:
		_oval(canvas, lips, Vector2(h * 0.04, h * 0.025), Color("d6336c"))


## A machine with one red eye that is always, always looking for you.
static func _zero(canvas: CanvasItem, c: Vector2, h: float, color: Color, mood: String, time: float) -> void:
	var head := Rect2(c + Vector2(-h * 0.68, -h * 0.34), Vector2(h * 1.36, h * 0.74))
	for side in [-1.0, 1.0]:
		canvas.draw_rect(Rect2(c + Vector2(h * 0.68 * side - h * 0.08, -h * 0.14), Vector2(h * 0.16, h * 0.34)), color.darkened(0.42))
	canvas.draw_line(c + Vector2(-h * 0.26, -h * 0.34), c + Vector2(-h * 0.36, -h * 0.5), color.darkened(0.3), h * 0.03, true)
	var blink := 0.5 + sin(time * 5.0) * 0.5
	canvas.draw_circle(c + Vector2(-h * 0.36, -h * 0.5), h * 0.045, Color("ff5470", 0.5 + blink * 0.5))
	_rounded(canvas, head, h * 0.14, color)
	_rounded(canvas, Rect2(head.position + Vector2(h * 0.08, h * 0.05), Vector2(head.size.x - h * 0.16, h * 0.07)), h * 0.03, SKIN_LIGHT)
	var visor := Rect2(c + Vector2(-h * 0.54, -h * 0.17), Vector2(h * 1.08, h * 0.25))
	_rounded(canvas, visor, h * 0.1, Color("141628"))
	var eye_y := visor.get_center().y
	if mood == "dead":
		canvas.draw_line(Vector2(c.x - h * 0.4, eye_y), Vector2(c.x + h * 0.4, eye_y), Color("4a4e68"), h * 0.03)
	else:
		var scan := sin(time * 1.7) * h * 0.34
		var red := Color("ff3355") if mood != "hurt" else Color.WHITE
		if mood == "angry":
			canvas.draw_rect(Rect2(c.x - h * 0.5, eye_y - h * 0.045, h, h * 0.09), Color(red, 0.75))
		canvas.draw_circle(Vector2(c.x + scan, eye_y), h * 0.1, Color(red, 0.35))
		canvas.draw_circle(Vector2(c.x + scan, eye_y), h * 0.06, red)
	for i in 5:
		var x := c.x + (float(i) - 2.0) * h * 0.15
		canvas.draw_line(Vector2(x, c.y + h * 0.17), Vector2(x, c.y + h * 0.31), Color("141628"), h * 0.035)
	for corner in [Vector2(-0.58, -0.25), Vector2(0.58, -0.25), Vector2(-0.58, 0.32), Vector2(0.58, 0.32)]:
		canvas.draw_circle(c + corner * h, h * 0.02, Color("141628"))


static func _rounded(canvas: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) / 2.0)
	var corners := [
		[rect.position + Vector2(rect.size.x - r, r), -PI / 2.0],
		[rect.position + rect.size - Vector2(r, r), 0.0],
		[rect.position + Vector2(r, rect.size.y - r), PI / 2.0],
		[rect.position + Vector2(r, r), PI],
	]
	for corner in corners:
		for i in 7:
			var a: float = float(corner[1]) + i * (PI / 2.0) / 6.0
			points.append((corner[0] as Vector2) + Vector2.from_angle(a) * r)
	_fill(canvas, points, color)


static func _mouth(canvas: CanvasItem, c: Vector2, h: float, mood: String) -> void:
	match mood:
		"idle":
			_smile(canvas, c, h * 0.09, h * 0.035)
		"angry":
			_frown(canvas, c, h * 0.09, h * 0.035)
		_:
			_oval(canvas, c + Vector2(0.0, h * 0.03), Vector2(h * 0.06, h * 0.07), INK)


## A dancer who is never quite where she seems to be: fading copies sway at either side.
static func _mirage(canvas: CanvasItem, c: Vector2, h: float, color: Color, mood: String, time: float) -> void:
	var sway := sin(time * 2.2) * h * 0.05
	for side in [-1.0, 1.0]:
		var ghost: Vector2 = c + Vector2((h * 0.72 + sway) * side, h * 0.02)
		_oval(canvas, ghost, Vector2(h * 0.34, h * 0.42), Color(color, 0.22))
	var body := c + Vector2(-sway * 0.4, 0.0)
	_oval(canvas, body + Vector2(0.0, h * 0.14), Vector2(h * 0.62, h * 0.32), color.darkened(0.25))
	_oval(canvas, body, Vector2(h * 0.46, h * 0.44), color)
	_oval(canvas, body + Vector2(-h * 0.15, -h * 0.27), Vector2(h * 0.16, h * 0.07), SKIN_LIGHT)
	var jewel := body + Vector2(0.0, -h * 0.34)
	_fill(canvas, PackedVector2Array([jewel + Vector2(0.0, -h * 0.08), jewel + Vector2(h * 0.06, 0.0), jewel + Vector2(0.0, h * 0.08), jewel + Vector2(-h * 0.06, 0.0)]), Color("fff1a8"))
	_eyes(canvas, body + Vector2(0.0, -h * 0.05), h * 0.2, h * 0.1, mood, time)
	_mouth(canvas, body + Vector2(0.0, h * 0.16), h, mood)


## A pocket watch that has outlived its owner. Its hands never stop, even when struck.
static func _chrono(canvas: CanvasItem, c: Vector2, h: float, color: Color, mood: String, time: float) -> void:
	var r := h * 0.47
	canvas.draw_circle(c + Vector2(0.0, -r - h * 0.02), h * 0.06, color.darkened(0.2))
	canvas.draw_circle(c, r, color.darkened(0.25))
	canvas.draw_circle(c, r * 0.87, Color("fff6dc"))
	for i in 12:
		var dir := Vector2.from_angle(i * TAU / 12.0)
		canvas.draw_line(c + dir * r * 0.72, c + dir * r * 0.82, INK, h * 0.018, true)
	var speed := 5.0 if mood == "angry" else 1.0
	canvas.draw_line(c, c + Vector2.from_angle(time * speed - PI / 2.0) * r * 0.74, Color(color.darkened(0.45), 0.55), h * 0.022, true)
	canvas.draw_line(c, c + Vector2.from_angle(time * speed / 12.0 + 2.0) * r * 0.5, Color(color.darkened(0.45), 0.55), h * 0.034, true)
	_eyes(canvas, c + Vector2(0.0, -h * 0.05), h * 0.16, h * 0.085, mood, time)
	_mouth(canvas, c + Vector2(0.0, h * 0.17), h, mood)


## A wolf who froze along with what it stopped: a crown of ice around a stern face.
static func _hyoga(canvas: CanvasItem, c: Vector2, h: float, color: Color, mood: String, time: float) -> void:
	var glint := 0.5 + sin(time * 2.6) * 0.5
	for i in 5:
		var x := (float(i) - 2.0) * h * 0.3
		var tall := h * (0.62 - absf(float(i) - 2.0) * 0.1)
		_fill(canvas, PackedVector2Array([c + Vector2(x - h * 0.16, -h * 0.1), c + Vector2(x, -tall), c + Vector2(x + h * 0.16, -h * 0.1)]), color.lightened(0.15 + glint * 0.15))
	for side in [-1.0, 1.0]:
		var ear: Vector2 = c + Vector2(h * 0.46 * side, -h * 0.1)
		_fill(canvas, PackedVector2Array([ear + Vector2(-h * 0.13, h * 0.08), ear + Vector2(h * 0.1 * side, -h * 0.22), ear + Vector2(h * 0.13, h * 0.08)]), color.darkened(0.3))
	_oval(canvas, c + Vector2(0.0, h * 0.1), Vector2(h * 0.56, h * 0.36), color)
	_oval(canvas, c + Vector2(0.0, h * 0.26), Vector2(h * 0.26, h * 0.16), Color.WHITE)
	canvas.draw_circle(c + Vector2(0.0, h * 0.18), h * 0.05, INK)
	_eyes(canvas, c + Vector2(0.0, h * 0.0), h * 0.23, h * 0.09, mood, time, Color("2c6ea3"))
	_mouth(canvas, c + Vector2(0.0, h * 0.27), h, mood)


## A phoenix forever burning out and coming back: all wings, flame and stubborn hope.
static func _homura(canvas: CanvasItem, c: Vector2, h: float, color: Color, mood: String, time: float) -> void:
	var flap := sin(time * 5.0) * h * 0.1
	for side in [-1.0, 1.0]:
		var root: Vector2 = c + Vector2(h * 0.3 * side, h * 0.02)
		_fill(canvas, PackedVector2Array([root + Vector2(0.0, -h * 0.14), root + Vector2(h * 0.66 * side, -h * 0.32 + flap), root + Vector2(h * 0.48 * side, h * 0.02 + flap), root + Vector2(h * 0.56 * side, h * 0.14 + flap), root + Vector2(0.0, h * 0.24)]), color.darkened(0.15))
	for i in 3:
		var x := (float(i) - 1.0) * h * 0.2
		var lick := sin(time * 9.0 + i) * h * 0.04
		_fill(canvas, PackedVector2Array([c + Vector2(x - h * 0.13, -h * 0.28), c + Vector2(x + lick, -h * (0.62 - absf(float(i) - 1.0) * 0.14)), c + Vector2(x + h * 0.13, -h * 0.28)]), Color("ffd166"))
	_oval(canvas, c + Vector2(0.0, h * 0.03), Vector2(h * 0.42, h * 0.4), color)
	_oval(canvas, c + Vector2(0.0, h * 0.2), Vector2(h * 0.24, h * 0.18), Color("ffd166"))
	_eyes(canvas, c + Vector2(0.0, -h * 0.07), h * 0.17, h * 0.09, mood, time)
	_fill(canvas, PackedVector2Array([c + Vector2(-h * 0.08, h * 0.05), c + Vector2(h * 0.08, h * 0.05), c + Vector2(0.0, h * 0.2)]), Color("ffb020"))


## A princess who calls herself the moon. Her shadow slides across her face with the hours.
static func _tsukuyo(canvas: CanvasItem, c: Vector2, h: float, color: Color, mood: String, time: float) -> void:
	var r := h * 0.47
	for i in 5:
		var angle := i * TAU / 5.0 + time * 0.3
		canvas.draw_circle(c + Vector2.from_angle(angle) * Vector2(h * 0.86, h * 0.42), h * 0.022, Color("fff1a8"))
	canvas.draw_circle(c, r, color)
	var shade := c + Vector2(r * (0.95 + sin(time * 0.7) * 0.12), -r * 0.12)
	var disc := _ellipse(c, Vector2(r, r))
	disc.remove_at(disc.size() - 1)
	var cover := _ellipse(shade, Vector2(r * 0.62, r * 0.84))
	cover.remove_at(cover.size() - 1)
	# Only the part inside the moon is shadow, or it would read as a second object.
	for piece in Geometry2D.intersect_polygons(disc, cover):
		_fill(canvas, piece, color.darkened(0.45))
	_oval(canvas, c + Vector2(-r * 0.42, -r * 0.5), Vector2(r * 0.22, r * 0.12), SKIN_LIGHT)
	var face := c + Vector2(-h * 0.06, -h * 0.03)
	_eyes(canvas, face, h * 0.16, h * 0.085, mood, time)
	_mouth(canvas, face + Vector2(0.0, h * 0.18), h, mood)


## The hole in the sky that everything falls from. One eye, and it has seen you already.
static func _void(canvas: CanvasItem, c: Vector2, h: float, color: Color, mood: String, time: float) -> void:
	for i in 3:
		var tilt := time * (0.7 + i * 0.25) + i * 2.1
		var ring := _ellipse(Vector2.ZERO, Vector2(h * (0.86 - i * 0.12), h * (0.24 + i * 0.07)), 0.0, TAU, 44)
		var turned := PackedVector2Array()
		for p in ring:
			turned.append(c + p.rotated(sin(tilt) * 0.5))
		canvas.draw_polyline(turned, Color(color.lightened(i * 0.2), 0.75 - i * 0.15), h * 0.03, true)
	canvas.draw_circle(c, h * 0.42, Color("07050f"))
	canvas.draw_arc(c, h * 0.42, 0.0, TAU, 48, color, h * 0.035, true)
	match mood:
		"dead":
			canvas.draw_line(c + Vector2(-h * 0.2, 0.0), c + Vector2(h * 0.2, 0.0), color, h * 0.05, true)
		"hurt":
			_oval(canvas, c, Vector2(h * 0.24, h * 0.05), Color.WHITE)
			canvas.draw_circle(c, h * 0.045, Color("ff4d6d"))
		_:
			_oval(canvas, c, Vector2(h * 0.26, h * 0.17), Color.WHITE)
			var look := Vector2(sin(time * 0.8) * h * 0.07, 0.0)
			canvas.draw_circle(c + look, h * 0.11, Color("ff4d6d") if mood == "angry" else color)
			canvas.draw_circle(c + look, h * 0.05, Color("07050f"))
