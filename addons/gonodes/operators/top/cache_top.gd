class_name CacheTOP
extends GNTopBase
## Buffers N frames of input in a GPU-side ring-buffer using blit SubViewports.
## Outputs the frame at the requested delay offset — enables delay, freeze,
## and time-scrubbing.  No CPU readback — textures stay on the GPU.

## Ring of blit viewports: each entry is { "viewport": SubViewport, "canvas": TextureRect }
var _ring: Array[Dictionary] = []
var _write_index: int = 0
var _total_written: int = 0
var _last_capture_stamp: int = -1
var _last_res: Vector2i = Vector2i.ZERO
## The single viewport that needs UPDATE_ONCE this frame (null if nothing to write).
var _pending_write_vp: SubViewport = null


func _init() -> void:
	node_type = "cache"


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
	var buf_len: int = clampi(get_param_value("length"), 1, 300)
	var delay_val: int = clampi(get_param_value("delay"), 0, buf_len - 1)
	var freeze: bool = get_param_value("freeze")
	var do_reset: bool = get_param_value("reset")

	if do_reset:
		_destroy_ring()

	_ensure_ring(buf_len, res)

	# Capture current frame into the write slot (unless frozen or input unchanged)
	_pending_write_vp = null
	if not freeze and tex_in.timestamp != _last_capture_stamp:
		var slot: Dictionary = _ring[_write_index]
		(slot.canvas as TextureRect).texture = tex_in.texture
		_pending_write_vp = slot.viewport as SubViewport
		_write_index = (_write_index + 1) % buf_len
		_total_written += 1
		_last_capture_stamp = tex_in.timestamp

	# Read from ring at delay offset
	var available: int = mini(_total_written, buf_len)
	if available == 0:
		if _cached_tex_data == null:
			_cached_tex_data = GNTextureData.new()
		_cached_tex_data.texture = tex_in.texture
		_cached_tex_data.resolution = res
		return _cached_tex_data

	var read_idx: int = (_write_index - 1 - delay_val + buf_len * 2) % buf_len
	var read_slot: Dictionary = _ring[read_idx]

	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = (read_slot.viewport as SubViewport).get_texture()
	_cached_tex_data.resolution = res
	return _cached_tex_data


## Ensures the blit ring has the right size and resolution.
func _ensure_ring(count: int, res: Vector2i) -> void:
	var needs_rebuild := _ring.size() != count or res != _last_res

	if not needs_rebuild:
		return

	_destroy_ring()
	_last_res = res

	for i in range(count):
		var slot := GNTopBase._create_blit_viewport(self, "Cache_%d" % i, res, true)
		_ring.append(slot)

	_write_index = 0
	_total_written = 0
	_last_capture_stamp = -1


## Frees all blit viewports.
func _destroy_ring() -> void:
	for slot in _ring:
		if slot.has("viewport") and is_instance_valid(slot.viewport):
			(slot.viewport as SubViewport).queue_free()
	_ring.clear()
	_write_index = 0
	_total_written = 0
	_last_capture_stamp = -1
	_last_res = Vector2i.ZERO
	_pending_write_vp = null


## Override: only render the write-slot viewport this frame, not all N ring
## slots.  GNTopBase.execute_cook would trigger UPDATE_ONCE on every child
## SubViewport — that would re-blit stale references and destroy cached frames.
func execute_cook(inputs: Array[GNData], frame: int) -> GNData:
	var result := super.execute_cook(inputs, frame)
	# super already set ALL children to UPDATE_ONCE — revert ring slots we
	# don't want to render, keeping only the pending write slot active.
	if result != null:
		for slot in _ring:
			var vp: SubViewport = slot.viewport as SubViewport
			if vp != _pending_write_vp:
				vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return result
