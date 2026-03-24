extends Node
## Correctness tests for MAT operators.
##
## MATs produce GNMaterialData. We verify material creation and properties.

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
# PbrMAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_pbr_mat_instantiate() -> void:
	var node := _make_node(PbrMAT.new(), "pbr1")
	GNTestAssert.assert_eq(node.node_type, "pbr", "node_type")

func test_pbr_mat_default_params() -> void:
	var node := _make_node(PbrMAT.new(), "pbr1")
	GNTestAssert.assert_approx(node.get_param_value("metallic"), 0.0, 0.001, "metallic default")
	GNTestAssert.assert_approx(node.get_param_value("roughness"), 0.5, 0.001, "roughness default")

func test_pbr_mat_produces_material() -> void:
	var node := _make_node(PbrMAT.new(), "pbr1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "PbrMAT output")
	if out is GNMaterialData:
		GNTestAssert.assert_not_null(out.material, "material exists")
		GNTestAssert.assert_true(out.material is StandardMaterial3D, "is StandardMaterial3D")

func test_pbr_mat_albedo_color() -> void:
	var node := _make_node(PbrMAT.new(), "pbr1")
	node.set_param_value("albedo_color", Color.RED)
	var out := _cook_no_input(node)
	if out is GNMaterialData and out.material is StandardMaterial3D:
		var mat: StandardMaterial3D = out.material
		GNTestAssert.assert_approx(mat.albedo_color.r, 1.0, 0.01, "red channel")
		GNTestAssert.assert_approx(mat.albedo_color.g, 0.0, 0.01, "green channel")

func test_pbr_mat_metallic_roughness() -> void:
	var node := _make_node(PbrMAT.new(), "pbr1")
	node.set_param_value("metallic", 1.0)
	node.set_param_value("roughness", 0.1)
	var out := _cook_no_input(node)
	if out is GNMaterialData and out.material is StandardMaterial3D:
		var mat: StandardMaterial3D = out.material
		GNTestAssert.assert_approx(mat.metallic, 1.0, 0.01, "metallic=1")
		GNTestAssert.assert_approx(mat.roughness, 0.1, 0.01, "roughness=0.1")


# ═══════════════════════════════════════════════════════════════════════════════
# ConstantMAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_constant_mat_instantiate() -> void:
	var node := _make_node(ConstantMAT.new(), "const1")
	GNTestAssert.assert_eq(node.node_type, "constant", "node_type")

func test_constant_mat_produces_material() -> void:
	var node := _make_node(ConstantMAT.new(), "const1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "ConstantMAT output")
	if out is GNMaterialData:
		GNTestAssert.assert_not_null(out.material, "material exists")

func test_constant_mat_is_unshaded() -> void:
	var node := _make_node(ConstantMAT.new(), "const1")
	var out := _cook_no_input(node)
	if out is GNMaterialData and out.material is StandardMaterial3D:
		var mat: StandardMaterial3D = out.material
		GNTestAssert.assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "unshaded")

func test_constant_mat_color() -> void:
	var node := _make_node(ConstantMAT.new(), "const1")
	node.set_param_value("color", Color.BLUE)
	var out := _cook_no_input(node)
	if out is GNMaterialData and out.material is StandardMaterial3D:
		var mat: StandardMaterial3D = out.material
		GNTestAssert.assert_approx(mat.albedo_color.b, 1.0, 0.01, "blue=1")


# ═══════════════════════════════════════════════════════════════════════════════
# ShaderMAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_shader_mat_instantiate() -> void:
	var node := _make_node(ShaderMAT.new(), "shader1")
	GNTestAssert.assert_eq(node.node_type, "shader", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# DepthMAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_depth_mat_instantiate() -> void:
	var node := _make_node(DepthMAT.new(), "depth1")
	GNTestAssert.assert_eq(node.node_type, "depth", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# WireframeMAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_wireframe_mat_instantiate() -> void:
	var node := _make_node(WireframeMAT.new(), "wire1")
	GNTestAssert.assert_eq(node.node_type, "wireframe", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# LineMAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_line_mat_instantiate() -> void:
	var node := _make_node(LineMAT.new(), "line1")
	GNTestAssert.assert_eq(node.node_type, "line", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# NormalMapMAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_normal_map_mat_instantiate() -> void:
	var node := _make_node(NormalMapMAT.new(), "nmap1")
	GNTestAssert.assert_eq(node.node_type, "normal_map", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# PointSpriteMAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_point_sprite_mat_instantiate() -> void:
	var node := _make_node(PointSpriteMAT.new(), "ps1")
	GNTestAssert.assert_eq(node.node_type, "point_sprite", "node_type")

# ═══════════════════════════════════════════════════════════════════════════════
# FluidSurfaceMAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_fluid_surface_mat_instantiate() -> void:
	var node := _make_node(FluidSurfaceMAT.new(), "fluidmat1")
	GNTestAssert.assert_not_null(node, "FluidSurfaceMAT created")

func test_fluid_surface_mat_node_type() -> void:
	var node := _make_node(FluidSurfaceMAT.new(), "fluidmat2")
	GNTestAssert.assert_eq(node.node_type, "fluid_surface", "node_type")

func test_fluid_surface_mat_produces_material() -> void:
	var node := _make_node(FluidSurfaceMAT.new(), "fluidmat3")
	var out := _cook_no_input(node)
	if out is GNMaterialData:
		GNTestAssert.assert_not_null(out.material, "material exists")


# ═══════════════════════════════════════════════════════════════════════════════
# NullMAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_null_mat_instantiate() -> void:
	var node := _make_node(NullMAT.new(), "null_mat1")
	GNTestAssert.assert_not_null(node, "NullMAT created")

func test_null_mat_node_type() -> void:
	var node := _make_node(NullMAT.new(), "null_mat2")
	GNTestAssert.assert_eq(node.node_type, "null", "node_type")

func test_null_mat_null_input() -> void:
	var node := _make_node(NullMAT.new(), "null_mat3")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNMaterialData, "null input accepted")
