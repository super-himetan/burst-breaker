extends RefCounted
## Things a single run can pick up or agree to: relics, routes, shrines, contracts, pilots, missions.
## Everything with `add` feeds the same stats as perks.

const MAX_RELICS := 3

const ROUTES := {
	"battle": {"glyph": "sword", "color": "ff7a8a", "weight": 3.0},
	"danger": {"glyph": "flag", "color": "ff5f5f", "weight": 2.0},
	"altar": {"glyph": "shard", "color": "b48cff", "weight": 2.0},
	"merchant": {"glyph": "coin", "color": "ffd84d", "weight": 2.0},
	"shrine": {"glyph": "crown", "color": "8be9fd", "weight": 2.0},
	"treasure": {"glyph": "chest", "color": "ffd166", "weight": 1.0},
	"bonus": {"glyph": "coin_stack", "color": "ffd166", "weight": 1.5},
	"forge": {"glyph": "hammer", "color": "ff9a3d", "weight": 1.5},
}
## A bonus stage: a sky of coin blocks and a few shots to break them.
const BONUS_SHOTS := 3
const BONUS_COINS := 2.0
const FORGE_OFFERS := 3
## The danger route: the next stage is tougher, and pays for it.
const DANGER_HP := 1.35
const DANGER_COINS := 1.6
const TREASURE_COINS := 15
const MERCHANT_OFFERS := 3
const MERCHANT_PRICE := 15

const RELICS := {
	"r_magnet": {"glyph": "coin", "add": {"coin_pct": 0.5}},
	"r_anvil": {"glyph": "hammer", "add": {"flat_damage": 5.0, "speed_pct": -0.1}},
	"r_clock": {"glyph": "hourglass", "add": {"stall": 1.0}},
	"r_fang": {"glyph": "crown", "add": {"boss_damage": 0.5}},
	"r_feather": {"glyph": "dash", "add": {"speed_pct": 0.2, "rebound_chance": 0.2}},
	"r_lens": {"glyph": "star", "add": {"crit_chance": 0.15}},
	"r_mask": {"glyph": "target", "add": {"first_strike": 2.0}},
	"r_cauldron": {"glyph": "drop", "add": {"poison": 2.0, "poison_damage": 0.5}},
	"r_powder": {"glyph": "bomb", "add": {"bomb_chance": 0.2, "bomb_damage": 0.5}},
	"r_prism": {"glyph": "fork", "add": {"split_chance": 0.2, "split_damage": 0.3}},
	"r_heart": {"glyph": "shield", "add": {"guards": 1.0}},
	"r_compass": {"glyph": "crosshair", "add": {"homing_chance": 0.3}},
}

## Owning every relic in a set adds its bonus on top.
const RELIC_SETS := {
	"set_blast": {"relics": ["r_powder", "r_prism"], "add": {"cluster": 1.0}},
	"set_hunt": {"relics": ["r_fang", "r_mask"], "add": {"boss_damage": 0.5, "first_strike": 1.0}},
	"set_alchemy": {"relics": ["r_cauldron", "r_powder"], "add": {"blast_poison": 2.0}},
	"set_wind": {"relics": ["r_feather", "r_compass"], "add": {"homing_chance": 0.3, "wall_damage": 2.0}},
	"set_fortune": {"relics": ["r_magnet", "r_lens"], "add": {"coin_pct": 0.5, "crit_chance": 0.1}},
	"set_bastion": {"relics": ["r_heart", "r_clock"], "add": {"guards": 1.0, "stall": 1.0}},
}

## Titles shown under the logo, earned through achievements.
const HONORS := {
	"honor_rookie": "",
	"honor_breaker": "wins_1",
	"honor_slayer": "bosses_3",
	"honor_chain": "best_combo_4",
	"honor_alchemist": "poison_damage_3",
	"honor_tycoon": "coins_5",
	"honor_scholar": "perks_seen_5",
	"honor_rusher": "rush_clears_1",
	"honor_origin": "boss_origin_1",
}

const SHRINES: Array[String] = ["offering", "gamble", "pact", "rest", "mirror"]
const OFFERING_COST := 0.3
const GAMBLE_WIN := 2.0
const GAMBLE_LOSS := 0.5

## Agreed to before a run. Harder rules, more coins.
const CONTRACTS := {
	"none": {"add": {}},
	"few_balls": {"add": {"ball_count": -3.0, "coin_pct": 1.0}},
	"thick": {"add": {"hp_reduction": -0.5, "coin_pct": 1.0}},
	"no_reroll": {"add": {"rerolls": -99.0, "coin_pct": 0.5}},
	"no_guard": {"add": {"guards": -99.0, "coin_pct": 0.5}},
	"rush_hour": {"add": {"wave_delta": 2.0, "coin_pct": 1.5}},
}

const PILOTS := {
	"rookie": {"glyph": "target", "unlock": "", "add": {}},
	"sniper": {"glyph": "crosshair", "unlock": "best_shot_3", "add": {"first_strike": 1.0, "ball_count": -1.0}},
	"gunner": {"glyph": "chevrons", "unlock": "runs_3", "add": {"launch_speed": 0.5, "ball_count": 1.0}},
	"alchemist": {"glyph": "flame", "unlock": "explosions_2", "add": {"poison": 1.0, "bomb_chance": 0.1}},
	"scholar": {"glyph": "cards", "unlock": "perks_seen_2", "add": {"rerolls": 1.0, "luck": 0.25}},
	"rogue": {"glyph": "dice", "unlock": "coins_3", "add": {"crit_chance": 0.1, "coin_pct": 0.2}},
}

## Small goals for one run. `reward` is multiplied by the stage reached, plus one.
const MISSIONS := {
	"kills": {"target": 60, "reward": 2},
	"explosions": {"target": 15, "reward": 2},
	"splits": {"target": 30, "reward": 2},
	"crits": {"target": 25, "reward": 2},
	"overkills": {"target": 20, "reward": 2},
	"style_s": {"target": 2, "reward": 3},
	"bursts": {"target": 2, "reward": 2},
	"bosses": {"target": 1, "reward": 4},
}
const MISSIONS_PER_RUN := 3


static func ids_of(table: Dictionary) -> Array[String]:
	var list: Array[String] = []
	for id: String in table:
		list.append(id)
	return list
