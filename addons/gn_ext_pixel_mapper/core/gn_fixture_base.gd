class_name GNFixtureBase
extends GNNode
## Base class for all FIX (fixture) operators.
## FIX operators produce GNFixtureData describing LED positions in local space.

## Runtime family ID -- resolved once from the extension registry.
static var FIX_FAMILY: int = -1

var _cached_fix_data: GNFixtureData = null

## Viewer overlay for LED dot visualisation.
var _fix_viewer_overlay: FixtureViewerOverlay = null


func _init() -> void:
	if FIX_FAMILY < 0:
		FIX_FAMILY = GNFamily.string_to_type("FIX")
	family = FIX_FAMILY


func initialize(p_id: String) -> void:
	if FIX_FAMILY < 0:
		FIX_FAMILY = GNFamily.string_to_type("FIX")
	family = FIX_FAMILY
	super.initialize(p_id)


func _is_family_data(data: GNData) -> bool:
	return data is GNFixtureData


## Safe input extraction -- returns null if port is empty or wrong type.
func _get_input_fix(inputs: Array[GNData], port: int = 0) -> GNFixtureData:
	if port < inputs.size() and inputs[port] is GNFixtureData:
		return inputs[port] as GNFixtureData
	return null


## Returns a reusable GNFixtureData, cleared for this cook.
func _prepare_output() -> GNFixtureData:
	if _cached_fix_data == null:
		_cached_fix_data = GNFixtureData.new()
	_cached_fix_data.valid = true
	_cached_fix_data.led_positions = PackedVector2Array()
	_cached_fix_data.led_count = 0
	return _cached_fix_data


func render_for_viewer(viewer, port_index: int = 0) -> void:
	var data: GNData = get_output_data(port_index)
	if data == null or not (data is GNFixtureData):
		viewer.set_info("No fixture output", "")
		return
	var fd: GNFixtureData = data as GNFixtureData
	if fd.led_count == 0:
		viewer.set_info("Empty fixture", "")
		return

	# Create a small image showing the LED layout
	var img_size := 256
	var img := Image.create(img_size, img_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.08, 0.12, 1.0))

	# Compute bounding box for auto-fit
	var bb_min := Vector2(INF, INF)
	var bb_max := Vector2(-INF, -INF)
	for i in range(fd.led_count):
		bb_min = bb_min.min(fd.led_positions[i])
		bb_max = bb_max.max(fd.led_positions[i])
	var bb_size: Vector2 = bb_max - bb_min
	if bb_size.x < 0.001:
		bb_size.x = 1.0
	if bb_size.y < 0.001:
		bb_size.y = 1.0
	# Add 10% margin
	var margin: float = maxf(bb_size.x, bb_size.y) * 0.1
	bb_min -= Vector2(margin, margin)
	bb_size += Vector2(margin * 2, margin * 2)
	var scale_f: float = float(img_size) / maxf(bb_size.x, bb_size.y)

	# Draw LEDs as bright dots
	var dot_radius: int = clampi(int(3.0 * 256.0 / float(img_size)), 1, 6)
	for i in range(fd.led_count):
		var pos: Vector2 = fd.led_positions[i]
		var px: int = clampi(int((pos.x - bb_min.x) * scale_f), 0, img_size - 1)
		var py: int = clampi(int((pos.y - bb_min.y) * scale_f), 0, img_size - 1)
		# Colour based on index for visual distinction
		var t: float = float(i) / maxf(float(fd.led_count - 1), 1.0)
		var col := Color.from_hsv(t * 0.7, 0.8, 1.0)
		for dy in range(-dot_radius, dot_radius + 1):
			for dx in range(-dot_radius, dot_radius + 1):
				if dx * dx + dy * dy <= dot_radius * dot_radius:
					var ix: int = clampi(px + dx, 0, img_size - 1)
					var iy: int = clampi(py + dy, 0, img_size - 1)
					img.set_pixel(ix, iy, col)

	var tex := ImageTexture.create_from_image(img)
	var total_ch: int = fd.led_count * fd.channels_per_led
	var info: String = "%s | %d LEDs | %s | Uni %d Ch %d-%d" % [
		fd.fixture_name, fd.led_count, fd.channel_layout.to_upper(),
		fd.universe, fd.start_channel, fd.start_channel + total_ch - 1]
	viewer.set_texture(tex, info)

	# Show hover overlay with per-LED DMX info
	if _fix_viewer_overlay == null:
		_fix_viewer_overlay = FixtureViewerOverlay.new()
	_fix_viewer_overlay.fixture_data = fd
	_fix_viewer_overlay.bb_min = bb_min
	_fix_viewer_overlay.bb_scale = scale_f
	_fix_viewer_overlay.img_size = img_size
	viewer.set_texture_overlay(_fix_viewer_overlay)


func handle_viewer_input(event: InputEvent, local_pos: Vector2, viewer = null, _port_index: int = 0) -> bool:
	if _fix_viewer_overlay == null or viewer == null:
		return false
	if event is InputEventMouseMotion:
		var uv: Vector2 = viewer.local_pos_to_uv(local_pos)
		_fix_viewer_overlay.mouse_uv = uv
		_fix_viewer_overlay.queue_redraw()
		return false  # Don't consume -- allow pan/zoom
	return false
