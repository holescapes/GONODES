class_name GNLogPanel
extends PanelContainer
## Collapsible log panel (Textport) for the GONODES editor.
## Draws the latest captured lines while this panel is open.
## Capture itself stays on when the panel is closed.

const DEFAULT_MAX_LINES := 50

## How many lines this panel draws. Capture and the log file are not capped here.
var max_lines: int = DEFAULT_MAX_LINES

var _rtl: RichTextLabel
var _filter_bar: HBoxContainer
var _clear_btn: Button
var _filter_buttons: Dictionary = {}  # Level -> CheckButton

## Ring buffer of log entries: Array of { level, category, message }
var _entries: Array[Dictionary] = []

## Active level filters (true = visible). Debug stays off until the user asks.
var _level_visible: Dictionary = {
	GNLogger.Level.DEBUG: false,
	GNLogger.Level.INFO:  true,
	GNLogger.Level.WARN:  true,
	GNLogger.Level.ERROR: true,
}

## Color per log level. The tag uses the full color; the message uses a lighter tint.
const _LEVEL_COLORS := {
	GNLogger.Level.DEBUG: Color(0.62, 0.62, 0.66),
	GNLogger.Level.INFO:  Color(0.45, 0.78, 1.0),
	GNLogger.Level.WARN:  Color(1.0, 0.78, 0.2),
	GNLogger.Level.ERROR: Color(1.0, 0.38, 0.34),
}

const _LEVEL_TAGS := {
	GNLogger.Level.DEBUG: "DBG",
	GNLogger.Level.INFO:  "INF",
	GNLogger.Level.WARN:  "WRN",
	GNLogger.Level.ERROR: "ERR",
}


func _init() -> void:
	name = "LogPanel"
	custom_minimum_size.y = 120
	size_flags_horizontal = SIZE_EXPAND_FILL

	# Dark background
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	sb.content_margin_left = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	# ── Filter bar ────────────────────────────────────────────────────────
	_filter_bar = HBoxContainer.new()
	_filter_bar.add_theme_constant_override("separation", 4)
	vbox.add_child(_filter_bar)

	for lvl in [GNLogger.Level.DEBUG, GNLogger.Level.INFO,
				GNLogger.Level.WARN, GNLogger.Level.ERROR]:
		var cb := CheckButton.new()
		cb.text = _LEVEL_TAGS[lvl]
		cb.set_pressed_no_signal(_level_visible[lvl])
		var tag_color: Color = _LEVEL_COLORS[lvl]
		cb.add_theme_color_override("font_color", tag_color)
		cb.add_theme_color_override("font_hover_color", tag_color.lightened(0.15))
		cb.add_theme_color_override("font_pressed_color", tag_color)
		cb.add_theme_color_override("font_hover_pressed_color", tag_color.lightened(0.15))
		if lvl == GNLogger.Level.DEBUG:
			cb.tooltip_text = "Show debug lines and capture them. Leave this off to skip per-cook debug."
		cb.toggled.connect(_on_filter_toggled.bind(lvl))
		_filter_bar.add_child(cb)
		_filter_buttons[lvl] = cb

	_filter_bar.add_child(VSeparator.new())

	_clear_btn = Button.new()
	_clear_btn.text = "Clear"
	_clear_btn.pressed.connect(clear_log)
	_filter_bar.add_child(_clear_btn)

	# ── RichTextLabel ─────────────────────────────────────────────────────
	_rtl = RichTextLabel.new()
	_rtl.bbcode_enabled = true
	_rtl.scroll_following = true
	_rtl.selection_enabled = true
	_rtl.size_flags_vertical = SIZE_EXPAND_FILL
	_rtl.size_flags_horizontal = SIZE_EXPAND_FILL
	_rtl.add_theme_font_size_override("normal_font_size", 12)
	vbox.add_child(_rtl)


func _ready() -> void:
	GNLogger.log_sink = Callable(self, "_on_log_received")


func _exit_tree() -> void:
	# Clear the sink so we don't hold a stale reference
	if GNLogger.log_sink.is_valid() and GNLogger.log_sink.get_object() == self:
		GNLogger.log_sink = Callable()


func wants_debug() -> bool:
	return _level_visible.get(GNLogger.Level.DEBUG, false)


func _on_log_received(lvl: GNLogger.Level, category: String, message: String) -> void:
	# Drawing is the expensive part. Capture already happened in GNLogger.
	if not visible:
		return
	var entry := { "level": lvl, "category": category, "message": message }
	_entries.append(entry)
	if _level_visible.get(lvl, true):
		_append_line(entry)
	_trim_display()


func _on_filter_toggled(pressed: bool, lvl: GNLogger.Level) -> void:
	_level_visible[lvl] = pressed
	if lvl == GNLogger.Level.DEBUG:
		_apply_debug_capture()
	if visible:
		refresh_from_buffer()


## DBG widens capture to debug. Closing the panel does not undo that.
func _apply_debug_capture() -> void:
	if wants_debug():
		GNLogger.level = GNLogger.Level.DEBUG
	else:
		GNLogger.level = GNLogger.baseline_level


## Replace the drawn lines with the logger's latest window.
func refresh_from_buffer() -> void:
	_entries.clear()
	_rtl.clear()
	for row in GNLogger.get_recent_lines():
		_entries.append(row)
		if _level_visible.get(row["level"], true):
			_append_line(row)
	_trim_display()


func clear_log() -> void:
	_entries.clear()
	_rtl.clear()
	GNLogger.clear_recent_lines()


func _trim_display() -> void:
	var limit := maxi(max_lines, 1)
	if _entries.size() <= limit:
		return
	while _entries.size() > limit:
		_entries.pop_front()
	_rtl.clear()
	for entry in _entries:
		if _level_visible.get(entry["level"], true):
			_append_line(entry)


func _append_line(entry: Dictionary) -> void:
	var lvl: int = entry["level"]
	var color: Color = _LEVEL_COLORS.get(lvl, Color.WHITE)
	var tag: String = _LEVEL_TAGS.get(lvl, "???")
	var tag_hex := color.to_html(false)
	var body_hex := color.lightened(0.35).to_html(false)
	_rtl.append_text(
		"[color=#%s][%s][/color] [color=#%s][%s] %s[/color]\n" % [
			tag_hex, tag, body_hex, entry["category"], entry["message"]])
