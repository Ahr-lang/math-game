extends Panel   # Cada tile es un Panel con un Label adentro

@onready var label = $Label  # Referencia al Label hijo dentro del Panel

func _ready():
	# Tamaño mínimo de cada tile (ancho x alto)
	custom_minimum_size = Vector2(100, 100)

	# Centramos el texto horizontal y verticalmente
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


# ---------------------------------------------------------
# MODO 1: CELDA NORMAL DE LA MATRIZ (números, bordes de color)
# ---------------------------------------------------------
func set_value(val: int, color: Color, is_last_row := false, col := 0, total_cols := 0):
	# Mostramos el valor numérico en el label
	label.text = str(val)

	# Color de la fuente = color de la fila (arcoíris)
	label.add_theme_color_override("font_color", color)

	# Creamos un StyleBoxFlat para dibujar fondo y bordes del Panel
	var stylebox := StyleBoxFlat.new()

	# Fondo gris oscuro
	stylebox.bg_color = Color(0.1, 0.1, 0.1)

	# Color de los bordes = color de la fila
	stylebox.border_color = color

	# Grosor de los bordes (en pixeles)
	var border_thickness := 10
	stylebox.border_width_left = border_thickness
	stylebox.border_width_right = border_thickness
	stylebox.border_width_top = border_thickness
	stylebox.border_width_bottom = border_thickness

	# Aplicamos este stylebox como estilo del panel
	add_theme_stylebox_override("panel", stylebox)


# ---------------------------------------------------------
# MODO 2: CELDA ESPECIAL PARA LA COLUMNA DE FILA: R1, R2, ...
#   - Sin bordes
#   - Sin fondo
#   - Solo texto "R#" centrado
# ---------------------------------------------------------
func set_row_header(row_index: int, color: Color = Color.WHITE):
	# Texto de la fila: R1, R2, R3, ...
	label.text = "R%d" % row_index

	# Color del texto (por defecto blanco, puedes cambiarlo si quieres)
	label.add_theme_color_override("font_color", color)

	# Creamos un stylebox "vacío" (transparente y sin bordes)
	var stylebox := StyleBoxFlat.new()

	# Fondo totalmente transparente (rgba: 0,0,0,0)
	stylebox.bg_color = Color(0, 0, 0, 0)

	# Todos los bordes en 0 para que no se vea marco
	stylebox.border_width_left = 0
	stylebox.border_width_right = 0
	stylebox.border_width_top = 0
	stylebox.border_width_bottom = 0

	# Aplicamos este stylebox al panel
	add_theme_stylebox_override("panel", stylebox)
