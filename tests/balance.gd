extends SceneTree
## Plays long campaigns with a simple bot to expose pacing and balance problems.
## Run: godot --headless --path . -s tests/balance.gd -- campaign 120 1
## Modes: campaign <runs> <seed> | perks <runs> <seed> | balls <runs> <seed>

const GameSim := preload("res://sim/game_sim.gd")
const SaveData := preload("res://save_data.gd")
const Perks := preload("res://data/perks.gd")
const Balls := preload("res://data/balls.gd")
const Shop := preload("res://data/shop.gd")

const DT := 1.0 / 60.0
## What a person adds on top of simulated shot time.
const AIM_SECONDS := 2.0
const PICK_SECONDS := 3.0
const RUN_TIMEOUT_MSEC := 20000

var _shard := 0
var _shards := 1


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "campaign"
	var runs := int(args[1]) if args.size() > 1 else 60
	var seed_value := int(args[2]) if args.size() > 2 else 1
	_shard = int(args[3]) if args.size() > 3 else 0
	_shards = int(args[4]) if args.size() > 4 else 1
	match mode:
		"campaign":
			_campaign(runs, seed_value)
		"perks":
			_perk_table(runs, seed_value)
		"balls":
			_ball_table(runs, seed_value)
	quit()


## Plays one run. `given` starts owned at level 2 (or its max); other picks are random.
func _play(config: Dictionary, seed_value: int, given := "") -> Dictionary:
	var sim := GameSim.new()
	var run_config := config.duplicate()
	run_config["emit_events"] = false
	sim.new_run(seed_value, run_config)
	if given != "":
		sim.levels[given] = mini(2, int(Perks.PERKS[given]["max"]))
		sim._recompute_stats()
		sim.rerolls = int(sim.stat("rerolls"))
		sim.guards = int(sim.stat("guards"))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	var picks := 0
	var seen := {}
	var first_burst_stage := 0
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < RUN_TIMEOUT_MSEC:
		match sim.state:
			GameSim.State.AIM:
				if sim.can_burst():
					if first_burst_stage == 0:
						first_burst_stage = sim.stage + 1
					sim.trigger_burst()
				else:
					sim.fire(_aim(sim, rng))
			GameSim.State.SHOOT:
				sim.step(DT)
			GameSim.State.UPGRADE:
				picks += 1
				for id in sim.choices:
					seen[id] = true
				var pick: String = sim.choices[rng.randi_range(0, sim.choices.size() - 1)]
				sim.choose_upgrade(pick)
			_:
				break
	return {
		"won": sim.state == GameSim.State.WON,
		"timeout": sim.state != GameSim.State.WON and sim.state != GameSim.State.LOST,
		"stage": sim.stage + 1,
		"damage": sim.total_damage,
		"combo": sim.best_combo,
		"best_shot": sim.best_shot_damage,
		"coins": sim.coins,
		"tier": sim.tier,
		"ball_type": sim.ball_type,
		"counters": sim.counters,
		"seconds": sim.sim_time + sim.shots * AIM_SECONDS + picks * PICK_SECONDS,
		"seen": seen,
		"first_burst_stage": first_burst_stage,
	}


## Usually looks for a gap to shoot through, like a person would; otherwise takes the
## threat at the bottom. Both carry a little human-like error.
func _aim(sim: GameSim, rng: RandomNumberGenerator) -> Vector2:
	if rng.randf() < 0.6:
		return _aim_through_gap(sim, rng)
	return _aim_at_lowest(sim, rng)


func _aim_through_gap(sim: GameSim, rng: RandomNumberGenerator) -> Vector2:
	var best_dir := Vector2.UP
	var best_length := -1.0
	for i in 15:
		var dir := Vector2.UP.rotated(deg_to_rad(-70.0 + i * 10.0))
		var points := sim.trace_aim(dir)
		var length := 0.0
		for p in range(points.size() - 1):
			length += points[p].distance_to(points[p + 1])
		if length > best_length:
			best_length = length
			best_dir = dir
	return best_dir.rotated(rng.randf_range(-0.05, 0.05))


func _aim_at_lowest(sim: GameSim, rng: RandomNumberGenerator) -> Vector2:
	var best := Vector2(360.0, 400.0)
	var best_y := -1.0
	for cell: Vector2i in sim.blocks:
		var c := sim.cell_rect(cell).get_center()
		if c.y > best_y or (is_equal_approx(c.y, best_y) and rng.randf() < 0.3):
			best_y = c.y
			best = c
	return (best - Vector2(sim.launch_x, GameSim.LAUNCH_Y)).rotated(rng.randf_range(-0.12, 0.12))


func _record(save: SaveData, result: Dictionary) -> void:
	save.record_run({
		"damage": result["damage"],
		"combo": result["combo"],
		"best_shot": result["best_shot"],
		"stage": result["stage"],
		"coins": result["coins"],
		"won": result["won"],
		"tier": result["tier"],
		"ball_type": result["ball_type"],
		"counters": result["counters"],
	})
	for id: String in result["seen"]:
		save.mark_perk_seen(id)
	save.check_achievements()


## Spends coins the way a player would: damage first, then whatever is cheapest.
func _spend(save: SaveData) -> void:
	var bought := true
	while bought:
		bought = false
		var best := ""
		var best_cost := INF
		for id in Shop.ids():
			if save.can_buy(id) and float(save.shop_cost(id)) < best_cost:
				best = id
				best_cost = save.shop_cost(id)
		if best != "":
			save.buy(best)
			bought = true


func _campaign(total_runs: int, seed_value: int) -> void:
	var save := SaveData.new(OS.get_temp_dir().path_join("burst_breaker_balance_%d.json" % seed_value))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var first_win := -1
	var recent_wins: Array[bool] = []
	var seconds_sum := 0.0
	var bursts_sum := 0
	var first_burst_stage_sum := 0
	var runs_with_burst := 0
	var timeouts := 0
	print("run  tier  ball      stage  win   time  coins   wallet  stars  shop  ach  perks  winrate20")
	for run in range(1, total_runs + 1):
		save.tier = _choose_tier(save, recent_wins)
		var unlocked: Array[String] = []
		for id in Balls.ids():
			if save.is_ball_unlocked(id):
				unlocked.append(id)
		save.ball_type = unlocked[rng.randi_range(0, unlocked.size() - 1)]
		var result := _play(save.run_config(false), seed_value * 1000 + run)
		_record(save, result)
		_spend(save)
		if result["timeout"]:
			timeouts += 1
		seconds_sum += float(result["seconds"])
		bursts_sum += int(result["counters"]["bursts"])
		if run <= 10:
			first_burst_stage_sum += int(result["first_burst_stage"])
			runs_with_burst += 1 if int(result["first_burst_stage"]) > 0 else 0
		var won: bool = result["won"]
		if won and first_win < 0:
			first_win = run
		recent_wins.append(won)
		if recent_wins.size() > 20:
			recent_wins.pop_front()
		# A sensible player prestiges once the shop has flattened out and the payoff is real.
		if save.can_prestige() and save.shop_level("damage") >= 18 and save.stars_on_prestige() >= maxi(3, save.stars / 2):
			save.prestige()
		if run <= 10 or run % 10 == 0:
			var wins := 0
			for w in recent_wins:
				wins += 1 if w else 0
			var shop_total := 0
			for key: String in save.shop:
				shop_total += int(save.shop[key])
			print("%3d  %4d  %-8s  %5d  %-4s  %4ds  %6d  %7d  %5d  %4d  %3d  %5d  %3d%%" % [
				run, result["tier"], result["ball_type"], result["stage"], "WIN" if won else "-", int(result["seconds"]),
				result["coins"], save.coins, save.stars, shop_total, save.achievements.size(), save.perks_seen.size(), 100 * wins / recent_wins.size(),
			])
	print("first_win=%d max_tier=%d stars=%d achievements=%d avg_run=%ds total_hours=%.1f timeouts=%d bursts_per_run=%.1f early_runs_with_burst=%d/10 early_first_burst_stage=%.1f" % [
		first_win, save.max_tier(), save.stars, save.achievements.size(), int(seconds_sum / total_runs), seconds_sum / 3600.0, timeouts,
		float(bursts_sum) / total_runs, runs_with_burst, float(first_burst_stage_sum) / maxi(runs_with_burst, 1),
	])


## Plays the highest tier while winning, and keeps stepping down during a losing streak.
func _choose_tier(save: SaveData, recent: Array[bool]) -> int:
	var top := save.max_tier()
	var losses := 0
	for i in range(recent.size() - 1, -1, -1):
		if recent[i]:
			break
		losses += 1
	return maxi(top - losses / 2, 0)


func _fixed_config() -> Dictionary:
	return {"tier": 0, "stars": 0, "shop": {"damage": 10, "balls": 4, "crit": 4}, "unlocked_perks": null}


func _perk_table(runs: int, seed_value: int) -> void:
	var rows: Array[Array] = []
	var ids: Array = [""] + Perks.ids()
	for index in ids.size():
		var id: String = ids[index]
		if index % _shards != _shard or (id != "" and Perks.is_evolution(id)):
			continue
		var wins := 0
		var damage := 0
		for i in runs:
			var r := _play(_fixed_config(), seed_value * 7919 + i, id)
			wins += 1 if r["won"] else 0
			damage += int(r["damage"])
		rows.append([100 * wins / runs, id if id != "" else "(random)", damage / runs])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for row in rows:
		print("%3d%%  %-16s avg_damage=%d" % [row[0], row[1], row[2]])


func _ball_table(runs: int, seed_value: int) -> void:
	var ids := Balls.ids()
	for index in ids.size():
		var id := ids[index]
		if index % _shards != _shard:
			continue
		var wins := 0
		var seconds := 0.0
		var combo := 0
		var stage := 0
		for i in runs:
			var config := _fixed_config()
			config["ball_type"] = id
			var r := _play(config, seed_value * 104729 + i)
			wins += 1 if r["won"] else 0
			seconds += float(r["seconds"])
			combo += int(r["combo"])
			stage += int(r["stage"])
		print("%-9s win %3d%%  stage %.1f  run %3ds  combo %4d" % [id, 100 * wins / runs, float(stage) / runs, int(seconds / runs), combo / runs])
