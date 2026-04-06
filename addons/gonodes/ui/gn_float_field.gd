class_name GNFloatField
extends GNNumericField
## Float parameter field.  Inherits drag, ladder, and edit mode from
## GNNumericField.  Adds float-specific value storage, precision display,
## suffix support, and a rangeless background tint.


signal value_changed(new_value: float)

## Current value.
var value: float = 0.0

## Step size for drag sensitivity and display precision.
var step: float = 0.01

## Default value for Ctrl+Click reset.
var default_value: float = 0.0

## Optional suffix appended to the display text (e.g. "°").
var suffix: String = ""

## Ladder tiers for float: sub-unit precision up to ×100.
const TIERS       := [0.001, 0.01, 0.1, 1.0, 10.0, 100.0]
const TIER_LABELS := ["×0.001", "×0.01", "×0.1", "×1", "×10", "×100"]
const TIER_CENTER := 3  # ×1

var _drag_start_value: float = 0.0


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

func _on_drag_motion(mm: InputEventMouseMotion) -> void:
	var delta_x: float = mm.relative.x
	var multiplier: float = TIERS[_active_tier]
	if mm.shift_pressed:
		multiplier *= 0.1
	elif mm.ctrl_pressed:
		multiplier *= 10.0
	set_value(value + delta_x * step * multiplier)

func _apply_text(text: String) -> void:
	text = text.strip_edges()
	if text.is_valid_float():
		set_value(text.to_float())

func _get_display_text() -> String:
	var text: String = _format_value_raw()
	if not suffix.is_empty():
		text += suffix
	return text

func _get_edit_text() -> String:
	return _format_value_raw()

func _get_fill_ratio() -> float:
	if not _has_range():
		return -1.0
	var range_min: float = float(min_value)
	var range_max: float = float(max_value)
	if range_max <= range_min:
		return -1.0
	return clampf((value - range_min) / (range_max - range_min), 0.0, 1.0)

func _get_bg_color() -> Color:
	match _state:
		_S.DRAGGING: return BG_DRAG
		_S.EDITING:  return BG_NORMAL
		_:
			if _hover:
				return BG_HOVER
			elif not _has_range():
				return BG_NORMAL_RANGELESS
			else:
				return BG_NORMAL

func _format_sens_label() -> String:
	var per_px: float = step * TIERS[_active_tier]
	if per_px >= 1.0:
		return "%d/px" % int(per_px)
	elif per_px >= 0.1:
		return "%.1f/px" % per_px
	elif per_px >= 0.01:
		return "%.2f/px" % per_px
	elif per_px >= 0.001:
		return "%.3f/px" % per_px
	else:
		return "%.4f/px" % per_px


# ═══════════════════════════════════════════════════════════════════════════════
# Value management
# ═══════════════════════════════════════════════════════════════════════════════

func set_value(v: float) -> void:
	v = _clamp_value(v)
	if not is_equal_approx(v, value):
		value = v
		queue_redraw()
		value_changed.emit(v)


func set_value_no_signal(v: float) -> void:
	v = _clamp_value(v)
	value = v
	queue_redraw()


func _clamp_value(v: float) -> float:
	if min_value != null and v < float(min_value):
		v = float(min_value)
	if max_value != null and v > float(max_value):
		v = float(max_value)
	return v


# ═══════════════════════════════════════════════════════════════════════════════
# Formatting
# ═══════════════════════════════════════════════════════════════════════════════

func _format_value_raw() -> String:
	var prec: int = _auto_precision()
	return ("%." + str(prec) + "f") % value


func _auto_precision() -> int:
	if step >= 1.0:
		return 0
	if step >= 0.1:
		return 1
	if step >= 0.01:
		return 2
	return 3
