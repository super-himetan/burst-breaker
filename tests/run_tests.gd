extends SceneTree
## Run: godot --headless --path . -s tests/run_tests.gd

const GameSim := preload("res://sim/game_sim.gd")
const I18n := preload("res://i18n.gd")
const SaveData := preload("res://save_data.gd")
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
	_test_languages_have_the_same_keys()
	_test_every_upgrade_has_text()
	_test_unknown_language_falls_back_to_japanese()
	_test_save_round_trip()
	_test_damaged_save_uses_defaults()
	_test_record_run_keeps_bests()
	_balance_report()
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)


func _sim(seed_value := 1) -> GameSim:
	var sim := GameSim.new()
	sim.new_run(seed_value)
	return sim


func _single_block(sim: GameSim, cell: Vector2i, hp: int, kind := "normal") -> void:
	sim.blocks = {cell: {"hp": hp, "max_hp": hp, "kind": kind}}
	sim.waves_left = 0


func _run_shot(sim: GameSim, limit := 60.0) -> void:
	var t := 0.0
	while sim.state == GameSim.State.SHOOT and t < limit:
		sim.step(DT)
		sim.events = []
		t += DT


func _test_ball_breaks_block() -> void:
	var sim := _sim()
	_single_block(sim, Vector2i(3, 5), 1)
	sim.blocks[Vector2i(0, 0)] = {"hp": 9999, "max_hp": 9999, "kind": "normal"}
	sim.launch_x = sim.cell_rect(Vector2i(3, 5)).get_center().x
	sim.fire(Vector2.UP)
	_run_shot(sim)
	_check(not sim.blocks.has(Vector2i(3, 5)) and not sim.blocks.has(Vector2i(3, 6)), "a ball breaks the block in its path")
	_check(sim.total_damage >= 1 and sim.coins >= 1, "breaking grants damage and coins")


func _test_shot_ends_and_blocks_descend() -> void:
	var sim := _sim()
	_single_block(sim, Vector2i(0, 0), 9999)
	sim.launch_x = sim.cell_rect(Vector2i(4, 0)).get_center().x
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
	sim.launch_x = sim.cell_rect(Vector2i(6, 0)).get_center().x
	sim.fire(Vector2.UP)
	_run_shot(sim)
	_check(sim.state == GameSim.State.LOST, "reaching the death row loses the run")


func _test_bomb_chain() -> void:
	var sim := _sim()
	_single_block(sim, Vector2i(3, 5), 1, "bomb")
	sim.blocks[Vector2i(3, 4)] = {"hp": 1, "max_hp": 1, "kind": "bomb"}
	sim.blocks[Vector2i(3, 3)] = {"hp": 1, "max_hp": 1, "kind": "normal"}
	sim.blocks[Vector2i(0, 0)] = {"hp": 9999, "max_hp": 9999, "kind": "normal"}
	sim.ball_count = 1
	sim.launch_x = sim.cell_rect(Vector2i(3, 5)).get_center().x
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
	sim.levels["split"] = 5
	_single_block(sim, Vector2i(3, 2), 9999)
	sim.fire(Vector2.UP)
	var peak := 0
	var t := 0.0
	while sim.state == GameSim.State.SHOOT and t < 30.0:
		sim.step(DT)
		sim.events = []
		peak = max(peak, sim.balls.size())
		t += DT
	_check(peak > sim.ball_count, "split creates extra balls (peak %d)" % peak)
	_check(peak <= GameSim.MAX_BALLS, "ball count stays capped")


func _test_ricochet_adds_damage() -> void:
	var sim := _sim()
	sim.levels["ricochet"] = 3
	sim.ball_count = 1
	_single_block(sim, Vector2i(3, 0), 9999)
	sim.launch_x = GameSim.FIELD_X + 40.0
	sim.fire(Vector2(-1.0, -1.0))
	var biggest := 0
	var t := 0.0
	while sim.state == GameSim.State.SHOOT and t < 30.0:
		sim.step(DT)
		for e in sim.events:
			if e["type"] == "hit":
				biggest = max(biggest, int(e["damage"]))
		sim.events = []
		t += DT
	_check(biggest > 1, "wall bounces raise damage (max hit %d)" % biggest)


func _test_clear_offers_upgrades_and_advances() -> void:
	var sim := _sim()
	_single_block(sim, Vector2i(3, 5), 1)
	sim.launch_x = sim.cell_rect(Vector2i(3, 5)).get_center().x
	sim.fire(Vector2.UP)
	_run_shot(sim)
	_check(sim.state == GameSim.State.UPGRADE, "clearing a stage offers upgrades")
	_check(sim.choices.has("split") and sim.choices.has("bomb"), "first offer contains split and bomb")
	_check(not sim.choose_upgrade("ricochet"), "cannot pick an upgrade that was not offered")
	_check(sim.choose_upgrade("split"), "picking an offered upgrade works")
	_check(sim.stage == 1 and sim.state == GameSim.State.AIM and sim.levels["split"] == 1, "picking moves to the next stage")


func _test_more_balls_upgrade() -> void:
	var sim := _sim()
	sim.state = GameSim.State.UPGRADE
	sim.choices = ["more_balls"] as Array[String]
	var before := sim.ball_count
	sim.choose_upgrade("more_balls")
	_check(sim.ball_count == before + 4, "+4 balls adds four balls")


func _test_new_run_resets() -> void:
	var sim := _sim()
	sim.state = GameSim.State.LOST
	sim.total_damage = 500
	sim.coins = 20
	sim.levels["bomb"] = 2
	sim.stage = 3
	sim.new_run(2)
	_check(sim.state == GameSim.State.AIM and sim.total_damage == 0 and sim.coins == 0 and sim.stage == 0 and sim.levels["bomb"] == 0, "a new run resets everything")


func _test_same_seed_same_result() -> void:
	var a := _autoplay(77)
	var b := _autoplay(77)
	_check(a["damage"] == b["damage"] and a["time"] == b["time"], "same seed gives the same run")


func _test_shot_always_finishes() -> void:
	var sim := _sim()
	_single_block(sim, Vector2i(3, 0), 9999)
	sim.ball_count = 20
	sim.fire(Vector2(1.0, -0.15))
	var t := 0.0
	while sim.state == GameSim.State.SHOOT and t < 40.0:
		sim.step(DT)
		sim.events = []
		t += DT
	_check(sim.state != GameSim.State.SHOOT, "a shot always finishes (%.1fs)" % t)


func _test_languages_have_the_same_keys() -> void:
	var ja: Array = I18n.TEXT["ja"].keys()
	var en: Array = I18n.TEXT["en"].keys()
	ja.sort()
	en.sort()
	_check(ja == en, "Japanese and English define the same text keys")
	_check(I18n.DEFAULT_LANG == "ja", "Japanese is the base language")


func _test_every_upgrade_has_text() -> void:
	var ok := true
	for id in GameSim.UPGRADE_IDS:
		for lang in I18n.LANGS:
			ok = ok and I18n.TEXT[lang].has("upgrade_" + id) and I18n.TEXT[lang].has("upgrade_%s_desc" % id)
	_check(ok, "every upgrade has a title and description in both languages")


func _test_unknown_language_falls_back_to_japanese() -> void:
	_check(I18n.text("xx", "start") == I18n.text("ja", "start"), "an unknown language falls back to Japanese")


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
	fresh.record_run(123, 45, 3, 67, true)
	_check(fresh.save_file(), "saving succeeds")
	var loaded := SaveData.new(path)
	loaded.load_file()
	_check(loaded.lang == "en" and not loaded.sound, "settings survive a reload")
	_check(loaded.best_damage == 123 and loaded.best_combo == 45 and loaded.best_stage == 3, "bests survive a reload")
	_check(loaded.total_coins == 67 and loaded.wins == 1 and loaded.runs == 1, "totals survive a reload")
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
	file.store_string("{\"lang\": \"xx\", \"best_damage\": 9}")
	file.close()
	var odd := SaveData.new(path)
	odd.load_file()
	_check(odd.lang == "ja" and odd.best_damage == 9, "an unknown saved language becomes Japanese, records stay")
	DirAccess.remove_absolute(path)


func _test_record_run_keeps_bests() -> void:
	var data := SaveData.new(_temp_save_path("unused"))
	_check(data.record_run(100, 10, 2, 5, false), "the first run is a new best")
	_check(not data.record_run(50, 5, 1, 5, false), "a weaker run is not a new best")
	_check(data.best_damage == 100 and data.total_coins == 10 and data.runs == 2 and data.wins == 0, "bests stay, totals add up")


## Plays a whole run with a simple aim-at-lowest-block policy.
func _autoplay(seed_value: int, preferred := "") -> Dictionary:
	var sim := _sim(seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 1000
	var guard := 0
	var upgrades := 0
	while guard < 3000000:
		guard += 1
		match sim.state:
			GameSim.State.AIM:
				var best := Vector2(360.0, 400.0)
				var best_y := -1.0
				for cell: Vector2i in sim.blocks:
					var c := sim.cell_rect(cell).get_center()
					if c.y > best_y or (is_equal_approx(c.y, best_y) and rng.randf() < 0.3):
						best_y = c.y
						best = c
				var dir := (best - Vector2(sim.launch_x, GameSim.LAUNCH_Y)).rotated(rng.randf_range(-0.12, 0.12))
				sim.fire(dir)
			GameSim.State.SHOOT:
				sim.step(DT)
				sim.events = []
			GameSim.State.UPGRADE:
				upgrades += 1
				var pick: String = sim.choices[rng.randi_range(0, sim.choices.size() - 1)]
				if preferred != "" and sim.choices.has(preferred):
					pick = preferred
				sim.choose_upgrade(pick)
			_:
				break
	return {
		"won": sim.state == GameSim.State.WON,
		"stage": sim.stage,
		"damage": sim.total_damage,
		"time": sim.sim_time,
		"combo": sim.best_combo,
		"shots": sim.shots,
		"upgrades": upgrades,
	}


func _balance_report() -> void:
	print("--- balance (autoplay, 60 runs each) ---")
	for preferred: String in ["", "split", "bomb", "ricochet", "more_balls"]:
		var wins := 0
		var time_sum := 0.0
		var stage_sum := 0
		var combo_sum := 0
		var shots_sum := 0
		var n := 60
		for i in n:
			var r := _autoplay(i + 1, preferred)
			if r["won"]:
				wins += 1
			time_sum += r["time"]
			stage_sum += r["stage"]
			combo_sum += r["combo"]
			shots_sum += r["shots"]
		print("%-11s win %3d%%  avg_stage %.2f  shot_time %5.1fs  shots %4.1f  best_combo %5.1f" % [
			"random" if preferred == "" else preferred,
			100 * wins / n,
			float(stage_sum) / n + 1.0,
			time_sum / n,
			float(shots_sum) / n,
			float(combo_sum) / n,
		])
