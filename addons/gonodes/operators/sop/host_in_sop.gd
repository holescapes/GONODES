class_name HostInSOP
extends GNSopBase
## Receives geometry data from the host application via the LibGodot C API.
##
## The host calls gonodes_set_input_geometry() or gonodes_set_input_geometry_direct()
## to push mesh data (positions, normals, UVs, colors, indices).
## GNEmbeddedHost flushes the data into this node via _set_host_geometry()
## or _set_host_geometry_direct().
##
## Usage: Place in a patch, set the node ID, and wire output to downstream SOPs.
## The host references this node by its ID string.

## Host-provided geometry arrays (from temp file / env-var path).
var _host_arrays: Array = []
var _host_dirty: bool = false

## Direct zero-copy path: raw attribute arrays from pointer lending.
var _host_direct_positions: PackedVector3Array = PackedVector3Array()
var _host_direct_normals: PackedVector3Array = PackedVector3Array()
var _host_direct_uvs: PackedVector2Array = PackedVector2Array()
var _host_direct_colors: PackedColorArray = PackedColorArray()
var _host_direct_indices: PackedInt32Array = PackedInt32Array()
var _host_direct_dirty: bool = false


func _init() -> void:
	node_type = "host_in_sop"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Geometry received from host")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "", "Label",
		"Optional label for this input in the host's UI"))


## Called by GNEmbeddedHost._flush_inputs() with Godot mesh arrays.
func _set_host_geometry(arrays: Array) -> void:
	_host_arrays = arrays
	_host_dirty = true
	mark_dirty()


## Called by GNEmbeddedHost._flush_inputs() with direct attribute arrays.
## Zero-copy: arrays are used directly from the host's staged pointers;
## no temp files, no JSON serialization.
func _set_host_geometry_direct(positions: PackedVector3Array,
		normals: PackedVector3Array, uvs: PackedVector2Array,
		colors: PackedColorArray, indices: PackedInt32Array) -> void:
	_host_direct_positions = positions
	_host_direct_normals = normals
	_host_direct_uvs = uvs
	_host_direct_colors = colors
	_host_direct_indices = indices
	_host_direct_dirty = true
	_host_dirty = false  # Direct path supersedes file path
	mark_dirty()


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	# Direct zero-copy path.
	if _host_direct_dirty and not _host_direct_positions.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _host_direct_positions
		if not _host_direct_normals.is_empty():
			arrays[Mesh.ARRAY_NORMAL] = _host_direct_normals
		if not _host_direct_uvs.is_empty():
			arrays[Mesh.ARRAY_TEX_UV] = _host_direct_uvs
		if not _host_direct_colors.is_empty():
			arrays[Mesh.ARRAY_COLOR] = _host_direct_colors
		if not _host_direct_indices.is_empty():
			arrays[Mesh.ARRAY_INDEX] = _host_direct_indices
		_cached_geo.set_surface_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_host_direct_dirty = false
		return _cached_geo

	# Temp-file path (legacy): host provided pre-built Godot arrays.
	if not _host_arrays.is_empty():
		_cached_geo.set_surface_arrays(Mesh.PRIMITIVE_TRIANGLES, _host_arrays)
		_host_dirty = false
		return _cached_geo

	return null
