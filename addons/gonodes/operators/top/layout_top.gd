class_name LayoutTOP
extends GNTopBase
## Tiles up to 8 input textures into a grid mosaic.
## Columns are configurable; rows are computed automatically.


func _init() -> void:
	node_type = "layout"


func _init_ports() -> void:
	# Dynamic ports — start with 2, grow on connect
	add_input("in0", GNFamily.Type.TOP, false, "Input texture 0", "Input 0")
	add_input("in1", GNFamily.Type.TOP, false, "Input texture 1", "Input 1")
	add_input("", GNFamily.Type.TOP, false, "")  # trailing empty for auto-grow
	add_output("out", GNFamily.Type.TOP, "Mosaic texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1024, 512), "",
		"Output resolution"))
	add_parameter(GNParameter.create_int("columns", 2, 1, 8, "Columns",
		"Number of columns in the grid"))
	add_parameter(GNParameter.create_color("bg_color", Color.BLACK, "Background",
		"Background color for empty grid cells"))


func update_dynamic_inputs(connected_ports: PackedInt32Array) -> void:
	# MergeSOP-style auto-grow / auto-shrink using connected_ports from the engine
	var highest_connected: int = -1
	for p in connected_ports:
		if p > highest_connected:
			highest_connected = p

	var desired: int = clampi(highest_connected + 2, 2, 8)

	while input_ports.size() > desired + 1:
		input_ports.pop_back()
	while input_ports.size() < desired + 1:
		var idx: int = input_ports.size() - 1
		input_ports.insert(idx, {"name": "in%d" % idx, "type": GNFamily.Type.TOP,
			"required": false, "description": "Input texture %d" % idx})

	# Trailing empty
	if input_ports.size() > 0 and not input_ports[-1].name.is_empty():
		input_ports.append({"name": "", "type": GNFamily.Type.TOP,
			"required": false, "description": ""})

	ports_changed.emit()


func _cook(inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	_init_shader_viewport("res://addons/gonodes/shaders/top/layout.gdshader", true, false, res)

	if _viewport.size != res:
		_viewport.size = res

	var cols: int = get_param_value("columns")
	var bc: Color = get_param_value("bg_color")

	# Count connected inputs
	var num_inputs: int = 0
	for i in range(mini(inputs.size(), 8)):
		if inputs[i] is GNTextureData:
			num_inputs = i + 1

	_material.set_shader_parameter("num_inputs", maxi(num_inputs, 1))
	_material.set_shader_parameter("columns", cols)
	_material.set_shader_parameter("bg_color", Vector4(bc.r, bc.g, bc.b, bc.a))

	for i in range(8):
		var tex_name: String = "tex%d" % i
		if i < inputs.size() and inputs[i] is GNTextureData:
			_material.set_shader_parameter(tex_name, (inputs[i] as GNTextureData).texture)

	_cached_tex_data.resolution = res

	return _cached_tex_data
