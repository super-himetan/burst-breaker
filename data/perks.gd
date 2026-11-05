extends RefCounted
## Run upgrades. `add` values stack per level into the sim's stats.
## rarity: 0 common, 1 rare, 2 epic, 3 legendary.
## `locked` perks join the pool once the matching achievement unlocks them.
## `tags` name the build a perk belongs to; owning a tag makes its other perks show up more.
## `needs` names a stat that must already be above zero, or the perk would do nothing.
## `curse` perks stay out of normal offers: only the altar and shrines hand them out.

const COMMON := 0
const RARE := 1
const EPIC := 2
const LEGENDARY := 3

const RARITY_WEIGHTS: Array[float] = [100.0, 38.0, 13.0, 4.0]

const TAGS: Array[String] = ["split", "blast", "toxic", "crit", "bounce", "swarm", "power", "fortune", "guard"]

const PERKS := {
	# Damage
	"power": {"rarity": COMMON, "max": 5, "tags": ["power"], "add": {"flat_damage": 2.0}},
	"heavy": {"rarity": RARE, "max": 5, "tags": ["power"], "add": {"damage_pct": 0.25}, "locked": true},
	"crit": {"rarity": COMMON, "max": 5, "tags": ["crit"], "add": {"crit_chance": 0.08}},
	"crit_power": {"rarity": RARE, "max": 3, "tags": ["crit"], "needs": "crit_chance", "add": {"crit_mult": 1.0}, "locked": true},
	"first_strike": {"rarity": COMMON, "max": 3, "tags": ["power"], "add": {"first_strike": 1.0}},
	"finisher": {"rarity": RARE, "max": 3, "tags": ["crit"], "add": {"finisher": 1.5}},
	"opener": {"rarity": COMMON, "max": 3, "tags": ["power"], "add": {"opener": 1.0}, "locked": true},
	"ricochet": {"rarity": COMMON, "max": 5, "tags": ["bounce"], "add": {"wall_damage": 1.0}},
	"ceiling": {"rarity": COMMON, "max": 3, "tags": ["bounce"], "add": {"top_damage": 3.0}, "locked": true},
	"combo_power": {"rarity": RARE, "max": 3, "tags": ["swarm", "split"], "add": {"combo_damage": 1.0}, "locked": true},
	"gambler": {"rarity": EPIC, "max": 1, "tags": ["crit"], "add": {"gamble": 1.0}, "locked": true},
	"glass": {"rarity": EPIC, "max": 1, "tags": ["power"], "add": {"damage_pct": 0.8, "ball_count": -2.0}, "locked": true},
	# Balls
	"more_balls": {"rarity": COMMON, "max": 5, "tags": ["swarm"], "add": {"ball_count": 4.0}},
	"rapid": {"rarity": COMMON, "max": 3, "tags": ["swarm"], "add": {"launch_speed": 0.3, "damage_pct": 0.05}},
	"speed": {"rarity": COMMON, "max": 3, "tags": ["bounce"], "add": {"speed_pct": 0.12, "damage_pct": 0.15}, "locked": true},
	"big_ball": {"rarity": RARE, "max": 3, "tags": ["power"], "add": {"radius": 3.0, "damage_pct": 0.12}},
	"second_wind": {"rarity": RARE, "max": 3, "tags": ["bounce"], "add": {"rebound_chance": 0.2}},
	"floor_guard": {"rarity": EPIC, "max": 2, "tags": ["bounce"], "add": {"floor_bounces": 4.0}, "locked": true},
	"split": {"rarity": COMMON, "max": 5, "tags": ["split"], "add": {"split_chance": 0.15}},
	"split_power": {"rarity": RARE, "max": 3, "tags": ["split"], "needs": "split_chance", "add": {"split_damage": 0.5}, "locked": true},
	"double_split": {"rarity": EPIC, "max": 1, "tags": ["split"], "needs": "split_chance", "add": {"split_count": 1.0}, "locked": true},
	"pierce": {"rarity": RARE, "max": 3, "tags": ["power"], "add": {"pierce_chance": 0.08}},
	"aimbot": {"rarity": RARE, "max": 3, "tags": ["bounce"], "add": {"homing_chance": 0.3}, "locked": true},
	# Blasts and damage over time
	"bomb": {"rarity": COMMON, "max": 5, "tags": ["blast"], "add": {"bomb_chance": 0.15}},
	"bomb_power": {"rarity": COMMON, "max": 5, "tags": ["blast"], "add": {"bomb_damage": 0.8}},
	"bomb_radius": {"rarity": EPIC, "max": 2, "tags": ["blast"], "add": {"bomb_radius": 1.0}, "locked": true},
	"chain_reaction": {"rarity": RARE, "max": 3, "tags": ["blast"], "add": {"chain_chance": 0.3}, "locked": true},
	"poison": {"rarity": COMMON, "max": 5, "tags": ["toxic"], "add": {"poison": 1.0}},
	"poison_power": {"rarity": RARE, "max": 3, "tags": ["toxic"], "needs": "poison", "add": {"poison_damage": 0.5}, "locked": true},
	"burn": {"rarity": COMMON, "max": 3, "tags": ["toxic"], "add": {"burn_pct": 0.06}, "locked": true},
	"shock": {"rarity": RARE, "max": 3, "tags": ["crit"], "add": {"shock_targets": 1.0}},
	"shockwave": {"rarity": COMMON, "max": 3, "tags": ["blast", "toxic"], "add": {"shockwave": 1.0}},
	# Control
	"stall": {"rarity": RARE, "max": 2, "tags": ["guard"], "add": {"stall": 1.0}},
	"guard": {"rarity": EPIC, "max": 2, "tags": ["guard"], "add": {"guards": 1.0}, "locked": true},
	"intercept": {"rarity": COMMON, "max": 3, "tags": ["guard"], "add": {"intercept_pct": 0.1}},
	"short_waves": {"rarity": EPIC, "max": 1, "tags": ["guard"], "add": {"wave_delta": -1.0}, "locked": true},
	"thin": {"rarity": COMMON, "max": 3, "tags": ["guard"], "add": {"hp_reduction": 0.06}},
	# Economy
	"greed": {"rarity": COMMON, "max": 5, "tags": ["fortune"], "add": {"coin_pct": 0.25}},
	"treasure": {"rarity": COMMON, "max": 3, "tags": ["fortune"], "add": {"treasure_rate": 0.05}},
	"interest": {"rarity": RARE, "max": 3, "tags": ["fortune"], "add": {"interest": 0.05}, "locked": true},
	"reroll": {"rarity": COMMON, "max": 3, "tags": ["fortune"], "add": {"rerolls": 1.0}},
	"extra_choice": {"rarity": LEGENDARY, "max": 1, "tags": ["fortune"], "add": {"extra_choices": 1.0}, "locked": true},
	"lucky": {"rarity": RARE, "max": 3, "tags": ["fortune"], "add": {"luck": 0.25}},
	"bounty": {"rarity": RARE, "max": 3, "tags": ["fortune"], "add": {"boss_damage": 0.3, "boss_coins": 0.5}, "locked": true},
	"reinforce": {"rarity": COMMON, "max": 3, "tags": ["swarm"], "add": {"extra_ball_rate": 0.05}},
	# Risk and scaling
	"overdrive": {"rarity": EPIC, "max": 1, "tags": ["power"], "add": {"damage_pct": 0.7, "wave_delta": 1.0}, "locked": true},
	"momentum": {"rarity": RARE, "max": 3, "tags": ["power"], "add": {"momentum": 0.1}},
	"last_stand": {"rarity": EPIC, "max": 1, "tags": ["guard"], "add": {"last_stand": 1.0}, "locked": true},
	# Companion
	"companion": {"rarity": RARE, "max": 3, "tags": ["swarm"], "add": {"companion": 1.0}},
	"companion_power": {"rarity": RARE, "max": 3, "tags": ["swarm"], "needs": "companion", "add": {"companion_damage": 1.0}},
	# Curses: much stronger, with a real price.
	"c_berserk": {"rarity": EPIC, "max": 1, "curse": true, "tags": ["power"], "add": {"damage_pct": 1.0, "ball_count": -3.0}},
	"c_blood": {"rarity": EPIC, "max": 1, "curse": true, "tags": ["power"], "add": {"damage_pct": 0.7, "wave_delta": 1.0}},
	"c_gold": {"rarity": EPIC, "max": 1, "curse": true, "tags": ["fortune"], "add": {"coin_pct": 2.0, "hp_reduction": -0.25}},
	"c_haste": {"rarity": EPIC, "max": 1, "curse": true, "tags": ["swarm"], "add": {"launch_speed": 2.0, "speed_pct": 0.5, "damage_pct": -0.2}},
	"c_lightning": {"rarity": EPIC, "max": 1, "curse": true, "tags": ["crit"], "add": {"crit_chance": 0.4, "burst_gain": -0.6}},
	"c_titan": {"rarity": EPIC, "max": 1, "curse": true, "tags": ["power"], "add": {"radius": 6.0, "damage_pct": 0.5, "speed_pct": -0.25}},
	"c_narrow": {"rarity": EPIC, "max": 1, "curse": true, "tags": ["guard"], "add": {"damage_pct": 0.8, "extra_choices": -1.0}},
	"c_doom": {"rarity": EPIC, "max": 1, "curse": true, "tags": ["blast"], "add": {"bomb_chance": 0.5, "bomb_damage": 1.0, "guards": -99.0}},
	# Evolutions: offered once both required perks are owned.
	"e_cluster": {"rarity": LEGENDARY, "max": 1, "requires": ["split", "bomb"], "add": {"cluster": 1.0, "split_chance": 0.1}},
	"e_storm": {"rarity": LEGENDARY, "max": 1, "requires": ["shock", "crit"], "add": {"crit_shock": 1.0, "crit_chance": 0.1}},
	"e_inferno": {"rarity": LEGENDARY, "max": 1, "requires": ["poison", "bomb"], "add": {"blast_poison": 3.0, "bomb_damage": 1.0}},
	"e_barrage": {"rarity": LEGENDARY, "max": 1, "requires": ["more_balls", "rapid"], "add": {"ball_count": 10.0, "launch_speed": 1.0}},
	"e_mirror": {"rarity": LEGENDARY, "max": 1, "requires": ["ricochet", "aimbot"], "add": {"wall_damage": 3.0, "homing_chance": 1.0}},
	"e_executioner": {"rarity": LEGENDARY, "max": 1, "requires": ["finisher", "crit"], "add": {"execute": 1.0, "crit_chance": 0.1}},
	"e_singularity": {"rarity": LEGENDARY, "max": 1, "requires": ["big_ball", "pierce"], "add": {"radius": 6.0, "pierce_chance": 0.25, "damage_pct": 0.5}},
	"e_midas": {"rarity": LEGENDARY, "max": 1, "requires": ["greed", "treasure"], "add": {"coin_pct": 1.0, "treasure_rate": 0.1}},
	"e_echo": {"rarity": LEGENDARY, "max": 1, "requires": ["second_wind", "ricochet"], "add": {"rebound_chance": 0.2, "floor_wall": 1.0}},
	"e_plague": {"rarity": LEGENDARY, "max": 1, "requires": ["poison", "shockwave"], "add": {"poison": 2.0, "plague": 1.0}},
	"e_fortress": {"rarity": LEGENDARY, "max": 1, "requires": ["stall", "intercept"], "add": {"intercept_pct": 0.1, "safe_damage": 0.06}},
	"e_lance": {"rarity": LEGENDARY, "max": 1, "requires": ["power", "first_strike"], "add": {"first_strike": 1.0, "first_refresh": 1.0}},
	"e_pack": {"rarity": LEGENDARY, "max": 1, "requires": ["companion", "reinforce"], "add": {"companion": 2.0, "companion_damage": 2.0}},
	# Ultimates: two evolutions fused into one.
	"u_cataclysm": {"rarity": LEGENDARY, "max": 1, "requires": ["e_cluster", "e_inferno"], "add": {"bomb_damage": 3.0, "bomb_radius": 1.0, "chain_chance": 0.5}},
	"u_judgement": {"rarity": LEGENDARY, "max": 1, "requires": ["e_storm", "e_executioner"], "add": {"crit_chance": 0.2, "crit_mult": 3.0}},
	"u_ragnarok": {"rarity": LEGENDARY, "max": 1, "requires": ["e_barrage", "e_singularity"], "add": {"ball_count": 10.0, "damage_pct": 1.0}},
	"u_paradox": {"rarity": LEGENDARY, "max": 1, "requires": ["e_mirror", "e_echo"], "add": {"wall_damage": 8.0, "rebound_chance": 0.3}},
	"u_kingdom": {"rarity": LEGENDARY, "max": 1, "requires": ["e_midas", "e_fortress"], "add": {"coin_pct": 2.0, "safe_damage": 0.1, "guards": 1.0}},
	"u_pestilence": {"rarity": LEGENDARY, "max": 1, "requires": ["e_plague", "e_lance"], "add": {"poison": 5.0, "first_strike": 2.0}},
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


## An evolution belongs to every build its two parents belong to.
static func tags_of(id: String) -> Array[String]:
	var list: Array[String] = []
	var perk: Dictionary = PERKS[id]
	var sources: Array = perk["requires"] if perk.has("requires") else [id]
	for source: String in sources:
		# An ultimate's parents are evolutions, so this walks down to the normal perks.
		var inherited: Array = tags_of(source) if is_evolution(source) else PERKS[source]["tags"]
		for tag: String in inherited:
			if not list.has(tag):
				list.append(tag)
	return list


static func is_curse(id: String) -> bool:
	return bool(PERKS[id].get("curse", false))


static func curses() -> Array[String]:
	var list: Array[String] = []
	for id: String in PERKS:
		if is_curse(id):
			list.append(id)
	return list


static func evolutions_of(id: String) -> Array[String]:
	var list: Array[String] = []
	for other: String in PERKS:
		if is_evolution(other) and (PERKS[other]["requires"] as Array).has(id):
			list.append(other)
	return list
