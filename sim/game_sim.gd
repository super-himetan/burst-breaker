extends RefCounted
## Pure game rules. No rendering, so tests and balance runs can drive it headless.

enum State { AIM, SHOOT, UPGRADE, WON, LOST }

const COLS := 7
const CELL_W := 90.0
const CELL_H := 60.0
const FIELD_X := 45.0
const FIELD_Y := 170.0
const FIELD_W := COLS * CELL_W
const LAUNCH_Y := 1060.0
const DEATH_ROW := 13
const BALL_RADIUS := 10.0
const BALL_SPEED := 1100.0
const LAUNCH_INTERVAL := 0.07
const MAX_BALLS := 150
const FIXED_DT := 1.0 / 120.0
const RECALL_TIME := 16.0
const CHAIN_DELAY := 0.07

const STAGES := [
	{"rows": 3, "waves": 1, "hp_min": 1, "hp_max": 3, "density": 0.65},
	{"rows": 3, "waves": 2, "hp_min": 2, "hp_max": 6, "density": 0.7},
	{"rows": 4, "waves": 2, "hp_min": 4, "hp_max": 9, "density": 0.7},
	{"rows": 4, "waves": 3, "hp_min": 6, "hp_max": 14, "density": 0.75},
	{"rows": 5, "waves": 3, "hp_min": 11, "hp_max": 24, "density": 0.75},
	{"rows": 5, "waves": 3, "hp_min": 15, "hp_max": 32, "density": 0.8},
	{"rows": 6, "waves": 3, "hp_min": 20, "hp_max": 42, "density": 0.8},
	{"rows": 6, "waves": 3, "hp_min": 26, "hp_max": 54, "density": 0.85},
]

const UPGRADE_IDS: Array[String] = ["split", "bomb", "ricochet", "more_balls"]


class Ball:
	var pos: Vector2
	var vel: Vector2
	var temp := false
	var wall_bonus := 0
	var returning := false


var state: int = State.AIM
var stage := 0
var waves_left := 0
var blocks := {}
var balls: Array[Ball] = []
var levels := {}
var ball_count := 8
var launch_x := FIELD_X + FIELD_W / 2.0
var choices: Array[String] = []
var events: Array[Dictionary] = []

var coins := 0
var combo := 0
var best_combo := 0
var total_damage := 0
var shot_damage := 0
var best_shot_damage := 0
var shots := 0
var sim_time := 0.0

var _rng := RandomNumberGenerator.new()
var _launch_dir := Vector2.UP
var _launch_left := 0
var _launch_timer := 0.0
var _next_launch_x := -1.0
var _shot_time := 0.0
var _pending_blasts: Array[Dictionary] = []
var _accumulator := 0.0


func new_run(seed_value: int) -> void:
	_rng.seed = seed_value
	state = State.AIM
	stage = 0
	levels = {"split": 0, "bomb": 0, "ricochet": 0, "more_balls": 0}
	ball_count = 8
	launch_x = FIELD_X + FIELD_W / 2.0
	choices = []
	events = []
	coins = 0
	combo = 0
	best_combo = 0
	total_damage = 0
	shot_damage = 0
	best_shot_damage = 0
	shots = 0
	sim_time = 0.0
	_accumulator = 0.0
	_start_stage()


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(FIELD_X + cell.x * CELL_W + 3.0, FIELD_Y + cell.y * CELL_H + 3.0, CELL_W - 6.0, CELL_H - 6.0)


func sanitize_dir(dir: Vector2) -> Vector2:
	var d := dir.normalized()
	if d == Vector2.ZERO:
		return Vector2.UP
	if d.y > -0.15:
		d = Vector2(signf(d.x) if d.x != 0.0 else 1.0, -0.15).normalized()
	return d


func fire(dir: Vector2) -> bool:
	if state != State.AIM:
		return false
	state = State.SHOOT
	_launch_dir = sanitize_dir(dir)
	_launch_left = ball_count
	_launch_timer = 0.0
	_next_launch_x = -1.0
	_shot_time = 0.0
	combo = 0
	shot_damage = 0
	shots += 1
	_emit({"type": "fire"})
	return true


func choose_upgrade(id: String) -> bool:
	if state != State.UPGRADE or not choices.has(id):
		return false
	levels[id] += 1
	if id == "more_balls":
		ball_count += 4
	choices = []
	stage += 1
	state = State.AIM
	_start_stage()
	return true


## Advances the simulation by real seconds, in fixed steps so runs stay reproducible.
func step(delta: float) -> void:
	_accumulator += min(delta, 0.1)
	while _accumulator >= FIXED_DT:
		_accumulator -= FIXED_DT
		_fixed_step(FIXED_DT)


## Aim preview: path from the launcher until the first block, with wall bounces.
func trace_aim(dir: Vector2, max_len := 1000.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var p := Vector2(launch_x, LAUNCH_Y)
	var d := sanitize_dir(dir)
	points.append(p)
	var travelled := 0.0
	var step_len := 6.0
	while travelled < max_len:
		p += d * step_len
		travelled += step_len
		if p.x < FIELD_X + BALL_RADIUS or p.x > FIELD_X + FIELD_W - BALL_RADIUS:
			d.x = -d.x
			points.append(p)
		if p.y < FIELD_Y + BALL_RADIUS:
			d.y = -d.y
			points.append(p)
		if _block_at_circle(p) != Vector2i(-1, -1):
			break
	points.append(p)
	return points


func _start_stage() -> void:
	blocks = {}
	balls = []
	_pending_blasts = []
	_launch_left = 0
	var cfg: Dictionary = STAGES[stage]
	waves_left = cfg["waves"]
	for row in int(cfg["rows"]):
		_spawn_row(row)
	_emit({"type": "stage_start", "stage": stage})


func _spawn_row(row: int) -> void:
	var cfg: Dictionary = STAGES[stage]
	var placed := 0
	for col in COLS:
		if _rng.randf() > float(cfg["density"]):
			continue
		_place_block(Vector2i(col, row))
		placed += 1
	if placed == 0:
		_place_block(Vector2i(_rng.randi_range(0, COLS - 1), row))


func _place_block(cell: Vector2i) -> void:
	var cfg: Dictionary = STAGES[stage]
	var hp := _rng.randi_range(int(cfg["hp_min"]), int(cfg["hp_max"]))
	var kind := "bomb" if _rng.randf() < 0.1 else "normal"
	blocks[cell] = {"hp": hp, "max_hp": hp, "kind": kind}


func _fixed_step(dt: float) -> void:
	if state != State.SHOOT:
		return
	sim_time += dt
	_shot_time += dt
	# Long shots speed up so nobody waits on a lone stuck ball.
	var move_dt := dt * (1.0 + clampf((_shot_time - 5.0) / 5.0, 0.0, 1.5))
	_launch_step(dt)
	if _shot_time > RECALL_TIME:
		for ball in balls:
			ball.returning = true
	_blast_step(dt)
	var i := balls.size() - 1
	while i >= 0:
		if _move_ball(balls[i], move_dt):
			balls.remove_at(i)
		i -= 1
	if state != State.SHOOT:
		return
	if blocks.is_empty() and _pending_blasts.is_empty():
		balls = []
		_launch_left = 0
		_end_shot()
	elif balls.is_empty() and _launch_left == 0 and _pending_blasts.is_empty():
		_end_shot()


func _launch_step(dt: float) -> void:
	if _launch_left <= 0:
		return
	_launch_timer -= dt
	if _launch_timer > 0.0:
		return
	_launch_timer = LAUNCH_INTERVAL
	_launch_left -= 1
	var ball := Ball.new()
	ball.pos = Vector2(launch_x, LAUNCH_Y)
	ball.vel = _launch_dir * BALL_SPEED
	balls.append(ball)


## Returns true when the ball is finished and should be removed.
func _move_ball(ball: Ball, dt: float) -> bool:
	if ball.returning:
		ball.vel = Vector2(0.0, BALL_SPEED)
	ball.pos += ball.vel * dt
	var left := FIELD_X + BALL_RADIUS
	var right := FIELD_X + FIELD_W - BALL_RADIUS
	var top := FIELD_Y + BALL_RADIUS
	if ball.pos.x < left and ball.vel.x < 0.0:
		ball.pos.x = left
		ball.vel.x = -ball.vel.x
		_on_wall(ball)
	elif ball.pos.x > right and ball.vel.x > 0.0:
		ball.pos.x = right
		ball.vel.x = -ball.vel.x
		_on_wall(ball)
	if ball.pos.y < top and ball.vel.y < 0.0:
		ball.pos.y = top
		ball.vel.y = -ball.vel.y
		_on_wall(ball)
	if ball.pos.y >= LAUNCH_Y and ball.vel.y > 0.0:
		if not ball.temp and _next_launch_x < 0.0:
			_next_launch_x = clampf(ball.pos.x, left, right)
		return true
	if not ball.returning:
		_collide_ball(ball)
		# Keep balls from skating sideways forever.
		if absf(ball.vel.y) < BALL_SPEED * 0.12:
			var sign_y := -1.0 if ball.vel.y < 0.0 else 1.0
			ball.vel.y = sign_y * BALL_SPEED * 0.12
			ball.vel = ball.vel.normalized() * BALL_SPEED
	return false


func _on_wall(ball: Ball) -> void:
	ball.wall_bonus += levels["ricochet"] * 2
	_emit({"type": "wall", "pos": ball.pos})


func _block_at_circle(p: Vector2) -> Vector2i:
	var col := int(floor((p.x - FIELD_X) / CELL_W))
	var row := int(floor((p.y - FIELD_Y) / CELL_H))
	for r in range(row - 1, row + 2):
		for c in range(col - 1, col + 2):
			var cell := Vector2i(c, r)
			if not blocks.has(cell):
				continue
			var rect := cell_rect(cell)
			var nearest := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
			if p.distance_squared_to(nearest) <= BALL_RADIUS * BALL_RADIUS:
				return cell
	return Vector2i(-1, -1)


func _collide_ball(ball: Ball) -> void:
	var cell := _block_at_circle(ball.pos)
	if cell == Vector2i(-1, -1):
		return
	var rect := cell_rect(cell)
	var nearest := Vector2(clampf(ball.pos.x, rect.position.x, rect.end.x), clampf(ball.pos.y, rect.position.y, rect.end.y))
	var normal := ball.pos - nearest
	if normal.length_squared() < 0.0001:
		normal = -ball.vel
	normal = normal.normalized()
	# Snap to an axis so bounces stay readable on a grid.
	if absf(normal.x) > absf(normal.y):
		normal = Vector2(signf(normal.x), 0.0)
	else:
		normal = Vector2(0.0, signf(normal.y))
	if ball.vel.dot(normal) >= 0.0:
		return
	ball.vel = ball.vel.bounce(normal)
	ball.pos = nearest + normal * (BALL_RADIUS + 0.5)
	_damage_block(cell, 1 + ball.wall_bonus)
	_maybe_split(ball)


func _maybe_split(ball: Ball) -> void:
	var level: int = levels["split"]
	if level <= 0 or balls.size() >= MAX_BALLS:
		return
	if _rng.randf() >= 0.22 * level:
		return
	var extra := Ball.new()
	extra.pos = ball.pos
	extra.vel = ball.vel.rotated(_rng.randf_range(-0.7, 0.7))
	extra.temp = true
	extra.wall_bonus = ball.wall_bonus
	balls.append(extra)
	_emit({"type": "split", "pos": ball.pos})


func _damage_block(cell: Vector2i, damage: int) -> void:
	var block: Dictionary = blocks[cell]
	var dealt: int = min(damage, int(block["hp"]))
	block["hp"] = int(block["hp"]) - damage
	total_damage += dealt
	shot_damage += dealt
	best_shot_damage = max(best_shot_damage, shot_damage)
	combo += 1
	best_combo = max(best_combo, combo)
	var center := cell_rect(cell).get_center()
	_emit({"type": "hit", "cell": cell, "pos": center, "damage": dealt, "combo": combo})
	if int(block["hp"]) > 0:
		return
	var gained := 1 + int(block["max_hp"]) / 5
	coins += gained
	var is_bomb: bool = block["kind"] == "bomb"
	blocks.erase(cell)
	_emit({"type": "kill", "cell": cell, "pos": center, "coins": gained, "bomb": is_bomb})
	var level: int = levels["bomb"]
	if is_bomb or (level > 0 and _rng.randf() < 0.18 + 0.1 * level):
		_pending_blasts.append({"cell": cell, "t": CHAIN_DELAY, "damage": 3 + 3 * level + 2 * stage})


func _blast_step(dt: float) -> void:
	var ready: Array[Dictionary] = []
	for blast in _pending_blasts:
		blast["t"] = float(blast["t"]) - dt
		if float(blast["t"]) <= 0.0:
			ready.append(blast)
	for blast in ready:
		_pending_blasts.erase(blast)
		var cell: Vector2i = blast["cell"]
		_emit({"type": "explode", "pos": cell_rect(cell).get_center()})
		for r in range(cell.y - 1, cell.y + 2):
			for c in range(cell.x - 1, cell.x + 2):
				var target := Vector2i(c, r)
				if blocks.has(target):
					_damage_block(target, int(blast["damage"]))


func _end_shot() -> void:
	if _next_launch_x >= 0.0:
		launch_x = _next_launch_x
	if blocks.is_empty() and waves_left <= 0:
		_clear_stage()
		return
	var moved := {}
	for cell: Vector2i in blocks:
		moved[cell + Vector2i(0, 1)] = blocks[cell]
	blocks = moved
	if waves_left > 0:
		waves_left -= 1
		_spawn_row(0)
	_emit({"type": "descend"})
	for cell: Vector2i in blocks:
		if cell.y >= DEATH_ROW:
			state = State.LOST
			_emit({"type": "lost"})
			return
	state = State.AIM


func _clear_stage() -> void:
	if stage >= STAGES.size() - 1:
		state = State.WON
		_emit({"type": "won"})
		return
	ball_count += 2
	state = State.UPGRADE
	choices = _roll_choices()
	_emit({"type": "stage_clear", "stage": stage})


func _roll_choices() -> Array[String]:
	# The first offer always shows the showiest picks so a new player feels them fast.
	if stage == 0:
		return ["split", "bomb", "more_balls"] as Array[String]
	var pool: Array[String] = UPGRADE_IDS.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, 3)


func _emit(event: Dictionary) -> void:
	if events.size() < 4000:
		events.append(event)
