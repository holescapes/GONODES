class_name GNPanelSource
extends RefCounted
## Metadata attached to GNTextureData that tracks an interactive PanelTOP's
## SubViewport through the TOP chain. Carries an accumulated inverse transform
## so WindowOUT can remap mouse coordinates and call push_input() on the
## original panel viewport.
##
## Normal TOPs produce GNTextureData with an empty panel_sources array.
## PanelTOP populates one PanelSource at identity. Spatial TOPs (Transform,
## Composite, Fit, Crop, Flip, etc.) apply their inverse to the transform.
## Non-spatial TOPs pass panel_sources through unchanged via GNTopBase default.

## The live interactive SubViewport owned by the PanelTOP.
## WindowOUT calls viewport.push_input(remapped_event) to forward interaction.
var viewport: SubViewport = null

## Accumulated inverse transform: maps from the current output texture space
## back to the panel's local coordinate space (pixels).
## Starts as IDENTITY at PanelTOP output. Each spatial TOP that repositions
## the texture concatenates its inverse onto this transform.
var transform: Transform2D = Transform2D.IDENTITY

## Original panel resolution in pixels — used for hit-testing bounds.
var resolution: Vector2i = Vector2i(512, 512)

## Unique identifier of the originating PanelTOP node (for debugging / disambiguation).
var source_id: String = ""


## Creates a deep copy with the same viewport reference but independent transform.
func duplicate_source() -> GNPanelSource:
	var copy := GNPanelSource.new()
	copy.viewport = viewport         # Same live viewport — NOT duplicated
	copy.transform = transform       # Transform2D is value-type, auto-copied
	copy.resolution = resolution
	copy.source_id = source_id
	return copy


## Tests whether a point in the current output texture space hits this panel.
## Returns the remapped point in panel-local space, or null if outside bounds.
func hit_test(point: Vector2) -> Variant:
	var local: Vector2 = transform * point
	if local.x >= 0.0 and local.x < resolution.x \
			and local.y >= 0.0 and local.y < resolution.y:
		return local
	return null
