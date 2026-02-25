class_name TorusSOP
extends GNNode
## Generates a torus mesh using Godot's TorusMesh primitive.

var _cached_geo: GNGeoData = null


func _init() -> void:
	node_type = "torus"
	family = GNFamily.Type.SOP
	node_description = "Generate a torus mesh."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Torus mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("inner_radius", 0.2, 0.01, 50.0, 0.01, "Inner Radius", "Tube cross-section radius"))
	add_parameter(GNParameter.create_float("outer_radius", 0.5, 0.01, 100.0, 0.01, "Outer Radius", "Ring center radius"))
	add_parameter(GNParameter.create_int("rings", 32, 3, 256, "Rings", "Segments around the ring"))
	add_parameter(GNParameter.create_int("ring_segments", 16, 3, 128, "Ring Segments", "Segments around the tube"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var torus := TorusMesh.new()
	torus.inner_radius = get_param_value("inner_radius")
	torus.outer_radius = get_param_value("outer_radius")
	torus.rings = get_param_value("rings")
	torus.ring_segments = get_param_value("ring_segments")

	var st := SurfaceTool.new()
	st.create_from(torus, 0)
	var arr_mesh := ArrayMesh.new()
	st.commit(arr_mesh)
	_cached_geo.set_mesh(arr_mesh)

	return _cached_geo
