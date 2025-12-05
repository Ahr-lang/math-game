extends Control

@onready var variable_input = $MainPanel/SidePanel/"Number of variables"  # SpinBox
@onready var reshuffle_button = $MainPanel/SidePanel/ReshuffleButton     # Button
@onready var matrix_container = $MainPanel/MatrixArea/MatrixRoot/MatrixContainer     # GridContainer
@onready var separator        = $MainPanel/MatrixArea/MatrixRoot/Separator
var tile_scene = preload("res://scenes/MatrixTile.tscn")

var row_colors: Array = []

func _ready():
	randomize()
	variable_input.value = 3
	reshuffle_button.pressed.connect(_on_reshuffle_pressed)
	matrix_container.resized.connect(_schedule_separator_update)
	separator.anchor_left = 0.0
	separator.anchor_right = 0.0
	separator.anchor_top = 0.0
	separator.anchor_bottom = 0.0
	_create_matrix()

func _on_reshuffle_pressed():
	_create_matrix()

func _create_matrix():
	var n = int(variable_input.value)
	var total_columns = n + 1  # incluye columna aumentada
	matrix_container.columns = total_columns

	# Limpia colores y tiles previos
	row_colors.clear()
	for child in matrix_container.get_children():
		child.queue_free()

	# Distribuye colores del arcoíris uniformemente y los mezcla
	var hues: Array = []
	for i in range(n):
		hues.append(float(i) / n)
	hues.shuffle()

	for hue in hues:
		var rainbow_color := Color.from_hsv(hue, 1.0, 1.0)
		row_colors.append(rainbow_color)

	# Crea los bloques
	for row in range(n):
		var row_color = row_colors[row]
		var is_last_row = (row == n - 1)

		for col in range(total_columns):
			var tile = tile_scene.instantiate()
			matrix_container.add_child(tile)
			tile.set_value(
				randi() % 21 - 10,
				row_color,
				is_last_row,
				col,
				total_columns
			)

	_schedule_separator_update()

func _schedule_separator_update() -> void:
	call_deferred("_update_separator_position")

func _update_separator_position() -> void:
	if matrix_container.get_child_count() == 0:
		return

	await get_tree().process_frame

	var last_col_index: int = matrix_container.columns - 1
	var prev_col_index: int = last_col_index - 1
	if prev_col_index < 0:
		return

	# tiles: previous column and last column
	var prev_tile: Control = matrix_container.get_child(prev_col_index)
	var last_tile: Control = matrix_container.get_child(last_col_index)

	var parent_global: Vector2 = separator.get_parent().global_position
	var matrix_global_y: float = matrix_container.global_position.y

	# edges
	var prev_right: float = prev_tile.global_position.x + prev_tile.size.x
	var last_left: float = last_tile.global_position.x

	# midpoint between them -> where the line should be centered
	var mid_x: float = (prev_right + last_left) * 0.5

	var line_width: float = max(separator.custom_minimum_size.x, 4.0)
	separator.size = Vector2(line_width, matrix_container.size.y)

	# local position inside parent, centered on mid_x
	separator.position = Vector2(
		mid_x - parent_global.x - line_width * 0.5,
		matrix_global_y - parent_global.y
	)

	# only if your Separator has a script with set_line()
	if separator.has_method("set_line"):
		separator.set_line(line_width * 0.5, 0.0, separator.size.y)
