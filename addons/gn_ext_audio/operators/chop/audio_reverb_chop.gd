class_name AudioReverbCHOP
extends GNChopBase
## Algorithmic reverb using Schroeder architecture.
##
## Implements a classic Schroeder reverb with 4 parallel comb filters
## feeding into 2 series allpass filters. Produces natural-sounding
## reverb tails without convolution (real-time friendly).
##
## Parameters control room size, damping, wet/dry mix, and pre-delay.

# Comb filter delay lines (4 parallel)
var _comb_bufs_l: Array[PackedFloat32Array] = []
var _comb_bufs_r: Array[PackedFloat32Array] = []
var _comb_idx: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])

# Allpass filter delay lines (2 series)
var _ap_bufs_l: Array[PackedFloat32Array] = []
var _ap_bufs_r: Array[PackedFloat32Array] = []
var _ap_idx: PackedInt32Array = PackedInt32Array([0, 0])

# Comb filter feedback state
var _comb_filt_l := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _comb_filt_r := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

var _prev_sr: float = 0.0

# Schroeder delay lengths in samples at 44100 Hz (prime-ish numbers)
const COMB_LENGTHS := [1557, 1617, 1491, 1422]
const AP_LENGTHS := [225, 556]


func _init() -> void:
	node_type = "audioreverb"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input")
	add_output("out", GNFamily.Type.CHOP, "Reverb output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("room_size", 0.7, 0.0, 1.0, 0.01,
		"Room Size", "Reverb decay time (larger = longer tail)"))
	add_parameter(GNParameter.create_float("damping", 0.5, 0.0, 1.0, 0.01,
		"Damping", "High-frequency damping (higher = darker reverb)"))
	add_parameter(GNParameter.create_float("wet", 0.3, 0.0, 1.0, 0.01,
		"Wet", "Wet (reverb) level"))
	add_parameter(GNParameter.create_float("dry", 1.0, 0.0, 1.0, 0.01,
		"Dry", "Dry (original) level"))
	add_parameter(GNParameter.create_float("width", 1.0, 0.0, 1.0, 0.01,
		"Width", "Stereo width of reverb"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var sr: float = in_data.sample_rate if in_data.sample_rate > 0.0 else AudioServer.get_mix_rate()

	# Rebuild delay lines if sample rate changed
	if not is_equal_approx(sr, _prev_sr):
		_init_buffers(sr)
		_prev_sr = sr

	var out := _prepare_output(sr)

	var room_size: float = get_param_value("room_size")
	var damping: float = get_param_value("damping")
	var wet: float = get_param_value("wet")
	var dry: float = get_param_value("dry")
	var width: float = get_param_value("width")

	# Scale room size to feedback coefficient
	var feedback: float = room_size * 0.28 + 0.7

	var names: PackedStringArray = in_data.get_channel_names()
	var in_l: PackedFloat32Array = in_data.get_channel(names[0]) if names.size() > 0 else PackedFloat32Array()
	var in_r: PackedFloat32Array = in_data.get_channel(names[1]) if names.size() > 1 else in_l

	if in_l.size() == 0:
		return null

	var num_samples: int = in_l.size()
	var out_l := PackedFloat32Array()
	out_l.resize(num_samples)
	var out_r := PackedFloat32Array()
	out_r.resize(num_samples)

	for s: int in range(num_samples):
		var input_l: float = in_l[s]
		var input_r: float = in_r[s] if s < in_r.size() else input_l

		var rev_l: float = 0.0
		var rev_r: float = 0.0

		# 4 parallel comb filters
		for c: int in range(4):
			# Left
			var buf_l: PackedFloat32Array = _comb_bufs_l[c]
			var idx_l: int = _comb_idx[c]
			var delayed_l: float = buf_l[idx_l]
			_comb_filt_l[c] = delayed_l * (1.0 - damping) + _comb_filt_l[c] * damping
			buf_l[idx_l] = input_l + _comb_filt_l[c] * feedback
			rev_l += delayed_l

			# Right (slightly offset)
			var buf_r: PackedFloat32Array = _comb_bufs_r[c]
			var delayed_r: float = buf_r[idx_l]
			_comb_filt_r[c] = delayed_r * (1.0 - damping) + _comb_filt_r[c] * damping
			buf_r[idx_l] = input_r + _comb_filt_r[c] * feedback
			rev_r += delayed_r

			_comb_idx[c] = (idx_l + 1) % buf_l.size()

		# 2 series allpass filters
		for a: int in range(2):
			var buf_al: PackedFloat32Array = _ap_bufs_l[a]
			var buf_ar: PackedFloat32Array = _ap_bufs_r[a]
			var idx: int = _ap_idx[a]

			var buf_out_l: float = buf_al[idx]
			buf_al[idx] = rev_l + buf_out_l * 0.5
			rev_l = buf_out_l - rev_l

			var buf_out_r: float = buf_ar[idx]
			buf_ar[idx] = rev_r + buf_out_r * 0.5
			rev_r = buf_out_r - rev_r

			_ap_idx[a] = (idx + 1) % buf_al.size()

		# Stereo width
		var wet_l: float = rev_l * (0.5 + width * 0.5) + rev_r * (0.5 - width * 0.5)
		var wet_r: float = rev_r * (0.5 + width * 0.5) + rev_l * (0.5 - width * 0.5)

		out_l[s] = input_l * dry + wet_l * wet
		out_r[s] = input_r * dry + wet_r * wet

	out.set_channel("left", out_l)
	out.set_channel("right", out_r)
	return out


func _init_buffers(sr: float) -> void:
	var sr_scale: float = sr / 44100.0
	_comb_bufs_l.clear()
	_comb_bufs_r.clear()
	for c: int in range(4):
		var len: int = int(COMB_LENGTHS[c] * sr_scale)
		var buf_l := PackedFloat32Array()
		buf_l.resize(len)
		buf_l.fill(0.0)
		_comb_bufs_l.append(buf_l)
		var buf_r := PackedFloat32Array()
		buf_r.resize(len)
		buf_r.fill(0.0)
		_comb_bufs_r.append(buf_r)
	_comb_idx = PackedInt32Array([0, 0, 0, 0])
	_comb_filt_l = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	_comb_filt_r = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])

	_ap_bufs_l.clear()
	_ap_bufs_r.clear()
	for a: int in range(2):
		var len: int = int(AP_LENGTHS[a] * sr_scale)
		var buf_l := PackedFloat32Array()
		buf_l.resize(len)
		buf_l.fill(0.0)
		_ap_bufs_l.append(buf_l)
		var buf_r := PackedFloat32Array()
		buf_r.resize(len)
		buf_r.fill(0.0)
		_ap_bufs_r.append(buf_r)
	_ap_idx = PackedInt32Array([0, 0])
