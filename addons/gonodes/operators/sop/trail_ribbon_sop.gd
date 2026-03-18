class_name TrailRibbonSOP
extends GNSopBase
## Builds ribbon/tube geometry from POP particle trails.
## Records particle positions each frame into a ring buffer, then
## generates triangle-strip ribbon geometry with proper normals,
## UVs, and alpha fade along the trail.

var _trail_buffer: PackedVector3Array = PackedVector3Array()  # flat: [p0_slot0, p0_slot1, ..., p1_slot0, ...]
var _write_idx: int = 0
var _filled: bool = false
var _last_max_particles: int = 0
var _last_trail_length: int = 0


func _init() -> void:
	node_type = "trailribbon"
	time_dependent = true
	node_description = "Build ribbon mesh from particle trails."


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input", "Pop")
	add_output("out", GNFamily.Type.SOP, "Ribbon mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("trail_length", 30, 2, 300,
		"Trail Length", "Frames of trail history per particle"))
	add_parameter(GNParameter.create_float("width", 0.1, 0.001, 10.0, 0.001,
		"Width", "Ribbon half-width"))
	add_parameter(GNParameter.create_float("taper", 0.8, 0.0, 1.0, 0.01,
		"Taper", "Width taper along trail (0 = uniform, 1 = full taper)"))
	add_parameter(GNParameter.create_int("max_particles", 1000, 1, 100000,
		"Max Particles", "Maximum particles to generate ribbons for"))
	add_parameter(GNParameter.create_bool("fade_alpha", true,
		"Fade Alpha", "Fade alpha along trail (old = transparent, new = opaque)"))
	add_parameter(GNParameter.create_bool("active", true,
		"Active", "Record new positions each frame"))


func _cook(inputs: Array[GNData]) -> GNData:
	# Accept POP data from input
	var pd: GNParticleData = null
	if inputs.size() > 0 and inputs[0] is GNParticleData:
		pd = inputs[0] as GNParticleData
	if pd == null or not pd.has_particles():
		return null

	var out := _prepare_geo()
	var trail_len: int = get_param_value("trail_length")
	var width: float = get_param_value("width")
	var taper: float = get_param_value("taper")
	var max_p: int = mini(get_param_value("max_particles"), pd.particle_count)
	var fade: bool = get_param_value("fade_alpha")
	var active: bool = get_param_value("active")

	# Read particle positions (GPU readback if needed)
	var positions := PackedVector3Array()
	var colors := PackedColorArray()
	var ages := PackedFloat32Array()
	var lives := PackedFloat32Array()

	if pd.is_cpu:
		for i in range(max_p):
			positions.append(pd.cpu_positions[i])
			colors.append(pd.cpu_colors[i])
			ages.append(pd.cpu_ages[i])
			lives.append(pd.cpu_lives[i])
	else:
		# GPU readback
		var ctx := GNGpuContext.get_context()
		var byte_count: int = max_p * pd.stride
		var raw: PackedByteArray = ctx.read_buffer(pd.rd_buffer, byte_count)
		positions.resize(max_p)
		colors.resize(max_p)
		ages.resize(max_p)
		lives.resize(max_p)
		for i in range(max_p):
			var base: int = i * pd.stride
			positions[i] = Vector3(
				raw.decode_float(base), raw.decode_float(base + 4), raw.decode_float(base + 8))
			colors[i] = Color(
				raw.decode_float(base + 32), raw.decode_float(base + 36),
				raw.decode_float(base + 40), raw.decode_float(base + 44))
			ages[i] = raw.decode_float(base + 48)
			lives[i] = raw.decode_float(base + 52)

	# Resize trail buffer if params changed
	if max_p != _last_max_particles or trail_len != _last_trail_length:
		_trail_buffer.resize(max_p * trail_len)
		_trail_buffer.fill(Vector3(0.0, -99999.0, 0.0))  # sentinel
		_write_idx = 0
		_filled = false
		_last_max_particles = max_p
		_last_trail_length = trail_len

	# Record current positions
	if active:
		for i in range(max_p):
			if ages[i] < lives[i]:
				_trail_buffer[i * trail_len + _write_idx] = positions[i]
			else:
				_trail_buffer[i * trail_len + _write_idx] = Vector3(0.0, -99999.0, 0.0)

		_write_idx = (_write_idx + 1) % trail_len
		if _write_idx == 0:
			_filled = true

	# Build ribbon mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var up := Vector3.UP

	for pi in range(max_p):
		if ages[pi] >= lives[pi]:
			continue

		var base: int = pi * trail_len
		var start_slot: int = _write_idx if _filled else 0
		var total_slots: int = trail_len if _filled else _write_idx

		# Collect valid trail points in chronological order
		var points := PackedVector3Array()
		for si in range(total_slots):
			var slot: int = (start_slot + si) % trail_len
			var p: Vector3 = _trail_buffer[base + slot]
			if p.y > -99000.0:
				points.append(p)

		if points.size() < 2:
			continue

		# Build ribbon strip for this particle
		var pc: Color = colors[pi]
		var prev_left := Vector3.ZERO
		var prev_right := Vector3.ZERO
		var prev_valid: bool = false

		for vi in range(points.size()):
			var t: float = float(vi) / float(points.size() - 1)
			var w: float = width * lerpf(1.0 - taper, 1.0, t)

			# Tangent from neighbors
			var tangent: Vector3
			if vi == 0:
				tangent = (points[1] - points[0]).normalized()
			elif vi == points.size() - 1:
				tangent = (points[vi] - points[vi - 1]).normalized()
			else:
				tangent = (points[vi + 1] - points[vi - 1]).normalized()

			if tangent.length_squared() < 0.0001:
				tangent = Vector3.FORWARD

			# Side vector perpendicular to tangent
			var side: Vector3 = tangent.cross(up)
			if side.length_squared() < 0.001:
				side = tangent.cross(Vector3.RIGHT)
			side = side.normalized()

			var normal: Vector3 = tangent.cross(side).normalized()

			var left: Vector3 = points[vi] - side * w
			var right: Vector3 = points[vi] + side * w

			var alpha: float = t if fade else 1.0
			var col := Color(pc.r, pc.g, pc.b, pc.a * alpha)
			var uv_v: float = t

			if prev_valid:
				# Emit two triangles for the quad
				# Triangle 1: prev_left, left, prev_right
				st.set_normal(normal)
				st.set_color(Color(pc.r, pc.g, pc.b, pc.a * (float(vi - 1) / float(points.size() - 1) if fade else 1.0)))
				st.set_uv(Vector2(0.0, uv_v - 1.0 / float(points.size() - 1)))
				st.add_vertex(prev_left)

				st.set_normal(normal)
				st.set_color(col)
				st.set_uv(Vector2(0.0, uv_v))
				st.add_vertex(left)

				st.set_normal(normal)
				st.set_color(Color(pc.r, pc.g, pc.b, pc.a * (float(vi - 1) / float(points.size() - 1) if fade else 1.0)))
				st.set_uv(Vector2(1.0, uv_v - 1.0 / float(points.size() - 1)))
				st.add_vertex(prev_right)

				# Triangle 2: prev_right, left, right
				st.set_normal(normal)
				st.set_color(Color(pc.r, pc.g, pc.b, pc.a * (float(vi - 1) / float(points.size() - 1) if fade else 1.0)))
				st.set_uv(Vector2(1.0, uv_v - 1.0 / float(points.size() - 1)))
				st.add_vertex(prev_right)

				st.set_normal(normal)
				st.set_color(col)
				st.set_uv(Vector2(0.0, uv_v))
				st.add_vertex(left)

				st.set_normal(normal)
				st.set_color(col)
				st.set_uv(Vector2(1.0, uv_v))
				st.add_vertex(right)

			prev_left = left
			prev_right = right
			prev_valid = true

	var arr_mesh := ArrayMesh.new()
	st.commit(arr_mesh)
	if arr_mesh.get_surface_count() > 0:
		out.set_mesh(arr_mesh)
	return out
