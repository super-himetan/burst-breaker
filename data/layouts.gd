extends RefCounted
## Unbreakable stage furniture, by stage index: a stage picks one layout, sometimes mirrored.
## Each piece is [kind, column, row]. Rows stay clear of where blocks first appear, and every
## layout must leave a route from the launcher to the top (the tests walk it to be sure).
## Kinds: wall, mover (a wall that slides each turn), bumper, ramp_l, ramp_r, portal (pairs).

const COLS := 7

const LAYOUTS := {
	1: [
		[["bumper", 1, 7], ["bumper", 3, 8], ["bumper", 5, 7]],
		[["bumper", 2, 7], ["bumper", 4, 7], ["bumper", 3, 9]],
	],
	2: [
		[["wall", 2, 8], ["wall", 3, 8], ["wall", 4, 8], ["ramp_r", 1, 8], ["ramp_l", 5, 8]],
		[["wall", 1, 7], ["wall", 1, 8], ["wall", 5, 7], ["wall", 5, 8], ["bumper", 3, 8]],
	],
	4: [
		[["wall", 0, 7], ["wall", 1, 7], ["wall", 2, 7], ["wall", 4, 7], ["wall", 5, 7], ["wall", 6, 7], ["bumper", 1, 9], ["bumper", 5, 9]],
		[["wall", 0, 6], ["wall", 1, 6], ["wall", 2, 6], ["wall", 3, 6], ["wall", 3, 8], ["wall", 4, 8], ["wall", 5, 8], ["wall", 6, 8]],
		[["wall", 0, 7], ["wall", 1, 7], ["wall", 2, 7], ["wall", 3, 7], ["wall", 4, 7], ["wall", 5, 7], ["portal", 1, 9], ["portal", 5, 6]],
	],
	5: [
		[["mover", 1, 7], ["mover", 4, 7], ["wall", 0, 6], ["wall", 6, 6], ["bumper", 3, 9]],
		[["portal", 0, 9], ["portal", 6, 6], ["ramp_r", 2, 7], ["ramp_l", 4, 7], ["wall", 3, 7], ["bumper", 3, 9]],
	],
	6: [
		[["wall", 0, 6], ["wall", 1, 6], ["wall", 2, 6], ["wall", 4, 8], ["wall", 5, 8], ["wall", 6, 8], ["mover", 3, 10], ["bumper", 1, 9]],
		[["mover", 0, 6], ["mover", 3, 6], ["mover", 6, 8], ["mover", 2, 8], ["bumper", 3, 10], ["portal", 0, 10], ["portal", 6, 7]],
	],
}


static func for_stage(stage: int) -> Array:
	return LAYOUTS.get(stage, [])


static func mirrored(layout: Array) -> Array:
	var flipped := []
	for piece: Array in layout:
		var kind: String = piece[0]
		if kind == "ramp_l":
			kind = "ramp_r"
		elif kind == "ramp_r":
			kind = "ramp_l"
		flipped.append([kind, COLS - 1 - int(piece[1]), piece[2]])
	return flipped
