extends PopupPanel

var _preview_container: HBoxContainer
var _preview_before_grid: GridContainer
var _preview_after_grid: GridContainer

func _ready() -> void:
	_setup_ui()

func show_preview(state_before: Dictionary, state_after: Dictionary, anchor_node: Control) -> void:
	_populate_preview_grid(_preview_before_grid, state_before, "Antes")
	_populate_preview_grid(_preview_after_grid, state_after, "Después")
	
	# Posicionar cerca del botón
	var global_rect = anchor_node.get_global_rect()
	var pos = global_rect.position
	pos.x += global_rect.size.x + 10 # A la derecha del historial
	
	position = Vector2i(pos)
	popup()

func _setup_ui() -> void:
	# En Godot 4, PopupPanel es un Window y no tiene mouse_filter
	
	_preview_container = HBoxContainer.new()
	_preview_container.add_theme_constant_override("separation", 20)
	add_child(_preview_container)
	
	var vbox1 = VBoxContainer.new()
	var lbl1 = Label.new()
	lbl1.text = "ANTES"
	lbl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox1.add_child(lbl1)
	_preview_before_grid = GridContainer.new()
	vbox1.add_child(_preview_before_grid)
	_preview_container.add_child(vbox1)
	
	var vbox2 = VBoxContainer.new()
	var lbl2 = Label.new()
	lbl2.text = "DESPUÉS"
	lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox2.add_child(lbl2)
	_preview_after_grid = GridContainer.new()
	vbox2.add_child(_preview_after_grid)
	_preview_container.add_child(vbox2)

func _populate_preview_grid(grid: GridContainer, state: Dictionary, _title: String) -> void:
	# Limpiar grid
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
		
	var n: int = state["n"]
	var rows_data: Array = state["rows"]
	var colors: Array = state["colors"]
	
	# Configurar columnas: n coeficientes + 1 separador + 1 aumentada
	grid.columns = n + 2
	
	for r in range(n):
		var row_vals: Array = rows_data[r]
		var color: Color = colors[r]
		
		for c in range(n + 1):
			# Antes de la última columna (la aumentada), insertamos el separador
			if c == n:
				var sep = ColorRect.new()
				sep.custom_minimum_size = Vector2(2, 40)
				sep.color = Color.WHITE
				grid.add_child(sep)

			var val: Fraction = row_vals[c]
			var lbl = Label.new()
			lbl.text = val.to_string()
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.custom_minimum_size = Vector2(40, 40) # Tamaño fijo pequeño
			
			# Fondo de color
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.1, 0.1, 0.1)
			style.border_color = color
			style.set_border_width_all(2)
			lbl.add_theme_stylebox_override("normal", style)
			lbl.add_theme_color_override("font_color", color)
			
			grid.add_child(lbl)
