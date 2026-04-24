class_name IsoSurfaceSOPNative
extends GNSopBase
## Native-accelerated IsoSurface via marching cubes — delegates to
## GNNativeIsoSurface (C++) when available, falls back to pure GDScript.

var _processor: RefCounted = null


func _init() -> void:
	node_type = "isosurface_native"
	node_description = "Analytic implicit surface via marching cubes (native C++ accelerated)."
	if ClassDB.class_exists("GNNativeIsoSurface"):
		_processor = ClassDB.instantiate("GNNativeIsoSurface")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "IsoSurface mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("surface_type",
		PackedStringArray(["Gyroid", "Schwarz-P", "Schwarz-D", "Sphere", "Torus"]),
		0, "Surface Type", "Implicit function to evaluate"))
	add_parameter(GNParameter.create_int("resolution", 40, 4, 128, "Resolution",
		"Grid subdivisions per axis"))
	add_parameter(GNParameter.create_float("bounds_size", 6.28, 0.5, 100.0, 0.5,
		"Bounds Size", "Cubic grid extent (centred at origin)"))
	add_parameter(GNParameter.create_float("threshold", 0.0, -50.0, 50.0, 0.01,
		"Threshold", "Iso value for surface extraction"))
	add_parameter(GNParameter.create_float("frequency", 1.0, 0.01, 20.0, 0.01,
		"Frequency", "Spatial frequency multiplier"))
	add_parameter(GNParameter.create_float("major_radius", 2.0, 0.1, 50.0, 0.1,
		"Major Radius", "Torus major radius"))
	add_parameter(GNParameter.create_float("minor_radius", 0.8, 0.01, 20.0, 0.05,
		"Minor Radius", "Torus minor radius"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var stype: int = get_param_value("surface_type")
	var res: int = get_param_value("resolution")
	var bounds: float = get_param_value("bounds_size")
	var threshold: float = get_param_value("threshold")
	var freq: float = get_param_value("frequency")
	var major_r: float = get_param_value("major_radius")
	var minor_r: float = get_param_value("minor_radius")

	if _processor != null:
		var result: Dictionary = _processor.process(stype, res, bounds,
			threshold, freq, major_r, minor_r)
		var verts: PackedVector3Array = result.get("positions", PackedVector3Array())
		var normals: PackedVector3Array = result.get("normals", PackedVector3Array())
		if verts.is_empty():
			return null
		var out := _prepare_geo()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.set_mesh(mesh)
		return out
	else:
		return null  # Fallback handled by core IsoSurfaceSOP
