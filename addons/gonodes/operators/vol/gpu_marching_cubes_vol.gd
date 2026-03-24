class_name GPUMarchingCubesVOL
extends GNVolBase
## GPU-accelerated marching cubes: extracts iso-surface from a 3D volume
## using a compute shader with atomic append buffer.  10–100× faster than
## the CPU MarchingCubesVOL for volumes above ~32³.

var _vertex_buf: RID = RID()
var _counter_buf: RID = RID()
var _edge_table_buf: RID = RID()
var _tri_table_buf: RID = RID()
var _tables_uploaded: bool = false
var _last_max_tris: int = 0

const FLOATS_PER_TRI: int = 24  # 3 verts × (pos vec4 + normal vec4)
const BYTES_PER_TRI: int = FLOATS_PER_TRI * 4  # 96 bytes


func _init() -> void:
	super._init()
	node_type = "gpu_marching_cubes"
	node_description = "GPU-accelerated iso-surface extraction via marching cubes compute shader."


func _init_ports() -> void:
	add_input("vol", GNFamily.Type.VOL, true, "Density volume to mesh", "Volume")
	add_output("mesh", GNFamily.Type.SOP, "Extracted triangle mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("threshold", 0.5,
		0.0, 10.0, 0.01, "Threshold", "Iso-value to extract"))
	add_parameter(GNParameter.create_int("max_triangles", 500000,
		10000, 5000000, "Max Triangles", "Output buffer capacity"))


func _cook(inputs: Array[GNData]) -> GNData:
	var vol: GNVolumeData = _get_input_vol(inputs, 0)
	if vol == null or not vol.has_volume():
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return _cook_cpu(inputs)

	var res: Vector3i = vol.resolution
	var threshold: float = get_param_value("threshold")
	var max_tris: int = get_param_value("max_triangles")
	var bounds: AABB = vol.bounds

	# Upload lookup tables once
	if not _tables_uploaded:
		_upload_lookup_tables(ctx)

	# (Re)allocate output buffer if needed
	if max_tris != _last_max_tris:
		_realloc_buffers(ctx, max_tris)

	# Clear counter to zero
	var zero_bytes := PackedByteArray()
	zero_bytes.resize(4)
	zero_bytes.encode_u32(0, 0)
	ctx.rd.buffer_update(_counter_buf, 0, 4, zero_bytes)

	# Compile shader
	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/marching_cubes_gpu.glsl")
	if not shader.is_valid():
		return _cook_cpu(inputs)

	# Create sampler for volume input
	var sampler: RID = ctx.create_linear_sampler()

	# Push constants: 12 values × 4 bytes = 48 bytes
	var pc := PackedByteArray()
	pc.resize(48)
	pc.encode_s32(0, res.x)
	pc.encode_s32(4, res.y)
	pc.encode_s32(8, res.z)
	pc.encode_float(12, threshold)
	pc.encode_s32(16, max_tris)
	pc.encode_float(20, bounds.position.x)
	pc.encode_float(24, bounds.position.y)
	pc.encode_float(28, bounds.position.z)
	pc.encode_float(32, bounds.size.x)
	pc.encode_float(36, bounds.size.y)
	pc.encode_float(40, bounds.size.z)
	pc.encode_float(44, 0.0)  # pad to 48 bytes

	# Create uniform set
	var uniform_set: RID = ctx.rd.uniform_set_create([
		ctx.uniform_sampler(0, sampler, vol.rd_texture),
		ctx.uniform_buffer(1, _vertex_buf),
		ctx.uniform_buffer(2, _counter_buf),
		ctx.uniform_buffer(3, _edge_table_buf),
		ctx.uniform_buffer(4, _tri_table_buf),
	], shader, 0)

	# Dispatch: one thread per cell, local_size = 4³
	var wg := _workgroups_3d(res - Vector3i.ONE, 4)
	ctx.dispatch(shader, uniform_set, wg.x, wg.y, wg.z, pc)

	ctx.rd.free_rid(uniform_set)
	ctx.rd.free_rid(sampler)

	# Read back triangle count
	var counter_data: PackedByteArray = ctx.read_buffer(_counter_buf, 4)
	var tri_count: int = mini(counter_data.decode_u32(0), max_tris)
	if tri_count == 0:
		return null

	# Read back vertex data
	var vert_bytes: int = tri_count * BYTES_PER_TRI
	var raw: PackedByteArray = ctx.read_buffer(_vertex_buf, vert_bytes)

	# Decode into Godot arrays
	var vert_count: int = tri_count * 3
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	positions.resize(vert_count)
	normals.resize(vert_count)

	for i in range(vert_count):
		var base: int = i * 32  # 8 floats × 4 bytes per vertex
		positions[i] = Vector3(
			raw.decode_float(base),
			raw.decode_float(base + 4),
			raw.decode_float(base + 8))
		normals[i] = Vector3(
			raw.decode_float(base + 16),
			raw.decode_float(base + 20),
			raw.decode_float(base + 24))

	var geo := GNGeoData.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	geo.set_mesh(mesh)
	return geo


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	# Fall back to the CPU marching cubes algorithm
	var vol := _get_input_vol_cpu(inputs, 0)
	if vol == null or not vol.has_volume():
		return null

	if not MetaballSOP._tables_initialized:
		MetaballSOP._init_marching_cubes_tables()
		MetaballSOP._tables_initialized = true

	var res: Vector3i = vol.resolution
	var threshold: float = get_param_value("threshold")
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
	var norms := PackedVector3Array()

	for iz in range(gz - 1):
		for iy in range(gy - 1):
			for ix in range(gx - 1):
				_march_cell_cpu(ix, iy, iz, gx, gy, field, threshold,
					bounds.position, cell_size, verts, norms)

	if verts.is_empty():
		return null

	var geo := GNGeoData.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	geo.set_mesh(mesh)
	return geo


# ═══════════════════════════════════════════════════════════════════════════════
# GPU Buffer Management
# ═══════════════════════════════════════════════════════════════════════════════

func _upload_lookup_tables(ctx: GNGpuContext) -> void:
	if not MetaballSOP._tables_initialized:
		MetaballSOP._init_marching_cubes_tables()
		MetaballSOP._tables_initialized = true

	# Edge table: 256 ints
	var edge_bytes := PackedByteArray()
	edge_bytes.resize(256 * 4)
	for i in range(256):
		edge_bytes.encode_s32(i * 4, MetaballSOP._mc_edge_table[i])
	_edge_table_buf = ctx.rd.storage_buffer_create(edge_bytes.size(), edge_bytes)

	# Tri table: 256 rows × 16 ints = 4096 ints (padded to 16, -1 terminated)
	var tri_bytes := PackedByteArray()
	tri_bytes.resize(256 * 16 * 4)
	tri_bytes.fill(0)
	for i in range(256):
		var row: PackedInt32Array = MetaballSOP._mc_tri_table[i]
		for j in range(row.size()):
			tri_bytes.encode_s32((i * 16 + j) * 4, row[j])
		# Fill remaining with -1
		for j in range(row.size(), 16):
			tri_bytes.encode_s32((i * 16 + j) * 4, -1)
	_tri_table_buf = ctx.rd.storage_buffer_create(tri_bytes.size(), tri_bytes)

	_tables_uploaded = true


func _realloc_buffers(ctx: GNGpuContext, max_tris: int) -> void:
	if _vertex_buf.is_valid():
		ctx.free_rid(_vertex_buf)
	if _counter_buf.is_valid():
		ctx.free_rid(_counter_buf)

	_vertex_buf = ctx.create_buffer(max_tris * BYTES_PER_TRI)
	_counter_buf = ctx.create_buffer(4)
	_last_max_tris = max_tris


# ═══════════════════════════════════════════════════════════════════════════════
# CPU Fallback March Cell (simplified from MarchingCubesVOL)
# ═══════════════════════════════════════════════════════════════════════════════

func _march_cell_cpu(ix: int, iy: int, iz: int, gx: int, gy: int,
		field: PackedFloat32Array, threshold: float,
		origin: Vector3, cell_size: Vector3,
		out_verts: PackedVector3Array, out_norms: PackedVector3Array) -> void:

	var offsets: Array[Vector3i] = [
		Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(1,1,0), Vector3i(0,1,0),
		Vector3i(0,0,1), Vector3i(1,0,1), Vector3i(1,1,1), Vector3i(0,1,1)]

	var corners: Array[Vector3] = []
	var values := PackedFloat32Array()
	corners.resize(8)
	values.resize(8)
	var cube_idx: int = 0
	for ci in range(8):
		var ox: int = ix + offsets[ci].x
		var oy: int = iy + offsets[ci].y
		var oz: int = iz + offsets[ci].z
		corners[ci] = origin + Vector3(ox * cell_size.x, oy * cell_size.y, oz * cell_size.z)
		values[ci] = field[oz * gy * gx + oy * gx + ox]
		if values[ci] >= threshold:
			cube_idx |= (1 << ci)

	if cube_idx == 0 or cube_idx == 255:
		return

	var edge_flags: int = MetaballSOP._mc_edge_table[cube_idx]
	var edge_verts: Array[Vector3] = []
	edge_verts.resize(12)
	var edge_pairs: Array[Vector2i] = [
		Vector2i(0,1), Vector2i(1,2), Vector2i(2,3), Vector2i(3,0),
		Vector2i(4,5), Vector2i(5,6), Vector2i(6,7), Vector2i(7,4),
		Vector2i(0,4), Vector2i(1,5), Vector2i(2,6), Vector2i(3,7)]

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
		var n: Vector3 = (v1 - v0).cross(v2 - v0).normalized()
		out_verts.append(v0)
		out_verts.append(v1)
		out_verts.append(v2)
		out_norms.append(n)
		out_norms.append(n)
		out_norms.append(n)
		ti += 3
