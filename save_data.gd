extends RefCounted
## Settings and records kept between sessions. A damaged file falls back to defaults.

const I18n := preload("res://i18n.gd")
const DEFAULT_PATH := "user://save.json"

var path := DEFAULT_PATH
var lang := I18n.DEFAULT_LANG
var sound := true
var vibration := true
var tutorial_done := false
var best_damage := 0
var best_combo := 0
var best_stage := 0
var total_coins := 0
var wins := 0
var runs := 0


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
	tutorial_done = bool(data.get("tutorial_done", tutorial_done))
	best_damage = int(data.get("best_damage", best_damage))
	best_combo = int(data.get("best_combo", best_combo))
	best_stage = int(data.get("best_stage", best_stage))
	total_coins = int(data.get("total_coins", total_coins))
	wins = int(data.get("wins", wins))
	runs = int(data.get("runs", runs))


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
		"tutorial_done": tutorial_done,
		"best_damage": best_damage,
		"best_combo": best_combo,
		"best_stage": best_stage,
		"total_coins": total_coins,
		"wins": wins,
		"runs": runs,
	}, "  "))
	file.close()
	return DirAccess.rename_absolute(tmp, path) == OK


## Adds a finished or abandoned run. Returns true when a personal best was beaten.
func record_run(damage: int, combo: int, stage: int, coins: int, won: bool) -> bool:
	var new_best := damage > best_damage or combo > best_combo or stage > best_stage
	best_damage = maxi(best_damage, damage)
	best_combo = maxi(best_combo, combo)
	best_stage = maxi(best_stage, stage)
	total_coins += coins
	runs += 1
	if won:
		wins += 1
	return new_best
