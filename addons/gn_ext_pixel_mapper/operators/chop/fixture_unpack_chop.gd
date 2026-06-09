class_name FixtureUnpackCHOP
extends GNChopBase
## Unpacks the packed result texture from FixtureSamplerTOP into named CHOP channels.
##
## Reads the tiny packed texture (channels_per_led × total_leds pixels) back to CPU
## and emits one CHOP channel per fixture·LED·colour component.
##
## Channel naming:
##   "<fixture_name>.<channel>.<led_index>"  e.g. "strip.r.0", "strip.g.0", "strip.b.0"
##
## Channel layout abbreviations: rgb → r/g/b, rgbw → r/g/b/w, r/g/b/w → single channel.
##
## NOTE: CPU readback of the result texture is intentional here — the packed texture
## is tiny (1–4 px wide × total_leds tall, e.g. 3×288 = 864 pixels) so the readback
## cost is negligible. The heavy GPU work (sampling the source image) already happened
## in FixtureSamplerTOP. This node is the bridge from GPU to DMX values.

const _LAYOUT_CHANNELS: Dictionary = {
	"rgb":  ["r", "g", "b"],
	"rgbw": ["r", "g", "b", "w"],
	"r":    ["r"],
	"g":    ["g"],
	"b":    ["b"],
	"w":    ["w"],
}


func _init() -> void:
	node_type = "fixture_unpack"
	node_description = "Unpacks FixtureSamplerTOP result into named CHOP channels. Wire output to DmxOutCHOP."


func _init_ports() -> void:
	add_input("sampler", GNFamily.Type.TOP, true, "Packed result texture from FixtureSamplerTOP")
	add_output("out", GNFamily.Type.CHOP, "Per-LED colour channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("value_range",
		PackedStringArray(["0–1 Float", "0–255 Integer"]), 0,
		"Value Range", "Output channel values as 0–1 floats or 0–255 integers."))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_data: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_data == null or tex_data.texture == null:
		node_warning = "No FixtureSamplerTOP connected."
		return null

	# Find the upstream FixtureSamplerTOP to get the fixture manifest
	var sampler: FixtureSamplerTOP = _find_upstream_sampler(inputs[0])
	if sampler == null or sampler._fixture_manifest.is_empty():
		node_warning = "Upstream node is not a FixtureSamplerTOP or has no fixtures."
		return null

	# CPU readback of the packed result texture
	var img: Image = tex_data.texture.get_image()
	if img == null:
		node_warning = "Cannot read result texture."
		return null

	node_warning = ""
	var scale: float = 255.0 if get_param_value("value_range") == 1 else 1.0

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
	_cached_channel_data.sample_rate = 60.0
	_cached_channel_data.length = 1

	var max_w: int = img.get_width()

	for entry in sampler._fixture_manifest:
		var fix_name: String = entry["name"]
		var led_count: int = entry["led_count"]
		var cpl: int = entry["channels_per_led"]
		var offset: int = entry["offset"]

		# Determine channel name list from layout
		var ch_names: Array = []
		for layout_key in _LAYOUT_CHANNELS:
			if GNFixtureData.channels_for_layout(layout_key) == cpl:
				ch_names = _LAYOUT_CHANNELS[layout_key]
				break
		if ch_names.is_empty():
			ch_names = ["ch0", "ch1", "ch2", "ch3"].slice(0, cpl)

		for ch_i in range(cpl):
			if ch_i >= max_w:
				continue
			var ch_label: String = ch_names[ch_i] if ch_i < ch_names.size() else ("ch%d" % ch_i)

			# Build a PackedFloat32Array — one value per LED
			var values := PackedFloat32Array()
			values.resize(led_count)
			for led_i in range(led_count):
				var pixel: Color = img.get_pixel(ch_i, offset + led_i)
				values[led_i] = pixel.r * scale

			var ch_full_name: String = "%s.%s" % [fix_name, ch_label]
			_cached_channel_data.set_channel(ch_full_name, values)

	_cached_channel_data.length = _cached_channel_data.channels.values()[0].size() if not _cached_channel_data.channels.is_empty() else 1
	return _cached_channel_data


## Walks upstream to find the FixtureSamplerTOP that produced this texture.
## Returns null if not found (fallback: manifest will be empty).
func _find_upstream_sampler(_data: GNData) -> FixtureSamplerTOP:
	var net: GNNetwork = _get_network()
	if net == null:
		return null
	# Find which node is connected to our input port 0
	for conn in net.connections:
		if conn.to_node == id and conn.to_port == 0:
			var src: GNNode = net.get_node(conn.from_node)
			if src is FixtureSamplerTOP:
				return src as FixtureSamplerTOP
	return null
