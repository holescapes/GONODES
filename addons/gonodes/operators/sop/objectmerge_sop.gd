class_name ObjectMergeSOP
extends GNSopBase
## Fetch geometry from another SOP node by reference path.
##
## Equivalent to duplicating a wire without connecting — useful for
## pulling geometry from distant parts of the network. The source
## node cooks normally; this operator reads its cached output.
##
## TouchDesigner equivalent: Object Merge SOP.


func _init() -> void:
	node_type = "sop"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Referenced geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("sop_path", GNFamily.Type.SOP,
		"SOP Path", "Node ID of the SOP to fetch geometry from"))
	add_parameter(GNParameter.create_bool("apply_transform", false,
		"Apply Transform", "Apply the source node's transform to the geometry"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var sop_path: String = get_param_value("sop_path")
	var eng: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if sop_path.is_empty() or eng == null or eng.network == null:
		return null

	var ref_node: GNNode = eng.network.nodes.get(sop_path, null)
	if ref_node == null:
		return null

	var ref_geo := ref_node.cached_output as GNGeoData
	if ref_geo == null or not ref_geo.has_geometry():
		return null

	var apply_xform: bool = get_param_value("apply_transform")

	if not apply_xform:
		return ref_geo

	# Duplicate and apply transform
	var out_geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()
	var xform := ref_geo.transform

	for surf_idx in range(ref_geo.mesh.get_surface_count()):
		var arrays := ref_geo.mesh.surface_get_arrays(surf_idx)
		var prim := ref_geo.mesh.surface_get_primitive_type(surf_idx)

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.size() > 0:
			var transformed := PackedVector3Array()
			transformed.resize(verts.size())
			for i in range(verts.size()):
				transformed[i] = xform * verts[i]
			arrays[Mesh.ARRAY_VERTEX] = transformed

		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var normal_basis := xform.basis.inverse().transposed()
			var transformed_n := PackedVector3Array()
			transformed_n.resize(normals.size())
			for i in range(normals.size()):
				transformed_n[i] = (normal_basis * normals[i]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = transformed_n

		new_mesh.add_surface_from_arrays(prim, arrays)

	out_geo.set_mesh(new_mesh)
	return out_geo
