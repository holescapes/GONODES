class_name NDIAudioInCHOP
extends GNChopBase
## Receives NDI audio from the network and outputs it as CHOP channel data.
##
## Each audio channel from the NDI source becomes a separate CHOP channel
## named "ch0", "ch1", etc.  The sample rate matches the source.
##
## Requires the gn_ext_ndi GDExtension (GNNDIReceiver class).

var _receiver: RefCounted = null
var _last_source: String = ""


func _init() -> void:
	node_type = "ndiaudioin"
	time_dependent = true
	node_description = "Receive NDI audio from the network. Requires gn_ext_ndi."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])

func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Audio channel data")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("source", "", "Source",
		"NDI source name (e.g. 'OBS (DESKTOP-ABC)')"))
	add_parameter(GNParameter.create_enum("bandwidth",
		PackedStringArray(["Highest", "Audio Only", "Lowest"]), 1, "Bandwidth",
		"NDI receive quality (default: Audio Only)"))
	add_parameter(GNParameter.create_int("timeout_ms", 16, 0, 1000, "Timeout",
		"Audio capture timeout in milliseconds"))
	add_parameter(GNParameter.create_bool("active", true, "",
		"Enable / disable receiving"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if not _is_ndi_available():
		GNLogger.warn("NDIAudioInCHOP", "'%s': gn_ext_ndi GDExtension not loaded" % id)
		return null

	if not get_param_value("active"):
		return _cached_channel_data

	_ensure_receiver()
	if _receiver == null:
		return null

	var source_name: String = get_param_value("source")
	if source_name != _last_source:
		if source_name.is_empty():
			_receiver.release()
		else:
			_receiver.create_receiver(source_name, get_param_value("bandwidth"))
		_last_source = source_name

	if not _receiver.is_receiver_connected():
		return null

	var timeout: int = get_param_value("timeout_ms")
	var samples: PackedFloat32Array = _receiver.receive_audio(timeout)
	if samples.is_empty():
		return _cached_channel_data

	var num_ch: int = _receiver.get_audio_channels()
	var sr: int = _receiver.get_audio_sample_rate()
	var num_samp: int = _receiver.get_audio_num_samples()

	if num_ch <= 0 or num_samp <= 0:
		return _cached_channel_data

	var out: GNChannelData = _prepare_output(float(sr))

	# De-interleave: samples are [ch0_s0, ch1_s0, ch0_s1, ch1_s1, ...]
	for c in range(num_ch):
		var chan_name := "ch%d" % c
		var chan_data := PackedFloat32Array()
		chan_data.resize(num_samp)
		for s in range(num_samp):
			chan_data[s] = samples[s * num_ch + c]
		out.channels[chan_name] = chan_data

	out.length = num_samp
	return out


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _is_ndi_available() -> bool:
	return ClassDB.class_exists(&"GNNDIReceiver")

func _ensure_receiver() -> void:
	if _receiver != null:
		return
	_receiver = ClassDB.instantiate(&"GNNDIReceiver")
	if _receiver == null:
		GNLogger.error("NDIAudioInCHOP", "'%s': failed to instantiate GNNDIReceiver" % id)
