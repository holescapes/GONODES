class_name HistogramIMG
extends GNImgBase
## CPU-side histogram analyser.
##
## Takes an IMG (or TOP via TOPtoIMG) and bins pixel intensities into
## R / G / B / Luma channels.  Outputs a chart image showing the
## distribution, useful for grading reference or feeding back into
## a procedural pipeline.
##
## This is intentionally IMG family because it performs a per-pixel
## CPU readback loop — see the GPU/CPU Family Rule in DATA_TYPES.md.

const CHART_BG := Color(0.08, 0.08, 0.08, 1.0)
const CHART_GRID := Color(0.2, 0.2, 0.2, 0.6)


func _init() -> void:
	node_type = "histogram"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "Source image to analyse")
	add_output("out", GNFamily.Type.IMG, "Histogram chart image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_bins", 256, 16, 512,
		"Bins", "Number of histogram bins"))
	add_parameter(GNParameter.create_bool("show_rgb", true,
		"Show RGB", "Draw separate R, G, B curves"))
	add_parameter(GNParameter.create_bool("show_luma", true,
		"Show Luma", "Draw the luminance curve"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 256),
		"Resolution", "Output chart size in pixels"))
	add_parameter(GNParameter.create_float("smoothing", 0.0, 0.0, 4.0, 0.1,
		"Smoothing", "Gaussian smoothing radius applied to the histogram curves"))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()
	var src := _get_input_img(inputs, 0)
	if src == null or src.image == null:
		return out

	var num_bins: int = get_param_value("num_bins")
	var show_rgb: bool = get_param_value("show_rgb")
	var show_luma: bool = get_param_value("show_luma")
	var res: Vector2i = get_param_value("resolution")
	var smoothing: float = get_param_value("smoothing")

	# ── Bin the source image ───────────────────────────────────────────────
	var bins_r := PackedFloat32Array()
	var bins_g := PackedFloat32Array()
	var bins_b := PackedFloat32Array()
	var bins_l := PackedFloat32Array()
	bins_r.resize(num_bins); bins_r.fill(0.0)
	bins_g.resize(num_bins); bins_g.fill(0.0)
	bins_b.resize(num_bins); bins_b.fill(0.0)
	bins_l.resize(num_bins); bins_l.fill(0.0)

	var img: Image = src.image
	var w: int = img.get_width()
	var h: int = img.get_height()
	var last_bin: int = num_bins - 1

	for y in range(h):
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			var ri: int = clampi(int(c.r * last_bin), 0, last_bin)
			var gi: int = clampi(int(c.g * last_bin), 0, last_bin)
			var bi: int = clampi(int(c.b * last_bin), 0, last_bin)
			var luma: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			var li: int = clampi(int(luma * last_bin), 0, last_bin)
			bins_r[ri] += 1.0
			bins_g[gi] += 1.0
			bins_b[bi] += 1.0
			bins_l[li] += 1.0

	# ── Optional smoothing ─────────────────────────────────────────────────
	if smoothing > 0.0:
		bins_r = _smooth(bins_r, smoothing)
		bins_g = _smooth(bins_g, smoothing)
		bins_b = _smooth(bins_b, smoothing)
		bins_l = _smooth(bins_l, smoothing)

	# ── Normalise to 0..1 ─────────────────────────────────────────────────
	var peak: float = 1.0
	for i in range(num_bins):
		if show_rgb:
			peak = maxf(peak, maxf(bins_r[i], maxf(bins_g[i], bins_b[i])))
		if show_luma:
			peak = maxf(peak, bins_l[i])
	var inv_peak: float = 1.0 / peak

	# ── Draw chart ─────────────────────────────────────────────────────────
	var chart := Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)
	chart.fill(CHART_BG)

	# grid lines at 25 % intervals
	for frac in [0.25, 0.5, 0.75]:
		var gx: int = int(frac * (res.x - 1))
		for gy in range(res.y):
			chart.set_pixel(gx, gy, CHART_GRID)

	# draw curves
	if show_rgb:
		_draw_curve(chart, bins_r, inv_peak, Color(1, 0, 0, 0.7), res)
		_draw_curve(chart, bins_g, inv_peak, Color(0, 1, 0, 0.7), res)
		_draw_curve(chart, bins_b, inv_peak, Color(0.3, 0.3, 1, 0.7), res)
	if show_luma:
		_draw_curve(chart, bins_l, inv_peak, Color(0.85, 0.85, 0.85, 0.9), res)

	out.set_image(chart)
	return out


# ── Helpers ────────────────────────────────────────────────────────────────────

func _draw_curve(chart: Image, bins: PackedFloat32Array, inv_peak: float,
		color: Color, res: Vector2i) -> void:
	var num_bins: int = bins.size()
	for col_x in range(res.x):
		var bin_f: float = float(col_x) / float(res.x - 1) * float(num_bins - 1)
		var bi: int = clampi(int(bin_f), 0, num_bins - 1)
		var val: float = bins[bi] * inv_peak
		var bar_h: int = clampi(int(val * res.y), 0, res.y)
		# Draw from bottom up
		for row_y in range(bar_h):
			var py: int = res.y - 1 - row_y
			var existing: Color = chart.get_pixel(col_x, py)
			# Additive blend for overlapping curves
			chart.set_pixel(col_x, py, Color(
				minf(existing.r + color.r * color.a * 0.5, 1.0),
				minf(existing.g + color.g * color.a * 0.5, 1.0),
				minf(existing.b + color.b * color.a * 0.5, 1.0),
				1.0
			))


## Simple 1D Gaussian blur on a PackedFloat32Array.
func _smooth(bins: PackedFloat32Array, radius: float) -> PackedFloat32Array:
	var n: int = bins.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var r: int = ceili(radius * 2.0)
	for i in range(n):
		var total: float = 0.0
		var weight_sum: float = 0.0
		for k in range(-r, r + 1):
			var j: int = clampi(i + k, 0, n - 1)
			var w: float = exp(-0.5 * (float(k) / radius) * (float(k) / radius))
			total += bins[j] * w
			weight_sum += w
		out[i] = total / weight_sum
	return out
