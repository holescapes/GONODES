class_name CHOPtoSOP
extends GNSopBase
## Converts CHOP channel data into SOP geometry.
##
## Three modes:
##   • Points — Each sample becomes a point in 3D space.  Channels named
##     px/py/pz map to position.  If only one channel exists it is used
##     as the Y coordinate with X = sample index.
##   • Line — Samples become a connected polyline (PRIMITIVE_LINE_STRIP).
##   • Trail — Similar to Line but connects multiple channels as separate
##     polylines (one per triplet px/py/pz or per channel group).
##
## Useful for turning audio or animation data into visible geometry.


func _init() -> void:
	node_type = "chop_to_sop"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, true, "Source CHOP channels")
	add_output("out", GNFamily.Type.SOP, "Generated geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Points", "Line", "Trail"]),
		0, "Mode", "How to interpret channel data"))
	add_parameter(GNParameter.create_float("x_scale", 0.1, 0.001, 100.0, 0.01,
		"X Scale", "Horizontal spacing between samples"))
	add_parameter(GNParameter.create_float("y_scale", 1.0, 0.001, 100.0, 0.01,
		"Y Scale", "Vertical multiplier for channel values"))
	add_parameter(GNParameter.create_int("max_samples", 1000, 1, 100000,
		"Max Samples", "Maximum samples to convert"))
	add_parameter(GNParameter.create_bool("center_x", true,
		"Center X", "Center geometry at X origin"))


func _cook(inputs: Array[GNData]) -> GNData:
	var chop_data: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	if chop_data == null or chop_data.channels.is_empty():
		return null

	var mode: int = get_param_value("mode")
	var x_scale: float = get_param_value("x_scale")
	var y_scale: float = get_param_value("y_scale")
	var max_samples: int = get_param_value("max_samples")
	var center_x: bool = get_param_value("center_x")

	var channels: Dictionary = chop_data.channels

	# Check for named position channels
	var has_pos := channels.has("px") and channels.has("py") and channels.has("pz")

	var out := _prepare_geo()

	match mode:
		0:  # Points
			_build_points(channels, has_pos, x_scale, y_scale, max_samples, center_x, out)
		1:  # Line
			_build_line(channels, has_pos, x_scale, y_scale, max_samples, center_x, out)
		2:  # Trail
			_build_trail(channels, x_scale, y_scale, max_samples, center_x, out)

	return out


func _build_points(channels: Dictionary, has_pos: bool, x_scale: float,
		y_scale: float, max_samples: int, center_x: bool, out: GNGeoData) -> void:
	var verts := PackedVector3Array()

	if has_pos:
		var px: PackedFloat32Array = channels["px"]
		var py: PackedFloat32Array = channels["py"]
		var pz: PackedFloat32Array = channels["pz"]
		var count: int = mini(mini(mini(px.size(), py.size()), pz.size()), max_samples)
		for i in range(count):
			verts.append(Vector3(px[i], py[i], pz[i]))
	else:
		# Use first channel as Y, index as X
		var ch_name: String = channels.keys()[0]
		var data: PackedFloat32Array = channels[ch_name]
		var count: int = mini(data.size(), max_samples)
		var x_offset: float = 0.0
		if center_x:
			x_offset = float(count - 1) * x_scale * 0.5
		for i in range(count):
			verts.append(Vector3(float(i) * x_scale - x_offset, data[i] * y_scale, 0.0))

	if verts.is_empty():
		return

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	out.set_mesh(mesh)


func _build_line(channels: Dictionary, has_pos: bool, x_scale: float,
		y_scale: float, max_samples: int, center_x: bool, out: GNGeoData) -> void:
	var verts := PackedVector3Array()

	if has_pos:
		var px: PackedFloat32Array = channels["px"]
		var py: PackedFloat32Array = channels["py"]
		var pz: PackedFloat32Array = channels["pz"]
		var count: int = mini(mini(mini(px.size(), py.size()), pz.size()), max_samples)
		for i in range(count):
			verts.append(Vector3(px[i], py[i], pz[i]))
	else:
		var ch_name: String = channels.keys()[0]
		var data: PackedFloat32Array = channels[ch_name]
		var count: int = mini(data.size(), max_samples)
		var x_offset: float = 0.0
		if center_x:
			x_offset = float(count - 1) * x_scale * 0.5
		for i in range(count):
			verts.append(Vector3(float(i) * x_scale - x_offset, data[i] * y_scale, 0.0))

	if verts.size() < 2:
		return

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	out.set_mesh(mesh)


func _build_trail(channels: Dictionary, x_scale: float, y_scale: float,
		max_samples: int, center_x: bool, out: GNGeoData) -> void:
	# Each channel becomes a separate polyline, offset in Z
	var mesh := ArrayMesh.new()
	var ch_names: Array = channels.keys()
	var z_spacing: float = 0.5

	for ci in range(ch_names.size()):
		var ch_name: String = ch_names[ci]
		var data: PackedFloat32Array = channels[ch_name]
		var count: int = mini(data.size(), max_samples)
		if count < 2:
			continue

		var verts := PackedVector3Array()
		var x_offset: float = 0.0
		if center_x:
			x_offset = float(count - 1) * x_scale * 0.5
		for i in range(count):
			verts.append(Vector3(
				float(i) * x_scale - x_offset,
				data[i] * y_scale,
				float(ci) * z_spacing))

		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)

	out.set_mesh(mesh)
