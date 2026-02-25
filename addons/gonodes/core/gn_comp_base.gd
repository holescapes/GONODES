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


# ═══════════════════════════════════════════════════════════════════════════════
# Preview
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a Label preview showing component type and visibility.
func create_preview_control() -> Control:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.text = ""
	return label


## Updates the component preview with scene node info.
func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		if _scene_node != null:
			var vis: String = "visible" if _scene_node.visible else "hidden"
			label.text = "%s\n%s" % [_scene_node.get_class(), vis]
		else:
			label.text = "no node"
