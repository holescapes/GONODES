class_name TouchPaintTOP
extends GNTopBase
## Accumulates a grayscale damage / attention mask from normalized touch
## coordinates.  Each paint stroke adds a radial falloff (smooth or gaussian)
## centered at (cx, cy).  Optional input seeds or replaces the mask buffer.
##
## Output is an ImageTexture (L8) suitable as a CustomShader mask input.
## Untouched pixels stay at 0 when accumulate starts from a clear buffer.

## CPU-side mask buffer (FORMAT_L8).
var _mask: Image = null
var _tex: ImageTexture = null
var _last_res: Vector2i = Vector2i.ZERO
var _was_clear: bool = false
var _was_paint: bool = false
## When true, next cook may seed from optional input TOP (after res create).
var _needs_seed: bool = false


func _init() -> void:
	node_type = "touch_paint"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Optional seed / prior mask texture", "In")
	add_output("out", GNFamily.Type.TOP, "Accumulated grayscale damage mask", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512),
		"Resolution", "Mask resolution in pixels"))
	add_parameter(GNParameter.create_float("cx", 0.5, 0.0, 1.0, 0.001,
		"Center X", "Normalized touch X (0–1)"))
	add_parameter(GNParameter.create_float("cy", 0.5, 0.0, 1.0, 0.001,
		"Center Y", "Normalized touch Y (0–1)"))
	add_parameter(GNParameter.create_float("radius_px", 80.0, 1.0, 2000.0, 1.0,
		"Radius", "Paint radius in pixels at current resolution"))
	add_parameter(GNParameter.create_float("strength", 0.1, 0.0, 1.0, 0.01,
		"Strength", "Intensity added per paint event (clamped to 1)"))
	add_parameter(GNParameter.create_enum("falloff",
		PackedStringArray(["Smooth", "Gaussian"]), 0,
		"Falloff", "Radial falloff shape"))
	add_parameter(GNParameter.create_bool("accumulate", true,
		"Accumulate", "Add into existing mask (off = replace stroke only on paint)"))
	add_parameter(GNParameter.create_bool("paint", false,
		"Paint", "When true, apply a stroke this cook (drive from touch)"))
	add_parameter(GNParameter.create_bool("clear", false,
		"Clear", "Pulse: zero the mask, then auto-resets to false"))


func _cook(inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	res = Vector2i(maxi(res.x, 1), maxi(res.y, 1))

	var do_clear: bool = get_param_value("clear")
	if do_clear and not _was_clear:
		_ensure_mask(res, true)
		set_param_value("clear", false)
	_was_clear = do_clear

	_ensure_mask(res, false)

	# Optional seed from input when mask was just (re)created empty
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if _needs_seed and tex_in != null and tex_in.texture != null and _mask != null:
		_seed_from_texture(tex_in)
		_needs_seed = false

	var do_paint: bool = get_param_value("paint")
	if do_paint:
		var cx: float = clampf(float(get_param_value("cx")), 0.0, 1.0)
		var cy: float = clampf(float(get_param_value("cy")), 0.0, 1.0)
		var radius: float = maxf(float(get_param_value("radius_px")), 1.0)
		var strength: float = clampf(float(get_param_value("strength")), 0.0, 1.0)
		var falloff: int = int(get_param_value("falloff"))
		var accumulate: bool = get_param_value("accumulate")
		if not accumulate:
			_mask.fill(Color(0, 0, 0, 1))
		_paint_stroke(cx, cy, radius, strength, falloff)
	_was_paint = do_paint

	if _tex == null:
		_tex = ImageTexture.create_from_image(_mask)
	else:
		_tex.update(_mask)

	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _tex
	_cached_tex_data.resolution = res
	return _cached_tex_data


## Direct ImageTexture upload — skip SubViewport UPDATE_ONCE path.
func execute_cook(inputs_data: Array[GNData], frame: int) -> GNData:
	var start_time := Time.get_ticks_usec()
	var result := _cook(inputs_data)
	cook_time_ms = (Time.get_ticks_usec() - start_time) / 1000.0
	if result != null:
		result.timestamp = frame
		result.valid = true
		cached_output = result
		cook_valid = true
	else:
		cached_output = null
		cook_valid = false
	clear_dirty()
	node_cooked.emit(id)
	return result


func _ensure_mask(res: Vector2i, force_clear: bool) -> void:
	if _mask == null or _last_res != res or force_clear:
		_mask = Image.create(res.x, res.y, false, Image.FORMAT_L8)
		_mask.fill(Color(0, 0, 0, 1))
		_last_res = res
		_tex = null
		# Seed from input after resolution (re)create, not after explicit clear pulse
		_needs_seed = not force_clear


func _seed_from_texture(tex_in: GNTextureData) -> void:
	var img: Image = tex_in.get_readback_image()
	if img == null:
		return
	if img.get_width() != _mask.get_width() or img.get_height() != _mask.get_height():
		img = img.duplicate()
		img.resize(_mask.get_width(), _mask.get_height(), Image.INTERPOLATE_BILINEAR)
	if img.get_format() != Image.FORMAT_L8:
		img.convert(Image.FORMAT_L8)
	_mask.copy_from(img)
	_tex = null


func _paint_stroke(cx: float, cy: float, radius_px: float, strength: float, falloff: int) -> void:
	var w: int = _mask.get_width()
	var h: int = _mask.get_height()
	var px: float = cx * float(w - 1)
	var py: float = cy * float(h - 1)
	var r: float = radius_px
	var r2: float = r * r
	var x0: int = clampi(int(floor(px - r)), 0, w - 1)
	var x1: int = clampi(int(ceil(px + r)), 0, w - 1)
	var y0: int = clampi(int(floor(py - r)), 0, h - 1)
	var y1: int = clampi(int(ceil(py + r)), 0, h - 1)

	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx: float = float(x) - px
			var dy: float = float(y) - py
			var d2: float = dx * dx + dy * dy
			if d2 > r2:
				continue
			var t: float = sqrt(d2) / r
			var fall: float
			if falloff == 1:
				# Gaussian-ish: e^{-4 t^2}
				fall = exp(-4.0 * t * t)
			else:
				# Smoothstep complement
				fall = 1.0 - t * t * (3.0 - 2.0 * t)
			var add: float = strength * fall
			var cur: float = _mask.get_pixel(x, y).r
			var nxt: float = clampf(cur + add, 0.0, 1.0)
			_mask.set_pixel(x, y, Color(nxt, nxt, nxt, 1.0))


## Test helper — returns a duplicate of the CPU mask (null if none).
func get_mask_image() -> Image:
	if _mask == null:
		return null
	return _mask.duplicate() as Image
