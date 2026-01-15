class_name MatrixGrid
extends RefCounted

var container: GridContainer
var separator: Control
var tile_scene: PackedScene
var extra_column_gap: float

# Callables para conectar señales
var on_tile_input: Callable 
var on_tile_mouse_enter: Callable
var on_tile_mouse_exit: Callable

func _init(p_container: GridContainer, p_separator: Control, p_tile_scene: PackedScene, p_gap: float):
	container = p_container
	separator = p_separator
	tile_scene = p_tile_scene
	extra_column_gap = p_gap

func setup_grid(n: int, augmented_matrix: Array, row_colors: Array) -> int:
	var logical_total_columns = n + 1
	var visual_total_columns  = n + 3
	container.columns = visual_total_columns
	
	# Limpiar hijos
	for child in container.get_children():
		child.queue_free()
		
	# Construcción de la matriz fila por fila
	for row in range(n):
		var row_color = row_colors[row]
		var is_last_row = (row == n - 1)
		var row_vals: Array = augmented_matrix[row]

		# 1) Header Rk
		var row_label = tile_scene.instantiate()
		_attach_handlers(row_label)
		container.add_child(row_label)
		if row_label.has_method("set_row_header"):
			row_label.set_row_header(row + 1)

		# 2) Coeficientes
		for col in range(n):
			var tile = tile_scene.instantiate()
			_attach_handlers(tile)
			container.add_child(tile)
			tile.set_value(row_vals[col], row_color, is_last_row, col, logical_total_columns)

		# 3) Espaciador
		var spacer := Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.custom_minimum_size = Vector2(extra_column_gap, 0.0)
		container.add_child(spacer)

		# 4) Aumentada
		var aug_tile = tile_scene.instantiate()
		_attach_handlers(aug_tile)
		container.add_child(aug_tile)
		aug_tile.set_value(row_vals[n], row_color, is_last_row, n, logical_total_columns)
		
	return visual_total_columns

func update_layout() -> void:
	_update_tile_sizes()
	update_separator_position()

func _update_tile_sizes() -> void:
	if container.get_child_count() == 0:
		return

	var cols: int = container.columns
	if cols <= 0:
		return

	var children := container.get_children()
	var rows: int = int(ceil(children.size() / float(cols)))
	if rows <= 0:
		return

	var h_sep: float = container.get_theme_constant("h_separation", "GridContainer")
	var v_sep: float = container.get_theme_constant("v_separation", "GridContainer")

	var available_width: float = container.size.x - (cols - 1) * h_sep
	var available_height: float = container.size.y - (rows - 1) * v_sep
	if available_width <= 0.0 or available_height <= 0.0:
		return

	var tile_cols: int = cols - 1
	if tile_cols <= 0:
		return

	var gap_width: float = extra_column_gap
	var tile_width: float = (available_width - gap_width) / tile_cols
	if tile_width <= 0.0:
		tile_width = available_width / cols
		gap_width = max(0.0, available_width - tile_width * tile_cols)

	var tile_height: float = available_height / rows
	if tile_height <= 0.0:
		return

	var font_size: int = int(clamp(tile_height * 0.45, 12.0, 60.0))

	for row in range(rows):
		for col in range(cols):
			var idx := row * cols + col
			if idx >= children.size():
				return
			var child = children[idx]
			if not (child is Control):
				continue
			var control := child as Control
			if col == cols - 2:
				control.custom_minimum_size = Vector2(gap_width, 0.0)
			else:
				control.custom_minimum_size = Vector2(tile_width, tile_height)
				if control.has_node("Label"):
					var label := control.get_node("Label") as Label
					if label:
						label.add_theme_font_size_override("font_size", font_size)

	container.queue_sort()

func update_separator_position() -> void:
	if container.get_child_count() == 0:
		return

	# Recordatorio: columns = n + 3 -> [header][...coef...][spacer][augmented]
	var cols: int = container.columns
	if cols < 3:
		return

	# Medimos el gap con posiciones globales para evitar desfases en resize/move
	var last_col_index: int = cols - 1
	var prev_col_index: int = last_col_index - 2
	if prev_col_index < 0:
		return

	var prev_tile: Control = container.get_child(prev_col_index)
	var last_tile: Control = container.get_child(last_col_index)
	if prev_tile == null or last_tile == null:
		return

	var prev_right: float = prev_tile.global_position.x + prev_tile.size.x
	var last_left: float = last_tile.global_position.x
	var mid_x: float = (prev_right + last_left) * 0.5

	var line_width: float = max(separator.custom_minimum_size.x, 4.0)

	separator.size = Vector2(line_width, container.size.y)
	separator.global_position = Vector2(
		mid_x - line_width * 0.5,
		container.global_position.y
	)

	if separator.has_method("set_line"):
		separator.set_line(line_width * 0.5, 0.0, separator.size.y)
func get_row_values(row_index: int, n: int, visual_cols: int) -> Array:
	var values: Array = []
	var logical_total := n + 1
	var children := container.get_children()

	for logical_col in range(logical_total):
		var idx := child_index_for_row_col(row_index, logical_col, visual_cols, n)
		if idx < 0 or idx >= children.size():
			values.append(Fraction.new(0))
			continue

		var tile := children[idx]
		var val := Fraction.new(0)
		if tile.has_node("Label"):
			var label: Label = tile.get_node("Label")
			val = Fraction.from_string(label.text)
		values.append(val)

	return values

func set_row_visual_state(row_index: int, is_solved: bool, is_misplaced: bool, n: int, visual_cols: int) -> void:
	var logical_total := n + 1
	var children := container.get_children()
	
	for logical_col in range(logical_total):
		var idx := child_index_for_row_col(row_index, logical_col, visual_cols, n)
		if idx >= 0 and idx < children.size():
			var tile = children[idx]
			if tile.has_method("set_solved"):
				tile.set_solved(is_solved)
			if tile.has_method("set_misplaced"):
				tile.set_misplaced(is_misplaced)

func highlight_row(row_index: int, highlight: bool, visual_cols: int) -> void:
	if visual_cols <= 0:
		return

	var start := row_index * visual_cols
	var end := start + visual_cols
	var children := container.get_children()
	if end > children.size():
		return

	var color := Color(1.2, 1.2, 1.2, 1.0) if highlight else Color(1, 1, 1, 1)
	for i in range(start, end):
		var node = children[i]
		if node is CanvasItem:
			node.modulate = color

func clear_highlights() -> void:
	for child in container.get_children():
		if child is CanvasItem:
			child.modulate = Color(1, 1, 1, 1)

func child_index_for_row_col(row_index: int, logical_col: int, visual_cols: int, n: int) -> int:
	if visual_cols <= 0:
		return -1
	var base := row_index * visual_cols
	if logical_col < n:
		return base + 1 + logical_col  # saltar header Rk
	return base + visual_cols - 1      # columna aumentada

func _attach_handlers(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	if on_tile_input.is_valid():
		control.gui_input.connect(on_tile_input.bind(control))
	if on_tile_mouse_enter.is_valid():
		control.mouse_entered.connect(on_tile_mouse_enter.bind(control))
	if on_tile_mouse_exit.is_valid():
		control.mouse_exited.connect(on_tile_mouse_exit.bind(control))

func row_index_for_child(child: Control, visual_cols: int) -> int:
	if visual_cols <= 0:
		return -1
	var children := container.get_children()
	var child_index := children.find(child)
	if child_index == -1:
		return -1
	return int(child_index / float(visual_cols))
