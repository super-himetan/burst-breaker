extends "res://game_audio.gd"
## Drawing the playfield: blocks, bosses, furniture, balls and the launcher.


func _draw() -> void:
	canvas = self
	if screen != Menus.Screen.GAME:
		return
	var field := Rect2(GameSim.FIELD_X - 8.0, GameSim.FIELD_Y - 8.0, GameSim.FIELD_W + 16.0, GameSim.LAUNCH_Y - GameSim.FIELD_Y + 42.0)
	panel(field, Color(0.04, 0.03, 0.1, 0.42), 26.0, UI.LINE, 2)
	_draw_danger_line()
	_draw_laser_warning()
	_draw_obstacles()
	_draw_field_force()
	_draw_blocks()
	_draw_chains()
	_draw_fog()
	_draw_boss_down()
	_draw_boss_crack()
	_draw_balls()
	_draw_launcher()
	if (aiming or hovering) and sim.state == GameSim.State.AIM and not paused:
		_draw_aim()

## Zero's marked columns glow in warning stripes until it fires.
func _draw_laser_warning() -> void:
	if sim.boss_id() != "zero" or sim.state != GameSim.State.AIM:
		return
	var boss: Dictionary = sim.boss_block
	var rect := sim.block_rect(boss)
	var pulse := 0.5 + sin(time * 9.0) * 0.5
	for col: int in boss["aim_cols"]:
		var x := GameSim.FIELD_X + col * GameSim.CELL_W
		var top := rect.end.y
		var bottom := GameSim.FIELD_Y + sim.death_row * GameSim.CELL_H
		draw_rect(Rect2(x + 4.0, top, GameSim.CELL_W - 8.0, bottom - top), Color(UI.DANGER, 0.08 + pulse * 0.1))
		var y := top + fmod(time * 90.0, 34.0)
		while y < bottom:
			draw_line(Vector2(x + 8.0, y), Vector2(x + GameSim.CELL_W - 8.0, y + 10.0), Color(UI.DANGER, 0.35), 3.0)
			y += 34.0

## The beaten boss hangs in the air for a moment, then falls away spinning.
func _draw_boss_down() -> void:
	if boss_down <= 0.0 or boss_down_id == "":
		return
	var k := 1.0 - boss_down / BOSS_DOWN_HOLD
	var fall := maxf(k - 0.2, 0.0)
	var pos := boss_down_pos + Vector2(0.0, fall * fall * 900.0)
	var size := Vector2(264.0, 114.0)
	draw_set_transform(pos, fall * 2.2, Vector2.ONE * (1.0 + k * 0.25))
	BossArt.draw(self, boss_down_id, Rect2(-size / 2.0, size), "dead", time)
	draw_set_transform(Vector2.ZERO)

## The screen itself cracks around the killing blow.
func _draw_boss_crack() -> void:
	if boss_crack <= 0.0:
		return
	var k := boss_crack / BOSS_DOWN_HOLD
	var color := Color(1.0, 1.0, 1.0, k * 0.85)
	for i in 9:
		var dir := Vector2.from_angle(i * TAU / 9.0 + float(i * i) * 0.4)
		var a := boss_crack_pos
		var reach := 90.0 + float((i * 37) % 170)
		for part in 3:
			var b := a + dir.rotated(sin(float(i + part) * 2.1) * 0.5) * reach * (1.0 - k * 0.2) / 2.0
			canvas.draw_line(a, b, color, 4.0 - part, true)
			a = b

func _draw_danger_line() -> void:
	var y := GameSim.FIELD_Y + sim.death_row * GameSim.CELL_H
	var close := 1.0 - clampf((sim.death_row - sim._lowest_row() - 1) / 4.0, 0.0, 1.0)
	var alpha := 0.22 + close * (0.45 + sin(time * 7.0) * 0.25)
	var x := GameSim.FIELD_X + 6.0
	while x < GameSim.FIELD_X + GameSim.FIELD_W - 6.0:
		draw_line(Vector2(x, y), Vector2(x + 14.0, y), Color(UI.DANGER, alpha), 3.0)
		x += 26.0

## Everything here is added to the picture as light.
func _draw_glow() -> void:
	canvas = glow_layer
	if screen != Menus.Screen.GAME or paused:
		return
	_draw_burst_light()
	for beam in beams:
		var k := float(beam["t"]) / 0.45
		var x := GameSim.FIELD_X + (float(beam["col"]) + 0.5) * GameSim.CELL_W
		var width := GameSim.CELL_W * (1.0 - k * 0.7)
		glow_layer.draw_rect(Rect2(x - width / 2.0, GameSim.FIELD_Y, width, GameSim.LAUNCH_Y - GameSim.FIELD_Y), Color(1.0, 0.25, 0.35, (1.0 - k) * 0.8))
		glow_layer.draw_rect(Rect2(x - width / 6.0, GameSim.FIELD_Y, width / 3.0, GameSim.LAUNCH_Y - GameSim.FIELD_Y), Color(1.0, 1.0, 1.0, 1.0 - k))
	var ball_color := _ball_color()
	var radius := sim.ball_radius
	for ball in sim.balls:
		var color: Color = ball_color.lerp(UI.STAR, 0.7) if ball.temp else ball_color
		# The tail grows and takes on the combo's colour as a shot heats up.
		var length := TRAIL_BASE + radius * 2.0 + minf(sim.combo * TRAIL_PER_COMBO, TRAIL_MAX_EXTRA)
		var trail_color := _trail_color(color.lerp(_combo_color(sim.combo), minf(sim.combo / TRAIL_COLOR_FULL_COMBO, 0.85)), sim.balls.find(ball))
		var back: Vector2 = -ball.vel.normalized() * length
		if trail_color.a > 0.0:
			glow_layer.draw_line(ball.pos + back, ball.pos + back * 0.45, Color(trail_color, 0.14), radius * 0.9)
			glow_layer.draw_line(ball.pos + back * 0.45, ball.pos, Color(trail_color, 0.34), radius * 1.4)
		_glow_sprite(ball.pos, radius * 5.0, Color(color, 0.42))
	for block in sim.unique_blocks():
		if block["kind"] == "bomb" or block["kind"] == "treasure":
			var pulse := 0.5 + sin(time * 4.0 + float(block["id"])) * 0.5
			_glow_sprite(sim.block_rect(block).get_center(), 100.0, Color(UI.BLOCKS[block["kind"]], 0.1 + pulse * 0.1))
		elif block["kind"] == "boss":
			_glow_sprite(sim.block_rect(block).get_center(), 420.0, Color(Bosses.color(block["boss_id"]), 0.3 + sin(time * 3.0) * 0.08))
	for r in rings:
		if float(r["t"]) < 0.0:
			continue
		var k := float(r["t"]) / 0.35
		_glow_sprite(r["pos"], float(r["size"]) * 1.7 * (0.5 + k), Color(1.0, 0.55, 0.3, (1.0 - k) * 0.65))
		glow_layer.draw_arc(r["pos"], 40.0 + k * float(r["size"]), 0.0, TAU, 48, Color(1.0, 0.85, 0.6, 1.0 - k), 12.0 * (1.0 - k) + 1.5, true)
	for b in bolts:
		var to: Vector2 = b["to"]
		var from := Vector2(float(b["x"]), GameSim.FIELD_Y)
		var mid := from.lerp(to, 0.5) + Vector2(randf_range(-30.0, 30.0), 0.0)
		var alpha := 1.0 - float(b["t"]) / 0.14
		glow_layer.draw_polyline(PackedVector2Array([from, mid, to]), Color(0.65, 0.9, 1.0, alpha), 4.0, true)
		_glow_sprite(to, 120.0, Color(0.6, 0.85, 1.0, alpha * 0.7))
	for p in particles:
		var alpha := 1.0 - float(p["t"]) / float(p["life"])
		var color: Color = p["color"]
		_glow_sprite(p["pos"], float(p["size"]) * (2.5 + alpha * 3.5), Color(color.lerp(Color.WHITE, alpha * 0.35), alpha))
	for c in fly_coins:
		_glow_sprite(c["pos"], 44.0, Color(UI.GOLD, 0.55))

## Light rushes into the launcher during the wind-up, then rays and a ring burst out of it.
func _draw_burst_light() -> void:
	if burst_windup >= 0.0:
		var k := clampf(burst_windup / BURST_WINDUP, 0.0, 1.0)
		var color := _ball_color()
		_glow_sprite(burst_origin, 180.0 + k * k * 900.0, Color(color, 0.25 + k * 0.6))
		for i in 42:
			var angle := float(i) * 2.399 + floorf(time * 12.0) * 0.37 * float(i % 3)
			var dir := Vector2.from_angle(angle)
			var reach := 900.0 * (1.0 - fmod(k * 2.5 + float(i) * 0.137, 1.0))
			glow_layer.draw_line(burst_origin + dir * (reach + 60.0 + k * 90.0), burst_origin + dir * reach, Color(color, 0.25 + k * 0.5), 3.0 + k * 3.0)
	if burst_after <= 0.0:
		return
	var fade := burst_after / BURST_AFTERGLOW
	var spent := 1.0 - fade
	var ray_color := _ball_color().lerp(UI.GOLD, 0.35)
	for i in 14:
		var angle := float(i) * TAU / 14.0 + time * 0.5
		var a := burst_origin + Vector2.from_angle(angle - 0.055) * 1800.0
		var b := burst_origin + Vector2.from_angle(angle + 0.055) * 1800.0
		glow_layer.draw_colored_polygon(PackedVector2Array([burst_origin, a, b]), Color(ray_color, fade * fade * 0.38))
	var radius := spent * GameSim.BURST_WAVE_SPEED * BURST_AFTERGLOW
	glow_layer.draw_arc(burst_origin, radius, 0.0, TAU, 96, Color(1.0, 1.0, 1.0, fade), 8.0 + 46.0 * fade, true)
	glow_layer.draw_arc(burst_origin, radius * 0.72, 0.0, TAU, 96, Color(ray_color, fade * 0.8), 5.0 + 20.0 * fade, true)
	_glow_sprite(burst_origin, 1500.0 * fade, Color(ray_color, fade * 0.8))

func _draw_field_force() -> void:
	match sim.modifier:
		"wind":
			for i in 14:
				var y := GameSim.FIELD_Y + 40.0 + i * 62.0
				var x := fmod(time * 260.0 * sim.wind + i * 173.0, GameSim.FIELD_W)
				if x < 0.0:
					x += GameSim.FIELD_W
				var at := Vector2(GameSim.FIELD_X + x, y)
				canvas.draw_line(at, at + Vector2(-46.0 * sim.wind, 0.0), Color(1.0, 1.0, 1.0, 0.12), 3.0, true)
		"gravity":
			for i in 4:
				var r := fmod(time * 40.0 + i * 30.0, 120.0)
				canvas.draw_arc(sim.well, 120.0 - r, 0.0, TAU, 40, Color(0.7, 0.55, 1.0, (r / 120.0) * 0.35), 3.0, true)
			canvas.draw_circle(sim.well, 14.0, Color(0.05, 0.02, 0.12))
			canvas.draw_arc(sim.well, 14.0, 0.0, TAU, 24, Color(0.7, 0.55, 1.0), 3.0, true)

## Linked pairs are tied with a dotted line, so it is clear they share their damage.
func _draw_chains() -> void:
	for block in sim.unique_blocks():
		if not block.has("link") or int(block["id"]) > int(block["link"]):
			continue
		var twin: Variant = sim.block_by_id(int(block["link"]))
		if twin == null:
			continue
		var from := sim.block_rect(block).get_center()
		var to := sim.block_rect(twin).get_center()
		var steps := int(from.distance_to(to) / 16.0)
		for i in steps:
			canvas.draw_circle(from.lerp(to, (i + 0.5) / steps), 3.0, Color(UI.GOLD, 0.7))

## Fog hides the colours that tell how much health the top of the field has left.
func _draw_fog() -> void:
	if sim.modifier != "fog":
		return
	for i in 10:
		var y := GameSim.FIELD_Y + i * 36.0
		var drift := sin(time * 0.6 + i) * 30.0
		canvas.draw_rect(Rect2(GameSim.FIELD_X - 10.0 + drift, y, GameSim.FIELD_W + 20.0, 40.0), Color(0.75, 0.75, 0.85, 0.16 * (1.0 - i / 12.0)))

## Furniture is dark and flat, so it never reads as something to break.
func _draw_obstacles() -> void:
	for entry: Dictionary in sim.obstacles.values():
		_draw_obstacle(String(entry["kind"]), sim.cell_rect(entry["cell"]), float(entry["pulse"]), int(entry["dir"]), bool(entry.get("open", false)), int(entry.get("hits", GameSim.KEY_HITS)))

func _draw_obstacle(kind: String, rect: Rect2, pulse: float, dir := 1, open := false, hits := GameSim.KEY_HITS) -> void:
	var edge := OBSTACLE_EDGE.lerp(Color.WHITE, pulse)
	var c := rect.get_center()
	match kind:
		"gate":
			if open:
				panel(rect, Color.TRANSPARENT, 8.0, Color(UI.MINT, 0.35), 2)
				return
			panel(rect, OBSTACLE_BODY, 8.0, UI.MINT.lerp(Color.WHITE, pulse), 3)
			for i in 4:
				var x := rect.position.x + rect.size.x * (i + 1) / 5.0
				canvas.draw_line(Vector2(x, rect.position.y + 6.0), Vector2(x, rect.end.y - 6.0), Color(UI.MINT, 0.7), 3.0)
			return
		"switch":
			canvas.draw_circle(c, 22.0, OBSTACLE_BODY)
			canvas.draw_arc(c, 22.0, 0.0, TAU, 28, UI.MINT.lerp(Color.WHITE, pulse), 4.0, true)
			canvas.draw_circle(c, 9.0 + pulse * 4.0, UI.MINT)
			return
		"door":
			panel(rect, Color("3a2a1c"), 6.0, Color("c9a86a"), 3)
			canvas.draw_circle(c + Vector2(0.0, -4.0), 6.0, Color("17122b"))
			canvas.draw_rect(Rect2(c + Vector2(-3.0, 0.0), Vector2(6.0, 12.0)), Color("17122b"))
			return
		"key":
			panel(rect.grow(-6.0), Color(UI.GOLD, 0.15 + pulse * 0.3), 10.0, UI.GOLD, 3)
			canvas.draw_arc(c + Vector2(-14.0, 0.0), 10.0, 0.0, TAU, 20, UI.GOLD, 4.0, true)
			canvas.draw_line(c + Vector2(-4.0, 0.0), c + Vector2(22.0, 0.0), UI.GOLD, 4.0)
			canvas.draw_line(c + Vector2(14.0, 0.0), c + Vector2(14.0, 8.0), UI.GOLD, 4.0)
			for i in hits:
				canvas.draw_circle(rect.position + Vector2(14.0 + i * 10.0, rect.size.y - 10.0), 3.0, UI.GOLD)
			return
		"bumper":
			var r := GameSim.BUMPER_RADIUS + pulse * 7.0
			soft_glow(c, Vector2.ONE * (r * 3.0), Color(UI.STAR, 0.18 + pulse * 0.5))
			canvas.draw_circle(c, r, OBSTACLE_BODY)
			canvas.draw_arc(c, r, 0.0, TAU, 32, UI.STAR.lerp(Color.WHITE, pulse), 4.0, true)
			canvas.draw_circle(c, r * 0.36, UI.STAR.lerp(Color.WHITE, pulse))
		"ramp_l", "ramp_r":
			var points := sim.shape_points(rect, "slope_l" if kind == "ramp_l" else "slope_r")
			canvas.draw_colored_polygon(points, OBSTACLE_BODY)
			points.append(points[0])
			canvas.draw_polyline(points, edge, 3.0, true)
		"portal":
			var spin := time * 3.0
			soft_glow(c, Vector2.ONE * 110.0, Color(OBSTACLE_PORTAL, 0.4))
			canvas.draw_circle(c, GameSim.PORTAL_RADIUS, Color(UI.INK, 0.9))
			for i in 3:
				canvas.draw_arc(c, GameSim.PORTAL_RADIUS - i * 6.0, spin * (1.0 + i * 0.4) + i, spin * (1.0 + i * 0.4) + i + 4.2, 20, OBSTACLE_PORTAL, 3.0, true)
		_:
			panel(rect, OBSTACLE_BODY, 8.0, edge, 3)
			if kind == "mover":
				var sign_x := float(dir)
				for i in 2:
					var tip := c + Vector2(sign_x * (4.0 + i * 16.0), 0.0)
					canvas.draw_polyline(PackedVector2Array([tip + Vector2(-sign_x * 10.0, -10.0), tip, tip + Vector2(-sign_x * 10.0, 10.0)]), edge, 3.0, true)
			else:
				for corner_at in [rect.position + Vector2(10.0, 10.0), rect.end - Vector2(10.0, 10.0), Vector2(rect.end.x - 10.0, rect.position.y + 10.0), Vector2(rect.position.x + 10.0, rect.end.y - 10.0)]:
					canvas.draw_circle(corner_at, 3.0, edge)

func _draw_blocks() -> void:
	var slide := -descend_anim * GameSim.CELL_H
	for block in sim.unique_blocks():
		var rect := sim.block_rect(block)
		# Anything that stayed put this turn, like a slow boss, must not appear to fall.
		if block["slid"]:
			rect.position.y += slide
		var kind: String = block["kind"]
		if kind == "boss":
			_draw_boss(block, rect)
			continue
		if block.has("ally_id"):
			_draw_ally(block, rect)
			continue
		var hit: float = clampf(float(flash.get(block["id"], 0.0)), 0.0, 1.0)
		# A struck block swells for a moment, so every hit has weight.
		var drawn := rect.grow(hit * 3.0)
		var shape: String = block.get("shape", "box")
		var body := _block_color(block).lerp(Color.WHITE, hit * 0.85)
		_draw_block_body(kind, drawn, body, _block_border(block), shape)
		if block.has("post"):
			_draw_block_outline(drawn, shape, Color("8be9fd"), 3.0)
		if block.has("element"):
			canvas.draw_circle(rect.position + Vector2(rect.size.x / 2.0, 7.0), 5.0, Worlds.ELEMENT_COLORS[block["element"]])
		if int(block["poison"]) > 0:
			canvas.draw_circle(rect.get_center() + Vector2(-9.0, -rect.size.y * 0.22), 5.0, Color("2f9e44"))
		if block["burning"]:
			canvas.draw_circle(rect.get_center() + Vector2(9.0, -rect.size.y * 0.22), 5.0, Color("e8590c"))

## Base look of a block, shared with the codex. The body's colour belongs to its health,
## so a block's kind has to read from its border and its centre icon.
func _draw_block_body(kind: String, rect: Rect2, color: Color, border := Color.TRANSPARENT, shape := "box") -> void:
	if shape == "box":
		panel(rect, color, 14.0)
		panel(Rect2(rect.position + Vector2(4.0, 3.0), Vector2(rect.size.x - 8.0, rect.size.y * 0.4)), Color(1.0, 1.0, 1.0, 0.2), 10.0)
	elif shape == "round":
		var radius := minf(rect.size.x, rect.size.y) / 2.0
		canvas.draw_circle(rect.get_center(), radius, color)
		canvas.draw_circle(rect.get_center() + Vector2(-radius * 0.26, -radius * 0.3), radius * 0.42, Color(1.0, 1.0, 1.0, 0.22))
	else:
		var points := sim.shape_points(rect, shape)
		canvas.draw_colored_polygon(points, color)
		# A lighter inner copy, nudged upward, gives every shape the same soft bevel.
		var center := rect.get_center()
		var inner := PackedVector2Array()
		for p in points:
			inner.append(center + (p - center) * 0.62 + Vector2(0.0, -rect.size.y * 0.06))
		canvas.draw_colored_polygon(inner, Color(1.0, 1.0, 1.0, 0.16))
	if border.a > 0.0:
		_draw_block_outline(rect, shape, border, float(KIND_BORDER))
	var c := rect.get_center()
	match kind:
		"bomb":
			canvas.draw_circle(c + Vector2(-1.0, 2.0), 12.0, UI.INK)
			canvas.draw_line(c + Vector2(5.0, -7.0), c + Vector2(11.0, -14.0), UI.INK, 3.0)
		"shield":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -15.0), c + Vector2(13.0, -10.0), c + Vector2(11.0, 4.0), c + Vector2(0.0, 15.0), c + Vector2(-11.0, 4.0), c + Vector2(-13.0, -10.0)]), UI.INK)
		"armor":
			canvas.draw_rect(Rect2(c + Vector2(-13.0, -11.0), Vector2(26.0, 22.0)), UI.INK, false, 4.0)
			canvas.draw_line(c + Vector2(-13.0, 0.0), c + Vector2(13.0, 0.0), UI.INK, 3.0)
		"regen":
			canvas.draw_rect(Rect2(c + Vector2(-12.0, -4.0), Vector2(24.0, 8.0)), UI.INK)
			canvas.draw_rect(Rect2(c + Vector2(-4.0, -12.0), Vector2(8.0, 24.0)), UI.INK)
		"treasure":
			panel(Rect2(c + Vector2(-14.0, -11.0), Vector2(28.0, 22.0)), UI.INK, 5.0)
			canvas.draw_circle(c, 4.0, UI.GOLD)
		"breeder":
			canvas.draw_circle(c + Vector2(-7.0, 0.0), 8.0, UI.INK)
			canvas.draw_circle(c + Vector2(9.0, 0.0), 8.0, UI.INK)
		"extra_ball":
			canvas.draw_circle(c, 13.0, UI.INK)
			canvas.draw_circle(c, 8.0, Color.WHITE)
		"elite":
			PerkArt.draw_glyph(canvas, "crown", c, 15.0, UI.INK)
		"coin":
			PerkArt.draw_glyph(canvas, "coin", c, 13.0, UI.INK)
		"part":
			PerkArt.draw_glyph(canvas, "gear", c, 15.0, UI.INK)
		"bounty":
			canvas.draw_circle(c, 15.0, UI.INK)
			canvas.draw_circle(c, 10.0, UI.GOLD)
			canvas.draw_rect(Rect2(c + Vector2(-2.0, -6.0), Vector2(4.0, 12.0)), UI.INK)

func _draw_ally(block: Dictionary, rect: Rect2) -> void:
	var id: String = block["ally_id"]
	var color := Bosses.color(id)
	panel(rect, color.darkened(0.72), 22.0, Color(color, 0.8), 3)
	var hit: float = clampf(float(flash.get(block["id"], 0.0)), 0.0, 1.0)
	BossArt.draw(canvas, id, Rect2(rect.position + Vector2(0.0, -4.0), Vector2(rect.size.x, rect.size.y - 22.0)), "hurt" if hit > 0.25 else "idle", time)
	var bar := Rect2(rect.position + Vector2(14.0, rect.size.y - 22.0), Vector2(rect.size.x - 28.0, 14.0))
	panel(bar, Color(0.0, 0.0, 0.0, 0.62), 7.0)
	panel(Rect2(bar.position, Vector2(maxf(bar.size.x * float(block["hp"]) / float(block["max_hp"]), 10.0), bar.size.y)), UI.GOLD, 7.0)

func _draw_block_outline(rect: Rect2, shape: String, color: Color, width: float) -> void:
	if shape == "box":
		panel(rect, Color.TRANSPARENT, 14.0, color, int(width))
	elif shape == "round":
		canvas.draw_arc(rect.get_center(), minf(rect.size.x, rect.size.y) / 2.0, 0.0, TAU, 32, color, width, true)
	else:
		var points := sim.shape_points(rect, shape)
		points.append(points[0])
		canvas.draw_polyline(points, color, width, true)

func draw_block_icon(kind: String, rect: Rect2) -> void:
	if kind == "boss":
		BossArt.draw(canvas, "purun", rect, "idle", time)
		return
	if kind in ["wall", "mover", "bumper", "ramp_l", "portal", "gate", "switch", "door", "key"]:
		_draw_obstacle(kind, rect, 0.0)
		return
	if kind.begins_with("skin_") or kind.begins_with("trail_") or kind.begins_with("sky_"):
		return
	if kind in ["round", "hex", "diamond", "tri_up", "pill"]:
		_draw_block_body("normal", rect, UI.RAMP[1], Color.TRANSPARENT, kind)
		return
	if kind == "big":
		_draw_block_body("normal", rect.grow(4.0), UI.RAMP[3])
		return
	_draw_block_body(kind, rect, UI.RAMP[1], UI.BLOCKS.get(kind, Color.TRANSPARENT))

func _draw_boss(block: Dictionary, rect: Rect2) -> void:
	var id: String = block["boss_id"]
	var color := Bosses.color(id)
	var ratio := clampf(float(block["hp"]) / float(block["max_hp"]), 0.0, 1.0)
	var hit: float = clampf(float(flash.get(block["id"], 0.0)), 0.0, 1.0)
	var angry: bool = block["angry"]
	var plate := color.darkened(0.72)
	if angry:
		plate = plate.lerp(UI.DANGER.darkened(0.45), 0.5 + sin(time * 9.0) * 0.3)
	panel(rect, plate, 22.0, Color(color, 0.8), 3)
	if block.get("awakened", false):
		var flare := 0.5 + sin(time * 6.0) * 0.5
		panel(rect.grow(6.0 + flare * 4.0), Color(UI.DANGER, 0.08), 28.0, Color(UI.DANGER, 0.6 + flare * 0.4), 4)
	# The whole character jolts when struck, so even small hits feel like they land.
	var jolt := Vector2(sin(time * 70.0), 0.0) * hit * 5.0
	var mood := "hurt" if hit > 0.25 else ("angry" if angry else "idle")
	var body := Rect2(rect.position + jolt + Vector2(0.0, -4.0), Vector2(rect.size.x, rect.size.y - 22.0))
	BossArt.draw(canvas, id, body, mood, time)
	if hit > 0.0:
		panel(rect, Color(1.0, 1.0, 1.0, hit * 0.3), 22.0)
	if sim.is_boss_guarded():
		var pulse := 0.5 + sin(time * 4.0) * 0.5
		panel(rect.grow(5.0 + pulse * 3.0), Color("8be9fd", 0.08), 28.0, Color("8be9fd", 0.55 + pulse * 0.4), 4)
	var bar := Rect2(rect.position + Vector2(14.0, rect.size.y - 28.0), Vector2(rect.size.x - 28.0, 22.0))
	panel(bar, Color(0.0, 0.0, 0.0, 0.62), 11.0)
	panel(Rect2(bar.position, Vector2(maxf(bar.size.x * ratio, 16.0), bar.size.y)), UI.DANGER if angry else UI.GOLD, 11.0)

func _draw_ball_shape(pos: Vector2, radius: float, color: Color) -> void:
	match String(Cosmetics.ITEMS[save.wearing("skin")]["shape"]):
		"star":
			PerkArt.draw_glyph(canvas, "star", pos, radius * 1.5, color)
		"diamond":
			canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(0.0, -radius * 1.3), pos + Vector2(radius * 1.3, 0.0), pos + Vector2(0.0, radius * 1.3), pos + Vector2(-radius * 1.3, 0.0)]), color)
		_:
			canvas.draw_circle(pos, radius, color)

func _trail_color(base: Color, index: int) -> Color:
	match String(Cosmetics.ITEMS[save.wearing("trail")]["mode"]):
		"none":
			return Color.TRANSPARENT
		"ember":
			return Color("ff9a3d").lerp(Color("ff4d6d"), 0.5 + sin(time * 8.0 + index) * 0.5)
		"rainbow":
			return Color.from_hsv(fmod(time * 0.8 + index * 0.05, 1.0), 0.7, 1.0)
	return base

func _draw_balls() -> void:
	var base := _ball_color()
	var radius := sim.ball_radius
	var heated := base.lerp(_combo_color(sim.combo), minf(sim.combo / TRAIL_COLOR_FULL_COMBO, 0.5))
	var second := Color(String(Balls.BALLS[sim.second_ball]["color"])) if sim.second_ball != "" else heated
	for ball in sim.balls:
		var color: Color = second if ball.alt else heated
		if ball.temp:
			color = color.lerp(UI.STAR, 0.5)
		_draw_ball_shape(ball.pos, radius, color)

func _draw_companion() -> void:
	if sim.stat("companion") <= 0.0:
		return
	var p := Vector2(sim.launch_x, GameSim.LAUNCH_Y) + Vector2(cos(time * 1.6) * 60.0, sin(time * 3.2) * 12.0 - 8.0)
	PerkArt.draw_glyph(canvas, "pal", p, 15.0, PerkArt.TAG_COLORS["swarm"])

func _draw_launcher() -> void:
	_draw_companion()
	if sim.state != GameSim.State.AIM:
		return
	var p := Vector2(sim.launch_x, GameSim.LAUNCH_Y)
	var color := _ball_color()
	var breathe := 1.0 + sin(time * 4.0) * 0.08
	soft_glow(p, Vector2(110.0, 110.0) * breathe, Color(color, 0.4))
	_draw_ball_shape(p, sim.ball_radius + 3.0, color)
	text_center(p + Vector2(0.0, 44.0), "x%d" % sim.shot_ball_count(), 26, UI.TEXT)
	if sim.guards > 0:
		for i in sim.guards:
			PerkArt.draw_glyph(canvas, "shield", Vector2(70.0 + i * 36.0, 1110.0), 14.0, UI.MINT)
	if not save.tutorial_done:
		_draw_tutorial()

## Until the first shot, a ghost finger shows the whole move: point somewhere, see the line, tap.
func _draw_tutorial() -> void:
	if aiming:
		text_center(Vector2(BASE_W / 2.0, 1180.0), t("tutorial_release"), 38, UI.GOLD)
		return
	var touch := DisplayServer.is_touchscreen_available()
	text_center(Vector2(BASE_W / 2.0, 1166.0), t("tutorial" if touch else "tutorial_click"), 36, UI.GOLD)
	text_center(Vector2(BASE_W / 2.0, 1214.0), t("tutorial_sub"), 24, UI.MUTED, font_body)
	var cycle := fmod(time, TUTORIAL_CYCLE) / TUTORIAL_CYCLE
	var round_index := int(time / TUTORIAL_CYCLE) % TUTORIAL_TARGETS.size()
	var target: Vector2 = TUTORIAL_TARGETS[round_index]
	var start: Vector2 = TUTORIAL_TARGETS[(round_index + TUTORIAL_TARGETS.size() - 1) % TUTORIAL_TARGETS.size()]
	var move := smoothstep(0.0, 0.45, cycle)
	var finger := start.lerp(target, move)
	var appear := minf(cycle / 0.1, 1.0) * (1.0 - smoothstep(0.85, 1.0, cycle))
	# The line shows where the balls would go, as the real aim does.
	if cycle > 0.3:
		_draw_aim_line(finger, appear * 0.6)
	# A ring, unlike the solid balls, marks the fingertip; it ripples outwards on the tap.
	var pressed := cycle > 0.5 and cycle < 0.62
	var ring := 30.0 * (0.85 if pressed else 1.0)
	canvas.draw_arc(finger, ring, 0.0, TAU, 40, Color(UI.GOLD, 0.9 * appear), 5.0, true)
	canvas.draw_circle(finger, 9.0, Color(UI.GOLD, 0.9 * appear))
	if cycle > 0.5:
		var ripple := clampf((cycle - 0.5) / 0.3, 0.0, 1.0)
		canvas.draw_arc(finger, 30.0 + ripple * 60.0, 0.0, TAU, 48, Color(UI.GOLD, (1.0 - ripple) * 0.7 * appear), 4.0, true)

func _draw_aim() -> void:
	_draw_aim_line(aim_current, 1.0)

func _draw_aim_line(target: Vector2, alpha: float) -> void:
	if not _can_aim_at(target):
		return
	var points := sim.trace_aim(target - Vector2(sim.launch_x, GameSim.LAUNCH_Y))
	var phase := fmod(time * 180.0, 32.0)
	var travelled := 0.0
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var d := phase
		while d < length:
			var fade := 1.0 - clampf((travelled + d) / 1000.0, 0.0, 0.85)
			canvas.draw_circle(a.lerp(b, d / length), 2.0 + 4.0 * fade, Color(1.0, 1.0, 1.0, (0.25 + 0.65 * fade) * alpha))
			d += 32.0
		travelled += length
