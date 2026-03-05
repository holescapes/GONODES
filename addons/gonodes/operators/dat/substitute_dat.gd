class_name SubstituteDAT
extends GNDatBase
## Find and replace text in table cells or plain text.
## Supports plain-text and regex matching with configurable scope.


func _init() -> void:
	node_type = "substitute"
	node_description = "Find and replace text in table cells or text."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Input table or text")
	add_output("out", GNFamily.Type.DAT, "Substituted output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("find", "",
		"Find", "Text or regex pattern to find"))
	add_parameter(GNParameter.create_string("replace_with", "",
		"Replace With", "Replacement text"))
	add_parameter(GNParameter.create_bool("use_regex", false,
		"Use Regex", "Treat find pattern as a regular expression"))
	add_parameter(GNParameter.create_bool("case_sensitive", true,
		"Case Sensitive", "Case-sensitive matching"))
	add_parameter(GNParameter.create_enum("scope",
		PackedStringArray(["All", "Column", "Row"]), 0,
		"Scope", "Limit substitution to all cells, a specific column, or a specific row"))
	add_parameter(GNParameter.create_int("scope_index", 0, 0, null,
		"Scope Index", "Column or row index when scope is Column or Row"))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_table()
	var in_dat: GNTableData = _get_input_dat(inputs, 0)
	if in_dat == null:
		return out

	var find_str: String = get_param_value("find")
	var replace_str: String = get_param_value("replace_with")
	var use_regex: bool = get_param_value("use_regex")
	var case_sensitive: bool = get_param_value("case_sensitive")
	var scope: int = get_param_value("scope")
	var scope_idx: int = get_param_value("scope_index")

	# Handle text mode
	if not in_dat.is_table:
		out.is_table = false
		var text: String = in_dat.text
		if not find_str.is_empty():
			text = _do_replace(text, find_str, replace_str, use_regex, case_sensitive)
		out.set_text(text)
		return out

	# Copy table structure
	out.is_table = true
	out.has_header = in_dat.has_header
	for row_idx in range(in_dat.table.size()):
		var src_row: PackedStringArray = in_dat.table[row_idx]
		var new_row := PackedStringArray()
		# Data row index (0-based, skipping header)
		var data_row: int = row_idx - (1 if in_dat.has_header else 0)
		var is_header_row: bool = in_dat.has_header and row_idx == 0

		for col_idx in range(src_row.size()):
			var cell_val: String = src_row[col_idx]
			var should_replace: bool = false

			if is_header_row:
				# Never modify header row
				should_replace = false
			elif find_str.is_empty():
				should_replace = false
			elif scope == 0:  # All
				should_replace = true
			elif scope == 1:  # Column
				should_replace = (col_idx == scope_idx)
			elif scope == 2:  # Row
				should_replace = (data_row == scope_idx)

			if should_replace:
				cell_val = _do_replace(cell_val, find_str, replace_str, use_regex, case_sensitive)
			new_row.append(cell_val)
		out.table.append(new_row)
	return out


## Performs find/replace using either plain text or regex.
func _do_replace(text: String, find: String, replace_with: String,
		use_regex: bool, case_sensitive: bool) -> String:
	if use_regex:
		var regex := RegEx.new()
		var pattern: String = find if case_sensitive else "(?i)" + find
		var err: Error = regex.compile(pattern)
		if err != OK:
			push_warning("SubstituteDAT: Invalid regex pattern: %s" % find)
			return text
		return regex.sub(text, replace_with, true)
	else:
		if case_sensitive:
			return text.replace(find, replace_with)
		else:
			# Case-insensitive plain-text replace via regex escape
			var escaped: String = _escape_regex(find)
			var regex := RegEx.new()
			regex.compile("(?i)" + escaped)
			return regex.sub(text, replace_with, true)


## Escapes special regex characters in a plain-text string.
func _escape_regex(text: String) -> String:
	var special := "\\^$.|?*+()[]{}"
	var result := ""
	for ch in text:
		if special.contains(ch):
			result += "\\" + ch
		else:
			result += ch
	return result
