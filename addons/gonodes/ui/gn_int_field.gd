class_name GNIntField
extends GNNumericField
## Integer parameter field.  Inherits drag, ladder, and edit mode from
## GNNumericField.  Adds integer-specific value storage, step arrows on
## ranged params, and an integer-tuned ladder (×1 through ×100).


signal value_changed(new_value: int)

## Current value.
var value: int = 0

## Default value for Ctrl+Click reset.
var default_value: int = 0

## Integer ladder: whole-number increments, centered on ×1.
const TIERS       := [1.0, 2.0, 5.0, 10.0, 50.0, 100.0]
const TIER_LABELS := ["×1", "×2", "×5", "×10", "×50", "×100"]
const TIER_CENTER := 0  # ×1

var _drag_start_value: int = 0
var _drag_accum: float = 0.0


# ═══════════════════════════════════════════════════════════════════════════════
# Virtual overrides
# ═══════════════════════════════════════════════════════════════════════════════

func _get_tiers() -> Array:
	return TIERS

func _get_tier_labels() -> Array:
	return TIER_LABELS

func _get_tier_center() -> int:
	return TIER_CENTER

func _reset_to_default() -> void:
	set_value(default_value)

func _on_drag_pending(_position: Vector2) -> void:
	_drag_start_value = value
	_drag_accum = 0.0

func _on_drag_motion(mm: InputEventMouseMotion) -> void:
	var delta_x: float = mm.relative.x
	var multiplier: float = TIERS[_active_tier]
	if mm.shift_pressed:
		multiplier *= 0.1
	elif mm.ctrl_pressed:
		multiplier *= 10.0
	_drag_accum += delta_x * multiplier
	set_value(_drag_start_value + roundi(_drag_accum))

func _on_arrow_click(position: Vector2) -> bool:
	if not _has_range():
		return false
	if position.x < ARROW_HIT_W:
		set_value(value - 1)
		return true
	elif position.x > size.x - ARROW_HIT_W:
		set_value(value + 1)
		return true
	return false

func _apply_text(text: String) -> void:
	text = text.strip_edges()
	if text.is_valid_int():
		set_value(text.to_int())
	elif text.is_valid_float():
		set_value(roundi(text.to_float()))

func _get_display_text() -> String:
	return str(value)

func _get_edit_text() -> String:
	return str(value)

func _get_fill_ratio() -> float:
	if not _has_range():
		return -1.0
	var range_min: int = int(min_value)
	var range_max: int = int(max_value)
	if range_max <= range_min:
		return -1.0
	return clampf(float(value - range_min) / float(range_max - range_min), 0.0, 1.0)

func _draw_extras() -> void:
	if not _has_range():
		return
	var mid_y: float = size.y * 0.5
	var arrow_h: float = 5.0
	var arrow_w: float = 4.0
	var left_color: Color = ARROW_COLOR
	var right_color: Color = ARROW_COLOR
	if _hover:
		left_color = TEXT_COLOR if value > int(min_value) else Color(ARROW_COLOR, 0.25)
		right_color = TEXT_COLOR if value < int(max_value) else Color(ARROW_COLOR, 0.25)
	draw_colored_polygon(PackedVector2Array([
		Vector2(arrow_w + 2, mid_y - arrow_h),
		Vector2(2, mid_y),
		Vector2(arrow_w + 2, mid_y + arrow_h),
	]), left_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x - arrow_w - 2, mid_y - arrow_h),
		Vector2(size.x - 2, mid_y),
		Vector2(size.x - arrow_w - 2, mid_y + arrow_h),
	]), right_color)

func _get_text_padding() -> Vector2:
	if _has_range():
		return Vector2(10.0, 20.0)
	return Vector2(6.0, 12.0)

func _get_bg_color() -> Color:
	match _state:
		_S.DRAGGING: return BG_DRAG
		_S.EDITING:  return BG_NORMAL
		_:           return BG_HOVER if _hover else BG_NORMAL

func _format_sens_label() -> String:
	var per_px: float = TIERS[_active_tier]
	if per_px >= 1.0:
		return "%d/px" % int(per_px)
	return "%.1f/px" % per_px


# ═══════════════════════════════════════════════════════════════════════════════
# Value management
# ═══════════════════════════════════════════════════════════════════════════════

func set_value(v: int) -> void:
	v = _clamp_value(v)
	if v != value:
		value = v
		queue_redraw()
		value_changed.emit(v)


func set_value_no_signal(v: int) -> void:
	v = _clamp_value(v)
	value = v
	queue_redraw()


func _clamp_value(v: int) -> int:
	if min_value != null and v < int(min_value):
		v = int(min_value)
	if max_value != null and v > int(max_value):
		v = int(max_value)
	return v
