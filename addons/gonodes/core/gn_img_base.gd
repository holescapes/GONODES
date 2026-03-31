class_name GNImgBase
extends GNNode
## Base class for all IMG (Image Operator) family operators.
##
## IMG operators process CPU-side Image data — no SubViewport, no GPU.
## For GPU texture work, use TOPs.  Convert IMG → TOP via ImgToTOP.
##
## Provides:
##   • family = GNFamily.Type.IMG set automatically
##   • Default output port "out" of type IMG
##   • Cached GNImageData with _prepare_image() helper
##   • Input validation via _get_input_img()
##   • Lightweight text preview showing resolution/format (no GPU upload)

# ─── Shared IMG Infrastructure ─────────────────────────────────────────────────

## Reusable output data object (created once, image replaced each cook).
var _cached_image_data: GNImageData = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.IMG


## Ensures family is set even when subclass _init() doesn't call super().
func initialize(p_id: String) -> void:
	family = GNFamily.Type.IMG
	super.initialize(p_id)


## Default output port.  Override in subclass to add inputs or extra outputs.
func _init_ports() -> void:
	add_output("out", GNFamily.Type.IMG, "Image output")


# ═══════════════════════════════════════════════════════════════════════════════
# Output Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Creates or returns the cached image data.  Call at the top of _cook().
## Unlike CHOP/DAT, we don't clear the old image here — the operator
## writes a new Image into it via set_image().
func _prepare_image() -> GNImageData:
	if _cached_image_data == null:
		_cached_image_data = GNImageData.new()
	return _cached_image_data


func display_in_viewer(viewer) -> void:
	if cached_output is GNImageData:
		var img_data: GNImageData = cached_output as GNImageData
		if img_data.image != null and not img_data.image.is_empty():
			viewer.show_image(img_data.image,
				"%dx%d" % [img_data.resolution.x, img_data.resolution.y])
			return
	viewer.show_info("No IMG output", "")


# ═══════════════════════════════════════════════════════════════════════════════
# Input Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Safely extracts a GNImageData from the inputs array at [param port].
## Returns null if the port doesn't exist or the data is not GNImageData.
func _get_input_img(inputs: Array[GNData], port: int = 0) -> GNImageData:
	if port < inputs.size() and inputs[port] is GNImageData:
		return inputs[port] as GNImageData
	return null


func update_preview_control(control: Control) -> void:
	if control is Label:
		(control as Label).text = cached_output.get_preview_text() if cached_output != null else ""



