extends Node
## Unit tests for GNChannelData — CHOP data container.
##
## Tests cover:
##   - Single-value and multi-sample channels
##   - get_channel, get_value, get_channel_names
##   - Index bounds and missing channel behavior
##   - invalidate() clearing
##   - duplicate_data() deep copy

# ═══════════════════════════════════════════════════════════════════════════════
# Basic Channel Operations
# ═══════════════════════════════════════════════════════════════════════════════

func test_set_single_value() -> void:
	var cd := GNChannelData.new()
	cd.set_single_value("out", 42.0)
	GNTestAssert.assert_approx(cd.get_value("out"), 42.0, 0.001, "single value")
	GNTestAssert.assert_eq(cd.length, 1, "length should be 1")


func test_set_channel_multi_sample() -> void:
	var cd := GNChannelData.new()
	var samples := PackedFloat32Array([1.0, 2.0, 3.0, 4.0, 5.0])
	cd.set_channel("wave", samples)
	GNTestAssert.assert_eq(cd.length, 5, "length=5")
	GNTestAssert.assert_approx(cd.get_value("wave", 0), 1.0, 0.001, "first sample")
	GNTestAssert.assert_approx(cd.get_value("wave", 4), 5.0, 0.001, "last sample")


func test_get_value_negative_index_returns_last() -> void:
	var cd := GNChannelData.new()
	cd.set_channel("ch", PackedFloat32Array([10.0, 20.0, 30.0]))
	GNTestAssert.assert_approx(cd.get_value("ch", -1), 30.0, 0.001, "index -1 = last")


func test_get_value_default_index_returns_last() -> void:
	var cd := GNChannelData.new()
	cd.set_channel("ch", PackedFloat32Array([10.0, 20.0, 30.0]))
	# Default index is -1 → last
	GNTestAssert.assert_approx(cd.get_value("ch"), 30.0, 0.001, "default = last")


func test_get_channel_missing() -> void:
	var cd := GNChannelData.new()
	var result := cd.get_channel("nonexistent")
	GNTestAssert.assert_eq(result.size(), 0, "missing channel → empty array")


func test_get_value_missing_channel() -> void:
	var cd := GNChannelData.new()
	# Should return 0.0 and not crash
	var v := cd.get_value("nonexistent")
	GNTestAssert.assert_approx(v, 0.0, 0.001, "missing channel → 0.0")


func test_get_value_out_of_range() -> void:
	var cd := GNChannelData.new()
	cd.set_channel("ch", PackedFloat32Array([1.0, 2.0]))
	var v := cd.get_value("ch", 99)
	GNTestAssert.assert_approx(v, 0.0, 0.001, "out of range → 0.0")


# ═══════════════════════════════════════════════════════════════════════════════
# Channel Names
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_channel_names() -> void:
	var cd := GNChannelData.new()
	cd.set_single_value("tx", 1.0)
	cd.set_single_value("ty", 2.0)
	cd.set_single_value("tz", 3.0)
	var names := cd.get_channel_names()
	GNTestAssert.assert_eq(names.size(), 3, "3 channels")
	# Convert to Array for contains check
	var name_arr: Array = Array(names)
	GNTestAssert.assert_true(name_arr.has("tx"), "has tx")
	GNTestAssert.assert_true(name_arr.has("ty"), "has ty")
	GNTestAssert.assert_true(name_arr.has("tz"), "has tz")


func test_get_channel_names_empty() -> void:
	var cd := GNChannelData.new()
	GNTestAssert.assert_eq(cd.get_channel_names().size(), 0, "empty = no channels")


# ═══════════════════════════════════════════════════════════════════════════════
# Multiple Channels, Length Tracking
# ═══════════════════════════════════════════════════════════════════════════════

func test_length_tracks_largest_channel() -> void:
	var cd := GNChannelData.new()
	cd.set_channel("short", PackedFloat32Array([1.0]))
	GNTestAssert.assert_eq(cd.length, 1, "length=1 after short")
	cd.set_channel("long", PackedFloat32Array([1.0, 2.0, 3.0, 4.0, 5.0]))
	GNTestAssert.assert_eq(cd.length, 5, "length=5 after long")


func test_sample_rate_default() -> void:
	var cd := GNChannelData.new()
	GNTestAssert.assert_approx(cd.sample_rate, 60.0, 0.001, "default sample rate")


# ═══════════════════════════════════════════════════════════════════════════════
# Invalidate
# ═══════════════════════════════════════════════════════════════════════════════

func test_invalidate_clears_channels() -> void:
	var cd := GNChannelData.new()
	cd.set_single_value("out", 5.0)
	cd.valid = true
	cd.invalidate()
	GNTestAssert.assert_eq(cd.channels.size(), 0, "channels cleared")
	GNTestAssert.assert_eq(cd.length, 0, "length reset")
	GNTestAssert.assert_false(cd.valid, "valid=false")


# ═══════════════════════════════════════════════════════════════════════════════
# Deep Copy
# ═══════════════════════════════════════════════════════════════════════════════

func test_duplicate_data_is_independent() -> void:
	var original := GNChannelData.new()
	original.set_channel("ch", PackedFloat32Array([1.0, 2.0, 3.0]))
	original.sample_rate = 44100.0
	original.valid = true

	var copy: GNChannelData = original.duplicate_data() as GNChannelData
	GNTestAssert.assert_not_null(copy, "copy should exist")
	GNTestAssert.assert_approx(copy.sample_rate, 44100.0, 0.001, "sample_rate copied")
	GNTestAssert.assert_true(copy.valid, "valid copied")
	GNTestAssert.assert_eq(copy.length, 3, "length copied")

	# Mutate original — copy should be unchanged
	original.set_single_value("ch", 999.0)
	GNTestAssert.assert_approx(copy.get_value("ch", 0), 1.0, 0.001, "copy is independent")
	GNTestAssert.assert_approx(copy.get_value("ch", 2), 3.0, 0.001, "copy data intact")


# ═══════════════════════════════════════════════════════════════════════════════
# Family Tag
# ═══════════════════════════════════════════════════════════════════════════════

func test_family_is_chop() -> void:
	var cd := GNChannelData.new()
	GNTestAssert.assert_eq(cd.get_family(), GNFamily.Type.CHOP, "family should be CHOP")
