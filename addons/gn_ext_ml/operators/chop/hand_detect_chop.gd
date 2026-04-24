class_name HandDetectCHOP
extends GNChopBase
## Hand landmark tracking via MediaPipe Hand ONNX model.
##
## Accepts a TOP input (camera/image), detects up to 2 hands, and outputs
## 21 landmarks per hand as CHOP channels: hand0:wrist:x, hand0:wrist:y, etc.
##
## Requires the gn_ext_ml GDExtension (GNOnnxInference class) and
## a hand landmark ONNX model in the models/ directory.

# MediaPipe 21 hand landmark names
const HAND_LANDMARKS := [
	"wrist",
	"thumb_cmc", "thumb_mcp", "thumb_ip", "thumb_tip",
	"index_mcp", "index_pip", "index_dip", "index_tip",
	"middle_mcp", "middle_pip", "middle_dip", "middle_tip",
	"ring_mcp", "ring_pip", "ring_dip", "ring_tip",
	"pinky_mcp", "pinky_pip", "pinky_dip", "pinky_tip",
]

var _onnx: RefCounted = null
var _model_loaded := false
var _last_model: String = ""

const MODEL_W := 224
const MODEL_H := 224


func _init() -> void:
	node_type = "handdetect"
	time_dependent = true
	node_description = "Hand landmark tracking — 21 points per hand. Requires gn_ext_ml."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])

func _init_ports() -> void:
	add_input("image", GNFamily.Type.TOP, true, "Camera / video input", "Image")
	add_output("out", GNFamily.Type.CHOP, "Hand landmark channels")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("model_path",
		"res://addons/gn_ext_ml/models/hand_landmark_lite.onnx",
		"Model", "Path to hand landmark ONNX model"))
	add_parameter(GNParameter.create_int("max_hands", 2, 1, 4,
		"Max Hands", "Maximum number of hands to detect"))
	add_parameter(GNParameter.create_float("min_confidence", 0.5, 0.0, 1.0,
		0.01, "Min Confidence", "Minimum hand detection confidence"))
	add_parameter(GNParameter.create_enum("provider",
		PackedStringArray(["CPU", "DirectML", "CUDA", "CoreML"]), 0,
		"Provider", "ONNX execution provider"))
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable detection"))


func _cook(inputs: Array[GNData]) -> GNData:
	if not _is_ml_available():
		GNLogger.warn("HandDetectCHOP", "'%s': gn_ext_ml not loaded" % id)
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
			GNLogger.error("HandDetectCHOP", "'%s': failed to load model '%s'" % [id, model_path])

	if not _model_loaded:
		return null

	var img: Image = in_tex.texture.get_image()
	if img == null:
		return null

	var input_names: PackedStringArray = _onnx.get_input_names()
	if input_names.is_empty():
		return null
	_onnx.set_input_from_image(input_names[0], img, MODEL_W, MODEL_H)

	if not _onnx.run():
		return null

	var output_names: PackedStringArray = _onnx.get_output_names()
	if output_names.is_empty():
		return null

	# Hand landmark model typically outputs [1, 63] = 21 landmarks × 3 (x, y, z)
	var raw: PackedFloat32Array = _onnx.get_output_float(output_names[0])
	if raw.is_empty():
		return null

	var min_conf: float = get_param_value("min_confidence")
	var max_hands: int = get_param_value("max_hands")
	var out: GNChannelData = _prepare_output(60.0)

	# Parse — each hand has 21 landmarks × 3 values (x, y, z)
	var points_per_hand := 21
	var vals_per_point := 3
	var vals_per_hand := points_per_hand * vals_per_point
	var num_hands := mini(max_hands, raw.size() / vals_per_hand)

	# Check for handedness/confidence output
	var hand_conf := 1.0
	if output_names.size() > 1:
		var conf_raw: PackedFloat32Array = _onnx.get_output_float(output_names[1])
		if not conf_raw.is_empty():
			hand_conf = conf_raw[0]

	for h in range(num_hands):
		if hand_conf < min_conf:
			continue
		var prefix := "hand%d" % h
		for p in range(points_per_hand):
			var base := h * vals_per_hand + p * vals_per_point
			if base + 2 >= raw.size():
				break
			var name: String = HAND_LANDMARKS[p] if p < HAND_LANDMARKS.size() else "pt%d" % p
			out.set_single_value("%s:%s:x" % [prefix, name], raw[base])
			out.set_single_value("%s:%s:y" % [prefix, name], raw[base + 1])
			out.set_single_value("%s:%s:z" % [prefix, name], raw[base + 2])

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
		GNLogger.error("HandDetectCHOP", "'%s': failed to instantiate GNOnnxInference" % id)
