class_name PoseDetectCHOP
extends GNChopBase
## Body pose estimation via BlazePose ONNX model.
##
## Accepts an IMG input (camera/image), runs pose detection, and outputs
## 33 body keypoints as CHOP channels: joint_name:x, joint_name:y,
## joint_name:z, joint_name:v (visibility). Wire TOPtoIMG in front of a TOP.
##
## Requires the gn_ext_ml GDExtension (GNOnnxInference class) and
## a BlazePose ONNX model in the models/ directory.


# MediaPipe BlazePose 33 keypoint names
const POSE_LANDMARKS := [
	"nose", "left_eye_inner", "left_eye", "left_eye_outer",
	"right_eye_inner", "right_eye", "right_eye_outer",
	"left_ear", "right_ear", "mouth_left", "mouth_right",
	"left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
	"left_wrist", "right_wrist", "left_pinky", "right_pinky",
	"left_index", "right_index", "left_thumb", "right_thumb",
	"left_hip", "right_hip", "left_knee", "right_knee",
	"left_ankle", "right_ankle", "left_heel", "right_heel",
	"left_foot_index", "right_foot_index",
]


var _session := GNMlSession.new()


# Input image dimensions expected by BlazePose
const MODEL_W := 256
const MODEL_H := 256




func _init() -> void:
	node_type = "posedetect"
	node_description = "Body pose estimation — 33 keypoints as CHOP channels. Requires gn_ext_ml."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("image", GNFamily.Type.IMG, true, "Camera or still image. Use TOPtoIMG when the source is a TOP.", "Image")
	add_output("out", GNFamily.Type.CHOP, "Pose keypoint channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("model_path", "res://addons/gn_ext_ml/models/pose_landmark_lite.onnx",
		PackedStringArray(["*.onnx"]),
		"Model", "Path to BlazePose ONNX model"))
	add_parameter(GNParameter.create_float("min_confidence", 0.5, 0.0, 1.0,
		0.01, "Min Confidence", "Minimum detection confidence threshold"))
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
		GNLogger.error("PoseDetectCHOP", "'%s': %s" % [id, _session.last_error])
		return null

	if not _session.run_image(in_img.image, MODEL_W, MODEL_H):
		node_warning = _session.last_error
		GNLogger.error("PoseDetectCHOP", "'%s': %s" % [id, _session.last_error])
		return null

	# Parse output — BlazePose outputs landmarks as [1, 33, 5] or [1, 195]
	# (33 × 5: x, y, z, visibility, presence) or similar flat layout
	var output_names: PackedStringArray = _session.output_names()
	if output_names.is_empty():
		return null

	var raw: PackedFloat32Array = _session.output_float(output_names[0])
	if raw.is_empty():
		return null


	var min_conf: float = get_param_value("min_confidence")
	var out: GNChannelData = _prepare_output(60.0)


	# Parse landmarks — handle both [1, 33, 5] and [1, 195] shapes
	var stride := 5 if raw.size() >= 33 * 5 else 4
	var num_points := mini(33, raw.size() / stride)


	for i in range(num_points):
		var base := i * stride
		var lx: float = raw[base]       # Normalized x [0..1]
		var ly: float = raw[base + 1]   # Normalized y [0..1]
		var lz: float = raw[base + 2]   # Relative depth
		var vis: float = raw[base + 3] if stride >= 4 else 1.0  # Visibility


		var name: String = POSE_LANDMARKS[i] if i < POSE_LANDMARKS.size() else "point%d" % i


		if vis >= min_conf:
			out.set_single_value("%s:x" % name, lx)
			out.set_single_value("%s:y" % name, ly)
			out.set_single_value("%s:z" % name, lz)
			out.set_single_value("%s:v" % name, vis)
		else:
			out.set_single_value("%s:x" % name, 0.0)
			out.set_single_value("%s:y" % name, 0.0)
			out.set_single_value("%s:z" % name, 0.0)
			out.set_single_value("%s:v" % name, 0.0)


	return out
