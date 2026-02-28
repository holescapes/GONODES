class_name GNParamRow
extends HBoxContainer
## A single parameter row in the inspector.
## Renders the appropriate control for the parameter's ValueType and tracks
## its mode (CONSTANT vs EXPRESSION). Edits flow back to the GNParameter model.

## The parameter this row controls.
var param: GNParameter = null

## The owning GNNode (for dirty marking).
var owner_node: GNNode = null

## Network reference for expression editor autocomplete.
var network: GNNetwork = null

## Mode label showing C/E/B/X badge.
var _mode_btn: Button = null

## Name label.
var _name_label: Label = null

## The value control (varies by type).
var _control: Control = null

## Expression text field (shown in EXPRESSION mode).
var _expr_edit: LineEdit = null

## Container for the value control (swapped when mode changes).
var _value_container: HBoxContainer = null

## Track whether we're programmatically updating (avoid feedback loops).
var _updating: bool = false

# ─── Per-Component Expression UI (for Vector2, Vector3, Vector4, Color) ───────
## Per-component C/E toggle buttons.  indexed same as GNParameter.component_modes.
var _comp_mode_btns: Array[Button] = []

## Per-component spinboxes (constant mode widgets).
var _comp_spins: Array[SpinBox] = []

## Per-component expression LineEdits (expression mode widgets).
var _comp_expr_edits: Array[LineEdit] = []

## Whether this row uses per-component expression UI.
var _is_multi_component: bool = false

## The shared expression editor popup (created lazily).
var _expr_editor: GNExpressionEditor = null

## Scalar expand button for opening the expression editor.
var _expand_btn: Button = null

## Per-component expand buttons for opening the expression editor.
var _comp_expand_btns: Array[Button] = []

## Direct reference to the code TextEdit when inside a code-editor wrapper VBox.
var _code_edit: TextEdit = null

## Preloaded GNCodeEditor script (lazy reference avoids class_name resolution issues).
const _GNCodeEditorScript := preload("res://addons/gonodes/ui/gn_code_editor.gd")

## Lazily-created windowed code editor for Script/Shader params.
var _code_editor: Window = null

## Context popup for right-clicking the parameter name label.
var _param_context_menu: PopupMenu = null


# ═══════════════════════════════════════════════════════════════════════════════
# Construction
# ═══════════════════════════════════════════════════════════════════════════════

## Builds this row for the given parameter. Call once after creation.
func setup(p_param: GNParameter, p_owner: GNNode) -> void:
	param = p_param
	owner_node = p_owner
	_is_multi_component = param.is_multi_component()

	size_flags_horizontal = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)

	if not _is_multi_component:
		# ── Scalar parameter: single C/E button, value control, expression edit ──
		_mode_btn = Button.new()
		_mode_btn.custom_minimum_size = Vector2(24, 24)
		_mode_btn.tooltip_text = "Click to toggle CONSTANT / EXPRESSION mode"
		_mode_btn.pressed.connect(_on_mode_toggle)
		add_child(_mode_btn)

	# Parameter name label
	_name_label = Label.new()
	_name_label.text = param.label if not param.label.is_empty() else param.param_name
	_name_label.custom_minimum_size = Vector2(100, 0)
	_name_label.size_flags_horizontal = 0
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if not param.description.is_empty():
		_name_label.tooltip_text = param.description
	_name_label.gui_input.connect(_on_name_label_input)
	add_child(_name_label)

	# Value container — holds either the value control or the expression editor
	_value_container = HBoxContainer.new()
	_value_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_value_container.add_theme_constant_override("separation", 2)
	add_child(_value_container)

	if _is_multi_component:
		# ── Multi-component: per-component rows with individual C/E toggles ──
		_build_multi_component_ui()
	else:
		# Build the appropriate value control
		_control = _create_value_control()
		if _control:
			_value_container.add_child(_control)

		# Build expression editor (hidden by default)
		_expr_edit = LineEdit.new()
		_expr_edit.placeholder_text = "expression…"
		_expr_edit.size_flags_horizontal = SIZE_EXPAND_FILL
		_expr_edit.add_theme_font_size_override("font_size", 11)
		_expr_edit.text = param.expression
		_expr_edit.text_submitted.connect(_on_expression_submitted)
		_expr_edit.focus_exited.connect(_on_expression_focus_lost)
		_expr_edit.visible = false
		_value_container.add_child(_expr_edit)

		# Expand button to open multi-line expression editor
		_expand_btn = Button.new()
		_expand_btn.text = "\u2197"  # ↗
		_expand_btn.tooltip_text = "Open multi-line expression editor"
		_expand_btn.custom_minimum_size = Vector2(24, 24)
		_expand_btn.add_theme_font_size_override("font_size", 12)
		_expand_btn.flat = true
		_expand_btn.visible = false
		_expand_btn.pressed.connect(func() -> void: _open_expression_editor(-1))
		_value_container.add_child(_expand_btn)

	# Wire parameter signals for external updates
	param.value_changed.connect(_on_param_value_changed)
	param.mode_changed.connect(_on_param_mode_changed)

	# Set initial state
	_update_mode_display()
	_update_value_display()


# ═══════════════════════════════════════════════════════════════════════════════
# Multi-Component UI Builder (TD/Houdini-style per-channel expressions)
# ═══════════════════════════════════════════════════════════════════════════════

## Builds per-component rows inside _value_container.
## Each component gets: [C/E button] [SpinBox] [LineEdit (hidden)]
## For Color params, an additional ColorPickerButton is shown for visual editing.
func _build_multi_component_ui() -> void:
	param._ensure_component_arrays()
	var count := param.get_component_count()
	var labels := param.get_component_labels()
	var is_color := param.value_type == GNParameter.ValueType.COLOR

	# Use a VBoxContainer so components stack vertically
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	_value_container.add_child(vbox)

	# If it's a color, add a picker at the top for quick visual editing
	if is_color:
		_control = _create_color_control()
		vbox.add_child(_control)

	for i in range(count):
		var row := HBoxContainer.new()
		row.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 2)

		# Per-component C/E toggle
		var mode_btn := Button.new()
		mode_btn.custom_minimum_size = Vector2(22, 22)
		mode_btn.add_theme_font_size_override("font_size", 10)
		mode_btn.tooltip_text = "Toggle %s between CONSTANT / EXPRESSION" % labels[i]
		var comp_idx := i  # capture for lambda
		mode_btn.pressed.connect(func() -> void: _on_comp_mode_toggle(comp_idx))
		row.add_child(mode_btn)
		_comp_mode_btns.append(mode_btn)

		# Component label
		var comp_label := Label.new()
		comp_label.text = labels[i]
		comp_label.custom_minimum_size = Vector2(16, 0)
		comp_label.add_theme_font_size_override("font_size", 11)
		comp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		row.add_child(comp_label)

		# SpinBox (visible in constant mode)
		var spin := SpinBox.new()
		if is_color:
			spin.min_value = 0.0
			spin.max_value = 1.0
			spin.step = 0.01
		else:
			spin.min_value = -9999
			spin.max_value = 9999
			spin.step = param.step
		spin.value = param.get_component_value(i)
		spin.size_flags_horizontal = SIZE_EXPAND_FILL
		var spin_idx := i
		spin.value_changed.connect(func(val: float) -> void: _on_comp_spin_changed(spin_idx, val))
		row.add_child(spin)
		_comp_spins.append(spin)

		# Expression LineEdit (visible in expression mode)
		var expr_edit := LineEdit.new()
		expr_edit.placeholder_text = "%s expr…" % labels[i]
		expr_edit.size_flags_horizontal = SIZE_EXPAND_FILL
		expr_edit.add_theme_font_size_override("font_size", 11)
		expr_edit.visible = false
		var expr_idx := i
		expr_edit.text_submitted.connect(func(text: String) -> void: _on_comp_expr_submitted(expr_idx, text))
		expr_edit.focus_exited.connect(func() -> void: _on_comp_expr_focus_lost(expr_idx))
		row.add_child(expr_edit)
		_comp_expr_edits.append(expr_edit)

		# Per-component expand button for multi-line editor
		var expand_btn := Button.new()
		expand_btn.text = "\u2197"  # \u2197
		expand_btn.tooltip_text = "Open multi-line expression editor for %s" % labels[i]
		expand_btn.custom_minimum_size = Vector2(22, 22)
		expand_btn.add_theme_font_size_override("font_size", 11)
		expand_btn.flat = true
		expand_btn.visible = false
		var expand_idx := i
		expand_btn.pressed.connect(func() -> void: _open_expression_editor(expand_idx))
		row.add_child(expand_btn)
		_comp_expand_btns.append(expand_btn)

		vbox.add_child(row)

	# Restore any existing per-component expression state
	_update_comp_mode_displays()


# ═══════════════════════════════════════════════════════════════════════════════
# Value Control Factory
# ═══════════════════════════════════════════════════════════════════════════════

## Creates the appropriate UI control based on the parameter's ValueType.
func _create_value_control() -> Control:
	match param.value_type:
		GNParameter.ValueType.FLOAT:
			return _create_float_control()
		GNParameter.ValueType.INT:
			return _create_int_control()
		GNParameter.ValueType.BOOL:
			return _create_bool_control()
		GNParameter.ValueType.STRING:
			return _create_string_control()
		GNParameter.ValueType.ENUM:
			return _create_enum_control()
		GNParameter.ValueType.COLOR:
			return _create_color_control()
		GNParameter.ValueType.VECTOR2, GNParameter.ValueType.VECTOR2I:
			return _create_vector2_control()
		GNParameter.ValueType.FILE:
			return _create_file_control()
		_:
			var lbl := Label.new()
			lbl.text = str(param.value)
			return lbl


func _create_float_control() -> Control:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 4)

	var slider := HSlider.new()
	slider.min_value = param.min_value if param.min_value != null else 0.0
	slider.max_value = param.max_value if param.max_value != null else 10.0
	slider.step = param.step
	slider.value = float(param.value)
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(80, 0)
	slider.value_changed.connect(_on_float_slider_changed)
	hbox.add_child(slider)

	var spinbox := SpinBox.new()
	spinbox.min_value = slider.min_value
	spinbox.max_value = slider.max_value
	spinbox.step = param.step
	spinbox.value = float(param.value)
	spinbox.custom_minimum_size = Vector2(70, 0)
	spinbox.value_changed.connect(_on_float_spinbox_changed)
	hbox.add_child(spinbox)

	return hbox


func _create_int_control() -> Control:
	var spinbox := SpinBox.new()
	spinbox.min_value = param.min_value if param.min_value != null else 0
	spinbox.max_value = param.max_value if param.max_value != null else 100
	spinbox.step = 1
	spinbox.value = int(param.value)
	spinbox.size_flags_horizontal = SIZE_EXPAND_FILL
	spinbox.value_changed.connect(_on_int_changed)
	return spinbox


func _create_bool_control() -> Control:
	var cb := CheckBox.new()
	cb.button_pressed = bool(param.value)
	cb.text = "On" if cb.button_pressed else "Off"
	cb.toggled.connect(_on_bool_changed)
	return cb


func _create_string_control() -> Control:
	var edit := TextEdit.new()
	edit.text = str(param.value)
	edit.size_flags_horizontal = SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 80)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.scroll_fit_content_height = false
	edit.focus_exited.connect(_on_string_focus_lost.bind(edit))

	# If this is a code param (Script operators or CustomShaderTOP), add Edit ↗ button
	if _is_code_editor_param():
		_code_edit = edit
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 2)

		# "Edit ↗" opens the full windowed code editor (presets, highlighting, etc.)
		var edit_btn := Button.new()
		edit_btn.text = "Edit \u2197"
		edit_btn.tooltip_text = "Open full code editor (syntax highlighting, presets, Ctrl+Enter)"
		edit_btn.custom_minimum_size = Vector2(60, 26)
		edit_btn.pressed.connect(_open_code_editor)
		vbox.add_child(edit_btn)
		vbox.add_child(edit)
		return vbox

	return edit


## Returns true if this row represents a code parameter that should get the
## windowed code-editor UI:  "code" on Script operators, or "shader_code" on
## CustomShaderTOP (node_type == "glsl").
func _is_code_editor_param() -> bool:
	if owner_node == null or param == null:
		return false
	if param.param_name == "code" and owner_node.node_type.begins_with("script"):
		return true
	if param.param_name == "shader_code":
		return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# Windowed Code Editor
# ═══════════════════════════════════════════════════════════════════════════════

## Lazily creates (or re-opens) the windowed GNCodeEditor for this param.
func _open_code_editor() -> void:
	if _code_editor == null:
		_code_editor = _GNCodeEditorScript.new()
		add_child(_code_editor)
		_code_editor.code_committed.connect(_on_code_editor_committed)
	_code_editor.open(owner_node, param.param_name)


## Handles confirmed code from the windowed editor — applies it to the param
## and syncs the inline TextEdit.
func _on_code_editor_committed(text: String, _param_name: String) -> void:
	param.set_value(text)
	if _code_edit != null:
		_code_edit.text = text
	if owner_node:
		owner_node.mark_dirty()



func _create_enum_control() -> Control:
	var option := OptionButton.new()
	for i in range(param.enum_options.size()):
		option.add_item(param.enum_options[i], i)
	option.selected = int(param.value)
	option.size_flags_horizontal = SIZE_EXPAND_FILL
	option.item_selected.connect(_on_enum_changed)
	return option


func _create_color_control() -> Control:
	var picker := ColorPickerButton.new()
	picker.color = param.value if param.value is Color else Color.WHITE
	picker.custom_minimum_size = Vector2(60, 24)
	picker.edit_alpha = true
	picker.color_changed.connect(_on_color_changed)
	return picker


func _create_vector2_control() -> Control:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 4)

	var vec_val = param.value
	var x_val: float = vec_val.x if vec_val else 0.0
	var y_val: float = vec_val.y if vec_val else 0.0

	var x_spin := SpinBox.new()
	x_spin.prefix = "X"
	x_spin.min_value = -9999
	x_spin.max_value = 9999
	x_spin.step = param.step
	x_spin.value = x_val
	x_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	x_spin.value_changed.connect(_on_vector2_x_changed)
	hbox.add_child(x_spin)

	var y_spin := SpinBox.new()
	y_spin.prefix = "Y"
	y_spin.min_value = -9999
	y_spin.max_value = 9999
	y_spin.step = param.step
	y_spin.value = y_val
	y_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	y_spin.value_changed.connect(_on_vector2_y_changed)
	hbox.add_child(y_spin)

	return hbox


func _create_file_control() -> Control:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 4)

	var option := OptionButton.new()
	option.size_flags_horizontal = SIZE_EXPAND_FILL
	option.clip_text = true
	option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	option.tooltip_text = "Select a file from the project or bundled resources"
	hbox.add_child(option)

	# Populate with matching files from all tiers
	_populate_file_dropdown(option)

	# Connect selection
	option.item_selected.connect(_on_file_option_selected)

	# Browse button — opens native file dialog for Tier 3 (absolute) paths
	var browse_btn := Button.new()
	browse_btn.text = "…"
	browse_btn.custom_minimum_size = Vector2(28, 0)
	browse_btn.tooltip_text = "Browse filesystem for a file"
	browse_btn.pressed.connect(func() -> void:
		_open_file_browse_dialog(option)
	)
	hbox.add_child(browse_btn)

	# Refresh button to rescan project files
	var refresh_btn := Button.new()
	refresh_btn.text = "↻"
	refresh_btn.custom_minimum_size = Vector2(28, 0)
	refresh_btn.tooltip_text = "Rescan for matching files"
	refresh_btn.pressed.connect(func() -> void:
		_populate_file_dropdown(option)
	)
	hbox.add_child(refresh_btn)

	# Clear button
	var clear_btn := Button.new()
	clear_btn.text = "X"
	clear_btn.custom_minimum_size = Vector2(24, 0)
	clear_btn.tooltip_text = "Clear file selection"
	clear_btn.pressed.connect(_on_file_clear_pressed)
	hbox.add_child(clear_btn)

	return hbox


## Populates the OptionButton dropdown with files from all tiers:
## Tier 1 (bundled res://), Tier 2 (project folder), and any Tier 3 current value.
func _populate_file_dropdown(option: OptionButton) -> void:
	option.clear()
	option.add_item("(none)", 0)
	option.set_item_metadata(0, "")

	# Collect matching extensions
	var extensions: Array[String] = []
	for f in param.file_filters:
		var ext := f.trim_prefix("*.")
		if not ext.is_empty():
			extensions.append(ext.to_lower())

	var item_idx := 1
	var current_path: String = str(param.value)
	var selected_idx := 0

	# ── Tier 1: Bundled (res://) ──
	var bundled_files := GNResourceLoader.scan_directory("res://", extensions)
	bundled_files.sort()
	if not bundled_files.is_empty():
		option.add_separator("── Bundled ──")
		item_idx += 1
		for file_path in bundled_files:
			var display := file_path.trim_prefix("res://")
			option.add_item(display, item_idx)
			option.set_item_metadata(item_idx, file_path)
			option.set_item_tooltip(item_idx, file_path)
			if file_path == current_path:
				selected_idx = item_idx
			item_idx += 1

	# ── Tier 2: Project folder ──
	var proj_dir: String = owner_node.project_dir if owner_node != null else ""
	if not proj_dir.is_empty():
		var project_files := GNResourceLoader.scan_directory(proj_dir, extensions)
		project_files.sort()
		if not project_files.is_empty():
			option.add_separator("── Project ──")
			item_idx += 1
			for abs_path in project_files:
				var proj_path := GNResourceLoader.to_project_relative(abs_path, proj_dir)
				var display := proj_path.trim_prefix(GNResourceLoader.PROJECT_PREFIX)
				option.add_item(display, item_idx)
				option.set_item_metadata(item_idx, proj_path)
				option.set_item_tooltip(item_idx, abs_path)
				if proj_path == current_path or abs_path == current_path:
					selected_idx = item_idx
				item_idx += 1

	# ── Tier 3: If current value is an absolute path not in lists above, add it ──
	if selected_idx == 0 and not current_path.is_empty():
		var tier := GNResourceLoader.classify(current_path)
		if tier == GNResourceLoader.PathTier.ABSOLUTE:
			option.add_separator("── External ──")
			item_idx += 1
			var display := current_path.get_file()
			option.add_item("⚠ " + display, item_idx)
			option.set_item_metadata(item_idx, current_path)
			option.set_item_tooltip(item_idx, "Absolute path (not portable): " + current_path)
			selected_idx = item_idx

	option.selected = selected_idx


## Opens a native file dialog for browsing the filesystem (Tier 3).
func _open_file_browse_dialog(option: OptionButton) -> void:
	var dialog := FileDialog.new()
	dialog.title = "Browse for %s" % param.label
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	if not param.file_filters.is_empty():
		dialog.filters = param.file_filters
	dialog.min_size = Vector2i(700, 500)

	dialog.file_selected.connect(func(path: String) -> void:
		# Convert to project-relative if inside project folder
		var proj_dir: String = owner_node.project_dir if owner_node != null else ""
		var saveable := GNResourceLoader.to_saveable(path, proj_dir)
		param.set_value(saveable)
		_populate_file_dropdown(option)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	# Add to a top-level node so it displays
	var root := get_tree().root if get_tree() != null else null
	if root != null:
		root.add_child(dialog)
	else:
		add_child(dialog)
	dialog.popup_centered()


# ═══════════════════════════════════════════════════════════════════════════════
# Value Change Handlers — UI → Model
# ═══════════════════════════════════════════════════════════════════════════════

func _on_float_slider_changed(val: float) -> void:
	if _updating:
		return
	_updating = true
	param.set_value(val)
	# Sync spinbox
	var hbox := _control as HBoxContainer
	if hbox and hbox.get_child_count() > 1:
		var spinbox: SpinBox = hbox.get_child(1) as SpinBox
		if spinbox:
			spinbox.value = val
	_updating = false


func _on_float_spinbox_changed(val: float) -> void:
	if _updating:
		return
	_updating = true
	param.set_value(val)
	# Sync slider
	var hbox := _control as HBoxContainer
	if hbox and hbox.get_child_count() > 0:
		var slider: HSlider = hbox.get_child(0) as HSlider
		if slider:
			slider.value = val
	_updating = false


func _on_int_changed(val: float) -> void:
	if _updating:
		return
	param.set_value(int(val))


func _on_bool_changed(pressed: bool) -> void:
	if _updating:
		return
	param.set_value(pressed)
	var cb := _control as CheckBox
	if cb:
		cb.text = "On" if pressed else "Off"


func _on_string_changed(text: String) -> void:
	if _updating:
		return
	param.set_value(text)


## Called when the TextEdit for a string parameter loses focus — commits the value.
func _on_string_focus_lost(edit: TextEdit) -> void:
	if _updating:
		return
	var new_text := edit.text
	if new_text != str(param.value):
		param.set_value(new_text)


func _on_enum_changed(idx: int) -> void:
	if _updating:
		return
	param.set_value(idx)


func _on_color_changed(color: Color) -> void:
	if _updating:
		return
	param.set_value(color)


func _on_vector2_x_changed(val: float) -> void:
	if _updating:
		return
	var current = param.value
	if param.value_type == GNParameter.ValueType.VECTOR2I:
		param.set_value(Vector2i(int(val), current.y))
	else:
		param.set_value(Vector2(val, current.y))


func _on_vector2_y_changed(val: float) -> void:
	if _updating:
		return
	var current = param.value
	if param.value_type == GNParameter.ValueType.VECTOR2I:
		param.set_value(Vector2i(current.x, int(val)))
	else:
		param.set_value(Vector2(current.x, val))


func _on_file_option_selected(idx: int) -> void:
	if _updating:
		return
	var hbox := _control as HBoxContainer
	if hbox == null or hbox.get_child_count() < 1:
		return
	var option: OptionButton = hbox.get_child(0) as OptionButton
	if option == null:
		return
	var path: String = option.get_item_metadata(idx)
	param.set_value(path)


func _on_file_clear_pressed() -> void:
	param.set_value("")
	# Reset dropdown to "(none)"
	var hbox := _control as HBoxContainer
	if hbox and hbox.get_child_count() >= 1:
		var option: OptionButton = hbox.get_child(0) as OptionButton
		if option:
			option.selected = 0


# ═══════════════════════════════════════════════════════════════════════════════
# Expression Handling
# ═══════════════════════════════════════════════════════════════════════════════

func _on_expression_submitted(text: String) -> void:
	_apply_expression_text(text)


func _on_expression_focus_lost() -> void:
	if _expr_edit and _expr_edit.visible:
		_apply_expression_text(_expr_edit.text)


func _apply_expression_text(text: String) -> void:
	if text.strip_edges().is_empty():
		# Empty expression → revert to constant mode
		param.set_constant()
	else:
		if text != param.expression:
			param.set_expression(text)
	_update_mode_display()


# ═══════════════════════════════════════════════════════════════════════════════
# Per-Component Expression Handling (Vector2, Vector3, Vector4, Color)
# ═══════════════════════════════════════════════════════════════════════════════

## Toggles a single component between CONSTANT and EXPRESSION mode.
func _on_comp_mode_toggle(idx: int) -> void:
	if param.component_modes[idx] == GNParameter.Mode.CONSTANT:
		# Switch to expression mode
		var expr_text: String = param.component_expressions[idx]
		_comp_expr_edits[idx].text = expr_text
		param.set_component_expression(idx, expr_text)
	else:
		# Switch back to constant
		param.set_component_constant(idx)
	_update_comp_mode_display(idx)


## Called when a per-component spinbox changes.
func _on_comp_spin_changed(idx: int, val: float) -> void:
	if _updating:
		return
	param.set_component_value(idx, val)


## Called when a per-component expression is submitted.
func _on_comp_expr_submitted(idx: int, text: String) -> void:
	_apply_comp_expression(idx, text)


## Called when a per-component expression field loses focus.
func _on_comp_expr_focus_lost(idx: int) -> void:
	if idx < _comp_expr_edits.size() and _comp_expr_edits[idx].visible:
		_apply_comp_expression(idx, _comp_expr_edits[idx].text)


## Applies/compiles a per-component expression (or reverts to constant if empty).
func _apply_comp_expression(idx: int, text: String) -> void:
	if text.strip_edges().is_empty():
		param.set_component_constant(idx)
	else:
		if text != param.component_expressions[idx]:
			param.set_component_expression(idx, text)
	_update_comp_mode_display(idx)


## Updates the C/E button and spin/expr visibility for all components.
func _update_comp_mode_displays() -> void:
	for i in range(param.get_component_count()):
		_update_comp_mode_display(i)


## Updates the C/E button and spin/expr visibility for a single component.
func _update_comp_mode_display(idx: int) -> void:
	if idx >= _comp_mode_btns.size():
		return
	var btn := _comp_mode_btns[idx]
	var spin := _comp_spins[idx]
	var expr_edit := _comp_expr_edits[idx]
	var comp_mode: int = param.component_modes[idx]

	if comp_mode == GNParameter.Mode.EXPRESSION:
		btn.text = "E"
		btn.modulate = Color(0.8, 0.6, 0.2)  # Orange
		spin.visible = false
		expr_edit.visible = true
		if not expr_edit.has_focus():
			expr_edit.text = param.component_expressions[idx]
		# Error state
		if idx < param.component_expression_errors.size():
			var err: String = param.component_expression_errors[idx]
			if not err.is_empty():
				expr_edit.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
				expr_edit.tooltip_text = err
			else:
				expr_edit.remove_theme_color_override("font_color")
				expr_edit.tooltip_text = ""
		if idx < _comp_expand_btns.size():
			_comp_expand_btns[idx].visible = true
	else:
		btn.text = "C"
		btn.modulate = Color(0.5, 0.8, 0.5)  # Green
		spin.visible = true
		expr_edit.visible = false
		if idx < _comp_expand_btns.size():
			_comp_expand_btns[idx].visible = false


## Updates per-component expression error indicators (called per-cook).
func _update_comp_expression_status() -> void:
	for i in range(mini(_comp_expr_edits.size(), param.component_expression_errors.size())):
		var expr_edit := _comp_expr_edits[i]
		if not expr_edit.visible:
			continue
		var err: String = param.component_expression_errors[i]
		if not err.is_empty():
			expr_edit.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
			expr_edit.tooltip_text = err
		else:
			expr_edit.remove_theme_color_override("font_color")
			# Show per-component profiling info
			if i < param.component_expression_eval_usec.size() and \
					param.component_expression_eval_usec[i] > 0.0:
				expr_edit.tooltip_text = "Eval: %.1f\u00b5s" % param.component_expression_eval_usec[i]
			else:
				expr_edit.tooltip_text = ""


## Syncs per-component spinbox values from the parameter model.
func _update_comp_value_display() -> void:
	if _updating:
		return
	_updating = true
	var count := mini(_comp_spins.size(), param.get_component_count())
	for i in range(count):
		if _comp_spins[i].visible:
			_comp_spins[i].value = param.get_component_value(i)
	_updating = false


# ═══════════════════════════════════════════════════════════════════════════════
# Mode Toggle
# ═══════════════════════════════════════════════════════════════════════════════

func _on_mode_toggle() -> void:
	if param.mode == GNParameter.Mode.CONSTANT:
		# Switch to expression mode
		_expr_edit.text = param.expression
		param.mode = GNParameter.Mode.EXPRESSION
	else:
		# Switch back to constant mode
		param.set_constant()
	_update_mode_display()


func _update_mode_display() -> void:
	if _is_multi_component:
		_update_comp_mode_displays()
		return
	if _mode_btn == null:
		return
	match param.mode:
		GNParameter.Mode.CONSTANT:
			_mode_btn.text = "C"
			_mode_btn.modulate = Color(0.5, 0.8, 0.5)  # Green tint
			if _control:
				_control.visible = true
			_expr_edit.visible = false
			_set_expand_btn_visible(false)
		GNParameter.Mode.EXPRESSION:
			_mode_btn.text = "E"
			_mode_btn.modulate = Color(0.8, 0.6, 0.2)  # Orange tint
			if _control:
				_control.visible = false
			_expr_edit.visible = true
			_set_expand_btn_visible(true)
			# Only set text if the user is NOT currently editing
			if not _expr_edit.has_focus():
				_expr_edit.text = param.expression
			# Show error state
			if not param.expression_error.is_empty():
				_expr_edit.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
				_expr_edit.tooltip_text = param.expression_error
			else:
				_expr_edit.remove_theme_color_override("font_color")
				_expr_edit.tooltip_text = ""
		GNParameter.Mode.BIND:
			_mode_btn.text = "B"
			_mode_btn.modulate = Color(0.4, 0.6, 0.9)  # Blue tint
		GNParameter.Mode.EXPORT:
			_mode_btn.text = "X"
			_mode_btn.modulate = Color(0.8, 0.3, 0.3)  # Red tint

## Updates only the expression error/tooltip indicator (called per-cook).
## Does NOT touch _expr_edit.text to avoid destroying user edits.
func update_expression_status() -> void:
	if param == null:
		return
	if _is_multi_component:
		_update_comp_expression_status()
		return
	if _expr_edit == null:
		return
	if not param.expression_error.is_empty():
		_expr_edit.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		_expr_edit.tooltip_text = param.expression_error
	else:
		_expr_edit.remove_theme_color_override("font_color")
		# Show profiling info in tooltip when no error
		if param.expression_eval_usec > 0.0:
			_expr_edit.tooltip_text = "Eval: %.1f\u00b5s (avg: %.1f\u00b5s)" % [
				param.expression_eval_usec, param.expression_eval_avg_usec]
		else:
			_expr_edit.tooltip_text = ""

# ═══════════════════════════════════════════════════════════════════════════════
# Model → UI Sync (external updates reflected in controls)
# ═══════════════════════════════════════════════════════════════════════════════

func _on_param_value_changed(_p_name: String, _new_value: Variant) -> void:
	_update_value_display()


func _on_param_mode_changed(_p_name: String, _new_mode: GNParameter.Mode) -> void:
	_update_mode_display()


## Syncs the UI control to the parameter's current value.
func _update_value_display() -> void:
	if _is_multi_component:
		_update_comp_value_display()
		return
	if _control == null or _updating:
		return
	_updating = true

	match param.value_type:
		GNParameter.ValueType.FLOAT:
			var hbox := _control as HBoxContainer
			if hbox and hbox.get_child_count() >= 2:
				var slider: HSlider = hbox.get_child(0) as HSlider
				var spinbox: SpinBox = hbox.get_child(1) as SpinBox
				if slider:
					slider.value = float(param.get_resolved_value())
				if spinbox:
					spinbox.value = float(param.get_resolved_value())
		GNParameter.ValueType.INT:
			var spinbox := _control as SpinBox
			if spinbox:
				spinbox.value = int(param.get_resolved_value())
		GNParameter.ValueType.BOOL:
			var cb := _control as CheckBox
			if cb:
				cb.button_pressed = bool(param.get_resolved_value())
				cb.text = "On" if cb.button_pressed else "Off"
		GNParameter.ValueType.STRING:
			# _code_edit is set when this is a Script code param wrapped in VBox
			var edit: TextEdit = _code_edit if _code_edit != null else (_control as TextEdit)
			if edit:
				edit.text = str(param.get_resolved_value())
		GNParameter.ValueType.ENUM:
			var option := _control as OptionButton
			if option:
				option.selected = int(param.get_resolved_value())
		GNParameter.ValueType.COLOR:
			var picker := _control as ColorPickerButton
			if picker:
				var val = param.get_resolved_value()
				picker.color = val if val is Color else Color.WHITE
		GNParameter.ValueType.VECTOR2, GNParameter.ValueType.VECTOR2I:
			var hbox := _control as HBoxContainer
			if hbox and hbox.get_child_count() >= 2:
				var vec_val = param.get_resolved_value()
				var x_spin: SpinBox = hbox.get_child(0) as SpinBox
				var y_spin: SpinBox = hbox.get_child(1) as SpinBox
				if x_spin:
					x_spin.value = vec_val.x
				if y_spin:
					y_spin.value = vec_val.y
		GNParameter.ValueType.FILE:
			var hbox := _control as HBoxContainer
			if hbox and hbox.get_child_count() >= 1:
				var option: OptionButton = hbox.get_child(0) as OptionButton
				if option:
					var file_path: String = str(param.get_resolved_value())
					# Find the matching item in the dropdown
					var found := false
					for i in range(option.item_count):
						if option.get_item_metadata(i) == file_path:
							option.selected = i
							found = true
							break
					if not found and not file_path.is_empty():
						# File not in dropdown — rescan then try again
						_populate_file_dropdown(option)

	_updating = false


# ═══════════════════════════════════════════════════════════════════════════════
# Cleanup
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# Expression Editor Integration
# ═══════════════════════════════════════════════════════════════════════════════

## Shows or hides the scalar expand button.
func _set_expand_btn_visible(visible: bool) -> void:
	if _expand_btn != null:
		_expand_btn.visible = visible


## Opens the multi-line expression editor popup for a param or component.
## component_idx == -1 means the main (scalar) expression.
func _open_expression_editor(component_idx: int) -> void:
	# Lazily create the editor
	if _expr_editor == null:
		_expr_editor = GNExpressionEditor.new()
		add_child(_expr_editor)
		_expr_editor.expression_committed.connect(_on_expr_editor_committed)

	# Pass network reference for autocomplete
	_expr_editor.network = network

	# Open for the appropriate param/component
	_expr_editor.open(param, component_idx)


## Handles committed expression text from the multi-line editor.
func _on_expr_editor_committed(text: String, p_param: GNParameter, component_idx: int) -> void:
	if p_param != param:
		return

	if component_idx < 0:
		# Main scalar expression
		param.set_expression(text)
		if _expr_edit != null and not _expr_edit.has_focus():
			_expr_edit.text = text
		_update_mode_display()
	else:
		# Per-component expression
		if component_idx < param.component_expressions.size():
			param.component_expressions[component_idx] = text
			param.component_modes[component_idx] = GNParameter.Mode.EXPRESSION
			param._compile_component_expression(component_idx)
			_update_comp_mode_display(component_idx)

	# Mark the owner node dirty so the network recooks
	if owner_node:
		owner_node.dirty = true


## Disconnects signals when this row is removed.
func cleanup() -> void:
	if param:
		if param.value_changed.is_connected(_on_param_value_changed):
			param.value_changed.disconnect(_on_param_value_changed)
		if param.mode_changed.is_connected(_on_param_mode_changed):
			param.mode_changed.disconnect(_on_param_mode_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# Copy Parameter Reference (right-click on param name label)
# ═══════════════════════════════════════════════════════════════════════════════

## Handles right-click on the parameter name label to show copy reference popup.
func _on_name_label_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_RIGHT or not mb.pressed:
		return
	_show_param_context_menu(mb.global_position)


## Shows the parameter context menu with Copy Reference options.
func _show_param_context_menu(screen_pos: Vector2) -> void:
	if _param_context_menu == null:
		_param_context_menu = PopupMenu.new()
		_param_context_menu.id_pressed.connect(_on_param_context_id)
		add_child(_param_context_menu)
	_param_context_menu.clear()

	var node_id := owner_node.id if owner_node else ""
	var p_name := param.param_name if param else ""

	# Self-reference: par("param_name") — for use on the same node
	_param_context_menu.add_item('Copy Self Ref  par("%s")' % p_name, 0)

	# Cross-node reference: par("node_id", "param_name") — for use from other nodes
	_param_context_menu.add_item('Copy Cross Ref  par("%s", "%s")' % [node_id, p_name], 1)

	# op() style: op("node_id", "param_name")
	_param_context_menu.add_item('Copy op() Ref  op("%s", "%s")' % [node_id, p_name], 2)

	_param_context_menu.position = Vector2i(screen_pos)
	_param_context_menu.reset_size()
	_param_context_menu.popup()


## Handles param context menu item selection.
func _on_param_context_id(id: int) -> void:
	var node_id := owner_node.id if owner_node else ""
	var p_name := param.param_name if param else ""
	var ref: String = ""
	match id:
		0:
			ref = 'par("%s")' % p_name
		1:
			ref = 'par("%s", "%s")' % [node_id, p_name]
		2:
			ref = 'op("%s", "%s")' % [node_id, p_name]
	if not ref.is_empty():
		DisplayServer.clipboard_set(ref)
