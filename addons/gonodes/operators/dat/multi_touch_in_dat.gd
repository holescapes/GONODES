class_name MultiTouchInDAT
extends GNDatBase
## Captures multi-touch input events and outputs a table of active touches.
## Each row represents one touch point with columns:
##   id | x | y | pressure | relative_x | relative_y | phase | window
##
## The optional "window" parameter binds this DAT to a specific WindowOUT
## by node name — reading only touch events from that window.
## When empty, reads from the global _input_event callback (all windows).

var _touches: Dictionary = {}  # touch_index -> { x, y, pressure, phase }


func _init() -> void:
	node_type = "multi_touch_in"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Active touch points table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", true, "Active",
		"Enable / disable touch capture"))
	add_parameter(GNParameter.create_bool("normalize", false, "Normalize",
		"Output 0-1 normalized coords instead of pixels"))
	add_parameter(GNParameter.create_string("window", "Window ID to capture from (0 = main)",
		"Window", "WindowOUT node name to read from (empty = global)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")
	var normalize: bool = get_param_value("normalize")
	var window_id: String = get_param_value("window")

	if not active:
		_touches.clear()
		return _prepare_table(true)

	# Resolve target WindowOUT
	var win_out: WindowOUT = null
	if not window_id.is_empty():
		win_out = WindowOUT.get_window_by_id(window_id)
		if win_out == null:
			node_warning = "WindowOUT '%s' not found or not open" % window_id

	# Determine which touch data to read
	var touch_data: Dictionary
	if win_out != null:
		touch_data = win_out._input_touches
	else:
		_poll_events()
		touch_data = _touches

	var tbl: GNTableData = _prepare_table(true)
	tbl.set_headers(PackedStringArray(["id", "x", "y", "pressure", "rel_x", "rel_y", "phase", "window"]))

	var vp_size: Vector2
	if win_out != null:
		vp_size = win_out._input_window_size
	else:
		vp_size = Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width", 1920),
			ProjectSettings.get_setting("display/window/size/viewport_height", 1080)
		)

	var win_title: String = win_out.get_param_value("title") if win_out != null else ""

	for idx in touch_data:
		var t: Dictionary = touch_data[idx]
		var x_val: float = t.get("x", 0.0)
		var y_val: float = t.get("y", 0.0)
		var rel_x: float = t.get("rel_x", t.get("relative_x", 0.0))
		var rel_y: float = t.get("rel_y", t.get("relative_y", 0.0))
		var pressure: float = t.get("pressure", 0.0)
		var phase: String = t.get("phase", "")

		if normalize and vp_size.x > 0 and vp_size.y > 0:
			x_val /= vp_size.x
			y_val /= vp_size.y
			rel_x /= vp_size.x
			rel_y /= vp_size.y

		tbl.append_row(PackedStringArray([
			str(idx),
			"%.4f" % x_val,
			"%.4f" % y_val,
			"%.4f" % pressure,
			"%.4f" % rel_x,
			"%.4f" % rel_y,
			phase,
			win_title
		]))

	# Remove ended touches after outputting (only when reading global)
	if win_out == null:
		var ended_ids: Array = []
		for idx in _touches:
			if _touches[idx].get("phase", "") == "ended":
				ended_ids.append(idx)
		for idx in ended_ids:
			_touches.erase(idx)

	return tbl


func _poll_events() -> void:
	# Process any pending input events that have been forwarded to us
	# In GONODES the engine pumps _unhandled_input; we read from Input singletons
	# For screen-touch, Godot provides InputEventScreenTouch / InputEventScreenDrag
	# We store the latest state per finger index
	pass  # State is updated via _input_event callback


func _input_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e: InputEventScreenTouch = event as InputEventScreenTouch
		if e.pressed:
			_touches[e.index] = {
				"x": e.position.x,
				"y": e.position.y,
				"pressure": e.pressure if e.pressure > 0 else 1.0,
				"relative_x": 0.0,
				"relative_y": 0.0,
				"phase": "began"
			}
		else:
			if _touches.has(e.index):
				_touches[e.index]["phase"] = "ended"
			else:
				_touches[e.index] = {
					"x": e.position.x,
					"y": e.position.y,
					"pressure": 0.0,
					"relative_x": 0.0,
					"relative_y": 0.0,
					"phase": "ended"
				}
	elif event is InputEventScreenDrag:
		var e: InputEventScreenDrag = event as InputEventScreenDrag
		_touches[e.index] = {
			"x": e.position.x,
			"y": e.position.y,
			"pressure": e.pressure if e.pressure > 0 else 1.0,
			"relative_x": e.relative.x,
			"relative_y": e.relative.y,
			"phase": "moved"
		}
