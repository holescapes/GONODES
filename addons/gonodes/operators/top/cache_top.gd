class_name CacheTOP
extends GNTopBase
## Buffers N frames of input in a ring-buffer.  Outputs the frame at the
## requested delay offset — enables delay, freeze, and time-scrubbing.

var _buffer: Array[ImageTexture] = []
var _write_index: int = 0
var _total_written: int = 0


func _init() -> void:
	node_type = "cache"
	node_description = "Frame buffer — stores N frames for delay, freeze, and time-scrubbing."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture to cache")
	add_output("out", GNFamily.Type.TOP, "Delayed/buffered texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("length", 30, 1, 300, "Buffer Length", "Number of frames to store"))
	add_parameter(GNParameter.create_int("delay", 0, 0, 299, "Delay", "Frame offset into the buffer (0 = current)"))
	add_parameter(GNParameter.create_bool("freeze", false, "Freeze", "Stop writing new frames"))
	add_parameter(GNParameter.create_bool("reset", false, "Reset", "Clear the buffer"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("CacheTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_ensure_viewport(res)
	if _viewport.size != res:
		_viewport.size = res

	var buf_len: int = clampi(get_param_value("length"), 1, 300)
	var delay_val: int = clampi(get_param_value("delay"), 0, buf_len - 1)
	var freeze: bool = get_param_value("freeze")
	var do_reset: bool = get_param_value("reset")

	if do_reset:
		_buffer.clear()
		_write_index = 0
		_total_written = 0

	# Resize buffer if length changed
	if _buffer.size() != buf_len:
		_buffer.resize(buf_len)
		_write_index = _write_index % buf_len if buf_len > 0 else 0

	# Capture current frame into buffer (unless frozen)
	if not freeze:
		var img: Image = tex_in.texture.get_image()
		if img != null:
			if _buffer[_write_index] == null:
				_buffer[_write_index] = ImageTexture.create_from_image(img)
			else:
				_buffer[_write_index].update(img)
			_write_index = (_write_index + 1) % buf_len
			_total_written += 1

	# Read from buffer at delay offset
	var available: int = mini(_total_written, buf_len)
	if available == 0:
		_cached_tex_data.resolution = res
		return _cached_tex_data

	var read_idx: int = (_write_index - 1 - delay_val + buf_len * 2) % buf_len
	if read_idx < _buffer.size() and _buffer[read_idx] != null:
		_cached_tex_data.texture = _buffer[read_idx]
	else:
		_cached_tex_data.texture = tex_in.texture

	_cached_tex_data.resolution = res

	return _cached_tex_data
