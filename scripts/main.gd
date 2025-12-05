extends Control

# --------- Referencias a nodos del árbol de la escena ---------

# SpinBox para elegir el número de variables (tamaño de la matriz)
@onready var variable_input   = $MainPanel/SidePanel/"Number of variables"

# Botón para volver a generar la matriz (reshuffle)
@onready var reshuffle_button = $MainPanel/SidePanel/ReshuffleButton

# GridContainer donde colocamos todos los tiles (Rk, coeficientes, espaciador, aumentada)
@onready var matrix_container = $MainPanel/MatrixArea/MatrixRoot/MatrixContainer

# Nodo Separator (la línea blanca vertical que se dibuja en medio del hueco)
@onready var separator        = $MainPanel/MatrixArea/MatrixRoot/Separator


# --------- Escenas / scripts auxiliares ---------

# Celda de la matriz (números y también headers R1, R2, ...)
var tile_scene        = preload("res://scenes/MatrixTile.tscn")

# Generador de sistemas Ax = b con solución garantizada
var MatrixGenerator   = preload("res://scripts/MatrixGenerator.gd")


# Operaciones
var RowOperations = preload("res://scripts/RowOperations.gd")

# --------- Datos de estado ---------

# Array para guardar los colores de cada fila (arcoíris)
var row_colors: Array = []

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


# Cuando se presiona el botón "Reshuffle"
func _on_reshuffle_pressed():
	_create_matrix()


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
	matrix_container.columns = visual_total_columns

	# --- NUEVO: generamos la matriz aumentada [A|b] con solución garantizada ---
	# augmented_matrix[row][0..n-1] = coeficientes A
	# augmented_matrix[row][n]      = término independiente b
	var augmented_matrix: Array = MatrixGenerator.generate_augmented(n, -5, 5)

	# Limpiamos cualquier cosa que estuviera antes en el GridContainer
	row_colors.clear()
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
		# Le damos un ancho mínimo para que fuerce el espacio
		spacer.custom_minimum_size = Vector2(EXTRA_COLUMN_GAP, 0.0)
		# Lo agregamos como una columna más
		matrix_container.add_child(spacer)

		# -----------------------------------------------------
		# 4) COLUMNA AUMENTADA (última columna lógica)
		#    índice lógico = n
		# -----------------------------------------------------
		var aug_tile = tile_scene.instantiate()
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
	# lo que ya tenías antes
	# y además el swap de filas
	if event.is_action_pressed("swap_rows"):
		var n := int(variable_input.value)
		RowOperations.swap_rows(matrix_container, n, 0, 1)
