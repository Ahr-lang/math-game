class_name Fraction

var num: int
var den: int

func _init(n: int, d: int = 1):
	if d == 0:
		push_error("Denominator cannot be zero")
		d = 1
	
	if d < 0:
		n = -n
		d = -d
	
	var common = gcd(abs(n), abs(d))
	num = int(n / common)
	den = int(d / common)

static func gcd(a: int, b: int) -> int:
	while b != 0:
		var t = b
		b = a % b
		a = t
	return a

func _to_string() -> String:
	if den == 1:
		return str(num)
	return "%d/%d" % [num, den]

func to_float() -> float:
	return float(num) / float(den)

func add(other: Fraction) -> Fraction:
	var new_num = num * other.den + other.num * den
	var new_den = den * other.den
	return Fraction.new(new_num, new_den)

func sub(other: Fraction) -> Fraction:
	var new_num = num * other.den - other.num * den
	var new_den = den * other.den
	return Fraction.new(new_num, new_den)

func mul(other: Fraction) -> Fraction:
	return Fraction.new(num * other.num, den * other.den)

func div(other: Fraction) -> Fraction:
	if other.num == 0:
		push_error("Cannot divide by zero fraction")
		return Fraction.new(0, 1)
	return Fraction.new(num * other.den, den * other.num)

static func from_string(s: String) -> Fraction:
	s = s.strip_edges()
	if "/" in s:
		var parts = s.split("/")
		if parts.size() == 2:
			var n_str = parts[0].strip_edges()
			var d_str = parts[1].strip_edges()
			if n_str.is_valid_int() and d_str.is_valid_int():
				return Fraction.new(int(n_str), int(d_str))
	elif s.is_valid_int():
		return Fraction.new(int(s))
	elif s.is_valid_float():
		# Try to convert float to fraction if it's close to an integer
		var f = float(s)
		if abs(f - round(f)) < 0.0001:
			return Fraction.new(int(round(f)))
		# Otherwise, keep it as a large fraction? 
		# For now, let's just treat it as num/1 (rounded) or maybe 
		# we shouldn't support float input if we want strict fractions.
		# But existing values might be floats (e.g. 5.0).
		return Fraction.new(int(f)) 
	return Fraction.new(0)

static func from_variant(v) -> Fraction:
	if v is Fraction:
		return v
	if v is String:
		return from_string(v)
	if v is int:
		return Fraction.new(v)
	if v is float:
		# Check if it's an integer stored as float
		if abs(v - round(v)) < 0.0001:
			return Fraction.new(int(round(v)))
		# If it's a real float, maybe we can't easily convert to nice fraction
		# without more logic. For this game, we assume we start with ints.
		return Fraction.new(int(v))
	return Fraction.new(0)
