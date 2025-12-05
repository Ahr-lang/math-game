# MatrixGenerator.gd
# Script para generar sistemas Ax = b que siempre tienen solución.
# Lo hacemos así:
#   1. Elegimos una solución aleatoria x.
#   2. Elegimos una matriz A aleatoria.
#   3. Calculamos b = A * x.
# Resultado: el sistema Ax = b es consistente (tiene al menos una solución).

extends RefCounted
class_name MatrixGenerator

const DEFAULT_MIN_VAL := -5
const DEFAULT_MAX_VAL := 5


# Devuelve un entero aleatorio en [min_val, max_val]
static func _rand_int(min_val: int, max_val: int) -> int:
	return randi() % (max_val - min_val + 1) + min_val


# Genera:
#   - A: matriz n x n (Array de Arrays)
#   - x: vector solución (Array de n enteros)
#   - b: vector resultado (Array de n enteros) tal que A * x = b
static func generate_system(
	n: int,
	min_val: int = DEFAULT_MIN_VAL,
	max_val: int = DEFAULT_MAX_VAL
) -> Dictionary:
	# 1) Solución aleatoria x (lo que el jugador "no ve")
	var x: Array = []
	for j in range(n):
		x.append(_rand_int(min_val, max_val))

	# 2) Matriz A aleatoria n x n
	var A: Array = []
	for i in range(n):
		var row: Array = []
		for j in range(n):
			row.append(_rand_int(min_val, max_val))
		A.append(row)

	# 3) Calculamos b = A * x
	var b: Array = []
	for i in range(n):
		var sum_row := 0
		for j in range(n):
			sum_row += A[i][j] * x[j]
		b.append(sum_row)

	# Regresamos todo por si luego quieres usar x para "verificar"
	return {
		"A": A,   # matriz de coeficientes n x n
		"b": b,   # vector resultante n
		"x": x    # solución que se usó (opcional para ti)
	}


# Versión cómoda para el juego:
# Devuelve directamente la matriz aumentada [A|b] como:
#   Array de n filas, cada fila = Array de (n + 1) enteros
static func generate_augmented(
	n: int,
	min_val: int = DEFAULT_MIN_VAL,
	max_val: int = DEFAULT_MAX_VAL
) -> Array:
	var sys := generate_system(n, min_val, max_val)
	var A: Array = sys["A"]
	var b: Array = sys["b"]

	var augmented: Array = []

	for i in range(n):
		var row: Array = []
		# Copiamos la fila de A
		for j in range(n):
			row.append(A[i][j])
		# Pegamos b al final (columna aumentada)
		row.append(b[i])
		augmented.append(row)

	return augmented
