class_name GNFixtureData
extends GNData
## Fixture layout data carried between FIX operators.
##
## Describes a set of LED positions in UV space (0–1 on both axes),
## their DMX routing, and channel layout.  FixtureSamplerTOP merges
## all connected GNFixtureData objects into a single GPU sample pass.

## One entry per LED — each is a Vector2 in UV space (0–1, 0–1).
## Packed in raster order for the GPU: row-major for grids, sequential for strips.
var led_positions: PackedVector2Array = PackedVector2Array()

## Fixture display name (shown in viewer overlay).
var fixture_name: String = ""

## Total LED count — always equals led_positions.size().
var led_count: int = 0

## Channel layout per LED: "rgb", "rgbw", "r", "g", "b", "w"
var channel_layout: String = "rgb"

## Number of scalar channels per LED (3 for rgb, 4 for rgbw, 1 for single).
var channels_per_led: int = 3

## DMX universe+channel of the first LED's first channel.
## Encoded as universe * 512 + channel_index (1-based).
## 0 = unassigned.
var dmx_start: int = 0

## Optional: area sampling half-extent in UV space per LED.
## Vector2.ZERO = point-sample; Vector2(w, h) = box-filter over that UV area.
var sample_extent: Vector2 = Vector2.ZERO


func get_family() -> int:
	return GNFamily.string_to_type("FIX")


func get_preview_text() -> String:
	if led_count == 0:
		return "empty"
	return "%s\n%d LEDs · %s" % [fixture_name, led_count, channel_layout]


func get_data_summary() -> String:
	if led_count == 0:
		return ""
	return "%s (%d·%s)" % [fixture_name, led_count, channel_layout]


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
	copy.dmx_start = dmx_start
	copy.sample_extent = sample_extent
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
		"led_count":       return float(led_count)
		"dmx_start":       return float(dmx_start)
		"channels_per_led": return float(channels_per_led)
		"name":            return fixture_name
	return 0.0


func get_expression_info() -> Dictionary:
	return {
		"led_count":        led_count,
		"dmx_start":        dmx_start,
		"channels_per_led": channels_per_led,
		"name":             fixture_name,
	}
