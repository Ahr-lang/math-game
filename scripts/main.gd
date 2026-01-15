extends Control

# --------- Referencias a nodos del árbol de la escena ---------

# SpinBox para elegir el número de variables (tamaño de la matriz)
@onready var variable_input   = $MainPanel/SidePanel/"Number of variables"

# Botón para volver a generar la matriz (reshuffle)
@onready var reshuffle_button = $MainPanel/SidePanel/ReshuffleButton
@onready var operation_label  = $MainPanel/SidePanel/OperationLabel
@onready var operation_text   = $MainPanel/SidePanel/OperationText
@onready var mode_add_button = $MainPanel/SidePanel/ModeBar/Add
@onready var mode_subtract_button = $MainPanel/SidePanel/ModeBar/Subtract
@onready var mode_multiply_button = $MainPanel/SidePanel/ModeBar/Multiply
@onready var mode_divide_button = $MainPanel/SidePanel/ModeBar/Divide
@onready var mode_switch_button = $MainPanel/SidePanel/ModeBar/Switch

# GridContainer donde colocamos todos los tiles (Rk, coeficientes, espaciador, aumentada)
@onready var matrix_container = $MainPanel/MatrixArea/MatrixRoot/MatrixContainer

# Nodo Separator (la línea blanca vertical que se dibuja en medio del hueco)
@onready var separator        = $MainPanel/MatrixArea/MatrixRoot/Separator
@onready var history_panel    = $MainPanel/SidePanel/HistoryPanel
@onready var back_button      = $MainPanel/SidePanel/BackButton

# --------- Escenas / scripts auxiliares ---------

# Celda de la matriz (números y también headers R1, R2, ...)
var tile_scene        = preload("res://scenes/MatrixTile.tscn")
var MatrixGeneratorScript   = preload("res://scripts/MatrixGenerator.gd")
var RowOperationsScript     = preload("res://scripts/RowOperations.gd")
var RowScalarScript         = preload("res://scripts/RowScalar.gd")
var RowDividerScript        = preload("res://scripts/RowDivider.gd")
var RowAdderScript          = preload("res://scripts/RowAdder.gd")
var RowSubtractorScript     = preload("res://scripts/RowSubtractor.gd")
var HistoryPreviewScript    = preload("res://scripts/HistoryPreview.gd")
# MatrixGrid y GameState son clases globales (class_name), no necesitan preload si Godot las detecta,
# pero por seguridad o si no se han refrescado:
# var MatrixGridScript = preload("res://scripts/MatrixGrid.gd") 
# var GameStateScript = preload("res://scripts/GameState.gd")

# Generador de sistemas Ax = b con solución garantizada


# Operaciones

# --------- Datos de estado ---------

var game_state: GameState
var matrix_grid: MatrixGrid

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
var _separator_update_frames: int = 0
var _mode_button_group: ButtonGroup

# Historial de estados para Undo y Preview
var history_preview_node: PopupPanel

# Ancho extra del hueco entre la última columna normal y la aumentada
# Este espacio es donde va a vivir la línea blanca
const EXTRA_COLUMN_GAP: float = 40.0


func _ready():
	# Semilla random para que los números sean diferentes cada vez
	randomize()
	
	# Inicializar helpers
	game_state = GameState.new()
	matrix_grid = MatrixGrid.new(matrix_container, separator, tile_scene, EXTRA_COLUMN_GAP)
	
	# Conectar callbacks del grid
	matrix_grid.on_tile_input = Callable(self, "_on_cell_gui_input")
	matrix_grid.on_tile_mouse_enter = Callable(self, "_on_cell_mouse_entered")
	matrix_grid.on_tile_mouse_exit = Callable(self, "_on_cell_mouse_exited")

	# Valor inicial del SpinBox (por ejemplo 3 variables)
	variable_input.value = 3

	# Habilitar BBCode para colorear fórmulas en el texto de operación
	if operation_text is RichTextLabel:
		var rtl := operation_text as RichTextLabel
		rtl.bbcode_enabled = true
		rtl.scroll_active = false
		rtl.add_theme_color_override("default_color", Color.WHITE)

	# Conectamos el botón de reshuffle al método que vuelve a crear la matriz
	reshuffle_button.pressed.connect(_on_reshuffle_pressed)
	
	# Conectamos el botón de Back
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		back_button.text = "Deshacer"
	_setup_mode_buttons()
	_sync_mode_buttons()

	# Cada vez que el GridContainer cambie de tamaño, actualizamos la posición del separador
	matrix_container.resized.connect(_schedule_separator_update)
	get_viewport().size_changed.connect(_schedule_separator_update)

	# Hacemos que el Separator use las anclas completas (pero lo movemos vía position/size)
	separator.anchor_left = 0.0
	separator.anchor_right = 0.0
	separator.anchor_top = 0.0
	separator.anchor_bottom = 0.0
	
	# Instanciar el preview de historial
	history_preview_node = HistoryPreviewScript.new()
	add_child(history_preview_node)

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

	# --- NUEVO: generamos la matriz aumentada [A|b] con solución garantizada ---
	var augmented_matrix: Array = MatrixGeneratorScript.generate_augmented(n, -5, 5)

	# Limpiamos estado
	game_state.clear()
	_reset_swap_selection()
	_clear_history()
	
	# Preparamos los colores de las filas:
	var hues: Array = []
	for i in range(n):
		hues.append(float(i) / n)
	hues.shuffle()

	for hue in hues:
		var rainbow_color := Color.from_hsv(hue, 1.0, 1.0)
		game_state.row_colors.append(rainbow_color)

	# Construcción de la matriz usando el helper
	current_visual_columns = matrix_grid.setup_grid(n, augmented_matrix, game_state.row_colors)

	# Después de construir todo, programamos actualización del separador
	_schedule_separator_update()
	_check_and_update_solved_rows()


# En vez de llamar directamente a _update_separator_position, usamos call_deferred
# para asegurarnos de que el layout ya se haya calculado.
func _schedule_separator_update() -> void:
	_separator_update_frames = max(_separator_update_frames, 2)
	set_process(true)


func _update_separator_position() -> void:
	matrix_grid.update_layout()


func _process(_delta: float) -> void:
	if _separator_update_frames <= 0:
		set_process(false)
		return
	_separator_update_frames -= 1
	_update_separator_position()
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
	
	var state_before = _capture_state()
	
	RowOperationsScript.swap_rows(matrix_container, n, from_row, to_row)

	# Actualizamos también el array de colores para que coincida con el cambio visual
	var tmp_color = game_state.row_colors[from_row]
	game_state.row_colors[from_row] = game_state.row_colors[to_row]
	game_state.row_colors[to_row] = tmp_color
	
	var state_after = _capture_state()

	_add_history_entry("Intercambio: R%d <-> R%d" % [from_row + 1, to_row + 1], state_before, state_after)

	# Limpiamos resaltados tras el intercambio
	_highlight_row(from_row, false)
	_highlight_row(to_row, false)
	selected_row_for_swap = -1
	_check_and_update_solved_rows()
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
		
		var state_before = _capture_state()
		
		if interaction_mode == InteractionMode.SUBTRACT:
			RowSubtractorScript.subtract_rows(matrix_container, n, selected_row_for_add_source, selected_row_for_add_target, game_state.row_colors)
			var state_after = _capture_state()
			_add_history_entry("R%d = R%d - R%d" % [selected_row_for_add_target + 1, selected_row_for_add_target + 1, selected_row_for_add_source + 1], state_before, state_after)
		else:
			RowAdderScript.add_rows(matrix_container, n, selected_row_for_add_source, selected_row_for_add_target, game_state.row_colors)
			var state_after = _capture_state()
			_add_history_entry("R%d = R%d + R%d" % [selected_row_for_add_target + 1, selected_row_for_add_target + 1, selected_row_for_add_source + 1], state_before, state_after)

		# Limpiar selecciones y resaltados
		_highlight_row(selected_row_for_add_source, false)
		_highlight_row(selected_row_for_add_target, false)
		selected_row_for_add_source = -1
		selected_row_for_add_target = -1
		hovered_row_for_add_target = -1
		_check_and_update_solved_rows()
		_refresh_operation_ui()


func _highlight_row(row_index: int, highlight: bool) -> void:
	matrix_grid.highlight_row(row_index, highlight, current_visual_columns)

func _clear_row_highlights() -> void:
	matrix_grid.clear_highlights()


func _reset_swap_selection() -> void:
	selected_row_for_swap = -1
	selected_row_for_scalar = -1
	selected_row_for_add_source = -1
	selected_row_for_add_target = -1
	hovered_row_for_add_target = -1
	scalar_input_buffer = ""
	_clear_row_highlights()
	_refresh_operation_ui()

func _clear_history() -> void:
	if history_panel == null:
		return

	for child in history_panel.get_children():
		history_panel.remove_child(child)
		child.queue_free()
	
	game_state.clear()


func _add_history_entry(text: String, state_before: Dictionary, state_after: Dictionary) -> void:
	if history_panel == null:
		return

	# Guardamos en el log lógico
	game_state.add_history_entry(text, state_before, state_after)

	# Creamos el elemento visual
	var entry_idx := game_state.history_size() - 1
	
	# Usamos un Button plano para poder detectar hover
	var btn := Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Estilo plano para que parezca label pero interactivo
	btn.flat = true
	# Conectamos señales para el preview
	btn.mouse_entered.connect(Callable(self, "_on_history_entry_hover").bind(entry_idx, btn))
	btn.mouse_exited.connect(Callable(self, "_on_history_entry_exit"))
	
	history_panel.add_child(btn)


func _capture_state() -> Dictionary:
	var n := int(variable_input.value)
	return game_state.capture_state(n, matrix_grid, current_visual_columns)


func _restore_state(state: Dictionary) -> void:
	var n: int = state["n"]
	if n != int(variable_input.value):
		return
		
	game_state.row_colors = state["colors"].duplicate()
	var rows_data: Array = state["rows"]
	
	# Restauramos valores en los tiles
	var logical_total := n + 1
	var children := matrix_container.get_children()
	
	for r in range(n):
		var row_vals: Array = rows_data[r]
		var r_color: Color = _row_color(r)
		var is_last_row := (r == n - 1)
		
		for col in range(logical_total):
			var idx := matrix_grid.child_index_for_row_col(r, col, current_visual_columns, n)
			if idx >= 0 and idx < children.size():
				var tile = children[idx]
				var val: Fraction = row_vals[col]
				
				if tile.has_method("set_value"):
					tile.set_value(val, r_color, is_last_row, col, logical_total)
				elif tile.has_node("Label"):
					tile.get_node("Label").text = val.to_string()

	_check_and_update_solved_rows()


func _on_back_pressed() -> void:
	var last_entry = game_state.pop_history()
	if last_entry.is_empty():
		return
	
	# Restauramos el estado "before" de esa acción
	_restore_state(last_entry["before"])
	
	# Eliminamos el último botón del panel visual
	var count = history_panel.get_child_count()
	if count > 0:
		var child = history_panel.get_child(count - 1)
		history_panel.remove_child(child)
		child.queue_free()
	
	_refresh_operation_ui()


# --- Preview Window Logic ---

func _on_history_entry_hover(idx: int, btn: Control) -> void:
	var entry = game_state.get_history_entry(idx)
	if entry.is_empty():
		return
		
	if history_preview_node:
		history_preview_node.show_preview(entry["before"], entry["after"], btn)

func _on_history_entry_exit() -> void:
	if history_preview_node:
		history_preview_node.hide()


func _set_interaction_mode(mode: int) -> void:
	# Quitamos el foco de cualquier botón o input para evitar pulsaciones accidentales (ej. Enter)
	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner:
		focus_owner.release_focus()

	if interaction_mode == mode:
		return

	interaction_mode = mode as InteractionMode
	_reset_swap_selection()
	_sync_mode_buttons()


func _setup_mode_buttons() -> void:
	_mode_button_group = ButtonGroup.new()

	if mode_switch_button:
		mode_switch_button.toggle_mode = true
		mode_switch_button.button_group = _mode_button_group
		mode_switch_button.pressed.connect(_on_mode_switch_pressed)
	if mode_multiply_button:
		mode_multiply_button.toggle_mode = true
		mode_multiply_button.button_group = _mode_button_group
		mode_multiply_button.pressed.connect(_on_mode_multiply_pressed)
	if mode_divide_button:
		mode_divide_button.toggle_mode = true
		mode_divide_button.button_group = _mode_button_group
		mode_divide_button.pressed.connect(_on_mode_divide_pressed)
	if mode_add_button:
		mode_add_button.toggle_mode = true
		mode_add_button.button_group = _mode_button_group
		mode_add_button.pressed.connect(_on_mode_add_pressed)
	if mode_subtract_button:
		mode_subtract_button.toggle_mode = true
		mode_subtract_button.button_group = _mode_button_group
		mode_subtract_button.pressed.connect(_on_mode_subtract_pressed)

func _sync_mode_buttons() -> void:
	if mode_switch_button:
		mode_switch_button.button_pressed = interaction_mode == InteractionMode.SWITCH
	if mode_multiply_button:
		mode_multiply_button.button_pressed = interaction_mode == InteractionMode.MULTIPLY
	if mode_divide_button:
		mode_divide_button.button_pressed = interaction_mode == InteractionMode.DIVIDE
	if mode_add_button:
		mode_add_button.button_pressed = interaction_mode == InteractionMode.ADD
	if mode_subtract_button:
		mode_subtract_button.button_pressed = interaction_mode == InteractionMode.SUBTRACT

func _on_mode_switch_pressed() -> void:
	_set_interaction_mode(InteractionMode.SWITCH)

func _on_mode_multiply_pressed() -> void:
	_set_interaction_mode(InteractionMode.MULTIPLY)

func _on_mode_divide_pressed() -> void:
	_set_interaction_mode(InteractionMode.DIVIDE)

func _on_mode_add_pressed() -> void:
	_set_interaction_mode(InteractionMode.ADD)

func _on_mode_subtract_pressed() -> void:
	_set_interaction_mode(InteractionMode.SUBTRACT)

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
		KEY_SLASH, KEY_KP_DIVIDE:
			if not scalar_input_buffer.contains("/"):
				if scalar_input_buffer == "":
					pass # No empezar con /
				else:
					scalar_input_buffer += "/"
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

	var val := Fraction.from_string(scalar_input_buffer)
	var n := int(variable_input.value)
	
	var state_before = _capture_state()
	
	if interaction_mode == InteractionMode.DIVIDE:
		if val.num == 0:
			return
		RowDividerScript.divide_row(matrix_container, n, selected_row_for_scalar, val, game_state.row_colors)
		var state_after = _capture_state()
		_add_history_entry("R%d / %s" % [selected_row_for_scalar + 1, scalar_input_buffer], state_before, state_after)
	else:
		RowScalarScript.multiply_row(matrix_container, n, selected_row_for_scalar, val, game_state.row_colors)
		var state_after = _capture_state()
		_add_history_entry("R%d * %s" % [selected_row_for_scalar + 1, scalar_input_buffer], state_before, state_after)

	scalar_input_buffer = ""
	_check_and_update_solved_rows()
	_refresh_operation_ui()


func _refresh_operation_ui() -> void:
	if operation_label == null or operation_text == null:
		return

	var text_out := ""

	match interaction_mode:
		InteractionMode.SWITCH:
			operation_label.text = "Modo: Intercambio de filas"
			if selected_row_for_swap == -1:
				text_out = "Haz clic en una fila y luego en otra para intercambiar. (B multiplicar, D dividir, A sumar, F restar)"
			else:
				text_out = "Fila seleccionada: R%d. Clic en otra fila para intercambiar, o en la misma para cancelar. (B multiplicar, D dividir, A sumar, F restar)" % [selected_row_for_swap + 1]

		InteractionMode.MULTIPLY:
			operation_label.text = "Modo: Multiplicar fila"
			var scalar_display := scalar_input_buffer if scalar_input_buffer != "" else "_"
			if selected_row_for_scalar == -1:
				text_out = "Selecciona una fila y escribe un número. Valor: %s (ENTER para aplicar, ESC para limpiar, swap_rows para volver)" % scalar_display
			else:
				var n := int(variable_input.value)
				var row_vals := _get_row_values(selected_row_for_scalar, n)
				var r_color := _row_color(selected_row_for_scalar)
				var formula_left := FormulaFormatter.format_scalar_formula(row_vals, scalar_display, n, false, r_color)
				var equal_vals := FormulaFormatter.format_scalar_result(row_vals, scalar_display, false, r_color)
				text_out = "R%d * %s. Escribe número y ENTER para aplicar. ESC limpia, clic de nuevo para cancelar selección.\n%s\n= %s" % [
					selected_row_for_scalar + 1,
					scalar_display,
					formula_left,
					equal_vals
				]

		InteractionMode.DIVIDE:
			operation_label.text = "Modo: Dividir fila"
			var scalar_display_div := scalar_input_buffer if scalar_input_buffer != "" else "_"
			if selected_row_for_scalar == -1:
				text_out = "Selecciona una fila y escribe un número. Valor: %s (ENTER para aplicar, ESC para limpiar, swap_rows para volver)" % scalar_display_div
			else:
				var n_div := int(variable_input.value)
				var row_vals_div := _get_row_values(selected_row_for_scalar, n_div)
				var r_color_div := _row_color(selected_row_for_scalar)
				var formula_left_div := FormulaFormatter.format_scalar_formula(row_vals_div, scalar_display_div, n_div, true, r_color_div)
				var equal_vals_div := FormulaFormatter.format_scalar_result(row_vals_div, scalar_display_div, true, r_color_div)
				text_out = "R%d / %s. Escribe número y ENTER para aplicar. ESC limpia, clic de nuevo para cancelar selección.\n%s\n= %s" % [
					selected_row_for_scalar + 1,
					scalar_display_div,
					formula_left_div,
					equal_vals_div
				]

		InteractionMode.ADD:
			operation_label.text = "Modo: Sumar filas"
			if selected_row_for_add_source == -1:
				text_out = "Selecciona la fila origen (A). Luego elige la fila destino para aplicar Rdest = Rdest + Rorigen."
			elif selected_row_for_add_target == -1:
				var n_add := int(variable_input.value)
				var src_vals_add := _get_row_values(selected_row_for_add_source, n_add)
				var src_color_add := _row_color(selected_row_for_add_source)
				var preview_target_add := selected_row_for_add_target
				var tgt_color_add := Color.WHITE
				if preview_target_add == -1 and hovered_row_for_add_target != -1 and hovered_row_for_add_target != selected_row_for_add_source:
					preview_target_add = hovered_row_for_add_target
					tgt_color_add = _row_color(preview_target_add)

				if preview_target_add != -1 and preview_target_add != selected_row_for_add_source:
					var tgt_vals_preview := _get_row_values(preview_target_add, n_add)
					var formula_preview := FormulaFormatter.format_addsub_formula(
						tgt_vals_preview,
						src_vals_add,
						false,
						n_add,
						src_color_add,
						tgt_color_add
					)
					text_out = "Origen: R%d. Destino: R%d. Se aplicaria [b]R%d[/b] = R%d + R%d.\n%s\n= %s" % [
						selected_row_for_add_source + 1,
						preview_target_add + 1,
						preview_target_add + 1,
						preview_target_add + 1,
						selected_row_for_add_source + 1,
						formula_preview[0],
						formula_preview[1]
					]
				else:
					text_out = "Origen: R%d. Selecciona la fila destino para aplicar [b]Rdest[/b] = Rdest + R%d." % [selected_row_for_add_source + 1, selected_row_for_add_source + 1]
			else:
				var n_add2 := int(variable_input.value)
				var tgt_vals_add := _get_row_values(selected_row_for_add_target, n_add2)
				var src_vals_add2 := _get_row_values(selected_row_for_add_source, n_add2)
				var formula_add2 := FormulaFormatter.format_addsub_formula(
					tgt_vals_add,
					src_vals_add2,
					false,
					n_add2,
					_row_color(selected_row_for_add_source),
					_row_color(selected_row_for_add_target)
				)
				text_out = "Origen: R%d. Destino: R%d. Se aplico [b]R%d[/b] = R%d + R%d.\n%s\n= %s" % [
					selected_row_for_add_source + 1,
					selected_row_for_add_target + 1,
					selected_row_for_add_target + 1,
					selected_row_for_add_target + 1,
					selected_row_for_add_source + 1,
					formula_add2[0],
					formula_add2[1]
				]

		InteractionMode.SUBTRACT:
			operation_label.text = "Modo: Restar filas"
			if selected_row_for_add_source == -1:
				text_out = "Selecciona la fila origen (A). Luego elige la fila destino para aplicar Rdest = Rdest - Rorigen."
			elif selected_row_for_add_target == -1:
				var n_sub_preview := int(variable_input.value)
				var src_vals_prev := _get_row_values(selected_row_for_add_source, n_sub_preview)
				var src_color_prev := _row_color(selected_row_for_add_source)
				var preview_target_sub := selected_row_for_add_target
				var tgt_color_prev := Color.WHITE
				if preview_target_sub == -1 and hovered_row_for_add_target != -1 and hovered_row_for_add_target != selected_row_for_add_source:
					preview_target_sub = hovered_row_for_add_target
					tgt_color_prev = _row_color(preview_target_sub)

				if preview_target_sub != -1 and preview_target_sub != selected_row_for_add_source:
					var tgt_vals_prev := _get_row_values(preview_target_sub, n_sub_preview)
					var formula_prev := FormulaFormatter.format_addsub_formula(
						tgt_vals_prev,
						src_vals_prev,
						true,
						n_sub_preview,
						src_color_prev,
						tgt_color_prev
					)
					text_out = "Origen: R%d. Destino: R%d. Se aplicaria [b]R%d[/b] = R%d - R%d.\n%s\n= %s" % [
						selected_row_for_add_source + 1,
						preview_target_sub + 1,
						preview_target_sub + 1,
						preview_target_sub + 1,
						selected_row_for_add_source + 1,
						formula_prev[0],
						formula_prev[1]
					]
				else:
					text_out = "Origen: R%d. Selecciona la fila destino para aplicar [b]Rdest[/b] = Rdest - R%d." % [selected_row_for_add_source + 1, selected_row_for_add_source + 1]
			else:
				var n_sub := int(variable_input.value)
				var tgt_vals := _get_row_values(selected_row_for_add_target, n_sub)
				var src_vals_sub := _get_row_values(selected_row_for_add_source, n_sub)
				var formula_sub := FormulaFormatter.format_addsub_formula(
					tgt_vals,
					src_vals_sub,
					true,
					n_sub,
					_row_color(selected_row_for_add_source),
					_row_color(selected_row_for_add_target)
				)
				text_out = "Origen: R%d. Destino: R%d. Se aplico [b]R%d[/b] = R%d - R%d.\n%s\n= %s" % [
					selected_row_for_add_source + 1,
					selected_row_for_add_target + 1,
					selected_row_for_add_target + 1,
					selected_row_for_add_target + 1,
					selected_row_for_add_source + 1,
					formula_sub[0],
					formula_sub[1]
				]

	_set_operation_text(text_out)


func _check_and_update_solved_rows() -> void:
	var n := int(variable_input.value)
	
	for row_idx in range(n):
		var row_vals := _get_row_values(row_idx, n)
		
		var solved_for_index := -1
		
		# Verificamos si esta fila coincide con el patrón de ALGUNA fila k (0..n-1)
		for target_idx in range(n):
			if _is_row_pattern_correct(row_vals, target_idx, n):
				solved_for_index = target_idx
				break
		
		var is_solved := (solved_for_index == row_idx)
		var is_misplaced := (solved_for_index != -1 and not is_solved)
		
		# Aplicamos el estado a todos los tiles de esa fila
		matrix_grid.set_row_visual_state(row_idx, is_solved, is_misplaced, n, current_visual_columns)


func _is_row_pattern_correct(row_vals: Array, target_row_idx: int, n: int) -> bool:
	for col in range(n):
		var val: Fraction = row_vals[col]
		if col == target_row_idx:
			# Debe ser 1 (num == den)
			if val.num != val.den or val.num == 0:
				return false
		else:
			# Debe ser 0 (num == 0)
			if val.num != 0:
				return false
	return true


func _set_operation_text(val: String) -> void:
	if operation_text == null:
		return
	if operation_text is RichTextLabel:
		var rtl := operation_text as RichTextLabel
		rtl.text = val
		rtl.visible_characters = -1
		if rtl.get_line_count() > 0:
			rtl.scroll_to_line(0)
	else:
		operation_text.text = val


func _get_row_values(row_index: int, n: int) -> Array:
	return matrix_grid.get_row_values(row_index, n, current_visual_columns)


func _row_color(row_index: int) -> Color:
	if row_index >= 0 and row_index < game_state.row_colors.size():
		return game_state.row_colors[row_index]
	return Color.WHITE
