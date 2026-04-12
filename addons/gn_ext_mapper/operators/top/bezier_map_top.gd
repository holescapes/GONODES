class_name BezierMapTOP
extends GNTopBase
## Bicubic Bezier surface warp with 4x4 control point grid.
## Uses Newton-Raphson inverse mapping from output pixel to source UV.


func _init() -> void:
	node_type = "bezier_map"
	node_description = "Smooth curved surface warp using a 4x4 Bezier control grid."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Bezier-warped texture")


func _init_parameters() -> void:
	# 16 control points (4x4 grid). Default positions form a uniform grid.
	# Named by grid position: Row 0-3 (top to bottom), Col 0-3 (left to right)
	var defaults := [
		[0.0, 0.0], [0.333, 0.0], [0.667, 0.0], [1.0, 0.0],
		[0.0, 0.333], [0.333, 0.333], [0.667, 0.333], [1.0, 0.333],
		[0.0, 0.667], [0.333, 0.667], [0.667, 0.667], [1.0, 0.667],
		[0.0, 1.0], [0.333, 1.0], [0.667, 1.0], [1.0, 1.0],
	]
	# Internal names must stay as cpXY for the shader uniforms
	var names := [
		"cp00", "cp10", "cp20", "cp30",
		"cp01", "cp11", "cp21", "cp31",
		"cp02", "cp12", "cp22", "cp32",
		"cp03", "cp13", "cp23", "cp33",
	]
	# Human-readable labels: Row/Col grid positions
	var row_labels := ["Top", "Upper Mid", "Lower Mid", "Bottom"]
	var col_labels := ["Left", "Center-Left", "Center-Right", "Right"]
	# Map internal index → (col, row) for labeling
	# Grid layout: index = row * 4 + col, names are cpCR where C=col, R=row
	for i in range(16):
		var n: String = names[i]
		var d: Array = defaults[i]
		var col_idx: int = int(n.substr(2, 1))  # cp[C]R → C
		var row_idx: int = int(n.substr(3, 1))  # cpC[R] → R
		var label := "%s %s" % [row_labels[row_idx], col_labels[col_idx]]
		add_parameter(GNParameter.create_float(n + "_x", d[0], -1.0, 2.0, 0.001,
			"%s X" % label, "Horizontal position for control point row %d, col %d" % [row_idx, col_idx]))
		add_parameter(GNParameter.create_float(n + "_y", d[1], -1.0, 2.0, 0.001,
			"%s Y" % label, "Vertical position for control point row %d, col %d" % [row_idx, col_idx]))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("BezierMapTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gn_ext_mapper/shaders/bezier_warp.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("input_tex", tex_in.texture)

	var names := [
		"cp00", "cp10", "cp20", "cp30",
		"cp01", "cp11", "cp21", "cp31",
		"cp02", "cp12", "cp22", "cp32",
		"cp03", "cp13", "cp23", "cp33",
	]
	for n in names:
		var pt := Vector2(get_param_value(n + "_x"), get_param_value(n + "_y"))
		_material.set_shader_parameter(n, pt)

	_cached_tex_data.resolution = res
	return _cached_tex_data
