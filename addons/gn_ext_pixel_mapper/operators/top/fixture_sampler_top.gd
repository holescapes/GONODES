class_name FixtureSamplerTOP
extends GNTopInteractiveBase
## MadMapper-style fixture sampler with interactive placement.
##
## Port 0 input : source TOP (the image to sample -- any resolution)
## Ports 1+ input: FIX inputs (dynamic auto-grow -- connect as many fixtures as needed)
##
## Port 0 output: Source texture passthrough (for downstream preview/WindowOUT)
## Port 1 output: CHOP with sampled LED colour values (for DMX output)
## Port 2 output: Interactive panel (fixture handles for WindowOUT)
##
## Each connected fixture has a placement transform stored on this node:
##   Strip: two endpoint UVs (draggable in viewer)
##   Grid/Matrix: four corner UVs (TL, TR, BL, BR -- draggable in viewer)
##   Custom: offset + scale (draggable group)
##
## Viewer shows source texture + interactive fixture handles overlay.
## FIX nodes define shape/LED count/DMX address; this node owns UV placement.


# ── Placement state ──────────────────────────────────────────────────────────

## Per-fixture placement, keyed by input port index (1-based).
## Each entry is a Dictionary with shape-specific fields:
##   strip:  { "a": Vector2, "b": Vector2 }
##   grid/matrix: { "tl": Vector2, "tr": Vector2, "bl": Vector2, "br": Vector2 }
##   custom: { "offset": Vector2, "scale": Vector2 }
var _placements: Dictionary = {}

## Default placement rectangles for new fixtures.
const _DEFAULT_STRIP_A := Vector2(0.1, 0.5)
const _DEFAULT_STRIP_B := Vector2(0.9, 0.5)
const _DEFAULT_RECT_TL := Vector2(0.1, 0.1)
const _DEFAULT_RECT_TR := Vector2(0.9, 0.1)
const _DEFAULT_RECT_BL := Vector2(0.1, 0.9)
const _DEFAULT_RECT_BR := Vector2(0.9, 0.9)
const _DEFAULT_CUSTOM_OFFSET := Vector2(0.1, 0.1)
const _DEFAULT_CUSTOM_SCALE := Vector2(0.8, 0.8)


# ── LED position texture (GPU sampling) ──────────────────────────────────────

var _led_pos_image: Image = null
var _led_pos_texture: ImageTexture = null
var _fixture_manifest: Array = []
var _last_fix_hash: int = -1
var _total_leds: int = 0
var _max_channels: int = 3

## Source texture passed through on port 0.
var _source_tex_data: GNTextureData = null

## CHOP output for port 1 (demand-gated).
var _cached_chop_data: GNChannelData = null

## Channel names for CHOP unpack.
const _LAYOUT_CHANNELS: Dictionary = {
	"rgb":  ["r", "g", "b"],
	"rgbw": ["r", "g", "b", "w"],
	"r":    ["r"],
	"g":    ["g"],
	"b":    ["b"],
	"w":    ["w"],
}


func _init() -> void:
	node_type = "fixture_sampler"
	node_description = "MadMapper-style fixture placement + sampling. Drag fixtures onto the source image."


func _init_ports() -> void:
	var fix_fam: int = GNFamily.string_to_type("FIX")
	add_input("source", GNFamily.Type.TOP, true, "Source image to sample")
	_enable_dynamic_inputs(fix_fam, "fix", "Fixture")
	add_output("out", GNFamily.Type.TOP, "Source texture passthrough")
	add_output("chop", GNFamily.Type.CHOP, "Sampled LED values as CHOP channels")
	add_panel_output("Fixture placement handles")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("sample_mode",
		PackedStringArray(["Point", "Box Filter"]), 0,
		"Sample Mode", "Point = single texel. Box Filter = 3x3 tap average."))
	add_parameter(GNParameter.create_vector2("sample_extent", Vector2.ZERO,
		"Sample Extent", "UV half-size for box-filter area per LED. (0,0) = point sample."))


# ── Dynamic input port management (preserve fixed port 0) ────────────────────

func _rebuild_input_ports(fix_count: int) -> void:
	var fix_fam: int = GNFamily.string_to_type("FIX")
	input_ports.clear()
	add_input("source", GNFamily.Type.TOP, true, "Source image to sample")
	for i in range(fix_count):
		add_input("fix%d" % i, fix_fam, false, "Fixture %d" % i)
	GNLogger.debug("GNNode", "'%s' input port count -> %d" % [id, input_ports.size()])
	ports_changed.emit(id)


func update_dynamic_inputs(connected_ports: PackedInt32Array) -> void:
	if not _dynamic_input:
		return
	var max_fix: int = -1
	for p in connected_ports:
		if p >= 1 and p > max_fix:
			max_fix = p
	var desired_fix_count: int = maxi(max_fix + 1, 1)
	if 1 + desired_fix_count == input_ports.size():
		return
	_rebuild_input_ports(desired_fix_count)


func from_dict(d: Dictionary) -> void:
	var saved_total: int = -1
	if _dynamic_input and d.has("dynamic_input_count"):
		saved_total = int(d["dynamic_input_count"])
		d = d.duplicate()
		d.erase("dynamic_input_count")
	super.from_dict(d)
	if saved_total > 1:
		_rebuild_input_ports(saved_total - 1)
	# Restore placements
	if d.has("fixture_placements"):
		_placements = _deserialize_placements(d["fixture_placements"])


func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	if not _placements.is_empty():
		d["fixture_placements"] = _serialize_placements()
	return d


# ── Cook ─────────────────────────────────────────────────────────────────────

func _cook(inputs: Array[GNData]) -> GNData:
	# Port 0 = source TOP
	var src_data: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if src_data == null or src_data.texture == null:
		node_warning = "No source TOP connected."
		return null

	# Store source for port 0 passthrough
	_source_tex_data = src_data

	# Collect FIX inputs (ports 1+)
	var fix_inputs: Array[GNFixtureData] = []
	var fix_port_indices: Array[int] = []
	for i in range(1, inputs.size()):
		var fd: GNFixtureData = inputs[i] as GNFixtureData if inputs[i] is GNFixtureData else null
		if fd != null and fd.led_count > 0:
			fix_inputs.append(fd)
			fix_port_indices.append(i)

	if fix_inputs.is_empty():
		node_warning = "No FIX inputs connected."
		_cached_tex_data.texture = src_data.texture
		_cached_tex_data.resolution = src_data.resolution
		return _cached_tex_data

	node_warning = ""

	# Ensure placements exist for all connected fixtures
	for idx in range(fix_inputs.size()):
		var port: int = fix_port_indices[idx]
		if not _placements.has(port):
			_placements[port] = _default_placement(fix_inputs[idx].shape)

	# Build final UV positions by mapping local -> world via placement transforms
	var final_positions: Array[PackedVector2Array] = []
	for idx in range(fix_inputs.size()):
		var fd: GNFixtureData = fix_inputs[idx]
		var port: int = fix_port_indices[idx]
		var placement: Dictionary = _placements[port]
		final_positions.append(_apply_placement(fd, placement))

	# Rebuild LED-position texture if changed
	var fix_hash: int = _compute_fix_hash(fix_inputs, final_positions)
	if fix_hash != _last_fix_hash:
		_rebuild_led_pos_texture(fix_inputs, final_positions, fix_port_indices)
		_last_fix_hash = fix_hash

	# GPU sampling pass
	if is_output_demanded(1) or _total_leds > 0:
		var sample_extent: Vector2 = get_param_value("sample_extent")
		var out_size := Vector2i(_max_channels, _total_leds)
		_init_shader_viewport(
			"res://addons/gn_ext_pixel_mapper/shaders/fixture_sampler.gdshader",
			false, false, out_size)
		if _viewport.size != out_size:
			_viewport.size = out_size
		_material.set_shader_parameter("source_tex", src_data.texture)
		_material.set_shader_parameter("led_pos_tex", _led_pos_texture)
		_material.set_shader_parameter("total_leds", _total_leds)
		_material.set_shader_parameter("channels_per_led", _max_channels)
		_material.set_shader_parameter("sample_mode", get_param_value("sample_mode"))
		var has_rgbw: bool = _fixture_manifest.any(func(e): return e.get("channel_layout", "rgb") == "rgbw")
		_material.set_shader_parameter("rgbw_mode", has_rgbw)

	# Port 0 returns source passthrough
	_cached_tex_data.texture = src_data.texture
	_cached_tex_data.resolution = src_data.resolution
	_cached_tex_data.metadata["fixture_manifest"] = _fixture_manifest
	_sync_panel_from_params_if_live()
	return _cached_tex_data


# ── Multi-output (Rule 25.24) ────────────────────────────────────────────────

func get_output_data(port_index: int) -> GNData:
	if port_index == 1:
		if not is_output_demanded(1):
			return null
		return _build_chop_output()
	return super.get_output_data(port_index)


func render_for_viewer(viewer, port_index: int = 0) -> void:
	if port_index == 1:
		var chop_data: GNChannelData = _build_chop_output()
		if chop_data != null and not chop_data.channels.is_empty():
			var renderer = GNFamily.get_renderer(GNFamily.Type.CHOP)
			if renderer != null:
				renderer.render_for_viewer(chop_data, viewer)
				return
			viewer.set_info("%d fixtures | %d LEDs | %d channels" % [
				_fixture_manifest.size(), _total_leds, chop_data.channels.size()], "")
			return
		if _viewport == null:
			viewer.set_info("No FIX inputs connected", "")
		else:
			viewer.set_info("Sampling %d LEDs..." % _total_leds, "")
		return
	super.render_for_viewer(viewer, port_index)


func _create_interactive_panel() -> GNInteractivePanel:
	var panel := FixtureOverlay.new()
	panel.grab_radius_uv = 0.03
	panel.handle_moved.connect(_on_fixture_handle_moved)
	return panel


func _on_fixture_handle_moved(fixture_idx: int, handle_idx: int, uv: Vector2) -> void:
	_move_handle(Vector2i(fixture_idx, handle_idx), uv)
	_sync_panel_from_params_if_live()
	mark_dirty()


func _sync_panel_from_params() -> void:
	if not is_instance_valid(_interactive_panel):
		return
	var panel: FixtureOverlay = _interactive_panel as FixtureOverlay
	if panel == null:
		return
	panel.fixtures.clear()
	for idx in range(_fixture_manifest.size()):
		var entry: Dictionary = _fixture_manifest[idx]
		var port: int = entry.get("port", -1)
		var shape: StringName = StringName(entry.get("shape", "strip"))
		var placement: Dictionary = _placements.get(port, {})
		var handles := PackedVector2Array()

		if shape == &"strip":
			handles.append(placement.get("a", _DEFAULT_STRIP_A))
			handles.append(placement.get("b", _DEFAULT_STRIP_B))
		elif shape == &"grid" or shape == &"matrix":
			handles.append(placement.get("tl", _DEFAULT_RECT_TL))
			handles.append(placement.get("tr", _DEFAULT_RECT_TR))
			handles.append(placement.get("bl", _DEFAULT_RECT_BL))
			handles.append(placement.get("br", _DEFAULT_RECT_BR))
		else:
			handles.append(placement.get("offset", _DEFAULT_CUSTOM_OFFSET))

		var leds := PackedVector2Array()
		if entry.has("offset") and _led_pos_image != null:
			var led_offset: int = entry["offset"]
			var led_count: int = entry["led_count"]
			for li in range(led_count):
				var px_idx: int = led_offset + li
				if px_idx < _led_pos_image.get_width():
					var c: Color = _led_pos_image.get_pixel(px_idx, 0)
					leds.append(Vector2(c.r, c.g))

		panel.fixtures.append({
			"shape": shape,
			"name": entry.get("name", ""),
			"handles": handles,
			"leds": leds,
			"color_index": idx,
			"cols": entry.get("cols", 0),
			"rows": entry.get("rows", 0),
		})
	panel.queue_redraw()


func _build_chop_output() -> GNChannelData:
	if _viewport == null or _fixture_manifest.is_empty():
		return null

	# CPU readback of the packed result texture (tiny: channels x total_leds)
	var vp_tex: ViewportTexture = _viewport.get_texture()
	if vp_tex == null:
		return null
	var img: Image = vp_tex.get_image()
	if img == null:
		return null

	if _cached_chop_data == null:
		_cached_chop_data = GNChannelData.new()
	else:
		_cached_chop_data.channels.clear()
	_cached_chop_data.valid = true
	_cached_chop_data.sample_rate = 60.0

	# DMX-interleaved format: one channel per DMX slot, 1 sample each.
	# Channel naming: "{fixture}.{led_index}.{component}" e.g. "strip.0.r", "strip.0.g"
	# This maps directly onto DmxOutCHOP: channel[i] -> DMX slot i.
	var max_w: int = img.get_width()

	# Build DMX routing table alongside channels (Rule 25.38 sideband metadata).
	# Maps each CHOP channel name -> { universe, slot } for DmxOutCHOP auto-routing.
	var dmx_routing: Array[Dictionary] = []

	for entry in _fixture_manifest:
		var fix_name: String = entry["name"]
		var led_count: int = entry["led_count"]
		var cpl: int = entry["channels_per_led"]
		var layout: String = entry.get("channel_layout", "rgb")
		var offset: int = entry["offset"]
		var uni: int = entry.get("universe", 1)
		var start_ch: int = entry.get("start_channel", 1)

		var ch_names: Array = _LAYOUT_CHANNELS.get(layout, [])
		if ch_names.is_empty():
			ch_names = ["ch0", "ch1", "ch2", "ch3"].slice(0, cpl)

		# Outer loop: LED first, then component -- preserves DMX wire order
		var dmx_slot: int = start_ch  # 1-based within universe
		for led_i in range(led_count):
			for ch_i in range(cpl):
				if ch_i >= max_w:
					continue
				var ch_label: String = ch_names[ch_i] if ch_i < ch_names.size() else ("ch%d" % ch_i)
				var pixel: Color = img.get_pixel(ch_i, offset + led_i)
				var values := PackedFloat32Array([pixel.r])
				var ch_full_name: String = "%s.%d.%s" % [fix_name, led_i, ch_label]
				_cached_chop_data.set_channel(ch_full_name, values)

				# Compute universe/slot, wrapping across universe boundaries
				var actual_uni: int = uni + (dmx_slot - 1) / 512
				var actual_slot: int = ((dmx_slot - 1) % 512) + 1
				dmx_routing.append({
					"channel": ch_full_name,
					"universe": actual_uni,
					"slot": actual_slot,
				})
				dmx_slot += 1

	_cached_chop_data.length = 1
	_cached_chop_data.metadata["dmx_routing"] = dmx_routing
	return _cached_chop_data


# ── Placement transforms ────────────────────────────────────────────────────

## Maps local-space LED positions to source-image UV using the placement transform.
static func _apply_placement(fd: GNFixtureData, placement: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	result.resize(fd.led_count)

	var shape: StringName = fd.shape
	if shape == &"strip":
		var a: Vector2 = placement.get("a", Vector2(0.1, 0.5))
		var b: Vector2 = placement.get("b", Vector2(0.9, 0.5))
		# Strip local positions have x in 0-1, y=0.5. Map x -> lerp(a, b).
		for i in range(fd.led_count):
			result[i] = a.lerp(b, fd.led_positions[i].x)

	elif shape == &"grid" or shape == &"matrix":
		var tl: Vector2 = placement.get("tl", Vector2(0.1, 0.1))
		var tr: Vector2 = placement.get("tr", Vector2(0.9, 0.1))
		var bl: Vector2 = placement.get("bl", Vector2(0.1, 0.9))
		var br: Vector2 = placement.get("br", Vector2(0.9, 0.9))
		# Bilinear interpolation: local x,y in 0-1 -> quad corners
		for i in range(fd.led_count):
			var lp: Vector2 = fd.led_positions[i]
			# Normalize to 0-1 range (matrix might have positions outside unit square)
			var top: Vector2 = tl.lerp(tr, lp.x)
			var bot: Vector2 = bl.lerp(br, lp.x)
			result[i] = top.lerp(bot, lp.y)

	else:
		# custom: offset + scale
		var offs: Vector2 = placement.get("offset", Vector2(0.1, 0.1))
		var sc: Vector2 = placement.get("scale", Vector2(0.8, 0.8))
		for i in range(fd.led_count):
			result[i] = offs + fd.led_positions[i] * sc

	return result


static func _default_placement(shape: StringName) -> Dictionary:
	if shape == &"strip":
		return { "a": _DEFAULT_STRIP_A, "b": _DEFAULT_STRIP_B }
	elif shape == &"grid" or shape == &"matrix":
		return { "tl": _DEFAULT_RECT_TL, "tr": _DEFAULT_RECT_TR,
				"bl": _DEFAULT_RECT_BL, "br": _DEFAULT_RECT_BR }
	else:
		return { "offset": _DEFAULT_CUSTOM_OFFSET, "scale": _DEFAULT_CUSTOM_SCALE }


# ── LED position texture ────────────────────────────────────────────────────

func _rebuild_led_pos_texture(fix_inputs: Array[GNFixtureData],
		final_positions: Array[PackedVector2Array],
		fix_port_indices: Array[int]) -> void:
	_total_leds = 0
	_max_channels = 1
	_fixture_manifest = []
	var sample_extent: Vector2 = get_param_value("sample_extent")

	for idx in range(fix_inputs.size()):
		var fd: GNFixtureData = fix_inputs[idx]
		_fixture_manifest.append({
			"name": fd.fixture_name,
			"led_count": fd.led_count,
			"channels_per_led": fd.channels_per_led,
			"channel_layout": fd.channel_layout,
			"universe": fd.universe,
			"start_channel": fd.start_channel,
			"offset": _total_leds,
			"port": fix_port_indices[idx],
			"shape": String(fd.shape),
		})
		_total_leds += fd.led_count
		_max_channels = maxi(_max_channels, fd.channels_per_led)

	if _total_leds == 0:
		return

	_led_pos_image = Image.create(_total_leds, 1, false, Image.FORMAT_RGBAF)

	var led_idx: int = 0
	for idx in range(fix_inputs.size()):
		var positions: PackedVector2Array = final_positions[idx]
		for i in range(positions.size()):
			var uv: Vector2 = positions[i]
			_led_pos_image.set_pixel(led_idx, 0,
				Color(uv.x, uv.y, sample_extent.x, sample_extent.y))
			led_idx += 1

	if _led_pos_texture == null:
		_led_pos_texture = ImageTexture.create_from_image(_led_pos_image)
	else:
		_led_pos_texture.update(_led_pos_image)


static func _compute_fix_hash(fix_inputs: Array[GNFixtureData],
		final_positions: Array[PackedVector2Array]) -> int:
	var h: int = 0
	for idx in range(fix_inputs.size()):
		var fd: GNFixtureData = fix_inputs[idx]
		h = hash(h ^ hash(fd.fixture_name) ^ hash(fd.led_count)
			^ hash(fd.channel_layout) ^ hash(fd.universe) ^ hash(fd.start_channel))
		var fp: PackedVector2Array = final_positions[idx]
		if fp.size() > 0:
			h = hash(h ^ hash(fp[0]))
			h = hash(h ^ hash(fp[fp.size() - 1]))
	return h


func _move_handle(handle_id: Vector2i, uv: Vector2) -> void:
	# Map from overlay fixture index back to port index
	if handle_id.x >= _fixture_manifest.size():
		return
	var entry: Dictionary = _fixture_manifest[handle_id.x]
	var port: int = entry.get("port", -1)
	if port < 0 or not _placements.has(port):
		return
	var placement: Dictionary = _placements[port]
	var shape: StringName = StringName(entry.get("shape", "custom"))
	var hi: int = handle_id.y

	if shape == &"strip":
		if hi == 0:
			placement["a"] = uv
		elif hi == 1:
			placement["b"] = uv
	elif shape == &"grid" or shape == &"matrix":
		var keys: Array = ["tl", "tr", "bl", "br"]
		if hi < keys.size():
			placement[keys[hi]] = uv
	else:
		# Custom: move the whole group
		placement["offset"] = uv


# ── Serialization of placement transforms ────────────────────────────────────

func _serialize_placements() -> Array:
	var result: Array = []
	for port in _placements:
		var p: Dictionary = _placements[port]
		var entry: Dictionary = { "port": port }
		for key in p:
			var val = p[key]
			if val is Vector2:
				entry[key] = { "_type": "Vector2", "x": val.x, "y": val.y }
			else:
				entry[key] = val
		result.append(entry)
	return result


static func _deserialize_placements(arr: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (arr is Array):
		return result
	for entry in arr:
		if not (entry is Dictionary) or not entry.has("port"):
			continue
		var port: int = int(entry["port"])
		var p: Dictionary = {}
		for key in entry:
			if key == "port":
				continue
			var val = entry[key]
			if val is Dictionary and val.get("_type", "") == "Vector2":
				p[key] = Vector2(float(val.get("x", 0)), float(val.get("y", 0)))
			else:
				p[key] = val
		result[port] = p
	return result
