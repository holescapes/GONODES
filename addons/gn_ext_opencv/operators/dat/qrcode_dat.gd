class_name QRCodeDAT
extends GNDatBase
## QR / barcode detection and decoding.
##
## Detects QR codes and barcodes in the input image and outputs decoded text
## along with bounding-corner positions.  For interactive kiosks, ticket
## scanning, and data-driven installations.
##
## Requires GNOpenCV GDExtension.
##
## Native: GNOpenCV.detect_qrcodes(rgba, w, h)
##         -> Array[Dictionary] each with keys:
##           text: String, points: PackedFloat32Array(8), type: String

var _cv: RefCounted = null


func _init() -> void:
	node_type = "qrcode"
	node_description = "QR / barcode detection and decoding. Requires gn_ext_opencv."


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, true, "Input image", "In")
	add_output("out", GNFamily.Type.DAT, "Decoded text and bounding corners", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable processing"))


func _cook(inputs: Array[GNData]) -> GNData:
	if _cached_table == null:
		_cached_table = GNTableData.new()

	_cached_table.set_headers(PackedStringArray([
		"text", "type",
		"x0", "y0", "x1", "y1", "x2", "y2", "x3", "y3"]))

	if not GNOpenCVHelper.is_available() or not get_param_value("active"):
		return _cached_table

	var src: GNImageData = inputs[0] as GNImageData if inputs.size() > 0 and inputs[0] is GNImageData else null
	if src == null or src.image == null:
		return _cached_table

	_ensure_cv()
	if _cv == null:
		return _cached_table

	var conv := GNOpenCVHelper.image_to_rgba(src.image)
	var rgba: PackedByteArray = conv[0]
	var w: int = conv[1]
	var h: int = conv[2]
	if rgba.is_empty():
		return _cached_table

	var codes: Array = _cv.detect_qrcodes(rgba, w, h)
	for code in codes:
		var text: String = code.get("text", "")
		var qr_type: String = code.get("type", "QR")
		var pts: PackedFloat32Array = code.get("points", PackedFloat32Array())
		var row := PackedStringArray()
		row.append(text)
		row.append(qr_type)
		# 4 corners (8 floats)
		for i in range(8):
			if i < pts.size():
				row.append("%.1f" % pts[i])
			else:
				row.append("0")
		_cached_table.append_row(row)

	return _cached_table


func _ensure_cv() -> void:
	if _cv != null:
		return
	_cv = GNOpenCVHelper.create_instance()
	if _cv == null:
		GNLogger.error("QRCodeDAT", "'%s': failed to instantiate GNOpenCV" % id)
