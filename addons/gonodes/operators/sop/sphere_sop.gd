class_name SphereSOP
extends GNSopBase
## Generates a sphere mesh using Godot's SphereMesh primitive.
## Leverages Godot's built-in mesh generation.


func _init() -> void:
	node_type = "sphere"
	node_description = "Generate a sphere mesh."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Sphere mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("radius", 0.5, 0.01, 100.0, 0.01, "Radius", "Sphere radius"))
	add_parameter(GNParameter.create_float("height", 1.0, 0.01, 200.0, 0.01, "Height", "Full sphere height (2 × radius for perfect sphere)"))
	add_parameter(GNParameter.create_int("radial_segments", 32, 3, 256, "Radial Segments", "Segments around circumference"))
	add_parameter(GNParameter.create_int("rings", 16, 2, 128, "Rings", "Horizontal edge loops"))
	add_parameter(GNParameter.create_bool("is_hemisphere", false, "Hemisphere", "Only produce top half"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var sphere := SphereMesh.new()
	sphere.radius = get_param_value("radius")
	sphere.height = get_param_value("height")
	sphere.radial_segments = get_param_value("radial_segments")
	sphere.rings = get_param_value("rings")
	sphere.is_hemisphere = get_param_value("is_hemisphere")

	var st := SurfaceTool.new()
	st.create_from(sphere, 0)
	var arr_mesh := ArrayMesh.new()
	st.commit(arr_mesh)
	_cached_geo.set_mesh(arr_mesh)

	return _cached_geo
