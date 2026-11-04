extends RefCounted
## Difficulty tiers. Clearing a tier unlocks the next, with no upper limit.
## Rules accumulate; tiers past the last rule only raise block HP and rewards.

const HP_GROWTH := 1.3
const COIN_PER_TIER := 0.35

## Index i takes effect at tier i + 1.
const RULES: Array[String] = [
	"tougher",
	"more_specials",
	"extra_wave",
	"fewer_balls",
	"boss_hp",
	"fewer_bombs",
	"strong_regen",
	"no_free_reroll",
	"fewer_choices",
	"shorter_field",
]


static func has_rule(tier: int, rule: String) -> bool:
	var index := RULES.find(rule)
	return index >= 0 and tier > index


static func hp_scale(tier: int) -> float:
	return pow(HP_GROWTH, tier)


static func coin_scale(tier: int) -> float:
	return 1.0 + COIN_PER_TIER * tier
