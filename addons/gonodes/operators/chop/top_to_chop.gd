class_name TOPtoCHOP
extends GNChopBase
## Samples pixel data from a TOP texture and converts it to CHOP channels.
## Supports four modes: full-image Average, CenterPixel, per-Row average,
## and per-Column average.  Per-channel (R/G/B/A) toggles control which
## colour components are output.


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "toptochop"
	node_description = "Sample TOP texture pixels as CHOP channels."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Source TOP texture")
	add_output("out", GNFamily.Type.CHOP, "Sampled colour channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Average", "CenterPixel", "RowAverage", "ColumnAverage"]), 0,
		"Mode", "How to sample the texture"))
	add_parameter(GNParameter.create_bool("channel_r", true,
		"Red", "Output red channel"))
	add_parameter(GNParameter.create_bool("channel_g", true,
		"Green", "Output green channel"))
	add_parameter(GNParameter.create_bool("channel_b", true,
		"Blue", "Output blue channel"))
	add_parameter(GNParameter.create_bool("channel_a", false,
		"Alpha", "Output alpha channel"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	var tex_data: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_data == null or tex_data.texture == null:
		GNLogger.warn("TOPtoCHOP", "'%s' — no valid TOP input" % id)
		return null

	var mode: int = get_param_value("mode")
	var want_r: bool = get_param_value("channel_r")
	var want_g: bool = get_param_value("channel_g")
	var want_b: bool = get_param_value("channel_b")
	var want_a: bool = get_param_value("channel_a")

	var img: Image = tex_data.texture.get_image()
	if img == null:
		GNLogger.warn("TOPtoCHOP", "'%s' — could not get Image from texture" % id)
		return null

	var out: GNChannelData = _prepare_output(60.0)

	var w: int = img.get_width()
	var h: int = img.get_height()
	if w == 0 or h == 0:
		return out

	match mode:
		0:  # Average — single value per channel
			_mode_average(img, out, w, h, want_r, want_g, want_b, want_a)
		1:  # CenterPixel — single value per channel
			_mode_center_pixel(img, out, w, h, want_r, want_g, want_b, want_a)
		2:  # RowAverage — one sample per row
			_mode_row_average(img, out, w, h, want_r, want_g, want_b, want_a)
		3:  # ColumnAverage — one sample per column
			_mode_column_average(img, out, w, h, want_r, want_g, want_b, want_a)

	return out


# ═══════════════════════════════════════════════════════════════════════════════
# Sampling Modes
# ═══════════════════════════════════════════════════════════════════════════════

func _mode_average(img: Image, out: GNChannelData, w: int, h: int,
		want_r: bool, want_g: bool, want_b: bool, want_a: bool) -> void:
	var sum_r: float = 0.0
	var sum_g: float = 0.0
	var sum_b: float = 0.0
	var sum_a: float = 0.0
	var total: float = float(w * h)

	for y in range(h):
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			sum_r += c.r
			sum_g += c.g
			sum_b += c.b
			sum_a += c.a

	if want_r:
		out.set_single_value("r", sum_r / total)
	if want_g:
		out.set_single_value("g", sum_g / total)
	if want_b:
		out.set_single_value("b", sum_b / total)
	if want_a:
		out.set_single_value("a", sum_a / total)


func _mode_center_pixel(img: Image, out: GNChannelData, w: int, h: int,
		want_r: bool, want_g: bool, want_b: bool, want_a: bool) -> void:
	var cx: int = w / 2
	var cy: int = h / 2
	var c: Color = img.get_pixel(cx, cy)

	if want_r:
		out.set_single_value("r", c.r)
	if want_g:
		out.set_single_value("g", c.g)
	if want_b:
		out.set_single_value("b", c.b)
	if want_a:
		out.set_single_value("a", c.a)


func _mode_row_average(img: Image, out: GNChannelData, w: int, h: int,
		want_r: bool, want_g: bool, want_b: bool, want_a: bool) -> void:
	var arr_r := PackedFloat32Array()
	var arr_g := PackedFloat32Array()
	var arr_b := PackedFloat32Array()
	var arr_a := PackedFloat32Array()
	arr_r.resize(h)
	arr_g.resize(h)
	arr_b.resize(h)
	arr_a.resize(h)

	var inv_w: float = 1.0 / float(w)
	for y in range(h):
		var sr: float = 0.0
		var sg: float = 0.0
		var sb: float = 0.0
		var sa: float = 0.0
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			sr += c.r
			sg += c.g
			sb += c.b
			sa += c.a
		arr_r[y] = sr * inv_w
		arr_g[y] = sg * inv_w
		arr_b[y] = sb * inv_w
		arr_a[y] = sa * inv_w

	if want_r:
		out.set_channel("r", arr_r)
	if want_g:
		out.set_channel("g", arr_g)
	if want_b:
		out.set_channel("b", arr_b)
	if want_a:
		out.set_channel("a", arr_a)
	out.length = h


func _mode_column_average(img: Image, out: GNChannelData, w: int, h: int,
		want_r: bool, want_g: bool, want_b: bool, want_a: bool) -> void:
	var arr_r := PackedFloat32Array()
	var arr_g := PackedFloat32Array()
	var arr_b := PackedFloat32Array()
	var arr_a := PackedFloat32Array()
	arr_r.resize(w)
	arr_g.resize(w)
	arr_b.resize(w)
	arr_a.resize(w)

	var inv_h: float = 1.0 / float(h)
	for x in range(w):
		var sr: float = 0.0
		var sg: float = 0.0
		var sb: float = 0.0
		var sa: float = 0.0
		for y in range(h):
			var c: Color = img.get_pixel(x, y)
			sr += c.r
			sg += c.g
			sb += c.b
			sa += c.a
		arr_r[x] = sr * inv_h
		arr_g[x] = sg * inv_h
		arr_b[x] = sb * inv_h
		arr_a[x] = sa * inv_h

	if want_r:
		out.set_channel("r", arr_r)
	if want_g:
		out.set_channel("g", arr_g)
	if want_b:
		out.set_channel("b", arr_b)
	if want_a:
		out.set_channel("a", arr_a)
	out.length = w
