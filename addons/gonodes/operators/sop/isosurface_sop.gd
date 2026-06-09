class_name IsoSurfaceSOP
extends GNSopBase
## IsoSurface SOP — Marching-cubes extraction of analytic implicit surfaces.
##
## Evaluates a configurable mathematical formula on a 3D voxel grid and
## extracts the iso-surface where field == threshold.  Built-in primitives
## include Gyroid, Schwarz-P, Schwarz-D, Sphere, Torus, and a Custom mode
## where the user provides an expression string (limited mini-language).
##
## Shares the marching-cubes lookup tables with MetaballSOP (static).

enum SurfaceType { GYROID, SCHWARZ_P, SCHWARZ_D, SPHERE, TORUS, CUSTOM }

# Reuse MetaballSOP marching cubes tables
# Ensure MetaballSOP class is loaded so the static tables get initialised.

func _init() -> void:
	node_type = "isosurface"
	# Guarantee marching cubes tables exist.
	if not MetaballSOP._tables_initialized:
		MetaballSOP._init_marching_cubes_tables()
		MetaballSOP._tables_initialized = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "IsoSurface mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("surface_type",
		PackedStringArray(["Gyroid", "Schwarz-P", "Schwarz-D", "Sphere", "Torus", "Custom"]),
		0, "Surface Type", "Implicit function to evaluate"))
	add_parameter(GNParameter.create_int("resolution", 40, 4, 128, "Resolution",
		"Grid subdivisions per axis"))
	add_parameter(GNParameter.create_float("bounds_size", 6.28, 0.5, 100.0, 0.5,
		"Bounds Size", "Cubic grid extent (centred at origin)"))
	add_parameter(GNParameter.create_float("threshold", 0.0, -50.0, 50.0, 0.01,
		"Threshold", "Iso value for surface extraction"))
	add_parameter(GNParameter.create_float("frequency", 1.0, 0.01, 20.0, 0.01,
		"Frequency", "Spatial frequency multiplier"))

	# Torus-specific
	add_parameter(GNParameter.create_float("major_radius", 2.0, 0.1, 50.0, 0.1,
		"Major Radius", "Torus major radius (Torus mode)"))
	add_parameter(GNParameter.create_float("minor_radius", 0.8, 0.01, 20.0, 0.05,
		"Minor Radius", "Torus minor radius (Torus mode)"))

	# Custom expression (simple mini-language: x, y, z, sin, cos, sqrt, +, -, *, /, ^)
	add_parameter(GNParameter.create_string("expression",
		"sin(x)*cos(y)+sin(y)*cos(z)+sin(z)*cos(x)",
		"Expression", "Custom implicit field formula (x, y, z)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var stype: int = get_param_value("surface_type")
	var res: int = get_param_value("resolution")
	var half_bounds: float = get_param_value("bounds_size") * 0.5
	var threshold: float = get_param_value("threshold")
	var freq: float = get_param_value("frequency")
	var major_r: float = get_param_value("major_radius")
	var minor_r: float = get_param_value("minor_radius")
	var expression_str: String = get_param_value("expression")

	var gs: int = res + 1  # grid size (number of samples per axis)
	var cell_size: float = (half_bounds * 2.0) / float(res)

	# ── Evaluate scalar field ──
	var field := PackedFloat32Array()
	field.resize(gs * gs * gs)

	var expr: Expression = null
	if stype == SurfaceType.CUSTOM:
		expr = Expression.new()
		var err := expr.parse(expression_str, PackedStringArray(["x", "y", "z"]))
		if err != OK:
			GNLogger.warn("IsoSurfaceSOP", "bad expression — %s" % expr.get_error_text())
			return null

	for iz in range(gs):
		for iy in range(gs):
			for ix in range(gs):
				var x: float = (-half_bounds + ix * cell_size) * freq
				var y: float = (-half_bounds + iy * cell_size) * freq
				var z: float = (-half_bounds + iz * cell_size) * freq
				var val: float = _evaluate_field(stype, x, y, z, major_r, minor_r, freq, expr)
				field[iz * gs * gs + iy * gs + ix] = val

	# ── Marching cubes ──
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()

	var edge_table: PackedInt32Array = MetaballSOP._mc_edge_table
	var tri_table: Array = MetaballSOP._mc_tri_table

	var offsets: Array[Vector3i] = [
		Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 0),
		Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 1, 1), Vector3i(0, 1, 1)
	]
	var edge_pairs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0),
		Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 4),
		Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)
	]

	for iz in range(res):
		for iy in range(res):
			for ix in range(res):
				# Build cube index
				var cube_idx: int = 0
				var corners := PackedVector3Array()
				corners.resize(8)
				var values := PackedFloat32Array()
				values.resize(8)
				for ci in range(8):
					var ox: int = ix + offsets[ci].x
					var oy: int = iy + offsets[ci].y
					var oz: int = iz + offsets[ci].z
					corners[ci] = Vector3(
						-half_bounds + ox * cell_size,
						-half_bounds + oy * cell_size,
						-half_bounds + oz * cell_size)
					values[ci] = field[oz * gs * gs + oy * gs + ox]
					if values[ci] >= threshold:
						cube_idx |= (1 << ci)

				if cube_idx == 0 or cube_idx == 255:
					continue

				var edge_flags: int = edge_table[cube_idx]
				var edge_verts := PackedVector3Array()
				edge_verts.resize(12)
				for ei in range(12):
					if edge_flags & (1 << ei) == 0:
						continue
					var e: Vector2i = edge_pairs[ei]
					var t: float = (threshold - values[e.x]) / (values[e.y] - values[e.x] + 0.00001)
					t = clampf(t, 0.0, 1.0)
					edge_verts[ei] = corners[e.x].lerp(corners[e.y], t)

				var tri_row: PackedInt32Array = tri_table[cube_idx]
				var ti: int = 0
				while ti < tri_row.size() and tri_row[ti] != -1:
					var v0: Vector3 = edge_verts[tri_row[ti]]
					var v1: Vector3 = edge_verts[tri_row[ti + 1]]
					var v2: Vector3 = edge_verts[tri_row[ti + 2]]

					# Finite-difference gradient for normals
					var n0 := _gradient_normal(v0, stype, freq, major_r, minor_r, expr, cell_size)
					var n1 := _gradient_normal(v1, stype, freq, major_r, minor_r, expr, cell_size)
					var n2 := _gradient_normal(v2, stype, freq, major_r, minor_r, expr, cell_size)

					verts.append(v0)
					verts.append(v1)
					verts.append(v2)
					normals.append(n0)
					normals.append(n1)
					normals.append(n2)
					ti += 3

	if verts.is_empty():
		return null

	var out := _prepare_geo()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.set_mesh(mesh)
	return out


func _evaluate_field(stype: int, x: float, y: float, z: float,
		major_r: float, minor_r: float, freq: float, expr: Expression) -> float:
	match stype:
		SurfaceType.GYROID:
			return sin(x) * cos(y) + sin(y) * cos(z) + sin(z) * cos(x)
		SurfaceType.SCHWARZ_P:
			return cos(x) + cos(y) + cos(z)
		SurfaceType.SCHWARZ_D:
			return (sin(x) * sin(y) * sin(z) +
				sin(x) * cos(y) * cos(z) +
				cos(x) * sin(y) * cos(z) +
				cos(x) * cos(y) * sin(z))
		SurfaceType.SPHERE:
			return 1.0 - (x * x + y * y + z * z)
		SurfaceType.TORUS:
			# Unscale frequency for radius calculation
			var xr: float = x / freq
			var yr: float = y / freq
			var zr: float = z / freq
			var len_xz: float = sqrt(xr * xr + zr * zr) - major_r
			return -(len_xz * len_xz + yr * yr - minor_r * minor_r)
		SurfaceType.CUSTOM:
			if expr != null:
				var result = expr.execute([x, y, z])
				if not expr.has_execute_failed():
					return float(result)
			return 0.0
	return 0.0


func _gradient_normal(p: Vector3, stype: int, freq: float,
		major_r: float, minor_r: float, expr: Expression, cell_size: float) -> Vector3:
	var eps: float = cell_size * 0.25
	# Central difference
	var dx: float = (_evaluate_field(stype, (p.x + eps) * freq, p.y * freq, p.z * freq,
			major_r, minor_r, freq, expr)
		- _evaluate_field(stype, (p.x - eps) * freq, p.y * freq, p.z * freq,
			major_r, minor_r, freq, expr))
	var dy: float = (_evaluate_field(stype, p.x * freq, (p.y + eps) * freq, p.z * freq,
			major_r, minor_r, freq, expr)
		- _evaluate_field(stype, p.x * freq, (p.y - eps) * freq, p.z * freq,
			major_r, minor_r, freq, expr))
	var dz: float = (_evaluate_field(stype, p.x * freq, p.y * freq, (p.z + eps) * freq,
			major_r, minor_r, freq, expr)
		- _evaluate_field(stype, p.x * freq, p.y * freq, (p.z - eps) * freq,
			major_r, minor_r, freq, expr))
	var grad := Vector3(dx, dy, dz)
	var len: float = grad.length()
	if len > 0.0001:
		return -grad / len
	return Vector3.UP
