class_name GNSdfBase
extends GNNode
## Base class for all SDF operators.
## SDF operators pass GNSDFData (an AST) between each other.
## The final RaymarchSDF TOP compiles the AST into GLSL.

## Runtime family ID — resolved once from the extension registry.
static var SDF_FAMILY: int = -1

var _cached_sdf_data: GNSDFData = null


func _init() -> void:
	if SDF_FAMILY < 0:
		SDF_FAMILY = GNFamily.string_to_type("SDF")
	family = SDF_FAMILY


func initialize(p_id: String) -> void:
	if SDF_FAMILY < 0:
		SDF_FAMILY = GNFamily.string_to_type("SDF")
	family = SDF_FAMILY
	super.initialize(p_id)


## Safe input extraction — returns null if port is empty or wrong type.
func _get_input_sdf(inputs: Array[GNData], port: int = 0) -> GNSDFData:
	if port < inputs.size() and inputs[port] is GNSDFData:
		return inputs[port] as GNSDFData
	return null


## Prepare a reusable GNSDFData output.
func _prepare_output() -> GNSDFData:
	if _cached_sdf_data == null:
		_cached_sdf_data = GNSDFData.new()
	_cached_sdf_data.valid = true
	return _cached_sdf_data


## Build an SDF tree node dictionary.
static func _make_node(op: String, params: Dictionary, children: Array = [],
		material: Dictionary = {}) -> Dictionary:
	var node: Dictionary = {"op": op, "params": params, "children": children}
	if not material.is_empty():
		node["material"] = material
	return node


func update_preview_control(control: Control) -> void:
	if control is Label:
		(control as Label).text = cached_output.get_preview_text() if cached_output != null else ""
