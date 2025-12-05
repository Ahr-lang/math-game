# Separator.gd
extends ColorRect

var line_x: float = -1.0
var line_top: float = 0.0
var line_bottom: float = 0.0

func set_line(x: float, top: float, bottom: float) -> void:
	line_x = x
	line_top = top
	line_bottom = bottom
	queue_redraw()

func _draw() -> void:
	if line_x < 0.0:
		return

	draw_line(
		Vector2(line_x, line_top),
		Vector2(line_x, line_bottom),
		Color.WHITE,
		4.0,
		true
	)
