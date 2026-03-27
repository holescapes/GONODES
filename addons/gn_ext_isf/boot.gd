## ISF extension boot script — registers code editor language and param row
## code param so the core editor knows how to handle "isf_code" params.
extends RefCounted


static func boot() -> void:
	# Register "isf_code" as a code-editor-eligible param
	GNParamRow.register_code_param("isf_code")

	# Register ISF code language with highlighting and preset folder
	GNCodeEditor.register_code_language("isf_code", {
		"preset_folder": "isf",
		"highlighter": _apply_isf_highlighter,
		"ref_text": "ISF: TIME, RENDERSIZE, isf_FragNormCoord, gl_FragColor | IMG_PIXEL, IMG_NORM_PIXEL, IMG_THIS_PIXEL, IMG_SIZE",
		"file_ext": ".fs",
	})


## ISF (Interactive Shader Format) syntax highlighting.
## JSON header block + GLSL body with ISF built-ins and image functions.
static func _apply_isf_highlighter(code_edit: CodeEdit) -> void:
	var h := CodeHighlighter.new()

	# Numbers
	h.number_color = Color(0.72, 0.86, 0.56)

	# Strings
	h.add_color_region('"', '"', Color(0.87, 0.72, 0.45))

	# ISF JSON header block /*{ ... }*/
	h.add_color_region("/*", "*/", Color(0.78, 0.68, 0.45))

	# Line comments
	h.add_color_region("//", "", Color(0.45, 0.45, 0.45), true)

	# ISF JSON metadata keys
	for kw in ["DESCRIPTION", "CREDIT", "ISFVSN", "CATEGORIES",
			"INPUTS", "PASSES", "IMPORTED",
			"NAME", "LABEL", "TYPE", "DEFAULT", "MIN", "MAX",
			"VALUES", "LABELS",
			"TARGET", "PERSISTENT", "FLOAT", "WIDTH", "HEIGHT",
			"PATH", "MIPMAP"]:
		h.add_keyword_color(kw, Color(0.9, 0.78, 0.42))

	# ISF input type strings
	for kw in ["float", "bool", "long", "point2D", "color",
			"image", "event", "audio", "audioFFT"]:
		h.add_keyword_color(kw, Color(0.5, 0.85, 0.95))

	# ISF GLSL built-in variables
	for kw in ["RENDERSIZE", "TIMEDELTA", "DATE", "FRAMEINDEX", "PASSINDEX",
			"isf_FragNormCoord", "gl_FragColor", "gl_FragCoord",
			"TIME", "PI", "TAU"]:
		h.add_keyword_color(kw, Color(0.55, 0.8, 1.0))

	# ISF image functions
	for fn in ["IMG_PIXEL", "IMG_NORM_PIXEL", "IMG_THIS_PIXEL",
			"IMG_THIS_NORM_PIXEL", "IMG_SIZE"]:
		h.add_keyword_color(fn, Color(0.4, 0.9, 0.55))

	# GLSL keywords
	for kw in ["void", "if", "else", "for", "while", "return", "discard",
			"true", "false", "const", "struct", "in", "out", "inout",
			"uniform", "varying", "precision", "mediump", "highp", "lowp"]:
		h.add_keyword_color(kw, Color(0.95, 0.5, 0.6))

	# GLSL types
	for kw in ["int", "vec2", "vec3", "vec4",
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

	h.symbol_color = Color(0.7, 0.7, 0.7)
	h.function_color = Color(0.5, 0.85, 0.95)
	h.member_variable_color = Color(0.85, 0.85, 0.75)

	code_edit.syntax_highlighter = h
