class_name CylinderSOP
extends GNNode
## Generates a cylinder mesh using Godot's CylinderMesh primitive.
## Supports cones (top_radius = 0) and capsule-like shapes.

var _cached_geo: GNGeoData = null


func _init() -> void:
	node_type = "cylinder"
	family = GNFamily.Type.SOP


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("top_radius", 0.5, 0.0, 50.0, 0.01, "Top Radius"))
	add_parameter(GNParameter.create_float("bottom_radius", 0.5, 0.0, 50.0, 0.01, "Bottom Radius"))
	add_parameter(GNParameter.create_float("height", 1.0, 0.01, 100.0, 0.01, "Height"))
	add_parameter(GNParameter.create_int("radial_segments", 32, 3, 256, "Radial Segments"))
	add_parameter(GNParameter.create_int("rings", 4, 1, 128, "Rings"))
	add_parameter(GNParameter.create_bool("cap_top", true, "Cap Top"))
	add_parameter(GNParameter.create_bool("cap_bottom", true, "Cap Bottom"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var cyl := CylinderMesh.new()
	cyl.top_radius = get_param_value("top_radius")
	cyl.bottom_radius = get_param_value("bottom_radius")
	cyl.height = get_param_value("height")
	cyl.radial_segments = get_param_value("radial_segments")
	cyl.rings = get_param_value("rings")
	cyl.cap_top = get_param_value("cap_top")
	cyl.cap_bottom = get_param_value("cap_bottom")

	var st := SurfaceTool.new()
	st.create_from(cyl, 0)
	var arr_mesh := ArrayMesh.new()
	st.commit(arr_mesh)
	_cached_geo.set_mesh(arr_mesh)

	return _cached_geo
