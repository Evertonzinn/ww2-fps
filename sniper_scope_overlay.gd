extends Control

# A transparent circular lens surrounded by an opaque vignette.
# Unlike the broken old shader, drawing uses the live viewport Control size.
const STEPS: int = 120
const BLACK: Color = Color(0.012, 0.013, 0.015, 0.97)
const HAIR: Color = Color(0.03, 0.03, 0.03, 0.90)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if size.x < 10.0 or size.y < 10.0:
		return
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.415
	var outer: float = size.length() * 2.0
	# Black quads cover only the area outside the transparent aperture.
	for i in range(STEPS):
		var a: float = TAU * float(i) / float(STEPS)
		var b: float = TAU * float(i + 1) / float(STEPS)
		var dir_a: Vector2 = Vector2(cos(a), sin(a))
		var dir_b: Vector2 = Vector2(cos(b), sin(b))
		var points: PackedVector2Array = PackedVector2Array([
			center + dir_a * radius,
			center + dir_a * outer,
			center + dir_b * outer,
			center + dir_b * radius
		])
		draw_colored_polygon(points, BLACK)
	draw_arc(center, radius, 0.0, TAU, 128, HAIR, 2.0, true)
	draw_line(center + Vector2(-radius * 0.85, 0), center + Vector2(radius * 0.85, 0), HAIR, 1.6, true)
	draw_line(center + Vector2(0, -radius * 0.85), center + Vector2(0, radius * 0.85), HAIR, 1.6, true)
	draw_circle(center, 1.7, HAIR)
	for sign in [-1.0, 1.0]:
		for step in range(1, 4):
			var x: float = float(step) * radius * 0.14 * sign
			draw_line(center + Vector2(x, -5), center + Vector2(x, 5), HAIR, 1.2, true)
