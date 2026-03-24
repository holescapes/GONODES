class_name HostOutDAT
extends GNOutBase
## Exports table/text data to the host application via the LibGodot C API.
##
## Takes a DAT input and makes its data available to the host through
## gonodes_get_output_table().  GNEmbeddedHost._collect_outputs() calls
## _get_host_table() each frame to publish the JSON.

## Cached JSON string for the host.
var _output_json: String = ""


func _init() -> void:
	node_type = "host_out_dat"
	node_description = "Export table/text data to host application (LibGodot embedding)."
	is_sink = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Table/text data to export to host")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "", "Label",
		"Optional label for this output in the host's UI"))


func _cook(inputs: Array[GNData]) -> GNData:
	var dat_in: GNTableData = _get_input_dat(inputs, 0)

	if dat_in == null:
		_output_json = ""
		return null

	if dat_in.is_table:
		# Serialize table as JSON 2D array.
		var rows: Array = []
		for row in dat_in.table:
			var cells: Array = []
			for cell in row:
				cells.append(cell)
			rows.append(cells)
		_output_json = JSON.stringify(rows)
	else:
		# Serialize text as JSON string.
		_output_json = JSON.stringify(dat_in.text)

	return null


## Called by GNEmbeddedHost._collect_outputs() to get table data.
func _get_host_table() -> String:
	return _output_json


func update_preview_control(control: Control) -> void:
	if control is Label:
		if _output_json.is_empty():
			(control as Label).text = "no input"
		else:
			var preview := _output_json.left(50)
			if _output_json.length() > 50:
				preview += "..."
			(control as Label).text = "→ host: %s" % preview
