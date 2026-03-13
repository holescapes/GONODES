class_name OpticalFlowTOPNative
extends GNTopBase
## Native-accelerated optical flow — delegates CPU-side flow computation
## to GNNativeOpticalFlowTop (C++) when available.

var _processor: RefCounted = null
var _prev_image: Image = null


func _init() -> void:
	node_type = "opticalflow"
	time_dependent = true
	node_description = "Motion vector estimation between frames — native C++ accelerated."
	if ClassDB.class_exists("GNNativeOpticalFlowTop"):
		_processor = ClassDB.instantiate("GNNativeOpticalFlowTop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Optical flow vectors (R=horiz, G=vert, B=magnitude)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "", "Output resolution"))
	add_parameter(GNParameter.create_float("sensitivity", 20.0, 1.0, 100.0, 0.1, "Sensitivity", ""))
	add_parameter(GNParameter.create_float("smoothing", 0.1, 0.001, 1.0, 0.001, "Smoothing", ""))
	add_parameter(GNParameter.create_int("iterations", 4, 1, 16, "Iterations", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if in_data == null or in_data.texture == null:
		return null

	var curr_image: Image = in_data.texture.get_image()
	if curr_image == null:
		return null

	if _prev_image == null:
		_prev_image = curr_image.duplicate()
		return null

	if _processor != null:
		var iterations: int = get_param_value("iterations")
		var lambda: float = get_param_value("smoothing")
		var scale: float = get_param_value("sensitivity")
		var result_image: Image = _processor.process(_prev_image, curr_image,
			iterations, lambda, scale)
		_prev_image = curr_image.duplicate()

		if result_image != null:
			var out := GNTextureData.new()
			out.set_from_image(result_image)
			return out

	_prev_image = curr_image.duplicate()
	return null
