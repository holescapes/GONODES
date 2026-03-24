class_name ClothSOP
extends GNSopBase
## Procedural Verlet-integration cloth simulation SOP.
##
## Takes an input grid/mesh and simulates fabric behaviour using
## position-based dynamics (PBD) with distance constraints.
##
## Pinned vertices are held in place; the rest fall under gravity and
## respond to wind.  The solver iterates each cook step so the cloth
## drapes progressively over time.
##
## TouchDesigner equivalent: Cloth SOP / Softbody SOP.

# ─── Simulation state ─────────────────────────────────────────────────────────

var _positions: PackedVector3Array = PackedVector3Array()
var _prev_positions: PackedVector3Array = PackedVector3Array()
var _rest_lengths: PackedFloat32Array = PackedFloat32Array()
var _edge_a: PackedInt32Array = PackedInt32Array()
var _edge_b: PackedInt32Array = PackedInt32Array()
var _pinned: PackedInt32Array = PackedInt32Array()  # Indices of pinned verts
var _initialized: bool = false
var _source_arrays: Array = []  # Original mesh surface arrays
var _source_prim: int = Mesh.PRIMITIVE_TRIANGLES


func _init() -> void:
	node_type = "cloth"
	time_dependent = true


func _init_ports() -> void:
	add_input("geo", GNFamily.Type.SOP, false, "Input mesh (grid recommended)")
	add_output("out", GNFamily.Type.SOP, "Simulated cloth geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("gravity", -9.8, -100.0, 0.0, 0.1,
		"Gravity", "Downward acceleration (Y axis)"))
	add_parameter(GNParameter.create_float("damping", 0.99, 0.8, 1.0, 0.001,
		"Damping", "Velocity damping per step (1 = no damping)"))
	add_parameter(GNParameter.create_int("iterations", 8, 1, 64,
		"Constraint Iterations", "Solver iterations per step (higher = stiffer)"))
	add_parameter(GNParameter.create_float("stiffness", 1.0, 0.0, 1.0, 0.01,
		"Stiffness", "Constraint stiffness (1 = rigid, 0 = jelly)"))
	add_parameter(GNParameter.create_float("wind_x", 0.0, -100.0, 100.0, 0.01,
		"Wind X", "Wind force X component"))
	add_parameter(GNParameter.create_float("wind_y", 0.0, -100.0, 100.0, 0.01,
		"Wind Y", "Wind force Y component"))
	add_parameter(GNParameter.create_float("wind_z", 0.0, -100.0, 100.0, 0.01,
		"Wind Z", "Wind force Z component"))
	add_parameter(GNParameter.create_enum("pin_mode",
		PackedStringArray(["Top Row", "Top Corners", "Custom Attrib", "None"]), 0,
		"Pin Mode", "Which vertices are fixed in place"))
	add_parameter(GNParameter.create_float("substeps", 2.0, 1.0, 10.0, 1.0,
		"Substeps", "Simulation substeps per frame (higher = more stable)"))
	add_parameter(GNParameter.create_pulse("reset",
		"Reset", "Reset simulation to rest pose"))


func _pre_cook(delta: float) -> void:
	super._pre_cook(delta)
	if get_param_value("reset"):
		_initialized = false
		mark_dirty()


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		_initialized = false
		return null

	# (Re)initialize simulation from input mesh
	if not _initialized:
		_init_simulation(in_geo)

	# Simulation parameters
	var gravity_val: float = get_param_value("gravity")
	var damping_val: float = get_param_value("damping")
	var iterations: int = get_param_value("iterations")
	var stiffness_val: float = get_param_value("stiffness")
	var wind_val := Vector3(get_param_value("wind_x"), get_param_value("wind_y"), get_param_value("wind_z"))
	var substep_count: int = int(get_param_value("substeps"))
	var dt: float = current_delta / float(substep_count) if substep_count > 0 else current_delta

	# Run substeps
	for _s in range(substep_count):
		_verlet_step(dt, gravity_val, damping_val, wind_val)
		for _i in range(iterations):
			_solve_constraints(stiffness_val)
		_enforce_pins()

	# Build output mesh
	var out := _prepare_geo()
	var arrays := _source_arrays.duplicate(true)
	arrays[Mesh.ARRAY_VERTEX] = _positions.duplicate()
	# Recompute normals
	arrays[Mesh.ARRAY_NORMAL] = _compute_normals(arrays)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(_source_prim, arrays)
	out.set_mesh(mesh)
	return out


# ═══════════════════════════════════════════════════════════════════════════════
# Simulation Init
# ═══════════════════════════════════════════════════════════════════════════════

func _init_simulation(geo: GNGeoData) -> void:
	_source_arrays = geo.mesh.surface_get_arrays(0)
	_source_prim = geo.mesh.surface_get_primitive_type(0)
	_positions = (_source_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	_prev_positions = _positions.duplicate()
	var vert_count: int = _positions.size()

	# Build edge list from triangle indices
	_edge_a.clear()
	_edge_b.clear()
	_rest_lengths.clear()
	var edge_set := {}  # "a:b" → true (deduplicate)

	var indices: PackedInt32Array = _source_arrays[Mesh.ARRAY_INDEX] if _source_arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.size() >= 3:
		for i in range(0, indices.size(), 3):
			_add_edge(indices[i], indices[i + 1], edge_set)
			_add_edge(indices[i + 1], indices[i + 2], edge_set)
			_add_edge(indices[i + 2], indices[i], edge_set)
	else:
		# Non-indexed mesh: treat consecutive triplets as triangles
		for i in range(0, vert_count, 3):
			if i + 2 < vert_count:
				_add_edge(i, i + 1, edge_set)
				_add_edge(i + 1, i + 2, edge_set)
				_add_edge(i + 2, i, edge_set)

	# Determine pinned vertices
	_pinned.clear()
	var pin_mode: int = get_param_value("pin_mode")
	match pin_mode:
		0:  # Top Row — vertices with highest Y
			_pin_top_row(vert_count)
		1:  # Top Corners — two highest-Y extremes
			_pin_top_corners(vert_count)
		2:  # Custom Attrib — vertices where point_attribs["pin"] > 0.5
			_pin_from_attrib(geo, vert_count)
		3:  # None
			pass

	_initialized = true


func _add_edge(a: int, b: int, edge_set: Dictionary) -> void:
	var lo: int = mini(a, b)
	var hi: int = maxi(a, b)
	var key: int = lo * 1000000 + hi  # Compact hash for dedup
	if edge_set.has(key):
		return
	edge_set[key] = true
	_edge_a.append(a)
	_edge_b.append(b)
	_rest_lengths.append(_positions[a].distance_to(_positions[b]))


func _pin_top_row(vert_count: int) -> void:
	if vert_count == 0:
		return
	var max_y: float = _positions[0].y
	for i in range(1, vert_count):
		max_y = maxf(max_y, _positions[i].y)
	var threshold: float = max_y - 0.01
	for i in range(vert_count):
		if _positions[i].y >= threshold:
			_pinned.append(i)


func _pin_top_corners(vert_count: int) -> void:
	if vert_count == 0:
		return
	var max_y: float = _positions[0].y
	for i in range(1, vert_count):
		max_y = maxf(max_y, _positions[i].y)
	var threshold: float = max_y - 0.01
	# Collect top-row candidates, then pick min-x and max-x
	var top_indices: PackedInt32Array = PackedInt32Array()
	for i in range(vert_count):
		if _positions[i].y >= threshold:
			top_indices.append(i)
	if top_indices.is_empty():
		return
	var min_idx: int = top_indices[0]
	var max_idx: int = top_indices[0]
	for idx in top_indices:
		if _positions[idx].x < _positions[min_idx].x:
			min_idx = idx
		if _positions[idx].x > _positions[max_idx].x:
			max_idx = idx
	_pinned.append(min_idx)
	if max_idx != min_idx:
		_pinned.append(max_idx)


func _pin_from_attrib(geo: GNGeoData, vert_count: int) -> void:
	var pin_data: PackedFloat32Array = geo.point_attribs.get("pin", PackedFloat32Array())
	for i in range(mini(pin_data.size(), vert_count)):
		if pin_data[i] > 0.5:
			_pinned.append(i)


# ═══════════════════════════════════════════════════════════════════════════════
# Verlet Integration
# ═══════════════════════════════════════════════════════════════════════════════

func _verlet_step(dt: float, gravity: float, damping: float, wind: Vector3) -> void:
	var dt2: float = dt * dt
	var grav := Vector3(0.0, gravity * dt2, 0.0)
	var wind_force := wind * dt2
	for i in range(_positions.size()):
		var vel := (_positions[i] - _prev_positions[i]) * damping
		_prev_positions[i] = _positions[i]
		_positions[i] += vel + grav + wind_force


func _solve_constraints(stiffness: float) -> void:
	var edge_count: int = _edge_a.size()
	for i in range(edge_count):
		var a: int = _edge_a[i]
		var b: int = _edge_b[i]
		var delta: Vector3 = _positions[b] - _positions[a]
		var dist: float = delta.length()
		if dist < 1e-8:
			continue
		var diff: float = (dist - _rest_lengths[i]) / dist * stiffness
		var offset: Vector3 = delta * diff * 0.5
		_positions[a] += offset
		_positions[b] -= offset


func _enforce_pins() -> void:
	for idx in _pinned:
		_positions[idx] = _prev_positions[idx]
		# Reset prev to current so velocity is zero at pin
		_prev_positions[idx] = _positions[idx]


# ═══════════════════════════════════════════════════════════════════════════════
# Normal Recomputation
# ═══════════════════════════════════════════════════════════════════════════════

func _compute_normals(arrays: Array) -> PackedVector3Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var count: int = verts.size()
	var normals := PackedVector3Array()
	normals.resize(count)

	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.size() >= 3:
		for i in range(0, indices.size(), 3):
			var i0: int = indices[i]
			var i1: int = indices[i + 1]
			var i2: int = indices[i + 2]
			var face_n: Vector3 = (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
			normals[i0] += face_n
			normals[i1] += face_n
			normals[i2] += face_n
	else:
		for i in range(0, count, 3):
			if i + 2 < count:
				var face_n: Vector3 = (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i])
				normals[i] += face_n
				normals[i + 1] += face_n
				normals[i + 2] += face_n

	for i in range(count):
		if normals[i].length_squared() > 1e-10:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP

	return normals
