class_name CameraUndistortIMG
extends GNImgBase
## Lens undistortion using calibration data.
##
## Applies barrel/pincushion distortion correction using a camera matrix and
## distortion coefficients.  These can come from CameraCalibDAT or be entered
## manually.  Essential for projection mapping and depth-sensor alignment.
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.undistort(rgba, w, h, camera_matrix, dist_coeffs)
##         -> PackedByteArray

var _cv: RefCounted = null


func _init() -> void:
	node_type = "camera_undistort"
	node_description = "Lens undistortion from calibration data. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Distorted input image")
	add_output("out", GNFamily.Type.IMG, "Undistorted output")


func _init_parameters() -> void:
	# Camera intrinsics (3x3 row-major: fx,0,cx, 0,fy,cy, 0,0,1)
	add_parameter(GNParameter.create_string("camera_matrix",
		"500,0,320, 0,500,240, 0,0,1",
		"Camera Matrix", "3x3 intrinsics matrix (comma-separated, row-major)"))
	# Distortion coefficients (k1,k2,p1,p2,k3)
	add_parameter(GNParameter.create_string("dist_coeffs",
		"0,0,0,0,0",
		"Dist Coeffs", "Distortion coefficients k1,k2,p1,p2,k3"))
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

	var cam_mat := _parse_floats(get_param_value("camera_matrix"))
	var dist := _parse_floats(get_param_value("dist_coeffs"))
	if cam_mat.size() < 9 or dist.size() < 5:
		GNLogger.warn("CameraUndistortIMG",
			"'%s': need 9 camera-matrix and 5 distortion values" % id)
		out.set_image(src.image)
		return out

	var result: PackedByteArray = _cv.undistort(
		rgba, w, h, cam_mat, dist)
	if result.is_empty():
		return out

	var img := GNOpenCVHelper.rgba_to_image(result, w, h)
	if img != null:
		out.set_image(img)
	return out


static func _parse_floats(text: String) -> PackedFloat32Array:
	var arr := PackedFloat32Array()
	for part in text.split(","):
		arr.append(part.strip_edges().to_float())
	return arr


func _ensure_cv() -> void:
	if _cv != null:
		return
	_cv = GNOpenCVHelper.create_instance()
	if _cv == null:
		GNLogger.error("CameraUndistortIMG", "'%s': failed to instantiate GNOpenCV" % id)
