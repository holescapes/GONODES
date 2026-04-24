class_name KeyboardInCHOP
extends GNChopBase
## Outputs keyboard key states as CHOP channels.
## Each key listed in the "keys" parameter becomes a channel with value 1.0
## (pressed) or 0.0 (released).  In Toggle mode the channel flips on each
## key-down event; in Momentary mode it follows the physical key state.
##
## The optional "window" parameter binds this CHOP to a specific WindowOUT
## by node name — reading only key events that occurred inside that window.
## When empty, reads from the global Input singleton (all windows).

## Persistent toggle states (key_name → bool).  Only used in Toggle mode.
var _key_states: Dictionary = {}

## Name of the last WindowOUT that had focus (readable by downstream ops).
var active_window_name: String = ""


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "keyboard_in"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Key state channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("keys", "w a s d space",
		"Keys", "Space-separated key names to monitor (e.g. 'w a s d space shift')"))
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Toggle", "Momentary"]), 1,
		"Mode", "Toggle: flip on key-down. Momentary: follow physical state."))
	add_parameter(GNParameter.create_string("window", "Window ID to capture from (0 = main)",
		"Window", "WindowOUT node name to read from (empty = global)"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var keys_str: String = get_param_value("keys")
	var mode: int = get_param_value("mode")
	var window_id: String = get_param_value("window")

	var out: GNChannelData = _prepare_output(60.0)

	# Resolve target WindowOUT (null = global Input)
	var win_out: WindowOUT = null
	if not window_id.is_empty():
		win_out = WindowOUT.get_window_by_id(window_id)
		if win_out == null:
			node_warning = "WindowOUT '%s' not found or not open" % window_id

	# Update active window name
	if win_out != null:
		active_window_name = win_out.get_param_value("title") if win_out._input_has_focus else ""
	else:
		var last_id: String = WindowOUT._last_focused_window
		var last_win: WindowOUT = WindowOUT.get_window_by_id(last_id) if not last_id.is_empty() else null
		active_window_name = last_win.get_param_value("title") if last_win != null else ""

	var key_names: PackedStringArray = keys_str.strip_edges().split(" ", false)
	for key_name in key_names:
		if key_name.is_empty():
			continue

		var keycode: Key = OS.find_keycode_from_string(key_name)
		var is_pressed: bool = false
		if win_out != null:
			is_pressed = win_out._input_keys.get(keycode, false) if keycode != KEY_NONE else false
		else:
			is_pressed = Input.is_key_pressed(keycode) if keycode != KEY_NONE else false

		var value: float = 0.0
		if mode == 0:
			# Toggle mode — flip state on press edge
			var was_pressed: bool = _key_states.get(key_name + "_raw", false)
			var toggled: bool = _key_states.get(key_name, false)
			if is_pressed and not was_pressed:
				toggled = not toggled
				_key_states[key_name] = toggled
			_key_states[key_name + "_raw"] = is_pressed
			value = 1.0 if toggled else 0.0
		else:
			# Momentary mode
			value = 1.0 if is_pressed else 0.0

		out.set_single_value(key_name, value)

	# Focused channel — 1.0 when the target window has keyboard focus
	if win_out != null:
		out.set_single_value("focused", 1.0 if win_out._input_has_focus else 0.0)
		out.set_single_value("window_name", float(hash(win_out.get_param_value("title")) & 0x7FFFFFFF))

	return out
