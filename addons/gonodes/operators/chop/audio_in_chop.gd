class_name AudioInCHOP
extends GNChopBase
## Captures live microphone audio and outputs waveform samples as CHOP channels.
##
## Creates/manages an AudioServer bus with AudioEffectCapture + AudioStreamPlayer
## using AudioStreamMicrophone. Pulls PCM frames each cook.
##
## Output channels:
##   left  — left channel waveform (or mono)
##   right — right channel waveform (stereo only)
##   level — RMS amplitude of the most recent buffer (0-1)
##
## Buffer size is configurable. At 60 FPS, ~735 samples per frame at 44100 Hz.

# ─── Audio infrastructure ──────────────────────────────────────────────────────

var _bus_name: String = ""
var _bus_idx: int = -1
var _capture_effect: AudioEffectCapture = null
var _stream_player: AudioStreamPlayer = null
var _active: bool = false

## Pre-allocated sample buffers to avoid per-frame allocation.
var _left_buf: PackedFloat32Array = PackedFloat32Array()
var _right_buf: PackedFloat32Array = PackedFloat32Array()


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "audio_in"
	time_dependent = true
	thread_safe = false  # AudioServer I/O


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Audio waveform channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", false, "Active",
		"Enable/disable microphone capture"))
	add_parameter(GNParameter.create_int("buffer_size", 1024, 64, 8192, "Buffer",
		"Number of samples to output per cook"))
	add_parameter(GNParameter.create_bool("stereo", false, "Stereo",
		"Output stereo (left+right) or mono (left only)"))
	add_parameter(GNParameter.create_float("gain", 1.0, 0.0, 10.0, 0.01, "Gain",
		"Input gain multiplier"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var want_active: bool = get_param_value("active")
	var buf_size: int = get_param_value("buffer_size")
	var stereo: bool = get_param_value("stereo")
	var gain: float = get_param_value("gain")

	if want_active and not _active:
		_start_capture()
	elif not want_active and _active:
		_stop_capture()

	var sample_rate: float = float(AudioServer.get_mix_rate())
	var out: GNChannelData = _prepare_output(sample_rate)

	if not _active or _capture_effect == null:
		# Output silence
		_left_buf.resize(buf_size)
		_left_buf.fill(0.0)
		out.set_channel("left", _left_buf.duplicate())
		out.set_single_value("level", 0.0)
		return out

	# Pull available frames from the capture effect
	var available: int = _capture_effect.get_frames_available()
	var pull_count: int = mini(available, buf_size)

	if pull_count <= 0:
		# No new frames — output zeros
		_left_buf.resize(buf_size)
		_left_buf.fill(0.0)
		out.set_channel("left", _left_buf.duplicate())
		out.set_single_value("level", 0.0)
		return out

	# get_buffer returns PackedVector2Array (left, right per frame)
	var frames: PackedVector2Array = _capture_effect.get_buffer(pull_count)

	_left_buf.resize(frames.size())
	if stereo:
		_right_buf.resize(frames.size())

	var rms_sum: float = 0.0
	for i in range(frames.size()):
		var l: float = frames[i].x * gain
		_left_buf[i] = l
		rms_sum += l * l
		if stereo:
			_right_buf[i] = frames[i].y * gain

	out.set_channel("left", _left_buf.duplicate())
	if stereo:
		out.set_channel("right", _right_buf.duplicate())

	var rms: float = sqrt(rms_sum / maxf(float(frames.size()), 1.0))
	out.set_single_value("level", clampf(rms, 0.0, 1.0))

	return out


# ═══════════════════════════════════════════════════════════════════════════════
# Audio Bus / Capture Management
# ═══════════════════════════════════════════════════════════════════════════════

func _start_capture() -> void:
	if _active:
		return

	# Create a dedicated audio bus for this node
	_bus_name = "GN_AudioIn_%s" % id
	_bus_idx = AudioServer.bus_count
	AudioServer.add_bus(_bus_idx)
	AudioServer.set_bus_name(_bus_idx, _bus_name)
	AudioServer.set_bus_mute(_bus_idx, true)  # Don't play mic back through speakers

	# Add capture effect
	_capture_effect = AudioEffectCapture.new()
	_capture_effect.buffer_length = 0.5  # 500ms ring buffer
	AudioServer.add_bus_effect(_bus_idx, _capture_effect)

	# Create AudioStreamPlayer with microphone stream
	_stream_player = AudioStreamPlayer.new()
	_stream_player.stream = AudioStreamMicrophone.new()
	_stream_player.bus = _bus_name
	add_child(_stream_player)
	_stream_player.play()

	_active = true
	GNLogger.info("AudioInCHOP", "Microphone capture started on bus '%s'" % _bus_name)


func _stop_capture() -> void:
	if not _active:
		return

	if _stream_player != null:
		_stream_player.stop()
		_stream_player.queue_free()
		_stream_player = null

	# Remove the bus (find by name in case index shifted)
	for i in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(i) == _bus_name:
			AudioServer.remove_bus(i)
			break

	_capture_effect = null
	_bus_idx = -1
	_active = false
	GNLogger.info("AudioInCHOP", "Microphone capture stopped")


## Clean up on node removal.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_stop_capture()
