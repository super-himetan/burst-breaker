extends RefCounted
## The boss roster. `pool` 0 appears on the middle boss stage and 1 on the last stage.
## `hp` scales the stage's base boss HP, so a stronger trick can sit on less health.
## `minion` is the block a boss summons each turn; "" rolls the stage's usual mix.
## `min_tier` keeps a boss out of the rotation until the player reaches that difficulty.

const BOSSES := {
	"purun": {"pool": 0, "hp": 1.0, "summon": 1, "minion": "", "color": "4fd8c4"},
	"mogu": {"pool": 0, "hp": 1.0, "summon": 2, "minion": "", "color": "f6a23c"},
	"gantetsu": {"pool": 0, "hp": 0.65, "summon": 1, "minion": "", "color": "7fae5a"},
	"dokan": {"pool": 1, "hp": 1.0, "summon": 0, "minion": "", "color": "5a6280"},
	"lumina": {"pool": 1, "hp": 0.7, "summon": 2, "minion": "regen", "color": "c77dff"},
	"zero": {"pool": 1, "hp": 1.2, "summon": 1, "minion": "", "color": "8da2c0"},
	"mirage": {"pool": 0, "hp": 0.85, "summon": 1, "minion": "", "color": "e084ff", "min_tier": 2},
	"chrono": {"pool": 0, "hp": 1.0, "summon": 1, "minion": "", "color": "d6b26a", "min_tier": 3},
	"hyoga": {"pool": 0, "hp": 0.9, "summon": 1, "minion": "", "color": "8fdcff", "min_tier": 4},
	"homura": {"pool": 1, "hp": 0.7, "summon": 1, "minion": "", "color": "ff7a3d", "min_tier": 3},
	"tsukuyo": {"pool": 1, "hp": 1.0, "summon": 1, "minion": "", "color": "c7cfff", "min_tier": 5},
	"void": {"pool": 1, "hp": 1.3, "summon": 2, "minion": "", "color": "7a5cff", "min_tier": 8},
}


static func ids() -> Array[String]:
	var list: Array[String] = []
	for id: String in BOSSES:
		list.append(id)
	return list


static func in_pool(pool: int, tier := 0) -> Array[String]:
	var list: Array[String] = []
	for id: String in BOSSES:
		if int(BOSSES[id]["pool"]) == pool and min_tier(id) <= tier:
			list.append(id)
	return list


static func min_tier(id: String) -> int:
	return int(BOSSES[id].get("min_tier", 0))


static func color(id: String) -> Color:
	return Color(String(BOSSES[id]["color"]))
