extends Node2D
## App flow, input, the game screen, effects and sound.
## Rules live in sim/game_sim.gd and other screens in menus.gd.

const GameSim := preload("res://sim/game_sim.gd")
const I18n := preload("res://i18n.gd")
const SaveData := preload("res://save_data.gd")
const Menus := preload("res://menus.gd")
const Verify := preload("res://verify.gd")
const Music := preload("res://music.gd")
const Perks := preload("res://data/perks.gd")
const Balls := preload("res://data/balls.gd")
const Bosses := preload("res://data/bosses.gd")
const BossArt := preload("res://boss_art.gd")
const Achievements := preload("res://data/achievements.gd")
const Shop := preload("res://data/shop.gd")
const PerkArt := preload("res://perk_art.gd")
const UI := preload("res://ui_theme.gd")
const BackgroundShader := preload("res://shaders/background.gdshader")
const ImpactShader := preload("res://shaders/impact.gdshader")

const BASE_H := 1280.0
const BASE_W := 720.0
const MIN_AIM_HEIGHT := 24.0
const TAP_SLOP := 18.0
const ACCEPT_INPUT_AFTER := 0.3
const FONT_LATIN := ["Avenir Next", "Helvetica Neue", "Roboto", "sans-serif"]
const FONT_JAPANESE := ["Hiragino Sans", "Hiragino Kaku Gothic ProN", "Noto Sans CJK JP", "Noto Sans JP", "sans-serif"]
const SAMPLE_RATE := 22050
const BURST_WINDUP := 1.15
const BURST_AFTERGLOW := 1.1
const BOSS_INTRO := 2.7
const BOSS_INTRO_SKIP_AFTER := 0.3
const BOSS_DOWN_HOLD := 1.7
const SPEECH_SECONDS := 2.6
const SPEECH_COOLDOWN := 7.0
const BOSS_HEAL_COLOR := Color("7dffb0")
const MUSIC_VOLUME_DB := -13.0
const REDUCED_FX_SCALE := 0.25
const WHEEL_SCROLL := 70.0
const PAN_SCROLL := 24.0
const COUNT_UP_SECONDS := 1.0
const COUNT_UP_TICK := 0.07
const OVERKILL_TEXT_GAP := 0.12
const CARD_ICON_MAX := 120.0
const CHIP_ICON_RADIUS := 12.0

var sim: GameSim
var save: SaveData
var menus: Menus
var verifier: Verify
var screen: int = Menus.Screen.TITLE
var settings_return: int = Menus.Screen.TITLE
var shop_return: int = Menus.Screen.TITLE
var paused := false
var run_banked := true
var run_seconds := 0.0
var run_new_record := false
var y_offset := 0.0
var time := 0.0
var screen_age := 0.0
var last_state := -1

var aiming := false
var aim_current := Vector2.ZERO
var hovering := false
var list_press := Vector2.ZERO
var list_last := Vector2.ZERO
var list_active := false
var list_moved := false

var hitstop := 0.0
var trauma := 0.0
var descend_anim := 0.0
var flash := {}
var particles: Array[Dictionary] = []
var numbers: Array[Dictionary] = []
var fly_coins: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var bolts: Array[Dictionary] = []
var toasts: Array[Dictionary] = []
var banner_text := ""
var banner_time := 0.0
var combo_pop := 0.0
var coin_pop := 0.0
var screen_flash := 0.0
var last_boom_stop := 0.0
var last_boom_sound := 0.0
var last_pop_sound := 0.0
var last_hit_sound := 0.0
var next_milestone := 25
var seen_choices: Array[String] = []
var burst_windup := -1.0
var burst_after := 0.0
var burst_origin := Vector2.ZERO
var burst_was_ready := false
var boss_intro := -1.0
var boss_intro_id := ""
var boss_intro_slammed := false
var boss_down := 0.0
var boss_down_id := ""
var boss_down_pos := Vector2.ZERO
var boss_rage_said := false
var speech_text := ""
var speech_time := 0.0
var speech_cooldown := 0.0
var speech_anchor := Vector2.ZERO
var beams: Array[Dictionary] = []

var font: Font
var font_body: Font
var font_label: Font
var canvas: CanvasItem
var glow_layer: Node2D
var ui_layer: Node2D
var list_clip: Control
var glow_texture: Texture2D
var background_material: ShaderMaterial
var impact_rect: ColorRect
var impact_material: ShaderMaterial
var impact := 0.0
var heat := 0.0
var _box := StyleBoxFlat.new()
var _pending_dots: Array[Dictionary] = []
var sounds := {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var music_player: AudioStreamPlayer
var music_task := -1
var music_pcm := PackedByteArray()
var end_age := 0.0
var last_tick_sound := 0.0
var last_overkill_text := 0.0
var end_preview := {}
var run_mastery_before := 0
var verify_stats := {"max_balls": 0, "explosions": 0, "splits": 0}


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
	music_task = WorkerThreadPool.add_task(func() -> void: music_pcm = Music.render_pcm())
	sim = GameSim.new()
	_recover_interrupted_run()
	if verify_dir != "":
		# Automated checks should never make noise, whatever the volume settings say.
		AudioServer.set_bus_mute(0, true)
		verifier = Verify.new(self, verify_dir)
		verifier.run()


## Latin text uses a clean geometric face, with Japanese falling back to a matching gothic.
func _make_font(weight: int) -> Font:
	var japanese := SystemFont.new()
	japanese.font_names = PackedStringArray(FONT_JAPANESE)
	japanese.font_weight = weight
	var latin := SystemFont.new()
	latin.font_names = PackedStringArray(FONT_LATIN)
	latin.font_weight = weight
	latin.fallbacks = [japanese]
	return latin


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
		Menus.Screen.STARS:
			_set_screen(Menus.Screen.PRESTIGE)
		Menus.Screen.GAME:
			if paused:
				_set_paused(false)
			elif _can_pause():
				_set_paused(true)
		_:
			_set_screen(Menus.Screen.TITLE)


func t(key: String) -> String:
	return I18n.text(save.lang, key)


func _set_screen(next: int) -> void:
	screen = next
	end_preview = save.preview_buy_all()
	screen_age = 0.0
	aiming = false
	list_active = false
	menus.on_enter(next)


func _set_paused(value: bool) -> void:
	paused = value
	screen_age = 0.0
	aiming = false


func _can_pause() -> bool:
	return screen == Menus.Screen.GAME and not paused and burst_windup < 0.0 and sim.state in [GameSim.State.AIM, GameSim.State.SHOOT]


func is_run_over() -> bool:
	return sim.state == GameSim.State.WON or sim.state == GameSim.State.LOST


func show_title_for_verify() -> void:
	_bank_run()
	_set_screen(Menus.Screen.TITLE)


func _start_run() -> void:
	_bank_run()
	sim.new_run(randi(), save.run_config())
	run_banked = false
	run_seconds = 0.0
	run_new_record = false
	end_age = 0.0
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
	var mastery_now := save.mastery_level(sim.ball_type)
	if mastery_now > run_mastery_before:
		toasts.append({"text": t("mastery_toast") % [t("ball_" + sim.ball_type), mastery_now], "t": 0.0})
	on_progress_changed()
	end_preview = save.preview_buy_all()


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


func _recover_interrupted_run() -> void:
	var earned := save.recover_interrupted_run()
	if earned < 0:
		return
	on_progress_changed()
	if earned > 0:
		toasts.append({"text": t("run_recovered") % I18n.format_number(earned), "t": 0.0})


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


func _apply_sound() -> void:
	var volume_db := _volume_db(save.sfx_volume)
	for player in players:
		player.volume_db = volume_db
	_apply_music()


func _apply_music() -> void:
	music_player.volume_db = MUSIC_VOLUME_DB + _volume_db(save.music_volume)
	if music_player.stream != null:
		music_player.stream_paused = save.music_volume <= 0


func _volume_db(volume: int) -> float:
	return linear_to_db(maxf(float(volume) / SaveData.VOLUME_MAX, 0.0001))


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


## Starts the loop once the background render has finished.
func _poll_music() -> void:
	if music_task < 0 or not WorkerThreadPool.is_task_completed(music_task):
		return
	WorkerThreadPool.wait_for_task_completion(music_task)
	music_task = -1
	var stream := _wav(music_pcm)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = music_pcm.size() / 2
	music_player.stream = stream
	music_player.play()
	_apply_music()


func _exit_tree() -> void:
	if music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(music_task)


func _process(delta: float) -> void:
	time += delta
	_poll_music()
	menus.update(delta, screen)
	var view := get_viewport_rect().size
	y_offset = maxf((view.y - BASE_H) / 2.0, 0.0)
	screen_age += delta
	if screen == Menus.Screen.GAME and not paused:
		_process_game(delta)
	_update_fx(delta)
	var shake := trauma * trauma * 24.0 * _fx_scale()
	var offset := Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	position = Vector2(0.0, y_offset) + offset
	# The interface stays steady while the playfield shakes under it.
	ui_layer.position = -offset
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
		sim.step(delta)
	verify_stats["max_balls"] = max(int(verify_stats["max_balls"]), sim.balls.size())
	_consume_events()
	_note_offered_perks()
	if is_run_over():
		_bank_run()


## The results count up with rising ticks, so a good run takes a moment to sink in.
func _process_count_up(delta: float) -> void:
	var before := end_age
	end_age += delta
	if sim.coins <= 0 or before >= COUNT_UP_SECONDS:
		return
	if end_age >= COUNT_UP_SECONDS:
		_play("win", 1.5)
	elif time - last_tick_sound >= COUNT_UP_TICK:
		last_tick_sound = time
		_play("coin", 0.9 + end_age / COUNT_UP_SECONDS)


func _counted(value: int) -> int:
	var k := clampf(end_age / COUNT_UP_SECONDS, 0.0, 1.0)
	return int(value * (1.0 - pow(1.0 - k, 3.0)))


func _begin_burst() -> void:
	if not sim.can_burst():
		return
	burst_windup = 0.0
	burst_origin = Vector2(sim.launch_x, GameSim.LAUNCH_Y)
	aiming = false
	_play("charge", 1.0)
	trauma = 0.25


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


func _note_offered_perks() -> void:
	if sim.choices == seen_choices:
		return
	seen_choices = sim.choices.duplicate()
	for id in seen_choices:
		save.mark_perk_seen(id)
	if not seen_choices.is_empty():
		on_progress_changed(_live_stats())


func _fx_scale() -> float:
	return REDUCED_FX_SCALE if save.reduce_fx else 1.0


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
	if event is InputEventScreenTouch and event.index == 0:
		var p: Vector2 = event.position - Vector2(0.0, y_offset)
		if event.pressed:
			_on_press(p)
		else:
			_on_release(p)
	elif event is InputEventScreenDrag and event.index == 0:
		var p: Vector2 = event.position - Vector2(0.0, y_offset)
		if aiming:
			aim_current = p
		elif list_active:
			_on_list_drag(p)
	elif event is InputEventMouseMotion and not DisplayServer.is_touchscreen_available():
		# With a mouse the aim simply follows the cursor, and a click fires.
		hovering = true
		if not aiming:
			aim_current = event.position - Vector2(0.0, y_offset)


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
			if screen == Menus.Screen.GAME and sim.state == GameSim.State.UPGRADE and index < sim.choices.size():
				_on_press(card_rect(index, sim.choices.size()).get_center())


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
	if screen == Menus.Screen.GAME and not paused and boss_intro >= BOSS_INTRO_SKIP_AFTER:
		boss_intro = -1.0
		return
	if screen != Menus.Screen.GAME or paused or burst_windup >= 0.0 or boss_intro >= 0.0 or boss_down > 0.0:
		return
	match sim.state:
		GameSim.State.AIM:
			aiming = true
			aim_current = p
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


## Letting go below the launcher cancels the shot.
func _can_aim_at(p: Vector2) -> bool:
	return p.y < GameSim.LAUNCH_Y - MIN_AIM_HEIGHT


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
		"shop":
			shop_return = screen
			_set_screen(Menus.Screen.SHOP)
		"stars":
			_set_screen(Menus.Screen.STARS)
		"achievements":
			_set_screen(Menus.Screen.ACHIEVEMENTS)
		"codex":
			_set_screen(Menus.Screen.CODEX)
		"prestige":
			_set_screen(Menus.Screen.PRESTIGE)
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
				Menus.Screen.STARS:
					_set_screen(Menus.Screen.PRESTIGE)
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
		"to_title":
			_bank_run()
			paused = false
			_set_screen(Menus.Screen.TITLE)


func current_buttons() -> Array[Dictionary]:
	if screen != Menus.Screen.GAME:
		return menus.buttons(screen)
	var list: Array[Dictionary] = []
	if burst_windup >= 0.0 or (boss_intro >= 0.0 and not paused) or (boss_down > 0.0 and not paused):
		return list
	if paused:
		list.append(_button("resume", Rect2(110.0, 430.0, 500.0, 120.0), t("resume"), "primary"))
		list.append(_button("settings", Rect2(110.0, 570.0, 500.0, 100.0), t("settings")))
		list.append(_button("restart", Rect2(110.0, 690.0, 500.0, 100.0), t("restart")))
		list.append(_button("to_title", Rect2(110.0, 810.0, 500.0, 100.0), t("to_title")))
	elif is_run_over():
		list.append(_button("restart", Rect2(70.0, 930.0, 580.0, 120.0), t("retry"), "primary"))
		var can_buy: int = end_preview.get("levels", 0)
		list.append(_button("shop", Rect2(70.0, 1066.0, 282.0, 100.0), t("shop_can_buy") % can_buy if can_buy > 0 else t("shop")))
		list.append(_button("to_title", Rect2(368.0, 1066.0, 282.0, 100.0), t("to_title")))
	elif sim.state == GameSim.State.UPGRADE:
		if sim.rerolls > 0:
			list.append(_button("reroll", Rect2(160.0, 1110.0, 400.0, 90.0), t("reroll_button") % sim.rerolls))
	else:
		list.append(_button("pause", Rect2(628.0, 4.0, 88.0, 62.0), "", "icon"))
		if sim.can_burst():
			list.append(_button("burst", Rect2(120.0, 1140.0, 480.0, 96.0), t("burst_ready"), "burst"))
	return list


func _button(id: String, rect: Rect2, label: String, style := "normal") -> Dictionary:
	return {"id": id, "rect": rect, "label": label, "style": style}


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
			"burst_end":
				if not sim.blocks.is_empty():
					_show_banner(I18n.format_number(e["damage"]), 1.2)
			"stage_start":
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
			"won":
				_play("win", 1.25)
				trauma = 1.0
				screen_flash = 0.8
				_big_celebration()
			"lost":
				_play("lose", 1.0)
				trauma = 0.8


func _show_banner(text: String, seconds: float) -> void:
	banner_text = text
	banner_time = seconds


func _on_hit(e: Dictionary) -> void:
	flash[e["block_id"]] = 1.0
	var combo: int = e["combo"]
	var is_crit: bool = e["crit"]
	if numbers.size() < 70:
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


func _draw() -> void:
	canvas = self
	if screen != Menus.Screen.GAME:
		return
	var field := Rect2(GameSim.FIELD_X - 8.0, GameSim.FIELD_Y - 8.0, GameSim.FIELD_W + 16.0, GameSim.LAUNCH_Y - GameSim.FIELD_Y + 42.0)
	panel(field, Color(0.04, 0.03, 0.1, 0.42), 26.0, UI.LINE, 2)
	_draw_danger_line()
	_draw_laser_warning()
	_draw_blocks()
	_draw_boss_down()
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
		var tail: Vector2 = ball.pos - ball.vel.normalized() * (34.0 + radius * 2.0)
		glow_layer.draw_line(tail, ball.pos, Color(color, 0.3), radius * 1.3)
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


func _glow_sprite(center: Vector2, size: float, color: Color) -> void:
	canvas.draw_texture_rect(glow_texture, Rect2(center - Vector2(size, size) / 2.0, Vector2(size, size)), false, color)


func soft_glow(center: Vector2, size: Vector2, color: Color) -> void:
	canvas.draw_texture_rect(glow_texture, Rect2(center - size / 2.0, size), false, color)


## A colored dot with a halo, used for ball swatches on top of buttons.
func soft_glow_deferred(center: Vector2, color_code: String) -> void:
	_pending_dots.append({"pos": center, "color": Color(color_code)})


func _draw_ui() -> void:
	canvas = ui_layer
	_pending_dots.clear()
	if screen == Menus.Screen.GAME:
		_draw_game_ui()
	else:
		menus.draw(screen)
	menus.draw_buttons(current_buttons(), time)
	for dot in _pending_dots:
		soft_glow(dot["pos"], Vector2(70.0, 70.0), Color(dot["color"], 0.5))
		ui_layer.draw_circle(dot["pos"], 13.0, dot["color"])
	_draw_toast()


func _draw_list() -> void:
	canvas = list_clip
	list_clip.draw_set_transform(Vector2(0.0, -Menus.LIST_TOP))
	if menus.is_list_screen(screen):
		menus.draw_list(screen)


func _draw_toast() -> void:
	if toasts.is_empty():
		return
	var toast := toasts[0]
	var k := float(toast["t"])
	var slide := clampf(k / 0.2, 0.0, 1.0) * clampf((2.2 - k) / 0.2, 0.0, 1.0)
	var y := -50.0 + slide * 96.0
	var rect := Rect2(40.0, y - 33.0, 640.0, 66.0)
	panel(rect, Color(UI.PANEL_SOLID, 0.97), 33.0, Color(UI.GOLD, 0.7), 2)
	var text := String(toast["text"])
	text_center(Vector2(BASE_W / 2.0, y), text, fit_size(text, 26, 590.0), UI.GOLD)


func fill_screen(color: Color) -> void:
	var view := get_viewport_rect().size
	canvas.draw_rect(Rect2(-80.0, -y_offset - 80.0, view.x + 160.0, view.y + 160.0), color)


func panel(rect: Rect2, color: Color, radius := 16.0, border := Color.TRANSPARENT, border_width := 0) -> void:
	_box.bg_color = color
	_box.set_corner_radius_all(int(radius))
	_box.border_color = border
	_box.set_border_width_all(border_width)
	canvas.draw_style_box(_box, rect)


func row(left: Vector2, width: float, label: String, value: String, size: int, value_color: Color) -> void:
	canvas.draw_string(font_body, left + Vector2(0.0, size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, UI.MUTED)
	canvas.draw_string(font, left + Vector2(0.0, size * 0.35), value, HORIZONTAL_ALIGNMENT_RIGHT, width, size, value_color)


func _draw_game_ui() -> void:
	for c in fly_coins:
		canvas.draw_circle(c["pos"], 8.0, UI.GOLD)
	for n in numbers:
		var alpha := 1.0 - float(n["t"]) / 0.55
		var rise := clampf(float(n["t"]) / 0.08, 0.0, 1.0)
		var base_size := 46 if n["big"] else 25
		var size := int(base_size * (0.7 + rise * 0.3))
		var color := Color(UI.GOLD, alpha) if n["big"] else (Color(UI.MINT, alpha) if n["dot"] else Color(1.0, 1.0, 1.0, alpha))
		text_center(n["pos"], str(n["text"]), size, color)
	_draw_hud()
	if screen_flash > 0.0:
		fill_screen(Color(1.0, 0.96, 0.9, screen_flash * 0.32 * _fx_scale()))
	if boss_down <= 0.0:
		match sim.state:
			GameSim.State.UPGRADE:
				_draw_upgrade_screen()
			GameSim.State.WON:
				_draw_end_screen(t("you_win"), UI.GOLD)
			GameSim.State.LOST:
				_draw_end_screen(t("game_over"), UI.ACCENT)
	_draw_boss_speech()
	if banner_time > 0.0 and (sim.state != GameSim.State.UPGRADE or boss_down > 0.0) and not paused:
		var pop := 1.0 + clampf(banner_time - 0.75, 0.0, 0.25) * 1.6
		var alpha := minf(banner_time * 3.0, 1.0)
		soft_glow(Vector2(BASE_W / 2.0, 610.0), Vector2(900.0, 340.0), Color(UI.ACCENT, 0.3 * alpha))
		var size := fit_size(banner_text, int(84.0 * pop), 660.0)
		text_shadowed(Vector2(BASE_W / 2.0, 610.0), banner_text, size, Color(1.0, 1.0, 1.0, alpha))
	if burst_windup >= 0.0:
		_draw_burst_cut_in()
	if boss_intro >= 0.0:
		_draw_boss_intro()
	if paused:
		fill_screen(Color(UI.INK, 0.82))
		text_center(Vector2(BASE_W / 2.0, 310.0), t("paused"), 76, UI.TEXT)
		_draw_build(935.0, 6)


## A comic-style bubble under the boss, kept on screen wherever the boss has moved to.
func _draw_boss_speech() -> void:
	if speech_time <= 0.0 or paused or boss_intro >= 0.0:
		return
	if sim.boss_block != null:
		speech_anchor = sim.block_rect(sim.boss_block).get_center() + Vector2(0.0, 62.0)
	elif boss_down > 0.0:
		speech_anchor = boss_down_pos + Vector2(0.0, 62.0)
	else:
		return
	var alpha := minf(speech_time * 5.0, 1.0)
	var pop := 1.0 + clampf(speech_time - (SPEECH_SECONDS - 0.12), 0.0, 0.12) * 1.2
	var size := fit_size(speech_text, 26, 560.0)
	var width: float = font_body.get_string_size(speech_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 44.0
	var box := Rect2(clampf(speech_anchor.x - width / 2.0, 20.0, BASE_W - width - 20.0), speech_anchor.y + 18.0, width, 58.0).grow(pop * 2.0 - 2.0)
	var white := Color(1.0, 1.0, 1.0, alpha)
	canvas.draw_colored_polygon(PackedVector2Array([speech_anchor + Vector2(-13.0, 22.0), speech_anchor + Vector2(0.0, 2.0), speech_anchor + Vector2(13.0, 22.0)]), white)
	panel(box, white, 22.0)
	text_center(box.get_center(), speech_text, size, Color(UI.INK, alpha), font_body)


## Fighting-game entrance: bars close, the boss drops in, then its name and first words.
func _draw_boss_intro() -> void:
	var view := get_viewport_rect().size
	var id := boss_intro_id
	var color := Bosses.color(id)
	var enter := 1.0 - pow(1.0 - clampf(boss_intro / 0.28, 0.0, 1.0), 3.0)
	var leave := clampf((BOSS_INTRO - boss_intro) / 0.22, 0.0, 1.0)
	var alpha := enter * leave
	fill_screen(Color(UI.INK, alpha * 0.82))
	var bar := alpha * 150.0
	canvas.draw_rect(Rect2(-80.0, -y_offset - 80.0, view.x + 160.0, bar + 80.0), Color.BLACK)
	canvas.draw_rect(Rect2(-80.0, BASE_H + y_offset - bar, view.x + 160.0, bar + 80.0), Color.BLACK)
	var warning := t("boss_banner")
	var scroll := fmod(time * 120.0, 260.0)
	for edge_y: float in [bar - 44.0, BASE_H - bar + 12.0]:
		for i in range(-1, 4):
			text_left(Vector2(i * 260.0 + scroll, edge_y + 16.0), warning, 24, Color(UI.DANGER, alpha * 0.9), font_label)
	soft_glow(Vector2(BASE_W / 2.0, 500.0), Vector2(1100.0, 760.0), Color(color, alpha * 0.55))
	# A falling drop with one small bounce, so the landing has weight.
	var fall := clampf(boss_intro / 0.42, 0.0, 1.0)
	var drop := (1.0 - fall * fall) * -760.0
	var after := maxf(boss_intro - 0.42, 0.0)
	drop -= absf(sin(after * 9.0)) * exp(-after * 7.0) * 46.0
	var size := Vector2(528.0, 228.0)
	var rect := Rect2(Vector2((BASE_W - size.x) / 2.0, 390.0 + drop), size)
	var mood := "hurt" if after > 0.0 and after < 0.12 else "idle"
	BossArt.draw(canvas, id, rect, mood, time)
	var reveal := clampf((boss_intro - 0.55) / 0.16, 0.0, 1.0) * leave
	if reveal <= 0.0:
		return
	var slide := (1.0 - reveal) * 120.0
	var title := t("boss_%s_title" % id)
	text_center(Vector2(BASE_W / 2.0 - slide, 690.0), title, fit_size(title, 28, 640.0), Color(color.lightened(0.35), reveal), font_label)
	var name_text := t("boss_%s_name" % id)
	text_shadowed(Vector2(BASE_W / 2.0 + slide, 760.0), name_text, fit_size(name_text, 96, 640.0), Color(1.0, 1.0, 1.0, reveal))
	var talk := clampf((boss_intro - 0.85) / 0.14, 0.0, 1.0) * leave
	if talk <= 0.0:
		return
	var line := t("boss_%s_intro" % id)
	var line_size := fit_size(line, 30, 580.0)
	var width: float = font_body.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, line_size).x + 56.0
	var box := Rect2((BASE_W - width) / 2.0, 846.0, width, 74.0)
	panel(box, Color(1.0, 1.0, 1.0, talk), 28.0)
	text_center(box.get_center(), line, line_size, Color(UI.INK, talk), font_body)


## Cinema bars close in and the move's name slams across the screen.
func _draw_burst_cut_in() -> void:
	var view := get_viewport_rect().size
	var k := clampf(burst_windup / BURST_WINDUP, 0.0, 1.0)
	var enter := 1.0 - pow(1.0 - clampf(k / 0.25, 0.0, 1.0), 3.0)
	fill_screen(Color(UI.INK, enter * 0.55))
	var bar := enter * 170.0
	canvas.draw_rect(Rect2(-80.0, -y_offset - 80.0, view.x + 160.0, bar + 80.0), Color.BLACK)
	canvas.draw_rect(Rect2(-80.0, BASE_H + y_offset - bar, view.x + 160.0, bar + 80.0), Color.BLACK)
	var color := _ball_color().lerp(UI.ACCENT, 0.55)
	var center_y := 560.0
	# The band races in, nearly stops so the name can be read, then leaves.
	var slide := (1.0 - enter) * 900.0 - maxf(k - 0.82, 0.0) / 0.18 * 1000.0
	var band := Rect2(-80.0 + slide, center_y - 120.0, view.x + 160.0, 240.0)
	soft_glow(Vector2(BASE_W / 2.0 + slide, center_y), Vector2(1200.0, 600.0), Color(color, 0.55))
	canvas.draw_rect(band, Color(color, 0.92))
	canvas.draw_rect(Rect2(band.position, Vector2(band.size.x, 6.0)), Color.WHITE)
	canvas.draw_rect(Rect2(band.position + Vector2(0.0, band.size.y - 6.0), Vector2(band.size.x, 6.0)), Color.WHITE)
	var name_text := t("burst_" + sim.ball_type)
	var creep := (0.5 - k) * 40.0
	text_center(Vector2(BASE_W / 2.0 + slide + creep, center_y - 66.0), t("burst"), 26, UI.INK, font_label)
	text_center(Vector2(BASE_W / 2.0 + slide - creep, center_y + 18.0), name_text, fit_size(name_text, 96, 650.0), UI.INK)


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
		var hit: float = clampf(float(flash.get(block["id"], 0.0)), 0.0, 1.0)
		# A struck block swells for a moment, so every hit has weight.
		var drawn := rect.grow(hit * 3.0)
		_draw_block_body(kind, drawn, _block_color(block))
		if block.has("post"):
			panel(drawn, Color.TRANSPARENT, 14.0, Color("8be9fd"), 3)
		if hit > 0.0:
			panel(drawn, Color(1.0, 1.0, 1.0, hit * 0.85), 14.0)
		if int(block["poison"]) > 0:
			canvas.draw_circle(rect.position + Vector2(rect.size.x - 11.0, 12.0), 5.0, Color("2f9e44"))
		if block["burning"]:
			canvas.draw_circle(rect.position + Vector2(rect.size.x - 11.0, rect.size.y - 12.0), 5.0, Color("e8590c"))
		var hp_text := I18n.format_number(block["hp"])
		var ink: Color = UI.TEXT if kind == "armor" else UI.INK
		text_center(rect.get_center() + Vector2(0.0, 2.0), hp_text, fit_size(hp_text, 27, rect.size.x - 20.0), ink)


## Base look of a block, shared with the codex.
func _draw_block_body(kind: String, rect: Rect2, color: Color) -> void:
	panel(rect, color, 14.0)
	panel(Rect2(rect.position + Vector2(4.0, 3.0), Vector2(rect.size.x - 8.0, rect.size.y * 0.4)), Color(1.0, 1.0, 1.0, 0.2), 10.0)
	# Icons sit in a corner so large HP numbers stay readable.
	var corner := rect.position + Vector2(14.0, 14.0)
	match kind:
		"bomb":
			canvas.draw_circle(corner, 6.0, UI.INK)
			canvas.draw_line(corner + Vector2(3.0, -4.0), corner + Vector2(7.0, -9.0), UI.INK, 2.0)
		"shield":
			panel(rect, Color.TRANSPARENT, 14.0, Color.WHITE, 4)
		"armor":
			panel(rect, Color.TRANSPARENT, 14.0, Color("2b2f45"), 6)
		"regen":
			canvas.draw_rect(Rect2(corner + Vector2(-6.0, -2.0), Vector2(12.0, 4.0)), UI.INK)
			canvas.draw_rect(Rect2(corner + Vector2(-2.0, -6.0), Vector2(4.0, 12.0)), UI.INK)
		"treasure":
			panel(Rect2(corner + Vector2(-7.0, -5.0), Vector2(14.0, 11.0)), Color("8a5a00"), 3.0)
		"breeder":
			canvas.draw_circle(corner + Vector2(-3.0, 0.0), 4.0, UI.INK)
			canvas.draw_circle(corner + Vector2(6.0, 0.0), 4.0, UI.INK)
		"extra_ball":
			canvas.draw_circle(corner, 7.0, Color("3b82f6"))


func draw_block_icon(kind: String, rect: Rect2) -> void:
	if kind == "boss":
		BossArt.draw(canvas, "purun", rect, "idle", time)
		return
	_draw_block_body(kind, rect, UI.BLOCKS.get(kind, UI.RAMP[1]))


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
	var hp_text := I18n.format_number(block["hp"])
	text_center(bar.get_center() + Vector2(1.0, 2.5), hp_text, 20, Color(0.0, 0.0, 0.0, 0.85))
	text_center(bar.get_center() + Vector2(0.0, 1.0), hp_text, 20, Color.WHITE)


func _block_color(block: Dictionary) -> Color:
	if block.has("tint"):
		return Bosses.color("purun")
	var kind: String = block["kind"]
	if UI.BLOCKS.has(kind):
		return UI.BLOCKS[kind]
	var top: float = float(GameSim.STAGES[sim.stage]["hp_max"]) * GameSim.Tiers.hp_scale(sim.tier)
	return UI.ramp(float(block["hp"]) / top)


func _combo_color(combo: int) -> Color:
	return UI.ramp(fmod(combo * 0.018, 1.0))


func _ball_color() -> Color:
	return Color(String(Balls.BALLS[sim.ball_type]["color"]))


func _draw_balls() -> void:
	var base := _ball_color()
	var radius := sim.ball_radius
	for ball in sim.balls:
		var color: Color = base.lerp(UI.STAR, 0.5) if ball.temp else base
		canvas.draw_circle(ball.pos, radius, color)


func _draw_launcher() -> void:
	if sim.state != GameSim.State.AIM:
		return
	var p := Vector2(sim.launch_x, GameSim.LAUNCH_Y)
	var color := _ball_color()
	var breathe := 1.0 + sin(time * 4.0) * 0.08
	soft_glow(p, Vector2(110.0, 110.0) * breathe, Color(color, 0.4))
	canvas.draw_circle(p, sim.ball_radius + 3.0, color)
	text_center(p + Vector2(0.0, 44.0), "x%d" % sim.shot_ball_count(), 26, UI.TEXT)
	if sim.guards > 0:
		text_center(Vector2(120.0, 1118.0), "GUARD x%d" % sim.guards, 20, UI.MINT, font_label)
	if not aiming and not save.tutorial_done:
		text_center(Vector2(BASE_W / 2.0, 1180.0), t("tutorial"), 36, UI.GOLD)
		# A pointer drifts across the field, showing that you aim by pointing.
		var drift := Vector2(BASE_W / 2.0 + sin(time * 1.8) * 220.0, 640.0 + cos(time * 2.6) * 50.0)
		soft_glow(drift, Vector2(120.0, 120.0), Color(1.0, 1.0, 1.0, 0.5))
		canvas.draw_circle(drift, 18.0, Color(1.0, 1.0, 1.0, 0.85))


func _draw_aim() -> void:
	if not _can_aim_at(aim_current):
		return
	var points := sim.trace_aim(aim_current - Vector2(sim.launch_x, GameSim.LAUNCH_Y))
	var phase := fmod(time * 180.0, 32.0)
	var travelled := 0.0
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var d := phase
		while d < length:
			var fade := 1.0 - clampf((travelled + d) / 1000.0, 0.0, 0.85)
			canvas.draw_circle(a.lerp(b, d / length), 2.0 + 4.0 * fade, Color(1.0, 1.0, 1.0, 0.25 + 0.65 * fade))
			d += 32.0
		travelled += length


func _draw_hud() -> void:
	text_center(Vector2(100.0, 58.0), t("hud_stage"), 18, UI.MUTED, font_label)
	text_center(Vector2(100.0, 98.0), "%d/%d" % [sim.stage + 1, GameSim.STAGES.size()], 38, UI.TEXT)
	if sim.tier > 0:
		var chip := Rect2(46.0, 128.0, 108.0, 30.0)
		panel(chip, Color(UI.ACCENT, 0.2), 15.0)
		text_center(chip.get_center(), t("tier_label") % sim.tier, fit_size(t("tier_label") % sim.tier, 17, 96.0), UI.ACCENT, font_body)
	text_center(Vector2(BASE_W / 2.0, 58.0), t("hud_damage"), 18, UI.MUTED, font_label)
	text_center(Vector2(BASE_W / 2.0, 98.0), I18n.format_number(sim.total_damage), 38, UI.TEXT)
	if sim.waves_left > 0:
		text_center(Vector2(BASE_W / 2.0, 134.0), t("hud_waves") % sim.waves_left, 20, UI.MINT, font_body)
	var coin_size := int(36.0 + coin_pop * 14.0)
	canvas.draw_circle(Vector2(575.0, 98.0), 13.0, UI.GOLD)
	text_center(Vector2(640.0, 98.0), I18n.format_number(sim.coins), coin_size, UI.GOLD)
	if sim.state == GameSim.State.SHOOT and sim.combo >= 5:
		_draw_combo()
	if sim.state in [GameSim.State.AIM, GameSim.State.SHOOT] and not sim.can_burst():
		_draw_burst_gauge()


func _draw_burst_gauge() -> void:
	var bar := Rect2(170.0, 1250.0, 380.0, 12.0)
	text_right(bar.position + Vector2(-16.0, 6.0), t("burst"), 16, UI.MUTED, font_label)
	panel(bar, Color(1.0, 1.0, 1.0, 0.1), 6.0)
	if sim.burst_charge > 0.0:
		var color: Color = UI.ramp(sim.burst_charge)
		var filled := Rect2(bar.position, Vector2(maxf(bar.size.x * sim.burst_charge, 12.0), bar.size.y))
		soft_glow(filled.end - Vector2(0.0, 6.0), Vector2(70.0, 70.0), Color(color, 0.5))
		panel(filled, color, 6.0)
	text_left(bar.end + Vector2(16.0, -6.0), "%d%%" % int(sim.burst_charge * 100.0), 18, UI.MUTED, font_body)


## The combo counter grows, brightens and shifts color as the chain climbs.
func _draw_combo() -> void:
	var pop := 1.0 + combo_pop * 0.28
	var color := _combo_color(sim.combo)
	var center := Vector2(BASE_W / 2.0, 1170.0)
	var size := int(minf(58.0 + sim.combo * 0.35, 112.0) * pop)
	soft_glow(center, Vector2(620.0, 280.0), Color(color, clampf(0.12 + sim.combo * 0.003, 0.0, 0.45)))
	text_center(center, str(sim.combo), size, color)
	text_center(center + Vector2(0.0, size * 0.62 + 8.0), t("hits_label"), 20, Color(color, 0.8), font_label)


func _draw_upgrade_screen() -> void:
	fill_screen(Color(UI.INK, 0.8))
	var clearing := sim.blocks.is_empty()
	var heading := t("stage_clear") if clearing else t("pick_start")
	var burst := 1.0 + maxf(0.25 - screen_age, 0.0) * 1.2
	soft_glow(Vector2(BASE_W / 2.0, 190.0), Vector2(860.0, 320.0), Color(UI.GOLD, 0.2 + sin(time * 3.0) * 0.05))
	text_center(Vector2(BASE_W / 2.0, 190.0), heading, int(fit_size(heading, 62, 640.0) * burst), UI.GOLD)
	if clearing:
		text_center(Vector2(BASE_W / 2.0, 262.0), t("pick_one"), 26, UI.MUTED, font_body)
	var count := sim.choices.size()
	for i in count:
		# Cards rise in one after another.
		var appear := clampf((screen_age - i * 0.06) / 0.22, 0.0, 1.0)
		var ease_in := 1.0 - pow(1.0 - appear, 3.0)
		var id := sim.choices[i]
		var rect := card_rect(i, count)
		rect.position.y += (1.0 - ease_in) * 70.0
		var hint := _card_hint(id)
		var has_hint := String(hint["text"]) != ""
		# The icon sits in its own column, so the eye can run down the cards and compare them.
		var icon_area := minf(rect.size.y - (56.0 if has_hint else 32.0), CARD_ICON_MAX)
		var icon_center := rect.position + Vector2(24.0 + icon_area / 2.0, 14.0 + (rect.size.y - (40.0 if has_hint else 0.0) - 14.0) / 2.0)
		var text_left_edge := icon_area + 34.0
		var text_x := text_left_edge + (rect.size.x - text_left_edge) / 2.0
		var text_width := rect.size.x - text_left_edge - 24.0
		var perk: Dictionary = Perks.PERKS[id]
		var color: Color = UI.RARITY[int(perk["rarity"])]
		var evolution := Perks.is_evolution(id)
		if evolution:
			var pulse := 0.5 + sin(time * 4.0) * 0.5
			soft_glow(rect.get_center(), rect.size * 1.5, Color(color, (0.2 + pulse * 0.25) * ease_in))
		panel(rect, Color(UI.PANEL_SOLID, 0.96 * ease_in), 30.0, Color(color, (0.9 if evolution else 0.45) * ease_in), 3 if evolution else 2)
		panel(Rect2(rect.position + Vector2(rect.size.x * 0.35, -2.0), Vector2(rect.size.x * 0.3, 5.0)), Color(color, ease_in), 2.5)
		var tile := Rect2(icon_center - Vector2.ONE * icon_area / 2.0, Vector2.ONE * icon_area)
		panel(tile, Color(PerkArt.color_of(id), 0.14 * ease_in), icon_area * 0.24, Color(PerkArt.color_of(id), 0.5 * ease_in), 2)
		PerkArt.draw(canvas, id, icon_center, icon_area * 0.36, ease_in)
		var label := t("evolution") if evolution else t("rarity_%d" % int(perk["rarity"]))
		text_center(rect.position + Vector2(text_x, 30.0), label, 16, Color(color, ease_in), font_label)
		var level: int = sim.levels[id]
		if level > 0:
			text_right(rect.position + Vector2(rect.size.x - 28.0, 30.0), t("level") % level, 19, Color(UI.MUTED, ease_in), font_body)
		var name_text := t("perk_" + id)
		text_center(rect.position + Vector2(text_x, rect.size.y * (0.3 if has_hint else 0.38)), name_text, fit_size(name_text, 42, text_width), Color(color, ease_in))
		var lines := t("perk_%s_desc" % id).split("\n")
		var line_y := rect.size.y * ((0.5 if lines.size() > 1 else 0.56) if has_hint else (0.64 if lines.size() > 1 else 0.7))
		for l in lines.size():
			text_center(rect.position + Vector2(text_x, line_y + l * 34.0), lines[l], fit_size(lines[l], 25, text_width), Color(UI.MUTED, ease_in), font_body)
		if has_hint:
			var hint_text := String(hint["text"])
			var hint_color: Color = hint["color"]
			text_center(rect.position + Vector2(rect.size.x / 2.0, rect.size.y - 27.0), hint_text, fit_size(hint_text, 24, rect.size.x - 50.0), Color(hint_color, ease_in))


## The one line that tells a card's place in the build: what it evolves from or into,
## or which part of the current build it feeds.
func _card_hint(id: String) -> Dictionary:
	if Perks.is_evolution(id):
		var parents: Array = Perks.PERKS[id]["requires"]
		return {"text": t("evolve_recipe") % [t("perk_" + String(parents[0])), t("perk_" + String(parents[1]))], "color": UI.GOLD}
	var path := sim.evolution_hint(id)
	if bool(path.get("ready", false)):
		return {"text": t("hint_evolve_ready") % t("perk_" + String(path["evolution"])), "color": UI.GOLD}
	var owned := sim.tag_levels()
	for tag in Perks.tags_of(id):
		if int(owned.get(tag, 0)) > 0:
			return {"text": t("hint_synergy") % t("tag_" + tag), "color": UI.MINT}
	if not path.is_empty():
		return {"text": t("hint_evolve_partner") % [t("perk_" + String(path["partner"])), t("perk_" + String(path["evolution"]))], "color": UI.STAR}
	return {"text": "", "color": UI.MUTED}


## The run's build: its strongest leanings on one line, then every owned perk as a chip.
func _draw_build(top: float, max_rows: int) -> void:
	var left := 60.0
	var right := BASE_W - 60.0
	var totals := sim.tag_levels()
	var tags: Array = totals.keys()
	tags.sort_custom(func(a: String, b: String) -> bool: return int(totals[a]) > int(totals[b]))
	var summary: Array[String] = []
	for tag: String in tags.slice(0, 3):
		summary.append("%s ×%d" % [t("tag_" + tag), int(totals[tag])])
	text_left(Vector2(left, top), t("build_title"), 20, UI.MUTED, font_label)
	text_right(Vector2(right, top), "   ".join(summary), 22, UI.MINT)
	var owned: Array[String] = []
	for id in Perks.ids():
		if int(sim.levels[id]) > 0:
			owned.append(id)
	if owned.is_empty():
		text_center(Vector2(BASE_W / 2.0, top + 44.0), t("build_empty"), 22, UI.MUTED, font_body)
		return
	# Evolutions lead, since they are the payoff of the whole build.
	owned.sort_custom(func(a: String, b: String) -> bool:
		var a_evo := Perks.is_evolution(a)
		if a_evo != Perks.is_evolution(b):
			return a_evo
		return int(sim.levels[a]) > int(sim.levels[b]))
	const CHIP_H := 38.0
	const CHIP_GAP := 8.0
	const CHIP_SIZE := 21
	var x := left
	var y := top + 24.0
	var row_index := 0
	for id in owned:
		var level: int = sim.levels[id]
		var label := t("perk_" + id) if level <= 1 else "%s %d" % [t("perk_" + id), level]
		var width: float = minf(font_body.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE).x + 54.0, right - left)
		if x + width > right:
			x = left
			y += CHIP_H + CHIP_GAP
			row_index += 1
			if row_index >= max_rows:
				return
		var chip := Rect2(x, y, width, CHIP_H)
		var color: Color = UI.RARITY[int(Perks.PERKS[id]["rarity"])]
		panel(chip, Color(color, 0.14), CHIP_H / 2.0, Color(color, 0.8 if Perks.is_evolution(id) else 0.4), 2)
		PerkArt.draw(canvas, id, chip.position + Vector2(22.0, CHIP_H / 2.0), CHIP_ICON_RADIUS)
		text_center(chip.get_center() + Vector2(14.0, 0.0), label, fit_size(label, CHIP_SIZE, width - 48.0), color, font_body)
		x += width + CHIP_GAP


func card_rect(index: int, count: int) -> Rect2:
	var top := 305.0
	var area := 785.0
	var gap := 16.0
	var height := minf((area - gap * (count - 1)) / count, 235.0)
	return Rect2(70.0, top + index * (height + gap), 580.0, height)


func _draw_end_screen(title: String, color: Color) -> void:
	fill_screen(Color(UI.INK, 0.86))
	var pop := 1.0 + maxf(0.3 - screen_age, 0.0) * 1.2
	soft_glow(Vector2(BASE_W / 2.0, 124.0), Vector2(860.0, 300.0), Color(color, 0.22))
	text_center(Vector2(BASE_W / 2.0, 124.0), title, int(fit_size(title, 72, 640.0) * pop), color)
	var cause := _defeat_line()
	if cause != "":
		text_center(Vector2(BASE_W / 2.0, 176.0), cause, fit_size(cause, 26, 620.0), UI.MUTED, font_body)
	if run_new_record:
		var chip := Rect2(BASE_W / 2.0 - 150.0, 198.0, 300.0, 48.0)
		panel(chip, Color(UI.GOLD, 0.14 + sin(time * 5.0) * 0.05), 24.0, UI.GOLD, 2)
		text_center(chip.get_center(), t("new_record"), fit_size(t("new_record"), 25, 270.0), UI.GOLD)
	text_center(Vector2(BASE_W / 2.0, 272.0), t("total_damage"), 20, UI.MUTED, font_label)
	text_center(Vector2(BASE_W / 2.0, 326.0), I18n.format_number(_counted(sim.total_damage)), 72, UI.TEXT)
	panel(Rect2(70.0, 376.0, 580.0, 240.0), UI.PANEL, 28.0, UI.LINE, 2)
	var seconds := int(run_seconds)
	var rows := [
		["best_shot", I18n.format_number(sim.best_shot_damage)],
		["best_combo", str(sim.best_combo)],
		["coins", t("coins_balance") % [I18n.format_number(_counted(sim.coins)), I18n.format_number(save.coins - sim.coins + _counted(sim.coins))]],
		["reached", "%d / %d" % [sim.stage + 1, GameSim.STAGES.size()]],
		["play_time", "%d:%02d" % [seconds / 60, seconds % 60]],
		["mastery_row", "%s Lv %d  +%d" % [t("ball_" + sim.ball_type), save.mastery_level(sim.ball_type), SaveData.run_xp(sim.stage + 1, sim.state == GameSim.State.WON, sim.tier)]],
	]
	for i in rows.size():
		row(Vector2(105.0, 404.0 + i * 38.0), 510.0, t(rows[i][0]), rows[i][1], 24, UI.TEXT)
	_draw_next_unlock(Rect2(70.0, 628.0, 580.0, 88.0))
	_draw_build(734.0, 3)
	var after: int = end_preview.get("power", 0)
	var now := save.power_rating()
	if after > now:
		var gain := t("power_gain") % ceili(100.0 * float(after - now) / float(now))
		text_center(Vector2(BASE_W / 2.0, 908.0), gain, fit_size(gain, 24, 600.0), UI.GOLD)


## Says what ended the run, so the next one has something to try differently.
func _defeat_line() -> String:
	if sim.state != GameSim.State.LOST:
		return ""
	if sim.boss_block == null:
		return t("defeat_blocks")
	var boss: Dictionary = sim.boss_block
	var percent := ceili(100.0 * float(boss["hp"]) / maxf(float(boss["max_hp"]), 1.0))
	return t("defeat_boss") % [t("boss_%s_name" % sim.boss_id()), percent]


func _draw_next_unlock(box: Rect2) -> void:
	var goal := save.next_unlock()
	if goal.is_empty():
		return
	var reward := t("perk_" + String(goal["perk"])) if goal["perk"] != "" else t("ball_" + String(goal["ball"]))
	var progress: float = goal["progress"]
	var left := box.position.x + 26.0
	var right := box.end.x - 26.0
	panel(box, UI.PANEL, 24.0, UI.LINE, 2)
	text_left(Vector2(left, box.position.y + 22.0), t("next_unlock"), 18, UI.MUTED, font_label)
	text_right(Vector2(right, box.position.y + 22.0), reward, fit_size(reward, 24, 330.0), UI.MINT)
	var goal_title := menus.achievement_title(goal["id"])
	text_left(Vector2(left, box.position.y + 50.0), goal_title, fit_size(goal_title, 20, 440.0), UI.TEXT, font_body)
	text_right(Vector2(right, box.position.y + 50.0), "%d%%" % int(progress * 100.0), 20, UI.MUTED, font_body)
	var bar := Rect2(left, box.position.y + 68.0, right - left, 8.0)
	panel(bar, Color(1.0, 1.0, 1.0, 0.08), 4.0)
	if progress > 0.0:
		panel(Rect2(bar.position, Vector2(maxf(bar.size.x * progress, 8.0), bar.size.y)), UI.ACCENT, 4.0)


## Largest size up to `size` at which the text fits, so no language can overflow a box.
func fit_size(text: String, size: int, max_width: float) -> int:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return size if width <= max_width else int(size * max_width / width)


func text_center(center: Vector2, text: String, size: int, color: Color, face: Font = null) -> void:
	var used: Font = font if face == null else face
	var width := used.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(used, center + Vector2(-width / 2.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func text_left(left: Vector2, text: String, size: int, color: Color, face: Font = null) -> void:
	canvas.draw_string(font if face == null else face, left + Vector2(0.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func text_right(right: Vector2, text: String, size: int, color: Color, face: Font = null) -> void:
	var used: Font = font if face == null else face
	var width := used.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(used, right + Vector2(-width, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func text_shadowed(center: Vector2, text: String, size: int, color: Color) -> void:
	text_center(center + Vector2(0.0, 5.0), text, size, Color(UI.INK, color.a * 0.6))
	text_center(center, text, size, color)


func _build_audio() -> void:
	sounds = {
		"hit": _tone(880.0, 0.06, 0.28, "triangle"),
		"pop": _tone(520.0, 0.09, 0.4, "triangle", -3000.0),
		"boom": _noise(0.3, 0.75),
		"coin": _tone(1320.0, 0.07, 0.22, "sine", 2500.0),
		"fire": _tone(300.0, 0.1, 0.3, "triangle", 1800.0),
		"pick": _tone(660.0, 0.12, 0.35, "sine", 1600.0),
		"win": _tone(660.0, 0.35, 0.45, "triangle", 1200.0),
		"lose": _tone(300.0, 0.5, 0.45, "triangle", -380.0),
		"charge": _tone(120.0, BURST_WINDUP, 0.5, "triangle", 900.0, true),
		"blast": _noise(1.1, 0.95),
	}
	for i in 14:
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = MUSIC_VOLUME_DB
	add_child(music_player)


func _play(id: String, pitch: float) -> void:
	var player := players[next_player]
	next_player = (next_player + 1) % players.size()
	player.stream = sounds[id]
	player.pitch_scale = pitch
	player.play()


func _tone(freq: float, duration: float, volume: float, wave: String, sweep := 0.0, swell := false) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var k := float(i) / SAMPLE_RATE
		phase += (freq + sweep * k) / SAMPLE_RATE
		# A triangle wave is rounder than a square, and sits better with the softer look.
		var value := sin(phase * TAU) if wave == "sine" else 1.0 - 4.0 * absf(fmod(phase, 1.0) - 0.5)
		var progress := float(i) / count
		var envelope := progress if swell else 1.0 - progress
		data.encode_s16(i * 2, int(value * volume * envelope * 32767.0))
	return _wav(data)


func _noise(duration: float, volume: float) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var held := 0.0
	for i in count:
		# Holding each sample longer over time drops the pitch, like a real blast.
		if i % (1 + i / 800) == 0:
			held = randf_range(-1.0, 1.0)
		var env := pow(1.0 - float(i) / count, 2.0)
		data.encode_s16(i * 2, int(held * volume * env * 32767.0))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream
