class_name MergeSOP
extends GNSopBase
## Merges multiple SOP inputs into a single mesh.
## Each input's surfaces are appended to the output mesh.


func _init() -> void:
	node_type = "merge"
	node_description = "Merge multiple meshes into one."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, true, "Geometry inputs (multi)")  # multi-input
	add_output("out", GNFamily.Type.SOP, "Merged mesh")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var new_mesh := ArrayMesh.new()
	var has_any: bool = false

	for input in inputs:
		var geo: GNGeoData = input as GNGeoData if input is GNGeoData else null
		if geo == null or not geo.has_geometry():
			continue
		has_any = true
		# Append all surfaces from this input
		for s in range(geo.mesh.get_surface_count()):
			var arrays: Array = geo.mesh.surface_get_arrays(s)
			var prim: Mesh.PrimitiveType = geo.mesh.surface_get_primitive_type(s)
			new_mesh.add_surface_from_arrays(prim, arrays)

	if not has_any:
		return null

	_cached_geo.set_mesh(new_mesh)
	return _cached_geo
