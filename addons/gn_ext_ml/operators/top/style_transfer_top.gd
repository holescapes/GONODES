class_name StyleTransferTOP
extends GNTopBase
## Neural style transfer via ONNX model.
##
## Accepts a content TOP input and applies an artistic style using a
## pre-trained fast style transfer model (e.g. Mosaic, Candy, Udnie).
##
## Requires the gn_ext_ml GDExtension (GNOnnxInference class).

var _onnx: RefCounted = null
var _model_loaded := false
var _last_model: String = ""

const MODEL_W := 256
const MODEL_H := 256


func _init() -> void:
	node_type = "styletransfer"
	time_dependent = true
	node_description = "Neural style transfer — apply artistic styles. Requires gn_ext_ml."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])

func _init_ports() -> void:
	add_input("content", GNFamily.Type.TOP, true, "Content image to stylize", "Content")
	add_output("out", GNFamily.Type.TOP, "Stylized texture")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("model_path",
		"res://addons/gn_ext_ml/models/style_mosaic.onnx",
		"Model", "Path to style transfer ONNX model"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "",
		"Output resolution"))
	add_parameter(GNParameter.create_float("strength", 1.0, 0.0, 1.0,
		0.01, "Strength", "Blend between original (0) and stylized (1)"))
	add_parameter(GNParameter.create_enum("provider",
		PackedStringArray(["CPU", "DirectML", "CUDA", "CoreML"]), 0,
		"Provider", "ONNX execution provider"))
	add_parameter(GNParameter.create_bool("active", true, "",
		"Enable / disable style transfer"))


func _cook(inputs: Array[GNData]) -> GNData:
	if not _is_ml_available():
		GNLogger.warn("StyleTransferTOP", "'%s': gn_ext_ml not loaded" % id)
		return null

	if not get_param_value("active"):
		return _cached_tex_data

	var in_tex: GNTextureData = _get_input_top(inputs, 0)
	if in_tex == null or in_tex.texture == null:
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
			GNLogger.error("StyleTransferTOP", "'%s': failed to load '%s'" % [id, model_path])

	if not _model_loaded:
		return null

	var img: Image = in_tex.texture.get_image()
	if img == null:
		return null

	# Style transfer models typically expect [0, 255] or [0, 1] NCHW
	var input_names: PackedStringArray = _onnx.get_input_names()
	if input_names.is_empty():
		return null
	_onnx.set_input_from_image(input_names[0], img, MODEL_W, MODEL_H)

	if not _onnx.run():
		return null

	var output_names: PackedStringArray = _onnx.get_output_names()
	if output_names.is_empty():
		return null

	# Output: [1, 3, H, W] float — NCHW, values in [0, 255] or similar
	var raw: PackedFloat32Array = _onnx.get_output_float(output_names[0])
	if raw.is_empty():
		return null

	var shape: PackedInt32Array = _onnx.get_output_shape(output_names[0])
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
		orig_img = in_tex.texture.get_image()
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
		out_w = res.x
		out_h = res.y

	var tex := ImageTexture.create_from_image(result_img)
	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = tex
	_cached_tex_data.resolution = Vector2i(out_w, out_h)
	_cached_tex_data.format = Image.FORMAT_RGBA8
	return _cached_tex_data


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _is_ml_available() -> bool:
	return ClassDB.class_exists(&"GNOnnxInference")

func _ensure_onnx() -> void:
	if _onnx != null:
		return
	_onnx = ClassDB.instantiate(&"GNOnnxInference")
	if _onnx == null:
		GNLogger.error("StyleTransferTOP", "'%s': failed to instantiate GNOnnxInference" % id)
