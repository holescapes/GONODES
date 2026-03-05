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
# Sub-network types — explicit preload for cold-cache robustness.
const _PreloadSubNetworkNode = preload("res://addons/gonodes/operators/comp/sub_network_node.gd")
const _PreloadInTunnel = preload("res://addons/gonodes/operators/comp/in_tunnel.gd")
const _PreloadOutTunnel = preload("res://addons/gonodes/operators/comp/out_tunnel.gd")## • Extensions live under `res://addons/gn_ext_<name>/` and contain a
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

	func _init(p_family: String, p_script: GDScript, p_desc: String,
			p_source: String = "core", p_section: String = "") -> void:
		family = p_family
		op_script = p_script
		description = p_desc
		source = p_source
		section = p_section


## class_name → OperatorEntry
var _operators: Dictionary = {}

## Loaded extension names (to avoid double-loading).
var _loaded_extensions: PackedStringArray = []


# ═══════════════════════════════════════════════════════════════════════════════
# Registration API
# ═══════════════════════════════════════════════════════════════════════════════

## Register a single operator.  Overwrites any existing entry with the same key.
func register_operator(class_name_key: String, family: String, op_script: GDScript,
		description: String, source: String = "core", section: String = "") -> void:
	_operators[class_name_key] = OperatorEntry.new(family, op_script, description, source, section)
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

		register_operator(op_class, family, loaded_script, desc, ext_name, op_section)
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

	# ── TOPs: 3D Rendering ──────────────────────────────────────────────
	_reg("RenderTOP",       "TOP", RenderTOP,
		"Renders a 3D COMP scene into a 2D texture with integrated post-processing.")

	# ── TOPs: Utility ───────────────────────────────────────────────────
	_reg("NullTOP",         "TOP", NullTOP,
		"Pass-through. Useful for organization and expression references.")
	_reg("SwitchTOP",       "TOP", SwitchTOP,
		"Select one of up to 4 texture inputs by index.")

	# ── TOPs: Output ────────────────────────────────────────────────────
	_reg("WindowTOP",       "TOP", WindowTOP,
		"Display a texture in a standalone OS window (VJ output).")
	_reg("FileSaveTOP",     "TOP", FileSaveTOP,
		"Save GPU texture to disk (PNG, WebP, EXR). GPU→CPU readback + file write.")

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
	_reg("OscOutCHOP",      "CHOP", OscOutCHOP,
		"Send CHOP channels as OSC messages over UDP.")
	_reg("MidiInCHOP",      "CHOP", MidiInCHOP,
		"Receive MIDI note, CC, pitch bend as CHOP channels.")
	_reg("AudioInCHOP",     "CHOP", AudioInCHOP,
		"Capture live microphone audio as CHOP channels.")
	_reg("AudioSpectrumCHOP", "CHOP", AudioSpectrumCHOP,
		"FFT spectrum analysis — frequency bands as CHOP channels.")
	_reg("AudioFileInCHOP", "CHOP", AudioFileInCHOP,
		"Play audio file (WAV/OGG) and output waveform as CHOP channels.")

	# ── CHOPs: Output / Sinks ───────────────────────────────────────────
	_reg("RecordCHOP",      "CHOP", RecordCHOP,
		"Record CHOP channels over time to buffer. Save to CSV/JSON.")

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

	# ── DATs: Output / Sinks ────────────────────────────────────────────
	_reg("FileSaveDAT",     "DAT", FileSaveDAT,
		"Export table/text to disk (CSV, TSV, JSON, plain text).")

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

	# ── IMGs: Bridge ────────────────────────────────────────────────────
	_reg("ImgToTOP",        "IMG", ImgToTOP,
		"Convert IMG (CPU Image) to TOP (GPU Texture). Bridge operator.")
	_reg("TOPtoIMG",        "IMG", TOPtoIMG,
		"Convert TOP (GPU Texture) to IMG (CPU Image). Bridge operator (GPU readback).")

	# ── IMGs: Output / Sinks ────────────────────────────────────────────
	_reg("FileSaveIMG",     "IMG", FileSaveIMG,
		"Save CPU Image to disk (PNG, WebP, EXR). Toggle 'active' to write.")
	_reg("MovieOutIMG",     "IMG", MovieOutIMG,
		"Save image sequence to disk as numbered PNG/WebP frames.")
	_reg("FFmpegOutIMG",    "IMG", FFmpegOutIMG,
		"Encode IMG sequence to video via FFmpeg CLI (H.264, H.265, VP9, ProRes).")

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
	_reg("SubNetworkNode",  "COMP", _PreloadSubNetworkNode,
		"Sub-network — contains a nested node graph with InTunnel/OutTunnel ports.")
	_reg("InTunnel",        "COMP", _PreloadInTunnel,
		"Input tunnel — bridges data from parent sub-network into inner graph.")
	_reg("OutTunnel",       "COMP", _PreloadOutTunnel,
		"Output tunnel — bridges data from inner graph to parent sub-network.")

	# ── MATs ────────────────────────────────────────────────────────────
	_reg("PBR_MAT",         "MAT", PBR_MAT,
		"Standard PBR material (StandardMaterial3D) with albedo, metallic, roughness, emission.")
	_reg("Shader_MAT",      "MAT", Shader_MAT,
		"Custom shader material (ShaderMaterial) with code/file input and uniforms.")

	GNLogger.info("ExtRegistry",
		"Registered %d core operators" % _operators.size())


## Convenience shorthand for core registration.
func _reg(class_name_key: String, family: String, op_script: GDScript,
		description: String) -> void:
	register_operator(class_name_key, family, op_script, description, "core")
