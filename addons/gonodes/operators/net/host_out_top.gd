class_name HostOutTOP
extends GNOutBase
## Exports a texture to the host application via the LibGodot C API.
##
## Takes a TOP input and makes its texture handle available to the host
## through gonodes_get_output_texture().  GNEmbeddedHost._collect_outputs()
## calls _get_host_texture() each frame to publish the handle.
##
## When the host shares its GPU device, the texture handle is directly
## usable (VkImage / GLuint / MTLTexture*) — zero-copy.

## Cached output info for the host.
var _output_handle: int = 0
var _output_width: int = 0
var _output_height: int = 0


func _init() -> void:
	node_type = "host_out"
	family = GNFamily.Type.NET
	is_sink = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Texture to export to host")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "Label", "Label",
		"Optional label for this output in the host's UI"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)

	if tex_in == null or tex_in.texture == null:
		_output_handle = 0
		_output_width = 0
		_output_height = 0
		return null

	# Extract the native texture handle from the Godot Texture2D.
	# RenderingServer.texture_get_native_handle() returns the
	# platform-specific handle (VkImage, GLuint, MTLTexture*).
	var tex_rid: RID = tex_in.texture.get_rid()
	if tex_rid.is_valid():
		_output_handle = RenderingServer.texture_get_native_handle(tex_rid)
	else:
		_output_handle = 0

	_output_width = tex_in.resolution.x
	_output_height = tex_in.resolution.y

	return null


## Called by GNEmbeddedHost._collect_outputs() to get the texture info.
func _get_host_texture() -> Dictionary:
	if _output_handle == 0:
		return {}
	return {
		"handle": _output_handle,
		"width": _output_width,
		"height": _output_height,
	}


func update_preview_control(control: Control) -> void:
	if control is Label:
		if _output_handle != 0:
			(control as Label).text = "→ host %dx%d" % [_output_width, _output_height]
		else:
			(control as Label).text = "no input"
