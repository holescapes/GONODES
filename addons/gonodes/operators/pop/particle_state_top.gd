class_name ParticleStateTOP
extends GNNode
## Visualizes POP particle state as a 2D heatmap texture.
## Bridge: POP → TOP for TOP-chain visualization.

var _cached_texture: GNTextureData = null


func _init() -> void:
	family = GNFamily.Type.TOP
	node_type = "particle_state"
	node_description = "Visualize particle attributes as a 2D texture (POP→TOP bridge)."


func initialize(p_id: String) -> void:
	family = GNFamily.Type.TOP
	super.initialize(p_id)


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle data input")
	add_output("out", GNFamily.Type.TOP, "Particle state texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("width", 256,
		64, 4096, "Width", "Texture width (particles wrap across rows)"))
	add_parameter(GNParameter.create_string("attribute", "pos", "Attribute",
		"Particle attribute to visualize (pos, vel, color, age, pscale)"))
	add_parameter(GNParameter.create_float("scale", 1.0,
		0.001, 1000.0, 0.1, "Scale", "Value scale for visualization"))


func _cook(inputs: Array[GNData]) -> GNData:
	var pd: GNParticleData = null
	if inputs.size() > 0 and inputs[0] is GNParticleData:
		pd = inputs[0] as GNParticleData
	if pd == null or not pd.has_particles():
		return null

	var width: int = get_param_value("width")
	var attrib_name: String = get_param_value("attribute")
	var vis_scale: float = get_param_value("scale")
	var count: int = pd.particle_count
	var height: int = ceili(float(count) / float(width))

	# CPU readback of the full buffer
	var ctx := GNGpuContext.get_context()
	var raw: PackedByteArray = ctx.read_buffer(pd.rd_buffer, count * pd.stride)
	var off: int = pd.get_attrib_offset(attrib_name)
	if off < 0:
		return null

	var desc: GNParticleData.AttribDesc = pd.attribute_layout.get(attrib_name, null)
	if desc == null:
		return null

	# Build an Image
	var img := Image.create(width, height, false, Image.FORMAT_RGBAF)
	img.fill(Color.BLACK)

	for i in range(count):
		var px: int = i % width
		var py: int = i / width
		var base: int = i * pd.stride + off
		var col := Color.BLACK
		match desc.type:
			"float":
				var v: float = raw.decode_float(base) * vis_scale
				col = Color(v, v, v, 1.0)
			"vec2":
				col.r = raw.decode_float(base) * vis_scale
				col.g = raw.decode_float(base + 4) * vis_scale
			"vec3":
				col.r = raw.decode_float(base) * vis_scale
				col.g = raw.decode_float(base + 4) * vis_scale
				col.b = raw.decode_float(base + 8) * vis_scale
			"vec4":
				col.r = raw.decode_float(base) * vis_scale
				col.g = raw.decode_float(base + 4) * vis_scale
				col.b = raw.decode_float(base + 8) * vis_scale
				col.a = raw.decode_float(base + 12) * vis_scale
		img.set_pixel(px, py, col)

	if _cached_texture == null:
		_cached_texture = GNTextureData.new()
	_cached_texture.texture = ImageTexture.create_from_image(img)
	_cached_texture.resolution = Vector2i(width, height)
	return _cached_texture
