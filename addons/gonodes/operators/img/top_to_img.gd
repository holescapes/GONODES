class_name TOPtoIMG
extends GNImgBase
## Converts a GPU GNTextureData (TOP) to a CPU-side GNImageData (IMG).
## This is the bridge from TOP → IMG pipeline (reverse of ImgToTOP).
##
## Uses `Texture2D.get_image()` to read the GPU texture back to CPU.
## The readback happens once per cook (only when dirty).
##
## ViewportTexture timing: upstream TOPs set their SubViewport to UPDATE_ONCE
## during cook, but Godot defers the actual render to the end of the frame.
## On the first dirty cook we return the previous cache and schedule a second
## cook next frame so the readback gets the freshly-rendered pixels.

var _readback_pending: bool = false


func _init() -> void:
	node_type = "top_to_img"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "GPU Texture input")
	add_output("out", GNFamily.Type.IMG, "CPU Image output")


func _init_parameters() -> void:
	# No parameters — pure pass-through converter
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	if inputs.is_empty() or not (inputs[0] is GNTextureData):
		_readback_pending = false
		return null

	var tex_data: GNTextureData = inputs[0] as GNTextureData
	if tex_data.texture == null:
		_readback_pending = false
		return null

	# ViewportTextures lag one frame: the upstream TOP sets UPDATE_ONCE
	# during its cook, but the viewport doesn't render until end-of-frame.
	# Schedule a second cook next frame to read the fresh pixels.
	if tex_data.texture is ViewportTexture and not _readback_pending:
		_readback_pending = true
		mark_dirty()
		# Return previous cache if available (avoids visual flash to black)
		if _cached_image_data != null and _cached_image_data.image != null:
			return _cached_image_data
		return null
	_readback_pending = false

	# GPU → CPU readback
	var image: Image = tex_data.texture.get_image()
	if image == null:
		GNLogger.warn("TOPtoIMG",
			"'%s': get_image() returned null (texture not ready)" % id)
		return null

	var out := _prepare_image()
	out.set_image(image)
	return out
