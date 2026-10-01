extends Node
## Unit tests for RAMP parameter type and network annotations.
##
## Tests cover:
##   - Ramp parameter factory (create_ramp)
##   - Ramp value sampling (sample_ramp) — linear, boundary, single-key
##   - Ramp serialization round-trip (to_dict / from_dict)
##   - Variant serialization for ramp data (_variant_to_json / _json_to_variant)
##   - Network annotation CRUD (add, get, update, remove)
##   - Network annotation serialization round-trip


# ═══════════════════════════════════════════════════════════════════════════════
# RAMP Parameter Factory
# ═══════════════════════════════════════════════════════════════════════════════

func test_create_ramp_defaults() -> void:
	var p := GNParameter.create_ramp("falloff", [], "Falloff", "Smooth falloff curve")
	GNTestAssert.assert_eq(p.param_name, "falloff", "param_name")
	GNTestAssert.assert_eq(p.value_type, GNParameter.ValueType.RAMP, "value_type")
	GNTestAssert.assert_eq(p.label, "Falloff", "label")
	GNTestAssert.assert_eq(p.description, "Smooth falloff curve", "description")
	GNTestAssert.assert_true(p.value is Array, "value is Array")
	var keys: Array = p.value
	GNTestAssert.assert_eq(keys.size(), 2, "default has 2 keys")
	GNTestAssert.assert_approx(float(keys[0].get("pos", -1.0)), 0.0, 0.001, "first key pos=0")
	GNTestAssert.assert_approx(float(keys[0].get("value", -1.0)), 0.0, 0.001, "first key value=0")
	GNTestAssert.assert_approx(float(keys[1].get("pos", -1.0)), 1.0, 0.001, "second key pos=1")
	GNTestAssert.assert_approx(float(keys[1].get("value", -1.0)), 1.0, 0.001, "second key value=1")


func test_create_ramp_custom_keys() -> void:
	var custom_keys: Array = [
		{"pos": 0.0, "value": 1.0, "left_tangent": 0.0, "right_tangent": -2.0},
		{"pos": 0.5, "value": 0.0, "left_tangent": 0.0, "right_tangent": 0.0},
		{"pos": 1.0, "value": 1.0, "left_tangent": 2.0, "right_tangent": 0.0},
	]
	var p := GNParameter.create_ramp("bounce", custom_keys, "Bounce")
	var keys: Array = p.value
	GNTestAssert.assert_eq(keys.size(), 3, "3 custom keys")
	GNTestAssert.assert_approx(float(keys[1].get("pos", -1.0)), 0.5, 0.001, "mid key pos")
	GNTestAssert.assert_approx(float(keys[1].get("value", -1.0)), 0.0, 0.001, "mid key value")


func test_ramp_not_multi_component() -> void:
	var p := GNParameter.create_ramp("r", [])
	GNTestAssert.assert_eq(p.get_component_count(), 0, "RAMP component count is 0")
	GNTestAssert.assert_false(p.is_multi_component(), "RAMP is NOT multi-component")


# ═══════════════════════════════════════════════════════════════════════════════
# Ramp Sampling (sample_ramp)
# ═══════════════════════════════════════════════════════════════════════════════

func test_sample_ramp_linear() -> void:
	## Default linear ramp: (0,0) → (1,1) with zero tangents = linear
	var keys: Array = [
		{"pos": 0.0, "value": 0.0, "left_tangent": 0.0, "right_tangent": 0.0},
		{"pos": 1.0, "value": 1.0, "left_tangent": 0.0, "right_tangent": 0.0},
	]
	# With zero tangents, cubic Hermite simplifies to linear blend
	GNTestAssert.assert_approx(GNParameter.sample_ramp(keys, 0.0), 0.0, 0.01, "t=0")
	GNTestAssert.assert_approx(GNParameter.sample_ramp(keys, 0.5), 0.5, 0.01, "t=0.5")
	GNTestAssert.assert_approx(GNParameter.sample_ramp(keys, 1.0), 1.0, 0.01, "t=1")


func test_sample_ramp_boundary_clamp() -> void:
	var keys: Array = [
		{"pos": 0.2, "value": 0.3, "left_tangent": 0.0, "right_tangent": 0.0},
		{"pos": 0.8, "value": 0.7, "left_tangent": 0.0, "right_tangent": 0.0},
	]
	# Before first key
	GNTestAssert.assert_approx(GNParameter.sample_ramp(keys, 0.0), 0.3, 0.001, "before first key")
	GNTestAssert.assert_approx(GNParameter.sample_ramp(keys, 0.1), 0.3, 0.001, "still before first key")
	# After last key
	GNTestAssert.assert_approx(GNParameter.sample_ramp(keys, 0.9), 0.7, 0.001, "after last key")
	GNTestAssert.assert_approx(GNParameter.sample_ramp(keys, 1.0), 0.7, 0.001, "at end")


func test_sample_ramp_single_key() -> void:
	var keys: Array = [{"pos": 0.5, "value": 0.75}]
	GNTestAssert.assert_approx(GNParameter.sample_ramp(keys, 0.0), 0.75, 0.001, "single key at t=0")
	GNTestAssert.assert_approx(GNParameter.sample_ramp(keys, 1.0), 0.75, 0.001, "single key at t=1")


func test_sample_ramp_empty() -> void:
	GNTestAssert.assert_approx(GNParameter.sample_ramp([], 0.5), 0.0, 0.001, "empty ramp returns 0")


func test_sample_ramp_three_keys() -> void:
	var keys: Array = [
		{"pos": 0.0, "value": 0.0, "left_tangent": 0.0, "right_tangent": 0.0},
		{"pos": 0.5, "value": 1.0, "left_tangent": 0.0, "right_tangent": 0.0},
		{"pos": 1.0, "value": 0.0, "left_tangent": 0.0, "right_tangent": 0.0},
	]
	GNTestAssert.assert_approx(GNParameter.sample_ramp(keys, 0.0), 0.0, 0.01, "start")
	GNTestAssert.assert_approx(GNParameter.sample_ramp(keys, 0.5), 1.0, 0.01, "peak")
	GNTestAssert.assert_approx(GNParameter.sample_ramp(keys, 1.0), 0.0, 0.01, "end")
	# Midpoint of first segment should be ~0.5
	var mid := GNParameter.sample_ramp(keys, 0.25)
	GNTestAssert.assert_true(mid > 0.3 and mid < 0.7, "t=0.25 should be roughly mid (%f)" % mid)


func test_sample_ramp_clamped_t() -> void:
	var keys: Array = [
		{"pos": 0.0, "value": 0.0, "left_tangent": 0.0, "right_tangent": 0.0},
		{"pos": 1.0, "value": 1.0, "left_tangent": 0.0, "right_tangent": 0.0},
	]
	GNTestAssert.assert_approx(GNParameter.sample_ramp(keys, -5.0), 0.0, 0.001, "t<0 clamped")
	GNTestAssert.assert_approx(GNParameter.sample_ramp(keys, 5.0), 1.0, 0.001, "t>1 clamped")


# ═══════════════════════════════════════════════════════════════════════════════
# RAMP Serialization
# ═══════════════════════════════════════════════════════════════════════════════

func test_ramp_variant_to_json() -> void:
	var keys: Array = [
		{"pos": 0.0, "value": 0.0, "left_tangent": 0.0, "right_tangent": 0.0},
		{"pos": 1.0, "value": 1.0, "left_tangent": 0.0, "right_tangent": 0.0},
	]
	var j = GNParameter._variant_to_json(keys)
	GNTestAssert.assert_true(j is Dictionary, "ramp JSON is dict")
	GNTestAssert.assert_eq(j.get("_type", ""), "Ramp", "type tag is Ramp")
	GNTestAssert.assert_true(j.get("keys", null) is Array, "keys array present")
	GNTestAssert.assert_eq(j["keys"].size(), 2, "2 keys serialized")


func test_ramp_json_to_variant() -> void:
	var j := {"_type": "Ramp", "keys": [
		{"pos": 0.0, "value": 0.5},
		{"pos": 1.0, "value": 0.8},
	]}
	var restored = GNParameter._json_to_variant(j, GNParameter.ValueType.RAMP)
	GNTestAssert.assert_true(restored is Array, "restored is Array")
	GNTestAssert.assert_eq(restored.size(), 2, "2 keys restored")
	GNTestAssert.assert_approx(float(restored[0].get("value", -1)), 0.5, 0.001, "key 0 value")


func test_ramp_raw_array_json_to_variant() -> void:
	## Forward-compat: accept raw Array without _type wrapper
	var raw_arr: Array = [
		{"pos": 0.0, "value": 0.0},
		{"pos": 1.0, "value": 1.0},
	]
	var restored = GNParameter._json_to_variant(raw_arr, GNParameter.ValueType.RAMP)
	GNTestAssert.assert_true(restored is Array, "raw array accepted")
	GNTestAssert.assert_eq(restored.size(), 2, "2 keys from raw")


func test_ramp_round_trip() -> void:
	var original := GNParameter.create_ramp("gradient")
	# Modify keys
	var keys: Array = original.value
	keys.append({"pos": 0.5, "value": 0.75, "left_tangent": 1.0, "right_tangent": -1.0})
	original.set_value(keys)

	var d := original.to_dict()
	GNTestAssert.assert_true(d.has("value"), "to_dict has value")

	var restored := GNParameter.create_ramp("gradient")
	restored.from_dict(d)
	var rkeys: Array = restored.value
	GNTestAssert.assert_eq(rkeys.size(), 3, "3 keys restored")
	GNTestAssert.assert_approx(float(rkeys[2].get("pos", -1)), 0.5, 0.001, "mid key pos")
	GNTestAssert.assert_approx(float(rkeys[2].get("left_tangent", 0)), 1.0, 0.001, "mid key left_tangent")


# ═══════════════════════════════════════════════════════════════════════════════
# Network Annotation CRUD
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_annotation_box() -> void:
	var net := GNNetwork.new()
	var ann_id := net.add_annotation("box", Vector2(100, 200), Vector2(300, 200), "My Group", Color.BLUE)
	GNTestAssert.assert_true(ann_id.begins_with("ann_"), "annotation ID prefix")
	GNTestAssert.assert_eq(net.annotations.size(), 1, "1 annotation")
	var ann = net.get_annotation(ann_id)
	GNTestAssert.assert_true(ann != null, "annotation found")
	GNTestAssert.assert_eq(ann["type"], "box", "type is box")
	GNTestAssert.assert_eq(ann["text"], "My Group", "text matches")


func test_add_annotation_note() -> void:
	var net := GNNetwork.new()
	var ann_id := net.add_annotation("note", Vector2(50, 50), Vector2(200, 120), "TODO: fix this")
	GNTestAssert.assert_eq(net.annotations.size(), 1, "1 annotation")
	var ann = net.get_annotation(ann_id)
	GNTestAssert.assert_eq(ann["type"], "note", "type is note")
	GNTestAssert.assert_eq(ann["text"], "TODO: fix this", "text matches")


func test_update_annotation() -> void:
	var net := GNNetwork.new()
	var ann_id := net.add_annotation("box", Vector2.ZERO)
	net.update_annotation(ann_id, {"text": "Updated", "position": Vector2(42, 42)})
	var ann = net.get_annotation(ann_id)
	GNTestAssert.assert_eq(ann["text"], "Updated", "text updated")
	GNTestAssert.assert_eq(ann["position"], Vector2(42, 42), "position updated")


func test_remove_annotation() -> void:
	var net := GNNetwork.new()
	var id1 := net.add_annotation("box", Vector2.ZERO)
	var id2 := net.add_annotation("note", Vector2(100, 100))
	GNTestAssert.assert_eq(net.annotations.size(), 2, "2 annotations before remove")
	var ok := net.remove_annotation(id1)
	GNTestAssert.assert_true(ok, "remove succeeded")
	GNTestAssert.assert_eq(net.annotations.size(), 1, "1 annotation after remove")
	GNTestAssert.assert_true(net.get_annotation(id1) == null, "removed annotation not found")
	GNTestAssert.assert_true(net.get_annotation(id2) != null, "other annotation still exists")


func test_remove_nonexistent_annotation() -> void:
	var net := GNNetwork.new()
	var ok := net.remove_annotation("ann_999")
	GNTestAssert.assert_false(ok, "removing nonexistent returns false")


func test_get_annotation_nonexistent() -> void:
	var net := GNNetwork.new()
	var result = net.get_annotation("ann_999")
	GNTestAssert.assert_true(result == null, "nonexistent returns null")


# ═══════════════════════════════════════════════════════════════════════════════
# Annotation Serialization Round-Trip
# ═══════════════════════════════════════════════════════════════════════════════

func test_annotation_serialization_round_trip() -> void:
	var net := GNNetwork.new()
	net.add_annotation("box", Vector2(10, 20), Vector2(300, 200), "Group A", Color(0.5, 0.3, 0.2, 0.6))
	net.add_annotation("note", Vector2(50, 100), Vector2(150, 80), "Remember this", Color(1.0, 1.0, 0.5, 0.9))

	var d := net.to_dict()
	GNTestAssert.assert_true(d.has("annotations"), "to_dict has annotations key")
	var ann_arr: Array = d["annotations"]
	GNTestAssert.assert_eq(ann_arr.size(), 2, "2 annotations serialized")

	# Verify box
	GNTestAssert.assert_eq(ann_arr[0]["type"], "box", "first is box")
	GNTestAssert.assert_eq(ann_arr[0]["text"], "Group A", "box text")

	# Verify note
	GNTestAssert.assert_eq(ann_arr[1]["type"], "note", "second is note")
	GNTestAssert.assert_eq(ann_arr[1]["text"], "Remember this", "note text")

	# Restore into a fresh network
	var net2 := GNNetwork.new()
	var ok := net2.from_dict(d)
	GNTestAssert.assert_true(ok, "from_dict succeeded")
	GNTestAssert.assert_eq(net2.annotations.size(), 2, "2 annotations restored")

	var restored_box: Dictionary = net2.annotations[0]
	GNTestAssert.assert_eq(restored_box["type"], "box", "restored type")
	GNTestAssert.assert_eq(restored_box["text"], "Group A", "restored text")
	GNTestAssert.assert_true(restored_box["position"] is Vector2, "position is Vector2")
	GNTestAssert.assert_true(restored_box["color"] is Color, "color is Color")
	GNTestAssert.assert_approx(restored_box["position"].x, 10.0, 0.001, "pos.x")
	GNTestAssert.assert_approx(restored_box["position"].y, 20.0, 0.001, "pos.y")
	GNTestAssert.assert_approx(restored_box["color"].r, 0.5, 0.01, "color.r")
	GNTestAssert.assert_approx(restored_box["color"].a, 0.6, 0.01, "color.a")


func test_annotation_id_counter_restored() -> void:
	## After loading, new annotation IDs should not collide with loaded ones.
	var net := GNNetwork.new()
	net.add_annotation("box", Vector2.ZERO)  # ann_1
	net.add_annotation("box", Vector2.ZERO)  # ann_2
	net.add_annotation("box", Vector2.ZERO)  # ann_3

	var d := net.to_dict()
	var net2 := GNNetwork.new()
	net2.from_dict(d)

	# Add a new annotation — should be ann_4 or higher, not collide with ann_1/2/3
	var new_id := net2.add_annotation("note", Vector2.ZERO)
	GNTestAssert.assert_true(new_id != "ann_1" and new_id != "ann_2" and new_id != "ann_3",
		"new ID (%s) does not collide with loaded IDs" % new_id)


func test_no_annotations_key_when_empty() -> void:
	var net := GNNetwork.new()
	var d := net.to_dict()
	GNTestAssert.assert_false(d.has("annotations"), "no annotations key when empty")


func test_annotation_font_size_round_trip() -> void:
	var net := GNNetwork.new()
	var ann_id := net.add_annotation("note", Vector2.ZERO, Vector2(200, 120), "Big note")
	net.update_annotation(ann_id, {"font_size": 24})

	var d := net.to_dict()
	GNTestAssert.assert_true(d.has("annotations"), "to_dict has annotations key")
	var ann_arr: Array = d["annotations"]
	GNTestAssert.assert_eq(ann_arr.size(), 1, "1 annotation serialized")
	GNTestAssert.assert_eq(ann_arr[0]["font_size"], 24, "font_size serialized")

	var net2 := GNNetwork.new()
	var ok := net2.from_dict(d)
	GNTestAssert.assert_true(ok, "from_dict succeeded")
	var restored: Dictionary = net2.annotations[0]
	GNTestAssert.assert_eq(int(restored.get("font_size", 12)), 24, "font_size restored")


func test_annotation_font_size_default() -> void:
	var net := GNNetwork.new()
	net.add_annotation("note", Vector2.ZERO)
	var d := net.to_dict()
	var net2 := GNNetwork.new()
	net2.from_dict(d)
	var ann: Dictionary = net2.annotations[0]
	GNTestAssert.assert_false(ann.has("font_size"), "no font_size key when default")
	GNTestAssert.assert_eq(int(ann.get("font_size", 12)), 12, "missing font_size loads as 12")


func test_clear_all_clears_annotations() -> void:
	var net := GNNetwork.new()
	net.add_annotation("box", Vector2.ZERO)
	net.add_annotation("note", Vector2.ZERO)
	GNTestAssert.assert_eq(net.annotations.size(), 2, "2 before clear")
	# from_dict calls _clear_all internally
	net.from_dict({"nodes": {}, "connections": []})
	GNTestAssert.assert_eq(net.annotations.size(), 0, "0 after clear")
