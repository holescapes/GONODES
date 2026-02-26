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


# ═══════════════════════════════════════════════════════════════════════════════
# Input Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Safely extracts a GNImageData from the inputs array at [param port].
## Returns null if the port doesn't exist or the data is not GNImageData.
func _get_input_img(inputs: Array[GNData], port: int = 0) -> GNImageData:
	if port < inputs.size() and inputs[port] is GNImageData:
		return inputs[port] as GNImageData
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Preview
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a Label preview showing image resolution and format.
## No GPU upload — IMG data stays CPU-side.  Use ImgToTOP to view the image.
func create_preview_control() -> Control:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.text = ""
	return label


## Updates the image stats preview from cached_output.
func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		if cached_output is GNImageData:
			var img_data: GNImageData = cached_output as GNImageData
			if img_data.image != null:
				var res: Vector2i = img_data.resolution
				var fmt_name: String = _format_name(img_data.format)
				label.text = "%d×%d\n%s" % [res.x, res.y, fmt_name]
			else:
				label.text = "no image"
		else:
			label.text = "no image"


## Returns a short human-readable name for an Image.Format enum value.
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
		_: return "fmt:%d" % fmt
