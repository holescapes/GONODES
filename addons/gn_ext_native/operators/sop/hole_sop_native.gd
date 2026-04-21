class_name HoleSOPNative
extends GNSopBase
## Native-accelerated hole cutting — delegates to GNNativeHoleSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "hole"
	if ClassDB.class_exists("GNNativeHoleSop"):
		_processor = ClassDB.instantiate("GNNativeHoleSop")


func _init_ports() -> void:
	add_input("base", GNFamily.Type.SOP, false, "Base surface geometry")
	add_input("hole", GNFamily.Type.SOP, false, "Hole profile geometry")
	add_output("out", GNFamily.Type.SOP, "Surface with holes cut")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("plane",
		PackedStringArray(["XZ", "XY", "YZ"]), 0,
		"Plane", "Projection plane for 2D point-in-polygon test"))
	add_parameter(GNParameter.create_float("tolerance", 0.001, 0.0001, 1.0, 0.0001,
		"Tolerance", "Edge tolerance for point-in-polygon test"))
	add_parameter(GNParameter.create_bool("invert", false,
		"Invert", "Keep inside instead of outside"))


func _cook(inputs: Array[GNData]) -> GNData:
	var base_geo := _get_input_sop(inputs, 0)
	var hole_geo := _get_input_sop(inputs, 1)
	if not base_geo or not base_geo.has_geometry() or not hole_geo or not hole_geo.has_geometry() or not _processor:
		return null

	var base_mesh: ArrayMesh = base_geo.mesh
	var hole_mesh: ArrayMesh = hole_geo.mesh
	if not base_mesh or not hole_mesh:
		return base_geo

	var base_arrays: Array = base_mesh.surface_get_arrays(0)
	var base_verts: PackedVector3Array = base_arrays[Mesh.ARRAY_VERTEX]
	var base_indices: PackedInt32Array = base_arrays[Mesh.ARRAY_INDEX] if base_arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()

	var hole_arrays: Array = hole_mesh.surface_get_arrays(0)
	var hole_verts: PackedVector3Array = hole_arrays[Mesh.ARRAY_VERTEX]

	var plane_idx: int = get_param_value("plane")
	var invert: bool = get_param_value("invert")

	# Map plane param to axis: XZ→1(Y), XY→2(Z), YZ→0(X)
	var project_axis: int
	match plane_idx:
		0: project_axis = 1  # XZ → project along Y
		1: project_axis = 2  # XY → project along Z
		_: project_axis = 0  # YZ → project along X

	var new_indices: PackedInt32Array = _processor.process(base_verts, base_indices,
		hole_verts, project_axis, invert)

	var out := _prepare_geo()
	var new_arrays: Array = base_arrays.duplicate()
	new_arrays[Mesh.ARRAY_INDEX] = new_indices
	var new_mesh := ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)
	out.mesh = new_mesh
	return out
