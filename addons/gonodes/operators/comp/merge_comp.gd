class_name MergeCOMP
extends GNCompBase
## Merges multiple COMP inputs into a single scene group.
##
## Creates a Node3D parent that contains all input COMP scene nodes as children.
## Supports group-level transform, visibility, and hierarchical nesting.
## RenderTOP adopts the group node, bringing all children into the viewport.
##
## Use cases:
##   • Combine GeometryCOMPs with different materials into one scene object
##   • Apply a group transform (e.g., rotate entire assembly)
##   • Nest MergeCOMPs for hierarchical scene graphs

var _group_node: Node3D = null

## Track which child nodes we've adopted so we can clean up properly.
var _managed_children: Array[Node3D] = []


func _init() -> void:
	node_type = "merge"


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.COMP, "comp", "COMP Input")
	add_output("out", GNFamily.Type.COMP, "Merged scene group")


func _init_parameters() -> void:
	# Group transform
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", "Group X position"))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", "Group Y position"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", "Group Z position"))
	add_parameter(GNParameter.create_float("rx", 0.0, null, null, 0.1, "Rotate X", "Group rotation X (degrees)"))
	add_parameter(GNParameter.create_float("ry", 0.0, null, null, 0.1, "Rotate Y", "Group rotation Y (degrees)"))
	add_parameter(GNParameter.create_float("rz", 0.0, null, null, 0.1, "Rotate Z", "Group rotation Z (degrees)"))
	add_parameter(GNParameter.create_float("sx", 1.0, null, null, 0.01, "Scale X", "Group scale X"))
	add_parameter(GNParameter.create_float("sy", 1.0, null, null, 0.01, "Scale Y", "Group scale Y"))
	add_parameter(GNParameter.create_float("sz", 1.0, null, null, 0.01, "Scale Z", "Group scale Z"))
	add_parameter(GNParameter.create_bool("visible", true, "Visible", "Show or hide the entire group"))


func _cook(_inputs: Array[GNData]) -> GNData:
	# Create group Node3D if needed
	if _group_node == null:
		_group_node = Node3D.new()
		_group_node.name = id + "_group"
		_scene_node = _group_node

	# Update group transform
	_group_node.position = Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))
	_group_node.rotation_degrees = Vector3(
		get_param_value("rx"), get_param_value("ry"), get_param_value("rz"))
	_group_node.scale = Vector3(
		get_param_value("sx"), get_param_value("sy"), get_param_value("sz"))
	_group_node.visible = get_param_value("visible")

	# Stable child sync — only add/remove nodes that actually changed.
	# This keeps RigidBody3D / StaticBody3D in the tree so the physics
	# engine preserves velocity, contacts, and accumulated state.
	_sync_children_from_network()

	return _build_comp_data()


## Detaches children first (they belong to their own COMPs), then
## destroys the group node so the next cook rebuilds the merge tree.
func destroy_scene_node() -> void:
	_release_children()
	super.destroy_scene_node()
	_group_node = null
	_managed_children.clear()


## Returns the group Node3D.  RenderTOP adopts this into its SubViewport,
## which brings all children along automatically.
func get_group_node() -> Node3D:
	return _group_node


func render_for_viewer(viewer, port_index: int = 0) -> void:
	var entries: Array = []
	for child in _managed_children:
		if not is_instance_valid(child):
			continue
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi.mesh != null and mi.mesh is ArrayMesh:
				entries.append({"mesh": mi.mesh, "material": mi.material_override, "transform": mi.transform})
		elif child is MultiMeshInstance3D:
			var mmi: MultiMeshInstance3D = child as MultiMeshInstance3D
			if mmi.multimesh != null and mmi.multimesh.mesh != null and mmi.multimesh.mesh is ArrayMesh:
				entries.append({"mesh": mmi.multimesh.mesh, "material": mmi.material_override, "transform": Transform3D.IDENTITY})

	if entries.size() > 0:
		GNGeoRenderer._ensure_viewer_scene()
		var vp: SubViewport = viewer.get_3d_viewport()
		GNGeoRenderer._reparent_viewer_nodes(vp)
		# Primary mesh
		GNGeoRenderer._viewer_mesh_instance.mesh = entries[0]["mesh"]
		GNGeoRenderer._viewer_mesh_instance.material_override = entries[0]["material"]
		# Extra meshes
		var extra_mis: Array[MeshInstance3D] = []
		for i in range(1, entries.size()):
			var mi := MeshInstance3D.new()
			mi.mesh = entries[i]["mesh"]
			mi.material_override = entries[i]["material"]
			mi.transform = entries[i]["transform"]
			vp.add_child(mi)
			extra_mis.append(mi)
		GNViewerRenderHelpers.apply_orbit_camera(GNGeoRenderer._viewer_camera, 45.0, -30.0, 5.0)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewer.set_info_bar("MergeCOMP")
		# Clean up extra meshes
		for mi in extra_mis:
			mi.queue_free()
		var child_count: int = _managed_children.size()
		var mesh_count: int = entries.size()
		var vis: String = "visible" if _group_node != null and _group_node.visible else "hidden"
		viewer.set_info_overlay("%d children, %d meshes\n%s" % [child_count, mesh_count, vis])
		return

	var child_count: int = _managed_children.size()
	var vis: String = "visible" if _group_node != null and _group_node.visible else "hidden"
	viewer.set_info("Merge Group — %d children\n%s" % [child_count, vis], "MergeCOMP")



## Populates the group node with children from upstream COMP connections.
## Uses a stable diff so nodes that haven't changed stay parented — critical
## for physics bodies that must remain in the scene tree to keep simulating.
func _sync_children_from_network() -> void:
	if _group_node == null:
		return

	# Build the expected child list from current connections (sorted by port)
	var expected: Array[Node3D] = []
	for upstream in get_input_nodes_sorted():
		var scene_nd: Node3D = null
		if upstream is GNCompBase:
			scene_nd = (upstream as GNCompBase).get_scene_node()
		else:
			var comp_data := upstream.cached_output as GNCompData
			if comp_data != null:
				scene_nd = comp_data.scene_node
		if scene_nd != null:
			expected.append(scene_nd)

	# Remove managed children that are no longer in the expected set
	for old_child in _managed_children:
		if old_child != null and is_instance_valid(old_child) and not expected.has(old_child):
			if old_child.get_parent() == _group_node:
				_group_node.remove_child(old_child)

	# Adopt expected children that aren't already in the group
	_managed_children.clear()
	for child in expected:
		if child.get_parent() != _group_node:
			if child.get_parent() != null:
				child.get_parent().remove_child(child)
			_group_node.add_child(child)
		_managed_children.append(child)


## Releases all children back out of the group (detach without freeing).
func _release_children() -> void:
	for child in _managed_children:
		if child != null and is_instance_valid(child) and child.get_parent() == _group_node:
			_group_node.remove_child(child)
	_managed_children.clear()
