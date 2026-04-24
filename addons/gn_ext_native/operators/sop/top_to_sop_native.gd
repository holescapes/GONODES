class_name TOPtoSOPNative
extends GNSopBase
## Native-accelerated TOP→SOP converter — delegates to GNNativeTopToSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "toptosop_native"
	node_description = "Convert TOP texture to SOP heightfield or point cloud — native C++ accelerated."
	if ClassDB.class_exists("GNNativeTopToSop"):
		_processor = ClassDB.instantiate("GNNativeTopToSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, true, "Source TOP texture")
	add_output("out", GNFamily.Type.SOP, "Generated geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Heightfield", "Point Cloud", "Normal Map"]), 0, "Mode", ""))
	add_parameter(GNParameter.create_int("resolution", 64, 4, 512, "Resolution", ""))
	add_parameter(GNParameter.create_float("height_scale", 2.0, 0.0, 100.0, 0.1, "Height Scale", ""))
	add_parameter(GNParameter.create_float("grid_size", 10.0, 0.1, 1000.0, 0.5, "Grid Size", ""))
	add_parameter(GNParameter.create_float("threshold", 0.1, 0.0, 1.0, 0.01, "Threshold", ""))
	add_parameter(GNParameter.create_enum("channel",
		PackedStringArray(["Luminance", "Red", "Green", "Blue", "Alpha"]), 0, "Channel", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_data: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_data == null or tex_data.texture == null:
		return null

	var img: Image = tex_data.texture.get_image()
	if img == null:
		return null

	if not _processor:
		return null

	var result: Dictionary = _processor.process(img,
		get_param_value("mode"), get_param_value("resolution"),
		get_param_value("height_scale"), get_param_value("grid_size"),
		get_param_value("threshold"), get_param_value("channel"))

	if not result.has("positions"):
		return null

	var geo := _prepare_geo()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = result["positions"]
	if result.has("normals"): arrays[Mesh.ARRAY_NORMAL] = result["normals"]
	if result.has("uvs"): arrays[Mesh.ARRAY_TEX_UV] = result["uvs"]
	if result.has("indices"): arrays[Mesh.ARRAY_INDEX] = result["indices"]

	var prim: int = result.get("primitive", 3)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(prim, arrays)
	geo.set_mesh(mesh)
	return geo
