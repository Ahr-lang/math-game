extends Panel

@onready var label = $Label

func _ready():
	custom_minimum_size = Vector2(100, 100)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func set_value(val: int, color: Color, is_last_row := false, col := 0, total_cols := 0):
	label.text = str(val)
	label.add_theme_color_override("font_color", color)

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.1)  # fondo gris oscuro
	stylebox.border_color = color

	var border_thickness := 10
	stylebox.border_width_left = border_thickness
	stylebox.border_width_right = border_thickness
	stylebox.border_width_top = border_thickness
	stylebox.border_width_bottom = border_thickness



	add_theme_stylebox_override("panel", stylebox)
