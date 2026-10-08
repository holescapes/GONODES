class_name TextDAT
extends GNDatBase
## Holds plain text content — editable via a string parameter.
## In text mode (not table mode). Useful for storing scripts,
## notes, or text data that other DATs can process.


func _init() -> void:
	node_type = "text"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Text output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("text", "", "Text", "Text content", true))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_table == null:
		_cached_table = GNTableData.new()

	var content: String = get_param_value("text")
	_cached_table.set_text(content)

	return _cached_table


## Called by GNTableRenderer when the user edits text in the viewer.
## row == -1 indicates full-text replacement (TextEdit mode).
func table_cell_edited(_row: int, _col: int, value: String) -> void:
	set_param_value("text", value)
	mark_dirty()
