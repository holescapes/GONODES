class_name SOPtoCHOP
extends GNChopBase
## Extracts vertex attributes from SOP geometry and outputs them as
## multi-sample CHOP channels (one sample per vertex).
## Supports Position (px/py/pz), Normal (nx/ny/nz), and UV (u/v) attributes.


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "sop_to_chop"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Source SOP geometry", "In")
	add_output("out", GNFamily.Type.CHOP, "Vertex attribute channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("attribute",
		PackedStringArray(["Position", "Normal", "UV"]), 0,
		"Attribute", "Which vertex attribute to extract"))
	add_parameter(GNParameter.create_int("max_points", 1000, 1, 100000,
		"Max Points", "Maximum number of vertices to read"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	var geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if geo == null or not geo.has_geometry():
		GNLogger.warn("SOPtoCHOP", "'%s' — no valid SOP input" % id)
		return null

	var attrib_type: int = get_param_value("attribute")
	var max_pts: int = get_param_value("max_points")

	var out: GNChannelData = _prepare_output(60.0)

	match attrib_type:
		0:  # Position
			_extract_positions(geo, out, max_pts)
		1:  # Normal
			_extract_normals(geo, out, max_pts)
		2:  # UV
			_extract_uvs(geo, out, max_pts)

	return out


# ═══════════════════════════════════════════════════════════════════════════════
# Extraction Helpers
# ═══════════════════════════════════════════════════════════════════════════════

func _extract_positions(geo: GNGeoData, out: GNChannelData, max_pts: int) -> void:
	var px := PackedFloat32Array()
	var py := PackedFloat32Array()
	var pz := PackedFloat32Array()
	var count: int = 0

	for surf_idx in range(geo.get_surface_count()):
		if count >= max_pts:
			break
		var positions: PackedVector3Array = geo.get_positions(surf_idx)
		for vtx in positions:
			if count >= max_pts:
				break
			px.append(vtx.x)
			py.append(vtx.y)
			pz.append(vtx.z)
			count += 1

	out.set_channel("px", px)
	out.set_channel("py", py)
	out.set_channel("pz", pz)
	out.length = count


func _extract_normals(geo: GNGeoData, out: GNChannelData, max_pts: int) -> void:
	var nx := PackedFloat32Array()
	var ny := PackedFloat32Array()
	var nz := PackedFloat32Array()
	var count: int = 0

	for surf_idx in range(geo.get_surface_count()):
		if count >= max_pts:
			break
		var normals: PackedVector3Array = geo.get_normals(surf_idx)
		if normals.is_empty():
			continue
		for vtx in normals:
			if count >= max_pts:
				break
			nx.append(vtx.x)
			ny.append(vtx.y)
			nz.append(vtx.z)
			count += 1

	out.set_channel("nx", nx)
	out.set_channel("ny", ny)
	out.set_channel("nz", nz)
	out.length = count


func _extract_uvs(geo: GNGeoData, out: GNChannelData, max_pts: int) -> void:
	var u := PackedFloat32Array()
	var v := PackedFloat32Array()
	var count: int = 0

	for surf_idx in range(geo.get_surface_count()):
		if count >= max_pts:
			break
		var uvs: PackedVector2Array = geo.get_uvs(surf_idx)
		if uvs.is_empty():
			continue
		for vtx in uvs:
			if count >= max_pts:
				break
			u.append(vtx.x)
			v.append(vtx.y)
			count += 1

	out.set_channel("u", u)
	out.set_channel("v", v)
	out.length = count
