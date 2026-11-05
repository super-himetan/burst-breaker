extends RefCounted
## Upgrade icons, drawn from shapes at any size. Coordinates run from -1 to 1 around the centre.
## The shape says what a perk does, and the colour says which build it belongs to.
## An evolution shows both of its parents, so its recipe can be read at a glance.

const Perks := preload("res://data/perks.gd")

const INK := Color("17122b")
const EVOLUTION_SCALE := 0.62
const EVOLUTION_OFFSET := 0.42
const SPARK_COLOR := Color("fff1a8")
const TAG_COLORS := {
	"split": Color("4fd1ff"),
	"blast": Color("ff9a3d"),
	"toxic": Color("6fdc6a"),
	"crit": Color("ff7ab0"),
	"bounce": Color("b48cff"),
	"swarm": Color("5ff0d0"),
	"power": Color("ff5f5f"),
	"fortune": Color("ffd84d"),
	"guard": Color("9db8ff"),
}

## Perk -> [glyph, optional "plus" badge for "more of the same"].
const ICONS := {
	"power": ["sword"], "heavy": ["hammer"], "crit": ["star"], "crit_power": ["star", "plus"],
	"first_strike": ["target"], "finisher": ["slash"], "opener": ["fresh_block"], "ricochet": ["wall_bounce"],
	"ceiling": ["ceiling"], "combo_power": ["combo"], "gambler": ["dice"], "glass": ["shard"],
	"more_balls": ["balls"], "rapid": ["chevrons"], "speed": ["dash"], "big_ball": ["big_ball"],
	"second_wind": ["rebound"], "floor_guard": ["floor"], "split": ["fork"], "split_power": ["fork", "plus"],
	"double_split": ["trident"], "pierce": ["pierce"], "aimbot": ["crosshair"], "bomb": ["bomb"],
	"bomb_power": ["bomb", "plus"], "bomb_radius": ["blast_rings"], "chain_reaction": ["links"], "poison": ["drop"],
	"poison_power": ["drop", "plus"], "burn": ["flame"], "shock": ["bolt"], "shockwave": ["wave"],
	"stall": ["hourglass"], "guard": ["shield"], "intercept": ["intercept"], "short_waves": ["short_rows"],
	"thin": ["squeeze"], "greed": ["coin"], "treasure": ["chest"], "interest": ["coin_stack"],
	"reroll": ["reroll"], "extra_choice": ["cards"], "lucky": ["clover"], "bounty": ["crown"],
	"reinforce": ["single_ball", "plus"], "overdrive": ["gauge"], "momentum": ["steps"], "last_stand": ["flag"],
}

## Shapes: poly/ipoly [points], line/iline [points, width], disc/idisc [x, y, r],
## ring [x, y, r, width], arc [x, y, r, from, to, width]. The "i" forms cut out in ink.
const GLYPHS := {
	"sword": [["poly", [0, -0.95, 0.17, -0.7, 0.17, 0.35, -0.17, 0.35, -0.17, -0.7]], ["line", [-0.42, 0.4, 0.42, 0.4], 0.15], ["line", [0, 0.42, 0, 0.9], 0.17]],
	"hammer": [["poly", [-0.65, -0.8, 0.65, -0.8, 0.65, -0.18, -0.65, -0.18]], ["line", [0, -0.2, 0, 0.9], 0.2]],
	"star": [["poly", [0, -0.95, 0.2, -0.2, 0.95, 0, 0.2, 0.2, 0, 0.95, -0.2, 0.2, -0.95, 0, -0.2, -0.2]]],
	"target": [["ring", 0, 0, 0.8, 0.14], ["ring", 0, 0, 0.45, 0.12], ["disc", 0, 0, 0.16]],
	"slash": [["line", [-0.72, -0.72, 0.72, 0.72], 0.24], ["line", [0.72, -0.72, -0.72, 0.72], 0.24]],
	"fresh_block": [["line", [-0.78, -0.55, 0.78, -0.55, 0.78, 0.55, -0.78, 0.55, -0.78, -0.55], 0.14], ["poly", [0, -0.36, 0.1, -0.1, 0.36, 0, 0.1, 0.1, 0, 0.36, -0.1, 0.1, -0.36, 0, -0.1, -0.1]]],
	"wall_bounce": [["line", [0.82, -0.92, 0.82, 0.92], 0.17], ["line", [-0.82, -0.72, 0.5, 0, -0.82, 0.72], 0.17], ["disc", -0.82, 0.72, 0.17]],
	"ceiling": [["line", [-0.9, -0.82, 0.9, -0.82], 0.18], ["line", [0, 0.85, 0, -0.42], 0.17], ["line", [-0.42, -0.04, 0, -0.48, 0.42, -0.04], 0.17]],
	"combo": [["disc", -0.62, 0.48, 0.18], ["disc", -0.06, 0.12, 0.27], ["disc", 0.5, -0.38, 0.38]],
	"dice": [["poly", [-0.78, -0.78, 0.78, -0.78, 0.78, 0.78, -0.78, 0.78]], ["idisc", -0.4, -0.4, 0.15], ["idisc", 0, 0, 0.15], ["idisc", 0.4, 0.4, 0.15]],
	"shard": [["poly", [-0.08, -0.95, 0.58, -0.2, 0.22, 0.92, -0.58, 0.35]], ["iline", [-0.08, -0.5, 0.1, -0.05, -0.12, 0.2, 0.08, 0.6], 0.07]],
	"balls": [["disc", -0.5, 0.38, 0.38], ["disc", 0.5, 0.38, 0.38], ["disc", 0, -0.45, 0.38]],
	"chevrons": [["line", [-0.65, -0.2, 0, -0.78, 0.65, -0.2], 0.2], ["line", [-0.65, 0.28, 0, -0.3, 0.65, 0.28], 0.2], ["line", [-0.65, 0.76, 0, 0.18, 0.65, 0.76], 0.2]],
	"dash": [["disc", 0.38, 0, 0.46], ["line", [-0.92, -0.42, -0.25, -0.42], 0.14], ["line", [-0.98, 0, -0.2, 0], 0.14], ["line", [-0.92, 0.42, -0.25, 0.42], 0.14]],
	"big_ball": [["disc", 0, 0, 0.85], ["idisc", -0.28, -0.28, 0.17]],
	"rebound": [["line", [-0.88, 0.78, 0.88, 0.78], 0.16], ["line", [-0.62, -0.5, 0, 0.5, 0.62, -0.5], 0.17], ["disc", 0.62, -0.62, 0.24]],
	"floor": [["line", [-0.92, 0.62, 0.92, 0.62], 0.34], ["disc", 0, -0.2, 0.42]],
	"fork": [["line", [0, 0.9, 0, 0.12], 0.2], ["line", [-0.62, -0.52, 0, 0.12, 0.62, -0.52], 0.2], ["disc", -0.64, -0.62, 0.24], ["disc", 0.64, -0.62, 0.24]],
	"trident": [["line", [0, 0.9, 0, -0.55], 0.18], ["line", [-0.68, -0.45, 0, 0.2, 0.68, -0.45], 0.18], ["disc", -0.7, -0.55, 0.21], ["disc", 0, -0.7, 0.21], ["disc", 0.7, -0.55, 0.21]],
	"pierce": [["line", [-0.36, -0.62, 0.36, -0.62, 0.36, 0.62, -0.36, 0.62, -0.36, -0.62], 0.12], ["line", [-0.95, 0, 0.9, 0], 0.17], ["line", [0.48, -0.38, 0.92, 0, 0.48, 0.38], 0.17]],
	"crosshair": [["ring", 0, 0, 0.58, 0.14], ["line", [0, -0.95, 0, -0.32], 0.14], ["line", [0, 0.32, 0, 0.95], 0.14], ["line", [-0.95, 0, -0.32, 0], 0.14], ["line", [0.32, 0, 0.95, 0], 0.14]],
	"bomb": [["disc", -0.08, 0.2, 0.68], ["line", [0.3, -0.34, 0.58, -0.68], 0.15], ["disc", 0.7, -0.8, 0.16], ["idisc", -0.32, -0.04, 0.13]],
	"blast_rings": [["disc", 0, 0, 0.32], ["ring", 0, 0, 0.6, 0.1], ["ring", 0, 0, 0.9, 0.1]],
	"links": [["ring", -0.4, 0, 0.42, 0.16], ["ring", 0.4, 0, 0.42, 0.16]],
	"drop": [["poly", [0, -0.95, 0.55, -0.1, 0.68, 0.32, 0.42, 0.75, 0, 0.9, -0.42, 0.75, -0.68, 0.32, -0.55, -0.1]], ["idisc", -0.25, 0.32, 0.13]],
	"flame": [["poly", [0.05, -0.95, 0.28, -0.42, 0.62, -0.2, 0.72, 0.3, 0.42, 0.8, 0, 0.93, -0.42, 0.8, -0.72, 0.3, -0.52, -0.12, -0.25, 0.02, -0.2, -0.5]], ["ipoly", [0, 0.12, 0.27, 0.48, 0, 0.8, -0.27, 0.48]]],
	"bolt": [["poly", [0.22, -0.95, -0.58, 0.14, -0.06, 0.14, -0.22, 0.95, 0.58, -0.2, 0.05, -0.2]]],
	"wave": [["disc", 0, 0, 0.2], ["arc", 0, 0, 0.55, -50, 50, 0.14], ["arc", 0, 0, 0.55, 130, 230, 0.14], ["arc", 0, 0, 0.88, -50, 50, 0.14], ["arc", 0, 0, 0.88, 130, 230, 0.14]],
	"hourglass": [["poly", [-0.62, -0.88, 0.62, -0.88, 0.09, 0, 0.62, 0.88, -0.62, 0.88, -0.09, 0]]],
	"shield": [["poly", [0, -0.92, 0.76, -0.62, 0.7, 0.2, 0, 0.95, -0.7, 0.2, -0.76, -0.62]], ["iline", [-0.3, 0, -0.04, 0.26, 0.34, -0.26], 0.1]],
	"intercept": [["line", [-0.88, 0.5, 0.88, 0.5], 0.22], ["line", [0, -0.88, 0, 0.14], 0.18], ["line", [-0.38, -0.22, 0, 0.18, 0.38, -0.22], 0.18]],
	"short_rows": [["line", [-0.82, -0.56, 0.82, -0.56], 0.26], ["line", [-0.82, 0, 0.82, 0], 0.26], ["line", [-0.34, 0.6, 0.34, 0.6], 0.2]],
	"squeeze": [["poly", [-0.85, -0.17, 0.85, -0.17, 0.85, 0.17, -0.85, 0.17]], ["line", [0, -0.95, 0, -0.42], 0.13], ["line", [-0.26, -0.62, 0, -0.36, 0.26, -0.62], 0.13], ["line", [0, 0.95, 0, 0.42], 0.13], ["line", [-0.26, 0.62, 0, 0.36, 0.26, 0.62], 0.13]],
	"coin": [["disc", 0, 0, 0.85], ["iline", [0, -0.42, 0, 0.42], 0.17]],
	"chest": [["poly", [-0.82, -0.02, 0.82, -0.02, 0.82, 0.76, -0.82, 0.76]], ["poly", [-0.82, -0.18, -0.6, -0.72, 0.6, -0.72, 0.82, -0.18]], ["idisc", 0, 0.24, 0.17]],
	"coin_stack": [["line", [-0.62, 0.66, 0.62, 0.66], 0.3], ["line", [-0.62, 0.22, 0.62, 0.22], 0.3], ["line", [-0.62, -0.22, 0.62, -0.22], 0.3], ["line", [-0.62, -0.66, 0.62, -0.66], 0.3]],
	"reroll": [["arc", 0, 0, 0.66, -60, 240, 0.2], ["poly", [0.08, -0.98, 0.72, -0.72, 0.2, -0.3]]],
	"cards": [["line", [-0.82, -0.62, -0.1, -0.78, 0.18, 0.5, -0.54, 0.66, -0.82, -0.62], 0.11], ["poly", [-0.02, -0.46, 0.68, -0.62, 0.92, 0.62, 0.22, 0.78]]],
	"clover": [["disc", 0, -0.46, 0.38], ["disc", 0.46, 0, 0.38], ["disc", 0, 0.46, 0.38], ["disc", -0.46, 0, 0.38], ["line", [0.2, 0.2, 0.72, 0.9], 0.13]],
	"crown": [["poly", [-0.88, 0.62, -0.88, -0.52, -0.42, 0, 0, -0.74, 0.42, 0, 0.88, -0.52, 0.88, 0.62]]],
	"single_ball": [["disc", -0.1, -0.1, 0.62]],
	"gauge": [["arc", 0, 0.28, 0.78, 180, 360, 0.2], ["line", [0, 0.28, 0.5, -0.32], 0.15], ["disc", 0, 0.28, 0.16]],
	"steps": [["line", [-0.62, 0.86, -0.62, 0.3], 0.32], ["line", [0, 0.86, 0, -0.18], 0.32], ["line", [0.62, 0.86, 0.62, -0.78], 0.32]],
	"flag": [["line", [-0.52, -0.92, -0.52, 0.92], 0.15], ["poly", [-0.46, -0.88, 0.8, -0.45, -0.46, -0.02]]],
}


static func color_of(id: String) -> Color:
	var tags := Perks.tags_of(id)
	return TAG_COLORS[tags[0]]


static func draw(canvas: CanvasItem, id: String, center: Vector2, radius: float, alpha := 1.0) -> void:
	if Perks.is_evolution(id):
		var parents: Array = Perks.PERKS[id]["requires"]
		var offset := Vector2(radius, radius) * EVOLUTION_OFFSET
		draw_single(canvas, parents[0], center - offset, radius * EVOLUTION_SCALE, alpha)
		draw_single(canvas, parents[1], center + offset, radius * EVOLUTION_SCALE, alpha)
		_draw_shape(canvas, GLYPHS["star"][0], center + Vector2(radius, -radius) * EVOLUTION_OFFSET, radius * 0.42, Color(SPARK_COLOR, alpha))
		return
	draw_single(canvas, id, center, radius, alpha)


static func draw_single(canvas: CanvasItem, id: String, center: Vector2, radius: float, alpha := 1.0) -> void:
	var icon: Array = ICONS[id]
	var color := Color(color_of(id), alpha)
	for shape: Array in GLYPHS[icon[0]]:
		_draw_shape(canvas, shape, center, radius, color)
	if icon.size() > 1:
		var badge := center + Vector2(radius, radius) * 0.62
		var arm := radius * 0.26
		canvas.draw_circle(badge, radius * 0.38, Color(INK, alpha))
		canvas.draw_line(badge - Vector2(arm, 0.0), badge + Vector2(arm, 0.0), Color(Color.WHITE, alpha), maxf(radius * 0.13, 1.5))
		canvas.draw_line(badge - Vector2(0.0, arm), badge + Vector2(0.0, arm), Color(Color.WHITE, alpha), maxf(radius * 0.13, 1.5))


static func _draw_shape(canvas: CanvasItem, shape: Array, center: Vector2, radius: float, color: Color) -> void:
	var kind: String = shape[0]
	var paint := Color(INK, color.a) if kind.begins_with("i") else color
	match kind:
		"poly", "ipoly":
			canvas.draw_colored_polygon(_points(shape[1], center, radius), paint)
		"line", "iline":
			canvas.draw_polyline(_points(shape[1], center, radius), paint, float(shape[2]) * radius, true)
		"disc", "idisc":
			canvas.draw_circle(center + Vector2(shape[1], shape[2]) * radius, float(shape[3]) * radius, paint)
		"ring":
			canvas.draw_arc(center + Vector2(shape[1], shape[2]) * radius, float(shape[3]) * radius, 0.0, TAU, 40, paint, float(shape[4]) * radius, true)
		"arc":
			canvas.draw_arc(center + Vector2(shape[1], shape[2]) * radius, float(shape[3]) * radius, deg_to_rad(shape[4]), deg_to_rad(shape[5]), 24, paint, float(shape[6]) * radius, true)


static func _points(flat: Array, center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		points.append(center + Vector2(flat[i], flat[i + 1]) * radius)
	return points
