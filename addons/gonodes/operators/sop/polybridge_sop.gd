class_name PolyBridgeSOP
extends GNSopBase
## Bridge two polygon edge loops with connecting geometry.
##
## Takes two SOP inputs and creates polygon strips connecting their
## boundary edges.  The bridge is built by pairing vertices from
## each boundary in order (closest-first matching).
##
## TouchDesigner equivalent: PolyBridge SOP.


func _init() -> void:
	node_type = "polybridge"


func _init_ports() -> void:
	add_input("geo_a", GNFamily.Type.SOP, false, "First boundary geometry", "Geometry A")
	add_input("geo_b", GNFamily.Type.SOP, false, "Second boundary geometry", "Geometry B")
	add_output("out", GNFamily.Type.SOP, "Bridged geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("divisions", 1, 1, 16,
		"Divisions", "Subdivision steps along the bridge"))
	add_parameter(GNParameter.create_float("twist", 0.0, -360.0, 360.0, 1.0,
		"Twist", "Twist angle (degrees) applied along the bridge"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_a := _get_input_sop(inputs, 0)
	var geo_b := _get_input_sop(inputs, 1)
	if geo_a == null or geo_b == null:
		return null
	if not geo_a.has_geometry() or not geo_b.has_geometry():
		return null

	var divisions: int = get_param_value("divisions")
	var twist: float = deg_to_rad(get_param_value("twist"))

	# Extract boundary points from each input
	var pts_a := _extract_boundary(geo_a)
	var pts_b := _extract_boundary(geo_b)

	if pts_a.is_empty() or pts_b.is_empty():
		return null

	# Match vertex counts by resampling the shorter
	var count := maxi(pts_a.size(), pts_b.size())
	pts_a = _resample_ring(pts_a, count)
	pts_b = _resample_ring(pts_b, count)

	# Build bridge geometry
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for div in range(divisions):
		var t0 := float(div) / float(divisions)
		var t1 := float(div + 1) / float(divisions)
		var twist0 := twist * t0
		var twist1 := twist * t1

		for i in range(count):
			var i_next := (i + 1) % count
			var a0 := pts_a[i].lerp(pts_b[i], t0)
			var a1 := pts_a[i_next].lerp(pts_b[i_next], t0)
			var b0 := pts_a[i].lerp(pts_b[i], t1)
			var b1 := pts_a[i_next].lerp(pts_b[i_next], t1)

			# Apply twist around bridge axis
			if absf(twist) > 0.001:
				var center_0 := (a0 + a1) * 0.5
				var center_1 := (b0 + b1) * 0.5
				a0 = _rotate_around(a0, center_0, Vector3.UP, twist0)
				a1 = _rotate_around(a1, center_0, Vector3.UP, twist0)
				b0 = _rotate_around(b0, center_1, Vector3.UP, twist1)
				b1 = _rotate_around(b1, center_1, Vector3.UP, twist1)

			var normal := (b0 - a0).cross(a1 - a0).normalized()
			st.set_normal(normal)
			st.add_vertex(a0)
			st.set_normal(normal)
			st.add_vertex(a1)
			st.set_normal(normal)
			st.add_vertex(b1)

			st.set_normal(normal)
			st.add_vertex(a0)
			st.set_normal(normal)
			st.add_vertex(b1)
			st.set_normal(normal)
			st.add_vertex(b0)

	var out_geo := _prepare_geo()
	out_geo.set_from_surface_tool(st)
	return out_geo


func _extract_boundary(geo: GNGeoData) -> PackedVector3Array:
	var positions := geo.get_positions()
	if positions.is_empty():
		return PackedVector3Array()
	# Simple: use all vertices as the boundary ring
	# A proper implementation would find boundary edges
	return positions


func _resample_ring(pts: PackedVector3Array, target_count: int) -> PackedVector3Array:
	if pts.size() == target_count:
		return pts
	var result := PackedVector3Array()
	result.resize(target_count)
	for i in range(target_count):
		var t := float(i) / float(target_count)
		var idx_f := t * float(pts.size())
		var idx0 := clampi(int(idx_f), 0, pts.size() - 1)
		var idx1 := clampi(idx0 + 1, 0, pts.size() - 1)
		var frac := idx_f - float(idx0)
		result[i] = pts[idx0].lerp(pts[idx1], frac)
	return result


func _rotate_around(point: Vector3, center: Vector3, axis: Vector3, angle: float) -> Vector3:
	var local := point - center
	local = local.rotated(axis.normalized(), angle)
	return center + local
