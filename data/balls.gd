extends RefCounted
## Starting ball types. `add` feeds the same stats as perks.
## `unlock` names the achievement that unlocks the type; empty means available from the start.

const BALLS := {
	"normal": {"count": 8, "color": "ffffff", "unlock": "", "add": {}},
	"iron": {"count": 5, "color": "b8c4d6", "unlock": "runs_2", "add": {"flat_damage": 2.0, "pierce_chance": 0.25}},
	"fire": {"count": 6, "color": "ff7a3d", "unlock": "kills_2", "add": {"poison": 2.0, "burn_pct": 0.04}},
	"splitter": {"count": 5, "color": "4fd1ff", "unlock": "splits_2", "add": {"split_chance": 0.4}},
	"blaster": {"count": 5, "color": "ff8c1a", "unlock": "explosions_2", "add": {"bomb_chance": 0.45, "bomb_damage": 0.5}},
	"ghost": {"count": 7, "color": "b48cff", "unlock": "wins_1", "add": {"pierce_chance": 0.5, "homing_chance": 0.2}},
	"lucky": {"count": 6, "color": "ffd84d", "unlock": "coins_3", "add": {"crit_chance": 0.3, "coin_pct": 0.5, "luck": 0.5}},
	"titan": {"count": 3, "color": "6dff9e", "unlock": "best_shot_4", "add": {"radius": 14.0, "damage_pct": 2.2, "rebound_chance": 0.25}},
}


static func ids() -> Array[String]:
	var list: Array[String] = []
	for id: String in BALLS:
		list.append(id)
	return list
