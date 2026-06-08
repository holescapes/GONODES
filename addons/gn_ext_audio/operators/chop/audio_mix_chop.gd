class_name AudioMixCHOP
extends GNChopBase
## Multi-input audio mixer with per-input gain, pan, mute, and solo.
##
## Accepts up to 8 stereo audio inputs and mixes them to a stereo output
## using equal-power panning law. Each input has independent gain (dB),
## pan (-1 to +1), and mute/solo controls. Master gain on output.
##
## Uses auto-grow dynamic inputs — connect more sources and new ports appear.


func _init() -> void:
	node_type = "audiomix"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, true, "Audio input source", "In")
	_enable_dynamic_inputs(GNFamily.Type.CHOP, "in", "Audio input source")
	add_output("out", GNFamily.Type.CHOP, "Mixed stereo output", "Out")


func _init_parameters() -> void:
	for i: int in range(8):
		var n: int = i + 1
		var prefix := "in%d_" % n
		add_parameter(GNParameter.create_float(prefix + "gain",
			0.0, -60.0, 12.0, 0.1,
			"Input %d Gain" % n, "Gain in dB for input %d" % n))
		add_parameter(GNParameter.create_float(prefix + "pan",
			0.0, -1.0, 1.0, 0.01,
			"Input %d Pan" % n, "Stereo pan for input %d (-1=L, 0=center, +1=R)" % n))
		add_parameter(GNParameter.create_bool(prefix + "mute", false,
			"Input %d Mute" % n, "Mute input %d" % n))
		add_parameter(GNParameter.create_bool(prefix + "solo", false,
			"Input %d Solo" % n, "Solo input %d" % n))
	add_parameter(GNParameter.create_float("master_gain",
		0.0, -60.0, 12.0, 0.1,
		"Master Gain", "Master output gain in dB"))


func _cook(inputs: Array[GNData]) -> GNData:
	# Determine sample rate and buffer size from first valid input
	var sr: float = AudioServer.get_mix_rate()
	var buf_size: int = 0
	var valid_inputs: Array[GNChannelData] = []

	for i: int in range(inputs.size()):
		var in_data: GNChannelData = inputs[i] as GNChannelData if i < inputs.size() and inputs[i] is GNChannelData else null
		valid_inputs.append(in_data)
		if in_data != null:
			if in_data.sample_rate > 0.0:
				sr = in_data.sample_rate
			if in_data.length > buf_size:
				buf_size = in_data.length

	if buf_size == 0:
		return null

	var out := _prepare_output(sr)
	var master_lin: float = _db_to_lin(get_param_value("master_gain"))

	# Check if any input has solo enabled
	var any_solo: bool = false
	for i: int in range(mini(valid_inputs.size(), 8)):
		if valid_inputs[i] != null and get_param_value("in%d_solo" % (i + 1)):
			any_solo = true
			break

	# Accumulate mix
	var mix_l := PackedFloat32Array()
	mix_l.resize(buf_size)
	mix_l.fill(0.0)
	var mix_r := PackedFloat32Array()
	mix_r.resize(buf_size)
	mix_r.fill(0.0)

	for i: int in range(mini(valid_inputs.size(), 8)):
		var in_data: GNChannelData = valid_inputs[i]
		if in_data == null:
			continue

		var n: int = i + 1
		var prefix := "in%d_" % n
		var muted: bool = get_param_value(prefix + "mute")
		var soloed: bool = get_param_value(prefix + "solo")

		# Mute/solo logic
		if muted:
			continue
		if any_solo and not soloed:
			continue

		var gain_lin: float = _db_to_lin(get_param_value(prefix + "gain"))
		var pan: float = get_param_value(prefix + "pan")

		# Equal-power panning
		var pan_angle: float = (pan + 1.0) * 0.25 * PI  # 0 to PI/2
		var gain_l: float = gain_lin * cos(pan_angle)
		var gain_r: float = gain_lin * sin(pan_angle)

		# Get L/R channels (or mono → both)
		var names: PackedStringArray = in_data.get_channel_names()
		var ch_l: PackedFloat32Array = PackedFloat32Array()
		var ch_r: PackedFloat32Array = PackedFloat32Array()

		if names.size() >= 2:
			ch_l = in_data.get_channel(names[0])
			ch_r = in_data.get_channel(names[1])
		elif names.size() == 1:
			ch_l = in_data.get_channel(names[0])
			ch_r = ch_l
		else:
			continue

		var len_l: int = ch_l.size()
		var len_r: int = ch_r.size()

		for s: int in range(buf_size):
			mix_l[s] += ch_l[mini(s, len_l - 1)] * gain_l if len_l > 0 else 0.0
			mix_r[s] += ch_r[mini(s, len_r - 1)] * gain_r if len_r > 0 else 0.0

	# Apply master gain
	for s: int in range(buf_size):
		mix_l[s] *= master_lin
		mix_r[s] *= master_lin

	out.set_channel("left", mix_l)
	out.set_channel("right", mix_r)
	return out


static func _db_to_lin(db: float) -> float:
	if db <= -60.0:
		return 0.0
	return pow(10.0, db / 20.0)
