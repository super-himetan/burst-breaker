extends SceneTree
## Renders icon.svg to the opaque 1024px PNG the App Store requires.
## Run: godot --headless --path . -s tools/make_ios_icon.gd

const SIZE := 1024
const BACKGROUND := Color("14122b")


func _init() -> void:
	var svg := Image.new()
	var scale_factor := float(SIZE) / 128.0
	if svg.load_svg_from_string(FileAccess.get_file_as_string("res://icon.svg"), scale_factor) != OK:
		push_error("Could not read icon.svg")
		quit(1)
		return
	svg.convert(Image.FORMAT_RGBA8)
	var opaque := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	opaque.fill(BACKGROUND)
	opaque.blend_rect(svg, Rect2i(Vector2i.ZERO, svg.get_size()), Vector2i.ZERO)
	opaque.convert(Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute("res://icons")
	quit(0 if opaque.save_png("res://icons/icon_1024.png") == OK else 1)
