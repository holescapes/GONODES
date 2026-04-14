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
static func resolve_scene_node_upstream(comp: GNCompBase, net: GNNetwork) -> Node3D:
	return _resolve_scene_node_r(comp, net, {})


static func _resolve_scene_node_r(comp: GNCompBase, net: GNNetwork,
		visited: Dictionary) -> Node3D:
	var scene_nd: Node3D = comp.get_scene_node()
	if scene_nd != null:
		return scene_nd
	if visited.has(comp.id):
		return null
	visited[comp.id] = true
	for conn in net.get_input_connections(comp.id):
		var upstream: GNNode = net.nodes.get(conn.from_node, null)
		if upstream is GNCompBase:
			var resolved: Node3D = _resolve_scene_node_r(
				upstream as GNCompBase, net, visited)
			if resolved != null:
				return resolved
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
