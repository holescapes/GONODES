class_name PolyLoftSOP
extends GNSopBase
## Loft a polygon surface between two or more cross-section inputs.
##
## Each SOP input provides a cross-section ring (ordered vertices).
## The loft connects corresponding vertices between successive sections
## to form a quad strip mesh, then triangulates.
##
## If only one input is connected, the second section is generated
## by translating it along the loft_axis by loft_distance.

func _init() -> void:
	node_type = "poly_loft"
	node_description = "Loft polygon surface between cross-section rings."


func _init_ports() -> void:
	add_input("section1", GNFamily.Type.SOP, false, "First cross-section")
	add_input("section2", GNFamily.Type.SOP, false, "Second cross-section (optional)")
	add_output("out", GNFamily.Type.SOP, "Lofted surface")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("loft_distance", 1.0, 0.0, 100.0, 0.01,
		"Loft Distance", "Distance for auto-generated second section"))
	add_parameter(GNParameter.create_enum("loft_axis",
		PackedStringArray(["Y", "X", "Z"]), 0, "Axis", "Auto-loft translation axis"))
	add_parameter(GNParameter.create_int("subdivisions", 1, 1, 64,
		"Subdivisions", "Intermediate cross-sections to interpolate"))
	add_parameter(GNParameter.create_bool("close_caps", false,
		"Close Caps", "Cap the ends of the lofted surface"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo1: GNGeoData = _require_input_geo(inputs)
	if geo1 == null:
		return null

	var loft_dist: float = get_param_value("loft_distance")
	var axis_idx: int = get_param_value("loft_axis")
	var subdivs: int = get_param_value("subdivisions")
	var caps: bool = get_param_value("close_caps")

	# Extract cross-section rings
	var ring1: PackedVector3Array = _extract_ring(geo1)
	if ring1.is_empty():
		return null

	var ring2: PackedVector3Array
	if inputs.size() > 1 and inputs[1] is GNGeoData:
		ring2 = _extract_ring(inputs[1] as GNGeoData)
	else:
		# Generate second ring by translating
		var offset := Vector3.ZERO
		match axis_idx:
			0: offset = Vector3(0, loft_dist, 0)
			1: offset = Vector3(loft_dist, 0, 0)
			2: offset = Vector3(0, 0, loft_dist)
		ring2 = PackedVector3Array()
		for p: Vector3 in ring1:
			ring2.append(p + offset)

	if ring2.is_empty():
		return null

	# Match vertex counts — resample shorter ring
	if ring1.size() != ring2.size():
		var target_count: int = maxi(ring1.size(), ring2.size())
		ring1 = _resample_ring(ring1, target_count)
		ring2 = _resample_ring(ring2, target_count)

	# Build intermediate sections via linear interpolation
	var sections: Array[PackedVector3Array] = []
	sections.append(ring1)
	for s in range(1, subdivs):
		var t: float = float(s) / float(subdivs)
		var mid_ring := PackedVector3Array()
		for i in range(ring1.size()):
			mid_ring.append(ring1[i].lerp(ring2[i], t))
		sections.append(mid_ring)
	sections.append(ring2)

	# Build mesh from sections
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts_per_ring: int = ring1.size()

	for s in range(sections.size() - 1):
		var cur: PackedVector3Array = sections[s]
		var nxt: PackedVector3Array = sections[s + 1]
		var v_cur: float = float(s) / float(sections.size() - 1)
		var v_nxt: float = float(s + 1) / float(sections.size() - 1)

		for i in range(verts_per_ring):
			var i_next: int = (i + 1) % verts_per_ring
			var a: Vector3 = cur[i]
			var b: Vector3 = cur[i_next]
			var c: Vector3 = nxt[i_next]
			var d: Vector3 = nxt[i]

			var u0: float = float(i) / float(verts_per_ring)
			var u1: float = float(i + 1) / float(verts_per_ring)

			# Quad as two triangles: a-b-c, a-c-d
			var normal: Vector3 = (b - a).cross(d - a).normalized()

			st.set_normal(normal)
			st.set_uv(Vector2(u0, v_cur))
			st.add_vertex(a)
			st.set_normal(normal)
			st.set_uv(Vector2(u1, v_cur))
			st.add_vertex(b)
			st.set_normal(normal)
			st.set_uv(Vector2(u1, v_nxt))
			st.add_vertex(c)

			st.set_normal(normal)
			st.set_uv(Vector2(u0, v_cur))
			st.add_vertex(a)
			st.set_normal(normal)
			st.set_uv(Vector2(u1, v_nxt))
			st.add_vertex(c)
			st.set_normal(normal)
			st.set_uv(Vector2(u0, v_nxt))
			st.add_vertex(d)

	# Cap ends with triangle fans
	if caps:
		_cap_ring(st, sections[0], false)
		_cap_ring(st, sections[sections.size() - 1], true)

	st.generate_normals()
	var output: GNGeoData = _prepare_geo()
	output.set_from_surface_tool(st)
	return output


## Extracts ordered vertex ring from the first surface of a GNGeoData.
func _extract_ring(geo: GNGeoData) -> PackedVector3Array:
	for surf_idx in range(geo.get_surface_count()):
		var arrays: Array = geo.get_surface_arrays(surf_idx)
		if arrays.is_empty():
			continue
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if positions.size() >= 3:
			return positions
	return PackedVector3Array()


## Resample a vertex ring to a target count via linear interpolation.
func _resample_ring(ring: PackedVector3Array, target: int) -> PackedVector3Array:
	if ring.size() == target:
		return ring
	var result := PackedVector3Array()
	result.resize(target)
	var src_len: float = float(ring.size())
	for i in range(target):
		var t: float = float(i) / float(target) * src_len
		var lo: int = clampi(int(t), 0, ring.size() - 1)
		var hi: int = clampi(lo + 1, 0, ring.size() - 1)
		var frac: float = t - float(lo)
		result[i] = ring[lo].lerp(ring[hi], frac)
	return result


## Cap a ring with a triangle fan from its centroid.
func _cap_ring(st: SurfaceTool, ring: PackedVector3Array, flip: bool) -> void:
	var centroid := Vector3.ZERO
	for p: Vector3 in ring:
		centroid += p
	centroid /= float(ring.size())

	var normal: Vector3 = (ring[1] - ring[0]).cross(centroid - ring[0]).normalized()
	if flip:
		normal = -normal

	for i in range(ring.size()):
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % ring.size()]
		if flip:
			st.set_normal(normal)
			st.add_vertex(centroid)
			st.set_normal(normal)
			st.add_vertex(b)
			st.set_normal(normal)
			st.add_vertex(a)
		else:
			st.set_normal(normal)
			st.add_vertex(a)
			st.set_normal(normal)
			st.add_vertex(b)
			st.set_normal(normal)
			st.add_vertex(centroid)
