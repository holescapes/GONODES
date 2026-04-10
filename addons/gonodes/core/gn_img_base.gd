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


## Shared ImageTexture for uploading CPU Images to the viewer.
static var _viewer_texture: ImageTexture = null

## Shared waveform view for rendering CHOP data on non-IMG ports.
static var _viewer_chop_waveform: GNWaveformView = null

## Shared spreadsheet for rendering DAT data on non-IMG ports.
static var _viewer_dat_tree: Tree = null

func render_for_viewer(viewer, port_index: int = 0) -> void:
	var data: GNData = get_output_data(port_index)
	if data is GNImageData:
		var img_data: GNImageData = data as GNImageData
		if img_data.image != null and not img_data.image.is_empty():
			var img: Image = img_data.image
			if _viewer_texture == null \
					or _viewer_texture.get_width() != img.get_width() \
					or _viewer_texture.get_height() != img.get_height():
				_viewer_texture = ImageTexture.create_from_image(img)
			else:
				_viewer_texture.update(img)
			viewer.set_texture(_viewer_texture,
				"%dx%d" % [img_data.resolution.x, img_data.resolution.y])
			return
	# Cross-family: CHOP data on a non-IMG port.
	if data is GNChannelData:
		var ch: GNChannelData = data as GNChannelData
		if not ch.channels.is_empty():
			if _viewer_chop_waveform == null:
				_viewer_chop_waveform = GNViewerRenderHelpers.create_waveform_view()
			_viewer_chop_waveform.set_channel_data(ch)
			viewer.set_control(_viewer_chop_waveform,
				"%d ch × %d samples" % [ch.channels.size(), ch.length])
			return
	# Cross-family: DAT data on a non-IMG port.
	if data is GNTableData:
		var tbl: GNTableData = data as GNTableData
		if not tbl.table.is_empty():
			if _viewer_dat_tree == null:
				_viewer_dat_tree = Tree.new()
				_viewer_dat_tree.columns = 1
				_viewer_dat_tree.hide_root = true
				_viewer_dat_tree.scroll_horizontal_enabled = true
				_viewer_dat_tree.scroll_vertical_enabled = true
			GNDatBase._populate_viewer_tree(_viewer_dat_tree, tbl)
			viewer.set_control(_viewer_dat_tree)
			return
	viewer.set_info("No IMG output", "")


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



