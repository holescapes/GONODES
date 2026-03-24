class_name TOPtoIMG
extends GNImgBase
## Converts a GPU GNTextureData (TOP) to a CPU-side GNImageData (IMG).
## This is the bridge from TOP → IMG pipeline (reverse of ImgToTOP).
##
## Uses `Texture2D.get_image()` to read the GPU texture back to CPU.
## The readback happens once per cook (only when dirty).


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
		return null

	var tex_data: GNTextureData = inputs[0] as GNTextureData
	if tex_data.texture == null:
		return null

	# GPU → CPU readback
	var image: Image = tex_data.texture.get_image()
	if image == null:
		GNLogger.warn("TOPtoIMG",
			"'%s': get_image() returned null (texture not ready)" % id)
		return null

	var out := _prepare_image()
	out.set_image(image)
	return out
