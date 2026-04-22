# @param int cols 5 Number of columns
# @param int rows 5 Number of rows
# @param float seed 0.0 Random seed offset
# @param bool integer_mode false Output integers instead of floats

func cook():
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(par("seed"))

	var headers = PackedStringArray()
	for c in range(par("cols")):
		headers.append("col_%d" % c)
	op.set_headers(headers)

	for r in range(par("rows")):
		var row = PackedStringArray()
		for c in range(par("cols")):
			if par("integer_mode"):
				row.append(str(rng.randi_range(0, 100)))
			else:
				row.append("%.4f" % rng.randf())
		op.append_row(row)
