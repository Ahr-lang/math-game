# RowOperations.gd
# Utilidades para operaciones de fila en la matriz (Gauss-Jordan).
#
# Estructura de cada fila en el GridContainer:
#   col 0        -> Rk (header de fila, NO SE MUEVE)
#   col 1..n     -> coeficientes normales
#   col n+1      -> espaciador (Control vacío)
#   col n+2      -> columna aumentada
#
# swap_rows(matrix_container, n, row_a, row_b):
#   - Intercambia el CONTENIDO de las filas row_a y row_b:
#       * coeficientes
#       * espaciador
#       * columna aumentada
#   - Las celdas Rk (columna 0) se quedan donde están.
#   - Los colores se van con las celdas, así que visualmente
#     ves que las filas se han intercambiado.

extends RefCounted
class_name RowOperations


static func swap_rows(matrix_container: GridContainer, n: int, row_a: int, row_b: int) -> void:
	# Si son la misma fila, no hay nada que hacer
	if row_a == row_b:
		return

	# Número de columnas visuales por fila:
	# Rk + n coeficientes + espaciador + aumentada
	var visual_cols := n + 3

	# Hijos actuales del GridContainer
	var children: Array = matrix_container.get_children()
	var total_children := children.size()

	# Chequeo de seguridad
	if total_children == 0 or total_children % visual_cols != 0:
		push_warning("RowOperations.swap_rows: child count no cuadra con filas completas.")
		return

	var num_rows := total_children / visual_cols

	# Validación de índices de fila
	if row_a < 0 or row_a >= num_rows:
		push_warning("RowOperations.swap_rows: row_a fuera de rango.")
		return
	if row_b < 0 or row_b >= num_rows:
		push_warning("RowOperations.swap_rows: row_b fuera de rango.")
		return

	# Aseguramos row_a < row_b para simplificar
	if row_a > row_b:
		var tmp_row := row_a
		row_a = row_b
		row_b = tmp_row

	# Copia que vamos a reordenar
	var new_children: Array = children.duplicate()

	# IMPORTANTE:
	#   col 0 es la Rk -> NO la tocamos
	#   intercambiamos solo desde col = 1 hasta visual_cols-1
	for col in range(1, visual_cols):
		var idx_a := row_a * visual_cols + col
		var idx_b := row_b * visual_cols + col

		var tmp_node = new_children[idx_a]
		new_children[idx_a] = new_children[idx_b]
		new_children[idx_b] = tmp_node

	# Reemplazamos el orden de los hijos del GridContainer
	for child in children:
		matrix_container.remove_child(child)

	for child in new_children:
		matrix_container.add_child(child)
