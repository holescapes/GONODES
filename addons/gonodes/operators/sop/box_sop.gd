class_name BoxSOP
extends GNSopBase
## Generates a box (cuboid) mesh using Godot's BoxMesh primitive.
## Leverages Godot's built-in mesh generation for optimal quality.


func _init() -> void:
	node_type = "box"
	node_description = "Generate a box (cuboid) mesh."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Box mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("size_x", 1.0, 0.01, 100.0, 0.1, "Size X", "Width along X axis"))
	add_parameter(GNParameter.create_float("size_y", 1.0, 0.01, 100.0, 0.1, "Size Y", "Height along Y axis"))
	add_parameter(GNParameter.create_float("size_z", 1.0, 0.01, 100.0, 0.1, "Size Z", "Depth along Z axis"))
	add_parameter(GNParameter.create_int("subdivide_w", 0, 0, 100, "Subdivide Width", "Subdivisions along width"))
	add_parameter(GNParameter.create_int("subdivide_h", 0, 0, 100, "Subdivide Height", "Subdivisions along height"))
	add_parameter(GNParameter.create_int("subdivide_d", 0, 0, 100, "Subdivide Depth", "Subdivisions along depth"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var box := BoxMesh.new()
	box.size = Vector3(
		get_param_value("size_x"),
		get_param_value("size_y"),
		get_param_value("size_z")
	)
	box.subdivide_width = get_param_value("subdivide_w")
	box.subdivide_height = get_param_value("subdivide_h")
	box.subdivide_depth = get_param_value("subdivide_d")

	# Convert PrimitiveMesh to ArrayMesh via SurfaceTool
	var st := SurfaceTool.new()
	st.create_from(box, 0)
	var arr_mesh := ArrayMesh.new()
	st.commit(arr_mesh)
	_cached_geo.set_mesh(arr_mesh)

	return _cached_geo
