class_name GNFixtureData
extends GNData
## Fixture layout data carried between FIX operators.
##
## Describes a set of LED positions in local normalized space (0-1 unit square),
## their DMX routing, and channel layout.  FixtureSamplerTOP applies a placement
## transform to map local positions onto the source image, then samples.

## One entry per LED in local fixture space (0-1 unit square).
## Strip: left-to-right along x. Grid/matrix: row-major fill.
## FixtureSamplerTOP maps these into source-image UV via its placement transforms.
var led_positions: PackedVector2Array = PackedVector2Array()

## Fixture display name (shown in viewer overlay and CHOP channel names).
var fixture_name: String = ""

## Total LED count -- always equals led_positions.size().
var led_count: int = 0

## Channel layout per LED: "rgb", "rgbw", "r", "g", "b", "w"
var channel_layout: String = "rgb"

## Number of scalar channels per LED (3 for rgb, 4 for rgbw, 1 for single).
var channels_per_led: int = 3

## DMX universe (1-based). 0 = unassigned.
var universe: int = 1

## First DMX channel within the universe (1-512). 0 = unassigned.
var start_channel: int = 1

## Shape hint for FixtureSamplerTOP's overlay handle drawing.
## "strip", "grid", "matrix", "custom"
var shape: StringName = &"strip"


func get_family() -> int:
	return GNFamily.string_to_type("FIX")


## Absolute DMX address (0-based) for protocol output.
func get_absolute_dmx() -> int:
	return (universe - 1) * 512 + (start_channel - 1)


func get_preview_text() -> String:
	if led_count == 0:
		return "empty"
	var total_ch: int = led_count * channels_per_led
	var end_ch: int = start_channel + total_ch - 1
	# May span universes
	var uni_str: String = "Uni %d" % universe if end_ch <= 512 else "Uni %d+" % universe
	return "%s\n%d LEDs - %s\n%s Ch %d-%d" % [fixture_name, led_count, channel_layout, uni_str, start_channel, start_channel + total_ch - 1]


func get_data_summary() -> String:
	if led_count == 0:
		return ""
	return "%s (%d-%s U%d.%d)" % [fixture_name, led_count, channel_layout, universe, start_channel]


func invalidate() -> void:
	super.invalidate()
	led_positions = PackedVector2Array()
	led_count = 0


func duplicate_data() -> GNData:
	var copy := GNFixtureData.new()
	copy.valid = valid
	copy.timestamp = timestamp
	copy.metadata = metadata.duplicate(true)
	copy.led_positions = led_positions.duplicate()
	copy.fixture_name = fixture_name
	copy.led_count = led_count
	copy.channel_layout = channel_layout
	copy.channels_per_led = channels_per_led
	copy.universe = universe
	copy.start_channel = start_channel
	copy.shape = shape
	return copy


## Returns channels_per_led for a given channel_layout string.
static func channels_for_layout(layout: String) -> int:
	match layout:
		"rgb":   return 3
		"rgbw":  return 4
		"r", "g", "b", "w": return 1
	return 3


func get_expression_value(key: String, _index: int = -1) -> Variant:
	match key:
		"led_count":        return float(led_count)
		"universe":         return float(universe)
		"start_channel":    return float(start_channel)
		"channels_per_led": return float(channels_per_led)
		"name":             return fixture_name
	return 0.0


func get_expression_info() -> Dictionary:
	return {
		"led_count":        led_count,
		"universe":         universe,
		"start_channel":    start_channel,
		"channels_per_led": channels_per_led,
		"name":             fixture_name,
	}
