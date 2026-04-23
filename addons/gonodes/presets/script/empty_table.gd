# @output dat Output table
# @param int rows 10 Number of rows
# @param int cols 3 Number of columns
# @param string col_prefix col Column name prefix

func cook():
	var nr = par("rows")
	var nc = par("cols")
	var pfx = par("col_prefix")

	var headers = PackedStringArray()
	for c in range(nc):
		headers.append("%s%d" % [pfx, c])
	op.set_headers(headers)

	for r in range(nr):
		var row = PackedStringArray()
		for c in range(nc):
			row.append("r%d_c%d" % [r, c])
		op.append_row(row)
