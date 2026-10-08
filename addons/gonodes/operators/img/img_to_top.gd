class_name ImgToTOP
extends GNTopBase
## Converts a CPU-side GNImageData (IMG family) to a GPU GNTextureData (TOP family).
## This is the bridge from IMG → TOP pipeline.
##
## Uploads the input Image to an ImageTexture each cook.
## No SubViewport needed — direct ImageTexture creation.
##
## VRAM-compressed Images (ETC2/DXT/ASTC from KTX2, etc.) are uploaded as
## compressed texture blocks when the GPU supports the format (GLES/mobile).
## Desktop GPUs that lack ETC2 may decompress at upload — still correct, just
## denser in VRAM.

var _tex: ImageTexture = null
var _last_size: Vector2i = Vector2i.ZERO
var _last_format: int = -1


func _init() -> void:
	node_type = "img_to_top"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "CPU Image input", "In")
	add_output("out", GNFamily.Type.TOP, "GPU Texture output", "Out")


func _init_parameters() -> void:
	# No parameters — pure pass-through converter
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	if inputs.is_empty() or not (inputs[0] is GNImageData):
		return null

	var img_data: GNImageData = inputs[0] as GNImageData
	if img_data.image == null:
		return null

	var img: Image = img_data.image
	var sz := Vector2i(img.get_width(), img.get_height())
	var fmt: int = img.get_format() as int

	# Compressed formats: recreate texture (update() is for uncompressed only).
	# Uncompressed: update in place when size/format match.
	if img.is_compressed() or _tex == null or sz != _last_size or fmt != _last_format:
		_tex = ImageTexture.create_from_image(img)
		_last_size = sz
		_last_format = fmt
	else:
		_tex.update(img)

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
