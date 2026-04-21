class_name PolyPatchSOPNative
extends GNSopBase
## Native-accelerated Coons patch — delegates to GNNativePolyPatchSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "polypatch"
	if ClassDB.class_exists("GNNativePolyPatchSop"):
		_processor = ClassDB.instantiate("GNNativePolyPatchSop")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Patch mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("c00x", -1.0, null, null, 0.01, "Corner 00 X", ""))
	add_parameter(GNParameter.create_float("c00y", 0.0, null, null, 0.01, "Corner 00 Y", ""))
	add_parameter(GNParameter.create_float("c00z", -1.0, null, null, 0.01, "Corner 00 Z", ""))
	add_parameter(GNParameter.create_float("c10x", 1.0, null, null, 0.01, "Corner 10 X", ""))
	add_parameter(GNParameter.create_float("c10y", 0.0, null, null, 0.01, "Corner 10 Y", ""))
	add_parameter(GNParameter.create_float("c10z", -1.0, null, null, 0.01, "Corner 10 Z", ""))
	add_parameter(GNParameter.create_float("c01x", -1.0, null, null, 0.01, "Corner 01 X", ""))
	add_parameter(GNParameter.create_float("c01y", 0.0, null, null, 0.01, "Corner 01 Y", ""))
	add_parameter(GNParameter.create_float("c01z", 1.0, null, null, 0.01, "Corner 01 Z", ""))
	add_parameter(GNParameter.create_float("c11x", 1.0, null, null, 0.01, "Corner 11 X", ""))
	add_parameter(GNParameter.create_float("c11y", 0.0, null, null, 0.01, "Corner 11 Y", ""))
	add_parameter(GNParameter.create_float("c11z", 1.0, null, null, 0.01, "Corner 11 Z", ""))
	add_parameter(GNParameter.create_int("rows", 10, 2, 128, "Rows", "Grid subdivisions"))
	add_parameter(GNParameter.create_int("cols", 10, 2, 128, "Cols", "Grid subdivisions"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _processor == null:
		return null

	var c00 := Vector3(get_param_value("c00x"), get_param_value("c00y"), get_param_value("c00z"))
	var c10 := Vector3(get_param_value("c10x"), get_param_value("c10y"), get_param_value("c10z"))
	var c01 := Vector3(get_param_value("c01x"), get_param_value("c01y"), get_param_value("c01z"))
	var c11 := Vector3(get_param_value("c11x"), get_param_value("c11y"), get_param_value("c11z"))
	var rows: int = get_param_value("rows")
	var cols: int = get_param_value("cols")

	var result: Dictionary = _processor.process(c00, c10, c01, c11, rows, cols)
	var geo := _prepare_geo()
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = result.get("vertices", PackedVector3Array())
	arrays[Mesh.ARRAY_NORMAL] = result.get("normals", PackedVector3Array())
	arrays[Mesh.ARRAY_TEX_UV] = result.get("uvs", PackedVector2Array())
	arrays[Mesh.ARRAY_INDEX] = result.get("indices", PackedInt32Array())
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	geo.set_mesh(mesh)
	return geo
