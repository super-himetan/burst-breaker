extends RefCounted
## Permanent upgrades bought with coins. Prestige resets their levels.

const ITEMS := {
	"damage": {"max": 40, "base": 30.0, "growth": 1.16, "add": {"damage_pct": 0.08}},
	"coins": {"max": 30, "base": 40.0, "growth": 1.2, "add": {"coin_pct": 0.1}},
	"balls": {"max": 12, "base": 90.0, "growth": 1.5, "add": {"ball_count": 1.0}},
	"crit": {"max": 15, "base": 60.0, "growth": 1.25, "add": {"crit_chance": 0.02}},
	"blast": {"max": 20, "base": 50.0, "growth": 1.2, "add": {"bomb_damage": 0.1}},
	"toxin": {"max": 20, "base": 50.0, "growth": 1.2, "add": {"poison_damage": 0.1}},
	"luck": {"max": 10, "base": 80.0, "growth": 1.35, "add": {"luck": 0.1}},
	"reroll": {"max": 3, "base": 250.0, "growth": 3.0, "add": {"rerolls": 1.0}},
	"guard": {"max": 2, "base": 900.0, "growth": 4.0, "add": {"guards": 1.0}},
	"start_perk": {"max": 3, "base": 500.0, "growth": 4.0, "add": {"start_perks": 1.0}},
}


static func ids() -> Array[String]:
	var list: Array[String] = []
	for id: String in ITEMS:
		list.append(id)
	return list


static func cost(id: String, level: int) -> int:
	var item: Dictionary = ITEMS[id]
	return int(ceil(float(item["base"]) * pow(float(item["growth"]), level)))
