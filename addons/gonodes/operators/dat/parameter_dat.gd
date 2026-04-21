class_name ParameterDAT
extends GNDatBase
## Exposes all parameters of a referenced node as a table.
## Columns: name, value, type, label, description, min, max, default.
## Useful for debugging/monitoring parameter state of any operator.


func _init() -> void:
	node_type = "parameter"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Parameter table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("node_id", "",
		"Node", "ID of the node whose parameters to expose"))
	add_parameter(GNParameter.create_bool("show_defaults", true,
		"Show Defaults", "Include default values column"))
	add_parameter(GNParameter.create_bool("show_ranges", true,
		"Show Ranges", "Include min/max range columns"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var target_id: String = get_param_value("node_id")
	var show_defaults: bool = get_param_value("show_defaults")
	var show_ranges: bool = get_param_value("show_ranges")

	var table := _prepare_table()
	table.is_table = true
	table.has_header = true

	var headers := PackedStringArray(["name", "value", "type", "label"])
	if show_defaults:
		headers.append("default")
	if show_ranges:
		headers.append("min")
		headers.append("max")

	table.set_headers(headers)

	if target_id.is_empty():
		return table

	var eng := get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if eng == null or eng.network == null:
		return table

	var target: GNNode = eng.network.nodes.get(target_id, null)
	if target == null:
		return table

	for param: GNParameter in target.parameters:
		var row := PackedStringArray()
		row.append(param.name)
		row.append(str(param.value))
		row.append(_type_name(param.value_type))
		row.append(param.label if param.label else param.name)
		if show_defaults:
			row.append(str(param.default_value))
		if show_ranges:
			row.append(str(param.min_value) if param.min_value != null else "")
			row.append(str(param.max_value) if param.max_value != null else "")
		table.append_row(row)

	return table


func _type_name(type: int) -> String:
	match type:
		GNParameter.ValueType.FLOAT: return "float"
		GNParameter.ValueType.INT: return "int"
		GNParameter.ValueType.BOOL: return "bool"
		GNParameter.ValueType.STRING: return "string"
		GNParameter.ValueType.ENUM: return "enum"
		GNParameter.ValueType.COLOR: return "color"
		GNParameter.ValueType.VECTOR2: return "vector2"
		GNParameter.ValueType.VECTOR2I: return "vector2i"
		_: return "unknown"
