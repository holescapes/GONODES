class_name ObjectDetectDAT
extends GNDatBase
## Object detection via YOLO/SSD ONNX model.
##
## Accepts an IMG input and outputs a table of detected objects with
## columns: label, confidence, x1, y1, x2, y2 (bounding box corners,
## normalized 0-1). Wire TOPtoIMG in front of a TOP.
##
## Requires the gn_ext_ml GDExtension (GNOnnxInference class).


# COCO 80-class label names (standard YOLO output classes)
const COCO_LABELS := [
	"person", "bicycle", "car", "motorcycle", "airplane", "bus", "train",
	"truck", "boat", "traffic_light", "fire_hydrant", "stop_sign",
	"parking_meter", "bench", "bird", "cat", "dog", "horse", "sheep",
	"cow", "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella",
	"handbag", "tie", "suitcase", "frisbee", "skis", "snowboard",
	"sports_ball", "kite", "baseball_bat", "baseball_glove", "skateboard",
	"surfboard", "tennis_racket", "bottle", "wine_glass", "cup", "fork",
	"knife", "spoon", "bowl", "banana", "apple", "sandwich", "orange",
	"broccoli", "carrot", "hot_dog", "pizza", "donut", "cake", "chair",
	"couch", "potted_plant", "bed", "dining_table", "toilet", "tv",
	"laptop", "mouse", "remote", "keyboard", "cell_phone", "microwave",
	"oven", "toaster", "sink", "refrigerator", "book", "clock", "vase",
	"scissors", "teddy_bear", "hair_drier", "toothbrush",
]


var _session := GNMlSession.new()


const MODEL_W := 640
const MODEL_H := 640




func _init() -> void:
	node_type = "objectdetect"
	node_description = "Object detection — table of bounding boxes. Requires gn_ext_ml."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("image", GNFamily.Type.IMG, true, "Camera or still image. Use TOPtoIMG when the source is a TOP.", "Image")
	add_output("out", GNFamily.Type.DAT, "Detection table", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("model_path", "res://addons/gn_ext_ml/models/yolov8n.onnx",
		PackedStringArray(["*.onnx"]),
		"Model", "YOLO ONNX file you supply. Ultralytics YOLOv8 weights are AGPL-3.0 and are not downloaded."))
	add_parameter(GNParameter.create_float("confidence", 0.25, 0.0, 1.0,
		0.01, "Confidence", "Minimum detection confidence threshold"))
	add_parameter(GNParameter.create_float("nms_threshold", 0.45, 0.0, 1.0,
		0.01, "NMS Threshold", "Non-maximum suppression IoU threshold"))
	add_parameter(GNParameter.create_int("max_detections", 100, 1, 1000,
		"Max Detections", "Maximum number of detections"))
	add_parameter(GNParameter.create_enum("provider",
		PackedStringArray(["CPU", "DirectML", "CUDA", "CoreML"]), 0,
		"Provider", "ONNX execution provider"))
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable detection"))




func _cook(inputs: Array[GNData]) -> GNData:
	if not get_param_value("active"):
		return cached_output

	node_warning = ""
	var in_img: GNImageData = GNMlSession.image_input(inputs)
	if in_img == null or in_img.image == null:
		return null

	var model_path: String = get_param_value("model_path")
	if not _session.begin(int(get_param_value("provider")), model_path, project_dir):
		node_warning = _session.last_error
		GNLogger.error("ObjectDetectDAT", "'%s': %s" % [id, _session.last_error])
		return null

	if not _session.run_image(in_img.image, MODEL_W, MODEL_H):
		node_warning = _session.last_error
		GNLogger.error("ObjectDetectDAT", "'%s': %s" % [id, _session.last_error])
		return null

	var output_names: PackedStringArray = _session.output_names()

	if output_names.is_empty():
		return null


	var raw: PackedFloat32Array = _session.output_float(output_names[0])
	var shape: PackedInt32Array = _session.output_shape(output_names[0])
	if raw.is_empty():
		return null


	var conf_thresh: float = get_param_value("confidence")
	var nms_thresh: float = get_param_value("nms_threshold")
	var max_det: int = get_param_value("max_detections")


	# Build output table
	var out := GNTableData.new()
	out.is_table = true
	out.set_headers(PackedStringArray(["label", "confidence", "x1", "y1", "x2", "y2"]))


	# YOLOv8 output: [1, 84, 8400] — transposed: 84 rows × 8400 columns
	# Row 0-3: cx, cy, w, h; rows 4-83: class probabilities
	var detections: Array[Dictionary] = []


	if shape.size() >= 3:
		var num_classes: int = shape[1] - 4 if shape[1] > 4 else 80
		var num_boxes: int = shape[2] if shape.size() >= 3 else 0


		for b in range(num_boxes):
			# Find best class for this box
			var best_conf := 0.0
			var best_class := 0
			for c in range(num_classes):
				var score: float = raw[(4 + c) * num_boxes + b]
				if score > best_conf:
					best_conf = score
					best_class = c


			if best_conf < conf_thresh:
				continue


			# Box: center x/y, width, height — normalized by model dims
			var cx: float = raw[0 * num_boxes + b] / MODEL_W
			var cy: float = raw[1 * num_boxes + b] / MODEL_H
			var bw: float = raw[2 * num_boxes + b] / MODEL_W
			var bh: float = raw[3 * num_boxes + b] / MODEL_H


			detections.append({
				"class": best_class,
				"conf": best_conf,
				"x1": clampf(cx - bw * 0.5, 0.0, 1.0),
				"y1": clampf(cy - bh * 0.5, 0.0, 1.0),
				"x2": clampf(cx + bw * 0.5, 0.0, 1.0),
				"y2": clampf(cy + bh * 0.5, 0.0, 1.0),
			})


	# Sort by confidence descending
	detections.sort_custom(func(a, b): return a["conf"] > b["conf"])


	# Simple NMS
	var kept: Array[Dictionary] = []
	for det in detections:
		if kept.size() >= max_det:
			break
		var dominated := false
		for k in kept:
			if k["class"] == det["class"] and _iou(k, det) > nms_thresh:
				dominated = true
				break
		if not dominated:
			kept.append(det)


	# Write to table
	for det in kept:
		var label: String = COCO_LABELS[det["class"]] if det["class"] < COCO_LABELS.size() else "class_%d" % det["class"]
		out.append_row(PackedStringArray([
			label,
			"%.3f" % det["conf"],
			"%.4f" % det["x1"],
			"%.4f" % det["y1"],
			"%.4f" % det["x2"],
			"%.4f" % det["y2"],
		]))


	return out




func _iou(a: Dictionary, b: Dictionary) -> float:
	var x1 := maxf(a["x1"], b["x1"])
	var y1 := maxf(a["y1"], b["y1"])
	var x2 := minf(a["x2"], b["x2"])
	var y2 := minf(a["y2"], b["y2"])
	var inter := maxf(0.0, x2 - x1) * maxf(0.0, y2 - y1)
	var area_a: float = (a["x2"] - a["x1"]) * (a["y2"] - a["y1"])
	var area_b: float = (b["x2"] - b["x1"]) * (b["y2"] - b["y1"])
	var union_area: float = area_a + area_b - inter
	return inter / union_area if union_area > 0.0 else 0.0
