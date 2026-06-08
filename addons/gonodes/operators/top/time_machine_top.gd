class_name TimeMachineTOP
extends GNTopBase
## Time-scrubbing over a GPU-side frame buffer — delay, reverse, speed ramp,
## ping-pong, and curve-based time warp.  Uses blit SubViewports as a
## ring-buffer so textures never leave the GPU.
##
## Mode 0 (Speed): Linear playback at a fixed speed multiplier.
## Mode 1 (Position): Manual normalised scrub (0..1) over the buffer.
## Mode 2 (Ramp): A time-ramp curve maps normalised playback progress to
##   buffer position — non-linear retiming (ease-in/out, freeze, speed ramps).

const MODE_SPEED    := 0
const MODE_POSITION := 1
const MODE_RAMP     := 2

var _ring: Array[Dictionary] = []
var _write_index: int = 0
var _total_written: int = 0
var _playback_pos: float = 0.0
var _last_capture_stamp: int = -1
var _last_res: Vector2i = Vector2i.ZERO
var _pending_write_vp: SubViewport = null


func _init() -> void:
	node_type = "time_machine"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture to record", "In")
	add_output("out", GNFamily.Type.TOP, "Time-shifted texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("length", 60, 1, 600, "Buffer Length", "Number of frames to store"))
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Speed", "Position", "Ramp"]), MODE_SPEED,
		"Mode", "Speed = fixed rate, Position = manual scrub, Ramp = curve-based time warp"))
	# Speed mode params
	var p_speed := GNParameter.create_float("speed", 1.0, -4.0, 4.0, 0.01, "Speed", "Playback speed (negative = reverse)")
	p_speed.visibility_rule = {"param": "mode", "values": [MODE_SPEED]}
	add_parameter(p_speed)
	# Position mode params
	var p_pos := GNParameter.create_float("position", 0.0, 0.0, 1.0, 0.001, "Position", "Manual scrub position (0..1)")
	p_pos.visibility_rule = {"param": "mode", "values": [MODE_POSITION]}
	add_parameter(p_pos)
	# Ramp mode params
	var p_ramp := GNParameter.create_ramp("time_ramp", [],
		"Time Ramp", "Curve mapping normalised playback progress (X) to buffer position (Y)")
	p_ramp.visibility_rule = {"param": "mode", "values": [MODE_RAMP]}
	add_parameter(p_ramp)
	# Shared params
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
	var buf_len: int = clampi(get_param_value("length"), 1, 600)
	var mode: int = get_param_value("mode")
	var wrap: int = get_param_value("wrap_mode")
	var freeze: bool = get_param_value("freeze")
	var do_reset: bool = get_param_value("reset")

	if do_reset:
		_destroy_ring()

	_ensure_ring(buf_len, res)

	# Record current frame into the write slot
	_pending_write_vp = null
	if not freeze and tex_in.timestamp != _last_capture_stamp:
		var slot: Dictionary = _ring[_write_index]
		(slot.canvas as TextureRect).texture = tex_in.texture
		_pending_write_vp = slot.viewport as SubViewport
		_write_index = (_write_index + 1) % buf_len
		_total_written += 1
		_last_capture_stamp = tex_in.timestamp

	# Determine read position
	var available: int = mini(_total_written, buf_len)
	if available == 0:
		if _cached_tex_data == null:
			_cached_tex_data = GNTextureData.new()
		_cached_tex_data.texture = tex_in.texture
		_cached_tex_data.resolution = res
		return _cached_tex_data

	match mode:
		MODE_SPEED:
			_playback_pos += get_param_value("speed")
		MODE_POSITION:
			_playback_pos = get_param_value("position") * float(available - 1)
		MODE_RAMP:
			# Normalised playback progress (0..1) mapped through the ramp curve
			var progress: float = fmod(elapsed_time * 0.01, 1.0)
			var ramp_keys: Array = get_param_value("time_ramp")
			var mapped: float = GNParameter.sample_ramp(ramp_keys, progress)
			_playback_pos = mapped * float(available - 1)

	# Wrap
	var max_pos: float = float(available - 1)
	if wrap == 0:
		_playback_pos = clampf(_playback_pos, 0.0, max_pos)
	elif wrap == 1:
		_playback_pos = fmod(fmod(_playback_pos, max_pos + 1.0) + max_pos + 1.0, max_pos + 1.0)
	else:
		var cycle: float = max_pos * 2.0
		if cycle > 0.0:
			var t: float = fmod(fmod(_playback_pos, cycle) + cycle, cycle)
			_playback_pos = max_pos - absf(t - max_pos)

	var read_frame: int = clampi(int(round(_playback_pos)), 0, available - 1)
	var read_idx: int = (_write_index - available + read_frame + buf_len * 2) % buf_len

	var read_slot: Dictionary = _ring[read_idx]
	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = (read_slot.viewport as SubViewport).get_texture()
	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_ring(count: int, res: Vector2i) -> void:
	if _ring.size() == count and res == _last_res:
		return
	_destroy_ring()
	_last_res = res
	for i in range(count):
		_ring.append(GNTopBase._create_blit_viewport(self, "TM_%d" % i, res, true))
	_write_index = 0
	_total_written = 0
	_last_capture_stamp = -1
	_playback_pos = 0.0


func _destroy_ring() -> void:
	for slot in _ring:
		if slot.has("viewport") and is_instance_valid(slot.viewport):
			(slot.viewport as SubViewport).queue_free()
	_ring.clear()
	_write_index = 0
	_total_written = 0
	_last_capture_stamp = -1
	_playback_pos = 0.0
	_pending_write_vp = null


func execute_cook(inputs: Array[GNData], frame: int) -> GNData:
	var result := super.execute_cook(inputs, frame)
	if result != null:
		for slot in _ring:
			var vp: SubViewport = slot.viewport as SubViewport
			if vp != _pending_write_vp:
				vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return result
	_last_res = Vector2i.ZERO
