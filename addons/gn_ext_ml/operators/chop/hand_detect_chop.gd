class_name HandDetectCHOP
extends GNChopBase
## Hand landmark tracking via MediaPipe Hand ONNX model.
##
## Accepts an IMG input (camera/image), detects up to 2 hands, and outputs
## 21 landmarks per hand as CHOP channels: hand0:wrist:x, hand0:wrist:y, etc.
## Wire TOPtoIMG in front of a TOP.
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


var _session := GNMlSession.new()


const MODEL_W := 224
const MODEL_H := 224




func _init() -> void:
	node_type = "handdetect"
	node_description = "Hand landmark tracking — 21 points per hand. Requires gn_ext_ml."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("image", GNFamily.Type.IMG, true, "Camera or still image. Use TOPtoIMG when the source is a TOP.", "Image")
	add_output("out", GNFamily.Type.CHOP, "Hand landmark channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("model_path", "res://addons/gn_ext_ml/models/hand_landmark_lite.onnx",
		PackedStringArray(["*.onnx"]),
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
	if not get_param_value("active"):
		return _cached_channel_data

	node_warning = ""
	var in_img: GNImageData = GNMlSession.image_input(inputs)
	if in_img == null or in_img.image == null:
		return null

	var model_path: String = get_param_value("model_path")
	if not _session.begin(int(get_param_value("provider")), model_path, project_dir):
		node_warning = _session.last_error
		GNLogger.error("HandDetectCHOP", "'%s': %s" % [id, _session.last_error])
		return null

	if not _session.run_image(in_img.image, MODEL_W, MODEL_H):
		node_warning = _session.last_error
		GNLogger.error("HandDetectCHOP", "'%s': %s" % [id, _session.last_error])
		return null

	var output_names: PackedStringArray = _session.output_names()

	if output_names.is_empty():
		return null


	# Hand landmark model typically outputs [1, 63] = 21 landmarks × 3 (x, y, z)
	var raw: PackedFloat32Array = _session.output_float(output_names[0])
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
		var conf_raw: PackedFloat32Array = _session.output_float(output_names[1])
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
