extends Node
## Unit tests for the gn_ext_shadertoy extension.
##
## Tests cover:
##   - ShadertoyTranslator: built-in replacement, mainImage→fragment, header gen
##   - ShadertoyBaseTOP subclass structure (ports, params, read-only credits)
##   - ShadertoyURLTOP: URL/ID extraction utility
##   - Effect TOPs: extra shader-specific params exist

# Preloads — extension classes may not auto-register in headless mode
const _Translator := preload("res://addons/gn_ext_shadertoy/shadertoy_translator.gd")
const _BaseTOP := preload("res://addons/gn_ext_shadertoy/operators/top/shadertoy_base_top.gd")
const _URLTOP := preload("res://addons/gn_ext_shadertoy/operators/top/shadertoy_url_top.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# ShadertoyTranslator — Built-in Replacements
# ═══════════════════════════════════════════════════════════════════════════════

func test_translator_empty_code() -> void:
	var result = _Translator.translate("")
	GNTestAssert.assert_eq(result.success, false, "empty code should fail")
	GNTestAssert.assert_not_empty(result.error, "should have error message")


func test_translator_basic_gradient() -> void:
	var src := """void mainImage(out vec4 fragColor, in vec2 fragCoord) {
	vec2 uv = fragCoord / iResolution.xy;
	fragColor = vec4(uv, 0.5 + 0.5 * sin(iTime), 1.0);
}"""
	var result = _Translator.translate(src, "Gradient", "Test")
	GNTestAssert.assert_eq(result.success, true, "should succeed")
	GNTestAssert.assert_eq(result.uses_time, true, "uses iTime")
	GNTestAssert.assert_eq(result.shader_name, "Gradient", "shader_name")
	GNTestAssert.assert_eq(result.author, "Test", "author")
	GNTestAssert.assert_contains(result.godot_code, "shader_type canvas_item",
		"header should contain shader_type")
	GNTestAssert.assert_contains(result.godot_code, "gn_resolution",
		"iResolution.xy should become gn_resolution")
	GNTestAssert.assert_contains(result.godot_code, "void fragment()",
		"mainImage should become fragment()")
	GNTestAssert.assert_contains(result.godot_code, "COLOR",
		"fragColor should become COLOR")
	GNTestAssert.assert_contains(result.godot_code, "FRAGCOORD",
		"fragCoord should become FRAGCOORD")
	GNTestAssert.assert_contains(result.godot_code, "TIME",
		"iTime should become TIME")


func test_translator_ichannel_detection() -> void:
	var src := """void mainImage(out vec4 fragColor, in vec2 fragCoord) {
	fragColor = texture(iChannel0, fragCoord / iResolution.xy)
		+ 0.5 * texture(iChannel2, fragCoord / iResolution.xy);
}"""
	var result = _Translator.translate(src)
	GNTestAssert.assert_eq(result.success, true, "should succeed")
	GNTestAssert.assert_eq(result.needs_input_tex.size(), 2, "two channels used")
	GNTestAssert.assert_eq(result.needs_input_tex[0], 0, "iChannel0 detected")
	GNTestAssert.assert_eq(result.needs_input_tex[1], 2, "iChannel2 detected")
	GNTestAssert.assert_contains(result.godot_code, "uniform sampler2D gn_tex0",
		"gn_tex0 uniform declared")
	GNTestAssert.assert_contains(result.godot_code, "uniform sampler2D gn_tex2",
		"gn_tex2 uniform declared")


func test_translator_imouse_iframe() -> void:
	var src := """void mainImage(out vec4 fragColor, in vec2 fragCoord) {
	vec2 uv = fragCoord / iResolution.xy;
	float t = float(iFrame) * 0.01;
	vec2 m = iMouse.xy / iResolution.xy;
	fragColor = vec4(uv + m, t, 1.0);
}"""
	var result = _Translator.translate(src)
	GNTestAssert.assert_eq(result.success, true, "should succeed")
	GNTestAssert.assert_eq(result.uses_mouse, true, "uses iMouse")
	GNTestAssert.assert_eq(result.uses_frame, true, "uses iFrame")
	GNTestAssert.assert_contains(result.godot_code, "gn_mouse",
		"iMouse → gn_mouse")
	GNTestAssert.assert_contains(result.godot_code, "gn_frame",
		"iFrame → gn_frame")


func test_translator_bare_iresolution() -> void:
	var src := """void mainImage(out vec4 fragColor, in vec2 fragCoord) {
	vec3 r = iResolution;
	fragColor = vec4(fragCoord / r.xy, 0.0, 1.0);
}"""
	var result = _Translator.translate(src)
	GNTestAssert.assert_eq(result.success, true, "should succeed")
	GNTestAssert.assert_contains(result.godot_code, "vec3(gn_resolution, 1.0)",
		"bare iResolution → vec3(gn_resolution, 1.0)")


func test_translator_custom_param_names() -> void:
	var src := """void mainImage(out vec4 col, in vec2 fc) {
	vec2 uv = fc / iResolution.xy;
	col = vec4(uv, 0.0, 1.0);
}"""
	var result = _Translator.translate(src)
	GNTestAssert.assert_eq(result.success, true, "should succeed")
	GNTestAssert.assert_contains(result.godot_code, "void fragment()",
		"mainImage(out vec4 col, in vec2 fc) → fragment()")
	GNTestAssert.assert_contains(result.godot_code, "COLOR", "col → COLOR")
	GNTestAssert.assert_contains(result.godot_code, "FRAGCOORD", "fc → FRAGCOORD")


func test_translator_strips_version_and_precision() -> void:
	var src := """#version 300 es
precision highp float;
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
	fragColor = vec4(1.0);
}"""
	var result = _Translator.translate(src)
	GNTestAssert.assert_eq(result.success, true, "should succeed")
	GNTestAssert.assert_eq(result.godot_code.find("#version"), -1,
		"#version should be stripped")
	GNTestAssert.assert_eq(result.godot_code.find("precision highp"), -1,
		"precision should be stripped")


func test_translator_itimedelta() -> void:
	var src := """void mainImage(out vec4 fragColor, in vec2 fragCoord) {
	fragColor = vec4(iTimeDelta, 0.0, 0.0, 1.0);
}"""
	var result = _Translator.translate(src)
	GNTestAssert.assert_eq(result.success, true, "should succeed")
	GNTestAssert.assert_contains(result.godot_code, "gn_time_delta",
		"iTimeDelta → gn_time_delta")


# ═══════════════════════════════════════════════════════════════════════════════
# ShadertoyBaseTOP & Pre-baked Subclasses
# ═══════════════════════════════════════════════════════════════════════════════

func test_base_generator_ports() -> void:
	var top = _BaseTOP.new()
	top._is_generator = true
	top._input_tex_count = 0
	top._shader_path = "res://addons/gn_ext_shadertoy/shaders/st_plasma.gdshader"
	top._shadertoy_url = "https://example.com"
	top._credits = "Test Author"
	top._init_ports()
	top._init_parameters()

	GNTestAssert.assert_eq(top.input_ports.size(), 0, "generator has no inputs")
	GNTestAssert.assert_eq(top.output_ports.size(), 1, "one output")
	GNTestAssert.assert_eq(top.parameters.has("resolution"), true,
		"generator has resolution param")
	GNTestAssert.assert_eq(top.parameters.has("shadertoy_url"), true,
		"has shadertoy_url param")
	GNTestAssert.assert_eq(top.parameters.has("credits"), true,
		"has credits param")

	# Read-only check
	var url_param: GNParameter = top.parameters["shadertoy_url"]
	GNTestAssert.assert_eq(url_param.read_only, true, "shadertoy_url is read_only")
	GNTestAssert.assert_eq(url_param.value, "https://example.com",
		"URL pre-filled from _shadertoy_url")


func test_base_effect_ports() -> void:
	var top = _BaseTOP.new()
	top._is_generator = false
	top._input_tex_count = 1
	top._shader_path = "res://addons/gn_ext_shadertoy/shaders/st_crt.gdshader"
	top._shadertoy_url = ""
	top._credits = "Test"
	top._init_ports()
	top._init_parameters()

	GNTestAssert.assert_eq(top.input_ports.size(), 1, "effect has one input")
	GNTestAssert.assert_eq(top.output_ports.size(), 1, "one output")
	GNTestAssert.assert_eq(top.parameters.has("resolution"), false,
		"effect has no resolution param (inherits from input)")


func test_url_param_skipped_when_empty() -> void:
	var top = _BaseTOP.new()
	top._is_generator = false
	top._input_tex_count = 1
	top._shader_path = "res://addons/gn_ext_shadertoy/shaders/st_crt.gdshader"
	top._shadertoy_url = ""
	top._credits = "Original GONODES"
	top._init_ports()
	top._init_parameters()

	GNTestAssert.assert_eq(top.parameters.has("shadertoy_url"), false,
		"empty URL ⇒ no shadertoy_url param")
	GNTestAssert.assert_eq(top.parameters.has("credits"), true,
		"credits param always present")


func test_url_param_present_when_set() -> void:
	var top = _BaseTOP.new()
	top._is_generator = false
	top._input_tex_count = 1
	top._shader_path = "res://addons/gn_ext_shadertoy/shaders/st_halftone.gdshader"
	top._shadertoy_url = "https://www.shadertoy.com/view/Mdf3Dn"
	top._credits = "tsone"
	top._init_ports()
	top._init_parameters()

	GNTestAssert.assert_eq(top.parameters.has("shadertoy_url"), true,
		"non-empty URL ⇒ shadertoy_url param exists")
	var url_param: GNParameter = top.parameters["shadertoy_url"]
	GNTestAssert.assert_eq(url_param.read_only, true, "URL is read-only")
	GNTestAssert.assert_contains(url_param.value, "Mdf3Dn",
		"URL value matches")


func test_seascape_top_init() -> void:
	var op = load("res://addons/gn_ext_shadertoy/operators/top/st_seascape_top.gd").new()
	GNTestAssert.assert_eq(op.node_type, "st_seascape", "node_type")
	GNTestAssert.assert_eq(op.time_dependent, true, "time_dependent")
	GNTestAssert.assert_eq(op._is_generator, true, "is generator")
	GNTestAssert.assert_eq(op._input_tex_count, 0, "no inputs")
	GNTestAssert.assert_contains(op._shader_path, "st_seascape", "shader path set")
	GNTestAssert.assert_contains(op._shadertoy_url, "Ms2SD1", "URL contains shader ID")


func test_voronoi_fire_top_init() -> void:
	var op = load("res://addons/gn_ext_shadertoy/operators/top/st_voronoi_fire_top.gd").new()
	GNTestAssert.assert_eq(op.node_type, "st_voronoi_fire", "node_type")
	GNTestAssert.assert_eq(op._is_generator, true, "is generator")


func test_creation_top_init() -> void:
	var op = load("res://addons/gn_ext_shadertoy/operators/top/st_creation_top.gd").new()
	GNTestAssert.assert_eq(op.node_type, "st_creation", "node_type")
	GNTestAssert.assert_eq(op._is_generator, true, "is generator")


func test_star_nest_top_init() -> void:
	var op = load("res://addons/gn_ext_shadertoy/operators/top/st_star_nest_top.gd").new()
	GNTestAssert.assert_eq(op.node_type, "st_star_nest", "node_type")
	GNTestAssert.assert_eq(op._is_generator, true, "is generator")


func test_plasma_top_init() -> void:
	var op = load("res://addons/gn_ext_shadertoy/operators/top/st_plasma_top.gd").new()
	GNTestAssert.assert_eq(op.node_type, "st_plasma", "node_type")
	GNTestAssert.assert_eq(op._is_generator, true, "is generator")


# ═══════════════════════════════════════════════════════════════════════════════
# Effect TOPs — extra params
# ═══════════════════════════════════════════════════════════════════════════════

func test_crt_top_params() -> void:
	var op = load("res://addons/gn_ext_shadertoy/operators/top/st_crt_top.gd").new()
	GNTestAssert.assert_eq(op.node_type, "st_crt", "node_type")
	GNTestAssert.assert_eq(op._is_generator, false, "is effect")
	GNTestAssert.assert_eq(op._input_tex_count, 1, "one input")
	op._init_ports()
	op._init_parameters()
	GNTestAssert.assert_eq(op.parameters.has("curvature"), true, "has curvature param")
	GNTestAssert.assert_eq(op.parameters.has("scanline_weight"), true, "has scanline_weight")
	GNTestAssert.assert_eq(op.parameters.has("vignette_strength"), true, "has vignette_strength")


func test_chromatic_ab_top_params() -> void:
	var op = load("res://addons/gn_ext_shadertoy/operators/top/st_chromatic_ab_top.gd").new()
	GNTestAssert.assert_eq(op.node_type, "st_chromatic_ab", "node_type")
	GNTestAssert.assert_eq(op._is_generator, false, "is effect")
	op._init_ports()
	op._init_parameters()
	GNTestAssert.assert_eq(op.parameters.has("intensity"), true, "has intensity param")
	GNTestAssert.assert_eq(op.parameters.has("radial_weight"), true, "has radial_weight")


func test_pixelate_top_params() -> void:
	var op = load("res://addons/gn_ext_shadertoy/operators/top/st_pixelate_top.gd").new()
	GNTestAssert.assert_eq(op._is_generator, false, "is effect")
	op._init_ports()
	op._init_parameters()
	GNTestAssert.assert_eq(op.parameters.has("pixel_size"), true, "has pixel_size")


func test_film_grain_top_params() -> void:
	var op = load("res://addons/gn_ext_shadertoy/operators/top/st_film_grain_top.gd").new()
	GNTestAssert.assert_eq(op._is_generator, false, "is effect")
	op._init_ports()
	op._init_parameters()
	GNTestAssert.assert_eq(op.parameters.has("grain_intensity"), true, "has grain_intensity")
	GNTestAssert.assert_eq(op.parameters.has("grain_speed"), true, "has grain_speed")


func test_halftone_top_params() -> void:
	var op = load("res://addons/gn_ext_shadertoy/operators/top/st_halftone_top.gd").new()
	GNTestAssert.assert_eq(op._is_generator, false, "is effect")
	GNTestAssert.assert_contains(op._shadertoy_url, "Mdf3Dn", "URL has shader ID")
	op._init_ports()
	op._init_parameters()
	GNTestAssert.assert_eq(op.parameters.has("dot_size"), true, "has dot_size")
	GNTestAssert.assert_eq(op.parameters.has("dot_scale"), true, "has dot_scale")
	GNTestAssert.assert_eq(op.parameters.has("shadertoy_url"), true,
		"halftone effect has a Shadertoy URL param")


# ═══════════════════════════════════════════════════════════════════════════════
# ShadertoyURLTOP — URL Extraction
# ═══════════════════════════════════════════════════════════════════════════════

func test_url_extract_bare_id() -> void:
	var sid = _URLTOP._extract_shader_id("Ms2SD1")
	GNTestAssert.assert_eq(sid, "Ms2SD1", "bare ID")


func test_url_extract_full_url() -> void:
	var sid = _URLTOP._extract_shader_id(
		"https://www.shadertoy.com/view/Ms2SD1")
	GNTestAssert.assert_eq(sid, "Ms2SD1", "full URL")


func test_url_extract_trailing_slash() -> void:
	var sid = _URLTOP._extract_shader_id(
		"https://www.shadertoy.com/view/Ms2SD1/")
	GNTestAssert.assert_eq(sid, "Ms2SD1", "trailing slash")


func test_url_extract_empty() -> void:
	var sid = _URLTOP._extract_shader_id("")
	GNTestAssert.assert_eq(sid, "", "empty string")


func test_url_top_init() -> void:
	var op = _URLTOP.new()
	GNTestAssert.assert_eq(op.node_type, "shadertoy", "node_type")
	GNTestAssert.assert_eq(op.time_dependent, true, "time_dependent default")
	op._init_ports()
	op._init_parameters()
	GNTestAssert.assert_eq(op.output_ports.size(), 1, "one output")
	GNTestAssert.assert_eq(op.parameters.has("shadertoy_code"), true,
		"has shadertoy_code param")
	GNTestAssert.assert_eq(op.parameters.has("shadertoy_url"), true,
		"has shadertoy_url param")
	GNTestAssert.assert_eq(op.parameters.has("fetch"), true,
		"has fetch pulse param")
	GNTestAssert.assert_eq(op.parameters.has("resolution"), true,
		"has resolution param")


# ═══════════════════════════════════════════════════════════════════════════════
# Read-only Parameter Flag
# ═══════════════════════════════════════════════════════════════════════════════

func test_read_only_flag_default() -> void:
	var p := GNParameter.create_string("test", "val", "Test", "desc")
	GNTestAssert.assert_eq(p.read_only, false, "default read_only is false")


func test_read_only_flag_set() -> void:
	var p := GNParameter.create_string("test", "val", "Test", "desc")
	p.read_only = true
	GNTestAssert.assert_eq(p.read_only, true, "read_only can be set to true")


func test_read_only_serialization() -> void:
	var p := GNParameter.create_string("test", "val", "Test", "desc")
	p.read_only = true
	var d := p.to_dict()
	var p2 := GNParameter.create_string("test", "", "Test", "desc")
	p2.from_dict(d)
	GNTestAssert.assert_eq(p2.read_only, true,
		"read_only survives to_dict/from_dict round-trip")


# ═══════════════════════════════════════════════════════════════════════════════
# Operator Sections — Shadertoy operators appear in "Shadertoy" section
# ═══════════════════════════════════════════════════════════════════════════════

func test_shadertoy_section_in_registry() -> void:
	## All Shadertoy extension operators should have section == "Shadertoy".
	var reg := GNExtensionRegistry.instance()
	# Force-load the extension if not already loaded
	reg.scan_extensions()
	var st_ops := [
		"STSeascapeTOP", "STVoronoiFireTOP", "STCreationTOP", "STStarNestTOP",
		"STPlasmaTOP", "STCRTTOP", "STChromaticAbTOP", "STPixelateTOP",
		"STFilmGrainTOP", "STHalftoneTOP", "ShadertoyURLTOP",
	]
	for op_name in st_ops:
		if reg.has_operator(op_name):
			GNTestAssert.assert_eq(reg.get_section(op_name), "Shadertoy",
				"%s should have section 'Shadertoy'" % op_name)


func test_core_operators_have_no_section() -> void:
	## Core operators (e.g. NoiseTOP, LFO_CHOP) should have empty section.
	var reg := GNExtensionRegistry.instance()
	for op_name in ["NoiseTOP", "LFO_CHOP", "NullDAT"]:
		if reg.has_operator(op_name):
			GNTestAssert.assert_eq(reg.get_section(op_name), "",
				"%s should have empty section" % op_name)


func test_sectioned_registry_groups_shadertoy() -> void:
	## get_operator_registry_sectioned() should group Shadertoy ops under
	## {"TOP": {"Shadertoy": [...], "": [...]}}
	var reg := GNExtensionRegistry.instance()
	reg.scan_extensions()
	var sectioned := reg.get_operator_registry_sectioned()
	if not sectioned.has("TOP"):
		GNTestAssert.assert_true(false, "TOP family missing from sectioned registry")
		return
	var top_sections: Dictionary = sectioned["TOP"]
	GNTestAssert.assert_true(top_sections.has("Shadertoy"),
		"TOP should have a 'Shadertoy' section")
	if top_sections.has("Shadertoy"):
		GNTestAssert.assert_gt(top_sections["Shadertoy"].size(), 0,
			"Shadertoy section should have operators")
	# Core ops should be under "" section
	GNTestAssert.assert_true(top_sections.has(""),
		"TOP should have unsectioned core operators")


func test_extension_level_section_applies_to_all_ops() -> void:
	## Extension-level section= in [extension] header should apply to every
	## operator from that extension without per-operator overrides.
	var reg := GNExtensionRegistry.instance()
	reg.scan_extensions()
	# FFmpeg extension has section="FFmpeg" at extension level
	var sectioned := reg.get_operator_registry_sectioned()
	if not sectioned.has("TOP"):
		GNTestAssert.assert_true(false, "TOP family missing from sectioned registry")
		return
	var top_sections: Dictionary = sectioned["TOP"]
	# FFmpeg section should exist if any FFmpeg operators were loaded
	var ffmpeg_ops_found := 0
	for op_name in reg.get_operator_registry().keys():
		if reg.get_section(op_name) == "FFmpeg":
			ffmpeg_ops_found += 1
	if ffmpeg_ops_found > 0:
		GNTestAssert.assert_true(top_sections.has("FFmpeg"),
			"TOP should have an 'FFmpeg' section from extension-level section key")
	# Shadertoy section still present (inherited from extension-level section)
	GNTestAssert.assert_true(top_sections.has("Shadertoy"),
		"Shadertoy section should still work via extension-level section key")
