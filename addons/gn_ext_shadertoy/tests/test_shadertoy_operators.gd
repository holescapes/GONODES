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


# ═══════════════════════════════════════════════════════════════════════════════
# ShadertoyTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_shadertoy_top_instantiate() -> void:
	var node := _make_node(ShadertoyTOP.new(), "shadertoy1")
	GNTestAssert.assert_not_null(node, "ShadertoyTOP created")


func test_shadertoy_top_set_shader_code() -> void:
	var node := _make_node(ShadertoyTOP.new(), "shadertoy2")
	var code := "void mainImage(out vec4 fragColor, in vec2 fragCoord) { fragColor = vec4(1.0); }"
	node.set_parameter("shader_code", code)
	GNTestAssert.assert_eq(node.get_parameter("shader_code"), code, "shader_code parameter set")
