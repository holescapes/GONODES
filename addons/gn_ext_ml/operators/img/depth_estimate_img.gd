class_name DepthEstimateIMG
extends GNImgBase
## Monocular depth estimation via MiDaS ONNX model.
##
## Accepts an IMG input and produces a single-channel depth map image.
## Brighter = closer, darker = farther (or inverted via parameter).
##
## Requires the gn_ext_ml GDExtension (GNOnnxInference class).

var _session := GNMlSession.new()

const MODEL_W := 256
const MODEL_H := 256


func _init() -> void:
	node_type = "depthestimate"
	node_description = "Monocular depth estimation — outputs a depth map. Requires gn_ext_ml."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])

func _init_ports() -> void:
	add_input("image", GNFamily.Type.IMG, true, "Source image / video", "Image")
	add_output("out", GNFamily.Type.IMG, "Depth map image", "Out")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("model_path", "res://addons/gn_ext_ml/models/midas_v21_small_256.onnx",
		PackedStringArray(["*.onnx"]),
		"Model", "Path to MiDaS depth estimation ONNX model"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "Output resolution",
		"Output depth map resolution"))
	add_parameter(GNParameter.create_bool("invert", false, "Invert",
		"Invert depth (dark=close, bright=far)"))
	add_parameter(GNParameter.create_bool("normalize", true, "Normalize",
		"Normalize depth range to [0, 1]"))
	add_parameter(GNParameter.create_enum("provider",
		PackedStringArray(["CPU", "DirectML", "CUDA", "CoreML"]), 0,
		"Provider", "ONNX execution provider"))
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable estimation"))


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
		GNLogger.error("DepthEstimateIMG", "'%s': %s" % [id, _session.last_error])
		return null

	var mean := PackedFloat32Array([0.485, 0.456, 0.406])
	var std := PackedFloat32Array([0.229, 0.224, 0.225])
	if not _session.run_image_normalized(in_img.image, MODEL_W, MODEL_H, mean, std):
		node_warning = _session.last_error
		GNLogger.error("DepthEstimateIMG", "'%s': %s" % [id, _session.last_error])
		return null

	var output_names: PackedStringArray = _session.output_names()

	if output_names.is_empty():
		return null

	# MiDaS outputs [1, 256, 256] disparity map (inverse depth)
	var raw: PackedFloat32Array = _session.output_float(output_names[0])
	if raw.is_empty():
		return null

	var do_normalize: bool = get_param_value("normalize")
	var do_invert: bool = get_param_value("invert")

	# Find min/max for normalization
	var dmin := INF
	var dmax := -INF
	if do_normalize:
		for v in raw:
			if v < dmin: dmin = v
			if v > dmax: dmax = v

	var range_val: float = dmax - dmin if dmax > dmin else 1.0

	# Build grayscale RGBA image
	var res: Vector2i = get_param_value("resolution")
	var out_w: int = res.x if res.x > 0 else MODEL_W
	var out_h: int = res.y if res.y > 0 else MODEL_H

	# Depth is at model resolution, we'll create at model res then resize
	var depth_bytes := PackedByteArray()
	depth_bytes.resize(MODEL_W * MODEL_H * 4)
	for i in range(mini(raw.size(), MODEL_W * MODEL_H)):
		var d: float = raw[i]
		if do_normalize:
			d = (d - dmin) / range_val
		else:
			d = clampf(d, 0.0, 1.0)
		if do_invert:
			d = 1.0 - d
		var b: int = clampi(int(d * 255.0), 0, 255)
		var idx := i * 4
		depth_bytes[idx] = b
		depth_bytes[idx + 1] = b
		depth_bytes[idx + 2] = b
		depth_bytes[idx + 3] = 255

	var depth_img := Image.create_from_data(MODEL_W, MODEL_H, false, Image.FORMAT_RGBA8, depth_bytes)
	if out_w != MODEL_W or out_h != MODEL_H:
		depth_img.resize(out_w, out_h, Image.INTERPOLATE_BILINEAR)

	out.set_image(depth_img)
	return out
