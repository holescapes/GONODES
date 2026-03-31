class_name GNSopBase
extends GNNode
## Base class for all SOP (Surface Operator) family operators.
##
## Provides:
##   • family = GNFamily.Type.SOP set automatically
##   • Default output port "out" of type SOP
##   • Cached GNGeoData with _prepare_geo() helper
##   • Input validation via _get_input_sop()
##   • Inline geometry stats preview (create_preview_control / update_preview_control)

# ─── Shared SOP Infrastructure ─────────────────────────────────────────────────

## Reusable output data object (created once, cleared each cook).
var _cached_geo: GNGeoData = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.SOP


## Ensures family is set even when subclass _init() doesn't call super().
func initialize(p_id: String) -> void:
	family = GNFamily.Type.SOP
	super.initialize(p_id)


## Default output port.  Override in subclass to add inputs or extra outputs.
func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Geometry output")


# ═══════════════════════════════════════════════════════════════════════════════
# Output Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Creates or clears the cached geometry data.
## Call at the top of _cook() to get a clean slate.
func _prepare_geo() -> GNGeoData:
	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()
	return _cached_geo


# ═══════════════════════════════════════════════════════════════════════════════
# Input Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Safely extracts a GNGeoData from the inputs array at [param port].
## Returns null if the port doesn't exist or the data is not GNGeoData.
func _get_input_sop(inputs: Array[GNData], port: int = 0) -> GNGeoData:
	if port < inputs.size() and inputs[port] is GNGeoData:
		return inputs[port] as GNGeoData
	return null


## Validates that port 0 has valid geometry. Returns the GNGeoData or null.
## Convenience for filter SOPs that require geometry on their first input.
func _require_input_geo(inputs: Array[GNData]) -> GNGeoData:
	var geo := _get_input_sop(inputs, 0)
	if geo == null or not geo.has_geometry():
		return null
	return geo


func update_preview_control(control: Control) -> void:
	if control is Label:
		(control as Label).text = cached_output.get_preview_text() if cached_output != null else ""


func display_in_viewer(viewer) -> void:
	if cached_output is GNGeoData:
		viewer.show_3d_mesh(cached_output as GNGeoData)
		return
	viewer.show_info("No SOP output", "")



