class_name GNExtensionRegistry
extends RefCounted
## Central registry for all GONODES operators — both built-in (core) and
## extension-provided.  Replaces the static match-factory and static
## description dictionary that previously lived in GNGraphEditor and
## GNNodePalette.
##
## Architecture
## ────────────
## • Core operators are registered at startup via `_register_core_operators()`.
## • Extensions live under `res://addons/gn_ext_<name>/` and contain a
##   `gn_extension.cfg` manifest (ConfigFile) listing operator scripts,
##   families, descriptions, and optional ClassDB dependency guards.
## • `scan_extensions()` discovers and loads manifest-declared operators.
## • All look-ups go through the singleton (`GNExtensionRegistry.instance`).
##
## Manifest format (`gn_extension.cfg`):
## ─────────────────────────────────────
##   [extension]
##   name = "FFmpeg Codecs"
##   version = "0.1.0"
##   author = "Your Name"
##   description = "H.264/VP9/HAP video codecs for MovieFileInTOP."
##   dependencies = ["FFmpegFrameDecoder"]   ; ClassDB classes that must exist
##   section = "FFmpeg"  ; palette sub-heading (defaults to name)
##
##   [operator.HAPMovieTOP]
##   family = "TOP"
##   script = "res://addons/gn_ext_ffmpeg/operators/hap_movie_top.gd"
##   description = "HAP codec GPU-direct video playback (S3TC/DXT)."
##
##   [operator.FFmpegMovieTOP]
##   family = "TOP"
##   script = "res://addons/gn_ext_ffmpeg/operators/ffmpeg_movie_top.gd"
##   description = "H.264/VP9/AV1 video via FFmpeg GDExtension."
##
## All operators from an extension inherit the extension-level section.
## Per-operator `section` can still override if needed.


# ═══════════════════════════════════════════════════════════════════════════════
# Singleton
# ═══════════════════════════════════════════════════════════════════════════════

## Lazily-created singleton.
static var _instance: GNExtensionRegistry = null

static func instance() -> GNExtensionRegistry:
	if _instance == null:
		_instance = GNExtensionRegistry.new()
		_instance._register_core_operators()
	return _instance


# ═══════════════════════════════════════════════════════════════════════════════
# Data Structures
# ═══════════════════════════════════════════════════════════════════════════════

## Per-operator registration record.
## Fields: family (String), op_script (GDScript or null), description (String),
##         source (String — "core" or extension name).
class OperatorEntry:
	var family: String          ## TOP / CHOP / SOP / DAT / MAT / COMP / POP
	var op_script: GDScript     ## Preloaded GDScript class (has .new())
	var description: String     ## One-line tooltip text
	var source: String          ## "core" or the extension name that provided it
	var section: String         ## Optional sub-section within the family (e.g. "Shadertoy")
	var extension_dir: String   ## Extension base dir (e.g. "res://addons/gn_ext_shadertoy") or "" for core

	func _init(p_family: String, p_script: GDScript, p_desc: String,
			p_source: String = "core", p_section: String = "",
			p_ext_dir: String = "") -> void:
		family = p_family
		op_script = p_script
		description = p_desc
		source = p_source
		section = p_section
		extension_dir = p_ext_dir


## class_name → OperatorEntry
var _operators: Dictionary = {}

## Loaded extension names (to avoid double-loading).
var _loaded_extensions: PackedStringArray = []


# ═══════════════════════════════════════════════════════════════════════════════
# Registration API
# ═══════════════════════════════════════════════════════════════════════════════

## Register a single operator.  Overwrites any existing entry with the same key.
func register_operator(class_name_key: String, family: String, op_script: GDScript,
		description: String, source: String = "core", section: String = "",
		extension_dir: String = "") -> void:
	_operators[class_name_key] = OperatorEntry.new(family, op_script, description, source, section, extension_dir)
	_invalidate_port_cache()


## Unregister an operator by class name.
func unregister_operator(class_name_key: String) -> void:
	_operators.erase(class_name_key)
	_invalidate_port_cache()


# ═══════════════════════════════════════════════════════════════════════════════
# Instance Factory
# ═══════════════════════════════════════════════════════════════════════════════

## Creates and returns a new instance of the named operator, or null.
func create_instance(class_name_key: String) -> GNNode:
	var entry: OperatorEntry = _operators.get(class_name_key, null)
	if entry == null:
		return null
	# Custom assets need their .gnasset loaded after construction
	if entry.source == "custom_asset":
		return create_custom_asset_instance(class_name_key)
	if entry.op_script == null:
		GNLogger.warn("ExtRegistry", "Operator '%s' has no script" % class_name_key)
		return null
	var node = entry.op_script.new()
	if node is GNNode:
		return node as GNNode
	GNLogger.error("ExtRegistry", "Script for '%s' does not extend GNNode" % class_name_key)
	node.free()
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Query API
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the operator registry grouped by family — same shape previously
## returned by GNGraphEditor.get_operator_registry().
## { "TOP": ["NoiseTOP", ...], "CHOP": [...], ... }
func get_operator_registry() -> Dictionary:
	var result: Dictionary = {}
	for op_name in _operators:
		var entry: OperatorEntry = _operators[op_name]
		if not result.has(entry.family):
			result[entry.family] = []
		result[entry.family].append(op_name)
	return result


## Returns the operator registry grouped by family AND section.
## { "TOP": { "": ["NoiseTOP", ...], "Shadertoy": ["STSeascapeTOP", ...] }, ... }
## Operators with no section go under the "" (empty string) key.
func get_operator_registry_sectioned() -> Dictionary:
	var result: Dictionary = {}
	for op_name in _operators:
		var entry: OperatorEntry = _operators[op_name]
		if not result.has(entry.family):
			result[entry.family] = {}
		var sections: Dictionary = result[entry.family]
		var sec: String = entry.section
		if not sections.has(sec):
			sections[sec] = []
		sections[sec].append(op_name)
	return result


## Returns the section string for an operator, or "".
func get_section(class_name_key: String) -> String:
	var entry: OperatorEntry = _operators.get(class_name_key, null)
	if entry:
		return entry.section
	return ""


## Returns the description for a single operator, or "".
func get_description(class_name_key: String) -> String:
	var entry: OperatorEntry = _operators.get(class_name_key, null)
	if entry:
		return entry.description
	return ""


## Returns true if the operator is registered.
func has_operator(class_name_key: String) -> bool:
	return _operators.has(class_name_key)


## Returns the full OperatorEntry for a registered operator, or null.
func get_entry(class_name_key: String) -> OperatorEntry:
	return _operators.get(class_name_key, null)


## Returns the OperatorEntry whose script matches the given node's script.
## Linear scan — only used by help window, not per-frame.
func get_entry_by_script(script: GDScript) -> OperatorEntry:
	if script == null:
		return null
	for key in _operators:
		var entry: OperatorEntry = _operators[key]
		if entry.op_script == script:
			return entry
	return null


## Returns the total number of registered operators.
func get_operator_count() -> int:
	return _operators.size()


## Returns all registered operator names.
func get_all_operator_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for key in _operators:
		names.append(key)
	return names


## Returns a list of loaded extension names.
func get_loaded_extensions() -> PackedStringArray:
	return _loaded_extensions.duplicate()


## Lazily-built cache: GNFamily.Type → Array[String] of operator names that accept
## that family as an input port.  Built once on first query, invalidated on
## register/unregister so subsequent queries rebuild.
var _input_family_cache: Dictionary = {}

## Returns operator names that have at least one input port matching [param family].
## Instantiates each operator once to inspect its ports, then caches the result.
func get_operators_accepting_family(family: GNFamily.Type) -> Array[String]:
	if _input_family_cache.has(family):
		return _input_family_cache[family]

	# Build the full cache for ALL families in one pass (avoids repeated instantiation).
	_build_input_family_cache()

	if _input_family_cache.has(family):
		return _input_family_cache[family]
	return []


## Builds (or rebuilds) the input-family → operators cache by instantiating every
## registered operator and reading its input ports.
func _build_input_family_cache() -> void:
	_input_family_cache.clear()
	for op_name in _operators:
		var node: GNNode = create_instance(op_name)
		if node == null:
			continue
		# create_instance() calls .new() which only runs _init().
		# Ports are set up in _init_ports(), which is called by initialize().
		# We don't want full initialize() (needs an ID, wires signals, etc.)
		# so call _init_ports() directly to populate input/output port arrays.
		node._init_ports()
		for port: GNPort in node.input_ports:
			if not _input_family_cache.has(port.family):
				_input_family_cache[port.family] = [] as Array[String]
			var arr: Array[String] = _input_family_cache[port.family]
			if not arr.has(op_name):
				arr.append(op_name)
		# Also include operators whose output family matches (for dragging FROM
		# an input port backwards — we want nodes that produce the right type).
		for port: GNPort in node.output_ports:
			var key_str := "output:%d" % port.family
			if not _input_family_cache.has(key_str):
				_input_family_cache[key_str] = [] as Array[String]
			var arr_out: Array[String] = _input_family_cache[key_str]
			if not arr_out.has(op_name):
				arr_out.append(op_name)
		node.free()


## Returns operator names that have at least one output port matching [param family].
func get_operators_producing_family(family: GNFamily.Type) -> Array[String]:
	if _input_family_cache.is_empty():
		_build_input_family_cache()
	var key_str := "output:%d" % family
	if _input_family_cache.has(key_str):
		return _input_family_cache[key_str]
	return []


## Invalidates the input-family cache (call after register/unregister).
func _invalidate_port_cache() -> void:
	_input_family_cache.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# Extension Scanning
# ═══════════════════════════════════════════════════════════════════════════════

## Scans `res://addons/` for folders matching `gn_ext_*` that contain a
## `gn_extension.cfg` manifest.  For each valid manifest whose ClassDB
## dependencies are satisfied, the declared operators are registered.
func scan_extensions() -> void:
	var addons_path := "res://addons"
	var dir := DirAccess.open(addons_path)
	if dir == null:
		print("[ExtRegistry] Cannot open addons directory")
		return

	var found_count := 0
	dir.list_dir_begin()
	var folder_name := dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and folder_name.begins_with("gn_ext_"):
			found_count += 1
			var ext_path := addons_path + "/" + folder_name
			var cfg_path := ext_path + "/gn_extension.cfg"
			if FileAccess.file_exists(cfg_path):
				_load_extension(cfg_path, folder_name)
			else:
				print("[ExtRegistry] Extension folder '%s' has no gn_extension.cfg" % folder_name)
		folder_name = dir.get_next()
	dir.list_dir_end()

	if found_count == 0:
		print("[ExtRegistry] No extensions found")
	else:
		print("[ExtRegistry] Scanned %d extension(s)" % found_count)


## Loads a single extension manifest and registers its operators.
func _load_extension(cfg_path: String, folder_name: String) -> void:
	if _loaded_extensions.has(folder_name):
		return  # Already loaded

	var cfg := ConfigFile.new()
	var err := cfg.load(cfg_path)
	if err != OK:
		print("[ExtRegistry] Failed to load manifest: %s (error %d)" % [cfg_path, err])
		return

	var ext_dir: String = cfg_path.get_base_dir()  # e.g. "res://addons/gn_ext_shadertoy"
	var ext_name: String = cfg.get_value("extension", "name", folder_name)

	# Extension-level palette section — defaults to the extension name.
	# All operators inherit this; per-operator "section" key overrides.
	var ext_section: String = cfg.get_value("extension", "section", ext_name)

	# ── Dependency check ──
	var deps: Array = cfg.get_value("extension", "dependencies", [])
	for dep_class in deps:
		if not ClassDB.class_exists(dep_class):
			print("[ExtRegistry] Extension '%s' skipped — missing dependency '%s'" % [ext_name, dep_class])
			return

	# ── Register operators ──
	# Sections named "operator.<ClassName>" declare individual operators.
	var registered_count := 0
	for section in cfg.get_sections():
		if not section.begins_with("operator."):
			continue

		var op_class := section.substr("operator.".length())
		var family: String = cfg.get_value(section, "family", "")
		var script_path: String = cfg.get_value(section, "script", "")
		var desc: String = cfg.get_value(section, "description", "")
		var op_section: String = cfg.get_value(section, "section", ext_section)

		if family.is_empty() or script_path.is_empty():
			print("[ExtRegistry] Extension '%s': operator '%s' missing family or script" % [ext_name, op_class])
			continue

		# Load the operator script
		if not ResourceLoader.exists(script_path):
			print("[ExtRegistry] Extension '%s': script not found '%s'" % [ext_name, script_path])
			continue

		var loaded_script: GDScript = load(script_path) as GDScript
		if loaded_script == null:
			print("[ExtRegistry] Extension '%s': failed to load script '%s'" % [ext_name, script_path])
			continue

		register_operator(op_class, family, loaded_script, desc, ext_name, op_section, ext_dir)
		registered_count += 1

	_loaded_extensions.append(folder_name)
	print("[ExtRegistry] Loaded extension '%s' (%d operators)" % [ext_name, registered_count])


# ═══════════════════════════════════════════════════════════════════════════════
# Core Operator Registration
# ═══════════════════════════════════════════════════════════════════════════════

## Registers all built-in (core) operators.
## This replaces the static match block in GNGraphEditor._create_operator_instance()
## and the static description dict in GNNodePalette._get_operator_description().
func _register_core_operators() -> void:
	# ── TOPs: Generators ─────────────────────────────────────────────────
	_reg("NoiseTOP",        "TOP", NoiseTOP,
		"Procedural noise texture (Simplex, Perlin, Voronoi, White). GPU shader.")
	_reg("RampTOP",         "TOP", RampTOP,
		"Gradient ramp generator (horizontal, vertical, radial, circular).")
	_reg("CircleTOP",       "TOP", CircleTOP,
		"SDF circle or ring shape with fill/border/softness.")
	_reg("RectangleTOP",    "TOP", RectangleTOP,
		"SDF rounded rectangle with fill/border/softness.")
	_reg("ConstantTOP",     "TOP", ConstantTOP,
		"Solid color texture.")
	_reg("TextTOP",         "TOP", TextTOP,
		"Renders text to a texture via a Label in a SubViewport.")
	_reg("MovieFileInTOP",  "TOP", MovieFileInTOP,
		"Plays a video file (.ogv Theora) as a live texture stream.")

	# ── TOPs: Filters (1 input) ─────────────────────────────────────────
	_reg("LevelTOP",        "TOP", LevelTOP,
		"Brightness, contrast, gamma, invert, and opacity adjustments.")
	_reg("BlurTOP",         "TOP", BlurTOP,
		"Two-pass separable blur (Gaussian or Box).")
	_reg("TransformTOP",    "TOP", TransformTOP,
		"2D translate, rotate, and scale with extend modes.")
	_reg("HSVAdjustTOP",    "TOP", HSVAdjustTOP,
		"Hue offset, saturation, and value (brightness) adjustment.")
	_reg("EdgeTOP",         "TOP", EdgeTOP,
		"Sobel edge detection with configurable strength.")
	_reg("ThresholdTOP",    "TOP", ThresholdTOP,
		"Binary black/white threshold with optional softness.")
	_reg("FlipTOP",         "TOP", FlipTOP,
		"Mirror texture horizontally and/or vertically.")
	_reg("TileTOP",         "TOP", TileTOP,
		"Tile/repeat a texture with optional mirroring.")
	_reg("CropTOP",         "TOP", CropTOP,
		"Crop a UV sub-region from the input texture.")
	_reg("FeedbackTOP",     "TOP", FeedbackTOP,
		"Blends current frame with previous frame for trails/echoes.")
	_reg("ResolutionTOP",   "TOP", ResolutionTOP,
		"Resize a texture to a different resolution.")

	# ── TOPs: Combiners (2 inputs) ──────────────────────────────────────
	_reg("CompositeTOP",    "TOP", CompositeTOP,
		"Blend two textures (Add, Multiply, Over, Screen, etc.).")
	_reg("CrossTOP",        "TOP", CrossTOP,
		"Linear crossfade between two textures.")
	_reg("DisplaceTOP",     "TOP", DisplaceTOP,
		"Distort one texture using another as a displacement map.")
	_reg("LookupTOP",       "TOP", LookupTOP,
		"Remap colors via a lookup table / ramp texture.")
	_reg("ColorMapTOP",     "TOP", ColorMapTOP,
		"Remap luminance to a gradient texture (source + gradient inputs).")
	_reg("RemapTOP",        "TOP", RemapTOP,
		"UV displacement remap or 1D LUT value remap via map texture.")
	_reg("LayoutTOP",       "TOP", LayoutTOP,
		"Tile up to 8 input textures into a grid mosaic (dynamic ports).")
	_reg("ChromaKeyTOP",    "TOP", ChromaKeyTOP,
		"Chroma / luma key (green-screen) with spill suppression.")

	# ── TOPs: Generators (new) ──────────────────────────────────────────
	_reg("PatternTOP",      "TOP", PatternTOP,
		"Procedural patterns: stripes, checkerboard, concentric, grid, dots.")
	_reg("TriangleTOP",     "TOP", TriangleTOP,
		"SDF 2D primitives: triangle, line, pentagon with fill/border.")
	_reg("SVGTOP",          "TOP", SVGTOP,
		"Render SVG vector graphics to a texture at arbitrary resolution.")

	# ── TOPs: Filters (new) ─────────────────────────────────────────────
	_reg("AnalyzeTOP",      "TOP", AnalyzeTOP,
		"Per-pixel statistics: min, max, average, or sum over a kernel.")
	_reg("MonoTOP",         "TOP", MonoTOP,
		"Convert to grayscale (Rec.709, Rec.601, Average, Desaturate).")
	_reg("SharpenTOP",      "TOP", SharpenTOP,
		"Unsharp-mask sharpening with strength and radius.")
	_reg("NormalMapTOP",    "TOP", NormalMapTOP,
		"Generate a tangent-space normal map from a height/bump texture.")
	_reg("DepthTOP",        "TOP", DepthTOP,
		"Pseudo-depth extraction via luminance (near/far/invert controls).")
	_reg("ChannelMixTOP",   "TOP", ChannelMixTOP,
		"Swap and remap RGBA channels with per-channel gain.")
	_reg("ConvolutionTOP",  "TOP", ConvolutionTOP,
		"Custom NxN kernel convolution with Emboss/Sharpen/Edge presets.")
	_reg("DilateErodeTOP",  "TOP", DilateErodeTOP,
		"Morphological dilate (expand) or erode (shrink) with circular footprint.")
	_reg("LensDistortTOP",  "TOP", LensDistortTOP,
		"Barrel / pincushion lens distortion with chromatic aberration.")
	_reg("LumaBlurTOP",     "TOP", LumaBlurTOP,
		"Luminance-weighted selective blur (bright or dark areas blurred more).")
	_reg("SlopeTOP",        "TOP", SlopeTOP,
		"Image gradient / derivative: horizontal, vertical, or magnitude.")
	_reg("CornerPinTOP",    "TOP", CornerPinTOP,
		"4-point perspective warp for projection mapping and keystone correction.")
	_reg("ProjectionTOP",   "TOP", ProjectionTOP,
		"UV projection mapping: planar, cylindrical, or spherical.")
	_reg("FitTOP",          "TOP", FitTOP,
		"Aspect-aware resize: fit, fill, stretch, or letterbox with border colour.")

	# ── TOPs: Temporal / Buffer ─────────────────────────────────────────
	_reg("CacheTOP",        "TOP", CacheTOP,
		"Ring buffer that stores N frames with delay and freeze controls.")
	_reg("TimeMachineTOP",  "TOP", TimeMachineTOP,
		"Playback controller over a frame buffer with speed, scrub, and wrap modes.")

	# ── TOPs: Scripting ─────────────────────────────────────────────────
	_reg("CustomShaderTOP",  "TOP", CustomShaderTOP,
		"User-editable GLSL shader with 4 texture inputs and uniforms.")
	_reg("ComputeShaderTOP", "TOP", ComputeShaderTOP,
		"GPU compute shader (GLSL 450) with storage image output and auto-detected parameters.")

	# ── TOPs: 3D Rendering ──────────────────────────────────────────────
	_reg("RenderTOP",       "TOP", RenderTOP,
		"Renders a 3D COMP scene into a 2D texture with integrated post-processing.")

	# ── TOPs: Utility ───────────────────────────────────────────────────
	_reg("NullTOP",         "TOP", NullTOP,
		"Pass-through. Useful for organization and expression references.")
	_reg("SwitchTOP",       "TOP", SwitchTOP,
		"Select one of up to 4 texture inputs by index.")

	# ── TOPs: Filters (matte, premultiply, posterize, radial blur, anti-alias, palette) ──
	_reg("MatteTOP",        "TOP", MatteTOP,
		"Apply alpha from a second texture (luma/R/G/B/A source, invert, premultiply).")
	_reg("PremultiplyTOP",  "TOP", PremultiplyTOP,
		"Premultiply or unpremultiply RGB by alpha.")
	_reg("PosterizeTOP",    "TOP", PosterizeTOP,
		"Reduce color depth to N discrete levels (2-256).")
	_reg("RadialBlurTOP",   "TOP", RadialBlurTOP,
		"Zoom / radial blur from a configurable center point.")
	_reg("AntiAliasTOP",    "TOP", AntiAliasTOP,
		"Simplified FXAA-style anti-aliasing with luma edge detection.")
	_reg("PaletteTOP",      "TOP", PaletteTOP,
		"Quantize colors to a palette texture with optional Bayer dithering.")

	# ── TOPs: New (Tier 1 + 2) ──────────────────────────────────────────
	_reg("OpticalFlowTOP",  "TOP", OpticalFlowTOP,
		"Horn-Schunck optical flow motion vector estimation.")
	_reg("GlueTOP",         "TOP", GlueTOP,
		"Pack multiple textures into a grid atlas layout.")
	_reg("EmbossTOP",       "TOP", EmbossTOP,
		"Emboss relief filter with adjustable angle and strength.")

	# ── TOPs: 3D Render Variants ────────────────────────────────────────
	_reg("GeometryBufferTOP",      "TOP", GeometryBufferTOP,
		"Render 3D scene with debug buffer output: Color, Unshaded, Normal Buffer, or Wireframe.")
	_reg("CompositorEffectTOP",    "TOP", CompositorEffectTOP,
		"Render 3D scene with a pipeline-level CompositorEffect: Outline, Depth Fog, or Depth View.")
	_reg("MultiBufferRenderTOP",   "TOP", MultiBufferRenderTOP,
		"Multi-buffer 3D render: outputs color, depth, and normal buffer textures.")

	# ── CHOPs: Generators ───────────────────────────────────────────────
	_reg("LFO_CHOP",        "CHOP", LFO_CHOP,
		"Low-frequency oscillator (sine, triangle, square, saw, pulse).")
	_reg("WaveCHOP",        "CHOP", WaveCHOP,
		"Multi-channel, multi-sample waveform generator.")
	_reg("NoiseCHOP",       "CHOP", NoiseCHOP,
		"Smooth procedural noise channels with roughness control.")
	_reg("ConstantCHOP",    "CHOP", ConstantCHOP,
		"Up to 3 named static float values.")
	_reg("PatternCHOP",     "CHOP", PatternCHOP,
		"Multi-sample pattern (ramp, sine, step, random, constant).")
	_reg("TimerCHOP",       "CHOP", TimerCHOP,
		"Countdown/count-up timer with loop and speed controls.")
	_reg("RampCHOP",        "CHOP", RampCHOP,
		"Dynamic ramp curves → CHOP channels (1–16 user-editable ramps).")

	# ── CHOPs: Filters (1 input) ────────────────────────────────────────
	_reg("MathCHOP",        "CHOP", MathCHOP,
		"Arithmetic operations (Add, Subtract, Multiply, Divide, Abs, Sin, Cos, Pow).")
	_reg("FilterCHOP",      "CHOP", FilterCHOP,
		"Single-pole IIR low-pass or high-pass filter.")
	_reg("LagCHOP",         "CHOP", LagCHOP,
		"Exponential smoothing with separate attack and release times.")
	_reg("LimitCHOP",       "CHOP", LimitCHOP,
		"Clamp, loop, or zig-zag values within a range.")
	_reg("TriggerCHOP",     "CHOP", TriggerCHOP,
		"Attack/peak/decay envelope triggered by rising edges.")
	_reg("SpeedCHOP",       "CHOP", SpeedCHOP,
		"Velocity integrator — accumulates input over time.")
	_reg("CountCHOP",       "CHOP", CountCHOP,
		"Rising-edge event counter with overflow modes.")
	_reg("HoldCHOP",        "CHOP", HoldCHOP,
		"Sample-and-hold — captures values on trigger.")
	_reg("SelectCHOP",      "CHOP", SelectCHOP,
		"Filter and rename channels by wildcard pattern.")

	# ── CHOPs: Combiners ────────────────────────────────────────────────
	_reg("LogicCHOP",       "CHOP", LogicCHOP,
		"Boolean logic (AND, OR, XOR, NAND, NOR, NOT) on channels.")
	_reg("MergeCHOP",       "CHOP", MergeCHOP,
		"Merge channels from up to 4 inputs.")
	_reg("CrossCHOP",       "CHOP", CrossCHOP,
		"Linear crossfade between two channel sets.")

	# ── CHOPs: Utility ──────────────────────────────────────────────────
	_reg("NullCHOP",        "CHOP", NullCHOP,
		"Pass-through.")
	_reg("SwitchCHOP",      "CHOP", SwitchCHOP,
		"Select one of up to 4 channel inputs by index.")
	_reg("RenameCHOP",      "CHOP", RenameCHOP,
		"Rename input channels with explicit from→to mapping.")

	# ── CHOPs: Bridge ───────────────────────────────────────────────────
	_reg("DATtoCHOP",       "CHOP", DATtoCHOP,
		"Convert DAT table to CHOP channels.")
	_reg("PhysicsCHOP",     "CHOP", PhysicsCHOP,
		"Read transform & velocity channels from a physics body COMP.")

	# ── CHOPs: Scripting ────────────────────────────────────────────────
	_reg("ScriptCHOP",      "CHOP", ScriptCHOP,
		"User-scripted CHOP. Write GDScript to generate or transform channel data.")

	# ── CHOPs: I/O (OSC, MIDI, Audio) ──────────────────────────────────
	_reg("OscInCHOP",       "CHOP", OscInCHOP,
		"Receive OSC messages as CHOP channels via UDP.")
	_reg("MidiInCHOP",      "CHOP", MidiInCHOP,
		"Receive MIDI note, CC, pitch bend as CHOP channels.")
	_reg("AudioInCHOP",     "CHOP", AudioInCHOP,
		"Capture live microphone audio as CHOP channels.")
	_reg("AudioSpectrumCHOP", "CHOP", AudioSpectrumCHOP,
		"FFT spectrum analysis — frequency bands as CHOP channels.")
	_reg("AudioFileInCHOP", "CHOP", AudioFileInCHOP,
		"Play audio file (WAV/OGG) and output waveform as CHOP channels.")

	# ── CHOPs: Input Devices ────────────────────────────────────────────
	_reg("KeyboardInCHOP",  "CHOP", KeyboardInCHOP,
		"Keyboard key states as CHOP channels (toggle or momentary mode).")
	_reg("MouseInCHOP",     "CHOP", MouseInCHOP,
		"Mouse position, delta, buttons, and scroll as CHOP channels.")
	_reg("GamepadCHOP",     "CHOP", GamepadCHOP,
		"Gamepad sticks, triggers, and buttons with deadzone control.")

	# ── CHOPs: Bridge (new) ─────────────────────────────────────────────
	_reg("ParameterCHOP",   "CHOP", ParameterCHOP,
		"Read another node's parameter values as CHOP channels.")
	_reg("TrailCHOP",       "CHOP", TrailCHOP,
		"Scrolling buffer recording input values over time (oscilloscope).")
	_reg("SOPtoCHOP",       "CHOP", SOPtoCHOP,
		"Extract SOP vertex positions/normals/UVs as CHOP channels.")
	_reg("TOPtoCHOP",       "CHOP", TOPtoCHOP,
		"Sample TOP texture pixel values (average, center, row, column).")

	# ── CHOPs: Generators (new) ─────────────────────────────────────────
	_reg("ClockCHOP",       "CHOP", ClockCHOP,
		"System time, frame count, elapsed time, and BPM beat channels.")
	_reg("ExpressionCHOP",  "CHOP", ExpressionCHOP,
		"Per-channel GDScript expression evaluation with time variables.")

	# ── CHOPs: Filters (new) ────────────────────────────────────────────
	_reg("SmoothCHOP",      "CHOP", SmoothCHOP,
		"Biquad Butterworth IIR filter (low-pass, high-pass, band-pass).")
	_reg("SpringCHOP",      "CHOP", SpringCHOP,
		"Damped harmonic oscillator — channels spring toward input values.")
	_reg("DelayCHOP",       "CHOP", DelayCHOP,
		"Delay channels by N frames using a ring buffer.")
	_reg("EnvelopeCHOP",    "CHOP", EnvelopeCHOP,
		"Envelope follower — RMS, peak, or average-abs with window size.")
	_reg("AnalyzeCHOP",     "CHOP", AnalyzeCHOP,
		"Per-channel statistics: min, max, average, RMS, sum, range, count.")
	_reg("LookupCHOP",      "CHOP", LookupCHOP,
		"Index into a sample array using another channel as lookup position.")
	_reg("StretchCHOP",     "CHOP", StretchCHOP,
		"Time-stretch samples with Catmull-Rom cubic interpolation.")
	_reg("ResampleCHOP",    "CHOP", ResampleCHOP,
		"Resample channels to a new sample count or sample rate.")
	_reg("TrimCHOP",        "CHOP", TrimCHOP,
		"Extract a sub-range of samples from channels.")
	_reg("ExtendCHOP",      "CHOP", ExtendCHOP,
		"Pad samples before/after with hold, cycle, mirror, slope, or zero.")

	# ── CHOPs: New (Tier 1 + 2) ────────────────────────────────────────
	_reg("BeatCHOP",        "CHOP", BeatCHOP,
		"Energy-based beat/onset detection for music-reactive visuals.")
	_reg("IKCHOP",          "CHOP", IKCHOP,
		"FABRIK inverse kinematics chain solver with joint position output.")
	_reg("WarpCHOP",        "CHOP", WarpCHOP,
		"Time-warp / retime channel data with speed, offset, or warp curve.")

	# ── CHOPs: Signal Analysis & Dynamics ──────────────────────────────
	_reg("SlopeCHOP",           "CHOP", SlopeCHOP,
		"1st/2nd derivative (rate-of-change) of input channels — velocity, acceleration.")
	_reg("AudioDynamicsCHOP",   "CHOP", AudioDynamicsCHOP,
		"Compressor / Limiter / Expander / Gate dynamics processor for audio-rate CHOPs.")

	# ── CHOPs: Combiners (new) ──────────────────────────────────────────
	_reg("InterpolateCHOP", "CHOP", InterpolateCHOP,
		"Blend between two channel sets with easing curves.")
	_reg("JoinCHOP",        "CHOP", JoinCHOP,
		"Concatenate samples from multiple inputs with optional crossfade.")
	_reg("CompositeCHOP",   "CHOP", CompositeCHOP,
		"Weighted blend from multiple inputs (avg, add, max, min).")
	_reg("CopyCHOP",        "CHOP", CopyCHOP,
		"Copy channels from B onto A (overwrite, add, subtract, multiply).")

	# ── CHOPs: Channel Management (new) ────────────────────────────────
	_reg("ShuffleCHOP",     "CHOP", ShuffleCHOP,
		"Reorder, reverse, sort, or randomize channel order.")
	_reg("SplitCHOP",       "CHOP", SplitCHOP,
		"Select one channel or group of N channels from input.")
	_reg("FanCHOP",         "CHOP", FanCHOP,
		"Fan a single channel into multiple copies with offset spread.")
	_reg("DeleteCHOP",      "CHOP", DeleteCHOP,
		"Delete channels by name pattern, index, or keep-only mode.")

	# ── CHOPs: New (TD Gap) ─────────────────────────────────────────────
	_reg("FeedbackCHOP",    "CHOP", FeedbackCHOP,
		"Previous-frame channel data for feedback loops.")
	_reg("BlendCHOP",       "CHOP", BlendCHOP,
		"Sample-by-sample weighted blend across multiple CHOP inputs.")
	_reg("PerformCHOP",     "CHOP", PerformCHOP,
		"System performance metrics: FPS, frame time, memory.")
	_reg("TransformCHOP",   "CHOP", TransformCHOP,
		"3D transform on xyz channel groups (translate, rotate, scale).")

	# ── SOPs: Generators ────────────────────────────────────────────────
	_reg("GridSOP",         "SOP", GridSOP,
		"Subdivided plane with configurable orientation.")
	_reg("BoxSOP",          "SOP", BoxSOP,
		"Box mesh with per-axis size and subdivisions.")
	_reg("SphereSOP",       "SOP", SphereSOP,
		"Sphere or hemisphere mesh.")
	_reg("TorusSOP",        "SOP", TorusSOP,
		"Torus (donut) mesh with inner/outer radius.")
	_reg("CylinderSOP",     "SOP", CylinderSOP,
		"Cylinder or cone mesh with top/bottom radius and caps.")
	_reg("LineSOP",         "SOP", LineSOP,
		"Line strip along an axis.")
	_reg("CircleSOP",       "SOP", CircleSOP,
		"Filled disc or wire circle with configurable orientation.")

	# ── SOPs: Filters ───────────────────────────────────────────────────
	_reg("TransformSOP",    "SOP", TransformSOP,
		"Translate, rotate, and scale geometry with 6 transform orders.")
	_reg("NoiseSOP",        "SOP", NoiseSOP,
		"Displace vertices with animated procedural noise.")
	_reg("SubdivideSOP",    "SOP", SubdivideSOP,
		"Midpoint triangle subdivision (1-4 iterations).")
	_reg("WireframeSOP",    "SOP", WireframeSOP,
		"Convert triangles to deduplicated wireframe lines.")

	# ── SOPs: Combiners ─────────────────────────────────────────────────
	_reg("MergeSOP",        "SOP", MergeSOP,
		"Merge multiple geometries into one ArrayMesh.")

	# ── SOPs: Utility ───────────────────────────────────────────────────
	_reg("NullSOP",         "SOP", NullSOP,
		"Pass-through.")
	_reg("SwitchSOP",       "SOP", SwitchSOP,
		"Select one of 2 geometry inputs by index.")

	# ── SOPs: Scripting ─────────────────────────────────────────────────
	_reg("ScriptSOP",       "SOP", ScriptSOP,
		"User-scripted SOP. Write GDScript to generate or transform 3D geometry.")

	# ── SOPs: Generators (new) ──────────────────────────────────────────
	_reg("TubeSOP",         "SOP", TubeSOP,
		"Tube or pipe generator with inner/outer walls and caps.")

	# ── SOPs: Filters (new) ────────────────────────────────────────────
	_reg("NormalSOP",       "SOP", NormalSOP,
		"Recompute smooth normals, flip normals, or generate flat (faceted) normals.")
	_reg("ReverseSOP",      "SOP", ReverseSOP,
		"Reverse face winding order and flip normals.")
	_reg("PeakSOP",         "SOP", PeakSOP,
		"Push vertices along their normals by a distance.")
	_reg("SortSOP",         "SOP", SortSOP,
		"Sort vertices by axis, distance from origin, or randomly.")
	_reg("FacetSOP",        "SOP", FacetSOP,
		"Unique points (flat shading) or consolidate close vertices.")
	_reg("DeleteSOP",       "SOP", DeleteSOP,
		"Delete faces or points by range, bounding box, or random percentage.")
	_reg("PointSOP",        "SOP", PointSOP,
		"Per-vertex position modification via GDScript expressions.")
	_reg("AttributeSOP",    "SOP", AttributeSOP,
		"Create or modify per-vertex point attributes from expressions or presets.")
	_reg("ClipSOP",         "SOP", ClipSOP,
		"Clip geometry by an axis-aligned plane with triangle splitting.")
	_reg("MirrorSOP",       "SOP", MirrorSOP,
		"Reflect geometry across a plane with optional merge.")
	_reg("ExtrudeSOP",      "SOP", ExtrudeSOP,
		"Per-triangle face extrusion with front, back, and side walls.")

	# ── SOPs: Combiners (new) ──────────────────────────────────────────
	_reg("CopySOP",         "SOP", CopySOP,
		"Instance template geometry onto each point of the target mesh.")
	_reg("ScatterSOP",      "SOP", ScatterSOP,
		"Scatter random points on mesh surface (area-weighted sampling).")
	_reg("BooleanSOP",      "SOP", BooleanSOP,
		"Boolean operations (union, intersect, subtract) via CSG.")
	_reg("SweepSOP",        "SOP", SweepSOP,
		"Sweep a cross-section along a backbone curve (parallel transport frames).")
	_reg("SkinSOP",         "SOP", SkinSOP,
		"Skin (loft) multiple cross-sections into a surface mesh.")

	# ── SOPs: Deformers (new) ──────────────────────────────────────────
	_reg("SpringSOP",       "SOP", SpringSOP,
		"Damped spring vertex deformer — vertices spring toward input positions.")
	_reg("BendSOP",         "SOP", BendSOP,
		"Bend geometry along an axis using circular arc deformation.")
	_reg("TwistSOP",        "SOP", TwistSOP,
		"Twist vertices around an axis proportional to position.")
	_reg("TaperSOP",        "SOP", TaperSOP,
		"Taper geometry by scaling perpendicular axes along a profile.")
	_reg("MagnetSOP",       "SOP", MagnetSOP,
		"Deform geometry by attracting/repelling vertices toward attractor points.")

	# ── SOPs: Generators (new 2) ───────────────────────────────────────
	_reg("FontSOP",         "SOP", FontSOP,
		"Generate 3D text mesh using Godot TextMesh.")
	_reg("LSystemSOP",      "SOP", LSystemSOP,
		"L-System turtle-graphics geometry generator (fractal plants, trees, curves).")
	_reg("MetaballSOP",     "SOP", MetaballSOP,
		"Metaball implicit surface via marching cubes from point cloud blobs.")
	_reg("IsoSurfaceSOP",   "SOP", IsoSurfaceSOP,
		"Analytic implicit surface via marching cubes (Gyroid, Schwarz-P, Torus, custom).")
	_reg("ParticleSOP",     "SOP", ParticleSOP,
		"CPU particle emitter from SOP surface with forces, collision, and attributes.")

	# ── SOPs: Filters (new 2) ─────────────────────────────────────────
	_reg("TrailSOP",        "SOP", TrailSOP,
		"Record centroid over time as a line strip trail.")
	_reg("UVProjectSOP",    "SOP", UVProjectSOP,
		"Assign UVs via planar, cylindrical, or spherical projection.")
	_reg("DivideSOP",       "SOP", DivideSOP,
		"Triangulate mesh and remove degenerate triangles.")
	_reg("CarveSOP",        "SOP", CarveSOP,
		"Trim mesh by parametric U range (reveal, slice, carve animations).")
	_reg("PolyReduceSOP",   "SOP", PolyReduceSOP,
		"Mesh decimation via quadric error metric edge collapse.")

	# ── SOPs: New (Tier 1 + 2) ─────────────────────────────────────────
	_reg("FuseSOP",         "SOP", FuseSOP,
		"Merge coincident vertices within a distance threshold.")
	_reg("RaySOP",          "SOP", RaySOP,
		"Project vertices onto a target surface via raycasting.")
	_reg("CapSOP",          "SOP", CapSOP,
		"Close open boundary holes with triangle fan caps.")
	_reg("LatticeSOP",      "SOP", LatticeSOP,
		"Free-form deformation via control-point lattice.")
	_reg("PolyLoftSOP",     "SOP", PolyLoftSOP,
		"Loft polygon surface between cross-section rings.")
	_reg("MountainSOP",     "SOP", MountainSOP,
		"Noise-based vertex displacement along normals.")

	# ── SOPs: Filter / Selection ────────────────────────────────────────
	_reg("SelectSOP",       "SOP", SelectSOP,
		"Keep geometry matching a criterion: range, bounding box, expression, or every Nth.")

	# ── SOPs: Bridge (cross-family conversion) ─────────────────────────
	_reg("CHOPtoSOP",       "SOP", CHOPtoSOP,
		"Convert CHOP channels to SOP points, lines, or trail geometry.")
	_reg("DATtoSOP",        "SOP", DATtoSOP,
		"Convert DAT table rows to SOP point positions.")
	_reg("TOPtoSOP",        "SOP", TOPtoSOP,
		"Convert TOP texture to SOP heightfield, point cloud, or normal map mesh.")

	# ── SOPs: New (TD Gap) ──────────────────────────────────────────────
	_reg("FileInSOP",       "SOP", FileInSOP,
		"Import OBJ, glTF, or resource file as SOP geometry.")
	_reg("FileOutSOP",      "SOP", FileOutSOP,
		"Export SOP geometry to Wavefront OBJ file.")
	_reg("GroupSOP",        "SOP", GroupSOP,
		"Create and manage point/primitive groups via bounding box, normal, or range.")
	_reg("PrimitiveSOP",    "SOP", PrimitiveSOP,
		"Compute per-primitive attributes: face normal, area, centroid, prim ID.")
	_reg("BlendSOP",        "SOP", BlendSOP,
		"Morph between two geometries by blending vertex positions.")

	# ── DATs: Generators ────────────────────────────────────────────────
	_reg("ConstantDAT",     "DAT", ConstantDAT,
		"Manually editable 4x4 table with column headers.")
	_reg("TextDAT",         "DAT", TextDAT,
		"Plain text storage.")
	_reg("InfoDAT",         "DAT", InfoDAT,
		"System info table (fps, frame, time, OS, memory).")
	_reg("OscInDAT",        "DAT", OscInDAT,
		"Receive OSC messages into a DAT table via UDP.")
	_reg("MidiInDAT",       "DAT", MidiInDAT,
		"Log raw MIDI messages (note, CC, pitch bend) into a DAT table.")

	# ── DATs: Filters ───────────────────────────────────────────────────
	_reg("SelectDAT",       "DAT", SelectDAT,
		"Extract row/column subsets by index range.")
	_reg("TransposeDAT",    "DAT", TransposeDAT,
		"Swap rows and columns.")
	_reg("SortDAT",         "DAT", SortDAT,
		"Sort rows by a column (alphabetic or numeric).")
	_reg("EvaluateDAT",     "DAT", EvaluateDAT,
		"Evaluate cells starting with '=' as GDScript expressions.")

	# ── DATs: Combiners ─────────────────────────────────────────────────
	_reg("MergeDAT",        "DAT", MergeDAT,
		"Stack rows or append columns from two inputs.")

	# ── DATs: Utility ───────────────────────────────────────────────────
	_reg("NullDAT",         "DAT", NullDAT,
		"Pass-through.")
	_reg("SwitchDAT",       "DAT", SwitchDAT,
		"Select one of 2 table inputs by index.")

	# ── DATs: Bridge ────────────────────────────────────────────────────
	_reg("CHOPDAT",         "DAT", CHOPDAT,
		"Convert CHOP channels to a DAT table.")

	# ── DATs: Scripting ─────────────────────────────────────────────────
	_reg("ScriptDAT",       "DAT", ScriptDAT,
		"User-scripted DAT. Write GDScript to generate or transform table/text data.")
	_reg("CallbackDAT",     "DAT", CallbackDAT,
		"Event-driven callback DAT. Named scripts fire on target node events (onCook, onValueChange, onStart).")

	# ── DATs: Input / IO (new) ──────────────────────────────────────────
	_reg("FileInDAT",       "DAT", FileInDAT,
		"Read a file (CSV, TSV, JSON, text) from disk into a table.")
	_reg("JSONDAT",         "DAT", JSONDAT,
		"Parse JSON string to table or generate JSON from table.")
	_reg("WebDAT",          "DAT", WebDAT,
		"Fetch data from a URL via HTTP GET/POST.")

	# ── DATs: Filters (new) ─────────────────────────────────────────────
	_reg("SubstituteDAT",   "DAT", SubstituteDAT,
		"Find and replace text in table cells or text (regex supported).")
	_reg("InsertDAT",       "DAT", InsertDAT,
		"Insert rows or columns into a table at a given position.")
	_reg("DeleteDAT",       "DAT", DeleteDAT,
		"Delete rows or columns from a table by index range.")
	_reg("FIFODAT",         "DAT", FIFODAT,
		"First-in-first-out rolling row buffer with max row limit.")

	# ── DATs: Bridge (new) ──────────────────────────────────────────────
	_reg("SOPtoDAT",        "DAT", SOPtoDAT,
		"Convert SOP vertex data or mesh summary to a DAT table.")
	_reg("TOPtoDAT",        "DAT", TOPtoDAT,
		"Convert TOP texture info or pixel data to a DAT table.")
	_reg("OPFindDAT",       "DAT", OPFindDAT,
		"Search the network for operators by family and name pattern.")

	# ── DATs: New (Tier 2) ─────────────────────────────────────────────
	_reg("TableDAT",        "DAT", TableDAT,
		"Manual editable data table (CSV-style).")
	_reg("NetworkDAT",      "DAT", NetworkDAT,
		"TCP/UDP network send/receive with protocol mode toggle.")
	_reg("XMLDAT",          "DAT", XMLDAT,
		"Parse XML document into a flat path/attribute/value table.")

	# ── DATs: New (TD Gap) ──────────────────────────────────────────────
	_reg("WebServerDAT",    "DAT", WebServerDAT,
		"HTTP server via TCPServer — serve content and log requests.")
	_reg("WebSocketDAT",    "DAT", WebSocketDAT,
		"WebSocket client/server for real-time bidirectional messaging.")
	_reg("ErrorDAT",        "DAT", ErrorDAT,
		"Capture warnings and errors from GNLogger as a table.")
	_reg("FolderDAT",       "DAT", FolderDAT,
		"List directory contents with optional recursive traversal.")
	_reg("MultiTouchInDAT", "DAT", MultiTouchInDAT,
		"Multi-touch input events as table rows with position and pressure.")

	# ── IMGs: Generators ─────────────────────────────────────────────────
	_reg("NoiseIMG",        "IMG", NoiseIMG,
		"CPU procedural noise image (value noise, white noise).")
	_reg("CheckerboardIMG", "IMG", CheckerboardIMG,
		"CPU checkerboard pattern generator.")

	# ── IMGs: File / Media Input ───────────────────────────────────────
	_reg("ImageFileInIMG",  "IMG", ImageFileInIMG,
		"Loads an image file (PNG, JPG, WebP, HDR, EXR, etc.) as CPU Image.")
	_reg("ImageSequenceIMG", "IMG", ImageSequenceIMG,
		"Plays a numbered image sequence as animated CPU Image frames.")
	_reg("WebcamIMG",       "IMG", WebcamIMG,
		"Live webcam/camera feed as CPU Image. Chain → ImgToTOP for GPU.")
	_reg("ScreenGrabIMG",   "IMG", ScreenGrabIMG,
		"Capture viewport contents as CPU Image. Chain → ImgToTOP for GPU.")

	# ── IMGs: Filters ───────────────────────────────────────────────────
	_reg("BlurIMG",         "IMG", BlurIMG,
		"CPU box blur filter. Separable horizontal/vertical passes.")
	_reg("EdgeDetectIMG",   "IMG", EdgeDetectIMG,
		"CPU edge detection (Sobel / Prewitt). Outputs grayscale edges.")
	_reg("PixelSortIMG",    "IMG", PixelSortIMG,
		"CPU pixel sorting glitch effect (sort pixel spans by brightness/hue).")

	# ── IMGs: Scripting ─────────────────────────────────────────────────
	_reg("ScriptIMG",       "IMG", ScriptIMG,
		"User-scripted IMG. Write GDScript to generate or transform CPU Images.")
	_reg("NullIMG",         "IMG", NullIMG,
		"Pass-through for organization and references.")

	# ── IMGs: Bridge ────────────────────────────────────────────────────
	_reg("ImgToTOP",        "IMG", ImgToTOP,
		"Convert IMG (CPU Image) to TOP (GPU Texture). Bridge operator.")
	_reg("TOPtoIMG",        "IMG", TOPtoIMG,
		"Convert TOP (GPU Texture) to IMG (CPU Image). Bridge operator (GPU readback).")

	# ── TOPs: Bridge (cross-family conversion) ─────────────────────────
	_reg("CHOPtoTOP",       "TOP", CHOPtoTOP,
		"Render CHOP channels as a texture (waveform, heatmap, or graph).")
	_reg("SnapshotTOP",     "TOP", SnapshotTOP,
		"Render any non-TOP data as a texture (SOP/CHOP/DAT/POP/VOL/MAT/IMG). Same visualization as the viewer panel.")

	# ── COMPs ───────────────────────────────────────────────────────────
	_reg("GeometryCOMP",    "COMP", GeometryCOMP,
		"MeshInstance3D wrapper — places SOP geometry in a 3D scene with MAT material.")
	_reg("CameraCOMP",      "COMP", CameraCOMP,
		"Camera3D wrapper — defines the viewpoint for RenderTOP.")
	_reg("LightCOMP",       "COMP", LightCOMP,
		"Light3D wrapper (Directional, Omni, Spot) for scene illumination.")
	_reg("MergeCOMP",       "COMP", MergeCOMP,
		"Merge multiple COMPs into a single scene group with group transform.")

	# ── COMPs: Physics ──────────────────────────────────────────────────
	_reg("RigidBodyCOMP",   "COMP", RigidBodyCOMP,
		"RigidBody3D with collision shape — dynamic physics object.")
	_reg("StaticBodyCOMP",  "COMP", StaticBodyCOMP,
		"StaticBody3D with collision shape — immovable collider.")
	_reg("SoftBodyCOMP",    "COMP", SoftBodyCOMP,
		"SoftBody3D — deformable mesh with spring-mass physics.")
	_reg("AreaCOMP",        "COMP", AreaCOMP,
		"Area3D force field — gravity zones, wind, attract/repel regions.")
	_reg("JointCOMP",       "COMP", JointCOMP,
		"Joint3D constraint between two physics bodies (Pin, Hinge, Slider, ConeTwist, 6DOF).")

	# ── COMPs: Sub-Networks ─────────────────────────────────────────────
	_reg("SubNetworkNode",  "COMP", SubNetworkNode,
		"Sub-network — contains a nested node graph with InTunnel/OutTunnel ports.")
	_reg("InTunnel",        "COMP", InTunnel,
		"Input tunnel — bridges data from parent sub-network into inner graph.")
	_reg("OutTunnel",       "COMP", OutTunnel,
		"Output tunnel — bridges data from inner graph to parent sub-network.")

	# ── COMPs: Utility (new) ────────────────────────────────────────────
	_reg("NullCOMP",        "COMP", NullCOMP,
		"Pass-through component for wire organization.")
	_reg("SwitchCOMP",      "COMP", SwitchCOMP,
		"Select one of up to 8 component inputs by index.")
	_reg("EnvironmentCOMP",  "COMP", EnvironmentCOMP,
		"Environment settings for 3D rendering — background, lighting, post-processing.")
	_reg("InstanceCOMP",    "COMP", InstanceCOMP,
		"MultiMeshInstance3D instancing — thousands of geometry copies in one draw call.")

	# ── COMPs: Animation ────────────────────────────────────────────────
	_reg("AnimationCOMP",   "COMP", AnimationCOMP,
		"AnimationPlayer wrapper for keyframe animation on COMP transform properties.")
	_reg("ReplicatorCOMP",  "COMP", ReplicatorCOMP,
		"Table-driven replicator — create N copies of a template with per-instance overrides.")
	_reg("EnginesCOMP",     "COMP", EnginesCOMP,
		"Cook throttle — Live, Snapshot, or Interval update modes for performance isolation.")

	# ── COMPs: Scripting ────────────────────────────────────────────────
	_reg("GenericScriptNode", "COMP", GenericScriptNode,
		"Multi-output scripting node. @output annotations produce any mix of data types.")

	# ── MATs ────────────────────────────────────────────────────────────
	_reg("NullMAT",         "MAT", NullMAT,
		"Pass-through for organization and references.")
	_reg("PBR_MAT",         "MAT", PBR_MAT,
		"Standard PBR material (StandardMaterial3D) with albedo, metallic, roughness, emission.")
	_reg("Shader_MAT",      "MAT", Shader_MAT,
		"Custom shader material (ShaderMaterial) with code/file input and uniforms.")

	# ── MATs (new) ──────────────────────────────────────────────────────
	_reg("ConstantMAT",     "MAT", ConstantMAT,
		"Flat unlit (constant) material — no lighting applied.")
	_reg("WireframeMAT",    "MAT", WireframeMAT,
		"Wireframe rendering material using spatial wireframe render mode.")
	_reg("PointSpriteMAT",  "MAT", PointSpriteMAT,
		"Point sprite material — renders vertices as sized point sprites.")
	_reg("DepthMAT",        "MAT", DepthMAT,
		"Visualize scene depth as grayscale with near/far controls.")

	# ── MATs: New (TD Gap) ──────────────────────────────────────────────
	_reg("NormalMapMAT",    "MAT", NormalMapMAT,
		"Normal map visualization material with tangent-space normal mapping.")
	_reg("LineMAT",         "MAT", LineMAT,
		"Line/wireframe material with color, width, and stipple controls.")

	# ── TOPs: Panel ─────────────────────────────────────────────────────
	_reg("PanelTOP",        "TOP", PanelTOP,
		"Renders UI widgets into a SubViewport texture with interactive input forwarding.")

	# ── UIs: Widgets ────────────────────────────────────────────────────
	_reg("ButtonUI",        "UI", ButtonUI,
		"Push button widget. Outputs press/release state as CHOP channel.")
	_reg("SliderUI",        "UI", SliderUI,
		"Horizontal or vertical slider. Outputs float value as CHOP channel.")
	_reg("ToggleUI",        "UI", ToggleUI,
		"On/off toggle (CheckButton). Outputs 0 or 1 as CHOP channel.")
	_reg("LabelUI",         "UI", LabelUI,
		"Display-only text label driven by DAT input or expression.")
	_reg("KnobUI",          "UI", KnobUI,
		"Rotary knob widget. Outputs float value as CHOP channel.")
	_reg("XYPadUI",         "UI", XYPadUI,
		"2D XY pad controller. Outputs x and y as CHOP channels.")
	_reg("DropdownUI",      "UI", DropdownUI,
		"Dropdown menu (OptionButton). Outputs selected index as CHOP channel.")
	_reg("ContainerUI",     "UI", ContainerUI,
		"Layout container for nesting and arranging child UI widgets.")

	# ── UIs: Tier 1 — High-Value ───────────────────────────────────────
	_reg("TextureRectUI",   "UI", TextureRectUI,
		"Displays a TOP texture in panel. Optional MAT shader overlay.")
	_reg("ColorRectUI",     "UI", ColorRectUI,
		"Colored rectangle. Clickable with optional MAT shader.")
	_reg("LineEditUI",      "UI", LineEditUI,
		"Single-line text input. Outputs text length and submit state.")
	_reg("TextEditUI",      "UI", TextEditUI,
		"Multi-line text editor. Optional DAT input for initial content.")
	_reg("ProgressBarUI",   "UI", ProgressBarUI,
		"Progress bar driven by CHOP input. Outputs value and ratio.")
	_reg("SpinBoxUI",       "UI", SpinBoxUI,
		"Numeric spin box with increment/decrement buttons.")
	_reg("ColorPickerUI",   "UI", ColorPickerUI,
		"Color picker button. Outputs RGBA channels as CHOP state.")
	_reg("RichTextLabelUI", "UI", RichTextLabelUI,
		"BBCode rich text label. Optional DAT input for content.")

	# ── UIs: Tier 2 — Containers ───────────────────────────────────────
	_reg("ScrollContainerUI", "UI", ScrollContainerUI,
		"Scrollable container for child UI widgets.")
	_reg("TabContainerUI",  "UI", TabContainerUI,
		"Tabbed container. Each UI input becomes a tab page.")
	_reg("SplitContainerUI","UI", SplitContainerUI,
		"Splits two UI inputs with a draggable divider.")
	_reg("MarginContainerUI","UI", MarginContainerUI,
		"Wraps a UI widget with configurable margins.")
	_reg("PanelContainerUI","UI", PanelContainerUI,
		"Styled panel container with background color and rounded corners.")

	# ── UIs: Tier 3 — Data-Driven ──────────────────────────────────────
	_reg("TreeUI",          "UI", TreeUI,
		"Tree view built from DAT table data with parent/child relationships.")
	_reg("ItemListUI",      "UI", ItemListUI,
		"Selectable item list from DAT data. Optional TOP icon texture.")
	_reg("TabBarUI",        "UI", TabBarUI,
		"Tab bar from DAT data. Outputs selected tab index.")
	_reg("MenuButtonUI",    "UI", MenuButtonUI,
		"Button with popup menu items from DAT data.")

	# ── UIs: Tier 4 — Completeness ─────────────────────────────────────
	_reg("CheckBoxUI",      "UI", CheckBoxUI,
		"Standard checkbox with label. Outputs 0/1 toggle state.")
	_reg("TextureButtonUI", "UI", TextureButtonUI,
		"Clickable texture button with normal/pressed/hover TOP inputs.")
	_reg("SeparatorUI",     "UI", SeparatorUI,
		"Horizontal or vertical separator line for layout.")
	_reg("NinePatchRectUI", "UI", NinePatchRectUI,
		"Stretchable nine-patch texture display from TOP input.")
	_reg("LinkButtonUI",    "UI", LinkButtonUI,
		"Clickable text link button with underline options.")
	_reg("TextureProgressBarUI", "UI", TextureProgressBarUI,
		"Textured progress bar with TOP layers and CHOP driver.")

	# ── OUTs: Display ──────────────────────────────────────────────────
	_reg("WindowOUT",       "OUT", WindowOUT,
		"Display a texture in a standalone OS window (VJ output).")

	# ── OUTs: File Save ────────────────────────────────────────────────
	_reg("TextureSaveOUT",  "OUT", TextureSaveOUT,
		"Save GPU texture to disk (PNG, WebP, EXR). GPU→CPU readback + file write.")
	_reg("ImageSaveOUT",    "OUT", ImageSaveOUT,
		"Save CPU Image to disk (PNG, WebP, EXR). Activate toggle to write.")
	_reg("TableSaveOUT",    "OUT", TableSaveOUT,
		"Export table/text to disk (CSV, TSV, JSON, plain text).")

	# ── OUTs: Video ────────────────────────────────────────────────────
	_reg("MovieOUT",        "OUT", MovieOUT,
		"Save image sequence to disk (numbered PNG/WebP frames).")
	_reg("FFmpegOUT",       "OUT", FFmpegOUT,
		"Encode IMG sequence to video via FFmpeg CLI (H.264, H.265, VP9, ProRes).")

	# ── OUTs: Audio / Network ──────────────────────────────────────────
	_reg("AudioDeviceOUT",  "OUT", AudioDeviceOUT,
		"Output CHOP channels to audio device as PCM audio.")
	_reg("RecordOUT",       "OUT", RecordOUT,
		"Record CHOP channels over time to buffer. Save to CSV/JSON.")
	_reg("OscOUT",          "OUT", OscOUT,
		"Send CHOP channels as OSC messages over UDP.")

	# ── POPs: Particle Operators ───────────────────────────────────────
	_reg("NullPOP",        "POP", NullPOP,
		"Pass-through for feedback loops, organization, and references.")
	_reg("SourcePOP",      "POP", SourcePOP,
		"Emit particles from SOP geometry surface or origin point.")
	_reg("ForcePOP",       "POP", ForcePOP,
		"Apply gravity, wind, and directional forces to particles.")
	_reg("TurbulencePOP",  "POP", TurbulencePOP,
		"Curl noise turbulence force field on particles.")
	_reg("CollisionPOP",   "POP", CollisionPOP,
		"Ground plane and bounding box collision for particles.")
	_reg("AttractPOP",     "POP", AttractPOP,
		"Point, line, or geometry attractor/repulsor for particles.")
	_reg("LimitPOP",       "POP", LimitPOP,
		"Kill particles by age, bounds, or speed threshold.")
	_reg("AdvectPOP",      "POP", AdvectPOP,
		"Advect particles by a VOL velocity field.")
	_reg("InstancePOP",    "POP", InstancePOP,
		"Copy SOP geometry onto each particle position as instances.")
	_reg("RenderPOP",      "POP", RenderPOP,
		"Render particle point cloud into a COMP for 3D viewport.")
	_reg("ParticleStateTOP", "TOP", ParticleStateTOP,
		"Visualize POP particle state as a 2D texture (position/velocity/age heatmap).")

	# ── VOLs: Volume Operators ─────────────────────────────────────────
	_reg("NullVOL",        "VOL", NullVOL,
		"Pass-through for organization and references.")
	_reg("NoiseVOL",       "VOL", NoiseVOL,
		"Generate 3D noise density volume (Perlin, Simplex, Cellular).")
	_reg("BlendVOL",       "VOL", BlendVOL,
		"Blend/combine two volumes (add, multiply, max, lerp).")
	_reg("BlurVOL",        "VOL", BlurVOL,
		"3D Gaussian or box blur on a volume.")
	_reg("DisplaceVOL",    "VOL", DisplaceVOL,
		"Warp a density volume by a velocity vector field.")
	_reg("FluidVOL",       "VOL", FluidVOL,
		"Navier-Stokes fluid simulation (advection, pressure, projection).")
	_reg("MarchingCubesVOL", "VOL", MarchingCubesVOL,
		"Extract iso-surface mesh from volume density field (CPU marching cubes).")
	_reg("RaymarchVOL",    "VOL", RaymarchVOL,
		"Render volume as density cloud via GPU raymarching into a TOP texture.")
	_reg("SOPtoVOL",       "VOL", SOPtoVOL,
		"Rasterize SOP mesh into a 3D density volume.")
	_reg("CHOPtoVOL",      "VOL", CHOPtoVOL,
		"Map CHOP channel data into volume slices.")
	_reg("AnalyzeVOL",     "VOL", AnalyzeVOL,
		"Compute min, max, mean, and sum statistics of a volume.")

	GNLogger.info("ExtRegistry",
		"Registered %d core operators" % _operators.size())


## Convenience shorthand for core registration.
func _reg(class_name_key: String, family: String, op_script: GDScript,
		description: String) -> void:
	register_operator(class_name_key, family, op_script, description, "core")


# ═══════════════════════════════════════════════════════════════════════════════
# Custom Asset Scanning (.gnasset)
# ═══════════════════════════════════════════════════════════════════════════════

## Directories scanned for .gnasset files.
const _ASSET_SCAN_DIRS: PackedStringArray = [
	"res://addons/gonodes/assets",
	"res://custom_operators",
	"user://gonodes_assets",
]

## Loaded .gnasset paths (to avoid double-loading).
var _loaded_assets: PackedStringArray = []


## Scans known directories for .gnasset files and registers each as a custom
## operator in the registry.  Assets whose identity block is missing or
## malformed are skipped with a warning.
func scan_custom_assets() -> void:
	var found_count := 0
	for scan_dir in _ASSET_SCAN_DIRS:
		if not DirAccess.dir_exists_absolute(scan_dir):
			continue
		var dir := DirAccess.open(scan_dir)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".gnasset"):
				var full_path := scan_dir.path_join(file_name)
				if not _loaded_assets.has(full_path):
					if _register_custom_asset(full_path):
						found_count += 1
			file_name = dir.get_next()
		dir.list_dir_end()

	if found_count > 0:
		GNLogger.info("ExtRegistry", "Loaded %d custom asset(s)" % found_count)


## Registers a single .gnasset file as a custom operator.
## Returns true on success.
func _register_custom_asset(asset_path: String) -> bool:
	var data := GNCustomOperator._read_asset_json(asset_path)
	if data.is_empty():
		GNLogger.warn("ExtRegistry", "Skipping invalid asset: %s" % asset_path)
		return false

	var identity: Dictionary = data.get("identity", {})
	var op_name: String = identity.get("op_name", "")
	if op_name.is_empty():
		GNLogger.warn("ExtRegistry", "Asset missing op_name: %s" % asset_path)
		return false

	var family_str: String = identity.get("family", "COMP")
	var desc: String = identity.get("description", "Custom operator from .gnasset")

	# Register with the GNCustomOperator script — create_instance will
	# produce a GNCustomOperator, and the caller must call load_from_asset()
	# with the path stored in the entry's extension_dir field.
	register_operator(op_name, family_str, GNCustomOperator,
		desc, "custom_asset", "Custom", asset_path)
	_loaded_assets.append(asset_path)
	GNLogger.info("ExtRegistry", "Registered custom asset '%s' from %s" % [op_name, asset_path])
	return true


## Override create_instance to handle GNCustomOperator specially — it needs
## load_from_asset() called with the asset path.
func create_custom_asset_instance(class_name_key: String) -> GNNode:
	var entry: OperatorEntry = _operators.get(class_name_key, null)
	if entry == null or entry.source != "custom_asset":
		return null
	var node := GNCustomOperator.new()
	if node.load_from_asset(entry.extension_dir):
		return node
	node.free()
	return null
