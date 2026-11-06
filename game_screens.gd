extends "res://game_field.gd"
## Drawing what sits over the field: the HUD, cards, results, cut-ins and the ending.


func _draw_ui() -> void:
	canvas = ui_layer
	_pending_dots.clear()
	if screen == Menus.Screen.GAME:
		_draw_game_ui()
	else:
		menus.draw(screen)
	menus.draw_buttons(current_buttons(), time)
	if screen == Menus.Screen.ENDING:
		_draw_ending()
	for dot in _pending_dots:
		soft_glow(dot["pos"], Vector2(70.0, 70.0), Color(dot["color"], 0.5))
		ui_layer.draw_circle(dot["pos"], 13.0, dot["color"])
	_draw_toast()
	_draw_wipe()

## A slanted band of ink sweeps across whenever the screen changes.
func _draw_wipe() -> void:
	if wipe <= 0.0:
		return
	var k := 1.0 - wipe / WIPE_SECONDS
	var view := get_viewport_rect().size
	var lead := (k * 2.0 - 0.3) * (view.x + 500.0) - 250.0
	var tail := lead - (view.x + 500.0) * 0.6
	var top := -y_offset - 20.0
	var bottom := view.y - y_offset + 20.0
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(tail + 220.0, top), Vector2(lead + 220.0, top), Vector2(lead - 220.0, bottom), Vector2(tail - 220.0, bottom)]), UI.INK)

func _draw_ending() -> void:
	fill_screen(Color(UI.INK, minf(ending_age, 1.0)))
	var lines := 8
	for i in lines:
		var since := ending_age - i * ENDING_LINE_SECONDS * 0.5
		if since <= 0.0:
			break
		var line := t("ending_%d" % (i + 1))
		var alpha := minf(since, 1.0)
		text_center(Vector2(BASE_W / 2.0, 220.0 + i * 88.0), line, fit_size(line, 30, 640.0), Color(UI.TEXT, alpha), font_body)

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
	# Each ball's emblem sweeps behind its move's name.
	for i in 5:
		var emblem := Vector2(BASE_W * (i + 0.5) / 5.0 + slide + creep * (i - 2), center_y + 92.0)
		PerkArt.draw_glyph(canvas, BALL_GLYPHS[sim.ball_type], emblem, 18.0, Color(UI.INK, 0.45))

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
	for i in sim.stage_total():
		var c := start + Vector2(i * STAGE_PIP_SPACING, 0.0)
		var color := UI.ACCENT if i == sim.stage else (UI.TEXT if i < sim.stage else Color(UI.MUTED, 0.3))
		if i == sim.stage:
			soft_glow(c, Vector2(44.0, 44.0), Color(UI.ACCENT, 0.5))
		if sim.is_boss_stage(i):
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
	# The rarest cards turn over in front of you.
	if int(perk["rarity"]) == Perks.LEGENDARY and not Perks.is_evolution(id) and screen_age < REVEAL_SECONDS:
		var flip := absf(cos(screen_age / REVEAL_SECONDS * PI))
		var center := rect.get_center()
		var narrow := Rect2(center - Vector2(rect.size.x * flip / 2.0, rect.size.y / 2.0), Vector2(rect.size.x * flip, rect.size.y))
		if screen_age < REVEAL_SECONDS / 2.0:
			panel(narrow, Color(UI.GOLD, 0.92 * alpha), 30.0, Color.WHITE, 3)
			soft_glow(center, rect.size * 1.4, Color(UI.GOLD, 0.5 * alpha))
			return
		rect = narrow
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
			var completes := sim.set_completed_by(option["relic"])
			if completes != "":
				text_right(Vector2(rect.end.x - 24.0, rect.position.y + 30.0), t("set_ready") % t(completes), 22, Color(UI.MINT, alpha), font_body)
		elif option.has("forge"):
			_draw_card(option["forge"], rect, alpha)
			text_right(Vector2(rect.end.x - 24.0, rect.position.y + 30.0), t("forge_hint"), 22, Color(UI.GOLD, alpha), font_body)
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
	_draw_stage_pips(Vector2(BASE_W / 2.0 - (sim.stage_total() - 1) * STAGE_PIP_SPACING / 2.0, 568.0))
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
