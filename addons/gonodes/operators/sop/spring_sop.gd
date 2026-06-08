class_name SpringSOP
extends GNSopBase
## Spring-based vertex deformer.
##
## Each vertex maintains an internal spring state (position + velocity).
## The input geometry provides the target (rest) positions; vertices
## spring toward those targets using damped harmonic oscillation.
##
## Useful for "jelly" follow effects, soft deformation, and lag-based
## vertex animation.  Similar to SpringCHOP but operates on SOP geometry.

# Per-vertex spring state — indexed by vertex index
var _positions: PackedVector3Array = PackedVector3Array()
var _velocities: PackedVector3Array = PackedVector3Array()
var _initialized: bool = false


func _init() -> void:
	node_type = "spring"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Target geometry (rest positions)", "In")
	add_output("out", GNFamily.Type.SOP, "Spring-deformed geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("stiffness", 20.0, 0.1, 500.0, 0.1,
		"Stiffness (k)", "Spring constant — higher = snappier"))
	add_parameter(GNParameter.create_float("damping", 4.0, 0.0, 50.0, 0.1,
		"Damping (c)", "Damping coefficient — higher = less overshoot"))
	add_parameter(GNParameter.create_float("mass", 1.0, 0.01, 10.0, 0.01,
		"Mass", "Vertex mass — higher = slower response"))
	add_parameter(GNParameter.create_bool("reset", false, "Reset", "Reset spring state"))
	add_parameter(GNParameter.create_float("max_displacement", 10.0, 0.01, 100.0, 0.01,
		"Max Disp.", "Clamp maximum displacement from target (safety)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_in: GNGeoData = _require_input_geo(inputs)
	if geo_in == null:
		return null

	var k: float = get_param_value("stiffness")
	var c: float = get_param_value("damping")
	var m: float = maxf(get_param_value("mass"), 0.01)
	var do_reset: bool = get_param_value("reset")
	var max_disp: float = get_param_value("max_displacement")

	var dt: float = current_delta
	if dt <= 0.0:
		dt = 1.0 / 60.0

	# Get target positions from input geometry
	var target_positions: PackedVector3Array = geo_in.get_positions()
	if target_positions.is_empty():
		return geo_in

	var vtx_count: int = target_positions.size()

	# Reset or resize spring state
	if do_reset or not _initialized or _positions.size() != vtx_count:
		_positions = target_positions.duplicate()
		_velocities.resize(vtx_count)
		_velocities.fill(Vector3.ZERO)
		_initialized = true
		# On first frame / reset, just pass through target positions
		if do_reset:
			return geo_in

	# Semi-implicit Euler integration per vertex
	for i in range(vtx_count):
		var target: Vector3 = target_positions[i]
		var pos: Vector3 = _positions[i]
		var vel: Vector3 = _velocities[i]

		var displacement: Vector3 = pos - target
		var force: Vector3 = -k * displacement - c * vel
		var accel: Vector3 = force / m

		vel += accel * dt
		pos += vel * dt

		# Clamp displacement for stability
		var disp: Vector3 = pos - target
		if disp.length() > max_disp:
			pos = target + disp.normalized() * max_disp
			vel *= 0.5  # Dampen on clamp

		_positions[i] = pos
		_velocities[i] = vel

	# Build output geometry with deformed positions
	var geo_out: GNGeoData = _prepare_geo()

	# Copy surface arrays from input and replace positions
	for surface_idx in range(geo_in.get_surface_count()):
		var arrays: Array = geo_in.get_surface_arrays(surface_idx)
		if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var out_verts := PackedVector3Array()
			out_verts.resize(src_verts.size())
			# Map from surface vertex positions to our spring-deformed positions
			# Since get_positions() returns surface 0 verts, we match by index
			if surface_idx == 0:
				for j in range(mini(src_verts.size(), vtx_count)):
					out_verts[j] = _positions[j]
				# If mesh has more verts than tracked, pass through
				for j in range(vtx_count, src_verts.size()):
					out_verts[j] = src_verts[j]
			else:
				out_verts = src_verts
			arrays[Mesh.ARRAY_VERTEX] = out_verts
			# Recalculate normals from deformed positions if normals exist
			if arrays.size() > Mesh.ARRAY_NORMAL and arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
				arrays[Mesh.ARRAY_NORMAL] = _recalc_normals(out_verts, arrays)
		geo_out.set_surface_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Copy point attributes
	for attrib_name: String in geo_in.point_attribs:
		geo_out.set_point_attrib(attrib_name, geo_in.get_point_attrib(attrib_name))

	geo_out.transform = geo_in.transform
	return geo_out


func _recalc_normals(verts: PackedVector3Array, arrays: Array) -> PackedVector3Array:
	# Use SurfaceTool for normal recalculation if we have indices
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)

	if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		# Per-face normal accumulation
		var tri_count: int = indices.size() / 3
		for t in range(tri_count):
			var i0: int = indices[t * 3]
			var i1: int = indices[t * 3 + 1]
			var i2: int = indices[t * 3 + 2]
			if i0 < verts.size() and i1 < verts.size() and i2 < verts.size():
				var face_normal: Vector3 = (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
				normals[i0] += face_normal
				normals[i1] += face_normal
				normals[i2] += face_normal
		for i in range(normals.size()):
			if normals[i].length_squared() > 0.0:
				normals[i] = normals[i].normalized()
	else:
		# No index buffer — process as sequential triangles
		var tri_count: int = verts.size() / 3
		for t in range(tri_count):
			var i0: int = t * 3
			var i1: int = t * 3 + 1
			var i2: int = t * 3 + 2
			var face_normal: Vector3 = (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]).normalized()
			normals[i0] = face_normal
			normals[i1] = face_normal
			normals[i2] = face_normal
	return normals
