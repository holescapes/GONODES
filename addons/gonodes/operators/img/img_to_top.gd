class_name ImgToTOP
extends GNTopBase
## Converts a CPU-side GNImageData (IMG family) to a GPU GNTextureData (TOP family).
## This is the bridge from IMG → TOP pipeline.
##
## Uploads the input Image to an ImageTexture each cook.
## No SubViewport needed — direct ImageTexture creation.

var _tex: ImageTexture = null


func _init() -> void:
	node_type = "img_to_top"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "CPU Image input")
	add_output("out", GNFamily.Type.TOP, "GPU Texture output")


func _init_parameters() -> void:
	# No parameters — pure pass-through converter
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	if inputs.is_empty() or not (inputs[0] is GNImageData):
		return null

	var img_data: GNImageData = inputs[0] as GNImageData
	if img_data.image == null:
		return null

	# Upload CPU Image to GPU ImageTexture
	if _tex == null:
		_tex = ImageTexture.create_from_image(img_data.image)
	else:
		_tex.update(img_data.image)

	# Ensure output infrastructure
	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()

	_cached_tex_data.texture = _tex
	_cached_tex_data.resolution = img_data.resolution
	_cached_tex_data.format = img_data.format
	return _cached_tex_data


## ImgToTOP doesn't use SubViewport — it's a direct ImageTexture upload.
## Override execute_cook to skip the UPDATE_ONCE viewport logic.
func execute_cook(inputs_data: Array[GNData], frame: int) -> GNData:
	var start_time := Time.get_ticks_usec()
	var result := _cook(inputs_data)
	var end_time := Time.get_ticks_usec()

	cook_time_ms = (end_time - start_time) / 1000.0

	if result != null:
		result.timestamp = frame
		result.valid = true
		cached_output = result
		cook_valid = true
	else:
		cached_output = null
		cook_valid = false

	clear_dirty()
	node_cooked.emit(id)
	return result
