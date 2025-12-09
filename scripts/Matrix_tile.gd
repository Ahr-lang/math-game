extends Panel   # Cada tile es un Panel con un Label adentro

@onready var label = $Label  # Referencia al Label hijo dentro del Panel

var _current_color: Color = Color.WHITE
var _is_solved: bool = false

func _ready():
	# Tamaño mínimo de cada tile (ancho x alto)
	custom_minimum_size = Vector2(100, 100)
	# Permitir que el Panel maneje el clic aunque se pulse sobre el texto
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Centramos el texto horizontal y verticalmente
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


# ---------------------------------------------------------
# MODO 1: CELDA NORMAL DE LA MATRIZ (números, bordes de color)
# ---------------------------------------------------------
func set_value(val, color: Color, is_last_row := false, col := 0, total_cols := 0):
	_current_color = color
	
	# Mostramos el valor numérico en el label
	var text_val = str(val)
	
	if val is Fraction:
		text_val = val.to_string()
	elif typeof(val) == TYPE_FLOAT and val == int(val):
		text_val = str(int(val))
	# Redondear si tiene muchos decimales para que quepa
	elif typeof(val) == TYPE_FLOAT:
		text_val = "%.2f" % val
		if text_val.ends_with(".00"):
			text_val = text_val.replace(".00", "")
			
	label.text = text_val

	# Color de la fuente = color de la fila (arcoíris)
	label.add_theme_color_override("font_color", color)

	_update_style()


var _is_misplaced: bool = false
var _blink_tween: Tween

func set_solved(solved: bool):
	if _is_solved != solved:
		_is_solved = solved
		_update_style()
		# Si se resuelve, aseguramos que deje de parpadear (por si acaso)
		if _is_solved:
			_stop_blinking()

func set_misplaced(misplaced: bool):
	if _is_misplaced != misplaced:
		_is_misplaced = misplaced
		_update_style()
		
		if _is_misplaced:
			_start_blinking()
		else:
			_stop_blinking()

func _start_blinking():
	if _blink_tween:
		_blink_tween.kill()
	
	_blink_tween = create_tween().set_loops()
	# Parpadeo suave de brillo
	_blink_tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5, 1), 0.5).set_trans(Tween.TRANS_SINE)
	_blink_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5).set_trans(Tween.TRANS_SINE)

func _stop_blinking():
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	self.modulate = Color(1, 1, 1, 1)

func _update_style():
	# Creamos un StyleBoxFlat para dibujar fondo y bordes del Panel
	var stylebox := StyleBoxFlat.new()

	# Fondo gris oscuro por defecto
	stylebox.bg_color = Color(0.1, 0.1, 0.1)
	
	if _is_solved:
		# Si está resuelta (y en su lugar), fondo verde suave
		stylebox.bg_color = Color(0.2, 0.25, 0.1)
		stylebox.border_color = Color.GOLD
	elif _is_misplaced:
		# Si está resuelta pero en lugar incorrecto, fondo naranja/amarillo suave
		stylebox.bg_color = Color(0.3, 0.2, 0.0)
		stylebox.border_color = Color.ORANGE
	else:
		stylebox.border_color = _current_color

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
