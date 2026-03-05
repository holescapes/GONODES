class_name MetaballSOP
extends GNSopBase
## Metaball / blobby surface generator using marching cubes.
##
## Evaluates an implicit scalar field defined by ball primitives (position +
## radius + weight) on a voxel grid then extracts the iso-surface via
## marching cubes.  Balls can come from:
##   • Input SOP point cloud — each point becomes a ball (radius from 'pscale'
##     attribute or the default_radius parameter).
##   • Built-in mode — up to 4 manual balls from parameters.
##
## The result is a smooth triangulated mesh where ball fields blend together
## organically.  Good for organic shapes, liquid drops, character blobs.
##
## This is a CPU implementation intended for later C++ porting.

## Marching cubes edge and triangle tables (pre-baked).
## These are the standard Paul Bourke tables (256 edge cases, up to 5 tris per cell).
## Stored as static to share across instances.
static var _mc_edge_table: PackedInt32Array
static var _mc_tri_table: Array  # Array of PackedInt32Array (256 entries)
static var _tables_initialized: bool = false


func _init() -> void:
	node_type = "metaball"
	node_description = "Metaball implicit surface via marching cubes."
	if not _tables_initialized:
		_init_marching_cubes_tables()
		_tables_initialized = true


func _init_ports() -> void:
	add_input("points", GNFamily.Type.SOP, false, "Point cloud for ball centres (optional)")
	add_output("out", GNFamily.Type.SOP, "Metaball surface mesh")


func _init_parameters() -> void:
	# Grid
	add_parameter(GNParameter.create_int("resolution", 30, 4, 128, "Resolution",
		"Voxel grid subdivisions per axis"))
	add_parameter(GNParameter.create_float("bounds_size", 6.0, 0.5, 100.0, 0.5,
		"Bounds Size", "Cubic grid extent (centered at origin)"))
	add_parameter(GNParameter.create_float("threshold", 1.0, 0.01, 10.0, 0.01,
		"Threshold", "Iso-surface threshold (field >= threshold = inside)"))

	# Default per-ball radius (used with point cloud input)
	add_parameter(GNParameter.create_float("default_radius", 1.0, 0.01, 50.0, 0.1,
		"Default Radius", "Ball radius when no 'pscale' attribute"))

	# Manual balls (when no input)
	add_parameter(GNParameter.create_int("ball_count", 2, 0, 4, "Ball Count",
		"Number of built-in balls (no input connected)"))
	add_parameter(GNParameter.create_float("b0x", -0.8, -50.0, 50.0, 0.1, "Ball 0 X", ""))
	add_parameter(GNParameter.create_float("b0y", 0.0, -50.0, 50.0, 0.1, "Ball 0 Y", ""))
	add_parameter(GNParameter.create_float("b0z", 0.0, -50.0, 50.0, 0.1, "Ball 0 Z", ""))
	add_parameter(GNParameter.create_float("b0r", 1.5, 0.01, 50.0, 0.1, "Ball 0 Radius", ""))
	add_parameter(GNParameter.create_float("b1x", 0.8, -50.0, 50.0, 0.1, "Ball 1 X", ""))
	add_parameter(GNParameter.create_float("b1y", 0.0, -50.0, 50.0, 0.1, "Ball 1 Y", ""))
	add_parameter(GNParameter.create_float("b1z", 0.0, -50.0, 50.0, 0.1, "Ball 1 Z", ""))
	add_parameter(GNParameter.create_float("b1r", 1.5, 0.01, 50.0, 0.1, "Ball 1 Radius", ""))
	add_parameter(GNParameter.create_float("b2x", 0.0, -50.0, 50.0, 0.1, "Ball 2 X", ""))
	add_parameter(GNParameter.create_float("b2y", 1.0, -50.0, 50.0, 0.1, "Ball 2 Y", ""))
	add_parameter(GNParameter.create_float("b2z", 0.0, -50.0, 50.0, 0.1, "Ball 2 Z", ""))
	add_parameter(GNParameter.create_float("b2r", 1.0, 0.01, 50.0, 0.1, "Ball 2 Radius", ""))
	add_parameter(GNParameter.create_float("b3x", 0.0, -50.0, 50.0, 0.1, "Ball 3 X", ""))
	add_parameter(GNParameter.create_float("b3y", -1.0, -50.0, 50.0, 0.1, "Ball 3 Y", ""))
	add_parameter(GNParameter.create_float("b3z", 0.0, -50.0, 50.0, 0.1, "Ball 3 Z", ""))
	add_parameter(GNParameter.create_float("b3r", 1.0, 0.01, 50.0, 0.1, "Ball 3 Radius", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var pts_geo: GNGeoData = _get_input_sop(inputs, 0)

	# ── Collect balls ──
	var ball_positions := PackedVector3Array()
	var ball_radii := PackedFloat32Array()

	if pts_geo != null and pts_geo.has_geometry():
		var pscale := pts_geo.get_point_attrib("pscale")
		var default_r: float = get_param_value("default_radius")
		for s in range(pts_geo.mesh.get_surface_count()):
			var arrays: Array = pts_geo.mesh.surface_get_arrays(s)
			if arrays[Mesh.ARRAY_VERTEX] == null:
				continue
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vi in range(verts.size()):
				ball_positions.append(verts[vi])
				if vi < pscale.size():
					ball_radii.append(pscale[vi])
				else:
					ball_radii.append(default_r)
	else:
		# Use manual balls
		var count: int = get_param_value("ball_count")
		for bi in range(mini(count, 4)):
			ball_positions.append(Vector3(
				get_param_value("b%dx" % bi),
				get_param_value("b%dy" % bi),
				get_param_value("b%dz" % bi)))
			ball_radii.append(get_param_value("b%dr" % bi))

	if ball_positions.is_empty():
		return null

	var res: int = get_param_value("resolution")
	var bounds: float = get_param_value("bounds_size") * 0.5
	var threshold: float = get_param_value("threshold")

	# ── Evaluate scalar field on grid ──
	var grid_size: int = res + 1
	var field := PackedFloat32Array()
	field.resize(grid_size * grid_size * grid_size)

	var cell_size: float = (bounds * 2.0) / float(res)

	for iz in range(grid_size):
		for iy in range(grid_size):
			for ix in range(grid_size):
				var p := Vector3(
					-bounds + ix * cell_size,
					-bounds + iy * cell_size,
					-bounds + iz * cell_size)
				var val: float = 0.0
				for bi in range(ball_positions.size()):
					var diff: Vector3 = p - ball_positions[bi]
					var dist_sq: float = diff.length_squared()
					var r: float = ball_radii[bi]
					# Smooth falloff: contribution = r^2 / dist^2
					if dist_sq > 0.0001:
						val += (r * r) / dist_sq
					else:
						val += 10000.0  # Inside ball centre
				field[iz * grid_size * grid_size + iy * grid_size + ix] = val

	# ── Marching cubes ──
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()

	for iz in range(res):
		for iy in range(res):
			for ix in range(res):
				_march_cube(ix, iy, iz, grid_size, field, threshold,
					cell_size, bounds, ball_positions, ball_radii, verts, normals)

	if verts.is_empty():
		return null

	var out := _prepare_geo()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.set_mesh(mesh)
	return out


func _march_cube(ix: int, iy: int, iz: int, gs: int,
		field: PackedFloat32Array, threshold: float,
		cell_size: float, bounds: float,
		ball_pos: PackedVector3Array, ball_radii: PackedFloat32Array,
		out_verts: PackedVector3Array, out_normals: PackedVector3Array) -> void:

	# 8 corner positions and values
	var corners: Array[Vector3] = []
	var values := PackedFloat32Array()
	corners.resize(8)
	values.resize(8)

	var offsets: Array[Vector3i] = [
		Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 0),
		Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 1, 1), Vector3i(0, 1, 1)
	]

	var cube_idx: int = 0
	for ci in range(8):
		var ox: int = ix + offsets[ci].x
		var oy: int = iy + offsets[ci].y
		var oz: int = iz + offsets[ci].z
		corners[ci] = Vector3(
			-bounds + ox * cell_size,
			-bounds + oy * cell_size,
			-bounds + oz * cell_size)
		values[ci] = field[oz * gs * gs + oy * gs + ox]
		if values[ci] >= threshold:
			cube_idx |= (1 << ci)

	if cube_idx == 0 or cube_idx == 255:
		return

	var edge_flags: int = _mc_edge_table[cube_idx]
	var edge_verts: Array[Vector3] = []
	edge_verts.resize(12)

	# Edge vertex pairs
	var edge_pairs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0),
		Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 4),
		Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)
	]

	for ei in range(12):
		if edge_flags & (1 << ei) == 0:
			continue
		var e: Vector2i = edge_pairs[ei]
		var t: float = (threshold - values[e.x]) / (values[e.y] - values[e.x] + 0.0001)
		t = clampf(t, 0.0, 1.0)
		edge_verts[ei] = corners[e.x].lerp(corners[e.y], t)

	# Generate triangles from table
	var tri_row: PackedInt32Array = _mc_tri_table[cube_idx]
	var ti: int = 0
	while ti < tri_row.size() and tri_row[ti] != -1:
		var v0: Vector3 = edge_verts[tri_row[ti]]
		var v1: Vector3 = edge_verts[tri_row[ti + 1]]
		var v2: Vector3 = edge_verts[tri_row[ti + 2]]

		# Compute normal from gradient of scalar field (analytically)
		var n0 := _compute_normal(v0, ball_pos, ball_radii)
		var n1 := _compute_normal(v1, ball_pos, ball_radii)
		var n2 := _compute_normal(v2, ball_pos, ball_radii)

		out_verts.append(v0)
		out_verts.append(v1)
		out_verts.append(v2)
		out_normals.append(n0)
		out_normals.append(n1)
		out_normals.append(n2)

		ti += 3


static func _compute_normal(p: Vector3, balls: PackedVector3Array,
		radii: PackedFloat32Array) -> Vector3:
	# Gradient of Σ(r²/|p-c|²) → normal points away from iso-surface
	var grad := Vector3.ZERO
	for i in range(balls.size()):
		var diff: Vector3 = p - balls[i]
		var dist_sq: float = diff.length_squared()
		if dist_sq < 0.0001:
			continue
		var r: float = radii[i]
		# d/dp (r²/|p-c|²) = -2r² * (p-c) / |p-c|^4
		grad += -2.0 * r * r * diff / (dist_sq * dist_sq)
	var len: float = grad.length()
	if len > 0.0001:
		return -grad / len  # Negate because gradient points inward
	return Vector3.UP


# ═══════════════════════════════════════════════════════════════════════════════
# Marching Cubes Lookup Tables (Paul Bourke)
# ═══════════════════════════════════════════════════════════════════════════════

static func _init_marching_cubes_tables() -> void:
	_mc_edge_table = PackedInt32Array([
		0x0, 0x109, 0x203, 0x30a, 0x406, 0x50f, 0x605, 0x70c,
		0x80c, 0x905, 0xa0f, 0xb06, 0xc0a, 0xd03, 0xe09, 0xf00,
		0x190, 0x99, 0x393, 0x29a, 0x596, 0x49f, 0x795, 0x69c,
		0x99c, 0x895, 0xb9f, 0xa96, 0xd9a, 0xc93, 0xf99, 0xe90,
		0x230, 0x339, 0x33, 0x13a, 0x636, 0x73f, 0x435, 0x53c,
		0xa3c, 0xb35, 0x83f, 0x936, 0xe3a, 0xf33, 0xc39, 0xd30,
		0x3a0, 0x2a9, 0x1a3, 0xaa, 0x7a6, 0x6af, 0x5a5, 0x4ac,
		0xbac, 0xaa5, 0x9af, 0x8a6, 0xfaa, 0xea3, 0xda9, 0xca0,
		0x460, 0x569, 0x663, 0x76a, 0x66, 0x16f, 0x265, 0x36c,
		0xc6c, 0xd65, 0xe6f, 0xf66, 0x86a, 0x963, 0xa69, 0xb60,
		0x5f0, 0x4f9, 0x7f3, 0x6fa, 0x1f6, 0xff, 0x3f5, 0x2fc,
		0xdfc, 0xcf5, 0xfff, 0xef6, 0x9fa, 0x8f3, 0xbf9, 0xaf0,
		0x650, 0x759, 0x453, 0x55a, 0x256, 0x35f, 0x55, 0x15c,
		0xe5c, 0xf55, 0xc5f, 0xd56, 0xa5a, 0xb53, 0x859, 0x950,
		0x7c0, 0x6c9, 0x5c3, 0x4ca, 0x3c6, 0x2cf, 0x1c5, 0xcc,
		0xfcc, 0xec5, 0xdcf, 0xcc6, 0xbca, 0xac3, 0x9c9, 0x8c0,
		0x8c0, 0x9c9, 0xac3, 0xbca, 0xcc6, 0xdcf, 0xec5, 0xfcc,
		0xcc, 0x1c5, 0x2cf, 0x3c6, 0x4ca, 0x5c3, 0x6c9, 0x7c0,
		0x950, 0x859, 0xb53, 0xa5a, 0xd56, 0xc5f, 0xf55, 0xe5c,
		0x15c, 0x55, 0x35f, 0x256, 0x55a, 0x453, 0x759, 0x650,
		0xaf0, 0xbf9, 0x8f3, 0x9fa, 0xef6, 0xfff, 0xcf5, 0xdfc,
		0x2fc, 0x3f5, 0xff, 0x1f6, 0x6fa, 0x7f3, 0x4f9, 0x5f0,
		0xb60, 0xa69, 0x963, 0x86a, 0xf66, 0xe6f, 0xd65, 0xc6c,
		0x36c, 0x265, 0x16f, 0x66, 0x76a, 0x663, 0x569, 0x460,
		0xca0, 0xda9, 0xea3, 0xfaa, 0x8a6, 0x9af, 0xaa5, 0xbac,
		0x4ac, 0x5a5, 0x6af, 0x7a6, 0xaa, 0x1a3, 0x2a9, 0x3a0,
		0xd30, 0xc39, 0xf33, 0xe3a, 0x936, 0x83f, 0xb35, 0xa3c,
		0x53c, 0x435, 0x73f, 0x636, 0x13a, 0x33, 0x339, 0x230,
		0xe90, 0xf99, 0xc93, 0xd9a, 0xa96, 0xb9f, 0x895, 0x99c,
		0x69c, 0x795, 0x49f, 0x596, 0x29a, 0x393, 0x99, 0x190,
		0xf00, 0xe09, 0xd03, 0xc0a, 0xb06, 0xa0f, 0x905, 0x80c,
		0x70c, 0x605, 0x50f, 0x406, 0x30a, 0x203, 0x109, 0x0
	])

	# Triangle table — 256 entries, each up to 16 ints terminated by -1.
	# This is the standard Bourke table.  Due to its size we build it from
	# a compact string encoding then parse once at startup.
	_mc_tri_table = []
	var raw: PackedStringArray = [
		"-1",
		"0,8,3,-1",
		"0,1,9,-1",
		"1,8,3,9,8,1,-1",
		"1,2,10,-1",
		"0,8,3,1,2,10,-1",
		"9,2,10,0,2,9,-1",
		"2,8,3,2,10,8,10,9,8,-1",
		"3,11,2,-1",
		"0,11,2,8,11,0,-1",
		"1,9,0,2,3,11,-1",
		"1,11,2,1,9,11,9,8,11,-1",
		"3,10,1,11,10,3,-1",
		"0,10,1,0,8,10,8,11,10,-1",
		"3,9,0,3,11,9,11,10,9,-1",
		"9,8,10,10,8,11,-1",
		"4,7,8,-1",
		"4,3,0,7,3,4,-1",
		"0,1,9,8,4,7,-1",
		"4,1,9,4,7,1,7,3,1,-1",
		"1,2,10,8,4,7,-1",
		"3,4,7,3,0,4,1,2,10,-1",
		"9,2,10,9,0,2,8,4,7,-1",
		"2,10,9,2,9,7,2,7,3,7,9,4,-1",
		"8,4,7,3,11,2,-1",
		"11,4,7,11,2,4,2,0,4,-1",
		"9,0,1,8,4,7,2,3,11,-1",
		"4,7,11,9,4,11,9,11,2,9,2,1,-1",
		"3,10,1,3,11,10,7,8,4,-1",
		"1,11,10,1,4,11,1,0,4,7,11,4,-1",
		"4,7,8,9,0,11,9,11,10,11,0,3,-1",
		"4,7,11,4,11,9,9,11,10,-1",
		"9,5,4,-1",
		"9,5,4,0,8,3,-1",
		"0,5,4,1,5,0,-1",
		"8,5,4,8,3,5,3,1,5,-1",
		"1,2,10,9,5,4,-1",
		"3,0,8,1,2,10,4,9,5,-1",
		"5,2,10,5,4,2,4,0,2,-1",
		"2,10,5,3,2,5,3,5,4,3,4,8,-1",
		"9,5,4,2,3,11,-1",
		"0,11,2,0,8,11,4,9,5,-1",
		"0,5,4,0,1,5,2,3,11,-1",
		"2,1,5,2,5,8,2,8,11,4,8,5,-1",
		"10,3,11,10,1,3,9,5,4,-1",
		"4,9,5,0,8,1,8,10,1,8,11,10,-1",
		"5,4,0,5,0,11,5,11,10,11,0,3,-1",
		"5,4,8,5,8,10,10,8,11,-1",
		"9,7,8,5,7,9,-1",
		"9,3,0,9,5,3,5,7,3,-1",
		"0,7,8,0,1,7,1,5,7,-1",
		"1,5,3,3,5,7,-1",
		"9,7,8,9,5,7,10,1,2,-1",
		"10,1,2,9,5,0,5,3,0,5,7,3,-1",
		"8,0,2,8,2,5,8,5,7,10,5,2,-1",
		"2,10,5,2,5,3,3,5,7,-1",
		"7,9,5,7,8,9,3,11,2,-1",
		"9,5,7,9,7,2,9,2,0,2,7,11,-1",
		"2,3,11,0,1,8,1,7,8,1,5,7,-1",
		"11,2,1,11,1,7,7,1,5,-1",
		"9,5,8,8,5,7,10,1,3,10,3,11,-1",
		"5,7,0,5,0,9,7,11,0,1,0,10,11,10,0,-1",
		"11,10,0,11,0,3,10,5,0,8,0,7,5,7,0,-1",
		"11,10,5,7,11,5,-1",
		"10,6,5,-1",
		"0,8,3,5,10,6,-1",
		"9,0,1,5,10,6,-1",
		"1,8,3,1,9,8,5,10,6,-1",
		"1,6,5,2,6,1,-1",
		"1,6,5,1,2,6,3,0,8,-1",
		"9,6,5,9,0,6,0,2,6,-1",
		"5,9,8,5,8,2,5,2,6,3,2,8,-1",
		"2,3,11,10,6,5,-1",
		"11,0,8,11,2,0,10,6,5,-1",
		"0,1,9,2,3,11,5,10,6,-1",
		"5,10,6,1,9,2,9,11,2,9,8,11,-1",
		"6,3,11,6,5,3,5,1,3,-1",
		"0,8,11,0,11,5,0,5,1,5,11,6,-1",
		"3,11,6,0,3,6,0,6,5,0,5,9,-1",
		"6,5,9,6,9,11,11,9,8,-1",
		"5,10,6,4,7,8,-1",
		"4,3,0,4,7,3,6,5,10,-1",
		"1,9,0,5,10,6,8,4,7,-1",
		"10,6,5,1,9,7,1,7,3,7,9,4,-1",
		"6,1,2,6,5,1,4,7,8,-1",
		"1,2,5,5,2,6,3,0,4,3,4,7,-1",
		"8,4,7,9,0,5,0,6,5,0,2,6,-1",
		"7,3,9,7,9,4,3,2,9,5,9,6,2,6,9,-1",
		"3,11,2,7,8,4,10,6,5,-1",
		"5,10,6,4,7,2,4,2,0,2,7,11,-1",
		"0,1,9,4,7,8,2,3,11,5,10,6,-1",
		"9,2,1,9,11,2,9,4,11,7,11,4,5,10,6,-1",
		"8,4,7,3,11,5,3,5,1,5,11,6,-1",
		"5,1,11,5,11,6,1,0,11,7,11,4,0,4,11,-1",
		"0,5,9,0,6,5,0,3,6,11,6,3,8,4,7,-1",
		"6,5,9,6,9,11,4,7,9,7,11,9,-1",
		"10,4,9,6,4,10,-1",
		"4,10,6,4,9,10,0,8,3,-1",
		"10,0,1,10,6,0,6,4,0,-1",
		"8,3,1,8,1,6,8,6,4,6,1,10,-1",
		"1,4,9,1,2,4,2,6,4,-1",
		"3,0,8,1,2,9,2,4,9,2,6,4,-1",
		"0,2,4,4,2,6,-1",
		"8,3,2,8,2,4,4,2,6,-1",
		"10,4,9,10,6,4,11,2,3,-1",
		"0,8,2,2,8,11,4,9,10,4,10,6,-1",
		"3,11,2,0,1,6,0,6,4,6,1,10,-1",
		"6,4,1,6,1,10,4,8,1,2,1,11,8,11,1,-1",
		"9,6,4,9,3,6,9,1,3,11,6,3,-1",
		"8,11,1,8,1,0,11,6,1,9,1,4,6,4,1,-1",
		"3,11,6,3,6,0,0,6,4,-1",
		"6,4,8,11,6,8,-1",
		"7,10,6,7,8,10,8,9,10,-1",
		"0,7,3,0,10,7,0,9,10,6,7,10,-1",
		"10,6,7,1,10,7,1,7,8,1,8,0,-1",
		"10,6,7,10,7,1,1,7,3,-1",
		"1,2,6,1,6,8,1,8,9,8,6,7,-1",
		"2,6,9,2,9,1,6,7,9,0,9,3,7,3,9,-1",
		"7,8,0,7,0,6,6,0,2,-1",
		"7,3,2,6,7,2,-1",
		"2,3,11,10,6,8,10,8,9,8,6,7,-1",
		"2,0,7,2,7,11,0,9,7,6,7,10,9,10,7,-1",
		"1,8,0,1,7,8,1,10,7,6,7,10,2,3,11,-1",
		"11,2,1,11,1,7,10,6,1,6,7,1,-1",
		"8,9,6,8,6,7,9,1,6,11,6,3,1,3,6,-1",
		"0,9,1,11,6,7,-1",
		"7,8,0,7,0,6,3,11,0,11,6,0,-1",
		"7,11,6,-1",
		"7,6,11,-1",
		"3,0,8,11,7,6,-1",
		"0,1,9,11,7,6,-1",
		"8,1,9,8,3,1,11,7,6,-1",
		"10,1,2,6,11,7,-1",
		"1,2,10,3,0,8,6,11,7,-1",
		"2,9,0,2,10,9,6,11,7,-1",
		"6,11,7,2,10,3,10,8,3,10,9,8,-1",
		"7,2,3,6,2,7,-1",
		"7,0,8,7,6,0,6,2,0,-1",
		"2,7,6,2,3,7,0,1,9,-1",
		"1,6,2,1,8,6,1,9,8,8,7,6,-1",
		"10,7,6,10,1,7,1,3,7,-1",
		"10,7,6,1,7,10,1,8,7,1,0,8,-1",
		"0,3,7,0,7,10,0,10,9,6,10,7,-1",
		"7,6,10,7,10,8,8,10,9,-1",
		"6,8,4,11,8,6,-1",
		"3,6,11,3,0,6,0,4,6,-1",
		"8,6,11,8,4,6,9,0,1,-1",
		"9,4,6,9,6,3,9,3,1,11,3,6,-1",
		"6,8,4,6,11,8,2,10,1,-1",
		"1,2,10,3,0,11,0,6,11,0,4,6,-1",
		"4,11,8,4,6,11,0,2,9,2,10,9,-1",
		"10,9,3,10,3,2,9,4,3,11,3,6,4,6,3,-1",
		"8,2,3,8,4,2,4,6,2,-1",
		"0,4,2,4,6,2,-1",
		"1,9,0,2,3,4,2,4,6,4,3,8,-1",
		"1,9,4,1,4,2,2,4,6,-1",
		"8,1,3,8,6,1,8,4,6,6,10,1,-1",
		"10,1,0,10,0,6,6,0,4,-1",
		"4,6,3,4,3,8,6,10,3,0,3,9,10,9,3,-1",
		"10,9,4,6,10,4,-1",
		"4,9,5,7,6,11,-1",
		"0,8,3,4,9,5,11,7,6,-1",
		"5,0,1,5,4,0,7,6,11,-1",
		"11,7,6,8,3,4,3,5,4,3,1,5,-1",
		"9,5,4,10,1,2,7,6,11,-1",
		"6,11,7,1,2,10,0,8,3,4,9,5,-1",
		"7,6,11,5,4,10,4,2,10,4,0,2,-1",
		"3,4,8,3,5,4,3,2,5,10,5,2,11,7,6,-1",
		"7,2,3,7,6,2,5,4,9,-1",
		"9,5,4,0,8,6,0,6,2,6,8,7,-1",
		"3,6,2,3,7,6,1,5,0,5,4,0,-1",
		"6,2,8,6,8,7,2,1,8,4,8,5,1,5,8,-1",
		"9,5,4,10,1,6,1,7,6,1,3,7,-1",
		"1,6,10,1,7,6,1,0,7,8,7,0,9,5,4,-1",
		"4,0,10,4,10,5,0,3,10,6,10,7,3,7,10,-1",
		"7,6,10,7,10,8,5,4,10,4,8,10,-1",
		"6,9,5,6,11,9,11,8,9,-1",
		"3,6,11,0,6,3,0,5,6,0,9,5,-1",
		"0,11,8,0,5,11,0,1,5,5,6,11,-1",
		"6,11,3,6,3,5,5,3,1,-1",
		"1,2,10,9,5,11,9,11,8,11,5,6,-1",
		"0,11,3,0,6,11,0,9,6,5,6,9,1,2,10,-1",
		"11,8,5,11,5,6,8,0,5,10,5,2,0,2,5,-1",
		"6,11,3,6,3,5,2,10,3,10,5,3,-1",
		"5,8,9,5,2,8,5,6,2,3,8,2,-1",
		"9,5,6,9,6,0,0,6,2,-1",
		"1,5,8,1,8,0,5,6,8,3,8,2,6,2,8,-1",
		"1,5,6,2,1,6,-1",
		"1,3,6,1,6,10,3,8,6,5,6,9,8,9,6,-1",
		"10,1,0,10,0,6,9,5,0,5,6,0,-1",
		"0,3,8,5,6,10,-1",
		"10,5,6,-1",
		"11,5,10,7,5,11,-1",
		"11,5,10,11,7,5,8,3,0,-1",
		"5,11,7,5,10,11,1,9,0,-1",
		"10,7,5,10,11,7,9,8,1,8,3,1,-1",
		"11,1,2,11,7,1,7,5,1,-1",
		"0,8,3,1,2,7,1,7,5,7,2,11,-1",
		"9,7,5,9,2,7,9,0,2,2,11,7,-1",
		"7,5,2,7,2,11,5,9,2,3,2,8,9,8,2,-1",
		"2,5,10,2,3,5,3,7,5,-1",
		"8,2,0,8,5,2,8,7,5,10,2,5,-1",
		"9,0,1,5,10,3,5,3,7,3,10,2,-1",
		"9,8,2,9,2,1,8,7,2,10,2,5,7,5,2,-1",
		"1,3,5,3,7,5,-1",
		"0,8,7,0,7,1,1,7,5,-1",
		"9,0,3,9,3,5,5,3,7,-1",
		"9,8,7,5,9,7,-1",
		"5,8,4,5,10,8,10,11,8,-1",
		"5,0,4,5,11,0,5,10,11,11,3,0,-1",
		"0,1,9,8,4,10,8,10,11,10,4,5,-1",
		"10,11,4,10,4,5,11,3,4,9,4,1,3,1,4,-1",
		"2,5,1,2,8,5,2,11,8,4,5,8,-1",
		"0,4,11,0,11,3,4,5,11,2,11,1,5,1,11,-1",
		"0,2,5,0,5,9,2,11,5,4,5,8,11,8,5,-1",
		"9,4,5,2,11,3,-1",
		"2,5,10,3,5,2,3,4,5,3,8,4,-1",
		"5,10,2,5,2,4,4,2,0,-1",
		"3,10,2,3,5,10,3,8,5,4,5,8,0,1,9,-1",
		"5,10,2,5,2,4,1,9,2,9,4,2,-1",
		"8,4,5,8,5,3,3,5,1,-1",
		"0,4,5,1,0,5,-1",
		"8,4,5,8,5,3,9,0,5,0,3,5,-1",
		"9,4,5,-1",
		"4,11,7,4,9,11,9,10,11,-1",
		"0,8,3,4,9,7,9,11,7,9,10,11,-1",
		"1,10,11,1,11,4,1,4,0,7,4,11,-1",
		"3,1,4,3,4,8,1,10,4,7,4,11,10,11,4,-1",
		"4,11,7,9,11,4,9,2,11,9,1,2,-1",
		"9,7,4,9,11,7,9,1,11,2,11,1,0,8,3,-1",
		"11,7,4,11,4,2,2,4,0,-1",
		"11,7,4,11,4,2,8,3,4,3,2,4,-1",
		"2,9,10,2,7,9,2,3,7,7,4,9,-1",
		"9,10,7,9,7,4,10,2,7,8,7,0,2,0,7,-1",
		"3,7,10,3,10,2,7,4,10,1,10,0,4,0,10,-1",
		"1,10,2,8,7,4,-1",
		"4,9,1,4,1,7,7,1,3,-1",
		"4,9,1,4,1,7,0,8,1,8,7,1,-1",
		"4,0,3,7,4,3,-1",
		"4,8,7,-1",
		"9,10,8,10,11,8,-1",
		"3,0,9,3,9,11,11,9,10,-1",
		"0,1,10,0,10,8,8,10,11,-1",
		"3,1,10,11,3,10,-1",
		"1,2,11,1,11,9,9,11,8,-1",
		"3,0,9,3,9,11,1,2,9,2,11,9,-1",
		"0,2,11,8,0,11,-1",
		"3,2,11,-1",
		"2,3,8,2,8,10,10,8,9,-1",
		"9,10,2,0,9,2,-1",
		"2,3,8,2,8,10,0,1,8,1,10,8,-1",
		"1,10,2,-1",
		"1,3,8,9,1,8,-1",
		"0,9,1,-1",
		"0,3,8,-1",
		"-1"
	]

	_mc_tri_table.resize(256)
	for i in range(256):
		var row := PackedInt32Array()
		var parts: PackedStringArray = raw[i].split(",")
		for p in parts:
			row.append(int(p.strip_edges()))
		_mc_tri_table[i] = row
