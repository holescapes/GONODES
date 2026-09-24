class_name GNViewerRenderHelpers
extends RefCounted
## Optional helper library for common data-to-image rendering.
##
## Nodes use these utilities from their render_for_viewer() overrides when the
## default visualization is sufficient.  Custom operators can bypass this
## entirely and implement their own rendering.  The viewer and SnapshotTOP
## never call these directly — they go through the node's virtual method.
##
## All public methods are static — no instance state needed.


# ═══════════════════════════════════════════════════════════════════════════════
# SOP — Render GNGeoData via SubViewport
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a self-contained 3D SubViewport scene (camera + light + mesh + gizmo)
## ready for off-screen rendering. Caller owns the returned SubViewport and must
## add it to the scene tree.
##
## Returns: { "viewport": SubViewport, "camera": Camera3D,
##            "mesh_instance": MeshInstance3D, "gizmo_root": Node3D }
static func create_sop_viewport(size: Vector2i) -> Dictionary:
	var vp := SubViewport.new()
	vp.name = "SOP_Render_VP"
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.disable_3d = false
	vp.size = size

	# Camera
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 45.0
	vp.add_child(cam)

	# Light
	var light := DirectionalLight3D.new()
	light.name = "Light"
	light.rotation_degrees = Vector3(-45, 30, 0)
	vp.add_child(light)

	# Mesh instance
	var mi := MeshInstance3D.new()
	mi.name = "MeshPreview"
	vp.add_child(mi)

	# Environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.12)
	env.ambient_light_color = Color(0.2, 0.2, 0.25)
	env.ambient_light_energy = 0.5
	var world := World3D.new()
	world.environment = env
	vp.world_3d = world

	# Axis gizmo
	var gizmo := _create_axis_gizmo()
	vp.add_child(gizmo)

	return {
		"viewport": vp,
		"camera": cam,
		"mesh_instance": mi,
		"gizmo_root": gizmo,
	}


## Updates the orbit camera position from yaw/pitch/distance.
static func apply_orbit_camera(cam: Camera3D, yaw: float, pitch: float,
		distance: float) -> void:
	var yaw_rad := deg_to_rad(yaw)
	var pitch_rad := deg_to_rad(pitch)
	var offset := Vector3(
		distance * cos(pitch_rad) * sin(yaw_rad),
		distance * sin(pitch_rad),
		distance * cos(pitch_rad) * cos(yaw_rad)
	)
	cam.position = offset
	cam.look_at(Vector3.ZERO)


## Applies a mesh + optional wireframe to a SOP viewport and triggers one render.
## [param wireframe] — if true, uses debug wireframe draw mode.
static func render_sop(vp: SubViewport, mi: MeshInstance3D, mesh: Mesh,
		wireframe: bool = false) -> void:
	mi.mesh = mesh
	if wireframe:
		vp.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
	else:
		vp.debug_draw = Viewport.DEBUG_DRAW_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Updates the gizmo root scale to maintain constant screen size.
static func update_gizmo_scale(gizmo_root: Node3D, orbit_distance: float,
		screen_fraction: float = 0.08) -> void:
	var s: float = orbit_distance * screen_fraction
	gizmo_root.scale = Vector3(s, s, s)


# ═══════════════════════════════════════════════════════════════════════════════
# POP — Render GNParticleData via SubViewport + MultiMesh
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a 3D viewport with a MultiMeshInstance3D for particle point cloud.
## Returns: { "viewport": SubViewport, "camera": Camera3D,
##            "multimesh_instance": MultiMeshInstance3D, "gizmo_root": Node3D }
static func create_pop_viewport(size: Vector2i) -> Dictionary:
	var vp := SubViewport.new()
	vp.name = "POP_Render_VP"
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.disable_3d = false
	vp.size = size

	# Camera
	var cam := Camera3D.new()
	cam.name = "PopCamera"
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 45.0
	vp.add_child(cam)

	# Light
	var light := DirectionalLight3D.new()
	light.name = "PopLight"
	light.rotation_degrees = Vector3(-45, 30, 0)
	vp.add_child(light)

	# MultiMesh instance
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "PopMultiMesh"
	vp.add_child(mmi)

	# Environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.1)
	env.ambient_light_color = Color(0.3, 0.3, 0.35)
	env.ambient_light_energy = 0.5
	var world := World3D.new()
	world.environment = env
	vp.world_3d = world

	# Axis gizmo
	var gizmo := _create_axis_gizmo()
	vp.add_child(gizmo)

	return {
		"viewport": vp,
		"camera": cam,
		"multimesh_instance": mmi,
		"gizmo_root": gizmo,
	}


## Renders POP particles via GPU compute shader → Texture2DRD (zero-copy).
## Returns a Texture2DRD wrapping the rendered output, or null on failure.
## Uses the same shader as PointCloudRenderTOP.
static var _pop_output_tex_rid: RID = RID()
static var _pop_depth_tex_rid: RID = RID()
static var _pop_output_tex2d_rd: Texture2DRD = null
static var _pop_prev_res: Vector2i = Vector2i.ZERO

static func render_pop_gpu(pd: GNParticleData, size: Vector2i,
		orbit_yaw: float, orbit_pitch: float, orbit_distance: float,
		point_size: float = 4.0) -> Texture2DRD:
	var ctx := GNGpuContext.get_context()
	if ctx == null or ctx.rd == null or not pd.rd_buffer.is_valid():
		return null

	var w: int = maxi(size.x, 1)
	var h: int = maxi(size.y, 1)
	var res := Vector2i(w, h)
	var mrd := ctx.rd

	# Reallocate if resolution changed
	if res != _pop_prev_res:
		_free_pop_textures(mrd)
		_pop_output_tex_rid = ctx.create_texture_2d(w, h)
		_pop_depth_tex_rid = ctx.create_texture_2d(w, h,
			RenderingDevice.DATA_FORMAT_R32_SFLOAT)
		_pop_prev_res = res

	# Clear
	var bg_img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	bg_img.fill(Color(0.08, 0.08, 0.1))
	mrd.texture_update(_pop_output_tex_rid, 0, bg_img.get_data())
	var depth_img := Image.create(w, h, false, Image.FORMAT_RF)
	depth_img.fill(Color(1.0, 0.0, 0.0))
	mrd.texture_update(_pop_depth_tex_rid, 0, depth_img.get_data())

	# Camera
	var yaw_rad := deg_to_rad(orbit_yaw)
	var pitch_rad := deg_to_rad(orbit_pitch)
	var dist := orbit_distance
	var eye := Vector3(
		dist * cos(pitch_rad) * sin(yaw_rad),
		dist * sin(pitch_rad),
		dist * cos(pitch_rad) * cos(yaw_rad))
	var fwd := (-eye).normalized()
	var world_up := Vector3.UP
	var right := fwd.cross(world_up).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	var up := right.cross(fwd).normalized()
	var fov_rad := deg_to_rad(60.0)

	# Push constants (112 bytes, same layout as point_cloud_render.glsl)
	var pc := PackedByteArray()
	pc.resize(112)
	pc.encode_s32(0, w)
	pc.encode_s32(4, h)
	pc.encode_s32(8, pd.particle_count)
	pc.encode_float(12, point_size)
	pc.encode_float(16, eye.x); pc.encode_float(20, eye.y); pc.encode_float(24, eye.z)
	pc.encode_float(28, fwd.x); pc.encode_float(32, fwd.y); pc.encode_float(36, fwd.z)
	pc.encode_float(40, right.x); pc.encode_float(44, right.y); pc.encode_float(48, right.z)
	pc.encode_float(52, up.x); pc.encode_float(56, up.y); pc.encode_float(60, up.z)
	pc.encode_float(64, fov_rad)
	pc.encode_float(68, 0.01)   # near clip
	pc.encode_float(72, 100.0)  # far clip
	pc.encode_float(76, 1.0)    # size attenuation
	pc.encode_float(80, 1.0)    # alpha
	pc.encode_s32(84, 1)        # use particle color
	pc.encode_float(88, 0.2)    # fallback color r
	pc.encode_float(92, 0.8)    # fallback color g
	pc.encode_float(96, 0.8)    # fallback color b
	pc.encode_float(100, 0.0)
	pc.encode_float(104, 0.0)
	pc.encode_float(108, 0.0)

	var shader: RID = ctx.get_shader(
		"res://addons/gonodes/shaders/top/point_cloud_render.glsl")
	if not shader.is_valid():
		return null

	var us: RID = mrd.uniform_set_create([
		ctx.uniform_buffer(0, pd.rd_buffer),
		ctx.uniform_image(1, _pop_output_tex_rid),
		ctx.uniform_image(2, _pop_depth_tex_rid),
	], shader, 0)

	var wg_x: int = ceili(float(pd.particle_count) / 64.0)
	ctx.dispatch(shader, us, wg_x, 1, 1, pc)
	mrd.free_rid(us)

	if _pop_output_tex2d_rd == null:
		_pop_output_tex2d_rd = Texture2DRD.new()
	_pop_output_tex2d_rd.texture_rd_rid = _pop_output_tex_rid
	return _pop_output_tex2d_rd


static func _free_pop_textures(mrd: RenderingDevice) -> void:
	if _pop_output_tex2d_rd != null:
		_pop_output_tex2d_rd.texture_rd_rid = RID()
	if _pop_output_tex_rid.is_valid() and mrd != null:
		mrd.free_rid(_pop_output_tex_rid)
	_pop_output_tex_rid = RID()
	if _pop_depth_tex_rid.is_valid() and mrd != null:
		mrd.free_rid(_pop_depth_tex_rid)
	_pop_depth_tex_rid = RID()


# ═══════════════════════════════════════════════════════════════════════════════
# MAT — Render GNMaterialData via SubViewport + Preview Sphere
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a 3D SubViewport with a preview sphere for material display.
## Returns: { "viewport": SubViewport, "sphere": MeshInstance3D }
static func create_mat_viewport(size: Vector2i) -> Dictionary:
	var vp := SubViewport.new()
	vp.name = "MAT_Render_VP"
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.disable_3d = false
	vp.size = size

	# Camera
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.position = Vector3(0, 0, 2.5)
	cam.look_at_from_position(Vector3(0, 0, 2.5), Vector3.ZERO)
	vp.add_child(cam)

	# Light
	var light := DirectionalLight3D.new()
	light.name = "Light"
	light.rotation_degrees = Vector3(-45, 30, 0)
	vp.add_child(light)

	# Preview sphere
	var sphere := MeshInstance3D.new()
	sphere.name = "PreviewSphere"
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.8
	sphere_mesh.height = 1.6
	sphere_mesh.radial_segments = 64
	sphere_mesh.rings = 32
	sphere.mesh = sphere_mesh
	vp.add_child(sphere)

	# Environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.15, 0.15, 0.18)
	env.ambient_light_color = Color(0.3, 0.3, 0.35)
	env.ambient_light_energy = 0.5
	var world := World3D.new()
	world.environment = env
	vp.world_3d = world

	return {
		"viewport": vp,
		"sphere": sphere,
	}


## Applies a material to the preview sphere and renders one frame.
static func render_mat(vp: SubViewport, sphere: MeshInstance3D,
		material: Material) -> void:
	sphere.material_override = material
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# ═══════════════════════════════════════════════════════════════════════════════
# CHOP — Waveform rendering
# ═══════════════════════════════════════════════════════════════════════════════

## Creates an interactive waveform Control (grid, zoom, pan, legends).
## Use this for viewer display; use render_chop_waveform_rolling() for
## baking CHOP data to a static Image (e.g. SnapshotTOP).
static func create_waveform_view() -> GNWaveformView:
	return GNWaveformView.new()


## Renders a rolling-window waveform: only the last [code]size.x[/code] samples
## are drawn so the waveform scrolls left as new data arrives.
static func render_chop_waveform_rolling(ch_data: GNChannelData, size: Vector2i,
		bg_color: Color = Color(0.06, 0.06, 0.08),
		line_color: Color = Color(0.3, 1.0, 0.4)) -> Image:
	var w: int = maxi(size.x, 1)
	var h: int = maxi(size.y, 1)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg_color)

	if ch_data == null or ch_data.channels.is_empty():
		return img

	var ch_names: Array = ch_data.channels.keys()
	var ch_count: int = ch_names.size()

	# Compute global range across all channels for consistent Y scaling.
	var min_v: float = INF
	var max_v: float = -INF
	for ch_name in ch_names:
		var samples: PackedFloat32Array = ch_data.channels[ch_name]
		for val in samples:
			min_v = minf(min_v, val)
			max_v = maxf(max_v, val)
	if absf(max_v - min_v) < 0.0001:
		min_v -= 0.5
		max_v += 0.5
	var headroom: float = (max_v - min_v) * 0.05
	min_v -= headroom
	max_v += headroom

	# Draw each channel — only the last W samples (rolling window).
	for ci in range(ch_count):
		var samples: PackedFloat32Array = ch_data.channels[ch_names[ci]]
		if samples.is_empty():
			continue

		var col: Color = line_color
		if ch_count > 1:
			col = Color.from_hsv(fmod(line_color.h + float(ci) / float(ch_count), 1.0),
				line_color.s, line_color.v, line_color.a)

		var sample_count: int = samples.size()

		if sample_count <= w:
			# Fewer samples than pixels — stretch across full width.
			for px in range(w):
				var t: float = float(px) / float(w - 1) if w > 1 else 0.0
				var si_f: float = t * float(sample_count - 1)
				var si0: int = clampi(int(si_f), 0, sample_count - 1)
				var si1: int = clampi(si0 + 1, 0, sample_count - 1)
				var frac: float = si_f - float(si0)
				var val: float = samples[si0] * (1.0 - frac) + samples[si1] * frac
				var norm: float = clampf((val - min_v) / (max_v - min_v), 0.0, 1.0)
				var py: int = clampi(h - 1 - int(norm * float(h - 1)), 0, h - 1)
				img.set_pixel(px, py, col)
				if px > 0:
					var prev_t: float = float(px - 1) / float(w - 1) if w > 1 else 0.0
					var prev_si_f: float = prev_t * float(sample_count - 1)
					var prev_si0: int = clampi(int(prev_si_f), 0, sample_count - 1)
					var prev_si1: int = clampi(prev_si0 + 1, 0, sample_count - 1)
					var prev_frac: float = prev_si_f - float(prev_si0)
					var prev_val: float = samples[prev_si0] * (1.0 - prev_frac) + samples[prev_si1] * prev_frac
					var prev_norm: float = clampf((prev_val - min_v) / (max_v - min_v), 0.0, 1.0)
					var prev_py: int = clampi(h - 1 - int(prev_norm * float(h - 1)), 0, h - 1)
					var y_min: int = mini(prev_py, py)
					var y_max: int = maxi(prev_py, py)
					for y in range(y_min, y_max + 1):
						img.set_pixel(px, clampi(y, 0, h - 1), col)
		else:
			# More samples than pixels — rolling window, last W samples.
			var start_idx: int = sample_count - w
			for px in range(w):
				var si: int = start_idx + px
				var val: float = samples[si]
				var norm: float = clampf((val - min_v) / (max_v - min_v), 0.0, 1.0)
				var py: int = clampi(h - 1 - int(norm * float(h - 1)), 0, h - 1)
				img.set_pixel(px, py, col)
				if px > 0:
					var prev_val: float = samples[si - 1]
					var prev_norm: float = clampf((prev_val - min_v) / (max_v - min_v), 0.0, 1.0)
					var prev_py: int = clampi(h - 1 - int(prev_norm * float(h - 1)), 0, h - 1)
					var y_min: int = mini(prev_py, py)
					var y_max: int = maxi(prev_py, py)
					for y in range(y_min, y_max + 1):
						img.set_pixel(px, clampi(y, 0, h - 1), col)

	return img



# ═══════════════════════════════════════════════════════════════════════════════
# VOL — Extract volume slices / MIP to CPU Image
# ═══════════════════════════════════════════════════════════════════════════════

## Extracts an XY slice at fixed Z from raw 3D texture data.
static func extract_vol_slice_xy(raw: PackedByteArray, res: Vector3i, bpv: int,
		z: int, fmt: int) -> Image:
	var img := Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)
	for y in range(res.y):
		for x in range(res.x):
			var offset: int = ((z * res.y + y) * res.x + x) * bpv
			var val: float = _read_voxel_value(raw, offset, fmt)
			img.set_pixel(x, y, _density_to_color(val))
	return img


## Extracts an XZ slice at fixed Y.
static func extract_vol_slice_xz(raw: PackedByteArray, res: Vector3i, bpv: int,
		y: int, fmt: int) -> Image:
	var img := Image.create(res.x, res.z, false, Image.FORMAT_RGBA8)
	for z in range(res.z):
		for x in range(res.x):
			var offset: int = ((z * res.y + y) * res.x + x) * bpv
			var val: float = _read_voxel_value(raw, offset, fmt)
			img.set_pixel(x, z, _density_to_color(val))
	return img


## Extracts a YZ slice at fixed X.
static func extract_vol_slice_yz(raw: PackedByteArray, res: Vector3i, bpv: int,
		x: int, fmt: int) -> Image:
	var img := Image.create(res.y, res.z, false, Image.FORMAT_RGBA8)
	for z in range(res.z):
		for yy in range(res.y):
			var offset: int = ((z * res.y + yy) * res.x + x) * bpv
			var val: float = _read_voxel_value(raw, offset, fmt)
			img.set_pixel(yy, z, _density_to_color(val))
	return img


## Maximum Intensity Projection: max density across Z for each (x, y).
static func compute_vol_mip(raw: PackedByteArray, res: Vector3i, bpv: int,
		fmt: int) -> Image:
	var img := Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)
	for y in range(res.y):
		for x in range(res.x):
			var max_val: float = 0.0
			for z in range(res.z):
				var offset: int = ((z * res.y + y) * res.x + x) * bpv
				var val: float = _read_voxel_value(raw, offset, fmt)
				if val > max_val:
					max_val = val
			img.set_pixel(x, y, _density_to_color(max_val))
	return img


## Renders volume data as a composite image: 3 orthogonal slices tiled in a 2×2
## grid (XY top-left, XZ top-right, YZ bottom-left) with optional MIP bottom-right.
## Returns a single RGBA8 Image.
static func render_vol_composite(vd: GNVolumeData, size: Vector2i,
		slice_pos: float = 0.5, show_mip: bool = false) -> Image:
	var w: int = maxi(size.x, 1)
	var h: int = maxi(size.y, 1)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.06, 0.06, 0.08))

	var ctx := GNGpuContext.get_context()
	if ctx.rd == null or not vd.rd_texture.is_valid():
		return img

	var raw: PackedByteArray = ctx.rd.texture_get_data(vd.rd_texture, 0)
	var res: Vector3i = vd.resolution
	var bpv: int = vd.bytes_per_voxel()

	var slice_z: int = clampi(int(slice_pos * (res.z - 1)), 0, res.z - 1)
	var slice_y: int = clampi(int(slice_pos * (res.y - 1)), 0, res.y - 1)
	var slice_x: int = clampi(int(slice_pos * (res.x - 1)), 0, res.x - 1)

	var xy_img := extract_vol_slice_xy(raw, res, bpv, slice_z, vd.data_format)
	var xz_img := extract_vol_slice_xz(raw, res, bpv, slice_y, vd.data_format)
	var yz_img := extract_vol_slice_yz(raw, res, bpv, slice_x, vd.data_format)

	# Tile into 2×2 grid
	var half_w: int = w / 2
	var half_h: int = h / 2
	_blit_scaled(img, xy_img, 0, 0, half_w, half_h)
	_blit_scaled(img, xz_img, half_w, 0, w - half_w, half_h)
	_blit_scaled(img, yz_img, 0, half_h, half_w, h - half_h)

	if show_mip:
		var mip_img := compute_vol_mip(raw, res, bpv, vd.data_format)
		_blit_scaled(img, mip_img, half_w, half_h, w - half_w, h - half_h)

	return img


# ── VOL GPU composite (zero-copy) ───────────────────────────────────────────

static var _vol_output_tex_rid: RID = RID()
static var _vol_output_tex2d_rd: Texture2DRD = null
static var _vol_prev_res: Vector2i = Vector2i.ZERO
static var _vol_sampler: RID = RID()

## Renders volume data as a 2×2 composite via compute shader → Texture2DRD.
## Returns a Texture2DRD wrapping the GPU output, or null on failure.
static func render_vol_gpu(vd: GNVolumeData, size: Vector2i,
		slice_pos: float = 0.5, show_mip: bool = false) -> Texture2DRD:
	var ctx := GNGpuContext.get_context()
	if ctx == null or ctx.rd == null or not vd.rd_texture.is_valid():
		return null

	var w: int = maxi(size.x, 1)
	var h: int = maxi(size.y, 1)
	var res := Vector2i(w, h)
	var mrd := ctx.rd

	# Reallocate output texture if resolution changed.
	if res != _vol_prev_res:
		_free_vol_textures(mrd)
		_vol_output_tex_rid = ctx.create_texture_2d(w, h)
		_vol_prev_res = res

	# Ensure sampler exists.
	if not _vol_sampler.is_valid():
		_vol_sampler = ctx.create_linear_sampler()

	# Clear background.
	var bg_img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	bg_img.fill(Color(0.06, 0.06, 0.08))
	mrd.texture_update(_vol_output_tex_rid, 0, bg_img.get_data())

	# Push constants (32 bytes).
	var pc := PackedByteArray()
	pc.resize(32)
	pc.encode_s32(0, w)
	pc.encode_s32(4, h)
	pc.encode_s32(8, vd.resolution.x)
	pc.encode_s32(12, vd.resolution.y)
	pc.encode_s32(16, vd.resolution.z)
	pc.encode_float(20, clampf(slice_pos, 0.0, 1.0))
	pc.encode_s32(24, 1 if show_mip else 0)
	pc.encode_s32(28, vd.resolution.z)  # mip_steps = volume depth

	var shader: RID = ctx.get_shader(
		"res://addons/gonodes/shaders/vol/vol_viewer_composite.glsl")
	if not shader.is_valid():
		return null

	var us: RID = mrd.uniform_set_create([
		ctx.uniform_sampler(0, _vol_sampler, vd.rd_texture),
		ctx.uniform_image(1, _vol_output_tex_rid),
	], shader, 0)

	var wg_x: int = ceili(float(w) / 8.0)
	var wg_y: int = ceili(float(h) / 8.0)
	ctx.dispatch(shader, us, wg_x, wg_y, 1, pc)
	mrd.free_rid(us)

	if _vol_output_tex2d_rd == null:
		_vol_output_tex2d_rd = Texture2DRD.new()
	_vol_output_tex2d_rd.texture_rd_rid = _vol_output_tex_rid
	return _vol_output_tex2d_rd


static func _free_vol_textures(mrd: RenderingDevice) -> void:
	if _vol_output_tex2d_rd != null:
		_vol_output_tex2d_rd.texture_rd_rid = RID()
	if _vol_output_tex_rid.is_valid() and mrd != null:
		mrd.free_rid(_vol_output_tex_rid)
	_vol_output_tex_rid = RID()


# ═══════════════════════════════════════════════════════════════════════════════
# Internals
# ═══════════════════════════════════════════════════════════════════════════════

## Reads a single float from raw volume data at a byte offset.
static func _read_voxel_value(raw: PackedByteArray, offset: int, fmt: int) -> float:
	if offset + 4 > raw.size():
		return 0.0
	match fmt:
		RenderingDevice.DATA_FORMAT_R32_SFLOAT:
			return raw.decode_float(offset)
		RenderingDevice.DATA_FORMAT_R16_SFLOAT:
			return raw.decode_half(offset)
		RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT:
			return raw.decode_float(offset)
		RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT:
			return raw.decode_half(offset)
	return raw.decode_float(offset)


## Maps a density (0..1) to grayscale.
static func _density_to_color(val: float) -> Color:
	var v: float = clampf(val, 0.0, 1.0)
	return Color(v, v, v, 1.0)


## Creates small XYZ axis lines (unit length): X=red, Y=green, Z=blue.
## Returns the root Node3D.  Caller scales via [method update_gizmo_scale].
static func _create_axis_gizmo() -> Node3D:
	var root := Node3D.new()
	root.name = "AxisGizmo"

	var axes := [
		{"dir": Vector3(1, 0, 0), "color": Color.RED},
		{"dir": Vector3(0, 1, 0), "color": Color.GREEN},
		{"dir": Vector3(0, 0, 1), "color": Color.BLUE},
	]
	for axis in axes:
		var im := ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		im.surface_set_color(axis["color"])
		im.surface_add_vertex(Vector3.ZERO)
		im.surface_set_color(axis["color"])
		im.surface_add_vertex(axis["dir"])
		im.surface_end()
		var mi := MeshInstance3D.new()
		mi.mesh = im
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.no_depth_test = true
		mat.render_priority = 10
		mi.material_override = mat
		root.add_child(mi)

	return root


## Nearest-neighbor blit of [param src] into a region of [param dst].
static func _blit_scaled(dst: Image, src: Image, dx: int, dy: int,
		dw: int, dh: int) -> void:
	var sw: int = src.get_width()
	var sh: int = src.get_height()
	if sw == 0 or sh == 0 or dw == 0 or dh == 0:
		return
	for y in range(dh):
		var sy: int = clampi(y * sh / dh, 0, sh - 1)
		for x in range(dw):
			var sx: int = clampi(x * sw / dw, 0, sw - 1)
			var px: int = dx + x
			var py: int = dy + y
			if px < dst.get_width() and py < dst.get_height():
				dst.set_pixel(px, py, src.get_pixel(sx, sy))


# ═════════════════════════════════════════════════════════════════════════════
# Shared geo viewer provider (UI registers; operators call helpers only)
# ═════════════════════════════════════════════════════════════════════════════

static var _geo_viewer_provider: Object = null


## Returns the registered geo viewer provider, or null when none.
static func geo_viewer_provider() -> Object:
	return _geo_viewer_provider


## Registers the UI-owned geo viewer scene provider.
static func register_geo_viewer(provider: Object) -> void:
	_geo_viewer_provider = provider


## Clears the registered provider (tests only).
static func clear_geo_viewer() -> void:
	_geo_viewer_provider = null


## Ensures the shared geo viewer scene exists; no-op when unregistered.
static func ensure_shared_geo_viewer() -> void:
	if _geo_viewer_provider != null:
		_geo_viewer_provider.call("ensure_scene")


## Re-parents shared geo viewer nodes into [param vp]; no-op when unregistered.
static func reparent_shared_geo_viewer(vp: SubViewport) -> void:
	if _geo_viewer_provider != null:
		_geo_viewer_provider.call("reparent_scene", vp)


## Returns the shared mesh instance, or null when no provider is registered.
static func shared_geo_mesh() -> MeshInstance3D:
	if _geo_viewer_provider == null:
		return null
	return _geo_viewer_provider.call("shared_mesh") as MeshInstance3D


## Returns the shared orbit camera, or null when no provider is registered.
static func shared_geo_camera() -> Camera3D:
	if _geo_viewer_provider == null:
		return null
	return _geo_viewer_provider.call("shared_camera") as Camera3D


## Returns the shared axis gizmo root, or null when no provider is registered.
static func shared_geo_gizmo() -> Node3D:
	if _geo_viewer_provider == null:
		return null
	return _geo_viewer_provider.call("shared_gizmo") as Node3D


# ═════════════════════════════════════════════════════════════════════════════
# Shared 3D Scene Helpers
# ═════════════════════════════════════════════════════════════════════════════

## Creates the standard 3D viewer scene nodes shared by SOP, POP, and MAT renderers.
## Returns a Dictionary: {camera, light, env_node, gizmo}.
## [param bg_color] sets the environment background tint.
static func create_3d_viewer_scene(bg_color: Color = Color(0.1, 0.1, 0.12),
		ambient_color: Color = Color(0.2, 0.2, 0.25)) -> Dictionary:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 45.0

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)

	var gizmo := _create_axis_gizmo()

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg_color
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = 0.5
	var env_node := WorldEnvironment.new()
	env_node.environment = env

	return {"camera": camera, "light": light, "env_node": env_node, "gizmo": gizmo}


## Re-parents an array of scene nodes into a SubViewport if not already there.
static func reparent_viewer_nodes(nodes: Array, vp: SubViewport) -> void:
	for node in nodes:
		if node.get_parent() != vp:
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			vp.add_child(node)


## Handles standard orbit camera input (left-drag to orbit, scroll to zoom).
## Returns true if the event was consumed.
static func handle_orbit_input(event: InputEvent, viewer) -> bool:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			viewer.orbit_dragging = mb.pressed
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			viewer.orbit_distance = maxf(viewer.orbit_distance * 0.9, 0.5)
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			viewer.orbit_distance = minf(viewer.orbit_distance * 1.1, 50.0)
			return true
	if event is InputEventMouseMotion and viewer.orbit_dragging:
		var mm: InputEventMouseMotion = event
		viewer.orbit_yaw = fmod(viewer.orbit_yaw + mm.relative.x * 0.5, 360.0)
		viewer.orbit_pitch = clampf(viewer.orbit_pitch - mm.relative.y * 0.5, -89.0, 89.0)
		return true
	return false
