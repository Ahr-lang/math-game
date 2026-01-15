class_name GameState
extends RefCounted

var history_log: Array = []
var row_colors: Array = []

func clear():
	history_log.clear()
	row_colors.clear()

func add_history_entry(text: String, state_before: Dictionary, state_after: Dictionary):
	history_log.append({
		"desc": text,
		"before": state_before,
		"after": state_after
	})

func pop_history() -> Dictionary:
	if history_log.is_empty():
		return {}
	return history_log.pop_back()

func get_history_entry(idx: int) -> Dictionary:
	if idx < 0 or idx >= history_log.size():
		return {}
	return history_log[idx]

func history_size() -> int:
	return history_log.size()

func capture_state(n: int, grid_helper: MatrixGrid, visual_cols: int) -> Dictionary:
	var rows_data: Array = []
	for r in range(n):
		rows_data.append(grid_helper.get_row_values(r, n, visual_cols))
	
	return {
		"n": n,
		"rows": rows_data,
		"colors": row_colors.duplicate()
	}
