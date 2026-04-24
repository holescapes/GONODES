class_name NDIAudioOutCHOP
extends GNChopBase
## Sends CHOP channel data as NDI audio to the network.
##
## Each CHOP channel is mapped to an NDI audio channel in order.
## All channels must have the same length (samples per channel).
##
## Requires the gn_ext_ndi GDExtension (GNNDISender class).

var _sender: RefCounted = null
var _last_name: String = ""


func _init() -> void:
	node_type = "ndiaudioout"
	time_dependent = true
	node_description = "Send CHOP data as NDI audio to the network. Requires gn_ext_ndi."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])

func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, true, "Audio channel data to send", "Audio")
	add_output("thru", GNFamily.Type.CHOP, "Pass-through of input")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("name", "GoNodes Audio", "Name",
		"NDI sender name visible on the network"))
	add_parameter(GNParameter.create_int("sample_rate", 48000, 8000, 192000,
		"Sample Rate", "Audio sample rate in Hz"))
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable sending"))


func _cook(inputs: Array[GNData]) -> GNData:
	if not _is_ndi_available():
		GNLogger.warn("NDIAudioOutCHOP", "'%s': gn_ext_ndi GDExtension not loaded" % id)
		return null

	var in_chop: GNChannelData = _get_input_chop(inputs, 0)
	if in_chop == null or in_chop.channels.is_empty():
		return null

	if not get_param_value("active"):
		return in_chop

	_ensure_sender()
	if _sender == null:
		return in_chop

	var sender_name: String = get_param_value("name")
	if sender_name != _last_name:
		_sender.create_sender(sender_name)
		_last_name = sender_name

	if not _sender.is_active():
		return in_chop

	# Interleave channels: [ch0_s0, ch1_s0, ch0_s1, ch1_s1, ...]
	var channel_names: Array = in_chop.channels.keys()
	var num_ch: int = channel_names.size()
	var num_samp: int = 0
	for ch_name in channel_names:
		var arr: PackedFloat32Array = in_chop.channels[ch_name]
		if arr.size() > num_samp:
			num_samp = arr.size()

	if num_samp <= 0:
		return in_chop

	var interleaved := PackedFloat32Array()
	interleaved.resize(num_ch * num_samp)

	for c in range(num_ch):
		var arr: PackedFloat32Array = in_chop.channels[channel_names[c]]
		for s in range(num_samp):
			var val: float = arr[s] if s < arr.size() else 0.0
			interleaved[s * num_ch + c] = val

	var sr: int = get_param_value("sample_rate")
	_sender.send_audio(interleaved, num_ch, sr, num_samp)

	return in_chop


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _is_ndi_available() -> bool:
	return ClassDB.class_exists(&"GNNDISender")

func _ensure_sender() -> void:
	if _sender != null:
		return
	_sender = ClassDB.instantiate(&"GNNDISender")
	if _sender == null:
		GNLogger.error("NDIAudioOutCHOP", "'%s': failed to instantiate GNNDISender" % id)
