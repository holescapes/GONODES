class_name KeyboardInCHOP
extends GNChopBase
## Outputs keyboard key states as CHOP channels.
## Each key listed in the "keys" parameter becomes a channel with value 1.0
## (pressed) or 0.0 (released).  In Toggle mode the channel flips on each
## key-down event; in Momentary mode it follows the physical key state.

## Persistent toggle states (key_name → bool).  Only used in Toggle mode.
var _key_states: Dictionary = {}


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "keyboardin"
	time_dependent = true
	node_description = "Output keyboard key states as CHOP channels."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Key state channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("keys", "w a s d space",
		"Keys", "Space-separated key names to monitor (e.g. 'w a s d space shift')"))
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Toggle", "Momentary"]), 1,
		"Mode", "Toggle: flip on key-down. Momentary: follow physical state."))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var keys_str: String = get_param_value("keys")
	var mode: int = get_param_value("mode")

	var out: GNChannelData = _prepare_output(60.0)

	var key_names: PackedStringArray = keys_str.strip_edges().split(" ", false)
	for key_name in key_names:
		if key_name.is_empty():
			continue

		var keycode: Key = OS.find_keycode_from_string(key_name)
		var is_pressed: bool = Input.is_key_pressed(keycode) if keycode != KEY_NONE else false

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

	return out
