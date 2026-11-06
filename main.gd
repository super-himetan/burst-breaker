extends "res://game_events.gd"
## App flow and input: starting and banking runs, screens, buttons, touches and keys.
## Reactions to the rules' events live in game_events.gd, and everything drawn or played below it.


func _ready() -> void:
	font = _make_font(800)
	font_body = _make_font(500)
	var label_font := FontVariation.new()
	label_font.base_font = _make_font(700)
	label_font.spacing_glyph = 3
	font_label = label_font
	_box.anti_aliasing = true
	_box.anti_aliasing_size = 1.2
	canvas = self
	RenderingServer.set_default_clear_color(UI.INK)
	_build_layers()
	_build_audio()
	var save_path := SaveData.DEFAULT_PATH
	var verify_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--verify="):
			verify_dir = arg.trim_prefix("--verify=")
			save_path = verify_dir.path_join("save.json")
	if verify_dir != "":
		DirAccess.make_dir_recursive_absolute(verify_dir)
		DirAccess.remove_absolute(save_path)
	save = SaveData.new(save_path)
	save.load_file()
	menus = Menus.new(self, save)
	_apply_sound()
	# Rendering the loop takes a moment, so it must not hold up the first frame.
	music_task = WorkerThreadPool.add_task(func() -> void: music_layers = Music.render_layers())
	sim = GameSim.new()
	web_touch = WebTouch.new()
	_recover_interrupted_run()
	if verify_dir != "":
		# Automated checks should never make noise, whatever the volume settings say.
		AudioServer.set_bus_mute(0, true)
		verifier = Verify.new(self, verify_dir)
		verifier.run()

func _build_layers() -> void:
	var back := CanvasLayer.new()
	back.layer = -1
	add_child(back)
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_material = ShaderMaterial.new()
	background_material.shader = BackgroundShader
	background.material = background_material
	back.add_child(background)

	glow_layer = Node2D.new()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = additive
	glow_layer.draw.connect(_draw_glow)
	add_child(glow_layer)

	list_clip = Control.new()
	list_clip.position = Vector2(0.0, Menus.LIST_TOP)
	list_clip.size = Vector2(BASE_W, Menus.LIST_BOTTOM - Menus.LIST_TOP)
	list_clip.clip_contents = true
	list_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_clip.draw.connect(_draw_list)
	add_child(list_clip)

	ui_layer = Node2D.new()
	ui_layer.draw.connect(_draw_ui)
	add_child(ui_layer)

	var front := CanvasLayer.new()
	front.layer = 10
	add_child(front)
	impact_rect = ColorRect.new()
	impact_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	impact_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact_material = ShaderMaterial.new()
	impact_material.shader = ImpactShader
	impact_rect.material = impact_material
	impact_rect.visible = false
	front.add_child(impact_rect)

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.35, Color(1.0, 1.0, 1.0, 0.42))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 128
	texture.height = 128
	glow_texture = texture

func _notification(what: int) -> void:
	if save == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if _can_pause():
			_set_paused(true)
		_stash_run()
		save.save_file()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_stash_run()
		save.save_file()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_request()

func _on_back_request() -> void:
	match screen:
		Menus.Screen.TITLE:
			get_tree().quit()
		Menus.Screen.SETTINGS:
			_set_screen(settings_return)
		Menus.Screen.SHOP:
			_set_screen(shop_return)
		Menus.Screen.COSMETICS:
			_set_screen(Menus.Screen.LOADOUT)
		Menus.Screen.ENDING:
			_close_ending()
		Menus.Screen.GAME:
			if paused:
				_set_paused(false)
			elif _can_pause():
				_set_paused(true)
		_:
			_set_screen(Menus.Screen.TITLE)

func _set_screen(next: int) -> void:
	if next != screen:
		wipe = WIPE_SECONDS
	screen = next
	_apply_sky()
	screen_age = 0.0
	aiming = false
	list_active = false
	menus.on_enter(next)

func _set_paused(value: bool) -> void:
	paused = value
	screen_age = 0.0
	aiming = false

func _can_pause() -> bool:
	return screen == Menus.Screen.GAME and not paused and burst_windup < 0.0 and evolve_cut < 0.0 and sim.state in [GameSim.State.AIM, GameSim.State.SHOOT]

func show_title_for_verify() -> void:
	_bank_run()
	_set_screen(Menus.Screen.TITLE)

func _start_run(rush := false) -> void:
	_bank_run()
	var config := save.run_config()
	if rush:
		config["rush"] = save.rush_list()
		config["routes"] = false
		config["true_path"] = false
	sim.new_run(randi(), config)
	combo_stage = 0
	boss_crack = 0.0
	pending_ending = false
	run_banked = false
	run_seconds = 0.0
	run_new_record = false
	end_age = 0.0
	finish_time = 0.0
	tension_left = TENSION_SECONDS
	zoom = 1.0
	rank_time = 0.0
	evolve_cut = -1.0
	run_mastery_before = save.mastery_level(save.ball_type)
	paused = false
	aiming = false
	particles.clear()
	numbers.clear()
	fly_coins.clear()
	rings.clear()
	bolts.clear()
	flash.clear()
	seen_choices = []
	banner_time = 0.0
	screen_flash = 0.0
	next_milestone = 25
	last_state = -1
	burst_windup = -1.0
	burst_after = 0.0
	burst_was_ready = false
	boss_intro = -1.0
	boss_down = 0.0
	speech_time = 0.0
	beams.clear()
	_set_screen(Menus.Screen.GAME)

## Records stats once per run, including runs the player abandons from the pause menu.
func _bank_run() -> void:
	if run_banked:
		return
	run_banked = true
	if sim.total_damage == 0:
		return
	run_new_record = save.record_run(_run_summary())
	if save.stars_gained > 0:
		toasts.append({"text": t("stars_toast") % save.stars_gained, "t": 0.0})
	var mastery_now := save.mastery_level(sim.ball_type)
	if mastery_now > run_mastery_before:
		toasts.append({"text": t("mastery_toast") % [t("ball_" + sim.ball_type), mastery_now], "t": 0.0})
	on_progress_changed()

func _recover_interrupted_run() -> void:
	var earned := save.recover_interrupted_run()
	if earned < 0:
		return
	on_progress_changed()
	if earned > 0:
		toasts.append({"text": t("run_recovered") % I18n.format_number(earned), "t": 0.0})

func _change_volume(id: String) -> void:
	var step := 1 if id.ends_with("_up") else -1
	if id.begins_with("sound"):
		save.sfx_volume = clampi(save.sfx_volume + step, 0, SaveData.VOLUME_MAX)
	else:
		save.music_volume = clampi(save.music_volume + step, 0, SaveData.VOLUME_MAX)
	_apply_sound()
	save.save_file()
	# The new level is easiest to judge by hearing it.
	_play("pick", 1.0)

func _process(delta: float) -> void:
	time += delta
	_poll_music()
	_mix_music(delta)
	wipe = maxf(wipe - delta, 0.0)
	ending_age += delta
	fever_glow = move_toward(fever_glow, 1.0 if screen == Menus.Screen.GAME and sim.fever and sim.state == GameSim.State.SHOOT else 0.0, delta * 3.0)
	background_material.set_shader_parameter("fever", fever_glow)
	boss_crack = maxf(boss_crack - delta, 0.0)
	menus.update(delta, screen)
	var view := get_viewport_rect().size
	y_offset = maxf((view.y - BASE_H) / 2.0, 0.0)
	_take_web_touches(view)
	screen_age += delta
	if screen == Menus.Screen.GAME and not paused:
		_process_game(delta)
	_update_fx(delta * (FINISH_FX_RATE if finish_time > 0.0 else 1.0))
	finish_time = maxf(finish_time - delta, 0.0)
	rank_time = maxf(rank_time - delta, 0.0)
	var shake := trauma * trauma * 24.0 * _fx_scale()
	var offset := Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	var wanted_zoom := 1.0 + (zoom_target - 1.0) * _fx_scale() if screen == Menus.Screen.GAME and not paused else 1.0
	zoom = lerpf(zoom, wanted_zoom, minf(delta * ZOOM_SPEED, 1.0))
	# Zoom toward the action, and counter both zoom and shake so the interface stays steady.
	var pushed := zoom_focus * (1.0 - zoom)
	position = Vector2(0.0, y_offset) + offset + pushed
	scale = Vector2(zoom, zoom)
	ui_layer.scale = Vector2.ONE / zoom
	ui_layer.position = -(offset + pushed) / zoom
	list_clip.position = Vector2(0.0, Menus.LIST_TOP) - offset
	list_clip.visible = menus.is_list_screen(screen)
	var target_heat := clampf(sim.combo / 90.0, 0.0, 1.0) if screen == Menus.Screen.GAME and sim.state == GameSim.State.SHOOT else 0.0
	heat = lerpf(heat, target_heat, minf(delta * 5.0, 1.0))
	background_material.set_shader_parameter("heat", heat)
	impact = maxf(impact - delta * 0.11, 0.0)
	burst_after = maxf(burst_after - delta, 0.0)
	impact_rect.visible = impact > 0.0005
	impact_material.set_shader_parameter("amount", impact * _fx_scale())
	queue_redraw()
	glow_layer.queue_redraw()
	ui_layer.queue_redraw()
	list_clip.queue_redraw()

func _process_game(delta: float) -> void:
	if sim.state != last_state:
		last_state = sim.state
		screen_age = 0.0
	if not is_run_over():
		run_seconds += delta
	elif boss_down <= 0.0:
		_process_count_up(delta)
	if evolve_cut >= 0.0:
		_process_evolve_cut(delta)
		return
	if boss_intro >= 0.0:
		_process_boss_intro(delta)
		return
	if boss_down > 0.0:
		boss_down = maxf(boss_down - delta, 0.0)
		# The screen after the fight should open fresh, not count as already waited for.
		screen_age = 0.0
	if burst_windup >= 0.0:
		_process_burst_windup(delta)
		return
	if sim.can_burst() and not burst_was_ready:
		burst_was_ready = true
		toasts.append({"text": t("burst_ready_toast"), "t": 0.0})
		_play("win", 2.0)
	if hitstop > 0.0:
		hitstop -= delta
	else:
		sim.step(delta * _time_rate(delta))
	verify_stats["max_balls"] = max(int(verify_stats["max_balls"]), sim.balls.size())
	_consume_events()
	_note_offered_perks()
	_maybe_start_ending()
	if is_run_over():
		_bank_run()

func _maybe_start_ending() -> void:
	if not pending_ending or boss_down > 0.0:
		return
	pending_ending = false
	save.true_ending_seen = true
	save.save_file()
	ending_age = 0.0
	_set_screen(Menus.Screen.ENDING)

func _close_ending() -> void:
	# Back to the results of the run that got here.
	_set_screen(Menus.Screen.GAME)

func _save_card() -> void:
	var folder := "user://cards"
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("%d.png" % int(Time.get_unix_time_from_system()))
	get_viewport().get_texture().get_image().save_png(path)
	toasts.append({"text": t("card_saved"), "t": 0.0})
	_play("win", 1.6)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			_on_key(event.keycode)
		return
	if event is InputEventMouseButton and event.pressed and menus.is_list_screen(screen):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			menus.scroll_by(screen, WHEEL_SCROLL)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			menus.scroll_by(screen, -WHEEL_SCROLL)
		return
	if event is InputEventPanGesture and menus.is_list_screen(screen):
		menus.scroll_by(screen, -event.delta.y * PAN_SCROLL)
		return
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and web_touch.touched_recently():
		# The browser already handed this touch over in _take_web_touches.
		return
	if event is InputEventScreenTouch and event.index == 0:
		var p: Vector2 = event.position - Vector2(0.0, y_offset)
		if event.pressed:
			_on_press(p)
		else:
			_on_release(p)
	elif event is InputEventScreenDrag and event.index == 0:
		_on_drag(event.position - Vector2(0.0, y_offset))
	elif event is InputEventMouseMotion and not DisplayServer.is_touchscreen_available():
		# With a mouse the aim simply follows the cursor, and a click fires.
		hovering = true
		if not aiming:
			aim_current = event.position - Vector2(0.0, y_offset)

func _on_drag(p: Vector2) -> void:
	if aiming:
		aim_current = p
	elif list_active:
		_on_list_drag(p)

## On the web the touches come from the browser itself, because iOS Safari does not pass them on to Godot.
func _take_web_touches(view: Vector2) -> void:
	for touch: Array in web_touch.take(view):
		var p: Vector2 = touch[1] - Vector2(0.0, y_offset)
		match String(touch[0]):
			"start":
				_on_press(p)
			"move":
				_on_drag(p)
			"end":
				_on_release(p)

## Keyboard shortcuts for the desktop build. They go through the same checks as a tap.
func _on_key(key: int) -> void:
	match key:
		KEY_ESCAPE:
			if screen != Menus.Screen.TITLE:
				_on_back_request()
		KEY_SPACE, KEY_ENTER, KEY_R:
			for id: String in ["restart", "resume", "burst"]:
				if id == "restart" and paused:
					continue
				if _tap_button_by_id(id):
					return
		KEY_1, KEY_2, KEY_3, KEY_4:
			var index: int = key - KEY_1
			if screen != Menus.Screen.GAME:
				return
			var count := 0
			match sim.state:
				GameSim.State.UPGRADE:
					count = sim.choices.size()
				GameSim.State.ROUTE:
					count = sim.route_options.size()
				GameSim.State.EVENT:
					count = (sim.event["options"] as Array).size()
			if index < count:
				_on_press(card_rect(index, count).get_center())

func _tap_button_by_id(id: String) -> bool:
	for button in current_buttons():
		if button["id"] == id:
			_on_press((button["rect"] as Rect2).get_center())
			return true
	return false

func _on_press(p: Vector2) -> void:
	for button in current_buttons():
		if (button["rect"] as Rect2).has_point(p):
			if screen_age >= ACCEPT_INPUT_AFTER or button["id"] == "pause":
				_play("pick", 1.0)
				_press_button(String(button["id"]))
			return
	if menus.is_list_screen(screen):
		list_active = true
		list_moved = false
		list_press = p
		list_last = p
		return
	if evolve_cut >= 0.0:
		if evolve_cut >= EVOLVE_SKIP_AFTER and not paused:
			evolve_cut = -1.0
		return
	if screen == Menus.Screen.GAME and not paused and boss_intro >= BOSS_INTRO_SKIP_AFTER:
		boss_intro = -1.0
		return
	if screen != Menus.Screen.GAME or paused or burst_windup >= 0.0 or boss_intro >= 0.0 or boss_down > 0.0:
		return
	match sim.state:
		GameSim.State.AIM:
			aiming = true
			aim_current = p
		GameSim.State.ROUTE:
			if screen_age < ACCEPT_INPUT_AFTER:
				return
			for i in sim.route_options.size():
				if card_rect(i, sim.route_options.size()).has_point(p):
					_play("pick", 1.0)
					sim.choose_route(sim.route_options[i])
					return
		GameSim.State.EVENT:
			if screen_age < ACCEPT_INPUT_AFTER:
				return
			var count: int = (sim.event["options"] as Array).size()
			for i in count:
				if card_rect(i, count).has_point(p):
					_play("coin" if sim.choose_event(i) else "lose", 1.0)
					return
		GameSim.State.UPGRADE:
			if screen_age < ACCEPT_INPUT_AFTER:
				return
			for i in sim.choices.size():
				if card_rect(i, sim.choices.size()).has_point(p):
					_play("pick", 1.0)
					sim.choose_upgrade(sim.choices[i])
					return

func _on_list_drag(p: Vector2) -> void:
	if p.distance_to(list_press) > TAP_SLOP:
		list_moved = true
	if list_moved:
		menus.scroll_by(screen, p.y - list_last.y)
	list_last = p

func _on_release(p: Vector2) -> void:
	if list_active:
		list_active = false
		if not list_moved and screen_age >= ACCEPT_INPUT_AFTER:
			menus.tap_list(screen, p)
		return
	if not aiming:
		return
	aiming = false
	if sim.state == GameSim.State.AIM and _can_aim_at(p):
		if not save.tutorial_done:
			save.tutorial_done = true
			save.save_file()
		sim.fire(p - Vector2(sim.launch_x, GameSim.LAUNCH_Y))

func _press_button(id: String) -> void:
	if menus.press(id):
		return
	match id:
		"start":
			# A brand-new player has nothing to choose yet, so go straight into the game.
			if save.runs == 0:
				_start_run()
			else:
				_set_screen(Menus.Screen.LOADOUT)
		"go", "restart":
			_start_run()
		"rush":
			if save.can_rush():
				_start_run(true)
		"cosmetics":
			_set_screen(Menus.Screen.COSMETICS)
		"save_card":
			_save_card()
		"ending_close":
			_close_ending()
		"shop":
			shop_return = screen
			_set_screen(Menus.Screen.SHOP)
		"stars":
			_set_screen(Menus.Screen.STARS)
		"achievements":
			_set_screen(Menus.Screen.ACHIEVEMENTS)
		"codex":
			_set_screen(Menus.Screen.CODEX)
		"howto":
			_set_screen(Menus.Screen.HOWTO)
		"settings":
			settings_return = screen
			_set_screen(Menus.Screen.SETTINGS)
		"back":
			match screen:
				Menus.Screen.SETTINGS:
					_set_screen(settings_return)
				Menus.Screen.SHOP:
					_set_screen(shop_return)
				Menus.Screen.COSMETICS:
					_set_screen(Menus.Screen.LOADOUT)
				_:
					_set_screen(Menus.Screen.TITLE)
		"lang_ja", "lang_en":
			save.lang = id.trim_prefix("lang_")
			save.save_file()
		"sound_up", "sound_down", "music_up", "music_down":
			_change_volume(id)
		"vibration":
			save.vibration = not save.vibration
			save.save_file()
		"reduce_fx":
			save.reduce_fx = not save.reduce_fx
			save.save_file()
		"pause":
			_set_paused(true)
		"resume":
			_set_paused(false)
		"reroll":
			sim.reroll_choices()
		"burst":
			_begin_burst()
		"event_leave":
			sim.leave_event()
		"to_title":
			_bank_run()
			paused = false
			_set_screen(Menus.Screen.TITLE)
