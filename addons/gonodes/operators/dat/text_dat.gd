class_name TextDAT
extends GNNode
## Holds plain text content — editable via a string parameter.
## In text mode (not table mode). Useful for storing scripts,
## notes, or text data that other DATs can process.

var _cached_table: GNTableData = null


func _init() -> void:
	node_type = "text"
	family = GNFamily.Type.DAT


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("text", "", "Text"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_table == null:
		_cached_table = GNTableData.new()

	var content: String = get_param_value("text")
	_cached_table.set_text(content)

	return _cached_table
