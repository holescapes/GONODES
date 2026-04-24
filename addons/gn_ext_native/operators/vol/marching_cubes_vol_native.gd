class_name MarchingCubesVOLNative
extends GNVolBase
## Native-accelerated marching cubes — delegates to GNNativeMarchingCubesVol (C++).
## Reads volume to CPU, passes to C++ for iso-surface extraction.

var _processor: RefCounted = null


func _init() -> void:
	super._init()
	node_type = "marchingcubes_native"
	node_description = "Extract iso-surface mesh from volume (marching cubes) — native C++ accelerated."
	if ClassDB.class_exists("GNNativeMarchingCubesVol"):
		_processor = ClassDB.instantiate("GNNativeMarchingCubesVol")


func _init_ports() -> void:
	add_input("vol", GNFamily.Type.VOL, true, "Density volume to mesh")
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

	var res: Vector3i = vol.resolution
	var threshold: float = get_param_value("threshold")
	var smooth: bool = get_param_value("smooth_normals")

	# GPU → CPU readback
	var raw: PackedByteArray = vol.read_full()
	if raw.is_empty():
		return null

	# Decode float field
	var bpv: int = vol.bytes_per_voxel()
	var total: int = res.x * res.y * res.z
	var field := PackedFloat32Array()
	field.resize(total)
	for i in range(total):
		field[i] = raw.decode_float(i * bpv)

	if not _processor:
		return null

	var result: Dictionary = _processor.process(field, res.x, res.y, res.z,
		threshold, smooth, vol.bounds.position, vol.bounds.size)

	var verts: PackedVector3Array = result.get("positions", PackedVector3Array())
	var normals: PackedVector3Array = result.get("normals", PackedVector3Array())
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
