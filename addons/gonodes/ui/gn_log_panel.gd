class_name GNLogPanel
extends PanelContainer
## Collapsible log panel (Textport) for the GONODES editor.
## Subscribes to GNLogger.log_sink and displays color-coded messages
## in a RichTextLabel with level filtering and a ring buffer.

const MAX_LINES := 500

var _rtl: RichTextLabel
var _filter_bar: HBoxContainer
var _clear_btn: Button
var _filter_buttons: Dictionary = {}  # Level -> CheckButton

## Ring buffer of log entries: Array of { level, category, message }
var _entries: Array[Dictionary] = []

## Active level filters (true = visible).
var _level_visible: Dictionary = {
	GNLogger.Level.DEBUG: true,
	GNLogger.Level.INFO:  true,
	GNLogger.Level.WARN:  true,
	GNLogger.Level.ERROR: true,
}

## Color per log level.
const _LEVEL_COLORS := {
	GNLogger.Level.DEBUG: Color(0.6, 0.6, 0.6),
	GNLogger.Level.INFO:  Color(0.85, 0.85, 0.85),
	GNLogger.Level.WARN:  Color(1.0, 0.85, 0.2),
	GNLogger.Level.ERROR: Color(1.0, 0.35, 0.35),
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
		cb.button_pressed = true
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


func _on_log_received(lvl: GNLogger.Level, category: String, message: String) -> void:
	var entry := { "level": lvl, "category": category, "message": message }
	_entries.append(entry)

	# Ring buffer trim
	while _entries.size() > MAX_LINES:
		_entries.pop_front()

	# Append to display if filter allows
	if _level_visible.get(lvl, true):
		_append_line(entry)


func _on_filter_toggled(pressed: bool, lvl: GNLogger.Level) -> void:
	_level_visible[lvl] = pressed
	_rebuild_display()


func clear_log() -> void:
	_entries.clear()
	_rtl.clear()


func _rebuild_display() -> void:
	_rtl.clear()
	for entry in _entries:
		if _level_visible.get(entry["level"], true):
			_append_line(entry)


func _append_line(entry: Dictionary) -> void:
	var lvl: int = entry["level"]
	var color: Color = _LEVEL_COLORS.get(lvl, Color.WHITE)
	var tag: String = _LEVEL_TAGS.get(lvl, "???")
	var hex := color.to_html(false)
	_rtl.append_text(
		"[color=#%s][%s] [%s] %s[/color]\n" % [hex, tag, entry["category"], entry["message"]])
