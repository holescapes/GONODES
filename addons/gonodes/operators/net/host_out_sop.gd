class_name HostOutSOP
extends GNOutBase
## Exports geometry data to the host application via the LibGodot C API.
##
## Takes a SOP input and makes its mesh data available to the host
## through gonodes_get_output_geometry().  GNEmbeddedHost._collect_outputs()
## calls _get_host_geometry() each frame to publish the data.

## Cached geometry arrays for the host.
var _output_positions: PackedFloat32Array = PackedFloat32Array()
var _output_normals: PackedFloat32Array = PackedFloat32Array()
var _output_uvs: PackedFloat32Array = PackedFloat32Array()
var _output_colors: PackedFloat32Array = PackedFloat32Array()
var _output_indices: PackedInt32Array = PackedInt32Array()
var _output_vertex_count: int = 0


func _init() -> void:
	node_type = "host_out_sop"
	family = GNFamily.Type.NET
	is_sink = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Geometry to export to host")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "", "Label",
		"Optional label for this output in the host's UI"))


func _cook(inputs: Array[GNData]) -> GNData:
	_output_positions = PackedFloat32Array()
	_output_normals = PackedFloat32Array()
	_output_uvs = PackedFloat32Array()
	_output_colors = PackedFloat32Array()
	_output_indices = PackedInt32Array()
	_output_vertex_count = 0

	if inputs.is_empty() or inputs[0] == null:
		return null

	var geo_in: GNGeoData = inputs[0] as GNGeoData if inputs[0] is GNGeoData else null
	if geo_in == null or not geo_in.has_geometry():
		return null

	var arrays: Array = geo_in.get_surface_arrays(0)
	if arrays.is_empty():
		return null

	# Positions → flat xyz
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays[Mesh.ARRAY_VERTEX] != null else PackedVector3Array()
	_output_vertex_count = positions.size()
	_output_positions.resize(_output_vertex_count * 3)
	for i in range(_output_vertex_count):
		_output_positions[i * 3] = positions[i].x
		_output_positions[i * 3 + 1] = positions[i].y
		_output_positions[i * 3 + 2] = positions[i].z

	# Normals → flat xyz
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays.size() > Mesh.ARRAY_NORMAL and arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	if not normals.is_empty():
		_output_normals.resize(normals.size() * 3)
		for i in range(normals.size()):
			_output_normals[i * 3] = normals[i].x
			_output_normals[i * 3 + 1] = normals[i].y
			_output_normals[i * 3 + 2] = normals[i].z

	# UVs → flat uv
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays.size() > Mesh.ARRAY_TEX_UV and arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	if not uvs.is_empty():
		_output_uvs.resize(uvs.size() * 2)
		for i in range(uvs.size()):
			_output_uvs[i * 2] = uvs[i].x
			_output_uvs[i * 2 + 1] = uvs[i].y

	# Colors → flat rgba
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays.size() > Mesh.ARRAY_COLOR and arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	if not colors.is_empty():
		_output_colors.resize(colors.size() * 4)
		for i in range(colors.size()):
			_output_colors[i * 4] = colors[i].r
			_output_colors[i * 4 + 1] = colors[i].g
			_output_colors[i * 4 + 2] = colors[i].b
			_output_colors[i * 4 + 3] = colors[i].a

	# Indices
	if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
		_output_indices = arrays[Mesh.ARRAY_INDEX]

	return null


## Called by GNEmbeddedHost._collect_outputs() to get geometry data.
func _get_host_geometry() -> Dictionary:
	if _output_vertex_count == 0:
		return {}
	return {
		"positions": _output_positions,
		"normals": _output_normals,
		"uvs": _output_uvs,
		"colors": _output_colors,
		"indices": _output_indices,
		"vertex_count": _output_vertex_count,
	}


func update_preview_control(control: Control) -> void:
	if control is Label:
		if _output_vertex_count > 0:
			(control as Label).text = "→ host %d verts" % _output_vertex_count
		else:
			(control as Label).text = "no input"
