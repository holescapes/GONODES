class_name TOPtoDAT
extends GNDatBase
## Converts TOP texture metadata or pixel data into a DAT table.
## Info mode outputs width, height, format; Pixels mode outputs per-pixel RGBA.


func _init() -> void:
	node_type = "top_to_dat"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "TOP texture input", "In")
	add_output("out", GNFamily.Type.DAT, "Texture data table", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Info", "Pixels"]), 0,
		"Mode", "Info outputs metadata; Pixels outputs per-pixel RGBA"))
	add_parameter(GNParameter.create_int("max_pixels", 100, 1, 10000,
		"Max Pixels", "Maximum number of pixels to output (Pixels mode)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_table()
	out.is_table = true
	out.has_header = true

	if inputs.size() == 0 or not (inputs[0] is GNTextureData):
		GNLogger.warn("TOPtoDAT", "No valid TOP input connected.")
		out.set_headers(PackedStringArray(["attribute", "value"]))
		return out

	var tex_data: GNTextureData = inputs[0] as GNTextureData
	var mode: int = get_param_value("mode")

	if mode == 0:
		_extract_info(tex_data, out)
	else:
		_extract_pixels(tex_data, out)

	return out


## Extracts texture metadata as a key-value table.
func _extract_info(tex_data: GNTextureData, tbl: GNTableData) -> void:
	tbl.set_headers(PackedStringArray(["attribute", "value"]))
	tbl.append_row(PackedStringArray(["width", str(tex_data.resolution.x)]))
	tbl.append_row(PackedStringArray(["height", str(tex_data.resolution.y)]))
	tbl.append_row(PackedStringArray(["format", str(tex_data.format)]))
	tbl.append_row(PackedStringArray(["aspect", "%.4f" % tex_data.get_aspect()]))

	if tex_data.texture != null:
		tbl.append_row(PackedStringArray(["texture_class", tex_data.texture.get_class()]))
		tbl.append_row(PackedStringArray(["has_texture", "true"]))
	else:
		tbl.append_row(PackedStringArray(["has_texture", "false"]))


## Extracts per-pixel RGBA data into a table (limited by max_pixels).
func _extract_pixels(tex_data: GNTextureData, tbl: GNTableData) -> void:
	tbl.set_headers(PackedStringArray(["x", "y", "r", "g", "b", "a"]))

	if tex_data.texture == null:
		GNLogger.warn("TOPtoDAT", "No texture available for pixel extraction.")
		return

	var image: Image = tex_data.texture.get_image()
	if image == null:
		GNLogger.warn("TOPtoDAT", "Cannot get Image from texture.")
		return

	var max_px: int = get_param_value("max_pixels")
	var width: int = image.get_width()
	var height: int = image.get_height()
	var count: int = 0

	for y in range(height):
		for x in range(width):
			if count >= max_px:
				return
			var pixel: Color = image.get_pixel(x, y)
			tbl.append_row(PackedStringArray([
				str(x), str(y),
				"%.4f" % pixel.r, "%.4f" % pixel.g,
				"%.4f" % pixel.b, "%.4f" % pixel.a
			]))
			count += 1
