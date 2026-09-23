class_name RaymarchSDF
extends GNTopBase
## Compiles an SDF scene-graph AST into a single GLSL raymarching shader
## and renders it to a texture via SubViewport.
##
## Input: GNSDFData (SDF tree from upstream SDF operators)
## Output: GNTextureData (rendered TOP texture)

var _last_tree_hash: int = 0
var _shader: Shader = null


func _init() -> void:
	super._init()
	node_type = "raymarch_sdf"
	time_dependent = true
	node_description = "Compile and render an SDF scene to a 2D texture via raymarching."


func _init_ports() -> void:
	add_input("sdf_in", GNSdfBase.SDF_FAMILY, false, "SDF scene-graph to render", "SDF")
	add_output("out", GNFamily.Type.TOP, "Rendered texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512),
		"Resolution", "Output resolution."))
	add_parameter(GNParameter.create_int("max_steps", 128, 16, 512,
		"Max Steps", "Maximum raymarching steps."))
	add_parameter(GNParameter.create_float("max_dist", 50.0, 1.0, 500.0, 1.0,
		"Max Distance", "Maximum ray travel distance."))
	add_parameter(GNParameter.create_float("epsilon", 0.001, 0.0001, 0.1, 0.0001,
		"Epsilon", "Surface hit threshold."))
	add_parameter(GNParameter.create_float("cam_distance", 5.0, 0.1, 100.0, 0.1,
		"Camera Distance", "Orbit camera distance from origin."))
	add_parameter(GNParameter.create_float("cam_angle_x", 0.3, -3.14, 3.14, 0.01,
		"Camera Angle X", "Horizontal orbit angle (radians)."))
	add_parameter(GNParameter.create_float("cam_angle_y", 0.4, -1.5, 1.5, 0.01,
		"Camera Angle Y", "Vertical orbit angle (radians)."))
	add_parameter(GNParameter.create_float("fov", 60.0, 10.0, 170.0, 1.0,
		"FOV", "Field of view in degrees."))
	add_parameter(GNParameter.create_color("bg_color", Color(0.05, 0.05, 0.08, 1.0),
		"Background", "Background color for missed rays."))
	add_parameter(GNParameter.create_float("light_dir_x", -0.5, -1.0, 1.0, 0.01,
		"Light Dir X", "Directional light X component."))
	add_parameter(GNParameter.create_float("light_dir_y", 0.8, -1.0, 1.0, 0.01,
		"Light Dir Y", "Directional light Y component."))
	add_parameter(GNParameter.create_float("light_dir_z", 0.6, -1.0, 1.0, 0.01,
		"Light Dir Z", "Directional light Z component."))
	add_parameter(GNParameter.create_float("ambient", 0.15, 0.0, 1.0, 0.01,
		"Ambient", "Ambient light intensity."))
	add_parameter(GNParameter.create_bool("show_ao", true, "Ambient Occlusion",
		"Enable basic ambient occlusion."))
	add_parameter(GNParameter.create_bool("soft_shadows", true, "Soft Shadows",
		"Enable soft shadow estimation."))


func _cook(inputs: Array[GNData]) -> GNData:
	var sdf_in: GNSDFData = null
	if inputs.size() > 0 and inputs[0] is GNSDFData:
		sdf_in = inputs[0] as GNSDFData
	if sdf_in == null or sdf_in.sdf_tree.is_empty():
		return null

	var res: Vector2i = get_param_value("resolution")

	# Recompile shader only when AST changes
	if sdf_in.tree_hash != _last_tree_hash or _shader == null:
		var glsl := _compile_shader(sdf_in.sdf_tree)
		_shader = Shader.new()
		_shader.code = glsl
		_last_tree_hash = sdf_in.tree_hash

		# Rebuild viewport with new shader
		if _viewport != null:
			_viewport.queue_free()
			_viewport = null
			_material = null
			_canvas = null
			_cached_tex_data = null

	# Lazy init viewport
	if _viewport == null:
		_viewport = _create_viewport("", res, false)
		_material = ShaderMaterial.new()
		_material.shader = _shader
		var rect := ColorRect.new()
		rect.name = "Canvas"
		rect.material = _material
		_viewport.add_child(rect)
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_canvas = rect
		_cached_tex_data = GNTextureData.new()
		_cached_tex_data.texture = _viewport.get_texture()
		_cached_tex_data.viewport = _viewport

	if _viewport.size != res:
		_viewport.size = res
		_cached_tex_data.resolution = res

	# Set uniforms
	_material.shader = _shader
	_material.set_shader_parameter("u_max_steps", get_param_value("max_steps"))
	_material.set_shader_parameter("u_max_dist", get_param_value("max_dist"))
	_material.set_shader_parameter("u_epsilon", get_param_value("epsilon"))
	_material.set_shader_parameter("u_cam_dist", get_param_value("cam_distance"))
	_material.set_shader_parameter("u_cam_angle", Vector2(
		get_param_value("cam_angle_x"), get_param_value("cam_angle_y")))
	_material.set_shader_parameter("u_fov", get_param_value("fov"))
	_material.set_shader_parameter("u_bg_color", get_param_value("bg_color"))
	var ld := Vector3(get_param_value("light_dir_x"), get_param_value("light_dir_y"), get_param_value("light_dir_z"))
	_material.set_shader_parameter("u_light_dir", ld.normalized())
	_material.set_shader_parameter("u_ambient", get_param_value("ambient"))
	_material.set_shader_parameter("u_show_ao", get_param_value("show_ao"))
	_material.set_shader_parameter("u_soft_shadows", get_param_value("soft_shadows"))
	_material.set_shader_parameter("u_time", elapsed_time)

	# Set per-node uniform values from the AST
	_set_tree_uniforms(sdf_in.sdf_tree, [0])

	_cached_tex_data.resolution = res
	return _cached_tex_data


# ═══════════════════════════════════════════════════════════════════════════════
# GLSL Compiler — walks AST → emits shader code
# ═══════════════════════════════════════════════════════════════════════════════

func _compile_shader(tree: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("shader_type canvas_item;")
	lines.append("")
	lines.append("// --- Uniforms ---")
	lines.append("uniform int u_max_steps;")
	lines.append("uniform float u_max_dist;")
	lines.append("uniform float u_epsilon;")
	lines.append("uniform float u_cam_dist;")
	lines.append("uniform vec2 u_cam_angle;")
	lines.append("uniform float u_fov;")
	lines.append("uniform vec4 u_bg_color;")
	lines.append("uniform vec3 u_light_dir;")
	lines.append("uniform float u_ambient;")
	lines.append("uniform bool u_show_ao;")
	lines.append("uniform bool u_soft_shadows;")
	lines.append("uniform float u_time;")
	lines.append("")

	# Collect per-node uniforms
	var counter := [0]
	var uniform_lines: PackedStringArray = PackedStringArray()
	_collect_uniforms(tree, counter, uniform_lines)
	lines.append_array(uniform_lines)
	lines.append("")

	# SDF primitive library
	lines.append("// --- SDF Primitives ---")
	lines.append(_sdf_lib())
	lines.append("")

	# Forward-declare sdf_scene so domain helpers can call it recursively
	# (not needed — domain helpers are standalone functions that call their child inline)

	# Emit domain helper functions (for modifiers that transform p)
	counter[0] = 0
	var domain_funcs: PackedStringArray = PackedStringArray()
	_collect_domain_functions(tree, counter, domain_funcs)
	if not domain_funcs.is_empty():
		lines.append("// --- Domain Modifier Functions ---")
		lines.append_array(domain_funcs)
		lines.append("")

	# Scene function
	lines.append("// --- Scene ---")
	counter[0] = 0
	var scene_body := _emit_sdf(tree, counter)
	lines.append("vec2 sdf_scene(vec3 p) {")
	lines.append("    return %s;" % scene_body)
	lines.append("}")
	lines.append("")

	# Material function
	counter[0] = 0
	var mat_body := _emit_material(tree, counter)
	lines.append("vec3 get_material(vec3 p, float d) {")
	lines.append("    return %s;" % mat_body)
	lines.append("}")
	lines.append("")

	# Raymarching + shading
	lines.append(_raymarch_code())

	return "\n".join(lines)


## Emits SDF evaluation code for one AST node. Returns a string expression "vec2(dist, id)".
func _emit_sdf(tree: Dictionary, counter: Array) -> String:
	var idx: int = counter[0]
	counter[0] += 1
	var op: String = tree.get("op", "sphere")
	var children: Array = tree.get("children", [])

	match op:
		"sphere":
			return "vec2(sdf_sphere(p - u_pos_%d, u_radius_%d), float(%d))" % [idx, idx, idx]
		"box":
			return "vec2(sdf_box(p - u_pos_%d, u_size_%d), float(%d))" % [idx, idx, idx]
		"torus":
			return "vec2(sdf_torus(p - u_pos_%d, vec2(u_major_%d, u_minor_%d)), float(%d))" % [idx, idx, idx, idx]
		"cylinder":
			return "vec2(sdf_cylinder(p - u_pos_%d, u_radius_%d, u_height_%d), float(%d))" % [idx, idx, idx, idx]
		"capsule":
			return "vec2(sdf_capsule(p - u_pos_%d, u_radius_%d, u_height_%d), float(%d))" % [idx, idx, idx, idx]
		"plane":
			return "vec2(sdf_plane(p, u_normal_%d, u_offset_%d), float(%d))" % [idx, idx, idx]
		"cone":
			return "vec2(sdf_cone(p - u_pos_%d, u_angle_%d, u_height_%d), float(%d))" % [idx, idx, idx, idx]
		"pyramid":
			return "vec2(sdf_pyramid(p - u_pos_%d, u_base_%d, u_height_%d), float(%d))" % [idx, idx, idx, idx]
		"octahedron":
			return "vec2(sdf_octahedron(p - u_pos_%d, u_size_%d), float(%d))" % [idx, idx, idx]
		"gyroid":
			return "vec2(sdf_gyroid(p - u_pos_%d, u_scale_%d, u_thickness_%d), float(%d))" % [idx, idx, idx, idx]
		"union":
			if children.size() < 2:
				return "vec2(1e10, 0.0)"
			var a := _emit_sdf(children[0], counter)
			var b := _emit_sdf(children[1], counter)
			return "sdf_union(%s, %s)" % [a, b]
		"intersection":
			if children.size() < 2:
				return "vec2(1e10, 0.0)"
			var a := _emit_sdf(children[0], counter)
			var b := _emit_sdf(children[1], counter)
			return "sdf_intersection(%s, %s)" % [a, b]
		"subtract":
			if children.size() < 2:
				return "vec2(1e10, 0.0)"
			var a := _emit_sdf(children[0], counter)
			var b := _emit_sdf(children[1], counter)
			return "sdf_subtract(%s, %s)" % [a, b]
		"smooth_union":
			if children.size() < 2:
				return "vec2(1e10, 0.0)"
			var a := _emit_sdf(children[0], counter)
			var b := _emit_sdf(children[1], counter)
			return "sdf_smooth_union(%s, %s, u_smooth_%d)" % [a, b, idx]
		"smooth_subtract":
			if children.size() < 2:
				return "vec2(1e10, 0.0)"
			var a := _emit_sdf(children[0], counter)
			var b := _emit_sdf(children[1], counter)
			return "sdf_smooth_subtract(%s, %s, u_smooth_%d)" % [a, b, idx]
		"repeat", "mirror", "twist", "bend", "elongate":
			# Domain modifiers: call the pre-generated helper function
			if children.is_empty():
				return "vec2(1e10, 0.0)"
			# Skip the child counter positions (they're consumed by _collect_domain_functions)
			_skip_counter(children[0], counter)
			return "sdf_domain_%d(p)" % idx
		"round":
			if children.is_empty():
				return "vec2(1e10, 0.0)"
			var child := _emit_sdf(children[0], counter)
			return "vec2(%s.x - u_round_%d, %s.y)" % [child, idx, child]
		"onion":
			if children.is_empty():
				return "vec2(1e10, 0.0)"
			var child := _emit_sdf(children[0], counter)
			return "vec2(sdf_onion(%s.x, u_onion_t_%d, u_onion_n_%d), %s.y)" % [child, idx, idx, child]
		"displace":
			if children.is_empty():
				return "vec2(1e10, 0.0)"
			var child := _emit_sdf(children[0], counter)
			return "vec2(%s.x + sdf_displace(p, u_disp_amount_%d, u_disp_freq_%d, u_disp_time_%d), %s.y)" % [child, idx, idx, idx, child]
		_:
			return "vec2(1e10, 0.0)"


## Skip counter positions for a subtree (used when domain functions handle the counter separately).
func _skip_counter(tree: Dictionary, counter: Array) -> void:
	counter[0] += 1
	var children: Array = tree.get("children", [])
	for child in children:
		_skip_counter(child, counter)


## Collect GLSL domain modifier helper functions that transform p before evaluating children.
## These are emitted as standalone functions before sdf_scene() so they can be called by name.
func _collect_domain_functions(tree: Dictionary, counter: Array,
		funcs: PackedStringArray) -> void:
	var idx: int = counter[0]
	counter[0] += 1
	var op: String = tree.get("op", "sphere")
	var children: Array = tree.get("children", [])

	# Domain modifiers generate a function that transforms p, then evals child
	var is_domain := op in ["repeat", "mirror", "twist", "bend", "elongate"]
	if is_domain and children.size() > 0:
		# First, recurse into children to generate their domain functions
		var child_counter := counter.duplicate()
		_collect_domain_functions(children[0], counter, funcs)

		# Now emit this node's function
		var child_expr := _emit_sdf(children[0], child_counter)
		var transform_code := ""
		match op:
			"repeat":
				transform_code = "    p = sdf_repeat(p, u_spacing_%d, u_limit_%d);" % [idx, idx]
			"mirror":
				transform_code = "    if (u_mirror_x_%d) p.x = abs(p.x);\n" % idx
				transform_code += "    if (u_mirror_y_%d) p.y = abs(p.y);\n" % idx
				transform_code += "    if (u_mirror_z_%d) p.z = abs(p.z);" % idx
			"twist":
				transform_code = "    p = sdf_twist(p, u_twist_%d, u_twist_axis_%d);" % [idx, idx]
			"bend":
				transform_code = "    p = sdf_bend(p, u_bend_%d, u_bend_axis_%d);" % [idx, idx]
			"elongate":
				transform_code = "    p = sdf_elongate(p, u_elongate_%d);" % idx

		funcs.append("vec2 sdf_domain_%d(vec3 p) {" % idx)
		funcs.append(transform_code)
		funcs.append("    return %s;" % child_expr)
		funcs.append("}")
		funcs.append("")
		return

	# Non-domain nodes: just recurse into children
	for child in children:
		_collect_domain_functions(child, counter, funcs)


## Collect all uniform declarations by walking the tree.
func _collect_uniforms(tree: Dictionary, counter: Array, lines: PackedStringArray) -> void:
	var idx: int = counter[0]
	counter[0] += 1
	var op: String = tree.get("op", "sphere")
	var children: Array = tree.get("children", [])

	match op:
		"sphere":
			lines.append("uniform vec3 u_pos_%d;" % idx)
			lines.append("uniform float u_radius_%d;" % idx)
		"box":
			lines.append("uniform vec3 u_pos_%d;" % idx)
			lines.append("uniform vec3 u_size_%d;" % idx)
		"torus":
			lines.append("uniform vec3 u_pos_%d;" % idx)
			lines.append("uniform float u_major_%d;" % idx)
			lines.append("uniform float u_minor_%d;" % idx)
		"cylinder":
			lines.append("uniform vec3 u_pos_%d;" % idx)
			lines.append("uniform float u_radius_%d;" % idx)
			lines.append("uniform float u_height_%d;" % idx)
		"capsule":
			lines.append("uniform vec3 u_pos_%d;" % idx)
			lines.append("uniform float u_radius_%d;" % idx)
			lines.append("uniform float u_height_%d;" % idx)
		"plane":
			lines.append("uniform vec3 u_normal_%d;" % idx)
			lines.append("uniform float u_offset_%d;" % idx)
		"cone":
			lines.append("uniform vec3 u_pos_%d;" % idx)
			lines.append("uniform float u_angle_%d;" % idx)
			lines.append("uniform float u_height_%d;" % idx)
		"pyramid":
			lines.append("uniform vec3 u_pos_%d;" % idx)
			lines.append("uniform float u_base_%d;" % idx)
			lines.append("uniform float u_height_%d;" % idx)
		"octahedron":
			lines.append("uniform vec3 u_pos_%d;" % idx)
			lines.append("uniform float u_size_%d;" % idx)
		"gyroid":
			lines.append("uniform vec3 u_pos_%d;" % idx)
			lines.append("uniform float u_scale_%d;" % idx)
			lines.append("uniform float u_thickness_%d;" % idx)
		"smooth_union", "smooth_subtract":
			lines.append("uniform float u_smooth_%d;" % idx)
		"repeat":
			lines.append("uniform vec3 u_spacing_%d;" % idx)
			lines.append("uniform vec3 u_limit_%d;" % idx)
		"mirror":
			lines.append("uniform bool u_mirror_x_%d;" % idx)
			lines.append("uniform bool u_mirror_y_%d;" % idx)
			lines.append("uniform bool u_mirror_z_%d;" % idx)
		"twist":
			lines.append("uniform float u_twist_%d;" % idx)
			lines.append("uniform int u_twist_axis_%d;" % idx)
		"bend":
			lines.append("uniform float u_bend_%d;" % idx)
			lines.append("uniform int u_bend_axis_%d;" % idx)
		"elongate":
			lines.append("uniform vec3 u_elongate_%d;" % idx)
		"round":
			lines.append("uniform float u_round_%d;" % idx)
		"onion":
			lines.append("uniform float u_onion_t_%d;" % idx)
			lines.append("uniform int u_onion_n_%d;" % idx)
		"displace":
			lines.append("uniform float u_disp_amount_%d;" % idx)
			lines.append("uniform float u_disp_freq_%d;" % idx)
			lines.append("uniform float u_disp_time_%d;" % idx)

	for child in children:
		_collect_uniforms(child, counter, lines)


## Set uniform values from AST node params.
func _set_tree_uniforms(tree: Dictionary, counter: Array) -> void:
	var idx: int = counter[0]
	counter[0] += 1
	var op: String = tree.get("op", "sphere")
	var params: Dictionary = tree.get("params", {})
	var children: Array = tree.get("children", [])

	match op:
		"sphere":
			_set_v3(idx, "pos", params.get("position", Vector3.ZERO))
			_material.set_shader_parameter("u_radius_%d" % idx, params.get("radius", 1.0))
		"box":
			_set_v3(idx, "pos", params.get("position", Vector3.ZERO))
			_set_v3(idx, "size", params.get("size", Vector3.ONE))
		"torus":
			_set_v3(idx, "pos", params.get("position", Vector3.ZERO))
			_material.set_shader_parameter("u_major_%d" % idx, params.get("major_radius", 1.0))
			_material.set_shader_parameter("u_minor_%d" % idx, params.get("minor_radius", 0.3))
		"cylinder":
			_set_v3(idx, "pos", params.get("position", Vector3.ZERO))
			_material.set_shader_parameter("u_radius_%d" % idx, params.get("radius", 0.5))
			_material.set_shader_parameter("u_height_%d" % idx, params.get("height", 2.0))
		"capsule":
			_set_v3(idx, "pos", params.get("position", Vector3.ZERO))
			_material.set_shader_parameter("u_radius_%d" % idx, params.get("radius", 0.3))
			_material.set_shader_parameter("u_height_%d" % idx, params.get("height", 2.0))
		"plane":
			var n: Vector3 = params.get("normal", Vector3(0, 1, 0))
			_material.set_shader_parameter("u_normal_%d" % idx, n.normalized())
			_material.set_shader_parameter("u_offset_%d" % idx, params.get("offset", 0.0))
		"cone":
			_set_v3(idx, "pos", params.get("position", Vector3.ZERO))
			_material.set_shader_parameter("u_angle_%d" % idx, deg_to_rad(params.get("angle", 30.0)))
			_material.set_shader_parameter("u_height_%d" % idx, params.get("height", 2.0))
		"pyramid":
			_set_v3(idx, "pos", params.get("position", Vector3.ZERO))
			_material.set_shader_parameter("u_base_%d" % idx, params.get("base", 1.0))
			_material.set_shader_parameter("u_height_%d" % idx, params.get("height", 1.5))
		"octahedron":
			_set_v3(idx, "pos", params.get("position", Vector3.ZERO))
			_material.set_shader_parameter("u_size_%d" % idx, params.get("size", 1.0))
		"gyroid":
			_set_v3(idx, "pos", params.get("position", Vector3.ZERO))
			_material.set_shader_parameter("u_scale_%d" % idx, params.get("scale", 1.0))
			_material.set_shader_parameter("u_thickness_%d" % idx, params.get("thickness", 0.1))
		"smooth_union", "smooth_subtract":
			_material.set_shader_parameter("u_smooth_%d" % idx, params.get("smoothness", 0.5))
		"repeat":
			_set_v3(idx, "spacing", params.get("spacing", Vector3(3, 3, 3)))
			_set_v3(idx, "limit", params.get("limit", Vector3.ZERO))
		"mirror":
			_material.set_shader_parameter("u_mirror_x_%d" % idx, params.get("mirror_x", true))
			_material.set_shader_parameter("u_mirror_y_%d" % idx, params.get("mirror_y", false))
			_material.set_shader_parameter("u_mirror_z_%d" % idx, params.get("mirror_z", false))
		"twist":
			_material.set_shader_parameter("u_twist_%d" % idx, params.get("amount", 1.0))
			_material.set_shader_parameter("u_twist_axis_%d" % idx, params.get("axis", 0))
		"bend":
			_material.set_shader_parameter("u_bend_%d" % idx, params.get("amount", 0.5))
			_material.set_shader_parameter("u_bend_axis_%d" % idx, params.get("axis", 0))
		"elongate":
			_set_v3(idx, "elongate", params.get("amount", Vector3(0, 0.5, 0)))
		"round":
			_material.set_shader_parameter("u_round_%d" % idx, params.get("radius", 0.1))
		"onion":
			_material.set_shader_parameter("u_onion_t_%d" % idx, params.get("thickness", 0.1))
			_material.set_shader_parameter("u_onion_n_%d" % idx, params.get("layers", 1))
		"displace":
			_material.set_shader_parameter("u_disp_amount_%d" % idx, params.get("amount", 0.2))
			_material.set_shader_parameter("u_disp_freq_%d" % idx, params.get("frequency", 5.0))
			_material.set_shader_parameter("u_disp_time_%d" % idx, params.get("time_offset", 0.0))

	for child in children:
		_set_tree_uniforms(child, counter)


func _set_v3(idx: int, name: String, val: Vector3) -> void:
	_material.set_shader_parameter("u_%s_%d" % [name, idx], val)


## Emit material color lookup code.
func _emit_material(tree: Dictionary, counter: Array) -> String:
	var idx: int = counter[0]
	counter[0] += 1
	var mat: Dictionary = tree.get("material", {})
	var children: Array = tree.get("children", [])

	if not mat.is_empty():
		var mt: String = mat.get("type", "solid")
		if mt == "gradient":
			var cn: Array = mat.get("color_near", [0.8, 0.2, 0.2])
			var cf: Array = mat.get("color_far", [0.2, 0.2, 0.8])
			var r: float = mat.get("range", 2.0)
			return "mix(vec3(%.3f,%.3f,%.3f), vec3(%.3f,%.3f,%.3f), clamp(d/%.3f, 0.0, 1.0))" % [
				cn[0], cn[1], cn[2], cf[0], cf[1], cf[2], r]
		else:
			var alb: Array = mat.get("albedo", [0.8, 0.2, 0.2])
			return "vec3(%.3f, %.3f, %.3f)" % [alb[0], alb[1], alb[2]]

	# Check children for material
	for child in children:
		var child_mat := _emit_material(child, counter)
		if child_mat != "vec3(0.7, 0.7, 0.7)":
			return child_mat

	# Skip children counter for non-material nodes
	return "vec3(0.7, 0.7, 0.7)"


# ═══════════════════════════════════════════════════════════════════════════════
# SDF Library — GLSL source for primitive functions
# ═══════════════════════════════════════════════════════════════════════════════

func _sdf_lib() -> String:
	return """
float sdf_sphere(vec3 p, float r) { return length(p) - r; }

float sdf_box(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdf_torus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

float sdf_cylinder(vec3 p, float r, float h) {
    vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h * 0.5);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdf_capsule(vec3 p, float r, float h) {
    p.y -= clamp(p.y, -h * 0.5, h * 0.5);
    return length(p) - r;
}

float sdf_plane(vec3 p, vec3 n, float h) {
    return dot(p, normalize(n)) + h;
}

float sdf_cone(vec3 p, float angle, float h) {
    vec2 c = vec2(sin(angle), cos(angle));
    vec2 q = h * vec2(c.x / c.y, -1.0);
    vec2 w = vec2(length(p.xz), p.y);
    vec2 a = w - q * clamp(dot(w, q) / dot(q, q), 0.0, 1.0);
    vec2 b = w - q * vec2(clamp(w.x / q.x, 0.0, 1.0), 1.0);
    float k = sign(q.y);
    float d = min(dot(a, a), dot(b, b));
    float s = max(k * (w.x * q.y - w.y * q.x), k * (w.y - q.y));
    return sqrt(d) * sign(s);
}

float sdf_pyramid(vec3 p, float base, float h) {
    float m2 = h * h + 0.25;
    p.xz = abs(p.xz);
    if (p.z > p.x) p.xz = p.zx;
    p.xz -= 0.5 * base;
    vec3 q = vec3(p.z, h * p.y - 0.5 * p.x, h * p.x + 0.5 * p.y);
    float s = max(-q.x, 0.0);
    float t = clamp((q.y - 0.5 * p.z) / (m2 + 0.25), 0.0, 1.0);
    float a = m2 * (q.x + s) * (q.x + s) + q.y * q.y;
    float b = m2 * (q.x + 0.5 * t) * (q.x + 0.5 * t) + (q.y - m2 * t) * (q.y - m2 * t);
    float d2 = min(q.y, -q.x * m2 - q.y * 0.5) > 0.0 ? 0.0 : min(a, b);
    return sqrt((d2 + q.z * q.z) / m2) * sign(max(q.z, -p.y));
}

float sdf_octahedron(vec3 p, float s) {
    p = abs(p);
    float m = p.x + p.y + p.z - s;
    vec3 q;
    if (3.0 * p.x < m) q = p.xyz;
    else if (3.0 * p.y < m) q = p.yzx;
    else if (3.0 * p.z < m) q = p.zxy;
    else return m * 0.57735027;
    float k = clamp(0.5 * (q.z - q.y + s), 0.0, s);
    return length(vec3(q.x, q.y - s + k, q.z - k));
}

float sdf_gyroid(vec3 p, float scale, float thickness) {
    p *= scale;
    return (abs(dot(sin(p), cos(p.zxy))) - thickness) / scale;
}

// --- Booleans ---
vec2 sdf_union(vec2 a, vec2 b) { return a.x < b.x ? a : b; }
vec2 sdf_intersection(vec2 a, vec2 b) { return a.x > b.x ? a : b; }
vec2 sdf_subtract(vec2 a, vec2 b) { return vec2(max(a.x, -b.x), a.y); }

vec2 sdf_smooth_union(vec2 a, vec2 b, float k) {
    float h = clamp(0.5 + 0.5 * (b.x - a.x) / k, 0.0, 1.0);
    float d = mix(b.x, a.x, h) - k * h * (1.0 - h);
    return vec2(d, mix(b.y, a.y, h));
}

vec2 sdf_smooth_subtract(vec2 a, vec2 b, float k) {
    float h = clamp(0.5 - 0.5 * (a.x + b.x) / k, 0.0, 1.0);
    float d = mix(a.x, -b.x, h) + k * h * (1.0 - h);
    return vec2(d, a.y);
}

// --- Domain Modifiers ---
vec3 sdf_repeat(vec3 p, vec3 spacing, vec3 lim) {
    if (spacing.x > 0.0) p.x = lim.x > 0.0 ? p.x - spacing.x * clamp(round(p.x / spacing.x), -lim.x, lim.x) : mod(p.x + spacing.x * 0.5, spacing.x) - spacing.x * 0.5;
    if (spacing.y > 0.0) p.y = lim.y > 0.0 ? p.y - spacing.y * clamp(round(p.y / spacing.y), -lim.y, lim.y) : mod(p.y + spacing.y * 0.5, spacing.y) - spacing.y * 0.5;
    if (spacing.z > 0.0) p.z = lim.z > 0.0 ? p.z - spacing.z * clamp(round(p.z / spacing.z), -lim.z, lim.z) : mod(p.z + spacing.z * 0.5, spacing.z) - spacing.z * 0.5;
    return p;
}

vec3 sdf_twist(vec3 p, float k, int axis) {
    float a;
    if (axis == 0) a = k * p.y;       // twist around Y
    else if (axis == 1) a = k * p.x;  // twist around X
    else a = k * p.z;                  // twist around Z
    float c = cos(a); float s = sin(a);
    if (axis == 0) return vec3(c * p.x - s * p.z, p.y, s * p.x + c * p.z);
    else if (axis == 1) return vec3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
    else return vec3(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
}

vec3 sdf_bend(vec3 p, float k, int axis) {
    float a;
    if (axis == 0) a = k * p.x;
    else if (axis == 1) a = k * p.y;
    else a = k * p.z;
    float c = cos(a); float s = sin(a);
    if (axis == 0) return vec3(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
    else if (axis == 1) return vec3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
    else return vec3(c * p.x - s * p.z, p.y, s * p.x + c * p.z);
}

vec3 sdf_elongate(vec3 p, vec3 h) {
    return p - clamp(p, -h, h);
}

float sdf_onion(float d, float thickness, int layers) {
    for (int i = 0; i < layers; i++) {
        d = abs(d) - thickness;
    }
    return d;
}

float sdf_displace(vec3 p, float amount, float freq, float t) {
    return amount * sin(freq * p.x + t) * sin(freq * p.y + t) * sin(freq * p.z + t);
}
"""


func _raymarch_code() -> String:
	return """
vec3 calc_normal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        sdf_scene(p + e.xyy).x - sdf_scene(p - e.xyy).x,
        sdf_scene(p + e.yxy).x - sdf_scene(p - e.yxy).x,
        sdf_scene(p + e.yyx).x - sdf_scene(p - e.yyx).x
    ));
}

float calc_ao(vec3 p, vec3 n) {
    float occ = 0.0;
    float sca = 1.0;
    for (int i = 0; i < 5; i++) {
        float h = 0.01 + 0.12 * float(i);
        float d = sdf_scene(p + n * h).x;
        occ += (h - d) * sca;
        sca *= 0.95;
    }
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

float calc_shadow(vec3 ro, vec3 rd, float tmin, float tmax) {
    float res = 1.0;
    float t = tmin;
    for (int i = 0; i < 32 && t < tmax; i++) {
        float h = sdf_scene(ro + rd * t).x;
        if (h < 0.001) return 0.0;
        res = min(res, 8.0 * h / t);
        t += h;
    }
    return clamp(res, 0.0, 1.0);
}

void fragment() {
    vec2 uv = (UV * 2.0 - 1.0);
    uv.x *= float(textureSize(TEXTURE, 0).x) / float(textureSize(TEXTURE, 0).y);

    // Camera
    float fov_rad = radians(u_fov);
    vec3 ro = vec3(
        u_cam_dist * cos(u_cam_angle.y) * sin(u_cam_angle.x),
        u_cam_dist * sin(u_cam_angle.y),
        u_cam_dist * cos(u_cam_angle.y) * cos(u_cam_angle.x)
    );
    vec3 target = vec3(0.0);
    vec3 fwd = normalize(target - ro);
    vec3 right = normalize(cross(fwd, vec3(0.0, 1.0, 0.0)));
    vec3 up = cross(right, fwd);
    vec3 rd = normalize(fwd * tan(fov_rad * 0.5) + right * uv.x + up * uv.y);

    // Raymarch
    float t = 0.0;
    float mat_id = 0.0;
    bool hit = false;
    for (int i = 0; i < u_max_steps; i++) {
        vec3 p = ro + rd * t;
        vec2 res = sdf_scene(p);
        if (res.x < u_epsilon) {
            hit = true;
            mat_id = res.y;
            break;
        }
        t += res.x;
        if (t > u_max_dist) break;
    }

    if (!hit) {
        COLOR = u_bg_color;
    } else {
        vec3 p = ro + rd * t;
        vec3 n = calc_normal(p);
        vec3 albedo = get_material(p, t);
        vec3 l = normalize(u_light_dir);

        // Diffuse + specular
        float diff = max(dot(n, l), 0.0);
        vec3 h = normalize(l - rd);
        float spec = pow(max(dot(n, h), 0.0), 32.0) * 0.3;

        float ao = u_show_ao ? calc_ao(p, n) : 1.0;
        float shadow = u_soft_shadows ? calc_shadow(p + n * 0.01, l, 0.02, 10.0) : 1.0;

        vec3 col = albedo * (u_ambient + diff * shadow) * ao + vec3(spec * shadow);

        // Tone mapping + gamma
        col = col / (col + vec3(1.0));
        col = pow(col, vec3(1.0 / 2.2));

        COLOR = vec4(col, 1.0);
    }
}
"""
