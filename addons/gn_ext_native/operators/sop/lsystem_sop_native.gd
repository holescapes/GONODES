class_name LSystemSOPNative
extends GNSopBase
## Native-accelerated L-System geometry — delegates to GNNativeLSystem (C++)
## when available, falls back to pure GDScript otherwise.

var _processor: RefCounted = null


func _init() -> void:
	node_type = "lsystem_native"
	node_description = "L-System fractal/branching geometry (native C++ accelerated)."
	if ClassDB.class_exists("GNNativeLSystem"):
		_processor = ClassDB.instantiate("GNNativeLSystem")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "L-System geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("axiom", "F", "Axiom",
		"Starting string for the L-System"))
	add_parameter(GNParameter.create_string("rule_a", "F=F[+F]F[-F]F", "Rule A",
		"Production rule (format: X=replacement)"))
	add_parameter(GNParameter.create_string("rule_b", "", "Rule B",
		"Second production rule (optional)"))
	add_parameter(GNParameter.create_string("rule_c", "", "Rule C",
		"Third production rule (optional)"))
	add_parameter(GNParameter.create_int("iterations", 3, 0, 8, "Iterations",
		"Number of grammar rewriting passes"))
	add_parameter(GNParameter.create_float("step_size", 1.0, 0.01, 100.0, 0.1,
		"Step Size", "Distance per F move"))
	add_parameter(GNParameter.create_float("angle", 25.7, 0.1, 180.0, 0.1,
		"Angle", "Turn angle in degrees"))
	add_parameter(GNParameter.create_float("step_scale", 1.0, 0.1, 2.0, 0.01,
		"Step Scale", "Step size multiplier per iteration depth"))
	add_parameter(GNParameter.create_float("angle_rand", 0.0, 0.0, 1.0, 0.01,
		"Angle Randomize", "Random variation on turn angle (0-1)"))
	add_parameter(GNParameter.create_int("seed", 42, 0, 99999, "Seed", "Random seed"))
	add_parameter(GNParameter.create_float("tube_radius", 0.0, 0.0, 10.0, 0.01,
		"Tube Radius", "Radius for tube geometry (0 = line primitives)"))
	add_parameter(GNParameter.create_int("tube_sides", 6, 3, 16, "Tube Sides",
		"Cross-section polygon sides"))
	add_parameter(GNParameter.create_float("taper", 0.7, 0.01, 1.0, 0.01,
		"Taper", "Radius multiplier per depth level"))
	add_parameter(GNParameter.create_float("gravity", 0.0, -5.0, 5.0, 0.01,
		"Gravity", "Downward bend per segment"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var axiom: String = get_param_value("axiom")
	var rules_str := ""
	var r_a: String = get_param_value("rule_a")
	var r_b: String = get_param_value("rule_b")
	var r_c: String = get_param_value("rule_c")
	if r_a != "":
		rules_str += r_a
	if r_b != "":
		rules_str += ";" + r_b
	if r_c != "":
		rules_str += ";" + r_c

	var iters: int = get_param_value("iterations")
	var step: float = get_param_value("step_size")
	var angle: float = get_param_value("angle")
	var step_s: float = get_param_value("step_scale")
	var a_rand: float = get_param_value("angle_rand")
	var s: int = get_param_value("seed")
	var tube_r: float = get_param_value("tube_radius")
	var tube_s: int = get_param_value("tube_sides")
	var taper: float = get_param_value("taper")
	var grav: float = get_param_value("gravity")

	if _processor != null:
		var result: Dictionary = _processor.process(axiom, rules_str, iters,
			step, angle, step_s, a_rand, s, tube_r, tube_s, taper, grav)
		var verts: PackedVector3Array = result.get("positions", PackedVector3Array())
		var normals: PackedVector3Array = result.get("normals", PackedVector3Array())

		if verts.is_empty():
			return null

		var out := _prepare_geo()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new()
		var prim_type := Mesh.PRIMITIVE_TRIANGLES if tube_r > 0.001 else Mesh.PRIMITIVE_LINES
		mesh.add_surface_from_arrays(prim_type, arrays)
		out.set_mesh(mesh)
		return out
	else:
		return null  # Fallback handled by core LSystemSOP
