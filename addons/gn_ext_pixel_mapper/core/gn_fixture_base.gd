class_name GNFixtureBase
extends GNNode
## Base class for all FIX (fixture) operators.
## FIX operators produce GNFixtureData describing LED positions in UV space.

## Runtime family ID — resolved once from the extension registry.
static var FIX_FAMILY: int = -1

var _cached_fix_data: GNFixtureData = null


func _init() -> void:
	if FIX_FAMILY < 0:
		FIX_FAMILY = GNFamily.string_to_type("FIX")
	family = FIX_FAMILY


func initialize(p_id: String) -> void:
	if FIX_FAMILY < 0:
		FIX_FAMILY = GNFamily.string_to_type("FIX")
	family = FIX_FAMILY
	super.initialize(p_id)


func _is_family_data(data: GNData) -> bool:
	return data is GNFixtureData


## Safe input extraction — returns null if port is empty or wrong type.
func _get_input_fix(inputs: Array[GNData], port: int = 0) -> GNFixtureData:
	if port < inputs.size() and inputs[port] is GNFixtureData:
		return inputs[port] as GNFixtureData
	return null


## Returns a reusable GNFixtureData, cleared for this cook.
func _prepare_output() -> GNFixtureData:
	if _cached_fix_data == null:
		_cached_fix_data = GNFixtureData.new()
	_cached_fix_data.valid = true
	_cached_fix_data.led_positions = PackedVector2Array()
	_cached_fix_data.led_count = 0
	return _cached_fix_data


func render_for_viewer(viewer, port_index: int = 0) -> void:
	var data: GNData = get_output_data(port_index)
	if data != null and data is GNFixtureData:
		var fd: GNFixtureData = data as GNFixtureData
		if fd.led_count == 0:
			viewer.set_info("Empty fixture", "")
		else:
			viewer.set_info(fd.get_preview_text(),
				"dmx_start: %d" % fd.dmx_start)
		return
	viewer.set_info("No fixture output", "")
