class_name SnapshotTOP
extends GNTopBase
## Renders any non-TOP data as a TOP texture — the same visualization the
## viewer panel shows, but available as a node output for downstream processing.
##
## Shares rendering code with GNViewerPanel via GNViewerRenderer, so
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
##   - POP  → MultiMesh point-cloud render (orbit, point size)
##   - VOL  → orthogonal slice composite or MIP
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

## POP viewport (particle point cloud).
var _pop_vp: SubViewport = null
var _pop_camera: Camera3D = null
var _pop_multimesh: MultiMeshInstance3D = null
var _pop_gizmo: Node3D = null

## MAT viewport (material sphere).
var _mat_vp: SubViewport = null
var _mat_sphere: MeshInstance3D = null

## Reusable ImageTexture for CPU-side renders (CHOP, DAT, VOL, IMG).
var _img_texture: ImageTexture = null

## Current mode — cached to detect mode changes.
var _current_mode: int = -1


func _init() -> void:
	super._init()
	node_type = "snapshot"
	node_description = "Render any non-TOP data as a TOP texture (same as viewer)."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Source data to render")
	add_output("out", GNFamily.Type.TOP, "Rendered texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["SOP", "CHOP", "DAT", "POP", "VOL", "MAT", "IMG"]),
		MODE_SOP, "Mode", "Select the input data family to visualize"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512),
		"Resolution", "Output image size"))

	# ── SOP parameters ──────────────────────────────────────────────────
	add_parameter(GNParameter.create_float("orbit_yaw", 45.0, -360.0, 360.0, 0.5,
		"Orbit Yaw", "Horizontal camera rotation in degrees"))
	add_parameter(GNParameter.create_float("orbit_pitch", -30.0, -89.0, 89.0, 0.5,
		"Orbit Pitch", "Vertical camera rotation in degrees"))
	add_parameter(GNParameter.create_float("orbit_distance", 3.0, 0.5, 50.0, 0.1,
		"Orbit Distance", "Camera distance from origin"))
	add_parameter(GNParameter.create_bool("wireframe", false,
		"Wireframe", "Render mesh as wireframe"))

	# ── POP parameters ──────────────────────────────────────────────────
	add_parameter(GNParameter.create_float("point_size", 0.02, 0.001, 1.0, 0.001,
		"Point Size", "Billboard size for each particle"))

	# ── VOL parameters ──────────────────────────────────────────────────
	add_parameter(GNParameter.create_enum("vol_view",
		PackedStringArray(["Slices", "MIP"]),
		0, "Volume View", "Slices = 3 orthogonal planes, MIP = max intensity projection"))
	add_parameter(GNParameter.create_float("slice_pos", 0.5, 0.0, 1.0, 0.01,
		"Slice Position", "Normalized position along each axis (0..1)"))

	# Set initial visibility
	_update_param_visibility(MODE_SOP)


func _on_parameter_changed(param_name: String, new_value: Variant) -> void:
	super._on_parameter_changed(param_name, new_value)
	if param_name == "mode":
		var new_mode: int = int(new_value)
		_rebuild_input_for_mode(new_mode)
		_update_param_visibility(new_mode)


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


## Shows/hides parameters based on the active mode.
func _update_param_visibility(mode: int) -> void:
	# SOP-only params
	var sop_params := ["orbit_yaw", "orbit_pitch", "orbit_distance", "wireframe"]
	for p in sop_params:
		if parameters.has(p):
			parameters[p].visible = (mode == MODE_SOP or mode == MODE_POP)

	# POP-only params
	if parameters.has("point_size"):
		parameters["point_size"].visible = (mode == MODE_POP)

	# VOL-only params
	var vol_params := ["vol_view", "slice_pos"]
	for p in vol_params:
		if parameters.has(p):
			parameters[p].visible = (mode == MODE_VOL)

	parameters_changed.emit(id)


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

	GNViewerRenderer.apply_orbit_camera(_sop_camera, yaw, pitch, dist)
	GNViewerRenderer.update_gizmo_scale(_sop_gizmo, dist)
	GNViewerRenderer.render_sop(_sop_vp, _sop_mesh_instance, geo.mesh, wire)

	return _output_from_viewport(_sop_vp, res)


func _cook_chop(data: GNData, res: Vector2i) -> GNData:
	var ch := data as GNChannelData
	if ch == null or ch.channels.is_empty():
		return null

	var img := GNViewerRenderer.render_chop_waveform(ch, res)
	return _output_from_image(img, res)


func _cook_dat(data: GNData, res: Vector2i) -> GNData:
	var tbl := data as GNTableData
	if tbl == null or tbl.table.is_empty():
		return null

	var img := GNViewerRenderer.render_dat_table(tbl, res)
	return _output_from_image(img, res)


func _cook_pop(data: GNData, res: Vector2i) -> GNData:
	var pd := data as GNParticleData
	if pd == null or pd.particle_count <= 0:
		return null

	_ensure_pop_viewport(res)
	_pop_vp.size = res

	var yaw: float = get_param_value("orbit_yaw")
	var pitch: float = get_param_value("orbit_pitch")
	var dist: float = get_param_value("orbit_distance")
	var pt_size: float = get_param_value("point_size")

	GNViewerRenderer.apply_orbit_camera(_pop_camera, yaw, pitch, dist)
	GNViewerRenderer.update_gizmo_scale(_pop_gizmo, dist)

	if not GNViewerRenderer.render_pop(_pop_vp, _pop_multimesh, pd, pt_size):
		return null

	return _output_from_viewport(_pop_vp, res)


func _cook_vol(data: GNData, res: Vector2i) -> GNData:
	var vd := data as GNVolumeData
	if vd == null or not vd.has_volume():
		return null

	var vol_view: int = get_param_value("vol_view")
	var slice_pos: float = get_param_value("slice_pos")
	var show_mip: bool = (vol_view == 1)

	var img := GNViewerRenderer.render_vol_composite(vd, res, slice_pos, show_mip)
	return _output_from_image(img, res)


func _cook_mat(data: GNData, res: Vector2i) -> GNData:
	var mat_data := data as GNMaterialData
	if mat_data == null or mat_data.material == null:
		return null

	_ensure_mat_viewport(res)
	_mat_vp.size = res

	GNViewerRenderer.render_mat(_mat_vp, _mat_sphere, mat_data.material)

	return _output_from_viewport(_mat_vp, res)


func _cook_img(data: GNData, res: Vector2i) -> GNData:
	var img_data := data as GNImageData
	if img_data == null:
		return null

	var img := GNViewerRenderer.render_img(img_data)
	if img == null:
		return null

	return _output_from_image(img, res)


# ═══════════════════════════════════════════════════════════════════════════════
# Lazy viewport creation
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_sop_viewport(size: Vector2i) -> void:
	if _sop_vp != null:
		return
	var scene := GNViewerRenderer.create_sop_viewport(size)
	_sop_vp = scene["viewport"]
	_sop_camera = scene["camera"]
	_sop_mesh_instance = scene["mesh_instance"]
	_sop_gizmo = scene["gizmo_root"]
	add_child(_sop_vp)


func _ensure_pop_viewport(size: Vector2i) -> void:
	if _pop_vp != null:
		return
	var scene := GNViewerRenderer.create_pop_viewport(size)
	_pop_vp = scene["viewport"]
	_pop_camera = scene["camera"]
	_pop_multimesh = scene["multimesh_instance"]
	_pop_gizmo = scene["gizmo_root"]
	add_child(_pop_vp)


func _ensure_mat_viewport(size: Vector2i) -> void:
	if _mat_vp != null:
		return
	var scene := GNViewerRenderer.create_mat_viewport(size)
	_mat_vp = scene["viewport"]
	_mat_sphere = scene["sphere"]
	add_child(_mat_vp)


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
	if _img_texture == null:
		_img_texture = ImageTexture.create_from_image(img)
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
		var mode: int = int(d["snapshot_mode"])
		_rebuild_input_for_mode(mode)
		_update_param_visibility(mode)
	super.from_dict(d)
