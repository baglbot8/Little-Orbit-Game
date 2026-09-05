extends SceneTree
## Rasterize the existing vector artwork, compositing an opaque Home Screen tile.
func _initialize() -> void:
	var source := FileAccess.get_file_as_string("res://assets/orbit_icon.svg")
	for item in [[180, "apple-touch-icon.png"], [192, "icon-192.png"], [512, "icon-512.png"]]:
		var size: int = item[0]
		var art := Image.new()
		assert(art.load_svg_from_string(source, float(size) / 256.0) == OK)
		var tile := Image.create(size, size, false, Image.FORMAT_RGBA8)
		tile.fill(Color("142b35"))
		tile.blend_rect(art, Rect2i(0, 0, size, size), Vector2i.ZERO)
		tile.convert(Image.FORMAT_RGB8)
		assert(tile.save_png("res://web/" + item[1]) == OK)
	quit()
