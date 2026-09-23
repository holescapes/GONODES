class_name SegmentationIMG
extends GNImgBase
## Person / background segmentation via ONNX model.
##
## Accepts an IMG input and outputs a binary mask image where
## white = person, black = background.  Useful for compositing,
## virtual backgrounds, and interactive installations.
##
## Requires the gn_ext_ml GDExtension (GNOnnxInference class).

var _onnx: RefCounted = null
var _model_loaded := false
var _last_model: String = ""

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

	if not _is_ml_available():
		GNLogger.warn("SegmentationIMG", "'%s': gn_ext_ml not loaded" % id)
		return null

	if not get_param_value("active"):
		return out

	var in_img: GNImageData = _get_input_img(inputs, 0)
	if in_img == null or in_img.image == null:
		return null

	_ensure_onnx()
	if _onnx == null:
		return null

	var model_path: String = get_param_value("model_path")
	if model_path != _last_model:
		_onnx.release()
		var providers := ["cpu", "directml", "cuda", "coreml"]
		_onnx.set_execution_provider(providers[get_param_value("provider")])
		_model_loaded = _onnx.load_model(model_path)
		_last_model = model_path
		if not _model_loaded:
			GNLogger.error("SegmentationIMG", "'%s': failed to load '%s'" % [id, model_path])

	if not _model_loaded:
		return null

	var img: Image = in_img.image

	var input_names: PackedStringArray = _onnx.get_input_names()
	if input_names.is_empty():
		return null
	_onnx.set_input_from_image(input_names[0], img, MODEL_W, MODEL_H)

	if not _onnx.run():
		return null

	var output_names: PackedStringArray = _onnx.get_output_names()
	if output_names.is_empty():
		return null

	# Selfie segmentation outputs [1, 1, 256, 256] or [1, 256, 256] probability
	var raw: PackedFloat32Array = _onnx.get_output_float(output_names[0])
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


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _is_ml_available() -> bool:
	return ClassDB.class_exists(&"GNOnnxInference")

func _ensure_onnx() -> void:
	if _onnx != null:
		return
	_onnx = ClassDB.instantiate(&"GNOnnxInference")
	if _onnx == null:
		GNLogger.error("SegmentationIMG", "'%s': failed to instantiate GNOnnxInference" % id)
