class_name FaceDetectCHOP
extends GNChopBase
## Face mesh landmark tracking via MediaPipe Face Mesh ONNX model.
##
## Accepts an IMG input, detects face landmarks, and outputs them as
## CHOP channels.  Key landmarks (eyes, nose, mouth, eyebrows, jawline)
## are named; remaining landmarks use index-based naming.
## Wire TOPtoIMG in front of a TOP.
##
## Requires the gn_ext_ml GDExtension (GNOnnxInference class).


# Named subsets of the 468 MediaPipe face mesh landmarks
const FACE_KEY_LANDMARKS := {
	# Eyes
	33: "left_eye_outer", 133: "left_eye_inner",
	362: "right_eye_outer", 263: "right_eye_inner",
	159: "left_eye_top", 145: "left_eye_bottom",
	386: "right_eye_top", 374: "right_eye_bottom",
	# Iris centers
	468: "left_iris", 473: "right_iris",
	# Nose
	1: "nose_tip", 4: "nose_bridge", 6: "nose_top",
	# Mouth
	61: "mouth_left", 291: "mouth_right",
	13: "upper_lip", 14: "lower_lip",
	78: "upper_lip_inner_left", 308: "upper_lip_inner_right",
	# Eyebrows
	70: "left_eyebrow_inner", 105: "left_eyebrow_mid", 107: "left_eyebrow_outer",
	300: "right_eyebrow_inner", 334: "right_eyebrow_mid", 336: "right_eyebrow_outer",
	# Jaw / chin
	152: "chin", 234: "left_jaw", 454: "right_jaw",
	# Forehead
	10: "forehead",
}


var _session := GNMlSession.new()


const MODEL_W := 192
const MODEL_H := 192




func _init() -> void:
	node_type = "facedetect"
	node_description = "Face mesh landmarks — 468 points for face tracking. Requires gn_ext_ml."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("image", GNFamily.Type.IMG, true, "Camera or still image. Use TOPtoIMG when the source is a TOP.", "Image")
	add_output("out", GNFamily.Type.CHOP, "Face landmark channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("model_path", "res://addons/gn_ext_ml/models/face_landmark.onnx",
		PackedStringArray(["*.onnx"]),
		"Model", "Path to face mesh ONNX model"))
	add_parameter(GNParameter.create_enum("detail",
		PackedStringArray(["Key Points Only", "All 468 Points"]), 0,
		"Detail", "Output key named landmarks or all 468 points"))
	add_parameter(GNParameter.create_int("max_faces", 1, 1, 4,
		"Max Faces", "Maximum number of faces to track"))
	add_parameter(GNParameter.create_float("min_confidence", 0.5, 0.0, 1.0,
		0.01, "Min Confidence", "Minimum face detection confidence"))
	add_parameter(GNParameter.create_enum("provider",
		PackedStringArray(["CPU", "DirectML", "CUDA", "CoreML"]), 0,
		"Provider", "ONNX execution provider"))
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable detection"))




func _cook(inputs: Array[GNData]) -> GNData:
	if not get_param_value("active"):
		return _cached_channel_data

	node_warning = ""
	var in_img: GNImageData = GNMlSession.image_input(inputs)
	if in_img == null or in_img.image == null:
		return null

	var model_path: String = get_param_value("model_path")
	if not _session.begin(int(get_param_value("provider")), model_path, project_dir):
		node_warning = _session.last_error
		GNLogger.error("FaceDetectCHOP", "'%s': %s" % [id, _session.last_error])
		return null

	if not _session.run_image(in_img.image, MODEL_W, MODEL_H):
		node_warning = _session.last_error
		GNLogger.error("FaceDetectCHOP", "'%s': %s" % [id, _session.last_error])
		return null

	var output_names: PackedStringArray = _session.output_names()

	if output_names.is_empty():
		return null


	# Face mesh outputs [1, 1404] = 468 × 3 (x, y, z)
	var raw: PackedFloat32Array = _session.output_float(output_names[0])
	if raw.is_empty():
		return null


	var detail: int = get_param_value("detail")
	var out: GNChannelData = _prepare_output(60.0)


	var num_points := raw.size() / 3


	if detail == 0:
		# Key points only — named landmarks
		for idx in FACE_KEY_LANDMARKS:
			if idx >= num_points:
				continue
			var name: String = FACE_KEY_LANDMARKS[idx]
			var base: int = idx * 3
			out.set_single_value("%s:x" % name, raw[base] / float(MODEL_W))
			out.set_single_value("%s:y" % name, raw[base + 1] / float(MODEL_H))
			out.set_single_value("%s:z" % name, raw[base + 2])
	else:
		# All 468 points
		for i in range(num_points):
			var base := i * 3
			var name: String
			if FACE_KEY_LANDMARKS.has(i):
				name = FACE_KEY_LANDMARKS[i]
			else:
				name = "pt%d" % i
			out.set_single_value("%s:x" % name, raw[base] / float(MODEL_W))
			out.set_single_value("%s:y" % name, raw[base + 1] / float(MODEL_H))
			out.set_single_value("%s:z" % name, raw[base + 2])


	return out
