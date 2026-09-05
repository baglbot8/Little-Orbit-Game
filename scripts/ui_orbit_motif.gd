extends Control
## Original, resolution-independent ink illustration used on paper goods.
var ink := Color("91aca0")
var planet_color := Color("d9bb82")
var seed_index := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size * Vector2(0.5, 0.52)
	var radius := minf(size.x * 0.24, size.y * 0.29)
	var orbit := PackedVector2Array()
	for i in range(65):
		var angle := TAU * float(i) / 64.0
		orbit.append(center + Vector2(cos(angle) * radius * 1.95, sin(angle) * radius * 0.68).rotated(-0.28))
	draw_polyline(orbit, Color(ink, 0.6), 1.6, true)
	draw_circle(center + Vector2(0, 3), radius, Color(ink, 0.18))
	draw_circle(center, radius, planet_color)
	draw_arc(center, radius * 0.78, 3.6, 5.3, 22, Color("fffae7"), 2.4, true)
	draw_circle(center + Vector2(radius * 1.63, -radius * 0.67), 4.0, ink)
	for i in range(5):
		var p := Vector2(size.x * (0.08 + fmod(float(i) * 0.213 + seed_index * 0.07, 0.86)), size.y * (0.18 if i % 2 == 0 else 0.81))
		var r := 3.0 if i % 2 == 0 else 2.0
		draw_line(p - Vector2(r, 0), p + Vector2(r, 0), ink, 1.4, true)
		draw_line(p - Vector2(0, r), p + Vector2(0, r), ink, 1.4, true)
