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
	copy.resolution = resolution
	copy.format = format
	# texture and viewport are NOT deep-copied — they are transient render resources
	copy.texture = texture
	copy.viewport = viewport
	return copy
