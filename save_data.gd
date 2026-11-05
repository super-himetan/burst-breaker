extends RefCounted
## Settings and long-term progress. A damaged file falls back to defaults.

const I18n := preload("res://i18n.gd")
const Achievements := preload("res://data/achievements.gd")
const Balls := preload("res://data/balls.gd")
const Perks := preload("res://data/perks.gd")
const Shop := preload("res://data/shop.gd")

const DEFAULT_PATH := "user://save.json"
const COINS_PER_STAR_SQUARED := 10000.0

var path := DEFAULT_PATH
var lang := I18n.DEFAULT_LANG
var sound := true
var vibration := true
var music := true
var reduce_fx := false
var tutorial_done := false

var coins := 0
var coins_this_life := 0
var stars := 0
var shop := {}
var best_damage := 0
var best_stage := 0
var wins := 0
var runs := 0
var lifetime := {}
var achievements := {}
var perks_seen := {}
var bosses_met := {}
var ball_type := "normal"
var tier := 0
## The latest state of a run still in progress, so closing the app cannot lose its coins.
var interrupted_run := {}


func _init(save_path := DEFAULT_PATH) -> void:
	path = save_path


func load_file() -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("Ignoring unreadable save file: %s" % path)
		return
	var data: Dictionary = parsed
	var saved_lang := String(data.get("lang", lang))
	lang = saved_lang if I18n.LANGS.has(saved_lang) else I18n.DEFAULT_LANG
	sound = bool(data.get("sound", sound))
	vibration = bool(data.get("vibration", vibration))
	music = bool(data.get("music", music))
	reduce_fx = bool(data.get("reduce_fx", reduce_fx))
	tutorial_done = bool(data.get("tutorial_done", tutorial_done))
	coins = int(data.get("coins", coins))
	coins_this_life = int(data.get("coins_this_life", coins_this_life))
	stars = int(data.get("stars", stars))
	best_damage = int(data.get("best_damage", best_damage))
	best_stage = int(data.get("best_stage", best_stage))
	wins = int(data.get("wins", wins))
	runs = int(data.get("runs", runs))
	shop = _int_map(data.get("shop", {}), Shop.ITEMS)
	lifetime = _int_map(data.get("lifetime", {}))
	achievements = _flag_map(data.get("achievements", {}))
	perks_seen = _flag_map(data.get("perks_seen", {}))
	bosses_met = _flag_map(data.get("bosses_met", {}))
	var saved_ball := String(data.get("ball_type", ball_type))
	ball_type = saved_ball if Balls.BALLS.has(saved_ball) else "normal"
	tier = int(data.get("tier", tier))
	interrupted_run = _read_run_summary(data.get("interrupted_run", {}))


## JSON turns every number into a float, and a damaged entry should not break the save.
func _read_run_summary(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	for key: String in ["damage", "combo", "best_shot", "stage", "coins", "tier"]:
		if not (value.get(key) is float or value.get(key) is int):
			return {}
	var saved_ball := String(value.get("ball_type", "normal"))
	return {
		"damage": int(value["damage"]),
		"combo": int(value["combo"]),
		"best_shot": int(value["best_shot"]),
		"stage": int(value["stage"]),
		"coins": int(value["coins"]),
		"won": false,
		"tier": int(value["tier"]),
		"ball_type": saved_ball if Balls.BALLS.has(saved_ball) else "normal",
		"counters": _int_map(value.get("counters", {})),
	}


func _int_map(value: Variant, allowed := {}) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for key: Variant in value:
			if allowed.is_empty() or allowed.has(key):
				result[String(key)] = int(value[key])
	return result


func _flag_map(value: Variant) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for key: Variant in value:
			result[String(key)] = true
	return result


func save_file() -> bool:
	# Write then rename, so a crash mid-save cannot destroy existing progress.
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file: %s" % path)
		return false
	file.store_string(JSON.stringify({
		"lang": lang,
		"sound": sound,
		"vibration": vibration,
		"music": music,
		"reduce_fx": reduce_fx,
		"tutorial_done": tutorial_done,
		"coins": coins,
		"coins_this_life": coins_this_life,
		"stars": stars,
		"shop": shop,
		"best_damage": best_damage,
		"best_stage": best_stage,
		"wins": wins,
		"runs": runs,
		"lifetime": lifetime,
		"achievements": achievements,
		"perks_seen": perks_seen,
		"bosses_met": bosses_met,
		"ball_type": ball_type,
		"tier": tier,
		"interrupted_run": interrupted_run,
	}, "  "))
	file.close()
	return DirAccess.rename_absolute(tmp, path) == OK


func stat_value(stat: String) -> int:
	return int(lifetime.get(stat, 0))


func run_config(emit_events := true) -> Dictionary:
	return {
		"ball_type": ball_type,
		"tier": tier,
		"shop": shop,
		"stars": stars,
		"unlocked_perks": unlocked_perks(),
		"tutorial_offer": runs == 0,
		"boss_met": bosses_met.keys(),
		"emit_events": emit_events,
	}


func has_achievement(id: String) -> bool:
	return achievements.has(id)


func unlocked_perks() -> Array[String]:
	var list: Array[String] = []
	for id in Perks.ids():
		if is_perk_unlocked(id):
			list.append(id)
	return list


func is_perk_unlocked(id: String) -> bool:
	if not Perks.starts_locked(id):
		return true
	return has_achievement(Achievements.locks_for_perk(id))


func is_ball_unlocked(id: String) -> bool:
	var unlock := String(Balls.BALLS[id]["unlock"])
	return unlock == "" or has_achievement(unlock)


func max_tier() -> int:
	return stat_value("best_tier")


func set_tier(value: int) -> void:
	tier = clampi(value, 0, max_tier())


func shop_level(id: String) -> int:
	return int(shop.get(id, 0))


func shop_cost(id: String) -> int:
	return Shop.cost(id, shop_level(id))


func can_buy(id: String) -> bool:
	return shop_level(id) < int(Shop.ITEMS[id]["max"]) and coins >= shop_cost(id)


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	coins -= shop_cost(id)
	shop[id] = shop_level(id) + 1
	var total_levels := 0
	for key: String in shop:
		total_levels += int(shop[key])
	lifetime["shop_levels"] = maxi(stat_value("shop_levels"), total_levels)
	return true


func stars_on_prestige() -> int:
	return int(floor(sqrt(coins_this_life / COINS_PER_STAR_SQUARED)))


func can_prestige() -> bool:
	return wins > 0 and stars_on_prestige() > 0


## Trades coins and shop levels for stars. Records, achievements and tiers are kept.
func prestige() -> bool:
	if not can_prestige():
		return false
	stars += stars_on_prestige()
	lifetime["stars"] = stars
	coins = 0
	coins_this_life = 0
	shop = {}
	return true


func mark_perk_seen(id: String) -> void:
	perks_seen[id] = true
	lifetime["perks_seen"] = perks_seen.size()


func mark_boss_met(id: String) -> void:
	bosses_met[id] = true


func stash_run(summary: Dictionary) -> void:
	interrupted_run = summary.duplicate(true)


## Banks a run the app closed on. Returns its coins, or -1 when there was no such run.
func recover_interrupted_run() -> int:
	if interrupted_run.is_empty():
		return -1
	var earned: int = interrupted_run["coins"]
	record_run(interrupted_run)
	return earned


## The closest achievement that opens a perk or a ball: {id, stat, target, progress, perk, ball}.
## Empty when everything is already open.
func next_unlock() -> Dictionary:
	var rewards := {}
	for perk: String in Achievements.PERK_UNLOCKS:
		rewards[Achievements.PERK_UNLOCKS[perk]] = {"perk": perk, "ball": ""}
	for ball: String in Balls.BALLS:
		var unlock := String(Balls.BALLS[ball]["unlock"])
		if unlock != "":
			rewards[unlock] = {"perk": "", "ball": ball}
	var best := {}
	for entry in Achievements.all():
		var id: String = entry["id"]
		if achievements.has(id) or not rewards.has(id):
			continue
		var progress := clampf(float(stat_value(entry["stat"])) / float(entry["target"]), 0.0, 1.0)
		if best.is_empty() or progress > float(best["progress"]):
			best = {"id": id, "stat": entry["stat"], "target": entry["target"], "progress": progress}
			best.merge(rewards[id])
	return best


## summary: damage, combo, best_shot, stage, coins, won, tier, ball_type, counters.
## Returns true when a personal best was beaten.
func record_run(summary: Dictionary) -> bool:
	interrupted_run = {}
	var damage: int = summary["damage"]
	var combo: int = summary["combo"]
	var best_shot: int = summary["best_shot"]
	var stage: int = summary["stage"]
	var earned: int = summary["coins"]
	var won: bool = summary["won"]
	var new_best := damage > best_damage or combo > stat_value("best_combo") or stage > best_stage
	best_damage = maxi(best_damage, damage)
	best_stage = maxi(best_stage, stage)
	coins += earned
	coins_this_life += earned
	runs += 1
	_add_stat("runs", 1)
	_add_stat("damage", damage)
	_add_stat("coins", earned)
	lifetime["best_combo"] = maxi(stat_value("best_combo"), combo)
	lifetime["best_shot"] = maxi(stat_value("best_shot"), best_shot)
	var counters: Dictionary = summary.get("counters", {})
	for key: String in counters:
		_add_stat(key, int(counters[key]))
	if won:
		wins += 1
		_add_stat("wins", 1)
		_add_stat("clears_" + String(summary["ball_type"]), 1)
		var cleared_tier: int = summary["tier"]
		lifetime["best_tier"] = maxi(stat_value("best_tier"), cleared_tier + 1)
	return new_best


func _add_stat(stat: String, amount: int) -> void:
	lifetime[stat] = stat_value(stat) + amount


## Unlocks anything newly reached and pays its reward. `live` holds the current run's
## values, so achievements can pop during a run before its totals are recorded.
func check_achievements(live := {}) -> Array[Dictionary]:
	var unlocked: Array[Dictionary] = []
	for entry in Achievements.all():
		var id: String = entry["id"]
		if achievements.has(id):
			continue
		var stat: String = entry["stat"]
		var value := stat_value(stat)
		if live.has(stat):
			if Achievements.BEST_STATS.has(stat):
				value = maxi(value, int(live[stat]))
			else:
				value += int(live[stat])
		if value >= int(entry["target"]):
			achievements[id] = true
			coins += int(entry["reward_coins"])
			unlocked.append(entry)
	return unlocked
