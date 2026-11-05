extends RefCounted
## Scripted end-to-end check: real input events, real rendering, saved screenshots.

const Bosses := preload("res://data/bosses.gd")
const Menus := preload("res://menus.gd")
const GameSim := preload("res://sim/game_sim.gd")
const SaveData := preload("res://save_data.gd")

var host: Node2D
var dir := ""
var checks := {}
var play_ms := 45000


func _init(host_node: Node2D, output_dir: String) -> void:
	host = host_node
	dir = output_dir
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--verify-play-seconds="):
			play_ms = int(arg.get_slice("=", 1)) * 1000


func run() -> void:
	Engine.time_scale = 3.0
	await _wait(0.5)
	_check("starts_on_title", host.screen == Menus.Screen.TITLE)
	_check("default_language_is_japanese", host.save.lang == "ja")
	await _shot("01_title_ja")
	await _verify_settings()
	await _tap_button("howto")
	await _shot("03_howto_ja")
	await _tap_button("back")
	await _tap_button("start")
	_check("first_start_skips_loadout", host.screen == Menus.Screen.GAME and host.sim.state == GameSim.State.AIM)
	await _shot("04_game_start_ja")
	await _verify_aim_controls()
	await _verify_pause()
	await _verify_play()
	await _verify_end()
	await _verify_specials()
	await _verify_meta_screens()
	await _verify_english()
	var ok := true
	for key: String in checks:
		ok = ok and bool(checks[key])
	var report := {"ok": ok, "failed": checks.keys().filter(func(k: String) -> bool: return not checks[k]), "checks": checks.size(), "stats": host.verify_stats}
	var file := FileAccess.open(dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	Engine.time_scale = 1.0
	host.get_tree().quit(0 if ok else 1)


func _verify_settings() -> void:
	await _tap_button("settings")
	_check("settings_opens", host.screen == Menus.Screen.SETTINGS)
	await _shot("02_settings_ja")
	await _tap_button("sound")
	_check("sound_toggles_off", not host.save.sound and AudioServer.is_bus_mute(0))
	await _tap_button("sound")
	_check("sound_toggles_on", host.save.sound and not AudioServer.is_bus_mute(0))
	await _tap_button("vibration")
	_check("vibration_toggles", not host.save.vibration)
	await _tap_button("vibration")
	await _tap_button("music")
	_check("music_toggles_off", not host.save.music)
	await _tap_button("music")
	_check("music_toggles_on", host.save.music)
	await _tap_button("reduce_fx")
	_check("reduce_fx_toggles", host.save.reduce_fx and host._fx_scale() < 1.0)
	await _tap_button("reduce_fx")
	await _tap_button("lang_en")
	_check("language_switches", host.save.lang == "en")
	var reloaded := SaveData.new(host.save.path)
	reloaded.load_file()
	_check("language_persists", reloaded.lang == "en")
	await _tap_button("lang_ja")
	await _tap_button("back")
	_check("settings_back_to_title", host.screen == Menus.Screen.TITLE)


func _verify_aim_controls() -> void:
	# Letting go below the launcher cancels instead of firing.
	await _tap_at(Vector2(360.0, GameSim.LAUNCH_Y + 60.0))
	_check("release_below_launcher_cancels", host.sim.shots == 0)
	var target := Vector2(120.0, 500.0)
	var expected := (target - Vector2(host.sim.launch_x, GameSim.LAUNCH_Y)).normalized()
	await _tap_at(target)
	_check("single_tap_fires", host.sim.shots == 1)
	_check("shot_goes_toward_tap", host.sim._launch_dir.distance_to(expected) < 0.01)
	while host.sim.state == GameSim.State.SHOOT:
		await _wait(0.05)
	host.sim.shots = 0


func _verify_pause() -> void:
	await _fire_at_lowest()
	await _wait(0.1)
	_check("touch_fires_shot", host.sim.shots == 1)
	if host.sim.state != GameSim.State.SHOOT:
		return
	await _tap_button("pause")
	_check("pause_opens", host.paused)
	var frozen: float = host.sim.sim_time
	await _wait(0.3)
	_check("pause_freezes_game", is_equal_approx(frozen, host.sim.sim_time))
	await _shot("05_pause_ja")
	await _tap_button("settings")
	_check("settings_from_pause", host.screen == Menus.Screen.SETTINGS and host.paused)
	await _tap_button("back")
	_check("settings_back_to_pause", host.screen == Menus.Screen.GAME and host.paused)
	await _tap_button("resume")
	_check("resume_continues", not host.paused)


func _verify_play() -> void:
	var saved := {}
	var preferred := ["split", "bomb", "more_balls"]
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < play_ms and not host.is_run_over():
		match host.sim.state:
			GameSim.State.AIM:
				if not saved.has("aim"):
					saved["aim"] = true
					await _fire_at_lowest("06_aiming_ja")
				else:
					await _fire_at_lowest()
			GameSim.State.SHOOT:
				if not saved.has("chaos") and host.sim.balls.size() >= 12:
					saved["chaos"] = true
					await _shot("07_chaos_ja")
				await _wait(0.03)
			GameSim.State.UPGRADE:
				await _wait_until(func() -> bool: return host.boss_down <= 0.0, 4000)
				await _wait(0.45)
				if not saved.has("upgrade"):
					saved["upgrade"] = true
					await _shot("08_upgrade_ja")
				var index := 0
				for i in host.sim.choices.size():
					if preferred.has(host.sim.choices[i]):
						index = i
						break
				var before: int = host.sim.picks_pending
				var stage_before: int = host.sim.stage
				await _tap_at(host.card_rect(index, host.sim.choices.size()).get_center())
				_check("upgrade_card_tap", host.sim.picks_pending < before or host.sim.stage > stage_before)
	if host.sim.counters["kills"] <= 0:
		_check("blocks_were_broken", false)
	_verify_interruption()


## The OS can close a backgrounded app without warning, so its coins must already be on disk.
func _verify_interruption() -> void:
	if host.is_run_over():
		return
	host.sim.coins += 7
	host._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var reloaded := SaveData.new(host.save.path)
	reloaded.load_file()
	_check("backgrounding_saves_run_coins", int(reloaded.interrupted_run.get("coins", -1)) == host.sim.coins)
	_check("backgrounding_does_not_bank_twice", reloaded.runs == 0 and reloaded.coins == host.save.coins)
	if host.paused:
		host._set_paused(false)


func _verify_end() -> void:
	# A slow run hits the time limit; the end screen still has to work from there.
	if not host.is_run_over():
		host.sim.state = GameSim.State.LOST
	await _wait(0.5)
	var earned: int = host.sim.coins
	_check("run_recorded", host.save.runs == 1 and host.save.stat_value("coins") == earned)
	_check("first_run_is_new_record", host.run_new_record)
	var reloaded := SaveData.new(host.save.path)
	reloaded.load_file()
	_check("records_persist", reloaded.runs == 1 and reloaded.stat_value("coins") == earned)
	_check("banked_run_leaves_nothing_to_recover", reloaded.interrupted_run.is_empty())
	_check("achievement_unlocked_on_first_run", host.save.has_achievement("runs_1"))
	await _shot("09_end_ja")
	# A stray tap on the results must not throw them away.
	await _wait(0.4)
	await _tap_at(Vector2(360.0, 500.0))
	_check("end_screen_ignores_stray_taps", host.is_run_over())
	await _tap_button("shop")
	_check("end_screen_opens_shop", host.screen == Menus.Screen.SHOP)
	await _tap_button("back")
	_check("shop_returns_to_end_screen", host.screen == Menus.Screen.GAME and host.is_run_over())
	await _wait(0.4)
	var retry_at := Time.get_ticks_msec()
	await _tap_at(host.current_buttons()[0]["rect"].get_center())
	while host.sim.state != GameSim.State.AIM and Time.get_ticks_msec() - retry_at < 3000:
		await host.get_tree().process_frame
	_check("retry_under_one_second", Time.get_ticks_msec() - retry_at < 1000)
	_check("retry_resets_run", host.sim.total_damage == 0 and host.sim.stage == 0 and host.screen == Menus.Screen.GAME)
	await _tap_button("pause")
	await _tap_button("to_title")
	_check("pause_to_title", host.screen == Menus.Screen.TITLE)


## Shows the boss and every special block on screen at once.
func _verify_specials() -> void:
	await _tap_button("start")
	_check("start_opens_loadout", host.screen == Menus.Screen.LOADOUT)
	await _shot("10_loadout_ja")
	await _tap_button("go")
	var sim: GameSim = host.sim
	sim.stage = 3
	sim.boss_force = "purun"
	sim._start_stage()
	await _wait_until(func() -> bool: return host.boss_intro >= 0.0, 2000)
	_check("boss_intro_plays", host.boss_intro >= 0.0)
	_check("no_buttons_during_boss_intro", host.current_buttons().is_empty())
	await _wait_until(func() -> bool: return host.boss_intro < 0.0, 8000)
	var kinds: Array[String] = ["bomb", "shield", "regen", "armor", "treasure", "breeder", "extra_ball"]
	for i in kinds.size():
		var cell := Vector2i(i, 5)
		sim.blocks[cell] = sim._new_block(50 + i * 400, kinds[i], cell)
	await _wait(1.2)
	await _shot("11_boss_and_specials_ja")
	await _verify_burst(sim)
	sim._damage_block((sim.boss_block as Dictionary)["origin"], 1.0e9)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	await _shot("12_boss_killed_ja")
	_check("boss_kill_wipes_field", sim.blocks.is_empty())
	await _wait_until(func() -> bool: return host.boss_down <= 0.0, 4000)
	await _verify_boss_cast(sim)
	await _tap_button("pause")
	if host.paused:
		await _tap_button("to_title")
	else:
		host.show_title_for_verify()
	await _wait(0.2)
	_check("back_on_title", host.screen == Menus.Screen.TITLE)


## Every character gets its entrance, its field look, an angry face and a trick on screen.
func _verify_boss_cast(sim: GameSim) -> void:
	for id in Bosses.ids():
		sim.state = GameSim.State.AIM
		sim.stage = 3 if int(Bosses.BOSSES[id]["pool"]) == 0 else 7
		sim.boss_force = id
		sim._start_stage()
		await _wait_until(func() -> bool: return host.boss_intro >= 1.1, 4000)
		await _shot("40_boss_intro_%s" % id)
		_check("%s_met_is_saved" % id, host.save.bosses_met.has(id))
		await _touch_skip()
		_check("%s_intro_can_be_skipped" % id, host.boss_intro < 0.0)
		await _wait(0.3)
		for turn in 3:
			sim._descend()
		await _wait(0.1)
		await _shot("41_boss_field_%s" % id)
		var boss: Dictionary = sim.boss_block
		sim._damage_block(boss["origin"], float(boss["hp"]) * 0.6)
		await _wait(0.5)
		await _shot("42_boss_angry_%s" % id)
		sim._damage_block((sim.boss_block as Dictionary)["origin"], 1.0e9)
		await _wait(0.2)
		await _shot("43_boss_down_%s" % id)
		await _wait_until(func() -> bool: return host.boss_down <= 0.0, 4000)
	sim.boss_force = ""


func _touch_skip() -> void:
	_touch(Vector2(360.0, 650.0), true)
	await _wait(0.05)
	_touch(Vector2(360.0, 650.0), false)
	await _wait(0.05)


func _verify_burst(sim: GameSim) -> void:
	_check("no_burst_button_when_empty", not _has_button("burst"))
	sim.burst_charge = 1.0
	await _wait(0.1)
	await _shot("24_burst_ready_ja")
	var rows_before := _lowest_block_row(sim)
	var boss_hp := int((sim.boss_block as Dictionary)["hp"])
	await _tap_button("burst")
	_check("burst_starts_wind_up", host.burst_windup >= 0.0 and sim.burst_charge >= 1.0)
	_check("no_buttons_during_cut_in", host.current_buttons().is_empty())
	await _wait(0.2)
	await _shot("25_burst_cut_in_ja")
	await _wait_until(func() -> bool: return host.burst_windup < 0.0, 3000)
	_check("burst_spends_gauge", sim.burst_charge == 0.0 and sim.counters["bursts"] == 1)
	await _wait(0.03)
	await _shot("26_burst_impact_ja")
	await _wait(0.1)
	await _shot("27_burst_wave_ja")
	await _wait_until(func() -> bool: return sim.state != GameSim.State.SHOOT, 8000)
	await _shot("28_burst_after_ja")
	_check("burst_damages_boss", int((sim.boss_block as Dictionary)["hp"]) < boss_hp)
	_check("burst_costs_no_turn", _lowest_block_row(sim) <= rows_before)
	_check("burst_returns_to_aim", sim.state == GameSim.State.AIM)


func _lowest_block_row(sim: GameSim) -> int:
	var row := -1
	for cell: Vector2i in sim.blocks:
		row = maxi(row, cell.y)
	return row


func _has_button(id: String) -> bool:
	for button in host.current_buttons():
		if button["id"] == id:
			return true
	return false


func _wait_until(condition: Callable, limit_ms: int) -> void:
	var started := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec() - started < limit_ms:
		await host.get_tree().process_frame


func _verify_meta_screens() -> void:
	var save: SaveData = host.save
	save.coins = 5000
	await _tap_button("shop")
	_check("shop_opens", host.screen == Menus.Screen.SHOP)
	await _wait(0.4)
	var coins_before: int = save.coins
	await _tap_at(host.menus.shop_row_center("damage"))
	_check("shop_tap_buys", save.shop_level("damage") == 1 and save.coins < coins_before)
	await _drag_list(Vector2(360.0, 900.0), Vector2(360.0, 500.0))
	_check("shop_drag_scrolls", host.menus.scroll > 0.0)
	var levels_before: int = save.shop_level("damage")
	await _shot("13_shop_ja")
	await _wait(0.2)
	_check("drag_does_not_buy", save.shop_level("damage") == levels_before)
	await _tap_button("buy_all")
	await _wait_until(func() -> bool: return save.cheapest_item() == "", 8000)
	_check("buy_all_spends_everything", save.cheapest_item() == "" and save.shop_level("damage") > levels_before)
	await _wait(1.5)
	await _shot("13a_shop_after_buy_all_ja")
	host.menus.scroll = 0.0
	save.shop["damage"] = 9
	save.coins = 100000
	await _wait(0.1)
	await _tap_at(host.menus.shop_row_center("damage"))
	_check("milestone_announces", host.menus._milestone_time > 0.0)
	await _wait(0.12)
	await _shot("13b_milestone_ja")
	save.coins = 5000
	await _tap_button("back")

	await _tap_button("achievements")
	await _drag_list(Vector2(360.0, 900.0), Vector2(360.0, 400.0))
	_check("achievements_scroll", host.menus.scroll > 0.0)
	await _shot("14_achievements_ja")
	await _tap_button("back")

	save.mark_perk_seen("split")
	save.mark_perk_seen("e_cluster")
	await _tap_button("codex")
	await _shot("15_codex_perks_ja")
	await _tap_button("tab_balls")
	await _shot("16_codex_balls_ja")
	await _tap_button("tab_blocks")
	await _shot("17_codex_blocks_ja")
	await _tap_button("tab_bosses")
	await _shot("17b_codex_bosses_ja")
	await _tap_button("back")

	await _tap_button("prestige")
	await _shot("18_prestige_locked_ja")
	_check("prestige_locked_without_clear", not save.can_prestige())
	await _tap_button("back")

	save.wins = 2
	save.lifetime["wins"] = 2
	save.lifetime["best_tier"] = 12
	save.coins_this_life = 40000
	save.achievements["wins_1"] = true
	save.achievements["runs_2"] = true
	save.tier = 0
	await _tap_button("prestige")
	await _shot("19_prestige_ready_ja")
	await _tap_button("prestige_do")
	await _shot("20_prestige_confirm_ja")
	_check("prestige_asks_first", save.stars == 0)
	await _tap_button("prestige_no")
	_check("prestige_can_cancel", save.stars == 0 and save.shop_level("damage") >= 1)
	await _tap_button("prestige_do")
	await _tap_button("prestige_yes")
	_check("prestige_grants_stars", save.stars == 2 and save.shop.is_empty() and save.coins >= 0)
	await _tap_button("stars")
	_check("star_tree_opens", host.screen == Menus.Screen.STARS)
	await _wait(0.4)
	await _tap_at(Vector2(360.0, Menus.LIST_TOP + 60.0))
	_check("star_tap_raises_node", save.star_level("s_damage") == 1)
	await _wait(0.5)
	await _shot("20a_star_tree_ja")
	await _tap_button("stars_reset")
	_check("star_reset_refunds", save.star_points_left() == 2)
	await _tap_button("back")
	_check("star_tree_back_to_prestige", host.screen == Menus.Screen.PRESTIGE)
	await _tap_button("back")
	await _shot("21_title_after_prestige_ja")

	await _tap_button("start")
	await _tap_button("ball_iron")
	_check("unlocked_ball_selects", save.ball_type == "iron")
	# The earlier burst may have earned the titan for real, so lock it again for this check.
	save.achievements.erase("best_shot_4")
	await _tap_button("ball_titan")
	_check("locked_ball_stays_locked", save.ball_type == "iron")
	for i in 12:
		await _tap_button("tier_up")
	_check("tier_goes_up", save.tier == 12)
	await _tap_button("tier_up")
	_check("tier_stops_at_limit", save.tier == 12)
	await _shot("22_loadout_high_tier_ja")
	await _tap_button("go")
	_check("loadout_applies", host.sim.ball_type == "iron" and host.sim.tier == 12)
	await _fire_at_lowest()
	await _wait(0.3)
	await _shot("23_high_tier_game_ja")
	await _tap_button("pause")
	if host.paused:
		await _tap_button("to_title")
	await _wait(0.2)
	await _tap_button("start")
	for i in 12:
		await _tap_button("tier_down")
	await _tap_button("ball_normal")
	await _tap_button("back")
	_check("back_on_title_after_loadout", host.screen == Menus.Screen.TITLE)


func _verify_english() -> void:
	await _tap_button("settings")
	await _tap_button("lang_en")
	await _shot("30_settings_en")
	await _tap_button("back")
	await _shot("31_title_en")
	await _tap_button("shop")
	await _shot("32_shop_en")
	await _tap_button("back")
	await _tap_button("achievements")
	await _shot("33_achievements_en")
	await _wait(0.4)
	_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await _wait(0.05)
	_check("mouse_wheel_scrolls_lists", host.menus.scroll > 0.0)
	await _tap_button("back")
	host.save.mark_perk_seen("double_split")
	await _tap_button("codex")
	await _shot("34_codex_en")
	await _tap_button("tab_blocks")
	await _shot("35_codex_blocks_en")
	await _tap_button("back")
	await _tap_button("prestige")
	await _shot("36_prestige_en")
	await _tap_button("stars")
	await _shot("36a_star_tree_en")
	await _tap_button("back")
	await _tap_button("back")
	await _tap_button("howto")
	await _shot("37_howto_en")
	await _tap_button("back")
	await _tap_button("start")
	await _shot("38_loadout_en")
	await _tap_button("go")
	await _wait(1.2)
	var sim: GameSim = host.sim
	sim.state = GameSim.State.UPGRADE
	sim.picks_pending = 1
	sim.rerolls = 2
	sim.choices = ["e_inferno", "aimbot", "gambler", "extra_choice"] as Array[String]
	await _wait(0.5)
	await _shot("39_upgrade_en")
	_key(KEY_1)
	await _wait(0.05)
	_check("number_key_picks_a_card", sim.levels["e_inferno"] == 1)
	sim.total_damage = 1
	sim.state = GameSim.State.LOST
	await _wait(0.5)
	await _shot("40_end_en")
	_key(KEY_R)
	await _wait(0.05)
	_check("r_key_retries", not host.is_run_over())
	sim.total_damage = 1
	sim.state = GameSim.State.LOST
	await _wait(0.5)
	await _tap_button("to_title")
	_check("end_to_title", host.screen == Menus.Screen.TITLE)
	await _tap_button("settings")
	await _tap_button("lang_ja")


func _check(name_: String, ok: bool) -> void:
	checks[name_] = bool(checks.get(name_, true)) and ok
	if not ok:
		print("verify: FAILED ", name_)


func _fire_at_lowest(shot_name := "") -> void:
	var sim: GameSim = host.sim
	var target := Vector2(360.0, 400.0)
	var best_y := -1.0
	for cell: Vector2i in sim.blocks:
		var c := sim.cell_rect(cell).get_center()
		if c.y > best_y:
			best_y = c.y
			target = c
	# Touch somewhere else first, then slide to the target: aiming must follow the finger.
	_touch(Vector2(360.0, 650.0), true)
	await _wait(0.03)
	_drag(target)
	await _wait(0.06)
	if shot_name != "":
		await _shot(shot_name)
	_touch(target, false)
	await _wait(0.03)


func _tap_button(id: String) -> void:
	print("verify: tap ", id)
	await _wait(0.4)
	for button in host.current_buttons():
		if button["id"] == id:
			await _tap_at((button["rect"] as Rect2).get_center())
			return
	_check("button_exists_" + id, false)


func _tap_at(world: Vector2) -> void:
	_touch(world, true)
	await _wait(0.02)
	_touch(world, false)
	await _wait(0.05)


func _drag_list(from: Vector2, to: Vector2) -> void:
	await _wait(0.4)
	_touch(from, true)
	await _wait(0.02)
	for i in range(1, 6):
		_drag(from.lerp(to, i / 5.0))
		await _wait(0.02)
	_touch(to, false)
	await _wait(0.05)


func _wait(seconds: float) -> void:
	await host.get_tree().create_timer(seconds * Engine.time_scale).timeout


func _shot(name_: String) -> void:
	print("verify: shot ", name_)
	# frame_post_draw never fires while macOS considers the window hidden, so draw explicitly.
	await host.get_tree().process_frame
	RenderingServer.force_draw(false)
	host.get_viewport().get_texture().get_image().save_png(dir.path_join(name_ + ".png"))


func _to_window(world: Vector2) -> Vector2:
	return host.get_viewport().get_final_transform() * (world + Vector2(0.0, host.y_offset))


func _key(keycode: int) -> void:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.pressed = true
	Input.parse_input_event(e)


func _wheel(button: int) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	Input.parse_input_event(e)


func _touch(world: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = _to_window(world)
	Input.parse_input_event(e)


func _drag(world: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = _to_window(world)
	Input.parse_input_event(e)
