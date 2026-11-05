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
const RunContent := preload("res://data/run_content.gd")
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
const KIND_BORDER := 4
const CARD_PATH_WIDTH := 96.0
const OBSTACLE_BODY := Color("2a2845")
const OBSTACLE_EDGE := Color("6f6b9c")
const OBSTACLE_PORTAL := Color("c77dff")
const OBSTACLE_PULSE_DECAY := 6.0
const BUILD_TILE := 54.0
const BUILD_GAP := 8.0
const STAGE_PIP_SPACING := 26.0
## The last target slows time, and destroying it nearly stops it.
const TENSION_SLOW := 0.45
const TENSION_SECONDS := 1.2
const TENSION_ZOOM := 1.05
const TENSION_BOSS_HP := 0.08
const FINISH_SLOW := 0.12
const FINISH_SECONDS := 0.6
const FINISH_ZOOM := 1.16
const FINISH_FX_RATE := 0.35
const ZOOM_SPEED := 10.0
const RANK_SECONDS := 1.4
const RANK_POP_SECONDS := 0.16
## Ranks below this are not worth interrupting the player's eye for.
const RANK_SHOW_FROM := 2
const RANK_COLORS: Array[Color] = [Color("8a8aa3"), Color("9db8ff"), Color("5ff0d0"), Color("6fdc6a"), Color("ffd84d"), Color("ff9a3d"), Color("ff5fa2")]
const TRAIL_BASE := 34.0
const TRAIL_PER_COMBO := 0.8
const TRAIL_MAX_EXTRA := 110.0
const TRAIL_COLOR_FULL_COMBO := 60.0
const EVOLVE_SECONDS := 2.1
const EVOLVE_IMPACT := 0.6
const EVOLVE_SKIP_AFTER := 0.3
const EVOLVE_FADE := 0.25

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
var last_bumper_sound := 0.0
var last_tick_sound := 0.0
var last_overkill_text := 0.0
var run_mastery_before := 0
var finish_time := 0.0
var tension_left := TENSION_SECONDS
var zoom := 1.0
var zoom_target := 1.0
var zoom_focus := Vector2(BASE_W / 2.0, BASE_H / 2.0)
var rank_time := 0.0
var rank_shown := 0
var evolve_cut := -1.0
var evolve_id := ""
var evolve_hit := false
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
	var mastery_now := save.mastery_level(sim.ball_type)
	if mastery_now > run_mastery_before:
		toasts.append({"text": t("mastery_toast") % [t("ball_" + sim.ball_type), mastery_now], "t": 0.0})
	on_progress_changed()


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
	if is_run_over():
		_bank_run()


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
		"event_leave":
			sim.leave_event()
		"to_title":
			_bank_run()
			paused = false
			_set_screen(Menus.Screen.TITLE)


func current_buttons() -> Array[Dictionary]:
	if screen != Menus.Screen.GAME:
		return menus.buttons(screen)
	var list: Array[Dictionary] = []
	if burst_windup >= 0.0 or evolve_cut >= 0.0 or (boss_intro >= 0.0 and not paused) or (boss_down > 0.0 and not paused):
		return list
	if paused:
		list.append(_button("resume", Rect2(110.0, 510.0, 500.0, 110.0), t("resume"), "primary"))
		list.append(_button("settings", Rect2(110.0, 636.0, 500.0, 84.0), t("settings")))
		list.append(_button("restart", Rect2(110.0, 736.0, 500.0, 84.0), t("restart")))
		list.append(_button("to_title", Rect2(110.0, 836.0, 500.0, 84.0), t("to_title")))
	elif is_run_over():
		list.append(_button("restart", Rect2(70.0, 930.0, 580.0, 120.0), t("retry"), "primary"))
		list.append(_button("shop", Rect2(70.0, 1066.0, 282.0, 100.0), t("shop")))
		list.append(_button("to_title", Rect2(368.0, 1066.0, 282.0, 100.0), t("to_title")))
	elif sim.state == GameSim.State.ROUTE:
		pass
	elif sim.state == GameSim.State.EVENT:
		list.append(_button("event_leave", Rect2(160.0, 1110.0, 400.0, 90.0), t("event_leave")))
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
			"companion":
				_play("pick", 2.0)
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


func _draw() -> void:
	canvas = self
	if screen != Menus.Screen.GAME:
		return
	var field := Rect2(GameSim.FIELD_X - 8.0, GameSim.FIELD_Y - 8.0, GameSim.FIELD_W + 16.0, GameSim.LAUNCH_Y - GameSim.FIELD_Y + 42.0)
	panel(field, Color(0.04, 0.03, 0.1, 0.42), 26.0, UI.LINE, 2)
	_draw_danger_line()
	_draw_laser_warning()
	_draw_obstacles()
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
		# The tail grows and takes on the combo's colour as a shot heats up.
		var length := TRAIL_BASE + radius * 2.0 + minf(sim.combo * TRAIL_PER_COMBO, TRAIL_MAX_EXTRA)
		var trail_color := color.lerp(_combo_color(sim.combo), minf(sim.combo / TRAIL_COLOR_FULL_COMBO, 0.85))
		var back: Vector2 = -ball.vel.normalized() * length
		glow_layer.draw_line(ball.pos + back, ball.pos + back * 0.45, Color(trail_color, 0.14), radius * 0.9)
		glow_layer.draw_line(ball.pos + back * 0.45, ball.pos, Color(trail_color, 0.34), radius * 1.4)
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
			GameSim.State.ROUTE:
				_draw_route_screen()
			GameSim.State.EVENT:
				_draw_event_screen()
			GameSim.State.WON:
				_draw_end_screen(t("you_win"), UI.GOLD)
			GameSim.State.LOST:
				_draw_end_screen(t("game_over"), UI.ACCENT)
	_draw_rank()
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
	if evolve_cut >= 0.0:
		_draw_evolve_cut()
	if paused:
		fill_screen(Color(UI.INK, 0.82))
		text_center(Vector2(BASE_W / 2.0, 230.0), t("paused"), 76, UI.TEXT)
		_draw_missions(Vector2(110.0, 330.0))
		_draw_build(950.0, 3)


## Slams in beside the field, clear of the heading and the cards when a stage just ended.
func _draw_rank() -> void:
	if rank_time <= 0.0 or is_run_over() or paused:
		return
	var age := RANK_SECONDS - rank_time
	var pop := 1.0 + maxf(RANK_POP_SECONDS - age, 0.0) / RANK_POP_SECONDS * 0.9
	var alpha := minf(rank_time * 4.0, 1.0)
	var color: Color = RANK_COLORS[rank_shown]
	var center := Vector2(610.0, 262.0)
	soft_glow(center, Vector2(240.0, 200.0), Color(color, 0.4 * alpha))
	text_shadowed(center, GameSim.RANKS[rank_shown], int(fit_size(GameSim.RANKS[rank_shown], 66, 170.0) * pop), Color(color, alpha))


func _draw_evolve_cut() -> void:
	var center := Vector2(BASE_W / 2.0, 500.0)
	var fade := clampf((EVOLVE_SECONDS - evolve_cut) / EVOLVE_FADE, 0.0, 1.0)
	fill_screen(Color(UI.INK, 0.9 * minf(evolve_cut / 0.12, 1.0) * fade))
	var parents: Array = Perks.PERKS[evolve_id]["requires"]
	if evolve_cut < EVOLVE_IMPACT:
		var k := evolve_cut / EVOLVE_IMPACT
		var gap := (1.0 - k * k * k) * 300.0
		PerkArt.draw_single(canvas, parents[0], center - Vector2(gap, 0.0), 78.0)
		PerkArt.draw_single(canvas, parents[1], center + Vector2(gap, 0.0), 78.0)
		soft_glow(center, Vector2.ONE * (200.0 + k * k * 500.0), Color(UI.GOLD, k * 0.6))
		return
	var since := evolve_cut - EVOLVE_IMPACT
	var pop := 1.0 + maxf(0.18 - since, 0.0) * 2.2
	var ray_fade := clampf(1.0 - since / 0.9, 0.0, 1.0) * fade
	for i in 12:
		var angle := i * TAU / 12.0 + time * 0.6
		var a := center + Vector2.from_angle(angle - 0.06) * 900.0
		var b := center + Vector2.from_angle(angle + 0.06) * 900.0
		canvas.draw_colored_polygon(PackedVector2Array([center, a, b]), Color(UI.GOLD, 0.28 * ray_fade))
	canvas.draw_arc(center, since * 1100.0, 0.0, TAU, 72, Color(1.0, 1.0, 1.0, ray_fade), 10.0, true)
	soft_glow(center, Vector2(900.0, 900.0), Color(UI.GOLD, 0.5 * fade))
	PerkArt.draw(canvas, evolve_id, center, 130.0 * pop, fade)
	text_center(center + Vector2(0.0, -210.0), t("evolution"), 34, Color(UI.GOLD, fade), font_label)
	var title := t("perk_" + evolve_id)
	text_shadowed(center + Vector2(0.0, 220.0), title, int(fit_size(title, 72, 640.0) * pop), Color(UI.GOLD, fade))
	var lines := t("perk_%s_desc" % evolve_id).split("\n")
	for i in lines.size():
		text_center(center + Vector2(0.0, 300.0 + i * 40.0), lines[i], fit_size(lines[i], 30, 620.0), Color(UI.TEXT, fade), font_body)


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


## Furniture is dark and flat, so it never reads as something to break.
func _draw_obstacles() -> void:
	for entry: Dictionary in sim.obstacles.values():
		_draw_obstacle(String(entry["kind"]), sim.cell_rect(entry["cell"]), float(entry["pulse"]), int(entry["dir"]))


func _draw_obstacle(kind: String, rect: Rect2, pulse: float, dir := 1) -> void:
	var edge := OBSTACLE_EDGE.lerp(Color.WHITE, pulse)
	var c := rect.get_center()
	match kind:
		"bumper":
			var r := GameSim.BUMPER_RADIUS + pulse * 7.0
			soft_glow(c, Vector2.ONE * (r * 3.0), Color(UI.STAR, 0.18 + pulse * 0.5))
			canvas.draw_circle(c, r, OBSTACLE_BODY)
			canvas.draw_arc(c, r, 0.0, TAU, 32, UI.STAR.lerp(Color.WHITE, pulse), 4.0, true)
			canvas.draw_circle(c, r * 0.36, UI.STAR.lerp(Color.WHITE, pulse))
		"ramp_l", "ramp_r":
			var points := sim.shape_points(rect, "slope_l" if kind == "ramp_l" else "slope_r")
			canvas.draw_colored_polygon(points, OBSTACLE_BODY)
			points.append(points[0])
			canvas.draw_polyline(points, edge, 3.0, true)
		"portal":
			var spin := time * 3.0
			soft_glow(c, Vector2.ONE * 110.0, Color(OBSTACLE_PORTAL, 0.4))
			canvas.draw_circle(c, GameSim.PORTAL_RADIUS, Color(UI.INK, 0.9))
			for i in 3:
				canvas.draw_arc(c, GameSim.PORTAL_RADIUS - i * 6.0, spin * (1.0 + i * 0.4) + i, spin * (1.0 + i * 0.4) + i + 4.2, 20, OBSTACLE_PORTAL, 3.0, true)
		_:
			panel(rect, OBSTACLE_BODY, 8.0, edge, 3)
			if kind == "mover":
				var sign_x := float(dir)
				for i in 2:
					var tip := c + Vector2(sign_x * (4.0 + i * 16.0), 0.0)
					canvas.draw_polyline(PackedVector2Array([tip + Vector2(-sign_x * 10.0, -10.0), tip, tip + Vector2(-sign_x * 10.0, 10.0)]), edge, 3.0, true)
			else:
				for corner_at in [rect.position + Vector2(10.0, 10.0), rect.end - Vector2(10.0, 10.0), Vector2(rect.end.x - 10.0, rect.position.y + 10.0), Vector2(rect.position.x + 10.0, rect.end.y - 10.0)]:
					canvas.draw_circle(corner_at, 3.0, edge)


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
		var shape: String = block.get("shape", "box")
		var body := _block_color(block).lerp(Color.WHITE, hit * 0.85)
		_draw_block_body(kind, drawn, body, _block_border(block), shape)
		if block.has("post"):
			_draw_block_outline(drawn, shape, Color("8be9fd"), 3.0)
		if int(block["poison"]) > 0:
			canvas.draw_circle(rect.get_center() + Vector2(-9.0, -rect.size.y * 0.22), 5.0, Color("2f9e44"))
		if block["burning"]:
			canvas.draw_circle(rect.get_center() + Vector2(9.0, -rect.size.y * 0.22), 5.0, Color("e8590c"))


## Base look of a block, shared with the codex. The body's colour belongs to its health,
## so a block's kind has to read from its border and its centre icon.
func _draw_block_body(kind: String, rect: Rect2, color: Color, border := Color.TRANSPARENT, shape := "box") -> void:
	if shape == "box":
		panel(rect, color, 14.0)
		panel(Rect2(rect.position + Vector2(4.0, 3.0), Vector2(rect.size.x - 8.0, rect.size.y * 0.4)), Color(1.0, 1.0, 1.0, 0.2), 10.0)
	elif shape == "round":
		var radius := minf(rect.size.x, rect.size.y) / 2.0
		canvas.draw_circle(rect.get_center(), radius, color)
		canvas.draw_circle(rect.get_center() + Vector2(-radius * 0.26, -radius * 0.3), radius * 0.42, Color(1.0, 1.0, 1.0, 0.22))
	else:
		var points := sim.shape_points(rect, shape)
		canvas.draw_colored_polygon(points, color)
		# A lighter inner copy, nudged upward, gives every shape the same soft bevel.
		var center := rect.get_center()
		var inner := PackedVector2Array()
		for p in points:
			inner.append(center + (p - center) * 0.62 + Vector2(0.0, -rect.size.y * 0.06))
		canvas.draw_colored_polygon(inner, Color(1.0, 1.0, 1.0, 0.16))
	if border.a > 0.0:
		_draw_block_outline(rect, shape, border, float(KIND_BORDER))
	var c := rect.get_center()
	match kind:
		"bomb":
			canvas.draw_circle(c + Vector2(-1.0, 2.0), 12.0, UI.INK)
			canvas.draw_line(c + Vector2(5.0, -7.0), c + Vector2(11.0, -14.0), UI.INK, 3.0)
		"shield":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -15.0), c + Vector2(13.0, -10.0), c + Vector2(11.0, 4.0), c + Vector2(0.0, 15.0), c + Vector2(-11.0, 4.0), c + Vector2(-13.0, -10.0)]), UI.INK)
		"armor":
			canvas.draw_rect(Rect2(c + Vector2(-13.0, -11.0), Vector2(26.0, 22.0)), UI.INK, false, 4.0)
			canvas.draw_line(c + Vector2(-13.0, 0.0), c + Vector2(13.0, 0.0), UI.INK, 3.0)
		"regen":
			canvas.draw_rect(Rect2(c + Vector2(-12.0, -4.0), Vector2(24.0, 8.0)), UI.INK)
			canvas.draw_rect(Rect2(c + Vector2(-4.0, -12.0), Vector2(8.0, 24.0)), UI.INK)
		"treasure":
			panel(Rect2(c + Vector2(-14.0, -11.0), Vector2(28.0, 22.0)), UI.INK, 5.0)
			canvas.draw_circle(c, 4.0, UI.GOLD)
		"breeder":
			canvas.draw_circle(c + Vector2(-7.0, 0.0), 8.0, UI.INK)
			canvas.draw_circle(c + Vector2(9.0, 0.0), 8.0, UI.INK)
		"extra_ball":
			canvas.draw_circle(c, 13.0, UI.INK)
			canvas.draw_circle(c, 8.0, Color.WHITE)


func _draw_block_outline(rect: Rect2, shape: String, color: Color, width: float) -> void:
	if shape == "box":
		panel(rect, Color.TRANSPARENT, 14.0, color, int(width))
	elif shape == "round":
		canvas.draw_arc(rect.get_center(), minf(rect.size.x, rect.size.y) / 2.0, 0.0, TAU, 32, color, width, true)
	else:
		var points := sim.shape_points(rect, shape)
		points.append(points[0])
		canvas.draw_polyline(points, color, width, true)


func draw_block_icon(kind: String, rect: Rect2) -> void:
	if kind == "boss":
		BossArt.draw(canvas, "purun", rect, "idle", time)
		return
	if kind in ["wall", "mover", "bumper", "ramp_l", "portal"]:
		_draw_obstacle(kind, rect, 0.0)
		return
	if kind in ["round", "hex", "diamond", "tri_up", "pill"]:
		_draw_block_body("normal", rect, UI.RAMP[1], Color.TRANSPARENT, kind)
		return
	if kind == "big":
		_draw_block_body("normal", rect.grow(4.0), UI.RAMP[3])
		return
	_draw_block_body(kind, rect, UI.RAMP[1], UI.BLOCKS.get(kind, Color.TRANSPARENT))


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


## Colour is the health readout: the hotter the block, the more it still takes to break.
func _block_color(block: Dictionary) -> Color:
	var size: Vector2i = block["size"]
	var top: float = float(GameSim.STAGES[sim.stage]["hp_max"]) * GameSim.Tiers.hp_scale(sim.tier) * size.x * size.y
	return UI.ramp(float(block["hp"]) / top)


func _block_border(block: Dictionary) -> Color:
	if block.has("tint"):
		return Bosses.color("purun")
	return UI.BLOCKS.get(block["kind"], Color.TRANSPARENT)


func _combo_color(combo: int) -> Color:
	return UI.ramp(fmod(combo * 0.018, 1.0))


func _ball_color() -> Color:
	return Color(String(Balls.BALLS[sim.ball_type]["color"]))


func _draw_balls() -> void:
	var base := _ball_color()
	var radius := sim.ball_radius
	var heated := base.lerp(_combo_color(sim.combo), minf(sim.combo / TRAIL_COLOR_FULL_COMBO, 0.5))
	for ball in sim.balls:
		var color: Color = heated.lerp(UI.STAR, 0.5) if ball.temp else heated
		canvas.draw_circle(ball.pos, radius, color)


func _draw_companion() -> void:
	if sim.stat("companion") <= 0.0:
		return
	var p := Vector2(sim.launch_x, GameSim.LAUNCH_Y) + Vector2(cos(time * 1.6) * 60.0, sin(time * 3.2) * 12.0 - 8.0)
	PerkArt.draw_glyph(canvas, "pal", p, 15.0, PerkArt.TAG_COLORS["swarm"])


func _draw_launcher() -> void:
	_draw_companion()
	if sim.state != GameSim.State.AIM:
		return
	var p := Vector2(sim.launch_x, GameSim.LAUNCH_Y)
	var color := _ball_color()
	var breathe := 1.0 + sin(time * 4.0) * 0.08
	soft_glow(p, Vector2(110.0, 110.0) * breathe, Color(color, 0.4))
	canvas.draw_circle(p, sim.ball_radius + 3.0, color)
	text_center(p + Vector2(0.0, 44.0), "x%d" % sim.shot_ball_count(), 26, UI.TEXT)
	if sim.guards > 0:
		for i in sim.guards:
			PerkArt.draw_glyph(canvas, "shield", Vector2(70.0 + i * 36.0, 1110.0), 14.0, UI.MINT)
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
	_draw_stage_pips(Vector2(46.0, 72.0))
	for i in sim.waves_left:
		panel(Rect2(40.0 + i * 26.0, 96.0, 18.0, 6.0), Color(UI.MINT, 0.8), 3.0)
	if sim.tier > 0:
		text_left(Vector2(40.0, 126.0), "T%d" % sim.tier, 22, UI.ACCENT)
	var coin_size := int(36.0 + coin_pop * 14.0)
	canvas.draw_circle(Vector2(575.0, 98.0), 13.0, UI.GOLD)
	text_center(Vector2(640.0, 98.0), I18n.format_number(sim.coins), coin_size, UI.GOLD)
	if sim.state == GameSim.State.SHOOT and sim.combo >= 5:
		_draw_combo()
	if sim.state in [GameSim.State.AIM, GameSim.State.SHOOT] and not sim.can_burst():
		_draw_burst_gauge()


## The run as a line of dots, with a diamond for each boss.
func _draw_stage_pips(start: Vector2) -> void:
	for i in GameSim.STAGES.size():
		var c := start + Vector2(i * STAGE_PIP_SPACING, 0.0)
		var color := UI.ACCENT if i == sim.stage else (UI.TEXT if i < sim.stage else Color(UI.MUTED, 0.3))
		if i == sim.stage:
			soft_glow(c, Vector2(44.0, 44.0), Color(UI.ACCENT, 0.5))
		if (GameSim.STAGES[i] as Dictionary).has("boss"):
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -10.0), c + Vector2(10.0, 0.0), c + Vector2(0.0, 10.0), c + Vector2(-10.0, 0.0)]), color)
		else:
			canvas.draw_circle(c, 6.0, color)


func _draw_burst_gauge() -> void:
	var bar := Rect2(170.0, 1250.0, 380.0, 12.0)
	panel(bar, Color(1.0, 1.0, 1.0, 0.1), 6.0)
	if sim.burst_charge > 0.0:
		var color: Color = UI.ramp(sim.burst_charge)
		var filled := Rect2(bar.position, Vector2(maxf(bar.size.x * sim.burst_charge, 12.0), bar.size.y))
		soft_glow(filled.end - Vector2(0.0, 6.0), Vector2(70.0, 70.0), Color(color, 0.5))
		panel(filled, color, 6.0)


## The combo counter grows, brightens and shifts color as the chain climbs.
func _draw_combo() -> void:
	var pop := 1.0 + combo_pop * 0.28
	var color := _combo_color(sim.combo)
	var center := Vector2(BASE_W / 2.0, 1170.0)
	var size := int(minf(58.0 + sim.combo * 0.35, 112.0) * pop)
	soft_glow(center, Vector2(620.0, 280.0), Color(color, clampf(0.12 + sim.combo * 0.003, 0.0, 0.45)))
	text_center(center, str(sim.combo), size, color)


func _draw_upgrade_screen() -> void:
	fill_screen(Color(UI.INK, 0.8))
	var clearing := sim.blocks.is_empty()
	var heading := t("stage_clear") if clearing else t("pick_start")
	var burst := 1.0 + maxf(0.25 - screen_age, 0.0) * 1.2
	soft_glow(Vector2(BASE_W / 2.0, 200.0), Vector2(860.0, 320.0), Color(UI.GOLD, 0.2 + sin(time * 3.0) * 0.05))
	text_center(Vector2(BASE_W / 2.0, 200.0), heading, int(fit_size(heading, 62, 640.0) * burst), UI.GOLD)
	var count := sim.choices.size()
	for i in count:
		# Cards rise in one after another.
		var appear := clampf((screen_age - i * 0.06) / 0.22, 0.0, 1.0)
		var ease_in := 1.0 - pow(1.0 - appear, 3.0)
		var rect := card_rect(i, count)
		rect.position.y += (1.0 - ease_in) * 70.0
		_draw_card(sim.choices[i], rect, ease_in)


## The one line that tells a card's place in the build: what it evolves from or into,
## or which part of the current build it feeds.
## One card reads left to right: what it is, what it does, and where it leads.
func _draw_card(id: String, rect: Rect2, alpha: float) -> void:
	var perk: Dictionary = Perks.PERKS[id]
	var color: Color = UI.RARITY[int(perk["rarity"])]
	var evolution := Perks.is_evolution(id)
	if evolution:
		var pulse := 0.5 + sin(time * 4.0) * 0.5
		soft_glow(rect.get_center(), rect.size * 1.5, Color(color, (0.2 + pulse * 0.25) * alpha))
	panel(rect, Color(UI.PANEL_SOLID, 0.96 * alpha), 30.0, Color(color, (0.9 if evolution else 0.45) * alpha), 3 if evolution else 2)
	var icon_size := minf(rect.size.y - 40.0, CARD_ICON_MAX)
	var icon_center := Vector2(rect.position.x + 24.0 + icon_size / 2.0, rect.get_center().y)
	var build_color := PerkArt.color_of(id)
	var feeds_build := _feeds_build(id)
	panel(Rect2(icon_center - Vector2.ONE * icon_size / 2.0, Vector2.ONE * icon_size), Color(build_color, 0.14 * alpha), icon_size * 0.24, Color(UI.MINT if feeds_build else build_color, (1.0 if feeds_build else 0.45) * alpha), 3 if feeds_build else 2)
	PerkArt.draw(canvas, id, icon_center, icon_size * 0.36, alpha)
	var path: Dictionary = {} if evolution else sim.evolution_hint(id)
	var text_x := icon_center.x + icon_size / 2.0 + 22.0
	var text_width := rect.end.x - text_x - (CARD_PATH_WIDTH if not path.is_empty() else 24.0)
	var middle := rect.get_center().y
	var name_text := t("perk_" + id)
	text_left(Vector2(text_x, middle - 24.0), name_text, fit_size(name_text, 40, text_width), Color(color, alpha))
	var desc := t("perk_%s_desc" % id)
	text_left(Vector2(text_x, middle + 22.0), desc, fit_size(desc, 25, text_width), Color(UI.TEXT, 0.82 * alpha), font_body)
	_draw_level_pips(id, Vector2(text_x + 4.0, middle + 54.0), alpha)
	if not path.is_empty():
		_draw_card_path(path, Vector2(rect.end.x - CARD_PATH_WIDTH / 2.0, middle), alpha)


func _draw_route_screen() -> void:
	fill_screen(Color(UI.INK, 0.86))
	text_center(Vector2(BASE_W / 2.0, 200.0), t("route_title"), 56, UI.TEXT)
	var count := sim.route_options.size()
	for i in count:
		var id := sim.route_options[i]
		var data: Dictionary = RunContent.ROUTES[id]
		_draw_option_card(card_rect(i, count), data["glyph"], t("route_" + id), t("route_%s_desc" % id), Color(String(data["color"])), _card_alpha(i))


func _card_alpha(index: int) -> float:
	return 1.0 - pow(1.0 - clampf((screen_age - index * 0.06) / 0.22, 0.0, 1.0), 3.0)


func _draw_event_screen() -> void:
	fill_screen(Color(UI.INK, 0.86))
	var kind: String = sim.event["kind"]
	var heading := t("event_" + kind)
	if kind == "shrine":
		heading = t("shrine_%s_title" % String(sim.event["shrine"]))
	text_center(Vector2(BASE_W / 2.0, 200.0), heading, fit_size(heading, 54, 640.0), UI.TEXT)
	var options: Array = sim.event["options"]
	for i in options.size():
		var option: Dictionary = options[i]
		var rect := card_rect(i, options.size())
		var alpha := _card_alpha(i)
		if option.has("perk"):
			_draw_card(option["perk"], rect, alpha)
			if option.has("cost"):
				var affordable: bool = int(option["cost"]) <= sim.coins
				text_right(Vector2(rect.end.x - 24.0, rect.position.y + 30.0), I18n.format_number(option["cost"]), 28, Color(UI.GOLD if affordable else UI.DANGER, alpha))
		elif option.has("relic"):
			var data: Dictionary = RunContent.RELICS[option["relic"]]
			_draw_option_card(rect, data["glyph"], t("relic_" + String(option["relic"])), t("relic_%s_desc" % String(option["relic"])), UI.GOLD, alpha)
		else:
			var key := "shrine_%s_%s" % [String(option["shrine"]), String(option["choice"])]
			_draw_option_card(rect, "crown", t(key), t(key + "_desc"), UI.STAR, alpha)


func _draw_option_card(rect: Rect2, glyph: String, title: String, desc: String, color: Color, alpha: float) -> void:
	panel(rect, Color(UI.PANEL_SOLID, 0.96 * alpha), 30.0, Color(color, 0.55 * alpha), 2)
	var icon_size := minf(rect.size.y - 40.0, CARD_ICON_MAX)
	var icon_center := Vector2(rect.position.x + 24.0 + icon_size / 2.0, rect.get_center().y)
	panel(Rect2(icon_center - Vector2.ONE * icon_size / 2.0, Vector2.ONE * icon_size), Color(color, 0.14 * alpha), icon_size * 0.24, Color(color, 0.5 * alpha), 2)
	PerkArt.draw_glyph(canvas, glyph, icon_center, icon_size * 0.36, Color(color, alpha))
	var text_x := icon_center.x + icon_size / 2.0 + 22.0
	var text_width := rect.end.x - text_x - 24.0
	text_left(Vector2(text_x, rect.get_center().y - 24.0), title, fit_size(title, 40, text_width), Color(color, alpha))
	text_left(Vector2(text_x, rect.get_center().y + 22.0), desc, fit_size(desc, 25, text_width), Color(UI.TEXT, 0.82 * alpha), font_body)


func _draw_missions(start: Vector2) -> void:
	for i in sim.missions.size():
		var mission: Dictionary = sim.missions[i]
		var y := start.y + i * 50.0
		var line := t("mission_" + String(mission["stat"])) % int(mission["target"])
		var done: bool = mission["done"]
		text_left(Vector2(start.x, y), line, fit_size(line, 24, 500.0), UI.MINT if done else UI.TEXT, font_body)
		var bar := Rect2(start.x, y + 20.0, 500.0, 6.0)
		panel(bar, Color(1.0, 1.0, 1.0, 0.08), 3.0)
		var progress := sim.mission_progress(mission)
		if progress > 0.0:
			panel(Rect2(bar.position, Vector2(maxf(bar.size.x * progress, 6.0), bar.size.y)), UI.MINT if done else UI.ACCENT, 3.0)


func _feeds_build(id: String) -> bool:
	var owned := sim.tag_levels()
	for tag in Perks.tags_of(id):
		if int(owned.get(tag, 0)) > 0:
			return true
	return false


func _draw_level_pips(id: String, start: Vector2, alpha: float) -> void:
	var level: int = sim.levels[id]
	if level <= 0:
		return
	for i in int(Perks.PERKS[id]["max"]):
		canvas.draw_circle(start + Vector2(i * 16.0, 0.0), 5.0, Color(UI.GOLD if i < level else UI.MUTED, (1.0 if i < level else 0.3) * alpha))


## Where this card leads: the evolution lights up once taking it would open it, and until
## then the partner it still needs waits here. The full recipe lives in the codex.
func _draw_card_path(path: Dictionary, center: Vector2, alpha: float) -> void:
	if path.get("ready", false):
		var pulse := 0.5 + sin(time * 5.0) * 0.5
		soft_glow(center, Vector2(130.0, 130.0), Color(UI.GOLD, (0.3 + pulse * 0.4) * alpha))
		canvas.draw_arc(center, 40.0, 0.0, TAU, 40, Color(UI.GOLD, alpha), 3.0, true)
		PerkArt.draw(canvas, path["evolution"], center, 28.0, alpha)
		return
	text_center(center + Vector2(-34.0, 0.0), "+", 26, Color(UI.MUTED, alpha))
	PerkArt.draw(canvas, path["partner"], center + Vector2(4.0, 0.0), 26.0, 0.7 * alpha)


## The run's build: its strongest leanings on one line, then every owned perk as a chip.
func _draw_build(top: float, max_rows: int) -> void:
	var owned: Array[String] = []
	for id in Perks.ids():
		if int(sim.levels[id]) > 0:
			owned.append(id)
	# Evolutions lead, since they are the payoff of the whole build.
	owned.sort_custom(func(a: String, b: String) -> bool:
		var a_evo := Perks.is_evolution(a)
		if a_evo != Perks.is_evolution(b):
			return a_evo
		return int(sim.levels[a]) > int(sim.levels[b]))
	var per_row := int((BASE_W - 100.0 + BUILD_GAP) / (BUILD_TILE + BUILD_GAP))
	# Relics show first: they are what makes this run unlike the others.
	for relic in sim.relics:
		owned.insert(0, relic)
	var shown := mini(owned.size(), per_row * max_rows)
	for i in shown:
		var row_index := i / per_row
		var in_row := mini(shown - row_index * per_row, per_row)
		var left := (BASE_W - in_row * (BUILD_TILE + BUILD_GAP) + BUILD_GAP) / 2.0
		var tile := Rect2(left + (i % per_row) * (BUILD_TILE + BUILD_GAP), top + row_index * (BUILD_TILE + BUILD_GAP), BUILD_TILE, BUILD_TILE)
		if RunContent.RELICS.has(owned[i]):
			panel(tile, Color(UI.GOLD, 0.16), 14.0, UI.GOLD, 2)
			PerkArt.draw_glyph(canvas, RunContent.RELICS[owned[i]]["glyph"], tile.get_center(), 18.0, UI.GOLD)
			continue
		var color: Color = PerkArt.color_of(owned[i])
		var evolved := Perks.is_evolution(owned[i])
		panel(tile, Color(color, 0.12), 14.0, UI.GOLD if evolved else Color(color, 0.35), 2)
		PerkArt.draw(canvas, owned[i], tile.get_center(), 18.0)


func card_rect(index: int, count: int) -> Rect2:
	var top := 305.0
	var area := 785.0
	var gap := 16.0
	var height := minf((area - gap * (count - 1)) / count, 235.0)
	return Rect2(70.0, top + index * (height + gap), 580.0, height)


func _draw_end_screen(title: String, color: Color) -> void:
	fill_screen(Color(UI.INK, 0.9))
	var pop := 1.0 + maxf(0.3 - screen_age, 0.0) * 1.2
	soft_glow(Vector2(BASE_W / 2.0, 130.0), Vector2(860.0, 280.0), Color(color, 0.2))
	text_center(Vector2(BASE_W / 2.0, 130.0), title, int(fit_size(title, 60, 640.0) * pop), color)
	var cause := _defeat_line()
	if cause != "":
		text_center(Vector2(BASE_W / 2.0, 186.0), cause, fit_size(cause, 24, 620.0), UI.MUTED, font_body)
	_draw_run_rank(Vector2(BASE_W / 2.0, 330.0))
	if run_new_record:
		text_center(Vector2(BASE_W / 2.0, 446.0), t("new_record"), fit_size(t("new_record"), 24, 500.0), UI.GOLD)
	text_right(Vector2(BASE_W / 2.0 - 28.0, 508.0), I18n.format_number(_counted(sim.total_damage)), 46, UI.TEXT)
	var coin_text := "+" + I18n.format_number(_counted(sim.coins))
	canvas.draw_circle(Vector2(BASE_W / 2.0 + 44.0, 508.0), 15.0, UI.GOLD)
	text_left(Vector2(BASE_W / 2.0 + 70.0, 508.0), coin_text, 46, UI.GOLD)
	_draw_stage_pips(Vector2(BASE_W / 2.0 - (GameSim.STAGES.size() - 1) * STAGE_PIP_SPACING / 2.0, 568.0))
	_draw_next_unlock(Rect2(110.0, 610.0, 500.0, 70.0))
	_draw_build(708.0, 3)


## The grade is the hero of the screen, and lands as the numbers finish counting.
func _draw_run_rank(center: Vector2) -> void:
	var since := end_age - COUNT_UP_SECONDS
	if since < 0.0:
		return
	var rank := sim.run_rank()
	var color: Color = RANK_COLORS[rank]
	var pop := 1.0 + maxf(0.16 - since, 0.0) * 5.0
	soft_glow(center, Vector2(520.0, 400.0), Color(color, 0.45))
	text_shadowed(center, GameSim.RANKS[rank], int(fit_size(GameSim.RANKS[rank], 170, 460.0) * pop), color)


## Only a boss needs saying: blocks reaching the line is plain from the field itself.
func _defeat_line() -> String:
	if sim.state != GameSim.State.LOST or sim.boss_block == null:
		return ""
	var boss: Dictionary = sim.boss_block
	var percent := ceili(100.0 * float(boss["hp"]) / maxf(float(boss["max_hp"]), 1.0))
	return t("defeat_boss") % [t("boss_%s_name" % sim.boss_id()), percent]


func _draw_next_unlock(box: Rect2) -> void:
	var goal := save.next_unlock()
	if goal.is_empty():
		return
	var reward := t("perk_" + String(goal["perk"])) if goal["perk"] != "" else t("ball_" + String(goal["ball"]))
	var progress: float = goal["progress"]
	text_left(box.position + Vector2(0.0, 16.0), t("next_unlock"), 18, UI.MUTED, font_label)
	text_right(Vector2(box.end.x, box.position.y + 16.0), reward, fit_size(reward, 24, 330.0), UI.MINT)
	var bar := Rect2(box.position + Vector2(0.0, 40.0), Vector2(box.size.x, 8.0))
	panel(bar, Color(1.0, 1.0, 1.0, 0.08), 4.0)
	if progress > 0.0:
		panel(Rect2(bar.position, Vector2(maxf(bar.size.x * progress, 8.0), bar.size.y)), UI.MINT, 4.0)


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
