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


func get_family() -> GNFamily.Type:
	return GNFamily.Type.IMG


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
	copy.resolution = resolution
	copy.format = format
	# Deep-copy the image so downstream nodes can't mutate our data
	if image != null:
		copy.image = image.duplicate()
	return copy


## Sets the image and updates cached resolution/format from it.
func set_image(img: Image) -> void:
	image = img
	if img != null:
		resolution = Vector2i(img.get_width(), img.get_height())
		format = img.get_format()
	else:
		resolution = Vector2i(256, 256)
		format = Image.FORMAT_RGBA8
