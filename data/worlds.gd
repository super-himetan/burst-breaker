extends RefCounted
## Chapters a run can take place in. Each changes the sky and which element its blocks carry.
## `sky` holds three colours for the background; `min_tier` opens a chapter as difficulty rises.

const ELEMENT_COLORS := {"fire": Color("ff7a3d"), "ice": Color("8fdcff"), "volt": Color("ffe066")}
## Each element is strong against the next one round the circle.
const BEATS := {"fire": "ice", "ice": "volt", "volt": "fire"}
const STRONG := 1.5
const WEAK := 0.75
## Share of a chapter's pictures that carry its element.
const ELEMENT_CHANCE := 0.45

const WORLDS := {
	"wall": {"element": "", "min_tier": 0, "sky": [Color(0.30, 0.18, 0.62), Color(0.05, 0.42, 0.50), Color(0.72, 0.13, 0.42)]},
	"desert": {"element": "fire", "min_tier": 1, "sky": [Color(0.62, 0.30, 0.14), Color(0.55, 0.42, 0.12), Color(0.72, 0.18, 0.13)]},
	"glacier": {"element": "ice", "min_tier": 3, "sky": [Color(0.14, 0.35, 0.62), Color(0.10, 0.55, 0.60), Color(0.30, 0.25, 0.72)]},
	"cosmos": {"element": "volt", "min_tier": 5, "sky": [Color(0.20, 0.10, 0.45), Color(0.45, 0.12, 0.62), Color(0.05, 0.25, 0.55)]},
}


static func open_at(tier: int) -> Array[String]:
	var list: Array[String] = []
	for id: String in WORLDS:
		if int(WORLDS[id]["min_tier"]) <= tier:
			list.append(id)
	return list


## How much an attack of one element does to a block of another.
static func multiplier(attack: String, defence: String) -> float:
	if attack == "" or defence == "" or attack == defence:
		return 1.0
	if BEATS[attack] == defence:
		return STRONG
	return WEAK if BEATS[defence] == attack else 1.0
