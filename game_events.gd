extends "res://game_effects.gd"
## Turning the rules' events into reactions, and keeping the save in step with the run.


## Chapters and stages each colour the sky, unless the player has chosen one of their own.
func _apply_sky() -> void:
	var worn: Array = Cosmetics.ITEMS[save.wearing("sky")]["colors"]
	var sky: Array = worn if not worn.is_empty() else Worlds.WORLDS["wall" if screen != Menus.Screen.GAME else sim.world]["sky"]
	var shift := sim.stage * STAGE_SKY_SHIFT if screen == Menus.Screen.GAME and worn.is_empty() else 0.0
	background_material.set_shader_parameter("sky_a", _as_rgb((sky[0] as Color).lerp(sky[1], shift)))
	background_material.set_shader_parameter("sky_b", _as_rgb((sky[1] as Color).lerp(sky[2], shift)))
	background_material.set_shader_parameter("sky_c", _as_rgb((sky[2] as Color).lerp(sky[0], shift)))

func _as_rgb(color: Color) -> Vector3:
	return Vector3(color.r, color.g, color.b)

func _run_summary() -> Dictionary:
	return {
		"damage": sim.total_damage,
		"combo": sim.best_combo,
		"best_shot": sim.best_shot_damage,
		"stage": sim.stage + 1,
		"coins": sim.coins,
		"won": sim.state == GameSim.State.WON,
		"tier": sim.tier,
		"ball_type": sim.ball_type,
		"counters": sim.counters,
	}

## Keeps the save up to date with the run in progress. The next launch banks whatever was
## left here, so the run itself is lost if the app closes but what it earned is not.
func _stash_run() -> void:
	if not run_banked and sim.total_damage > 0:
		save.stash_run(_run_summary())

## Checks achievements against saved totals plus the run in progress, then saves.
func on_progress_changed(live := {}) -> void:
	_announce(save.check_achievements(live))
	_stash_run()
	save.save_file()

func on_star_raised() -> void:
	_play("win", 1.7)
	on_progress_changed()

func on_shop_bought(id: String, chain: int) -> void:
	_play("coin", 1.1 + minf(chain * 0.03, 1.2))
	if Shop.is_milestone(id, save.shop_level(id)):
		_play("win", 1.4)
		trauma = minf(trauma + 0.6, 1.0)
		if save.vibration and OS.has_feature("mobile"):
			Input.vibrate_handheld(50)
	on_progress_changed()

func _announce(unlocked: Array[Dictionary]) -> void:
	var opened_content := false
	for entry in unlocked:
		toasts.append({"text": t("achievement_toast") % menus.achievement_title(entry["id"]), "t": 0.0})
		if Achievements.PERK_UNLOCKS.values().has(entry["id"]):
			opened_content = true
		for id in Balls.ids():
			if Balls.BALLS[id]["unlock"] == entry["id"]:
				opened_content = true
	if opened_content:
		toasts.append({"text": t("unlock_toast"), "t": 0.0})
	if not unlocked.is_empty():
		_play("win", 1.7)

func _live_stats() -> Dictionary:
	var live := {
		"damage": sim.total_damage,
		"coins": sim.coins,
		"best_combo": sim.best_combo,
		"best_shot": sim.best_shot_damage,
	}
	live.merge(sim.counters)
	return live

## The game holds its breath while the cut-in plays, then the move lands all at once.
func _process_burst_windup(delta: float) -> void:
	burst_windup += delta
	trauma = maxf(trauma, burst_windup / BURST_WINDUP * 0.35)
	heat = 1.0
	if burst_windup < BURST_WINDUP:
		return
	burst_windup = -1.0
	burst_was_ready = false
	sim.trigger_burst()
	burst_after = BURST_AFTERGLOW
	screen_flash = 1.0
	trauma = 1.0
	impact = 0.05
	hitstop = 0.09
	_play("blast", 0.8)
	_play("boom", 0.6)
	if save.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(120)
	_spawn_particles(burst_origin, Color.WHITE, 120, 1500.0)
	_consume_events()

func _note_offered_perks() -> void:
	if sim.choices == seen_choices:
		return
	seen_choices = sim.choices.duplicate()
	for id in seen_choices:
		save.mark_perk_seen(id)
	if not seen_choices.is_empty():
		on_progress_changed(_live_stats())

func _consume_events() -> void:
	var events := sim.events
	sim.events = []
	for e in events:
		match String(e["type"]):
			"fire":
				_play("fire", 1.0)
			"hit":
				_on_hit(e)
			"kill":
				_on_kill(e)
			"explode":
				_on_explode(e)
			"split":
				verify_stats["splits"] = int(verify_stats["splits"]) + 1
				_spawn_particles(e["pos"], Color.WHITE, 4, 160.0)
			"wall":
				_spawn_particles(e["pos"], UI.MUTED, 2, 90.0)
			"rebound":
				_spawn_particles(e["pos"], UI.MINT, 6, 220.0)
			"shock":
				if bolts.size() < 24:
					bolts.append({"to": e["pos"], "x": (e["pos"] as Vector2).x + randf_range(-60.0, 60.0), "t": 0.0})
			"regen":
				_spawn_particles(e["pos"], UI.BLOCKS["regen"], 3, 90.0)
			"breed":
				_spawn_particles(e["pos"], UI.BLOCKS["breeder"], 8, 180.0)
			"companion":
				_play("pick", 2.0)
			"switch":
				_play("pick", 0.8)
				_spawn_particles(e["pos"], UI.MINT, 10, 260.0)
			"unlock":
				_show_banner(t("unlock_banner"), 1.0)
				_play("win", 1.4)
				for p: Vector2 in e["targets"]:
					_spawn_particles(p, UI.GOLD, 10, 360.0)
			"part_broken":
				_show_banner(t("part_banner"), 1.0)
				_play("boom", 0.9)
				trauma = minf(trauma + 0.6, 1.0)
				_spawn_particles(e["pos"], UI.BLOCKS["part"], 40, 700.0)
			"relic_set":
				toasts.append({"text": t("set_toast") % t(String(e["id"])), "t": 0.0})
				_play("win", 1.8)
			"bonus_start":
				_show_banner(t("bonus_banner"), 1.0)
			"bonus_end":
				_play("win", 1.3)
			"relic":
				toasts.append({"text": t("relic_toast") % t("relic_" + String(e["id"])), "t": 0.0})
				_play("win", 1.5)
			"mission":
				toasts.append({"text": t("mission_toast") % I18n.format_number(e["coins"]), "t": 0.0})
				_play("win", 1.6)
			"gamble":
				_play("win" if e["won"] else "lose", 1.0)
				_show_banner(t("gamble_won" if e["won"] else "gamble_lost"), 1.0)
			"bumper":
				_spawn_particles(e["pos"], UI.STAR, 8, 320.0)
				if time - last_bumper_sound > 0.05:
					last_bumper_sound = time
					_play("pick", randf_range(1.5, 1.8))
			"portal":
				_spawn_particles(e["from"], OBSTACLE_PORTAL, 6, 220.0)
				_spawn_particles(e["to"], OBSTACLE_PORTAL, 6, 220.0)
			"plague":
				_spawn_particles(e["pos"], Color("2f9e44"), 6, 200.0)
			"extra_ball":
				_show_banner("+1", 0.5)
			"guard":
				_show_banner(t("guard_banner"), 1.0)
				screen_flash = 0.7
				trauma = 1.0
				_play("boom", 0.7)
			"stalled":
				_show_banner(t("stalled_banner"), 0.6)
			"descend":
				descend_anim = 1.0
			"shot_end":
				on_progress_changed(_live_stats())
			"shot_rank":
				_show_rank(int(e["rank"]))
			"perk_taken":
				if Perks.is_evolution(e["id"]):
					_begin_evolve_cut(e["id"])
			"burst_end":
				if not sim.blocks.is_empty():
					_show_banner(I18n.format_number(e["damage"]), 1.2)
			"stage_start":
				tension_left = TENSION_SECONDS
				_apply_sky()
				if sim.modifier != "" and int(e["stage"]) > 0:
					_show_banner(t("modifier_" + sim.modifier), 1.0)
					continue
				if int(e["stage"]) == 0 and not e["boss"] and sim.world != "wall":
					_show_banner(t("world_" + sim.world), 1.2)
					continue
				if e["boss"]:
					_begin_boss_intro(e["boss_id"])
				else:
					_show_banner(t("stage_banner") % (int(e["stage"]) + 1), 1.0)
			"boss_action":
				_on_boss_action(e)
			"boss_angry":
				if not boss_rage_said:
					boss_rage_said = true
					_say("boss_%s_angry" % String(e["boss"]), true)
					trauma = minf(trauma + 0.5, 1.0)
					_spawn_particles(e["pos"], UI.DANGER, 30, 500.0)
					_play("charge", 1.3)
			"stage_clear":
				_play("win", 1.0)
				trauma = minf(trauma + 0.5, 1.0)
				screen_flash = 0.5
				# The whole field's takings rush to the counter at once.
				for i in 26:
					if fly_coins.size() < 80:
						fly_coins.append({"pos": Vector2(randf_range(80.0, 640.0), randf_range(200.0, 900.0)), "vel": Vector2.from_angle(randf() * TAU) * randf_range(100.0, 500.0), "t": 0.0})
			"fever":
				_show_banner(t("fever"), 1.1)
				screen_flash = maxf(screen_flash, 0.5)
				_play("win", 1.9)
			"jackpot":
				_show_banner(t("jackpot"), 1.3)
				toasts.append({"text": "+" + I18n.format_number(e["coins"]), "t": 0.0})
				_play("win", 2.0)
				for i in 40:
					if fly_coins.size() < 80:
						fly_coins.append({"pos": Vector2(BASE_W / 2.0, 500.0), "vel": Vector2.from_angle(randf() * TAU) * randf_range(200.0, 900.0), "t": 0.0})
			"bounty":
				_show_banner(t("bounty_banner"), 1.0)
				_play("charge", 1.7)
			"bounty_escaped":
				toasts.append({"text": t("bounty_escaped"), "t": 0.0})
			"note":
				if save.add_note():
					toasts.append({"text": t("note_toast") % save.notes, "t": 0.0})
					save.save_file()
			"won":
				if sim.boss_id() == "" and int(sim.counters.get("boss_origin", 0)) > 0:
					pending_ending = true
				_play("win", 1.25)
				trauma = 1.0
				screen_flash = 0.8
				_big_celebration()
			"lost":
				_play("lose", 1.0)
				trauma = 0.8
