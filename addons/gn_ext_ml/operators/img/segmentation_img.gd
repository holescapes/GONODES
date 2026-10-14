class_name SegmentationIMG
extends GNImgBase
## Person / background segmentation via ONNX model.
##
## Accepts an IMG input and outputs a binary mask image where
## white = person, black = background.  Useful for compositing,
## virtual backgrounds, and interactive installations.
##
## Requires the gn_ext_ml GDExtension (GNOnnxInference class).

var _session := GNMlSession.new()

const MODEL_W := 256
const MODEL_H := 256


func _init() -> void:
	node_type = "segmentation"
	node_description = "Person segmentation — outputs a mask image. Requires gn_ext_ml."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])

func _init_ports() -> void:
	add_input("image", GNFamily.Type.IMG, true, "Camera / video input", "Image")
	add_output("out", GNFamily.Type.IMG, "Segmentation mask", "Out")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("model_path", "res://addons/gn_ext_ml/models/selfie_segmentation.onnx",
		PackedStringArray(["*.onnx"]),
		"Model", "Path to segmentation ONNX model"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "Output resolution",
		"Output mask resolution"))
	add_parameter(GNParameter.create_float("threshold", 0.5, 0.0, 1.0,
		0.01, "Threshold", "Segmentation confidence threshold"))
	add_parameter(GNParameter.create_bool("soft_mask", false, "Soft Mask",
		"Output smooth probability instead of hard binary mask"))
	add_parameter(GNParameter.create_bool("invert", false, "Invert",
		"Invert mask (white = background)"))
	add_parameter(GNParameter.create_enum("provider",
		PackedStringArray(["CPU", "DirectML", "CUDA", "CoreML"]), 0,
		"Provider", "ONNX execution provider"))
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable segmentation"))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()

	if not get_param_value("active"):
		return out

	node_warning = ""
	var in_img: GNImageData = GNMlSession.image_input(inputs)
	if in_img == null or in_img.image == null:
		return null

	var model_path: String = get_param_value("model_path")
	if not _session.begin(int(get_param_value("provider")), model_path, project_dir):
		node_warning = _session.last_error
		GNLogger.error("SegmentationIMG", "'%s': %s" % [id, _session.last_error])
		return null

	if not _session.run_image(in_img.image, MODEL_W, MODEL_H):
		node_warning = _session.last_error
		GNLogger.error("SegmentationIMG", "'%s': %s" % [id, _session.last_error])
		return null

	var output_names: PackedStringArray = _session.output_names()

	if output_names.is_empty():
		return null

	# Selfie segmentation outputs [1, 1, 256, 256] or [1, 256, 256] probability
	var raw: PackedFloat32Array = _session.output_float(output_names[0])
	if raw.is_empty():
		return null

	var threshold: float = get_param_value("threshold")
	var soft_mask: bool = get_param_value("soft_mask")
	var do_invert: bool = get_param_value("invert")

	# Build grayscale RGBA mask
	var mask_bytes := PackedByteArray()
	mask_bytes.resize(MODEL_W * MODEL_H * 4)
	for i in range(mini(raw.size(), MODEL_W * MODEL_H)):
		var prob: float = clampf(raw[i], 0.0, 1.0)
		var val: float
		if soft_mask:
			val = prob
		else:
			val = 1.0 if prob >= threshold else 0.0
		if do_invert:
			val = 1.0 - val
		var b: int = clampi(int(val * 255.0), 0, 255)
		var idx := i * 4
		mask_bytes[idx] = b
		mask_bytes[idx + 1] = b
		mask_bytes[idx + 2] = b
		mask_bytes[idx + 3] = 255

	var mask_img := Image.create_from_data(MODEL_W, MODEL_H, false, Image.FORMAT_RGBA8, mask_bytes)
	var res: Vector2i = get_param_value("resolution")
	if res.x > 0 and res.y > 0 and (res.x != MODEL_W or res.y != MODEL_H):
		mask_img.resize(res.x, res.y, Image.INTERPOLATE_BILINEAR)

	out.set_image(mask_img)
	return out
