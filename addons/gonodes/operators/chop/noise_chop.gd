class_name NoiseCHOP
extends GNChopBase
## Generates smooth noise channels over time.
## Each channel produces a continuous noise signal seeded differently.
## Time-dependent when speed > 0 (auto-detected each frame).


func _init() -> void:
	node_type = "noise"


## Internal time accumulator for continuous noise evolution.
var _time_accum: float = 0.0


func update_time_dependency() -> void:
	time_dependent = get_param_value("speed") != 0.0


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Noise channel data")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_channels", 1, 1, 16, "Num Channels", "Number of noise channels"))
	add_parameter(GNParameter.create_string("channel_names", "chan1",
		"Channel Names", "Comma-separated channel names"))
	add_parameter(GNParameter.create_float("roughness", 0.5, 0.0, 1.0, 0.01, "Roughness", "Octave detail (0 = smooth, 1 = rough)"))
	add_parameter(GNParameter.create_float("period", 1.0, 0.01, 100.0, 0.01, "Period", "Time period of noise cycle"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 99999, "Seed", "Random seed"))
	add_parameter(GNParameter.create_float("speed", 1.0, 0.0, 10.0, 0.01, "Speed", "Time evolution speed (0 = frozen)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var num_ch: int = get_param_value("num_channels")
	var names_str: String = get_param_value("channel_names")
	var roughness: float = get_param_value("roughness")
	var period: float = get_param_value("period")
	var seed_val: int = get_param_value("seed")

	# Advance time accumulator using engine-injected delta
	var speed: float = get_param_value("speed")
	_time_accum += current_delta * speed

	# Parse channel names (comma-separated) or auto-generate
	var ch_names: PackedStringArray = _parse_channel_names(names_str, num_ch)

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = 60.0

	for i in range(num_ch):
		var ch_name: String = ch_names[i] if i < ch_names.size() else ("chan%d" % (i + 1))
		var value: float = _sample_noise(_time_accum, period, roughness, seed_val + i)
		_cached_channel_data.set_single_value(ch_name, value)

	return _cached_channel_data


## Parses comma-separated channel name string.  Pads with auto-names if needed.
func _parse_channel_names(names_str: String, count: int) -> PackedStringArray:
	var names := PackedStringArray()
	if not names_str.is_empty():
		for part in names_str.split(","):
			names.append(part.strip_edges())
	# Pad with auto-generated names
	while names.size() < count:
		names.append("chan%d" % (names.size() + 1))
	return names


## Samples 1D noise at a given time, with period and roughness (octave blending).
## Uses a simple hash-based smooth noise for portability.
func _sample_noise(t: float, period: float, roughness: float, seed_offset: int) -> float:
	var scaled_t: float = t / maxf(period, 0.001)
	var value: float = 0.0
	var amp: float = 1.0
	var freq: float = 1.0
	var total_amp: float = 0.0
	var octaves: int = 1 + int(roughness * 4.0)  # 1-5 octaves based on roughness

	for _oct in range(octaves):
		value += amp * _smooth_hash_1d(scaled_t * freq + float(seed_offset) * 17.31)
		total_amp += amp
		amp *= roughness
		freq *= 2.0

	if total_amp > 0.0:
		value /= total_amp

	return value


## 1D smooth noise from hash — cubic interpolation between random values.
func _smooth_hash_1d(x: float) -> float:
	var i: float = floorf(x)
	var f: float = x - i
	# Smoothstep
	var u: float = f * f * (3.0 - 2.0 * f)
	return lerpf(_hash_1d(i), _hash_1d(i + 1.0), u) * 2.0 - 1.0


## Simple 1D float hash (returns 0-1).
func _hash_1d(n: float) -> float:
	return fmod(sin(n * 127.1 + 311.7) * 43758.5453, 1.0)
