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
	node_type = "merge_comp"
	node_description = "Merge multiple COMPs into a scene group."


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.COMP, "comp", "COMP Input")
	add_output("out", GNFamily.Type.COMP, "Merged scene group")


func _init_parameters() -> void:
	# Group transform
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", "Group X position"))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", "Group Y position"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", "Group Z position"))
	add_parameter(GNParameter.create_float("rx", 0.0, -360.0, 360.0, 0.1, "Rotate X", "Group rotation X (degrees)"))
	add_parameter(GNParameter.create_float("ry", 0.0, -360.0, 360.0, 0.1, "Rotate Y", "Group rotation Y (degrees)"))
	add_parameter(GNParameter.create_float("rz", 0.0, -360.0, 360.0, 0.1, "Rotate Z", "Group rotation Z (degrees)"))
	add_parameter(GNParameter.create_float("sx", 1.0, 0.001, 100.0, 0.01, "Scale X", "Group scale X"))
	add_parameter(GNParameter.create_float("sy", 1.0, 0.001, 100.0, 0.01, "Scale Y", "Group scale Y"))
	add_parameter(GNParameter.create_float("sz", 1.0, 0.001, 100.0, 0.01, "Scale Z", "Group scale Z"))
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

	# Detach previously managed children so we can re-adopt from fresh input list
	_release_children()

	# Collect scene nodes from connected COMP inputs via the network
	_populate_from_network()

	return null  # RenderTOP reads scene nodes via get_scene_node() / get_children()


## Returns the group Node3D.  RenderTOP adopts this into its SubViewport,
## which brings all children along automatically.
func get_group_node() -> Node3D:
	return _group_node


## Populates the group node with children from upstream COMP connections.
## Walks the network to find connected COMP nodes and reparents their scene nodes.
## Children are ordered by input port index (port 0 = first child, port 1 = second, …),
## giving the user deterministic control over the scene hierarchy via port wiring.
func _populate_from_network() -> void:
	if _group_node == null:
		return

	var engine: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if engine == null or engine.network == null:
		return

	var network: GNNetwork = engine.network

	# Get connections sorted by input port index (determines hierarchy order)
	var conns: Array = network.get_input_connections(id).duplicate()
	conns.sort_custom(func(a: GNConnection, b: GNConnection) -> bool:
		return a.to_port < b.to_port)

	for conn in conns:
		var upstream: GNNode = network.nodes.get(conn.from_node, null)
		if upstream == null or not (upstream is GNCompBase):
			continue
		var comp: GNCompBase = upstream as GNCompBase
		var scene_nd: Node3D = comp.get_scene_node()
		if scene_nd == null:
			continue

		# Reparent into our group
		if scene_nd.get_parent() != _group_node:
			if scene_nd.get_parent() != null:
				scene_nd.get_parent().remove_child(scene_nd)
			_group_node.add_child(scene_nd)
			_managed_children.append(scene_nd)


## Releases all children back out of the group (detach without freeing).
func _release_children() -> void:
	for child in _managed_children:
		if child != null and is_instance_valid(child) and child.get_parent() == _group_node:
			_group_node.remove_child(child)
	_managed_children.clear()
