class_name GNMlSession
extends RefCounted
## Owns one ONNX Runtime session for an ML operator.
##
## The operator keeps its own tensor decode. This helper loads the model,
## switches the execution provider, and runs an image. A later AI job holds
## one of these. It does not subclass this class.


var last_error: String = ""

var _onnx: RefCounted = null
var _path: String = ""
var _provider: int = -1

const PROVIDERS := ["cpu", "directml", "cuda", "coreml"]


static func is_runtime_available() -> bool:
	return ClassDB.class_exists(&"GNOnnxInference")


## Load [param model_path] on [param provider_idx] when either changed.
## [param project_dir] resolves a project:// model path.
func begin(provider_idx: int, model_path: String, project_dir: String) -> bool:
	last_error = ""
	if not is_runtime_available():
		last_error = "gn_ext_ml is not loaded"
		return false
	var path := model_path.strip_edges()
	if path.is_empty():
		last_error = "No model path"
		return false
	if _onnx == null:
		_onnx = ClassDB.instantiate(&"GNOnnxInference")
	if _onnx == null:
		last_error = "Failed to create GNOnnxInference"
		return false
	if _onnx.is_loaded() and path == _path and provider_idx == _provider:
		return true
	_onnx.release()
	_onnx.set_project_dir(project_dir)
	var provider_name: String = PROVIDERS[clampi(provider_idx, 0, PROVIDERS.size() - 1)]
	_onnx.set_execution_provider(provider_name)
	if not _onnx.load_model(path):
		_path = ""
		_provider = -1
		last_error = str(_onnx.get_last_error())
		if last_error.is_empty():
			last_error = "Failed to load %s" % path
		return false
	_path = path
	_provider = provider_idx
	return true


func run_image(image: Image, width: int, height: int) -> bool:
	return _run(image, width, height, false, PackedFloat32Array(), PackedFloat32Array())


func run_image_normalized(image: Image, width: int, height: int, mean: PackedFloat32Array, std: PackedFloat32Array) -> bool:
	return _run(image, width, height, true, mean, std)


func output_names() -> PackedStringArray:
	if _onnx == null:
		return PackedStringArray()
	return _onnx.get_output_names()


func output_float(output_name: String) -> PackedFloat32Array:
	if _onnx == null:
		return PackedFloat32Array()
	return _onnx.get_output_float(output_name)


func output_shape(output_name: String) -> PackedInt32Array:
	if _onnx == null:
		return PackedInt32Array()
	return _onnx.get_output_shape(output_name)


## First IMG input, or null when that port is empty or a different type.
static func image_input(inputs: Array[GNData]) -> GNImageData:
	if inputs.is_empty():
		return null
	return inputs[0] as GNImageData


## Spatial size declared by the loaded model, or the fallback when a dim is dynamic.
func image_size(fallback_w: int, fallback_h: int) -> Vector2i:
	if _onnx == null or not _onnx.is_loaded():
		return Vector2i(fallback_w, fallback_h)
	var info: Dictionary = _onnx.get_model_info()
	var inputs: Array = info.get("inputs", [])
	if inputs.is_empty():
		return Vector2i(fallback_w, fallback_h)
	var shape: PackedInt32Array = inputs[0].get("shape", PackedInt32Array())
	if shape.size() >= 4 and shape[2] > 0 and shape[3] > 0:
		return Vector2i(shape[3], shape[2])
	return Vector2i(fallback_w, fallback_h)


func _run(image: Image, width: int, height: int, normalized: bool, mean: PackedFloat32Array, std: PackedFloat32Array) -> bool:
	last_error = ""
	if _onnx == null or not _onnx.is_loaded():
		last_error = "Model is not loaded"
		return false
	if image == null:
		last_error = "No image"
		return false
	var names: PackedStringArray = _onnx.get_input_names()
	if names.is_empty():
		last_error = "Model has no inputs"
		return false
	if normalized:
		_onnx.set_input_from_image_normalized(names[0], image, width, height, mean, std)
	else:
		_onnx.set_input_from_image(names[0], image, width, height)
	if not _onnx.run():
		last_error = str(_onnx.get_last_error())
		if last_error.is_empty():
			last_error = "Inference failed"
		return false
	return true
