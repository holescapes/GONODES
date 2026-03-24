class_name CHOPtoTOP
extends GNTopBase
## Converts CHOP channel data into a TOP texture.
##
## Modes:
##   • Waveform — Renders each channel as a horizontal waveform line drawn
##     into an Image.  Channel value 0→1 maps to bottom→top.
##   • Heatmap — One row per channel, one pixel per sample, brightness =
##     normalised channel value.  Good for spectrogram-like visualisations.
##   • Graph — Similar to waveform but fills underneath each line with a
##     semi-transparent gradient.
##
## The texture is created on the CPU via Image (no SubViewport), which
## keeps things simple and portable.  Later C++ porting can optimise this.


func _init() -> void:
	super._init()
	node_type = "chop_to_top"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, true, "Source CHOP channels")
	add_output("out", GNFamily.Type.TOP, "Rendered texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Waveform", "Heatmap", "Graph"]),
		0, "Mode", "Visualisation style"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 256),
		"Resolution", "Output image size"))
	add_parameter(GNParameter.create_color("background", Color(0.05, 0.05, 0.05, 1.0),
		"Background", "Background colour"))
	add_parameter(GNParameter.create_color("line_color", Color(0.2, 0.8, 0.2, 1.0),
		"Line Color", "Waveform / graph line colour"))
	add_parameter(GNParameter.create_float("line_width", 2.0, 1.0, 8.0, 1.0,
		"Line Width", "Stroke width in pixels (approximate)"))
	add_parameter(GNParameter.create_float("min_val", -1.0, -1000.0, 1000.0, 0.1,
		"Min Value", "Value mapped to bottom of image"))
	add_parameter(GNParameter.create_float("max_val", 1.0, -1000.0, 1000.0, 0.1,
		"Max Value", "Value mapped to top of image"))
	add_parameter(GNParameter.create_bool("auto_range", true,
		"Auto Range", "Automatically fit min/max to channel data"))


func _cook(inputs: Array[GNData]) -> GNData:
	var chop: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	if chop == null or chop.channels.is_empty():
		return null

	var mode: int = get_param_value("mode")
	var res: Vector2i = get_param_value("resolution")
	var bg: Color = get_param_value("background")
	var line_col: Color = get_param_value("line_color")
	var lw: float = get_param_value("line_width")
	var min_v: float = get_param_value("min_val")
	var max_v: float = get_param_value("max_val")
	var auto_range: bool = get_param_value("auto_range")

	var w: int = maxi(res.x, 1)
	var h: int = maxi(res.y, 1)

	var channels: Dictionary = chop.channels
	var ch_names: Array = channels.keys()
	var ch_count: int = ch_names.size()
	if ch_count == 0:
		return null

	# Auto range
	if auto_range:
		min_v = INF
		max_v = -INF
		for ch_name in ch_names:
			var data: PackedFloat32Array = channels[ch_name]
			for val in data:
				min_v = minf(min_v, val)
				max_v = maxf(max_v, val)
		if absf(max_v - min_v) < 0.0001:
			min_v -= 0.5
			max_v += 0.5

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	# Fill background
	img.fill(bg)

	match mode:
		0:
			_draw_waveform(img, channels, ch_names, w, h, min_v, max_v, line_col, lw)
		1:
			_draw_heatmap(img, channels, ch_names, w, h, min_v, max_v, line_col)
		2:
			_draw_graph(img, channels, ch_names, w, h, min_v, max_v, line_col)

	# Create texture from image
	var tex := ImageTexture.create_from_image(img)

	# Ensure cached tex data exists
	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = tex
	_cached_tex_data.resolution = res
	return _cached_tex_data


func _val_to_y(val: float, min_v: float, max_v: float, h: int) -> int:
	var t: float = (val - min_v) / (max_v - min_v) if absf(max_v - min_v) > 0.0001 else 0.5
	t = clampf(t, 0.0, 1.0)
	return clampi(h - 1 - int(t * (h - 1)), 0, h - 1)


func _draw_waveform(img: Image, channels: Dictionary, ch_names: Array,
		w: int, h: int, min_v: float, max_v: float,
		line_col: Color, lw: float) -> void:
	# Multiple channels get different hue offsets
	var ch_count: int = ch_names.size()
	for ci in range(ch_count):
		var data: PackedFloat32Array = channels[ch_names[ci]]
		var col: Color = line_col
		if ch_count > 1:
			col = Color.from_hsv(fmod(line_col.h + float(ci) / float(ch_count), 1.0),
				line_col.s, line_col.v, line_col.a)

		var samples: int = data.size()
		if samples == 0:
			continue

		var half_lw: int = maxi(int(lw * 0.5), 0)

		for px in range(w):
			var t: float = float(px) / float(w - 1) if w > 1 else 0.0
			var si: float = t * float(samples - 1)
			var si0: int = clampi(int(si), 0, samples - 1)
			var si1: int = clampi(si0 + 1, 0, samples - 1)
			var frac: float = si - float(si0)
			var val: float = data[si0] * (1.0 - frac) + data[si1] * frac

			# Also get prev sample for connecting line
			var py_cur: int = _val_to_y(val, min_v, max_v, h)

			# Draw thick point
			for dy in range(-half_lw, half_lw + 1):
				var y: int = clampi(py_cur + dy, 0, h - 1)
				img.set_pixel(px, y, col)

			# Connect to previous pixel vertically
			if px > 0:
				var prev_t: float = float(px - 1) / float(w - 1) if w > 1 else 0.0
				var prev_si: float = prev_t * float(samples - 1)
				var prev_si0: int = clampi(int(prev_si), 0, samples - 1)
				var prev_si1: int = clampi(prev_si0 + 1, 0, samples - 1)
				var prev_frac: float = prev_si - float(prev_si0)
				var prev_val: float = data[prev_si0] * (1.0 - prev_frac) + data[prev_si1] * prev_frac
				var py_prev: int = _val_to_y(prev_val, min_v, max_v, h)

				# Vertical line fill between prev and current
				var y_min: int = mini(py_prev, py_cur)
				var y_max: int = maxi(py_prev, py_cur)
				for y in range(y_min, y_max + 1):
					var yc: int = clampi(y, 0, h - 1)
					img.set_pixel(px, yc, col)


func _draw_heatmap(img: Image, channels: Dictionary, ch_names: Array,
		w: int, h: int, min_v: float, max_v: float, _line_col: Color) -> void:
	var ch_count: int = ch_names.size()
	var row_h: int = maxi(h / ch_count, 1)

	for ci in range(ch_count):
		var data: PackedFloat32Array = channels[ch_names[ci]]
		var samples: int = data.size()
		if samples == 0:
			continue
		var y_start: int = ci * row_h
		var y_end: int = mini(y_start + row_h, h)

		for px in range(w):
			var si: int = clampi(int(float(px) / float(w) * float(samples)), 0, samples - 1)
			var t: float = (data[si] - min_v) / (max_v - min_v) if absf(max_v - min_v) > 0.0001 else 0.5
			t = clampf(t, 0.0, 1.0)
			# Blue–Red colour ramp
			var col := Color(t, 0.2 * (1.0 - absf(t - 0.5) * 2.0), 1.0 - t, 1.0)
			for y in range(y_start, y_end):
				img.set_pixel(px, y, col)


func _draw_graph(img: Image, channels: Dictionary, ch_names: Array,
		w: int, h: int, min_v: float, max_v: float, line_col: Color) -> void:
	var ch_count: int = ch_names.size()

	for ci in range(ch_count):
		var data: PackedFloat32Array = channels[ch_names[ci]]
		var samples: int = data.size()
		if samples == 0:
			continue

		var col: Color = line_col
		if ch_count > 1:
			col = Color.from_hsv(fmod(line_col.h + float(ci) / float(ch_count), 1.0),
				line_col.s, line_col.v, line_col.a)
		var fill_col := Color(col.r, col.g, col.b, col.a * 0.15)

		for px in range(w):
			var t: float = float(px) / float(w - 1) if w > 1 else 0.0
			var si: float = t * float(samples - 1)
			var si0: int = clampi(int(si), 0, samples - 1)
			var si1: int = clampi(si0 + 1, 0, samples - 1)
			var frac: float = si - float(si0)
			var val: float = data[si0] * (1.0 - frac) + data[si1] * frac
			var py: int = _val_to_y(val, min_v, max_v, h)

			# Fill from line to bottom
			for y in range(py, h):
				var yc: int = clampi(y, 0, h - 1)
				if y == py:
					img.set_pixel(px, yc, col)
				else:
					# Blend fill
					var existing: Color = img.get_pixel(px, yc)
					img.set_pixel(px, yc, existing.blend(fill_col))
