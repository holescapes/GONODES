class_name MouseInCHOP
extends GNChopBase
## Outputs mouse position, movement delta, button states, and scroll as CHOP
## channels.  Position can be raw pixels or normalized 0-1 by viewport size.
##
## The Window menu binds this CHOP to a WindowOUT by node name. (none) reads
## the global Input singleton.

## Previous mouse position for computing per-frame delta.
var _prev_pos: Vector2 = Vector2.ZERO

## Accumulated scroll value (Godot only fires events, not a continuous axis).
var _scroll_accum: float = 0.0

## Whether we have captured the first frame (avoids a huge initial delta).
var _first_frame: bool = true

## Name of the last WindowOUT that had focus (readable by downstream ops).
var active_window_name: String = ""


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "mouse_in"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Mouse state channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("normalized", true,
		"Normalized", "Normalize position to 0-1 range using viewport size"))
	add_parameter(GNParameter.create_bool("buttons", true,
		"Buttons", "Output mouse button channels (lmb, rmb, mmb)"))
	add_parameter(GNParameter.create_bool("scroll", true,
		"Scroll", "Output accumulated scroll wheel channel"))
	add_parameter(GNParameter.create_node_ref("window", GNFamily.Type.OUT,
		"Window", "WindowOUT to read. (none) uses global input.", "window"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var normalized: bool = get_param_value("normalized")
	var output_buttons: bool = get_param_value("buttons")
	var output_scroll: bool = get_param_value("scroll")
	var window_id: String = get_param_value("window")

	var out: GNChannelData = _prepare_output(60.0)

	# Resolve target WindowOUT (null = global Input)
	var win_out: WindowOUT = null
	node_warning = ""
	if not window_id.is_empty():
		win_out = WindowOUT.get_window_by_id(window_id)
		if win_out == null:
			node_warning = "WindowOUT '%s' not found or not open" % window_id

	# Update active window name
	if win_out != null:
		active_window_name = win_out.get_param_value("title") if win_out.output_window_focused() else ""
	else:
		var last_id: String = WindowOUT._last_focused_window
		var last_win: WindowOUT = WindowOUT.get_window_by_id(last_id) if not last_id.is_empty() else null
		active_window_name = last_win.get_param_value("title") if last_win != null else ""

	# ── Position ───────────────────────────────────────────────────────────
	var pos: Vector2 = Vector2.ZERO
	var vp_size: Vector2 = Vector2.ONE

	if win_out != null:
		pos = win_out.pointer_local()
		vp_size = win_out._input_window_size
		if vp_size.x == 0.0:
			vp_size.x = 1.0
		if vp_size.y == 0.0:
			vp_size.y = 1.0
	else:
		var viewport: Viewport = Engine.get_main_loop().root if Engine.get_main_loop() != null else null
		if viewport != null:
			pos = viewport.get_mouse_position()
			vp_size = Vector2(viewport.get_visible_rect().size)
			if vp_size.x == 0.0:
				vp_size.x = 1.0
			if vp_size.y == 0.0:
				vp_size.y = 1.0

	var tx: float = pos.x
	var ty: float = pos.y
	if normalized:
		tx = pos.x / vp_size.x
		ty = pos.y / vp_size.y

	out.set_single_value("tx", tx)
	out.set_single_value("ty", ty)

	# ── Delta ──────────────────────────────────────────────────────────────
	if _first_frame:
		_prev_pos = pos
		_first_frame = false

	var dx: float = pos.x - _prev_pos.x
	var dy: float = pos.y - _prev_pos.y
	if normalized:
		dx /= vp_size.x
		dy /= vp_size.y
	_prev_pos = pos

	out.set_single_value("dx", dx)
	out.set_single_value("dy", dy)

	# ── Buttons ────────────────────────────────────────────────────────────
	if output_buttons:
		if win_out != null:
			var over := win_out.pointer_over_window()
			out.set_single_value("lmb", 1.0 if win_out.button_held(MOUSE_BUTTON_LEFT) or (over and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) else 0.0)
			out.set_single_value("rmb", 1.0 if win_out.button_held(MOUSE_BUTTON_RIGHT) or (over and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) else 0.0)
			out.set_single_value("mmb", 1.0 if win_out.button_held(MOUSE_BUTTON_MIDDLE) or (over and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)) else 0.0)
			win_out.consume_button_latch()
		else:
			out.set_single_value("lmb", 1.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0.0)
			out.set_single_value("rmb", 1.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 0.0)
			out.set_single_value("mmb", 1.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) else 0.0)

	# ── Scroll ─────────────────────────────────────────────────────────────
	if output_scroll:
		if win_out != null:
			out.set_single_value("scroll", win_out._input_scroll)
		else:
			# Global mode: decay accumulated scroll each frame
			_scroll_accum *= 0.9
			out.set_single_value("scroll", _scroll_accum)

	# Focused channel — 1.0 when the target window has mouse focus
	if win_out != null:
		out.set_single_value("focused", 1.0 if win_out._input_has_focus else 0.0)
		out.set_single_value("window_name", float(hash(win_out.get_param_value("title")) & 0x7FFFFFFF))

	return out
