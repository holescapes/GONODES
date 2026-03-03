extends Node
## Unit + integration tests for the RampCHOP operator.
##
## Tests cover:
##   - Default initialization (params, port, slot count)
##   - Single-sample output (scalar mode for chop() reads)
##   - Multi-sample output (curve evaluation)
##   - Empty channel names are skipped
##   - Dynamic count increase / decrease (slots added/removed)
##   - Custom ramp keypoints produce correct output
##   - Serialization round-trip (to_dict → from_dict) preserves dynamic count
##   - Cook-engine integration: RampCHOP output readable via chop() expression

var _engine: GNCookEngine
var _network: GNNetwork


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func before_each() -> void:
	_network = GNNetwork.new()
	_engine = GNCookEngine.new()
	_engine.network = _network
	_engine.cooking_enabled = false
	_engine.elapsed_time = 1.0
	_engine.frame_count = 60
	_engine.current_delta = 1.0 / 60.0
	add_child(_engine)


func after_each() -> void:
	if is_instance_valid(_engine):
		_engine.queue_free()
	_engine = null
	_network = null


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _make_ramp(id: String) -> RampCHOP:
	var node := RampCHOP.new()
	node.initialize(id)
	_network.add_node(node)
	return node


func _cook() -> void:
	_engine.cook_frame(_engine.current_delta)


func _out(node: GNNode) -> GNChannelData:
	return node.cached_output as GNChannelData


# ═══════════════════════════════════════════════════════════════════════════════
# Initialization
# ═══════════════════════════════════════════════════════════════════════════════

func test_default_init() -> void:
	var r := _make_ramp("r1")
	GNTestAssert.assert_eq(r.node_type, "ramp", "node_type")
	GNTestAssert.assert_eq(r.family, GNFamily.Type.CHOP, "family")
	# Default params: samples, count, name0, ramp0, name1, ramp1
	GNTestAssert.assert_true(r.parameters.has("samples"), "has samples param")
	GNTestAssert.assert_true(r.parameters.has("count"), "has count param")
	GNTestAssert.assert_true(r.parameters.has("name0"), "has name0")
	GNTestAssert.assert_true(r.parameters.has("ramp0"), "has ramp0")
	GNTestAssert.assert_true(r.parameters.has("name1"), "has name1")
	GNTestAssert.assert_true(r.parameters.has("ramp1"), "has ramp1")
	GNTestAssert.assert_eq(r.get_param_value("count"), 2, "default count is 2")
	GNTestAssert.assert_eq(r.get_param_value("samples"), 1, "default samples is 1")
	# Output port
	GNTestAssert.assert_eq(r.output_ports.size(), 1, "1 output port")


# ═══════════════════════════════════════════════════════════════════════════════
# Single-Sample Output (Scalar Mode)
# ═══════════════════════════════════════════════════════════════════════════════

func test_single_sample_default_ramp() -> void:
	## Default linear ramp (0→1) sampled at t=1.0 should output 1.0.
	var r := _make_ramp("r1")
	_cook()
	var data := _out(r)
	GNTestAssert.assert_true(data != null, "output not null")
	GNTestAssert.assert_true(data.channels.has("ramp0"), "has channel ramp0")
	GNTestAssert.assert_true(data.channels.has("ramp1"), "has channel ramp1")
	# Default linear ramp evaluated at t=1.0 → 1.0
	GNTestAssert.assert_approx(data.get_value("ramp0"), 1.0, 0.01, "ramp0 value at t=1")
	GNTestAssert.assert_approx(data.get_value("ramp1"), 1.0, 0.01, "ramp1 value at t=1")


# ═══════════════════════════════════════════════════════════════════════════════
# Multi-Sample Output
# ═══════════════════════════════════════════════════════════════════════════════

func test_multi_sample_linear_ramp() -> void:
	## Linear ramp with 5 samples should produce evenly spaced 0→1 values.
	var r := _make_ramp("r1")
	r.set_param_value("samples", 5)
	r.set_param_value("count", 1)
	_cook()
	var data := _out(r)
	GNTestAssert.assert_true(data != null, "output not null")
	var ch := data.get_channel("ramp0")
	GNTestAssert.assert_eq(ch.size(), 5, "5 samples")
	GNTestAssert.assert_approx(ch[0], 0.0, 0.01, "sample 0 = 0.0")
	GNTestAssert.assert_approx(ch[2], 0.5, 0.01, "sample 2 = 0.5")
	GNTestAssert.assert_approx(ch[4], 1.0, 0.01, "sample 4 = 1.0")


# ═══════════════════════════════════════════════════════════════════════════════
# Empty Channel Names Skipped
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_name_skipped() -> void:
	var r := _make_ramp("r1")
	r.set_param_value("count", 2)
	r.set_param_value("name1", "")
	_cook()
	var data := _out(r)
	GNTestAssert.assert_true(data.channels.has("ramp0"), "ramp0 present")
	GNTestAssert.assert_false(data.channels.has(""), "empty key not in channels")
	GNTestAssert.assert_eq(data.channels.size(), 1, "only 1 channel output")


# ═══════════════════════════════════════════════════════════════════════════════
# Dynamic Count (Increase / Decrease)
# ═══════════════════════════════════════════════════════════════════════════════

func test_increase_count() -> void:
	var r := _make_ramp("r1")
	GNTestAssert.assert_false(r.parameters.has("name2"), "no name2 before increase")
	r.set_param_value("count", 4)
	_cook()
	# After cook, slots 0-3 should exist
	GNTestAssert.assert_true(r.parameters.has("name2"), "name2 exists after increase")
	GNTestAssert.assert_true(r.parameters.has("ramp2"), "ramp2 exists after increase")
	GNTestAssert.assert_true(r.parameters.has("name3"), "name3 exists after increase")
	GNTestAssert.assert_true(r.parameters.has("ramp3"), "ramp3 exists after increase")
	var data := _out(r)
	GNTestAssert.assert_eq(data.channels.size(), 4, "4 channels output")


func test_decrease_count() -> void:
	var r := _make_ramp("r1")
	r.set_param_value("count", 4)
	_cook()  # Build 4 slots
	GNTestAssert.assert_true(r.parameters.has("ramp3"), "ramp3 before decrease")
	r.set_param_value("count", 1)
	_cook()
	GNTestAssert.assert_false(r.parameters.has("name1"), "name1 removed")
	GNTestAssert.assert_false(r.parameters.has("ramp1"), "ramp1 removed")
	GNTestAssert.assert_false(r.parameters.has("ramp3"), "ramp3 removed")
	var data := _out(r)
	GNTestAssert.assert_eq(data.channels.size(), 1, "only 1 channel after decrease")


# ═══════════════════════════════════════════════════════════════════════════════
# Custom Ramp Keypoints
# ═══════════════════════════════════════════════════════════════════════════════

func test_custom_ramp_curve() -> void:
	## V-shaped ramp: 1→0→1 over 3 keypoints.
	var r := _make_ramp("r1")
	r.set_param_value("count", 1)
	r.set_param_value("samples", 3)
	var v_keys: Array = [
		{"pos": 0.0, "value": 1.0, "left_tangent": 0.0, "right_tangent": 0.0},
		{"pos": 0.5, "value": 0.0, "left_tangent": 0.0, "right_tangent": 0.0},
		{"pos": 1.0, "value": 1.0, "left_tangent": 0.0, "right_tangent": 0.0},
	]
	r.set_param_value("ramp0", v_keys)
	_cook()
	var ch := _out(r).get_channel("ramp0")
	GNTestAssert.assert_eq(ch.size(), 3, "3 samples")
	GNTestAssert.assert_approx(ch[0], 1.0, 0.01, "start = 1.0")
	GNTestAssert.assert_approx(ch[1], 0.0, 0.01, "mid = 0.0")
	GNTestAssert.assert_approx(ch[2], 1.0, 0.01, "end = 1.0")


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization Round-Trip
# ═══════════════════════════════════════════════════════════════════════════════

func test_serialization_round_trip() -> void:
	## Save with 4 ramp slots, custom name, custom ramp → restore and verify.
	var r := _make_ramp("r1")
	r.set_param_value("count", 4)
	_cook()  # Build the 4 slots first
	# Now customize slot 2 (exists after cook)
	r.set_param_value("name2", "falloff")
	var custom_keys: Array = [
		{"pos": 0.0, "value": 0.0, "left_tangent": 0.0, "right_tangent": 0.0},
		{"pos": 0.5, "value": 1.0, "left_tangent": 0.0, "right_tangent": 0.0},
		{"pos": 1.0, "value": 0.5, "left_tangent": 0.0, "right_tangent": 0.0},
	]
	r.set_param_value("ramp2", custom_keys)
	_cook()  # Re-cook with customized values

	# Serialize
	var d := r.to_dict()
	GNTestAssert.assert_true(d.has("parameters"), "dict has parameters")

	# Create a new RampCHOP and restore
	var r2 := RampCHOP.new()
	r2.initialize("r2")
	r2.from_dict(d)

	# Count should be 4
	GNTestAssert.assert_eq(r2.get_param_value("count"), 4, "restored count = 4")
	# name2 should be "falloff"
	GNTestAssert.assert_eq(r2.get_param_value("name2"), "falloff", "restored name2")
	# ramp2 should have 3 keys
	var restored_keys: Array = r2.get_param_value("ramp2")
	GNTestAssert.assert_eq(restored_keys.size(), 3, "restored ramp2 has 3 keys")
	GNTestAssert.assert_approx(float(restored_keys[1].get("value", -1.0)), 1.0, 0.01,
		"restored ramp2 mid key value")
	# Slots 0-3 should exist
	GNTestAssert.assert_true(r2.parameters.has("ramp3"), "ramp3 exists after restore")


# ═══════════════════════════════════════════════════════════════════════════════
# Cook Engine Integration: chop() expression reads RampCHOP output
# ═══════════════════════════════════════════════════════════════════════════════

func test_chop_expression_reads_ramp_output() -> void:
	## RampCHOP["curves"] → ConstantCHOP["reader"] via chop("curves", "ramp0")
	var r := _make_ramp("curves")
	# Default linear ramp at samples=1 → ramp0 = 1.0

	var reader := ConstantCHOP.new()
	reader.initialize("reader")
	_network.add_node(reader)
	# Set value0 expression to read ramp0 channel from "curves"
	var p: GNParameter = reader.get_parameter("value0")
	p.mode = GNParameter.Mode.EXPRESSION
	p.expression = "chop(\"curves\", \"ramp0\")"

	_cook()
	var data := _out(reader)
	GNTestAssert.assert_true(data != null, "reader output not null")
	# ramp0 channel on "curves" outputs 1.0, so reader's value0 should be 1.0
	var val: float = data.get_value("chan1")
	GNTestAssert.assert_approx(val, 1.0, 0.01,
		"reader reads ramp0=1.0 via chop() expression")
