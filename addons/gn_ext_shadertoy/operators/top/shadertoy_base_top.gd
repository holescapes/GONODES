class_name ShadertoyBaseTOP
extends GNTopBase
## Abstract base for pre-baked Shadertoy shader conversions.
##
## Subclasses set [member _shader_path], [member _shadertoy_url],
## [member _credits], and [member _is_generator].  This base class handles
## the common viewport + shader pipeline, time/mouse/frame uniform binding,
## read-only credit params, and input texture wiring.
##
## Generator TOPs (no input):  resolution param + time-animated output.
## Effect TOPs (one input):    inherit resolution from input, apply shader.


# ── Subclass must override ────────────────────────────────────────────────────

## Path to the converted .gdshader file (set in subclass _init).
var _shader_path: String = ""

## Original Shadertoy URL for credit display.
var _shadertoy_url: String = ""

## Author / credit string.
var _credits: String = ""

## True for generator TOPs (no inputs); false for effect TOPs (one input).
var _is_generator: bool = true

## Number of iChannel texture inputs the shader uses (0 for generators).
var _input_tex_count: int = 0

## Frame counter for iFrame uniform.
var _frame_count: int = 0


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _init_ports() -> void:
	for i in range(_input_tex_count):
		add_input("in%d" % i, GNFamily.Type.TOP, false,
			"Texture input %d (iChannel%d in original shader)" % [i, i])
	add_output("out", GNFamily.Type.TOP, "Shader output texture")


func _init_parameters() -> void:
	if _is_generator:
		add_parameter(GNParameter.create_vector2i("resolution",
			Vector2i(512, 512), "", "Output texture resolution in pixels"))

	# Read-only credit parameters — visible but not editable.
	# Only show the Shadertoy URL when the shader actually came from Shadertoy.
	if not _shadertoy_url.is_empty():
		var url_param := GNParameter.create_string("shadertoy_url", _shadertoy_url,
			"Shadertoy URL", "Original Shadertoy shader URL")
		url_param.read_only = true
		add_parameter(url_param)

	var credit_param := GNParameter.create_string("credits", _credits,
		"Credits", "Shader author and license")
	credit_param.read_only = true
	add_parameter(credit_param)


func _cook(inputs: Array[GNData]) -> GNData:
	# ── Resolution ──
	var res := Vector2i(512, 512)
	if _is_generator:
		res = get_param_value("resolution")
	else:
		var tex_in := _get_input_top(inputs, 0)
		if tex_in == null:
			GNLogger.warn(get_script().get_global_name(),
				"'%s' — no valid input" % id)
			return null
		res = tex_in.resolution

	# ── Viewport + shader init ──
	_init_shader_viewport(_shader_path, true, not _is_generator, res)

	if _viewport.size != res:
		_viewport.size = res

	# ── Bind uniforms ──
	_material.set_shader_parameter("gn_resolution", Vector2(res))

	if _material.shader != null:
		# Mouse — placeholder (user can wire via expression or CHOP)
		_material.set_shader_parameter("gn_mouse", Vector4.ZERO)

		# Frame counter
		_material.set_shader_parameter("gn_frame", _frame_count)
		_frame_count += 1

		# Time delta
		_material.set_shader_parameter("gn_time_delta", get_process_delta_time())

	# ── Bind input textures ──
	for i in range(_input_tex_count):
		var tex_in := _get_input_top(inputs, i)
		if tex_in != null:
			_material.set_shader_parameter("gn_tex%d" % i, tex_in.texture)
			if not _is_generator and i == 0 and _canvas is TextureRect:
				(_canvas as TextureRect).texture = tex_in.texture

	_cached_tex_data.resolution = res
	return _cached_tex_data
