class_name HostInDAT
extends GNDatBase
## Receives table/text data from the host application via the LibGodot C API.
##
## The host calls gonodes_set_input_table() to push JSON data.
## GNEmbeddedHost flushes that data into this node via _set_host_table().
##
## JSON format:
##   Table mode: [["col1","col2"], ["row1a","row1b"], ...]
##   Text mode:  "plain text string"
##
## Usage: Place in a patch, set the node ID, and wire output to downstream DATs.

## Host-provided JSON string.
var _host_json: String = ""
var _host_dirty: bool = false


func _init() -> void:
	node_type = "host_in"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Table/text received from host")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "", "Label",
		"Optional label for this input in the host's UI"))
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Table", "Text"]), 0, "Mode",
		"Whether incoming data is a 2D table or plain text"))


## Called by GNEmbeddedHost._flush_inputs() with the host's data.
func _set_host_table(json_data: String) -> void:
	_host_json = json_data
	_host_dirty = true
	mark_dirty()


func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_table()
	var mode_idx: int = get_param_value("mode")

	if _host_json.is_empty():
		out.valid = false
		return out

	var json := JSON.new()
	if json.parse(_host_json) != OK:
		node_warning = "Invalid JSON from host: %s" % json.get_error_message()
		out.valid = false
		return out

	if mode_idx == 0:
		# Table mode: expect Array of Arrays.
		if json.data is Array:
			var rows: Array = json.data
			out.table.clear()
			for row in rows:
				if row is Array:
					var psa := PackedStringArray()
					for cell in row:
						psa.append(str(cell))
					out.table.append(psa)
			out.has_header = out.table.size() > 0
			out.is_table = true
		else:
			node_warning = "Table mode expects JSON array of arrays"
			out.valid = false
			return out
	else:
		# Text mode: expect a string.
		out.text = str(json.data)
		out.is_table = false

	out.valid = true
	_host_dirty = false
	return out
