extends "res://game_screens.gd"
## Reactions to what happens in play: particles, shakes, slow motion and boss moments.


## Slow motion around the end of a stage. Only the view slows, so the rules stay exact.
func _time_rate(delta: float) -> float:
	zoom_target = 1.0
	if finish_time > 0.0:
		zoom_target = FINISH_ZOOM
		return FINISH_SLOW
	if sim.state != GameSim.State.SHOOT or tension_left <= 0.0:
		return 1.0
	var target: Variant = _last_target()
	if target == null:
		return 1.0
	tension_left -= delta
	zoom_target = TENSION_ZOOM
	zoom_focus = sim.block_rect(target).get_center()
	return TENSION_SLOW

## The one thing left standing between the player and the end of the stage, if there is one.
func _last_target() -> Variant:
	if sim.waves_left > 0:
		return null
	if sim.boss_block != null:
		var boss: Dictionary = sim.boss_block
		return boss if float(boss["hp"]) / float(boss["max_hp"]) <= TENSION_BOSS_HP else null
	# A big block covers several cells but is still only one target.
	if sim.blocks.size() <= 4 and sim.unique_blocks().size() == 1:
		return sim.blocks.values()[0]
	return null

func _begin_finish(pos: Vector2) -> void:
	if finish_time > 0.0:
		return
	finish_time = FINISH_SECONDS
	zoom_focus = pos
	screen_flash = maxf(screen_flash, 0.8)
	trauma = maxf(trauma, 0.8)
	impact = maxf(impact, 0.02)
	_play("blast", 1.2)
	_spawn_particles(pos, UI.GOLD, 50, 800.0)
	_spawn_particles(pos, Color.WHITE, 40, 1100.0)
	rings.append({"pos": pos, "t": 0.0, "size": 260.0})
	if save.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(60)

func _begin_evolve_cut(id: String) -> void:
	evolve_cut = 0.0
	evolve_id = id
	evolve_hit = false
	aiming = false
	_play("charge", 1.4)

## Two parents fly in and collide. The game waits, since this is the build's big moment.
func _process_evolve_cut(delta: float) -> void:
	evolve_cut += delta
	if not evolve_hit and evolve_cut >= EVOLVE_IMPACT:
		evolve_hit = true
		trauma = 1.0
		screen_flash = 1.0
		impact = 0.04
		_play("blast", 1.0)
		_play("win", 1.3)
		if save.vibration and OS.has_feature("mobile"):
			Input.vibrate_handheld(100)
	if evolve_cut >= EVOLVE_SECONDS:
		evolve_cut = -1.0

func _show_rank(rank: int) -> void:
	if rank < RANK_SHOW_FROM:
		return
	rank_shown = rank
	rank_time = RANK_SECONDS
	if rank >= GameSim.RANK_S:
		_play("win", 1.2 + (rank - GameSim.RANK_S) * 0.2)
		trauma = minf(trauma + 0.25, 1.0)

## The results count up with rising ticks, so a good run takes a moment to sink in.
func _process_count_up(delta: float) -> void:
	var before := end_age
	end_age += delta
	if sim.coins <= 0 or before >= COUNT_UP_SECONDS:
		return
	if end_age >= COUNT_UP_SECONDS:
		_play("win", 1.5)
		trauma = maxf(trauma, 0.3)
	elif time - last_tick_sound >= COUNT_UP_TICK:
		last_tick_sound = time
		_play("coin", 0.9 + end_age / COUNT_UP_SECONDS)

func _begin_burst() -> void:
	if not sim.can_burst():
		return
	burst_windup = 0.0
	burst_origin = Vector2(sim.launch_x, GameSim.LAUNCH_Y)
	aiming = false
	_play("charge", 1.0)
	trauma = 0.25

func _begin_boss_intro(id: String) -> void:
	boss_intro = 0.0
	boss_intro_id = id
	boss_intro_slammed = false
	boss_rage_said = false
	speech_time = 0.0
	speech_cooldown = SPEECH_COOLDOWN
	aiming = false
	_play("charge", 0.6)
	save.mark_boss_met(id)
	save.save_file()

## The boss drops in, the screen jumps, and it gets to say its piece.
func _process_boss_intro(delta: float) -> void:
	boss_intro += delta
	if not boss_intro_slammed and boss_intro >= 0.42:
		boss_intro_slammed = true
		trauma = 1.0
		impact = 0.03
		screen_flash = 0.7
		_play("boom", 0.55)
		_spawn_particles(Vector2(BASE_W / 2.0, 560.0), Bosses.color(boss_intro_id), 60, 900.0)
		if save.vibration and OS.has_feature("mobile"):
			Input.vibrate_handheld(80)
	if boss_intro >= BOSS_INTRO:
		boss_intro = -1.0

func _say(key: String, always := false) -> void:
	if not always and speech_cooldown > 0.0:
		return
	speech_text = t(key)
	speech_time = SPEECH_SECONDS
	speech_cooldown = SPEECH_COOLDOWN

func _on_boss_action(e: Dictionary) -> void:
	var action: String = e["action"]
	var color := Bosses.color(e["boss"])
	match action:
		"split":
			_play("pop", 0.7)
			trauma = minf(trauma + 0.3, 1.0)
		"chomp", "heal":
			var amount: int = e["amount"]
			if amount > 0:
				numbers.append({"pos": e["pos"] + Vector2(0.0, -30.0), "text": "+" + I18n.format_number(amount), "t": 0.0, "big": true, "dot": true})
				_spawn_particles(e["pos"], BOSS_HEAL_COLOR, 18, 260.0)
				_play("coin", 0.7)
		"throw":
			_play("fire", 0.6)
		"guards":
			_play("pick", 0.7)
		"aim":
			_play("charge", 1.6)
		"blink":
			_play("pick", 0.6)
			_spawn_particles(e["pos"], color, 28, 520.0)
		"freeze":
			_play("pick", 1.8)
		"veil":
			_play("charge", 1.8)
			rings.append({"pos": e["pos"], "t": 0.0, "size": 180.0})
		"drain":
			_play("charge", 0.7)
			_spawn_particles(Vector2(BASE_W / 2.0, 1250.0), color, 16, 300.0)
		"rebirth":
			_play("blast", 0.9)
			_play("win", 1.1)
			screen_flash = 1.0
			trauma = 1.0
			impact = 0.03
			_spawn_particles(e["pos"], color, 90, 1000.0)
			boss_rage_said = true
			_say("boss_homura_angry", true)
			return
		"laser":
			_play("blast", 1.3)
			trauma = minf(trauma + 0.6, 1.0)
			impact = maxf(impact, 0.012)
			for col: int in e["cols"]:
				beams.append({"col": col, "t": 0.0})
	for target: Vector2 in e.get("targets", []):
		_spawn_particles(target, color, 14, 320.0)
		rings.append({"pos": target, "t": 0.0, "size": 70.0})
		if bolts.size() < 24 and action == "throw":
			bolts.append({"to": target, "x": (e["pos"] as Vector2).x, "t": 0.0})
	if action != "aim" or randf() < 0.5:
		_say("boss_%s_trick" % String(e["boss"]))

func _show_banner(text: String, seconds: float) -> void:
	banner_text = text
	banner_time = seconds

func _on_hit(e: Dictionary) -> void:
	flash[e["block_id"]] = 1.0
	var combo: int = e["combo"]
	var is_crit: bool = e["crit"]
	# Only crits get a number: a screen full of small ones reads as noise.
	if is_crit and numbers.size() < 70:
		numbers.append({
			"pos": e["pos"] + Vector2(randf_range(-18.0, 18.0), -10.0),
			"text": I18n.format_number(e["damage"]),
			"t": 0.0,
			"big": is_crit,
			"dot": e["dot"],
		})
	if is_crit:
		_spawn_particles(e["pos"], UI.GOLD, 8, 300.0)
		impact = maxf(impact, 0.004)
	if e["dot"]:
		return
	_spawn_particles(e["pos"], _combo_color(combo), 2, 150.0)
	combo_pop = 1.0
	# Long chains climb through stages, each with its own burst of light.
	if combo_stage < COMBO_STAGES.size() and combo >= COMBO_STAGES[combo_stage]:
		combo_stage += 1
		rings.append({"pos": e["pos"], "t": 0.0, "size": 200.0 + combo_stage * 120.0})
		impact = maxf(impact, 0.012 * combo_stage)
	if combo < 2:
		combo_stage = 0
	if time - last_hit_sound > 0.03:
		last_hit_sound = time
		# Climb a pentatonic scale with the combo so long chains audibly rise.
		var scale_steps := [0, 2, 4, 7, 9]
		var octave := mini(combo / 5, 3)
		var semitones: int = scale_steps[combo % 5] + octave * 12
		_play("hit", pow(2.0, semitones / 12.0))
	if combo >= next_milestone:
		_show_banner(t("hits_banner") % next_milestone, 0.9)
		screen_flash = 0.35
		trauma = minf(trauma + 0.4, 1.0)
		impact = maxf(impact, 0.016)
		_play("win", 1.5)
		next_milestone = next_milestone * 2

func _on_kill(e: Dictionary) -> void:
	var kind: String = e["kind"]
	var color: Color = UI.BLOCKS.get(kind, UI.ramp(randf()))
	var is_boss := kind == "boss"
	if is_boss or (sim.blocks.is_empty() and sim.waves_left <= 0):
		_begin_finish(e["pos"])
	if int(e.get("overkill", 0)) > 0:
		_on_overkill(e)
	_spawn_particles(e["pos"], color, 70 if is_boss else 16, 900.0 if is_boss else 420.0)
	_spawn_particles(e["pos"], Color.WHITE, 30 if is_boss else 6, 600.0 if is_boss else 280.0)
	trauma = minf(trauma + (1.0 if is_boss else 0.12), 1.0)
	hitstop = maxf(hitstop, 0.15 if is_boss else 0.012)
	if is_boss:
		screen_flash = 1.0
		impact = 0.03
		_play("boom", 0.6)
		boss_down = BOSS_DOWN_HOLD
		boss_down_id = e["boss_id"]
		boss_down_pos = e["pos"]
		boss_crack = BOSS_DOWN_HOLD
		boss_crack_pos = e["pos"]
		_say("boss_%s_defeat" % boss_down_id, true)
		_show_banner(t("boss_down") % t("boss_%s_name" % boss_down_id), BOSS_DOWN_HOLD)
	if time - last_pop_sound > 0.025:
		last_pop_sound = time
		_play("pop", randf_range(0.9, 1.2))
	if save.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(40 if is_boss else 10)
	for i in mini(int(e["coins"]), 30 if is_boss else 6):
		if fly_coins.size() >= 80:
			break
		fly_coins.append({
			"pos": e["pos"],
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(180.0, 460.0),
			"t": 0.0,
		})

## Outgrown blocks burst harder and say so, but never so often that the text becomes noise.
func _on_overkill(e: Dictionary) -> void:
	_spawn_particles(e["pos"], UI.GOLD, 10 + int(e["overkill"]) * 4, 620.0)
	if time - last_overkill_text < OVERKILL_TEXT_GAP:
		return
	last_overkill_text = time
	numbers.append({"pos": e["pos"] + Vector2(0.0, -24.0), "text": t("overkill"), "t": 0.0, "big": true, "dot": false})

func _on_explode(e: Dictionary) -> void:
	verify_stats["explosions"] = int(verify_stats["explosions"]) + 1
	if rings.size() < 40:
		rings.append({"pos": e["pos"], "t": 0.0, "size": 170.0 * int(e.get("radius", 1))})
	_spawn_particles(e["pos"], UI.BLOCKS["bomb"], 26, 620.0)
	_spawn_particles(e["pos"], UI.GOLD, 14, 420.0)
	trauma = minf(trauma + 0.35, 1.0)
	impact = maxf(impact, 0.009)
	screen_flash = maxf(screen_flash, 0.14)
	if time - last_boom_sound > 0.05:
		last_boom_sound = time
		_play("boom", randf_range(0.85, 1.15))
	if time - last_boom_stop > 0.14:
		last_boom_stop = time
		hitstop = maxf(hitstop, 0.035)

func _big_celebration() -> void:
	for i in 14:
		var pos := Vector2(randf_range(80.0, 640.0), randf_range(240.0, 900.0))
		rings.append({"pos": pos, "t": -randf() * 0.4, "size": 170.0})
		_spawn_particles(pos, UI.ramp(randf()), 18, 560.0)

func _spawn_particles(pos: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		if particles.size() >= 450:
			return
		particles.append({
			"pos": pos,
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(speed * 0.3, speed),
			"t": 0.0,
			"life": randf_range(0.25, 0.55),
			"color": color,
			"size": randf_range(4.0, 10.0),
		})

func _update_fx(delta: float) -> void:
	trauma = maxf(trauma - delta * 2.2, 0.0)
	descend_anim = maxf(descend_anim - delta * 6.0, 0.0)
	for entry: Dictionary in sim.obstacles.values():
		entry["pulse"] = maxf(float(entry["pulse"]) - delta * OBSTACLE_PULSE_DECAY, 0.0)
	banner_time = maxf(banner_time - delta, 0.0)
	combo_pop = maxf(combo_pop - delta * 8.0, 0.0)
	coin_pop = maxf(coin_pop - delta * 7.0, 0.0)
	screen_flash = maxf(screen_flash - delta * 2.5, 0.0)
	speech_time = maxf(speech_time - delta, 0.0)
	speech_cooldown = maxf(speech_cooldown - delta, 0.0)
	for beam in beams:
		beam["t"] = float(beam["t"]) + delta
	beams = beams.filter(func(beam: Dictionary) -> bool: return float(beam["t"]) < 0.45)
	for id in flash.keys():
		flash[id] = float(flash[id]) - delta * 9.0
		if float(flash[id]) <= 0.0:
			flash.erase(id)
	var i := particles.size() - 1
	while i >= 0:
		var p := particles[i]
		p["t"] = float(p["t"]) + delta
		p["pos"] = p["pos"] + p["vel"] * delta
		p["vel"] = p["vel"] * 0.93 + Vector2(0.0, 900.0 * delta)
		if float(p["t"]) >= float(p["life"]):
			particles.remove_at(i)
		i -= 1
	i = numbers.size() - 1
	while i >= 0:
		var n := numbers[i]
		n["t"] = float(n["t"]) + delta
		n["pos"] = n["pos"] + Vector2(0.0, -90.0 * delta)
		if float(n["t"]) > 0.55:
			numbers.remove_at(i)
		i -= 1
	i = fly_coins.size() - 1
	var target := Vector2(640.0, 98.0)
	while i >= 0:
		var c := fly_coins[i]
		c["t"] = float(c["t"]) + delta
		if float(c["t"]) < 0.22:
			c["pos"] = c["pos"] + c["vel"] * delta
			c["vel"] = c["vel"] * 0.9
		else:
			# Vacuum toward the counter, accelerating, so collection feels greedy.
			var pull := (float(c["t"]) - 0.22) * 18.0
			c["pos"] = (c["pos"] as Vector2).lerp(target, minf(pull * delta * 6.0, 1.0))
			if (c["pos"] as Vector2).distance_to(target) < 22.0:
				fly_coins.remove_at(i)
				coin_pop = 1.0
				if randf() < 0.4:
					_play("coin", randf_range(1.0, 1.3))
		i -= 1
	i = rings.size() - 1
	while i >= 0:
		var r := rings[i]
		r["t"] = float(r["t"]) + delta
		if float(r["t"]) > 0.35:
			rings.remove_at(i)
		i -= 1
	i = bolts.size() - 1
	while i >= 0:
		var b := bolts[i]
		b["t"] = float(b["t"]) + delta
		if float(b["t"]) > 0.14:
			bolts.remove_at(i)
		i -= 1
	i = toasts.size() - 1
	# Only the oldest toast counts down, so several unlocks show one after another.
	if not toasts.is_empty():
		toasts[0]["t"] = float(toasts[0]["t"]) + delta
		if float(toasts[0]["t"]) > 2.2:
			toasts.remove_at(0)
