class_name GNParamRow
extends HBoxContainer
## A single parameter row in the inspector.
## Renders the appropriate control for the parameter's ValueType and tracks
## its mode (CONSTANT vs EXPRESSION). Edits flow back to the GNParameter model.

## The parameter this row controls.
var param: GNParameter = null

## The owning GNNode (for dirty marking).
var owner_node: GNNode = null

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


# ═══════════════════════════════════════════════════════════════════════════════
# Construction
# ═══════════════════════════════════════════════════════════════════════════════

## Builds this row for the given parameter. Call once after creation.
func setup(p_param: GNParameter, p_owner: GNNode) -> void:
	param = p_param
	owner_node = p_owner

	size_flags_horizontal = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)

	# Mode toggle button (C = constant, E = expression)
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
	add_child(_name_label)

	# Value container — holds either the value control or the expression editor
	_value_container = HBoxContainer.new()
	_value_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_value_container.add_theme_constant_override("separation", 2)
	add_child(_value_container)

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

	# Wire parameter signals for external updates
	param.value_changed.connect(_on_param_value_changed)
	param.mode_changed.connect(_on_param_mode_changed)

	# Set initial state
	_update_mode_display()
	_update_value_display()


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
	var edit := LineEdit.new()
	edit.text = str(param.value)
	edit.size_flags_horizontal = SIZE_EXPAND_FILL
	edit.text_submitted.connect(_on_string_changed)
	return edit


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
	match param.mode:
		GNParameter.Mode.CONSTANT:
			_mode_btn.text = "C"
			_mode_btn.modulate = Color(0.5, 0.8, 0.5)  # Green tint
			if _control:
				_control.visible = true
			_expr_edit.visible = false
		GNParameter.Mode.EXPRESSION:
			_mode_btn.text = "E"
			_mode_btn.modulate = Color(0.8, 0.6, 0.2)  # Orange tint
			if _control:
				_control.visible = false
			_expr_edit.visible = true
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
	if param == null or _expr_edit == null:
		return
	if not param.expression_error.is_empty():
		_expr_edit.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		_expr_edit.tooltip_text = param.expression_error
	else:
		_expr_edit.remove_theme_color_override("font_color")
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
			var edit := _control as LineEdit
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

	_updating = false


# ═══════════════════════════════════════════════════════════════════════════════
# Cleanup
# ═══════════════════════════════════════════════════════════════════════════════

## Disconnects signals when this row is removed.
func cleanup() -> void:
	if param:
		if param.value_changed.is_connected(_on_param_value_changed):
			param.value_changed.disconnect(_on_param_value_changed)
		if param.mode_changed.is_connected(_on_param_mode_changed):
			param.mode_changed.disconnect(_on_param_mode_changed)
