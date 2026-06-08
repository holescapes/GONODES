class_name LODCOMP
extends GNCompBase
## Level-of-detail switcher — swaps between multiple geometry COMPs
## based on camera distance.
##
## Connects up to 4 LOD inputs (high → low detail). The node measures
## distance from the camera and selects the appropriate LOD level.
##
## Uses Godot's native VisibilityRange on MeshInstance3D or manual
## selection when VisibilityRange is not applicable.

var _container: Node3D = null
var _last_active_lod: int = -1

## Proxy tree for fan-out — when upstream LOD scene nodes are already
## claimed by another consumer.
var _proxy_tree: GNProxyTree = GNProxyTree.new()

## Maps LOD index to the Node3D actually parented under _container
## (either the original or a proxy).
var _managed_lod_nodes: Array = [null, null, null, null]


func _init() -> void:
	node_type = "lod"


func _init_ports() -> void:
	add_input("lod0", GNFamily.Type.COMP, true, "LOD 0 — highest detail (closest)", "LOD 0")
	add_input("lod1", GNFamily.Type.COMP, false, "LOD 1 — medium detail", "LOD 1")
	add_input("lod2", GNFamily.Type.COMP, false, "LOD 2 — low detail", "LOD 2")
	add_input("lod3", GNFamily.Type.COMP, false, "LOD 3 — lowest detail (farthest)", "LOD 3")
	add_output("out", GNFamily.Type.COMP, "LOD-managed component", "Out")


func _init_parameters() -> void:
	# Transform
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", "Object X position"))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", "Object Y position"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", "Object Z position"))
	# Distance thresholds
	add_parameter(GNParameter.create_float("dist1", 10.0, 0.0, 1000.0, 0.5,
		"LOD 1 Distance", "Switch to LOD 1 beyond this distance"))
	add_parameter(GNParameter.create_float("dist2", 25.0, 0.0, 1000.0, 0.5,
		"LOD 2 Distance", "Switch to LOD 2 beyond this distance"))
	add_parameter(GNParameter.create_float("dist3", 50.0, 0.0, 1000.0, 0.5,
		"LOD 3 Distance", "Switch to LOD 3 beyond this distance"))
	add_parameter(GNParameter.create_float("fade_range", 0.0, 0.0, 10.0, 0.1,
		"Fade Range", "Crossfade range between LOD levels (0 = instant switch)"))
	add_parameter(GNParameter.create_bool("auto_lod", true,
		"Auto LOD", "Automatically select LOD based on camera distance"))
	add_parameter(GNParameter.create_int("forced_lod", 0, 0, 3,
		"Forced LOD", "Manually select LOD level (when Auto LOD is off)"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_container()

	# Collect connected LOD levels
	var lod_nodes: Array[Node3D] = []
	var lod_data: Array = []
	for i in range(4):
		var data = inputs[i] if inputs.size() > i else null
		lod_data.append(data)
		var scene_node := _get_upstream_scene_node(i)
		lod_nodes.append(scene_node)

	if lod_nodes[0] == null:
		node_warning = "LOD 0 (highest detail) not connected"
		return null

	# Adopt or proxy all LOD nodes under our container
	var active_sources: Array[Node3D] = []
	for i in range(4):
		var node := lod_nodes[i]
		if node == null:
			# Remove stale managed node if the LOD was disconnected
			if _managed_lod_nodes[i] != null and is_instance_valid(_managed_lod_nodes[i]):
				if _managed_lod_nodes[i].get_parent() == _container:
					_container.remove_child(_managed_lod_nodes[i])
			_managed_lod_nodes[i] = null
			continue
		active_sources.append(node)
		var child: Node3D = _adopt_or_proxy_lod(node)
		_managed_lod_nodes[i] = child

	# Clean up proxies for sources no longer connected
	var stale: Array[Node3D] = _proxy_tree.cleanup_stale(active_sources)
	for proxy: Node3D in stale:
		if proxy.get_parent() == _container:
			_container.remove_child(proxy)

	# Sync all proxies from their sources
	_proxy_tree.sync_all()

	# Determine active LOD
	var active_lod: int = 0
	if get_param_value("auto_lod"):
		active_lod = _compute_lod_from_camera()
	else:
		active_lod = get_param_value("forced_lod")

	# Clamp to highest available LOD
	while active_lod > 0 and lod_nodes[active_lod] == null:
		active_lod -= 1

	# Show only active LOD, hide others
	for i in range(4):
		if _managed_lod_nodes[i] != null and is_instance_valid(_managed_lod_nodes[i]):
			_managed_lod_nodes[i].visible = (i == active_lod)

	_last_active_lod = active_lod

	# Update container transform
	_container.position = Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))

	node_warning = "LOD %d active" % active_lod
	return lod_data[0]  # Always pass LOD0 data downstream


func _compute_lod_from_camera() -> int:
	# Find the nearest camera in the scene tree
	var cam := _find_camera()
	if cam == null:
		return 0

	var dist := cam.global_position.distance_to(_container.global_position)
	var d1: float = get_param_value("dist1")
	var d2: float = get_param_value("dist2")
	var d3: float = get_param_value("dist3")

	if dist >= d3:
		return 3
	elif dist >= d2:
		return 2
	elif dist >= d1:
		return 1
	return 0


func _find_camera() -> Camera3D:
	# Walk up the tree to find a viewport, then get its camera
	var node: Node = _container
	while node != null:
		if node is SubViewport:
			var vp := node as SubViewport
			# Check for cameras in the viewport
			for child in vp.get_children():
				if child is Camera3D:
					return child as Camera3D
		node = node.get_parent()
	return null


func _ensure_container() -> void:
	if _container != null and is_instance_valid(_container):
		return
	_container = Node3D.new()
	_container.name = id + "_lod"
	_scene_node = _container


## Adopts a source node directly if orphaned, or creates a proxy if the
## source is already claimed by another consumer.
func _adopt_or_proxy_lod(source: Node3D) -> Node3D:
	if source.get_parent() == _container:
		return source
	if _proxy_tree.has_proxy_for(source):
		var proxy: Node3D = _proxy_tree.get_or_create_proxy(source)
		if proxy.get_parent() != _container:
			_container.add_child(proxy)
		return proxy
	if source.get_parent() == null:
		_container.add_child(source)
		return source
	var proxy: Node3D = _proxy_tree.get_or_create_proxy(source)
	if proxy.get_parent() != _container:
		_container.add_child(proxy)
	return proxy


func _on_node_removed() -> void:
	_proxy_tree.release_all()
	_managed_lod_nodes = [null, null, null, null]
	if _container != null and is_instance_valid(_container):
		if _container.get_parent() != null:
			_container.get_parent().remove_child(_container)
		_container.queue_free()
		_container = null
