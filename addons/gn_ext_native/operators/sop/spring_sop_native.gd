class_name SpringSOPNative
extends GNSopBase
## Native-accelerated spring vertex deformer — delegates to GNNativeSpring
## (C++) when available, falls back to pure GDScript otherwise.

var _processor: RefCounted = null


func _init() -> void:
	node_type = "spring_native"
	time_dependent = true
	node_description = "Damped spring vertex deformer (native C++ accelerated)."
	if ClassDB.class_exists("GNNativeSpring"):
		_processor = ClassDB.instantiate("GNNativeSpring")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Target geometry (rest positions)")
	add_output("out", GNFamily.Type.SOP, "Spring-deformed geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("stiffness", 20.0, 0.1, 500.0, 0.1,
		"Stiffness (k)", "Spring constant — higher = snappier"))
	add_parameter(GNParameter.create_float("damping", 4.0, 0.0, 50.0, 0.1,
		"Damping (c)", "Damping coefficient — higher = less overshoot"))
	add_parameter(GNParameter.create_float("mass", 1.0, 0.01, 10.0, 0.01,
		"Mass", "Vertex mass — higher = slower response"))
	add_parameter(GNParameter.create_bool("reset", false, "", "Reset spring state"))
	add_parameter(GNParameter.create_float("max_displacement", 10.0, 0.01, 100.0, 0.01,
		"Max Disp.", "Clamp maximum displacement from target"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = _require_input_geo(inputs)
	if geo_in == null:
		return null

	var k: float = get_param_value("stiffness")
	var c: float = get_param_value("damping")
	var m: float = maxf(get_param_value("mass"), 0.01)
	var do_reset: bool = get_param_value("reset")
	var max_disp: float = get_param_value("max_displacement")

	var dt: float = current_delta
	if dt <= 0.0:
		dt = 1.0 / 60.0

	var target_positions: PackedVector3Array = geo_in.get_positions()
	if target_positions.is_empty():
		return geo_in

	if _processor != null:
		var spring_positions: PackedVector3Array = _processor.step(
			target_positions, dt, k, c, m, max_disp, do_reset)

		if spring_positions.is_empty():
			return geo_in

		# Rebuild mesh with deformed positions
		var out := _prepare_geo()
		var new_mesh := ArrayMesh.new()

		for s in range(geo_in.get_surface_count()):
			var arrays: Array = geo_in.get_surface_arrays(s)
			if arrays[Mesh.ARRAY_VERTEX] == null:
				continue

			var orig_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			# Map back from flat position array
			var deformed := PackedVector3Array()
			deformed.resize(orig_verts.size())
			for i in range(orig_verts.size()):
				if i < spring_positions.size():
					deformed[i] = spring_positions[i]
				else:
					deformed[i] = orig_verts[i]
			arrays[Mesh.ARRAY_VERTEX] = deformed

			var prim := geo_in.mesh.surface_get_primitive_type(s) if geo_in.mesh != null else Mesh.PRIMITIVE_TRIANGLES
			new_mesh.add_surface_from_arrays(prim, arrays)

		out.set_mesh(new_mesh)
		return out
	else:
		return null  # Fallback handled by core SpringSOP
