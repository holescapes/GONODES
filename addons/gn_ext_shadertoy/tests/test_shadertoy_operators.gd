extends Node
## Tests for gn_ext_shadertoy operators.

var _network: GNNetwork
var _engine: GNCookEngine


func before_each() -> void:
	_network = GNNetwork.new()
	_engine = GNCookEngine.new()
	_engine.network = _network
	_engine.cooking_enabled = false
	_engine.elapsed_time = 1.0
	_engine.frame_count = 60
	_engine.current_delta = 1.0 / 60.0
	add_child(_engine)


func after_each() -> void:
	if is_instance_valid(_engine):
		remove_child(_engine)
		_engine.queue_free()


func _make_node(node: GNNode, id: String) -> GNNode:
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


func _cook_no_input(node: GNNode) -> GNData:
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, _engine.frame_count)
	return node.cached_output


# ═══════════════════════════════════════════════════════════════════════════════
# ShadertoyTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_shadertoy_top_instantiate() -> void:
	var node := _make_node(ShadertoyTOP.new(), "shadertoy1")
	GNTestAssert.assert_not_null(node, "ShadertoyTOP created")
	GNTestAssert.assert_eq(node.node_type, "shadertoy", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family is TOP")

func test_shadertoy_top_ports() -> void:
	var node := _make_node(ShadertoyTOP.new(), "shadertoy2")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.TOP, "output is TOP")

func test_shadertoy_top_parameters() -> void:
	var node := _make_node(ShadertoyTOP.new(), "shadertoy3")
	GNTestAssert.assert_true(node.parameters.has("shadertoy_code"), "has shadertoy_code")

func test_shadertoy_top_set_shader_code() -> void:
	var node := _make_node(ShadertoyTOP.new(), "shadertoy4")
	var code := "void mainImage(out vec4 fragColor, in vec2 fragCoord) { fragColor = vec4(1.0); }"
	node.set_param_value("shadertoy_code", code)
	GNTestAssert.assert_eq(node.get_param_value("shadertoy_code"), code, "shadertoy_code parameter set")

func test_shadertoy_top_cook_null() -> void:
	var node := _make_node(ShadertoyTOP.new(), "shadertoy5")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "ShadertoyTOP cook-null no crash")

func test_shadertoy_top_description() -> void:
	var node := _make_node(ShadertoyTOP.new(), "shadertoy6")
	GNTestAssert.assert_true(not node.node_description.is_empty(), "has description")
