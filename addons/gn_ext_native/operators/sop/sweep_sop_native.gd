class_name SweepSOPNative
extends GNSopBase
## Native-accelerated sweep — delegates to GNNativeSweepSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "sweep_native"
	node_description = "Sweep a cross-section along a curve — native C++ accelerated."
	if ClassDB.class_exists("GNNativeSweepSop"):
		_processor = ClassDB.instantiate("GNNativeSweepSop")


func _init_ports() -> void:
	add_input("backbone", GNFamily.Type.SOP, false, "Backbone curve", "Backbone")
	add_input("profile", GNFamily.Type.SOP, true, "Profile cross-section (optional)", "Profile")
	add_output("out", GNFamily.Type.SOP, "Swept mesh", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("scale", 0.1, 0.001, 50.0, 0.01, "Profile Scale", ""))
	add_parameter(GNParameter.create_int("profile_segs", 12, 3, 128, "Profile Segments", "Circle segs if no input"))
	add_parameter(GNParameter.create_bool("close_profile", true, "", "Close profile ring"))
	add_parameter(GNParameter.create_bool("close_backbone", false, "", "Close backbone loop"))
	add_parameter(GNParameter.create_bool("end_caps", false, "", "End caps"))


func _cook(inputs: Array[GNData]) -> GNData:
	var backbone_geo: GNGeoData = _get_input_sop(inputs, 0)
	if backbone_geo == null or not backbone_geo.has_geometry():
		return _prepare_geo()

	var profile_geo: GNGeoData = _get_input_sop(inputs, 1)
	var scale_val: float = get_param_value("scale")
	var close_profile: bool = get_param_value("close_profile")
	var close_backbone: bool = get_param_value("close_backbone")

	# Extract backbone points
	var backbone_pts := _extract_points(backbone_geo)
	if backbone_pts.size() < 2:
		return _prepare_geo()

	# Extract or generate profile
	var profile_pts := PackedVector3Array()
	if profile_geo != null and profile_geo.has_geometry():
		profile_pts = _extract_points(profile_geo)
	else:
		var segs: int = get_param_value("profile_segs")
		profile_pts = _make_circle_profile(segs)

	if profile_pts.size() < 3:
		return _prepare_geo()

	if _processor != null:
		var result: Dictionary = _processor.process(profile_pts, backbone_pts,
			scale_val, close_profile, close_backbone)

		var geo := _prepare_geo()
		var new_mesh := ArrayMesh.new()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = result.get("positions", PackedVector3Array())
		if result.has("normals"):
			arrays[Mesh.ARRAY_NORMAL] = result["normals"]
		if result.has("uvs"):
			arrays[Mesh.ARRAY_TEX_UV] = result["uvs"]
		if result.has("indices"):
			arrays[Mesh.ARRAY_INDEX] = result["indices"]
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		geo.set_mesh(new_mesh)
		return geo
	else:
		return _prepare_geo()


func _extract_points(geo: GNGeoData) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for s in range(geo.mesh.get_surface_count()):
		var arrays: Array = geo.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			pts.append_array(arrays[Mesh.ARRAY_VERTEX])
	return pts


func _make_circle_profile(segs: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in range(segs):
		var angle: float = float(i) / float(segs) * TAU
		pts.append(Vector3(cos(angle), sin(angle), 0.0))
	return pts
