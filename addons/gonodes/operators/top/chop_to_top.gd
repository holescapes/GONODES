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
## The texture is created on the CPU via Image (no SubViewport).
## One Image and one ImageTexture are reused. The pixels are redrawn only
## when the samples, style, or fitted range actually change.

var _smooth_min: float = INF
var _smooth_max: float = -INF
var _img: Image = null
var _tex: ImageTexture = null
var _last_picture_key: int = 0


func _init() -> void:
	super._init()
	node_type = "chop_to_top"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, true, "Source CHOP channels", "In")
	add_output("out", GNFamily.Type.TOP, "Rendered texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Waveform", "Heatmap", "Graph", "Spectrogram"]),
		0, "Mode", "Visualisation style"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 256),
		"Resolution", "Output image size"))
	add_parameter(GNParameter.create_color("background", Color(0.05, 0.05, 0.05, 1.0),
		"Background", "Background colour"))
	add_parameter(GNParameter.create_color("line_color", Color(0.2, 0.8, 0.2, 1.0),
		"Line Color", "Waveform / graph line colour"))
	var p_lw := GNParameter.create_float("line_width", 2.0, 1.0, 8.0, 1.0,
		"Line Width", "Stroke width in pixels (approximate)")
	p_lw.visibility_rule = {"param": "mode", "values": [0, 2]}
	add_parameter(p_lw)
	add_parameter(GNParameter.create_float("min_val", -1.0, -1000.0, 1000.0, 0.1,
		"Min Value", "Value mapped to bottom of image"))
	add_parameter(GNParameter.create_float("max_val", 1.0, -1000.0, 1000.0, 0.1,
		"Max Value", "Value mapped to top of image"))
	add_parameter(GNParameter.create_bool("auto_range", true,
		"Auto Range", "Automatically fit min/max to channel data"))
	# Spectrogram-specific params
	var p_nb := GNParameter.create_int("num_bands", 64, 8, 512, "Bands",
		"Number of frequency bands (width of output)")
	p_nb.visibility_rule = {"param": "mode", "values": [3]}
	add_parameter(p_nb)
	var p_mel := GNParameter.create_bool("mel_scale", true, "Mel Scale",
		"Logarithmic (mel) frequency mapping — perceptual pitch spacing")
	p_mel.visibility_rule = {"param": "mode", "values": [3]}
	add_parameter(p_mel)
	var p_cs := GNParameter.create_enum("color_scheme",
		PackedStringArray(["Grayscale", "Heat", "Plasma"]),
		1, "Colors", "Spectrogram colour palette")
	p_cs.visibility_rule = {"param": "mode", "values": [3]}
	add_parameter(p_cs)


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

	# Auto range — smooth expansion with 10% headroom padding
	if auto_range:
		var frame_min: float = INF
		var frame_max: float = -INF
		for ch_name in ch_names:
			var data: PackedFloat32Array = channels[ch_name]
			for val in data:
				frame_min = minf(frame_min, val)
				frame_max = maxf(frame_max, val)
		# Add 10% padding so the waveform doesn't slam against edges
		var span: float = frame_max - frame_min
		if span < 0.0001:
			span = 1.0
		var pad: float = span * 0.1
		frame_min -= pad
		frame_max += pad
		# Smooth: expand instantly, shrink slowly (decay toward current range)
		if _smooth_min == INF:
			_smooth_min = frame_min
			_smooth_max = frame_max
		else:
			_smooth_min = minf(_smooth_min, frame_min)
			_smooth_max = maxf(_smooth_max, frame_max)
			# Slowly decay toward the current frame range
			_smooth_min = lerpf(_smooth_min, frame_min, 0.05)
			_smooth_max = lerpf(_smooth_max, frame_max, 0.05)
		min_v = _smooth_min
		max_v = _smooth_max
		if absf(max_v - min_v) < 0.0001:
			min_v -= 0.5
			max_v += 0.5
	else:
		# Reset smooth state when auto_range is off
		_smooth_min = INF
		_smooth_max = -INF

	var picture_key := _picture_key(channels, ch_names, mode, w, h, bg, line_col, lw, min_v, max_v)
	if picture_key == _last_picture_key and _tex != null and _cached_tex_data != null:
		return _cached_tex_data

	if _img == null or _img.get_width() != w or _img.get_height() != h \
			or _img.get_format() != Image.FORMAT_RGBA8:
		_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_img.fill(bg)
	var img := _img

	match mode:
		0:
			_draw_waveform(img, channels, ch_names, w, h, min_v, max_v, line_col, lw)
		1:
			_draw_heatmap(img, channels, ch_names, w, h, min_v, max_v, line_col)
		2:
			_draw_graph(img, channels, ch_names, w, h, min_v, max_v, line_col)
		3:
			_draw_spectrogram(img, channels, ch_names, w, h, min_v, max_v)

	if _tex == null or _tex.get_width() != w or _tex.get_height() != h:
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)
	_last_picture_key = picture_key

	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _tex
	_cached_tex_data.resolution = res
	return _cached_tex_data


func _picture_key(channels: Dictionary, ch_names: Array, mode: int, w: int, h: int,
		bg: Color, line_col: Color, lw: float, min_v: float, max_v: float) -> int:
	var key := mode
	key = key * 31 + w
	key = key * 31 + h
	key = key * 31 + hash(bg)
	key = key * 31 + hash(line_col)
	key = key * 31 + hash(lw)
	key = key * 31 + int(round(min_v * 10000.0))
	key = key * 31 + int(round(max_v * 10000.0))
	key = key * 31 + int(get_param_value("num_bands"))
	key = key * 31 + int(bool(get_param_value("mel_scale")))
	key = key * 31 + int(get_param_value("color_scheme"))
	for ch_name in ch_names:
		key = key * 31 + hash(str(ch_name))
		key = key * 31 + _hash_samples(channels[ch_name])
	return key


static func _hash_samples(data: PackedFloat32Array) -> int:
	var h := data.size() * 16777619
	for v in data:
		h = (h * 16777619) ^ int(round(v * 100000.0))
	return h


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


func _draw_spectrogram(img: Image, channels: Dictionary, ch_names: Array,
		w: int, h: int, min_v: float, max_v: float) -> void:
	## Renders CHOP channels as a single-frame spectrogram row.
	## Each channel = one frequency band. X = band index, Y = single row (full height).
	## Chain → CacheTOP + LayoutTOP (vertical) for a scrolling waterfall.
	var num_bands: int = get_param_value("num_bands")
	var mel: bool = get_param_value("mel_scale")
	var scheme: int = get_param_value("color_scheme")
	var ch_count: int = ch_names.size()
	if ch_count == 0:
		return

	# Use the first channel's samples as frequency bins, or average all channels
	var bins := PackedFloat32Array()
	var first_data: PackedFloat32Array = channels[ch_names[0]]
	var src_len: int = first_data.size()
	if src_len == 0:
		return

	# Resample/remap to num_bands
	bins.resize(num_bands)
	for b in range(num_bands):
		var t: float = float(b) / float(num_bands - 1) if num_bands > 1 else 0.0
		# Mel scale: logarithmic frequency mapping
		if mel:
			t = (pow(10.0, t) - 1.0) / 9.0
		var si: float = t * float(src_len - 1)
		var si0: int = clampi(int(si), 0, src_len - 1)
		var si1: int = clampi(si0 + 1, 0, src_len - 1)
		var frac: float = si - float(si0)
		bins[b] = first_data[si0] * (1.0 - frac) + first_data[si1] * frac

	# Draw — each band = one vertical column, full height
	var range_span: float = max_v - min_v
	if absf(range_span) < 0.0001:
		range_span = 1.0

	for px in range(w):
		var band_idx: int = clampi(int(float(px) / float(w) * float(num_bands)), 0, num_bands - 1)
		var val: float = clampf((bins[band_idx] - min_v) / range_span, 0.0, 1.0)
		var col: Color = _spectrogram_color(val, scheme)
		for y in range(h):
			img.set_pixel(px, y, col)


static func _spectrogram_color(t: float, scheme: int) -> Color:
	match scheme:
		0:  # Grayscale
			return Color(t, t, t, 1.0)
		1:  # Heat (black → red → yellow → white)
			return Color(
				clampf(t * 3.0, 0.0, 1.0),
				clampf(t * 3.0 - 1.0, 0.0, 1.0),
				clampf(t * 3.0 - 2.0, 0.0, 1.0), 1.0)
		2:  # Plasma (dark purple → magenta → orange → yellow)
			var r: float = clampf(0.5 + 0.5 * sin(3.14159 * (t * 0.95 + 0.1)), 0.0, 1.0)
			var g: float = clampf(0.5 + 0.5 * sin(3.14159 * (t * 0.95 - 0.35)), 0.0, 1.0)
			var b_val: float = clampf(0.5 + 0.5 * sin(3.14159 * (t * 0.95 + 0.7)), 0.0, 1.0)
			return Color(r, g, b_val, 1.0)
		_:
			return Color(t, t, t, 1.0)
