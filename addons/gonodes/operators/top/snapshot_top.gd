class_name SnapshotTOP
extends GNTopBase
## Renders any non-TOP data as a TOP texture — the same visualization the
## viewer panel shows, but available as a node output for downstream processing.
##
## Shares rendering code with GNViewerPanel via GNViewerRenderHelpers, so
## improvements to the viewer automatically benefit this node too.
##
## The "mode" parameter selects the input data family. Changing mode rebuilds
## the input port to the matching family type and shows only the relevant
## parameters.
##
## Modes: SOP, CHOP, DAT, POP, VOL, MAT, IMG
##   - SOP  → orbit camera render (yaw, pitch, distance, wireframe)
##   - CHOP → waveform image
##   - DAT  → grid-cell table image
##   - POP  → GPU compute point-cloud render → Texture2DRD (zero-copy)
##   - VOL  → GPU compute slice composite / MIP → Texture2DRD (zero-copy)
##   - MAT  → sphere preview render
##   - IMG  → direct CPU Image upload (pass-through)

## Mode enum indices — must match the enum_options order in _init_parameters.
const MODE_SOP  := 0
const MODE_CHOP := 1
const MODE_DAT  := 2
const MODE_POP  := 3
const MODE_VOL  := 4
const MODE_MAT  := 5
const MODE_IMG  := 6

## Maps mode index → GNFamily.Type for the input port.
const MODE_FAMILIES: Array[int] = [
	GNFamily.Type.SOP,   # 0
	GNFamily.Type.CHOP,  # 1
	GNFamily.Type.DAT,   # 2
	GNFamily.Type.POP,   # 3
	GNFamily.Type.VOL,   # 4
	GNFamily.Type.MAT,   # 5
	GNFamily.Type.IMG,   # 6
]

# ── Sub-viewport scenes (created lazily per mode) ────────────────────────────

## SOP viewport (3D mesh render).
var _sop_vp: SubViewport = null
var _sop_camera: Camera3D = null
var _sop_mesh_instance: MeshInstance3D = null
var _sop_gizmo: Node3D = null

## MAT viewport (material sphere).
var _mat_vp: SubViewport = null
var _mat_sphere: MeshInstance3D = null

## Reusable ImageTexture for CPU-side renders (CHOP, VOL, IMG).
var _img_texture: ImageTexture = null

## Previous ImageTexture size+format — for detecting when we need to recreate.
var _prev_img_size: Vector2i = Vector2i.ZERO
var _prev_img_format: int = -1

## DAT SubViewport + drawing control for text table rendering.
var _dat_vp: SubViewport = null
var _dat_draw: _DATTableDraw = null

## Current mode — cached to detect mode changes.
var _current_mode: int = -1


func _init() -> void:
	super._init()
	node_type = "snapshot"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Source data to render")
	add_output("out", GNFamily.Type.TOP, "Rendered texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["SOP", "CHOP", "DAT", "POP", "VOL", "MAT", "IMG"]),
		MODE_SOP, "Mode", "Select the input data family to visualize"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512),
		"Resolution", "Output image size"))

	# ── SOP parameters (visible for SOP + POP) ─────────────────────────
	var sop_pop_rule := {"param": "mode", "values": [MODE_SOP, MODE_POP]}
	var p_yaw := GNParameter.create_float("orbit_yaw", 45.0, -360.0, 360.0, 0.5,
		"Orbit Yaw", "Horizontal camera rotation in degrees")
	p_yaw.visibility_rule = sop_pop_rule
	add_parameter(p_yaw)
	var p_pitch := GNParameter.create_float("orbit_pitch", -30.0, -89.0, 89.0, 0.5,
		"Orbit Pitch", "Vertical camera rotation in degrees")
	p_pitch.visibility_rule = sop_pop_rule
	add_parameter(p_pitch)
	var p_dist := GNParameter.create_float("orbit_distance", 3.0, 0.5, 50.0, 0.1,
		"Orbit Distance", "Camera distance from origin")
	p_dist.visibility_rule = sop_pop_rule
	add_parameter(p_dist)
	var p_wire := GNParameter.create_bool("wireframe", false,
		"Wireframe", "Render mesh as wireframe")
	p_wire.visibility_rule = {"param": "mode", "values": [MODE_SOP]}
	add_parameter(p_wire)

	# ── POP parameters ──────────────────────────────────────────────────
	var p_ps := GNParameter.create_float("point_size", 0.02, 0.001, 1.0, 0.001,
		"Point Size", "Billboard size for each particle")
	p_ps.visibility_rule = {"param": "mode", "values": [MODE_POP]}
	add_parameter(p_ps)

	# ── VOL parameters ──────────────────────────────────────────────────
	var vol_rule := {"param": "mode", "values": [MODE_VOL]}
	var p_vv := GNParameter.create_enum("vol_view",
		PackedStringArray(["Slices", "MIP"]),
		0, "Volume View", "Slices = 3 orthogonal planes, MIP = max intensity projection")
	p_vv.visibility_rule = vol_rule
	add_parameter(p_vv)
	var p_sp := GNParameter.create_float("slice_pos", 0.5, 0.0, 1.0, 0.01,
		"Slice Position", "Normalized position along each axis (0..1)")
	p_sp.visibility_rule = vol_rule
	add_parameter(p_sp)


func _on_parameter_changed(param_name: String, new_value: Variant) -> void:
	super._on_parameter_changed(param_name, new_value)
	if param_name == "mode":
		_rebuild_input_for_mode(int(new_value))


## Rebuilds the input port to match the selected mode's family type.
func _rebuild_input_for_mode(mode: int) -> void:
	if mode == _current_mode:
		return
	_current_mode = mode
	var fam: int = MODE_FAMILIES[mode]
	input_ports.clear()
	add_input("in", fam as GNFamily.Type, false,
		"Source data to render (%s)" % GNFamily.get_family_name(fam as GNFamily.Type))
	ports_changed.emit(id)


func _cook(inputs: Array[GNData]) -> GNData:
	var data: GNData = inputs[0] if inputs.size() > 0 and inputs[0] != null else null
	if data == null:
		return null

	var mode: int = get_param_value("mode")
	var res: Vector2i = get_param_value("resolution")
	res = Vector2i(maxi(res.x, 1), maxi(res.y, 1))

	match mode:
		MODE_SOP:
			return _cook_sop(data, res)
		MODE_CHOP:
			return _cook_chop(data, res)
		MODE_DAT:
			return _cook_dat(data, res)
		MODE_POP:
			return _cook_pop(data, res)
		MODE_VOL:
			return _cook_vol(data, res)
		MODE_MAT:
			return _cook_mat(data, res)
		MODE_IMG:
			return _cook_img(data, res)

	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Per-mode cook implementations
# ═══════════════════════════════════════════════════════════════════════════════

func _cook_sop(data: GNData, res: Vector2i) -> GNData:
	var geo := data as GNGeoData
	if geo == null or geo.mesh == null:
		return null

	_ensure_sop_viewport(res)
	_sop_vp.size = res

	var yaw: float = get_param_value("orbit_yaw")
	var pitch: float = get_param_value("orbit_pitch")
	var dist: float = get_param_value("orbit_distance")
	var wire: bool = get_param_value("wireframe")

	GNViewerRenderHelpers.apply_orbit_camera(_sop_camera, yaw, pitch, dist)
	GNViewerRenderHelpers.update_gizmo_scale(_sop_gizmo, dist)
	GNViewerRenderHelpers.render_sop(_sop_vp, _sop_mesh_instance, geo.mesh, wire)

	return _output_from_viewport(_sop_vp, res)


func _cook_chop(data: GNData, res: Vector2i) -> GNData:
	var ch := data as GNChannelData
	if ch == null or ch.channels.is_empty():
		return null

	# Use a rolling window: show last 'res.x' samples so the waveform scrolls.
	var img := GNViewerRenderHelpers.render_chop_waveform_rolling(ch, res)
	return _output_from_image(img, res)


func _cook_dat(data: GNData, res: Vector2i) -> GNData:
	var tbl := data as GNTableData
	if tbl == null or tbl.table.is_empty():
		return null

	_ensure_dat_viewport(res)
	_dat_vp.size = res
	_dat_draw.table_data = tbl
	_dat_draw.queue_redraw()

	return _output_from_viewport(_dat_vp, res)


func _cook_pop(data: GNData, res: Vector2i) -> GNData:
	var pd := data as GNParticleData
	if pd == null or pd.particle_count <= 0:
		return null

	var yaw: float = get_param_value("orbit_yaw")
	var pitch: float = get_param_value("orbit_pitch")
	var dist: float = get_param_value("orbit_distance")
	var pt_size: float = get_param_value("point_size")

	var tex := GNViewerRenderHelpers.render_pop_gpu(
		pd, res, yaw, pitch, dist, pt_size)
	if tex == null:
		return null

	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = tex
	_cached_tex_data.resolution = res
	return _cached_tex_data


func _cook_vol(data: GNData, res: Vector2i) -> GNData:
	var vd := data as GNVolumeData
	if vd == null or not vd.has_volume():
		return null

	var vol_view: int = get_param_value("vol_view")
	var slice_pos: float = get_param_value("slice_pos")
	var show_mip: bool = (vol_view == 1)

	var tex := GNViewerRenderHelpers.render_vol_gpu(vd, res, slice_pos, show_mip)
	if tex == null:
		return null

	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = tex
	_cached_tex_data.resolution = res
	return _cached_tex_data


func _cook_mat(data: GNData, res: Vector2i) -> GNData:
	var mat_data := data as GNMaterialData
	if mat_data == null or mat_data.material == null:
		return null

	_ensure_mat_viewport(res)
	_mat_vp.size = res

	GNViewerRenderHelpers.render_mat(_mat_vp, _mat_sphere, mat_data.material)

	return _output_from_viewport(_mat_vp, res)


func _cook_img(data: GNData, res: Vector2i) -> GNData:
	var img_data := data as GNImageData
	if img_data == null or img_data.image == null:
		return null

	var src: Image = img_data.image
	# Resize to target resolution if needed.
	var img: Image
	if src.get_size() == Vector2i(res.x, res.y) and src.get_format() == Image.FORMAT_RGBA8:
		img = src
	else:
		img = src.duplicate()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		if img.get_size() != Vector2i(res.x, res.y):
			img.resize(res.x, res.y)

	# Recreate ImageTexture if size or format changed.
	var img_size := img.get_size()
	if _img_texture == null or _prev_img_size != img_size or _prev_img_format != img.get_format():
		_img_texture = ImageTexture.create_from_image(img)
		_prev_img_size = img_size
		_prev_img_format = img.get_format()
	else:
		_img_texture.update(img)

	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _img_texture
	_cached_tex_data.resolution = res
	return _cached_tex_data


# ═══════════════════════════════════════════════════════════════════════════════
# Lazy viewport creation
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_sop_viewport(size: Vector2i) -> void:
	if _sop_vp != null:
		return
	var scene := GNViewerRenderHelpers.create_sop_viewport(size)
	_sop_vp = scene["viewport"]
	_sop_camera = scene["camera"]
	_sop_mesh_instance = scene["mesh_instance"]
	_sop_gizmo = scene["gizmo_root"]
	add_child(_sop_vp)


func _ensure_mat_viewport(size: Vector2i) -> void:
	if _mat_vp != null:
		return
	var scene := GNViewerRenderHelpers.create_mat_viewport(size)
	_mat_vp = scene["viewport"]
	_mat_sphere = scene["sphere"]
	add_child(_mat_vp)


func _ensure_dat_viewport(size: Vector2i) -> void:
	if _dat_vp != null:
		return
	_dat_vp = SubViewport.new()
	_dat_vp.size = size
	_dat_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_dat_vp.transparent_bg = false
	_dat_draw = _DATTableDraw.new()
	_dat_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dat_vp.add_child(_dat_draw)
	add_child(_dat_vp)


# ═══════════════════════════════════════════════════════════════════════════════
# Output helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Wraps a SubViewport's texture as the TOP output.
func _output_from_viewport(vp: SubViewport, res: Vector2i) -> GNData:
	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = vp.get_texture()
	_cached_tex_data.viewport = vp
	_cached_tex_data.resolution = res
	return _cached_tex_data


## Uploads a CPU-side Image as an ImageTexture TOP output.
func _output_from_image(img: Image, res: Vector2i) -> GNData:
	var img_size := img.get_size()
	var img_fmt := img.get_format()
	if _img_texture == null or _prev_img_size != img_size or _prev_img_format != img_fmt:
		_img_texture = ImageTexture.create_from_image(img)
		_prev_img_size = img_size
		_prev_img_format = img_fmt
	else:
		_img_texture.update(img)
	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _img_texture
	_cached_tex_data.resolution = res
	return _cached_tex_data


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization — persist mode for input port rebuild on load
# ═══════════════════════════════════════════════════════════════════════════════

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["snapshot_mode"] = get_param_value("mode")
	return d


func from_dict(d: Dictionary) -> void:
	# Rebuild input port before super restores connections
	if d.has("snapshot_mode"):
		_rebuild_input_for_mode(int(d["snapshot_mode"]))
	super.from_dict(d)


# ═══════════════════════════════════════════════════════════════════════════════
# Inner class: DAT table drawing control (renders text via _draw)
# ═══════════════════════════════════════════════════════════════════════════════

class _DATTableDraw extends Control:
	var table_data: GNTableData = null

	var bg_color: Color = Color(0.06, 0.06, 0.08)
	var cell_color: Color = Color(0.12, 0.12, 0.16)
	var header_color: Color = Color(0.18, 0.18, 0.25)
	var border_color: Color = Color(0.06, 0.06, 0.08)
	var text_color: Color = Color(0.85, 0.85, 0.9)
	var header_text_color: Color = Color(0.95, 0.95, 1.0)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), bg_color)
		if table_data == null or table_data.table.is_empty():
			return

		var rows: Array = table_data.table
		var row_count: int = rows.size()
		var col_count: int = 0
		for row in rows:
			if row.size() > col_count:
				col_count = row.size()
		if col_count == 0:
			return

		var font: Font = ThemeDB.fallback_font
		var font_size: int = clampi(int(size.y / row_count * 0.55), 8, 18)

		var cell_w: float = size.x / float(col_count)
		var cell_h: float = size.y / float(row_count)

		for r in range(row_count):
			for c in range(col_count):
				var x0: float = c * cell_w
				var y0: float = r * cell_h
				var rect := Rect2(x0, y0, cell_w, cell_h)

				# Cell background
				var is_header: bool = (r == 0 and table_data.has_header)
				var fill: Color = header_color if is_header else cell_color
				draw_rect(rect.grow(-0.5), fill)

				# Cell text
				var cell_val: String = ""
				if c < rows[r].size():
					cell_val = str(rows[r][c])
				if cell_val.length() > 0:
					var tc: Color = header_text_color if is_header else text_color
					# Truncate text to fit cell width
					var max_chars: int = maxi(int(cell_w / (font_size * 0.55)), 1)
					if cell_val.length() > max_chars:
						cell_val = cell_val.left(max_chars - 1) + "\u2026"
					var text_y: float = y0 + cell_h * 0.5 + font_size * 0.35
					draw_string(font, Vector2(x0 + 4.0, text_y), cell_val,
						HORIZONTAL_ALIGNMENT_LEFT, cell_w - 8.0, font_size, tc)
