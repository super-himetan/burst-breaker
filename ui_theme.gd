extends RefCounted
## The game's look in one place: a dark ink base with a small set of bright pastels.

const INK := Color("0d0a1e")
const PANEL := Color(0.13, 0.11, 0.26, 0.72)
const PANEL_SOLID := Color("1b1738")
const LINE := Color(1.0, 1.0, 1.0, 0.11)
const TEXT := Color("f5f3ff")
const MUTED := Color("a5a1c9")
const ACCENT := Color("ff5c8a")
const GOLD := Color("ffd166")
const STAR := Color("8be9fd")
const MINT := Color("5eead4")
const DANGER := Color("ff6b81")

## Block toughness runs along this ramp instead of a full rainbow.
const RAMP: Array[Color] = [Color("5eead4"), Color("67c7ff"), Color("a78bfa"), Color("f472b6"), Color("ff8a5c")]

const RARITY: Array[Color] = [Color("5eead4"), Color("67c7ff"), Color("b794ff"), Color("ffc35c")]

const BLOCKS := {
	"bomb": Color("ff7a45"),
	"shield": Color("c9d4e8"),
	"regen": Color("4ade80"),
	"armor": Color("4b5270"),
	"treasure": Color("ffd166"),
	"breeder": Color("c084fc"),
	"extra_ball": Color("f5f3ff"),
	"boss": Color("b3183f"),
	"elite": Color("ffd166"),
	"bounty": Color("fff1a8"),
}


## Position 0 to 1 along the toughness ramp.
static func ramp(position: float) -> Color:
	var scaled := clampf(position, 0.0, 1.0) * (RAMP.size() - 1)
	var index := mini(int(scaled), RAMP.size() - 2)
	return RAMP[index].lerp(RAMP[index + 1], scaled - index)
