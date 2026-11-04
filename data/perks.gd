extends RefCounted
## Run upgrades. `add` values stack per level into the sim's stats.
## rarity: 0 common, 1 rare, 2 epic, 3 legendary.
## `locked` perks join the pool once the matching achievement unlocks them.

const COMMON := 0
const RARE := 1
const EPIC := 2
const LEGENDARY := 3

const RARITY_WEIGHTS: Array[float] = [100.0, 38.0, 13.0, 4.0]

const PERKS := {
	# Damage
	"power": {"rarity": COMMON, "max": 5, "add": {"flat_damage": 1.0}},
	"heavy": {"rarity": RARE, "max": 5, "add": {"damage_pct": 0.25}, "locked": true},
	"crit": {"rarity": COMMON, "max": 5, "add": {"crit_chance": 0.08}},
	"crit_power": {"rarity": RARE, "max": 3, "add": {"crit_mult": 1.0}, "locked": true},
	"first_strike": {"rarity": COMMON, "max": 3, "add": {"first_strike": 1.0}},
	"finisher": {"rarity": RARE, "max": 3, "add": {"finisher": 1.0}},
	"opener": {"rarity": COMMON, "max": 3, "add": {"opener": 1.0}, "locked": true},
	"ricochet": {"rarity": COMMON, "max": 5, "add": {"wall_damage": 1.0}},
	"ceiling": {"rarity": COMMON, "max": 3, "add": {"top_damage": 3.0}, "locked": true},
	"combo_power": {"rarity": RARE, "max": 3, "add": {"combo_damage": 1.0}, "locked": true},
	"gambler": {"rarity": EPIC, "max": 1, "add": {"gamble": 1.0}, "locked": true},
	"glass": {"rarity": EPIC, "max": 1, "add": {"damage_pct": 0.8, "ball_count": -2.0}, "locked": true},
	# Balls
	"more_balls": {"rarity": COMMON, "max": 5, "add": {"ball_count": 4.0}},
	"rapid": {"rarity": COMMON, "max": 3, "add": {"launch_speed": 0.3, "damage_pct": 0.05}},
	"speed": {"rarity": COMMON, "max": 3, "add": {"speed_pct": 0.12, "damage_pct": 0.15}, "locked": true},
	"big_ball": {"rarity": RARE, "max": 3, "add": {"radius": 3.0, "damage_pct": 0.12}},
	"second_wind": {"rarity": RARE, "max": 3, "add": {"rebound_chance": 0.2}},
	"floor_guard": {"rarity": EPIC, "max": 2, "add": {"floor_bounces": 4.0}, "locked": true},
	"split": {"rarity": COMMON, "max": 5, "add": {"split_chance": 0.15}},
	"split_power": {"rarity": RARE, "max": 3, "add": {"split_damage": 0.5}, "locked": true},
	"double_split": {"rarity": EPIC, "max": 1, "add": {"split_count": 1.0}, "locked": true},
	"pierce": {"rarity": RARE, "max": 3, "add": {"pierce_chance": 0.08}},
	"aimbot": {"rarity": RARE, "max": 3, "add": {"homing_chance": 0.3}, "locked": true},
	# Blasts and damage over time
	"bomb": {"rarity": COMMON, "max": 5, "add": {"bomb_chance": 0.12}},
	"bomb_power": {"rarity": COMMON, "max": 5, "add": {"bomb_damage": 0.5}},
	"bomb_radius": {"rarity": EPIC, "max": 2, "add": {"bomb_radius": 1.0}, "locked": true},
	"chain_reaction": {"rarity": RARE, "max": 3, "add": {"chain_chance": 0.3}, "locked": true},
	"poison": {"rarity": COMMON, "max": 5, "add": {"poison": 1.0}},
	"poison_power": {"rarity": RARE, "max": 3, "add": {"poison_damage": 0.5}, "locked": true},
	"burn": {"rarity": COMMON, "max": 3, "add": {"burn_pct": 0.06}, "locked": true},
	"shock": {"rarity": RARE, "max": 3, "add": {"shock_targets": 1.0}},
	"shockwave": {"rarity": COMMON, "max": 3, "add": {"shockwave": 1.0}},
	# Control
	"stall": {"rarity": RARE, "max": 2, "add": {"stall": 1.0}},
	"guard": {"rarity": EPIC, "max": 2, "add": {"guards": 1.0}, "locked": true},
	"intercept": {"rarity": COMMON, "max": 3, "add": {"intercept_pct": 0.1}},
	"short_waves": {"rarity": EPIC, "max": 1, "add": {"wave_delta": -1.0}, "locked": true},
	"thin": {"rarity": COMMON, "max": 3, "add": {"hp_reduction": 0.06}},
	# Economy
	"greed": {"rarity": COMMON, "max": 5, "add": {"coin_pct": 0.25}},
	"treasure": {"rarity": COMMON, "max": 3, "add": {"treasure_rate": 0.05}},
	"interest": {"rarity": RARE, "max": 3, "add": {"interest": 0.05}, "locked": true},
	"reroll": {"rarity": COMMON, "max": 3, "add": {"rerolls": 1.0}},
	"extra_choice": {"rarity": LEGENDARY, "max": 1, "add": {"extra_choices": 1.0}, "locked": true},
	"lucky": {"rarity": RARE, "max": 3, "add": {"luck": 0.25}},
	"bounty": {"rarity": RARE, "max": 3, "add": {"boss_damage": 0.3, "boss_coins": 0.5}, "locked": true},
	"reinforce": {"rarity": COMMON, "max": 3, "add": {"extra_ball_rate": 0.05}},
	# Risk and scaling
	"overdrive": {"rarity": EPIC, "max": 1, "add": {"damage_pct": 0.7, "wave_delta": 1.0}, "locked": true},
	"momentum": {"rarity": RARE, "max": 3, "add": {"momentum": 0.06}},
	"last_stand": {"rarity": EPIC, "max": 1, "add": {"last_stand": 1.0}, "locked": true},
	# Evolutions: offered once both required perks are owned.
	"e_cluster": {"rarity": LEGENDARY, "max": 1, "requires": ["split", "bomb"], "add": {"cluster": 1.0, "split_chance": 0.1}},
	"e_storm": {"rarity": LEGENDARY, "max": 1, "requires": ["shock", "crit"], "add": {"crit_shock": 1.0, "crit_chance": 0.1}},
	"e_inferno": {"rarity": LEGENDARY, "max": 1, "requires": ["poison", "bomb"], "add": {"blast_poison": 3.0, "bomb_damage": 1.0}},
	"e_barrage": {"rarity": LEGENDARY, "max": 1, "requires": ["more_balls", "rapid"], "add": {"ball_count": 10.0, "launch_speed": 1.0}},
	"e_mirror": {"rarity": LEGENDARY, "max": 1, "requires": ["ricochet", "aimbot"], "add": {"wall_damage": 3.0, "homing_chance": 1.0}},
	"e_executioner": {"rarity": LEGENDARY, "max": 1, "requires": ["finisher", "crit"], "add": {"execute": 1.0, "crit_chance": 0.1}},
	"e_singularity": {"rarity": LEGENDARY, "max": 1, "requires": ["big_ball", "pierce"], "add": {"radius": 6.0, "pierce_chance": 0.25, "damage_pct": 0.5}},
	"e_midas": {"rarity": LEGENDARY, "max": 1, "requires": ["greed", "treasure"], "add": {"coin_pct": 1.0, "treasure_rate": 0.1}},
}


static func ids() -> Array[String]:
	var list: Array[String] = []
	for id: String in PERKS:
		list.append(id)
	return list


static func is_evolution(id: String) -> bool:
	return PERKS[id].has("requires")


static func starts_locked(id: String) -> bool:
	return bool(PERKS[id].get("locked", false))
