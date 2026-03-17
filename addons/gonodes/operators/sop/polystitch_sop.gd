class_name PolyStitchSOP
extends GNSopBase
## Stitch two polygon boundaries together by connecting closest vertex pairs.
##
## Takes two SOP inputs and creates triangle strips connecting their
## nearest boundary vertices.  Useful for joining separate mesh pieces
## into a single continuous surface.
##
## TouchDesigner equivalent: PolyStitch SOP.


func _init() -> void:
	node_type = "polystitch"
	node_description = "Stitch polygon boundaries by connecting nearest vertices."


func _init_ports() -> void:
	add_input("geo_a", GNFamily.Type.SOP, false, "First boundary geometry", "Geometry A")
	add_input("geo_b", GNFamily.Type.SOP, false, "Second boundary geometry", "Geometry B")
	add_output("out", GNFamily.Type.SOP, "Stitched geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("max_distance", 1.0, 0.0, 100.0, 0.01,
		"Max Distance", "Maximum distance for vertex pairing (0 = unlimited)"))
	add_parameter(GNParameter.create_bool("include_inputs", true,
		"Include Inputs", "Include original geometry in output"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_a := _get_input_sop(inputs, 0)
	var geo_b := _get_input_sop(inputs, 1)
	if geo_a == null or geo_b == null:
		return null
	if not geo_a.has_geometry() or not geo_b.has_geometry():
		return null

	var max_dist: float = get_param_value("max_distance")
	var include_inputs: bool = get_param_value("include_inputs")

	var pts_a := geo_a.get_positions()
	var pts_b := geo_b.get_positions()
	if pts_a.is_empty() or pts_b.is_empty():
		return null

	# Find nearest pairs from A to B
	var pairs: Array[Array] = []
	for i in range(pts_a.size()):
		var best_j := -1
		var best_d := INF
		for j in range(pts_b.size()):
			var d := pts_a[i].distance_to(pts_b[j])
			if d < best_d:
				best_d = d
				best_j = j
		if max_dist <= 0.0 or best_d <= max_dist:
			pairs.append([i, best_j, best_d])

	if pairs.is_empty():
		return null

	# Sort pairs by index for consistent stitching
	pairs.sort_custom(func(a, b): return a[0] < b[0])

	# Build stitch geometry
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for pi in range(pairs.size() - 1):
		var a0 := pts_a[pairs[pi][0]]
		var b0 := pts_b[pairs[pi][1]]
		var a1 := pts_a[pairs[pi + 1][0]]
		var b1 := pts_b[pairs[pi + 1][1]]

		var n := (b0 - a0).cross(a1 - a0).normalized()
		st.set_normal(n)
		st.add_vertex(a0)
		st.set_normal(n)
		st.add_vertex(b0)
		st.set_normal(n)
		st.add_vertex(b1)

		st.set_normal(n)
		st.add_vertex(a0)
		st.set_normal(n)
		st.add_vertex(b1)
		st.set_normal(n)
		st.add_vertex(a1)

	var out_geo := _prepare_geo()

	if include_inputs:
		# Merge input meshes + stitch into output
		var combined := ArrayMesh.new()
		for s in range(geo_a.mesh.get_surface_count()):
			var arr := geo_a.mesh.surface_get_arrays(s)
			var p := geo_a.mesh.surface_get_primitive_type(s)
			combined.add_surface_from_arrays(p, arr)
		for s in range(geo_b.mesh.get_surface_count()):
			var arr := geo_b.mesh.surface_get_arrays(s)
			var p := geo_b.mesh.surface_get_primitive_type(s)
			combined.add_surface_from_arrays(p, arr)
		var stitch_mesh := st.commit()
		for s in range(stitch_mesh.get_surface_count()):
			var arr := stitch_mesh.surface_get_arrays(s)
			combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out_geo.set_mesh(combined)
	else:
		out_geo.set_from_surface_tool(st)

	return out_geo
