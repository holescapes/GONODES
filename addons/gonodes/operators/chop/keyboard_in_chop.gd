class_name KeyboardInCHOP
extends GNChopBase
## Outputs keyboard key states as CHOP channels.
## Each key listed in the "keys" parameter becomes a channel with value 1.0
## (pressed) or 0.0 (released).  An empty list captures every key.  In Toggle
## mode the channel flips on each key-down event; in Momentary mode it follows
## the physical key state.
##
## The "window" menu binds this CHOP to a WindowOUT by node name, reading only
## key events from that window.  (none) reads the global Input singleton.

## Persistent toggle states (key_name → bool).  Only used in Toggle mode.
var _key_states: Dictionary = {}

## Key names that were down on the previous cook, so a release still emits 0.
var _live_keys: Dictionary = {}

## Pressed state already resolved this cook when Keys is empty.
var _resolved_press: Dictionary = {}
var _use_resolved: bool = false

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
		"Keys", "Space-separated key names (for example w a s d space). Leave empty to capture every key."))
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Toggle", "Momentary"]), 1,
		"Mode", "Toggle: flip on key-down. Momentary: follow physical state."))
	add_parameter(GNParameter.create_node_ref("window", GNFamily.Type.OUT,
		"Window", "WindowOUT to read. (none) uses global input.", "window"))


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
	node_warning = ""
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

	var key_names := _key_names_for_cook(keys_str, win_out)
	var still_down: Dictionary = {}
	for key_name in key_names:
		if key_name.is_empty():
			continue
		var is_pressed := _key_is_pressed(key_name, win_out)
		if is_pressed:
			still_down[key_name] = true
		out.set_single_value(key_name, _key_value(key_name, is_pressed, mode))
	_live_keys = still_down

	# Focused channel — 1.0 when the target window has keyboard focus
	if win_out != null:
		out.set_single_value("focused", 1.0 if win_out._input_has_focus else 0.0)
		win_out.consume_key_latch()

	return out


func _key_names_for_cook(keys_str: String, win_out: WindowOUT) -> PackedStringArray:
	var listed := keys_str.strip_edges()
	if not listed.is_empty():
		_use_resolved = false
		_resolved_press.clear()
		return listed.split(" ", false)
	_use_resolved = true
	_resolved_press.clear()
	if win_out != null:
		for raw_code in win_out._input_keys.keys():
			if win_out.key_held(int(raw_code)):
				_note_key(int(raw_code))
		for raw_code in win_out._key_latch.keys():
			_note_key(int(raw_code))
	else:
		for code in _scan_keycodes():
			if Input.is_key_pressed(code as Key):
				_note_key(code)
	var names := PackedStringArray()
	for key_name in _resolved_press.keys():
		names.append(key_name)
	for key_name in _live_keys.keys():
		if not _resolved_press.has(key_name):
			_resolved_press[key_name] = false
			names.append(key_name)
	return names


func _note_key(code: int) -> void:
	if code == KEY_NONE:
		return
	var key_name := OS.get_keycode_string(code as Key).to_lower().replace(" ", "_")
	if key_name.is_empty() or key_name == "none":
		return
	_resolved_press[key_name] = true


func _key_is_pressed(key_name: String, win_out: WindowOUT) -> bool:
	if _use_resolved:
		return bool(_resolved_press.get(key_name, false))
	var keycode: Key = OS.find_keycode_from_string(key_name.replace("_", " "))
	if keycode == KEY_NONE:
		keycode = OS.find_keycode_from_string(key_name)
	if keycode == KEY_NONE:
		return false
	if win_out != null:
		return win_out.key_held(int(keycode)) or Input.is_key_pressed(keycode)
	return Input.is_key_pressed(keycode)


func _key_value(key_name: String, is_pressed: bool, mode: int) -> float:
	if mode != 0:
		return 1.0 if is_pressed else 0.0
	var was_pressed: bool = _key_states.get(key_name + "_raw", false)
	var toggled: bool = _key_states.get(key_name, false)
	if is_pressed and not was_pressed:
		toggled = not toggled
		_key_states[key_name] = toggled
	_key_states[key_name + "_raw"] = is_pressed
	return 1.0 if toggled else 0.0


static var _scan_codes: Array[int] = []

static func _scan_keycodes() -> Array[int]:
	if not _scan_codes.is_empty():
		return _scan_codes
	var codes: Array[int] = []
	for i in range(32, 127):
		codes.append(i)
	for k in [
		KEY_ESCAPE, KEY_TAB, KEY_BACKTAB, KEY_BACKSPACE, KEY_ENTER, KEY_KP_ENTER,
		KEY_INSERT, KEY_DELETE, KEY_HOME, KEY_END, KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN,
		KEY_PAGEUP, KEY_PAGEDOWN, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META,
		KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK,
		KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6,
		KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12,
		KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4,
		KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9,
		KEY_KP_MULTIPLY, KEY_KP_DIVIDE, KEY_KP_SUBTRACT, KEY_KP_ADD, KEY_KP_PERIOD,
	]:
		codes.append(int(k))
	_scan_codes = codes
	return _scan_codes
