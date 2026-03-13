class_name AnalyzeVOL
extends GNVolBase
## Reads back a volume to CPU and outputs statistics as CHOP channels.
##
## Output channels: min, max, mean, sum, nonzero_count, total_voxels.
## Optionally outputs a histogram channel.

func _init() -> void:
	super._init()
	node_type = "analyze"
	node_description = "Compute volume density statistics → CHOP output."


func _init_ports() -> void:
	add_input("vol", GNFamily.Type.VOL, true, "Volume to analyze")
	add_output("stats", GNFamily.Type.CHOP, "Statistics as channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("histogram", false, "Histogram",
		"Output a histogram channel (64 bins)"))
	add_parameter(GNParameter.create_int("hist_bins", 64,
		8, 256, "Histogram Bins", "Number of histogram bins"))


func _cook(inputs: Array[GNData]) -> GNData:
	var vol: GNVolumeData = _get_input_vol(inputs, 0)
	if vol == null or not vol.has_volume():
		return null

	# CPU readback
	var raw: PackedByteArray = vol.read_full()
	if raw.is_empty():
		return null

	var bpv: int = vol.bytes_per_voxel()
	var total: int = vol.voxel_count()
	var values := PackedFloat32Array()
	values.resize(total)
	for i in range(total):
		values[i] = raw.decode_float(i * bpv)

	# Compute statistics
	var v_min: float = INF
	var v_max: float = -INF
	var v_sum: float = 0.0
	var nonzero: int = 0

	for i in range(total):
		var v: float = values[i]
		if v < v_min: v_min = v
		if v > v_max: v_max = v
		v_sum += v
		if absf(v) > 1e-7:
			nonzero += 1

	var v_mean: float = v_sum / float(maxi(total, 1))

	# Build CHOP output
	var out := GNChannelData.new()
	out.sample_rate = 60.0
	out.set_single_value("min", v_min)
	out.set_single_value("max", v_max)
	out.set_single_value("mean", v_mean)
	out.set_single_value("sum", v_sum)
	out.set_single_value("nonzero_count", float(nonzero))
	out.set_single_value("total_voxels", float(total))

	# Optional histogram
	if get_param_value("histogram"):
		var bins: int = get_param_value("hist_bins")
		var range_val: float = v_max - v_min
		if range_val < 1e-10:
			range_val = 1.0
		var hist := PackedFloat32Array()
		hist.resize(bins)
		for i in range(total):
			var idx: int = clampi(int((values[i] - v_min) / range_val * float(bins)), 0, bins - 1)
			hist[idx] += 1.0
		out.set_channel("histogram", hist)
		out.length = bins

	return out
