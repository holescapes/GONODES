class_name PointCloudRenderTOP
extends GNTopBase
## Renders POP particle data or SOP point positions as a 2D point-cloud image.
##
## GPU path: dispatches a compute shader that reads the particle SSBO and
## splats circular discs with perspective projection and depth testing.
## CPU fallback: reads positions, projects, and draws to an Image.

var _out_tex: GNTextureData = null


func _init() -> void:
	node_type = "point_cloud_render"
	time_dependent = true

func _init_ports() -> void:
	add_input("pop", GNFamily.Type.POP, true, "Particle data to render", "Particles")
	add_output("out", GNFamily.Type.TOP, "Rendered point cloud image")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("width", 512, 64, 4096,
		"Width", "Output image width"))
	add_parameter(GNParameter.create_int("height", 512, 64, 4096,
		"Height", "Output image height"))
	add_parameter(GNParameter.create_float("point_size", 4.0, 0.5, 64.0, 0.5,
		"Point Size", "Base splat radius in pixels"))
	add_parameter(GNParameter.create_float("size_attenuation", 1.0, 0.0, 1.0, 0.01,
		"Size Attenuation", "0 = constant, 1 = full perspective scaling"))
	add_parameter(GNParameter.create_float("alpha", 1.0, 0.0, 1.0, 0.01,
		"Alpha", "Global opacity multiplier"))
	add_parameter(GNParameter.create_bool("use_particle_color", true,
		"Particle Color", "Use per-particle color (false = uniform color)"))
	add_parameter(GNParameter.create_color("color", Color.WHITE,
		"Color", "Uniform color when not using particle color"))
	add_parameter(GNParameter.create_color("bg_color", Color(0.0, 0.0, 0.0, 0.0),
		"Background", "Background color (default transparent)"))
	# Camera
	add_parameter(GNParameter.create_float("cam_dist", 3.0, 0.1, 50.0, 0.1,
		"Camera Distance", "Distance from origin"))
	add_parameter(GNParameter.create_float("cam_yaw", 0.0, -180.0, 180.0, 1.0,
		"Camera Yaw", "Horizontal rotation (degrees)"))
	add_parameter(GNParameter.create_float("cam_pitch", 20.0, -89.0, 89.0, 1.0,
		"Camera Pitch", "Vertical rotation (degrees)"))
	add_parameter(GNParameter.create_float("fov", 60.0, 10.0, 120.0, 1.0,
		"FOV", "Field of view (degrees)"))
	add_parameter(GNParameter.create_float("near_clip", 0.01, 0.001, 1.0, 0.01,
		"Near Clip", "Near clipping distance"))
	add_parameter(GNParameter.create_float("far_clip", 100.0, 1.0, 1000.0, 1.0,
		"Far Clip", "Far clipping distance"))


func _cook(inputs: Array[GNData]) -> GNData:
	var pd: GNParticleData = _get_input_pop(inputs, 0)
	if pd == null or not pd.has_particles():
		return null

	var ctx := GNGpuContext.get_context()
	if ctx == null or ctx.rd == null:
		return _cook_cpu(inputs)

	var w: int = get_param_value("width")
	var h: int = get_param_value("height")
	var pt_size: float = get_param_value("point_size")
	var sz_atten: float = get_param_value("size_attenuation")
	var alpha_val: float = get_param_value("alpha")
	var use_pcol: bool = get_param_value("use_particle_color")
	var col: Color = get_param_value("color")
	var bg: Color = get_param_value("bg_color")

	var dist: float = get_param_value("cam_dist")
	var yaw: float = deg_to_rad(get_param_value("cam_yaw"))
	var pitch: float = deg_to_rad(get_param_value("cam_pitch"))
	var fov_rad: float = deg_to_rad(get_param_value("fov"))
	var near_c: float = get_param_value("near_clip")
	var far_c: float = get_param_value("far_clip")

	var eye := Vector3(
		dist * cos(pitch) * sin(yaw),
		dist * sin(pitch),
		dist * cos(pitch) * cos(yaw))
	var fwd := (-eye).normalized()
	var world_up := Vector3.UP
	var right := fwd.cross(world_up).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	var up := right.cross(fwd).normalized()

	# Create output color texture (initialize with bg color)
	var bg_img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	bg_img.fill(bg)
	var out_tex_rid: RID = ctx.upload_image(bg_img)

	# Create depth buffer (R32F, initialized to 1.0 = far)
	var depth_img := Image.create(w, h, false, Image.FORMAT_RF)
	depth_img.fill(Color(1.0, 0.0, 0.0))
	var depth_rid: RID = ctx.upload_image(depth_img)

	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/top/point_cloud_render.glsl")
	if not shader.is_valid():
		ctx.rd.free_rid(out_tex_rid)
		ctx.rd.free_rid(depth_rid)
		return null

	# Push constants: 80 bytes
	var pc := PackedByteArray()
	pc.resize(80)
	pc.encode_s32(0, w)
	pc.encode_s32(4, h)
	pc.encode_s32(8, pd.particle_count)
	pc.encode_float(12, pt_size)
	pc.encode_float(16, eye.x); pc.encode_float(20, eye.y); pc.encode_float(24, eye.z)
	pc.encode_float(28, fwd.x); pc.encode_float(32, fwd.y); pc.encode_float(36, fwd.z)
	pc.encode_float(40, right.x); pc.encode_float(44, right.y); pc.encode_float(48, right.z)
	pc.encode_float(52, up.x); pc.encode_float(56, up.y); pc.encode_float(60, up.z)
	pc.encode_float(64, fov_rad)
	# Repack to fit: near, far, size_atten, alpha, use_pcol, col_rgb
	# Need more space — extend to 112 bytes (multiple of 16)
	pc.resize(112)
	pc.encode_float(68, near_c)
	pc.encode_float(72, far_c)
	pc.encode_float(76, sz_atten)
	pc.encode_float(80, alpha_val)
	pc.encode_s32(84, 1 if use_pcol else 0)
	pc.encode_float(88, col.r)
	pc.encode_float(92, col.g)
	pc.encode_float(96, col.b)
	# Pad to 112
	pc.encode_float(100, 0.0)
	pc.encode_float(104, 0.0)
	pc.encode_float(108, 0.0)

	var us: RID = ctx.rd.uniform_set_create([
		ctx.uniform_buffer(0, pd.rd_buffer),
		ctx.uniform_image(1, out_tex_rid),
		ctx.uniform_image(2, depth_rid),
	], shader, 0)

	var wg_x: int = ceili(float(pd.particle_count) / 64.0)
	ctx.dispatch(shader, us, wg_x, 1, 1, pc)
	ctx.rd.free_rid(us)
	ctx.rd.free_rid(depth_rid)

	var result_img: Image = ctx.download_image(out_tex_rid, w, h)
	ctx.rd.free_rid(out_tex_rid)

	var itex := ImageTexture.create_from_image(result_img)
	if _out_tex == null:
		_out_tex = GNTextureData.new()
	_out_tex.texture = itex
	_out_tex.resolution = Vector2i(w, h)
	_out_tex.format = Image.FORMAT_RGBA8
	return _out_tex


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var pd: GNParticleData = _get_input_pop(inputs, 0)
	if pd == null or not pd.has_particles():
		return null

	var w: int = get_param_value("width")
	var h: int = get_param_value("height")
	var pt_size: float = get_param_value("point_size")
	var sz_atten: float = get_param_value("size_attenuation")
	var alpha_val: float = get_param_value("alpha")
	var use_pcol: bool = get_param_value("use_particle_color")
	var col: Color = get_param_value("color")
	var bg: Color = get_param_value("bg_color")

	var dist: float = get_param_value("cam_dist")
	var yaw: float = deg_to_rad(get_param_value("cam_yaw"))
	var pitch: float = deg_to_rad(get_param_value("cam_pitch"))
	var fov_rad: float = deg_to_rad(get_param_value("fov"))
	var near_c: float = get_param_value("near_clip")
	var far_c: float = get_param_value("far_clip")

	var eye := Vector3(
		dist * cos(pitch) * sin(yaw),
		dist * sin(pitch),
		dist * cos(pitch) * cos(yaw))
	var fwd := (-eye).normalized()
	var world_up := Vector3.UP
	var right := fwd.cross(world_up).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	var up := right.cross(fwd).normalized()

	var half_fov: float = tan(fov_rad * 0.5)
	var aspect: float = float(w) / float(h)

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg)

	# Depth buffer (CPU)
	var depth_buf := PackedFloat32Array()
	depth_buf.resize(w * h)
	depth_buf.fill(1.0)

	var positions: PackedVector3Array = pd.read_positions()
	var n: int = positions.size()

	for i in range(n):
		var pos: Vector3 = positions[i]
		var rel: Vector3 = pos - eye
		var depth: float = rel.dot(fwd)
		if depth < near_c or depth > far_c:
			continue

		var sx: float = rel.dot(right)
		var sy: float = rel.dot(up)

		var ndc_x: float = sx / (depth * half_fov * aspect)
		var ndc_y: float = sy / (depth * half_fov)

		var px: float = (ndc_x * 0.5 + 0.5) * float(w)
		var py: float = ((-ndc_y) * 0.5 + 0.5) * float(h)

		var radius: float = pt_size * 0.01  # simplified for CPU
		radius = lerpf(pt_size, pt_size / maxf(depth, 0.001) * float(h) * 0.5 / half_fov, sz_atten)
		var r: int = ceili(radius)
		if r < 1:
			r = 1

		var pcol: Color = col
		if use_pcol and pd.is_cpu and pd.cpu_colors.size() > i:
			pcol = pd.cpu_colors[i]

		var norm_depth: float = (depth - near_c) / (far_c - near_c)

		var cx: int = int(px)
		var cy: int = int(py)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var ix: int = cx + dx
				var iy: int = cy + dy
				if ix < 0 or ix >= w or iy < 0 or iy >= h:
					continue
				var dist2: float = float(dx * dx + dy * dy)
				if dist2 > radius * radius:
					continue
				var falloff: float = 1.0 - dist2 / (radius * radius)
				var buf_idx: int = iy * w + ix
				if norm_depth < depth_buf[buf_idx]:
					depth_buf[buf_idx] = norm_depth
					img.set_pixel(ix, iy, Color(
						pcol.r * falloff,
						pcol.g * falloff,
						pcol.b * falloff,
						alpha_val * falloff))

	if _out_tex == null:
		_out_tex = GNTextureData.new()
	_out_tex.texture = ImageTexture.create_from_image(img)
	_out_tex.resolution = Vector2i(w, h)
	_out_tex.format = Image.FORMAT_RGBA8
	return _out_tex


func _get_input_pop(inputs: Array[GNData], port: int = 0) -> GNParticleData:
	if port < inputs.size() and inputs[port] is GNParticleData:
		return inputs[port] as GNParticleData
	return null
