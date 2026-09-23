class_name PoseDetectCHOP
extends GNChopBase
## Body pose estimation via BlazePose ONNX model.
##
## Accepts a TOP input (camera/image), runs pose detection, and outputs
## 33 body keypoints as CHOP channels: joint_name:x, joint_name:y,
## joint_name:z, joint_name:v (visibility).
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

var _onnx: RefCounted = null
var _model_loaded := false
var _last_model: String = ""

# Input image dimensions expected by BlazePose
const MODEL_W := 256
const MODEL_H := 256


func _init() -> void:
	node_type = "posedetect"
	time_dependent = true
	node_description = "Body pose estimation — 33 keypoints as CHOP channels. Requires gn_ext_ml."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])

func _init_ports() -> void:
	add_input("image", GNFamily.Type.TOP, true, "Camera / video input", "Image")
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
	if not _is_ml_available():
		GNLogger.warn("PoseDetectCHOP", "'%s': gn_ext_ml not loaded" % id)
		return null

	if not get_param_value("active"):
		return _cached_channel_data

	var in_tex: GNTextureData = _get_input_top(inputs, 0)
	if in_tex == null or in_tex.texture == null:
		return null

	_ensure_onnx()
	if _onnx == null:
		return null

	# Load / switch model
	var model_path: String = get_param_value("model_path")
	if model_path != _last_model:
		_onnx.release()
		var providers := ["cpu", "directml", "cuda", "coreml"]
		_onnx.set_execution_provider(providers[get_param_value("provider")])
		_model_loaded = _onnx.load_model(model_path)
		_last_model = model_path
		if not _model_loaded:
			GNLogger.error("PoseDetectCHOP", "'%s': failed to load model '%s'" % [id, model_path])

	if not _model_loaded:
		return null

	# Get input image
	var img: Image = in_tex.texture.get_image()
	if img == null:
		return null

	# Set input tensor (NCHW, normalized to [0,1])
	var input_names: PackedStringArray = _onnx.get_input_names()
	if input_names.is_empty():
		return null
	_onnx.set_input_from_image(input_names[0], img, MODEL_W, MODEL_H)

	# Run inference
	if not _onnx.run():
		return null

	# Parse output — BlazePose outputs landmarks as [1, 33, 5] or [1, 195]
	# (33 × 5: x, y, z, visibility, presence) or similar flat layout
	var output_names: PackedStringArray = _onnx.get_output_names()
	if output_names.is_empty():
		return null

	var raw: PackedFloat32Array = _onnx.get_output_float(output_names[0])
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


func _get_input_top(inputs: Array[GNData], idx: int) -> GNTextureData:
	if idx >= inputs.size():
		return null
	return inputs[idx] as GNTextureData


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _is_ml_available() -> bool:
	return ClassDB.class_exists(&"GNOnnxInference")

func _ensure_onnx() -> void:
	if _onnx != null:
		return
	_onnx = ClassDB.instantiate(&"GNOnnxInference")
	if _onnx == null:
		GNLogger.error("PoseDetectCHOP", "'%s': failed to instantiate GNOnnxInference" % id)
