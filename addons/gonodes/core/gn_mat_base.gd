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


func update_preview_control(control: Control) -> void:
	if control is Label:
		(control as Label).text = cached_output.get_preview_text() if cached_output != null else ""



