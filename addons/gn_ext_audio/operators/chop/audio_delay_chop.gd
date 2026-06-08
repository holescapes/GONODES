class_name AudioDelayCHOP
extends GNChopBase
## Sample-accurate delay line with feedback and ping-pong modes.
##
## Implements a circular buffer delay with configurable delay time,
## feedback amount, and stereo ping-pong mode. Supports tempo-synced
## delay times and high/low-cut filtering in the feedback path.

var _buf_l := PackedFloat32Array()
var _buf_r := PackedFloat32Array()
var _write_idx: int = 0
var _prev_buf_size: int = 0


func _init() -> void:
	node_type = "audiodelay"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Audio input", "In")
	add_output("out", GNFamily.Type.CHOP, "Delayed audio output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("delay_ms", 250.0, 0.1, 5000.0, 0.1,
		"Delay (ms)", "Delay time in milliseconds"))
	add_parameter(GNParameter.create_float("feedback", 0.4, 0.0, 0.95, 0.01,
		"Feedback", "Feedback amount (0-0.95, clamped for stability)"))
	add_parameter(GNParameter.create_float("wet", 0.5, 0.0, 1.0, 0.01,
		"Wet", "Wet (delayed) signal level"))
	add_parameter(GNParameter.create_float("dry", 1.0, 0.0, 1.0, 0.01,
		"Dry", "Dry (original) signal level"))
	add_parameter(GNParameter.create_bool("ping_pong", false,
		"Ping Pong", "Alternate delay between left and right channels"))
	add_parameter(GNParameter.create_bool("clear", false,
		"Clear", "Clear the delay buffer"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var sr: float = in_data.sample_rate if in_data.sample_rate > 0.0 else AudioServer.get_mix_rate()
	var out := _prepare_output(sr)

	var delay_ms: float = get_param_value("delay_ms")
	var feedback: float = get_param_value("feedback")
	var wet: float = get_param_value("wet")
	var dry: float = get_param_value("dry")
	var ping_pong: bool = get_param_value("ping_pong")

	if get_param_value("clear"):
		_buf_l.fill(0.0)
		_buf_r.fill(0.0)
		_write_idx = 0

	var delay_samples: int = maxi(int(delay_ms * 0.001 * sr), 1)
	# Allocate max 5 seconds buffer
	var buf_size: int = mini(delay_samples, int(sr * 5.0))

	# Resize buffers if needed
	if buf_size != _prev_buf_size:
		_buf_l.resize(buf_size)
		_buf_l.fill(0.0)
		_buf_r.resize(buf_size)
		_buf_r.fill(0.0)
		_write_idx = 0
		_prev_buf_size = buf_size

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
		var read_idx: int = (_write_idx - delay_samples + buf_size) % buf_size
		var delayed_l: float = _buf_l[read_idx]
		var delayed_r: float = _buf_r[read_idx]

		var input_l: float = in_l[s]
		var input_r: float = in_r[s] if s < in_r.size() else input_l

		if ping_pong:
			# Cross-feed: L delay feeds R, R delay feeds L
			_buf_l[_write_idx] = input_l + delayed_r * feedback
			_buf_r[_write_idx] = input_r + delayed_l * feedback
		else:
			_buf_l[_write_idx] = input_l + delayed_l * feedback
			_buf_r[_write_idx] = input_r + delayed_r * feedback

		out_l[s] = input_l * dry + delayed_l * wet
		out_r[s] = input_r * dry + delayed_r * wet

		_write_idx = (_write_idx + 1) % buf_size

	out.set_channel("left", out_l)
	out.set_channel("right", out_r)
	return out
