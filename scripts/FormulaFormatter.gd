class_name FormulaFormatter
extends RefCounted

static func colorize(text: String, color: Color) -> String:
	var hex := color.to_html(false)
	return "[color=#%s]%s[/color]" % [hex, text]

static func format_scalar_formula(row_vals: Array, scalar_display: String, n: int, is_divide: bool, row_color: Color) -> String:
	var letters := "abcdefghijklmnopqrstuvwxyz"
	var parts: Array = []
	var symbol := "/%s" if is_divide else "%s"

	for i in range(row_vals.size()):
		var val_text := colorize(row_vals[i].to_string(), row_color)
		if i < n:
			var letter := letters[i % letters.length()]
			parts.append("%s(%s)%s" % [val_text, symbol % scalar_display, letter])
		else:
			parts.append("%s(%s)" % [val_text, symbol % scalar_display])

	return "  ".join(parts)

static func format_scalar_result(row_vals: Array, scalar_display: String, is_divide: bool, row_color: Color) -> String:
	if scalar_display == "_" or scalar_display == "-" or scalar_display == "":
		return ""

	# scalar_display puede ser "1/3"
	var scalar := Fraction.from_string(scalar_display)
	if scalar.num == 0 and is_divide:
		return ""

	var results: Array = []
	for val in row_vals:
		var res_val: Fraction
		if is_divide:
			res_val = val.div(scalar)
		else:
			res_val = val.mul(scalar)
		results.append(colorize(res_val.to_string(), row_color))
	return "  ".join(results)

static func format_addsub_formula(target_vals: Array, source_vals: Array, is_subtract: bool, n: int, source_color: Color, target_color: Color) -> Array:
	var symbol := "-" if is_subtract else "+"
	var letters := "abcdefghijklmnopqrstuvwxyz"
	var parts: Array = []
	var results: Array = []

	for i in range(target_vals.size()):
		var tgt: Fraction = target_vals[i]
		var src: Fraction = source_vals[i]
		var tgt_text := colorize(tgt.to_string(), target_color)
		var src_text := colorize(src.to_string(), source_color)
		var letter := ""
		if i < n:
			letter = letters[i % letters.length()]
			parts.append("%s %s %s%s" % [tgt_text, symbol, src_text, letter])
		else:
			parts.append("%s %s %s" % [tgt_text, symbol, src_text])

		var res: Fraction
		if is_subtract:
			res = tgt.sub(src)
		else:
			res = tgt.add(src)
		results.append(colorize(res.to_string(), target_color))

	return [ "  ".join(parts), "  ".join(results) ]
