class_name TOPtoSOP
extends GNSopBase
## Converts a TOP texture into SOP geometry — a displaced grid mesh where
## each vertex height is driven by pixel luminance.
##
## Modes:
##   • Heightfield — Creates an NxN grid and displaces Y by luminance.
##   • Point Cloud — Every pixel with luminance above a threshold becomes a
##     point in 3D (x = col, y = luminance, z = row).
##   • Normal Map — Creates a flat grid and stores the texture RGB as vertex
##     colours or normals (useful for baking).
##
## Useful for terrain generation, data-driven mesh sculpting, and image-to-3D
## workflows.

func _init() -> void:
	node_type = "top_to_sop"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, true, "Source TOP texture", "In")
	add_output("out", GNFamily.Type.SOP, "Generated geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Heightfield", "Point Cloud", "Normal Map"]),
		0, "Mode", "Conversion method"))
	add_parameter(GNParameter.create_int("resolution", 64, 4, 512,
		"Resolution", "Grid subdivisions (clamped to image size)"))
	add_parameter(GNParameter.create_float("height_scale", 2.0, 0.0, 100.0, 0.1,
		"Height Scale", "Vertical displacement multiplier"))
	add_parameter(GNParameter.create_float("grid_size", 10.0, 0.1, 1000.0, 0.5,
		"Grid Size", "Horizontal extent of the grid"))
	add_parameter(GNParameter.create_float("threshold", 0.1, 0.0, 1.0, 0.01,
		"Threshold", "Luminance threshold for Point Cloud mode"))
	add_parameter(GNParameter.create_enum("channel",
		PackedStringArray(["Luminance", "Red", "Green", "Blue", "Alpha"]),
		0, "Channel", "Which channel drives displacement"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_data: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_data == null or tex_data.texture == null:
		return null

	var img: Image = tex_data.texture.get_image()
	if img == null:
		return null

	var mode: int = get_param_value("mode")
	var res: int = get_param_value("resolution")
	var height_scale: float = get_param_value("height_scale")
	var grid_size: float = get_param_value("grid_size")
	var threshold: float = get_param_value("threshold")
	var channel: int = get_param_value("channel")

	var img_w: int = img.get_width()
	var img_h: int = img.get_height()
	if img_w == 0 or img_h == 0:
		return null

	# Clamp resolution to image dimensions
	res = mini(res, mini(img_w, img_h))

	var out := _prepare_geo()

	match mode:
		0:
			_build_heightfield(img, res, img_w, img_h, height_scale, grid_size, channel, out)
		1:
			_build_point_cloud(img, res, img_w, img_h, height_scale, grid_size, threshold, channel, out)
		2:
			_build_normal_map_grid(img, res, img_w, img_h, grid_size, out)

	return out


func _sample_channel(color: Color, channel: int) -> float:
	match channel:
		0:  # Luminance
			return color.r * 0.299 + color.g * 0.587 + color.b * 0.114
		1: return color.r
		2: return color.g
		3: return color.b
		4: return color.a
	return color.r * 0.299 + color.g * 0.587 + color.b * 0.114


func _build_heightfield(img: Image, res: int, img_w: int, img_h: int,
		height_scale: float, grid_size: float, channel: int, out: GNGeoData) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var half: float = grid_size * 0.5
	var step: float = grid_size / float(res - 1) if res > 1 else grid_size

	# Generate vertices
	for iz in range(res):
		for ix in range(res):
			var u: float = float(ix) / float(res - 1) if res > 1 else 0.5
			var v: float = float(iz) / float(res - 1) if res > 1 else 0.5
			var px: int = clampi(int(u * (img_w - 1)), 0, img_w - 1)
			var py: int = clampi(int(v * (img_h - 1)), 0, img_h - 1)
			var color: Color = img.get_pixel(px, py)
			var h: float = _sample_channel(color, channel) * height_scale

			verts.append(Vector3(-half + ix * step, h, -half + iz * step))
			uvs.append(Vector2(u, v))

	# Generate indices
	for iz in range(res - 1):
		for ix in range(res - 1):
			var tl: int = iz * res + ix
			var tr: int = tl + 1
			var bl: int = (iz + 1) * res + ix
			var br: int = bl + 1
			indices.append(tl)
			indices.append(bl)
			indices.append(tr)
			indices.append(tr)
			indices.append(bl)
			indices.append(br)

	# Compute normals
	normals.resize(verts.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO
	for ti in range(indices.size() / 3):
		var i0: int = indices[ti * 3]
		var i1: int = indices[ti * 3 + 1]
		var i2: int = indices[ti * 3 + 2]
		var e1: Vector3 = verts[i1] - verts[i0]
		var e2: Vector3 = verts[i2] - verts[i0]
		var fn: Vector3 = e1.cross(e2)
		normals[i0] += fn
		normals[i1] += fn
		normals[i2] += fn
	for i in range(normals.size()):
		var len: float = normals[i].length()
		if len > 0.0001:
			normals[i] /= len
		else:
			normals[i] = Vector3.UP

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.set_mesh(mesh)


func _build_point_cloud(img: Image, res: int, img_w: int, img_h: int,
		height_scale: float, grid_size: float, threshold: float, channel: int,
		out: GNGeoData) -> void:
	var verts := PackedVector3Array()
	var half: float = grid_size * 0.5

	var step_x: int = maxi(img_w / res, 1)
	var step_y: int = maxi(img_h / res, 1)

	for iy in range(0, img_h, step_y):
		for ix in range(0, img_w, step_x):
			var color: Color = img.get_pixel(ix, iy)
			var val: float = _sample_channel(color, channel)
			if val < threshold:
				continue
			var u: float = float(ix) / float(img_w - 1) if img_w > 1 else 0.5
			var v: float = float(iy) / float(img_h - 1) if img_h > 1 else 0.5
			verts.append(Vector3(
				-half + u * grid_size,
				val * height_scale,
				-half + v * grid_size))

	if verts.is_empty():
		return

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	out.set_mesh(mesh)


func _build_normal_map_grid(img: Image, res: int, img_w: int, img_h: int,
		grid_size: float, out: GNGeoData) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var half: float = grid_size * 0.5
	var step: float = grid_size / float(res - 1) if res > 1 else grid_size

	for iz in range(res):
		for ix in range(res):
			var u: float = float(ix) / float(res - 1) if res > 1 else 0.5
			var v: float = float(iz) / float(res - 1) if res > 1 else 0.5
			verts.append(Vector3(-half + ix * step, 0.0, -half + iz * step))
			uvs.append(Vector2(u, v))

			# Sample normal from image
			var px: int = clampi(int(u * (img_w - 1)), 0, img_w - 1)
			var py: int = clampi(int(v * (img_h - 1)), 0, img_h - 1)
			var color: Color = img.get_pixel(px, py)
			# Normal map convention: RGB -> XYZ mapped from [0,1] to [-1,1]
			var n := Vector3(
				color.r * 2.0 - 1.0,
				color.b * 2.0 - 1.0,  # B maps to Y (up)
				color.g * 2.0 - 1.0)
			var nlen: float = n.length()
			if nlen > 0.0001:
				n /= nlen
			else:
				n = Vector3.UP
			normals.append(n)

	for iz in range(res - 1):
		for ix in range(res - 1):
			var tl: int = iz * res + ix
			var tr: int = tl + 1
			var bl: int = (iz + 1) * res + ix
			var br: int = bl + 1
			indices.append(tl)
			indices.append(bl)
			indices.append(tr)
			indices.append(tr)
			indices.append(bl)
			indices.append(br)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.set_mesh(mesh)
