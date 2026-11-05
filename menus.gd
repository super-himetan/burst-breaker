extends RefCounted
## Every screen outside the actual game: layout, drawing and tap handling.
## One button list drives both drawing and hit tests, so they can never disagree.

const I18n := preload("res://i18n.gd")
const UI := preload("res://ui_theme.gd")
const Achievements := preload("res://data/achievements.gd")
const Balls := preload("res://data/balls.gd")
const Bosses := preload("res://data/bosses.gd")
const BossArt := preload("res://boss_art.gd")
const Perks := preload("res://data/perks.gd")
const PerkArt := preload("res://perk_art.gd")
const Shop := preload("res://data/shop.gd")
const StarTree := preload("res://data/star_tree.gd")
const Tiers := preload("res://data/tiers.gd")
const GameSim := preload("res://sim/game_sim.gd")

enum Screen { TITLE, HOWTO, SETTINGS, GAME, LOADOUT, SHOP, ACHIEVEMENTS, CODEX, PRESTIGE, STARS }

const BASE_W := 720.0
const BASE_H := 1280.0
const LIST_TOP := 215.0
const LIST_BOTTOM := 1095.0
const ROW_GAP := 12.0
const SHOP_ROW_H := 118.0
const ACHIEVEMENT_ROW_H := 98.0
const CODEX_ROW_H := 110.0
const BLOCK_KINDS: Array[String] = ["normal", "bomb", "shield", "regen", "armor", "treasure", "breeder", "extra_ball", "boss"]
const CODEX_TABS: Array[String] = ["perks", "balls", "blocks", "bosses"]
const BOSS_SILHOUETTE := Color(0.0, 0.0, 0.0, 0.45)
const HOWTO_STEPS := 6
const BUY_ALL_STEP := 0.07
const MILESTONE_HOLD := 0.55
const MILESTONE_SECONDS := 1.3
const ROW_FLASH_SECONDS := 0.35
const STAR_INDENT := 30.0
const BRANCH_COLORS := {"attack": Color("ff7a8a"), "burst": Color("4fd1ff"), "fortune": Color("ffd84d")}

var host: Node2D
var save: RefCounted
var scroll := 0.0
var codex_tab := "perks"
var confirm_prestige := false
var _achievement_rows: Array[Dictionary] = []
var _achievements_done := 0
var _buying := false
var _buy_timer := 0.0
var _buy_chain := 0
var _milestone_id := ""
var _milestone_time := 0.0
var _row_flash := {}


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
	_buying = false
	_milestone_time = 0.0
	_row_flash = {}
	if screen == Screen.ACHIEVEMENTS:
		_rebuild_achievements()


func is_list_screen(screen: int) -> bool:
	return screen in [Screen.SHOP, Screen.ACHIEVEMENTS, Screen.CODEX, Screen.STARS]


func update(delta: float, screen: int) -> void:
	_milestone_time = maxf(_milestone_time - delta, 0.0)
	for id: String in _row_flash.keys():
		_row_flash[id] = float(_row_flash[id]) - delta
		if float(_row_flash[id]) <= 0.0:
			_row_flash.erase(id)
	if not _buying or screen != Screen.SHOP:
		return
	_buy_timer -= delta
	if _buy_timer > 0.0:
		return
	var id: String = save.cheapest_item()
	if id == "":
		_buying = false
		return
	_buy_chain += 1
	_buy_timer = BUY_ALL_STEP
	_buy_item(id)
	if _milestone_time > 0.0:
		_buy_timer = MILESTONE_HOLD


func _buy_item(id: String) -> void:
	if not save.buy(id):
		return
	_row_flash[id] = ROW_FLASH_SECONDS
	if Shop.is_milestone(id, save.shop_level(id)):
		_milestone_id = id
		_milestone_time = MILESTONE_SECONDS
	host.on_shop_bought(id, _buy_chain)


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
			list.append(_button("start", Rect2(90.0, 560.0, 540.0, 130.0), t("start"), "primary"))
			var grid: Array[String] = ["shop", "achievements", "codex", "prestige", "howto", "settings"]
			for i in grid.size():
				var rect := Rect2(90.0 + (i % 2) * 280.0, 712.0 + (i / 2) * 106.0, 260.0, 92.0)
				list.append(_button(grid[i], rect, t(grid[i])))
		Screen.HOWTO:
			list.append(_button("back", Rect2(160.0, 1090.0, 400.0, 96.0), t("back")))
		Screen.SETTINGS:
			list.append(_button("lang_ja", Rect2(70.0, 340.0, 280.0, 100.0), "日本語", "selected" if save.lang == "ja" else "normal"))
			list.append(_button("lang_en", Rect2(370.0, 340.0, 280.0, 100.0), "English", "selected" if save.lang == "en" else "normal"))
			_add_volume_buttons(list, "sound", 490.0, save.sfx_volume)
			_add_volume_buttons(list, "music", 610.0, save.music_volume)
			list.append(_button("vibration", Rect2(70.0, 730.0, 580.0, 100.0), "%s : %s" % [t("vibration"), t("on" if save.vibration else "off")]))
			list.append(_button("reduce_fx", Rect2(70.0, 850.0, 580.0, 100.0), "%s : %s" % [t("reduce_fx"), t("on" if save.reduce_fx else "off")]))
			list.append(_button("back", Rect2(160.0, 1090.0, 400.0, 96.0), t("back")))
		Screen.LOADOUT:
			var ball_ids := Balls.ids()
			for i in ball_ids.size():
				var id := ball_ids[i]
				var rect := Rect2(50.0 + (i % 2) * 315.0, 145.0 + (i / 2) * 104.0, 305.0, 92.0)
				var style := "selected" if save.ball_type == id else ("normal" if save.is_ball_unlocked(id) else "disabled")
				list.append(_button("ball_" + id, rect, _ball_label(id), style))
			if save.max_tier() > 0:
				list.append(_button("tier_down", Rect2(50.0, 660.0, 100.0, 80.0), "<", "normal" if save.tier > 0 else "disabled"))
				list.append(_button("tier_up", Rect2(570.0, 660.0, 100.0, 80.0), ">", "normal" if save.tier < save.max_tier() else "disabled"))
			list.append(_button("go", Rect2(90.0, 990.0, 540.0, 120.0), t("go"), "primary"))
			list.append(_button("back", Rect2(180.0, 1128.0, 360.0, 84.0), t("back")))
		Screen.SHOP:
			list.append(_button("buy_all", Rect2(60.0, 1120.0, 290.0, 92.0), t("buy_all"), "normal" if save.cheapest_item() != "" else "disabled"))
			list.append(_button("back", Rect2(370.0, 1120.0, 290.0, 92.0), t("back")))
		Screen.ACHIEVEMENTS:
			list.append(_button("back", Rect2(180.0, 1120.0, 360.0, 92.0), t("back")))
		Screen.STARS:
			list.append(_button("stars_reset", Rect2(60.0, 1120.0, 290.0, 92.0), t("stars_reset"), "normal" if not save.star_nodes.is_empty() else "disabled"))
			list.append(_button("back", Rect2(370.0, 1120.0, 290.0, 92.0), t("back")))
		Screen.CODEX:
			for i in CODEX_TABS.size():
				var tab := CODEX_TABS[i]
				var rect := Rect2(40.0 + i * 162.0, 122.0, 152.0, 70.0)
				list.append(_button("tab_" + tab, rect, t("codex_" + tab), "selected" if codex_tab == tab else "normal"))
			list.append(_button("back", Rect2(180.0, 1120.0, 360.0, 92.0), t("back")))
		Screen.PRESTIGE:
			if confirm_prestige:
				list.append(_button("prestige_yes", Rect2(70.0, 720.0, 280.0, 110.0), t("yes"), "primary"))
				list.append(_button("prestige_no", Rect2(370.0, 720.0, 280.0, 110.0), t("no")))
			else:
				var style := "primary" if save.can_prestige() else "disabled"
				list.append(_button("prestige_do", Rect2(90.0, 780.0, 540.0, 130.0), t("prestige_do"), style))
				list.append(_button("stars", Rect2(90.0, 930.0, 540.0, 100.0), t("stars_tree"), "normal" if int(save.stars) > 0 else "disabled"))
				list.append(_button("back", Rect2(180.0, 1120.0, 360.0, 92.0), t("back")))
	return list


func _add_volume_buttons(list: Array[Dictionary], id: String, y: float, volume: int) -> void:
	list.append(_button(id + "_down", Rect2(70.0, y, 110.0, 100.0), "−", "normal" if volume > 0 else "disabled"))
	list.append(_button(id + "_up", Rect2(540.0, y, 110.0, 100.0), "+", "normal" if volume < save.VOLUME_MAX else "disabled"))


func _draw_volume(key: String, y: float, volume: int) -> void:
	var value: String = t("off") if volume == 0 else "%d%%" % (volume * 100 / int(save.VOLUME_MAX))
	var label := "%s : %s" % [t(key), value]
	host.panel(Rect2(70.0, y, 580.0, 100.0), UI.PANEL, 50.0, UI.LINE, 2)
	host.text_center(Vector2(BASE_W / 2.0, y + 50.0), label, host.fit_size(label, 30, 340.0), UI.TEXT)


func _ball_label(id: String) -> String:
	if not save.is_ball_unlocked(id):
		return t("locked")
	var level: int = save.mastery_level(id)
	return t("ball_" + id) if level == 0 else "%s  Lv%d" % [t("ball_" + id), level]


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
		"buy_all":
			if save.cheapest_item() != "":
				_buying = true
				_buy_timer = 0.0
				_buy_chain = 0
		"stars_reset":
			save.reset_stars()
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
	match screen:
		Screen.SHOP:
			return save.shop_ids().size() * (SHOP_ROW_H + ROW_GAP)
		Screen.STARS:
			return StarTree.ids().size() * (SHOP_ROW_H + ROW_GAP)
		Screen.ACHIEVEMENTS:
			return _achievement_rows.size() * (ACHIEVEMENT_ROW_H + ROW_GAP)
		Screen.CODEX:
			return _codex_ids().size() * (CODEX_ROW_H + ROW_GAP)
	return 0.0


func scroll_by(screen: int, amount: float) -> void:
	var limit := maxf(list_height(screen) - (LIST_BOTTOM - LIST_TOP), 0.0)
	scroll = clampf(scroll - amount, 0.0, limit)


func tap_list(screen: int, p: Vector2) -> void:
	if p.y < LIST_TOP or p.y > LIST_BOTTOM or not screen in [Screen.SHOP, Screen.STARS]:
		return
	var index := int((p.y - LIST_TOP + scroll) / (SHOP_ROW_H + ROW_GAP))
	var ids: Array[String] = save.shop_ids() if screen == Screen.SHOP else StarTree.ids()
	if index < 0 or index >= ids.size():
		return
	if screen == Screen.STARS:
		if save.raise_star(ids[index]):
			_row_flash[ids[index]] = ROW_FLASH_SECONDS
			host.on_star_raised()
		return
	_buy_chain = 0
	_buy_item(ids[index])


## Screen position of a shop row, for the end-to-end check.
func shop_row_center(id: String) -> Vector2:
	return Vector2(BASE_W / 2.0, LIST_TOP + save.shop_ids().find(id) * (SHOP_ROW_H + ROW_GAP) + SHOP_ROW_H / 2.0 - scroll)


## Everything fixed on screen. Scrolling rows are drawn separately by draw_list, clipped.
func draw(screen: int) -> void:
	match screen:
		Screen.TITLE:
			_draw_title()
		Screen.HOWTO:
			_draw_howto()
		Screen.SETTINGS:
			_heading(t("settings"), 130.0)
			host.text_center(Vector2(BASE_W / 2.0, 295.0), t("language"), 24, UI.MUTED, host.font_label)
			_draw_volume("sound", 490.0, save.sfx_volume)
			_draw_volume("music", 610.0, save.music_volume)
		Screen.LOADOUT:
			_draw_loadout()
		Screen.SHOP:
			_heading(t("shop"), 58.0)
			_wallet_line(128.0)
			var power := t("power_rating") % num(save.power_rating())
			host.text_center(Vector2(BASE_W / 2.0, 178.0), power, 26, UI.MINT)
			_draw_milestone()
		Screen.STARS:
			_heading(t("stars_tree"), 66.0)
			var left := t("stars_left") % [save.star_points_left(), save.stars]
			host.text_center(Vector2(BASE_W / 2.0, 150.0), left, host.fit_size(left, 30, 620.0), UI.STAR)
		Screen.ACHIEVEMENTS:
			_heading(t("achievements"), 66.0)
			host.text_center(Vector2(BASE_W / 2.0, 160.0), t("achievement_count") % [_achievements_done, _achievement_rows.size()], 26, UI.MUTED, host.font_body)
		Screen.CODEX:
			_heading(t("codex"), 58.0)
			if codex_tab == "perks":
				host.text_center(Vector2(BASE_W / 2.0, 1106.0), t("codex_seen") % [save.perks_seen.size(), _codex_ids().size()], 20, UI.MUTED, host.font_body)
		Screen.PRESTIGE:
			_draw_prestige()


func _heading(title: String, y: float) -> void:
	host.text_center(Vector2(BASE_W / 2.0, y), title, host.fit_size(title, 54, 640.0), UI.TEXT)


func draw_list(screen: int) -> void:
	match screen:
		Screen.SHOP:
			_draw_shop()
		Screen.ACHIEVEMENTS:
			_draw_achievements()
		Screen.CODEX:
			_draw_codex()
		Screen.STARS:
			_draw_star_tree()


func draw_buttons(list: Array[Dictionary], time: float) -> void:
	for button in list:
		var rect: Rect2 = button["rect"]
		var label := String(button["label"])
		var radius := rect.size.y / 2.0
		match String(button["style"]):
			"icon":
				var c := rect.get_center()
				host.panel(Rect2(c + Vector2(-12.0, -14.0), Vector2(7.0, 28.0)), UI.MUTED, 3.5)
				host.panel(Rect2(c + Vector2(5.0, -14.0), Vector2(7.0, 28.0)), UI.MUTED, 3.5)
			"primary":
				var pulse := 0.5 + sin(time * 3.0) * 0.5
				host.soft_glow(rect.get_center(), rect.size * Vector2(1.3, 2.2), Color(UI.ACCENT, 0.22 + pulse * 0.2))
				host.panel(rect, UI.ACCENT, radius)
				host.panel(Rect2(rect.position + Vector2(10.0, 7.0), Vector2(rect.size.x - 20.0, rect.size.y * 0.42)), Color(1.0, 1.0, 1.0, 0.13), radius * 0.75)
				host.text_center(rect.get_center(), label, host.fit_size(label, 48, rect.size.x - 60.0), Color.WHITE)
			"burst":
				var color: Color = UI.ramp(fmod(time * 0.5, 1.0))
				var beat := 0.5 + sin(time * 8.0) * 0.5
				host.soft_glow(rect.get_center(), rect.size * Vector2(1.5, 2.8), Color(color, 0.45 + beat * 0.35))
				host.panel(rect.grow(beat * 4.0), color, radius + beat * 4.0, Color.WHITE, 3)
				host.text_center(rect.get_center(), label, host.fit_size(label, 44, rect.size.x - 50.0), UI.INK)
			"selected":
				host.panel(rect, UI.TEXT, radius)
				host.text_center(rect.get_center(), label, host.fit_size(label, 32, rect.size.x - 40.0), UI.INK)
			"disabled":
				host.panel(rect, Color(1.0, 1.0, 1.0, 0.03), radius, UI.LINE, 2)
				host.text_center(rect.get_center(), label, host.fit_size(label, 28, rect.size.x - 40.0), Color(UI.MUTED, 0.55), host.font_body)
			_:
				host.panel(rect, UI.PANEL, radius, UI.LINE, 2)
				host.text_center(rect.get_center(), label, host.fit_size(label, 30, rect.size.x - 40.0), UI.TEXT)
		var dot := rect.position + Vector2(rect.size.x - radius * 0.55, radius * 0.45)
		if button["id"] == "shop" and _any_purchase_available():
			host.soft_glow(dot, Vector2(44.0, 44.0), Color(UI.ACCENT, 0.7))
			host.canvas.draw_circle(dot, 8.0, UI.ACCENT)
		if button["id"] == "prestige" and (save.can_prestige() or _can_spend_stars()):
			host.soft_glow(dot, Vector2(44.0, 44.0), Color(UI.STAR, 0.7))
			host.canvas.draw_circle(dot, 8.0, UI.STAR)


func _any_purchase_available() -> bool:
	return save.cheapest_item() != ""


func _can_spend_stars() -> bool:
	for id in StarTree.ids():
		if save.can_raise_star(id):
			return true
	return false


func _draw_milestone() -> void:
	if _milestone_time <= 0.0:
		return
	var age := MILESTONE_SECONDS - _milestone_time
	var alpha := minf(_milestone_time * 3.0, 1.0)
	var pop := 1.0 + maxf(0.18 - age, 0.0) * 2.0
	var center := Vector2(BASE_W / 2.0, 640.0)
	host.panel(Rect2(0.0, center.y - 110.0, BASE_W, 220.0), Color(UI.INK, 0.85 * alpha), 0.0)
	host.soft_glow(center, Vector2(1000.0, 460.0), Color(UI.GOLD, 0.3 * alpha))
	var title := t("level") % save.shop_level(_milestone_id) + "  " + t("shop_" + _milestone_id)
	host.text_shadowed(center + Vector2(0.0, -44.0), title, int(host.fit_size(title, 46, 640.0) * pop), Color(UI.TEXT, alpha))
	var bonus := t("shop_%s_bonus" % _milestone_id)
	host.text_shadowed(center + Vector2(0.0, 28.0), bonus, int(host.fit_size(bonus, 64, 640.0) * pop), Color(UI.GOLD, alpha))


func _draw_star_tree() -> void:
	var ids := StarTree.ids()
	for i in ids.size():
		var y := LIST_TOP + i * (SHOP_ROW_H + ROW_GAP) - scroll
		if y > LIST_BOTTOM or y + SHOP_ROW_H < LIST_TOP:
			continue
		var id := ids[i]
		var node: Dictionary = StarTree.NODES[id]
		var level: int = save.star_level(id)
		var opened: bool = save.is_star_node_open(id)
		var can_raise: bool = save.can_raise_star(id)
		var color: Color = BRANCH_COLORS[node["branch"]]
		var indent := StarTree.depth(id) * STAR_INDENT
		var rect := Rect2(40.0 + indent, y, 640.0 - indent, SHOP_ROW_H)
		host.panel(rect, UI.PANEL, 26.0, Color(color, 0.8) if can_raise else UI.LINE, 2)
		if _row_flash.has(id):
			host.panel(rect, Color(color, 0.35 * float(_row_flash[id]) / ROW_FLASH_SECONDS), 26.0)
		host.panel(Rect2(rect.position + Vector2(14.0, 22.0), Vector2(8.0, SHOP_ROW_H - 44.0)), color if opened else Color(color, 0.25), 4.0)
		var title_color: Color = UI.TEXT if opened else Color(UI.MUTED, 0.7)
		var name_width := 400.0 - indent
		var title := t("star_" + id)
		host.text_left(Vector2(rect.position.x + 36.0, y + 40.0), title, host.fit_size(title, 30, name_width), title_color)
		var desc: String = t("star_%s_desc" % id) if opened else t("star_locked") % t("star_" + String(node["requires"]))
		host.text_left(Vector2(rect.position.x + 36.0, y + 82.0), desc, host.fit_size(desc, 23, name_width), UI.MUTED, host.font_body)
		host.text_center(Vector2(586.0, y + 36.0), "%d / %d" % [level, int(node["max"])], 22, UI.MUTED, host.font_body)
		var maxed := level >= int(node["max"])
		var price: String = t("max_level") if maxed else t("star_cost") % int(node["cost"])
		var price_color: Color = UI.MINT if maxed else (UI.STAR if can_raise else Color(UI.STAR, 0.4))
		host.text_center(Vector2(586.0, y + 78.0), price, 30, price_color)


func _wallet_line(y: float) -> void:
	var coins_text := num(save.coins)
	var stars_text := "" if int(save.stars) <= 0 else "%s %d" % [t("stars"), save.stars]
	var coins_w: float = host.font.get_string_size(coins_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var stars_w: float = 0.0 if stars_text == "" else host.font.get_string_size(stars_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 40.0
	var x := BASE_W / 2.0 - (coins_w + 34.0 + stars_w) / 2.0
	host.canvas.draw_circle(Vector2(x + 13.0, y), 13.0, UI.GOLD)
	host.text_left(Vector2(x + 34.0, y), coins_text, 32, UI.GOLD)
	if stars_text != "":
		host.text_left(Vector2(x + 34.0 + coins_w + 40.0, y), stars_text, 26, UI.STAR)


func _draw_title() -> void:
	# Soft floating blocks keep the title alive without any art assets.
	var time: float = host.time
	for i in 12:
		var speed := 16.0 + i * 3.0
		var x := fmod(i * 137.0, 620.0) + 20.0
		var y := fmod(time * speed + i * 211.0, BASE_H + 400.0) - 200.0
		var color: Color = UI.RAMP[i % UI.RAMP.size()]
		host.panel(Rect2(x, y, 84.0, 54.0), Color(color, 0.1), 12.0)
	var line_1 := t("title_line_1")
	var line_2 := t("title_line_2")
	var pulse := 0.5 + sin(time * 1.6) * 0.5
	var glow_color: Color = UI.ramp(fmod(time * 0.06, 1.0))
	host.soft_glow(Vector2(BASE_W / 2.0, 150.0), Vector2(860.0, 420.0), Color(glow_color, 0.2 + pulse * 0.1))
	host.text_center(Vector2(BASE_W / 2.0, 95.0), line_1, host.fit_size(line_1, 104, 640.0), UI.TEXT)
	host.text_center(Vector2(BASE_W / 2.0, 205.0), line_2, host.fit_size(line_2, 104, 640.0), glow_color.lerp(UI.TEXT, 0.25))
	host.text_center(Vector2(BASE_W / 2.0, 295.0), t("tagline"), host.fit_size(t("tagline"), 28, 620.0), UI.MUTED, host.font_body)
	_wallet_line(355.0)
	host.panel(Rect2(90.0, 395.0, 540.0, 145.0), UI.PANEL, 28.0, UI.LINE, 2)
	var rows := [
		["rec_damage", num(save.best_damage)],
		["rec_combo", num(save.stat_value("best_combo"))],
		["rec_tier", str(save.max_tier())],
	]
	for i in rows.size():
		host.row(Vector2(122.0, 428.0 + i * 40.0), 476.0, t(rows[i][0]), rows[i][1], 25, UI.TEXT)


func _draw_howto() -> void:
	_heading(t("howto"), 130.0)
	for i in HOWTO_STEPS:
		var y := 220.0 + i * 140.0
		host.panel(Rect2(50.0, y, 620.0, 124.0), UI.PANEL, 28.0, UI.LINE, 2)
		var color: Color = UI.RAMP[i % UI.RAMP.size()]
		host.canvas.draw_circle(Vector2(112.0, y + 62.0), 34.0, color)
		host.text_center(Vector2(112.0, y + 64.0), str(i + 1), 34, UI.INK)
		var line := t("howto_%d" % (i + 1))
		host.text_left(Vector2(170.0, y + 62.0), line, host.fit_size(line, 30, 480.0), UI.TEXT)


func _draw_loadout() -> void:
	_heading(t("loadout"), 76.0)
	var ball_ids := Balls.ids()
	for i in ball_ids.size():
		var id := ball_ids[i]
		if save.is_ball_unlocked(id):
			var dot := Vector2(50.0 + (i % 2) * 315.0 + 38.0, 145.0 + (i / 2) * 104.0 + 46.0)
			host.soft_glow_deferred(dot, String(Balls.BALLS[id]["color"]))
	_draw_mastery(578.0)
	var desc := t("ball_%s_desc" % save.ball_type)
	host.text_center(Vector2(BASE_W / 2.0, 612.0), desc, host.fit_size(desc, 28, 640.0), UI.TEXT, host.font_body)
	var move := t("burst_move") % t("burst_" + String(save.ball_type))
	host.text_center(Vector2(BASE_W / 2.0, 652.0), move, host.fit_size(move, 23, 640.0), UI.GOLD)
	var tier: int = save.tier
	var label := t("tier_label") % tier
	host.text_center(Vector2(BASE_W / 2.0, 700.0), label, 42, UI.ACCENT if tier > 0 else UI.TEXT)
	if tier == 0:
		host.text_center(Vector2(BASE_W / 2.0, 790.0), t("tier_base"), 26, UI.MUTED, host.font_body)
		return
	var hp_text := t("tier_hp") % _scale_text(Tiers.hp_scale(tier))
	var coin_text := t("tier_coins") % _scale_text(Tiers.coin_scale(tier))
	host.text_center(Vector2(BASE_W / 2.0, 775.0), "%s    %s" % [hp_text, coin_text], 26, UI.GOLD)
	# Space for the newest rules; older ones keep applying.
	var active: Array[String] = []
	for i in mini(tier, Tiers.RULES.size()):
		active.append(Tiers.RULES[i])
	var shown := active.slice(maxi(active.size() - 4, 0))
	for i in shown.size():
		var line := t("tier_rule_" + shown[i])
		host.text_center(Vector2(BASE_W / 2.0, 825.0 + i * 36.0), line, host.fit_size(line, 24, 640.0), UI.MUTED, host.font_body)


func _draw_mastery(y: float) -> void:
	var ball: String = save.ball_type
	var level: int = save.mastery_level(ball)
	var line: String = t("mastery_line") % [level, t("ball_%s_mastery" % ball)]
	host.text_left(Vector2(50.0, y), line, host.fit_size(line, 22, 470.0), UI.MINT, host.font_body)
	var bar := Rect2(530.0, y - 6.0, 140.0, 12.0)
	var progress: float = save.mastery_progress(ball)
	host.panel(bar, Color(1.0, 1.0, 1.0, 0.08), 6.0)
	if progress > 0.0:
		host.panel(Rect2(bar.position, Vector2(maxf(bar.size.x * progress, 12.0), bar.size.y)), UI.MINT, 6.0)


func _scale_text(value: float) -> String:
	return "%.1f" % value if value < 100.0 else num(int(value))


func _draw_shop() -> void:
	var ids: Array[String] = save.shop_ids()
	for i in ids.size():
		var y := LIST_TOP + i * (SHOP_ROW_H + ROW_GAP) - scroll
		if y > LIST_BOTTOM or y + SHOP_ROW_H < LIST_TOP:
			continue
		var id := ids[i]
		var level: int = save.shop_level(id)
		var maxed: bool = level >= int(Shop.ITEMS[id]["max"])
		var buyable: bool = save.can_buy(id)
		var rect := Rect2(40.0, y, 640.0, SHOP_ROW_H)
		host.panel(rect, UI.PANEL, 26.0, Color(UI.GOLD, 0.55) if buyable else UI.LINE, 2)
		if _row_flash.has(id):
			host.panel(rect, Color(UI.GOLD, 0.35 * float(_row_flash[id]) / ROW_FLASH_SECONDS), 26.0)
		var title := t("shop_" + id)
		host.text_left(Vector2(70.0, y + 30.0), title, host.fit_size(title, 28, 390.0), UI.TEXT)
		var desc := t("shop_%s_desc" % id)
		host.text_left(Vector2(70.0, y + 64.0), desc, host.fit_size(desc, 22, 390.0), UI.MUTED, host.font_body)
		var next := Shop.next_milestone(id, level)
		if next > 0:
			var milestone := t("milestone_line") % [next, t("shop_%s_bonus" % id)]
			host.text_left(Vector2(70.0, y + 94.0), milestone, host.fit_size(milestone, 21, 390.0), UI.GOLD, host.font_body)
		host.text_center(Vector2(570.0, y + 36.0), t("level") % level, 22, UI.MUTED, host.font_body)
		var price: String = t("max_level") if maxed else num(save.shop_cost(id))
		var price_color: Color = UI.MINT if maxed else (UI.GOLD if buyable else Color(UI.GOLD, 0.45))
		host.text_center(Vector2(570.0, y + 78.0), price, 34, price_color)


func _draw_achievements() -> void:
	for i in _achievement_rows.size():
		var y := LIST_TOP + i * (ACHIEVEMENT_ROW_H + ROW_GAP) - scroll
		if y > LIST_BOTTOM or y + ACHIEVEMENT_ROW_H < LIST_TOP:
			continue
		var entry := _achievement_rows[i]
		var stat: String = entry["stat"]
		var target: int = entry["target"]
		var done: bool = save.has_achievement(entry["id"])
		host.panel(Rect2(40.0, y, 640.0, ACHIEVEMENT_ROW_H), UI.PANEL, 24.0, Color(UI.MINT, 0.4) if done else UI.LINE, 2)
		var title := t("ach_" + stat)
		if title.contains("%s"):
			title = title % num(target)
		host.text_left(Vector2(66.0, y + 32.0), title, host.fit_size(title, 26, 390.0), UI.MINT if done else UI.TEXT)
		var note := t("reward") % num(int(entry["reward_coins"]))
		host.text_right(Vector2(654.0, y + 32.0), note, host.fit_size(note, 19, 190.0), UI.GOLD, host.font_body)
		var progress := 1.0 if done else clampf(float(save.stat_value(stat)) / float(target), 0.0, 1.0)
		var bar := Rect2(66.0, y + 63.0, 490.0, 12.0)
		host.panel(bar, Color(1.0, 1.0, 1.0, 0.08), 6.0)
		if progress > 0.0:
			host.panel(Rect2(bar.position, Vector2(maxf(bar.size.x * progress, 12.0), bar.size.y)), UI.MINT if done else UI.ACCENT, 6.0)
		host.text_right(Vector2(654.0, y + 69.0), "%d%%" % int(progress * 100.0), 22, UI.MUTED, host.font_body)


func _codex_ids() -> Array[String]:
	match codex_tab:
		"balls":
			return Balls.ids()
		"blocks":
			return BLOCK_KINDS
		"bosses":
			return Bosses.ids()
	return Perks.ids()


func _draw_codex() -> void:
	var ids := _codex_ids()
	for i in ids.size():
		var y := LIST_TOP + i * (CODEX_ROW_H + ROW_GAP) - scroll
		if y > LIST_BOTTOM or y + CODEX_ROW_H < LIST_TOP:
			continue
		host.panel(Rect2(40.0, y, 640.0, CODEX_ROW_H), UI.PANEL, 24.0, UI.LINE, 2)
		match codex_tab:
			"balls":
				_draw_codex_ball(ids[i], y)
			"blocks":
				_draw_codex_block(ids[i], y)
			"bosses":
				_draw_codex_boss(ids[i], y)
			_:
				_draw_codex_perk(ids[i], y)


func _draw_codex_perk(id: String, y: float) -> void:
	var perk: Dictionary = Perks.PERKS[id]
	var rarity: int = perk["rarity"]
	var color: Color = UI.RARITY[rarity]
	if not save.perks_seen.has(id):
		host.text_left(Vector2(70.0, y + 36.0), t("codex_unknown"), 28, Color(UI.MUTED, 0.7))
		var hint := _perk_hint(id)
		if hint != "":
			host.text_left(Vector2(70.0, y + 76.0), hint, host.fit_size(hint, 22, 580.0), Color(UI.MUTED, 0.8), host.font_body)
		return
	PerkArt.draw(host.canvas, id, Vector2(92.0, y + CODEX_ROW_H / 2.0), 34.0)
	var name_text := t("perk_" + id)
	host.text_left(Vector2(142.0, y + 36.0), name_text, host.fit_size(name_text, 28, 210.0), color)
	var kind: String = t("rarity_%d" % rarity)
	if Perks.is_evolution(id):
		var parents: Array = Perks.PERKS[id]["requires"]
		kind = t("evolve_recipe") % [t("perk_" + String(parents[0])), t("perk_" + String(parents[1]))]
	host.text_right(Vector2(650.0, y + 36.0), kind, host.fit_size(kind, 20, 290.0), UI.MUTED, host.font_body)
	var desc := t("perk_%s_desc" % id).replace("\n", " ")
	host.text_left(Vector2(142.0, y + 76.0), desc, host.fit_size(desc, 23, 510.0), UI.TEXT, host.font_body)


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
	host.canvas.draw_circle(Vector2(95.0, y + 55.0), 25.0, color if unlocked else Color(UI.MUTED, 0.3))
	host.text_left(Vector2(146.0, y + 36.0), t("ball_" + id) if unlocked else t("codex_unknown"), 28, UI.TEXT)
	var line: String = t("ball_%s_desc" % id) if unlocked else t("unlock_by") % achievement_title(String(Balls.BALLS[id]["unlock"]))
	host.text_left(Vector2(146.0, y + 76.0), line, host.fit_size(line, 23, 510.0), UI.MUTED, host.font_body)


func _draw_codex_block(kind: String, y: float) -> void:
	host.draw_block_icon(kind, Rect2(62.0, y + 27.0, 84.0, 56.0))
	host.text_left(Vector2(176.0, y + 36.0), t("block_" + kind), 28, UI.TEXT)
	var line := t("block_%s_desc" % kind)
	host.text_left(Vector2(176.0, y + 76.0), line, host.fit_size(line, 23, 480.0), UI.MUTED, host.font_body)


func _draw_codex_boss(id: String, y: float) -> void:
	var portrait := Rect2(52.0, y + 16.0, 158.0, 78.0)
	if not save.bosses_met.has(id):
		host.panel(portrait, BOSS_SILHOUETTE, 18.0)
		host.text_center(portrait.get_center(), "?", 40, Color(UI.MUTED, 0.6))
		host.text_left(Vector2(228.0, y + 36.0), t("codex_unknown"), 28, Color(UI.MUTED, 0.7))
		var stage_hint := t("boss_hint_%d" % int(Bosses.BOSSES[id]["pool"]))
		host.text_left(Vector2(228.0, y + 76.0), stage_hint, host.fit_size(stage_hint, 22, 430.0), Color(UI.MUTED, 0.8), host.font_body)
		return
	BossArt.draw(host.canvas, id, portrait, "idle", host.time)
	var name_text := t("boss_%s_name" % id)
	host.text_left(Vector2(228.0, y + 30.0), name_text, host.fit_size(name_text, 28, 290.0), Bosses.color(id).lightened(0.35))
	var kills := t("boss_defeated") % save.stat_value("boss_" + id)
	host.text_right(Vector2(656.0, y + 30.0), kills, 19, UI.MUTED, host.font_label)
	var desc := t("boss_%s_desc" % id)
	host.text_left(Vector2(228.0, y + 74.0), desc, host.fit_size(desc, 22, 430.0), UI.TEXT, host.font_body)


func _draw_prestige() -> void:
	var pulse := 0.5 + sin(float(host.time) * 1.6) * 0.5
	host.soft_glow(Vector2(BASE_W / 2.0, 170.0), Vector2(620.0, 380.0), Color(UI.STAR, 0.14 + pulse * 0.1))
	host.text_center(Vector2(BASE_W / 2.0, 140.0), t("prestige"), 72, UI.STAR)
	host.text_center(Vector2(BASE_W / 2.0, 250.0), t("stars_owned") % save.stars, 36, UI.TEXT)
	host.panel(Rect2(60.0, 310.0, 600.0, 240.0), UI.PANEL, 30.0, UI.LINE, 2)
	host.text_center(Vector2(BASE_W / 2.0, 350.0), t("prestige_desc_1"), 28, UI.TEXT, host.font_body)
	host.text_center(Vector2(BASE_W / 2.0, 392.0), t("prestige_desc_2"), 28, UI.TEXT, host.font_body)
	host.text_center(Vector2(BASE_W / 2.0, 452.0), t("prestige_bonus"), host.fit_size(t("prestige_bonus"), 27, 550.0), UI.GOLD)
	host.text_center(Vector2(BASE_W / 2.0, 504.0), t("prestige_keep"), host.fit_size(t("prestige_keep"), 25, 550.0), UI.MUTED, host.font_body)
	if confirm_prestige:
		host.text_center(Vector2(BASE_W / 2.0, 650.0), t("prestige_confirm"), 44, UI.ACCENT)
		return
	var line := ""
	if int(save.wins) <= 0:
		line = t("prestige_locked")
	elif not save.can_prestige():
		line = t("prestige_more")
	else:
		line = t("prestige_gain") % save.stars_on_prestige()
	host.text_center(Vector2(BASE_W / 2.0, 680.0), line, host.fit_size(line, 34, 620.0), UI.TEXT)
