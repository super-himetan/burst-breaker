extends RefCounted
## Permanent upgrades bought with coins. Prestige resets their levels.
## Every `every` levels an item pays a milestone: `bonus` adds up like `add`, `bonus_mult` multiplies.
## `level_mult` multiplies on every level. `after_all` items open once the rest are maxed.

const ITEMS := {
	"damage": {"max": 40, "base": 30.0, "growth": 1.2, "add": {"damage_pct": 0.08}, "every": 10, "bonus_mult": {"damage_mult": 1.5}},
	"coins": {"max": 30, "base": 40.0, "growth": 1.25, "add": {"coin_pct": 0.1}, "every": 10, "bonus": {"coin_pct": 0.5}},
	"balls": {"max": 12, "base": 120.0, "growth": 1.7, "add": {"ball_count": 1.0}, "every": 4, "bonus": {"ball_count": 2.0}},
	"crit": {"max": 15, "base": 60.0, "growth": 1.3, "add": {"crit_chance": 0.02}, "every": 5, "bonus": {"crit_mult": 0.5}},
	"blast": {"max": 20, "base": 50.0, "growth": 1.25, "add": {"bomb_damage": 0.1}, "every": 5, "bonus": {"bomb_damage": 0.5}},
	"toxin": {"max": 20, "base": 50.0, "growth": 1.25, "add": {"poison_damage": 0.1}, "every": 5, "bonus": {"poison_damage": 0.5}},
	"luck": {"max": 10, "base": 80.0, "growth": 1.4, "add": {"luck": 0.1}, "every": 5, "bonus": {"luck": 0.25}},
	"reroll": {"max": 3, "base": 300.0, "growth": 3.5, "add": {"rerolls": 1.0}},
	"guard": {"max": 2, "base": 1200.0, "growth": 4.0, "add": {"guards": 1.0}},
	"start_perk": {"max": 3, "base": 800.0, "growth": 4.0, "add": {"start_perks": 1.0}},
	"infinity": {"max": 200, "base": 5000.0, "growth": 1.16, "add": {}, "after_all": true, "level_mult": {"damage_mult": 1.03}, "every": 10, "bonus_mult": {"damage_mult": 1.25}},
}


static func ids() -> Array[String]:
	var list: Array[String] = []
	for id: String in ITEMS:
		list.append(id)
	return list


## Adds what `level` levels of this item give to `target`.
static func apply(target: Dictionary, id: String, level: int) -> void:
	var item: Dictionary = ITEMS[id]
	var every: int = item.get("every", 0)
	var reached := level / every if every > 0 else 0
	var add: Dictionary = item["add"]
	for key: String in add:
		target[key] = float(target.get(key, 0.0)) + float(add[key]) * level
	var bonus: Dictionary = item.get("bonus", {})
	for key: String in bonus:
		target[key] = float(target.get(key, 0.0)) + float(bonus[key]) * reached
	var bonus_mult: Dictionary = item.get("bonus_mult", {})
	for key: String in bonus_mult:
		target[key] = float(target.get(key, 1.0)) * pow(float(bonus_mult[key]), reached)
	var level_mult: Dictionary = item.get("level_mult", {})
	for key: String in level_mult:
		target[key] = float(target.get(key, 1.0)) * pow(float(level_mult[key]), level)


static func is_milestone(id: String, level: int) -> bool:
	var every: int = ITEMS[id].get("every", 0)
	return every > 0 and level > 0 and level % every == 0


## The next level that pays a milestone, or 0 when there is none left.
static func next_milestone(id: String, level: int) -> int:
	var every: int = ITEMS[id].get("every", 0)
	if every <= 0:
		return 0
	var next := (level / every + 1) * every
	return next if next <= int(ITEMS[id]["max"]) else 0


static func cost(id: String, level: int) -> int:
	var item: Dictionary = ITEMS[id]
	return int(ceil(float(item["base"]) * pow(float(item["growth"]), level)))
