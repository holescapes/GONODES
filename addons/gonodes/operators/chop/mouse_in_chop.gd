class_name MouseInCHOP
extends GNChopBase
## Outputs mouse position, movement delta, button states, and scroll as CHOP
## channels.  Position can be raw pixels or normalized 0-1 by viewport size.

## Previous mouse position for computing per-frame delta.
var _prev_pos: Vector2 = Vector2.ZERO

## Accumulated scroll value (Godot only fires events, not a continuous axis).
var _scroll_accum: float = 0.0

## Whether we have captured the first frame (avoids a huge initial delta).
var _first_frame: bool = true


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "mousein"
	time_dependent = true
	node_description = "Output mouse position, delta, buttons, and scroll as channels."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Mouse state channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("normalized", true,
		"Normalized", "Normalize position to 0-1 range using viewport size"))
	add_parameter(GNParameter.create_bool("buttons", true,
		"Buttons", "Output mouse button channels (lmb, rmb, mmb)"))
	add_parameter(GNParameter.create_bool("scroll", true,
		"Scroll", "Output accumulated scroll wheel channel"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var normalized: bool = get_param_value("normalized")
	var output_buttons: bool = get_param_value("buttons")
	var output_scroll: bool = get_param_value("scroll")

	var out: GNChannelData = _prepare_output(60.0)

	# ── Position ───────────────────────────────────────────────────────────
	var viewport: Viewport = Engine.get_main_loop().root if Engine.get_main_loop() != null else null
	var pos: Vector2 = Vector2.ZERO
	var vp_size: Vector2 = Vector2.ONE

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
		out.set_single_value("lmb", 1.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0.0)
		out.set_single_value("rmb", 1.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 0.0)
		out.set_single_value("mmb", 1.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) else 0.0)

	# ── Scroll ─────────────────────────────────────────────────────────────
	if output_scroll:
		# Scroll is event-driven; we decay each frame so it acts like an impulse.
		_scroll_accum *= 0.9
		out.set_single_value("scroll", _scroll_accum)

	return out
