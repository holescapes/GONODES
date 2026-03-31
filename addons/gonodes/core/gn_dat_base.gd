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


func update_preview_control(control: Control) -> void:
	if control is Label:
		(control as Label).text = cached_output.get_preview_text() if cached_output != null else ""


func display_in_viewer(viewer) -> void:
	if cached_output is GNTableData:
		viewer.show_spreadsheet(cached_output as GNTableData)
		return
	viewer.show_info("No DAT output", "")



