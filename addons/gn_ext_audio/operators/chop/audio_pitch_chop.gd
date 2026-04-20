class_name AudioPitchCHOP
extends GNChopBase
## Pitch shift without tempo change via granular resynthesis.
##
## Uses overlapping grains with Hann windowing to shift pitch up or down
## without changing the playback speed. Simple granular approach — effective
## for small pitch shifts (±12 semitones). Larger shifts may introduce
## artifacts.
##
## For high-quality pitch shifting, consider using a dedicated DSP library
## via GDExtension.

var _buf_l := PackedFloat32Array()
var _buf_r := PackedFloat32Array()
var _buf_write: int = 0
var _grain_phase: float = 0.0
var _buf_size: int = 0

const MAX_BUF_SECONDS := 1.0


func _init() -> void:
	node_type = "audiopitch"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input")
	add_output("out", GNFamily.Type.CHOP, "Pitch-shifted audio output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("semitones", 0.0, -24.0, 24.0, 0.1,
		"Semitones", "Pitch shift in semitones"))
	add_parameter(GNParameter.create_float("grain_size", 0.05, 0.01, 0.2, 0.001,
		"Grain Size", "Grain window size in seconds"))
	add_parameter(GNParameter.create_float("wet", 1.0, 0.0, 1.0, 0.01,
		"Wet", "Wet (shifted) signal level"))
	add_parameter(GNParameter.create_float("dry", 0.0, 0.0, 1.0, 0.01,
		"Dry", "Dry (original) signal level"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var sr: float = in_data.sample_rate if in_data.sample_rate > 0.0 else AudioServer.get_mix_rate()
	var out := _prepare_output(sr)

	var semitones: float = get_param_value("semitones")
	var grain_sec: float = get_param_value("grain_size")
	var wet: float = get_param_value("wet")
	var dry: float = get_param_value("dry")

	# Pitch ratio: 2^(semitones/12)
	var ratio: float = pow(2.0, semitones / 12.0)
	var grain_samples: int = maxi(int(grain_sec * sr), 64)

	# Ensure circular buffer
	var target_buf: int = int(sr * MAX_BUF_SECONDS)
	if _buf_size != target_buf:
		_buf_size = target_buf
		_buf_l.resize(_buf_size)
		_buf_l.fill(0.0)
		_buf_r.resize(_buf_size)
		_buf_r.fill(0.0)
		_buf_write = 0
		_grain_phase = 0.0

	var names: PackedStringArray = in_data.get_channel_names()
	var in_l: PackedFloat32Array = in_data.get_channel(names[0]) if names.size() > 0 else PackedFloat32Array()
	var in_r: PackedFloat32Array = in_data.get_channel(names[1]) if names.size() > 1 else in_l

	if in_l.size() == 0:
		return null

	var num_samples: int = in_l.size()

	# Write input to circular buffer
	for s: int in range(num_samples):
		_buf_l[_buf_write] = in_l[s]
		_buf_r[_buf_write] = in_r[s] if s < in_r.size() else in_l[s]
		_buf_write = (_buf_write + 1) % _buf_size

	# Read with pitch-shifted grains (two overlapping grains)
	var out_l := PackedFloat32Array()
	out_l.resize(num_samples)
	var out_r := PackedFloat32Array()
	out_r.resize(num_samples)

	var read_offset: float = float(grain_samples)
	var grain_size_f: float = float(grain_samples)

	for s: int in range(num_samples):
		# Two overlapping grains, 50% overlap
		var g1_phase: float = fmod(_grain_phase, 1.0)
		var g2_phase: float = fmod(_grain_phase + 0.5, 1.0)

		# Hann windows
		var w1: float = 0.5 * (1.0 - cos(TAU * g1_phase))
		var w2: float = 0.5 * (1.0 - cos(TAU * g2_phase))

		# Read positions in circular buffer
		var base_read: int = (_buf_write - num_samples + s - grain_samples + _buf_size) % _buf_size
		var offset1: float = g1_phase * grain_size_f
		var offset2: float = g2_phase * grain_size_f

		var idx1: int = (base_read + int(offset1)) % _buf_size
		var idx2: int = (base_read + int(offset2)) % _buf_size

		var g1_l: float = _buf_l[idx1] * w1
		var g1_r: float = _buf_r[idx1] * w1
		var g2_l: float = _buf_l[idx2] * w2
		var g2_r: float = _buf_r[idx2] * w2

		var shifted_l: float = g1_l + g2_l
		var shifted_r: float = g1_r + g2_r

		out_l[s] = in_l[s] * dry + shifted_l * wet
		out_r[s] = (in_r[s] if s < in_r.size() else in_l[s]) * dry + shifted_r * wet

		# Advance grain phase at pitch-shifted rate
		_grain_phase += (ratio - 1.0) / grain_size_f + 1.0 / grain_size_f
		if _grain_phase > 100.0:
			_grain_phase = fmod(_grain_phase, 1.0)

	out.set_channel("left", out_l)
	out.set_channel("right", out_r)
	return out
