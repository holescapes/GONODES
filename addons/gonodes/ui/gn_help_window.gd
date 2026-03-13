class_name GNHelpWindow
extends Window
## A floating help window that displays auto-generated documentation for a GNNode.
##
## Reads node_description, port descriptions, and parameter metadata to build
## a formatted reference page.  Uses Godot's native RichTextLabel with BBCode.
##
## Content sources (in priority order):
##   1. Custom `.md` file in `res://addons/gonodes/help/<family>/<node_type>.md`
##   2. Auto-generated from operator metadata (zero manual authoring)
##
## Example patches:
##   Place `.gnpatch` files in `res://addons/gonodes/help/<family>/` with naming
##   convention `<node_type>_<label>.gnpatch` (e.g., `noise_top_example.gnpatch`,
##   `noise_top_feedback.gnpatch`).  Files are discovered by scanning the directory
##   for any `.gnpatch` whose filename starts with the node_type prefix.
##   Multiple examples per node are supported — each gets its own button.
##   Clicking a button emits [signal example_patch_requested] with the file path.
##
## Features:
##   • Family-colored header with node type badge
##   • Inputs/outputs tables with port names and descriptions
##   • Parameters table with name, type, default, range, and description
##   • "Open Example" button when a sample patch exists
##   • Closes on Escape or close button

## Emitted when the user closes this help window.
signal closed(help_window: GNHelpWindow)

## Emitted when the user clicks "Open Example" — carries the .gnpatch file path.
signal example_patch_requested(patch_path: String)

## The GNNode this help window documents.
var gn_node: GNNode = null

## Resolved paths to example .gnpatch files (empty if none found).
var _example_patch_paths: Array[String] = []

## Base directory for help files.
const HELP_DIR := "res://addons/gonodes/help"

## Internal controls.
var _bg: ColorRect = null
var _content_vbox: VBoxContainer = null
var _scroll: ScrollContainer = null
var _rtl: RichTextLabel = null
var _example_buttons: Array[Button] = []


func _init() -> void:
	title = "Help"
	size = Vector2i(520, 600)
	min_size = Vector2i(360, 300)
	unresizable = false
	always_on_top = false
	close_requested.connect(_on_close_requested)
	wrap_controls = true


func _ready() -> void:
	# Dark background
	_bg = ColorRect.new()
	_bg.color = Color(0.10, 0.10, 0.12)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Scroll container for long content
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	add_child(_scroll)

	# VBoxContainer so RichTextLabel + example button stack vertically
	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content_vbox)

	# RichTextLabel with BBCode for formatting
	_rtl = RichTextLabel.new()
	_rtl.bbcode_enabled = true
	_rtl.fit_content = true
	_rtl.scroll_active = false  # ScrollContainer handles scrolling
	_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rtl.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	_rtl.add_theme_constant_override("line_separation", 4)
	_content_vbox.add_child(_rtl)

	# Example buttons are created dynamically in _build_help_content()

	if gn_node != null:
		_build_help_content()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_requested()
		get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════════════

## Sets the node to document and rebuilds content.
func show_help_for(node: GNNode) -> void:
	gn_node = node
	title = "Help — %s" % node.id
	if _rtl != null:
		_build_help_content()


# ═══════════════════════════════════════════════════════════════════════════════
# Content Generation
# ═══════════════════════════════════════════════════════════════════════════════

## Builds the full BBCode content from the GNNode's metadata.
## Checks for a custom .md help file first; falls back to auto-generation.
func _build_help_content() -> void:
	if gn_node == null:
		_rtl.text = "[i]No node selected.[/i]"
		for btn in _example_buttons:
			if is_instance_valid(btn):
				btn.queue_free()
		_example_buttons.clear()
		return

	# Resolve help file paths
	var family_dir := GNFamily.get_family_name(gn_node.family).to_lower()
	var help_md_path := "%s/%s/%s.md" % [HELP_DIR, family_dir, gn_node.node_type]
	_example_patch_paths = _find_example_patches(family_dir)

	# Try loading custom .md content
	var custom_content := ""
	if ResourceLoader.exists(help_md_path) or FileAccess.file_exists(help_md_path):
		var f := FileAccess.open(help_md_path, FileAccess.READ)
		if f != null:
			custom_content = f.get_as_text()
			f.close()

	var bb := ""
	var family_name := GNFamily.get_family_name(gn_node.family)
	var family_color := GNFamily.get_color(gn_node.family)
	var hex := family_color.to_html(false)

	# ── Header (always auto-generated) ──
	bb += "[font_size=22][b][color=#%s]%s[/color][/b][/font_size]\n" % [hex, gn_node.id]
	bb += "[font_size=14][color=#888888]%s  •  %s[/color][/font_size]\n\n" % [
		gn_node.node_type, family_name]

	if not custom_content.is_empty():
		# ── Custom .md content ──
		bb += custom_content + "\n\n"
		# Still append auto-generated reference tables below the custom content
		bb += _section_header("Reference")
		bb += "\n"

	# ── Description ──
	if not gn_node.node_description.is_empty():
		bb += "%s\n\n" % gn_node.node_description
	else:
		bb += "[i]No description available.[/i]\n\n"

	# ── Inputs ──
	if gn_node.input_ports.size() > 0:
		bb += _section_header("Inputs")
		bb += _table_header(["Port", "Family", "Description"])
		for port in gn_node.input_ports:
			var port_family := GNFamily.get_family_name(port.family)
			var port_desc: String = port.description if not port.description.is_empty() else "—"
			var multi_tag := " [i](dynamic)[/i]" if gn_node._dynamic_input and port.index == 0 else ""
			bb += _table_row([port.port_name + multi_tag, port_family, port_desc])
		bb += "[/table]\n"
	else:
		bb += _section_header("Inputs")
		bb += "[i]None (generator node)[/i]\n\n"

	# ── Outputs ──
	if gn_node.output_ports.size() > 0:
		bb += _section_header("Outputs")
		bb += _table_header(["Port", "Family", "Description"])
		for port in gn_node.output_ports:
			var port_family := GNFamily.get_family_name(port.family)
			var port_desc: String = port.description if not port.description.is_empty() else "—"
			bb += _table_row([port.port_name, port_family, port_desc])
		bb += "[/table]\n"

	# ── Parameters ──
	if gn_node.parameters.size() > 0:
		bb += _section_header("Parameters")
		bb += _table_header(["Name", "Type", "Default", "Description"])
		# Sort parameter names for consistent display
		var param_names: Array = gn_node.parameters.keys()
		param_names.sort()
		for pname in param_names:
			var param: GNParameter = gn_node.parameters[pname]
			var type_str := _value_type_name(param.value_type)
			var default_str := _format_default(param)
			var desc: String = param.description if not param.description.is_empty() else "—"
			# Add range info for numeric types
			var range_str := _format_range(param)
			if not range_str.is_empty():
				desc += "  [color=#666666]%s[/color]" % range_str
			bb += _table_row([pname, type_str, default_str, desc])
		bb += "[/table]\n"

	# ── Flags ──
	bb += _section_header("Properties")
	bb += "[color=#aaaaaa]Time-dependent:[/color]  %s\n" % ("Yes" if gn_node.time_dependent else "No")
	bb += "[color=#aaaaaa]Family:[/color]  %s\n" % family_name
	bb += "[color=#aaaaaa]Node type:[/color]  %s\n" % gn_node.node_type

	# ── Example patches ──
	if _example_patch_paths.size() > 0:
		bb += "\n"
		var count := _example_patch_paths.size()
		bb += _section_header("Examples (%d)" % count if count > 1 else "Example")
		bb += "[color=#aaaaaa]Sample %s available — click %s below to open in a new editor.[/color]\n" % [
			"patches" if count > 1 else "patch",
			"a button" if count > 1 else "the button"]

	_rtl.text = bb

	# Rebuild example buttons — remove old ones first
	for btn in _example_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_example_buttons.clear()

	for path in _example_patch_paths:
		var btn := Button.new()
		var label := path.get_file().get_basename().replace("_", " ").capitalize()
		btn.text = label
		btn.tooltip_text = path
		btn.custom_minimum_size = Vector2(0, 36)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bound_path := path  # capture for lambda
		btn.pressed.connect(func() -> void: _on_example_pressed_path(bound_path))
		_content_vbox.add_child(btn)
		_example_buttons.append(btn)


## Scans the help directory for all .gnpatch files matching this node type.
## Convention: any file whose name starts with `<node_type>` followed by `_` or `.`
## inside `help/<family>/` is treated as an example for this operator.
## Examples: `noise_top_example.gnpatch`, `noise_top_feedback.gnpatch`, `noise_top.gnpatch`
## Returns an array of matching file paths (may be empty).
func _find_example_patches(family_dir: String) -> Array[String]:
	var results: Array[String] = []
	var prefix := gn_node.node_type  # e.g. "noise_top"

	# Scan core help directory
	_scan_dir_for_patches("%s/%s" % [HELP_DIR, family_dir], prefix, results)

	# Scan extension help directory (if this operator comes from an extension)
	var registry := GNExtensionRegistry.instance()
	var entry: GNExtensionRegistry.OperatorEntry = registry.get_entry_by_script(gn_node.get_script())
	if entry != null and not entry.extension_dir.is_empty():
		_scan_dir_for_patches("%s/help/%s" % [entry.extension_dir, family_dir], prefix, results)

	results.sort()
	return results


## Scans a single directory for .gnpatch files matching the node_type prefix.
func _scan_dir_for_patches(dir_path: String, prefix: String, results: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".gnpatch"):
			var base := file_name.get_basename()
			if base == prefix or base.begins_with(prefix + "_"):
				results.append("%s/%s" % [dir_path, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()


## Emits the example patch request when the user clicks an example button.
func _on_example_pressed_path(patch_path: String) -> void:
	example_patch_requested.emit(patch_path)


# ═══════════════════════════════════════════════════════════════════════════════
# Formatting Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Builds a section heading in BBCode.
func _section_header(text: String) -> String:
	return "[font_size=16][b]%s[/b][/font_size]\n" % text


## Builds a table header row using [table] BBCode.
func _table_header(columns: Array) -> String:
	var bb := "[table=%d]" % columns.size()
	for col in columns:
		bb += "[cell][b][color=#aaaaaa]%s[/color][/b][/cell]" % col
	return bb + "\n"


## Builds a table data row.
func _table_row(cells: Array) -> String:
	var bb := ""
	for i in range(cells.size()):
		bb += "[cell]%s[/cell]" % str(cells[i])
	return bb + "\n"


## Returns a human-readable name for a GNParameter.ValueType enum value.
func _value_type_name(vt: GNParameter.ValueType) -> String:
	match vt:
		GNParameter.ValueType.FLOAT:    return "Float"
		GNParameter.ValueType.INT:      return "Int"
		GNParameter.ValueType.BOOL:     return "Bool"
		GNParameter.ValueType.STRING:   return "String"
		GNParameter.ValueType.VECTOR2:  return "Vec2"
		GNParameter.ValueType.VECTOR2I: return "Vec2i"
		GNParameter.ValueType.VECTOR3:  return "Vec3"
		GNParameter.ValueType.VECTOR4:  return "Vec4"
		GNParameter.ValueType.COLOR:    return "Color"
		GNParameter.ValueType.ENUM:     return "Enum"
		GNParameter.ValueType.FILE:     return "File"
		_:                              return "?"


## Formats the default value for display, truncating long strings.
func _format_default(param: GNParameter) -> String:
	var val = param.default_value
	if val == null:
		return "—"
	var s := str(val)
	# Truncate long defaults (e.g., shader code)
	if s.length() > 30:
		s = s.substr(0, 27) + "…"
	return s


## Builds a range string like "[0.0 .. 1.0]" for numeric parameters.
func _format_range(param: GNParameter) -> String:
	if param.value_type == GNParameter.ValueType.FLOAT or param.value_type == GNParameter.ValueType.INT:
		if param.min_value != null or param.max_value != null:
			var lo: String = str(param.min_value) if param.min_value != null else "—∞"
			var hi: String = str(param.max_value) if param.max_value != null else "∞"
			return "[%s .. %s]" % [lo, hi]
	elif param.value_type == GNParameter.ValueType.ENUM:
		if param.enum_options.size() > 0:
			return "{%s}" % ", ".join(param.enum_options)
	return ""


func _on_close_requested() -> void:
	closed.emit(self)
	queue_free()
