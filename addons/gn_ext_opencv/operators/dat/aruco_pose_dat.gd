class_name ArucoPoseDAT
extends GNDatBase
## 3D pose estimation from detected ArUco markers + camera calibration.
##
## Reads an image, detects ArUco markers, and computes rotation / translation
## vectors for each detected marker relative to the calibrated camera.
## Output table: marker_id, rvec_x, rvec_y, rvec_z, tvec_x, tvec_y, tvec_z,
## distance.
##
## Requires GNOpenCV GDExtension (opencv_contrib aruco module).
##
## Native: GNOpenCV.detect_aruco(rgba, w, h, dictionary, ...) -> void
## Native: GNOpenCV.estimate_aruco_pose(camera_matrix, dist_coeffs,
##         marker_size) -> PackedFloat32Array
##         [count, id0,rvx,rvy,rvz,tvx,tvy,tvz, id1,...]

var _cv: RefCounted = null


func _init() -> void:
	node_type = "aruco_pose"
	node_description = "3D pose estimation from ArUco markers. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Input image", "In")
	add_output("out", GNFamily.Type.DAT, "Pose data per marker", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("dictionary",
		PackedStringArray([
			"4x4_50", "4x4_100", "4x4_250", "4x4_1000",
			"5x5_50", "5x5_100", "5x5_250", "5x5_1000",
			"6x6_50", "6x6_100", "6x6_250", "6x6_1000",
			"7x7_50", "7x7_100", "7x7_250", "7x7_1000",
			"AprilTag 16h5", "AprilTag 25h9", "AprilTag 36h10", "AprilTag 36h11"
		]), 0,
		"Dictionary", "ArUco marker dictionary"))
	add_parameter(GNParameter.create_float("marker_size", 0.05, 0.001, 10.0, 0.001,
		"Marker Size (m)", "Physical marker side length in meters"))
	# Camera calibration (from CameraCalibDAT or manual)
	add_parameter(GNParameter.create_string("camera_matrix",
		"500,0,320, 0,500,240, 0,0,1",
		"Camera Matrix", "3x3 intrinsics (comma-sep, row-major)"))
	add_parameter(GNParameter.create_string("dist_coeffs",
		"0,0,0,0,0",
		"Dist Coeffs", "Distortion k1,k2,p1,p2,k3"))
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable processing"))


func _cook(inputs: Array[GNData]) -> GNData:
	if _cached_table == null:
		_cached_table = GNTableData.new()

	_cached_table.set_headers(PackedStringArray([
		"marker_id", "rvec_x", "rvec_y", "rvec_z",
		"tvec_x", "tvec_y", "tvec_z", "distance"]))

	if not GNOpenCVHelper.is_available() or not get_param_value("active"):
		return _cached_table

	var src: GNImageData = inputs[0] as GNImageData if inputs.size() > 0 and inputs[0] is GNImageData else null
	if src == null or src.image == null:
		return _cached_table

	_ensure_cv()
	if _cv == null:
		return _cached_table

	var conv := GNOpenCVHelper.image_to_rgba(src.image)
	var rgba: PackedByteArray = conv[0]
	var w: int = conv[1]
	var h: int = conv[2]
	if rgba.is_empty():
		return _cached_table

	# Detect markers first (stores results internally in native)
	_cv.detect_aruco(rgba, w, h,
		get_param_value("dictionary"),
		0.0, 0.0, 0.0, 1, false)  # no drawing needed

	# Estimate poses
	var cam_mat := _parse_floats(get_param_value("camera_matrix"))
	var dist := _parse_floats(get_param_value("dist_coeffs"))
	if cam_mat.size() < 9 or dist.size() < 5:
		return _cached_table

	var marker_size: float = get_param_value("marker_size")
	var pose_data: PackedFloat32Array = _cv.estimate_aruco_pose(
		cam_mat, dist, marker_size)
	if pose_data.is_empty():
		return _cached_table

	# Parse: [count, id0,rvx,rvy,rvz,tvx,tvy,tvz, id1,...]
	var count: int = int(pose_data[0])
	var idx: int = 1
	for _i in range(count):
		if idx + 7 > pose_data.size():
			break
		var mid: int = int(pose_data[idx])
		var rvx: float = pose_data[idx + 1]
		var rvy: float = pose_data[idx + 2]
		var rvz: float = pose_data[idx + 3]
		var tvx: float = pose_data[idx + 4]
		var tvy: float = pose_data[idx + 5]
		var tvz: float = pose_data[idx + 6]
		var dist_val: float = sqrt(tvx * tvx + tvy * tvy + tvz * tvz)
		_cached_table.append_row(PackedStringArray([
			str(mid),
			"%.4f" % rvx, "%.4f" % rvy, "%.4f" % rvz,
			"%.4f" % tvx, "%.4f" % tvy, "%.4f" % tvz,
			"%.4f" % dist_val]))
		idx += 7

	return _cached_table


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
		GNLogger.error("ArucoPoseDAT", "'%s': failed to instantiate GNOpenCV" % id)
