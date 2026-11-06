extends RefCounted
## Pure game rules. No rendering, so tests and balance runs can drive it headless.

const Perks := preload("res://data/perks.gd")
const Balls := preload("res://data/balls.gd")
const Shop := preload("res://data/shop.gd")
const StarTree := preload("res://data/star_tree.gd")
const Tiers := preload("res://data/tiers.gd")
const Bosses := preload("res://data/bosses.gd")
const Layouts := preload("res://data/layouts.gd")
const Formations := preload("res://data/formations.gd")
const RunContent := preload("res://data/run_content.gd")
const Worlds := preload("res://data/worlds.gd")

enum State { AIM, SHOOT, UPGRADE, WON, LOST, ROUTE, EVENT }

const COLS := 7
const CELL_W := 90.0
const CELL_H := 60.0
const FIELD_X := 45.0
const FIELD_Y := 170.0
const FIELD_W := COLS * CELL_W
const LAUNCH_Y := 1060.0
const DEATH_ROW := 13
const BALL_RADIUS := 10.0
const MAX_RADIUS := 34.0
const BALL_SPEED := 1100.0
const LAUNCH_INTERVAL := 0.07
const MAX_BALLS := 150
const FIXED_DT := 1.0 / 120.0
const RECALL_TIME := 12.0
const CHAIN_DELAY := 0.07
const CRIT_BASE_MULT := 2.5
const NO_CELL := Vector2i(-9999, -9999)
const STAR_DAMAGE := 0.25
## Coins buy stars and stars earn coins, so this share sets how fast the whole economy snowballs.
const STAR_COINS := 0.1
const BURST_PER_HIT := 1.0 / 260.0
const BURST_SHOT_CAP := 0.3
## Starting part-way means even a short run gets to see the move.
const BURST_START := 0.3
const BURST_WAVE_SPEED := 1500.0
const BURST_RAIN_BALLS := 60
## A hit this many times a block's max HP crushes it, and each further step pays more coins.
const OVERKILL_RATIO := 4.0
const OVERKILL_MAX_STEPS := 4
## Style ranks, worst to best. A score at or above a threshold earns that rank.
const RANKS: Array[String] = ["D", "C", "B", "A", "S", "SS", "SSS"]
## Set from measured play: about one shot in ten reaches S, and about one in a hundred SSS.
const RANK_THRESHOLDS: Array[float] = [0.0, 1.0, 2.5, 4.5, 7.0, 11.0, 17.0]
const RUN_RANK_THRESHOLDS: Array[float] = [0.0, 2.0, 2.7, 3.5, 5.0, 8.0, 14.0]
const RANK_S := 4
## How much clearing the whole field, or a boss's whole health bar, adds to a shot's score.
const STYLE_FIELD_WEIGHT := 5.0
const STYLE_BOSS_WEIGHT := 8.0

const STAGES := [
	{"rows": 3, "waves": 1, "hp_min": 1, "hp_max": 3, "density": 0.65, "specials": {"bomb": 0.1}},
	{"rows": 3, "waves": 2, "hp_min": 3, "hp_max": 8, "density": 0.7, "specials": {"bomb": 0.1, "treasure": 0.04, "extra_ball": 0.04}},
	{"rows": 4, "waves": 2, "hp_min": 8, "hp_max": 16, "density": 0.7, "specials": {"bomb": 0.1, "treasure": 0.04, "extra_ball": 0.04, "shield": 0.08}},
	{"rows": 2, "waves": 0, "hp_min": 12, "hp_max": 26, "density": 0.6, "specials": {"bomb": 0.14, "treasure": 0.05}, "boss": {"pool": 0, "hp": 700, "every": 3}},
	{"rows": 5, "waves": 3, "hp_min": 34, "hp_max": 70, "density": 0.75, "specials": {"bomb": 0.1, "treasure": 0.04, "extra_ball": 0.04, "shield": 0.08, "regen": 0.08, "armor": 0.08}},
	{"rows": 5, "waves": 3, "hp_min": 50, "hp_max": 108, "density": 0.8, "specials": {"bomb": 0.1, "treasure": 0.04, "extra_ball": 0.04, "shield": 0.08, "regen": 0.08, "armor": 0.1, "breeder": 0.05}},
	{"rows": 6, "waves": 3, "hp_min": 75, "hp_max": 160, "density": 0.8, "specials": {"bomb": 0.1, "treasure": 0.04, "extra_ball": 0.04, "shield": 0.1, "regen": 0.1, "armor": 0.1, "breeder": 0.07}},
	{"rows": 3, "waves": 0, "hp_min": 70, "hp_max": 140, "density": 0.65, "specials": {"bomb": 0.14, "treasure": 0.05, "shield": 0.08, "regen": 0.08, "armor": 0.08}, "boss": {"pool": 1, "hp": 19500, "every": 1}},
]

## Reached only by players who have beaten every other boss.
const TRUE_STAGE := {"rows": 3, "waves": 0, "hp_min": 90, "hp_max": 180, "density": 0.65, "specials": {"bomb": 0.1, "armor": 0.1}, "boss": {"pool": 2, "hp": 42000, "every": 1}}
const RUSH_STAGE_POOL := {0: 3, 1: 7, 2: 7}
const ELITE_CHANCE := 0.1
const ELITE_HP := 4.0
const ELITE_COINS := 4.0
const BOUNTY_CHANCE := 0.12
const BOUNTY_HP := 2.5
const BOUNTY_COINS := 10.0
const BOUNTY_TURNS := 4
const FEVER_COMBO := 250
const FEVER_COINS := 2.0
const JACKPOT_CHANCE := 0.05
const JACKPOT_COINS := 15.0
const NOTE_CHANCE := 0.6
const ALLY_HP := 0.3
## Stage conditions: wind pushes balls sideways, a gravity well bends them, fog hides colours.
const MODIFIERS: Array[String] = ["wind", "fog", "gravity"]
const MODIFIER_CHANCE := 0.3
const WIND_FORCE := 260.0
const GRAVITY_FORCE := 900.0
const GRAVITY_REACH := 140.0
const CHAIN_CHANCE := 0.3
const LINK_SHARE := 0.5
const PART_HP := 3.0
const PART_BOSSES: Array[String] = ["dokan", "lumina", "zero", "hyoga", "chrono", "void", "origin"]
const PART_POST := Vector2i(3, 1)
const PART_BREAK_DAMAGE := 0.06
const KEY_HITS := 3
const ORIGIN_TRICKS := 3
const BOSS_SIZE := Vector2i(3, 2)
const BUMPER_RADIUS := 26.0
const PORTAL_RADIUS := 24.0
const PORTAL_COOLDOWN := 0.25
## How far a rounded polygon's edge bends in from its cell, as a share of the cell.
const PILL_SEGMENTS := 6
## Hits it takes the companion to act, at one level.
const COMPANION_HITS := 24
const COMPANION_DAMAGE := 4.0
const BOSS_STAGE_EXTRA_PICKS := 1
const SLIME_STEP := 0.25
const SLIME_PIECES := 3
const MOGU_HEAL_PER_BITE := 0.02
const GUARDED_DAMAGE := 0.25
const GUARD_RETURN_TURNS := 3
const GUARD_HP := 2.5
const LUMINA_HEAL := 0.02
const LUMINA_ANGRY_HEAL := 0.03
## Burn takes a share of max HP, which would melt a boss at the rate that suits small blocks.
const BOSS_BURN_SCALE := 0.25
const DOKAN_THROWS := 2
const ZERO_WALL_ROWS := 4
## Chrono undoes this share of the damage from the shot before.
const CHRONO_REWIND := 0.25
const CHRONO_ANGRY_REWIND := 0.4
const HYOGA_FREEZES := 2
## Homura comes back once with this share of its health.
const HOMURA_REBIRTH := 0.5
## Tsukuyo trades turns between a veil (the guarded rate) and an opening.
const TSUKUYO_EXPOSED := 1.5
const VOID_DRAIN := 0.12
const VOID_ANGRY_DRAIN := 0.2
## Boss tricks never place blocks closer to the danger line than this.
const BOSS_REACH_MARGIN := 4
## Each owned level sharing a tag raises a perk's odds, up to a cap so offers never lock in.
const SYNERGY_PER_LEVEL := 0.6
const SYNERGY_LEVEL_CAP := 5
## A perk that would complete an evolution right now.
const SYNERGY_PARTNER_MULT := 3.0
## A skipped evolution keeps coming back at about the odds of a common perk.
const EVOLUTION_RETURN_MULT := 25.0
const PLAGUE_SHARE := 0.5


class Ball:
	var pos: Vector2
	var vel: Vector2
	var temp := false
	var wall_bonus := 0.0
	var returning := false
	var hits := 0
	var ignore_id := -1
	var ignore_t := 0.0
	var portal_t := 0.0
	var alt := false


var state: int = State.AIM
var stage := 0
var waves_left := 0
var blocks := {}
## Unbreakable pieces by cell: {kind, cell, partner, dir, pulse}. They never count toward a clear.
var obstacles := {}
var _formation_rows: Array[Dictionary] = []
## What the run is doing between stages. Routes appear only when the config turns them on.
var routes_enabled := false
var world := "wall"
var fever := false
var true_path := false
var rush: Array[String] = []
var attack_element := ""
var modifier := ""
var wind := 0.0
var well := Vector2.ZERO
var bonus_shots := 0
var second_ball := ""
var _second_element := ""
var route_options: Array[String] = []
var event := {}
var relics: Array[String] = []
var missions: Array[Dictionary] = []
var _next_stage_hp := 1.0
var _next_stage_coins := 1.0
var _stage_hp_mult := 1.0
var _stage_coin_mult := 1.0
var _companion_hits := 0
var balls: Array[Ball] = []
var levels := {}
var stats := {}
var ball_type := "normal"
var tier := 0
var ball_count := 10
var bonus_balls := 0
var launch_x := FIELD_X + FIELD_W / 2.0
var choices: Array[String] = []
var picks_pending := 0
var rerolls := 0
var guards := 0
var death_row := DEATH_ROW
var ball_radius := BALL_RADIUS
var ball_speed := BALL_SPEED
var unlocked_perks: Variant = null
var emit_events := true
var boss_block: Variant = null
var events: Array[Dictionary] = []

var coins := 0
var combo := 0
var best_combo := 0
var total_damage := 0
var shot_damage := 0
var best_shot_damage := 0
var shots := 0
var sim_time := 0.0
var counters := {}
var burst_charge := 0.0
var last_shot_score := 0.0
var last_shot_rank := 0

var _rng := RandomNumberGenerator.new()
var _launch_dir := Vector2.UP
var _launch_left := 0
var _launch_timer := 0.0
var _next_launch_x := -1.0
var _shot_time := 0.0
var _floor_bounces_left := 0
var _pending_blasts: Array[Dictionary] = []
var _accumulator := 0.0
var _next_block_id := 1
var _base_stats := {}
var _coin_scale := 1.0
var _coin_carry := 0.5
var _tutorial_offer := false
var _stages_cleared := 0
var _offered_evolutions := {}
var _burst_shot := false
var _burst_shot_gain := 0.0
var _boss_met: Array = []
var boss_force := ""
var boss_force_own_pool := false
var _shot_start_blocks := 1
var _shot_start_kills := 0
var _shot_balls := 1
var _shot_start_boss_hp := 0
var _shot_boss_max_hp := 0
var _style_total := 0.0
var _style_shots := 0


## config: ball_type, tier, shop ({id: level}), stars, unlocked_perks (null = all),
## tutorial_offer, emit_events, boss_met (ids to meet last), boss_force (always this boss),
## boss_force_own_pool (boss_force only on the stage that boss normally appears on).
func new_run(seed_value: int, config := {}) -> void:
	_rng.seed = seed_value
	state = State.AIM
	stage = 0
	levels = {}
	for id in Perks.ids():
		levels[id] = 0
	ball_type = String(config.get("ball_type", "normal"))
	tier = int(config.get("tier", 0))
	unlocked_perks = config.get("unlocked_perks", null)
	_tutorial_offer = bool(config.get("tutorial_offer", false))
	emit_events = bool(config.get("emit_events", true))
	_boss_met = config.get("boss_met", [])
	boss_force = String(config.get("boss_force", ""))
	boss_force_own_pool = bool(config.get("boss_force_own_pool", false))
	routes_enabled = bool(config.get("routes", false))
	world = String(config.get("world", "wall"))
	true_path = bool(config.get("true_path", false))
	rush = []
	for id: String in config.get("rush", []):
		rush.append(id)
	fever = false
	attack_element = String(Balls.BALLS.get(ball_type, {}).get("element", ""))
	second_ball = String(config.get("second_ball", ""))
	if not Balls.BALLS.has(second_ball) or second_ball == ball_type:
		second_ball = ""
	_second_element = String(Balls.BALLS[second_ball].get("element", "")) if second_ball != "" else ""
	bonus_shots = 0
	route_options = []
	event = {}
	relics = []
	_next_stage_hp = 1.0
	_next_stage_coins = 1.0
	_stage_hp_mult = 1.0
	_stage_coin_mult = 1.0
	_companion_hits = 0
	missions = []
	_base_stats = _build_base_stats(config)
	_coin_scale = Tiers.coin_scale(tier) * (1.0 + STAR_COINS * int(config.get("stars", 0)))
	launch_x = FIELD_X + FIELD_W / 2.0
	choices = []
	picks_pending = 0
	events = []
	coins = 0
	combo = 0
	best_combo = 0
	total_damage = 0
	shot_damage = 0
	best_shot_damage = 0
	shots = 0
	sim_time = 0.0
	bonus_balls = 0
	counters = {"kills": 0, "explosions": 0, "splits": 0, "crits": 0, "poison_damage": 0, "bosses": 0, "treasures": 0, "evolutions": 0, "bursts": 0, "overkills": 0, "style_s": 0, "awakened": 0, "bounties": 0, "fevers": 0}
	last_shot_score = 0.0
	last_shot_rank = 0
	_style_total = 0.0
	_style_shots = 0
	_burst_shot = false
	_burst_shot_gain = 0.0
	_accumulator = 0.0
	_coin_carry = 0.5
	_next_block_id = 1
	_stages_cleared = 0
	_offered_evolutions = {}
	death_row = DEATH_ROW - 1 if Tiers.has_rule(tier, "shorter_field") else DEATH_ROW
	_recompute_stats()
	burst_charge = minf(BURST_START + stat("burst_start"), 1.0)
	rerolls = int(stat("rerolls"))
	if Tiers.has_rule(tier, "no_free_reroll"):
		rerolls = 0
	guards = maxi(int(stat("guards")), 0)
	rerolls = maxi(rerolls, 0)
	if bool(config.get("missions", false)):
		_roll_missions()
	var start_picks := int(stat("start_perks"))
	if _tutorial_offer:
		start_picks = 0
	_start_stage()
	if start_picks > 0:
		picks_pending = start_picks
		_open_upgrade()


func stat(key: String) -> float:
	return float(stats.get(key, 0.0))


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(FIELD_X + cell.x * CELL_W + 3.0, FIELD_Y + cell.y * CELL_H + 3.0, CELL_W - 6.0, CELL_H - 6.0)


## Outer rectangle of the block on this cell; bosses span several cells.
func block_rect(block: Dictionary) -> Rect2:
	var origin: Vector2i = block["origin"]
	var size: Vector2i = block["size"]
	return Rect2(
		FIELD_X + origin.x * CELL_W + 3.0,
		FIELD_Y + origin.y * CELL_H + 3.0,
		size.x * CELL_W - 6.0,
		size.y * CELL_H - 6.0
	)


func unique_blocks() -> Array[Dictionary]:
	var seen := {}
	var list: Array[Dictionary] = []
	for cell: Vector2i in blocks:
		var block: Dictionary = blocks[cell]
		if not seen.has(block["id"]):
			seen[block["id"]] = true
			list.append(block)
	return list


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
	_launch_left = shot_ball_count()
	_launch_timer = 0.0
	_next_launch_x = -1.0
	_shot_time = 0.0
	_floor_bounces_left = int(stat("floor_bounces"))
	_burst_shot_gain = 0.0
	combo = 0
	shot_damage = 0
	shots += 1
	fever = false
	_shot_start_blocks = maxi(unique_blocks().size(), 1)
	_shot_start_kills = int(counters["kills"])
	_shot_balls = shot_ball_count()
	_shot_start_boss_hp = 0 if boss_block == null else int((boss_block as Dictionary)["hp"])
	_shot_boss_max_hp = 0 if boss_block == null else int((boss_block as Dictionary)["max_hp"])
	_emit({"type": "fire"})
	return true


func can_burst() -> bool:
	return state == State.AIM and burst_charge >= 1.0


## Spends a full gauge on the ball type's special move. It costs no turn: blocks stay put.
func trigger_burst() -> bool:
	if not can_burst():
		return false
	burst_charge = 0.0
	counters["bursts"] += 1
	state = State.SHOOT
	_burst_shot = true
	_launch_left = 0
	_next_launch_x = -1.0
	_shot_time = 0.0
	combo = 0
	shot_damage = 0
	match ball_type:
		"iron":
			_burst_meteor()
		"fire":
			_burst_inferno()
		"splitter":
			_burst_rain()
		"blaster":
			_burst_chain()
		"ghost":
			_queue_burst_wave(0.22, 0.06, 0.0)
			_queue_burst_wave(0.22, 0.06, 0.5)
		"lucky":
			_queue_burst_wave(0.4, 0.12, 0.0)
			for block in unique_blocks():
				_grant_coins(8.0 + 4.0 * stage)
		"titan":
			_burst_titanfall()
		_:
			_queue_burst_wave(0.4, 0.12, 0.0)
	_emit({"type": "burst", "ball": ball_type})
	return true


func _queue_burst_wave(share: float, boss_share: float, delay: float) -> void:
	for block in unique_blocks():
		_queue_burst_hit(block, share, boss_share, delay)


## One hit of the expanding shockwave: it reaches blocks further from the launcher later.
func _queue_burst_hit(block: Dictionary, share: float, boss_share: float, delay := 0.0) -> void:
	var center := block_rect(block).get_center()
	var travel := center.distance_to(Vector2(launch_x, LAUNCH_Y)) / BURST_WAVE_SPEED
	var used := boss_share if block["kind"] == "boss" else share
	_pending_blasts.append({"burst": true, "cell": block["origin"], "t": delay + travel, "damage": float(block["max_hp"]) * used, "radius": 1})


func _burst_meteor() -> void:
	var columns: Array[int] = []
	for col in COLS:
		columns.append(col)
	for i in 5:
		columns.remove_at(_rng.randi_range(0, columns.size() - 1))
	for block in unique_blocks():
		var origin: Vector2i = block["origin"]
		var size: Vector2i = block["size"]
		for x in range(origin.x, origin.x + size.x):
			if columns.has(x):
				_queue_burst_hit(block, 1.0, 0.15)
				break


func _burst_inferno() -> void:
	for block in unique_blocks():
		block["poison"] = int(block["poison"]) + 10 + stage * 6
		block["burning"] = true
	_queue_burst_wave(0.25, 0.08, 0.0)


func _burst_rain() -> void:
	var power := (2.0 + stage) * sqrt(Tiers.hp_scale(tier))
	for i in BURST_RAIN_BALLS:
		if balls.size() >= MAX_BALLS:
			break
		var ball := Ball.new()
		ball.pos = Vector2(_rng.randf_range(FIELD_X + 20.0, FIELD_X + FIELD_W - 20.0), FIELD_Y + ball_radius + 2.0)
		ball.vel = Vector2.DOWN.rotated(_rng.randf_range(-0.6, 0.6)) * ball_speed
		ball.temp = true
		ball.hits = 1
		ball.wall_bonus = power
		balls.append(ball)


func _burst_chain() -> void:
	for block in unique_blocks():
		if block["kind"] != "boss":
			block["kind"] = "bomb"
	_queue_burst_wave(0.35, 0.1, 0.0)


func _burst_titanfall() -> void:
	var from_row := _lowest_row() - 2
	for block in unique_blocks():
		var origin: Vector2i = block["origin"]
		var size: Vector2i = block["size"]
		if origin.y + size.y - 1 >= from_row:
			_queue_burst_hit(block, 1.0, 0.15)
		elif block["kind"] == "boss":
			_queue_burst_hit(block, 0.0, 0.1)


func shot_ball_count() -> int:
	return maxi(ball_count + bonus_balls, 1)


func choose_upgrade(id: String) -> bool:
	if state != State.UPGRADE or not choices.has(id):
		return false
	levels[id] += 1
	if Perks.is_evolution(id):
		counters["evolutions"] += 1
	_recompute_stats()
	if int(Perks.PERKS[id]["add"].get("rerolls", 0.0)) > 0:
		rerolls += 1
	if int(Perks.PERKS[id]["add"].get("guards", 0.0)) > 0:
		guards += 1
	_emit({"type": "perk_taken", "id": id})
	choices = []
	picks_pending -= 1
	if picks_pending > 0:
		_open_upgrade()
		return true
	_leave_stage()
	return true


## After the picks: on to the next stage, by way of a choice of road when routes are on.
func _leave_stage() -> void:
	if not _is_stage_finished():
		state = State.AIM
		return
	if routes_enabled and stage < _final_stage():
		route_options = _roll_routes()
		state = State.ROUTE
		_emit({"type": "route"})
		return
	_go_to_next_stage()


func _go_to_next_stage() -> void:
	stage += 1
	_start_stage()
	state = State.AIM


func _final_stage() -> int:
	return stage_total() - 1


func _roll_routes() -> Array[String]:
	var options: Array[String] = []
	var pool := RunContent.ids_of(RunContent.ROUTES)
	while options.size() < 2:
		var total := 0.0
		for id in pool:
			total += float(RunContent.ROUTES[id]["weight"])
		var roll := _rng.randf() * total
		for id in pool:
			roll -= float(RunContent.ROUTES[id]["weight"])
			if roll <= 0.0:
				options.append(id)
				pool.erase(id)
				break
	return options


func choose_route(id: String) -> bool:
	if state != State.ROUTE or not route_options.has(id):
		return false
	route_options = []
	match id:
		"danger":
			_next_stage_hp = RunContent.DANGER_HP
			_next_stage_coins = RunContent.DANGER_COINS
			_go_to_next_stage()
		"altar":
			_open_altar()
		"merchant":
			_open_merchant()
		"shrine":
			_open_shrine()
		"treasure":
			_grant_coins(RunContent.TREASURE_COINS * (stage + 1.0))
			_open_relic_choice()
		"bonus":
			_start_bonus()
		"forge":
			_open_forge()
		_:
			_go_to_next_stage()
	return true


func _start_bonus() -> void:
	blocks = {}
	obstacles = {}
	balls = []
	modifier = ""
	waves_left = 0
	_formation_rows = []
	bonus_shots = RunContent.BONUS_SHOTS
	for row in 6:
		for col in COLS:
			if (col + row) % 2 == 0:
				var cell := Vector2i(col, row)
				var block := _new_block(_block_hp(float(stage_cfg()["hp_min"])), "coin", cell)
				block["shape"] = "round"
				blocks[cell] = block
	state = State.AIM
	_emit({"type": "bonus_start"})


## Bonus stages have no threat: a few shots, then on to the next stage.
func _bonus_turn() -> bool:
	if bonus_shots <= 0:
		return false
	bonus_shots -= 1
	if bonus_shots <= 0 or blocks.is_empty():
		bonus_shots = 0
		blocks = {}
		_emit({"type": "bonus_end"})
		_go_to_next_stage()
	else:
		state = State.AIM
	return true


func _open_forge() -> void:
	var owned: Array[String] = []
	for id in Perks.ids():
		if int(levels[id]) > 0 and not Perks.is_evolution(id) and not Perks.is_curse(id):
			owned.append(id)
	var options: Array[Dictionary] = []
	for i in mini(RunContent.FORGE_OFFERS, owned.size()):
		options.append({"forge": owned.pop_at(_rng.randi_range(0, owned.size() - 1))})
	_open_event("forge", options)


## Melts a level of one perk down into a fresh perk at least as rare.
func _reforge(id: String) -> void:
	levels[id] = int(levels[id]) - 1
	var rarity: int = Perks.PERKS[id]["rarity"]
	var pool: Array[String] = []
	for other in Perks.ids():
		if other != id and _is_perk_available(other) and int(Perks.PERKS[other]["rarity"]) >= rarity:
			pool.append(other)
	_recompute_stats()
	if not pool.is_empty():
		_take_perk(pool[_rng.randi_range(0, pool.size() - 1)])


func _open_event(kind: String, options: Array[Dictionary], extra := {}) -> void:
	if options.is_empty():
		_go_to_next_stage()
		return
	event = {"kind": kind, "options": options}
	event.merge(extra)
	state = State.EVENT


func _open_altar() -> void:
	var options: Array[Dictionary] = []
	var pool := Perks.curses().filter(func(id: String) -> bool: return int(levels[id]) <= 0)
	for i in mini(3, pool.size()):
		options.append({"perk": pool.pop_at(_rng.randi_range(0, pool.size() - 1))})
	_open_event("altar", options)


func _open_merchant() -> void:
	var options: Array[Dictionary] = []
	var offer := _roll_choices()
	for id in offer.slice(0, RunContent.MERCHANT_OFFERS):
		options.append({"perk": id, "cost": merchant_price(id)})
	_open_event("merchant", options)


func merchant_price(id: String) -> int:
	return int(RunContent.MERCHANT_PRICE * (1 + int(Perks.PERKS[id]["rarity"])) * (stage + 1) * _coin_scale)


func _open_relic_choice() -> void:
	if relics.size() >= RunContent.MAX_RELICS:
		_go_to_next_stage()
		return
	var pool := RunContent.ids_of(RunContent.RELICS).filter(func(id: String) -> bool: return not relics.has(id))
	var options: Array[Dictionary] = []
	for i in mini(3, pool.size()):
		options.append({"relic": pool.pop_at(_rng.randi_range(0, pool.size() - 1))})
	_open_event("relic", options)


func _open_shrine() -> void:
	var kind: String = RunContent.SHRINES[_rng.randi_range(0, RunContent.SHRINES.size() - 1)]
	var options: Array[Dictionary] = [{"shrine": kind, "choice": "a"}]
	if kind == "rest":
		options.append({"shrine": kind, "choice": "b"})
	_open_event("shrine", options, {"shrine": kind})


## Takes one of the event's options. Returns false when it cannot be afforded.
func choose_event(index: int) -> bool:
	if state != State.EVENT or index < 0 or index >= (event["options"] as Array).size():
		return false
	var option: Dictionary = event["options"][index]
	if int(option.get("cost", 0)) > coins:
		return false
	coins -= int(option.get("cost", 0))
	if option.has("perk"):
		_take_perk(option["perk"])
	elif option.has("relic"):
		take_relic(option["relic"])
	elif option.has("shrine"):
		_resolve_shrine(option["shrine"], option["choice"])
	elif option.has("forge"):
		_reforge(option["forge"])
	if event.get("kind") == "merchant":
		(event["options"] as Array).remove_at(index)
		if not (event["options"] as Array).is_empty():
			return true
	leave_event()
	return true


func leave_event() -> void:
	if state != State.EVENT:
		return
	event = {}
	_go_to_next_stage()


func _take_perk(id: String) -> void:
	levels[id] += 1
	_recompute_stats()
	guards = maxi(guards + int(Perks.PERKS[id]["add"].get("guards", 0.0)), 0)
	_emit({"type": "perk_taken", "id": id})


func completed_sets() -> Array[String]:
	var done: Array[String] = []
	for set_id: String in RunContent.RELIC_SETS:
		var whole := true
		for relic: String in RunContent.RELIC_SETS[set_id]["relics"]:
			whole = whole and relics.has(relic)
		if whole:
			done.append(set_id)
	return done


## The set a relic would complete right now, for the choice screen to point out.
func set_completed_by(id: String) -> String:
	for set_id: String in RunContent.RELIC_SETS:
		var parts: Array = RunContent.RELIC_SETS[set_id]["relics"]
		if parts.has(id) and not completed_sets().has(set_id):
			var missing := 0
			for relic: String in parts:
				missing += 0 if relics.has(relic) or relic == id else 1
			if missing == 0:
				return set_id
	return ""


func take_relic(id: String) -> void:
	if relics.size() >= RunContent.MAX_RELICS or relics.has(id):
		return
	var completes := set_completed_by(id)
	relics.append(id)
	if completes != "":
		_emit({"type": "relic_set", "id": completes})
	_recompute_stats()
	guards = maxi(guards + int(RunContent.RELICS[id]["add"].get("guards", 0.0)), 0)
	_emit({"type": "relic", "id": id})


func _resolve_shrine(kind: String, choice: String) -> void:
	match kind:
		"offering":
			coins -= int(coins * RunContent.OFFERING_COST)
			var pool: Array[String] = []
			for id in Perks.ids():
				if _is_perk_available(id) and int(Perks.PERKS[id]["rarity"]) >= Perks.RARE:
					pool.append(id)
			if not pool.is_empty():
				_take_perk(pool[_rng.randi_range(0, pool.size() - 1)])
		"gamble":
			var won := _rng.randf() < 0.5
			coins = int(coins * (RunContent.GAMBLE_WIN if won else RunContent.GAMBLE_LOSS))
			_emit({"type": "gamble", "won": won})
		"pact":
			var curses := Perks.curses().filter(func(id: String) -> bool: return int(levels[id]) <= 0)
			if not curses.is_empty():
				_take_perk(curses[_rng.randi_range(0, curses.size() - 1)])
			var relic_pool := RunContent.ids_of(RunContent.RELICS).filter(func(id: String) -> bool: return not relics.has(id))
			if not relic_pool.is_empty():
				take_relic(relic_pool[_rng.randi_range(0, relic_pool.size() - 1)])
		"rest":
			if choice == "a":
				burst_charge = 1.0
			else:
				guards += 1
		"mirror":
			var owned: Array[String] = []
			for id in Perks.ids():
				if int(levels[id]) > 0 and int(levels[id]) < int(Perks.PERKS[id]["max"]):
					owned.append(id)
			if not owned.is_empty():
				_take_perk(owned[_rng.randi_range(0, owned.size() - 1)])


func _roll_missions() -> void:
	var pool := RunContent.ids_of(RunContent.MISSIONS)
	missions = []
	for i in RunContent.MISSIONS_PER_RUN:
		var id: String = pool.pop_at(_rng.randi_range(0, pool.size() - 1))
		missions.append({"stat": id, "target": RunContent.MISSIONS[id]["target"], "done": false})


func mission_progress(mission: Dictionary) -> float:
	return clampf(float(counters.get(mission["stat"], 0)) / float(mission["target"]), 0.0, 1.0)


func _check_missions() -> void:
	for mission in missions:
		if mission["done"] or mission_progress(mission) < 1.0:
			continue
		mission["done"] = true
		var reward := _grant_coins(float(RunContent.MISSIONS[mission["stat"]]["reward"]) * (stage + 1))
		_emit({"type": "mission", "stat": mission["stat"], "coins": reward})


func reroll_choices() -> bool:
	if state != State.UPGRADE or rerolls <= 0:
		return false
	rerolls -= 1
	# Rerolling for a better second card should not throw away an evolution on the table.
	var keep: Array[String] = []
	for id in choices:
		if Perks.is_evolution(id):
			keep.append(id)
	choices = _roll_choices(keep)
	_emit({"type": "reroll"})
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
		if p.x < FIELD_X + ball_radius or p.x > FIELD_X + FIELD_W - ball_radius:
			d.x = -d.x
			points.append(p)
		if p.y < FIELD_Y + ball_radius:
			d.y = -d.y
			points.append(p)
		if _cell_at_circle(p, -1) != NO_CELL or _obstacle_touches(p):
			break
	points.append(p)
	return points


func _build_base_stats(config: Dictionary) -> Dictionary:
	var base := {}
	var ball: Dictionary = Balls.BALLS.get(ball_type, Balls.BALLS["normal"])
	_add_stats(base, ball["add"], 1)
	base["ball_count"] = float(ball["count"])
	var second := String(config.get("second_ball", ""))
	if Balls.BALLS.has(second) and second != ball_type:
		# A second ball type brings half its strengths and half its count.
		var other: Dictionary = Balls.BALLS[second]
		for key: String in other["add"]:
			base[key] = float(base.get(key, 0.0)) + float(other["add"][key]) * 0.5
		base["ball_count"] = float(base["ball_count"]) + int(other["count"]) / 2
	var mastery: int = config.get("mastery", 0)
	_add_stats(base, ball["mastery"], mastery)
	base["ball_count"] = float(base["ball_count"]) + mastery / Balls.MASTERY_BALL_EVERY
	var shop: Dictionary = config.get("shop", {})
	for id: String in shop:
		if Shop.ITEMS.has(id):
			Shop.apply(base, id, int(shop[id]))
	_add_stats(base, RunContent.CONTRACTS.get(config.get("contract", "none"), RunContent.CONTRACTS["none"])["add"], 1)
	_add_stats(base, RunContent.PILOTS.get(config.get("pilot", "rookie"), RunContent.PILOTS["rookie"])["add"], 1)
	var star_nodes: Dictionary = config.get("star_nodes", {})
	for id: String in star_nodes:
		if StarTree.NODES.has(id):
			_add_stats(base, StarTree.NODES[id]["add"], int(star_nodes[id]))
	base["damage_pct"] = float(base.get("damage_pct", 0.0))
	base["star_mult"] = 1.0 + STAR_DAMAGE * int(config.get("stars", 0))
	if Tiers.has_rule(tier, "fewer_balls"):
		base["ball_count"] = float(base["ball_count"]) - 1.0
	if Tiers.has_rule(tier, "extra_wave"):
		base["wave_delta"] = float(base.get("wave_delta", 0.0)) + 1.0
	if Tiers.has_rule(tier, "fewer_choices"):
		base["extra_choices"] = float(base.get("extra_choices", 0.0)) - 1.0
	return base


func _add_stats(target: Dictionary, add: Dictionary, times: int) -> void:
	for key: String in add:
		target[key] = float(target.get(key, 0.0)) + float(add[key]) * times


func _recompute_stats() -> void:
	stats = _base_stats.duplicate()
	for id: String in levels:
		var level: int = levels[id]
		if level > 0:
			_add_stats(stats, Perks.PERKS[id]["add"], level)
	for relic in relics:
		_add_stats(stats, RunContent.RELICS[relic]["add"], 1)
	for set_id in completed_sets():
		_add_stats(stats, RunContent.RELIC_SETS[set_id]["add"], 1)
	ball_count = maxi(int(stat("ball_count")), 1)
	ball_radius = minf(BALL_RADIUS + stat("radius"), MAX_RADIUS)
	ball_speed = BALL_SPEED * (1.0 + stat("speed_pct"))


## Where a stage's numbers come from, whichever kind of run this is.
func stage_cfg() -> Dictionary:
	if not rush.is_empty():
		var at := mini(stage, rush.size() - 1)
		return STAGES[RUSH_STAGE_POOL[int(Bosses.BOSSES[rush[at]]["pool"])]]
	return TRUE_STAGE if stage >= STAGES.size() else STAGES[stage]


func stage_total() -> int:
	if not rush.is_empty():
		return rush.size()
	return STAGES.size() + (1 if true_path else 0)


func is_boss_stage(index: int) -> bool:
	if not rush.is_empty() or index >= STAGES.size():
		return true
	return (STAGES[index] as Dictionary).has("boss")


func _start_stage() -> void:
	blocks = {}
	balls = []
	boss_block = null
	bonus_balls = 0
	_stage_hp_mult = _next_stage_hp
	_stage_coin_mult = _next_stage_coins
	_next_stage_hp = 1.0
	_next_stage_coins = 1.0
	_build_obstacles()
	_roll_modifier()
	_pending_blasts = []
	_launch_left = 0
	var cfg: Dictionary = stage_cfg()
	waves_left = maxi(int(cfg["waves"]) + int(stat("wave_delta")), 0) if not cfg.has("boss") else 0
	var first_rows := int(cfg["rows"])
	_formation_rows = Formations.queue_for(first_rows + waves_left, _rng)
	_apply_world_elements()
	# The bottom of the picture goes in first, with the rest following it down as waves.
	var top := BOSS_SIZE.y + 1 if cfg.has("boss") else 0
	if cfg.has("boss"):
		_spawn_boss(cfg["boss"])
	for i in first_rows:
		_spawn_row(top + first_rows - 1 - i)
	_maybe_spawn_bounty()
	_emit({"type": "stage_start", "stage": stage, "boss": cfg.has("boss"), "boss_id": boss_id()})


func _roll_modifier() -> void:
	modifier = ""
	if stage == 0 or stage_cfg().has("boss") or not rush.is_empty() or _rng.randf() >= MODIFIER_CHANCE:
		return
	modifier = MODIFIERS[_rng.randi_range(0, MODIFIERS.size() - 1)]
	wind = 1.0 if _rng.randf() < 0.5 else -1.0
	var free: Array[Vector2i] = []
	for y in range(7, 10):
		for x in range(1, COLS - 1):
			if not obstacles.has(Vector2i(x, y)):
				free.append(Vector2i(x, y))
	well = cell_rect(free[_rng.randi_range(0, free.size() - 1)]).get_center()


func _build_obstacles() -> void:
	obstacles = {}
	var layouts := Layouts.for_stage(stage)
	if layouts.is_empty():
		return
	var layout: Array = layouts[_rng.randi_range(0, layouts.size() - 1)]
	if _rng.randf() < 0.5:
		layout = Layouts.mirrored(layout)
	var portal: Variant = null
	for piece: Array in layout:
		var cell := Vector2i(piece[1], piece[2])
		var entry := {"kind": piece[0], "cell": cell, "dir": 1 if _rng.randf() < 0.5 else -1, "pulse": 0.0, "open": false, "hits": KEY_HITS}
		obstacles[cell] = entry
		if piece[0] == "portal":
			if portal == null:
				portal = entry
			else:
				entry["partner"] = portal["cell"]
				portal["partner"] = cell


func _block_hp(base: float) -> int:
	var scaled := base * Tiers.hp_scale(tier) * (1.0 - minf(stat("hp_reduction"), 0.5)) * _stage_hp_mult
	return maxi(int(ceil(scaled)), 1)


func _new_block(hp: int, kind: String, origin: Vector2i, size := Vector2i.ONE) -> Dictionary:
	var block := {
		"id": _next_block_id,
		"hp": hp,
		"max_hp": hp,
		"kind": kind,
		"origin": origin,
		"size": size,
		"poison": 0,
		"burning": false,
		"slid": true,
		"shape": "box",
	}
	_next_block_id += 1
	return block


func boss_id() -> String:
	return "" if boss_block == null else String((boss_block as Dictionary)["boss_id"])


## Bosses the player has not met yet come first, so the whole cast shows up quickly.
## The part a boss's trick depends on. It rides beside the boss until it is broken.
func _spawn_part(boss: Dictionary) -> void:
	var cell: Vector2i = (boss["origin"] as Vector2i) + PART_POST
	if cell.x >= COLS or blocks.has(cell):
		return
	var part := _new_block(_block_hp(float(stage_cfg()["hp_max"]) * PART_HP), "part", cell)
	part["post"] = PART_POST
	part["part_of"] = boss["boss_id"]
	blocks[cell] = part
	boss["part"] = part


func pool_rolls(chance: float) -> bool:
	return _rng.randf() < chance


## The second boss of a double battle stands beside the first and shields it until it falls.
func _spawn_partner(boss: Dictionary, partner: String, boss_hp: int) -> void:
	var at := Vector2i(COLS - BOSS_SIZE.x, 0)
	var ally := _new_block(maxi(int(boss_hp * ALLY_HP), 1), "normal", at, BOSS_SIZE)
	ally["post"] = at - (boss["origin"] as Vector2i)
	ally["ally_id"] = partner
	for y in BOSS_SIZE.y:
		for x in BOSS_SIZE.x:
			blocks[at + Vector2i(x, y)] = ally
	boss["guards"] = [ally]
	_boss_action("guards", {"targets": [block_rect(ally).get_center()]})


func _pick_boss(pool: int) -> String:
	if boss_force != "" and (not boss_force_own_pool or int(Bosses.BOSSES[boss_force]["pool"]) == pool):
		return boss_force
	if not rush.is_empty():
		return rush[mini(stage, rush.size() - 1)]
	var options := Bosses.in_pool(pool, tier)
	var fresh := options.filter(func(id: String) -> bool: return not _boss_met.has(id))
	var from: Array = fresh if not fresh.is_empty() else options
	return String(from[_rng.randi_range(0, from.size() - 1)])


func _spawn_boss(cfg: Dictionary) -> void:
	var id := _pick_boss(int(cfg["pool"]))
	var data: Dictionary = Bosses.BOSSES[id]
	var scale := 2.0 if Tiers.has_rule(tier, "boss_hp") else 1.0
	var awakened := tier >= Bosses.AWAKENED_MIN_TIER and pool_rolls(Bosses.AWAKENED_CHANCE)
	if awakened:
		scale *= Bosses.AWAKENED_HP
	var hp := _block_hp(float(cfg["hp"]) * float(data["hp"]) * scale)
	var partner := ""
	if int(cfg["pool"]) == 1 and tier >= Bosses.DUO_MIN_TIER and Bosses.PARTNERS.has(id) and pool_rolls(Bosses.DUO_CHANCE):
		partner = Bosses.PARTNERS[id]
	var origin := Vector2i((COLS - BOSS_SIZE.x) / 2 if partner == "" else 0, 0)
	var block := _new_block(hp, "boss", origin, BOSS_SIZE)
	block["boss_id"] = id
	block["summon"] = int(data["summon"]) + (1 if awakened else 0)
	block["awakened"] = awakened
	block["minion"] = data["minion"]
	block["every"] = maxi(int(cfg["every"]) - (1 if awakened else 0), 1)
	block["age"] = 0
	block["angry"] = false
	block["next_split"] = 1.0 - SLIME_STEP
	block["dir"] = 1 if _rng.randf() < 0.5 else -1
	block["guards"] = []
	block["guard_wait"] = 0
	block["aim_cols"] = []
	block["veil"] = false
	block["broken"] = false
	block["reborn"] = false
	boss_block = block
	for y in BOSS_SIZE.y:
		for x in BOSS_SIZE.x:
			blocks[origin + Vector2i(x, y)] = block
	if id == "gantetsu":
		_spawn_guards(block)
	if partner != "":
		_spawn_partner(block, partner, hp)
	if PART_BOSSES.has(id):
		_spawn_part(block)


## Whole pictures share an element, so a chapter's colours arrive in readable groups.
func _apply_world_elements() -> void:
	var element: String = Worlds.WORLDS.get(world, Worlds.WORLDS["wall"])["element"]
	if element == "":
		return
	var current := false
	for entry in _formation_rows:
		if int(entry["index"]) == int(entry["height"]) - 1:
			current = _rng.randf() < Worlds.ELEMENT_CHANCE
		if current:
			entry["element"] = element


func _spawn_row(row: int) -> void:
	if _formation_rows.is_empty():
		_formation_rows = Formations.queue_for(1, _rng)
	var entry: Dictionary = _formation_rows.pop_front()
	var cfg: Dictionary = stage_cfg()
	var pattern: String = entry["row"]
	var kinds := {}
	for col in COLS:
		var letter := pattern[col]
		if letter == "." or letter == "+":
			continue
		var size := Formations.size_of(letter)
		# A picture's left half decides, and the right half copies it.
		var mirror := mini(col, COLS - 1 - col)
		if size == Vector2i.ONE and not kinds.has(mirror):
			kinds[mirror] = _roll_block_kind(cfg["specials"])
		var kind: String = kinds[mirror] if size == Vector2i.ONE else "normal"
		# The centre of a row is the natural seat for a tougher, richer block.
		if col == COLS / 2 and size == Vector2i.ONE and stage > 0 and rush.is_empty() and _rng.randf() < ELITE_CHANCE:
			kind = "elite"
		_place_formation_block(Vector2i(col, row), size, kind, entry, cfg)
	_maybe_chain_row(row)


## Ties a mirrored pair of plain blocks together: damage to one is shared with the other.
func _maybe_chain_row(row: int) -> void:
	if stage < 2 or _rng.randf() >= CHAIN_CHANCE:
		return
	for col in range(0, COLS / 2):
		var a: Variant = blocks.get(Vector2i(col, row))
		var b: Variant = blocks.get(Vector2i(COLS - 1 - col, row))
		if a == null or b == null:
			continue
		if a["kind"] != "normal" or b["kind"] != "normal" or a["size"] != Vector2i.ONE or b["size"] != Vector2i.ONE:
			continue
		a["link"] = b["id"]
		b["link"] = a["id"]
		return


func block_by_id(id: int) -> Variant:
	for block in unique_blocks():
		if int(block["id"]) == id:
			return block
	return null


## `origin` is the cell a pattern letter sits on, and a tall block grows upward from the row
## it arrived on, since rows above it have not come down yet.
func _place_formation_block(cell: Vector2i, size: Vector2i, kind: String, entry: Dictionary, cfg: Dictionary) -> void:
	var origin := Vector2i(cell.x, maxi(cell.y - size.y + 1, 0))
	for y in size.y:
		for x in size.x:
			var covered := origin + Vector2i(x, y)
			if covered.x >= COLS or blocks.has(covered) or obstacles.has(covered):
				return
	var strength := Formations.toughness(cell.x + (size.x - 1) / 2.0, int(entry["index"]), int(entry["height"]), int(entry["mode"]))
	var hp := _block_hp(lerpf(float(cfg["hp_min"]), float(cfg["hp_max"]), strength) * size.x * size.y)
	if kind == "elite":
		hp = int(hp * ELITE_HP)
	if kind == "treasure" or kind == "extra_ball":
		hp = maxi(hp / 2, 1)
	if kind == "shield":
		# Shields ignore damage size, so they count hits instead of absorbing HP.
		hp = 3 + (mini(cell.x, COLS - 1 - cell.x) + cell.y) % 4 + stage
	var block := _new_block(hp, kind, origin, size)
	block["shape"] = _shape_at(entry["shape"], cell)
	var element: String = entry.get("element", "")
	if element != "":
		block["element"] = element
	for y in size.y:
		for x in size.x:
			blocks[origin + Vector2i(x, y)] = block


func _shape_at(shape: String, cell: Vector2i) -> String:
	if shape != "tri":
		return shape
	return "tri_up" if (cell.x + cell.y) % 2 == 0 else "tri_down"


## A lone block for a boss to summon, outside any formation.
func _place_block(cell: Vector2i) -> bool:
	if blocks.has(cell) or obstacles.has(cell):
		return false
	var cfg: Dictionary = stage_cfg()
	var kind := _roll_block_kind(cfg["specials"])
	var hp := _block_hp(_rng.randf_range(float(cfg["hp_min"]), float(cfg["hp_max"])))
	if kind == "treasure" or kind == "extra_ball":
		hp = maxi(hp / 2, 1)
	if kind == "shield":
		hp = _rng.randi_range(3, 6) + stage
	blocks[cell] = _new_block(hp, kind, cell)
	return true


func _roll_block_kind(specials: Dictionary) -> String:
	var roll := _rng.randf()
	var edge := 0.0
	var special_scale := 1.5 if Tiers.has_rule(tier, "more_specials") else 1.0
	for kind: String in specials:
		var chance: float = float(specials[kind]) * special_scale
		if kind == "bomb" and Tiers.has_rule(tier, "fewer_bombs"):
			chance *= 0.5
		if kind == "treasure":
			chance += stat("treasure_rate")
		if kind == "extra_ball":
			chance += stat("extra_ball_rate")
		edge += chance
		if roll < edge:
			return kind
	return "normal"


func _fixed_step(dt: float) -> void:
	if state != State.SHOOT:
		return
	sim_time += dt
	_shot_time += dt
	# Long shots speed up so nobody waits on a lone stuck ball.
	var move_dt := dt * (1.0 + clampf((_shot_time - 3.5) / 4.0, 0.0, 2.0))
	_launch_step(dt)
	if _shot_time > RECALL_TIME:
		for ball in balls:
			ball.returning = true
	_blast_step(dt)
	var i := balls.size() - 1
	while i >= 0:
		if i < balls.size() and _move_ball(balls[i], move_dt):
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


func _is_stage_finished() -> bool:
	if not blocks.is_empty():
		return false
	return waves_left <= 0


func _launch_step(dt: float) -> void:
	if _launch_left <= 0:
		return
	_launch_timer -= dt
	if _launch_timer > 0.0:
		return
	_launch_timer = LAUNCH_INTERVAL / (1.0 + stat("launch_speed"))
	_launch_left -= 1
	var ball := Ball.new()
	ball.pos = Vector2(launch_x, LAUNCH_Y)
	ball.vel = _launch_dir * ball_speed
	ball.alt = second_ball != "" and _launch_left % 2 == 1
	balls.append(ball)


## Returns true when the ball is finished and should be removed.
func _move_ball(ball: Ball, dt: float) -> bool:
	if ball.returning:
		ball.vel = Vector2(0.0, ball_speed)
	elif modifier == "wind" or modifier == "gravity":
		ball.vel = (ball.vel + _field_force(ball.pos) * dt).normalized() * ball_speed
	ball.pos += ball.vel * dt
	if ball.ignore_t > 0.0:
		ball.ignore_t -= dt
		if ball.ignore_t <= 0.0:
			ball.ignore_id = -1
	ball.portal_t = maxf(ball.portal_t - dt, 0.0)
	var left := FIELD_X + ball_radius
	var right := FIELD_X + FIELD_W - ball_radius
	var top := FIELD_Y + ball_radius
	if ball.pos.x < left and ball.vel.x < 0.0:
		ball.pos.x = left
		ball.vel.x = -ball.vel.x
		_on_wall(ball, false)
	elif ball.pos.x > right and ball.vel.x > 0.0:
		ball.pos.x = right
		ball.vel.x = -ball.vel.x
		_on_wall(ball, false)
	if ball.pos.y < top and ball.vel.y < 0.0:
		ball.pos.y = top
		ball.vel.y = -ball.vel.y
		_on_wall(ball, true)
	if ball.pos.y >= LAUNCH_Y and ball.vel.y > 0.0:
		if not ball.returning and _try_rebound(ball):
			return false
		if not ball.temp and _next_launch_x < 0.0:
			_next_launch_x = clampf(ball.pos.x, FIELD_X + BALL_RADIUS, FIELD_X + FIELD_W - BALL_RADIUS)
		return true
	if not ball.returning:
		_collide_obstacles(ball)
		_collide_ball(ball)
		# Keep balls from skating sideways forever.
		if absf(ball.vel.y) < ball_speed * 0.12:
			var sign_y := -1.0 if ball.vel.y < 0.0 else 1.0
			ball.vel.y = sign_y * ball_speed * 0.12
			ball.vel = ball.vel.normalized() * ball_speed
	return false


## Wind and gravity bend paths without changing speed, so shots stay the same length.
func _field_force(p: Vector2) -> Vector2:
	if modifier == "wind":
		return Vector2(wind * WIND_FORCE, 0.0)
	var toward := well - p
	var distance := maxf(toward.length(), 1.0)
	return toward / distance * GRAVITY_FORCE * clampf(GRAVITY_REACH / distance, 0.0, 2.0)


func _try_rebound(ball: Ball) -> bool:
	var saved := false
	if _floor_bounces_left > 0:
		_floor_bounces_left -= 1
		saved = true
	elif _rng.randf() < stat("rebound_chance"):
		saved = true
	if saved:
		ball.pos.y = LAUNCH_Y
		ball.vel.y = -absf(ball.vel.y)
		_emit({"type": "rebound", "pos": ball.pos})
		if stat("floor_wall") > 0.0:
			_on_wall(ball, false)
	return saved


func _on_wall(ball: Ball, is_top: bool) -> void:
	ball.wall_bonus += stat("wall_damage")
	if is_top:
		ball.wall_bonus += stat("top_damage")
	if stat("first_refresh") > 0.0:
		ball.hits = 0
	_emit({"type": "wall", "pos": ball.pos})
	if stat("homing_chance") > 0.0 and _rng.randf() < stat("homing_chance") and not blocks.is_empty():
		var target := _nearest_block_center(ball.pos)
		var dir := (target - ball.pos).normalized()
		if dir != Vector2.ZERO:
			ball.vel = dir * ball_speed


func _nearest_block_center(from: Vector2) -> Vector2:
	var best := from
	var best_d := INF
	for cell: Vector2i in blocks:
		var c := cell_rect(cell).get_center()
		var d := from.distance_squared_to(c)
		if d < best_d:
			best_d = d
			best = c
	return best


## Finds a block touching the circle, skipping `ignore_id` so piercing balls don't re-hit.
func _cell_at_circle(p: Vector2, ignore_id: int, radius := -1.0) -> Vector2i:
	var r := ball_radius if radius < 0.0 else radius
	var col := int(floor((p.x - FIELD_X) / CELL_W))
	var row := int(floor((p.y - FIELD_Y) / CELL_H))
	for y in range(row - 1, row + 2):
		for x in range(col - 1, col + 2):
			var cell := Vector2i(x, y)
			if not blocks.has(cell):
				continue
			var block: Dictionary = blocks[cell]
			if int(block["id"]) == ignore_id:
				continue
			var rect := block_rect(block)
			var nearest := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
			if p.distance_squared_to(nearest) > r * r:
				continue
			if block.get("shape", "box") == "box" or not _shape_contact(block, p, r).is_empty():
				return cell
	return NO_CELL


## Where a circle touches a non-box block: {nearest, normal}, or empty when it misses.
func _shape_contact(block: Dictionary, p: Vector2, r: float) -> Dictionary:
	var rect := block_rect(block)
	if block["shape"] == "round":
		return _circle_contact(rect.get_center(), minf(rect.size.x, rect.size.y) / 2.0, p, r)
	return _polygon_contact(shape_points(rect, block["shape"]), p, r)


## The outline of a shape inside its rectangle, shared by collisions and drawing.
func shape_points(rect: Rect2, shape: String) -> PackedVector2Array:
	var l := rect.position.x
	var t := rect.position.y
	var r := rect.end.x
	var b := rect.end.y
	var cx := rect.get_center().x
	var cy := rect.get_center().y
	match shape:
		"diamond":
			return PackedVector2Array([Vector2(cx, t), Vector2(r, cy), Vector2(cx, b), Vector2(l, cy)])
		"hex":
			var inset := rect.size.x * 0.22
			return PackedVector2Array([Vector2(l + inset, t), Vector2(r - inset, t), Vector2(r, cy), Vector2(r - inset, b), Vector2(l + inset, b), Vector2(l, cy)])
		"tri_up":
			return PackedVector2Array([Vector2(cx, t), Vector2(r, b), Vector2(l, b)])
		"tri_down", "slope_flat":
			return PackedVector2Array([Vector2(l, t), Vector2(r, t), Vector2(cx, b)])
		"slope_l":
			return PackedVector2Array([rect.position, Vector2(r, t), Vector2(l, b)])
		"slope_r":
			return PackedVector2Array([rect.position, Vector2(r, t), rect.end])
		"pill":
			var points := PackedVector2Array()
			var radius := rect.size.y / 2.0
			for i in PILL_SEGMENTS + 1:
				points.append(Vector2(r - radius, cy) + Vector2.from_angle(-PI / 2.0 + PI * i / PILL_SEGMENTS) * radius)
			for i in PILL_SEGMENTS + 1:
				points.append(Vector2(l + radius, cy) + Vector2.from_angle(PI / 2.0 + PI * i / PILL_SEGMENTS) * radius)
			return points
	return PackedVector2Array([rect.position, Vector2(r, t), rect.end, Vector2(l, b)])


func _circle_contact(center: Vector2, radius: float, p: Vector2, r: float) -> Dictionary:
	var away := p - center
	if away.length() > radius + r:
		return {}
	var normal := away.normalized() if away.length_squared() > 0.0001 else Vector2.DOWN
	return {"nearest": center + normal * radius, "normal": normal}


func _polygon_contact(points: PackedVector2Array, p: Vector2, r: float) -> Dictionary:
	var best := Vector2.ZERO
	var best_d := INF
	for i in points.size():
		var on_edge := Geometry2D.get_closest_point_to_segment(p, points[i], points[(i + 1) % points.size()])
		var d := p.distance_squared_to(on_edge)
		if d < best_d:
			best_d = d
			best = on_edge
	var inside := Geometry2D.is_point_in_polygon(p, points)
	if not inside and best_d > r * r:
		return {}
	var normal := (best - p if inside else p - best)
	normal = normal.normalized() if normal.length_squared() > 0.0001 else Vector2.DOWN
	return {"nearest": best, "normal": normal}


func _obstacle_near(p: Vector2) -> Array:
	var found := []
	var col := int(floor((p.x - FIELD_X) / CELL_W))
	var row := int(floor((p.y - FIELD_Y) / CELL_H))
	for y in range(row - 1, row + 2):
		for x in range(col - 1, col + 2):
			if obstacles.has(Vector2i(x, y)):
				found.append(obstacles[Vector2i(x, y)])
	return found


## Solid pieces stop the aiming line. Portals are holes, so it passes over them.
func _obstacle_touches(p: Vector2) -> bool:
	for entry: Dictionary in _obstacle_near(p):
		if entry["kind"] != "portal" and not entry.get("open", false) and not _obstacle_contact(entry, p).is_empty():
			return true
	return false


func _obstacle_contact(entry: Dictionary, p: Vector2) -> Dictionary:
	var rect := cell_rect(entry["cell"])
	match String(entry["kind"]):
		"bumper":
			return _circle_contact(rect.get_center(), BUMPER_RADIUS, p, ball_radius)
		"ramp_l":
			return _polygon_contact(shape_points(rect, "slope_l"), p, ball_radius)
		"ramp_r":
			return _polygon_contact(shape_points(rect, "slope_r"), p, ball_radius)
	var nearest := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
	if p.distance_squared_to(nearest) > ball_radius * ball_radius:
		return {}
	var normal := p - nearest
	if normal.length_squared() < 0.0001:
		normal = Vector2.DOWN
	# Snap to an axis, like a block, so walls bounce the way they look.
	normal = Vector2(signf(normal.x), 0.0) if absf(normal.x) > absf(normal.y) else Vector2(0.0, signf(normal.y))
	return {"nearest": nearest, "normal": normal}


func _collide_obstacles(ball: Ball) -> void:
	for entry: Dictionary in _obstacle_near(ball.pos):
		if entry["kind"] == "portal":
			_try_portal(ball, entry)
			continue
		if entry.get("open", false):
			continue
		var contact := _obstacle_contact(entry, ball.pos)
		if contact.is_empty() or ball.vel.dot(contact["normal"]) >= 0.0:
			continue
		ball.vel = ball.vel.bounce(contact["normal"])
		ball.pos = contact["nearest"] + (contact["normal"] as Vector2) * (ball_radius + 0.5)
		entry["pulse"] = 1.0
		# Every surface counts as a wall, so bounce builds get to enjoy these too.
		_on_wall(ball, false)
		match String(entry["kind"]):
			"bumper":
				_emit({"type": "bumper", "pos": cell_rect(entry["cell"]).get_center()})
			"switch":
				_flip_gates(entry)
			"key":
				_hit_key(entry)


## Every gate on the stage changes at once, so one hit can open the way or shut it again.
func _flip_gates(switch_entry: Dictionary) -> void:
	for other: Dictionary in obstacles.values():
		if other["kind"] == "gate":
			other["open"] = not other["open"]
	_emit({"type": "switch", "pos": cell_rect(switch_entry["cell"]).get_center()})


func _hit_key(key: Dictionary) -> void:
	key["hits"] = int(key["hits"]) - 1
	if int(key["hits"]) > 0:
		return
	var opened: Array[Vector2] = []
	for cell: Vector2i in obstacles.keys():
		if obstacles[cell]["kind"] == "door" or obstacles[cell] == key:
			opened.append(cell_rect(cell).get_center())
			obstacles.erase(cell)
	_emit({"type": "unlock", "targets": opened})


func _try_portal(ball: Ball, entry: Dictionary) -> void:
	if ball.portal_t > 0.0 or not entry.has("partner"):
		return
	var center := cell_rect(entry["cell"]).get_center()
	if ball.pos.distance_to(center) > PORTAL_RADIUS:
		return
	var exit_at := cell_rect(entry["partner"]).get_center()
	_emit({"type": "portal", "from": center, "to": exit_at})
	ball.pos = exit_at
	ball.portal_t = PORTAL_COOLDOWN


func _collide_ball(ball: Ball) -> void:
	var cell := _cell_at_circle(ball.pos, ball.ignore_id)
	if cell == NO_CELL:
		return
	var block: Dictionary = blocks[cell]
	var pierced := _rng.randf() < stat("pierce_chance")
	if pierced:
		ball.ignore_id = block["id"]
		ball.ignore_t = 0.12
	else:
		var rect := block_rect(block)
		var nearest := Vector2(clampf(ball.pos.x, rect.position.x, rect.end.x), clampf(ball.pos.y, rect.position.y, rect.end.y))
		var normal := ball.pos - nearest
		if block.get("shape", "box") != "box":
			var contact := _shape_contact(block, ball.pos, ball_radius)
			nearest = contact["nearest"]
			normal = contact["normal"]
		else:
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
		ball.pos = nearest + normal * (ball_radius + 0.5)
	_hit_block_with_ball(cell, block, ball)
	_maybe_split(ball)


func _hit_block_with_ball(cell: Vector2i, block: Dictionary, ball: Ball) -> void:
	var damage := 1.0 + stat("flat_damage") + ball.wall_bonus
	damage += stat("combo_damage") * floorf(combo / 10.0)
	if ball.hits == 0:
		damage *= 1.0 + stat("first_strike")
	if ball.temp:
		damage *= 1.0 + stat("split_damage")
	ball.hits += 1
	var is_crit := _rng.randf() < stat("crit_chance")
	if is_crit:
		counters["crits"] += 1
		damage *= CRIT_BASE_MULT + stat("crit_mult")
		if stat("crit_shock") > 0.0:
			_strike_random(2, damage * 0.5)
		if stat("execute") > 0.0 and float(block["hp"]) / float(block["max_hp"]) < 0.3:
			damage = float(block["hp"]) * 2.0
	if stat("gamble") > 0.0:
		damage *= 3.0 if _rng.randf() < 0.5 else 0.5
	var poison := int(stat("poison"))
	if poison > 0:
		block["poison"] = int(block["poison"]) + poison
	if stat("burn_pct") > 0.0:
		block["burning"] = true
	var own_element := attack_element
	if ball.alt:
		attack_element = _second_element
	var scaled_damage := _scale_damage(damage, block)
	attack_element = own_element
	_damage_block(cell, scaled_damage, {"crit": is_crit})


## Multipliers shared by every damage source.
func _scale_damage(damage: float, block: Dictionary) -> float:
	var scaled := damage * (1.0 + stat("damage_pct")) * float(stats.get("star_mult", 1.0)) * float(stats.get("damage_mult", 1.0))
	scaled *= 1.0 + stat("momentum") * _stages_cleared
	if stat("finisher") > 0.0 and float(block["hp"]) / float(block["max_hp"]) < 0.3:
		scaled *= 1.0 + stat("finisher")
	if stat("opener") > 0.0 and int(block["hp"]) == int(block["max_hp"]):
		scaled *= 1.0 + stat("opener")
	if stat("last_stand") > 0.0 and _lowest_row() >= death_row - 3:
		scaled *= 2.0
	if stat("safe_damage") > 0.0:
		scaled *= 1.0 + stat("safe_damage") * maxi(death_row - _lowest_row() - 1, 0)
	if block["kind"] == "boss":
		scaled *= 1.0 + stat("boss_damage")
	scaled *= Worlds.multiplier(attack_element, block.get("element", ""))
	return scaled


func _lowest_row() -> int:
	var lowest := -1
	for cell: Vector2i in blocks:
		lowest = maxi(lowest, cell.y)
	return lowest


func _maybe_split(ball: Ball) -> void:
	var chance := stat("split_chance")
	if chance <= 0.0 or _rng.randf() >= chance:
		return
	var count := 1 + int(stat("split_count"))
	for i in count:
		if balls.size() >= MAX_BALLS:
			return
		var extra := Ball.new()
		extra.pos = ball.pos
		extra.vel = ball.vel.rotated(_rng.randf_range(-0.7, 0.7))
		extra.temp = true
		extra.wall_bonus = ball.wall_bonus
		extra.hits = 1
		balls.append(extra)
	counters["splits"] += 1
	_emit({"type": "split", "pos": ball.pos})
	if stat("cluster") > 0.0:
		var cell := _cell_at_circle(ball.pos, -1, ball_radius + 30.0)
		if cell != NO_CELL:
			_pending_blasts.append({"cell": cell, "t": CHAIN_DELAY, "damage": _blast_damage() * 0.5, "radius": 1})


func _damage_block(cell: Vector2i, raw_damage: float, flags := {}) -> void:
	if not blocks.has(cell):
		return
	var block: Dictionary = blocks[cell]
	var damage := raw_damage
	var is_burst: bool = flags.get("burst", false)
	if block["kind"] == "armor" and not is_burst:
		damage *= 0.5
	if block["kind"] == "shield" and not is_burst:
		damage = 1.0
	if block["kind"] == "boss" and not is_burst and is_boss_guarded():
		damage *= GUARDED_DAMAGE
	elif block["kind"] == "boss" and block["boss_id"] == "tsukuyo":
		damage *= TSUKUYO_EXPOSED
	var amount := maxi(int(ceil(damage)), 1)
	var dealt: int = mini(amount, int(block["hp"]))
	block["hp"] = int(block["hp"]) - amount
	total_damage += dealt
	shot_damage += dealt
	best_shot_damage = maxi(best_shot_damage, shot_damage)
	if not flags.get("dot", false):
		combo += 1
		best_combo = maxi(best_combo, combo)
		if combo >= FEVER_COMBO and not fever:
			fever = true
			counters["fevers"] += 1
			_emit({"type": "fever"})
		if not _burst_shot:
			_charge_burst()
			_companion_hit()
	if flags.get("poison", false):
		counters["poison_damage"] += dealt
	var center := block_rect(block).get_center()
	_emit({
		"type": "hit",
		"block_id": block["id"],
		"pos": center,
		"damage": dealt,
		"combo": combo,
		"crit": flags.get("crit", false),
		"dot": flags.get("dot", false),
	})
	if block.has("link") and not flags.get("linked", false):
		var twin: Variant = block_by_id(int(block["link"]))
		if twin != null:
			_damage_block(twin["origin"], amount * LINK_SHARE, {"dot": true, "linked": true})
	if int(block["hp"]) <= 0 and block["kind"] == "boss" and _try_rebirth(block):
		return
	if int(block["hp"]) <= 0:
		_kill_block(cell, block, flags, _overkill_steps(amount, block, flags))
	elif block["kind"] == "boss":
		_on_boss_hurt(block)


## The companion watches the ball work, and joins in every so often.
func _companion_hit() -> void:
	var level := stat("companion")
	if level <= 0.0:
		return
	_companion_hits += 1
	if _companion_hits < int(COMPANION_HITS / level):
		return
	_companion_hits = 0
	_strike_random(1, COMPANION_DAMAGE * (1.0 + stat("companion_damage")) + stat("flat_damage"))
	_emit({"type": "companion"})


func _charge_burst() -> void:
	var gain := minf(BURST_PER_HIT * (1.0 + stat("burst_gain")), BURST_SHOT_CAP - _burst_shot_gain)
	if gain <= 0.0:
		return
	_burst_shot_gain += gain
	burst_charge = minf(burst_charge + gain, 1.0)


## Direct hits only, and never a boss: this rewards outgrowing the small blocks.
func _overkill_steps(amount: int, block: Dictionary, flags: Dictionary) -> int:
	if block["kind"] == "boss" or flags.get("dot", false):
		return 0
	return mini(int(float(amount) / float(block["max_hp"]) / OVERKILL_RATIO), OVERKILL_MAX_STEPS)


func _kill_block(cell: Vector2i, block: Dictionary, flags: Dictionary, overkill := 0) -> void:
	var kind: String = block["kind"]
	_erase_block(block)
	counters["kills"] += 1
	var gained := 0.5
	if kind == "treasure":
		gained = 6.0 + stage * 3.0
		counters["treasures"] += 1
	if kind == "elite":
		gained = ELITE_COINS * (stage + 1)
	if kind == "coin":
		gained = RunContent.BONUS_COINS * (stage + 1)
	if block.has("part_of") and boss_block != null:
		var owner: Dictionary = boss_block
		owner["broken"] = true
		owner["hp"] = maxi(int(owner["hp"]) - int(float(owner["max_hp"]) * PART_BREAK_DAMAGE), 1)
		_emit({"type": "part_broken", "pos": block_rect(block).get_center(), "boss": owner["boss_id"]})
	if kind == "bounty":
		gained = BOUNTY_COINS * (stage + 1)
		counters["bounties"] += 1
	if kind == "boss":
		gained = 25.0 * (stage + 1) * (1.0 + stat("boss_coins"))
		counters["bosses"] += 1
		if block["awakened"]:
			gained *= Bosses.AWAKENED_COINS
			counters["awakened"] += 1
		if _rng.randf() < NOTE_CHANCE:
			_emit({"type": "note"})
		counters["boss_" + String(block["boss_id"])] = int(counters.get("boss_" + String(block["boss_id"]), 0)) + 1
		boss_block = null
	if overkill > 0:
		gained *= 1.0 + overkill
		counters["overkills"] += 1
	var coin_amount := _grant_coins(gained)
	var center := block_rect(block).get_center()
	_emit({"type": "kill", "pos": center, "coins": coin_amount, "kind": kind, "bomb": kind == "bomb", "boss_id": block.get("boss_id", ""), "overkill": overkill})
	if kind == "extra_ball":
		bonus_balls += 1
		_emit({"type": "extra_ball", "pos": center})
	if kind == "boss":
		_wipe_minions()
		return
	_spread_plague(cell, int(block["poison"]))
	_on_kill_effects(cell, kind, flags)


## Plague: a poisoned block that dies passes part of its poison to its neighbours.
func _spread_plague(cell: Vector2i, poison: int) -> void:
	if stat("plague") <= 0.0 or poison <= 0:
		return
	var passed := maxi(int(poison * PLAGUE_SHARE), 1)
	var seen := {}
	for side in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var target: Vector2i = cell + side
		if not blocks.has(target) or seen.has(blocks[target]["id"]):
			continue
		seen[blocks[target]["id"]] = true
		blocks[target]["poison"] = int(blocks[target]["poison"]) + passed
		_emit({"type": "plague", "pos": block_rect(blocks[target]).get_center()})


## Fractions carry over, so small rewards still add up exactly.
func _grant_coins(base: float) -> int:
	_coin_carry += base * (1.0 + stat("coin_pct")) * _coin_scale * _stage_coin_mult * (FEVER_COINS if fever else 1.0)
	var amount := int(_coin_carry)
	_coin_carry -= amount
	coins += amount
	return amount


## A dead boss takes its whole court with it: the biggest moment of the run.
func _wipe_minions() -> void:
	for block in unique_blocks():
		_erase_block(block)
		counters["kills"] += 1
		var coin_amount := _grant_coins(0.5)
		var center := block_rect(block).get_center()
		_emit({"type": "kill", "pos": center, "coins": coin_amount, "kind": block["kind"], "bomb": true})
		_emit({"type": "explode", "pos": center, "radius": 1})
		counters["explosions"] += 1
	_pending_blasts = []
	waves_left = 0


func _on_kill_effects(cell: Vector2i, kind: String, flags: Dictionary) -> void:
	var wave := stat("shockwave")
	if wave > 0.0:
		var wave_damage := (1.0 + stat("flat_damage")) * 2.0 * wave
		for side in [Vector2i.LEFT, Vector2i.RIGHT]:
			var target: Vector2i = cell + side
			if blocks.has(target):
				_damage_block(target, _scale_damage(wave_damage, blocks[target]), {"dot": true})
	var targets := int(stat("shock_targets"))
	if targets > 0:
		_strike_random(targets, (1.0 + stat("flat_damage")) * 3.0)
	var should_blast := kind == "bomb" or _rng.randf() < stat("bomb_chance")
	if flags.get("blast", false) and _rng.randf() < stat("chain_chance"):
		should_blast = true
	if should_blast:
		_pending_blasts.append({"cell": cell, "t": CHAIN_DELAY, "damage": _blast_damage(), "radius": 1 + int(stat("bomb_radius"))})


func _blast_damage() -> float:
	return (3.0 + stat("flat_damage") + 4.5 * stage) * (1.0 + stat("bomb_damage")) * sqrt(Tiers.hp_scale(tier)) * 0.8


func _strike_random(count: int, damage: float) -> void:
	var cells := blocks.keys()
	if cells.is_empty():
		return
	for i in count:
		var cell: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
		if blocks.has(cell):
			_emit({"type": "shock", "pos": cell_rect(cell).get_center()})
			_damage_block(cell, _scale_damage(damage, blocks[cell]), {"dot": true})


func _erase_block(block: Dictionary) -> void:
	var origin: Vector2i = block["origin"]
	var size: Vector2i = block["size"]
	for y in size.y:
		for x in size.x:
			blocks.erase(origin + Vector2i(x, y))


func _blast_step(dt: float) -> void:
	var ready: Array[Dictionary] = []
	for blast in _pending_blasts:
		blast["t"] = float(blast["t"]) - dt
		if float(blast["t"]) <= 0.0:
			ready.append(blast)
	for blast in ready:
		_pending_blasts.erase(blast)
		_detonate(blast)


func _detonate(blast: Dictionary) -> void:
	var cell: Vector2i = blast["cell"]
	var radius: int = blast["radius"]
	if blast.has("burst"):
		if blocks.has(cell):
			_emit({"type": "explode", "pos": block_rect(blocks[cell]).get_center(), "radius": 1})
			_damage_block(cell, float(blast["damage"]), {"burst": true, "blast": true})
		return
	counters["explosions"] += 1
	_emit({"type": "explode", "pos": cell_rect(cell).get_center(), "radius": radius})
	var hit_ids := {}
	for y in range(cell.y - radius, cell.y + radius + 1):
		for x in range(cell.x - radius, cell.x + radius + 1):
			var target := Vector2i(x, y)
			if not blocks.has(target):
				continue
			var block: Dictionary = blocks[target]
			if hit_ids.has(block["id"]):
				continue
			hit_ids[block["id"]] = true
			if stat("blast_poison") > 0.0:
				block["poison"] = int(block["poison"]) + int(stat("blast_poison"))
			_damage_block(target, _scale_damage(float(blast["damage"]), block), {"blast": true})


func _end_shot() -> void:
	if _next_launch_x >= 0.0:
		launch_x = _next_launch_x
	if _burst_shot:
		_end_burst()
		return
	if _bonus_turn():
		return
	_apply_end_of_shot()
	_rate_shot()
	_check_missions()
	if _is_stage_finished():
		_clear_stage()
		return
	_emit({"type": "shot_end"})
	if boss_block == null and blocks.is_empty():
		# Everything died but waves remain: bring the next row in immediately.
		waves_left -= 1
		_spawn_row(0)
		state = State.AIM
		return
	_descend()
	if _is_stage_finished():
		_clear_stage()
		return
	if _check_death():
		return
	state = State.AIM


## Rewards how much one shot achieved, measured so bigger numbers alone do not inflate it:
## share of the field destroyed, share of a boss's health taken, and hits per ball.
func _rate_shot() -> void:
	var kills := int(counters["kills"]) - _shot_start_kills
	var score := STYLE_FIELD_WEIGHT * float(kills) / _shot_start_blocks + float(combo) / _shot_balls
	if _shot_start_boss_hp > 0:
		var boss_hp := 0 if boss_block == null else maxi(int((boss_block as Dictionary)["hp"]), 0)
		var max_hp: float = _boss_max_hp_at_shot()
		score += STYLE_BOSS_WEIGHT * float(maxi(_shot_start_boss_hp - boss_hp, 0)) / max_hp
	last_shot_score = score
	last_shot_rank = rank_for(score, RANK_THRESHOLDS)
	_style_total += score
	_style_shots += 1
	if last_shot_rank >= RANK_S:
		counters["style_s"] += 1
	_emit({"type": "shot_rank", "rank": last_shot_rank})


func _boss_max_hp_at_shot() -> float:
	return maxf(float(_shot_boss_max_hp), 1.0)


static func rank_for(score: float, thresholds: Array[float]) -> int:
	var rank := 0
	for i in thresholds.size():
		if score >= thresholds[i]:
			rank = i
	return rank


## The run's overall grade: the average shot, with a step up for finishing the run.
func run_rank() -> int:
	var average := _style_total / maxi(_style_shots, 1)
	var rank := rank_for(average, RUN_RANK_THRESHOLDS)
	return mini(rank + (1 if state == State.WON else 0), RANKS.size() - 1)


func _end_burst() -> void:
	_burst_shot = false
	_emit({"type": "burst_end", "damage": shot_damage})
	if _bonus_turn():
		return
	if _is_stage_finished():
		_clear_stage()
		return
	if blocks.is_empty():
		waves_left -= 1
		_spawn_row(0)
	state = State.AIM


func _apply_end_of_shot() -> void:
	var regen_rate := 0.3 if Tiers.has_rule(tier, "strong_regen") else 0.15
	var poison_scale := (1.0 + stat("poison_damage"))
	var cells := blocks.keys()
	var seen := {}
	for cell: Vector2i in cells:
		if not blocks.has(cell):
			continue
		var block: Dictionary = blocks[cell]
		if seen.has(block["id"]):
			continue
		seen[block["id"]] = true
		if int(block["poison"]) > 0:
			var damage := int(block["poison"]) * poison_scale
			_damage_block(cell, _scale_damage(damage, block), {"dot": true, "poison": true})
		if blocks.has(cell) and block["burning"]:
			var burn_scale := BOSS_BURN_SCALE if block["kind"] == "boss" else 1.0
			_damage_block(cell, float(block["max_hp"]) * stat("burn_pct") * burn_scale, {"dot": true})
		if blocks.has(cell) and block["kind"] == "regen":
			block["hp"] = mini(int(block["hp"]) + maxi(int(float(block["max_hp"]) * regen_rate), 1), int(block["max_hp"]))
			_emit({"type": "regen", "pos": block_rect(block).get_center()})
	if stat("intercept_pct") > 0.0:
		var lowest := _lowest_row()
		var hit_ids := {}
		for cell: Vector2i in blocks.keys():
			if cell.y == lowest and blocks.has(cell) and blocks[cell]["kind"] != "boss":
				var target_id: int = blocks[cell]["id"]
				if not hit_ids.has(target_id):
					hit_ids[target_id] = true
					_damage_block(cell, float(blocks[cell]["max_hp"]) * stat("intercept_pct"), {"dot": true})
	# Blasts started by end-of-shot damage finish now, so a shot resolves completely.
	var guard_count := 0
	while not _pending_blasts.is_empty() and guard_count < 500:
		guard_count += 1
		var blast: Dictionary = _pending_blasts.pop_back()
		_detonate(blast)
	_breed()


func _breed() -> void:
	var breeders: Array[Dictionary] = []
	for block in unique_blocks():
		if block["kind"] == "breeder":
			breeders.append(block)
	for block in breeders:
		var origin: Vector2i = block["origin"]
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var target: Vector2i = origin + offset
			if target.x >= 0 and target.x < COLS and not blocks.has(target) and not obstacles.has(target):
				var hp: int = maxi(int(block["max_hp"]) / 2, 1)
				blocks[target] = _new_block(hp, "normal", target)
				_emit({"type": "breed", "pos": cell_rect(target).get_center()})
				break


func _descend() -> void:
	var every_nth := 7 - int(stat("stall")) * 2
	if stat("stall") > 0.0 and shots % every_nth == 0:
		_emit({"type": "stalled"})
		_boss_turn(false)
		return
	var boss_moves := _boss_turn(true)
	var moved := {}
	var bites := 0
	if boss_block != null:
		var boss: Dictionary = boss_block
		var origin: Vector2i = boss["origin"]
		var old_y := origin.y
		if boss_moves:
			origin += Vector2i.DOWN
		if boss["boss_id"] == "mogu":
			origin = _strafe(boss, origin)
		elif boss["boss_id"] == "mirage":
			origin = _blink(origin)
		boss["origin"] = origin
		boss["slid"] = origin.y != old_y
		for y in BOSS_SIZE.y:
			for x in BOSS_SIZE.x:
				moved[origin + Vector2i(x, y)] = boss
		var part: Variant = boss.get("part")
		if part != null and blocks.has((part as Dictionary)["origin"]) and blocks[(part as Dictionary)["origin"]]["id"] == part["id"]:
			var post_cell: Vector2i = origin + PART_POST
			if post_cell.x < COLS:
				part["slid"] = post_cell.y != (part["origin"] as Vector2i).y
				part["origin"] = post_cell
				moved[post_cell] = part
		# Bodyguards keep formation instead of drifting down with the rest.
		for guard: Dictionary in _live_guards():
			var post: Vector2i = origin + (guard["post"] as Vector2i)
			guard["slid"] = post.y != (guard["origin"] as Vector2i).y
			guard["origin"] = post
			for gy in int(guard["size"].y):
				for gx in int(guard["size"].x):
					moved[post + Vector2i(gx, gy)] = guard
	# Bottom rows first, so blocks stack up against the boss instead of overlapping it.
	_move_bounties(moved)
	var falling := unique_blocks()
	falling.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["origin"].y) + int(a["size"].y) > int(b["origin"].y) + int(b["size"].y))
	for block in falling:
		if block["kind"] == "boss" or block.has("post") or block["kind"] == "bounty":
			continue
		var origin: Vector2i = block["origin"]
		var target := origin + Vector2i.DOWN
		# Blocks drop past furniture rather than getting stuck on it.
		while _covers_obstacle(target, block["size"]):
			target += Vector2i.DOWN
		if _covers_any(moved, target, block["size"]):
			target = origin
		if _covers_any(moved, target, block["size"]):
			bites += 1
			continue
		block["slid"] = target != origin
		block["origin"] = target
		for y in int(block["size"].y):
			for x in int(block["size"].x):
				moved[target + Vector2i(x, y)] = block
	blocks = moved
	_slide_movers()
	if waves_left > 0:
		waves_left -= 1
		_spawn_row(0)
	if boss_block != null and boss_id() == "mogu" and bites > 0:
		_heal_boss(float(bites) * MOGU_HEAL_PER_BITE, "chomp")
	_boss_trick()
	_summon_if_due()
	_emit({"type": "descend"})


## A bounty never falls: it scuttles along its row, and leaves if it is not caught in time.
func _move_bounties(moved: Dictionary) -> void:
	for block in unique_blocks():
		if block["kind"] != "bounty":
			continue
		block["turns"] = int(block["turns"]) - 1
		var origin: Vector2i = block["origin"]
		if int(block["turns"]) <= 0:
			_emit({"type": "bounty_escaped", "pos": block_rect(block).get_center()})
			continue
		var next := origin + Vector2i(int(block["dir"]), 0)
		if next.x < 0 or next.x >= COLS or moved.has(next) or obstacles.has(next):
			block["dir"] = -int(block["dir"])
			next = origin
		block["slid"] = false
		block["origin"] = next
		moved[next] = block


func _maybe_spawn_bounty() -> void:
	if stage == 0 or stage_cfg().has("boss") or not rush.is_empty() or _rng.randf() >= BOUNTY_CHANCE:
		return
	var free: Array[Vector2i] = []
	for y in range(5, 6):
		for x in COLS:
			var cell := Vector2i(x, y)
			if not blocks.has(cell) and not obstacles.has(cell):
				free.append(cell)
	if free.is_empty():
		return
	var cell: Vector2i = free[_rng.randi_range(0, free.size() - 1)]
	var block := _new_block(_block_hp(float(stage_cfg()["hp_max"]) * BOUNTY_HP), "bounty", cell)
	block["turns"] = BOUNTY_TURNS
	block["dir"] = 1 if _rng.randf() < 0.5 else -1
	blocks[cell] = block
	_emit({"type": "bounty", "pos": cell_rect(cell).get_center()})


func _covers_obstacle(origin: Vector2i, size: Vector2i) -> bool:
	return _covers_any(obstacles, origin, size)


func _covers_any(cells: Dictionary, origin: Vector2i, size: Vector2i) -> bool:
	for y in size.y:
		for x in size.x:
			if cells.has(origin + Vector2i(x, y)):
				return true
	return false


## Moving walls step along their row each turn, turning back at an edge or anything in the way.
func _slide_movers() -> void:
	for entry: Dictionary in obstacles.values():
		if entry["kind"] != "mover":
			continue
		var cell: Vector2i = entry["cell"]
		var next := cell + Vector2i(int(entry["dir"]), 0)
		if next.x < 0 or next.x >= COLS or obstacles.has(next) or blocks.has(next):
			entry["dir"] = -int(entry["dir"])
			next = cell + Vector2i(int(entry["dir"]), 0)
			if next.x < 0 or next.x >= COLS or obstacles.has(next) or blocks.has(next):
				continue
		obstacles.erase(cell)
		entry["cell"] = next
		obstacles[next] = entry


## Ages the boss. Returns true when the boss should step down this turn.
func _boss_turn(can_move: bool) -> bool:
	if boss_block == null:
		return false
	var boss: Dictionary = boss_block
	boss["age"] = int(boss["age"]) + 1
	return can_move and int(boss["age"]) % int(boss["every"]) == 0


func _summon_if_due() -> void:
	if boss_block == null:
		return
	var boss: Dictionary = boss_block
	var count: int = boss["summon"]
	if count <= 0:
		return
	if boss["angry"]:
		count += 1
	var free: Array[int] = []
	for col in COLS:
		if not blocks.has(Vector2i(col, 0)):
			free.append(col)
	for i in mini(count, free.size()):
		var index := _rng.randi_range(0, free.size() - 1)
		var cell := Vector2i(free[index], 0)
		if String(boss["minion"]) == "":
			_place_block(cell)
		else:
			_put_block(cell, String(boss["minion"]), _minion_hp())
		free.remove_at(index)
	_emit({"type": "summon"})


func _minion_hp() -> int:
	var cfg: Dictionary = stage_cfg()
	return _block_hp(_rng.randf_range(float(cfg["hp_min"]), float(cfg["hp_max"])))


func _put_block(cell: Vector2i, kind: String, hp: int) -> Variant:
	if blocks.has(cell) or obstacles.has(cell) or cell.x < 0 or cell.x >= COLS or cell.y < 0:
		return null
	var block := _new_block(hp, kind, cell)
	blocks[cell] = block
	return block


func _boss_action(action: String, extra := {}) -> void:
	var event := {"type": "boss_action", "action": action, "boss": boss_id(), "pos": block_rect(boss_block).get_center()}
	event.merge(extra)
	_emit(event)


## Runs after every hit that leaves the boss alive.
func _on_boss_hurt(boss: Dictionary) -> void:
	var ratio := float(boss["hp"]) / float(boss["max_hp"])
	if ratio < 0.5 and not boss["angry"]:
		boss["angry"] = true
		_emit({"type": "boss_angry", "boss": boss["boss_id"], "pos": block_rect(boss).get_center()})
	if boss["boss_id"] == "purun":
		while ratio < float(boss["next_split"]):
			boss["next_split"] = float(boss["next_split"]) - SLIME_STEP
			_split_slime(boss)


## Purun: every quarter of its health flies off as new blocks around it.
func _split_slime(boss: Dictionary) -> void:
	var origin: Vector2i = boss["origin"]
	var spots: Array[Vector2i] = []
	for x in range(-1, BOSS_SIZE.x + 1):
		spots.append(origin + Vector2i(x, BOSS_SIZE.y))
	for y in BOSS_SIZE.y:
		spots.append(origin + Vector2i(-1, y))
		spots.append(origin + Vector2i(BOSS_SIZE.x, y))
	var targets: Array[Vector2] = []
	while targets.size() < SLIME_PIECES and not spots.is_empty():
		var cell: Vector2i = spots.pop_at(_rng.randi_range(0, spots.size() - 1))
		if cell.y >= death_row - BOSS_REACH_MARGIN:
			continue
		var piece: Variant = _put_block(cell, "normal", _minion_hp())
		if piece != null:
			(piece as Dictionary)["tint"] = "boss"
			targets.append(cell_rect(cell).get_center())
	_boss_action("split", {"targets": targets})


## Mogu: wanders sideways every turn and eats whatever ends up inside it.
func _blink(origin: Vector2i) -> Vector2i:
	var next := _rng.randi_range(0, COLS - BOSS_SIZE.x - 1)
	if next >= origin.x:
		next += 1
	return Vector2i(next, origin.y)


func _strafe(boss: Dictionary, origin: Vector2i) -> Vector2i:
	var next: int = origin.x + int(boss["dir"])
	if next < 0 or next > COLS - BOSS_SIZE.x:
		boss["dir"] = -int(boss["dir"])
		next = origin.x + int(boss["dir"])
	return Vector2i(next, origin.y)


func _heal_boss(share: float, action: String) -> void:
	var boss: Dictionary = boss_block
	var amount := mini(int(ceil(float(boss["max_hp"]) * share)), int(boss["max_hp"]) - int(boss["hp"]))
	boss["hp"] = int(boss["hp"]) + amount
	if float(boss["hp"]) / float(boss["max_hp"]) >= 0.5:
		boss["angry"] = false
	_boss_action(action, {"amount": amount})


func _boss_trick() -> void:
	if boss_block == null:
		return
	var boss: Dictionary = boss_block
	# With its part broken, a boss can no longer use its trick.
	if boss.get("broken", false):
		return
	match boss["boss_id"]:
		"gantetsu":
			if _live_guards().is_empty():
				boss["guard_wait"] = int(boss["guard_wait"]) + 1
				if int(boss["guard_wait"]) >= GUARD_RETURN_TURNS:
					boss["guard_wait"] = 0
					_spawn_guards(boss)
		"lumina":
			_heal_boss(LUMINA_ANGRY_HEAL if boss["angry"] else LUMINA_HEAL, "heal")
		"dokan":
			_throw_bombs(boss)
		"zero":
			_laser_turn(boss)
		"mirage":
			_boss_action("blink")
		"chrono":
			_rewind(boss)
		"hyoga":
			_freeze_blocks(boss)
		"tsukuyo":
			boss["veil"] = not boss["veil"]
			if boss["veil"]:
				_boss_action("veil")
		"void":
			burst_charge = maxf(burst_charge - (VOID_ANGRY_DRAIN if boss["angry"] else VOID_DRAIN), 0.0)
			_boss_action("drain")
		"origin":
			# It has fought every keeper, and uses what it learned from each in turn.
			match int(boss["age"]) % ORIGIN_TRICKS:
				0:
					_heal_boss(LUMINA_HEAL, "heal")
				1:
					_throw_bombs(boss)
				_:
					burst_charge = maxf(burst_charge - VOID_DRAIN, 0.0)
					_boss_action("drain")


## Gantetsu: while either bodyguard stands, hits barely scratch it.
func _spawn_guards(boss: Dictionary) -> void:
	var origin: Vector2i = boss["origin"]
	var guards_list: Array = []
	var targets: Array[Vector2] = []
	var cfg: Dictionary = stage_cfg()
	for post: Vector2i in [Vector2i(-1, 1), Vector2i(BOSS_SIZE.x, 1)]:
		var placed: Variant = _put_block(origin + post, "armor", _block_hp(float(cfg["hp_max"]) * GUARD_HP))
		if placed != null:
			(placed as Dictionary)["post"] = post
			guards_list.append(placed)
			targets.append(cell_rect(origin + post).get_center())
	boss["guards"] = guards_list
	_boss_action("guards", {"targets": targets})


func _live_guards() -> Array:
	if boss_block == null:
		return []
	var alive: Array = []
	for guard: Dictionary in (boss_block as Dictionary)["guards"]:
		var cell: Vector2i = guard["origin"]
		if blocks.has(cell) and blocks[cell]["id"] == guard["id"]:
			alive.append(guard)
	return alive


func is_boss_guarded() -> bool:
	if boss_block != null and (boss_block as Dictionary)["veil"]:
		return true
	return not _live_guards().is_empty()


func _rewind(boss: Dictionary) -> void:
	var dealt := maxi(_shot_start_boss_hp - int(boss["hp"]), 0)
	if dealt <= 0:
		return
	var share := CHRONO_ANGRY_REWIND if boss["angry"] else CHRONO_REWIND
	_heal_boss(share * dealt / float(boss["max_hp"]), "heal")


func _freeze_blocks(boss: Dictionary) -> void:
	var plain: Array[Dictionary] = []
	for block in unique_blocks():
		if block["kind"] == "normal" and not block.has("post"):
			plain.append(block)
	var targets: Array[Vector2] = []
	for i in mini(HYOGA_FREEZES + (1 if boss["angry"] else 0), plain.size()):
		var block: Dictionary = plain.pop_at(_rng.randi_range(0, plain.size() - 1))
		block["kind"] = "armor"
		targets.append(block_rect(block).get_center())
	if not targets.is_empty():
		_boss_action("freeze", {"targets": targets})


## Homura's one trick: the blow that should end it lights it up again instead.
func _try_rebirth(block: Dictionary) -> bool:
	if block["boss_id"] != "homura" or block["reborn"]:
		return false
	block["reborn"] = true
	block["hp"] = maxi(int(float(block["max_hp"]) * HOMURA_REBIRTH), 1)
	block["angry"] = true
	_boss_action("rebirth")
	return true


## Dokan: lobs bombs and rubble just ahead of the front line.
func _throw_bombs(boss: Dictionary) -> void:
	var origin: Vector2i = boss["origin"]
	var top := origin.y + BOSS_SIZE.y
	var bottom := mini(_lowest_row() + 1, death_row - BOSS_REACH_MARGIN)
	var free: Array[Vector2i] = []
	for y in range(top, bottom + 1):
		for x in COLS:
			if not blocks.has(Vector2i(x, y)):
				free.append(Vector2i(x, y))
	var count := DOKAN_THROWS + (1 if boss["angry"] else 0)
	var targets: Array[Vector2] = []
	for i in mini(count, free.size()):
		var cell: Vector2i = free.pop_at(_rng.randi_range(0, free.size() - 1))
		_put_block(cell, "bomb" if i == 0 else "normal", _minion_hp())
		targets.append(cell_rect(cell).get_center())
	if not targets.is_empty():
		_boss_action("throw", {"targets": targets})


## Zero: marks columns one turn, then fires down them and leaves armoured walls behind.
func _laser_turn(boss: Dictionary) -> void:
	var aimed: Array = boss["aim_cols"]
	if aimed.is_empty():
		var options: Array[int] = []
		for col in COLS:
			options.append(col)
		for i in 2 if boss["angry"] else 1:
			aimed.append(options.pop_at(_rng.randi_range(0, options.size() - 1)))
		_boss_action("aim")
		return
	var origin: Vector2i = boss["origin"]
	var top := origin.y + BOSS_SIZE.y
	for col: int in aimed:
		for y in range(top, mini(top + ZERO_WALL_ROWS, death_row - BOSS_REACH_MARGIN + 1)):
			_put_block(Vector2i(col, y), "armor", _minion_hp())
	_boss_action("laser", {"cols": aimed.duplicate()})
	boss["aim_cols"] = []


func _check_death() -> bool:
	var breached := false
	for cell: Vector2i in blocks:
		if cell.y >= death_row:
			breached = true
			break
	if not breached:
		return false
	if guards > 0:
		guards -= 1
		_use_guard()
		return false
	state = State.LOST
	_emit({"type": "lost"})
	return true


## A guard wipes the two lowest rows instead of ending the run. Bosses get pushed back up.
func _use_guard() -> void:
	var lowest := _lowest_row()
	for block in unique_blocks():
		if block["kind"] == "boss":
			var origin: Vector2i = block["origin"]
			for y in BOSS_SIZE.y:
				for x in BOSS_SIZE.x:
					blocks.erase(origin + Vector2i(x, y))
			var raised := Vector2i(origin.x, maxi(origin.y - 3, 0))
			block["origin"] = raised
			for y in BOSS_SIZE.y:
				for x in BOSS_SIZE.x:
					blocks[raised + Vector2i(x, y)] = block
		elif int((block["origin"] as Vector2i).y) >= lowest - 1:
			_erase_block(block)
	_emit({"type": "guard"})


func _clear_stage() -> void:
	_stages_cleared += 1
	var earned_interest := int(floor(coins * stat("interest")))
	coins += earned_interest
	if stage >= _final_stage():
		state = State.WON
		if not rush.is_empty():
			counters["rush_clears"] = 1
		_emit({"type": "won"})
		return
	if _rng.randf() < JACKPOT_CHANCE + stat("luck") * JACKPOT_CHANCE:
		_emit({"type": "jackpot", "coins": _grant_coins(JACKPOT_COINS * (stage + 1))})
	picks_pending = 1
	if stage_cfg().has("boss"):
		picks_pending += BOSS_STAGE_EXTRA_PICKS
		# Beating a boss is what relics are for, when the run has roads to spend them on.
		if routes_enabled and relics.size() < RunContent.MAX_RELICS:
			var pool := RunContent.ids_of(RunContent.RELICS).filter(func(id: String) -> bool: return not relics.has(id))
			take_relic(pool[_rng.randi_range(0, pool.size() - 1)])
	_emit({"type": "stage_clear", "stage": stage})
	_open_upgrade()


func _open_upgrade() -> void:
	state = State.UPGRADE
	choices = _roll_choices()
	if choices.is_empty():
		# Everything is maxed out: nothing to offer, so move straight on.
		picks_pending = 0
		_leave_stage()


func _is_perk_unlocked(id: String) -> bool:
	return unlocked_perks == null or (unlocked_perks as Array).has(id)


func _is_perk_available(id: String) -> bool:
	var perk: Dictionary = Perks.PERKS[id]
	if int(levels[id]) >= int(perk["max"]):
		return false
	if Perks.is_curse(id):
		return false
	if Perks.is_evolution(id):
		for required: String in perk["requires"]:
			if int(levels[required]) <= 0:
				return false
		return true
	if perk.has("needs") and stat(String(perk["needs"])) <= 0.0:
		return false
	return _is_perk_unlocked(id)


## How much of each build this run already has: owned perk levels plus the ball's leaning.
func tag_levels() -> Dictionary:
	var totals := {}
	for tag: String in (Balls.BALLS.get(ball_type, Balls.BALLS["normal"]) as Dictionary)["tags"]:
		totals[tag] = 1
	for id: String in levels:
		var level: int = levels[id]
		if level > 0:
			for tag in Perks.tags_of(id):
				totals[tag] = int(totals.get(tag, 0)) + level
	return totals


## Where a perk leads: {evolution, partner, ready}, where `ready` means taking this perk
## makes the evolution reachable. Empty when it leads nowhere new.
func evolution_hint(id: String) -> Dictionary:
	if Perks.is_evolution(id):
		return {}
	var waiting := {}
	for evolution in Perks.evolutions_of(id):
		if int(levels[evolution]) > 0:
			continue
		var requires: Array = Perks.PERKS[evolution]["requires"]
		var partner: String = requires[0] if requires[1] == id else requires[1]
		var partner_owned := int(levels[partner]) > 0
		if partner_owned and int(levels[id]) <= 0:
			return {"evolution": evolution, "partner": partner, "ready": true}
		if not partner_owned and waiting.is_empty() and _is_perk_unlocked(partner):
			waiting = {"evolution": evolution, "partner": partner, "ready": false}
	return waiting


func _synergy_mult(id: String, tags: Dictionary) -> float:
	if Perks.is_evolution(id):
		return EVOLUTION_RETURN_MULT
	var matched := 0
	for tag in Perks.tags_of(id):
		matched += int(tags.get(tag, 0))
	var mult := 1.0 + SYNERGY_PER_LEVEL * mini(matched, SYNERGY_LEVEL_CAP)
	if bool(evolution_hint(id).get("ready", false)):
		mult *= SYNERGY_PARTNER_MULT
	return mult


func _roll_choices(keep: Array[String] = []) -> Array[String]:
	var count := maxi(3 + int(stat("extra_choices")), 2)
	# Brand-new players always see the showiest picks first.
	if _tutorial_offer and stage == 0:
		return ["split", "bomb", "more_balls"] as Array[String]
	var picked: Array[String] = keep.duplicate()
	# A newly reachable evolution is always offered once, so builds pay off visibly.
	if picked.is_empty():
		for id in Perks.ids():
			if Perks.is_evolution(id) and _is_perk_available(id) and not _offered_evolutions.has(id):
				_offered_evolutions[id] = true
				picked.append(id)
				break
	var pool: Array[String] = []
	for id in Perks.ids():
		if _is_perk_available(id) and not picked.has(id):
			pool.append(id)
	var tags := tag_levels()
	while picked.size() < count and not pool.is_empty():
		# The last card ignores the build, so changing direction always stays possible.
		var id := _weighted_pick(pool, {} if picked.size() == count - 1 else tags)
		picked.append(id)
		pool.erase(id)
	return picked


## `tags` empty means plain rarity odds, without any leaning toward the current build.
func _weighted_pick(pool: Array[String], tags := {}) -> String:
	var luck := stat("luck")
	var total := 0.0
	var weights: Array[float] = []
	for id in pool:
		var rarity: int = Perks.PERKS[id]["rarity"]
		var weight: float = Perks.RARITY_WEIGHTS[rarity] * (1.0 + luck * rarity)
		if not tags.is_empty():
			weight *= _synergy_mult(id, tags)
		weights.append(weight)
		total += weight
	var roll := _rng.randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]


func _emit(event: Dictionary) -> void:
	if emit_events and events.size() < 4000:
		events.append(event)
