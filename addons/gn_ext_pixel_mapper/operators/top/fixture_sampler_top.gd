class_name FixtureSamplerTOP
extends GNTopBase
## Samples a source image at every LED UV position across all connected fixtures.
##
## Port 0  : source TOP (the image to sample — any resolution)
## Ports 1+: FIX inputs (dynamic auto-grow — connect as many fixtures as needed)
##
## On cook, all connected GNFixtureData objects are merged into a single
## "LED position texture" (one pixel per LED: rg=uv, ba=extent).  One shader
## dispatch then samples the source image at all LED positions simultaneously.
##
## Output texture layout:
##   width  = max channels_per_led across all fixtures (1–4)
##   height = total_led_count
##   pixel (channel_col, led_row).r = that channel value for that LED
##
## The LED position texture is only rebuilt when FIX inputs change (dirty).
## The shader re-runs every frame that the source TOP is dirty.


## Packed LED-position image (CPU-side, rebuilt when fixtures change).
## Format: RGBAf — r=uv_x, g=uv_y, b=extent_x, a=extent_y
var _led_pos_image: Image = null
var _led_pos_texture: ImageTexture = null

## Cached fixture metadata in cook-order, for FixtureUnpackCHOP.
## Array of Dictionaries: {name, led_count, channels_per_led, dmx_start, offset}
## offset = index of this fixture's first LED in the global LED array.
var _fixture_manifest: Array = []

## Hash of the last FIX inputs to detect changes without rebuilding every frame.
var _last_fix_hash: int = -1

## Total LED count across all connected fixtures.
var _total_leds: int = 0

## Max channels_per_led across all fixtures (determines output texture width).
var _max_channels: int = 3


func _init() -> void:
	node_type = "fixture_sampler"
	node_description = "Samples a source image at all fixture LED positions in a single GPU pass."


func _init_ports() -> void:
	var fix_fam: int = GNFamily.string_to_type("FIX")
	add_input("source", GNFamily.Type.TOP, true, "Source image to sample")
	_enable_dynamic_inputs(fix_fam, "fix", "Fixture")
	add_output("out", GNFamily.Type.TOP, "Packed result texture - one pixel per LED channel")
	# Port 0 is "source" (fixed TOP). Dynamic FIX ports occupy indices 1..N.
	# update_dynamic_inputs and from_dict are overridden below to preserve port 0.


## Rebuilds input ports: source at index 0, then [param fix_count] FIX ports.
func _rebuild_input_ports(fix_count: int) -> void:
	var fix_fam: int = GNFamily.string_to_type("FIX")
	input_ports.clear()
	add_input("source", GNFamily.Type.TOP, true, "Source image to sample")
	for i in range(fix_count):
		add_input("fix%d" % i, fix_fam, false, "Fixture %d" % i)
	GNLogger.debug("GNNode", "'%s' input port count -> %d" % [id, input_ports.size()])
	ports_changed.emit(id)


## Overrides GNNode.update_dynamic_inputs to preserve the fixed "source" port at
## index 0.  The base implementation calls set_input_count() which clears ALL ports.
func update_dynamic_inputs(connected_ports: PackedInt32Array) -> void:
	if not _dynamic_input:
		return
	# FIX ports are at absolute indices 1..N. Only consider p >= 1.
	var max_fix: int = -1
	for p in connected_ports:
		if p >= 1 and p > max_fix:
			max_fix = p
	var desired_fix_count: int = maxi(max_fix + 1, 1)
	if 1 + desired_fix_count == input_ports.size():
		return
	_rebuild_input_ports(desired_fix_count)


## Overrides GNNode.from_dict to handle dynamic_input_count correctly.
## The base implementation passes the saved count directly to set_input_count(),
## which would overwrite port 0. We intercept, call super without that key,
## then rebuild with the correct FIX count.
func from_dict(d: Dictionary) -> void:
	var saved_total: int = -1
	if _dynamic_input and d.has("dynamic_input_count"):
		saved_total = int(d["dynamic_input_count"])
		d = d.duplicate()
		d.erase("dynamic_input_count")
	super.from_dict(d)
	if saved_total > 1:
		_rebuild_input_ports(saved_total - 1)  # saved_total includes source port


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("sample_mode",
		PackedStringArray(["Point", "Box Filter"]), 0,
		"Sample Mode", "Point = single texel. Box Filter = 3×3 tap average over the LED's sample_extent area."))


func _cook(inputs: Array[GNData]) -> GNData:
	# Port 0 = source TOP
	var src_data: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if src_data == null or src_data.texture == null:
		node_warning = "No source TOP connected."
		return null

	# Collect FIX inputs (ports 1+)
	var fix_inputs: Array[GNFixtureData] = []
	for i in range(1, inputs.size()):
		var fd: GNFixtureData = inputs[i] as GNFixtureData if inputs[i] is GNFixtureData else null
		if fd != null and fd.led_count > 0:
			fix_inputs.append(fd)

	if fix_inputs.is_empty():
		node_warning = "No FIX inputs connected."
		return null

	node_warning = ""

	# ── Rebuild LED-position texture if fixtures changed ──────────────────
	var fix_hash: int = _compute_fix_hash(fix_inputs)
	if fix_hash != _last_fix_hash:
		_rebuild_led_pos_texture(fix_inputs)
		_last_fix_hash = fix_hash

	# ── Ensure shader viewport exists ─────────────────────────────────────
	var out_size := Vector2i(_max_channels, _total_leds)
	_init_shader_viewport(
		"res://addons/gn_ext_pixel_mapper/shaders/fixture_sampler.gdshader",
		false, false, out_size)

	# Resize if total_leds or max_channels changed
	if _viewport.size != out_size:
		_viewport.size = out_size

	# ── Set shader uniforms ───────────────────────────────────────────────
	_material.set_shader_parameter("source_tex", src_data.texture)
	_material.set_shader_parameter("led_pos_tex", _led_pos_texture)
	_material.set_shader_parameter("total_leds", _total_leds)
	_material.set_shader_parameter("channels_per_led", _max_channels)
	_material.set_shader_parameter("sample_mode", get_param_value("sample_mode"))

	_cached_tex_data.resolution = out_size
	_cached_tex_data.metadata["fixture_manifest"] = _fixture_manifest
	return _cached_tex_data


## Builds the LED-position ImageTexture from all active fixtures.
## Also updates _fixture_manifest, _total_leds, _max_channels.
func _rebuild_led_pos_texture(fix_inputs: Array[GNFixtureData]) -> void:
	_total_leds = 0
	_max_channels = 1
	_fixture_manifest = []

	for fd in fix_inputs:
		_fixture_manifest.append({
			"name": fd.fixture_name,
			"led_count": fd.led_count,
			"channels_per_led": fd.channels_per_led,
			"channel_layout": fd.channel_layout,
			"dmx_start": fd.dmx_start,
			"offset": _total_leds,
		})
		_total_leds += fd.led_count
		_max_channels = maxi(_max_channels, fd.channels_per_led)

	if _total_leds == 0:
		return

	# RGBAf image: width=total_leds, height=1
	# r=uv_x, g=uv_y, b=extent_x, a=extent_y
	_led_pos_image = Image.create(_total_leds, 1, false, Image.FORMAT_RGBAF)

	var led_idx: int = 0
	for fd in fix_inputs:
		for i in range(fd.led_count):
			var uv: Vector2 = fd.led_positions[i]
			_led_pos_image.set_pixel(led_idx, 0,
				Color(uv.x, uv.y, fd.sample_extent.x, fd.sample_extent.y))
			led_idx += 1

	if _led_pos_texture == null:
		_led_pos_texture = ImageTexture.create_from_image(_led_pos_image)
	else:
		_led_pos_texture.update(_led_pos_image)


## Hash the fixture inputs for change detection (avoids rebuild every frame).
## NOTE: Only samples first+last LED positions for speed. A middle-LED-only UV
## change won't trigger rebuild until fixture_name/led_count/layout also changes.
static func _compute_fix_hash(fix_inputs: Array[GNFixtureData]) -> int:
	var h: int = 0
	for fd in fix_inputs:
		h = hash(h ^ hash(fd.fixture_name) ^ hash(fd.led_count)
			^ hash(fd.channel_layout) ^ hash(fd.dmx_start))
		# Sample a few positions to detect UV changes
		if fd.led_count > 0:
			h = hash(h ^ hash(fd.led_positions[0]))
			h = hash(h ^ hash(fd.led_positions[fd.led_count - 1]))
	return h
