extends RefCounted
## What stars can buy. Stars are never spent for good: the tree can be reset for free,
## and every star still gives its flat bonus. A node opens once its parent has a level.
## `add` feeds the same stats as perks. `keep_coins` is read by the save instead of the sim.

const NODES := {
	"s_damage": {"branch": "attack", "cost": 1, "max": 5, "requires": "", "add": {"damage_pct": 0.15}},
	"s_crit": {"branch": "attack", "cost": 2, "max": 3, "requires": "s_damage", "add": {"crit_mult": 0.5}},
	"s_start_perk": {"branch": "attack", "cost": 6, "max": 2, "requires": "s_crit", "add": {"start_perks": 1.0}},
	"s_burst_start": {"branch": "burst", "cost": 1, "max": 5, "requires": "", "add": {"burst_start": 0.1}},
	"s_burst_gain": {"branch": "burst", "cost": 2, "max": 3, "requires": "s_burst_start", "add": {"burst_gain": 0.2}},
	"s_guard": {"branch": "burst", "cost": 8, "max": 1, "requires": "s_burst_gain", "add": {"guards": 1.0}},
	"s_coins": {"branch": "fortune", "cost": 1, "max": 5, "requires": "", "add": {"coin_pct": 0.2}},
	"s_keep": {"branch": "fortune", "cost": 3, "max": 3, "requires": "s_coins", "add": {"keep_coins": 0.1}},
	"s_reroll": {"branch": "fortune", "cost": 3, "max": 3, "requires": "s_keep", "add": {"rerolls": 1.0}},
	"s_choice": {"branch": "fortune", "cost": 10, "max": 1, "requires": "s_reroll", "add": {"extra_choices": 1.0}},
}


static func ids() -> Array[String]:
	var list: Array[String] = []
	for id: String in NODES:
		list.append(id)
	return list


## How many nodes sit above this one, for indenting the list.
static func depth(id: String) -> int:
	var count := 0
	var parent := String(NODES[id]["requires"])
	while parent != "":
		count += 1
		parent = String(NODES[parent]["requires"])
	return count
