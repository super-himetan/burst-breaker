extends RefCounted
## Looks with no effect on play. `unlock` names the achievement that opens each one.

const ITEMS := {
	"skin_default": {"slot": "skin", "unlock": "", "shape": "circle", "color": ""},
	"skin_gold": {"slot": "skin", "unlock": "wins_2", "shape": "circle", "color": "ffd166"},
	"skin_star": {"slot": "skin", "unlock": "style_s_2", "shape": "star", "color": ""},
	"skin_diamond": {"slot": "skin", "unlock": "evolutions_2", "shape": "diamond", "color": ""},
	"skin_void": {"slot": "skin", "unlock": "rush_clears_1", "shape": "diamond", "color": "7a5cff"},
	"skin_origin": {"slot": "skin", "unlock": "boss_origin_1", "shape": "star", "color": "ffffff"},
	"trail_default": {"slot": "trail", "unlock": "", "mode": "combo"},
	"trail_none": {"slot": "trail", "unlock": "", "mode": "none"},
	"trail_ember": {"slot": "trail", "unlock": "explosions_2", "mode": "ember"},
	"trail_rainbow": {"slot": "trail", "unlock": "best_combo_3", "mode": "rainbow"},
	"sky_default": {"slot": "sky", "unlock": "", "colors": []},
	"sky_dusk": {"slot": "sky", "unlock": "wins_1", "colors": [Color(0.62, 0.20, 0.35), Color(0.55, 0.30, 0.15), Color(0.35, 0.12, 0.55)]},
	"sky_mint": {"slot": "sky", "unlock": "bosses_2", "colors": [Color(0.08, 0.50, 0.42), Color(0.10, 0.40, 0.55), Color(0.20, 0.55, 0.35)]},
	"sky_mono": {"slot": "sky", "unlock": "bursts_2", "colors": [Color(0.28, 0.28, 0.34), Color(0.20, 0.20, 0.26), Color(0.36, 0.36, 0.42)]},
}
const DEFAULTS := {"skin": "skin_default", "trail": "trail_default", "sky": "sky_default"}


static func ids() -> Array[String]:
	var list: Array[String] = []
	for id: String in ITEMS:
		list.append(id)
	return list
