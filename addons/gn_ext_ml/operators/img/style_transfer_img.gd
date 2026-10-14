class_name StyleTransferIMG
extends GNImgBase
## Neural style transfer via ONNX model.
##
## Accepts a content IMG input and applies an artistic style using a
## pre-trained fast style transfer model (e.g. Mosaic, Candy, Udnie).
##
## Requires the gn_ext_ml GDExtension (GNOnnxInference class).

var _session := GNMlSession.new()

const MODEL_W := 224
const MODEL_H := 224
const STYLE_FILES := [
	"style_mosaic.onnx",
	"style_candy.onnx",
	"style_udnie.onnx",
	"style_rain_princess.onnx",
	"style_pointilism.onnx",
]


## Built-in Johnson styles, or the custom file when [param style_idx] is past that list.
static func model_for_style(style_idx: int, custom_path: String) -> String:
	if style_idx < 0 or style_idx >= STYLE_FILES.size():
		return custom_path
	return "res://addons/gn_ext_ml/models/" + STYLE_FILES[style_idx]


func _init() -> void:
	node_type = "styletransfer"
	node_description = "Neural style transfer — apply artistic styles. Requires gn_ext_ml."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])

func _init_ports() -> void:
	add_input("content", GNFamily.Type.IMG, true, "Content image to stylize", "Content")
	add_output("out", GNFamily.Type.IMG, "Stylized image", "Out")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("style",
		PackedStringArray(["Mosaic", "Candy", "Udnie", "Rain Princess", "Pointillism", "Custom"]), 0,
		"Style", "Fast style trained on one picture. Custom uses the model file."))
	add_parameter(GNParameter.create_file("model_path", "res://addons/gn_ext_ml/models/style_mosaic.onnx",
		PackedStringArray(["*.onnx"]),
		"Model", "ONNX file used when Style is Custom. The built-in styles ignore this path."))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "Output resolution",
		"Output resolution"))
	add_parameter(GNParameter.create_float("strength", 1.0, 0.0, 1.0,
		0.01, "Strength", "Blend between original (0) and stylized (1)"))
	add_parameter(GNParameter.create_enum("provider",
		PackedStringArray(["CPU", "DirectML", "CUDA", "CoreML"]), 0,
		"Provider", "ONNX execution provider"))
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable style transfer"))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()

	if not get_param_value("active"):
		return out

	node_warning = ""
	var in_img: GNImageData = GNMlSession.image_input(inputs)
	if in_img == null or in_img.image == null:
		return null

	var model_path := model_for_style(int(get_param_value("style")), str(get_param_value("model_path")))
	if not _session.begin(int(get_param_value("provider")), model_path, project_dir):
		node_warning = _session.last_error
		GNLogger.error("StyleTransferIMG", "'%s': %s" % [id, _session.last_error])
		return null

	var model_size := _session.image_size(MODEL_W, MODEL_H)
	if not _session.run_image(in_img.image, model_size.x, model_size.y):
		node_warning = _session.last_error
		GNLogger.error("StyleTransferIMG", "'%s': %s" % [id, _session.last_error])
		return null

	var output_names: PackedStringArray = _session.output_names()

	if output_names.is_empty():
		return null

	# Output: [1, 3, H, W] float — NCHW, values in [0, 255] or similar
	var raw: PackedFloat32Array = _session.output_float(output_names[0])
	if raw.is_empty():
		return null

	var shape: PackedInt32Array = _session.output_shape(output_names[0])
	var out_h: int = shape[2] if shape.size() >= 4 else MODEL_H
	var out_w: int = shape[3] if shape.size() >= 4 else MODEL_W
	var num_px := out_w * out_h

	# Convert NCHW back to RGBA8
	var result_bytes := PackedByteArray()
	result_bytes.resize(num_px * 4)

	# Find range for normalization
	var vmin := INF
	var vmax := -INF
	for v in raw:
		if v < vmin: vmin = v
		if v > vmax: vmax = v
	var range_val: float = vmax - vmin if vmax > vmin else 1.0

	var strength: float = get_param_value("strength")

	# Get original pixels for blending
	var orig_img: Image = null
	if strength < 1.0:
		orig_img = in_img.image.duplicate()
		if orig_img.get_format() != Image.FORMAT_RGB8:
			orig_img.convert(Image.FORMAT_RGB8)
		orig_img.resize(out_w, out_h, Image.INTERPOLATE_BILINEAR)

	var orig_px: PackedByteArray = orig_img.get_data() if orig_img != null else PackedByteArray()

	for i in range(num_px):
		# NCHW: channel c at offset c * num_px + i
		var r: float = clampf((raw[i] - vmin) / range_val, 0.0, 1.0)
		var g: float = clampf((raw[num_px + i] - vmin) / range_val, 0.0, 1.0)
		var b: float = clampf((raw[2 * num_px + i] - vmin) / range_val, 0.0, 1.0)

		if strength < 1.0 and orig_px.size() >= (i + 1) * 3:
			var or_: float = orig_px[i * 3] / 255.0
			var og: float = orig_px[i * 3 + 1] / 255.0
			var ob: float = orig_px[i * 3 + 2] / 255.0
			r = lerpf(or_, r, strength)
			g = lerpf(og, g, strength)
			b = lerpf(ob, b, strength)

		var idx := i * 4
		result_bytes[idx] = clampi(int(r * 255.0), 0, 255)
		result_bytes[idx + 1] = clampi(int(g * 255.0), 0, 255)
		result_bytes[idx + 2] = clampi(int(b * 255.0), 0, 255)
		result_bytes[idx + 3] = 255

	var result_img := Image.create_from_data(out_w, out_h, false, Image.FORMAT_RGBA8, result_bytes)
	var res: Vector2i = get_param_value("resolution")
	if res.x > 0 and res.y > 0 and (res.x != out_w or res.y != out_h):
		result_img.resize(res.x, res.y, Image.INTERPOLATE_BILINEAR)

	out.set_image(result_img)
	return out
