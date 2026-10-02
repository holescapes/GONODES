class_name GNMatBase
extends GNNode
## Base class for all MAT (Material Operator) family operators.
##
## Provides:
##   • family = GNFamily.Type.MAT set automatically
##   • Default output port "out" of type MAT
##   • Cached GNMaterialData with _prepare_material() helper
##   • Inline label preview (create_preview_control / update_preview_control)

# ─── Shared MAT Infrastructure ─────────────────────────────────────────────────

## Reusable output data object (created once, updated each cook).
var _cached_mat_data: GNMaterialData = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.MAT


## Ensures family is set even when subclass _init() doesn't call super().
func initialize(p_id: String) -> void:
	family = GNFamily.Type.MAT
	super.initialize(p_id)


func _is_family_data(data: GNData) -> bool:
	return data is GNMaterialData


## Default output port.  Override in subclass to add inputs or extra outputs.
func _init_ports() -> void:
	add_output("out", GNFamily.Type.MAT, "Material output")


# ═══════════════════════════════════════════════════════════════════════════════
# Output Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Creates the cached material data if it doesn't exist.
## Call at the top of _cook() to get a reusable output container.
func _prepare_output() -> GNMaterialData:
	if _cached_mat_data == null:
		_cached_mat_data = GNMaterialData.new()
	return _cached_mat_data


# ═══════════════════════════════════════════════════════════════════════════════
# Input Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Safely extracts a GNMaterialData from the inputs array at [param port].
## Returns null if the port doesn't exist or the data is not GNMaterialData.
func _get_input_mat(inputs: Array[GNData], port: int = 0) -> GNMaterialData:
	if port < inputs.size() and inputs[port] is GNMaterialData:
		var _ret0 := inputs[port] as GNMaterialData
		return _ret0
	return null



