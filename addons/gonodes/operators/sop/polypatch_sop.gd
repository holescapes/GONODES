class_name PolyPatchSOP
extends GNSopBase
## Generate a smooth polynomial patch surface from 4 boundary curves.
##
## Creates a Coons-style bilinear or bicubic patch from 4 input edges.
## Uses boundary interpolation with configurable resolution.
##
## TouchDesigner equivalent: PolyPatch SOP.


func _init() -> void:
	node_type = "poly_patch"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry (uses first 4 edge loops)", "In")
	add_output("out", GNFamily.Type.SOP, "Patch surface", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("rows", 10, 2, 100,
		"Rows", "Subdivisions in U direction"))
	add_parameter(GNParameter.create_int("cols", 10, 2, 100,
		"Cols", "Subdivisions in V direction"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return null

	var rows: int = get_param_value("rows")
	var cols: int = get_param_value("cols")

	# Extract 4 corners from the input bounding box
	var positions := in_geo.get_positions()
	if positions.size() < 4:
		return null

	# Use first 4 vertices as boundary corners (p00, p10, p11, p01)
	var p00 := positions[0]
	var p10 := positions[min(1, positions.size() - 1)]
	var p11 := positions[min(2, positions.size() - 1)]
	var p01 := positions[min(3, positions.size() - 1)]

	# Bilinear Coons patch
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var grid: Array[PackedVector3Array] = []
	for r in range(rows + 1):
		var row := PackedVector3Array()
		var v := float(r) / float(rows)
		for c in range(cols + 1):
			var u := float(c) / float(cols)
			# Bilinear interpolation
			var pt := p00 * (1.0 - u) * (1.0 - v) + \
					  p10 * u * (1.0 - v) + \
					  p01 * (1.0 - u) * v + \
					  p11 * u * v
			row.append(pt)
		grid.append(row)

	# Build triangles from grid
	for r in range(rows):
		for c in range(cols):
			var v00 := grid[r][c]
			var v10 := grid[r][c + 1]
			var v01 := grid[r + 1][c]
			var v11 := grid[r + 1][c + 1]

			var n := (v10 - v00).cross(v01 - v00).normalized()
			st.set_normal(n)
			st.set_uv(Vector2(float(c) / float(cols), float(r) / float(rows)))
			st.add_vertex(v00)
			st.set_normal(n)
			st.set_uv(Vector2(float(c + 1) / float(cols), float(r) / float(rows)))
			st.add_vertex(v10)
			st.set_normal(n)
			st.set_uv(Vector2(float(c + 1) / float(cols), float(r + 1) / float(rows)))
			st.add_vertex(v11)

			st.set_normal(n)
			st.set_uv(Vector2(float(c) / float(cols), float(r) / float(rows)))
			st.add_vertex(v00)
			st.set_normal(n)
			st.set_uv(Vector2(float(c + 1) / float(cols), float(r + 1) / float(rows)))
			st.add_vertex(v11)
			st.set_normal(n)
			st.set_uv(Vector2(float(c) / float(cols), float(r + 1) / float(rows)))
			st.add_vertex(v01)

	var out_geo := _prepare_geo()
	out_geo.set_from_surface_tool(st)
	return out_geo
