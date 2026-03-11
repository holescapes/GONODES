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

## Interactive panel sources that originated from PanelTOP nodes upstream.
## Empty for normal TOPs. PanelTOP populates one entry at identity transform.
## Spatial TOPs apply their inverse transform; non-spatial TOPs pass through.
## WindowOUT reads this to forward mouse input to the correct panel viewport.
var panel_sources: Array = []  # Array[GNPanelSource]


func get_family() -> GNFamily.Type:
	return GNFamily.Type.TOP


## Returns the aspect ratio (width / height).  Returns 1.0 if height is zero.
func get_aspect() -> float:
	if resolution.y == 0:
		return 1.0
	return float(resolution.x) / float(resolution.y)


func invalidate() -> void:
	super.invalidate()
	texture = null
	panel_sources.clear()


## Copies panel_sources from an input GNTextureData (passthrough for non-spatial TOPs).
func carry_panel_sources_from(input: GNTextureData) -> void:
	panel_sources.clear()
	if input != null:
		for ps in input.panel_sources:
			panel_sources.append(ps.duplicate_source())


## Merges panel_sources from multiple inputs (used by CompositeTOP, LayoutTOP, etc.).
## Each source gets a per-input inverse transform applied before merging.
func merge_panel_sources(inputs: Array, transforms: Array) -> void:
	panel_sources.clear()
	for i in range(inputs.size()):
		var tex: GNTextureData = inputs[i]
		if tex == null:
			continue
		var inv: Transform2D = transforms[i] if i < transforms.size() else Transform2D.IDENTITY
		for ps in tex.panel_sources:
			var copy: GNPanelSource = ps.duplicate_source()
			copy.transform = copy.transform * inv
			panel_sources.append(copy)


func duplicate_data() -> GNData:
	var copy := GNTextureData.new()
	copy.valid = valid
	copy.timestamp = timestamp
	copy.resolution = resolution
	copy.format = format
	# texture and viewport are NOT deep-copied — they are transient render resources
	copy.texture = texture
	copy.viewport = viewport
	# Deep-copy panel sources (each gets its own transform but shares viewport ref)
	for ps in panel_sources:
		copy.panel_sources.append(ps.duplicate_source())
	return copy
