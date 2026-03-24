extends Node
## Unit tests for the gn_ext_shadertoy extension.
##
## Tests cover:
##   - ShadertoyTranslator: built-in replacement, mainImage→fragment, header gen
##   - ShadertoyTOP: URL/ID extraction, init, params
##   - Factory presets exist on disk

const ShadertoyTOP = preload("res://addons/gn_ext_shadertoy/operators/top/shadertoy_top.gd")

# ═══════════════════════════════════════════════════════════════════════════════
# ShadertoyTranslator — Built-in Replacements
# ═══════════════════════════════════════════════════════════════════════════════

func test_translator_empty_code() -> void:
	var result = ShadertoyTranslator.translate("")
	GNTestAssert.assert_eq(result.success, false, "empty code should fail")
	GNTestAssert.assert_not_empty(result.error, "should have error message")


func test_translator_basic_gradient() -> void:
	var src := """void mainImage(out vec4 fragColor, in vec2 fragCoord) {
	vec2 uv = fragCoord / iResolution.xy;
	fragColor = vec4(uv, 0.5 + 0.5 * sin(iTime), 1.0);
}"""
	var result = ShadertoyTranslator.translate(src, "Gradient", "Test")
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
	GNTestAssert.assert_contains(result.godot_code, "UV * gn_resolution",
		"fragCoord should become UV * gn_resolution")
	GNTestAssert.assert_contains(result.godot_code, "TIME",
		"iTime should become TIME")


func test_translator_ichannel_detection() -> void:
	var src := """void mainImage(out vec4 fragColor, in vec2 fragCoord) {
	fragColor = texture(iChannel0, fragCoord / iResolution.xy)
		+ 0.5 * texture(iChannel2, fragCoord / iResolution.xy);
}"""
	var result = ShadertoyTranslator.translate(src)
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
	var result = ShadertoyTranslator.translate(src)
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
	var result = ShadertoyTranslator.translate(src)
	GNTestAssert.assert_eq(result.success, true, "should succeed")
	GNTestAssert.assert_contains(result.godot_code, "vec3(gn_resolution, 1.0)",
		"bare iResolution → vec3(gn_resolution, 1.0)")


func test_translator_custom_param_names() -> void:
	var src := """void mainImage(out vec4 col, in vec2 fc) {
	vec2 uv = fc / iResolution.xy;
	col = vec4(uv, 0.0, 1.0);
}"""
	var result = ShadertoyTranslator.translate(src)
	GNTestAssert.assert_eq(result.success, true, "should succeed")
	GNTestAssert.assert_contains(result.godot_code, "void fragment()",
		"mainImage(out vec4 col, in vec2 fc) → fragment()")
	GNTestAssert.assert_contains(result.godot_code, "COLOR", "col → COLOR")
	GNTestAssert.assert_contains(result.godot_code, "UV * gn_resolution", "fc → UV * gn_resolution")


func test_translator_strips_version_and_precision() -> void:
	var src := """#version 300 es
precision highp float;
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
	fragColor = vec4(1.0);
}"""
	var result = ShadertoyTranslator.translate(src)
	GNTestAssert.assert_eq(result.success, true, "should succeed")
	GNTestAssert.assert_eq(result.godot_code.find("#version"), -1,
		"#version should be stripped")
	GNTestAssert.assert_eq(result.godot_code.find("precision highp"), -1,
		"precision should be stripped")


func test_translator_itimedelta() -> void:
	var src := """void mainImage(out vec4 fragColor, in vec2 fragCoord) {
	fragColor = vec4(iTimeDelta, 0.0, 0.0, 1.0);
}"""
	var result = ShadertoyTranslator.translate(src)
	GNTestAssert.assert_eq(result.success, true, "should succeed")
	GNTestAssert.assert_contains(result.godot_code, "gn_time_delta",
		"iTimeDelta → gn_time_delta")


# ═══════════════════════════════════════════════════════════════════════════════
# Factory Presets — verify preset files exist on disk
# ═══════════════════════════════════════════════════════════════════════════════

func test_factory_presets_exist() -> void:
	## All 10 factory presets should exist as .glsl files.
	var preset_dir := "res://addons/gn_ext_shadertoy/presets/shadertoy/"
	var expected := [
		"plasma.glsl", "creation.glsl", "star_nest.glsl", "lava_lamp.glsl",
		"voronoi.glsl", "crt.glsl", "chromatic_ab.glsl", "pixelate.glsl",
		"film_grain.glsl", "halftone.glsl",
	]
	for preset: String in expected:
		var path := preset_dir + preset
		GNTestAssert.assert_true(FileAccess.file_exists(path),
			"preset should exist: %s" % preset)


# ═══════════════════════════════════════════════════════════════════════════════
# ShadertoyTOP — URL Extraction
# ═══════════════════════════════════════════════════════════════════════════════

func test_url_extract_bare_id() -> void:
	var sid = ShadertoyTOP._extract_shader_id("Ms2SD1")
	GNTestAssert.assert_eq(sid, "Ms2SD1", "bare ID")


func test_url_extract_full_url() -> void:
	var sid = ShadertoyTOP._extract_shader_id(
		"https://www.shadertoy.com/view/Ms2SD1")
	GNTestAssert.assert_eq(sid, "Ms2SD1", "full URL")


func test_url_extract_trailing_slash() -> void:
	var sid = ShadertoyTOP._extract_shader_id(
		"https://www.shadertoy.com/view/Ms2SD1/")
	GNTestAssert.assert_eq(sid, "Ms2SD1", "trailing slash")


func test_url_extract_empty() -> void:
	var sid = ShadertoyTOP._extract_shader_id("")
	GNTestAssert.assert_eq(sid, "", "empty string")


func test_url_top_init() -> void:
	var op = ShadertoyTOP.new()
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
	## ShadertoyTOP should have section == "Shadertoy".
	var reg := GNExtensionRegistry.instance()
	reg.scan_extensions()
	if reg.has_operator("ShadertoyTOP"):
		GNTestAssert.assert_eq(reg.get_section("ShadertoyTOP"), "Shadertoy",
			"ShadertoyTOP should have section 'Shadertoy'")


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
