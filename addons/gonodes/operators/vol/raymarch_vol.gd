class_name RaymarchVOL
extends GNVolBase
## Volume ray-march renderer → 2D image (TOP output).
## Dispatches a compute shader that front-to-back composites the density field.

var _out_tex: GNTextureData = null


func _init() -> void:
	super._init()
	node_type = "raymarch"


func _init_ports() -> void:
	add_input("vol", GNFamily.Type.VOL, true, "Density volume to render", "Volume")
	add_output("image", GNFamily.Type.TOP, "Rendered 2D image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("width", 512, 64, 2048, "Width", "Output image width"))
	add_parameter(GNParameter.create_int("height", 512, 64, 2048, "Height", "Output image height"))
	add_parameter(GNParameter.create_int("max_steps", 128,
		16, 512, "Max Steps", "Maximum ray-march steps"))
	add_parameter(GNParameter.create_float("step_size", 0.01,
		0.001, 0.1, 0.001, "Step Size", "Distance per step"))
	add_parameter(GNParameter.create_float("density_scale", 5.0,
		0.1, 50.0, 0.1, "Density Scale", "Multiplier for density sampling"))
	add_parameter(GNParameter.create_float("absorption", 10.0,
		0.1, 100.0, 0.1, "Absorption", "Beer-Lambert absorption coefficient"))
	# Camera
	add_parameter(GNParameter.create_float("cam_dist", 1.5,
		0.1, 10.0, 0.1, "Camera Distance", "Distance from origin"))
	add_parameter(GNParameter.create_float("cam_yaw", 0.0,
		-180.0, 180.0, 1.0, "Camera Yaw", "Horizontal rotation (degrees)"))
	add_parameter(GNParameter.create_float("cam_pitch", 20.0,
		-89.0, 89.0, 1.0, "Camera Pitch", "Vertical rotation (degrees)"))
	add_parameter(GNParameter.create_float("fov", 60.0,
		10.0, 120.0, 1.0, "FOV", "Field of view (degrees)"))
	# Lighting
	add_parameter(GNParameter.create_float("light_yaw", 45.0,
		-180.0, 180.0, 1.0, "Light Yaw", "Light direction yaw (degrees)"))
	add_parameter(GNParameter.create_float("light_pitch", 60.0,
		-89.0, 89.0, 1.0, "Light Pitch", "Light direction pitch (degrees)"))
	add_parameter(GNParameter.create_color("light_color", Color(1.0, 0.95, 0.8),
		"Light Color", "Directional light color"))
	add_parameter(GNParameter.create_float("light_intensity", 2.0,
		0.0, 20.0, 0.1, "Light Intensity", "Directional light brightness"))
	add_parameter(GNParameter.create_float("hg_g", 0.3,
		-0.99, 0.99, 0.01, "Scattering (HG g)", "Henyey-Greenstein asymmetry: >0 forward, <0 back"))
	add_parameter(GNParameter.create_int("shadow_steps", 32,
		0, 128, "Shadow Steps", "Shadow ray march steps (0 = no shadows)"))
	add_parameter(GNParameter.create_float("ambient", 0.15,
		0.0, 1.0, 0.01, "Ambient", "Ambient light contribution"))
	add_parameter(GNParameter.create_color("emit_color", Color(1.0, 0.85, 0.6),
		"Emission Color", "Self-emission color (density-proportional glow)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var vol: GNVolumeData = _get_input_vol(inputs, 0)
	if vol == null or not vol.has_volume():
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	var w: int = get_param_value("width")
	var h: int = get_param_value("height")
	var max_steps: int = get_param_value("max_steps")
	var step: float = get_param_value("step_size")
	var dscale: float = get_param_value("density_scale")
	var absorb: float = get_param_value("absorption")
	var dist: float = get_param_value("cam_dist")
	var yaw_deg: float = get_param_value("cam_yaw")
	var pitch_deg: float = get_param_value("cam_pitch")
	var fov_deg: float = get_param_value("fov")

	# Compute camera vectors
	var yaw: float = deg_to_rad(yaw_deg)
	var pitch: float = deg_to_rad(pitch_deg)
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
	var fov_rad: float = deg_to_rad(fov_deg)

	# Lighting parameters
	var l_yaw: float = deg_to_rad(get_param_value("light_yaw"))
	var l_pitch: float = deg_to_rad(get_param_value("light_pitch"))
	var light_dir := Vector3(
		cos(l_pitch) * sin(l_yaw),
		sin(l_pitch),
		cos(l_pitch) * cos(l_yaw)).normalized()
	var light_col: Color = get_param_value("light_color")
	var light_int: float = get_param_value("light_intensity")
	var hg_g: float = get_param_value("hg_g")
	var shadow_st: int = get_param_value("shadow_steps")
	var amb: float = get_param_value("ambient")
	var emit_col: Color = get_param_value("emit_color")

	# Create 2D output texture on RD
	var tf := RDTextureFormat.new()
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	tf.width = w
	tf.height = h
	tf.depth = 1
	tf.mipmaps = 1
	tf.array_layers = 1
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT)
	var out_tex: RID = ctx.rd.texture_create(tf, RDTextureView.new())

	var shader: RID = ctx.get_shader("res://addons/gonodes/shaders/vol/raymarch_vol.glsl")
	if not shader.is_valid():
		ctx.rd.free_rid(out_tex)
		return null

	var sampler: RID = ctx.create_linear_sampler()

	# Push constants: camera + lighting (40 fields → 160 bytes)
	var pc := PackedByteArray()
	pc.resize(160)
	pc.encode_s32(0, w)
	pc.encode_s32(4, h)
	pc.encode_s32(8, vol.resolution.x)
	pc.encode_s32(12, vol.resolution.y)
	pc.encode_s32(16, vol.resolution.z)
	pc.encode_s32(20, max_steps)
	pc.encode_float(24, step)
	pc.encode_float(28, dscale)
	pc.encode_float(32, eye.x)
	pc.encode_float(36, eye.y)
	pc.encode_float(40, eye.z)
	pc.encode_float(44, fwd.x)
	pc.encode_float(48, fwd.y)
	pc.encode_float(52, fwd.z)
	pc.encode_float(56, right.x)
	pc.encode_float(60, right.y)
	pc.encode_float(64, right.z)
	pc.encode_float(68, up.x)
	pc.encode_float(72, up.y)
	pc.encode_float(76, up.z)
	pc.encode_float(80, fov_rad)
	pc.encode_float(84, absorb)
	# Lighting fields (offset 88)
	pc.encode_float(88, light_dir.x)
	pc.encode_float(92, light_dir.y)
	pc.encode_float(96, light_dir.z)
	pc.encode_float(100, light_col.r)
	pc.encode_float(104, light_col.g)
	pc.encode_float(108, light_col.b)
	pc.encode_float(112, light_int)
	pc.encode_float(116, hg_g)
	pc.encode_s32(120, shadow_st)
	pc.encode_float(124, amb)
	pc.encode_float(128, emit_col.r)
	pc.encode_float(132, emit_col.g)
	pc.encode_float(136, emit_col.b)
	# Pad to 160 bytes (next multiple of 16 after 140)
	pc.encode_float(140, 0.0)
	pc.encode_float(144, 0.0)
	pc.encode_float(148, 0.0)
	pc.encode_float(152, 0.0)
	pc.encode_float(156, 0.0)

	var us: RID = ctx.rd.uniform_set_create([
		ctx.uniform_sampler(0, sampler, vol.rd_texture),
		ctx.uniform_image(1, out_tex),
	], shader, 0)

	var wg_x: int = ceili(float(w) / 8.0)
	var wg_y: int = ceili(float(h) / 8.0)
	ctx.dispatch(shader, us, wg_x, wg_y, 1, pc)
	ctx.rd.free_rid(us)
	ctx.rd.free_rid(sampler)

	# Read back 2D texture → Image → ImageTexture → GNTextureData
	var bytes: PackedByteArray = ctx.rd.texture_get_data(out_tex, 0)
	ctx.rd.free_rid(out_tex)

	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)
	var itex := ImageTexture.create_from_image(img)

	if _out_tex == null:
		_out_tex = GNTextureData.new()
	_out_tex.texture = itex
	_out_tex.resolution = Vector2i(w, h)
	_out_tex.format = Image.FORMAT_RGBA8
	return _out_tex


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	var vol := _get_input_vol_cpu(inputs, 0)
	if vol == null or not vol.has_volume():
		return null

	var w: int = get_param_value("width")
	var h: int = get_param_value("height")
	var max_steps: int = get_param_value("max_steps")
	var step: float = get_param_value("step_size")
	var dscale: float = get_param_value("density_scale")
	var absorb: float = get_param_value("absorption")
	var dist: float = get_param_value("cam_dist")
	var yaw: float = deg_to_rad(get_param_value("cam_yaw"))
	var pitch: float = deg_to_rad(get_param_value("cam_pitch"))
	var fov_rad: float = deg_to_rad(get_param_value("fov"))

	# Lighting
	var l_yaw: float = deg_to_rad(get_param_value("light_yaw"))
	var l_pitch: float = deg_to_rad(get_param_value("light_pitch"))
	var light_dir := Vector3(
		cos(l_pitch) * sin(l_yaw),
		sin(l_pitch),
		cos(l_pitch) * cos(l_yaw)).normalized()
	var light_col: Color = get_param_value("light_color")
	var light_int: float = get_param_value("light_intensity")
	var amb: float = get_param_value("ambient")
	var emit_col: Color = get_param_value("emit_color")

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

	var res: Vector3i = vol.resolution
	var aspect: float = float(w) / float(h)
	var half_h: float = tan(fov_rad * 0.5)

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	for py in range(h):
		for px in range(w):
			var u: float = (float(px) + 0.5) / float(w) * 2.0 - 1.0
			var v: float = (float(py) + 0.5) / float(h) * 2.0 - 1.0
			var rd: Vector3 = (fwd + right * u * half_h * aspect + up * (-v) * half_h).normalized()

			# Ray-AABB intersection with unit cube [-0.5, 0.5]
			var t_near: float = 0.0
			var t_far: float = 1e10
			for axis in range(3):
				var orig: float = [eye.x, eye.y, eye.z][axis]
				var dir: float = [rd.x, rd.y, rd.z][axis]
				if absf(dir) < 1e-8:
					if orig < -0.5 or orig > 0.5:
						t_far = -1.0
						break
				else:
					var t0: float = (-0.5 - orig) / dir
					var t1: float = (0.5 - orig) / dir
					if t0 > t1:
						var tmp: float = t0
						t0 = t1
						t1 = tmp
					t_near = maxf(t_near, t0)
					t_far = minf(t_far, t1)

			if t_near >= t_far or t_far < 0.0:
				img.set_pixel(px, py, Color.BLACK)
				continue

			# Front-to-back compositing with lighting
			var transmittance: float = 1.0
			var color_r: float = 0.0
			var color_g: float = 0.0
			var color_b: float = 0.0
			var t_cur: float = maxf(t_near, 0.0)

			for _s in range(max_steps):
				if t_cur > t_far or transmittance < 0.01:
					break
				var pos: Vector3 = eye + rd * t_cur
				var uvw := Vector3(pos.x + 0.5, pos.y + 0.5, pos.z + 0.5)
				var density: float = _vol_sample_trilinear(vol.cpu_data, uvw, res) * dscale
				if density > 0.0:
					var alpha: float = 1.0 - exp(-absorb * density * step)
					# Simplified lighting for CPU: directional + ambient, no shadows
					var radiance_r: float = (light_col.r * light_int * (1.0 + amb) * density) + (emit_col.r * density)
					var radiance_g: float = (light_col.g * light_int * (1.0 + amb) * density) + (emit_col.g * density)
					var radiance_b: float = (light_col.b * light_int * (1.0 + amb) * density) + (emit_col.b * density)
					color_r += transmittance * alpha * radiance_r
					color_g += transmittance * alpha * radiance_g
					color_b += transmittance * alpha * radiance_b
					transmittance *= (1.0 - alpha)
				t_cur += step

			img.set_pixel(px, py, Color(
				clampf(color_r, 0.0, 1.0),
				clampf(color_g, 0.0, 1.0),
				clampf(color_b, 0.0, 1.0),
				1.0 - transmittance))

	if _out_tex == null:
		_out_tex = GNTextureData.new()
	_out_tex.texture = ImageTexture.create_from_image(img)
	_out_tex.resolution = Vector2i(w, h)
	_out_tex.format = Image.FORMAT_RGBA8
	return _out_tex
