class_name GNViewerRenderer
extends RefCounted
## Shared rendering utilities for visualizing any GNData type as a 2D image.
##
## Used by both the docked/floating GNViewerPanel (interactive) and SnapshotTOP
## (headless rendering into a TOP texture).  This keeps all "data → image"
## conversion in one place: when new visualizations are added or improved here,
## both the viewer and SnapshotTOP benefit automatically.
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


## Builds a MultiMesh from GNParticleData and renders one frame.
## [param point_size] — base billboard size for each particle.
static func render_pop(vp: SubViewport, mmi: MultiMeshInstance3D,
		pd: GNParticleData, point_size: float = 0.02) -> bool:
	var ctx := GNGpuContext.get_context()
	if ctx.rd == null or not pd.rd_buffer.is_valid():
		return false

	var byte_count: int = pd.particle_count * pd.stride
	var raw: PackedByteArray = ctx.rd.buffer_get_data(pd.rd_buffer, 0, byte_count)

	# Build MultiMesh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = pd.particle_count

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	mm.mesh = quad

	var pos_off: int = pd.get_attrib_offset("pos")
	var color_off: int = pd.get_attrib_offset("color")
	var pscale_off: int = pd.get_attrib_offset("pscale")

	for i in range(pd.particle_count):
		var base: int = i * pd.stride
		var px: float = raw.decode_float(base + pos_off)
		var py: float = raw.decode_float(base + pos_off + 4)
		var pz: float = raw.decode_float(base + pos_off + 8)

		var ps: float = point_size
		if pscale_off >= 0:
			ps = raw.decode_float(base + pscale_off) * point_size

		var xform := Transform3D(Basis.IDENTITY.scaled(Vector3(ps, ps, ps)),
			Vector3(px, py, pz))
		mm.set_instance_transform(i, xform)

		if color_off >= 0:
			var cr: float = raw.decode_float(base + color_off)
			var cg: float = raw.decode_float(base + color_off + 4)
			var cb: float = raw.decode_float(base + color_off + 8)
			var ca: float = raw.decode_float(base + color_off + 12)
			mm.set_instance_color(i, Color(cr, cg, cb, ca))
		else:
			mm.set_instance_color(i, Color(0.2, 0.8, 0.8))

	mmi.multimesh = mm
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	return true


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
# CHOP — Render GNChannelData to CPU Image (waveform)
# ═══════════════════════════════════════════════════════════════════════════════

## Renders CHOP channel data as a waveform image (CPU-side).
## Returns a completed Image (RGBA8) suitable for ImageTexture upload.
##
## [param ch_data]    — source channel data.
## [param size]       — output image dimensions.
## [param bg_color]   — background fill.
## [param line_color] — base waveform line color (channels get hue offsets).
static func render_chop_waveform(ch_data: GNChannelData, size: Vector2i,
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

	# Compute global range with headroom
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

	# Draw each channel
	for ci in range(ch_count):
		var samples: PackedFloat32Array = ch_data.channels[ch_names[ci]]
		if samples.is_empty():
			continue

		var col: Color = line_color
		if ch_count > 1:
			col = Color.from_hsv(fmod(line_color.h + float(ci) / float(ch_count), 1.0),
				line_color.s, line_color.v, line_color.a)

		var sample_count: int = samples.size()
		for px in range(w):
			var t: float = float(px) / float(w - 1) if w > 1 else 0.0
			var si: float = t * float(sample_count - 1)
			var si0: int = clampi(int(si), 0, sample_count - 1)
			var si1: int = clampi(si0 + 1, 0, sample_count - 1)
			var frac: float = si - float(si0)
			var val: float = samples[si0] * (1.0 - frac) + samples[si1] * frac

			var norm: float = (val - min_v) / (max_v - min_v)
			norm = clampf(norm, 0.0, 1.0)
			var py: int = clampi(h - 1 - int(norm * float(h - 1)), 0, h - 1)
			img.set_pixel(px, py, col)

			# Connect to previous pixel vertically
			if px > 0:
				var prev_t: float = float(px - 1) / float(w - 1) if w > 1 else 0.0
				var prev_si: float = prev_t * float(sample_count - 1)
				var prev_si0: int = clampi(int(prev_si), 0, sample_count - 1)
				var prev_si1: int = clampi(prev_si0 + 1, 0, sample_count - 1)
				var prev_frac: float = prev_si - float(prev_si0)
				var prev_val: float = samples[prev_si0] * (1.0 - prev_frac) + samples[prev_si1] * prev_frac
				var prev_norm: float = clampf((prev_val - min_v) / (max_v - min_v), 0.0, 1.0)
				var prev_py: int = clampi(h - 1 - int(prev_norm * float(h - 1)), 0, h - 1)
				var y_min: int = mini(prev_py, py)
				var y_max: int = maxi(prev_py, py)
				for y in range(y_min, y_max + 1):
					img.set_pixel(px, clampi(y, 0, h - 1), col)

	return img


# ═══════════════════════════════════════════════════════════════════════════════
# DAT — Render GNTableData to CPU Image (simple text table)
# ═══════════════════════════════════════════════════════════════════════════════

## Renders table data as a simple text-on-image representation.
## Since Godot doesn't expose font rendering to Image easily, this draws a
## color-coded grid with cell values baked in via set_pixel patterns.
## For SnapshotTOP this provides a basic visual representation of the table.
static func render_dat_table(tbl: GNTableData, size: Vector2i,
		bg_color: Color = Color(0.06, 0.06, 0.08),
		cell_color: Color = Color(0.15, 0.15, 0.2),
		header_color: Color = Color(0.2, 0.2, 0.3)) -> Image:
	var w: int = maxi(size.x, 1)
	var h: int = maxi(size.y, 1)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg_color)

	if tbl == null or tbl.table.is_empty():
		return img

	var row_count: int = tbl.table.size()
	var col_count: int = 0
	for row in tbl.table:
		if row.size() > col_count:
			col_count = row.size()
	if col_count == 0:
		return img

	# Draw grid cells
	var cell_w: int = maxi(w / col_count, 1)
	var cell_h: int = maxi(h / row_count, 1)

	for r in range(row_count):
		for c in range(col_count):
			var x0: int = c * cell_w
			var y0: int = r * cell_h
			var x1: int = mini(x0 + cell_w - 1, w - 1)
			var y1: int = mini(y0 + cell_h - 1, h - 1)

			var fill: Color = header_color if (r == 0 and tbl.has_header) else cell_color

			# Fill cell
			for y in range(y0, y1 + 1):
				for x in range(x0, x1 + 1):
					img.set_pixel(x, y, fill)

			# Draw border (1px dark line on right and bottom edges)
			for y in range(y0, y1 + 1):
				if x1 < w:
					img.set_pixel(mini(x1, w - 1), y, bg_color)
			for x in range(x0, x1 + 1):
				if y1 < h:
					img.set_pixel(x, mini(y1, h - 1), bg_color)

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


# ═══════════════════════════════════════════════════════════════════════════════
# IMG — Upload Image to texture (trivial, but here for completeness)
# ═══════════════════════════════════════════════════════════════════════════════

## Returns a copy of the Image suitable for ImageTexture upload.
## This is essentially a pass-through — the Image is already CPU-side.
static func render_img(img_data: GNImageData) -> Image:
	if img_data == null or img_data.image == null:
		return null
	return img_data.image


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
