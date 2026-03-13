class_name RaymarchVOL
extends GNVolBase
## Volume ray-march renderer → 2D image (TOP output).
## Dispatches a compute shader that front-to-back composites the density field.

var _out_tex: GNTextureData = null


func _init() -> void:
	super._init()
	node_type = "raymarch"
	node_description = "Render a volume as a 2D image via GPU ray-marching."


func _init_ports() -> void:
	add_input("vol", GNFamily.Type.VOL, true, "Density volume to render")
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

	# Push constants: 21 floats + 5 ints (see shader)
	var pc := PackedByteArray()
	pc.resize(100)  # 25 * 4 bytes
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
	# Pad to multiple of 16
	pc.encode_float(88, 0.0)
	pc.encode_float(92, 0.0)
	pc.encode_float(96, 0.0)

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
