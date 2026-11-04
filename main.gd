extends Node2D
## App flow, input, the game screen, effects and sound.
## Rules live in sim/game_sim.gd and other screens in menus.gd.

const GameSim := preload("res://sim/game_sim.gd")
const I18n := preload("res://i18n.gd")
const SaveData := preload("res://save_data.gd")
const Menus := preload("res://menus.gd")
const Verify := preload("res://verify.gd")
const Perks := preload("res://data/perks.gd")
const Balls := preload("res://data/balls.gd")
const Achievements := preload("res://data/achievements.gd")
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

var sim: GameSim
var save: SaveData
var menus: Menus
var verifier: Verify
var screen: int = Menus.Screen.TITLE
var settings_return: int = Menus.Screen.TITLE
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
	sim = GameSim.new()
	if verify_dir != "":
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
		save.save_file()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_request()


func _on_back_request() -> void:
	match screen:
		Menus.Screen.TITLE:
			get_tree().quit()
		Menus.Screen.SETTINGS:
			_set_screen(settings_return)
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
	_set_screen(Menus.Screen.GAME)


## Records stats once per run, including runs the player abandons from the pause menu.
func _bank_run() -> void:
	if run_banked:
		return
	run_banked = true
	if sim.total_damage == 0:
		return
	run_new_record = save.record_run({
		"damage": sim.total_damage,
		"combo": sim.best_combo,
		"best_shot": sim.best_shot_damage,
		"stage": sim.stage + 1,
		"coins": sim.coins,
		"won": sim.state == GameSim.State.WON,
		"tier": sim.tier,
		"ball_type": sim.ball_type,
		"counters": sim.counters,
	})
	on_progress_changed()


## Checks achievements against saved totals plus the run in progress, then saves.
func on_progress_changed(live := {}) -> void:
	_announce(save.check_achievements(live))
	save.save_file()


func on_shop_bought() -> void:
	_play("coin", 1.2)
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
	AudioServer.set_bus_mute(0, not save.sound)


func _process(delta: float) -> void:
	time += delta
	var view := get_viewport_rect().size
	y_offset = maxf((view.y - BASE_H) / 2.0, 0.0)
	screen_age += delta
	if screen == Menus.Screen.GAME and not paused:
		_process_game(delta)
	_update_fx(delta)
	var shake := trauma * trauma * 24.0
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
	impact_material.set_shader_parameter("amount", impact)
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


func _note_offered_perks() -> void:
	if sim.choices == seen_choices:
		return
	seen_choices = sim.choices.duplicate()
	for id in seen_choices:
		save.mark_perk_seen(id)
	if not seen_choices.is_empty():
		on_progress_changed(_live_stats())


func _input(event: InputEvent) -> void:
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
	if screen != Menus.Screen.GAME or paused or burst_windup >= 0.0:
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
		GameSim.State.WON, GameSim.State.LOST:
			if screen_age >= ACCEPT_INPUT_AFTER:
				_play("pick", 1.0)
				_start_run()


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
			_set_screen(Menus.Screen.SHOP)
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
			_set_screen(settings_return if screen == Menus.Screen.SETTINGS else Menus.Screen.TITLE)
		"lang_ja", "lang_en":
			save.lang = id.trim_prefix("lang_")
			save.save_file()
		"sound":
			save.sound = not save.sound
			_apply_sound()
			save.save_file()
		"vibration":
			save.vibration = not save.vibration
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
	if burst_windup >= 0.0:
		return list
	if paused:
		list.append(_button("resume", Rect2(110.0, 430.0, 500.0, 120.0), t("resume"), "primary"))
		list.append(_button("settings", Rect2(110.0, 570.0, 500.0, 100.0), t("settings")))
		list.append(_button("restart", Rect2(110.0, 690.0, 500.0, 100.0), t("restart")))
		list.append(_button("to_title", Rect2(110.0, 810.0, 500.0, 100.0), t("to_title")))
	elif is_run_over():
		list.append(_button("to_title", Rect2(160.0, 1080.0, 400.0, 100.0), t("to_title")))
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
					_show_banner(t("boss_banner"), 1.3)
					trauma = 0.8
					_play("lose", 0.8)
				else:
					_show_banner(t("stage_banner") % (int(e["stage"]) + 1), 1.0)
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
	_spawn_particles(e["pos"], color, 70 if is_boss else 16, 900.0 if is_boss else 420.0)
	_spawn_particles(e["pos"], Color.WHITE, 30 if is_boss else 6, 600.0 if is_boss else 280.0)
	trauma = minf(trauma + (1.0 if is_boss else 0.12), 1.0)
	hitstop = maxf(hitstop, 0.15 if is_boss else 0.012)
	if is_boss:
		screen_flash = 1.0
		impact = 0.03
		_play("boom", 0.6)
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
	_draw_blocks()
	_draw_balls()
	_draw_launcher()
	if (aiming or hovering) and sim.state == GameSim.State.AIM and not paused:
		_draw_aim()


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
			_glow_sprite(sim.block_rect(block).get_center(), 420.0, Color(UI.ACCENT, 0.3 + sin(time * 3.0) * 0.08))
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
		fill_screen(Color(1.0, 0.96, 0.9, screen_flash * 0.32))
	match sim.state:
		GameSim.State.UPGRADE:
			_draw_upgrade_screen()
		GameSim.State.WON:
			_draw_end_screen(t("you_win"), UI.GOLD)
		GameSim.State.LOST:
			_draw_end_screen(t("game_over"), UI.ACCENT)
	if banner_time > 0.0 and sim.state != GameSim.State.UPGRADE and not paused:
		var pop := 1.0 + clampf(banner_time - 0.75, 0.0, 0.25) * 1.6
		var alpha := minf(banner_time * 3.0, 1.0)
		soft_glow(Vector2(BASE_W / 2.0, 610.0), Vector2(900.0, 340.0), Color(UI.ACCENT, 0.3 * alpha))
		var size := fit_size(banner_text, int(84.0 * pop), 660.0)
		text_shadowed(Vector2(BASE_W / 2.0, 610.0), banner_text, size, Color(1.0, 1.0, 1.0, alpha))
	if burst_windup >= 0.0:
		_draw_burst_cut_in()
	if paused:
		fill_screen(Color(UI.INK, 0.82))
		text_center(Vector2(BASE_W / 2.0, 310.0), t("paused"), 76, UI.TEXT)


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
		rect.position.y += slide
		var kind: String = block["kind"]
		if kind == "boss":
			_draw_boss(block, rect)
			continue
		var hit: float = clampf(float(flash.get(block["id"], 0.0)), 0.0, 1.0)
		# A struck block swells for a moment, so every hit has weight.
		var drawn := rect.grow(hit * 3.0)
		_draw_block_body(kind, drawn, _block_color(block))
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
		panel(rect, UI.BLOCKS["boss"], 14.0)
		_draw_boss_face(rect)
		return
	_draw_block_body(kind, rect, UI.BLOCKS.get(kind, UI.RAMP[1]))


func _draw_boss(block: Dictionary, rect: Rect2) -> void:
	var ratio := clampf(float(block["hp"]) / float(block["max_hp"]), 0.0, 1.0)
	var color: Color = UI.BLOCKS["boss"]
	if ratio < 0.5:
		color = color.lerp(Color("ff6b35"), 0.45 + sin(time * 9.0) * 0.3)
	panel(rect, color, 22.0, Color(1.0, 1.0, 1.0, 0.25), 3)
	panel(Rect2(rect.position + Vector2(8.0, 6.0), Vector2(rect.size.x - 16.0, rect.size.y * 0.3)), Color(1.0, 1.0, 1.0, 0.1), 14.0)
	_draw_boss_face(rect)
	var hit: float = clampf(float(flash.get(block["id"], 0.0)), 0.0, 1.0)
	if hit > 0.0:
		panel(rect, Color(1.0, 1.0, 1.0, hit * 0.55), 22.0)
	var bar := Rect2(rect.position + Vector2(18.0, rect.size.y - 26.0), Vector2(rect.size.x - 36.0, 12.0))
	panel(bar, Color(0.0, 0.0, 0.0, 0.4), 6.0)
	panel(Rect2(bar.position, Vector2(maxf(bar.size.x * ratio, 12.0), bar.size.y)), UI.GOLD, 6.0)
	text_center(rect.get_center() + Vector2(0.0, 8.0), I18n.format_number(block["hp"]), 30, Color.WHITE)


func _draw_boss_face(rect: Rect2) -> void:
	var c := rect.get_center()
	var eye := rect.size.x * 0.2
	var r := minf(rect.size.y * 0.13, 11.0)
	var y := -rect.size.y * 0.25
	canvas.draw_circle(c + Vector2(-eye, y), r, Color.WHITE)
	canvas.draw_circle(c + Vector2(eye, y), r, Color.WHITE)
	canvas.draw_circle(c + Vector2(-eye, y), r * 0.5, UI.INK)
	canvas.draw_circle(c + Vector2(eye, y), r * 0.5, UI.INK)


func _block_color(block: Dictionary) -> Color:
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
		var perk: Dictionary = Perks.PERKS[id]
		var color: Color = UI.RARITY[int(perk["rarity"])]
		var evolution := Perks.is_evolution(id)
		if evolution:
			var pulse := 0.5 + sin(time * 4.0) * 0.5
			soft_glow(rect.get_center(), rect.size * 1.5, Color(color, (0.2 + pulse * 0.25) * ease_in))
		panel(rect, Color(UI.PANEL_SOLID, 0.96 * ease_in), 30.0, Color(color, (0.9 if evolution else 0.45) * ease_in), 3 if evolution else 2)
		panel(Rect2(rect.position + Vector2(rect.size.x * 0.35, -2.0), Vector2(rect.size.x * 0.3, 5.0)), Color(color, ease_in), 2.5)
		var label := t("evolution") if evolution else t("rarity_%d" % int(perk["rarity"]))
		text_center(rect.position + Vector2(rect.size.x / 2.0, 30.0), label, 16, Color(color, ease_in), font_label)
		var level: int = sim.levels[id]
		if level > 0:
			text_right(rect.position + Vector2(rect.size.x - 28.0, 30.0), t("level") % level, 19, Color(UI.MUTED, ease_in), font_body)
		var name_text := t("perk_" + id)
		text_center(rect.position + Vector2(rect.size.x / 2.0, rect.size.y * 0.38), name_text, fit_size(name_text, 42, rect.size.x - 60.0), Color(color, ease_in))
		var lines := t("perk_%s_desc" % id).split("\n")
		var line_y := rect.size.y * (0.64 if lines.size() > 1 else 0.7)
		for l in lines.size():
			text_center(rect.position + Vector2(rect.size.x / 2.0, line_y + l * 34.0), lines[l], fit_size(lines[l], 25, rect.size.x - 60.0), Color(UI.MUTED, ease_in), font_body)


func card_rect(index: int, count: int) -> Rect2:
	var top := 305.0
	var area := 785.0
	var gap := 16.0
	var height := minf((area - gap * (count - 1)) / count, 235.0)
	return Rect2(70.0, top + index * (height + gap), 580.0, height)


func _draw_end_screen(title: String, color: Color) -> void:
	fill_screen(Color(UI.INK, 0.86))
	var pop := 1.0 + maxf(0.3 - screen_age, 0.0) * 1.2
	soft_glow(Vector2(BASE_W / 2.0, 210.0), Vector2(860.0, 360.0), Color(color, 0.22))
	text_center(Vector2(BASE_W / 2.0, 210.0), title, int(fit_size(title, 76, 640.0) * pop), color)
	if run_new_record:
		var chip := Rect2(BASE_W / 2.0 - 170.0, 275.0, 340.0, 56.0)
		panel(chip, Color(UI.GOLD, 0.14 + sin(time * 5.0) * 0.05), 28.0, UI.GOLD, 2)
		text_center(chip.get_center(), t("new_record"), fit_size(t("new_record"), 28, 310.0), UI.GOLD)
	text_center(Vector2(BASE_W / 2.0, 380.0), t("total_damage"), 20, UI.MUTED, font_label)
	text_center(Vector2(BASE_W / 2.0, 445.0), I18n.format_number(sim.total_damage), 84, UI.TEXT)
	panel(Rect2(70.0, 510.0, 580.0, 320.0), UI.PANEL, 30.0, UI.LINE, 2)
	var seconds := int(run_seconds)
	var rows := [
		["best_shot", I18n.format_number(sim.best_shot_damage)],
		["best_combo", str(sim.best_combo)],
		["coins", I18n.format_number(sim.coins)],
		["reached", "%d / %d" % [sim.stage + 1, GameSim.STAGES.size()]],
		["play_time", "%d:%02d" % [seconds / 60, seconds % 60]],
	]
	for i in rows.size():
		row(Vector2(105.0, 553.0 + i * 58.0), 510.0, t(rows[i][0]), rows[i][1], 29, UI.TEXT)
	var alpha := 0.6 + sin(time * 4.5) * 0.4
	text_center(Vector2(BASE_W / 2.0, 950.0), t("tap_retry"), 44, Color(UI.TEXT, alpha))


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
