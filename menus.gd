extends RefCounted
## Every screen outside the actual game: layout, drawing and tap handling.
## One button list drives both drawing and hit tests, so they can never disagree.

const I18n := preload("res://i18n.gd")
const Achievements := preload("res://data/achievements.gd")
const Balls := preload("res://data/balls.gd")
const Perks := preload("res://data/perks.gd")
const Shop := preload("res://data/shop.gd")
const Tiers := preload("res://data/tiers.gd")
const GameSim := preload("res://sim/game_sim.gd")

enum Screen { TITLE, HOWTO, SETTINGS, GAME, LOADOUT, SHOP, ACHIEVEMENTS, CODEX, PRESTIGE }

const BASE_W := 720.0
const BASE_H := 1280.0
const LIST_TOP := 215.0
const LIST_BOTTOM := 1095.0
const ROW_GAP := 10.0
const COLOR_BG := Color("14122b")
const COLOR_FIELD := Color("1c1a3d")
const COLOR_BUTTON := Color("2c2860")
const COLOR_ACCENT := Color("ff5c7a")
const COLOR_COIN := Color("ffd84d")
const COLOR_LABEL := Color("9a96d8")
const COLOR_STAR := Color("8fe3ff")
const COLOR_OK := Color("6dff9e")
const RARITY_COLORS: Array[Color] = [Color("c8c8e0"), Color("4fd1ff"), Color("b48cff"), Color("ffb347")]
const BLOCK_KINDS: Array[String] = ["normal", "bomb", "shield", "regen", "armor", "treasure", "breeder", "extra_ball", "boss"]
const CODEX_TABS: Array[String] = ["perks", "balls", "blocks"]

var host: Node2D
var save: RefCounted
var scroll := 0.0
var codex_tab := "perks"
var confirm_prestige := false
var _achievement_rows: Array[Dictionary] = []
var _achievements_done := 0


func _init(host_node: Node2D, save_data: RefCounted) -> void:
	host = host_node
	save = save_data


func t(key: String) -> String:
	return I18n.text(save.lang, key)


func num(value: int) -> String:
	return I18n.format_number(value)


func on_enter(screen: int) -> void:
	scroll = 0.0
	confirm_prestige = false
	if screen == Screen.ACHIEVEMENTS:
		_rebuild_achievements()


func is_list_screen(screen: int) -> bool:
	return screen in [Screen.SHOP, Screen.ACHIEVEMENTS, Screen.CODEX]


func _rebuild_achievements() -> void:
	_achievement_rows = Achievements.all()
	_achievements_done = 0
	for entry in _achievement_rows:
		if save.has_achievement(entry["id"]):
			_achievements_done += 1
	# Unfinished goals first, closest to done on top: what to chase next is always visible.
	var key := func(entry: Dictionary) -> float:
		if save.has_achievement(entry["id"]):
			return 2.0
		return 1.0 - clampf(float(save.stat_value(entry["stat"])) / float(entry["target"]), 0.0, 1.0)
	_achievement_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return key.call(a) < key.call(b))


func _button(id: String, rect: Rect2, label: String, style := "normal") -> Dictionary:
	return {"id": id, "rect": rect, "label": label, "style": style}


func buttons(screen: int) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	match screen:
		Screen.TITLE:
			list.append(_button("start", Rect2(110.0, 500.0, 500.0, 130.0), t("start"), "primary"))
			var grid: Array[String] = ["shop", "achievements", "codex", "prestige", "howto", "settings"]
			for i in grid.size():
				var rect := Rect2(70.0 + (i % 2) * 300.0, 650.0 + (i / 2) * 120.0, 280.0, 105.0)
				list.append(_button(grid[i], rect, t(grid[i])))
		Screen.HOWTO:
			list.append(_button("back", Rect2(110.0, 1060.0, 500.0, 110.0), t("back")))
		Screen.SETTINGS:
			list.append(_button("lang_ja", Rect2(70.0, 340.0, 280.0, 100.0), "日本語", "selected" if save.lang == "ja" else "normal"))
			list.append(_button("lang_en", Rect2(370.0, 340.0, 280.0, 100.0), "English", "selected" if save.lang == "en" else "normal"))
			list.append(_button("sound", Rect2(70.0, 490.0, 580.0, 100.0), "%s : %s" % [t("sound"), t("on" if save.sound else "off")]))
			list.append(_button("vibration", Rect2(70.0, 610.0, 580.0, 100.0), "%s : %s" % [t("vibration"), t("on" if save.vibration else "off")]))
			list.append(_button("back", Rect2(110.0, 1060.0, 500.0, 110.0), t("back")))
		Screen.LOADOUT:
			var ball_ids := Balls.ids()
			for i in ball_ids.size():
				var id := ball_ids[i]
				var rect := Rect2(50.0 + (i % 2) * 315.0, 145.0 + (i / 2) * 104.0, 305.0, 94.0)
				var style := "selected" if save.ball_type == id else ("normal" if save.is_ball_unlocked(id) else "disabled")
				list.append(_button("ball_" + id, rect, t("ball_" + id) if save.is_ball_unlocked(id) else t("locked"), style))
			if save.max_tier() > 0:
				list.append(_button("tier_down", Rect2(50.0, 660.0, 110.0, 80.0), "<", "normal" if save.tier > 0 else "disabled"))
				list.append(_button("tier_up", Rect2(560.0, 660.0, 110.0, 80.0), ">", "normal" if save.tier < save.max_tier() else "disabled"))
			list.append(_button("go", Rect2(110.0, 990.0, 500.0, 120.0), t("go"), "primary"))
			list.append(_button("back", Rect2(160.0, 1125.0, 400.0, 90.0), t("back")))
		Screen.SHOP, Screen.ACHIEVEMENTS:
			list.append(_button("back", Rect2(160.0, 1120.0, 400.0, 100.0), t("back")))
		Screen.CODEX:
			for i in CODEX_TABS.size():
				var tab := CODEX_TABS[i]
				var rect := Rect2(50.0 + i * 210.0, 120.0, 200.0, 75.0)
				list.append(_button("tab_" + tab, rect, t("codex_" + tab), "selected" if codex_tab == tab else "normal"))
			list.append(_button("back", Rect2(160.0, 1120.0, 400.0, 100.0), t("back")))
		Screen.PRESTIGE:
			if confirm_prestige:
				list.append(_button("prestige_yes", Rect2(70.0, 720.0, 280.0, 110.0), t("yes"), "primary"))
				list.append(_button("prestige_no", Rect2(370.0, 720.0, 280.0, 110.0), t("no")))
			else:
				var style := "primary" if save.can_prestige() else "disabled"
				list.append(_button("prestige_do", Rect2(110.0, 800.0, 500.0, 130.0), t("prestige_do"), style))
				list.append(_button("back", Rect2(160.0, 1120.0, 400.0, 100.0), t("back")))
	return list


## Handles buttons that only change menu state. Returns true when it consumed the id.
func press(id: String) -> bool:
	if id.begins_with("ball_"):
		var ball := id.trim_prefix("ball_")
		if save.is_ball_unlocked(ball):
			save.ball_type = ball
			save.save_file()
		return true
	if id.begins_with("tab_"):
		codex_tab = id.trim_prefix("tab_")
		scroll = 0.0
		return true
	match id:
		"tier_up", "tier_down":
			save.set_tier(int(save.tier) + (1 if id == "tier_up" else -1))
			save.save_file()
		"prestige_do":
			if save.can_prestige():
				confirm_prestige = true
		"prestige_no":
			confirm_prestige = false
		"prestige_yes":
			confirm_prestige = false
			save.prestige()
			host.on_progress_changed()
		_:
			return false
	return true


func list_height(screen: int) -> float:
	var rows := 0
	var row_h := 100.0
	match screen:
		Screen.SHOP:
			rows = Shop.ids().size()
			row_h = 120.0
		Screen.ACHIEVEMENTS:
			rows = _achievement_rows.size()
			row_h = 96.0
		Screen.CODEX:
			rows = _codex_ids().size()
			row_h = 112.0
	return rows * (row_h + ROW_GAP)


func scroll_by(screen: int, amount: float) -> void:
	var limit := maxf(list_height(screen) - (LIST_BOTTOM - LIST_TOP), 0.0)
	scroll = clampf(scroll - amount, 0.0, limit)


func tap_list(screen: int, p: Vector2) -> void:
	if screen != Screen.SHOP or p.y < LIST_TOP or p.y > LIST_BOTTOM:
		return
	var index := int((p.y - LIST_TOP + scroll) / (120.0 + ROW_GAP))
	var ids := Shop.ids()
	if index >= 0 and index < ids.size() and save.buy(ids[index]):
		host.on_shop_bought()


## Screen position of a shop row, for the end-to-end check.
func shop_row_center(id: String) -> Vector2:
	return Vector2(BASE_W / 2.0, LIST_TOP + Shop.ids().find(id) * (120.0 + ROW_GAP) + 60.0 - scroll)


func draw(screen: int) -> void:
	match screen:
		Screen.TITLE:
			_draw_title()
		Screen.HOWTO:
			_draw_howto()
		Screen.SETTINGS:
			_draw_settings()
		Screen.LOADOUT:
			_draw_loadout()
		Screen.SHOP:
			_draw_shop()
		Screen.ACHIEVEMENTS:
			_draw_achievements()
		Screen.CODEX:
			_draw_codex()
		Screen.PRESTIGE:
			_draw_prestige()


func draw_buttons(list: Array[Dictionary], time: float) -> void:
	for button in list:
		var rect: Rect2 = button["rect"]
		var label := String(button["label"])
		match String(button["style"]):
			"icon":
				var c := rect.get_center()
				host.draw_rect(Rect2(c + Vector2(-13.0, -15.0), Vector2(9.0, 30.0)), COLOR_LABEL)
				host.draw_rect(Rect2(c + Vector2(4.0, -15.0), Vector2(9.0, 30.0)), COLOR_LABEL)
			"primary":
				var pulse := 0.5 + sin(time * 4.0) * 0.5
				host.draw_rect(rect, COLOR_ACCENT.lerp(Color("ff8ca0"), pulse * 0.4))
				host.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 8.0)), Color(1.0, 1.0, 1.0, 0.3))
				host.text_center(rect.get_center(), label, host.fit_size(label, 52, rect.size.x - 24.0), Color.WHITE)
			"selected":
				host.draw_rect(rect, COLOR_COIN)
				host.text_center(rect.get_center(), label, host.fit_size(label, 34, rect.size.x - 20.0), COLOR_BG)
			"disabled":
				host.draw_rect(rect, Color(COLOR_BUTTON, 0.45))
				host.text_center(rect.get_center(), label, host.fit_size(label, 34, rect.size.x - 20.0), Color(COLOR_LABEL, 0.6))
			_:
				host.draw_rect(rect, COLOR_BUTTON)
				host.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6.0)), Color(1.0, 1.0, 1.0, 0.12))
				host.text_center(rect.get_center(), label, host.fit_size(label, 34, rect.size.x - 20.0), Color.WHITE)
		if button["id"] == "shop" and _any_purchase_available():
			host.draw_circle(rect.position + Vector2(rect.size.x - 16.0, 16.0), 10.0, COLOR_ACCENT)
		if button["id"] == "prestige" and save.can_prestige():
			host.draw_circle(rect.position + Vector2(rect.size.x - 16.0, 16.0), 10.0, COLOR_STAR)


func _any_purchase_available() -> bool:
	for id in Shop.ids():
		if save.can_buy(id):
			return true
	return false


func _wallet_line(y: float) -> void:
	host.draw_circle(Vector2(BASE_W / 2.0 - 130.0, y), 14.0, COLOR_COIN)
	host.text_center(Vector2(BASE_W / 2.0 - 60.0, y), num(save.coins), 36, COLOR_COIN)
	if int(save.stars) > 0:
		host.text_center(Vector2(BASE_W / 2.0 + 90.0, y), "%s %d" % [t("stars"), save.stars], 32, COLOR_STAR)


func _draw_title() -> void:
	# Drifting blocks and balls keep the title alive without any art assets.
	var time: float = host.time
	for i in 16:
		var speed := 30.0 + i * 6.0
		var x := fmod(i * 137.0, 660.0) + 10.0
		var y := fmod(time * speed + i * 211.0, BASE_H + 400.0) - 200.0
		var color := Color.from_hsv(fmod(i * 0.13 + time * 0.02, 1.0), 0.7, 0.95, 0.2)
		if i % 4 == 0:
			host.draw_circle(Vector2(x, y), 14.0, Color(1.0, 1.0, 1.0, 0.22))
		else:
			host.draw_rect(Rect2(x, y, 84.0, 54.0), color)
	var pop := 1.0 + sin(time * 3.0) * 0.015
	var hue_color := Color.from_hsv(fmod(time * 0.08, 1.0), 0.45, 1.0)
	host.text_outlined(Vector2(BASE_W / 2.0, 110.0), t("game_title"), int(host.fit_size(t("game_title"), 72, 640.0) * pop), hue_color)
	host.text_outlined(Vector2(BASE_W / 2.0, 195.0), t("tagline"), 34, COLOR_COIN)
	_wallet_line(255.0)
	host.draw_rect(Rect2(90.0, 295.0, 540.0, 190.0), Color(0.05, 0.04, 0.14, 0.82))
	host.text_center(Vector2(BASE_W / 2.0, 325.0), t("records"), 28, COLOR_LABEL)
	var rows := [
		["rec_damage", num(save.best_damage)],
		["rec_combo", num(save.stat_value("best_combo"))],
		["rec_tier", str(save.max_tier())],
	]
	for i in rows.size():
		host.row(Vector2(125.0, 370.0 + i * 42.0), 470.0, t(rows[i][0]), rows[i][1], 28, Color.WHITE)


func _draw_howto() -> void:
	host.text_outlined(Vector2(BASE_W / 2.0, 170.0), t("howto"), 64, COLOR_COIN)
	var colors := [Color("4fd1ff"), COLOR_OK, COLOR_COIN, COLOR_ACCENT, Color("b48cff")]
	for i in 5:
		var y := 300.0 + i * 140.0
		host.draw_rect(Rect2(50.0, y - 50.0, 620.0, 110.0), COLOR_FIELD)
		host.draw_rect(Rect2(50.0, y - 50.0, 90.0, 110.0), colors[i])
		host.text_center(Vector2(95.0, y + 4.0), str(i + 1), 50, COLOR_BG)
		var line := t("howto_%d" % (i + 1))
		host.text_center(Vector2(405.0, y + 4.0), line, host.fit_size(line, 30, 510.0), Color.WHITE)


func _draw_settings() -> void:
	host.text_outlined(Vector2(BASE_W / 2.0, 170.0), t("settings"), 64, COLOR_COIN)
	host.text_center(Vector2(BASE_W / 2.0, 295.0), t("language"), 34, COLOR_LABEL)


func _draw_loadout() -> void:
	host.text_outlined(Vector2(BASE_W / 2.0, 80.0), t("loadout"), 56, COLOR_COIN)
	var ball_ids := Balls.ids()
	for i in ball_ids.size():
		var id := ball_ids[i]
		if save.is_ball_unlocked(id):
			var dot := Vector2(50.0 + (i % 2) * 315.0 + 30.0, 145.0 + (i / 2) * 104.0 + 47.0)
			host.draw_circle(dot, 14.0, Color(String(Balls.BALLS[id]["color"])))
	var desc := t("ball_%s_desc" % save.ball_type)
	host.text_center(Vector2(BASE_W / 2.0, 620.0), desc, host.fit_size(desc, 30, 660.0), Color.WHITE)
	var tier: int = save.tier
	var label := t("tier_label") % tier
	host.text_center(Vector2(BASE_W / 2.0, 700.0), label, 44, COLOR_ACCENT if tier > 0 else Color.WHITE)
	if tier == 0:
		host.text_center(Vector2(BASE_W / 2.0, 780.0), t("tier_base"), 30, COLOR_LABEL)
		return
	var hp_text := t("tier_hp") % _scale_text(Tiers.hp_scale(tier))
	var coin_text := t("tier_coins") % _scale_text(Tiers.coin_scale(tier))
	host.text_center(Vector2(BASE_W / 2.0, 775.0), "%s    %s" % [hp_text, coin_text], 28, COLOR_COIN)
	# Space for the newest rules; older ones keep applying.
	var active: Array[String] = []
	for i in mini(tier, Tiers.RULES.size()):
		active.append(Tiers.RULES[i])
	var shown := active.slice(maxi(active.size() - 4, 0))
	for i in shown.size():
		var line := t("tier_rule_" + shown[i])
		host.text_center(Vector2(BASE_W / 2.0, 825.0 + i * 38.0), line, host.fit_size(line, 26, 640.0), COLOR_LABEL)


func _scale_text(value: float) -> String:
	return "%.1f" % value if value < 100.0 else num(int(value))


## Draws the list body. Header and footer drawn afterward cover rows scrolled past the edges.
func _draw_list_frame(title: String, top_extra := "") -> void:
	host.draw_rect(Rect2(-80.0, -host.y_offset - 80.0, BASE_W + 160.0, host.y_offset + 80.0 + LIST_TOP), COLOR_BG)
	host.draw_rect(Rect2(-80.0, LIST_BOTTOM, BASE_W + 160.0, BASE_H), COLOR_BG)
	host.text_outlined(Vector2(BASE_W / 2.0, 70.0), title, 52, COLOR_COIN)
	if top_extra != "":
		host.text_center(Vector2(BASE_W / 2.0, 170.0), top_extra, 30, COLOR_LABEL)


func _draw_shop() -> void:
	var ids := Shop.ids()
	for i in ids.size():
		var y := LIST_TOP + i * (120.0 + ROW_GAP) - scroll
		if y > LIST_BOTTOM or y + 120.0 < LIST_TOP:
			continue
		var id := ids[i]
		var level: int = save.shop_level(id)
		var maxed: bool = level >= int(Shop.ITEMS[id]["max"])
		var buyable: bool = save.can_buy(id)
		host.draw_rect(Rect2(40.0, y, 640.0, 120.0), COLOR_BUTTON if buyable else COLOR_FIELD)
		host.draw_rect(Rect2(40.0, y, 10.0, 120.0), COLOR_COIN if buyable else COLOR_LABEL)
		host.text_left(Vector2(70.0, y + 36.0), t("shop_" + id), 32, Color.WHITE)
		var desc := t("shop_%s_desc" % id)
		host.text_left(Vector2(70.0, y + 84.0), desc, host.fit_size(desc, 26, 410.0), COLOR_LABEL)
		host.text_center(Vector2(570.0, y + 36.0), t("level") % level, 26, COLOR_LABEL)
		var price: String = t("max_level") if maxed else num(save.shop_cost(id))
		var price_color: Color = COLOR_OK if maxed else (COLOR_COIN if buyable else Color(COLOR_COIN, 0.45))
		host.text_center(Vector2(570.0, y + 84.0), price, 34, price_color)
	_draw_list_frame(t("shop"))
	_wallet_line(150.0)


func _draw_achievements() -> void:
	for i in _achievement_rows.size():
		var y := LIST_TOP + i * (96.0 + ROW_GAP) - scroll
		if y > LIST_BOTTOM or y + 96.0 < LIST_TOP:
			continue
		var entry := _achievement_rows[i]
		var stat: String = entry["stat"]
		var target: int = entry["target"]
		var done: bool = save.has_achievement(entry["id"])
		host.draw_rect(Rect2(40.0, y, 640.0, 96.0), COLOR_FIELD)
		var name_key := "ach_" + stat
		var title := t(name_key)
		if title.contains("%s"):
			title = title % num(target)
		host.text_left(Vector2(62.0, y + 28.0), title, host.fit_size(title, 28, 400.0), COLOR_OK if done else Color.WHITE)
		var note := t("reward") % num(int(entry["reward_coins"]))
		host.text_left(Vector2(470.0, y + 28.0), note, host.fit_size(note, 20, 200.0), COLOR_COIN)
		var progress := 1.0 if done else clampf(float(save.stat_value(stat)) / float(target), 0.0, 1.0)
		host.draw_rect(Rect2(62.0, y + 60.0, 480.0, 16.0), COLOR_BG)
		host.draw_rect(Rect2(62.0, y + 60.0, 480.0 * progress, 16.0), COLOR_OK if done else COLOR_ACCENT)
		host.text_center(Vector2(610.0, y + 68.0), "%d%%" % int(progress * 100.0), 24, COLOR_LABEL)
	_draw_list_frame(t("achievements"), t("achievement_count") % [_achievements_done, _achievement_rows.size()])


func _codex_ids() -> Array[String]:
	match codex_tab:
		"balls":
			return Balls.ids()
		"blocks":
			return BLOCK_KINDS
	return Perks.ids()


func _draw_codex() -> void:
	var ids := _codex_ids()
	for i in ids.size():
		var y := LIST_TOP + i * (112.0 + ROW_GAP) - scroll
		if y > LIST_BOTTOM or y + 112.0 < LIST_TOP:
			continue
		host.draw_rect(Rect2(40.0, y, 640.0, 112.0), COLOR_FIELD)
		match codex_tab:
			"balls":
				_draw_codex_ball(ids[i], y)
			"blocks":
				_draw_codex_block(ids[i], y)
			_:
				_draw_codex_perk(ids[i], y)
	_draw_list_frame(t("codex"))
	if codex_tab == "perks":
		var seen: int = save.perks_seen.size()
		host.text_center(Vector2(BASE_W / 2.0, 1102.0), t("codex_seen") % [seen, ids.size()], 22, COLOR_LABEL)


func _draw_codex_perk(id: String, y: float) -> void:
	var perk: Dictionary = Perks.PERKS[id]
	var rarity: int = perk["rarity"]
	var color: Color = RARITY_COLORS[rarity]
	if not save.perks_seen.has(id):
		host.draw_rect(Rect2(40.0, y, 10.0, 112.0), Color(COLOR_LABEL, 0.4))
		host.text_left(Vector2(70.0, y + 34.0), t("codex_unknown"), 30, COLOR_LABEL)
		host.text_left(Vector2(70.0, y + 80.0), _perk_hint(id), 22, Color(COLOR_LABEL, 0.8))
		return
	host.draw_rect(Rect2(40.0, y, 10.0, 112.0), color)
	host.text_left(Vector2(70.0, y + 32.0), t("perk_" + id), 30, color)
	var kind: String = t("evolution") if Perks.is_evolution(id) else t("rarity_%d" % rarity)
	host.text_left(Vector2(490.0, y + 32.0), kind, 22, COLOR_LABEL)
	var desc := t("perk_%s_desc" % id).replace("\n", " ")
	host.text_left(Vector2(70.0, y + 80.0), desc, host.fit_size(desc, 24, 590.0), Color.WHITE)


func _perk_hint(id: String) -> String:
	if Perks.is_evolution(id):
		var parents: Array = Perks.PERKS[id]["requires"]
		return "%s + %s" % [t("perk_" + String(parents[0])), t("perk_" + String(parents[1]))]
	var unlock := Achievements.locks_for_perk(id)
	if unlock == "" or save.has_achievement(unlock):
		return ""
	return t("unlock_by") % achievement_title(unlock)


func achievement_title(id: String) -> String:
	for entry in Achievements.all():
		if entry["id"] == id:
			var title := t("ach_" + String(entry["stat"]))
			return title % num(int(entry["target"])) if title.contains("%s") else title
	return id


func _draw_codex_ball(id: String, y: float) -> void:
	var unlocked: bool = save.is_ball_unlocked(id)
	var color := Color(String(Balls.BALLS[id]["color"]))
	host.draw_circle(Vector2(90.0, y + 56.0), 28.0, color if unlocked else Color(COLOR_LABEL, 0.4))
	host.text_left(Vector2(140.0, y + 32.0), t("ball_" + id) if unlocked else t("codex_unknown"), 30, Color.WHITE)
	var line: String = t("ball_%s_desc" % id) if unlocked else t("unlock_by") % achievement_title(String(Balls.BALLS[id]["unlock"]))
	host.text_left(Vector2(140.0, y + 80.0), line, host.fit_size(line, 24, 530.0), COLOR_LABEL)


func _draw_codex_block(kind: String, y: float) -> void:
	host.draw_block_icon(kind, Rect2(58.0, y + 28.0, 84.0, 56.0))
	host.text_left(Vector2(170.0, y + 32.0), t("block_" + kind), 30, Color.WHITE)
	var line := t("block_%s_desc" % kind)
	host.text_left(Vector2(170.0, y + 80.0), line, host.fit_size(line, 24, 500.0), COLOR_LABEL)


func _draw_prestige() -> void:
	host.text_outlined(Vector2(BASE_W / 2.0, 150.0), t("prestige"), 72, COLOR_STAR)
	host.text_center(Vector2(BASE_W / 2.0, 260.0), t("stars_owned") % save.stars, 40, COLOR_STAR)
	host.text_center(Vector2(BASE_W / 2.0, 340.0), t("prestige_desc_1"), 32, Color.WHITE)
	host.text_center(Vector2(BASE_W / 2.0, 385.0), t("prestige_desc_2"), 32, Color.WHITE)
	host.text_center(Vector2(BASE_W / 2.0, 455.0), t("prestige_bonus"), host.fit_size(t("prestige_bonus"), 30, 640.0), COLOR_COIN)
	host.text_center(Vector2(BASE_W / 2.0, 505.0), t("prestige_keep"), host.fit_size(t("prestige_keep"), 28, 640.0), COLOR_LABEL)
	if confirm_prestige:
		host.text_outlined(Vector2(BASE_W / 2.0, 650.0), t("prestige_confirm"), 48, COLOR_ACCENT)
		return
	var line := ""
	if int(save.wins) <= 0:
		line = t("prestige_locked")
	elif not save.can_prestige():
		line = t("prestige_more")
	else:
		line = t("prestige_gain") % save.stars_on_prestige()
	host.text_center(Vector2(BASE_W / 2.0, 690.0), line, host.fit_size(line, 38, 640.0), Color.WHITE)
