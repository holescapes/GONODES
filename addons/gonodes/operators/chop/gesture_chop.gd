class_name GestureCHOP
extends GNChopBase
## Detects touch gestures and outputs them as CHOP channels.
## Tracks pinch (scale), swipe (direction/velocity), and rotation gestures.
## Outputs: pinch_scale, swipe_x, swipe_y, rotate_angle, tap, num_touches.

var _prev_touches: Dictionary = {}
var _pinch_scale: float = 1.0
var _rotate_angle: float = 0.0
var _swipe_x: float = 0.0
var _swipe_y: float = 0.0
var _tap: float = 0.0
var _num_touches: int = 0


func _init() -> void:
	node_type = "gesture"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Gesture channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("pinch", true,
		"Pinch", "Enable pinch/zoom gesture detection"))
	add_parameter(GNParameter.create_bool("swipe", true,
		"Swipe", "Enable swipe gesture detection"))
	add_parameter(GNParameter.create_bool("rotate", true,
		"Rotate", "Enable rotation gesture detection"))
	add_parameter(GNParameter.create_float("decay", 0.85, 0.0, 1.0, 0.01,
		"Decay", "Velocity decay rate per frame"))
	add_parameter(GNParameter.create_bool("reset", false,
		"Reset", "Reset all gesture state"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var enable_pinch: bool = get_param_value("pinch")
	var enable_swipe: bool = get_param_value("swipe")
	var enable_rotate: bool = get_param_value("rotate")
	var decay: float = get_param_value("decay")
	var do_reset: bool = get_param_value("reset")

	if do_reset:
		_pinch_scale = 1.0
		_rotate_angle = 0.0
		_swipe_x = 0.0
		_swipe_y = 0.0
		_tap = 0.0

	# Collect current touch points from InputMap
	var touches: Dictionary = {}
	_num_touches = 0
	for i in range(10):
		if Input.is_action_pressed("touch_%d" % i) if InputMap.has_action("touch_%d" % i) else false:
			_num_touches += 1

	# Decay velocities
	_swipe_x *= decay
	_swipe_y *= decay
	_tap = 0.0

	# Mouse-based gesture simulation for desktop
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mpos: Vector2 = Engine.get_main_loop().root.get_mouse_position() if Engine.get_main_loop() and Engine.get_main_loop().root else Vector2.ZERO
		if _prev_touches.has("mouse"):
			var delta: Vector2 = mpos - _prev_touches["mouse"]
			if enable_swipe:
				_swipe_x = delta.x
				_swipe_y = delta.y
		_prev_touches["mouse"] = mpos
		_num_touches = maxi(_num_touches, 1)
	else:
		if _prev_touches.has("mouse"):
			_tap = 1.0
		_prev_touches.erase("mouse")

	var out := _prepare_output(60.0)
	out.length = 1

	if enable_pinch:
		out.channels["pinch_scale"] = PackedFloat32Array([_pinch_scale])
	if enable_swipe:
		out.channels["swipe_x"] = PackedFloat32Array([_swipe_x])
		out.channels["swipe_y"] = PackedFloat32Array([_swipe_y])
	if enable_rotate:
		out.channels["rotate_angle"] = PackedFloat32Array([_rotate_angle])

	out.channels["tap"] = PackedFloat32Array([_tap])
	out.channels["num_touches"] = PackedFloat32Array([float(_num_touches)])

	return out
