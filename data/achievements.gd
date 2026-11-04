extends RefCounted
## Achievements are thresholds on lifetime stats. Ids are "<stat>_<n>", counted from 1.

const TRACKS := {
	"damage": [1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000, 10000000000],
	"kills": [100, 500, 2000, 5000, 15000, 50000, 150000, 500000],
	"coins": [100, 500, 2000, 8000, 30000, 100000, 500000, 2000000],
	"runs": [1, 5, 10, 25, 50, 100, 200, 500],
	"wins": [1, 3, 5, 10, 25, 50, 100],
	"best_combo": [50, 100, 200, 400, 800, 1500, 3000],
	"best_shot": [100, 500, 1000, 3000, 25000, 100000, 1000000],
	"explosions": [50, 300, 2000, 10000, 50000, 200000],
	"splits": [100, 500, 5000, 25000, 100000],
	"crits": [50, 500, 5000, 25000, 100000],
	"poison_damage": [1000, 10000, 100000, 1000000],
	"bosses": [1, 5, 15, 50, 100],
	"treasures": [5, 25, 100, 500],
	"perks_seen": [10, 20, 30, 40, 50],
	"evolutions": [1, 5, 15, 40],
	"bursts": [1, 10, 50, 200, 1000],
	"best_tier": [1, 2, 3, 5, 7, 10, 15, 20],
	"stars": [1, 5, 10, 25, 50, 100],
	"shop_levels": [5, 15, 30, 60, 90],
	"clears_normal": [1],
	"clears_iron": [1],
	"clears_fire": [1],
	"clears_splitter": [1],
	"clears_blaster": [1],
	"clears_ghost": [1],
	"clears_lucky": [1],
	"clears_titan": [1],
}

## Stats where the highest single value counts, instead of a running total.
const BEST_STATS: Array[String] = ["best_combo", "best_shot", "best_tier", "stars", "shop_levels", "perks_seen"]

## Which achievement unlocks each locked perk.
const PERK_UNLOCKS := {
	"opener": "runs_1",
	"speed": "damage_1",
	"burn": "kills_1",
	"ceiling": "best_combo_1",
	"chain_reaction": "explosions_1",
	"split_power": "splits_1",
	"heavy": "damage_2",
	"poison_power": "poison_damage_1",
	"crit_power": "crits_1",
	"interest": "coins_1",
	"bounty": "bosses_1",
	"aimbot": "best_combo_2",
	"combo_power": "best_combo_3",
	"floor_guard": "runs_3",
	"double_split": "splits_3",
	"bomb_radius": "explosions_3",
	"gambler": "crits_2",
	"glass": "best_shot_2",
	"overdrive": "best_tier_1",
	"guard": "wins_2",
	"short_waves": "bosses_2",
	"last_stand": "runs_4",
	"extra_choice": "wins_3",
}


static func id_for(stat: String, index: int) -> String:
	return "%s_%d" % [stat, index + 1]


## Every achievement in display order: {id, stat, target, reward_coins}.
static func all() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for stat: String in TRACKS:
		var targets: Array = TRACKS[stat]
		for i in targets.size():
			list.append({
				"id": id_for(stat, i),
				"stat": stat,
				"target": int(targets[i]),
				"reward_coins": 20 * int(pow(2.5, i)),
			})
	return list


static func locks_for_perk(perk: String) -> String:
	return String(PERK_UNLOCKS.get(perk, ""))
