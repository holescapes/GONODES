class_name ClothSOPNative
extends GNSopBase
## Native-accelerated Verlet cloth sim — delegates to GNNativeClothSop (C++).

var _processor: RefCounted = null
var _initialized: bool = false
var _source_arrays: Array = []
var _source_prim: int = Mesh.PRIMITIVE_TRIANGLES


func _init() -> void:
	node_type = "cloth_native"
	time_dependent = true
	if ClassDB.class_exists("GNNativeClothSop"):
		_processor = ClassDB.instantiate("GNNativeClothSop")


func _init_ports() -> void:
	add_input("geo", GNFamily.Type.SOP, false, "Input mesh (grid recommended)", "Geometry")
	add_output("out", GNFamily.Type.SOP, "Simulated cloth geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("gravity", -9.8, -100.0, 0.0, 0.1,
		"Gravity", "Downward acceleration (Y axis)"))
	add_parameter(GNParameter.create_float("damping", 0.99, 0.8, 1.0, 0.001,
		"Damping", "Velocity damping per step"))
	add_parameter(GNParameter.create_int("iterations", 8, 1, 64,
		"Constraint Iterations", "Solver iterations per step"))
	add_parameter(GNParameter.create_float("stiffness", 1.0, 0.0, 1.0, 0.01,
		"Stiffness", "Constraint stiffness"))
	add_parameter(GNParameter.create_float("wind_x", 0.0, -100.0, 100.0, 0.01, "Wind X", ""))
	add_parameter(GNParameter.create_float("wind_y", 0.0, -100.0, 100.0, 0.01, "Wind Y", ""))
	add_parameter(GNParameter.create_float("wind_z", 0.0, -100.0, 100.0, 0.01, "Wind Z", ""))
	add_parameter(GNParameter.create_enum("pin_mode",
		PackedStringArray(["Top Row", "Top Corners", "Custom Attrib", "None"]), 0,
		"Pin Mode", "Which vertices are fixed"))
	add_parameter(GNParameter.create_float("substeps", 2.0, 1.0, 10.0, 1.0,
		"Substeps", "Substeps per frame"))
	add_parameter(GNParameter.create_pulse("reset", "Reset", "Reset simulation"))


func _pre_cook(delta: float) -> void:
	super._pre_cook(delta)
	if get_param_value("reset"):
		_initialized = false
		mark_dirty()


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		_initialized = false
		return null

	if not _initialized:
		_source_arrays = in_geo.mesh.surface_get_arrays(0)
		_source_prim = in_geo.mesh.surface_get_primitive_type(0)
		var verts: PackedVector3Array = _source_arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = _source_arrays[Mesh.ARRAY_INDEX] if _source_arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var pinned := _compute_pinned(verts)
		if _processor != null:
			_processor.init_simulation(verts, indices, pinned)
		_initialized = true

	var gravity_val: float = get_param_value("gravity")
	var damping_val: float = get_param_value("damping")
	var iterations: int = get_param_value("iterations")
	var stiffness_val: float = get_param_value("stiffness")
	var wind := Vector3(get_param_value("wind_x"), get_param_value("wind_y"), get_param_value("wind_z"))
	var substeps: int = int(get_param_value("substeps"))
	var dt: float = current_delta / float(maxi(substeps, 1))

	if _processor != null:
		for _s in range(substeps):
			_processor.step(dt, gravity_val, damping_val, wind, iterations, stiffness_val)
		var positions: PackedVector3Array = _processor.get_positions()
		var geo := _prepare_geo()
		var arrays := _source_arrays.duplicate(true)
		arrays[Mesh.ARRAY_VERTEX] = positions
		var st := SurfaceTool.new()
		st.begin(_source_prim)
		st.create_from_arrays(arrays)
		st.generate_normals()
		var mesh := ArrayMesh.new()
		st.commit(mesh)
		geo.set_mesh(mesh)
		return geo

	return null


func _compute_pinned(verts: PackedVector3Array) -> PackedInt32Array:
	var pinned := PackedInt32Array()
	var pin_mode: int = get_param_value("pin_mode")
	if pin_mode == 3 or verts.is_empty():
		return pinned
	var max_y: float = verts[0].y
	for v in verts:
		max_y = maxf(max_y, v.y)
	var threshold: float = max_y - 0.01
	match pin_mode:
		0:
			for i in range(verts.size()):
				if verts[i].y >= threshold:
					pinned.append(i)
		1:
			var min_x: float = INF
			var max_x: float = -INF
			for i in range(verts.size()):
				if verts[i].y >= threshold:
					min_x = minf(min_x, verts[i].x)
					max_x = maxf(max_x, verts[i].x)
			for i in range(verts.size()):
				if verts[i].y >= threshold and (verts[i].x <= min_x + 0.01 or verts[i].x >= max_x - 0.01):
					pinned.append(i)
	return pinned
