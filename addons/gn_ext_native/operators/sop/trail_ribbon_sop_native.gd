class_name TrailRibbonSOPNative
extends GNSopBase
## Native-accelerated trail ribbon — delegates to GNNativeTrailRibbonSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "trail_ribbon_native"
	time_dependent = true
	if ClassDB.class_exists("GNNativeTrailRibbonSop"):
		_processor = ClassDB.instantiate("GNNativeTrailRibbonSop")


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input", "POP")
	add_output("out", GNFamily.Type.SOP, "Ribbon mesh", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("trail_length", 30, 2, 300,
		"Trail Length", "Number of frames in trail history"))
	add_parameter(GNParameter.create_float("width", 0.1, 0.001, 10.0, 0.001,
		"Width", "Ribbon width"))
	add_parameter(GNParameter.create_float("taper", 0.8, 0.0, 1.0, 0.01,
		"Taper", "Width taper along trail (0=no taper, 1=fade to zero)"))
	add_parameter(GNParameter.create_int("max_particles", 1000, 1, 100000,
		"Max Particles", "Maximum particles to process"))
	add_parameter(GNParameter.create_bool("fade_alpha", true,
		"Fade Alpha", "Fade opacity along trail"))
	add_parameter(GNParameter.create_bool("active", true,
		"Active", "Enable trail recording"))


func _cook(inputs: Array[GNData]) -> GNData:
	if not _processor:
		return null

	var active: bool = get_param_value("active")
	if not active:
		return null

	# For single-point mode (centroid), use the first particle position
	var current_pos := Vector3.ZERO
	if inputs.size() > 0 and inputs[0]:
		# Try to get position from particle data or geometry centroid
		var data = inputs[0]
		if data is GNGeoData and data.mesh:
			var arrays: Array = data.mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if verts.size() > 0:
				for v in verts:
					current_pos += v
				current_pos /= verts.size()

	var width: float = get_param_value("width")
	var max_frames: int = get_param_value("trail_length")
	var up := Vector3(0, 1, 0)

	var result: Dictionary = _processor.process(current_pos, width, max_frames, up)

	var out := _prepare_geo()
	var r_verts: PackedVector3Array = result.get("vertices", PackedVector3Array())
	if r_verts.size() == 0:
		return null

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = r_verts
	arrays[Mesh.ARRAY_NORMAL] = result.get("normals", PackedVector3Array())
	arrays[Mesh.ARRAY_TEX_UV] = result.get("uvs", PackedVector2Array())
	arrays[Mesh.ARRAY_INDEX] = result.get("indices", PackedInt32Array())
	var new_mesh := ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.mesh = new_mesh
	return out
