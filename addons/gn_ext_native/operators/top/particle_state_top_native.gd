class_name ParticleStateTOPNative
extends GNNode
## Native-accelerated POP→TOP visualization — delegates to GNNativeParticleStateTop (C++).

var _processor: RefCounted = null
var _cached_texture: GNTextureData = null


func _init() -> void:
	family = GNFamily.Type.TOP
	node_type = "particle_state_native"
	node_description = "Visualize particle attributes as a 2D texture — native C++ accelerated."
	if ClassDB.class_exists("GNNativeParticleStateTop"):
		_processor = ClassDB.instantiate("GNNativeParticleStateTop")


func initialize(p_id: String) -> void:
	family = GNFamily.Type.TOP
	super.initialize(p_id)


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle data input")
	add_output("out", GNFamily.Type.TOP, "Particle state texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("width", 256, 64, 4096, "Width", ""))
	add_parameter(GNParameter.create_string("attribute", "pos", "Attribute", ""))
	add_parameter(GNParameter.create_float("scale", 1.0, 0.001, 1000.0, 0.1, "Scale", ""))


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

	var ctx := GNGpuContext.get_context()
	var raw: PackedByteArray = ctx.read_buffer(pd.rd_buffer, count * pd.stride)
	var off: int = pd.get_attrib_offset(attrib_name)
	var atype: String = pd.get_attrib_type(attrib_name)

	if raw.is_empty() or not _processor:
		return null

	var img: Image = _processor.process(raw, count, pd.stride, off, atype, width, vis_scale)
	if img == null:
		return null

	var tex := ImageTexture.create_from_image(img)
	if _cached_texture == null:
		_cached_texture = GNTextureData.new()
	_cached_texture.texture = tex
	_cached_texture.resolution = Vector2i(width, ceili(float(count) / float(width)))
	return _cached_texture
