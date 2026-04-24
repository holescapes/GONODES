class_name HostInTOP
extends GNTopBase
## Receives a texture from the host application via the LibGodot C API.
##
## The host calls gonodes_set_input_texture() to push a GPU texture handle.
## GNEmbeddedHost flushes that data into this node via _set_host_texture().
## Zero-copy when the host shares its GPU device with LibGodot.
##
## Usage: Place in a patch, set the node ID, and wire output to downstream TOPs.
## The host references this node by its ID string.

## Host-provided texture handle (VkImage / GLuint / MTLTexture* cast to int).
var _host_handle: int = 0
var _host_width: int = 0
var _host_height: int = 0
var _host_format: int = 0
var _host_dirty: bool = false

## GPU zero-copy state: external texture wrapped as a Godot RID + Texture2DRD.
var _ext_rd_rid: RID = RID()
var _ext_texture_2d: Texture2DRD = null
var _prev_handle: int = 0


func _init() -> void:
	node_type = "host_in"
	family = GNFamily.Type.NET


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Texture received from host")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "Label", "Label",
		"Optional label for this input in the host's UI"))


## Called by GNEmbeddedHost._flush_inputs() with the host's texture data.
func _set_host_texture(handle: int, width: int, height: int, format: int) -> void:
	_host_handle = handle
	_host_width = width
	_host_height = height
	_host_format = format
	_host_dirty = true
	mark_dirty()


func _cook(_inputs: Array[GNData]) -> GNData:
	if _host_handle == 0:
		_free_ext_texture()
		return null

	var res := Vector2i(_host_width, _host_height)

	# GPU zero-copy path: wrap the host's native texture handle directly
	# via RenderingDevice.texture_create_from_extension().
	# Works for both shared-context (handle on same device) and non-shared
	# (GNEmbeddedHost already uploaded to a local texture on this device).
	var ctx := GNGpuContext.get_context()
	if ctx != null and ctx.rd != null:
		# Recreate the view when the native handle changes.
		if _host_handle != _prev_handle or not _ext_rd_rid.is_valid():
			_free_ext_texture()
			var fmt: int = _host_format if _host_format != 0 \
				else RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
			_ext_rd_rid = ctx.create_texture_2d_from_native(
				_host_handle, _host_width, _host_height, fmt)
			_prev_handle = _host_handle

		if _ext_rd_rid.is_valid():
			if _ext_texture_2d == null:
				_ext_texture_2d = Texture2DRD.new()
			_ext_texture_2d.texture_rd_rid = _ext_rd_rid

			if _cached_tex_data == null:
				_cached_tex_data = GNTextureData.new()
			_cached_tex_data.texture = _ext_texture_2d
			_cached_tex_data.resolution = res
			_cached_tex_data.valid = true
			_host_dirty = false
			return _cached_tex_data

	# CPU fallback (Compatibility renderer — no RenderingDevice).
	_ensure_viewport(res, true)
	if _viewport.size != res:
		_viewport.size = res
	_cached_tex_data.resolution = res
	_cached_tex_data.valid = true
	_host_dirty = false
	return _cached_tex_data


## Frees the RD view wrapping the external texture.
## Does NOT free the underlying native handle — the host owns it.
func _free_ext_texture() -> void:
	if _ext_rd_rid.is_valid():
		var ctx := GNGpuContext.get_context()
		if ctx != null and ctx.rd != null:
			ctx.rd.free_rid(_ext_rd_rid)
		_ext_rd_rid = RID()
	_ext_texture_2d = null
	_prev_handle = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_free_ext_texture()
