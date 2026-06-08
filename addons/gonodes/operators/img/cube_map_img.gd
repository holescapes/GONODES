class_name CubeMapIMG
extends GNImgBase
## Assembles or extracts cubemap faces using CPU Image operations.
##
## Modes:
##   - Assemble: Takes 6 IMG inputs (+X, -X, +Y, -Y, +Z, -Z) and packs them
##     into a horizontal cross layout (4x3 grid) output image.
##   - Extract: Takes a single cross-layout or equirectangular IMG and outputs
##     one face at a time (select which face via parameter).
##   - Equirect to Cross: Converts a single equirectangular panorama into the
##     4x3 cross layout for cubemap usage.
##
## Useful for skyboxes, reflection probes, IBL, and environment map authoring.
## Use ImgToTOP to upload the result to the GPU texture pipeline.


static var FACE_NAMES := PackedStringArray(["+X", "-X", "+Y", "-Y", "+Z", "-Z"])

# Cross layout positions (4 cols x 3 rows):  +X right, -X left, +Y top, -Y bottom, +Z front, -Z back
static var CROSS_POSITIONS := [
	Vector2i(2, 1),  # +X
	Vector2i(0, 1),  # -X
	Vector2i(1, 0),  # +Y
	Vector2i(1, 2),  # -Y
	Vector2i(1, 1),  # +Z
	Vector2i(3, 1),  # -Z
]


func _init() -> void:
	node_type = "cube_map"


func _init_ports() -> void:
	# In Assemble mode, inputs 0-5 are the 6 faces; in Extract/Equirect mode only input 0 is used
	add_input("in0", GNFamily.Type.IMG, false, "+X face / source panorama", "+X / Source")
	add_input("in1", GNFamily.Type.IMG, false, "-X face", "-X")
	add_input("in2", GNFamily.Type.IMG, false, "+Y face", "+Y")
	add_input("in3", GNFamily.Type.IMG, false, "-Y face", "-Y")
	add_input("in4", GNFamily.Type.IMG, false, "+Z face", "+Z")
	add_input("in5", GNFamily.Type.IMG, false, "-Z face", "-Z")
	add_output("out", GNFamily.Type.IMG, "Cubemap output image", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Assemble", "Extract Face", "Equirect to Cross"]),
		0, "Mode", "Operation mode"))
	add_parameter(GNParameter.create_enum("extract_face",
		FACE_NAMES, 0, "Extract Face", "Which face to extract (Extract mode only)"))
	add_parameter(GNParameter.create_int("face_size", 256, 1, 4096,
		"Face Size", "Resolution of each face in pixels"))


func get_active_input_indices() -> PackedInt32Array:
	var mode: int = get_param_value("mode")
	if mode == 0:
		return PackedInt32Array()  # Assemble: all 6 inputs
	return PackedInt32Array([0])  # Extract / Equirect: only input 0


func _cook(inputs: Array[GNData]) -> GNData:
	var mode: int = get_param_value("mode")
	match mode:
		0:
			return _cook_assemble(inputs)
		1:
			return _cook_extract(inputs)
		2:
			return _cook_equirect_to_cross(inputs)
	return null


# ===========================================================================
# Assemble: 6 face inputs -> cross layout
# ===========================================================================

func _cook_assemble(inputs: Array[GNData]) -> GNData:
	var face_size: int = get_param_value("face_size")
	var faces: Array[Image] = []

	for i in range(6):
		var img_data: GNImageData = inputs[i] as GNImageData if i < inputs.size() and inputs[i] is GNImageData else null
		if img_data != null and img_data.image != null:
			var img := img_data.image.duplicate()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(face_size, face_size)
			faces.append(img)
		else:
			faces.append(_blank_face(face_size))

	var cross_w: int = face_size * 4
	var cross_h: int = face_size * 3
	var out_img := Image.create(cross_w, cross_h, false, Image.FORMAT_RGBA8)
	out_img.fill(Color(0.0, 0.0, 0.0, 0.0))

	for i in range(6):
		var pos: Vector2i = CROSS_POSITIONS[i] * face_size
		out_img.blit_rect(faces[i], Rect2i(Vector2i.ZERO, Vector2i(face_size, face_size)), pos)

	return _output_image(out_img, Vector2i(cross_w, cross_h))


# ===========================================================================
# Extract: cross layout input -> single face output
# ===========================================================================

func _cook_extract(inputs: Array[GNData]) -> GNData:
	var img_in: GNImageData = _get_input_img(inputs, 0)
	if img_in == null or img_in.image == null:
		GNLogger.warn("CubeMapIMG", "'%s' -- no valid input for Extract mode" % id)
		return null

	var src_img := img_in.image.duplicate()
	src_img.convert(Image.FORMAT_RGBA8)

	var face_idx: int = get_param_value("extract_face")
	var face_size: int = get_param_value("face_size")

	# Detect layout from aspect ratio
	var sw: int = src_img.get_width()
	var sh: int = src_img.get_height()
	var aspect: float = float(sw) / float(sh) if sh > 0 else 1.0

	var face_img: Image
	if absf(aspect - (4.0 / 3.0)) < 0.1:
		# Cross layout (4:3)
		var cell_w: int = sw / 4
		var cell_h: int = sh / 3
		var pos: Vector2i = CROSS_POSITIONS[face_idx]
		var src_rect := Rect2i(pos.x * cell_w, pos.y * cell_h, cell_w, cell_h)
		face_img = Image.create(cell_w, cell_h, false, Image.FORMAT_RGBA8)
		face_img.blit_rect(src_img, src_rect, Vector2i.ZERO)
	elif absf(aspect - 2.0) < 0.2:
		# Equirectangular (2:1) -- sample the requested face
		var eq_size: int = mini(face_size, 2048)
		face_img = _equirect_face(src_img, face_idx, eq_size)
	else:
		GNLogger.warn("CubeMapIMG", "'%s' -- unrecognized layout (aspect %.2f)" % [id, aspect])
		return null

	if face_img.get_width() != face_size or face_img.get_height() != face_size:
		face_img.resize(face_size, face_size)

	return _output_image(face_img, Vector2i(face_size, face_size))


# ===========================================================================
# Equirect -> Cross: equirectangular panorama -> cross layout
# ===========================================================================

func _cook_equirect_to_cross(inputs: Array[GNData]) -> GNData:
	var img_in: GNImageData = _get_input_img(inputs, 0)
	if img_in == null or img_in.image == null:
		GNLogger.warn("CubeMapIMG", "'%s' -- no valid input for Equirect to Cross mode" % id)
		return null

	var src_img := img_in.image.duplicate()
	src_img.convert(Image.FORMAT_RGBA8)

	var face_size: int = get_param_value("face_size")
	var cross_w: int = face_size * 4
	var cross_h: int = face_size * 3
	var out_img := Image.create(cross_w, cross_h, false, Image.FORMAT_RGBA8)
	out_img.fill(Color(0.0, 0.0, 0.0, 0.0))

	for i in range(6):
		var face_img := _equirect_face(src_img, i, face_size)
		var pos: Vector2i = CROSS_POSITIONS[i] * face_size
		out_img.blit_rect(face_img, Rect2i(Vector2i.ZERO, Vector2i(face_size, face_size)), pos)

	return _output_image(out_img, Vector2i(cross_w, cross_h))


# ===========================================================================
# Helpers
# ===========================================================================

func _blank_face(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 1.0))
	return img


func _output_image(img: Image, res: Vector2i) -> GNData:
	var data := _prepare_image()
	data.image = img
	data.resolution = res
	data.format = img.get_format()
	return data


## Samples an equirectangular image for a specific cubemap face.
## face_idx: 0=+X, 1=-X, 2=+Y, 3=-Y, 4=+Z, 5=-Z
func _equirect_face(src: Image, face_idx: int, size: int) -> Image:
	var face := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var sw: int = src.get_width()
	var sh: int = src.get_height()

	for y in range(size):
		for x in range(size):
			# Map pixel to [-1, 1] on the face
			var u: float = (float(x) + 0.5) / float(size) * 2.0 - 1.0
			var v: float = (float(y) + 0.5) / float(size) * 2.0 - 1.0

			# Convert face UV to 3D direction
			var dir: Vector3 = _face_uv_to_dir(face_idx, u, v)

			# 3D direction -> equirectangular UV
			var theta: float = atan2(dir.x, -dir.z)
			var phi: float = asin(clampf(dir.y, -1.0, 1.0))
			var eq_u: float = (theta / TAU) + 0.5
			var eq_v: float = 0.5 - (phi / PI)

			# Sample source (nearest neighbour for speed)
			var sx: int = clampi(int(eq_u * sw), 0, sw - 1)
			var sy: int = clampi(int(eq_v * sh), 0, sh - 1)
			face.set_pixel(x, y, src.get_pixel(sx, sy))

	return face


func _face_uv_to_dir(face_idx: int, u: float, v: float) -> Vector3:
	match face_idx:
		0:  # +X
			return Vector3(1.0, -v, -u).normalized()
		1:  # -X
			return Vector3(-1.0, -v, u).normalized()
		2:  # +Y
			return Vector3(u, 1.0, v).normalized()
		3:  # -Y
			return Vector3(u, -1.0, -v).normalized()
		4:  # +Z
			return Vector3(u, -v, -1.0).normalized()
		5:  # -Z
			return Vector3(-u, -v, 1.0).normalized()
	return Vector3.FORWARD
