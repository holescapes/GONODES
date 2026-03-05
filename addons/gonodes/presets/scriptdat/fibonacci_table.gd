# @param int rows 8 Number of Fibonacci rows
# @param bool include_ratio true Show golden ratio column

func cook():
	op.set_headers(PackedStringArray(["n", "fib", "ratio"] if par("include_ratio") else ["n", "fib"]))
	var a := 0
	var b := 1
	for i in range(par("rows")):
		var row := PackedStringArray([str(i), str(a)])
		if par("include_ratio") and a > 0:
			row.append("%.6f" % (float(b) / float(a)))
		elif par("include_ratio"):
			row.append("-")
		op.append_row(row)
		var tmp := a
		a = b
		b = tmp + b
