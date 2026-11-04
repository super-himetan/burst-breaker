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

const BASE_H := 1280.0
const BASE_W := 720.0
const MIN_PULL := 30.0
const TAP_SLOP := 18.0
const ACCEPT_INPUT_AFTER := 0.3
const COLOR_BG := Color("14122b")
const COLOR_FIELD := Color("1c1a3d")
const COLOR_BOMB := Color("ff8c1a")
const COLOR_COIN := Color("ffd84d")
const COLOR_LABEL := Color("9a96d8")
const COLOR_BUTTON := Color("2c2860")
const COLOR_ACCENT := Color("ff5c7a")
const BLOCK_COLORS := {
	"bomb": Color("ff8c1a"),
	"shield": Color("7f93b8"),
	"regen": Color("35c46e"),
	"armor": Color("5a5f70"),
	"treasure": Color("e6b422"),
	"breeder": Color("a24fd6"),
	"extra_ball": Color("e9eef7"),
	"boss": Color("c9213f"),
}
const FONT_NAMES := ["Hiragino Sans", "Hiragino Kaku Gothic ProN", "Noto Sans CJK JP", "Noto Sans JP", "sans-serif"]
const SAMPLE_RATE := 22050

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
var aim_start := Vector2.ZERO
var aim_current := Vector2.ZERO
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
	menus = Menus.new(self, save)
	_apply_sound()
	sim = GameSim.new()
	if verify_dir != "":
		verifier = Verify.new(self, verify_dir)
		verifier.run()


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
	return screen == Menus.Screen.GAME and not paused and sim.state in [GameSim.State.AIM, GameSim.State.SHOOT]


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
	var shake := trauma * trauma * 26.0
	position = Vector2(randf_range(-shake, shake), y_offset + randf_range(-shake, shake))
	queue_redraw()


func _process_game(delta: float) -> void:
	if sim.state != last_state:
		last_state = sim.state
		screen_age = 0.0
	if not is_run_over():
		run_seconds += delta
	if hitstop > 0.0:
		hitstop -= delta
	else:
		sim.step(delta)
	verify_stats["max_balls"] = max(int(verify_stats["max_balls"]), sim.balls.size())
	_consume_events()
	_note_offered_perks()
	if is_run_over():
		_bank_run()


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
	if screen != Menus.Screen.GAME or paused:
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
	var pull := aim_start - p
	if sim.state == GameSim.State.AIM and pull.length() >= MIN_PULL and pull.y < 0.0:
		if not save.tutorial_done:
			save.tutorial_done = true
			save.save_file()
		sim.fire(pull)


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
		"to_title":
			_bank_run()
			paused = false
			_set_screen(Menus.Screen.TITLE)


func current_buttons() -> Array[Dictionary]:
	if screen != Menus.Screen.GAME:
		return menus.buttons(screen)
	var list: Array[Dictionary] = []
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
			"rebound":
				_spawn_particles(e["pos"], Color("6dff9e"), 6, 220.0)
			"shock":
				if bolts.size() < 24:
					bolts.append({"to": e["pos"], "x": (e["pos"] as Vector2).x + randf_range(-60.0, 60.0), "t": 0.0})
			"regen":
				_spawn_particles(e["pos"], BLOCK_COLORS["regen"], 3, 90.0)
			"breed":
				_spawn_particles(e["pos"], BLOCK_COLORS["breeder"], 8, 180.0)
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
		_spawn_particles(e["pos"], COLOR_COIN, 8, 300.0)
	if e["dot"]:
		return
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
		_show_banner(t("hits_banner") % next_milestone, 0.9)
		screen_flash = 0.35
		trauma = minf(trauma + 0.4, 1.0)
		_play("win", 1.5)
		next_milestone = next_milestone * 2


func _on_kill(e: Dictionary) -> void:
	var kind: String = e["kind"]
	var color: Color = BLOCK_COLORS.get(kind, COLOR_ACCENT)
	var is_boss := kind == "boss"
	_spawn_particles(e["pos"], color, 70 if is_boss else 16, 900.0 if is_boss else 420.0)
	_spawn_particles(e["pos"], Color.WHITE, 30 if is_boss else 6, 600.0 if is_boss else 280.0)
	trauma = minf(trauma + (1.0 if is_boss else 0.12), 1.0)
	hitstop = maxf(hitstop, 0.15 if is_boss else 0.012)
	if is_boss:
		screen_flash = 1.0
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
	_spawn_particles(e["pos"], COLOR_BOMB, 26, 620.0)
	_spawn_particles(e["pos"], COLOR_COIN, 14, 420.0)
	trauma = minf(trauma + 0.35, 1.0)
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
	var target := Vector2(650.0, 100.0)
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
	fill_screen(COLOR_BG)
	if screen == Menus.Screen.GAME:
		_draw_game()
	else:
		menus.draw(screen)
	menus.draw_buttons(current_buttons(), time)
	_draw_toast()


func _draw_toast() -> void:
	if toasts.is_empty():
		return
	var toast := toasts[0]
	var k := float(toast["t"])
	var slide := clampf(k / 0.2, 0.0, 1.0) * clampf((2.2 - k) / 0.2, 0.0, 1.0)
	var y := -40.0 + slide * 80.0
	draw_rect(Rect2(40.0, y - 30.0, 640.0, 60.0), Color(0.05, 0.04, 0.14, 0.94))
	draw_rect(Rect2(40.0, y - 30.0, 8.0, 60.0), COLOR_COIN)
	var text := String(toast["text"])
	text_center(Vector2(BASE_W / 2.0, y), text, fit_size(text, 28, 600.0), COLOR_COIN)


func fill_screen(color: Color) -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(-80.0, -y_offset - 80.0, view.x + 160.0, view.y + 160.0), color)


func row(left: Vector2, width: float, label: String, value: String, size: int, value_color: Color) -> void:
	draw_string(font, left + Vector2(0.0, size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, COLOR_LABEL)
	draw_string(font, left + Vector2(0.0, size * 0.35), value, HORIZONTAL_ALIGNMENT_RIGHT, width, size, value_color)


func _draw_game() -> void:
	var heat := clampf(sim.combo / 80.0, 0.0, 1.0) if sim.state == GameSim.State.SHOOT else 0.0
	var field := Rect2(GameSim.FIELD_X, GameSim.FIELD_Y, GameSim.FIELD_W, GameSim.LAUNCH_Y - GameSim.FIELD_Y + 30.0)
	draw_rect(field, COLOR_FIELD.lerp(Color("4a1742"), heat))
	var death_y := GameSim.FIELD_Y + sim.death_row * GameSim.CELL_H
	draw_line(Vector2(GameSim.FIELD_X, death_y), Vector2(GameSim.FIELD_X + GameSim.FIELD_W, death_y), Color(1.0, 0.3, 0.4, 0.35), 3.0)
	_draw_blocks()
	_draw_balls()
	_draw_launcher()
	if aiming and sim.state == GameSim.State.AIM:
		_draw_aim()
	for r in rings:
		if float(r["t"]) >= 0.0:
			var k := float(r["t"]) / 0.35
			draw_arc(r["pos"], 40.0 + k * float(r["size"]), 0.0, TAU, 40, Color(1.0, 0.75, 0.3, 1.0 - k), 16.0 * (1.0 - k) + 2.0)
	for b in bolts:
		var to: Vector2 = b["to"]
		var from := Vector2(float(b["x"]), GameSim.FIELD_Y)
		var mid := from.lerp(to, 0.5) + Vector2(randf_range(-30.0, 30.0), 0.0)
		var alpha := 1.0 - float(b["t"]) / 0.14
		draw_line(from, mid, Color(0.7, 0.9, 1.0, alpha), 5.0)
		draw_line(mid, to, Color(0.7, 0.9, 1.0, alpha), 5.0)
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
		var size := 44 if n["big"] else 26
		var color := Color(1.0, 0.85, 0.2, alpha) if n["big"] else (Color(0.6, 1.0, 0.6, alpha) if n["dot"] else Color(1.0, 1.0, 1.0, alpha))
		text_center(n["pos"], str(n["text"]), size, color)
	_draw_hud()
	if screen_flash > 0.0:
		fill_screen(Color(1.0, 1.0, 1.0, screen_flash * 0.5))
	match sim.state:
		GameSim.State.UPGRADE:
			_draw_upgrade_screen()
		GameSim.State.WON:
			_draw_end_screen(t("you_win"), COLOR_COIN)
		GameSim.State.LOST:
			_draw_end_screen(t("game_over"), COLOR_ACCENT)
	if banner_time > 0.0 and sim.state != GameSim.State.UPGRADE and not paused:
		var pop := 1.0 + clampf(banner_time - 0.75, 0.0, 0.25) * 2.0
		text_outlined(Vector2(BASE_W / 2.0, 610.0), banner_text, int(80.0 * pop), Color(1.0, 1.0, 1.0, minf(banner_time * 3.0, 1.0)))
	if paused:
		fill_screen(Color(0.04, 0.03, 0.1, 0.85))
		text_outlined(Vector2(BASE_W / 2.0, 310.0), t("paused"), 80, COLOR_COIN)


func _draw_blocks() -> void:
	var slide := -descend_anim * GameSim.CELL_H
	for block in sim.unique_blocks():
		var rect := sim.block_rect(block)
		rect.position.y += slide
		if block["kind"] == "boss":
			_draw_boss(block, rect)
			continue
		_draw_block_body(String(block["kind"]), rect, _block_color(block))
		if flash.has(block["id"]):
			draw_rect(rect, Color(1.0, 1.0, 1.0, clampf(float(flash[block["id"]]), 0.0, 1.0)))
		if int(block["poison"]) > 0:
			draw_circle(rect.position + Vector2(rect.size.x - 10.0, 10.0), 6.0, Color("7dff5c"))
		if block["burning"]:
			draw_circle(rect.position + Vector2(10.0, 10.0), 6.0, Color("ff6a2b"))
		var hp_text := I18n.format_number(block["hp"])
		text_center(rect.get_center() + Vector2(0.0, 2.0), hp_text, fit_size(hp_text, 30, rect.size.x - 10.0), COLOR_BG if block["kind"] == "extra_ball" else Color.WHITE)


## Base look of a block, shared with the codex.
func _draw_block_body(kind: String, rect: Rect2, color: Color) -> void:
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 7.0)), color.lightened(0.35))
	draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - 7.0), Vector2(rect.size.x, 7.0)), color.darkened(0.3))
	var c := rect.get_center()
	match kind:
		"bomb":
			draw_circle(c + Vector2(-27.0, 0.0), 8.0, Color("3a1500"))
		"shield":
			draw_rect(rect, Color("dfe8ff"), false, 5.0)
		"armor":
			draw_rect(rect, Color("1b1d26"), false, 7.0)
		"regen":
			draw_rect(Rect2(c + Vector2(-34.0, -3.0), Vector2(14.0, 6.0)), Color.WHITE)
			draw_rect(Rect2(c + Vector2(-30.0, -7.0), Vector2(6.0, 14.0)), Color.WHITE)
		"treasure":
			draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y * 0.42), Vector2(rect.size.x, 5.0)), Color("7a5a0a"))
		"breeder":
			draw_circle(c + Vector2(-30.0, -10.0), 5.0, Color.WHITE)
			draw_circle(c + Vector2(-30.0, 10.0), 5.0, Color.WHITE)
		"extra_ball":
			draw_circle(c + Vector2(-27.0, 0.0), 9.0, Color("4fd1ff"))


func draw_block_icon(kind: String, rect: Rect2) -> void:
	if kind == "boss":
		draw_rect(rect, BLOCK_COLORS["boss"])
		_draw_boss_face(rect)
		return
	_draw_block_body(kind, rect, BLOCK_COLORS.get(kind, Color("4fa8e8")))


func _draw_boss(block: Dictionary, rect: Rect2) -> void:
	var enraged := float(block["hp"]) / float(block["max_hp"]) < 0.5
	var color: Color = BLOCK_COLORS["boss"]
	if enraged:
		color = color.lerp(Color("ff7a1a"), 0.5 + sin(time * 10.0) * 0.3)
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 10.0)), color.lightened(0.35))
	draw_rect(rect, Color("3a0812"), false, 6.0)
	_draw_boss_face(rect)
	if flash.has(block["id"]):
		draw_rect(rect, Color(1.0, 1.0, 1.0, clampf(float(flash[block["id"]]) * 0.6, 0.0, 1.0)))
	var bar := Rect2(rect.position + Vector2(12.0, rect.size.y - 28.0), Vector2(rect.size.x - 24.0, 18.0))
	draw_rect(bar, Color("3a0812"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(block["hp"]) / float(block["max_hp"]), 0.0, 1.0), bar.size.y)), COLOR_COIN)
	var hp_text := I18n.format_number(block["hp"])
	text_outlined(rect.get_center() + Vector2(0.0, -6.0), hp_text, 34, Color.WHITE)


func _draw_boss_face(rect: Rect2) -> void:
	var c := rect.get_center()
	var eye := rect.size.x * 0.2
	var r := minf(rect.size.y * 0.13, 12.0)
	draw_circle(c + Vector2(-eye, -rect.size.y * 0.24), r, Color.WHITE)
	draw_circle(c + Vector2(eye, -rect.size.y * 0.24), r, Color.WHITE)
	draw_circle(c + Vector2(-eye, -rect.size.y * 0.24), r * 0.5, Color.BLACK)
	draw_circle(c + Vector2(eye, -rect.size.y * 0.24), r * 0.5, Color.BLACK)


func _block_color(block: Dictionary) -> Color:
	var kind: String = block["kind"]
	if BLOCK_COLORS.has(kind):
		return BLOCK_COLORS[kind]
	var top: float = float(GameSim.STAGES[sim.stage]["hp_max"]) * GameSim.Tiers.hp_scale(sim.tier)
	var ratio := clampf(float(block["hp"]) / top, 0.0, 1.0)
	return Color.from_hsv(0.58 - ratio * 0.5, 0.72, 0.95)


func _block_color_for_combo(combo: int) -> Color:
	return Color.from_hsv(fmod(combo * 0.021, 1.0), 0.65, 1.0)


func _ball_color() -> Color:
	return Color(String(Balls.BALLS[sim.ball_type]["color"]))


func _draw_balls() -> void:
	var base := _ball_color()
	var radius := sim.ball_radius
	for ball in sim.balls:
		var tail: Vector2 = ball.pos - ball.vel.normalized() * (24.0 + radius)
		var color := base.lerp(Color("9be7ff"), 0.6) if ball.temp else base
		draw_line(tail, ball.pos, Color(color, 0.35), radius)
		draw_circle(ball.pos, radius, color)


func _draw_launcher() -> void:
	var p := Vector2(sim.launch_x, GameSim.LAUNCH_Y)
	if sim.state != GameSim.State.AIM:
		return
	draw_circle(p, sim.ball_radius + 4.0, _ball_color())
	text_center(p + Vector2(0.0, 44.0), "x%d" % sim.shot_ball_count(), 28, Color.WHITE)
	if sim.guards > 0:
		text_center(Vector2(120.0, 1120.0), "GUARD x%d" % sim.guards, 22, Color("6dff9e"))
	if not aiming and not save.tutorial_done:
		var bob := sin(time * 4.0) * 40.0
		text_outlined(Vector2(BASE_W / 2.0, 1170.0 + bob * 0.2), t("tutorial"), 40, COLOR_COIN)
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
	text_center(Vector2(95.0, 62.0), t("hud_stage"), 22, COLOR_LABEL)
	text_center(Vector2(95.0, 100.0), "%d/%d" % [sim.stage + 1, GameSim.STAGES.size()], 40, Color.WHITE)
	if sim.tier > 0:
		text_center(Vector2(95.0, 142.0), t("tier_label") % sim.tier, 20, COLOR_ACCENT)
	text_center(Vector2(BASE_W / 2.0, 62.0), t("hud_damage"), 22, COLOR_LABEL)
	text_center(Vector2(BASE_W / 2.0, 100.0), I18n.format_number(sim.total_damage), 40, Color.WHITE)
	var coin_size := int(40.0 + coin_pop * 14.0)
	draw_circle(Vector2(575.0, 100.0), 14.0, COLOR_COIN)
	text_center(Vector2(640.0, 100.0), I18n.format_number(sim.coins), coin_size, COLOR_COIN)
	if sim.state == GameSim.State.SHOOT and sim.combo >= 5:
		var pop := 1.0 + combo_pop * 0.35
		var color := Color.from_hsv(fmod(time * 0.8, 1.0), 0.6, 1.0)
		text_outlined(Vector2(BASE_W / 2.0, 1160.0), t("hits") % sim.combo, int(minf(46.0 + sim.combo * 0.45, 92.0) * pop), color)


func _draw_upgrade_screen() -> void:
	fill_screen(Color(0.04, 0.03, 0.1, 0.84))
	var clearing := sim.blocks.is_empty()
	var heading := t("stage_clear") if clearing else t("pick_start")
	text_outlined(Vector2(BASE_W / 2.0, 200.0), heading, fit_size(heading, 66, 640.0), COLOR_COIN)
	if clearing:
		text_center(Vector2(BASE_W / 2.0, 272.0), t("pick_one"), 32, Color.WHITE)
	var appear := clampf(screen_age / 0.25, 0.0, 1.0)
	var count := sim.choices.size()
	for i in count:
		var id := sim.choices[i]
		var rect := card_rect(i, count)
		rect.position.x += (1.0 - appear) * 500.0 * (i + 1)
		var perk: Dictionary = Perks.PERKS[id]
		var color: Color = Menus.RARITY_COLORS[int(perk["rarity"])]
		var evolution := Perks.is_evolution(id)
		draw_rect(rect, Color("4a2a10") if evolution else COLOR_BUTTON)
		draw_rect(Rect2(rect.position, Vector2(12.0, rect.size.y)), color)
		if evolution:
			var glow := 0.55 + sin(time * 6.0) * 0.45
			draw_rect(rect, Color(color, glow), false, 5.0)
		var label := t("evolution") if evolution else t("rarity_%d" % int(perk["rarity"]))
		text_left(rect.position + Vector2(30.0, 26.0), label, 20, color)
		var level: int = sim.levels[id]
		if level > 0:
			text_center(rect.position + Vector2(rect.size.x - 58.0, 26.0), t("level") % level, 22, COLOR_LABEL)
		var name_text := t("perk_" + id)
		var middle := rect.size.y * 0.33
		text_center(rect.position + Vector2(rect.size.x / 2.0, middle), name_text, fit_size(name_text, 42, rect.size.x - 60.0), color)
		var lines := t("perk_%s_desc" % id).split("\n")
		var line_y := rect.size.y * (0.62 if lines.size() > 1 else 0.7)
		for l in lines.size():
			text_center(rect.position + Vector2(rect.size.x / 2.0, line_y + l * 36.0), lines[l], fit_size(lines[l], 28, rect.size.x - 60.0), Color.WHITE)


func card_rect(index: int, count: int) -> Rect2:
	var top := 310.0
	var area := 780.0
	var gap := 16.0
	var height := minf((area - gap * (count - 1)) / count, 230.0)
	return Rect2(70.0, top + index * (height + gap), 580.0, height)


func _draw_end_screen(title: String, color: Color) -> void:
	fill_screen(Color(0.04, 0.03, 0.1, 0.88))
	var pop := 1.0 + maxf(0.3 - screen_age, 0.0) * 1.5
	text_outlined(Vector2(BASE_W / 2.0, 230.0), title, int(fit_size(title, 78, 640.0) * pop), color)
	if run_new_record:
		var wobble := 1.0 + sin(time * 8.0) * 0.06
		text_outlined(Vector2(BASE_W / 2.0, 325.0), t("new_record"), int(44.0 * wobble), COLOR_COIN)
	text_center(Vector2(BASE_W / 2.0, 410.0), t("total_damage"), 28, COLOR_LABEL)
	text_center(Vector2(BASE_W / 2.0, 475.0), I18n.format_number(sim.total_damage), 72, Color.WHITE)
	var seconds := int(run_seconds)
	var rows := [
		["best_shot", I18n.format_number(sim.best_shot_damage)],
		["best_combo", str(sim.best_combo)],
		["coins", I18n.format_number(sim.coins)],
		["reached", "%d / %d" % [sim.stage + 1, GameSim.STAGES.size()]],
		["play_time", "%d:%02d" % [seconds / 60, seconds % 60]],
	]
	for i in rows.size():
		row(Vector2(110.0, 570.0 + i * 54.0), 500.0, t(rows[i][0]), rows[i][1], 32, COLOR_COIN)
	var alpha := 0.65 + sin(time * 6.0) * 0.35
	text_outlined(Vector2(BASE_W / 2.0, 950.0), t("tap_retry"), 54, Color(1.0, 1.0, 1.0, alpha))


## Largest size up to `size` at which the text fits, so no language can overflow a box.
func fit_size(text: String, size: int, max_width: float) -> int:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return size if width <= max_width else int(size * max_width / width)


func text_center(center: Vector2, text: String, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := center + Vector2(-width / 2.0, size * 0.35)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func text_left(left: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(font, left + Vector2(0.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func text_outlined(center: Vector2, text: String, size: int, color: Color) -> void:
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
		var k := float(i) / SAMPLE_RATE
		phase += (freq + sweep * k) / SAMPLE_RATE
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
