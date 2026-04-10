class_name GNOpenCVHelper
## Shared utilities for all OpenCV operators.
##
## Provides availability checks, image conversion between Godot Image
## and the GNOpenCV native layer, and common parameter helpers.
## All methods are static — no instantiation needed.


## Returns true if the GNOpenCV native class is loaded.
static func is_available() -> bool:
	return ClassDB.class_exists(&"GNOpenCV")


## Instantiates the native GNOpenCV class via ClassDB to avoid compile-time
## dependency.  Returns null if the GDExtension is not loaded.
static func create_instance() -> RefCounted:
	if not is_available():
		return null
	return ClassDB.instantiate(&"GNOpenCV")


## Converts a Godot Image to RGBA8 PackedByteArray suitable for native calls.
## Returns [rgba_bytes, width, height].  Returns empty array on failure.
static func image_to_rgba(img: Image) -> Array:
	if img == null:
		return [PackedByteArray(), 0, 0]
	var copy := img.duplicate() as Image
	if copy.get_format() != Image.FORMAT_RGBA8:
		copy.convert(Image.FORMAT_RGBA8)
	return [copy.get_data(), copy.get_width(), copy.get_height()]


## Creates a Godot Image from RGBA8 byte data returned by native calls.
static func rgba_to_image(rgba: PackedByteArray, w: int, h: int) -> Image:
	if rgba.is_empty() or w <= 0 or h <= 0:
		return null
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba)


## Creates an ImageTexture from RGBA8 byte data.
static func rgba_to_texture(rgba: PackedByteArray, w: int, h: int) -> ImageTexture:
	var img := rgba_to_image(rgba, w, h)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)
