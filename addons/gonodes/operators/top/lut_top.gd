class_name LUTTOP
extends GNTopBase
## Applies a 3D LUT (Look-Up Table) for colour grading.
##
## Supports .cube (Adobe/Resolve) and .3dl (Autodesk) LUT files.
## The LUT is parsed on CPU once when the file changes, uploaded as a
## Texture3D, and applied via a trivial fragment shader every frame.

var _lut_texture: ImageTexture3D = null
var _lut_path_cache: String = ""


func _init() -> void:
	node_type = "lut"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture to grade")
	add_output("out", GNFamily.Type.TOP, "Colour-graded texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("lut_file", "Path to the lut file",
		PackedStringArray(["*.cube", "*.3dl"]),
		"LUT File", "Path to .cube or .3dl LUT file"))
	add_parameter(GNParameter.create_float("intensity", 1.0, 0.0, 1.0, 0.01,
		"Intensity", "Blend between original (0) and graded (1)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		return null

	var lut_path: String = get_param_value("lut_file")
	if lut_path.is_empty():
		# Pass through ungraded
		if _cached_tex_data == null:
			_cached_tex_data = GNTextureData.new()
		_cached_tex_data.texture = tex_in.texture
		_cached_tex_data.resolution = tex_in.resolution
		return _cached_tex_data

	# Rebuild LUT texture when path changes
	if lut_path != _lut_path_cache:
		_lut_path_cache = lut_path
		node_error = ""
		_lut_texture = _load_lut(lut_path)
		if _lut_texture == null and node_error.is_empty():
			node_error = "Failed to load LUT: %s" % lut_path
		if _lut_texture == null:
			GNLogger.warn("LUTTOP", "'%s' — %s" % [id, node_error])

	if _lut_texture == null:
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/lut.gdshader", true, false, res)
	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("lut_tex", _lut_texture)
	_material.set_shader_parameter("intensity", get_param_value("intensity"))

	_cached_tex_data.resolution = res
	return _cached_tex_data


# ═══════════════════════════════════════════════════════════════════════════════
# LUT Parsing
# ═══════════════════════════════════════════════════════════════════════════════

func _load_lut(path: String) -> ImageTexture3D:
	var resolved: String = GNResourceLoader.resolve(path, project_dir)
	if resolved.is_empty():
		node_error = "Cannot resolve LUT path: %s" % path
		return null
	if not FileAccess.file_exists(resolved):
		node_error = "LUT file not found: %s" % resolved
		return null
	if resolved.ends_with(".cube"):
		return _parse_cube(resolved)
	elif resolved.ends_with(".3dl"):
		return _parse_3dl(resolved)
	node_error = "Unsupported LUT format (use .cube or .3dl)"
	return null


func _parse_cube(path: String) -> ImageTexture3D:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var size: int = 33
	var data: PackedFloat32Array = PackedFloat32Array()
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("LUT_3D_SIZE"):
			size = int(line.split(" ")[-1])
			continue
		if line.begins_with("TITLE") or line.begins_with("DOMAIN_MIN") or line.begins_with("DOMAIN_MAX"):
			continue
		var parts: PackedStringArray = line.split(" ", false)
		if parts.size() >= 3:
			data.append(float(parts[0]))
			data.append(float(parts[1]))
			data.append(float(parts[2]))
	file.close()
	return _build_texture_3d(data, size)


func _parse_3dl(path: String) -> ImageTexture3D:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var size: int = 0
	var data: PackedFloat32Array = PackedFloat32Array()
	var max_val: float = 4095.0
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parts: PackedStringArray = line.split(" ", false)
		if parts.is_empty():
			parts = line.split("\t", false)
		if parts.size() == 1 and size == 0:
			# Mesh line — skip header
			continue
		if parts.size() >= 3:
			if size == 0:
				# First data line; detect bit depth from value range
				var test_val: float = float(parts[0])
				if test_val > 1.0:
					max_val = 4095.0  # 12-bit
				else:
					max_val = 1.0
			data.append(float(parts[0]) / max_val)
			data.append(float(parts[1]) / max_val)
			data.append(float(parts[2]) / max_val)
			size += 1
	file.close()
	# Cube root to get dimension
	var dim: int = int(round(pow(float(size), 1.0 / 3.0)))
	if dim * dim * dim != size:
		GNLogger.warn("LUTTOP", "3DL entry count %d is not a perfect cube" % size)
		return null
	return _build_texture_3d(data, dim)


func _build_texture_3d(data: PackedFloat32Array, size: int) -> ImageTexture3D:
	var expected: int = size * size * size * 3
	if data.size() < expected:
		GNLogger.warn("LUTTOP", "LUT has %d floats, expected %d for %d^3" % [data.size(), expected, size])
		return null

	# Build per-slice Images for ImageTexture3D
	var images: Array[Image] = []
	for z in range(size):
		var img_data := PackedByteArray()
		img_data.resize(size * size * 4)  # RGBA8
		for y in range(size):
			for x in range(size):
				var idx: int = (z * size * size + y * size + x) * 3
				var r: int = clampi(int(data[idx] * 255.0), 0, 255)
				var g: int = clampi(int(data[idx + 1] * 255.0), 0, 255)
				var b: int = clampi(int(data[idx + 2] * 255.0), 0, 255)
				var pixel_idx: int = (y * size + x) * 4
				img_data[pixel_idx] = r
				img_data[pixel_idx + 1] = g
				img_data[pixel_idx + 2] = b
				img_data[pixel_idx + 3] = 255
		var slice := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, img_data)
		images.append(slice)

	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBA8, size, size, size, false, images)
	return tex
