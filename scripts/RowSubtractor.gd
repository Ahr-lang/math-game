# RowSubtractor.gd
# Resta una fila origen a una fila destino y actualiza los tiles visibles.

extends RefCounted
class_name RowSubtractor


static func subtract_rows(matrix_container: GridContainer, n: int, source_row: int, target_row: int, row_colors: Array) -> void:
	if source_row == target_row:
		return

	var visual_cols := n + 3
	var children := matrix_container.get_children()
	var total_children := children.size()

	if total_children == 0 or total_children % visual_cols != 0:
		push_warning("RowSubtractor.subtract_rows: child count no cuadra con filas completas.")
		return

	var num_rows := total_children / visual_cols
	if source_row < 0 or source_row >= num_rows:
		push_warning("RowSubtractor.subtract_rows: fila origen fuera de rango.")
		return
	if target_row < 0 or target_row >= num_rows:
		push_warning("RowSubtractor.subtract_rows: fila destino fuera de rango.")
		return

	var target_color: Color = Color.WHITE
	if target_row < row_colors.size():
		target_color = row_colors[target_row]

	var is_last_row := (target_row == n - 1)
	var logical_total_cols := n + 1

	for logical_col in range(logical_total_cols):
		var src_idx := _child_index_for_row_col(source_row, logical_col, visual_cols, n)
		var dst_idx := _child_index_for_row_col(target_row, logical_col, visual_cols, n)
		if src_idx < 0 or dst_idx < 0 or src_idx >= total_children or dst_idx >= total_children:
			continue

		var src_tile := children[src_idx]
		var dst_tile := children[dst_idx]
		var src_val := RowScalar._extract_fraction_value(src_tile)
		var dst_val := RowScalar._extract_fraction_value(dst_tile)
		var new_val := dst_val.sub(src_val)

		if dst_tile.has_method("set_value"):
			dst_tile.set_value(new_val, target_color, is_last_row, logical_col, logical_total_cols)
		elif dst_tile.has_node("Label"):
			var label: Label = dst_tile.get_node("Label")
			label.text = new_val.to_string()


static func _child_index_for_row_col(row_index: int, logical_col: int, visual_cols: int, n: int) -> int:
	if visual_cols <= 0:
		return -1
	var base := row_index * visual_cols
	if logical_col < n:
		return base + 1 + logical_col  # salto header
	return base + visual_cols - 1      # columna aumentada


static func _extract_numeric_value(tile: Node) -> float:
	if tile.has_node("Label"):
		var label: Label = tile.get_node("Label")
		var text := label.text.strip_edges()
		if text.is_valid_float():
			return float(text)
		if text.is_valid_int():
			return float(int(text))
	return 0.0
