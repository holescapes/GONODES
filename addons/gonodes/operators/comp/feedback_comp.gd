class_name FeedbackCOMP
extends GNCompBase
## Outputs the previous frame's 3D scene node for temporal feedback loops.
## Stores a snapshot of the input COMP's transform each frame.
## Enables 3D feedback effects like motion trails and temporal accumulation.

var _prev_transform: Transform3D = Transform3D.IDENTITY
var _feedback_node: Node3D = null
var _has_prev: bool = false


func _init() -> void:
	node_type = "feedback"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.COMP, false, "Current frame scene input", "In")
	add_output("out", GNFamily.Type.COMP, "Previous frame's scene data", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("reset", false,
		"Reset", "Reset stored transform to identity"))
	add_parameter(GNParameter.create_float("blend", 1.0, 0.0, 1.0, 0.01,
		"Blend", "Blend between current and stored transform"))


func _cook(inputs: Array[GNData]) -> GNData:
	var do_reset: bool = get_param_value("reset")
	var blend: float = get_param_value("blend")

	if do_reset:
		_prev_transform = Transform3D.IDENTITY
		_has_prev = false

	# Create feedback scene node if needed
	if _feedback_node == null:
		_feedback_node = Node3D.new()
		_feedback_node.name = id + "_feedback"
		_scene_node = _feedback_node

	# Output the stored previous transform
	if _has_prev:
		_feedback_node.transform = _prev_transform
	else:
		_feedback_node.transform = Transform3D.IDENTITY

	# Store current input's transform for next frame
	var in_data := inputs[0] as GNCompData if inputs.size() > 0 and inputs[0] is GNCompData else null
	if in_data != null and in_data.scene_node != null:
		var current_t: Transform3D = in_data.scene_node.transform
		if blend < 0.999:
			_prev_transform = _prev_transform.interpolate_with(current_t, blend)
		else:
			_prev_transform = current_t
		_has_prev = true

	return _build_comp_data()


func destroy_scene_node() -> void:
	super.destroy_scene_node()
	_feedback_node = null
	_has_prev = false
