# RowDivider.gd
# Divide una fila por un escalar y actualiza los tiles visibles.

extends RefCounted
class_name RowDivider


static func divide_row(matrix_container: GridContainer, n: int, row_index: int, divisor, row_colors: Array) -> void:
	var div_frac: Fraction
	if divisor is Fraction:
		div_frac = divisor
	else:
		div_frac = Fraction.from_variant(divisor)

	if div_frac.num == 0:
		push_warning("RowDivider.divide_row: divisor es 0, operación ignorada.")
		return

	# Reutilizamos RowScalar multiplicando por el recíproco
	var reciprocal := Fraction.new(div_frac.den, div_frac.num)
	RowScalar.multiply_row(matrix_container, n, row_index, reciprocal, row_colors)
