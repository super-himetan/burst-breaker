extends RefCounted
## The pictures blocks fall in. Rows read top to bottom, seven columns wide, and every picture
## is left-right symmetric so it looks designed, not scattered.
## x one block, W a 2x1 block, B a 2x2 block, G a 3x2 block, + a cell a big block already covers.
## `shape` dresses the whole picture; "tri" alternates up and down so triangles interlock.

const COLS := 7

const ALL: Array[Dictionary] = [
	{"shape": "diamond", "rows": ["...x...", "..xxx..", ".xxxxx.", "..xxx..", "...x..."]},
	{"shape": "round", "rows": [".xx.xx.", "xxxxxxx", ".xxxxx.", "..xxx..", "...x..."]},
	{"shape": "hex", "rows": ["x.....x", ".x...x.", "..x.x..", "...x..."]},
	{"shape": "hex", "rows": ["...x...", "...x...", "xxxxxxx", "...x...", "...x..."]},
	{"shape": "tri", "rows": ["...x...", "..xxx..", ".xxxxx.", "xxxxxxx"]},
	{"shape": "tri", "rows": ["xxxxxxx", ".xxxxx.", "..xxx..", "...x..."]},
	{"shape": "pill", "rows": [".xxxxx.", "xx...xx", "x.....x"]},
	{"shape": "pill", "rows": ["x.x.x.x", "x.x.x.x", "x.x.x.x", "x.x.x.x"]},
	{"shape": "round", "rows": ["x.x.x.x", ".x.x.x.", "x.x.x.x"]},
	{"shape": "box", "rows": ["x..x..x", "xx.x.xx", "xxxxxxx"]},
	{"shape": "box", "rows": ["W+...W+", ".x.x.x.", "W+...W+"]},
	{"shape": "hex", "rows": [".xG++x.", ".x+++x."]},
	{"shape": "diamond", "rows": ["B+...B+", "++.x.++", "..xxx.."]},
	{"shape": "round", "rows": ["..G++..", "..+++..", ".x.x.x."]},
	{"shape": "box", "rows": ["xx.x.xx", ".xx.xx."]},
	{"shape": "pill", "rows": ["W+.x.W+"]},
	{"shape": "hex", "rows": ["xxxxxxx"]},
	{"shape": "round", "rows": ["x.x.x.x"]},
	{"shape": "tri", "rows": [".x.x.x."]},
]


## Some pictures that exactly fill `total` rows, listed in the order their rows should arrive:
## bottom row first.
static func queue_for(total: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var left := total
	while left > 0:
		var options: Array[Dictionary] = []
		for formation in ALL:
			if (formation["rows"] as Array).size() <= left:
				options.append(formation)
		var picked: Dictionary = options[rng.randi_range(0, options.size() - 1)]
		var rows: Array = picked["rows"]
		var mode := rng.randi_range(0, 2)
		for i in range(rows.size() - 1, -1, -1):
			queue.append({"row": rows[i], "shape": picked["shape"], "index": i, "height": rows.size(), "mode": mode})
		left -= rows.size()
	return queue


## How tough a cell is, from 0 to 1. Mirrors around the centre, so colours stay symmetric too.
static func toughness(col: float, row_index: int, height: int, mode: int) -> float:
	var from_center := absf(col - (COLS - 1) / 2.0) / ((COLS - 1) / 2.0)
	match mode:
		0:
			return 1.0 - from_center
		1:
			return from_center
	return float(row_index) / maxf(height - 1, 1)


## The block size a pattern letter stands for.
static func size_of(letter: String) -> Vector2i:
	match letter:
		"W":
			return Vector2i(2, 1)
		"B":
			return Vector2i(2, 2)
		"G":
			return Vector2i(3, 2)
	return Vector2i.ONE
