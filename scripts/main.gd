extends Control

# --------- Referencias a nodos del árbol de la escena ---------

# SpinBox para elegir el número de variables (tamaño de la matriz)
@onready var variable_input   = $MainPanel/SidePanel/"Number of variables"

# Botón para volver a generar la matriz (reshuffle)
@onready var reshuffle_button = $MainPanel/SidePanel/ReshuffleButton
@onready var operation_label  = $MainPanel/SidePanel/OperationLabel
@onready var operation_text   = $MainPanel/SidePanel/OperationText

# GridContainer donde colocamos todos los tiles (Rk, coeficientes, espaciador, aumentada)
@onready var matrix_container = $MainPanel/MatrixArea/MatrixRoot/MatrixContainer

# Nodo Separator (la línea blanca vertical que se dibuja en medio del hueco)
@onready var separator        = $MainPanel/MatrixArea/MatrixRoot/Separator
@onready var history_panel    = $MainPanel/SidePanel/HistoryPanel


# --------- Escenas / scripts auxiliares ---------

# Celda de la matriz (números y también headers R1, R2, ...)
var tile_scene        = preload("res://scenes/MatrixTile.tscn")
var MatrixGeneratorScript   = preload("res://scripts/MatrixGenerator.gd")
var RowOperationsScript     = preload("res://scripts/RowOperations.gd")
var RowScalarScript         = preload("res://scripts/RowScalar.gd")
var RowDividerScript        = preload("res://scripts/RowDivider.gd")
var RowAdderScript          = preload("res://scripts/RowAdder.gd")
var RowSubtractorScript     = preload("res://scripts/RowSubtractor.gd")

# Generador de sistemas Ax = b con solución garantizada


# Operaciones

# --------- Datos de estado ---------

# Array para guardar los colores de cada fila (arcoíris)
var row_colors: Array = []

# Seguimiento del modo de interacción y la selección de intercambio
enum InteractionMode { SWITCH, MULTIPLY, DIVIDE, ADD, SUBTRACT }
var interaction_mode := InteractionMode.SWITCH
var selected_row_for_swap: int = -1
var selected_row_for_scalar: int = -1
var selected_row_for_add_source: int = -1
var selected_row_for_add_target: int = -1
var hovered_row_for_add_target: int = -1
var scalar_input_buffer: String = ""
var current_visual_columns: int = 0

# Ancho extra del hueco entre la última columna normal y la aumentada
# Este espacio es donde va a vivir la línea blanca
const EXTRA_COLUMN_GAP: float = 40.0


func _ready():
	# Semilla random para que los números sean diferentes cada vez
	randomize()

	# Valor inicial del SpinBox (por ejemplo 3 variables)
	variable_input.value = 3

	# Conectamos el botón de reshuffle al método que vuelve a crear la matriz
	reshuffle_button.pressed.connect(_on_reshuffle_pressed)

	# Cada vez que el GridContainer cambie de tamaño, actualizamos la posición del separador
	matrix_container.resized.connect(_schedule_separator_update)

	# Hacemos que el Separator use las anclas completas (pero lo movemos vía position/size)
	separator.anchor_left = 0.0
	separator.anchor_right = 0.0
	separator.anchor_top = 0.0
	separator.anchor_bottom = 0.0

	# Creamos la matriz al inicio
	_create_matrix()
	_refresh_operation_ui()


# Cuando se presiona el botón "Reshuffle"
func _on_reshuffle_pressed():
	_create_matrix()
	_refresh_operation_ui()


func _create_matrix():
	# n = número de variables (y también número de filas/columnas principales)
	var n = int(variable_input.value)

	# Total de columnas "lógicas": las de la matriz (coeficientes) + 1 aumentada
	var logical_total_columns = n + 1

	# Total de columnas "visuales" que ve el GridContainer:
	#   1 (columna Rk) +
	#   n (coeficientes normales) +
	#   1 (espaciador invisible) +
	#   1 (aumentada)
	# = n + 3
	var visual_total_columns  = n + 3
	current_visual_columns = visual_total_columns
	matrix_container.columns = visual_total_columns

	# --- NUEVO: generamos la matriz aumentada [A|b] con solución garantizada ---
	# augmented_matrix[row][0..n-1] = coeficientes A
	# augmented_matrix[row][n]      = término independiente b
	var augmented_matrix: Array = MatrixGeneratorScript.generate_augmented(n, -5, 5)

	# Limpiamos cualquier cosa que estuviera antes en el GridContainer
	row_colors.clear()
	_reset_swap_selection()
	_clear_history()
	for child in matrix_container.get_children():
		child.queue_free()

	# Preparamos los colores de las filas:
	# Creamos n tonos de matiz de 0 a 1 distribuidos, luego los mezclamos (shuffle)
	var hues: Array = []
	for i in range(n):
		hues.append(float(i) / n)  # hue = 0, 1/n, 2/n, ... (arcoíris)
	hues.shuffle()

	# Convertimos cada hue en un Color RGB saturado y brillante
	for hue in hues:
		var rainbow_color := Color.from_hsv(hue, 1.0, 1.0)
		row_colors.append(rainbow_color)

	# ---------------------------------------------------------
	# Construcción de la matriz fila por fila
	# ---------------------------------------------------------
	for row in range(n):
		var row_color = row_colors[row]   # color asignado a esta fila
		var is_last_row = (row == n - 1)  # true si es la última fila

		# Valores de la fila: [ a_0, a_1, ..., a_{n-1}, b ]
		var row_vals: Array = augmented_matrix[row]

		# -----------------------------------------------------
		# 1) PRIMERA COLUMNA: etiqueta de fila "R1", "R2", ...
		# -----------------------------------------------------
		var row_label = tile_scene.instantiate()
		_attach_row_click_handler(row_label)
		matrix_container.add_child(row_label)

		# Usamos el método especial de MatrixTile para headers de fila
		if row_label.has_method("set_row_header"):
			# row + 1 porque row empieza en 0 (R1, R2, R3, ...)
			row_label.set_row_header(row + 1)

		# -----------------------------------------------------
		# 2) COLUMNAS NORMALES: coeficientes de la matriz A
		#    índices lógicos de columna: 0..(n-1)
		# -----------------------------------------------------
		for col in range(n):
			var tile = tile_scene.instantiate()
			_attach_row_click_handler(tile)
			matrix_container.add_child(tile)

			# Usamos el valor generado en la matriz A
			tile.set_value(
				row_vals[col],          # valor a_ij
				row_color,              # color de la fila
				is_last_row,            # si es la última fila
				col,                    # índice lógico de columna (0..n-1)
				logical_total_columns   # total lógico (n+1)
			)

		# -----------------------------------------------------
		# 3) COLUMNA ESPACIADORA (INVISIBLE)
		#    Solo sirve para crear un hueco más grande
		#    entre la última normal y la aumentada
		# -----------------------------------------------------
		var spacer := Control.new()      # Control vacío, sin escenas ni nada
		# Permitimos que los clics atraviesen el hueco
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Le damos un ancho mínimo para que fuerce el espacio
		spacer.custom_minimum_size = Vector2(EXTRA_COLUMN_GAP, 0.0)
		# Lo agregamos como una columna más
		matrix_container.add_child(spacer)

		# -----------------------------------------------------
		# 4) COLUMNA AUMENTADA (última columna lógica)
		#    índice lógico = n
		# -----------------------------------------------------
		var aug_tile = tile_scene.instantiate()
		_attach_row_click_handler(aug_tile)
		matrix_container.add_child(aug_tile)

		aug_tile.set_value(
			row_vals[n],              # término independiente b_i
			row_color,                # mismo color de la fila
			is_last_row,              # si es la última fila
			n,                        # índice lógico de la columna aumentada
			logical_total_columns     # total lógico de columnas (n+1)
		)

	# Después de construir todo, programamos actualización del separador
	_schedule_separator_update()


# En vez de llamar directamente a _update_separator_position, usamos call_deferred
# para asegurarnos de que el layout ya se haya calculado.
func _schedule_separator_update() -> void:
	call_deferred("_update_separator_position")


func _update_separator_position() -> void:
	# Si todavía no hay hijos en el GridContainer, no hacemos nada
	if matrix_container.get_child_count() == 0:
		return

	# Esperamos un frame de proceso para que Godot termine de acomodar el GridContainer
	await get_tree().process_frame

	# Recordatorio de la estructura visual de columnas en el GridContainer:
	#   col 0        -> Rk (etiqueta de fila)
	#   col 1..n     -> columnas normales (coeficientes)
	#   col n+1      -> espaciador (invisible)
	#   col n+2      -> columna aumentada
	#   columns = n + 3

	# Índice de la última columna visual (aumentada)
	var last_col_index: int = matrix_container.columns - 1      # n+2

	# Índice de la última columna NORMAL (antes del espaciador) = n
	# (saltamos el espaciador restando 2)
	var prev_col_index: int = last_col_index - 2                # n
	if prev_col_index < 0:
		return

	# Obtenemos la referencia al Control de la última normal (primera fila)
	var prev_tile: Control = matrix_container.get_child(prev_col_index)

	# Y el Control de la columna aumentada (primera fila)
	var last_tile: Control = matrix_container.get_child(last_col_index)

	# Posición global del padre del separador (para convertir de global a local)
	var parent_global: Vector2 = separator.get_parent().global_position

	# Posición vertical de la matriz (para alinear el separador en Y)
	var matrix_global_y: float = matrix_container.global_position.y

	# ---------------------------------------------------------
	# Calculamos el hueco entre la última normal y la aumentada
	# ---------------------------------------------------------

	# Borde derecho de la última columna normal
	var prev_right: float = prev_tile.global_position.x + prev_tile.size.x

	# Borde izquierdo de la columna aumentada
	var last_left: float = last_tile.global_position.x

	# Punto medio entre esos dos bordes → x donde va centrada la línea
	var mid_x: float = (prev_right + last_left) * 0.5

	# Ancho de la línea (usamos el mínimo definido o 4 px)
	var line_width: float = max(separator.custom_minimum_size.x, 4.0)

	# Ajustamos el tamaño del separador:
	#   - ancho = line_width
	#   - alto = altura del GridContainer (para cubrir toda la matriz)
	separator.size = Vector2(line_width, matrix_container.size.y)

	# Posicionamos el separador en coordenadas locales del padre:
	#   - X: centrado en mid_x
	#   - Y: alineado con el inicio de la matriz
	separator.position = Vector2(
		mid_x - parent_global.x - line_width * 0.5,
		matrix_global_y - parent_global.y
	)

	# Si el Separator tiene un método set_line (por ejemplo, si es un Line2D custom),
	# lo actualizamos para dibujar la línea de arriba a abajo.
	if separator.has_method("set_line"):
		separator.set_line(line_width * 0.5, 0.0, separator.size.y)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("swap_rows"):
		# Entramos en modo intercambio y limpiamos selección previa
		_set_interaction_mode(InteractionMode.SWITCH)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey

		if key_event.keycode == KEY_B:
			_set_interaction_mode(InteractionMode.MULTIPLY)
			return
		if key_event.keycode == KEY_D:
			_set_interaction_mode(InteractionMode.DIVIDE)
			return
		if key_event.keycode == KEY_A:
			_set_interaction_mode(InteractionMode.ADD)
			return
		if key_event.keycode == KEY_F:
			_set_interaction_mode(InteractionMode.SUBTRACT)
			return

		if interaction_mode == InteractionMode.MULTIPLY or interaction_mode == InteractionMode.DIVIDE:
			_handle_scalar_key_input(key_event)


# --------------------------
# Interacción y clics de filas
# --------------------------

func _attach_row_click_handler(control: Control) -> void:
	# Aseguramos que el control reciba eventos de ratón
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.gui_input.connect(Callable(self, "_on_cell_gui_input").bind(control))
	control.mouse_entered.connect(Callable(self, "_on_cell_mouse_entered").bind(control))
	control.mouse_exited.connect(Callable(self, "_on_cell_mouse_exited").bind(control))


func _on_cell_gui_input(event: InputEvent, control: Control) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if not (mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed):
		return

	var row_index := _row_index_for_child(control)
	if row_index < 0:
		return

	match interaction_mode:
		InteractionMode.SWITCH:
			_handle_row_swap_click(row_index)
		InteractionMode.MULTIPLY, InteractionMode.DIVIDE:
			_handle_row_multiply_click(row_index)
		InteractionMode.ADD:
			_handle_row_add_click(row_index)
		InteractionMode.SUBTRACT:
			_handle_row_add_click(row_index)


func _on_cell_mouse_entered(control: Control) -> void:
	var row_index := _row_index_for_child(control)
	if row_index < 0:
		return

	if interaction_mode == InteractionMode.ADD or interaction_mode == InteractionMode.SUBTRACT:
		if selected_row_for_add_source != -1:
			if row_index != selected_row_for_add_source:
				hovered_row_for_add_target = row_index
				_refresh_operation_ui()
			elif hovered_row_for_add_target != -1:
				hovered_row_for_add_target = -1
				_refresh_operation_ui()
	else:
		if hovered_row_for_add_target != -1:
			hovered_row_for_add_target = -1
			_refresh_operation_ui()


func _on_cell_mouse_exited(control: Control) -> void:
	var row_index := _row_index_for_child(control)
	if row_index == hovered_row_for_add_target:
		hovered_row_for_add_target = -1
		_refresh_operation_ui()


func _row_index_for_child(child: Control) -> int:
	if current_visual_columns <= 0:
		return -1

	var children := matrix_container.get_children()
	var child_index := children.find(child)
	if child_index == -1:
		return -1

	return int(child_index / float(current_visual_columns))


func _handle_row_swap_click(row_index: int) -> void:
	# Primer clic: marcamos la fila
	if selected_row_for_swap == -1:
		selected_row_for_swap = row_index
		_highlight_row(row_index, true)
		_refresh_operation_ui()
		return

	# Si volvemos a clicar la misma fila, cancelamos selección
	if row_index == selected_row_for_swap:
		_highlight_row(row_index, false)
		selected_row_for_swap = -1
		_refresh_operation_ui()
		return

	# Segundo clic en otra fila: intercambiamos
	var n := int(variable_input.value)
	var from_row := selected_row_for_swap
	var to_row := row_index
	RowOperationsScript.swap_rows(matrix_container, n, from_row, to_row)
	_add_history_entry("Intercambio: R%d <-> R%d" % [from_row + 1, to_row + 1])

	# Limpiamos resaltados tras el intercambio
	_highlight_row(from_row, false)
	_highlight_row(to_row, false)
	selected_row_for_swap = -1
	_refresh_operation_ui()


func _handle_row_multiply_click(row_index: int) -> void:
	if selected_row_for_scalar == row_index:
		_highlight_row(row_index, false)
		selected_row_for_scalar = -1
	else:
		_clear_row_highlights()
		selected_row_for_scalar = row_index
		_highlight_row(row_index, true)

	_refresh_operation_ui()


func _handle_row_add_click(row_index: int) -> void:
	# Primer clic define origen; segundo clic (distinto) aplica a destino
	if selected_row_for_add_source == -1:
		selected_row_for_add_source = row_index
		_highlight_row(row_index, true)
		hovered_row_for_add_target = -1
		_refresh_operation_ui()
		return

	# Si clicamos el mismo, cancelamos origen
	if row_index == selected_row_for_add_source and selected_row_for_add_target == -1:
		_highlight_row(row_index, false)
		selected_row_for_add_source = -1
		hovered_row_for_add_target = -1
		_refresh_operation_ui()
		return

	# Si ya hay origen y clicamos otro, ese otro es destino y aplicamos
	if row_index != selected_row_for_add_source:
		selected_row_for_add_target = row_index
		var n := int(variable_input.value)
		if interaction_mode == InteractionMode.SUBTRACT:
			RowSubtractorScript.subtract_rows(matrix_container, n, selected_row_for_add_source, selected_row_for_add_target, row_colors)
			_add_history_entry("R%d = R%d - R%d" % [selected_row_for_add_target + 1, selected_row_for_add_target + 1, selected_row_for_add_source + 1])
		else:
			RowAdderScript.add_rows(matrix_container, n, selected_row_for_add_source, selected_row_for_add_target, row_colors)
			_add_history_entry("R%d = R%d + R%d" % [selected_row_for_add_target + 1, selected_row_for_add_target + 1, selected_row_for_add_source + 1])

		# Limpiar selecciones y resaltados
		_highlight_row(selected_row_for_add_source, false)
		_highlight_row(selected_row_for_add_target, false)
		selected_row_for_add_source = -1
		selected_row_for_add_target = -1
		hovered_row_for_add_target = -1
		_refresh_operation_ui()


func _highlight_row(row_index: int, highlight: bool) -> void:
	if current_visual_columns <= 0:
		return

	var start := row_index * current_visual_columns
	var end := start + current_visual_columns
	var children := matrix_container.get_children()
	if end > children.size():
		return

	var color := Color(1.2, 1.2, 1.2, 1.0) if highlight else Color(1, 1, 1, 1)
	for i in range(start, end):
		var node = children[i]
		if node is CanvasItem:
			node.modulate = color


func _reset_swap_selection() -> void:
	selected_row_for_swap = -1
	selected_row_for_scalar = -1
	selected_row_for_add_source = -1
	selected_row_for_add_target = -1
	hovered_row_for_add_target = -1
	scalar_input_buffer = ""
	_clear_row_highlights()
	_refresh_operation_ui()


func _clear_row_highlights() -> void:
	for child in matrix_container.get_children():
		if child is CanvasItem:
			child.modulate = Color(1, 1, 1, 1)


func _clear_history() -> void:
	if history_panel == null:
		return

	for child in history_panel.get_children():
		history_panel.remove_child(child)
		child.queue_free()


func _add_history_entry(text: String) -> void:
	if history_panel == null:
		return

	var label := Label.new()
	label.text = text
	history_panel.add_child(label)


func _set_interaction_mode(mode: int) -> void:
	if interaction_mode == mode:
		return

	interaction_mode = mode as InteractionMode
	_reset_swap_selection()


func _handle_scalar_key_input(event: InputEventKey) -> void:
	match event.keycode:
		KEY_0, KEY_KP_0, KEY_1, KEY_KP_1, KEY_2, KEY_KP_2, KEY_3, KEY_KP_3, KEY_4, KEY_KP_4, KEY_5, KEY_KP_5, KEY_6, KEY_KP_6, KEY_7, KEY_KP_7, KEY_8, KEY_KP_8, KEY_9, KEY_KP_9:
			var digit := OS.get_keycode_string(event.keycode)
			scalar_input_buffer += digit
		KEY_PERIOD, KEY_KP_PERIOD:
			if not scalar_input_buffer.contains("."):
				if scalar_input_buffer == "":
					scalar_input_buffer = "0."
				else:
					scalar_input_buffer += "."
		KEY_MINUS, KEY_KP_SUBTRACT:
			if scalar_input_buffer == "":
				scalar_input_buffer = "-"
		KEY_BACKSPACE:
			if scalar_input_buffer.length() > 0:
				scalar_input_buffer = scalar_input_buffer.substr(0, scalar_input_buffer.length() - 1)
		KEY_ESCAPE:
			scalar_input_buffer = ""
			selected_row_for_scalar = -1
			_clear_row_highlights()
		KEY_ENTER, KEY_KP_ENTER:
			_apply_scalar_multiplier()
	_refresh_operation_ui()


func _apply_scalar_multiplier() -> void:
	if selected_row_for_scalar < 0:
		return
	if scalar_input_buffer == "" or scalar_input_buffer == "-":
		return

	var val := float(scalar_input_buffer)
	var n := int(variable_input.value)
	if interaction_mode == InteractionMode.DIVIDE:
		if val == 0.0:
			return
		RowDividerScript.divide_row(matrix_container, n, selected_row_for_scalar, val, row_colors)
		_add_history_entry("R%d / %s" % [selected_row_for_scalar + 1, scalar_input_buffer])
	else:
		RowScalarScript.multiply_row(matrix_container, n, selected_row_for_scalar, val, row_colors)
		_add_history_entry("R%d * %s" % [selected_row_for_scalar + 1, scalar_input_buffer])

	scalar_input_buffer = ""
	_refresh_operation_ui()


func _refresh_operation_ui() -> void:
	if operation_label == null or operation_text == null:
		return

	match interaction_mode:
		InteractionMode.SWITCH:
			operation_label.text = "Modo: Intercambio de filas"
			if selected_row_for_swap == -1:
				operation_text.text = "Haz clic en una fila y luego en otra para intercambiar. (B multiplicar, D dividir, A sumar, F restar)"
			else:
				operation_text.text = "Fila seleccionada: R%d. Clic en otra fila para intercambiar, o en la misma para cancelar. (B multiplicar, D dividir, A sumar, F restar)" % [selected_row_for_swap + 1]
		InteractionMode.MULTIPLY:
			operation_label.text = "Modo: Multiplicar fila"
			var scalar_display := scalar_input_buffer if scalar_input_buffer != "" else "_"
			if selected_row_for_scalar == -1:
				operation_text.text = "Selecciona una fila y escribe un número. Valor: %s (ENTER para aplicar, ESC para limpiar, swap_rows para volver)" % scalar_display
			else:
				var n := int(variable_input.value)
				var row_vals := _get_row_values(selected_row_for_scalar, n)
				var formula_left := _format_scalar_formula(row_vals, scalar_display, n, false)
				var equal_vals := _format_scalar_result(row_vals, scalar_display, false)
				operation_text.text = "R%d * %s. Escribe número y ENTER para aplicar. ESC limpia, clic de nuevo para cancelar selección.\n%s\n= %s" % [
					selected_row_for_scalar + 1,
					scalar_display,
					formula_left,
					equal_vals
				]
		InteractionMode.DIVIDE:
			operation_label.text = "Modo: Dividir fila"
			var scalar_display_div := scalar_input_buffer if scalar_input_buffer != "" else "_"
			if selected_row_for_scalar == -1:
				operation_text.text = "Selecciona una fila y escribe un número. Valor: %s (ENTER para aplicar, ESC para limpiar, swap_rows para volver)" % scalar_display_div
			else:
				var n_div := int(variable_input.value)
				var row_vals_div := _get_row_values(selected_row_for_scalar, n_div)
				var formula_left_div := _format_scalar_formula(row_vals_div, scalar_display_div, n_div, true)
				var equal_vals_div := _format_scalar_result(row_vals_div, scalar_display_div, true)
				operation_text.text = "R%d / %s. Escribe número y ENTER para aplicar. ESC limpia, clic de nuevo para cancelar selección.\n%s\n= %s" % [
					selected_row_for_scalar + 1,
					scalar_display_div,
					formula_left_div,
					equal_vals_div
				]
		InteractionMode.ADD:
			operation_label.text = "Modo: Sumar filas"
			if selected_row_for_add_source == -1:
				operation_text.text = "Selecciona la fila origen (A). Luego elige la fila destino para aplicar Rdest = Rdest + Rorigen."
			elif selected_row_for_add_target == -1:
				var n_add := int(variable_input.value)
				var src_vals_add := _get_row_values(selected_row_for_add_source, n_add)
				var preview_target_add := selected_row_for_add_target
				if preview_target_add == -1 and hovered_row_for_add_target != -1 and hovered_row_for_add_target != selected_row_for_add_source:
					preview_target_add = hovered_row_for_add_target

				if preview_target_add != -1 and preview_target_add != selected_row_for_add_source:
					var tgt_vals_preview := _get_row_values(preview_target_add, n_add)
					var formula_preview := _format_addsub_formula(tgt_vals_preview, src_vals_add, false, n_add)
					operation_text.text = "Origen: R%d. Destino (hover): R%d. Se aplicaría Rdest = Rdest + Rorigen.\n%s\n= %s" % [
						selected_row_for_add_source + 1,
						preview_target_add + 1,
						formula_preview[0],
						formula_preview[1]
					]
				else:
					operation_text.text = "Origen: R%d. Selecciona la fila destino para aplicar Rdest = Rdest + R%d." % [selected_row_for_add_source + 1, selected_row_for_add_source + 1]
			else:
				var n_add2 := int(variable_input.value)
				var tgt_vals_add := _get_row_values(selected_row_for_add_target, n_add2)
				var src_vals_add2 := _get_row_values(selected_row_for_add_source, n_add2)
				var formula_add2 := _format_addsub_formula(tgt_vals_add, src_vals_add2, false, n_add2)
				operation_text.text = "Origen: R%d. Destino: R%d. Se aplicó Rdest = Rdest + Rorigen.\n%s\n= %s" % [
					selected_row_for_add_source + 1,
					selected_row_for_add_target + 1,
					formula_add2[0],
					formula_add2[1]
				]
		InteractionMode.SUBTRACT:
			operation_label.text = "Modo: Restar filas"
			if selected_row_for_add_source == -1:
				operation_text.text = "Selecciona la fila origen (A). Luego elige la fila destino para aplicar Rdest = Rdest - Rorigen."
			elif selected_row_for_add_target == -1:
				var n_sub_preview := int(variable_input.value)
				var src_vals_prev := _get_row_values(selected_row_for_add_source, n_sub_preview)
				var preview_target_sub := selected_row_for_add_target
				if preview_target_sub == -1 and hovered_row_for_add_target != -1 and hovered_row_for_add_target != selected_row_for_add_source:
					preview_target_sub = hovered_row_for_add_target

				if preview_target_sub != -1 and preview_target_sub != selected_row_for_add_source:
					var tgt_vals_prev := _get_row_values(preview_target_sub, n_sub_preview)
					var formula_prev := _format_addsub_formula(tgt_vals_prev, src_vals_prev, true, n_sub_preview)
					operation_text.text = "Origen: R%d. Destino (hover): R%d. Se aplicaría Rdest = Rdest - Rorigen.\n%s\n= %s" % [
						selected_row_for_add_source + 1,
						preview_target_sub + 1,
						formula_prev[0],
						formula_prev[1]
					]
				else:
					operation_text.text = "Origen: R%d. Selecciona la fila destino para aplicar Rdest = Rdest - R%d." % [selected_row_for_add_source + 1, selected_row_for_add_source + 1]
			else:
				var n_sub := int(variable_input.value)
				var tgt_vals := _get_row_values(selected_row_for_add_target, n_sub)
				var src_vals_sub := _get_row_values(selected_row_for_add_source, n_sub)
				var formula_sub := _format_addsub_formula(tgt_vals, src_vals_sub, true, n_sub)
				operation_text.text = "Origen: R%d. Destino: R%d. Se aplicó Rdest = Rdest - Rorigen.\n%s\n= %s" % [
					selected_row_for_add_source + 1,
					selected_row_for_add_target + 1,
					formula_sub[0],
					formula_sub[1]
				]


func _get_row_values(row_index: int, n: int) -> Array:
	var values: Array = []
	var logical_total := n + 1
	var children := matrix_container.get_children()

	for logical_col in range(logical_total):
		var idx := _child_index_for_row_col(row_index, logical_col, current_visual_columns, n)
		if idx < 0 or idx >= children.size():
			values.append(0.0)
			continue

		var tile := children[idx]
		var val := 0.0
		if tile.has_node("Label"):
			var label: Label = tile.get_node("Label")
			var text := label.text.strip_edges()
			if text.is_valid_float():
				val = float(text)
			elif text.is_valid_int():
				val = float(int(text))
		values.append(val)

	return values


func _child_index_for_row_col(row_index: int, logical_col: int, visual_cols: int, n: int) -> int:
	if visual_cols <= 0:
		return -1
	var base := row_index * visual_cols
	if logical_col < n:
		return base + 1 + logical_col  # saltar header Rk
	return base + visual_cols - 1      # columna aumentada


func _format_scalar_formula(row_vals: Array, scalar_display: String, n: int, is_divide: bool) -> String:
	var letters := "abcdefghijklmnopqrstuvwxyz"
	var parts: Array = []
	var symbol := "/%s" if is_divide else "%s"

	for i in range(row_vals.size()):
		if i < n:
			var letter := letters[i % letters.length()]
			parts.append("%s(%s)%s" % [row_vals[i], symbol % scalar_display, letter])
		else:
			parts.append("%s(%s)" % [row_vals[i], symbol % scalar_display])

	return "  ".join(parts)


func _format_scalar_result(row_vals: Array, scalar_display: String, is_divide: bool) -> String:
	if scalar_display == "_" or scalar_display == "-" or scalar_display == "":
		return ""

	if not scalar_display.is_valid_float():
		return ""

	var scalar := float(scalar_display)
	var results: Array = []
	for val in row_vals:
		if is_divide:
			results.append(str(val / scalar))
		else:
			results.append(str(val * scalar))
	return "  ".join(results)


func _format_addsub_formula(target_vals: Array, source_vals: Array, is_subtract: bool, n: int) -> Array:
	var symbol := "-" if is_subtract else "+"
	var letters := "abcdefghijklmnopqrstuvwxyz"
	var parts: Array = []
	var results: Array = []

	for i in range(target_vals.size()):
		var tgt: float = float(target_vals[i])
		var src: float = float(source_vals[i])
		var letter := ""
		if i < n:
			letter = letters[i % letters.length()]
			parts.append("%s %s %s%s" % [tgt, symbol, src, letter])
		else:
			parts.append("%s %s %s" % [tgt, symbol, src])

		var res: float = tgt - src if is_subtract else tgt + src
		results.append(str(res))

	return [ "  ".join(parts), "  ".join(results) ]
