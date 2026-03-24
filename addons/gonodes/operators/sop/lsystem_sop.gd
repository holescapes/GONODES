class_name LSystemSOP
extends GNSopBase
## Lindenmayer System (L-System) turtle-graphics geometry generator.
##
## Interprets a formal grammar to produce branching, fractal, and organic
## structures.  A turtle starts at the origin facing +Y and interprets
## symbols to move, turn, push/pop state, and optionally draw tubes.
##
## Grammar symbols:
##   F — Move forward and draw a line/tube segment
##   f — Move forward without drawing
##   + — Yaw right (turn around up axis)
##   - — Yaw left
##   ^ — Pitch up
##   & — Pitch down
##   \\ — Roll clockwise
##   / — Roll counter-clockwise
##   [ — Push state (branch start)
##   ] — Pop state (branch end)
##   | — Turn around 180° (yaw)
##
## Example axiom/rules for a simple tree:
##   Axiom:  F
##   Rule A: F → F[+F]F[-F]F
##
## Output can be lines (PRIMITIVE_LINES) or tubes if tube_radius > 0.

const MAX_STRING_LENGTH := 500000  # Safety limit for production string


func _init() -> void:
	node_type = "lsystem"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "L-System geometry")


func _init_parameters() -> void:
	# Grammar
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

	# Turtle parameters
	add_parameter(GNParameter.create_float("step_size", 1.0, 0.01, 100.0, 0.1,
		"Step Size", "Distance per F move"))
	add_parameter(GNParameter.create_float("angle", 25.7, 0.1, 180.0, 0.1,
		"Angle", "Turn angle in degrees"))
	add_parameter(GNParameter.create_float("step_scale", 1.0, 0.1, 2.0, 0.01,
		"Step Scale", "Step size multiplier per iteration depth"))
	add_parameter(GNParameter.create_float("angle_rand", 0.0, 0.0, 1.0, 0.01,
		"Angle Randomize", "Random variation on turn angle (0-1)"))
	add_parameter(GNParameter.create_int("seed", 42, 0, 99999, "Seed", "Random seed"))

	# Geometry mode
	add_parameter(GNParameter.create_float("tube_radius", 0.0, 0.0, 10.0, 0.01,
		"Tube Radius", "Radius for tube geometry (0 = line primitives)"))
	add_parameter(GNParameter.create_int("tube_sides", 6, 3, 16, "Tube Sides",
		"Cross-section polygon sides"))
	add_parameter(GNParameter.create_float("taper", 0.7, 0.01, 1.0, 0.01,
		"Taper", "Radius multiplier per depth level (branch thinning)"))

	# Gravity bend
	add_parameter(GNParameter.create_float("gravity", 0.0, -5.0, 5.0, 0.01,
		"Gravity", "Downward bend per segment (tropism)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var axiom: String = get_param_value("axiom")
	var rules: Dictionary = _parse_rules()
	var iters: int = get_param_value("iterations")
	var step: float = get_param_value("step_size")
	var angle: float = deg_to_rad(get_param_value("angle"))
	var step_scale: float = get_param_value("step_scale")
	var angle_rand: float = get_param_value("angle_rand")
	var seed_val: int = get_param_value("seed")
	var tube_r: float = get_param_value("tube_radius")
	var tube_sides: int = get_param_value("tube_sides")
	var taper: float = get_param_value("taper")
	var gravity: float = get_param_value("gravity")

	# ── Step 1: Produce string ──
	var production := axiom
	for _i in range(iters):
		production = _apply_rules(production, rules)
		if production.length() > MAX_STRING_LENGTH:
			production = production.left(MAX_STRING_LENGTH)
			break

	# ── Step 2: Turtle interpretation ──
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var segments: Array[Array] = []  # Array of [Vector3 start, Vector3 end, float radius]
	# Use a Dictionary for the turtle frame so mutations propagate (GDScript
	# passes Vector3 *by value*, but Dictionary *by reference*).
	var T: Dictionary = {
		"pos": Vector3.ZERO,
		"dir": Vector3.UP,
		"right": Vector3.RIGHT,
		"up": Vector3.FORWARD,
		"step": step,
		"radius": tube_r,
		"depth": 0
	}

	# State stack
	var stack: Array[Dictionary] = []

	for ch_idx in range(production.length()):
		var ch: String = production[ch_idx]
		var rand_offset: float = 0.0
		if angle_rand > 0.0:
			rand_offset = rng.randf_range(-angle_rand, angle_rand) * angle

		match ch:
			"F":
				var end_pos: Vector3 = T["pos"] + T["dir"] * T["step"]
				# Apply gravity tropism
				if gravity != 0.0:
					end_pos.y -= gravity * T["step"] * 0.5
					T["dir"] = (end_pos - T["pos"]).normalized()
					_recalculate_frame(T)
				segments.append([T["pos"], end_pos, T["radius"]])
				T["pos"] = end_pos
			"f":
				T["pos"] = T["pos"] + T["dir"] * T["step"]
			"+":
				_yaw(T, angle + rand_offset)
			"-":
				_yaw(T, -(angle + rand_offset))
			"^":
				_pitch(T, angle + rand_offset)
			"&":
				_pitch(T, -(angle + rand_offset))
			"\\":
				_roll(T, angle + rand_offset)
			"/":
				_roll(T, -(angle + rand_offset))
			"[":
				stack.append(T.duplicate())
				T["depth"] = T["depth"] + 1
				T["step"] = T["step"] * step_scale
				T["radius"] = T["radius"] * taper
			"]":
				if not stack.is_empty():
					var state: Dictionary = stack.pop_back()
					T["pos"] = state["pos"]
					T["dir"] = state["dir"]
					T["right"] = state["right"]
					T["up"] = state["up"]
					T["step"] = state["step"]
					T["radius"] = state["radius"]
					T["depth"] = state["depth"]
			"|":
				T["dir"] = -T["dir"]
				T["right"] = -T["right"]

	if segments.is_empty():
		return null

	# ── Step 3: Build mesh ──
	var out := _prepare_geo()

	if tube_r > 0.0:
		_build_tube_mesh(out, segments, tube_sides)
	else:
		_build_line_mesh(out, segments)

	return out


# ── Grammar helpers ────────────────────────────────────────────────────────────

func _parse_rules() -> Dictionary:
	var rules: Dictionary = {}
	for rule_key in ["rule_a", "rule_b", "rule_c"]:
		var rule_str: String = get_param_value(rule_key)
		if rule_str.is_empty():
			continue
		var parts := rule_str.split("=", false, 1)
		if parts.size() == 2:
			var symbol := parts[0].strip_edges()
			var replacement := parts[1].strip_edges()
			if symbol.length() == 1:
				rules[symbol] = replacement
	return rules


static func _apply_rules(input: String, rules: Dictionary) -> String:
	var result := ""
	for i in range(input.length()):
		var ch := input[i]
		if rules.has(ch):
			result += rules[ch]
		else:
			result += ch
		if result.length() > MAX_STRING_LENGTH:
			break
	return result


# ── Turtle frame manipulation (Dictionary passed by reference) ─────────────────

static func _yaw(T: Dictionary, a: float) -> void:
	# Rotate dir and right around up
	var cos_a := cos(a)
	var sin_a := sin(a)
	var dir: Vector3 = T["dir"]
	var right: Vector3 = T["right"]
	T["dir"] = (dir * cos_a + right * sin_a).normalized()
	T["right"] = (right * cos_a - dir * sin_a).normalized()


static func _pitch(T: Dictionary, a: float) -> void:
	var cos_a := cos(a)
	var sin_a := sin(a)
	var dir: Vector3 = T["dir"]
	var up: Vector3 = T["up"]
	T["dir"] = (dir * cos_a + up * sin_a).normalized()
	T["up"] = (up * cos_a - dir * sin_a).normalized()


static func _roll(T: Dictionary, a: float) -> void:
	var cos_a := cos(a)
	var sin_a := sin(a)
	var right: Vector3 = T["right"]
	var up: Vector3 = T["up"]
	T["right"] = (right * cos_a + up * sin_a).normalized()
	T["up"] = (up * cos_a - right * sin_a).normalized()


static func _recalculate_frame(T: Dictionary) -> void:
	var dir: Vector3 = T["dir"]
	var right: Vector3 = dir.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	T["right"] = right
	T["up"] = right.cross(dir).normalized()


# ── Mesh builders ──────────────────────────────────────────────────────────────

func _build_line_mesh(out: GNGeoData, segments: Array[Array]) -> void:
	var verts := PackedVector3Array()
	for seg in segments:
		verts.append(seg[0])
		verts.append(seg[1])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	out.set_mesh(mesh)


func _build_tube_mesh(out: GNGeoData, segments: Array[Array], sides: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for seg in segments:
		var start: Vector3 = seg[0]
		var end_pos: Vector3 = seg[1]
		var radius: float = maxf(seg[2], 0.001)

		var seg_dir: Vector3 = (end_pos - start)
		var seg_len: float = seg_dir.length()
		if seg_len < 0.0001:
			continue
		seg_dir /= seg_len

		# Build local frame
		var right := seg_dir.cross(Vector3.UP).normalized()
		if right.length_squared() < 0.001:
			right = seg_dir.cross(Vector3.RIGHT).normalized()
		var up := right.cross(seg_dir).normalized()

		# Generate ring vertices at start and end
		var ring_start := PackedVector3Array()
		var ring_end := PackedVector3Array()

		for i in range(sides):
			var angle_step: float = TAU * float(i) / float(sides)
			var offset := (right * cos(angle_step) + up * sin(angle_step)) * radius
			ring_start.append(start + offset)
			ring_end.append(end_pos + offset)

		# Connect rings with quads (as 2 triangles each)
		for i in range(sides):
			var i_next: int = (i + 1) % sides
			var s0: Vector3 = ring_start[i]
			var s1: Vector3 = ring_start[i_next]
			var e0: Vector3 = ring_end[i]
			var e1: Vector3 = ring_end[i_next]

			# Normal for each vertex
			var n0: Vector3 = (s0 - start).normalized()
			var n1: Vector3 = (s1 - start).normalized()
			var n2: Vector3 = (e0 - end_pos).normalized()
			var n3: Vector3 = (e1 - end_pos).normalized()

			# Tri 1: s0, e0, s1
			st.set_normal(n0); st.add_vertex(s0)
			st.set_normal(n2); st.add_vertex(e0)
			st.set_normal(n1); st.add_vertex(s1)

			# Tri 2: s1, e0, e1
			st.set_normal(n1); st.add_vertex(s1)
			st.set_normal(n2); st.add_vertex(e0)
			st.set_normal(n3); st.add_vertex(e1)

	st.generate_tangents()
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	out.set_mesh(mesh)
