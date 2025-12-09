# RowScalar.gd
# Multiplica una fila por un escalar y actualiza los tiles visibles.

extends RefCounted
class_name RowScalar


static func multiply_row(matrix_container: GridContainer, n: int, row_index: int, scalar, row_colors: Array) -> void:
	var visual_cols := n + 3
	var children := matrix_container.get_children()
	var total_children := children.size()

	if total_children == 0 or total_children % visual_cols != 0:
		push_warning("RowScalar.multiply_row: child count no cuadra con filas completas.")
		return

	var num_rows := total_children / visual_cols
	if row_index < 0 or row_index >= num_rows:
		push_warning("RowScalar.multiply_row: fila fuera de rango.")
		return

	var scalar_frac: Fraction
	if scalar is Fraction:
		scalar_frac = scalar
	else:
		scalar_frac = Fraction.from_variant(scalar)

	var row_color: Color = Color.WHITE
	if row_index < row_colors.size():
		row_color = row_colors[row_index]

	var is_last_row := (row_index == n - 1)
	var logical_total_cols := n + 1

	for logical_col in range(logical_total_cols):
		var child_index := _child_index_for_row_col(row_index, logical_col, visual_cols, n)
		if child_index < 0 or child_index >= total_children:
			continue

		var tile = children[child_index]
		if tile == null:
			continue

		var current_val := _extract_fraction_value(tile)
		var new_val := current_val.mul(scalar_frac)

		if tile.has_method("set_value"):
			tile.set_value(new_val, row_color, is_last_row, logical_col, logical_total_cols)
		elif tile.has_node("Label"):
			var label: Label = tile.get_node("Label")
			label.text = new_val.to_string()


static func _child_index_for_row_col(row_index: int, logical_col: int, visual_cols: int, n: int) -> int:
	var base := row_index * visual_cols
	if logical_col < n:
		return base + 1 + logical_col  # salta el header Rk
	# columna aumentada está al final (después del espaciador)
	return base + visual_cols - 1


static func _extract_fraction_value(tile: Node) -> Fraction:
	if tile.has_node("Label"):
		var label: Label = tile.get_node("Label")
		return Fraction.from_string(label.text)
	return Fraction.new(0)
