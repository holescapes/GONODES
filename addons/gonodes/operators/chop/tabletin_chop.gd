class_name TabletInCHOP
extends GNChopBase
## Pen tablet / stylus input CHOP.
##
## Outputs pen position, pressure, tilt, and button state as CHOP channels.
## Uses Godot's InputEventScreenDrag / InputEventMouseMotion with pen data.
##
## TouchDesigner equivalent: Tablet In CHOP.

var _x: float = 0.0
var _y: float = 0.0
var _pressure: float = 0.0
var _tilt_x: float = 0.0
var _tilt_y: float = 0.0
var _button: float = 0.0


func _init() -> void:
	node_type = "tabletin"
	time_dependent = true
	node_description = "Pen tablet / stylus input as CHOP channels."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Tablet channels (x, y, pressure, tilt_x, tilt_y, button)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("normalize", true,
		"Normalize", "Normalize coordinates to 0–1 range"))
	add_parameter(GNParameter.create_bool("active", true,
		"Active", "Enable tablet input capture"))


func _pre_cook(_delta: float) -> void:
	if not get_param_value("active"):
		return
	# Pen data comes through standard mouse events in Godot
	# pressure and tilt are available on InputEventMouseMotion
	mark_dirty()


func _cook(_inputs: Array[GNData]) -> GNData:
	var normalize: bool = get_param_value("normalize")
	var out := _prepare_output(60.0)

	# Read latest pen state
	var vp := Engine.get_main_loop()
	if vp is SceneTree:
		var viewport := (vp as SceneTree).get_root()
		var mouse_pos := viewport.get_mouse_position()
		_x = mouse_pos.x
		_y = mouse_pos.y
		if normalize:
			var size := viewport.get_visible_rect().size
			if size.x > 0:
				_x /= size.x
			if size.y > 0:
				_y /= size.y

	out.set_single_value("x", _x)
	out.set_single_value("y", _y)
	out.set_single_value("pressure", _pressure)
	out.set_single_value("tilt_x", _tilt_x)
	out.set_single_value("tilt_y", _tilt_y)
	out.set_single_value("button", _button)

	return out


## Call this from an input handler to update pen state
func update_pen_state(pressure: float, tilt: Vector2, button_pressed: bool) -> void:
	_pressure = pressure
	_tilt_x = tilt.x
	_tilt_y = tilt.y
	_button = 1.0 if button_pressed else 0.0
