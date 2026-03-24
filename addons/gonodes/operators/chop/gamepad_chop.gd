class_name GamepadCHOP
extends GNChopBase
## Outputs gamepad / controller state as CHOP channels.
## Stick axes, triggers, and face / shoulder / D-pad buttons are mapped to
## named channels.  A per-axis deadzone is applied to analog inputs.


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "gamepad"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Gamepad state channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("device", 0, 0, 7,
		"Device", "Gamepad device index (0-7)"))
	add_parameter(GNParameter.create_float("deadzone", 0.1, 0.0, 0.5, 0.01,
		"Deadzone", "Analog stick deadzone threshold"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var device: int = get_param_value("device")
	var deadzone: float = get_param_value("deadzone")

	var out: GNChannelData = _prepare_output(60.0)

	# ── Analog sticks & triggers ───────────────────────────────────────────
	out.set_single_value("lx", _apply_deadzone(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), deadzone))
	out.set_single_value("ly", _apply_deadzone(Input.get_joy_axis(device, JOY_AXIS_LEFT_Y), deadzone))
	out.set_single_value("rx", _apply_deadzone(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), deadzone))
	out.set_single_value("ry", _apply_deadzone(Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y), deadzone))
	out.set_single_value("lt", maxf(0.0, Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT)))
	out.set_single_value("rt", maxf(0.0, Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT)))

	# ── Face buttons ───────────────────────────────────────────────────────
	out.set_single_value("a", _btn(device, JOY_BUTTON_A))
	out.set_single_value("b", _btn(device, JOY_BUTTON_B))
	out.set_single_value("x", _btn(device, JOY_BUTTON_X))
	out.set_single_value("y", _btn(device, JOY_BUTTON_Y))

	# ── Shoulder buttons ───────────────────────────────────────────────────
	out.set_single_value("lb", _btn(device, JOY_BUTTON_LEFT_SHOULDER))
	out.set_single_value("rb", _btn(device, JOY_BUTTON_RIGHT_SHOULDER))

	# ── Start / Select ─────────────────────────────────────────────────────
	out.set_single_value("start", _btn(device, JOY_BUTTON_START))
	out.set_single_value("select", _btn(device, JOY_BUTTON_BACK))

	# ── D-pad ──────────────────────────────────────────────────────────────
	out.set_single_value("dup", _btn(device, JOY_BUTTON_DPAD_UP))
	out.set_single_value("ddown", _btn(device, JOY_BUTTON_DPAD_DOWN))
	out.set_single_value("dleft", _btn(device, JOY_BUTTON_DPAD_LEFT))
	out.set_single_value("dright", _btn(device, JOY_BUTTON_DPAD_RIGHT))

	return out


# ═══════════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Applies a symmetric deadzone to an axis value.
func _apply_deadzone(value: float, deadzone: float) -> float:
	if absf(value) < deadzone:
		return 0.0
	# Remap so the output still spans the full -1..1 range beyond the deadzone.
	var sign_v: float = signf(value)
	return sign_v * ((absf(value) - deadzone) / (1.0 - deadzone))


## Shorthand: returns 1.0 if the button is pressed, 0.0 otherwise.
func _btn(device: int, button: JoyButton) -> float:
	return 1.0 if Input.is_joy_button_pressed(device, button) else 0.0
