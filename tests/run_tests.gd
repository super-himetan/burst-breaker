extends SceneTree
## Run: godot --headless --path . -s tests/run_tests.gd

const GameSim := preload("res://sim/game_sim.gd")
const I18n := preload("res://i18n.gd")
const SaveData := preload("res://save_data.gd")
const Perks := preload("res://data/perks.gd")
const Balls := preload("res://data/balls.gd")
const Shop := preload("res://data/shop.gd")
const Tiers := preload("res://data/tiers.gd")
const Achievements := preload("res://data/achievements.gd")
const DT := 1.0 / 60.0

var failures := 0


func _init() -> void:
	_test_ball_breaks_block()
	_test_shot_ends_and_blocks_descend()
	_test_wall_bounce_keeps_ball_in_field()
	_test_lose_at_death_row()
	_test_bomb_chain()
	_test_split_adds_balls()
	_test_ricochet_adds_damage()
	_test_clear_offers_upgrades_and_advances()
	_test_more_balls_upgrade()
	_test_new_run_resets()
	_test_same_seed_same_result()
	_test_shot_always_finishes()
	_test_every_perk_changes_something()
	_test_perk_mechanics()
	_test_evolution_needs_both_parents()
	_test_locked_perks_stay_out_of_offers()
	_test_max_level_perks_stop_appearing()
	_test_reroll()
	_test_special_blocks()
	_test_boss()
	_test_guard_saves_the_run()
	_test_ball_types()
	_test_tiers()
	_test_shop_and_prestige()
	_test_achievements_data()
	_test_achievements_flow()
	_test_text_coverage()
	_test_save_round_trip()
	_test_damaged_save_uses_defaults()
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)


func _sim(seed_value := 1, config := {}) -> GameSim:
	var sim := GameSim.new()
	sim.new_run(seed_value, config)
	return sim


func _block(sim: GameSim, cell: Vector2i, hp: int, kind := "normal") -> Dictionary:
	var block := {"id": 100000 + cell.x * 100 + cell.y, "hp": hp, "max_hp": hp, "kind": kind, "origin": cell, "size": Vector2i.ONE, "poison": 0, "burning": false}
	sim.blocks[cell] = block
	return block


func _single_block(sim: GameSim, cell: Vector2i, hp: int, kind := "normal") -> Dictionary:
	sim.blocks = {}
	sim.boss_block = null
	sim.waves_left = 0
	return _block(sim, cell, hp, kind)


func _give(sim: GameSim, perk: String, level := 1) -> void:
	sim.levels[perk] = level
	sim._recompute_stats()


func _center_x(sim: GameSim, col: int) -> float:
	return sim.cell_rect(Vector2i(col, 0)).get_center().x


func _run_shot(sim: GameSim, limit := 60.0) -> void:
	var t := 0.0
	while sim.state == GameSim.State.SHOOT and t < limit:
		sim.step(DT)
		sim.events = []
		t += DT


func _test_ball_breaks_block() -> void:
	var sim := _sim()
	_single_block(sim, Vector2i(3, 5), 1)
	_block(sim, Vector2i(0, 0), 9999)
	sim.launch_x = _center_x(sim, 3)
	sim.fire(Vector2.UP)
	_run_shot(sim)
	_check(not sim.blocks.has(Vector2i(3, 5)) and not sim.blocks.has(Vector2i(3, 6)), "a ball breaks the block in its path")
	_check(sim.total_damage >= 1 and sim.coins >= 1, "breaking grants damage and coins")


func _test_shot_ends_and_blocks_descend() -> void:
	var sim := _sim()
	_single_block(sim, Vector2i(0, 0), 9999)
	sim.launch_x = _center_x(sim, 4)
	sim.fire(Vector2.UP)
	_run_shot(sim)
	_check(sim.state == GameSim.State.AIM, "shot returns to aiming")
	_check(sim.blocks.has(Vector2i(0, 1)), "surviving blocks descend one row")


func _test_wall_bounce_keeps_ball_in_field() -> void:
	var sim := _sim()
	_single_block(sim, Vector2i(0, 0), 9999)
	sim.fire(Vector2(1.0, -0.3))
	var inside := true
	var t := 0.0
	while sim.state == GameSim.State.SHOOT and t < 30.0:
		sim.step(DT)
		sim.events = []
		for ball in sim.balls:
			if ball.pos.x < GameSim.FIELD_X or ball.pos.x > GameSim.FIELD_X + GameSim.FIELD_W or ball.pos.y < GameSim.FIELD_Y:
				inside = false
		t += DT
	_check(inside, "balls stay inside the field")


func _test_lose_at_death_row() -> void:
	var sim := _sim()
	_single_block(sim, Vector2i(0, GameSim.DEATH_ROW - 1), 9999)
	sim.launch_x = _center_x(sim, 6)
	sim.fire(Vector2.UP)
	_run_shot(sim)
	_check(sim.state == GameSim.State.LOST, "reaching the death row loses the run")


func _test_bomb_chain() -> void:
	var sim := _sim()
	_single_block(sim, Vector2i(3, 5), 1, "bomb")
	_block(sim, Vector2i(3, 4), 1, "bomb")
	_block(sim, Vector2i(3, 3), 1)
	_block(sim, Vector2i(0, 0), 9999)
	sim.ball_count = 1
	sim.launch_x = _center_x(sim, 3)
	sim.fire(Vector2.UP)
	var explosions := 0
	var t := 0.0
	while sim.state == GameSim.State.SHOOT and t < 30.0:
		sim.step(DT)
		for e in sim.events:
			if e["type"] == "explode":
				explosions += 1
		sim.events = []
		t += DT
	_check(explosions >= 2, "a bomb chains into a neighbouring bomb (got %d)" % explosions)
	_check(not sim.blocks.has(Vector2i(3, 4)), "chained blast removes the neighbour")


func _test_split_adds_balls() -> void:
	var sim := _sim()
	_give(sim, "split", 5)
	_single_block(sim, Vector2i(3, 2), 99999)
	sim.fire(Vector2.UP)
	var peak := 0
	var t := 0.0
	while sim.state == GameSim.State.SHOOT and t < 30.0:
		sim.step(DT)
		sim.events = []
		peak = maxi(peak, sim.balls.size())
		t += DT
	_check(peak > sim.ball_count, "split creates extra balls (peak %d)" % peak)
	_check(peak <= GameSim.MAX_BALLS + sim.ball_count, "ball count stays capped")


func _test_ricochet_adds_damage() -> void:
	var sim := _sim()
	_give(sim, "ricochet", 3)
	sim.ball_count = 1
	_single_block(sim, Vector2i(3, 0), 99999)
	sim.launch_x = GameSim.FIELD_X + 40.0
	sim.fire(Vector2(-1.0, -1.0))
	var biggest := 0
	var t := 0.0
	while sim.state == GameSim.State.SHOOT and t < 30.0:
		sim.step(DT)
		for e in sim.events:
			if e["type"] == "hit":
				biggest = maxi(biggest, int(e["damage"]))
		sim.events = []
		t += DT
	_check(biggest > 1, "wall bounces raise damage (max hit %d)" % biggest)


func _test_clear_offers_upgrades_and_advances() -> void:
	var sim := _sim(1, {"tutorial_offer": true})
	_single_block(sim, Vector2i(3, 5), 1)
	sim.launch_x = _center_x(sim, 3)
	sim.fire(Vector2.UP)
	_run_shot(sim)
	_check(sim.state == GameSim.State.UPGRADE, "clearing a stage offers upgrades")
	_check(sim.choices.has("split") and sim.choices.has("bomb"), "a new player's first offer has split and bomb")
	_check(not sim.choose_upgrade("ricochet"), "cannot pick an upgrade that was not offered")
	_check(sim.choose_upgrade("split"), "picking an offered upgrade works")
	_check(sim.stage == 1 and sim.state == GameSim.State.AIM and sim.levels["split"] == 1, "picking moves to the next stage")


func _test_more_balls_upgrade() -> void:
	var sim := _sim()
	var before := sim.ball_count
	_give(sim, "more_balls")
	_check(sim.ball_count == before + 4, "+4 balls adds four balls")


func _test_new_run_resets() -> void:
	var sim := _sim()
	sim.state = GameSim.State.LOST
	sim.total_damage = 500
	sim.coins = 20
	sim.levels["bomb"] = 2
	sim.stage = 3
	sim.counters["kills"] = 9
	sim.new_run(2)
	_check(sim.state == GameSim.State.AIM and sim.total_damage == 0 and sim.coins == 0 and sim.stage == 0 and sim.levels["bomb"] == 0, "a new run resets everything")
	_check(sim.counters["kills"] == 0, "a new run resets counters")


func _test_same_seed_same_result() -> void:
	var a := _autoplay(77)
	var b := _autoplay(77)
	_check(a["damage"] == b["damage"] and is_equal_approx(a["time"], b["time"]), "same seed gives the same run")


func _test_shot_always_finishes() -> void:
	var sim := _sim()
	_single_block(sim, Vector2i(3, 0), 999999)
	sim.ball_count = 20
	_give(sim, "floor_guard", 2)
	_give(sim, "second_wind", 3)
	sim.fire(Vector2(1.0, -0.15))
	var t := 0.0
	while sim.state == GameSim.State.SHOOT and t < 40.0:
		sim.step(DT)
		sim.events = []
		t += DT
	_check(sim.state != GameSim.State.SHOOT, "a shot always finishes, even with rebounds (%.1fs)" % t)


## Compares one fixed scenario with and without each perk, so a perk that silently does
## nothing shows up here. Perks that only act outside a shot are compared by stats.
func _test_every_perk_changes_something() -> void:
	var by_stats := ["reroll", "extra_choice", "lucky", "guard", "treasure", "reinforce", "short_waves", "thin", "stall", "overdrive", "interest", "bounty"]
	var baseline := _perk_probe("")
	for id in Perks.ids():
		if by_stats.has(id):
			var sim := _sim()
			var before := sim.stats.duplicate()
			_give(sim, id)
			_check(before != sim.stats, "perk %s changes stats" % id)
			continue
		_check(_perk_probe(id) != baseline, "perk %s changes the outcome" % id)


func _perk_probe(perk: String) -> Dictionary:
	var sim := _sim(5, {"emit_events": false})
	# A small build, because many perks only act on crits, splits, kills or poison.
	for helper in ["crit", "split", "bomb", "poison"]:
		sim.levels[helper] = 1
	if perk != "":
		sim.levels[perk] = int(Perks.PERKS[perk]["max"])
		for required: String in Perks.PERKS[perk].get("requires", []):
			sim.levels[required] = 1
	sim._recompute_stats()
	sim._stages_cleared = 2
	sim.ball_count += 12
	sim.blocks = {}
	sim.waves_left = 3
	for y in range(1, 6):
		for x in GameSim.COLS:
			# The open lanes let balls reach the ceiling.
			if x % 3 != 2:
				var fragile := y == 5 or (x + y) % 4 == 0
				_block(sim, Vector2i(x, y), 3 if fragile else 400, "bomb" if (x + y) % 6 == 0 else "normal")
	_block(sim, Vector2i(0, 10), 500)
	sim.boss_block = null
	sim.launch_x = _center_x(sim, 3)
	var t := 0.0
	for shot_dir in [Vector2(0.7, -1.0), Vector2(-0.45, -1.0), Vector2(0.1, -1.0)]:
		sim.fire(shot_dir)
		while sim.state == GameSim.State.SHOOT and t < 60.0:
			sim.step(DT)
			t += DT
	return {"damage": sim.total_damage, "coins": sim.coins, "time": sim.sim_time, "kills": sim.counters["kills"], "combo": sim.best_combo}


func _test_perk_mechanics() -> void:
	var sim := _sim()
	_give(sim, "power", 3)
	var block := _single_block(sim, Vector2i(3, 2), 1000)
	sim._hit_block_with_ball(Vector2i(3, 2), block, _ball())
	_check(sim.total_damage == 4, "power adds flat damage")

	sim = _sim()
	_give(sim, "first_strike", 1)
	block = _single_block(sim, Vector2i(3, 2), 1000)
	var ball := _ball()
	sim._hit_block_with_ball(Vector2i(3, 2), block, ball)
	var first := sim.total_damage
	sim._hit_block_with_ball(Vector2i(3, 2), block, ball)
	_check(first == 3 and sim.total_damage == 4, "first strike only boosts a ball's first hit")

	sim = _sim()
	_give(sim, "crit", 1)
	sim.stats["crit_chance"] = 1.0
	block = _single_block(sim, Vector2i(3, 2), 1000)
	sim._hit_block_with_ball(Vector2i(3, 2), block, _ball())
	_check(sim.total_damage == 3 and sim.counters["crits"] == 1, "a critical hit multiplies damage")

	sim = _sim()
	_give(sim, "poison", 2)
	sim.ball_count = 1
	block = _single_block(sim, Vector2i(3, 2), 1000)
	sim._hit_block_with_ball(Vector2i(3, 2), block, _ball())
	_check(int(block["poison"]) == 2, "poison stacks on hit")
	sim._apply_end_of_shot()
	_check(sim.counters["poison_damage"] == 2, "poison ticks at the end of the shot")

	sim = _sim()
	_give(sim, "burn", 1)
	block = _single_block(sim, Vector2i(3, 2), 1000)
	sim._hit_block_with_ball(Vector2i(3, 2), block, _ball())
	var hp_before := int(block["hp"])
	sim._apply_end_of_shot()
	_check(int(block["hp"]) == hp_before - 60, "burn removes a share of max HP")

	sim = _sim()
	_give(sim, "intercept", 1)
	_single_block(sim, Vector2i(3, 2), 1000)
	var upper := _block(sim, Vector2i(3, 1), 1000)
	sim._apply_end_of_shot()
	_check(int(sim.blocks[Vector2i(3, 2)]["hp"]) == 900 and int(upper["hp"]) == 1000, "intercept only hits the lowest row")

	sim = _sim()
	_give(sim, "pierce", 1)
	sim.stats["pierce_chance"] = 1.0
	sim.ball_count = 1
	_single_block(sim, Vector2i(3, 5), 9999)
	_block(sim, Vector2i(3, 3), 9999)
	sim.launch_x = _center_x(sim, 3)
	sim.fire(Vector2.UP)
	_run_shot(sim)
	_check(int(sim.blocks[Vector2i(3, 4)]["hp"]) < 9999, "a piercing ball reaches the block behind")

	sim = _sim()
	_give(sim, "floor_guard", 1)
	sim.ball_count = 1
	_single_block(sim, Vector2i(0, 0), 99999)
	sim.fire(Vector2(0.4, -1.0))
	var rebounds := 0
	var t := 0.0
	while sim.state == GameSim.State.SHOOT and t < 30.0:
		sim.step(DT)
		for e in sim.events:
			if e["type"] == "rebound":
				rebounds += 1
		sim.events = []
		t += DT
	_check(rebounds == 4, "floor guard bounces the set number of times (%d)" % rebounds)

	sim = _sim()
	_give(sim, "stall", 2)
	_single_block(sim, Vector2i(0, 0), 99999)
	sim.shots = 3
	sim._descend()
	_check(sim.blocks.has(Vector2i(0, 0)), "stall skips the descent on its turn")
	sim.shots = 4
	sim._descend()
	_check(sim.blocks.has(Vector2i(0, 1)), "other turns still descend")

	sim = _sim()
	_give(sim, "shockwave", 1)
	_single_block(sim, Vector2i(3, 2), 1)
	var side := _block(sim, Vector2i(4, 2), 100)
	sim._damage_block(Vector2i(3, 2), 5.0)
	_check(int(side["hp"]) < 100, "shockwave hits the neighbours of a kill")

	sim = _sim()
	_give(sim, "interest", 3)
	sim.coins = 100
	sim.blocks = {}
	sim.waves_left = 0
	sim._clear_stage()
	_check(sim.coins == 115, "interest pays at stage clear")

	sim = _sim()
	_give(sim, "momentum", 1)
	block = _single_block(sim, Vector2i(3, 2), 1000)
	var early := sim._scale_damage(10.0, block)
	sim._stages_cleared = 3
	_check(sim._scale_damage(10.0, block) > early, "momentum grows with cleared stages")

	sim = _sim()
	_give(sim, "last_stand", 1)
	block = _single_block(sim, Vector2i(3, 2), 1000)
	var safe := sim._scale_damage(10.0, block)
	_block(sim, Vector2i(0, GameSim.DEATH_ROW - 2), 1000)
	_check(is_equal_approx(sim._scale_damage(10.0, block), safe * 2.0), "last stand doubles damage in danger")

	sim = _sim()
	_give(sim, "e_cluster", 1)
	sim.stats["split_chance"] = 1.0
	_single_block(sim, Vector2i(3, 2), 1000)
	var clustered := _ball()
	clustered.pos = sim.cell_rect(Vector2i(3, 2)).get_center()
	sim._maybe_split(clustered)
	_check(sim._pending_blasts.size() == 1, "cluster makes a split explode")

	sim = _sim()
	_give(sim, "e_executioner", 1)
	sim.stats["crit_chance"] = 1.0
	block = _single_block(sim, Vector2i(3, 2), 1000)
	block["hp"] = 200
	sim._hit_block_with_ball(Vector2i(3, 2), block, _ball())
	_check(not sim.blocks.has(Vector2i(3, 2)), "executioner kills weakened blocks on a crit")


func _ball() -> GameSim.Ball:
	var ball := GameSim.Ball.new()
	ball.pos = Vector2(100.0, 100.0)
	ball.vel = Vector2.UP * 100.0
	return ball


func _test_evolution_needs_both_parents() -> void:
	var sim := _sim()
	_check(not sim._is_perk_available("e_cluster"), "an evolution is unavailable without its parents")
	_give(sim, "split")
	_check(not sim._is_perk_available("e_cluster"), "one parent is not enough")
	_give(sim, "bomb")
	_check(sim._is_perk_available("e_cluster"), "both parents make it available")
	var first := sim._roll_choices()
	_check(first.has("e_cluster"), "a newly reachable evolution is offered straight away")


func _test_locked_perks_stay_out_of_offers() -> void:
	var sim := _sim(3, {"unlocked_perks": ["power", "crit", "split", "bomb"] as Array[String]})
	var ok := true
	for i in 30:
		for id in sim._roll_choices():
			ok = ok and ["power", "crit", "split", "bomb", "e_cluster", "e_executioner", "e_storm"].has(id)
	_check(ok, "offers only contain unlocked perks")
	var data := SaveData.new(_temp_save_path("locks"))
	_check(not data.is_perk_unlocked("heavy") and data.is_perk_unlocked("power"), "locked perks start locked")
	data.achievements[Achievements.locks_for_perk("heavy")] = true
	_check(data.is_perk_unlocked("heavy"), "the matching achievement unlocks a perk")


func _test_max_level_perks_stop_appearing() -> void:
	var sim := _sim()
	_give(sim, "power", 5)
	var seen := false
	for i in 50:
		seen = seen or sim._roll_choices().has("power")
	_check(not seen, "a maxed perk is no longer offered")


func _test_reroll() -> void:
	var sim := _sim()
	_check(not sim.reroll_choices(), "no reroll outside the upgrade screen")
	sim.state = GameSim.State.UPGRADE
	sim.rerolls = 1
	sim.choices = sim._roll_choices()
	_check(sim.reroll_choices() and sim.rerolls == 0, "a reroll spends one charge")
	_check(not sim.reroll_choices(), "no charges means no reroll")


func _test_special_blocks() -> void:
	var sim := _sim()
	var block := _single_block(sim, Vector2i(3, 2), 5, "shield")
	sim._damage_block(Vector2i(3, 2), 1000.0)
	_check(int(block["hp"]) == 4, "shield blocks take one damage per hit")

	sim = _sim()
	block = _single_block(sim, Vector2i(3, 2), 100, "armor")
	sim._damage_block(Vector2i(3, 2), 10.0)
	_check(int(block["hp"]) == 95, "armor halves damage")

	sim = _sim()
	block = _single_block(sim, Vector2i(3, 2), 100, "regen")
	block["hp"] = 50
	sim._apply_end_of_shot()
	_check(int(block["hp"]) == 65, "regen blocks heal at the end of the shot")
	block["hp"] = 100
	sim._apply_end_of_shot()
	_check(int(block["hp"]) == 100, "regen never exceeds max HP")

	sim = _sim()
	_single_block(sim, Vector2i(3, 2), 1, "treasure")
	sim._damage_block(Vector2i(3, 2), 1.0)
	_check(sim.coins >= 15 and sim.counters["treasures"] == 1, "treasure blocks pay out")

	sim = _sim()
	var before := sim.shot_ball_count()
	_single_block(sim, Vector2i(3, 2), 1, "extra_ball")
	sim._damage_block(Vector2i(3, 2), 1.0)
	_check(sim.shot_ball_count() == before + 1, "+ball blocks add a ball for the stage")
	sim.stage = 1
	sim._start_stage()
	_check(sim.shot_ball_count() == before, "the extra ball ends with the stage")

	sim = _sim()
	_single_block(sim, Vector2i(3, 2), 10, "breeder")
	sim._apply_end_of_shot()
	_check(sim.blocks.size() == 2, "breeder blocks spawn a neighbour")


func _test_boss() -> void:
	var sim := _sim(4)
	sim.stage = 3
	sim._start_stage()
	var boss: Dictionary = sim.boss_block
	_check(boss != null and boss["kind"] == "boss", "stage 4 has a boss")
	var cells := 0
	for cell: Vector2i in sim.blocks:
		if sim.blocks[cell]["kind"] == "boss":
			cells += 1
	_check(cells == GameSim.BOSS_SIZE.x * GameSim.BOSS_SIZE.y, "the boss covers several cells")
	var origin: Vector2i = boss["origin"]
	var hp_before := int(boss["hp"])
	sim._damage_block(origin, 10.0)
	sim._damage_block(origin + Vector2i(2, 1), 10.0)
	_check(int(boss["hp"]) == hp_before - 20, "every boss cell shares one HP pool")
	var blast_hp := int(boss["hp"])
	sim._detonate({"cell": origin + Vector2i(1, 0), "damage": 10.0, "radius": 2})
	_check(int(boss["hp"]) == blast_hp - 10, "a blast hits the boss only once")
	sim.state = GameSim.State.SHOOT
	sim._descend()
	var moved_once: Vector2i = boss["origin"]
	sim._descend()
	sim._descend()
	_check(moved_once == origin and boss["origin"] == origin + Vector2i.DOWN, "the boss steps down every few turns")
	var valid := true
	for cell: Vector2i in sim.blocks:
		var b: Dictionary = sim.blocks[cell]
		var o: Vector2i = b["origin"]
		var s: Vector2i = b["size"]
		valid = valid and cell.x >= o.x and cell.x < o.x + s.x and cell.y >= o.y and cell.y < o.y + s.y
	_check(valid, "blocks keep consistent positions after moving around the boss")
	sim._damage_block(boss["origin"], 1.0e9)
	_check(sim.blocks.is_empty() and sim.boss_block == null, "killing the boss wipes its minions")
	_check(sim.counters["bosses"] == 1, "boss kills are counted")
	sim.state = GameSim.State.SHOOT
	sim._end_shot()
	_check(sim.state == GameSim.State.UPGRADE and sim.picks_pending == 2, "a boss stage grants two picks")

	var final_sim := _sim(4)
	final_sim.stage = GameSim.STAGES.size() - 1
	final_sim._start_stage()
	_check(final_sim.boss_block != null, "the last stage has a boss")
	final_sim._damage_block((final_sim.boss_block as Dictionary)["origin"], 1.0e9)
	final_sim.state = GameSim.State.SHOOT
	final_sim._end_shot()
	_check(final_sim.state == GameSim.State.WON, "killing the last boss wins the run")


func _test_guard_saves_the_run() -> void:
	var sim := _sim(1, {"shop": {"guard": 1}})
	_check(sim.guards == 1, "the shop grants guards")
	_single_block(sim, Vector2i(0, GameSim.DEATH_ROW - 1), 99999)
	_block(sim, Vector2i(0, 2), 99999)
	sim.launch_x = _center_x(sim, 6)
	sim.fire(Vector2.UP)
	_run_shot(sim)
	_check(sim.state == GameSim.State.AIM and sim.guards == 0, "a guard stops the loss")
	_check(sim.blocks.has(Vector2i(0, 3)) and sim.blocks.size() == 1, "a guard clears only the lowest rows")


func _test_ball_types() -> void:
	for id in Balls.ids():
		var sim := _sim(1, {"ball_type": id})
		_check(sim.ball_count == int(Balls.BALLS[id]["count"]), "ball %s fires its ball count" % id)
	var iron := _sim(1, {"ball_type": "iron"})
	var block := _single_block(iron, Vector2i(3, 2), 1000)
	iron.stats["pierce_chance"] = 0.0
	iron._hit_block_with_ball(Vector2i(3, 2), block, _ball())
	_check(iron.total_damage == 3, "the iron ball hits harder")
	var titan := _sim(1, {"ball_type": "titan"})
	_check(titan.ball_radius > GameSim.BALL_RADIUS, "the titan ball is larger")


func _test_tiers() -> void:
	var base := _sim(9)
	var hard := _sim(9, {"tier": 1})
	var base_hp := 0
	var hard_hp := 0
	for cell: Vector2i in base.blocks:
		base_hp += int(base.blocks[cell]["max_hp"])
	for cell: Vector2i in hard.blocks:
		hard_hp += int(hard.blocks[cell]["max_hp"])
	_check(hard_hp > base_hp, "a higher tier means tougher blocks")
	_check(Tiers.coin_scale(3) > Tiers.coin_scale(1), "a higher tier pays more coins")
	var t4 := _sim(1, {"tier": 4})
	_check(t4.ball_count == 7, "tier rules accumulate (fewer balls)")
	var t8 := _sim(1, {"tier": 8, "shop": {"reroll": 2}})
	_check(t8.rerolls == 0, "tier 8 removes free rerolls")
	var t9 := _sim(1, {"tier": 9})
	t9.state = GameSim.State.UPGRADE
	_check(t9._roll_choices().size() == 2, "tier 9 offers fewer choices")
	var t10 := _sim(1, {"tier": 10})
	_check(t10.death_row == GameSim.DEATH_ROW - 1, "tier 10 shortens the field")
	var t25 := _sim(1, {"tier": 25})
	_check(not t25.blocks.is_empty(), "tiers past the rule list still work")


func _test_shop_and_prestige() -> void:
	var data := SaveData.new(_temp_save_path("shop"))
	_check(not data.buy("damage"), "cannot buy without coins")
	data.coins = 100
	var cost := data.shop_cost("damage")
	_check(data.buy("damage") and data.coins == 100 - cost and data.shop_level("damage") == 1, "buying spends coins and adds a level")
	_check(data.shop_cost("damage") > cost, "the next level costs more")
	data.shop["reroll"] = 3
	data.coins = 99999999
	_check(not data.buy("reroll"), "a maxed item cannot be bought")
	var plain := _sim()
	var stronger := _sim(1, {"shop": {"damage": 10}})
	var a := _single_block(plain, Vector2i(3, 2), 1000)
	var b := _single_block(stronger, Vector2i(3, 2), 1000)
	_check(stronger._scale_damage(10.0, b) > plain._scale_damage(10.0, a), "shop damage raises damage")

	data = SaveData.new(_temp_save_path("prestige"))
	data.coins = 5000
	data.coins_this_life = 40000
	data.shop = {"damage": 5}
	_check(not data.can_prestige(), "prestige needs a clear first")
	data.wins = 1
	var gained := data.stars_on_prestige()
	_check(gained == 10, "stars follow lifetime coins (%d)" % gained)
	data.lifetime["best_tier"] = 3
	data.achievements["runs_1"] = true
	_check(data.prestige(), "prestige works after a clear")
	_check(data.stars == 10 and data.coins == 0 and data.shop.is_empty() and data.coins_this_life == 0, "prestige resets coins and shop")
	_check(data.max_tier() == 3 and data.has_achievement("runs_1"), "prestige keeps tiers and achievements")
	_check(not data.can_prestige(), "prestige needs new coins")
	var starred := _sim(1, {"stars": 10})
	var c := _single_block(starred, Vector2i(3, 2), 1000)
	_check(is_equal_approx(starred._scale_damage(10.0, c), 16.0), "stars multiply damage")


func _test_achievements_data() -> void:
	var entries := Achievements.all()
	_check(entries.size() >= 100, "at least 100 achievements (%d)" % entries.size())
	var ids := {}
	for entry in entries:
		ids[entry["id"]] = true
	_check(ids.size() == entries.size(), "achievement ids are unique")
	var ok := true
	for perk: String in Achievements.PERK_UNLOCKS:
		ok = ok and Perks.PERKS.has(perk) and Perks.starts_locked(perk) and ids.has(Achievements.PERK_UNLOCKS[perk])
	_check(ok, "perk unlocks point at real achievements")
	ok = true
	for id in Perks.ids():
		if Perks.starts_locked(id):
			ok = ok and Achievements.PERK_UNLOCKS.has(id)
	_check(ok, "every locked perk can be unlocked")
	ok = true
	for id in Balls.ids():
		var unlock := String(Balls.BALLS[id]["unlock"])
		ok = ok and (unlock == "" or ids.has(unlock))
		ok = ok and ids.has("clears_%s_1" % id)
	_check(ok, "ball unlocks and clear goals exist")
	_check(Perks.ids().size() >= 40, "at least 40 perks (%d)" % Perks.ids().size())
	ok = true
	for id in Perks.ids():
		if Perks.is_evolution(id):
			for required: String in Perks.PERKS[id]["requires"]:
				ok = ok and Perks.PERKS.has(required) and not Perks.is_evolution(required)
	_check(ok, "evolutions name real parents")


func _summary(damage := 100, won := false) -> Dictionary:
	return {"damage": damage, "combo": 10, "best_shot": 50, "stage": 2, "coins": 20, "won": won, "tier": 0, "ball_type": "normal", "counters": {"kills": 10}}


func _test_achievements_flow() -> void:
	var data := SaveData.new(_temp_save_path("achieve"))
	_check(data.record_run(_summary()), "the first run is a new best")
	_check(not data.record_run(_summary(50)), "a weaker run is not a new best")
	_check(data.best_damage == 100 and data.coins == 40 and data.runs == 2 and data.wins == 0, "bests stay, totals add up")
	_check(data.stat_value("kills") == 20, "counters add to lifetime stats")
	var coins_before := data.coins
	var unlocked := data.check_achievements()
	_check(unlocked.size() == 1 and unlocked[0]["id"] == "runs_1", "reaching a target unlocks the achievement")
	_check(data.coins == coins_before + int(unlocked[0]["reward_coins"]), "achievements pay coins")
	_check(data.check_achievements().is_empty(), "an achievement unlocks only once")
	var live := data.check_achievements({"kills": 80})
	_check(live.size() == 1 and live[0]["id"] == "kills_1", "live values count during a run")
	_check(not data.has_achievement("best_combo_1") and data.check_achievements({"best_combo": 60}).size() == 1, "best stats compare instead of adding")
	data.record_run(_summary(1000, true))
	_check(data.stat_value("clears_normal") == 1 and data.max_tier() == 1, "a clear unlocks the next tier")
	data.set_tier(5)
	_check(data.tier == 1, "cannot select a locked tier")
	var seen := SaveData.new(_temp_save_path("seen"))
	seen.mark_perk_seen("power")
	seen.mark_perk_seen("power")
	_check(seen.stat_value("perks_seen") == 1, "seen perks count once")
	_check(not seen.is_ball_unlocked("ghost") and seen.is_ball_unlocked("normal"), "only the normal ball starts unlocked")
	seen.achievements["wins_1"] = true
	_check(seen.is_ball_unlocked("ghost"), "an achievement unlocks a ball")
	var config := seen.run_config(false)
	_check(config["tutorial_offer"] == true and config["emit_events"] == false, "run config reflects progress")


func _test_text_coverage() -> void:
	var ja: Array = I18n.TEXT["ja"].keys()
	var en: Array = I18n.TEXT["en"].keys()
	ja.sort()
	en.sort()
	_check(ja == en, "Japanese and English define the same text keys")
	_check(I18n.DEFAULT_LANG == "ja", "Japanese is the base language")
	_check(I18n.text("xx", "start") == I18n.text("ja", "start"), "an unknown language falls back to Japanese")
	var missing: Array[String] = []
	var needed: Array[String] = []
	for id in Perks.ids():
		needed.append("perk_" + id)
		needed.append("perk_%s_desc" % id)
	for id in Balls.ids():
		needed.append("ball_" + id)
		needed.append("ball_%s_desc" % id)
	for id in Shop.ids():
		needed.append("shop_" + id)
		needed.append("shop_%s_desc" % id)
	for rule in Tiers.RULES:
		needed.append("tier_rule_" + rule)
	for stat: String in Achievements.TRACKS:
		needed.append("ach_" + stat)
	for kind in ["normal", "bomb", "shield", "regen", "armor", "treasure", "breeder", "extra_ball", "boss"]:
		needed.append("block_" + kind)
		needed.append("block_%s_desc" % kind)
	for lang in I18n.LANGS:
		for key in needed:
			if not I18n.TEXT[lang].has(key):
				missing.append("%s:%s" % [lang, key])
	_check(missing.is_empty(), "all game data has text %s" % str(missing.slice(0, 6)))
	var format_ok := I18n.format_number(999) == "999" and I18n.format_number(1500) == "1.5K" and I18n.format_number(2500000) == "2.5M"
	_check(format_ok, "large numbers are shortened")


func _temp_save_path(name_: String) -> String:
	var path := OS.get_temp_dir().path_join("burst_breaker_test_%s.json" % name_)
	DirAccess.remove_absolute(path)
	return path


func _test_save_round_trip() -> void:
	var path := _temp_save_path("round_trip")
	var fresh := SaveData.new(path)
	fresh.load_file()
	_check(fresh.lang == "ja" and fresh.sound and fresh.best_damage == 0, "with no file, settings are the defaults")
	fresh.lang = "en"
	fresh.sound = false
	fresh.record_run(_summary(123, true))
	fresh.coins = 500
	fresh.buy("damage")
	fresh.stars = 3
	fresh.ball_type = "iron"
	fresh.tier = 1
	fresh.check_achievements()
	fresh.mark_perk_seen("split")
	_check(fresh.save_file(), "saving succeeds")
	var loaded := SaveData.new(path)
	loaded.load_file()
	_check(loaded.lang == "en" and not loaded.sound, "settings survive a reload")
	_check(loaded.best_damage == 123 and loaded.wins == 1 and loaded.runs == 1, "records survive a reload")
	_check(loaded.coins == fresh.coins and loaded.shop_level("damage") == 1 and loaded.stars == 3, "wallet, shop and stars survive a reload")
	_check(loaded.achievements == fresh.achievements and loaded.perks_seen.has("split"), "achievements and codex survive a reload")
	_check(loaded.ball_type == "iron" and loaded.tier == 1, "the loadout survives a reload")
	DirAccess.remove_absolute(path)


func _test_damaged_save_uses_defaults() -> void:
	var path := _temp_save_path("damaged")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	var damaged := SaveData.new(path)
	damaged.load_file()
	_check(damaged.lang == "ja" and damaged.best_damage == 0, "a damaged save falls back to defaults")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\"lang\": \"xx\", \"best_damage\": 9, \"ball_type\": \"nope\", \"shop\": {\"gone\": 3, \"damage\": 2}}")
	file.close()
	var odd := SaveData.new(path)
	odd.load_file()
	_check(odd.lang == "ja" and odd.best_damage == 9 and odd.ball_type == "normal", "unknown saved values become defaults, records stay")
	_check(odd.shop == {"damage": 2}, "removed shop items are dropped")
	DirAccess.remove_absolute(path)


## Plays a whole run with a simple aim-at-lowest-block policy.
func _autoplay(seed_value: int) -> Dictionary:
	var sim := _sim(seed_value, {"emit_events": false})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 1000
	var guard := 0
	while guard < 3000000:
		guard += 1
		match sim.state:
			GameSim.State.AIM:
				sim.fire(Vector2(rng.randf_range(-0.6, 0.6), -1.0))
			GameSim.State.SHOOT:
				sim.step(DT)
			GameSim.State.UPGRADE:
				sim.choose_upgrade(sim.choices[rng.randi_range(0, sim.choices.size() - 1)])
			_:
				break
	return {"damage": sim.total_damage, "time": sim.sim_time}
