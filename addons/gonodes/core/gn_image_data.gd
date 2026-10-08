class_name GNImageData
extends GNData
## Output data type for IMG operators.
## Wraps a CPU-side Image — no SubViewport, no GPU texture upload.
## Use ImgToTOP to convert to GNTextureData for the TOP pipeline.

## The CPU-side image result.
var image: Image = null

## Output resolution in pixels (cached from image for quick access).
var resolution: Vector2i = Vector2i(256, 256)

## Image format.
var format: Image.Format = Image.FORMAT_RGBA8


func get_family() -> int:
	return GNFamily.Type.IMG


func get_preview_text() -> String:
	if image != null:
		return "%d×%d\n%s" % [resolution.x, resolution.y, _format_name(format)]
	return "no image"


func get_data_summary() -> String:
	return "%d×%d" % [resolution.x, resolution.y]


static func _format_name(fmt: Image.Format) -> String:
	match fmt:
		Image.FORMAT_RGBA8: return "RGBA8"
		Image.FORMAT_RGB8: return "RGB8"
		Image.FORMAT_L8: return "L8"
		Image.FORMAT_LA8: return "LA8"
		Image.FORMAT_RGBAF: return "RGBAF"
		Image.FORMAT_RGBAH: return "RGBAH"
		Image.FORMAT_RF: return "RF"
		Image.FORMAT_RGF: return "RGF"
		Image.FORMAT_DXT1: return "DXT1"
		Image.FORMAT_DXT5: return "DXT5"
		Image.FORMAT_ETC2_RGB8: return "ETC2_RGB8"
		Image.FORMAT_ETC2_RGBA8: return "ETC2_RGBA8"
		Image.FORMAT_ETC2_RGB8A1: return "ETC2_RGB8A1"
		_: return "fmt:%d" % fmt


## Returns the aspect ratio (width / height).  Returns 1.0 if height is zero.
func get_aspect() -> float:
	if resolution.y == 0:
		return 1.0
	return float(resolution.x) / float(resolution.y)


func invalidate() -> void:
	super.invalidate()
	image = null


func duplicate_data() -> GNData:
	var copy := GNImageData.new()
	copy.valid = valid
	copy.timestamp = timestamp
	copy.metadata = metadata.duplicate(true)
	copy.resolution = resolution
	copy.format = format
	# Deep-copy the image so downstream nodes can't mutate our data
	if image != null:
		copy.image = image.duplicate()
	return copy


func get_expression_value(key: String, _index: int = -1) -> Variant:
	match key:
		"resolution": return resolution
		"aspect": return get_aspect()
		"width": return resolution.x
		"height": return resolution.y
		_: return 0.0


func get_expression_info() -> Dictionary:
	return {
		"resolution": resolution,
		"aspect": get_aspect(),
	}


func get_export_filters() -> Array[Dictionary]:
	return [
		{"filter": "*.png", "description": "PNG Image"},
		{"filter": "*.webp", "description": "WebP Image"},
		{"filter": "*.exr", "description": "EXR Image (HDR)"},
	]


func export_to_file(path: String) -> Error:
	if image == null:
		return ERR_INVALID_DATA
	var ext := path.get_extension().to_lower()
	match ext:
		"png": return image.save_png(path)
		"webp": return image.save_webp(path)
		"exr": return image.save_exr(path)
		_: return image.save_png(path)


## Sets the image and updates cached resolution/format from it.
func set_image(img: Image) -> void:
	image = img
	if img != null:
		resolution = Vector2i(img.get_width(), img.get_height())
		format = img.get_format()
	else:
		resolution = Vector2i(256, 256)
		format = Image.FORMAT_RGBA8
