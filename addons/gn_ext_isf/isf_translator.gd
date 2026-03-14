class_name ISFTranslator
extends RefCounted
## Translates ISF (Interactive Shader Format) GLSL into Godot canvas_item shaders.
##
## ISF is a GLSL fragment shader format with a JSON metadata header inside a
## /* ... */ comment.  It is the dominant shader interchange format in the VJ
## world (VDMX, MadMapper, Millumin, CoGe, Synesthesia, etc.).
##
## ── Translation map ──────────────────────────────────────────────────────────
##   ISF                                →  Godot canvas_item
##   RENDERSIZE                         →  isf_rendersize  (uniform vec2)
##   TIME                               →  TIME            (Godot built-in)
##   TIMEDELTA                          →  isf_time_delta  (uniform float)
##   DATE                               →  isf_date        (uniform vec4)
##   FRAMEINDEX                         →  isf_frame_index (uniform int)
##   PASSINDEX                          →  isf_pass_index  (uniform int)
##   isf_FragNormCoord                  →  UV              (Godot built-in)
##   gl_FragColor = ...                 →  COLOR = ...
##   IMG_PIXEL(img, coord)              →  texture(img, coord / isf_rendersize)
##   IMG_NORM_PIXEL(img, coord)         →  texture(img, coord)
##   IMG_THIS_PIXEL(img)                →  texture(img, UV)
##   IMG_THIS_NORM_PIXEL(img)           →  texture(img, UV)
##   IMG_SIZE(img)                      →  isf_<img>_size  (uniform vec2)
##   inputImage                         →  isf_inputImage  (uniform sampler2D)
##   INPUTS[float/bool/long/point2D/color] → uniform params (auto-generated)
##   INPUTS[image]                      →  uniform sampler2D
##   PASSES / TARGET / PERSISTENT       →  multi-pass SubViewport pipeline
##
## ── Supported ISF features ───────────────────────────────────────────────────
##   • Single-pass generators, FX and transitions
##   • Multi-pass shaders (PASSES array with TARGET names)
##   • Persistent buffers (PERSISTENT key)
##   • Float-precision buffers (FLOAT key)
##   • Per-pass WIDTH/HEIGHT expressions ($WIDTH, $HEIGHT, $inputName)
##   • All ISF input types: float, bool, long, point2D, color, image, event
##   • IMPORTED image resources
##   • ISF v1 and v2 (vv_FragNormCoord → isf_FragNormCoord backcompat)


# ═══════════════════════════════════════════════════════════════════════════════
# Data Structures
# ═══════════════════════════════════════════════════════════════════════════════

## Describes a single ISF input declared in the JSON header.
class ISFInput:
	var input_name: String = ""
	var type: String = ""           # "float", "bool", "long", "point2D", "color", "image", "event", "audio", "audioFFT"
	var label: String = ""
	var default_value: Variant = null
	var min_value: Variant = null
	var max_value: Variant = null
	var identity_value: Variant = null
	var values: Array = []          # For "long" type — integer values
	var labels: Array = []          # For "long" type — display labels


## Describes a single render pass in a multi-pass ISF shader.
class ISFPass:
	var target: String = ""         # Buffer name this pass renders to
	var persistent: bool = false    # Whether buffer persists across frames
	var is_float: bool = false      # Whether buffer uses 32-bit float precision
	var width_expr: String = ""     # Width expression (e.g. "$WIDTH/4.0")
	var height_expr: String = ""    # Height expression (e.g. "$HEIGHT/4.0")


## Result of a translation attempt.
class TranslationResult:
	var success: bool = false
	var godot_code: String = ""     # Final pass shader code (or single-pass code)
	var pass_codes: Array[String] = []  # Per-pass shader codes (for multi-pass)
	var error: String = ""
	var inputs: Array[ISFInput] = []
	var passes: Array[ISFPass] = []
	var image_inputs: Array[String] = []  # Names of image-type inputs
	var is_generator: bool = true   # True if no "inputImage" input
	var is_transition: bool = false # True if has startImage + endImage + progress
	var description: String = ""
	var credit: String = ""
	var categories: Array = []
	var imported_images: Dictionary = {}  # name → { "PATH": relative_path }
	var uses_time: bool = false
	var uses_time_delta: bool = false
	var uses_date: bool = false
	var uses_frame_index: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════════════

## Translates a complete ISF file (JSON header + GLSL body) into Godot shader(s).
## Returns a [TranslationResult] with the converted code or an error message.
static func translate(isf_source: String) -> TranslationResult:
	var result := TranslationResult.new()

	if isf_source.strip_edges().is_empty():
		result.error = "Empty ISF source"
		return result

	# ── Extract JSON header ──
	var json_dict := _extract_json_header(isf_source)
	if json_dict.is_empty():
		result.error = "No valid ISF JSON header found (expected /* { ... } */ at start)"
		return result

	# ── Parse metadata ──
	result.description = json_dict.get("DESCRIPTION", "")
	result.credit = json_dict.get("CREDIT", "")
	result.categories = json_dict.get("CATEGORIES", [])

	# ── Parse INPUTS ──
	var raw_inputs: Array = json_dict.get("INPUTS", [])
	for raw_input in raw_inputs:
		if raw_input is not Dictionary:
			continue
		var inp := ISFInput.new()
		inp.input_name = str(raw_input.get("NAME", ""))
		inp.type = str(raw_input.get("TYPE", "")).to_lower()
		inp.label = str(raw_input.get("LABEL", ""))
		inp.default_value = raw_input.get("DEFAULT", null)
		inp.min_value = raw_input.get("MIN", null)
		inp.max_value = raw_input.get("MAX", null)
		inp.identity_value = raw_input.get("IDENTITY", null)
		inp.values = raw_input.get("VALUES", [])
		inp.labels = raw_input.get("LABELS", [])
		result.inputs.append(inp)

		if inp.type == "image":
			result.image_inputs.append(inp.input_name)

	# Detect generator/FX/transition
	var has_input_image := false
	var has_start_image := false
	var has_end_image := false
	var has_progress := false
	for inp in result.inputs:
		if inp.input_name == "inputImage":
			has_input_image = true
		if inp.input_name == "startImage":
			has_start_image = true
		if inp.input_name == "endImage":
			has_end_image = true
		if inp.input_name == "progress":
			has_progress = true

	result.is_generator = not has_input_image and not has_start_image
	result.is_transition = has_start_image and has_end_image and has_progress

	# ── Parse PASSES ──
	var raw_passes: Array = json_dict.get("PASSES", [])
	for raw_pass in raw_passes:
		if raw_pass is not Dictionary:
			continue
		var p := ISFPass.new()
		p.target = str(raw_pass.get("TARGET", ""))
		p.persistent = bool(raw_pass.get("PERSISTENT", false))
		p.is_float = bool(raw_pass.get("FLOAT", false))
		p.width_expr = str(raw_pass.get("WIDTH", ""))
		p.height_expr = str(raw_pass.get("HEIGHT", ""))
		result.passes.append(p)

	# ── Parse IMPORTED images ──
	result.imported_images = json_dict.get("IMPORTED", {})

	# ── Extract GLSL body (everything after the JSON comment) ──
	var glsl_body := _extract_glsl_body(isf_source)
	if glsl_body.strip_edges().is_empty():
		result.error = "No GLSL body found after JSON header"
		return result

	# ── Detect built-in usage ──
	result.uses_time = glsl_body.find("TIME") != -1
	result.uses_time_delta = glsl_body.find("TIMEDELTA") != -1
	result.uses_date = glsl_body.find("DATE") != -1
	result.uses_frame_index = glsl_body.find("FRAMEINDEX") != -1

	# ── Translate GLSL ──
	var translated_body := _translate_glsl(glsl_body, result)

	# ── Build complete shader(s) ──
	if result.passes.size() <= 1:
		# Single-pass (or no PASSES declared — default single pass)
		result.godot_code = _build_shader_code(translated_body, result, -1)
		result.pass_codes.append(result.godot_code)
	else:
		# Multi-pass: generate one shader per pass
		for pass_idx in range(result.passes.size()):
			var pass_code := _build_shader_code(translated_body, result, pass_idx)
			result.pass_codes.append(pass_code)
		# The final pass code is the "output" shader
		result.godot_code = result.pass_codes[result.pass_codes.size() - 1]

	result.success = true
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# JSON Header Extraction
# ═══════════════════════════════════════════════════════════════════════════════

## Extracts the JSON dictionary from the ISF header comment /* { ... } */.
static func _extract_json_header(source: String) -> Dictionary:
	# Find the first /* ... */ comment block
	var start := source.find("/*")
	if start == -1:
		return {}
	var end := source.find("*/", start + 2)
	if end == -1:
		return {}

	var json_str := source.substr(start + 2, end - start - 2).strip_edges()

	# Parse JSON
	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK:
		return {}

	var data = json.get_data()
	if data is Dictionary:
		return data
	return {}


## Extracts the GLSL body after the JSON header comment.
static func _extract_glsl_body(source: String) -> String:
	var start := source.find("/*")
	if start == -1:
		return source
	var end := source.find("*/", start + 2)
	if end == -1:
		return ""
	return source.substr(end + 2)


# ═══════════════════════════════════════════════════════════════════════════════
# GLSL Translation
# ═══════════════════════════════════════════════════════════════════════════════

## Translates ISF GLSL conventions to Godot canvas_item equivalents.
static func _translate_glsl(code: String, result: TranslationResult) -> String:
	# ── Strip #version and precision qualifiers ──
	code = _strip_line_starting_with(code, "#version")
	code = _strip_line_starting_with(code, "precision ")

	# ── ISF v1 backcompat: vv_FragNormCoord → isf_FragNormCoord ──
	code = code.replace("vv_FragNormCoord", "isf_FragNormCoord")

	# ── Replace ISF image functions ──
	# Must be done before variable name replacements to avoid partial matches.
	# IMG_THIS_NORM_PIXEL(img) → texture(img, UV)
	code = _replace_img_func(code, "IMG_THIS_NORM_PIXEL", true, true)
	# IMG_THIS_PIXEL(img) → texture(img, UV)
	code = _replace_img_func(code, "IMG_THIS_PIXEL", true, false)
	# IMG_NORM_PIXEL(img, coord) → texture(img, coord)
	code = _replace_img_func(code, "IMG_NORM_PIXEL", false, true)
	# IMG_PIXEL(img, coord) → texture(img, coord / isf_rendersize)
	code = _replace_img_func(code, "IMG_PIXEL", false, false)
	# IMG_SIZE(img) → isf_<img>_size
	code = _replace_img_size(code)

	# ── Replace ISF built-in variables ──
	# RENDERSIZE → isf_rendersize (must be before other replacements)
	code = code.replace("RENDERSIZE", "isf_rendersize")

	# TIMEDELTA → isf_time_delta (must be before TIME replacement)
	code = code.replace("TIMEDELTA", "isf_time_delta")

	# TIME stays as TIME (Godot built-in)
	# No replacement needed — Godot's TIME is the same concept.

	# DATE → isf_date
	code = code.replace("DATE", "isf_date")

	# FRAMEINDEX → isf_frame_index
	code = code.replace("FRAMEINDEX", "isf_frame_index")

	# PASSINDEX → isf_pass_index
	code = code.replace("PASSINDEX", "isf_pass_index")

	# isf_FragNormCoord → UV
	code = code.replace("isf_FragNormCoord", "UV")

	# gl_FragColor → COLOR
	code = code.replace("gl_FragColor", "COLOR")

	# gl_FragCoord → FRAGCOORD
	code = code.replace("gl_FragCoord", "FRAGCOORD")

	# ── Replace texture2D/texture2DRect with texture ──
	code = code.replace("texture2DRect", "texture")
	code = code.replace("texture2D", "texture")

	# ── Rename main() → fragment() ──
	code = _replace_main_func(code)

	return code


## Replaces ISF image sampling functions with Godot texture() calls.
## [param func_name] — the ISF function name to replace.
## [param is_this] — true if the function uses the current fragment's coords (no coord arg).
## [param is_normalized] — true if coordinates are normalized (0-1 range).
static func _replace_img_func(code: String, func_name: String,
		is_this: bool, is_normalized: bool) -> String:
	var result := ""
	var search_pos := 0

	while search_pos < code.length():
		var pos := code.find(func_name, search_pos)
		if pos == -1:
			result += code.substr(search_pos)
			break

		# Check it's not part of a longer identifier
		if pos > 0:
			var before := code[pos - 1]
			if before.is_valid_identifier() or before == "_":
				result += code.substr(search_pos, pos - search_pos + func_name.length())
				search_pos = pos + func_name.length()
				continue

		result += code.substr(search_pos, pos - search_pos)

		# Find the opening parenthesis
		var paren_start := code.find("(", pos + func_name.length())
		if paren_start == -1:
			result += func_name
			search_pos = pos + func_name.length()
			continue

		# Find matching closing parenthesis (handle nesting)
		var paren_end := _find_matching_paren(code, paren_start)
		if paren_end == -1:
			result += func_name
			search_pos = pos + func_name.length()
			continue

		var args_str := code.substr(paren_start + 1, paren_end - paren_start - 1).strip_edges()

		if is_this:
			# IMG_THIS_PIXEL(imageName) → texture(imageName, UV)
			var img_name := args_str.strip_edges()
			result += "texture(%s, UV)" % img_name
		elif is_normalized:
			# IMG_NORM_PIXEL(imageName, coord) → texture(imageName, coord)
			var comma_pos := _find_top_level_comma(args_str)
			if comma_pos == -1:
				result += "texture(%s, UV)" % args_str.strip_edges()
			else:
				var img_name := args_str.substr(0, comma_pos).strip_edges()
				var coord := args_str.substr(comma_pos + 1).strip_edges()
				result += "texture(%s, %s)" % [img_name, coord]
		else:
			# IMG_PIXEL(imageName, coord) → texture(imageName, coord / isf_rendersize)
			var comma_pos := _find_top_level_comma(args_str)
			if comma_pos == -1:
				result += "texture(%s, UV)" % args_str.strip_edges()
			else:
				var img_name := args_str.substr(0, comma_pos).strip_edges()
				var coord := args_str.substr(comma_pos + 1).strip_edges()
				result += "texture(%s, (%s) / isf_rendersize)" % [img_name, coord]

		search_pos = paren_end + 1

	return result


## Replaces IMG_SIZE(imageName) → isf_<imageName>_size.
static func _replace_img_size(code: String) -> String:
	var result := ""
	var search_pos := 0
	var func_name := "IMG_SIZE"

	while search_pos < code.length():
		var pos := code.find(func_name, search_pos)
		if pos == -1:
			result += code.substr(search_pos)
			break

		# Check it's not part of a longer identifier
		if pos > 0:
			var before := code[pos - 1]
			if before.is_valid_identifier() or before == "_":
				result += code.substr(search_pos, pos - search_pos + func_name.length())
				search_pos = pos + func_name.length()
				continue

		result += code.substr(search_pos, pos - search_pos)

		var paren_start := code.find("(", pos + func_name.length())
		if paren_start == -1:
			result += func_name
			search_pos = pos + func_name.length()
			continue

		var paren_end := _find_matching_paren(code, paren_start)
		if paren_end == -1:
			result += func_name
			search_pos = pos + func_name.length()
			continue

		var img_name := code.substr(paren_start + 1, paren_end - paren_start - 1).strip_edges()
		result += "isf_%s_size" % img_name
		search_pos = paren_end + 1

	return result


## Replaces void main() { ... } with void fragment() { ... }.
static func _replace_main_func(code: String) -> String:
	# ISF uses void main() { }, not mainImage like Shadertoy
	var regex_pattern := "void\\s+main\\s*\\("
	var regex := RegEx.new()
	regex.compile(regex_pattern)
	var match := regex.search(code)
	if match == null:
		return code
	# Replace just the function name
	var start_pos := match.get_start()
	var end_pos := match.get_end()
	var before := code.substr(0, start_pos)
	var after := code.substr(end_pos)
	return before + "void fragment(" + after


# ═══════════════════════════════════════════════════════════════════════════════
# Shader Code Builder
# ═══════════════════════════════════════════════════════════════════════════════

## Builds a complete Godot canvas_item shader from the translated GLSL body.
## [param pass_idx] — -1 for single-pass, 0..N for multi-pass.
static func _build_shader_code(body: String, result: TranslationResult,
		pass_idx: int) -> String:
	var code := "shader_type canvas_item;\n"
	code += "// Auto-translated from ISF"
	if not result.description.is_empty():
		code += " — \"%s\"" % result.description
	if not result.credit.is_empty():
		code += " by %s" % result.credit
	code += "\n\n"

	# ── Standard ISF uniforms ──
	code += "uniform vec2 isf_rendersize;\n"
	if result.uses_time_delta:
		code += "uniform float isf_time_delta;\n"
	if result.uses_date:
		code += "uniform vec4 isf_date;\n"
	if result.uses_frame_index:
		code += "uniform int isf_frame_index;\n"
	if result.passes.size() > 1:
		code += "uniform int isf_pass_index;\n"

	# ── Uniform declarations for ISF INPUTS ──
	for inp in result.inputs:
		match inp.type:
			"float":
				var def_val := 0.0
				if inp.default_value != null:
					def_val = float(inp.default_value)
				code += "uniform float %s = %.6f;\n" % [inp.input_name, def_val]
			"bool":
				var def_val := false
				if inp.default_value != null:
					def_val = bool(inp.default_value)
				code += "uniform bool %s = %s;\n" % [inp.input_name, "true" if def_val else "false"]
			"long":
				var def_val := 0
				if inp.default_value != null:
					def_val = int(inp.default_value)
				code += "uniform int %s = %d;\n" % [inp.input_name, def_val]
			"point2d":
				var def_x := 0.0
				var def_y := 0.0
				if inp.default_value is Array and inp.default_value.size() >= 2:
					def_x = float(inp.default_value[0])
					def_y = float(inp.default_value[1])
				code += "uniform vec2 %s = vec2(%.6f, %.6f);\n" % [inp.input_name, def_x, def_y]
			"color":
				var r := 1.0; var g := 1.0; var b := 1.0; var a := 1.0
				if inp.default_value is Array:
					if inp.default_value.size() >= 1: r = float(inp.default_value[0])
					if inp.default_value.size() >= 2: g = float(inp.default_value[1])
					if inp.default_value.size() >= 3: b = float(inp.default_value[2])
					if inp.default_value.size() >= 4: a = float(inp.default_value[3])
				code += "uniform vec4 %s = vec4(%.4f, %.4f, %.4f, %.4f);\n" % [inp.input_name, r, g, b, a]
			"image", "audio", "audiofft":
				code += "uniform sampler2D %s;\n" % inp.input_name
				code += "uniform vec2 isf_%s_size;\n" % inp.input_name
			"event":
				code += "uniform bool %s = false;\n" % inp.input_name

	# ── Sampler declarations for PASS targets (readable as textures) ──
	for p in result.passes:
		if not p.target.is_empty():
			code += "uniform sampler2D %s;\n" % p.target
			code += "uniform vec2 isf_%s_size;\n" % p.target

	# ── Sampler declarations for IMPORTED images ──
	for img_name in result.imported_images:
		code += "uniform sampler2D %s;\n" % img_name
		code += "uniform vec2 isf_%s_size;\n" % img_name

	code += "\n"
	code += body

	return code


# ═══════════════════════════════════════════════════════════════════════════════
# String Utilities
# ═══════════════════════════════════════════════════════════════════════════════

## Strips any line that starts with the given prefix (after whitespace).
static func _strip_line_starting_with(code: String, prefix: String) -> String:
	var lines := code.split("\n")
	var result_lines := PackedStringArray()
	for line in lines:
		if not line.strip_edges().begins_with(prefix):
			result_lines.append(line)
	return "\n".join(result_lines)


## Finds the matching closing parenthesis for an opening paren at [param start_pos].
## Returns -1 if not found.
static func _find_matching_paren(code: String, start_pos: int) -> int:
	var depth := 0
	for i in range(start_pos, code.length()):
		match code[i]:
			"(": depth += 1
			")":
				depth -= 1
				if depth == 0:
					return i
	return -1


## Finds the first top-level comma in [param s] (not inside nested parens).
## Returns -1 if not found.
static func _find_top_level_comma(s: String) -> int:
	var depth := 0
	for i in range(s.length()):
		match s[i]:
			"(": depth += 1
			")": depth -= 1
			",":
				if depth == 0:
					return i
	return -1
