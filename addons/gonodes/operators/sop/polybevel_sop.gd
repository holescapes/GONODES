class_name PolyBevelSOP
extends GNSopBase
## Bevel polygon edges by pushing vertices outward and creating chamfer faces.
##
## Operates by offsetting each vertex along the average of its adjacent face
## normals, optionally creating new geometry at the beveled edges.
##
## TouchDesigner equivalent: PolyBevel SOP.


func _init() -> void:
	node_type = "poly_bevel"
	node_description = "Bevel polygon edges with offset and rounding."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Beveled geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("offset", 0.05, 0.0, 10.0, 0.001,
		"Offset", "Bevel offset distance"))
	add_parameter(GNParameter.create_int("divisions", 1, 1, 8,
		"Divisions", "Number of subdivision steps for rounding"))
	add_parameter(GNParameter.create_float("roundness", 0.5, 0.0, 1.0, 0.01,
		"Roundness", "Blend between flat chamfer (0) and rounded bevel (1)"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return null

	var offset: float = get_param_value("offset")
	var divisions: int = get_param_value("divisions")
	var roundness: float = get_param_value("roundness")

	if offset <= 0.0:
		return in_geo

	var out_geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for surf_idx in range(in_geo.mesh.get_surface_count()):
		var arrays := in_geo.mesh.surface_get_arrays(surf_idx)
		var prim := in_geo.mesh.surface_get_primitive_type(surf_idx)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

		if verts.size() < 3 or normals.is_empty():
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		# Simple vertex-pull bevel: push each vertex inward along its normal,
		# then create chamfer quads along edges.  For multi-division, we
		# interpolate positions between original and offset positions.
		var beveled_verts := PackedVector3Array()
		var beveled_normals := PackedVector3Array()
		var beveled_indices := PackedInt32Array()

		# Create inner ring of vertices (offset toward centre)
		var inner_verts := PackedVector3Array()
		inner_verts.resize(verts.size())
		for vi in range(verts.size()):
			var n: Vector3 = normals[vi] if vi < normals.size() else Vector3.UP
			inner_verts[vi] = verts[vi] - n * offset

		if divisions <= 1:
			# Single step: original verts + inner verts + connecting quads
			beveled_verts = verts + inner_verts
			beveled_normals = normals + normals

			# Original face indices shifted to inner ring
			var vert_offset := verts.size()
			for idx in indices:
				beveled_indices.append(idx + vert_offset)

			# Connect original to inner with quads along edges
			var edges := _collect_edges(indices, verts.size())
			for edge in edges:
				var a: int = edge[0]
				var b: int = edge[1]
				var a2: int = a + vert_offset
				var b2: int = b + vert_offset
				# Two triangles per quad
				beveled_indices.append_array([a, b, b2, a, b2, a2])
		else:
			# Multi-division: interpolate rings
			var ring_count := divisions + 1
			for ring in range(ring_count):
				var t := float(ring) / float(ring_count - 1)
				# Apply roundness: slerp-like curve
				if roundness > 0.0:
					t = _smooth_step(t, roundness)
				for vi in range(verts.size()):
					beveled_verts.append(verts[vi].lerp(inner_verts[vi], t))
					beveled_normals.append(normals[vi] if vi < normals.size() else Vector3.UP)

			# Inner face uses last ring
			var last_ring_offset := (ring_count - 1) * verts.size()
			for idx in indices:
				beveled_indices.append(idx + last_ring_offset)

			# Connect rings
			for ring in range(ring_count - 1):
				var off_a := ring * verts.size()
				var off_b := (ring + 1) * verts.size()
				var edges := _collect_edges(indices, verts.size())
				for edge in edges:
					var a: int = edge[0] + off_a
					var b: int = edge[1] + off_a
					var a2: int = edge[0] + off_b
					var b2: int = edge[1] + off_b
					beveled_indices.append_array([a, b, b2, a, b2, a2])

		var out_arrays: Array = []
		out_arrays.resize(Mesh.ARRAY_MAX)
		out_arrays[Mesh.ARRAY_VERTEX] = beveled_verts
		out_arrays[Mesh.ARRAY_NORMAL] = beveled_normals
		out_arrays[Mesh.ARRAY_INDEX] = beveled_indices
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)

	out_geo.set_mesh(new_mesh)
	return out_geo


func _collect_edges(indices: PackedInt32Array, _vert_count: int) -> Array:
	var edge_set: Dictionary = {}
	var edges: Array = []
	var tri_count := indices.size() / 3
	for t in range(tri_count):
		for e in range(3):
			var a := indices[t * 3 + e]
			var b := indices[t * 3 + ((e + 1) % 3)]
			var key := mini(a, b) * 1000000 + maxi(a, b)
			if not edge_set.has(key):
				edge_set[key] = true
				edges.append([mini(a, b), maxi(a, b)])
	return edges


func _smooth_step(t: float, roundness: float) -> float:
	# Hermite smooth step interpolation blended by roundness
	var smooth := t * t * (3.0 - 2.0 * t)
	return lerpf(t, smooth, roundness)
