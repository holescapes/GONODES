## Shadertoy extension boot script — registers code editor language and param row
## code param so the core editor knows how to handle "shadertoy_code" params.
extends RefCounted


static func boot() -> void:
	# Register "shadertoy_code" as a code-editor-eligible param
	GNParamRow.register_code_param("shadertoy_code")

	# Register Shadertoy code language with highlighting and preset folder
	GNCodeEditor.register_code_language("shadertoy_code", {
		"preset_folder": "shadertoy",
		"highlighter": _apply_shadertoy_highlighter,
		"ref_text": "void mainImage(out vec4 fragColor, in vec2 fragCoord)  |  iTime, iResolution, iMouse, iChannel0..3, iFrame, iTimeDelta",
		"file_ext": ".glsl",
	})


## Shadertoy GLSL syntax highlighting — mainImage format with all iXxx built-ins.
static func _apply_shadertoy_highlighter(code_edit: CodeEdit) -> void:
	var h := CodeHighlighter.new()

	# Numbers
	h.number_color = Color(0.72, 0.86, 0.56)

	# Strings
	h.add_color_region('"', '"', Color(0.87, 0.72, 0.45))

	# Comments
	h.add_color_region("//", "", Color(0.45, 0.45, 0.45), true)
	h.add_color_region("/*", "*/", Color(0.45, 0.45, 0.45))

	# Shadertoy built-in uniforms
	for kw in ["iTime", "iTimeDelta", "iFrame", "iDate",
			"iResolution", "iMouse",
			"iChannel0", "iChannel1", "iChannel2", "iChannel3",
			"iChannelResolution", "iSampleRate",
			"fragCoord", "fragColor"]:
		h.add_keyword_color(kw, Color(0.55, 0.8, 1.0))

	# GLSL keywords
	for kw in ["void", "if", "else", "for", "while", "return", "discard",
			"true", "false", "const", "struct", "in", "out", "inout",
			"uniform", "varying", "precision", "mediump", "highp", "lowp"]:
		h.add_keyword_color(kw, Color(0.95, 0.5, 0.6))

	# GLSL types
	for kw in ["float", "int", "bool", "vec2", "vec3", "vec4",
			"ivec2", "ivec3", "ivec4", "mat2", "mat3", "mat4",
			"sampler2D", "sampler3D", "samplerCube"]:
		h.add_keyword_color(kw, Color(0.5, 0.85, 0.95))

	# GLSL math functions
	for fn in ["sin", "cos", "tan", "abs", "floor", "ceil", "round",
			"clamp", "mix", "step", "smoothstep", "length", "normalize",
			"dot", "cross", "reflect", "refract", "pow", "sqrt",
			"min", "max", "mod", "fract", "sign", "texture",
			"distance", "atan", "asin", "acos", "exp", "log",
			"inversesqrt", "radians", "degrees"]:
		h.add_keyword_color(fn, Color(0.6, 0.7, 0.95))

	# mainImage entry point
	h.add_keyword_color("mainImage", Color(0.4, 0.9, 0.5))

	# Constants
	for kw in ["PI", "TAU"]:
		h.add_keyword_color(kw, Color(0.55, 0.8, 1.0))

	h.symbol_color = Color(0.7, 0.7, 0.7)
	h.function_color = Color(0.5, 0.85, 0.95)
	h.member_variable_color = Color(0.85, 0.85, 0.75)

	code_edit.syntax_highlighter = h
