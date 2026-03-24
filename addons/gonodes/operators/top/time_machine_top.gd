class_name TimeMachineTOP
extends GNTopBase
## Time-scrubbing over a frame buffer — delay, reverse, speed ramp, ping-pong.
## Reads from CacheTOP or maintains its own internal ring-buffer.

var _buffer: Array[ImageTexture] = []
var _write_index: int = 0
var _total_written: int = 0
var _playback_pos: float = 0.0


func _init() -> void:
	node_type = "time_machine"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture to record")
	add_output("out", GNFamily.Type.TOP, "Time-shifted texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("length", 60, 1, 600, "Buffer Length", "Number of frames to store"))
	add_parameter(GNParameter.create_float("speed", 1.0, -4.0, 4.0, 0.01, "Speed", "Playback speed (negative = reverse)"))
	add_parameter(GNParameter.create_float("position", 0.0, 0.0, 1.0, 0.001, "Position", "Manual scrub position (0..1) — overrides speed when > 0"))
	add_parameter(GNParameter.create_enum("wrap_mode",
		PackedStringArray(["Clamp", "Loop", "Ping-Pong"]), 1, "Wrap Mode", "Behaviour at buffer boundaries"))
	add_parameter(GNParameter.create_bool("freeze", false, "Freeze", "Stop recording new frames"))
	add_parameter(GNParameter.create_bool("reset", false, "Reset", "Clear the buffer"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("TimeMachineTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_ensure_viewport(res)
	if _viewport.size != res:
		_viewport.size = res

	var buf_len: int = clampi(get_param_value("length"), 1, 600)
	var speed_val: float = get_param_value("speed")
	var pos_val: float = get_param_value("position")
	var wrap: int = get_param_value("wrap_mode")
	var freeze: bool = get_param_value("freeze")
	var do_reset: bool = get_param_value("reset")

	if do_reset:
		_buffer.clear()
		_write_index = 0
		_total_written = 0
		_playback_pos = 0.0

	if _buffer.size() != buf_len:
		_buffer.resize(buf_len)
		_write_index = _write_index % buf_len if buf_len > 0 else 0

	# Record
	if not freeze:
		var img: Image = tex_in.texture.get_image()
		if img != null:
			if _buffer[_write_index] == null:
				_buffer[_write_index] = ImageTexture.create_from_image(img)
			else:
				_buffer[_write_index].update(img)
			_write_index = (_write_index + 1) % buf_len
			_total_written += 1

	# Determine read position
	var available: int = mini(_total_written, buf_len)
	if available == 0:
		_cached_tex_data.texture = tex_in.texture
		_cached_tex_data.resolution = res
		return _cached_tex_data

	if pos_val > 0.001:
		# Manual position scrub
		_playback_pos = pos_val * float(available - 1)
	else:
		# Speed-driven playback
		_playback_pos += speed_val

	# Wrap
	var max_pos: float = float(available - 1)
	if wrap == 0:
		_playback_pos = clampf(_playback_pos, 0.0, max_pos)
	elif wrap == 1:
		_playback_pos = fmod(fmod(_playback_pos, max_pos + 1.0) + max_pos + 1.0, max_pos + 1.0)
	else:
		# Ping-pong
		var cycle: float = max_pos * 2.0
		if cycle > 0.0:
			var t: float = fmod(fmod(_playback_pos, cycle) + cycle, cycle)
			_playback_pos = max_pos - absf(t - max_pos)

	var read_frame: int = clampi(int(round(_playback_pos)), 0, available - 1)
	var read_idx: int = (_write_index - available + read_frame + buf_len * 2) % buf_len

	if read_idx < _buffer.size() and _buffer[read_idx] != null:
		_cached_tex_data.texture = _buffer[read_idx]
	else:
		_cached_tex_data.texture = tex_in.texture

	_cached_tex_data.resolution = res
	return _cached_tex_data
