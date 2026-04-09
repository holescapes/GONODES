extends Node
## Unit tests for GNParameter — the typed parameter resource.
##
## Tests cover:
##   - Factory constructors (create_float, create_int, etc.)
##   - Value access, clamping, default reset
##   - Mode switching (CONSTANT ↔ EXPRESSION)
##   - Convenience methods (set_param_reference, set_chop_reference)
##   - Serialization round-trips (to_dict / from_dict)
##   - Legacy migration (BIND → expression, EXPORT → CONSTANT)
##   - Per-component expressions (Vector2, Color)
##   - Expression compilation


# ═══════════════════════════════════════════════════════════════════════════════
# Factory Constructors
# ═══════════════════════════════════════════════════════════════════════════════

func test_create_float_defaults() -> void:
	var p := GNParameter.create_float("opacity", 0.75, 0.0, 1.0, 0.01, "Opacity", "Master opacity")
	GNTestAssert.assert_eq(p.param_name, "opacity", "param_name")
	GNTestAssert.assert_eq(p.value_type, GNParameter.ValueType.FLOAT, "value_type")
	GNTestAssert.assert_approx(p.value, 0.75, 0.001, "initial value")
	GNTestAssert.assert_approx(p.default_value, 0.75, 0.001, "default_value")
	GNTestAssert.assert_eq(p.mode, GNParameter.Mode.CONSTANT, "mode should start CONSTANT")
	GNTestAssert.assert_approx(p.min_value, 0.0, 0.001, "min_value")
	GNTestAssert.assert_approx(p.max_value, 1.0, 0.001, "max_value")
	GNTestAssert.assert_eq(p.label, "Opacity", "label")
	GNTestAssert.assert_eq(p.description, "Master opacity", "description")


func test_create_int() -> void:
	var p := GNParameter.create_int("seed", 42, 0, 999, "Seed", "Random seed")
	GNTestAssert.assert_eq(p.value_type, GNParameter.ValueType.INT, "value_type")
	GNTestAssert.assert_eq(p.value, 42, "initial value")
	GNTestAssert.assert_eq(p.min_value, 0, "min_value")
	GNTestAssert.assert_eq(p.max_value, 999, "max_value")


func test_create_bool() -> void:
	var p := GNParameter.create_bool("active", true, "Active", "Enable this node")
	GNTestAssert.assert_eq(p.value_type, GNParameter.ValueType.BOOL, "value_type")
	GNTestAssert.assert_eq(p.value, true, "initial value")


func test_create_string() -> void:
	var p := GNParameter.create_string("name", "hello", "Name", "Node name")
	GNTestAssert.assert_eq(p.value_type, GNParameter.ValueType.STRING, "value_type")
	GNTestAssert.assert_eq(p.value, "hello", "initial value")


func test_create_enum() -> void:
	var opts := PackedStringArray(["Sine", "Triangle", "Square"])
	var p := GNParameter.create_enum("waveform", opts, 1, "Wave", "Waveform type")
	GNTestAssert.assert_eq(p.value_type, GNParameter.ValueType.ENUM, "value_type")
	GNTestAssert.assert_eq(p.value, 1, "initial index")
	GNTestAssert.assert_eq(p.enum_options.size(), 3, "enum_options size")


func test_create_vector2() -> void:
	var p := GNParameter.create_vector2("offset", Vector2(1.0, 2.0), "Offset")
	GNTestAssert.assert_eq(p.value_type, GNParameter.ValueType.VECTOR2, "value_type")
	GNTestAssert.assert_eq(p.value, Vector2(1.0, 2.0), "initial value")
	GNTestAssert.assert_true(p.is_multi_component(), "should be multi-component")
	GNTestAssert.assert_eq(p.get_component_count(), 2, "component count")


func test_create_color() -> void:
	var p := GNParameter.create_color("tint", Color.RED, "Tint", "Color tint")
	GNTestAssert.assert_eq(p.value_type, GNParameter.ValueType.COLOR, "value_type")
	GNTestAssert.assert_eq(p.value, Color.RED, "initial value")
	GNTestAssert.assert_eq(p.get_component_count(), 4, "component count")


func test_create_file() -> void:
	var filters := PackedStringArray(["*.png", "*.jpg"])
	var p := GNParameter.create_file("image", "", filters, "Image", "Source image")
	GNTestAssert.assert_eq(p.value_type, GNParameter.ValueType.FILE, "value_type")
	GNTestAssert.assert_eq(p.file_filters.size(), 2, "file_filters size")


# ═══════════════════════════════════════════════════════════════════════════════
# Value Access & Clamping
# ═══════════════════════════════════════════════════════════════════════════════

func test_set_value_emits_signal() -> void:
	var p := GNParameter.create_float("x", 0.0, -1.0, 1.0)
	var captured := {"name": "", "val": null}
	p.value_changed.connect(func(pn: String, v: Variant) -> void:
		captured["name"] = pn
		captured["val"] = v
	)
	p.set_value(0.5)
	GNTestAssert.assert_eq(captured["name"], "x", "signal param_name")
	GNTestAssert.assert_approx(captured["val"], 0.5, 0.001, "signal value")


func test_clamping_min() -> void:
	var p := GNParameter.create_float("x", 0.5, 0.0, 1.0)
	p.set_value(-5.0)
	GNTestAssert.assert_approx(p.value, 0.0, 0.001, "clamped to min")


func test_clamping_max() -> void:
	var p := GNParameter.create_float("x", 0.5, 0.0, 1.0)
	p.set_value(99.0)
	GNTestAssert.assert_approx(p.value, 1.0, 0.001, "clamped to max")


func test_no_clamp_when_null_limits() -> void:
	var p := GNParameter.create_float("x", 0.0, null, null)
	p.set_value(-1000.0)
	GNTestAssert.assert_approx(p.value, -1000.0, 0.001, "no min clamp")
	p.set_value(1000.0)
	GNTestAssert.assert_approx(p.value, 1000.0, 0.001, "no max clamp")


func test_get_resolved_value_constant() -> void:
	var p := GNParameter.create_float("x", 5.0)
	GNTestAssert.assert_approx(p.get_resolved_value(), 5.0, 0.001, "constant mode returns value")


func test_get_resolved_value_expression() -> void:
	var p := GNParameter.create_float("x", 5.0)
	p.mode = GNParameter.Mode.EXPRESSION
	p.resolved_value = 42.0
	GNTestAssert.assert_approx(p.get_resolved_value(), 42.0, 0.001, "expression mode returns resolved_value")


# ═══════════════════════════════════════════════════════════════════════════════
# Reset
# ═══════════════════════════════════════════════════════════════════════════════

func test_reset_restores_defaults() -> void:
	var p := GNParameter.create_float("x", 1.0, 0.0, 10.0)
	p.set_value(7.0)
	p.set_expression("time * 2.0")
	GNTestAssert.assert_eq(p.mode, GNParameter.Mode.EXPRESSION, "should be expression before reset")
	p.reset()
	GNTestAssert.assert_eq(p.mode, GNParameter.Mode.CONSTANT, "mode after reset")
	GNTestAssert.assert_approx(p.value, 1.0, 0.001, "value after reset")
	GNTestAssert.assert_empty(p.expression, "expression cleared")


# ═══════════════════════════════════════════════════════════════════════════════
# Mode Switching
# ═══════════════════════════════════════════════════════════════════════════════

func test_set_constant_mode() -> void:
	var p := GNParameter.create_float("x", 0.0, 0.0, 1.0)
	p.set_expression("time")
	GNTestAssert.assert_eq(p.mode, GNParameter.Mode.EXPRESSION, "should be expression")
	p.set_constant(0.5)
	GNTestAssert.assert_eq(p.mode, GNParameter.Mode.CONSTANT, "should be constant")
	GNTestAssert.assert_approx(p.value, 0.5, 0.001, "constant value")


func test_set_expression_mode() -> void:
	var p := GNParameter.create_float("x", 0.0)
	p.set_expression("time * 2.0")
	GNTestAssert.assert_eq(p.mode, GNParameter.Mode.EXPRESSION, "mode")
	GNTestAssert.assert_eq(p.expression, "time * 2.0", "expression text")


func test_mode_changed_signal() -> void:
	var p := GNParameter.create_float("x", 0.0)
	var captured := {"mode": GNParameter.Mode.CONSTANT}
	p.mode_changed.connect(func(_pn: String, m: GNParameter.Mode) -> void:
		captured["mode"] = m
	)
	p.set_expression("time")
	GNTestAssert.assert_eq(captured["mode"], GNParameter.Mode.EXPRESSION, "signal mode")


# ═══════════════════════════════════════════════════════════════════════════════
# Convenience Reference Methods
# ═══════════════════════════════════════════════════════════════════════════════

func test_set_param_reference() -> void:
	var p := GNParameter.create_float("x", 0.0)
	p.set_param_reference("noise1", "scale")
	GNTestAssert.assert_eq(p.mode, GNParameter.Mode.EXPRESSION, "mode")
	GNTestAssert.assert_eq(p.expression, 'par("noise1", "scale")', "expression text")


func test_set_chop_reference_simple() -> void:
	var p := GNParameter.create_float("x", 0.0)
	p.set_chop_reference("lfo1", "out")
	GNTestAssert.assert_eq(p.expression, 'chop("lfo1", "out")', "simple chop ref")


func test_set_chop_reference_with_scale() -> void:
	var p := GNParameter.create_float("x", 0.0)
	p.set_chop_reference("lfo1", "out", 2.0)
	GNTestAssert.assert_contains(p.expression, "* 2", "should have scale multiplier")


func test_set_chop_reference_with_offset() -> void:
	var p := GNParameter.create_float("x", 0.0)
	p.set_chop_reference("lfo1", "out", 1.0, 0.5)
	GNTestAssert.assert_contains(p.expression, "+ 0.5", "should have offset")


func test_set_chop_reference_with_negative_offset() -> void:
	var p := GNParameter.create_float("x", 0.0)
	p.set_chop_reference("lfo1", "out", 1.0, -0.5)
	GNTestAssert.assert_contains(p.expression, "- 0.5", "should have negative offset")


# ═══════════════════════════════════════════════════════════════════════════════
# Expression Compilation
# ═══════════════════════════════════════════════════════════════════════════════

func test_valid_expression_compiles() -> void:
	var p := GNParameter.create_float("x", 0.0)
	p.set_expression("time * 2.0 + 1.0")
	GNTestAssert.assert_true(p.is_expression_valid(), "expression should be valid")
	GNTestAssert.assert_not_null(p.get_compiled_expression(), "compiled object should exist")
	GNTestAssert.assert_empty(p.expression_error, "no error text")


func test_invalid_expression_reports_error() -> void:
	var p := GNParameter.create_float("x", 0.0)
	p.set_expression("(((")
	GNTestAssert.assert_false(p.is_expression_valid(), "expression should be invalid")
	GNTestAssert.assert_not_empty(p.expression_error, "should have error text")


func test_empty_expression_is_invalid() -> void:
	var p := GNParameter.create_float("x", 0.0)
	p.set_expression("")
	GNTestAssert.assert_false(p.is_expression_valid(), "empty expression is invalid")


# ═══════════════════════════════════════════════════════════════════════════════
# Per-Component Expressions
# ═══════════════════════════════════════════════════════════════════════════════

func test_component_labels_vector2() -> void:
	var p := GNParameter.create_vector2("pos", Vector2.ZERO)
	var labels := p.get_component_labels()
	GNTestAssert.assert_eq(labels.size(), 2, "label count")
	GNTestAssert.assert_eq(labels[0], "X", "first label")
	GNTestAssert.assert_eq(labels[1], "Y", "second label")


func test_component_labels_color() -> void:
	var p := GNParameter.create_color("c", Color.WHITE)
	var labels := p.get_component_labels()
	GNTestAssert.assert_eq(labels.size(), 4, "label count")
	GNTestAssert.assert_eq(labels[0], "R")
	GNTestAssert.assert_eq(labels[3], "A")


func test_set_component_expression() -> void:
	var p := GNParameter.create_vector2("pos", Vector2(1.0, 2.0))
	p.set_component_expression(0, "time")
	GNTestAssert.assert_eq(p.mode, GNParameter.Mode.EXPRESSION, "overall mode should be EXPRESSION")
	GNTestAssert.assert_eq(p.component_modes[0], GNParameter.Mode.EXPRESSION, "X should be EXPRESSION")
	GNTestAssert.assert_eq(p.component_modes[1], GNParameter.Mode.CONSTANT, "Y should stay CONSTANT")
	GNTestAssert.assert_true(p.has_any_component_expression(), "has_any_component_expression")


func test_set_component_constant_restores_overall_mode() -> void:
	var p := GNParameter.create_vector2("pos", Vector2.ZERO)
	p.set_component_expression(0, "time")
	GNTestAssert.assert_eq(p.mode, GNParameter.Mode.EXPRESSION, "should be EXPRESSION")
	p.set_component_constant(0)
	GNTestAssert.assert_eq(p.mode, GNParameter.Mode.CONSTANT, "back to CONSTANT when all components constant")


func test_get_component_value_vector2() -> void:
	var p := GNParameter.create_vector2("pos", Vector2(3.0, 7.0))
	GNTestAssert.assert_approx(p.get_component_value(0), 3.0, 0.001, "X")
	GNTestAssert.assert_approx(p.get_component_value(1), 7.0, 0.001, "Y")


func test_set_component_value_vector2() -> void:
	var p := GNParameter.create_vector2("pos", Vector2(1.0, 2.0))
	p.set_component_value(0, 10.0)
	GNTestAssert.assert_eq(p.value, Vector2(10.0, 2.0), "X updated")


func test_get_component_value_color() -> void:
	var c := Color(0.1, 0.2, 0.3, 0.4)
	var p := GNParameter.create_color("c", c)
	GNTestAssert.assert_approx(p.get_component_value(0), 0.1, 0.001, "R")
	GNTestAssert.assert_approx(p.get_component_value(1), 0.2, 0.001, "G")
	GNTestAssert.assert_approx(p.get_component_value(2), 0.3, 0.001, "B")
	GNTestAssert.assert_approx(p.get_component_value(3), 0.4, 0.001, "A")


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization — to_dict / from_dict Round-Trip
# ═══════════════════════════════════════════════════════════════════════════════

func test_to_dict_constant_float() -> void:
	var p := GNParameter.create_float("x", 3.14)
	var d := p.to_dict()
	GNTestAssert.assert_has_key(d, "value", "should have value key")
	GNTestAssert.assert_approx(d["value"], 3.14, 0.001, "serialized value")
	# CONSTANT mode should NOT be saved (it's the default)
	GNTestAssert.assert_false(d.has("mode"), "mode should be omitted for CONSTANT")


func test_to_dict_expression() -> void:
	var p := GNParameter.create_float("x", 0.0)
	p.set_expression("time * 2.0")
	var d := p.to_dict()
	GNTestAssert.assert_eq(d.get("mode", ""), "EXPRESSION", "mode saved")
	GNTestAssert.assert_eq(d.get("expression", ""), "time * 2.0", "expression saved")


func test_round_trip_float() -> void:
	var original := GNParameter.create_float("x", 7.5, 0.0, 100.0)
	original.set_value(42.0)
	var d := original.to_dict()
	var restored := GNParameter.create_float("x", 0.0, 0.0, 100.0)
	restored.from_dict(d)
	GNTestAssert.assert_approx(restored.value, 42.0, 0.001, "restored value")
	GNTestAssert.assert_eq(restored.mode, GNParameter.Mode.CONSTANT, "restored mode")


func test_round_trip_expression() -> void:
	var original := GNParameter.create_float("x", 0.0)
	original.set_expression("time + 1.0")
	var d := original.to_dict()
	var restored := GNParameter.create_float("x", 0.0)
	restored.from_dict(d)
	GNTestAssert.assert_eq(restored.mode, GNParameter.Mode.EXPRESSION, "restored mode")
	GNTestAssert.assert_eq(restored.expression, "time + 1.0", "restored expression")
	GNTestAssert.assert_true(restored.is_expression_valid(), "restored expression should compile")


func test_round_trip_vector2() -> void:
	var original := GNParameter.create_vector2("pos", Vector2(1.0, 2.0))
	original.set_value(Vector2(10.0, 20.0))
	var d := original.to_dict()
	var restored := GNParameter.create_vector2("pos", Vector2.ZERO)
	restored.from_dict(d)
	GNTestAssert.assert_eq(restored.value, Vector2(10.0, 20.0), "restored vector2")


func test_round_trip_color() -> void:
	var c := Color(0.1, 0.2, 0.3, 0.4)
	var original := GNParameter.create_color("tint", Color.WHITE)
	original.set_value(c)
	var d := original.to_dict()
	var restored := GNParameter.create_color("tint", Color.WHITE)
	restored.from_dict(d)
	GNTestAssert.assert_approx(restored.value.r, 0.1, 0.001, "R")
	GNTestAssert.assert_approx(restored.value.g, 0.2, 0.001, "G")
	GNTestAssert.assert_approx(restored.value.b, 0.3, 0.001, "B")
	GNTestAssert.assert_approx(restored.value.a, 0.4, 0.001, "A")


func test_round_trip_component_expressions() -> void:
	var original := GNParameter.create_vector2("pos", Vector2.ZERO)
	original.set_component_expression(0, "time * 5.0")
	var d := original.to_dict()
	GNTestAssert.assert_true(d.has("component_expressions"), "component_expressions saved")
	var restored := GNParameter.create_vector2("pos", Vector2.ZERO)
	restored.from_dict(d)
	GNTestAssert.assert_eq(restored.component_modes[0], GNParameter.Mode.EXPRESSION, "X mode restored")
	GNTestAssert.assert_eq(restored.component_expressions[0], "time * 5.0", "X expression restored")
	GNTestAssert.assert_eq(restored.component_modes[1], GNParameter.Mode.CONSTANT, "Y stays CONSTANT")


# ═══════════════════════════════════════════════════════════════════════════════
# Legacy Migration
# ═══════════════════════════════════════════════════════════════════════════════

func test_legacy_bind_migration() -> void:
	## Simulates loading an old save that used BIND mode.
	## Should auto-convert to EXPRESSION with par() reference.
	var p := GNParameter.create_float("scale", 1.0)
	var legacy_dict := {
		"value": 1.0,
		"mode": "BIND",
		"bind_source_node": "ctrl",
		"bind_source_param": "master_scale",
	}
	p.from_dict(legacy_dict)
	GNTestAssert.assert_eq(p.mode, GNParameter.Mode.EXPRESSION, "BIND→EXPRESSION")
	GNTestAssert.assert_eq(p.expression, 'par("ctrl", "master_scale")', "auto-generated par() expression")


func test_legacy_export_migration() -> void:
	## Simulates loading an old save that used EXPORT mode.
	## Should revert to CONSTANT.
	var p := GNParameter.create_float("scale", 1.0)
	var legacy_dict := {
		"value": 5.0,
		"mode": "EXPORT",
	}
	p.from_dict(legacy_dict)
	GNTestAssert.assert_eq(p.mode, GNParameter.Mode.CONSTANT, "EXPORT→CONSTANT")
	GNTestAssert.assert_approx(p.value, 5.0, 0.001, "value preserved")


func test_legacy_unknown_mode_falls_back() -> void:
	var p := GNParameter.create_float("x", 0.0)
	var d := {"value": 3.0, "mode": "SOME_FUTURE_MODE"}
	p.from_dict(d)
	GNTestAssert.assert_eq(p.mode, GNParameter.Mode.CONSTANT, "unknown mode→CONSTANT")


# ═══════════════════════════════════════════════════════════════════════════════
# Variant Serialization Helpers
# ═══════════════════════════════════════════════════════════════════════════════

func test_variant_to_json_vector3() -> void:
	var v := Vector3(1.0, 2.0, 3.0)
	var j = GNParameter._variant_to_json(v)
	GNTestAssert.assert_true(j is Dictionary, "should be dict")
	GNTestAssert.assert_eq(j["_type"], "Vector3", "type tag")
	GNTestAssert.assert_approx(j["x"], 1.0, 0.001, "x")
	GNTestAssert.assert_approx(j["y"], 2.0, 0.001, "y")
	GNTestAssert.assert_approx(j["z"], 3.0, 0.001, "z")


func test_json_to_variant_vector3() -> void:
	var j := {"_type": "Vector3", "x": 1.0, "y": 2.0, "z": 3.0}
	var v = GNParameter._json_to_variant(j, GNParameter.ValueType.VECTOR3)
	GNTestAssert.assert_eq(v, Vector3(1.0, 2.0, 3.0), "reconstructed vector3")


func test_variant_roundtrip_color() -> void:
	var c := Color(0.5, 0.6, 0.7, 0.8)
	var j = GNParameter._variant_to_json(c)
	var restored = GNParameter._json_to_variant(j, GNParameter.ValueType.COLOR)
	GNTestAssert.assert_approx(restored.r, 0.5, 0.001, "R")
	GNTestAssert.assert_approx(restored.g, 0.6, 0.001, "G")
	GNTestAssert.assert_approx(restored.b, 0.7, 0.001, "B")
	GNTestAssert.assert_approx(restored.a, 0.8, 0.001, "A")


func test_variant_roundtrip_primitives() -> void:
	# float
	GNTestAssert.assert_eq(
		GNParameter._variant_to_json(3.14), 3.14, "float passthrough")
	# int
	GNTestAssert.assert_eq(
		GNParameter._variant_to_json(42), 42, "int passthrough")
	# bool
	GNTestAssert.assert_eq(
		GNParameter._variant_to_json(true), true, "bool passthrough")
	# string
	GNTestAssert.assert_eq(
		GNParameter._variant_to_json("hello"), "hello", "string passthrough")
