class_name GNTextureData
extends GNData
## Output data type for TOP operators.
## Wraps a Texture2D produced by rendering through a SubViewport.
## RefCounted (inherits from GNData) — transient render result.

## The rendered texture result (read from SubViewport after cook).
var texture: Texture2D = null

## The SubViewport used to render this TOP's output.  Owned by the TOP node.
var viewport: SubViewport = null

## Output resolution in pixels.
var resolution: Vector2i = Vector2i(512, 512)

## Image format of the texture.
var format: Image.Format = Image.FORMAT_RGBA8


func get_family() -> int:
	return GNFamily.Type.TOP


func get_preview_text() -> String:
	if texture != null:
		return "%dx%d" % [resolution.x, resolution.y]
	return ""


func get_data_summary() -> String:
	if texture != null:
		return "%d×%d" % [resolution.x, resolution.y]
	return ""


## Returns the aspect ratio (width / height).  Returns 1.0 if height is zero.
func get_aspect() -> float:
	if resolution.y == 0:
		return 1.0
	return float(resolution.x) / float(resolution.y)


func invalidate() -> void:
	super.invalidate()
	texture = null


func duplicate_data() -> GNData:
	var copy := GNTextureData.new()
	copy.valid = valid
	copy.timestamp = timestamp
	copy.metadata = metadata.duplicate(true)
	copy.resolution = resolution
	copy.format = format
	# texture and viewport are NOT deep-copied — they are transient render resources
	copy.texture = texture
	copy.viewport = viewport
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


## Returns CPU pixels from [member texture].
## [ViewportTexture] uses blocking [method Texture2D.get_image]; [Texture2DRD]
## uses async readback via [method GNGpuContext.get_texture_readback_image].
func get_readback_image() -> Image:
	if texture == null:
		return null
	return GNGpuContext.get_context().get_texture_readback_image(
		texture, resolution, format)


func export_to_file(path: String) -> Error:
	if texture == null:
		return ERR_INVALID_DATA
	var img: Image = get_readback_image()
	if img == null:
		return ERR_INVALID_DATA
	var ext := path.get_extension().to_lower()
	match ext:
		"png": return img.save_png(path)
		"webp": return img.save_webp(path)
		"exr": return img.save_exr(path)
		_: return img.save_png(path)
