extends Node2D
## Screens, input, drawing, effects and sound. Game rules live in sim/game_sim.gd.

const GameSim := preload("res://sim/game_sim.gd")
const I18n := preload("res://i18n.gd")
const SaveData := preload("res://save_data.gd")

enum Screen { TITLE, HOWTO, SETTINGS, GAME }

const BASE_H := 1280.0
const BASE_W := 720.0
const MIN_PULL := 30.0
const ACCEPT_INPUT_AFTER := 0.3
const COLOR_BG := Color("14122b")
const COLOR_FIELD := Color("1c1a3d")
const COLOR_BOMB := Color("ff8c1a")
const COLOR_COIN := Color("ffd84d")
const COLOR_LABEL := Color("9a96d8")
const COLOR_BUTTON := Color("2c2860")
const COLOR_ACCENT := Color("ff5c7a")
const FONT_NAMES := ["Hiragino Sans", "Hiragino Kaku Gothic ProN", "Noto Sans CJK JP", "Noto Sans JP", "sans-serif"]
const SAMPLE_RATE := 22050

var sim: GameSim
var save: SaveData
var screen: int = Screen.TITLE
var settings_return: int = Screen.TITLE
var paused := false
var run_banked := true
var run_seconds := 0.0
var run_new_record := false
var y_offset := 0.0
var time := 0.0
var screen_age := 0.0
var last_state := -1

var aiming := false
var aim_start := Vector2.ZERO
var aim_current := Vector2.ZERO

var hitstop := 0.0
var trauma := 0.0
var descend_anim := 0.0
var flash := {}
var particles: Array[Dictionary] = []
var numbers: Array[Dictionary] = []
var fly_coins: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var banner_text := ""
var banner_time := 0.0
var combo_pop := 0.0
var coin_pop := 0.0
var screen_flash := 0.0
var last_boom_stop := 0.0
var last_hit_sound := 0.0
var next_milestone := 25

var font: Font
var sounds := {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var verify_stats := {"max_balls": 0, "explosions": 0, "splits": 0}


func _ready() -> void:
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(FONT_NAMES)
	system_font.font_weight = 700
	font = system_font
	RenderingServer.set_default_clear_color(COLOR_BG)
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
	_apply_sound()
	sim = GameSim.new()
	if verify_dir != "":
		_run_verify(verify_dir)


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
		Screen.TITLE:
			get_tree().quit()
		Screen.HOWTO:
			_set_screen(Screen.TITLE)
		Screen.SETTINGS:
			_set_screen(settings_return)
		Screen.GAME:
			if paused:
				_set_paused(false)
			elif _can_pause():
				_set_paused(true)


func _t(key: String) -> String:
	return I18n.text(save.lang, key)


func _set_screen(next: int) -> void:
	screen = next
	screen_age = 0.0
	aiming = false


func _set_paused(value: bool) -> void:
	paused = value
	screen_age = 0.0
	aiming = false


func _can_pause() -> bool:
	return screen == Screen.GAME and not paused and sim.state in [GameSim.State.AIM, GameSim.State.SHOOT]


func _is_run_over() -> bool:
	return sim.state == GameSim.State.WON or sim.state == GameSim.State.LOST


func _start_run() -> void:
	_bank_run()
	sim.new_run(randi())
	run_banked = false
	run_seconds = 0.0
	run_new_record = false
	paused = false
	aiming = false
	particles.clear()
	numbers.clear()
	fly_coins.clear()
	rings.clear()
	flash.clear()
	banner_time = 0.0
	screen_flash = 0.0
	next_milestone = 25
	last_state = -1
	_set_screen(Screen.GAME)


## Records stats once per run, including runs the player abandons from the pause menu.
func _bank_run() -> void:
	if run_banked:
		return
	run_banked = true
	if sim.total_damage == 0:
		return
	run_new_record = save.record_run(sim.total_damage, sim.best_combo, sim.stage + 1, sim.coins, sim.state == GameSim.State.WON)
	save.save_file()


func _apply_sound() -> void:
	AudioServer.set_bus_mute(0, not save.sound)


func _process(delta: float) -> void:
	time += delta
	var view := get_viewport_rect().size
	y_offset = maxf((view.y - BASE_H) / 2.0, 0.0)
	screen_age += delta
	if screen == Screen.GAME and not paused:
		_process_game(delta)
	_update_fx(delta)
	var shake := trauma * trauma * 26.0
	position = Vector2(randf_range(-shake, shake), y_offset + randf_range(-shake, shake))
	queue_redraw()


func _process_game(delta: float) -> void:
	if sim.state != last_state:
		last_state = sim.state
		screen_age = 0.0
	if not _is_run_over():
		run_seconds += delta
	if hitstop > 0.0:
		hitstop -= delta
	else:
		sim.step(delta)
	verify_stats["max_balls"] = max(int(verify_stats["max_balls"]), sim.balls.size())
	_consume_events()
	if _is_run_over():
		_bank_run()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.index == 0:
		var p: Vector2 = event.position - Vector2(0.0, y_offset)
		if event.pressed:
			_on_press(p)
		else:
			_on_release(p)
	elif event is InputEventScreenDrag and event.index == 0 and aiming:
		aim_current = event.position - Vector2(0.0, y_offset)


func _on_press(p: Vector2) -> void:
	for button in _current_buttons():
		if (button["rect"] as Rect2).has_point(p):
			if screen_age >= ACCEPT_INPUT_AFTER or button["id"] == "pause":
				_play("pick", 1.0)
				_press_button(String(button["id"]))
			return
	if screen != Screen.GAME or paused:
		return
	match sim.state:
		GameSim.State.AIM:
			aiming = true
			aim_start = p
			aim_current = p
		GameSim.State.UPGRADE:
			if screen_age < ACCEPT_INPUT_AFTER:
				return
			for i in sim.choices.size():
				if _card_rect(i).has_point(p):
					_play("pick", 1.0)
					sim.choose_upgrade(sim.choices[i])
					return
		GameSim.State.WON, GameSim.State.LOST:
			if screen_age >= ACCEPT_INPUT_AFTER:
				_play("pick", 1.0)
				_start_run()


func _on_release(p: Vector2) -> void:
	if not aiming:
		return
	aiming = false
	var pull := aim_start - p
	if sim.state == GameSim.State.AIM and pull.length() >= MIN_PULL and pull.y < 0.0:
		if not save.tutorial_done:
			save.tutorial_done = true
			save.save_file()
		sim.fire(pull)


func _press_button(id: String) -> void:
	match id:
		"start", "restart":
			_start_run()
		"howto":
			_set_screen(Screen.HOWTO)
		"settings":
			settings_return = screen
			_set_screen(Screen.SETTINGS)
		"back":
			_set_screen(settings_return if screen == Screen.SETTINGS else Screen.TITLE)
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
		"to_title":
			_bank_run()
			paused = false
			_set_screen(Screen.TITLE)


## One list drives both drawing and hit tests, so they can never disagree.
func _current_buttons() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	match screen:
		Screen.TITLE:
			list.append(_button("start", Rect2(110.0, 710.0, 500.0, 130.0), _t("start"), "primary"))
			list.append(_button("howto", Rect2(110.0, 860.0, 500.0, 100.0), _t("howto")))
			list.append(_button("settings", Rect2(110.0, 980.0, 500.0, 100.0), _t("settings")))
		Screen.HOWTO:
			list.append(_button("back", Rect2(110.0, 1040.0, 500.0, 110.0), _t("back")))
		Screen.SETTINGS:
			list.append(_button("lang_ja", Rect2(70.0, 340.0, 280.0, 100.0), "日本語", "selected" if save.lang == "ja" else "normal"))
			list.append(_button("lang_en", Rect2(370.0, 340.0, 280.0, 100.0), "English", "selected" if save.lang == "en" else "normal"))
			list.append(_button("sound", Rect2(70.0, 490.0, 580.0, 100.0), "%s : %s" % [_t("sound"), _t("on" if save.sound else "off")]))
			list.append(_button("vibration", Rect2(70.0, 610.0, 580.0, 100.0), "%s : %s" % [_t("vibration"), _t("on" if save.vibration else "off")]))
			list.append(_button("back", Rect2(110.0, 1040.0, 500.0, 110.0), _t("back")))
		Screen.GAME:
			if paused:
				list.append(_button("resume", Rect2(110.0, 430.0, 500.0, 120.0), _t("resume"), "primary"))
				list.append(_button("settings", Rect2(110.0, 570.0, 500.0, 100.0), _t("settings")))
				list.append(_button("restart", Rect2(110.0, 690.0, 500.0, 100.0), _t("restart")))
				list.append(_button("to_title", Rect2(110.0, 810.0, 500.0, 100.0), _t("to_title")))
			elif _is_run_over():
				list.append(_button("to_title", Rect2(160.0, 1080.0, 400.0, 100.0), _t("to_title")))
			elif sim.state != GameSim.State.UPGRADE:
				list.append(_button("pause", Rect2(628.0, 4.0, 88.0, 62.0), "", "icon"))
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
				_spawn_particles(e["pos"], Color("7f7ac9"), 2, 90.0)
			"descend":
				descend_anim = 1.0
			"stage_start":
				banner_text = _t("stage_banner") % (int(e["stage"]) + 1)
				banner_time = 1.0
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


func _on_hit(e: Dictionary) -> void:
	flash[e["cell"]] = 1.0
	var combo: int = e["combo"]
	if numbers.size() < 70:
		numbers.append({
			"pos": e["pos"] + Vector2(randf_range(-18.0, 18.0), -10.0),
			"text": str(e["damage"]),
			"t": 0.0,
			"big": int(e["damage"]) >= 5,
		})
	_spawn_particles(e["pos"], _block_color_for_combo(combo), 2, 150.0)
	combo_pop = 1.0
	if time - last_hit_sound > 0.03:
		last_hit_sound = time
		# Climb a pentatonic scale with the combo so long chains audibly rise.
		var scale_steps := [0, 2, 4, 7, 9]
		var octave := mini(combo / 5, 3)
		var semitones: int = scale_steps[combo % 5] + octave * 12
		_play("hit", pow(2.0, semitones / 12.0))
	if combo >= next_milestone:
		banner_text = _t("hits_banner") % next_milestone
		banner_time = 0.9
		screen_flash = 0.35
		trauma = minf(trauma + 0.4, 1.0)
		_play("win", 1.5)
		next_milestone = next_milestone * 2


func _on_kill(e: Dictionary) -> void:
	var color: Color = COLOR_BOMB if e["bomb"] else COLOR_ACCENT
	_spawn_particles(e["pos"], color, 16, 420.0)
	_spawn_particles(e["pos"], Color.WHITE, 6, 280.0)
	trauma = minf(trauma + 0.12, 1.0)
	hitstop = maxf(hitstop, 0.012)
	_play("pop", randf_range(0.9, 1.2))
	if save.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(10)
	for i in mini(int(e["coins"]), 6):
		if fly_coins.size() >= 80:
			break
		fly_coins.append({
			"pos": e["pos"],
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(180.0, 460.0),
			"t": 0.0,
		})


func _on_explode(e: Dictionary) -> void:
	verify_stats["explosions"] = int(verify_stats["explosions"]) + 1
	rings.append({"pos": e["pos"], "t": 0.0})
	_spawn_particles(e["pos"], COLOR_BOMB, 26, 620.0)
	_spawn_particles(e["pos"], COLOR_COIN, 14, 420.0)
	trauma = minf(trauma + 0.35, 1.0)
	screen_flash = maxf(screen_flash, 0.14)
	_play("boom", randf_range(0.85, 1.15))
	if time - last_boom_stop > 0.14:
		last_boom_stop = time
		hitstop = maxf(hitstop, 0.035)


func _big_celebration() -> void:
	for i in 14:
		var pos := Vector2(randf_range(80.0, 640.0), randf_range(240.0, 900.0))
		rings.append({"pos": pos, "t": -randf() * 0.4})
		_spawn_particles(pos, Color.from_hsv(randf(), 0.8, 1.0), 18, 560.0)


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
	for cell in flash.keys():
		flash[cell] = float(flash[cell]) - delta * 9.0
		if float(flash[cell]) <= 0.0:
			flash.erase(cell)
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
	var target := Vector2(650.0, 92.0)
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


func _draw() -> void:
	_fill_screen(COLOR_BG)
	match screen:
		Screen.TITLE:
			_draw_title()
		Screen.HOWTO:
			_draw_howto()
		Screen.SETTINGS:
			_draw_settings()
		Screen.GAME:
			_draw_game()
	_draw_buttons()


func _fill_screen(color: Color) -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(-80.0, -y_offset - 80.0, view.x + 160.0, view.y + 160.0), color)


func _draw_buttons() -> void:
	for button in _current_buttons():
		var rect: Rect2 = button["rect"]
		match String(button["style"]):
			"icon":
				var c := rect.get_center()
				draw_rect(Rect2(c + Vector2(-13.0, -15.0), Vector2(9.0, 30.0)), COLOR_LABEL)
				draw_rect(Rect2(c + Vector2(4.0, -15.0), Vector2(9.0, 30.0)), COLOR_LABEL)
				continue
			"primary":
				var pulse := 0.5 + sin(time * 4.0) * 0.5
				draw_rect(rect, COLOR_ACCENT.lerp(Color("ff8ca0"), pulse * 0.4))
				draw_rect(Rect2(rect.position, Vector2(rect.size.x, 8.0)), Color(1.0, 1.0, 1.0, 0.3))
				_text(rect.get_center(), String(button["label"]), 52, Color.WHITE)
				continue
			"selected":
				draw_rect(rect, COLOR_COIN)
				_text(rect.get_center(), String(button["label"]), 36, COLOR_BG)
				continue
		draw_rect(rect, COLOR_BUTTON)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6.0)), Color(1.0, 1.0, 1.0, 0.12))
		_text(rect.get_center(), String(button["label"]), 36, Color.WHITE)


func _draw_title() -> void:
	# Drifting blocks and balls keep the title alive without any art assets.
	for i in 16:
		var speed := 30.0 + i * 6.0
		var x := fmod(i * 137.0, 660.0) + 10.0
		var y := fmod(time * speed + i * 211.0, BASE_H + 400.0) - 200.0
		var color := Color.from_hsv(fmod(i * 0.13 + time * 0.02, 1.0), 0.7, 0.95, 0.2)
		if i % 4 == 0:
			draw_circle(Vector2(x, y), 14.0, Color(1.0, 1.0, 1.0, 0.22))
		else:
			draw_rect(Rect2(x, y, 84.0, 54.0), color)
	var pop := 1.0 + sin(time * 3.0) * 0.015
	var hue_color := Color.from_hsv(fmod(time * 0.08, 1.0), 0.45, 1.0)
	_text_outlined(Vector2(BASE_W / 2.0, 190.0), _t("game_title"), int(_fit_size(_t("game_title"), 72, 640.0) * pop), hue_color)
	_text_outlined(Vector2(BASE_W / 2.0, 285.0), _t("tagline"), 36, COLOR_COIN)
	draw_rect(Rect2(90.0, 345.0, 540.0, 335.0), Color(0.05, 0.04, 0.14, 0.82))
	_text(Vector2(BASE_W / 2.0, 385.0), _t("records"), 30, COLOR_LABEL)
	var rows := [
		["rec_damage", str(save.best_damage)],
		["rec_combo", str(save.best_combo)],
		["rec_stage", "%d / %d" % [save.best_stage, GameSim.STAGES.size()]],
		["rec_coins", str(save.total_coins)],
		["rec_wins", str(save.wins)],
	]
	for i in rows.size():
		_row(Vector2(125.0, 437.0 + i * 50.0), 470.0, _t(rows[i][0]), rows[i][1], 30, Color.WHITE)


func _row(left: Vector2, width: float, label: String, value: String, size: int, value_color: Color) -> void:
	draw_string(font, left + Vector2(0.0, size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, COLOR_LABEL)
	draw_string(font, left + Vector2(0.0, size * 0.35), value, HORIZONTAL_ALIGNMENT_RIGHT, width, size, value_color)


func _draw_howto() -> void:
	_text_outlined(Vector2(BASE_W / 2.0, 170.0), _t("howto"), 64, COLOR_COIN)
	var colors := [Color("4fd1ff"), Color("6dff9e"), COLOR_COIN, COLOR_ACCENT, Color("b48cff")]
	for i in 5:
		var y := 300.0 + i * 140.0
		draw_rect(Rect2(50.0, y - 50.0, 620.0, 110.0), COLOR_FIELD)
		draw_rect(Rect2(50.0, y - 50.0, 90.0, 110.0), colors[i])
		_text(Vector2(95.0, y + 4.0), str(i + 1), 50, COLOR_BG)
		var line := _t("howto_%d" % (i + 1))
		_text(Vector2(405.0, y + 4.0), line, _fit_size(line, 30, 510.0), Color.WHITE)


func _draw_settings() -> void:
	_text_outlined(Vector2(BASE_W / 2.0, 170.0), _t("settings"), 64, COLOR_COIN)
	_text(Vector2(BASE_W / 2.0, 295.0), _t("language"), 34, COLOR_LABEL)


func _draw_game() -> void:
	var heat := clampf(sim.combo / 80.0, 0.0, 1.0) if sim.state == GameSim.State.SHOOT else 0.0
	var field := Rect2(GameSim.FIELD_X, GameSim.FIELD_Y, GameSim.FIELD_W, GameSim.LAUNCH_Y - GameSim.FIELD_Y + 30.0)
	draw_rect(field, COLOR_FIELD.lerp(Color("4a1742"), heat))
	var death_y := GameSim.FIELD_Y + GameSim.DEATH_ROW * GameSim.CELL_H
	draw_line(Vector2(GameSim.FIELD_X, death_y), Vector2(GameSim.FIELD_X + GameSim.FIELD_W, death_y), Color(1.0, 0.3, 0.4, 0.35), 3.0)
	_draw_blocks()
	_draw_balls()
	_draw_launcher()
	if aiming and sim.state == GameSim.State.AIM:
		_draw_aim()
	for r in rings:
		if float(r["t"]) >= 0.0:
			var k := float(r["t"]) / 0.35
			draw_arc(r["pos"], 40.0 + k * 170.0, 0.0, TAU, 40, Color(1.0, 0.75, 0.3, 1.0 - k), 16.0 * (1.0 - k) + 2.0)
	for p in particles:
		var alpha := 1.0 - float(p["t"]) / float(p["life"])
		var color: Color = p["color"]
		color.a = alpha
		var s: float = float(p["size"]) * (0.4 + alpha * 0.6)
		draw_rect(Rect2(p["pos"] - Vector2(s, s) / 2.0, Vector2(s, s)), color)
	for c in fly_coins:
		draw_circle(c["pos"], 9.0, COLOR_COIN)
		draw_circle(c["pos"], 5.0, Color("c99a1a"))
	for n in numbers:
		var alpha := 1.0 - float(n["t"]) / 0.55
		var size := 40 if n["big"] else 26
		var color := Color(1.0, 0.9, 0.3, alpha) if n["big"] else Color(1.0, 1.0, 1.0, alpha)
		_text(n["pos"], str(n["text"]), size, color)
	_draw_hud()
	if screen_flash > 0.0:
		_fill_screen(Color(1.0, 1.0, 1.0, screen_flash * 0.5))
	match sim.state:
		GameSim.State.UPGRADE:
			_draw_upgrade_screen()
		GameSim.State.WON:
			_draw_end_screen(_t("you_win"), COLOR_COIN)
		GameSim.State.LOST:
			_draw_end_screen(_t("game_over"), COLOR_ACCENT)
	if banner_time > 0.0 and sim.state != GameSim.State.UPGRADE and not paused:
		var pop := 1.0 + clampf(banner_time - 0.75, 0.0, 0.25) * 2.0
		_text_outlined(Vector2(BASE_W / 2.0, 610.0), banner_text, int(80.0 * pop), Color(1.0, 1.0, 1.0, minf(banner_time * 3.0, 1.0)))
	if paused:
		_fill_screen(Color(0.04, 0.03, 0.1, 0.85))
		_text_outlined(Vector2(BASE_W / 2.0, 310.0), _t("paused"), 80, COLOR_COIN)


func _draw_blocks() -> void:
	var slide := -descend_anim * GameSim.CELL_H
	for cell: Vector2i in sim.blocks:
		var block: Dictionary = sim.blocks[cell]
		var rect := sim.cell_rect(cell)
		rect.position.y += slide
		var color := _block_color(block)
		draw_rect(rect, color)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 7.0)), color.lightened(0.35))
		draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - 7.0), Vector2(rect.size.x, 7.0)), color.darkened(0.3))
		if flash.has(cell):
			draw_rect(rect, Color(1.0, 1.0, 1.0, clampf(float(flash[cell]), 0.0, 1.0)))
		if block["kind"] == "bomb":
			draw_circle(rect.get_center() + Vector2(-27.0, 0.0), 8.0, Color("3a1500"))
		_text(rect.get_center() + Vector2(0.0, 2.0), str(block["hp"]), 30, Color.WHITE)


func _block_color(block: Dictionary) -> Color:
	if block["kind"] == "bomb":
		return COLOR_BOMB
	var ratio := clampf(float(block["hp"]) / 54.0, 0.0, 1.0)
	return Color.from_hsv(0.58 - ratio * 0.58, 0.72, 0.95)


func _block_color_for_combo(combo: int) -> Color:
	return Color.from_hsv(fmod(combo * 0.021, 1.0), 0.65, 1.0)


func _draw_balls() -> void:
	for ball in sim.balls:
		var tail: Vector2 = ball.pos - ball.vel.normalized() * 34.0
		var color := Color("9be7ff") if ball.temp else Color.WHITE
		draw_line(tail, ball.pos, Color(color, 0.35), 10.0)
		draw_circle(ball.pos, GameSim.BALL_RADIUS, color)


func _draw_launcher() -> void:
	var p := Vector2(sim.launch_x, GameSim.LAUNCH_Y)
	if sim.state == GameSim.State.AIM:
		draw_circle(p, GameSim.BALL_RADIUS + 4.0, Color.WHITE)
		_text(p + Vector2(0.0, 38.0), "x%d" % sim.ball_count, 28, Color.WHITE)
		if not aiming and not save.tutorial_done:
			var bob := sin(time * 4.0) * 40.0
			_text_outlined(Vector2(BASE_W / 2.0, 1170.0 + bob * 0.2), _t("tutorial"), 40, COLOR_COIN)
			draw_circle(Vector2(BASE_W / 2.0, 900.0 + bob), 22.0, Color(1.0, 1.0, 1.0, 0.75))


func _draw_aim() -> void:
	var pull := aim_start - aim_current
	if pull.length() < MIN_PULL or pull.y >= 0.0:
		return
	var points := sim.trace_aim(pull)
	var dash_phase := fmod(time * 180.0, 36.0)
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var d := dash_phase
		while d < length:
			draw_circle(a.lerp(b, d / length), 6.0, Color(1.0, 1.0, 1.0, 0.85))
			d += 36.0


func _draw_hud() -> void:
	_text(Vector2(95.0, 62.0), _t("hud_stage"), 22, COLOR_LABEL)
	_text(Vector2(95.0, 100.0), "%d/%d" % [sim.stage + 1, GameSim.STAGES.size()], 40, Color.WHITE)
	_text(Vector2(BASE_W / 2.0, 62.0), _t("hud_damage"), 22, COLOR_LABEL)
	_text(Vector2(BASE_W / 2.0, 100.0), str(sim.total_damage), 40, Color.WHITE)
	var coin_size := int(40.0 + coin_pop * 14.0)
	draw_circle(Vector2(590.0, 100.0), 14.0, COLOR_COIN)
	_text(Vector2(650.0, 100.0), str(sim.coins), coin_size, COLOR_COIN)
	if sim.state == GameSim.State.SHOOT and sim.combo >= 5:
		var pop := 1.0 + combo_pop * 0.35
		var color := Color.from_hsv(fmod(time * 0.8, 1.0), 0.6, 1.0)
		_text_outlined(Vector2(BASE_W / 2.0, 1160.0), _t("hits") % sim.combo, int(minf(46.0 + sim.combo * 0.45, 92.0) * pop), color)


func _draw_upgrade_screen() -> void:
	_fill_screen(Color(0.04, 0.03, 0.1, 0.82))
	_text_outlined(Vector2(BASE_W / 2.0, 220.0), _t("stage_clear"), _fit_size(_t("stage_clear"), 70, 620.0), COLOR_COIN)
	_text(Vector2(BASE_W / 2.0, 295.0), _t("pick_one"), 34, Color.WHITE)
	var appear := clampf(screen_age / 0.25, 0.0, 1.0)
	for i in sim.choices.size():
		var id := sim.choices[i]
		var rect := _card_rect(i)
		rect.position.x += (1.0 - appear) * 500.0 * (i + 1)
		draw_rect(rect, COLOR_BUTTON)
		draw_rect(Rect2(rect.position, Vector2(12.0, rect.size.y)), _upgrade_color(id))
		_text(rect.position + Vector2(rect.size.x / 2.0, 62.0), _t("upgrade_" + id), 46, _upgrade_color(id))
		var lines := _t("upgrade_%s_desc" % id).split("\n")
		for l in lines.size():
			_text(rect.position + Vector2(rect.size.x / 2.0, 122.0 + l * 38.0), lines[l], 30, Color.WHITE)
		var level: int = sim.levels[id]
		if level > 0:
			_text(rect.position + Vector2(rect.size.x - 58.0, 30.0), _t("level") % level, 24, COLOR_LABEL)


func _upgrade_color(id: String) -> Color:
	match id:
		"split":
			return Color("4fd1ff")
		"bomb":
			return COLOR_BOMB
		"ricochet":
			return Color("b48cff")
	return Color("6dff9e")


func _card_rect(index: int) -> Rect2:
	return Rect2(70.0, 350.0 + index * 245.0, 580.0, 225.0)


func _draw_end_screen(title: String, color: Color) -> void:
	_fill_screen(Color(0.04, 0.03, 0.1, 0.88))
	var pop := 1.0 + maxf(0.3 - screen_age, 0.0) * 1.5
	_text_outlined(Vector2(BASE_W / 2.0, 230.0), title, int(78.0 * pop), color)
	if run_new_record:
		var wobble := 1.0 + sin(time * 8.0) * 0.06
		_text_outlined(Vector2(BASE_W / 2.0, 325.0), _t("new_record"), int(44.0 * wobble), COLOR_COIN)
	_text(Vector2(BASE_W / 2.0, 410.0), _t("total_damage"), 28, COLOR_LABEL)
	_text(Vector2(BASE_W / 2.0, 475.0), str(sim.total_damage), 72, Color.WHITE)
	var seconds := int(run_seconds)
	var rows := [
		["best_shot", str(sim.best_shot_damage)],
		["best_combo", str(sim.best_combo)],
		["coins", str(sim.coins)],
		["reached", "%d / %d" % [sim.stage + 1, GameSim.STAGES.size()]],
		["play_time", "%d:%02d" % [seconds / 60, seconds % 60]],
	]
	for i in rows.size():
		_row(Vector2(110.0, 570.0 + i * 54.0), 500.0, _t(rows[i][0]), rows[i][1], 32, COLOR_COIN)
	var alpha := 0.65 + sin(time * 6.0) * 0.35
	_text_outlined(Vector2(BASE_W / 2.0, 950.0), _t("tap_retry"), 54, Color(1.0, 1.0, 1.0, alpha))


## Largest size up to `size` at which the text fits, so no language can overflow a box.
func _fit_size(text: String, size: int, max_width: float) -> int:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return size if width <= max_width else int(size * max_width / width)


func _text(center: Vector2, text: String, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := center + Vector2(-width / 2.0, size * 0.35)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_outlined(center: Vector2, text: String, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := center + Vector2(-width / 2.0, size * 0.35)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(size / 6, 4), Color(0.0, 0.0, 0.0, color.a))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _build_audio() -> void:
	sounds = {
		"hit": _tone(880.0, 0.06, 0.28, "square"),
		"pop": _tone(520.0, 0.09, 0.4, "square", -3000.0),
		"boom": _noise(0.3, 0.75),
		"coin": _tone(1320.0, 0.07, 0.22, "sine", 2500.0),
		"fire": _tone(300.0, 0.1, 0.3, "square", 1800.0),
		"pick": _tone(660.0, 0.12, 0.35, "sine", 1600.0),
		"win": _tone(660.0, 0.35, 0.45, "square", 1200.0),
		"lose": _tone(300.0, 0.5, 0.45, "square", -380.0),
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


func _tone(freq: float, duration: float, volume: float, wave: String, sweep := 0.0) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / SAMPLE_RATE
		phase += (freq + sweep * t) / SAMPLE_RATE
		var value := sin(phase * TAU) if wave == "sine" else (1.0 if fmod(phase, 1.0) < 0.5 else -1.0)
		data.encode_s16(i * 2, int(value * volume * (1.0 - float(i) / count) * 32767.0))
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


# --- Scripted end-to-end check: real input events, real rendering, saved screenshots. ---

var _checks := {}


func _run_verify(dir: String) -> void:
	Engine.time_scale = 3.0
	await _wait(0.5)
	_check("starts_on_title", screen == Screen.TITLE)
	_check("default_language_is_japanese", save.lang == "ja")
	await _shot(dir, "01_title_ja")
	await _verify_menus(dir)
	await _tap_button("start")
	_check("start_opens_game", screen == Screen.GAME and sim.state == GameSim.State.AIM)
	await _shot(dir, "07_game_start_ja")
	await _verify_pause(dir)
	await _verify_play(dir)
	await _verify_end(dir)
	await _verify_english_game(dir)
	_check("no_script_stall", true)
	var ok := true
	for key: String in _checks:
		ok = ok and bool(_checks[key])
	var report := {"ok": ok, "checks": _checks, "stats": verify_stats}
	var file := FileAccess.open(dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	Engine.time_scale = 1.0
	get_tree().quit(0 if ok else 1)


func _verify_menus(dir: String) -> void:
	await _tap_button("settings")
	_check("settings_opens", screen == Screen.SETTINGS)
	await _shot(dir, "02_settings_ja")
	await _tap_button("sound")
	_check("sound_toggles_off", not save.sound and AudioServer.is_bus_mute(0))
	await _tap_button("sound")
	_check("sound_toggles_on", save.sound and not AudioServer.is_bus_mute(0))
	await _tap_button("vibration")
	_check("vibration_toggles", not save.vibration)
	await _tap_button("vibration")
	await _tap_button("lang_en")
	_check("language_switches", save.lang == "en")
	var reloaded := SaveData.new(save.path)
	reloaded.load_file()
	_check("language_persists", reloaded.lang == "en")
	await _shot(dir, "03_settings_en")
	await _tap_button("back")
	_check("settings_back_to_title", screen == Screen.TITLE)
	await _shot(dir, "04_title_en")
	await _tap_button("howto")
	await _shot(dir, "05_howto_en")
	await _tap_button("back")
	await _tap_button("settings")
	await _tap_button("lang_ja")
	await _tap_button("back")
	await _tap_button("howto")
	_check("howto_opens", screen == Screen.HOWTO)
	await _shot(dir, "06_howto_ja")
	await _tap_button("back")


func _verify_pause(dir: String) -> void:
	await _fire_at_lowest()
	await _wait(0.1)
	_check("touch_fires_shot", sim.shots == 1)
	while sim.state == GameSim.State.SHOOT and not _can_pause():
		await _wait(0.02)
	if _can_pause():
		await _tap_button("pause")
		_check("pause_opens", paused)
		var frozen := sim.sim_time
		await _wait(0.3)
		_check("pause_freezes_game", is_equal_approx(frozen, sim.sim_time))
		await _shot(dir, "08_pause_ja")
		await _tap_button("settings")
		_check("settings_from_pause", screen == Screen.SETTINGS and paused)
		await _tap_button("back")
		_check("settings_back_to_pause", screen == Screen.GAME and paused)
		await _tap_button("resume")
		_check("resume_continues", not paused)


func _verify_play(dir: String) -> void:
	var chaos_saved := false
	var upgrade_saved := false
	var aim_saved := false
	var picks := ["split", "bomb"]
	var picked: Array[String] = []
	var started := Time.get_ticks_msec()
	var limit_ms := 70000
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--verify-play-seconds="):
			limit_ms = int(arg.get_slice("=", 1)) * 1000
	while Time.get_ticks_msec() - started < limit_ms and not _is_run_over():
		match sim.state:
			GameSim.State.AIM:
				if not aim_saved:
					aim_saved = true
					await _fire_at_lowest(dir, "09_aiming_ja")
				else:
					await _fire_at_lowest()
			GameSim.State.SHOOT:
				if not chaos_saved and sim.balls.size() >= 20:
					chaos_saved = true
					await _shot(dir, "10_chaos_ja")
				await _wait(0.03)
			GameSim.State.UPGRADE:
				await _wait(0.45)
				if not upgrade_saved:
					upgrade_saved = true
					await _shot(dir, "11_upgrade_ja")
				var index := 0
				for i in sim.choices.size():
					if picks.has(sim.choices[i]) and not picked.has(sim.choices[i]):
						index = i
				var id := sim.choices[index]
				var stage_before := sim.stage
				await _tap_at(_card_rect(index).get_center())
				_check("upgrade_card_tap", sim.stage == stage_before + 1)
				picked.append(id)


func _verify_end(dir: String) -> void:
	# A slow run hits the time limit; the end screen still has to work from there.
	if not _is_run_over():
		sim.state = GameSim.State.LOST
	await _wait(0.5)
	_check("run_recorded", save.runs == 1 and save.total_coins == sim.coins and save.best_damage == sim.total_damage)
	var reloaded := SaveData.new(save.path)
	reloaded.load_file()
	_check("records_persist", reloaded.best_damage == sim.total_damage and reloaded.runs == 1)
	_check("first_run_is_new_record", run_new_record)
	await _shot(dir, "12_end_ja")
	var retry_at := Time.get_ticks_msec()
	await _tap_at(Vector2(360.0, 900.0))
	while sim.state != GameSim.State.AIM and Time.get_ticks_msec() - retry_at < 3000:
		await get_tree().process_frame
	_check("retry_under_one_second", Time.get_ticks_msec() - retry_at < 1000)
	_check("retry_resets_run", sim.total_damage == 0 and sim.stage == 0 and screen == Screen.GAME)
	await _tap_button("pause")
	await _tap_button("to_title")
	_check("pause_to_title", screen == Screen.TITLE)
	await _shot(dir, "13_title_with_records_ja")


func _verify_english_game(dir: String) -> void:
	await _tap_button("settings")
	await _tap_button("lang_en")
	await _tap_button("back")
	await _tap_button("start")
	await _wait(1.2)
	await _shot(dir, "14_game_en")
	sim.state = GameSim.State.UPGRADE
	sim.choices = ["ricochet", "bomb", "split"] as Array[String]
	await _wait(0.5)
	await _shot(dir, "15_upgrade_en")
	sim.total_damage = 1
	sim.state = GameSim.State.LOST
	await _wait(0.5)
	await _shot(dir, "16_end_en")
	await _tap_button("to_title")
	_check("end_to_title", screen == Screen.TITLE)
	await _tap_button("settings")
	await _tap_button("lang_ja")


func _check(name_: String, ok: bool) -> void:
	_checks[name_] = bool(_checks.get(name_, true)) and ok


func _fire_at_lowest(dir := "", shot_name := "") -> void:
	var target := Vector2(360.0, 400.0)
	var best_y := -1.0
	for cell: Vector2i in sim.blocks:
		var c := sim.cell_rect(cell).get_center()
		if c.y > best_y:
			best_y = c.y
			target = c
	var aim_dir := (target - Vector2(sim.launch_x, GameSim.LAUNCH_Y)).normalized()
	var from := Vector2(360.0, 650.0)
	var to := from - aim_dir * 220.0
	_touch(from, true)
	await _wait(0.03)
	_drag(to)
	await _wait(0.06)
	if dir != "":
		await _shot(dir, shot_name)
	_touch(to, false)
	await _wait(0.03)


func _tap_button(id: String) -> void:
	print("verify: tap ", id, " screen=", screen, " state=", sim.state)
	await _wait(0.4)
	for button in _current_buttons():
		if button["id"] == id:
			await _tap_at((button["rect"] as Rect2).get_center())
			return
	_check("button_exists_" + id, false)


func _tap_at(world: Vector2) -> void:
	_touch(world, true)
	await _wait(0.02)
	_touch(world, false)
	await _wait(0.05)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds * Engine.time_scale).timeout


func _shot(dir: String, name_: String) -> void:
	print("verify: shot ", name_)
	# frame_post_draw never fires while macOS considers the window hidden, so draw explicitly.
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(dir.path_join(name_ + ".png"))


func _to_window(world: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * (world + Vector2(0.0, y_offset))


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
