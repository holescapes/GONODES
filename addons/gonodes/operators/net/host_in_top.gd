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


func _init() -> void:
	node_type = "host_in"
	family = GNFamily.Type.NET


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Texture received from host")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "", "Label",
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
		return null

	var res := Vector2i(_host_width, _host_height)
	_ensure_viewport(res, true)

	if _viewport.size != res:
		_viewport.size = res

	# In a shared GPU context, the host handle IS the texture on the same
	# device.  We wrap it in a GNTextureData for downstream consumption.
	#
	# For non-shared contexts, GNEmbeddedHost would have done CPU readback
	# and uploaded to a local texture — _host_handle then points to the
	# local copy.
	#
	# TODO: Implement RenderingDevice.create_texture_from_external()
	# when Godot 4.6 stabilizes the external texture import API.

	_cached_tex_data.resolution = res
	_cached_tex_data.valid = true
	_host_dirty = false
	return _cached_tex_data
