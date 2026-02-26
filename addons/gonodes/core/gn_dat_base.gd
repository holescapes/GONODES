class_name GNDatBase
extends GNNode
## Base class for all DAT (Data Operator) family operators.
##
## Provides:
##   • family = GNFamily.Type.DAT set automatically
##   • Default output port "out" of type DAT
##   • Cached GNTableData with _prepare_table() helper
##   • Input validation via _get_input_dat()
##   • Inline table preview (create_preview_control / update_preview_control)

# ─── Shared DAT Infrastructure ─────────────────────────────────────────────────

## Reusable output data object (created once, cleared as needed).
var _cached_table: GNTableData = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.DAT


## Ensures family is set even when subclass _init() doesn't call super().
func initialize(p_id: String) -> void:
	family = GNFamily.Type.DAT
	super.initialize(p_id)


## Default output port.  Override in subclass to add inputs or extra outputs.
func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Table output")


# ═══════════════════════════════════════════════════════════════════════════════
# Output Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Creates the cached table data if it doesn't exist, and optionally clears it.
## Call at the top of _cook() to get a clean slate for table output.
## Set [param clear] to false if you want to append incrementally.
func _prepare_table(clear: bool = true) -> GNTableData:
	if _cached_table == null:
		_cached_table = GNTableData.new()
	elif clear:
		_cached_table.table.clear()
	return _cached_table


# ═══════════════════════════════════════════════════════════════════════════════
# Input Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Safely extracts a GNTableData from the inputs array at [param port].
## Returns null if the port doesn't exist or the data is not GNTableData.
func _get_input_dat(inputs: Array[GNData], port: int = 0) -> GNTableData:
	if port < inputs.size() and inputs[port] is GNTableData:
		return inputs[port] as GNTableData
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Preview
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a Label preview showing a compact table summary.
func create_preview_control() -> Control:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.text = ""
	return label


## Updates the table preview label with header + first few rows.
func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		if cached_output is GNTableData:
			var tbl: GNTableData = cached_output as GNTableData
			var lines := PackedStringArray()
			if tbl.table.is_empty():
				label.text = "(empty)"
				return
			# Show header row
			if tbl.has_header and tbl.table.size() > 0:
				lines.append(" | ".join(tbl.table[0]))
			# Show up to 3 data rows
			var data_start: int = 1 if tbl.has_header else 0
			var data_count: int = tbl.table.size() - data_start
			var max_rows: int = mini(data_count, 3)
			for r in range(max_rows):
				lines.append(" | ".join(tbl.table[data_start + r]))
			if data_count > 3:
				lines.append("... +%d rows" % (data_count - 3))
			label.text = "\n".join(lines) if lines.size() > 0 else ""
		else:
			label.text = ""
