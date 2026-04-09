class_name HapInTOP
extends GNTopBase
## GPU-direct HAP video playback — DXT frames upload directly to the GPU
## with zero CPU pixel-level decode overhead.
##
## Supports HAP (DXT1), HAP Alpha (DXT5), and HAP Q (YCoCg DXT5) variants.
## Ideal for VJ workflows requiring multiple simultaneous HD video streams.

var _decoder: RefCounted = null
var _texture: ImageTexture = null
var _playing: bool = false
var _last_file: String = ""


func _init() -> void:
	node_type = "hapintop"
	time_dependent = true
	node_description = "GPU-direct HAP video playback — DXT compressed frames upload directly to GPU."
	if ClassDB.class_exists("GNHapDecoder"):
		_decoder = ClassDB.instantiate("GNHapDecoder")


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Video texture output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file", "",
		PackedStringArray(["*.mov"]),
		"File", "HAP .mov video file path"))
	add_parameter(GNParameter.create_bool("play", true,
		"Play", "Enable playback"))
	add_parameter(GNParameter.create_bool("loop", true,
		"Loop", "Loop playback when reaching the end"))
	add_parameter(GNParameter.create_float("speed", 1.0, 0.0, 4.0, 0.1,
		"Speed", "Playback speed multiplier"))
	add_parameter(GNParameter.create_float("seek", -1.0, -1.0, 86400.0, 0.1,
		"Seek (sec)", "Seek to time in seconds (-1 = disabled)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _decoder == null:
		node_warning = "HAP codec requires the native gn_ext_hap library."
		return null

	var file_path: String = get_param_value("file")
	var play: bool = get_param_value("play")
	var do_loop: bool = get_param_value("loop")
	var speed: float = get_param_value("speed")
	var seek_time: float = get_param_value("seek")

	# Open file if changed
	if file_path != _last_file:
		_last_file = file_path
		if file_path.is_empty():
			_decoder.close()
			_texture = null
			return null
		# Resolve project:// and other path tiers to absolute
		var resolved := GNResourceLoader.resolve(file_path, project_dir)
		if resolved.is_empty():
			node_warning = "Cannot resolve path: " + file_path
			_texture = null
			return null
		if not _decoder.open(resolved):
			node_warning = "Failed to open HAP file: " + file_path
			_texture = null
			return null
		node_warning = ""
		# Allocate viewport to match video dimensions
		var w: int = _decoder.get_width()
		var h: int = _decoder.get_height()
		if w > 0 and h > 0:
			_ensure_viewport(Vector2i(w, h))

	if not _decoder.is_open():
		return null

	# Seek if requested
	if seek_time >= 0.0:
		_decoder.seek_time(seek_time)

	if not play:
		# Return last frame if paused
		if _texture != null:
			return _make_tex_data(_texture)
		return null

	# Advance by speed (skip frames for speed > 1)
	var frames_to_advance: int = maxi(1, roundi(speed))
	var dxt_data: PackedByteArray = PackedByteArray()
	for _i in range(frames_to_advance):
		dxt_data = _decoder.decode_next_frame()
		if dxt_data.is_empty():
			if do_loop:
				_decoder.seek_frame(0)
				dxt_data = _decoder.decode_next_frame()
			break

	if dxt_data.is_empty():
		if _texture != null:
			return _make_tex_data(_texture)
		return null

	# Create Image from raw DXT data and upload to GPU
	var w: int = _decoder.get_width()
	var h: int = _decoder.get_height()
	var img_format: int = _decoder.get_image_format()

	var img: Image = Image.create_from_data(w, h, false,
		img_format as Image.Format, dxt_data)

	if _texture == null:
		_texture = ImageTexture.create_from_image(img)
	else:
		_texture.update(img)

	return _make_tex_data(_texture)


## Helper to wrap a texture in GNTextureData for the TOP output.
func _make_tex_data(tex: Texture2D) -> GNData:
	var out := GNTextureData.new()
	out.texture = tex
	return out
