extends RefCounted
## Starting ball types. `add` feeds the same stats as perks.
## `unlock` names the achievement that unlocks the type; empty means available from the start.
## `tags` lean the run's upgrade offers toward the build this ball is good at.
## `element` matters against blocks in the elemental chapters; see data/worlds.gd.
## `mastery` is what each mastery level adds, on top of the extra balls every few levels.

const MASTERY_MAX := 10
const MASTERY_BALL_EVERY := 5

const BALLS := {
	"normal": {"count": 10, "color": "ffffff", "unlock": "", "tags": [], "add": {"damage_pct": 0.4}, "mastery": {"damage_pct": 0.1}},
	"iron": {"element": "ice", "count": 5, "color": "b8c4d6", "unlock": "runs_2", "tags": ["power"], "add": {"flat_damage": 3.0, "pierce_chance": 0.2}, "mastery": {"flat_damage": 0.5}},
	"fire": {"element": "fire", "count": 6, "color": "ff7a3d", "unlock": "kills_2", "tags": ["toxic"], "add": {"poison": 2.0, "burn_pct": 0.04}, "mastery": {"poison_damage": 0.15}},
	"splitter": {"element": "volt", "count": 5, "color": "4fd1ff", "unlock": "splits_2", "tags": ["split"], "add": {"split_chance": 0.16}, "mastery": {"split_damage": 0.1}},
	"blaster": {"element": "fire", "count": 6, "color": "ff8c1a", "unlock": "explosions_2", "tags": ["blast"], "add": {"bomb_chance": 0.65, "bomb_damage": 2.0}, "mastery": {"bomb_damage": 0.15}},
	"ghost": {"element": "ice", "count": 7, "color": "b48cff", "unlock": "wins_1", "tags": ["bounce"], "add": {"pierce_chance": 0.12, "homing_chance": 0.15}, "mastery": {"homing_chance": 0.05}},
	"lucky": {"count": 8, "color": "ffd84d", "unlock": "coins_4", "tags": ["crit", "fortune"], "add": {"crit_chance": 0.45, "coin_pct": 0.5, "luck": 0.5, "damage_pct": 0.2}, "mastery": {"crit_chance": 0.02}},
	"titan": {"element": "volt", "count": 3, "color": "6dff9e", "unlock": "best_shot_4", "tags": ["power"], "add": {"radius": 14.0, "damage_pct": 2.2, "rebound_chance": 0.25}, "mastery": {"damage_pct": 0.2}},
}


## Total experience a ball needs to reach `level`.
static func mastery_xp(level: int) -> int:
	return 6 * level * (level + 1)


static func ids() -> Array[String]:
	var list: Array[String] = []
	for id: String in BALLS:
		list.append(id)
	return list
