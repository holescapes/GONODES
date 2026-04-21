class_name AudioListenerCOMP
extends GNCompBase
## Wraps Godot's AudioListener3D for positional audio in 3D scenes.
## Place in a scene via RenderTOP to enable spatial audio reception.
## Pairs with AudioSourceCOMP for full 3D audio spatialization.

var _listener: AudioListener3D = null


func _init() -> void:
	node_type = "audiolistener"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.COMP, "Audio listener component")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01,
		"Translate X", "Listener X position"))
	add_parameter(GNParameter.create_float("ty", 1.0, null, null, 0.01,
		"Translate Y", "Listener Y position"))
	add_parameter(GNParameter.create_float("tz", 3.0, null, null, 0.01,
		"Translate Z", "Listener Z position"))
	add_parameter(GNParameter.create_float("rx", 0.0, null, null, 0.1,
		"Rotate X", "Listener pitch (degrees)"))
	add_parameter(GNParameter.create_float("ry", 0.0, null, null, 0.1,
		"Rotate Y", "Listener yaw (degrees)"))
	add_parameter(GNParameter.create_float("rz", 0.0, null, null, 0.1,
		"Rotate Z", "Listener roll (degrees)"))
	add_parameter(GNParameter.create_bool("current", true,
		"Current", "Make this the active audio listener"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _listener == null:
		_listener = AudioListener3D.new()
		_listener.name = id + "_listener"
		_scene_node = _listener

	_listener.position = Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))
	_listener.rotation_degrees = Vector3(
		get_param_value("rx"), get_param_value("ry"), get_param_value("rz"))

	var is_current: bool = get_param_value("current")
	if is_current and _listener.is_inside_tree():
		_listener.make_current()

	return _build_comp_data()


func destroy_scene_node() -> void:
	super.destroy_scene_node()
	_listener = null
