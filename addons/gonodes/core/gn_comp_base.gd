class_name GNCompBase
extends GNNode
## Base class for all COMP (Component) family operators.
##
## Provides:
##   • family = GNFamily.Type.COMP set automatically
##   • Default output port "out" of type COMP
##   • GNCompData output via _build_comp_data() wrapping _scene_node
##   • Automatic cleanup of reparented scene nodes via _notification(PREDELETE)
##   • Typed scene node accessor pattern via _scene_node
##   • Inline label preview (create_preview_control / update_preview_control)

# ─── Shared COMP Infrastructure ────────────────────────────────────────────────

## The 3D scene node managed by this COMP (MeshInstance3D, Camera3D, Light3D, etc.).
## Subclasses create and assign their concrete node type to this variable.
## Automatically freed on node removal via _notification(PREDELETE).
var _scene_node: Node3D = null

## Cached GNCompData wrapping _scene_node.  Built via _build_comp_data().
var _cached_comp_data: GNCompData = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.COMP


## Ensures family is set even when subclass _init() doesn't call super().
func initialize(p_id: String) -> void:
	family = GNFamily.Type.COMP
	super.initialize(p_id)


func _is_family_data(data: GNData) -> bool:
	# COMP wires carry GNCompData but also pass through upstream data
	# (GNGeoData from GeometryCOMP, GNTextureData from tunnels, etc.).
	# Accept any non-null data so Switch/Null routing works for all cases.
	return data != null


## Default output port.  Override in subclass to add inputs or extra outputs.
func _init_ports() -> void:
	add_output("out", GNFamily.Type.COMP, "Component output")


## Automatic cleanup: if this node's scene node was reparented into another
## viewport (e.g. RenderTOP's SubViewport), we must remove and free it manually
## because it's not a direct child of this GNNode.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _scene_node != null and _scene_node.get_parent() != null:
			_scene_node.get_parent().remove_child(_scene_node)
			_scene_node.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Input Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Safely extracts a GNCompData from the inputs array at [param port].
## Returns null if the port doesn't exist or the data is not GNCompData.
func _get_input_comp(inputs: Array[GNData], port: int = 0) -> GNCompData:
	if port < inputs.size() and inputs[port] is GNCompData:
		return inputs[port] as GNCompData
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Scene Node Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the managed 3D scene node.  Subclasses typically provide a typed
## accessor (get_mesh_instance, get_camera, get_light) that casts this.
func get_scene_node() -> Node3D:
	return _scene_node


## Builds GNCompData wrapping the current _scene_node.  Call from _cook() in
## subclasses that own a scene node: `return _build_comp_data()`.
## Returns a valid GNCompData even when _scene_node is null (valid=false).
func _build_comp_data() -> GNCompData:
	if _cached_comp_data == null:
		_cached_comp_data = GNCompData.new()
	_cached_comp_data.scene_node = _scene_node
	_cached_comp_data.scene_label = _scene_node.get_class() if _scene_node != null else ""
	_cached_comp_data.valid = _scene_node != null
	_cached_comp_data.timestamp = Engine.get_process_frames()
	return _cached_comp_data


## Destroys the runtime scene node and resets this COMP to its pre-first-cook
## state.  The next cook will lazily recreate everything via _ensure_body() /
## lazy init.  Override in subclasses to nil out additional internal state.
func destroy_scene_node() -> void:
	if _scene_node != null:
		if _scene_node.get_parent() != null:
			_scene_node.get_parent().remove_child(_scene_node)
		_scene_node.queue_free()
		_scene_node = null


## Walks upstream through pass-through COMPs (NullCOMP, SwitchCOMP,
## AnimationCOMP, etc.) to find the actual scene node.  Cycle-safe.
## Uses data-type checking (cached_output as GNCompData) — works for any
## node type (GNCompBase, SubNetworkNode, GNCustomOperator, etc.).
static func resolve_scene_node_upstream(node: GNNode, net: GNNetwork) -> Node3D:
	return _resolve_scene_node_r(node, net, {})


static func _resolve_scene_node_r(node: GNNode, net: GNNetwork,
		visited: Dictionary) -> Node3D:
	if visited.has(node.id):
		return null
	visited[node.id] = true
	var comp_data := node.cached_output as GNCompData
	if comp_data != null and comp_data.scene_node != null:
		return comp_data.scene_node
	# GeometryCOMP passes the SOP mesh through as GNGeoData and keeps the
	# MeshInstance3D on the operator. That node is what RenderTOP adopts.
	if node is GNCompBase:
		var owned: Node3D = (node as GNCompBase).get_scene_node()
		if owned != null:
			return owned
	var found_wire := false
	for conn in net.get_input_connections(node.id):
		found_wire = true
		var upstream: GNNode = net.nodes.get(conn.from_node, null)
		if upstream != null:
			var resolved: Node3D = _resolve_scene_node_r(upstream, net, visited)
			if resolved != null:
				return resolved
	# SelectCOMP has no wire. Follow its remote COMP reference.
	if not found_wire:
		for ref_id in node.get_remote_dependencies():
			var remote: GNNode = net.nodes.get(ref_id, null)
			if remote != null and remote.family == GNFamily.Type.COMP:
				var remote_scene: Node3D = _resolve_scene_node_r(remote, net, visited)
				if remote_scene != null:
					return remote_scene
	return null



## Instance convenience: resolves the scene node from an upstream input port.
## Uses [method resolve_scene_node_upstream], so a GeometryCOMP mesh is found
## even when that operator returns GNGeoData instead of GNCompData.
func _get_upstream_scene_node(port: int) -> Node3D:
	var upstream := get_input_node(port)
	if upstream == null:
		return null
	var net: GNNetwork = null
	var parent := get_parent()
	if parent is GNCookEngine:
		net = (parent as GNCookEngine).network
	if net != null:
		return resolve_scene_node_upstream(upstream, net)
	var comp_data := upstream.cached_output as GNCompData
	if comp_data != null and comp_data.scene_node != null:
		return comp_data.scene_node
	if upstream is GNCompBase:
		return (upstream as GNCompBase).get_scene_node()
	return null


## Instance convenience: resolves the MeshInstance3D from an upstream input port.
## Searches the scene node itself and its direct children.
func _resolve_upstream_mesh() -> MeshInstance3D:
	var scene_nd: Node3D = _get_upstream_scene_node(0)
	if scene_nd == null:
		return null
	if scene_nd is MeshInstance3D:
		return scene_nd as MeshInstance3D
	for child in scene_nd.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Preview
# ═══════════════════════════════════════════════════════════════════════════════

## Updates the component preview with scene node info.
func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		if _scene_node != null:
			var vis: String = "visible" if _scene_node.visible else "hidden"
			label.text = "%s\n%s" % [_scene_node.get_class(), vis]
		else:
			label.text = "no node"


func render_for_preview(host) -> void:
	if _scene_node != null:
		var vis: String = "visible" if _scene_node.visible else "hidden"
		host.set_text("%s\n%s" % [_scene_node.get_class(), vis])
	else:
		host.set_text("no node")


# ═══════════════════════════════════════════════════════════════════════════════
# Export — Scene node export (COMPs export their 3D scene tree, not GNData)
# ═══════════════════════════════════════════════════════════════════════════════

func can_export_output() -> bool:
	if _scene_node != null:
		return true
	return super.can_export_output()


func get_exportable_outputs() -> Array[Dictionary]:
	var result := super.get_exportable_outputs()
	# Inject scene-node GLB export if we have a 3D scene and it's not already
	# covered by a data port (COMPs may have both scene + data outputs).
	if _scene_node != null:
		result.insert(0, { "port": -1, "label": "Scene (GLB)",
			"filters": [{"filter": "*.glb", "description": "glTF Binary (scene graph)"}] })
	return result


func get_export_filters(port_index: int = -1) -> Array[Dictionary]:
	if port_index == -1 and _scene_node != null:
		return [{"filter": "*.glb", "description": "glTF Binary (scene graph)"}]
	return super.get_export_filters(port_index)


func export_output(path: String, port_index: int = -1) -> Error:
	if port_index == -1 and _scene_node != null:
		return _export_scene_to_glb(path)
	if port_index >= 0:
		return super.export_output(path, port_index)
	# Legacy default: scene first, then data
	if _scene_node != null:
		return _export_scene_to_glb(path)
	return super.export_output(path, port_index)


func _export_scene_to_glb(path: String) -> Error:
	var clone: Node3D = _scene_node.duplicate()
	var tmp_root := Node3D.new()
	tmp_root.name = "ExportRoot"
	tmp_root.add_child(clone)
	_set_owner_recursive(clone, tmp_root)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(tmp_root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, path)
	tmp_root.remove_child(clone)
	clone.queue_free()
	tmp_root.free()
	return err


static func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)
