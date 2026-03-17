class_name MarchingCubesVOL
extends GNVolBase
## Extracts an iso-surface from a 3D volume using marching cubes → SOP mesh.
## CPU readback of the volume, then standard Bourke marching cubes algorithm.
## Reuses MetaballSOP's pre-baked lookup tables.

func _init() -> void:
	super._init()
	node_type = "marchingcubes"
	node_description = "Extract iso-surface mesh from volume (marching cubes)."


func _init_ports() -> void:
	add_input("vol", GNFamily.Type.VOL, true, "Density volume to mesh", "Volume")
	add_output("mesh", GNFamily.Type.SOP, "Extracted triangle mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("threshold", 0.5,
		0.0, 10.0, 0.01, "Threshold", "Iso-value to extract"))
	add_parameter(GNParameter.create_bool("smooth_normals", true, "Smooth Normals",
		"Use gradient normals (true) or face normals (false)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var vol: GNVolumeData = _get_input_vol(inputs, 0)
	if vol == null or not vol.has_volume():
		return null

	# Ensure marching cubes tables are initialized
	if not MetaballSOP._tables_initialized:
		MetaballSOP._init_marching_cubes_tables()
		MetaballSOP._tables_initialized = true

	var res: Vector3i = vol.resolution
	var threshold: float = get_param_value("threshold")
	var smooth: bool = get_param_value("smooth_normals")

	# Read full volume to CPU
	var raw: PackedByteArray = vol.read_full()
	if raw.is_empty():
		return null

	# Decode float field (R32F = 4 bytes per voxel)
	var bpv: int = vol.bytes_per_voxel()
	var total_voxels: int = res.x * res.y * res.z
	var field := PackedFloat32Array()
	field.resize(total_voxels)
	for i in range(total_voxels):
		field[i] = raw.decode_float(i * bpv)

	# Grid size (marching cubes operates on grid of res-1 cells)
	var gx: int = res.x
	var gy: int = res.y
	var gz: int = res.z

	var bounds: AABB = vol.bounds
	var cell_size := Vector3(
		bounds.size.x / float(gx - 1),
		bounds.size.y / float(gy - 1),
		bounds.size.z / float(gz - 1))

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()

	# March through each cube cell
	for iz in range(gz - 1):
		for iy in range(gy - 1):
			for ix in range(gx - 1):
				_march_cell(ix, iy, iz, gx, gy, field, threshold,
					bounds.position, cell_size, smooth, verts, normals)

	if verts.is_empty():
		return null

	var geo := GNGeoData.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	geo.set_mesh(mesh)
	return geo


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var vol := _get_input_vol_cpu(inputs, 0)
	if vol == null or not vol.has_volume():
		return null

	if not MetaballSOP._tables_initialized:
		MetaballSOP._init_marching_cubes_tables()
		MetaballSOP._tables_initialized = true

	var res: Vector3i = vol.resolution
	var threshold: float = get_param_value("threshold")
	var smooth: bool = get_param_value("smooth_normals")
	var field: PackedFloat32Array = vol.cpu_data

	var gx: int = res.x
	var gy: int = res.y
	var gz: int = res.z
	var bounds: AABB = vol.bounds
	var cell_size := Vector3(
		bounds.size.x / float(gx - 1),
		bounds.size.y / float(gy - 1),
		bounds.size.z / float(gz - 1))

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()

	for iz in range(gz - 1):
		for iy in range(gy - 1):
			for ix in range(gx - 1):
				_march_cell(ix, iy, iz, gx, gy, field, threshold,
					bounds.position, cell_size, smooth, verts, normals)

	if verts.is_empty():
		return null

	var geo := GNGeoData.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	geo.set_mesh(mesh)
	return geo


func _march_cell(ix: int, iy: int, iz: int, gx: int, gy: int,
		field: PackedFloat32Array, threshold: float,
		origin: Vector3, cell_size: Vector3, smooth: bool,
		out_verts: PackedVector3Array, out_normals: PackedVector3Array) -> void:

	var offsets: Array[Vector3i] = [
		Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 0),
		Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 1, 1), Vector3i(0, 1, 1)
	]

	var corners: Array[Vector3] = []
	var values := PackedFloat32Array()
	corners.resize(8)
	values.resize(8)

	var cube_idx: int = 0
	for ci in range(8):
		var ox: int = ix + offsets[ci].x
		var oy: int = iy + offsets[ci].y
		var oz: int = iz + offsets[ci].z
		corners[ci] = origin + Vector3(
			ox * cell_size.x, oy * cell_size.y, oz * cell_size.z)
		values[ci] = field[oz * gy * gx + oy * gx + ox]
		if values[ci] >= threshold:
			cube_idx |= (1 << ci)

	if cube_idx == 0 or cube_idx == 255:
		return

	var edge_flags: int = MetaballSOP._mc_edge_table[cube_idx]
	var edge_verts: Array[Vector3] = []
	edge_verts.resize(12)

	var edge_pairs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0),
		Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 4),
		Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)
	]

	for ei in range(12):
		if edge_flags & (1 << ei) == 0:
			continue
		var e: Vector2i = edge_pairs[ei]
		var denom: float = values[e.y] - values[e.x]
		var t: float = 0.5
		if absf(denom) > 0.0001:
			t = clampf((threshold - values[e.x]) / denom, 0.0, 1.0)
		edge_verts[ei] = corners[e.x].lerp(corners[e.y], t)

	var tri_row: PackedInt32Array = MetaballSOP._mc_tri_table[cube_idx]
	var ti: int = 0
	while ti < tri_row.size() and tri_row[ti] != -1:
		var v0: Vector3 = edge_verts[tri_row[ti]]
		var v1: Vector3 = edge_verts[tri_row[ti + 1]]
		var v2: Vector3 = edge_verts[tri_row[ti + 2]]

		out_verts.append(v0)
		out_verts.append(v1)
		out_verts.append(v2)

		if smooth:
			# Central-difference gradient normal at each vertex
			out_normals.append(_gradient_normal(v0, origin, cell_size,
				Vector3i(ix, iy, iz).x, field, Vector3i(gx, gx, gx)))
			out_normals.append(_gradient_normal(v1, origin, cell_size,
				0, field, Vector3i(gx, gx, gx)))
			out_normals.append(_gradient_normal(v2, origin, cell_size,
				0, field, Vector3i(gx, gx, gx)))
		else:
			# Face normal
			var n: Vector3 = (v1 - v0).cross(v2 - v0).normalized()
			out_normals.append(n)
			out_normals.append(n)
			out_normals.append(n)

		ti += 3


func _gradient_normal(p: Vector3, origin: Vector3, cell: Vector3,
		_unused: int, field: PackedFloat32Array, grid: Vector3i) -> Vector3:
	# Find float grid coordinates
	var fp := (p - origin) / cell
	var gx: int = grid.x
	var gy: int = grid.x  # grid is cubic in our convention
	var ix: int = clampi(int(fp.x), 1, gx - 2)
	var iy: int = clampi(int(fp.y), 1, gy - 2)
	var iz: int = clampi(int(fp.z), 1, gx - 2)

	# Central differences
	var dx: float = field[iz * gy * gx + iy * gx + (ix + 1)] - field[iz * gy * gx + iy * gx + (ix - 1)]
	var dy: float = field[iz * gy * gx + (iy + 1) * gx + ix] - field[iz * gy * gx + (iy - 1) * gx + ix]
	var dz: float = field[(iz + 1) * gy * gx + iy * gx + ix] - field[(iz - 1) * gy * gx + iy * gx + ix]

	var grad := Vector3(dx, dy, dz)
	var len: float = grad.length()
	if len > 0.0001:
		return -grad / len  # Negate so normal points outward
	return Vector3.UP
