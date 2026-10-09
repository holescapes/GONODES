class_name LayoutTOP
extends GNTopBase
## Tiles up to 8 input textures into a grid mosaic.
## Columns are configurable; rows are computed automatically.


func _init() -> void:
	node_type = "layout"


func _init_ports() -> void:
	# The network only grows ports when _dynamic_input is set. Two labeled
	# inputs plus one unnamed spare. Connecting the spare adds the next input,
	# up to the 8 samplers in layout.gdshader.
	_dynamic_input = true
	_dynamic_input_family = GNFamily.Type.TOP
	_dynamic_input_prefix = "in"
	_dynamic_input_desc = "Input"
	_rebuild_layout_inputs(-1)
	add_output("out", GNFamily.Type.TOP, "Mosaic texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1024, 512), "Output resolution",
		"Output resolution"))
	add_parameter(GNParameter.create_int("columns", 2, 1, 8, "Columns",
		"Number of columns in the grid"))
	add_parameter(GNParameter.create_color("bg_color", Color.BLACK, "Background",
		"Background color for empty grid cells"))


func update_dynamic_inputs(connected_ports: PackedInt32Array) -> void:
	var highest := -1
	for p in connected_ports:
		if p > highest:
			highest = p
	_rebuild_layout_inputs(highest)


## [param highest] is the highest connected port, or -1 when nothing is wired.
## Always keeps Input 0 and Input 1. Adds one unnamed spare after the last
## wire, and stops at 8 because the shader only samples tex0–tex7.
func _rebuild_layout_inputs(highest: int) -> void:
	var named := clampi(highest + 1, 2, 8)
	var spare := named < 8
	var total := named + (1 if spare else 0)
	var last_is_spare := input_ports.size() > 0 and input_ports[-1].port_name.is_empty()
	if input_ports.size() == total and last_is_spare == spare:
		return
	input_ports.clear()
	for i in range(named):
		add_input("in%d" % i, GNFamily.Type.TOP, false,
			"Input texture %d" % i, "Input %d" % i)
	if spare:
		add_input("", GNFamily.Type.TOP, false, "Additional input")
	ports_changed.emit(id)


func _cook(inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	_init_shader_viewport("res://addons/gonodes/shaders/top/layout.gdshader", true, false, res)

	_ensure_viewport_size(res)

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
