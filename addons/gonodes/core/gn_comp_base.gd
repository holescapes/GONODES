class_name GNCompBase
extends GNNode
## Base class for all COMP (Component) family operators.
##
## Provides:
##   • family = GNFamily.Type.COMP set automatically
##   • Default output port "out" of type COMP
##   • Automatic cleanup of reparented scene nodes via _notification(PREDELETE)
##   • Typed scene node accessor pattern via _scene_node
##   • Inline label preview (create_preview_control / update_preview_control)

# ─── Shared COMP Infrastructure ────────────────────────────────────────────────

## The 3D scene node managed by this COMP (MeshInstance3D, Camera3D, Light3D, etc.).
## Subclasses create and assign their concrete node type to this variable.
## Automatically freed on node removal via _notification(PREDELETE).
var _scene_node: Node3D = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.COMP


## Ensures family is set even when subclass _init() doesn't call super().
func initialize(p_id: String) -> void:
	family = GNFamily.Type.COMP
	super.initialize(p_id)


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


## Destroys the runtime scene node and resets this COMP to its pre-first-cook
## state.  The next cook will lazily recreate everything via _ensure_body() /
## lazy init.  Override in subclasses to nil out additional internal state.
func destroy_scene_node() -> void:
	if _scene_node != null:
		if _scene_node.get_parent() != null:
			_scene_node.get_parent().remove_child(_scene_node)
		_scene_node.queue_free()
		_scene_node = null


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


func display_in_viewer(viewer) -> void:
	# COMPs pass through their input data (e.g. GNGeoData from SOP input).
	# Route by output data type so the viewer shows the right visualization.
	if cached_output is GNGeoData:
		viewer.show_3d_mesh(cached_output as GNGeoData)
		return
	if cached_output is GNTextureData:
		var td: GNTextureData = cached_output as GNTextureData
		if td.texture:
			viewer.show_texture(td.texture,
				"%dx%d" % [td.resolution.x, td.resolution.y])
			viewer.update_zoom_label()
			return
	if cached_output != null:
		viewer.show_info(cached_output.get_preview_text(), "")
		return
	viewer.show_info("COMP: %s" % node_type, "Component operator")
