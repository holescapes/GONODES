class_name SoftBodyCOMP
extends GNCompBase
## CPU-side Verlet cloth/soft-body simulation.
##
## Takes a COMP input (typically GeometryCOMP) and simulates deformable physics
## using position-based Verlet integration.  Bypasses Jolt/Godot SoftBody3D
## entirely — works in any SubViewport + custom World3D setup.
##
## Architecture:
##   SOP → GeometryCOMP → SoftBodyCOMP → MergeCOMP → RenderTOP
##              ↑
##          PbrMAT

# ── Simulation state ─────────────────────────────────────────────────────────
var _mesh_inst: MeshInstance3D = null
var _positions: PackedVector3Array        # current vertex positions (world)
var _prev_positions: PackedVector3Array   # previous frame positions (Verlet)
var _rest_lengths: PackedFloat32Array     # rest distance per constraint edge
var _edge_a: PackedInt32Array             # vertex index A per constraint
var _edge_b: PackedInt32Array             # vertex index B per constraint
var _pinned: PackedByteArray              # 1 = pinned (immovable), 0 = free
var _normals: PackedVector3Array          # stored normals from source mesh
var _uvs: PackedVector2Array              # stored UVs from source mesh
var _indices: PackedInt32Array            # triangle indices from source mesh
var _sim_initialized: bool = false
var _source_mesh_ref: Mesh = null         # track upstream mesh for change detection


func _init() -> void:
	node_type = "soft_body"
	time_dependent = true


func _init_ports() -> void:
	add_input("comp_in", GNFamily.Type.COMP, false, "Geometry COMP input (mesh + material)", "Comp")
	add_output("out", GNFamily.Type.COMP, "SoftBody component")


func _init_parameters() -> void:
	# ── Transform ────────────────────────────────────────────────────────
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", "X position"))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", "Y position"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", "Z position"))
	add_parameter(GNParameter.create_float("rx", 0.0, null, null, 0.1, "Rotate X", "Rotation X (degrees)"))
	add_parameter(GNParameter.create_float("ry", 0.0, null, null, 0.1, "Rotate Y", "Rotation Y (degrees)"))
	add_parameter(GNParameter.create_float("rz", 0.0, null, null, 0.1, "Rotate Z", "Rotation Z (degrees)"))
	add_parameter(GNParameter.create_float("sx", 1.0, null, null, 0.01, "Scale X", "Scale X"))
	add_parameter(GNParameter.create_float("sy", 1.0, null, null, 0.01, "Scale Y", "Scale Y"))
	add_parameter(GNParameter.create_float("sz", 1.0, null, null, 0.01, "Scale Z", "Scale Z"))

	# ── Simulation ───────────────────────────────────────────────────────
	add_parameter(GNParameter.create_int("iterations", 8, 1, 40,
		"Iterations", "Constraint solver iterations per frame (higher = stiffer)"))
	add_parameter(GNParameter.create_float("gravity", -9.8, -50.0, 50.0, 0.1,
		"Gravity", "Vertical acceleration (negative = downward)"))
	add_parameter(GNParameter.create_float("damping", 0.98, 0.8, 1.0, 0.005,
		"Damping", "Velocity retention per step (1 = no damping, lower = more drag)"))
	add_parameter(GNParameter.create_float("stiffness", 1.0, 0.0, 1.0, 0.01,
		"Stiffness", "Constraint correction strength (0 = floppy, 1 = rigid springs)"))

	# ── Ground collision ─────────────────────────────────────────────────
	add_parameter(GNParameter.create_bool("floor_collision", true,
		"Floor Collision", "Collide with a horizontal floor plane"))
	add_parameter(GNParameter.create_float("floor_y", 0.0, -100.0, 100.0, 0.01,
		"Floor Y", "Floor plane height (world Y)"))

	# ── Pinning ──────────────────────────────────────────────────────────
	add_parameter(GNParameter.create_enum("pin_mode",
		PackedStringArray(["None", "Top Edge", "Top Corners", "All Edges"]), 1,
		"Pin Mode", "Which vertices are frozen (relative to mesh bounding box)"))
	add_parameter(GNParameter.create_float("pin_threshold", 0.02, 0.0, 1.0, 0.005,
		"Pin Threshold", "Normalized Y threshold for pinning (0 = exact top, higher = more rows)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var upstream_mesh: MeshInstance3D = _resolve_upstream_mesh()
	if upstream_mesh == null or upstream_mesh.mesh == null:
		return null

	# ── First cook or mesh changed: build simulation from source mesh ────
	if not _sim_initialized or upstream_mesh.mesh != _source_mesh_ref:
		_init_simulation(upstream_mesh)

	# ── Verlet time step ─────────────────────────────────────────────────
	var dt: float = current_delta
	if dt <= 0.0:
		dt = 1.0 / 60.0
	# Cap delta to prevent explosion after long pauses
	dt = minf(dt, 1.0 / 20.0)

	var gravity_y: float = get_param_value("gravity")
	var damping: float = get_param_value("damping")
	var stiffness: float = get_param_value("stiffness")
	var iterations: int = get_param_value("iterations")
	var floor_on: bool = get_param_value("floor_collision")
	var floor_y: float = get_param_value("floor_y")
	var gravity_vec := Vector3(0.0, gravity_y * dt * dt, 0.0)

	var count: int = _positions.size()

	# ── Verlet integration ───────────────────────────────────────────────
	for i in range(count):
		if _pinned[i]:
			continue
		var pos: Vector3 = _positions[i]
		var prev: Vector3 = _prev_positions[i]
		var vel: Vector3 = (pos - prev) * damping
		_prev_positions[i] = pos
		_positions[i] = pos + vel + gravity_vec

	# ── Distance constraints ─────────────────────────────────────────────
	var edge_count: int = _edge_a.size()
	for _iter in range(iterations):
		for e in range(edge_count):
			var ia: int = _edge_a[e]
			var ib: int = _edge_b[e]
			var pa: Vector3 = _positions[ia]
			var pb: Vector3 = _positions[ib]
			var delta: Vector3 = pb - pa
			var dist: float = delta.length()
			if dist < 1e-8:
				continue
			var rest: float = _rest_lengths[e]
			var correction: Vector3 = delta * ((dist - rest) / dist) * 0.5 * stiffness
			var a_pinned: bool = _pinned[ia] == 1
			var b_pinned: bool = _pinned[ib] == 1
			if a_pinned and b_pinned:
				continue
			elif a_pinned:
				_positions[ib] = pb - correction * 2.0
			elif b_pinned:
				_positions[ia] = pa + correction * 2.0
			else:
				_positions[ia] = pa + correction
				_positions[ib] = pb - correction

	# ── Floor collision ──────────────────────────────────────────────────
	if floor_on:
		for i in range(count):
			if _pinned[i]:
				continue
			if _positions[i].y < floor_y:
				_positions[i].y = floor_y

	# ── Write positions back to mesh ─────────────────────────────────────
	_rebuild_mesh()

	# Vertices are already in world space (transform baked at _init_simulation),
	# so leave _mesh_inst at identity.  Sync material/visibility only.
	var upstream_nd: Node3D = _get_upstream_scene_node(0)
	if upstream_nd is MeshInstance3D:
		var src_mesh := upstream_nd as MeshInstance3D
		_mesh_inst.material_override = src_mesh.material_override
		_mesh_inst.visible = upstream_nd.visible

	return _build_comp_data()


# ═══════════════════════════════════════════════════════════════════════════════
# Simulation Init
# ═══════════════════════════════════════════════════════════════════════════════

## Extracts vertices, indices, and edge constraints from the upstream mesh.
## Computes pinning based on the chosen pin mode.
func _init_simulation(upstream: MeshInstance3D) -> void:
	_sim_initialized = false
	_source_mesh_ref = upstream.mesh

	# Create render node
	if _mesh_inst == null:
		_mesh_inst = MeshInstance3D.new()
		_mesh_inst.name = id + "_soft"
		_scene_node = _mesh_inst

	_mesh_inst.material_override = upstream.material_override
	_mesh_inst.visible = upstream.visible
	_mesh_inst.cast_shadow = upstream.cast_shadow

	# Extract surface arrays
	var src_mesh: Mesh = upstream.mesh
	if src_mesh.get_surface_count() == 0:
		return
	var arrays: Array = src_mesh.surface_get_arrays(0)
	_positions = PackedVector3Array(arrays[Mesh.ARRAY_VERTEX])
	_normals = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	_uvs = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	_indices = PackedInt32Array(arrays[Mesh.ARRAY_INDEX]) if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

	# Apply initial transform to put positions into world space offset
	var xform := Transform3D()
	xform.origin = Vector3(get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))
	xform.basis = Basis.from_euler(Vector3(
		deg_to_rad(get_param_value("rx")),
		deg_to_rad(get_param_value("ry")),
		deg_to_rad(get_param_value("rz"))))
	xform.basis = xform.basis.scaled(Vector3(
		get_param_value("sx"), get_param_value("sy"), get_param_value("sz")))
	for i in range(_positions.size()):
		_positions[i] = xform * _positions[i]

	# Copy positions as prev (zero initial velocity)
	_prev_positions = _positions.duplicate()

	# Build edge constraints from triangle index buffer
	_build_edges()

	# Compute pinning
	_compute_pinning()

	_sim_initialized = true


## Builds unique edge constraints from the triangle index buffer.
func _build_edges() -> void:
	_edge_a = PackedInt32Array()
	_edge_b = PackedInt32Array()
	_rest_lengths = PackedFloat32Array()

	var seen := {}  # "min_max" → true
	var idx_count: int = _indices.size()

	if idx_count == 0:
		# No index buffer — create from sequential triangles
		var vert_count: int = _positions.size()
		idx_count = vert_count - (vert_count % 3)
		for t in range(0, idx_count, 3):
			_add_edge_if_new(seen, t, t + 1)
			_add_edge_if_new(seen, t + 1, t + 2)
			_add_edge_if_new(seen, t, t + 2)
	else:
		for t in range(0, idx_count, 3):
			_add_edge_if_new(seen, _indices[t], _indices[t + 1])
			_add_edge_if_new(seen, _indices[t + 1], _indices[t + 2])
			_add_edge_if_new(seen, _indices[t], _indices[t + 2])


func _add_edge_if_new(seen: Dictionary, ia: int, ib: int) -> void:
	var key: int = mini(ia, ib) * 100000 + maxi(ia, ib)
	if seen.has(key):
		return
	seen[key] = true
	_edge_a.append(ia)
	_edge_b.append(ib)
	_rest_lengths.append(_positions[ia].distance_to(_positions[ib]))


## Determines which vertices are pinned based on pin_mode parameter.
func _compute_pinning() -> void:
	var count: int = _positions.size()
	_pinned = PackedByteArray()
	_pinned.resize(count)

	var pin_mode: int = get_param_value("pin_mode")
	if pin_mode == 0:  # None
		return

	# Find bounding box Y range
	var min_y: float = INF
	var max_y: float = -INF
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for i in range(count):
		var p: Vector3 = _positions[i]
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.z)
		max_z = maxf(max_z, p.z)

	var y_range: float = max_y - min_y
	if y_range < 1e-6:
		return  # Flat mesh — can't meaningfully pin by Y

	var threshold: float = get_param_value("pin_threshold")

	match pin_mode:
		1:  # Top Edge — pin vertices near max Y
			for i in range(count):
				if (_positions[i].y - min_y) / y_range >= (1.0 - threshold):
					_pinned[i] = 1
		2:  # Top Corners — pin only extreme X corners at top
			var x_range: float = max_x - min_x
			for i in range(count):
				var p: Vector3 = _positions[i]
				var ny: float = (p.y - min_y) / y_range
				if ny >= (1.0 - threshold):
					var nx: float = (p.x - min_x) / x_range if x_range > 1e-6 else 0.5
					if nx <= threshold or nx >= (1.0 - threshold):
						_pinned[i] = 1
		3:  # All Edges — pin vertices near any bounding box edge
			var x_range: float = max_x - min_x
			var z_range: float = max_z - min_z
			for i in range(count):
				var p: Vector3 = _positions[i]
				var ny: float = (p.y - min_y) / y_range
				var nx: float = (p.x - min_x) / x_range if x_range > 1e-6 else 0.5
				var nz: float = (p.z - min_z) / z_range if z_range > 1e-6 else 0.5
				if ny >= (1.0 - threshold) or ny <= threshold \
					or nx >= (1.0 - threshold) or nx <= threshold \
					or nz >= (1.0 - threshold) or nz <= threshold:
					_pinned[i] = 1


# ═══════════════════════════════════════════════════════════════════════════════
# Mesh Rebuild
# ═══════════════════════════════════════════════════════════════════════════════

## Writes current _positions back into a fresh ArrayMesh on _mesh_inst.
func _rebuild_mesh() -> void:
	if _mesh_inst == null:
		return

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _positions
	if _normals.size() == _positions.size():
		# Recompute normals from deformed positions
		_recompute_normals()
		arrays[Mesh.ARRAY_NORMAL] = _normals
	if _uvs.size() == _positions.size():
		arrays[Mesh.ARRAY_TEX_UV] = _uvs
	if _indices.size() > 0:
		arrays[Mesh.ARRAY_INDEX] = _indices

	var new_mesh := ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_inst.mesh = new_mesh


## Recomputes face normals from the current deformed vertex positions.
func _recompute_normals() -> void:
	var count: int = _positions.size()
	# Zero out
	for i in range(count):
		_normals[i] = Vector3.ZERO

	var idx_count: int = _indices.size()
	if idx_count > 0:
		for t in range(0, idx_count, 3):
			var ia: int = _indices[t]
			var ib: int = _indices[t + 1]
			var ic: int = _indices[t + 2]
			var face_n: Vector3 = (_positions[ib] - _positions[ia]).cross(
				_positions[ic] - _positions[ia])
			_normals[ia] += face_n
			_normals[ib] += face_n
			_normals[ic] += face_n
	else:
		var tri_count: int = count - (count % 3)
		for t in range(0, tri_count, 3):
			var face_n: Vector3 = (_positions[t + 1] - _positions[t]).cross(
				_positions[t + 2] - _positions[t])
			_normals[t] += face_n
			_normals[t + 1] += face_n
			_normals[t + 2] += face_n

	for i in range(count):
		if _normals[i].length_squared() > 1e-12:
			_normals[i] = _normals[i].normalized()
		else:
			_normals[i] = Vector3.UP


# ═══════════════════════════════════════════════════════════════════════════════
# Cleanup
# ═══════════════════════════════════════════════════════════════════════════════

func destroy_scene_node() -> void:
	_mesh_inst = null
	_sim_initialized = false
	_source_mesh_ref = null
	_positions = PackedVector3Array()
	_prev_positions = PackedVector3Array()
	super.destroy_scene_node()


func render_for_viewer(viewer, port_index: int = 0) -> void:
	if _mesh_inst != null and _mesh_inst.mesh != null and _mesh_inst.mesh is ArrayMesh:
		GNGeoRenderer._ensure_viewer_scene()
		var vp: SubViewport = viewer.get_3d_viewport()
		GNGeoRenderer._reparent_viewer_nodes(vp)
		GNGeoRenderer._viewer_mesh_instance.mesh = _mesh_inst.mesh
		GNGeoRenderer._viewer_mesh_instance.material_override = _mesh_inst.material_override
		GNViewerRenderHelpers.apply_orbit_camera(
			GNGeoRenderer._viewer_camera, 45.0, -30.0, 3.0)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewer.set_info_bar("SoftBodyCOMP")
		var verts: int = _positions.size() if _positions != null else 0
		viewer.set_info_overlay("SoftBody — %d verts  Iter: %d" % [verts, get_param_value("iterations")])
		return
	var verts: int = _positions.size() if _positions != null else 0
	viewer.set_info("SoftBody — %d vertices\nIterations: %d" % [
		verts, get_param_value("iterations")], "SoftBodyCOMP")


# ═══════════════════════════════════════════════════════════════════════════════
# Upstream Resolution
# ═══════════════════════════════════════════════════════════════════════════════
