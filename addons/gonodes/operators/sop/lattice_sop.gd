class_name LatticeSOP
extends GNSopBase
## Free-form deformation (FFD) via a cubic lattice.
##
## Maps each vertex into the unit cube of a control-point lattice,
## then displaces it using trilinear (or Bézier) interpolation of
## the deformed control-point positions.
##
## Input 0: geometry to deform
## The lattice is generated internally with configurable divisions.
## Each control point can be displaced via the deform_amplitude parameter
## combined with a noise pattern (for easy "organic" FFD without manual editing).

func _init() -> void:
	node_type = "lattice"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Geometry to deform", "In")
	add_output("out", GNFamily.Type.SOP, "Deformed geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("div_x", 2, 2, 8, "Divisions X", "Lattice divisions along X"))
	add_parameter(GNParameter.create_int("div_y", 2, 2, 8, "Divisions Y", "Lattice divisions along Y"))
	add_parameter(GNParameter.create_int("div_z", 2, 2, 8, "Divisions Z", "Lattice divisions along Z"))
	add_parameter(GNParameter.create_float("amplitude", 0.0, 0.0, 10.0, 0.01,
		"Deform Amplitude", "Noise displacement strength applied to lattice control points"))
	add_parameter(GNParameter.create_float("frequency", 1.0, 0.01, 20.0, 0.01,
		"Noise Frequency", "Spatial frequency of noise applied to control points"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 9999, "Seed", "Random seed for noise"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo: GNGeoData = _require_input_geo(inputs)
	if geo == null:
		return null

	var dx: int = get_param_value("div_x")
	var dy: int = get_param_value("div_y")
	var dz: int = get_param_value("div_z")
	var amp: float = get_param_value("amplitude")
	var freq: float = get_param_value("frequency")
	var noise_seed: int = get_param_value("seed")

	# Compute bounding box of input geometry
	var aabb := _compute_aabb(geo)
	var origin: Vector3 = aabb.position
	var extent: Vector3 = aabb.size
	# Avoid division by zero
	if extent.x < 1e-6:
		extent.x = 1.0
	if extent.y < 1e-6:
		extent.y = 1.0
	if extent.z < 1e-6:
		extent.z = 1.0

	# Build lattice control points (rest + deformed)
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = freq

	# Control points: (dx+1)*(dy+1)*(dz+1)
	var cp_rest: Array[Vector3] = []
	var cp_def: Array[Vector3] = []
	for iz in range(dz + 1):
		for iy in range(dy + 1):
			for ix in range(dx + 1):
				var uv := Vector3(
					float(ix) / float(dx),
					float(iy) / float(dy),
					float(iz) / float(dz))
				var rest_pos: Vector3 = origin + extent * uv
				cp_rest.append(rest_pos)
				var disp := Vector3.ZERO
				if amp > 0.0:
					disp.x = noise.get_noise_3d(rest_pos.x * 100.0, rest_pos.y * 100.0, rest_pos.z * 100.0) * amp
					disp.y = noise.get_noise_3d(rest_pos.x * 100.0 + 1000.0, rest_pos.y * 100.0, rest_pos.z * 100.0) * amp
					disp.z = noise.get_noise_3d(rest_pos.x * 100.0, rest_pos.y * 100.0 + 1000.0, rest_pos.z * 100.0) * amp
				cp_def.append(rest_pos + disp)

	# Deform each vertex using trilinear interpolation
	var output: GNGeoData = _prepare_geo()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for surf_idx in range(geo.get_surface_count()):
		var arrays: Array = geo.get_surface_arrays(surf_idx)
		if arrays.is_empty():
			continue
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]
		var indices = arrays[Mesh.ARRAY_INDEX]

		for i in range(positions.size()):
			# Map vertex to unit lattice coords
			var p: Vector3 = positions[i]
			var u: float = clampf((p.x - origin.x) / extent.x, 0.0, 1.0)
			var v: float = clampf((p.y - origin.y) / extent.y, 0.0, 1.0)
			var w: float = clampf((p.z - origin.z) / extent.z, 0.0, 1.0)

			# Cell indices
			var ix: int = mini(int(u * dx), dx - 1)
			var iy: int = mini(int(v * dy), dy - 1)
			var iz: int = mini(int(w * dz), dz - 1)

			# Local coords within cell [0..1]
			var lx: float = clampf(u * dx - ix, 0.0, 1.0)
			var ly: float = clampf(v * dy - iy, 0.0, 1.0)
			var lz: float = clampf(w * dz - iz, 0.0, 1.0)

			# Trilinear interpolation of deformed control points
			var new_pos: Vector3 = _trilinear(cp_def, dx, dy, dz, ix, iy, iz, lx, ly, lz)

			if normals != null and i < normals.size():
				st.set_normal(normals[i])
			if uvs != null and i < uvs.size():
				st.set_uv(uvs[i])
			st.add_vertex(new_pos)

	st.generate_normals()
	output.set_from_surface_tool(st)
	return output


## Trilinear interpolation between 8 corner control points of a lattice cell.
func _trilinear(cp: Array[Vector3], dx: int, dy: int, _dz: int,
		ix: int, iy: int, iz: int, lx: float, ly: float, lz: float) -> Vector3:
	var sx: int = dx + 1
	var sy: int = dy + 1
	# Helper to get control point index
	# index = iz * (sy * sx) + iy * sx + ix
	var c000: Vector3 = cp[iz * (sy * sx) + iy * sx + ix]
	var c100: Vector3 = cp[iz * (sy * sx) + iy * sx + (ix + 1)]
	var c010: Vector3 = cp[iz * (sy * sx) + (iy + 1) * sx + ix]
	var c110: Vector3 = cp[iz * (sy * sx) + (iy + 1) * sx + (ix + 1)]
	var c001: Vector3 = cp[(iz + 1) * (sy * sx) + iy * sx + ix]
	var c101: Vector3 = cp[(iz + 1) * (sy * sx) + iy * sx + (ix + 1)]
	var c011: Vector3 = cp[(iz + 1) * (sy * sx) + (iy + 1) * sx + ix]
	var c111: Vector3 = cp[(iz + 1) * (sy * sx) + (iy + 1) * sx + (ix + 1)]

	var c00: Vector3 = c000.lerp(c100, lx)
	var c01: Vector3 = c001.lerp(c101, lx)
	var c10: Vector3 = c010.lerp(c110, lx)
	var c11: Vector3 = c011.lerp(c111, lx)
	var c0: Vector3 = c00.lerp(c10, ly)
	var c1: Vector3 = c01.lerp(c11, ly)
	return c0.lerp(c1, lz)


## Compute AABB of input geometry.
func _compute_aabb(geo: GNGeoData) -> AABB:
	var result := AABB()
	var first := true
	for surf_idx in range(geo.get_surface_count()):
		var arrays: Array = geo.get_surface_arrays(surf_idx)
		if arrays.is_empty():
			continue
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for p: Vector3 in positions:
			if first:
				result = AABB(p, Vector3.ZERO)
				first = false
			else:
				result = result.expand(p)
	return result
