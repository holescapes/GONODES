class_name ShadertoyTranslator
extends RefCounted
## Translates single-pass Shadertoy GLSL into Godot canvas_item shader language.
##
## Handles the mechanical mapping between Shadertoy built-ins and Godot
## equivalents.  Multi-pass (Buffer A/B/C/D) shaders are NOT yet supported —
## only the final "Image" pass is converted.
##
## ── Translation map ──────────────────────────────────────────────────────────
##   Shadertoy                          →  Godot canvas_item
##   void mainImage(out vec4, in vec2)  →  void fragment()
##   fragColor                          →  COLOR
##   fragCoord / fragCoord.xy           →  FRAGCOORD.xy
##   iResolution.xy / iResolution       →  gn_resolution  (uniform vec2)
##   iTime                              →  TIME
##   iTimeDelta                         →  gn_time_delta   (uniform float)
##   iFrame                             →  gn_frame        (uniform int)
##   iMouse                             →  gn_mouse        (uniform vec4)
##   iChannel0..3                       →  gn_tex0..3      (uniform sampler2D)
##   texture(iChannelN, uv)             →  texture(gn_texN, uv)
##
## ── Future: multi-pass ───────────────────────────────────────────────────────
## To support Buffer A/B/C/D passes:
##   1. Parse the renderpass array from the Shadertoy API JSON
##   2. Create one SubViewport per buffer pass, each with its own shader
##   3. Wire buffer outputs as sampler2D inputs to subsequent passes
##   4. Run passes in order each cook: BufferA → BufferB → … → Image
##   5. Buffer passes can read their own previous frame via a feedback texture
##
## This would mirror the FeedbackTOP pattern already in GONODES core.


## Result of a translation attempt.
class TranslationResult:
	var success: bool = false
	var godot_code: String = ""
	var error: String = ""
	var needs_input_tex: Array[int] = []  ## indices of iChannel slots used
	var uses_time: bool = false
	var uses_mouse: bool = false
	var uses_frame: bool = false
	var shader_name: String = ""
	var author: String = ""


## Translates raw Shadertoy GLSL (the "code" field from a single renderpass)
## into a complete Godot `shader_type canvas_item;` shader string.
##
## Returns a [TranslationResult] with the converted code or an error message.
static func translate(shadertoy_glsl: String, shader_name: String = "", author: String = "") -> TranslationResult:
	var result := TranslationResult.new()
	result.shader_name = shader_name
	result.author = author

	if shadertoy_glsl.strip_edges().is_empty():
		result.error = "Empty shader code"
		return result

	var code := shadertoy_glsl

	# ── Strip #version and precision qualifiers (Godot handles these) ──
	code = _strip_line_starting_with(code, "#version")
	code = _strip_line_starting_with(code, "precision ")

	# ── Detect which built-ins are used ──
	result.uses_time = code.find("iTime") != -1
	result.uses_mouse = code.find("iMouse") != -1
	result.uses_frame = code.find("iFrame") != -1

	# Find iChannel usage (0-3)
	for i in range(4):
		if code.find("iChannel%d" % i) != -1:
			result.needs_input_tex.append(i)

	# ── Replace Shadertoy built-ins ──

	# iResolution — must be done BEFORE fragCoord replacements to avoid partial matches
	# Handle iResolution.xy, iResolution.x, iResolution.y, plain iResolution, and r shorthand #define
	code = code.replace("iResolution.xy", "gn_resolution")
	code = code.replace("iResolution.x", "gn_resolution.x")
	code = code.replace("iResolution.y", "gn_resolution.y")
	# Remaining bare iResolution (e.g., iResolution in vec3 constructor) → vec3(gn_resolution, 1.0)
	# Only replace standalone iResolution not already converted
	code = _replace_bare_iresolution(code)

	# iChannel0..3 → gn_tex0..3
	for i in range(4):
		code = code.replace("iChannel%d" % i, "gn_tex%d" % i)

	# iTimeDelta → gn_time_delta
	code = code.replace("iTimeDelta", "gn_time_delta")

	# iTime → TIME (Godot built-in)
	code = code.replace("iTime", "TIME")

	# iFrame → gn_frame
	code = code.replace("iFrame", "gn_frame")

	# iMouse → gn_mouse
	code = code.replace("iMouse", "gn_mouse")

	# iDate → gn_date (rarely used but handle it)
	code = code.replace("iDate", "gn_date")

	# ── Replace mainImage signature → fragment() ──
	code = _replace_main_image(code)

	# ── Build the complete shader with header ──
	var header := "shader_type canvas_item;\n"
	header += "// Auto-translated from Shadertoy"
	if not shader_name.is_empty():
		header += " — \"%s\"" % shader_name
	if not author.is_empty():
		header += " by %s" % author
	header += "\n\n"

	# Uniform declarations
	header += "uniform vec2 gn_resolution;\n"
	if result.uses_mouse:
		header += "uniform vec4 gn_mouse;\n"
	if result.uses_frame:
		header += "uniform int gn_frame;\n"
	header += "uniform float gn_time_delta;\n"

	# Texture inputs
	for i in result.needs_input_tex:
		header += "uniform sampler2D gn_tex%d : hint_default_white;\n" % i

	header += "\n"

	result.godot_code = header + code
	result.success = true
	return result


## Strips any line that starts with the given prefix (after whitespace).
static func _strip_line_starting_with(code: String, prefix: String) -> String:
	var lines := code.split("\n")
	var result_lines: PackedStringArray = PackedStringArray()
	for line in lines:
		if not line.strip_edges().begins_with(prefix):
			result_lines.append(line)
	return "\n".join(result_lines)


## Replaces bare `iResolution` (not already converted to gn_resolution) with
## `vec3(gn_resolution, 1.0)` since Shadertoy's iResolution is vec3.
static func _replace_bare_iresolution(code: String) -> String:
	# Already replaced .xy/.x/.y above — now handle remaining bare iResolution
	# that wasn't part of those patterns.  Simple approach: replace
	# "iResolution" that isn't preceded by "gn_" or followed by "."
	var result := ""
	var i := 0
	var needle := "iResolution"
	var needle_len := needle.length()
	while i < code.length():
		var pos := code.find(needle, i)
		if pos == -1:
			result += code.substr(i)
			break
		result += code.substr(i, pos - i)
		# Check if already replaced (preceded by "gn_")
		if pos >= 3 and code.substr(pos - 3, 3) == "gn_":
			result += needle
			i = pos + needle_len
			continue
		# Check if followed by . (already handled .x, .y, .xy above)
		var after := pos + needle_len
		if after < code.length() and code[after] == ".":
			result += needle
			i = pos + needle_len
			continue
		# Bare iResolution → vec3(gn_resolution, 1.0)
		result += "vec3(gn_resolution, 1.0)"
		i = pos + needle_len
	return result


## Replaces the Shadertoy `void mainImage(out vec4 fragColor, in vec2 fragCoord)`
## function signature with Godot's `void fragment()` and remaps variable names.
static func _replace_main_image(code: String) -> String:
	# Find mainImage signature — flexible with whitespace
	# Pattern: void mainImage( out vec4 <name>, in vec2 <name> )
	var sig_start := code.find("mainImage")
	if sig_start == -1:
		return code  # No mainImage found — might be a helper-only file

	# Find the opening of mainImage: back up to "void"
	var void_start := code.rfind("void", sig_start)
	if void_start == -1:
		return code

	# Find the opening brace after the signature
	var paren_open := code.find("(", sig_start)
	var paren_close := code.find(")", paren_open) if paren_open != -1 else -1
	if paren_open == -1 or paren_close == -1:
		return code

	# Extract parameter names
	var params_str := code.substr(paren_open + 1, paren_close - paren_open - 1)
	var frag_color_name := "fragColor"
	var frag_coord_name := "fragCoord"

	# Parse "out vec4 <name>" and "in vec2 <name>"
	var parts := params_str.split(",")
	for part in parts:
		var stripped := part.strip_edges()
		if stripped.begins_with("out"):
			# out vec4 <name>
			var tokens := stripped.split(" ", false)
			if tokens.size() >= 3:
				frag_color_name = tokens[tokens.size() - 1].strip_edges()
		elif stripped.begins_with("in"):
			# in vec2 <name>
			var tokens := stripped.split(" ", false)
			if tokens.size() >= 3:
				frag_coord_name = tokens[tokens.size() - 1].strip_edges()

	# Replace the signature
	var old_sig := code.substr(void_start, paren_close - void_start + 1)
	code = code.replace(old_sig, "void fragment()")

	# Replace fragColor → COLOR
	if frag_color_name != "COLOR":
		code = code.replace(frag_color_name, "COLOR")

	# Replace fragCoord → FRAGCOORD
	if frag_coord_name != "FRAGCOORD":
		# fragCoord.xy → FRAGCOORD.xy, fragCoord → FRAGCOORD
		code = code.replace(frag_coord_name, "FRAGCOORD")

	return code
