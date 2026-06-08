class_name CameraCalibDAT
extends GNDatBase
## Camera intrinsics calibration from chessboard / circle-grid frames.
##
## Feed successive video frames containing a calibration pattern.  When
## enough valid frames have been captured, press "Calibrate" to compute the
## camera matrix and distortion coefficients.
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.find_chessboard(rgba, w, h, cols, rows)
##         -> PackedFloat32Array (corner positions, empty = not found)
## Native: GNOpenCV.calibrate_camera(all_corners, cols, rows, image_w, image_h)
##         -> Dictionary {matrix: PackedFloat32Array(9), distortion: PFA(5),
##                        reprojection_error: float}

var _cv: RefCounted = null
var _captured_frames: Array[PackedFloat32Array] = []
var _calibration: Dictionary = {}
var _image_size: Vector2i = Vector2i.ZERO


func _init() -> void:
	node_type = "camera_calib"
	node_description = "Camera calibration from chessboard / circle grid. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Video frames with calibration pattern", "In")
	add_output("out", GNFamily.Type.DAT, "Calibration data table", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("cols", 9, 2, 30,
		"Columns", "Number of inner corners per row in the chessboard"))
	add_parameter(GNParameter.create_int("rows", 6, 2, 30,
		"Rows", "Number of inner corners per column"))
	add_parameter(GNParameter.create_pulse("capture", "Capture Frame",
		"Capture the current frame for calibration"))
	add_parameter(GNParameter.create_pulse("calibrate", "Calibrate",
		"Compute calibration from captured frames"))
	add_parameter(GNParameter.create_pulse("reset", "Reset",
		"Discard all captured frames and calibration data"))


func _pre_cook(_delta: float) -> void:
	if get_param_value("reset"):
		set_param_value("reset", false)
		_captured_frames.clear()
		_calibration.clear()


func _cook(inputs: Array[GNData]) -> GNData:
	if _cached_table == null:
		_cached_table = GNTableData.new()

	if not GNOpenCVHelper.is_available():
		_build_status_table("GNOpenCV not loaded", 0)
		return _cached_table

	_ensure_cv()
	if _cv == null:
		_build_status_table("Failed to instantiate GNOpenCV", 0)
		return _cached_table

	var src: GNImageData = inputs[0] as GNImageData if inputs.size() > 0 and inputs[0] is GNImageData else null
	var do_capture: bool = get_param_value("capture")
	var do_calibrate: bool = get_param_value("calibrate")
	if do_capture:
		set_param_value("capture", false)
	if do_calibrate:
		set_param_value("calibrate", false)

	# Capture frame
	if do_capture and src != null and src.image != null:
		var conv := GNOpenCVHelper.image_to_rgba(src.image)
		var rgba: PackedByteArray = conv[0]
		var w: int = conv[1]
		var h: int = conv[2]
		if not rgba.is_empty():
			_image_size = Vector2i(w, h)
			var corners: PackedFloat32Array = _cv.find_chessboard(
				rgba, w, h,
				get_param_value("cols"),
				get_param_value("rows"))
			if not corners.is_empty():
				_captured_frames.append(corners)

	# Calibrate
	if do_calibrate and _captured_frames.size() >= 3:
		_calibration = _cv.calibrate_camera(
			_captured_frames,
			get_param_value("cols"),
			get_param_value("rows"),
			_image_size.x, _image_size.y)

	# Build output table
	if _calibration.is_empty():
		_build_status_table("Waiting for calibration", _captured_frames.size())
	else:
		_build_calibration_table()

	return _cached_table


func _build_status_table(status: String, frames: int) -> void:
	_cached_table.set_headers(PackedStringArray(["key", "value"]))
	_cached_table.append_row(PackedStringArray(["status", status]))
	_cached_table.append_row(PackedStringArray(["captured_frames", str(frames)]))


func _build_calibration_table() -> void:
	_cached_table.set_headers(PackedStringArray(["key", "value"]))

	# Camera matrix (3x3 row-major)
	var mat: PackedFloat32Array = _calibration.get("matrix", PackedFloat32Array())
	var mat_str := PackedStringArray()
	for v in mat:
		mat_str.append("%.6f" % v)
	_cached_table.append_row(PackedStringArray(["camera_matrix", ",".join(mat_str)]))

	# Distortion (k1,k2,p1,p2,k3)
	var dist: PackedFloat32Array = _calibration.get("distortion", PackedFloat32Array())
	var dist_str := PackedStringArray()
	for v in dist:
		dist_str.append("%.6f" % v)
	_cached_table.append_row(PackedStringArray(["distortion", ",".join(dist_str)]))

	# Reprojection error
	var err: float = _calibration.get("reprojection_error", -1.0)
	_cached_table.append_row(PackedStringArray(["reprojection_error", "%.4f" % err]))

	_cached_table.append_row(PackedStringArray(
		["captured_frames", str(_captured_frames.size())]))


func _ensure_cv() -> void:
	if _cv != null:
		return
	_cv = GNOpenCVHelper.create_instance()
	if _cv == null:
		GNLogger.error("CameraCalibDAT", "'%s': failed to instantiate GNOpenCV" % id)
