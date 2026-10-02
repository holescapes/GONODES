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

## Shared undo/redo stack (set by GNParamInspector from the graph editor).
var undo_redo: UndoRedo = null

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

## Per-component numeric fields (constant mode widgets).
var _comp_fields: Array[GNNumericField] = []

## Per-component expression LineEdits (expression mode widgets).
var _comp_expr_edits: Array[LineEdit] = []

## Whether this row uses per-component expression UI.
var _is_multi_component: bool = false

## The VBox that wraps per-component rows (multi-component params only).
## Hidden when a whole-parameter expression overrides all components.
var _comp_vbox: VBoxContainer = null

## The shared expression editor popup (created lazily).
var _expr_editor: GNExpressionEditor = null

## Scalar expand button for opening the expression editor.
var _expand_btn: Button = null

## Per-component expand buttons for opening the expression editor.
var _comp_expand_btns: Array[Button] = []

## Per-component resolved-value labels (shown when component is in Expression mode).
var _comp_resolved_labels: Array[Label] = []

## Resolved-value label shown next to the expression LineEdit (scalar params).
var _resolved_label: Label = null

## Inline autocomplete panel for expression fields (Panel + ItemList, not a Window).
var _autocomplete_panel: Panel = null

## ItemList inside _autocomplete_panel.
var _autocomplete_list: ItemList = null

## The LineEdit that triggered the current autocomplete popup.
var _autocomplete_target: LineEdit = null

## "quote" replaces partial text inside a string arg; "general" replaces an identifier.
var _autocomplete_mode: String = ""

## Column where the replaceable fragment starts (general mode only).
var _autocomplete_replace_start: int = 0

## Highlighted row index while the LineEdit keeps keyboard focus.
var _autocomplete_highlight: int = 0

## Direct reference to the code TextEdit when inside a code-editor wrapper VBox.
var _code_edit: TextEdit = null


## Lazily-created windowed code editor for Script/Shader params.
var _code_editor: Window = null

## Context popup for right-clicking the parameter name label.
var _param_context_menu: PopupMenu = null

## Emitted when the user presses Tab in this row's value control.
## The inspector uses this to jump to the next row.
signal tab_next_requested()

## Emitted when the user presses Shift+Tab in this row's value control.
signal tab_prev_requested()


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

	# Master C/E mode button — all parameter types get one.
	# For scalar params it toggles whole-param mode; for multi-component params
	# it toggles a unified whole-parameter expression that overrides per-component values.
	_mode_btn = Button.new()
	_mode_btn.custom_minimum_size = Vector2(24, 24)
	_mode_btn.tooltip_text = "Click to toggle CONSTANT / EXPRESSION mode"
	_mode_btn.focus_mode = Control.FOCUS_NONE
	_mode_btn.pressed.connect(_on_mode_toggle)
	add_child(_mode_btn)

	# Parameter name label
	_name_label = Label.new()
	_name_label.text = param.label if not param.label.is_empty() else param.param_name
	_name_label.custom_minimum_size = Vector2(100, 0)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.size_flags_horizontal = 0
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	var tip_parts: PackedStringArray = PackedStringArray()
	tip_parts.append("expr: %s" % param.param_name)
	if not param.description.is_empty():
		tip_parts.append(param.description)
	_name_label.tooltip_text = "\n".join(tip_parts)
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
		_expr_edit.size_flags_stretch_ratio = 2.0
		_expr_edit.add_theme_font_size_override("font_size", 11)
		_expr_edit.text = param.expression
		_expr_edit.text_submitted.connect(_on_expression_submitted)
		_expr_edit.focus_exited.connect(_on_expression_focus_lost)
		_expr_edit.gui_input.connect(_on_expr_gui_input)
		_expr_edit.text_changed.connect(func(t: String) -> void: _on_expr_text_changed(_expr_edit))
		_expr_edit.visible = false
		_value_container.add_child(_expr_edit)

		# Resolved value preview (shown in expression mode: "→ 0.523")
		_resolved_label = Label.new()
		_resolved_label.size_flags_horizontal = SIZE_EXPAND_FILL
		_resolved_label.size_flags_stretch_ratio = 1.0
		_resolved_label.add_theme_font_size_override("font_size", 10)
		_resolved_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55))
		_resolved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_resolved_label.clip_text = true
		_resolved_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_resolved_label.visible = false
		_resolved_label.mouse_filter = Control.MOUSE_FILTER_PASS
		_value_container.add_child(_resolved_label)

		# Expand button to open multi-line expression editor
		_expand_btn = Button.new()
		_expand_btn.text = "\u2197"  # ↗
		_expand_btn.tooltip_text = "Open multi-line expression editor"
		_expand_btn.custom_minimum_size = Vector2(24, 24)
		_expand_btn.add_theme_font_size_override("font_size", 12)
		_expand_btn.flat = true
		_expand_btn.visible = false
		_expand_btn.focus_mode = Control.FOCUS_NONE
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
## Also creates whole-parameter expression controls (hidden by default) that
## override per-component rows when a unified expression is active.
func _build_multi_component_ui() -> void:
	param._ensure_component_arrays()
	var count := param.get_component_count()
	var labels := param.get_component_labels()
	var is_color := param.value_type == GNParameter.ValueType.COLOR

	# ── Whole-parameter expression UI (shown when a unified expression overrides
	#    all components, e.g. "Vector2(chop(...), chop(...))") ──
	_expr_edit = LineEdit.new()
	_expr_edit.placeholder_text = "expression…"
	_expr_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_expr_edit.add_theme_font_size_override("font_size", 11)
	_expr_edit.text = param.expression
	_expr_edit.text_submitted.connect(_on_expression_submitted)
	_expr_edit.focus_exited.connect(_on_expression_focus_lost)
	_expr_edit.gui_input.connect(_on_expr_gui_input)
	_expr_edit.text_changed.connect(func(t: String) -> void: _on_expr_text_changed(_expr_edit))
	_expr_edit.visible = false
	_value_container.add_child(_expr_edit)

	_resolved_label = Label.new()
	_resolved_label.custom_minimum_size = Vector2(60, 0)
	_resolved_label.add_theme_font_size_override("font_size", 10)
	_resolved_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55))
	_resolved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_resolved_label.clip_text = true
	_resolved_label.visible = false
	_resolved_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_value_container.add_child(_resolved_label)

	_expand_btn = Button.new()
	_expand_btn.text = "\u2197"  # ↗
	_expand_btn.tooltip_text = "Open multi-line expression editor"
	_expand_btn.custom_minimum_size = Vector2(24, 24)
	_expand_btn.add_theme_font_size_override("font_size", 12)
	_expand_btn.flat = true
	_expand_btn.visible = false
	_expand_btn.focus_mode = Control.FOCUS_NONE
	_expand_btn.pressed.connect(func() -> void: _open_expression_editor(-1))
	_value_container.add_child(_expand_btn)

	# ── Per-component UI (hidden when whole-param expression is active) ──
	_comp_vbox = VBoxContainer.new()
	_comp_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	_comp_vbox.add_theme_constant_override("separation", 2)
	_value_container.add_child(_comp_vbox)

	# If it's a color, add a picker at the top for quick visual editing
	if is_color:
		_control = _create_color_control()
		_comp_vbox.add_child(_control)

	for i in range(count):
		var row := HBoxContainer.new()
		row.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 2)

		# Per-component C/E toggle
		var mode_btn := Button.new()
		mode_btn.custom_minimum_size = Vector2(22, 22)
		mode_btn.add_theme_font_size_override("font_size", 10)
		mode_btn.tooltip_text = "Toggle %s between CONSTANT / EXPRESSION" % labels[i]
		mode_btn.focus_mode = Control.FOCUS_NONE
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

		# Numeric field (visible in constant mode) — use GNIntField for VECTOR2I
		var is_int_vec := param.value_type == GNParameter.ValueType.VECTOR2I
		var field: GNNumericField
		if is_int_vec:
			var ifield := GNIntField.new()
			ifield.min_value = null
			ifield.max_value = null
			ifield.value = int(param.get_component_value(i))
			ifield.default_value = int(_get_default_component(i))
			ifield.size_flags_horizontal = SIZE_EXPAND_FILL
			var field_idx_i := i
			ifield.value_changed.connect(func(val: int) -> void: _on_comp_field_changed(field_idx_i, float(val)))
			var tab_idx_i := i
			ifield.tab_requested.connect(func(fwd: bool) -> void: _on_comp_field_tab(tab_idx_i, fwd))
			field = ifield
		elif is_color:
			var ffield := GNFloatField.new()
			ffield.min_value = 0.0
			ffield.max_value = 1.0
			ffield.step = 0.01
			ffield.value = param.get_component_value(i)
			ffield.default_value = _get_default_component(i)
			ffield.size_flags_horizontal = SIZE_EXPAND_FILL
			var field_idx_c := i
			ffield.value_changed.connect(func(val: float) -> void: _on_comp_field_changed(field_idx_c, val))
			var tab_idx_c := i
			ffield.tab_requested.connect(func(fwd: bool) -> void: _on_comp_field_tab(tab_idx_c, fwd))
			field = ffield
		else:
			var ffield := GNFloatField.new()
			ffield.min_value = null
			ffield.max_value = null
			ffield.step = param.step
			ffield.value = param.get_component_value(i)
			ffield.default_value = _get_default_component(i)
			ffield.size_flags_horizontal = SIZE_EXPAND_FILL
			var field_idx_f := i
			ffield.value_changed.connect(func(val: float) -> void: _on_comp_field_changed(field_idx_f, val))
			var tab_idx_f := i
			ffield.tab_requested.connect(func(fwd: bool) -> void: _on_comp_field_tab(tab_idx_f, fwd))
			field = ffield
		row.add_child(field)
		_comp_fields.append(field)

		# Expression LineEdit (visible in expression mode)
		var expr_edit := LineEdit.new()
		expr_edit.placeholder_text = "%s expr…" % labels[i]
		expr_edit.size_flags_horizontal = SIZE_EXPAND_FILL
		expr_edit.add_theme_font_size_override("font_size", 11)
		expr_edit.visible = false
		var expr_idx := i
		expr_edit.text_submitted.connect(func(text: String) -> void: _on_comp_expr_submitted(expr_idx, text))
		expr_edit.focus_exited.connect(func() -> void: _on_comp_expr_focus_lost(expr_idx))
		var gui_idx := i
		expr_edit.gui_input.connect(func(ev: InputEvent) -> void: _on_comp_expr_gui_input(gui_idx, ev))
		expr_edit.text_changed.connect(func(t: String) -> void: _on_expr_text_changed(expr_edit))
		row.add_child(expr_edit)
		_comp_expr_edits.append(expr_edit)

		# Per-component resolved value label
		var comp_res_label := Label.new()
		comp_res_label.custom_minimum_size = Vector2(50, 0)
		comp_res_label.add_theme_font_size_override("font_size", 10)
		comp_res_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55))
		comp_res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		comp_res_label.clip_text = true
		comp_res_label.visible = false
		comp_res_label.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(comp_res_label)
		_comp_resolved_labels.append(comp_res_label)

		# Per-component expand button for multi-line editor
		var expand_btn := Button.new()
		expand_btn.text = "\u2197"  # \u2197
		expand_btn.tooltip_text = "Open multi-line expression editor for %s" % labels[i]
		expand_btn.custom_minimum_size = Vector2(22, 22)
		expand_btn.add_theme_font_size_override("font_size", 11)
		expand_btn.flat = true
		expand_btn.visible = false
		expand_btn.focus_mode = Control.FOCUS_NONE
		var expand_idx := i
		expand_btn.pressed.connect(func() -> void: _open_expression_editor(expand_idx))
		row.add_child(expand_btn)
		_comp_expand_btns.append(expand_btn)

		_comp_vbox.add_child(row)

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
		GNParameter.ValueType.VECTOR2:
			return _create_vector2_control()
		GNParameter.ValueType.VECTOR2I:
			return _create_vector2i_control()
		GNParameter.ValueType.FILE:
			return _create_file_control()
		GNParameter.ValueType.RAMP:
			return _create_ramp_control()
		_:
			var lbl := Label.new()
			lbl.text = str(param.value)
			return lbl


func _create_float_control() -> Control:
	var field := GNFloatField.new()
	field.value = float(param.value)
	field.min_value = param.min_value
	field.max_value = param.max_value
	field.step = param.step
	field.default_value = float(param.default_value)
	field.size_flags_horizontal = SIZE_EXPAND_FILL
	field.value_changed.connect(_on_float_field_changed)
	field.tab_requested.connect(_on_field_tab)
	return field


func _create_int_control() -> Control:
	var field := GNIntField.new()
	field.value = int(param.value)
	field.min_value = param.min_value
	field.max_value = param.max_value
	field.default_value = int(param.default_value)
	field.size_flags_horizontal = SIZE_EXPAND_FILL
	field.value_changed.connect(_on_int_field_changed)
	field.tab_requested.connect(_on_field_tab)
	return field


func _create_bool_control() -> Control:
	# Pulse params render as a momentary push-button instead of a checkbox
	if param.is_pulse:
		var btn := Button.new()
		btn.text = param.label
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		btn.pressed.connect(_on_pulse_pressed)
		return btn
	var cb := CheckBox.new()
	cb.button_pressed = bool(param.value)
	cb.text = "On" if cb.button_pressed else "Off"
	cb.toggled.connect(_on_bool_changed)
	return cb


func _create_string_control() -> Control:
	# Node-reference params get a filtered dropdown instead of a text area
	if param.node_ref_family >= -1:
		return _create_node_ref_control()

	# Code params keep a multi-line read-only preview plus the Edit ↗ button
	if _is_code_editor_param():
		var edit := TextEdit.new()
		edit.size_flags_horizontal = SIZE_EXPAND_FILL
		edit.custom_minimum_size = Vector2(0, 60)
		edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		edit.scroll_fit_content_height = false
		edit.editable = false
		edit.add_theme_color_override("font_readonly_color", Color(0.6, 0.6, 0.6, 0.7))
		_code_edit = edit
		_set_code_preview_text(str(param.value))

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 2)

		var edit_btn := Button.new()
		edit_btn.text = "Edit \u2197"
		edit_btn.tooltip_text = "Open full code editor (syntax highlighting, presets, Ctrl+Enter)"
		edit_btn.custom_minimum_size = Vector2(60, 26)
		edit_btn.pressed.connect(_open_code_editor)
		vbox.add_child(edit_btn)
		vbox.add_child(edit)
		return vbox

	# One-line strings (IP, OSC address, labels, etc.)
	var line := LineEdit.new()
	line.text = str(param.value)
	line.size_flags_horizontal = SIZE_EXPAND_FILL
	line.custom_minimum_size = Vector2(0, 28)
	if param.read_only:
		line.editable = false
		line.add_theme_color_override("font_uneditable_color", Color(0.7, 0.7, 0.7, 0.8))
	else:
		line.text_submitted.connect(_on_string_submitted)
		line.focus_exited.connect(_on_string_line_focus_lost.bind(line))
	return line


## Creates a dropdown (OptionButton) for node-reference string parameters.
## Lists only nodes whose family matches the param's node_ref_family filter
## (-1 = show all families).  Shows a warning icon if the current value
## points to a node of the wrong family.
func _create_node_ref_control() -> Control:
	var ob := OptionButton.new()
	ob.size_flags_horizontal = SIZE_EXPAND_FILL
	ob.custom_minimum_size = Vector2(0, 28)
	_keep_option_button_from_stretching(ob)
	ob.allow_reselect = true

	_populate_node_ref_dropdown(ob)

	# Select the current value
	var cur_val: String = str(param.value)
	var found := false
	for i in range(ob.item_count):
		if ob.get_item_metadata(i) == cur_val:
			ob.selected = i
			found = true
			break
	if not found and not cur_val.is_empty():
		# Value references a node that doesn't match filter — add it with warning
		ob.add_item("\u26a0 %s (wrong family)" % cur_val)
		ob.set_item_metadata(ob.item_count - 1, cur_val)
		ob.selected = ob.item_count - 1

	ob.item_selected.connect(_on_node_ref_selected.bind(ob))
	# Refresh list when dropdown is opened (nodes may have been added/removed)
	ob.pressed.connect(_populate_node_ref_dropdown.bind(ob))
	return ob


## Populates the OptionButton with matching node IDs from the network.
func _populate_node_ref_dropdown(ob: OptionButton) -> void:
	var cur_val: String = str(param.value)
	ob.clear()
	ob.add_item("(none)")
	ob.set_item_metadata(0, "")

	if network == null:
		return

	var ref_family: int = param.node_ref_family
	var own_id: String = owner_node.id if owner_node != null else ""
	var sorted_ids: Array = network.nodes.keys()
	sorted_ids.sort()

	for n_id in sorted_ids:
		if n_id == own_id:
			continue  # Don't list self
		var n: GNNode = network.nodes[n_id]
		if ref_family == -1 or n.family == ref_family:
			ob.add_item(n_id)
			ob.set_item_metadata(ob.item_count - 1, n_id)
		elif n_id == cur_val:
			# Current value points to a wrong-family node — show with warning
			var fam_name: String = GNFamily.FAMILY_NAMES.get(n.family, "?")
			ob.add_item("\u26a0 %s (%s)" % [n_id, fam_name])
			ob.set_item_metadata(ob.item_count - 1, n_id)

	# Re-select current value after repopulate
	for i in range(ob.item_count):
		if ob.get_item_metadata(i) == cur_val:
			ob.selected = i
			break


func _on_node_ref_selected(idx: int, ob: OptionButton) -> void:
	if _updating:
		return
	var new_val: String = ob.get_item_metadata(idx)
	if new_val != str(param.value):
		_set_value_with_undo(new_val)
		# Show warning if the selected node has the wrong family
		if not new_val.is_empty() and network != null and param.node_ref_family >= 0:
			var target: GNNode = network.nodes.get(new_val, null)
			if target != null and target.family != param.node_ref_family:
				var expected: String = GNFamily.FAMILY_NAMES.get(param.node_ref_family, "?")
				var actual: String = GNFamily.FAMILY_NAMES.get(target.family, "?")
				if owner_node != null:
					owner_node.node_warning = "Target '%s' is %s, expected %s" % [new_val, actual, expected]


## Returns true if this row represents a code parameter that should get the
## windowed code-editor UI. Core recognizes "code" on GDScriptSCRIPT,
## callback params on CallbackDAT, and "shader_code" on CustomShaderTOP.
## Extensions register additional code params via register_code_param().
func _is_code_editor_param() -> bool:
	if owner_node == null or param == null:
		return false
	# Extension-registered code params
	if _ext_code_params.has(param.param_name):
		return true
	# Core: GDScriptSCRIPT "code" param
	if param.param_name == "code" and owner_node.node_type == "script":
		return true
	# Core: CallbackDAT callback code params
	if owner_node.node_type == "callbackdat" and param.param_name in [
		"on_start", "on_cook", "on_value_change", "on_create"]:
		return true
	# Core: shader_code (CustomShaderTOP, ShaderMAT)
	if param.param_name == "shader_code":
		return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# Extension Code Param Registry
# ═══════════════════════════════════════════════════════════════════════════════

## Extension-registered code parameter names that should get the code editor UI.
## Extensions call register_code_param() from their boot script.
static var _ext_code_params: Dictionary = {}

## Register a parameter name as a code-editor-eligible param.
## The param row will show an "Edit \u2197" button for this param.
##
## Example (in gn_ext_isf boot.gd):
##   GNParamRow.register_code_param("isf_code")
static func register_code_param(param_name: String) -> void:
	_ext_code_params[param_name] = true


# ═══════════════════════════════════════════════════════════════════════════════
# Windowed Code Editor
# ═══════════════════════════════════════════════════════════════════════════════

## Lazily creates (or re-opens) the windowed GNCodeEditor for this param.
## If the owning node provides its own open_code_editor() (e.g. NativeSCRIPT,
## PythonSCRIPT), delegate to it so the specialised editor is used.
func _open_code_editor() -> void:
	if owner_node and owner_node.has_method("open_code_editor"):
		owner_node.open_code_editor()
		return
	if _code_editor == null:
		_code_editor = GNCodeEditor.new()
		add_child(_code_editor)
		_code_editor.code_committed.connect(_on_code_editor_committed)
	_code_editor.open(owner_node, param.param_name)


## Handles confirmed code from the windowed editor — applies it to the param
## and syncs the inline TextEdit.
func _on_code_editor_committed(text: String, _param_name: String) -> void:
	_set_value_with_undo(text)
	_set_code_preview_text(text)
	if owner_node:
		owner_node.mark_dirty()



func _create_enum_control() -> Control:
	var option := OptionButton.new()
	option.size_flags_horizontal = SIZE_EXPAND_FILL
	# Device names and other long items must not set the button's minimum
	# width. That width climbs through the inspector and the side panel
	# cannot shrink. The popup still lists the full strings.
	_keep_option_button_from_stretching(option)
	for i in range(param.enum_options.size()):
		option.add_item(param.enum_options[i], i)
	option.selected = int(param.value)
	option.item_selected.connect(_on_enum_changed)
	# Dynamic enum: refresh options every time the dropdown is about to open
	if param.dynamic_enum_callback.is_valid():
		option.get_popup().about_to_popup.connect(
			_on_dynamic_enum_refresh.bind(option))
		# Also refresh immediately on build so the label is correct on first display
		# and stale indices from a saved patch are resolved against the live device list.
		_on_dynamic_enum_refresh(option)
	return option


## Called just before the OptionButton popup opens, and also on initial build.
## Queries the dynamic callback for a fresh set of options and rebuilds the
## dropdown in-place. Preserves selection by device name when possible.
## Does NOT silently redirect to a different device if the saved name is missing --
## that is handled at the node level via refresh_dynamic_enums() on first cook.
func _on_dynamic_enum_refresh(option: OptionButton) -> void:
	if param == null or not param.dynamic_enum_callback.is_valid():
		return
	var fresh: PackedStringArray = param.dynamic_enum_callback.call()
	if fresh == param.enum_options:
		return
	var prev_idx: int = option.selected
	var prev_text: String = option.get_item_text(prev_idx) if prev_idx >= 0 and prev_idx < option.item_count else ""
	param.enum_options = fresh
	option.clear()
	for i in range(fresh.size()):
		option.add_item(fresh[i], i)
	# Try to preserve selection by name match
	var new_idx: int = -1
	if not prev_text.is_empty():
		for i in range(fresh.size()):
			if fresh[i] == prev_text:
				new_idx = i
				break
	if new_idx >= 0:
		option.selected = new_idx
		if new_idx != int(param.value):
			param.value = new_idx
			param.saved_enum_label = fresh[new_idx]  # Keep label in sync
			if owner_node != null:
				owner_node.mark_dirty()
	else:
		# Name not found -- keep index clamped to list bounds.
		# Do NOT redirect to a different device; node_warning is set by refresh_dynamic_enums().
		option.selected = mini(prev_idx, fresh.size() - 1)


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

	var x_field := GNFloatField.new()
	x_field.min_value = null
	x_field.max_value = null
	x_field.step = param.step
	x_field.value = x_val
	x_field.default_value = x_val
	x_field.suffix = "  X"
	x_field.size_flags_horizontal = SIZE_EXPAND_FILL
	x_field.value_changed.connect(_on_vector2_x_changed)
	hbox.add_child(x_field)

	var y_field := GNFloatField.new()
	y_field.min_value = null
	y_field.max_value = null
	y_field.step = param.step
	y_field.value = y_val
	y_field.default_value = y_val
	y_field.suffix = "  Y"
	y_field.size_flags_horizontal = SIZE_EXPAND_FILL
	y_field.value_changed.connect(_on_vector2_y_changed)
	hbox.add_child(y_field)

	return hbox


func _create_vector2i_control() -> Control:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 4)

	var vec_val = param.value
	var x_val: int = int(vec_val.x) if vec_val else 0
	var y_val: int = int(vec_val.y) if vec_val else 0

	var x_field := GNIntField.new()
	x_field.min_value = null
	x_field.max_value = null
	x_field.value = x_val
	x_field.default_value = x_val
	x_field.suffix = "  X"
	x_field.size_flags_horizontal = SIZE_EXPAND_FILL
	x_field.value_changed.connect(_on_vector2i_x_changed)
	hbox.add_child(x_field)

	var y_field := GNIntField.new()
	y_field.min_value = null
	y_field.max_value = null
	y_field.value = y_val
	y_field.default_value = y_val
	y_field.suffix = "  Y"
	y_field.size_flags_horizontal = SIZE_EXPAND_FILL
	y_field.value_changed.connect(_on_vector2i_y_changed)
	hbox.add_child(y_field)

	return hbox


## File lists can match hundreds of project files. Without a cap, PopupMenu
## grows to the parent window. A positive max height makes that menu scroll.
## Width stays uncapped (0).
const FILE_DROPDOWN_MAX_HEIGHT := 360


## Stops an OptionButton from adopting its longest (or selected) string as a
## minimum width. The inspector scroll does not scroll sideways, so that width
## becomes the side panel's minimum and the split cannot shrink.
func _keep_option_button_from_stretching(option: OptionButton) -> void:
	option.clip_text = true
	option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	option.fit_to_longest_item = false
	if option.custom_minimum_size.x < 80.0:
		option.custom_minimum_size.x = 80.0


func _create_file_control() -> Control:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 4)

	var option := OptionButton.new()
	option.size_flags_horizontal = SIZE_EXPAND_FILL
	_keep_option_button_from_stretching(option)
	option.get_popup().max_size = Vector2i(0, FILE_DROPDOWN_MAX_HEIGHT)
	option.tooltip_text = "Select a file from the project or bundled resources"
	hbox.add_child(option)

	# Show the current file only. The full project scan runs when the list opens.
	_show_current_file(option)
	option.get_popup().about_to_popup.connect(func() -> void:
		_populate_file_dropdown(option)
	)

	# Connect selection
	option.item_selected.connect(_on_file_option_selected)

	# Browse button — opens native file dialog for Tier 3 (absolute) paths
	var browse_btn := Button.new()
	browse_btn.text = "…"
	browse_btn.custom_minimum_size = Vector2(28, 0)
	browse_btn.tooltip_text = "Browse filesystem" if param.file_browse_mode != GNParameter.FileBrowseMode.OPEN_DIR else "Browse for folder"
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


## Creates a ramp/curve editor control for RAMP parameters.
func _create_ramp_control() -> Control:
	var ramp_editor := GNRampEditor.new()
	ramp_editor.size_flags_horizontal = SIZE_EXPAND_FILL
	ramp_editor.custom_minimum_size = Vector2(0, 100)
	# Initialize with current param value (Array of key dicts)
	var current_keys: Array = param.value if param.value is Array else []
	ramp_editor.set_keys(current_keys)
	# Wire change signal back to the parameter model
	ramp_editor.ramp_changed.connect(_on_ramp_changed)
	return ramp_editor


## Shows the current path without scanning the project. The scan is the hitch
## when a node with a file parameter is selected.
func _show_current_file(option: OptionButton) -> void:
	option.clear()
	option.add_item("(none)", 0)
	option.set_item_metadata(0, "")
	var current_path := ""
	if param != null:
		var resolved: Variant = param.get_resolved_value()
		current_path = str(resolved) if resolved != null else ""
	if current_path.is_empty() or current_path == "<null>":
		option.selected = 0
		return
	var display := current_path.get_file()
	if display.is_empty():
		display = current_path
	option.add_item(display, 1)
	option.set_item_metadata(1, current_path)
	option.set_item_tooltip(1, current_path)
	option.selected = 1


## Populates the OptionButton dropdown with files from all tiers:
## Patch Local (project folder beside the .gnpatch), Bundled (res://), and any
## Tier 3 current value.  Patch Local appears first so patch-adjacent files are
## easy to find, and those files are excluded from the Bundled section.
func _populate_file_dropdown(option: OptionButton) -> void:
	option.clear()
	option.add_item("(none)", 0)
	option.set_item_metadata(0, "")

	var item_idx := 1
	var current_path: String = str(param.value)
	var selected_idx := 0

	# Folder picker — no file scan; show current directory only.
	if param.file_browse_mode == GNParameter.FileBrowseMode.OPEN_DIR:
		if not current_path.is_empty():
			option.add_separator("── Folder ──")
			item_idx += 1
			option.add_item(current_path, item_idx)
			option.set_item_metadata(item_idx, current_path)
			option.set_item_tooltip(item_idx, current_path)
			selected_idx = item_idx
		option.selected = selected_idx
		return

	# Collect matching extensions
	var extensions: Array[String] = []
	for f in param.file_filters:
		var ext := f.trim_prefix("*.")
		if not ext.is_empty():
			extensions.append(ext.to_lower())

	# ── Patch Local: project folder beside the .gnpatch ──
	var proj_dir: String = owner_node.project_dir if owner_node != null else ""
	# Compute the res:// prefix that maps to project_dir so we can filter
	# those files out of the Bundled section below.
	var project_res_prefix := ""
	if not proj_dir.is_empty():
		var res_root := ProjectSettings.globalize_path("res://").replace("\\", "/")
		if not res_root.ends_with("/"):
			res_root += "/"
		var norm_proj := proj_dir.replace("\\", "/")
		if not norm_proj.ends_with("/"):
			norm_proj += "/"
		if norm_proj.begins_with(res_root):
			project_res_prefix = "res://" + norm_proj.substr(res_root.length())

		var project_files := GNResourceLoader.scan_directory(proj_dir, extensions)
		project_files.sort()
		if not project_files.is_empty():
			option.add_separator("── Patch Local ──")
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

	# ── Bundled (res://) — excluding files already shown in Patch Local ──
	var bundled_files := GNResourceLoader.scan_directory("res://", extensions)
	bundled_files.sort()
	if not bundled_files.is_empty():
		var added_bundled := false
		for file_path in bundled_files:
			if not project_res_prefix.is_empty() and file_path.begins_with(project_res_prefix):
				continue  # already listed under Patch Local
			if not added_bundled:
				option.add_separator("── Bundled ──")
				item_idx += 1
				added_bundled = true
			var display := file_path.trim_prefix("res://")
			option.add_item(display, item_idx)
			option.set_item_metadata(item_idx, file_path)
			option.set_item_tooltip(item_idx, file_path)
			if file_path == current_path:
				selected_idx = item_idx
			item_idx += 1

	# ── External / save path not in either list above ──
	if selected_idx == 0 and not current_path.is_empty():
		var tier := GNResourceLoader.classify(current_path)
		if tier == GNResourceLoader.PathTier.ABSOLUTE \
				or param.file_browse_mode == GNParameter.FileBrowseMode.SAVE_FILE \
				or current_path.begins_with("user://"):
			option.add_separator("── External ──")
			item_idx += 1
			var display := current_path.get_file()
			if display.is_empty():
				display = current_path
			option.add_item("⚠ " + display, item_idx)
			option.set_item_metadata(item_idx, current_path)
			option.set_item_tooltip(item_idx, "Path: " + current_path)
			selected_idx = item_idx

	option.selected = selected_idx


## Opens a native file dialog for browsing the filesystem (Tier 3).
func _open_file_browse_dialog(option: OptionButton) -> void:
	var dialog := FileDialog.new()
	dialog.title = "Browse for %s" % param.label
	match param.file_browse_mode:
		GNParameter.FileBrowseMode.SAVE_FILE:
			dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		GNParameter.FileBrowseMode.OPEN_DIR:
			dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_:
			dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	if not param.file_filters.is_empty() \
			and param.file_browse_mode != GNParameter.FileBrowseMode.OPEN_DIR:
		dialog.filters = param.file_filters
	dialog.min_size = Vector2i(700, 500)

	var _apply_picked := func(path: String) -> void:
		var proj_dir: String = owner_node.project_dir if owner_node != null else ""
		var saveable := GNResourceLoader.to_saveable(path, proj_dir)
		_set_value_with_undo(saveable)
		_populate_file_dropdown(option)
		dialog.queue_free()

	dialog.file_selected.connect(_apply_picked)
	dialog.dir_selected.connect(_apply_picked)
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

## Records a parameter value change in the undo stack (if available) then applies it.
## Uses merge mode so rapid drag edits collapse into a single undo step.
func _set_value_with_undo(new_value: Variant, mergeable: bool = false) -> void:
	if undo_redo == null:
		param.set_value(new_value)
		return
	var old_value: Variant = param.value
	var p := param  # capture for lambdas
	undo_redo.create_action("Set %s.%s" % [owner_node.id if owner_node else "?", param.param_name],
		UndoRedo.MERGE_ALL if mergeable else UndoRedo.MERGE_DISABLE)
	undo_redo.add_do_method(Callable(p, "set_value").bind(new_value))
	undo_redo.add_undo_method(Callable(p, "set_value").bind(old_value))
	undo_redo.commit_action()
	if network != null:
		network.notify_state_changed()


## Snapshot-based undo for complex changes (mode toggles, expressions, bulk ops).
## Takes a before snapshot, runs the callable, then records a restore-based undo.
func _do_with_snapshot_undo(action_name: String, callable: Callable) -> void:
	if undo_redo == null:
		callable.call()
		return
	var before: Dictionary = param.to_dict()
	callable.call()
	var after: Dictionary = param.to_dict()
	var p := param
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(Callable(p, "restore_snapshot").bind(after))
	undo_redo.add_undo_method(Callable(p, "restore_snapshot").bind(before))
	undo_redo.commit_action(false)  # already applied
	if network != null:
		network.notify_state_changed()


func _on_float_field_changed(val: float) -> void:
	if _updating:
		return
	_set_value_with_undo(val, true)


func _on_int_field_changed(val: int) -> void:
	if _updating:
		return
	_set_value_with_undo(val, true)


func _on_pulse_pressed() -> void:
	# Pulse buttons are one-shot actions — never suppressed by _updating.
	param.set_value(true)


func _on_bool_changed(pressed: bool) -> void:
	if _updating:
		return
	_set_value_with_undo(pressed)
	var cb := _control as CheckBox
	if cb:
		cb.text = "On" if pressed else "Off"


func _on_string_changed(text: String) -> void:
	if _updating:
		return
	_set_value_with_undo(text, true)


## Commits a string parameter value when it changed.
func _commit_string_value(new_text: String) -> void:
	if _updating:
		return
	if new_text != str(param.value):
		_set_value_with_undo(new_text)


## Enter in a one-line string field — commit immediately and release focus.
func _on_string_submitted(text: String) -> void:
	_commit_string_value(text)
	var line_edit := _control as LineEdit
	if line_edit:
		line_edit.release_focus()


## Click-away / Tab away from a one-line string field — commit on focus loss.
func _on_string_line_focus_lost(edit: LineEdit) -> void:
	_commit_string_value(edit.text)


## Sets the read-only code preview TextEdit to a truncated multi-line snippet.
func _set_code_preview_text(full_text: String) -> void:
	if _code_edit == null:
		return
	var preview_lines := full_text.split("\n", true, 6)
	if preview_lines.size() > 5:
		preview_lines.resize(5)
		preview_lines.append("…")
	_code_edit.text = "\n".join(preview_lines)


func _on_enum_changed(idx: int) -> void:
	if _updating:
		return
	# Save the human-readable label alongside the index so patches can do
	# name-based device resolution across sessions (device order may change).
	if param != null and param.value_type == GNParameter.ValueType.ENUM \
			and idx >= 0 and idx < param.enum_options.size():
		param.saved_enum_label = param.enum_options[idx]
	_set_value_with_undo(idx)


func _on_color_changed(color: Color) -> void:
	if _updating:
		return
	_set_value_with_undo(color, true)


func _on_vector2_x_changed(val: float) -> void:
	if _updating:
		return
	var current = param.value
	_set_value_with_undo(Vector2(val, current.y), true)


func _on_vector2_y_changed(val: float) -> void:
	if _updating:
		return
	var current = param.value
	_set_value_with_undo(Vector2(current.x, val), true)


func _on_vector2i_x_changed(val: int) -> void:
	if _updating:
		return
	var current = param.value
	_set_value_with_undo(Vector2i(val, current.y), true)


func _on_vector2i_y_changed(val: int) -> void:
	if _updating:
		return
	var current = param.value
	_set_value_with_undo(Vector2i(current.x, val), true)


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
	_set_value_with_undo(path)


func _on_file_clear_pressed() -> void:
	_set_value_with_undo("")
	# Reset dropdown to "(none)"
	var hbox := _control as HBoxContainer
	if hbox and hbox.get_child_count() >= 1:
		var option: OptionButton = hbox.get_child(0) as OptionButton
		if option:
			option.selected = 0


func _on_ramp_changed(new_keys: Array) -> void:
	if _updating:
		return
	_set_value_with_undo(new_keys)
	if owner_node:
		owner_node.mark_dirty()


# ═══════════════════════════════════════════════════════════════════════════════
# Expression Handling
# ═══════════════════════════════════════════════════════════════════════════════

## Releases focus from any focused text control when the user clicks outside it.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if _is_pointer_over_autocomplete():
		return
	# Check main expression field
	if _expr_edit and _expr_edit.has_focus() and _expr_edit.visible:
		if not _expr_edit.get_global_rect().has_point(event.global_position):
			_expr_edit.release_focus()
			return
	# Check per-component expression fields
	for edit in _comp_expr_edits:
		if edit and edit.has_focus() and edit.visible:
			if not edit.get_global_rect().has_point(event.global_position):
				edit.release_focus()
				return
	# Check one-line string LineEdit controls
	var string_edit: LineEdit = _control as LineEdit if _control is LineEdit else null
	if string_edit and string_edit.has_focus() and string_edit.visible and string_edit.editable:
		if not string_edit.get_global_rect().has_point(event.global_position):
			string_edit.release_focus()
			return


## Grabs focus on this row's primary value control (for Tab navigation).
## Returns true if focus was successfully grabbed.
func grab_value_focus() -> bool:
	if _control and _control.visible and _control is GNNumericField:
		(_control as GNNumericField)._enter_edit_mode()
		return true
	if _expr_edit and _expr_edit.visible:
		_expr_edit.grab_focus()
		return true
	if _control and _control.visible:
		if _control is CheckBox or _control is OptionButton or _control is LineEdit or _control is TextEdit:
			_control.grab_focus()
			return true
	# Multi-component: focus the first visible field
	if _is_multi_component:
		for field in _comp_fields:
			if field and field.visible:
				field._enter_edit_mode()
				return true
		for edit in _comp_expr_edits:
			if edit and edit.visible:
				edit.grab_focus()
				return true
	return false


## Routes a scalar GNNumericField's tab_requested signal to row-level signals.
func _on_field_tab(forward: bool) -> void:
	if forward:
		tab_next_requested.emit()
	else:
		tab_prev_requested.emit()


## Routes a per-component field's Tab, cycling through siblings first.
func _on_comp_field_tab(comp_idx: int, forward: bool) -> void:
	if forward:
		for i in range(comp_idx + 1, _comp_fields.size()):
			if _comp_fields[i].visible:
				_comp_fields[i]._enter_edit_mode()
				return
		tab_next_requested.emit()
	else:
		for i in range(comp_idx - 1, -1, -1):
			if _comp_fields[i].visible:
				_comp_fields[i]._enter_edit_mode()
				return
		tab_prev_requested.emit()


## Handles Tab/Shift+Tab in expression LineEdits to navigate between rows.
## Also triggers inline autocomplete on caret-moving input (arrows, mouse click).
func _on_expr_gui_input(event: InputEvent) -> void:
	if _expr_edit == null:
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		var key := event as InputEventKey
		if _handle_autocomplete_key(_expr_edit, key):
			accept_event()
			return
		if key.keycode == KEY_TAB:
			if _expr_edit.has_focus():
				_apply_expression_text(_expr_edit.text)
				_expr_edit.release_focus()
			if key.shift_pressed:
				tab_prev_requested.emit()
			else:
				tab_next_requested.emit()
			accept_event()
			return
		# Arrow keys / Home / End move the caret — recheck autocomplete
		if key.keycode in [KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END]:
			_check_inline_autocomplete.call_deferred(_expr_edit)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		# Mouse click repositions caret — recheck after Godot processes it
		_check_inline_autocomplete.call_deferred(_expr_edit)


## Handles Tab/Shift+Tab in per-component expression LineEdits, cycling siblings first.
func _on_comp_expr_gui_input(comp_idx: int, event: InputEvent) -> void:
	if comp_idx < 0 or comp_idx >= _comp_expr_edits.size():
		return
	var edit: LineEdit = _comp_expr_edits[comp_idx]
	if event is InputEventKey and (event as InputEventKey).pressed:
		var key := event as InputEventKey
		if _handle_autocomplete_key(edit, key):
			accept_event()
			return
		if key.keycode != KEY_TAB:
			if key.keycode in [KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END]:
				_check_inline_autocomplete.call_deferred(edit)
			return
		# Commit current component's expression
		if edit.has_focus():
			_on_comp_expr_submitted(comp_idx, edit.text)
			edit.release_focus()
		var forward := not key.shift_pressed
		if forward:
			for i in range(comp_idx + 1, _comp_expr_edits.size()):
				if _comp_expr_edits[i].visible:
					_comp_expr_edits[i].grab_focus()
					accept_event()
					return
			tab_next_requested.emit()
		else:
			for i in range(comp_idx - 1, -1, -1):
				if _comp_expr_edits[i].visible:
					_comp_expr_edits[i].grab_focus()
					accept_event()
					return
			tab_prev_requested.emit()
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_check_inline_autocomplete.call_deferred(edit)


func _on_expression_submitted(text: String) -> void:
	_apply_expression_text(text)


func _on_expression_focus_lost() -> void:
	if _is_pointer_over_autocomplete():
		if _expr_edit:
			_expr_edit.call_deferred("grab_focus")
		return
	_close_autocomplete()
	if _expr_edit and _expr_edit.visible:
		_apply_expression_text(_expr_edit.text)


func _apply_expression_text(text: String) -> void:
	_do_with_snapshot_undo("Expression %s" % param.param_name, func() -> void:
		if text.strip_edges().is_empty():
			# Empty expression → revert to constant mode
			param.set_constant()
		else:
			if text != param.expression:
				param.set_expression(text)
	)
	_update_mode_display()


# ═══════════════════════════════════════════════════════════════════════════════
# Per-Component Expression Handling (Vector2, Vector3, Vector4, Color)
# ═══════════════════════════════════════════════════════════════════════════════

## Toggles a single component between CONSTANT and EXPRESSION mode.
func _on_comp_mode_toggle(idx: int) -> void:
	_do_with_snapshot_undo("Toggle comp %d mode %s" % [idx, param.param_name], func() -> void:
		if param.component_modes[idx] == GNParameter.Mode.CONSTANT:
			# Switch to expression mode
			var expr_text: String = param.component_expressions[idx]
			_comp_expr_edits[idx].text = expr_text
			param.set_component_expression(idx, expr_text)
		else:
			# Switch back to constant
			param.set_component_constant(idx)
	)
	_update_comp_mode_display(idx)


## Extracts a single component from the parameter's default_value.
func _get_default_component(idx: int) -> float:
	var dv: Variant = param.default_value
	match param.value_type:
		GNParameter.ValueType.VECTOR2:
			var v: Vector2 = dv if dv is Vector2 else Vector2.ZERO
			return v.x if idx == 0 else v.y
		GNParameter.ValueType.VECTOR2I:
			var v: Vector2i = dv if dv is Vector2i else Vector2i.ZERO
			return float(v.x if idx == 0 else v.y)
		GNParameter.ValueType.VECTOR3:
			var v: Vector3 = dv if dv is Vector3 else Vector3.ZERO
			return [v.x, v.y, v.z][idx] if idx < 3 else 0.0
		GNParameter.ValueType.VECTOR4:
			var v: Vector4 = dv if dv is Vector4 else Vector4.ZERO
			return [v.x, v.y, v.z, v.w][idx] if idx < 4 else 0.0
		GNParameter.ValueType.COLOR:
			var c: Color = dv if dv is Color else Color.BLACK
			return [c.r, c.g, c.b, c.a][idx] if idx < 4 else 0.0
		_:
			return 0.0


## Called when a per-component GNFloatField changes.
func _on_comp_field_changed(idx: int, val: float) -> void:
	if _updating:
		return
	# set_component_value calls set_value internally, so capture old whole-value for undo
	if undo_redo != null:
		var old_value: Variant = param.value
		var p := param
		var new_value_after: Variant
		# Build the new composite value manually to avoid double-setting
		param.set_component_value(idx, val)
		new_value_after = param.value
		# Now record it without re-applying (undo restores old, redo restores new)
		undo_redo.create_action("Set %s.%s[%d]" % [owner_node.id if owner_node else "?", param.param_name, idx],
			UndoRedo.MERGE_ALL)
		undo_redo.add_do_method(Callable(p, "set_value").bind(new_value_after))
		undo_redo.add_undo_method(Callable(p, "set_value").bind(old_value))
		undo_redo.commit_action(false)  # false = don't execute do (already done)
	else:
		param.set_component_value(idx, val)
	# Sync the ColorPickerButton swatch when editing R/G/B/A components
	if param.value_type == GNParameter.ValueType.COLOR:
		var picker := _control as ColorPickerButton
		if picker:
			_updating = true
			picker.color = param.value
			_updating = false


## Called when a per-component expression is submitted.
func _on_comp_expr_submitted(idx: int, text: String) -> void:
	_apply_comp_expression(idx, text)


## Called when a per-component expression field loses focus.
func _on_comp_expr_focus_lost(idx: int) -> void:
	if _is_pointer_over_autocomplete():
		if idx >= 0 and idx < _comp_expr_edits.size():
			_comp_expr_edits[idx].call_deferred("grab_focus")
		return
	_close_autocomplete()
	if idx < _comp_expr_edits.size() and _comp_expr_edits[idx].visible:
		_apply_comp_expression(idx, _comp_expr_edits[idx].text)


## Applies/compiles a per-component expression (or reverts to constant if empty).
func _apply_comp_expression(idx: int, text: String) -> void:
	_do_with_snapshot_undo("Comp expr %d %s" % [idx, param.param_name], func() -> void:
		if text.strip_edges().is_empty():
			param.set_component_constant(idx)
		else:
			if text != param.component_expressions[idx]:
				param.set_component_expression(idx, text)
	)
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
	var field := _comp_fields[idx]
	var expr_edit := _comp_expr_edits[idx]
	var comp_mode: int = param.component_modes[idx]

	if comp_mode == GNParameter.Mode.EXPRESSION:
		btn.text = "E"
		btn.modulate = Color(0.8, 0.6, 0.2)  # Orange
		field.visible = false
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
		# Show resolved component value
		if idx < _comp_resolved_labels.size():
			_comp_resolved_labels[idx].visible = true
			var comp_val := _get_resolved_component(idx)
			_comp_resolved_labels[idx].text = "→ " + _format_resolved_value(comp_val)
			_comp_resolved_labels[idx].tooltip_text = str(comp_val)
	else:
		btn.text = "C"
		btn.modulate = Color(0.5, 0.8, 0.5)  # Green
		field.visible = true
		expr_edit.visible = false
		if idx < _comp_expand_btns.size():
			_comp_expand_btns[idx].visible = false
		if idx < _comp_resolved_labels.size():
			_comp_resolved_labels[idx].visible = false


## Updates per-component expression error indicators and resolved-value
## previews (called per-cook).
func _update_comp_expression_status() -> void:
	for i in range(mini(_comp_expr_edits.size(), param.component_expression_errors.size())):
		var expr_edit := _comp_expr_edits[i]
		if not expr_edit.visible:
			continue
		var err: String = param.component_expression_errors[i]
		if not err.is_empty():
			expr_edit.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
			expr_edit.tooltip_text = err
			if i < _comp_resolved_labels.size() and _comp_resolved_labels[i].visible:
				_comp_resolved_labels[i].text = "→ err"
				_comp_resolved_labels[i].add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				_comp_resolved_labels[i].tooltip_text = err
		else:
			expr_edit.remove_theme_color_override("font_color")
			# Show per-component profiling info
			if i < param.component_expression_eval_usec.size() and \
					param.component_expression_eval_usec[i] > 0.0:
				expr_edit.tooltip_text = "Eval: %.1f\u00b5s" % param.component_expression_eval_usec[i]
			else:
				expr_edit.tooltip_text = ""
			# Update resolved component value
			if i < _comp_resolved_labels.size() and _comp_resolved_labels[i].visible:
				var comp_val := _get_resolved_component(i)
				_comp_resolved_labels[i].text = "→ " + _format_resolved_value(comp_val)
				_comp_resolved_labels[i].add_theme_color_override("font_color", Color(0.55, 0.75, 0.55))
				_comp_resolved_labels[i].tooltip_text = str(comp_val)


## Syncs per-component field values from the parameter model.
func _update_comp_value_display() -> void:
	if _updating:
		return
	_updating = true
	var count := mini(_comp_fields.size(), param.get_component_count())
	for i in range(count):
		if _comp_fields[i].visible:
			_comp_fields[i].set_value_no_signal(param.get_component_value(i))
	_updating = false


# ═══════════════════════════════════════════════════════════════════════════════
# Mode Toggle
# ═══════════════════════════════════════════════════════════════════════════════

func _on_mode_toggle() -> void:
	_do_with_snapshot_undo("Toggle mode %s" % param.param_name, func() -> void:
		if _is_multi_component:
			# For multi-component params the master button cycles between:
			#   C  →  E (whole-parameter expression)
			#   E  →  C (revert to constant, but preserve expression text)
			var has_whole_expr := (param.mode == GNParameter.Mode.EXPRESSION
					and not param.expression.is_empty())
			if has_whole_expr:
				# ── Whole expression active → revert to CONSTANT ──
				# Preserve param.expression so the user can toggle back without
				# losing their work.  Only reset the compiled state / mode.
				param.mode = GNParameter.Mode.CONSTANT
				param._compiled_expression = null
				param._compiled_expression_callable = Callable()
				param._compiled_expression_evaluator = null
				param._expression_valid = false
				param.expression_error = ""
				param.mode_changed.emit(param.param_name, param.mode)
			elif param.mode == GNParameter.Mode.EXPRESSION and param.expression.is_empty():
				# Per-component expressions active (or stuck empty-expression state)
				# → revert to CONSTANT as well
				param.mode = GNParameter.Mode.CONSTANT
				param.mode_changed.emit(param.param_name, param.mode)
			else:
				# ── CONSTANT → switch to whole expression ──
				# Re-enable the preserved expression text (may be empty for first use)
				if _expr_edit:
					_expr_edit.text = param.expression
				if param.expression.is_empty():
					# No previous expression — just flip mode so the LineEdit appears
					param.mode = GNParameter.Mode.EXPRESSION
					param.mode_changed.emit(param.param_name, param.mode)
				else:
					# Re-compile the preserved expression text
					param.set_expression(param.expression)
		else:
			# Scalar parameter toggle
			match param.mode:
				GNParameter.Mode.CONSTANT:
					# C → E
					_expr_edit.text = param.expression
					param.set_expression(param.expression)
				GNParameter.Mode.EXPRESSION:
					# E → C
					param.set_constant()
	)
	_update_mode_display()


func _update_mode_display() -> void:
	if _mode_btn == null:
		return

	if _is_multi_component:
		# Multi-component params support two expression modes:
		# 1) Whole-parameter expression — overrides all components with a single
		#    expression returning Vector2/3/4/Color.
		# 2) Per-component expressions — individual X/Y/Z/W channels have their own.
		#
		# The master button shows E when either:
		#   a) A whole-param expression is active/being entered, OR
		#   b) At least one per-component expression is active.
		#
		# We show the whole-expression LineEdit when mode==EXPRESSION and there
		# are NO per-component expressions active (i.e. the user is working with
		# a unified expression, even if it's empty and they're about to type it).
		var is_whole_expr_mode := (param.mode == GNParameter.Mode.EXPRESSION
				and not param.has_any_component_expression())
		# Also show whole-expr UI if expression text exists even when components
		# also have expressions (whole takes priority over per-component).
		if not is_whole_expr_mode and param.mode == GNParameter.Mode.EXPRESSION \
				and not param.expression.is_empty():
			is_whole_expr_mode = true

		if is_whole_expr_mode:
			# ── Whole-parameter expression active (or empty, awaiting user input) ──
			_mode_btn.text = "E"
			_mode_btn.modulate = Color(0.8, 0.6, 0.2)  # Orange
			_mode_btn.tooltip_text = "EXPRESSION mode — unified expression for all components. Click to revert to CONSTANT."
			# Show whole-expression UI, hide per-component rows
			if _expr_edit:
				_expr_edit.visible = true
				if not _expr_edit.has_focus():
					_expr_edit.text = param.expression
				if not param.expression_error.is_empty():
					_expr_edit.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
					_expr_edit.tooltip_text = param.expression_error
				else:
					_expr_edit.remove_theme_color_override("font_color")
					_expr_edit.tooltip_text = ""
			_set_expand_btn_visible(true)
			if _resolved_label:
				if param.expression.is_empty():
					_resolved_label.visible = false
				else:
					_resolved_label.visible = true
					_resolved_label.text = "→ " + _format_resolved_value(param.get_resolved_value())
					_resolved_label.tooltip_text = str(param.get_resolved_value())
			if _comp_vbox:
				_comp_vbox.visible = false
		elif param.mode == GNParameter.Mode.EXPRESSION:
			# ── Per-component expressions active ──
			_mode_btn.text = "E"
			_mode_btn.modulate = Color(0.8, 0.6, 0.2)
			_mode_btn.tooltip_text = "Per-component expressions active. Click to enable unified expression."
			if _expr_edit:
				_expr_edit.visible = false
			_set_expand_btn_visible(false)
			if _resolved_label:
				_resolved_label.visible = false
			if _comp_vbox:
				_comp_vbox.visible = true
			_update_comp_mode_displays()
		else:
			# ── CONSTANT mode ──
			_mode_btn.text = "C"
			_mode_btn.modulate = Color(0.5, 0.8, 0.5)
			_mode_btn.tooltip_text = "CONSTANT mode. Click to enter a unified expression."
			# Hide whole-expression UI, show per-component rows
			if _expr_edit:
				_expr_edit.visible = false
			_set_expand_btn_visible(false)
			if _resolved_label:
				_resolved_label.visible = false
			if _comp_vbox:
				_comp_vbox.visible = true
			_update_comp_mode_displays()
		return

	# ── Scalar parameter ──
	match param.mode:
		GNParameter.Mode.CONSTANT:
			_mode_btn.text = "C"
			_mode_btn.modulate = Color(0.5, 0.8, 0.5)  # Green tint
			_mode_btn.tooltip_text = "CONSTANT mode — direct literal value. Click to cycle mode."
			if _control:
				_control.visible = true
			_expr_edit.visible = false
			_set_expand_btn_visible(false)
			if _resolved_label:
				_resolved_label.visible = false
		GNParameter.Mode.EXPRESSION:
			_mode_btn.text = "E"
			_mode_btn.modulate = Color(0.8, 0.6, 0.2)  # Orange tint
			_mode_btn.tooltip_text = "EXPRESSION mode — evaluated each frame. Click to cycle mode."
			if _control:
				_control.visible = false
			_expr_edit.visible = true
			_set_expand_btn_visible(true)
			if _resolved_label:
				_resolved_label.visible = true
				_resolved_label.text = "→ " + _format_resolved_value(param.get_resolved_value())
				_resolved_label.tooltip_text = str(param.get_resolved_value())
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

## Updates expression error/tooltip indicator AND resolved-value preview
## (called per-cook). Does NOT touch _expr_edit.text to avoid destroying edits.
func update_expression_status() -> void:
	if param == null:
		return
	if _is_multi_component:
		# Check for whole-parameter expression first (same logic as _update_mode_display)
		var is_whole_expr_mode := (param.mode == GNParameter.Mode.EXPRESSION
				and not param.has_any_component_expression())
		if not is_whole_expr_mode and param.mode == GNParameter.Mode.EXPRESSION \
				and not param.expression.is_empty():
			is_whole_expr_mode = true
		if is_whole_expr_mode and _expr_edit != null and not param.expression.is_empty():
			if not param.expression_error.is_empty():
				_expr_edit.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
				_expr_edit.tooltip_text = param.expression_error
				if _resolved_label and _resolved_label.visible:
					_resolved_label.text = "→ err"
					_resolved_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
					_resolved_label.tooltip_text = param.expression_error
			else:
				_expr_edit.remove_theme_color_override("font_color")
				if param.expression_eval_usec > 0.0:
					_expr_edit.tooltip_text = "Eval: %.1f\u00b5s (avg: %.1f\u00b5s)" % [
						param.expression_eval_usec, param.expression_eval_avg_usec]
				else:
					_expr_edit.tooltip_text = ""
				if _resolved_label and _resolved_label.visible:
					var rv = param.get_resolved_value()
					_resolved_label.text = "→ " + _format_resolved_value(rv)
					_resolved_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55))
					_resolved_label.tooltip_text = str(rv)
		else:
			_update_comp_expression_status()
		return
	if _expr_edit == null:
		return
	if not param.expression_error.is_empty():
		_expr_edit.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		_expr_edit.tooltip_text = param.expression_error
		if _resolved_label and _resolved_label.visible:
			_resolved_label.text = "→ err"
			_resolved_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			_resolved_label.tooltip_text = param.expression_error
	else:
		_expr_edit.remove_theme_color_override("font_color")
		# Show profiling info in tooltip when no error
		if param.expression_eval_usec > 0.0:
			_expr_edit.tooltip_text = "Eval: %.1f\u00b5s (avg: %.1f\u00b5s)" % [
				param.expression_eval_usec, param.expression_eval_avg_usec]
		else:
			_expr_edit.tooltip_text = ""
		# Update resolved-value preview
		if _resolved_label and _resolved_label.visible:
			var rv = param.get_resolved_value()
			_resolved_label.text = "→ " + _format_resolved_value(rv)
			_resolved_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55))
			_resolved_label.tooltip_text = str(rv)

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
			var field := _control as GNFloatField
			if field:
				field.min_value = param.min_value
				field.max_value = param.max_value
				field.set_value_no_signal(float(param.get_resolved_value()))
		GNParameter.ValueType.INT:
			var field := _control as GNIntField
			if field:
				field.min_value = param.min_value
				field.max_value = param.max_value
				field.set_value_no_signal(int(param.get_resolved_value()))
		GNParameter.ValueType.BOOL:
			if param.is_pulse:
				return  # Pulse buttons have no toggle state to refresh
			var cb := _control as CheckBox
			if cb:
				cb.button_pressed = bool(param.get_resolved_value())
				cb.text = "On" if cb.button_pressed else "Off"
		GNParameter.ValueType.STRING:
			if _code_edit != null:
				if not _code_edit.has_focus():
					_set_code_preview_text(str(param.get_resolved_value()))
			elif _control is LineEdit:
				var line_edit := _control as LineEdit
				if not line_edit.has_focus():
					line_edit.text = str(param.get_resolved_value())
		GNParameter.ValueType.ENUM:
			var option := _control as OptionButton
			if option:
				option.selected = int(param.get_resolved_value())
		GNParameter.ValueType.COLOR:
			var picker := _control as ColorPickerButton
			if picker:
				var val = param.get_resolved_value()
				picker.color = val if val is Color else Color.WHITE
		GNParameter.ValueType.VECTOR2:
			var hbox := _control as HBoxContainer
			if hbox and hbox.get_child_count() >= 2:
				var vec_val = param.get_resolved_value()
				var x_field: GNFloatField = hbox.get_child(0) as GNFloatField
				var y_field: GNFloatField = hbox.get_child(1) as GNFloatField
				if x_field:
					x_field.set_value_no_signal(vec_val.x)
				if y_field:
					y_field.set_value_no_signal(vec_val.y)
		GNParameter.ValueType.VECTOR2I:
			var hbox_i := _control as HBoxContainer
			if hbox_i and hbox_i.get_child_count() >= 2:
				var vec_val_i = param.get_resolved_value()
				var x_int: GNIntField = hbox_i.get_child(0) as GNIntField
				var y_int: GNIntField = hbox_i.get_child(1) as GNIntField
				if x_int:
					x_int.set_value_no_signal(int(vec_val_i.x))
				if y_int:
					y_int.set_value_no_signal(int(vec_val_i.y))
		GNParameter.ValueType.FILE:
			var hbox := _control as HBoxContainer
			if hbox and hbox.get_child_count() >= 1:
				var option: OptionButton = hbox.get_child(0) as OptionButton
				if option:
					# Do not rescan the project here. This runs when the row is
					# built, so a node with a texture, movie, or sound was
					# walking res:// on every click. The list fills when opened.
					_show_current_file(option)
		GNParameter.ValueType.RAMP:
			var ramp_editor := _control as GNRampEditor
			if ramp_editor:
				var current_keys: Array = param.get_resolved_value() if param.get_resolved_value() is Array else []
				ramp_editor.set_keys(current_keys)

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

	_do_with_snapshot_undo("Expr editor %s" % param.param_name, func() -> void:
		if component_idx < 0:
			# Main scalar expression
			param.set_expression(text)
		else:
			# Per-component expression
			if component_idx < param.component_expressions.size():
				param.component_expressions[component_idx] = text
				param.component_modes[component_idx] = GNParameter.Mode.EXPRESSION
				param._compile_component_expression(component_idx)
	)

	if component_idx < 0:
		if _expr_edit != null and not _expr_edit.has_focus():
			_expr_edit.text = text
		_update_mode_display()
	else:
		if component_idx < param.component_expressions.size():
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

	_param_context_menu.add_separator()

	# Insert reference pickers (set expression and switch to expression mode)
	_param_context_menu.add_item("Insert Parameter Reference…", 10)
	_param_context_menu.add_item("Insert CHOP Reference…", 11)

	# Promote to Parent — only shown when the node lives inside a SubNetwork
	if _is_inside_subnet():
		_param_context_menu.add_separator()
		_param_context_menu.add_item("Promote to Parent (Spare Param)", 20)

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
		10:
			_show_param_reference_picker()
			return
		11:
			_show_chop_reference_picker()
			return
		20:
			_promote_to_parent()
			return
	if not ref.is_empty():
		DisplayServer.clipboard_set(ref)


# ═══════════════════════════════════════════════════════════════════════════════
# Promote to Parent (Spare Param)
# ═══════════════════════════════════════════════════════════════════════════════

## Returns true if the owner_node's network is an inner_network of a SubNetwork.
func _is_inside_subnet() -> bool:
	if network == null:
		return false
	return network.host_node is SubNetworkNode


## Returns the SubNetworkNode that owns the current network, or null.
func _find_parent_subnet() -> SubNetworkNode:
	if network == null or not (network.host_node is SubNetworkNode):
		return null
	var _ret0 := network.host_node as SubNetworkNode
	return _ret0


## Creates a spare parameter on the parent SubNetwork that mirrors this param,
## and wires the inner node's param to read from the parent via an expression.
func _promote_to_parent() -> void:
	var parent_subnet := _find_parent_subnet()
	if parent_subnet == null or param == null or owner_node == null:
		GNLogger.warn("ParamRow", "Cannot promote — not inside a sub-network")
		return

	# Build a unique spare param name: inner_node_id + "_" + param_name
	var sp_name := "%s_%s" % [owner_node.id, param.param_name]
	# Avoid collision with existing spare params
	var base_name := sp_name
	var counter := 1
	while parent_subnet.spare_parameters.has(sp_name):
		counter += 1
		sp_name = "%s_%d" % [base_name, counter]

	# Clone the parameter as a spare param on the parent
	var spare := param.duplicate()
	spare.param_name = sp_name
	spare.label = "%s: %s" % [owner_node.id, param.label]
	# Copy current value as default
	spare.default_value = param.value
	spare.value = param.value

	parent_subnet.add_spare_parameter(spare)

	# Wire the inner node's param to read from parent via expression
	param.mode = GNParameter.Mode.EXPRESSION
	param.expression = 'par("../", "%s")' % sp_name
	param.mode_changed.emit(param.param_name, param.mode)
	owner_node.mark_dirty()

	GNLogger.info("ParamRow", "Promoted '%s.%s' to parent spare param '%s'" % [
		owner_node.id, param.param_name, sp_name])

	# Refresh the row UI to show expression mode
	_update_mode_display()
	_update_value_display()


# ═══════════════════════════════════════════════════════════════════════════════
# Resolved Value Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Formats a resolved value into a compact display string (e.g. "0.52", "true").
## Keeps floats to 3 decimal places; vectors/colors show abbreviated form.
func _format_resolved_value(val: Variant) -> String:
	if val == null:
		return "null"
	if val is float:
		return _compact_float(val)
	if val is int:
		return str(val)
	if val is bool:
		return "true" if val else "false"
	if val is Vector2:
		return "(%s, %s)" % [_compact_float(val.x), _compact_float(val.y)]
	if val is Vector2i:
		return "(%d, %d)" % [val.x, val.y]
	if val is Vector3:
		return "(%s, %s, %s)" % [_compact_float(val.x), _compact_float(val.y), _compact_float(val.z)]
	if val is Vector4:
		return "(%s, %s, %s, %s)" % [_compact_float(val.x), _compact_float(val.y), _compact_float(val.z), _compact_float(val.w)]
	if val is Color:
		return "(%.2f, %.2f, %.2f, %.2f)" % [val.r, val.g, val.b, val.a]
	if val is String:
		var s: String = val
		if s.length() > 16:
			return '"%s…"' % s.left(14)
		return '"%s"' % s
	return str(val).left(20)


## Formats a float compactly: trims trailing zeros, caps at 3 decimals.
func _compact_float(v: float) -> String:
	if absf(v) >= 1000.0:
		return "%.0f" % v
	if absf(v) >= 100.0:
		return "%.1f" % v
	if absf(v) >= 10.0:
		return "%.2f" % v
	return "%.3f" % v


## Extracts a single component's resolved value from the parameter's resolved_value.
## Used for per-component expression labels.
func _get_resolved_component(idx: int) -> float:
	var rv = param.resolved_value
	if rv is Vector2 or rv is Vector2i:
		return rv.x if idx == 0 else rv.y
	if rv is Vector3:
		return [rv.x, rv.y, rv.z][idx] if idx < 3 else 0.0
	if rv is Vector4:
		return [rv.x, rv.y, rv.z, rv.w][idx] if idx < 4 else 0.0
	if rv is Color:
		return [rv.r, rv.g, rv.b, rv.a][idx] if idx < 4 else 0.0
	return 0.0


# ═══════════════════════════════════════════════════════════════════════════════
# Insert Reference Pickers (right-click → "Insert Parameter/CHOP Reference…")
# ═══════════════════════════════════════════════════════════════════════════════

## Shows a dialog to insert a par() expression referencing another node's parameter.
## On confirm, switches this param to EXPRESSION mode with the generated expression.
func _show_param_reference_picker() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Insert Parameter Reference → '%s'" % param.param_name
	dialog.ok_button_text = "Insert"
	dialog.size = Vector2i(420, 160)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var node_lbl := Label.new()
	node_lbl.text = "Source node ID:"
	vbox.add_child(node_lbl)
	var node_edit := LineEdit.new()
	node_edit.placeholder_text = "e.g., ctrl_panel"
	vbox.add_child(node_edit)

	var param_lbl := Label.new()
	param_lbl.text = "Source parameter name:"
	vbox.add_child(param_lbl)
	var param_edit := LineEdit.new()
	param_edit.placeholder_text = "e.g., master_scale"
	vbox.add_child(param_edit)

	dialog.add_child(vbox)

	dialog.confirmed.connect(func() -> void:
		var src_node: String = node_edit.text.strip_edges()
		var src_param_name: String = param_edit.text.strip_edges()
		if not src_node.is_empty() and not src_param_name.is_empty():
			param.set_param_reference(src_node, src_param_name)
			_expr_edit.text = param.expression
			_update_mode_display()
			if owner_node:
				owner_node.mark_dirty()
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	var root := get_tree().root if get_tree() else null
	if root:
		root.add_child(dialog)
		dialog.popup_centered()
	else:
		dialog.queue_free()


## Shows a dialog to insert a chop() expression referencing a CHOP channel.
## On confirm, switches this param to EXPRESSION mode with the generated expression.
func _show_chop_reference_picker() -> void:
	# Gather available CHOP nodes from the network for hints
	var chop_names: PackedStringArray = []
	if network != null:
		for nid in network.nodes:
			var n: GNNode = network.nodes[nid]
			if n.family == GNFamily.Type.CHOP:
				chop_names.append(nid)

	var dialog := AcceptDialog.new()
	dialog.title = "Insert CHOP Reference → '%s'" % param.param_name
	dialog.ok_button_text = "Insert"
	dialog.size = Vector2i(420, 220)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var node_lbl := Label.new()
	node_lbl.text = "CHOP node ID:"
	vbox.add_child(node_lbl)
	var node_edit := LineEdit.new()
	node_edit.placeholder_text = "e.g., lfo1"
	vbox.add_child(node_edit)
	if not chop_names.is_empty():
		var hint := Label.new()
		hint.text = "Available CHOPs: %s" % ", ".join(chop_names)
		hint.add_theme_font_size_override("font_size", 10)
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		vbox.add_child(hint)

	var ch_lbl := Label.new()
	ch_lbl.text = "Channel name:"
	vbox.add_child(ch_lbl)
	var ch_edit := LineEdit.new()
	ch_edit.text = "out"
	ch_edit.placeholder_text = "e.g., out"
	vbox.add_child(ch_edit)

	# Optional scale / offset
	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 8)
	var sc_lbl := Label.new()
	sc_lbl.text = "Scale:"
	opts.add_child(sc_lbl)
	var sc_spin := SpinBox.new()
	sc_spin.value = 1.0
	sc_spin.min_value = -1000.0
	sc_spin.max_value = 1000.0
	sc_spin.step = 0.01
	opts.add_child(sc_spin)
	var off_lbl := Label.new()
	off_lbl.text = "Offset:"
	opts.add_child(off_lbl)
	var off_spin := SpinBox.new()
	off_spin.value = 0.0
	off_spin.min_value = -10000.0
	off_spin.max_value = 10000.0
	off_spin.step = 0.01
	opts.add_child(off_spin)
	vbox.add_child(opts)

	dialog.add_child(vbox)

	dialog.confirmed.connect(func() -> void:
		var src_node: String = node_edit.text.strip_edges()
		var channel: String = ch_edit.text.strip_edges()
		if not src_node.is_empty() and not channel.is_empty():
			param.set_chop_reference(src_node, channel, sc_spin.value, off_spin.value)
			_expr_edit.text = param.expression
			_update_mode_display()
			if owner_node:
				owner_node.mark_dirty()
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	var root := get_tree().root if get_tree() else null
	if root:
		root.add_child(dialog)
		dialog.popup_centered()
	else:
		dialog.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Inline Expression Autocomplete
# ═══════════════════════════════════════════════════════════════════════════════

## Regex matching function call patterns that should trigger node-ID autocomplete.
## Built dynamically from GNFamily's expression function registry so extension-
## defined families get autocomplete automatically.
static var _ac_trigger_re: RegEx = null
static var _ac_second_arg_re: RegEx = null
static var _ac_regex_snapshot: PackedStringArray = []

## Returns the shared trigger regex, rebuilding if the registry changed.
static func _get_ac_trigger_re() -> RegEx:
	_ensure_ac_regexes()
	return _ac_trigger_re

## Returns the shared second-arg regex, rebuilding if the registry changed.
static func _get_ac_second_arg_re() -> RegEx:
	_ensure_ac_regexes()
	return _ac_second_arg_re

## Rebuilds autocomplete regexes when the expression function registry changes.
static func _ensure_ac_regexes() -> void:
	var variants := GNFamily.get_expression_func_variants()
	var snapshot := PackedStringArray(variants)
	if _ac_trigger_re != null and snapshot == _ac_regex_snapshot:
		return
	_ac_regex_snapshot = snapshot
	var family_alt := "|".join(variants) if not variants.is_empty() else "(?!x)"
	# All family funcs now support port args natively, so second-arg
	# context always suggests data keys/channels.
	var value_variants := GNFamily.get_expression_func_variants()
	var value_alt := "|".join(value_variants) if not value_variants.is_empty() else "(?!x)"
	# First arg: (family_func|op|par|set_par)("partial...
	_ac_trigger_re = RegEx.new()
	_ac_trigger_re.compile("(%s|op|par[sfi]?|set_par)\\s*\\(\\s*\"([^\"]*)$" % family_alt)
	# Second arg: (value_func|op)("node", "partial...
	_ac_second_arg_re = RegEx.new()
	_ac_second_arg_re.compile("(%s|op)\\s*\\(\\s*\"([^\"]*)\"\\s*,\\s*\"([^\"]*)$" % value_alt)

## Called on every text change in an expression LineEdit.
func _on_expr_text_changed(edit: LineEdit) -> void:
	_check_inline_autocomplete(edit)


## Called when the caret moves (arrow keys, mouse click) without text changing.
func _on_expr_caret_moved(edit: LineEdit) -> void:
	_check_inline_autocomplete(edit)


## Shared logic: detect autocomplete context from text before caret and show popup.
func _check_inline_autocomplete(edit: LineEdit) -> void:
	if network == null:
		return

	var text := edit.text
	var col := edit.caret_column
	var before := text.substr(0, col)

	# Check for second-arg context first (channel suggestions)
	var m2 := _get_ac_second_arg_re().search(before)
	if m2:
		var fn2 := m2.get_string(1)
		var node_id := m2.get_string(2)
		var partial := m2.get_string(3)
		var completions: Array[Dictionary]
		if fn2 == "op":
			completions = _gather_param_completions(node_id)
		else:
			completions = _gather_data_completions(node_id)
		_show_inline_autocomplete(edit, completions, partial, "quote")
		return

	# Check for first-arg context (node ID suggestions)
	var m := _get_ac_trigger_re().search(before)
	if m:
		var fn := m.get_string(1)
		var partial := m.get_string(2)
		var filter_family: int = _fn_to_family(fn)
		_show_inline_autocomplete(edit, _gather_node_ids(filter_family), partial, "quote")
		return

	# General identifier suggestions (functions, variables, constants)
	var id_prefix := GNExpressionEditor.extract_identifier_prefix(before)
	if id_prefix.length() >= 1:
		var general_items := _gather_general_completions(id_prefix)
		_show_inline_autocomplete(edit, general_items, id_prefix, "general")
		return

	# No match — close popup if open
	_close_autocomplete()


## Maps a function name to the expected family filter (-1 = all).
## Uses the dynamic expression function registry so extension families
## like sdf(), audio(), etc. resolve automatically.
func _fn_to_family(fn: String) -> int:
	var family_id := GNFamily.resolve_expression_func_family(fn)
	if family_id >= 0:
		return family_id
	return -1  # op, par, set_par → all families


## Gathers node IDs from the network, optionally filtered by output family.
## Returns Array of { id: String, family: int }.
func _gather_node_ids(filter_family: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if network == null:
		return results
	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		if filter_family >= 0 and node.family != filter_family:
			# Also check output ports for cross-family operators
			var match_found := false
			for port in node.output_ports:
				if port.family == filter_family:
					match_found = true
					break
			if not match_found:
				continue
		results.append({ "id": node_id, "family": node.family })
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.id).naturalnocasecmp_to(str(b.id)) < 0)
	return results


## Gathers parameter names from a node for op() second-arg autocomplete.
func _gather_param_completions(node_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if network == null:
		return results
	var node: GNNode = network.get_node_by_id(node_id)
	if node == null:
		return results
	for p_name: String in node.parameters:
		results.append({ "id": p_name, "family": node.family })
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.id).naturalnocasecmp_to(str(b.id)) < 0)
	return results


## Gathers shared general-expression completions filtered by identifier prefix.
func _gather_general_completions(prefix: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for entry in GNExpressionEditor.filter_general_completions(prefix):
		results.append({
			"id": GNExpressionEditor.completion_entry_name(entry),
			"insert": entry["insert"],
			"label": entry.get("label", entry["insert"]),
			"description": entry.get("description", ""),
			"color": entry.get("color", Color.WHITE),
		})
	return results


## Gathers completion items (e.g. channel names, expression info keys) from
## a node's cached output.  Combines data.get_completions() + expression info
## keys so the inline LineEdit offers the same completions as the popup editor.
func _gather_data_completions(node_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if network == null:
		return results
	var node: GNNode = network.get_node_by_id(node_id)
	if node == null or node.cached_output == null:
		return results
	# Data-specific completions (e.g. channel names for CHOP)
	var completions := node.cached_output.get_completions()
	for item in completions:
		results.append({ "id": item["label"], "family": node.family })
	# Expression info keys (e.g. "resolution", "aspect" for TOP/IMG)
	var info := node.cached_output.get_expression_info()
	for key: String in info:
		results.append({ "id": key, "family": node.family })
	return results


## Pixel offset from the LineEdit inner left edge to the caret (margin + typed width).
static func line_edit_caret_text_offset_x(edit: LineEdit) -> float:
	var font := edit.get_theme_font("font")
	var font_size := edit.get_theme_font_size("font_size")
	var prefix := edit.text.substr(0, edit.caret_column)
	var text_w := font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var margin_left := 0.0
	var style := edit.get_theme_stylebox("normal")
	if style:
		margin_left = style.get_margin(SIDE_LEFT)
	return margin_left + text_w


const EXPR_AUTOCOMPLETE_LIST_WIDTH := 320.0
const EXPR_AUTOCOMPLETE_LIST_MAX_HEIGHT := 240.0
const EXPR_AUTOCOMPLETE_LIST_VERTICAL_INSET := 4.0  # ItemList offset_top + offset_bottom (2 + 2)
const EXPR_AUTOCOMPLETE_SCROLL_PAD := 6.0
const EXPR_AUTOCOMPLETE_ROW_HEIGHT_MIN := 8.0
const EXPR_AUTOCOMPLETE_ROW_HEIGHT_FLOOR := 32.0


## Panel height for inline autocomplete: row_h * count + vertical insets + scroll pad, capped.
static func compute_expr_autocomplete_panel_height(row_height: float, item_count: int) -> float:
	if item_count <= 0:
		return 0.0
	var content_h := row_height * float(item_count) + EXPR_AUTOCOMPLETE_LIST_VERTICAL_INSET + EXPR_AUTOCOMPLETE_SCROLL_PAD
	return mini(content_h, EXPR_AUTOCOMPLETE_LIST_MAX_HEIGHT)


## Row height from a laid-out ItemList row, or theme font + padding with a 32px floor.
static func estimate_expr_autocomplete_row_height(list: ItemList) -> float:
	if list.item_count > 0:
		var measured := list.get_item_rect(0).size.y
		if measured >= EXPR_AUTOCOMPLETE_ROW_HEIGHT_MIN:
			return measured
	var font := list.get_theme_font("font")
	var font_size := list.get_theme_font_size("font_size")
	var font_h := float(font.get_height(font_size)) if font else 16.0
	return maxf(maxf(font_h, 12.0) + 8.0, EXPR_AUTOCOMPLETE_ROW_HEIGHT_FLOOR)


## Panel + ItemList suggestion widget for inline expression autocomplete (headless-testable).
static func make_expr_autocomplete_suggestion_widget() -> Control:
	var panel := Panel.new()
	panel.name = "ExprAutocomplete"
	panel.top_level = true
	panel.focus_mode = Control.FOCUS_NONE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	panel.z_index = 100

	var list := ItemList.new()
	list.name = "List"
	list.focus_mode = Control.FOCUS_NONE
	list.mouse_filter = Control.MOUSE_FILTER_STOP
	list.fixed_icon_size = Vector2i(12, 12)
	list.max_columns = 1
	list.same_column_width = true
	list.select_mode = ItemList.SELECT_SINGLE
	panel.add_child(list)
	list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	list.offset_left = 2
	list.offset_top = 2
	list.offset_right = -2
	list.offset_bottom = -2
	return panel


## Canvas position for the autocomplete list: caret X, bottom of the LineEdit Y.
func _autocomplete_panel_position(edit: LineEdit) -> Vector2:
	return Vector2(
		edit.global_position.x + line_edit_caret_text_offset_x(edit),
		edit.global_position.y + edit.size.y
	)


## True when the pointer is over the open autocomplete panel.
func _is_pointer_over_autocomplete() -> bool:
	if _autocomplete_panel == null or not _autocomplete_panel.visible:
		return false
	var vp := _autocomplete_panel.get_viewport()
	if vp == null:
		return false
	return _autocomplete_panel.get_global_rect().has_point(vp.get_mouse_position())


## True when the inline autocomplete panel is open for this LineEdit.
func _is_autocomplete_active_for(edit: LineEdit) -> bool:
	return (_autocomplete_panel != null
			and _autocomplete_panel.visible
			and _autocomplete_target == edit)


## Handles Up/Down/Enter/Escape while the LineEdit keeps focus. Returns true if consumed.
func _handle_autocomplete_key(edit: LineEdit, key: InputEventKey) -> bool:
	if not _is_autocomplete_active_for(edit):
		return false
	match key.keycode:
		KEY_UP:
			_autocomplete_highlight = maxi(0, _autocomplete_highlight - 1)
			_sync_autocomplete_highlight()
			return true
		KEY_DOWN:
			if _autocomplete_list != null:
				_autocomplete_highlight = mini(_autocomplete_list.item_count - 1, _autocomplete_highlight + 1)
			_sync_autocomplete_highlight()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_insert_autocomplete_highlight()
			return true
		KEY_ESCAPE:
			_close_autocomplete()
			return true
	return false


## Updates the list's highlighted row without moving keyboard focus.
func _sync_autocomplete_highlight() -> void:
	if _autocomplete_list == null:
		return
	_autocomplete_list.deselect_all()
	if _autocomplete_list.item_count > 0:
		_autocomplete_highlight = clampi(_autocomplete_highlight, 0, _autocomplete_list.item_count - 1)
		_autocomplete_list.select(_autocomplete_highlight, true)
		_autocomplete_list.ensure_current_is_visible()


## Shows or updates the inline autocomplete popup below the caret in the LineEdit.
func _show_inline_autocomplete(
		edit: LineEdit,
		items: Array[Dictionary],
		partial: String,
		mode: String = "quote") -> void:
	if items.is_empty():
		_close_autocomplete()
		return

	var filtered: Array[Dictionary] = items
	if mode == "quote":
		# Filter by partial text inside quotes
		var q := partial.to_lower()
		filtered = []
		for item in items:
			if q.is_empty() or str(item.id).to_lower().contains(q):
				filtered.append(item)
		if filtered.is_empty():
			_close_autocomplete()
			return

	# Create panel lazily
	if _autocomplete_panel == null:
		_autocomplete_panel = make_expr_autocomplete_suggestion_widget() as Panel
		_autocomplete_list = _autocomplete_panel.get_node("List") as ItemList
		_autocomplete_list.item_selected.connect(_on_autocomplete_list_item_selected)
		add_child(_autocomplete_panel)

	var was_visible := _is_autocomplete_active_for(edit)

	_autocomplete_target = edit
	_autocomplete_mode = mode
	if mode == "general":
		_autocomplete_replace_start = edit.caret_column - partial.length()
	else:
		_autocomplete_replace_start = 0
	_autocomplete_list.clear()

	for i in range(filtered.size()):
		var entry: Dictionary = filtered[i]
		var label: String = str(entry.get("label", entry.id))
		var family_color: Color = entry.get("color", GNFamily.FAMILY_COLORS.get(entry.get("family", -1), Color.WHITE))
		_autocomplete_list.add_item(label)
		_autocomplete_list.set_item_metadata(i, entry)
		var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(family_color)
		var tex := ImageTexture.create_from_image(img)
		_autocomplete_list.set_item_icon(i, tex)
		var tip: String = str(entry.get("description", ""))
		if not tip.is_empty():
			_autocomplete_list.set_item_tooltip(i, tip)

	if not was_visible:
		_autocomplete_highlight = 0
	else:
		_autocomplete_highlight = mini(_autocomplete_highlight, filtered.size() - 1)
	_sync_autocomplete_highlight()

	var row_h := estimate_expr_autocomplete_row_height(_autocomplete_list)
	var list_h := compute_expr_autocomplete_panel_height(row_h, filtered.size())
	_autocomplete_panel.size = Vector2(EXPR_AUTOCOMPLETE_LIST_WIDTH, list_h)
	_autocomplete_panel.global_position = _autocomplete_panel_position(edit)
	_autocomplete_panel.show()
	_fit_autocomplete_panel_height.call_deferred(filtered.size())


## Re-sizes the autocomplete panel after layout so get_item_rect() reflects real row height.
func _fit_autocomplete_panel_height(item_count: int) -> void:
	if _autocomplete_panel == null or _autocomplete_list == null or not _autocomplete_panel.visible:
		return
	var row_h := estimate_expr_autocomplete_row_height(_autocomplete_list)
	var list_h := compute_expr_autocomplete_panel_height(row_h, item_count)
	_autocomplete_panel.size.y = list_h


## Inserts the currently highlighted autocomplete item into the target LineEdit.
func _insert_autocomplete_highlight() -> void:
	if _autocomplete_list == null or _autocomplete_target == null:
		return
	if _autocomplete_highlight < 0 or _autocomplete_highlight >= _autocomplete_list.item_count:
		return
	var meta = _autocomplete_list.get_item_metadata(_autocomplete_highlight)
	_insert_autocomplete_item(meta)


## Inserts one autocomplete entry into the target LineEdit.
func _insert_autocomplete_item(meta: Variant) -> void:
	if _autocomplete_target == null:
		return
	var edit := _autocomplete_target
	var text := edit.text
	var col := edit.caret_column
	var before := text.substr(0, col)
	var after := text.substr(col)

	if _autocomplete_mode == "general":
		if not (meta is Dictionary):
			return
		var insert_text: String = str(meta.get("insert", meta.get("id", "")))
		var new_before := text.substr(0, _autocomplete_replace_start) + insert_text
		edit.text = new_before + after
		edit.caret_column = new_before.length()
	else:
		var selected_id: String = ""
		if meta is Dictionary:
			selected_id = str(meta.get("id", ""))
		else:
			selected_id = str(meta)
		var quote_pos := before.rfind("\"")
		if quote_pos < 0:
			return
		var new_before := before.substr(0, quote_pos + 1) + selected_id
		edit.text = new_before + after
		edit.caret_column = new_before.length()

	edit.grab_focus()
	_close_autocomplete()


## Called when the user clicks a row in the autocomplete list.
func _on_autocomplete_list_item_selected(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if _autocomplete_target == null or _autocomplete_list == null:
		return
	var meta = _autocomplete_list.get_item_metadata(index)
	_insert_autocomplete_item(meta)
	_autocomplete_target.grab_focus()


## Closes the autocomplete panel if open.
func _close_autocomplete() -> void:
	if _autocomplete_panel != null and _autocomplete_panel.visible:
		_autocomplete_panel.hide()
	_autocomplete_target = null
	_autocomplete_mode = ""
	_autocomplete_replace_start = 0
	_autocomplete_highlight = 0
