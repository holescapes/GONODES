class_name DrawOverlayIMG
extends GNImgBase
## Utility — draw bounding boxes, circles, text labels, polylines,
## crosshairs, and filled rectangles on an image.
##
## Intended for visualizing detection results from other CV operators.
## Draw data comes from parameters (manual placement) or can be driven
## by expressions referencing upstream DAT/CHOP data.
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.draw_overlay(rgba, w, h, commands) -> PackedByteArray
##   commands is a PackedFloat32Array encoded as:
##     [cmd_type, ...args, cmd_type, ...args, ...]
##   cmd_type: 0=rect, 1=circle, 2=line, 3=crosshair, 4=text

var _cv: RefCounted = null


func _init() -> void:
	node_type = "draw_overlay"
	node_description = "Draw bounding boxes, text, circles, crosshairs. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Base image to draw on")
	add_output("out", GNFamily.Type.IMG, "Image with overlays drawn")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("draw_mode",
		PackedStringArray(["Rectangle", "Circle", "Line", "Crosshair", "Text"]), 0,
		"Draw Mode", "Shape / primitive to draw"))
	# Normalized coordinates (0..1)
	add_parameter(GNParameter.create_float("x1", 0.1, 0.0, 1.0, 0.01,
		"X1", "Start X (normalized)"))
	add_parameter(GNParameter.create_float("y1", 0.1, 0.0, 1.0, 0.01,
		"Y1", "Start Y (normalized)"))
	add_parameter(GNParameter.create_float("x2", 0.5, 0.0, 1.0, 0.01,
		"X2", "End X / radius factor (normalized)"))
	add_parameter(GNParameter.create_float("y2", 0.5, 0.0, 1.0, 0.01,
		"Y2", "End Y (normalized)"))
	add_parameter(GNParameter.create_color("color", Color(0.0, 1.0, 0.0, 1.0),
		"Color", "Drawing color"))
	add_parameter(GNParameter.create_int("thickness", 2, 1, 20,
		"Thickness", "Line thickness (-1 = filled)"))
	add_parameter(GNParameter.create_string("label", "hello",
		"Label", "Text string (for Text mode)"))
	add_parameter(GNParameter.create_float("font_scale", 1.0, 0.1, 10.0, 0.1,
		"Font Scale", "Text font size multiplier"))
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable processing"))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()
	if not GNOpenCVHelper.is_available():
		return out
	if not get_param_value("active"):
		var src := _get_input_img(inputs, 0)
		if src != null and src.image != null:
			out.set_image(src.image)
		return out

	var src := _get_input_img(inputs, 0)
	if src == null or src.image == null:
		return out

	_ensure_cv()
	if _cv == null:
		return out

	var conv := GNOpenCVHelper.image_to_rgba(src.image)
	var rgba: PackedByteArray = conv[0]
	var w: int = conv[1]
	var h: int = conv[2]
	if rgba.is_empty():
		return out

	var mode: int = get_param_value("draw_mode")
	var px1: float = get_param_value("x1") * w
	var py1: float = get_param_value("y1") * h
	var px2: float = get_param_value("x2") * w
	var py2: float = get_param_value("y2") * h
	var c: Color = get_param_value("color")
	var thick: int = get_param_value("thickness")
	var label_text: String = get_param_value("label")
	var fscale: float = get_param_value("font_scale")

	# Build draw commands array
	var cmds := PackedFloat32Array()
	cmds.append(float(mode))
	cmds.append(px1)
	cmds.append(py1)
	cmds.append(px2)
	cmds.append(py2)
	cmds.append(c.r)
	cmds.append(c.g)
	cmds.append(c.b)
	cmds.append(float(thick))
	cmds.append(fscale)

	var result: PackedByteArray = _cv.draw_overlay(
		rgba, w, h, cmds, label_text)
	if result.is_empty():
		return out

	var img := GNOpenCVHelper.rgba_to_image(result, w, h)
	if img != null:
		out.set_image(img)
	return out


func _ensure_cv() -> void:
	if _cv != null:
		return
	_cv = GNOpenCVHelper.create_instance()
	if _cv == null:
		GNLogger.error("DrawOverlayIMG", "'%s': failed to instantiate GNOpenCV" % id)
