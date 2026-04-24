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
##   platforms = ["windows", "macos", "linux"]  ; OS filter (omit = all)
##   architectures = ["x86_64"]                 ; CPU arch filter (omit = all)
##   renderers = ["forward_plus", "mobile"]     ; renderer filter (omit = all)
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
	var requires_compute: bool  ## True if the operator needs compute shaders
	var requires_renderers: PackedStringArray  ## e.g. ["forward_plus"] — empty = all
	var deprecated: bool                       ## True if the operator is deprecated
	var deprecation_message: String            ## Reason / migration guidance
	var deprecated_replacement: String         ## Class name of the replacement operator
	var is_custom_asset: bool   ## True if this is a .gnasset custom operator
	var asset_read_only: bool   ## True if this asset came from an extension (not user-editable)

	func _init(p_family: String, p_script: GDScript, p_desc: String,
			p_source: String = "core", p_section: String = "",
			p_ext_dir: String = "") -> void:
		family = p_family
		op_script = p_script
		description = p_desc
		source = p_source
		section = p_section
		extension_dir = p_ext_dir
		requires_compute = false
		requires_renderers = PackedStringArray()
		deprecated = false
		deprecation_message = ""
		deprecated_replacement = ""
		is_custom_asset = false
		asset_read_only = false


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
		extension_dir: String = "") -> OperatorEntry:
	var entry := OperatorEntry.new(family, op_script, description, source, section, extension_dir)
	_operators[class_name_key] = entry
	_invalidate_port_cache()
	return entry


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
		# Inject description from manifest so it is the single source of truth.
		if not entry.description.is_empty():
			node.node_description = entry.description
		# Cache deprecation info from the instance onto the registry entry
		if node.deprecated and not entry.deprecated:
			entry.deprecated = true
			entry.deprecation_message = node.deprecation_message
			entry.deprecated_replacement = node.deprecated_replacement
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
## { "TOP": { "": ["NoiseTOP", ...], "Shadertoy": ["ShadertoyTOP", ...] }, ... }
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


## Returns the custom asset registry grouped for the palette:
## { family_name: { section_name: [op_names] } }
## Section names are extension display names or "User" for user-created assets.
## Only includes operators where is_custom_asset == true.
func get_custom_asset_registry() -> Dictionary:
	var result: Dictionary = {}
	for op_name in _operators:
		var entry: OperatorEntry = _operators[op_name]
		if not entry.is_custom_asset:
			continue
		if not result.has(entry.family):
			result[entry.family] = {}
		var sections: Dictionary = result[entry.family]
		# Use section from registration (extension name or "Custom" → rename to "User")
		var sec: String = entry.section if entry.section != "Custom" else "User"
		if not sections.has(sec):
			sections[sec] = []
		sections[sec].append(op_name)
	return result


## Returns true if the named operator is deprecated.
func is_deprecated(class_name_key: String) -> bool:
	var entry: OperatorEntry = _operators.get(class_name_key, null)
	return entry != null and entry.deprecated


## Probes all registered operators for deprecation status by instantiating each
## script once.  Called once at startup so the palette can show deprecation
## styling without the user having to create every node first.
func scan_deprecation() -> void:
	for op_name in _operators:
		var entry: OperatorEntry = _operators[op_name]
		if entry.deprecated or entry.op_script == null:
			continue
		var probe = entry.op_script.new()
		if probe is GNNode and probe.deprecated:
			entry.deprecated = true
			entry.deprecation_message = probe.deprecation_message
			entry.deprecated_replacement = probe.deprecated_replacement
		if probe is Node:
			probe.queue_free()


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
func get_operators_accepting_family(family: int) -> Array[String]:
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
func get_operators_producing_family(family: int) -> Array[String]:
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
# Native GDExtension Activation
# ═══════════════════════════════════════════════════════════════════════════════

## Scans `res://addons/gn_ext_*/` for `.gdextension` and
## `.gdextension.disabled` files at the extension root and in any subdirectory.
## For each one, checks whether the native binary for the current platform
## actually exists.  If it does, ensures the file has the `.gdextension`
## extension (active).  If it doesn't, renames it to `.gdextension.disabled`
## so Godot won't attempt to load it.
##
## `.gdextension` files MUST live at the extension root (not inside `native/`)
## because `native/` has `.gdignore` and Godot won't discover files there.
##
## Call this from the plugin's `_enter_tree()`.  Changes only take effect on
## the *next* Godot restart (because Godot loads GDExtensions at engine init,
## before plugins run).
##
## Returns `true` if any files were renamed (meaning a restart would clear
## errors or pick up newly-compiled libraries).
static func sync_native_extensions() -> bool:
	var addons_path := "res://addons"
	var dir := DirAccess.open(addons_path)
	if dir == null:
		return false

	var changed := false
	var active_gdext_paths: PackedStringArray = []

	dir.list_dir_begin()
	var folder_name := dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and folder_name.begins_with("gn_ext_"):
			var ext_path := addons_path + "/" + folder_name
			# Scan the extension root and all subdirectories for .gdextension files.
			# .gdextension files live at the extension root (outside .gdignore'd
			# native/ dirs) so Godot can auto-discover them.
			if _sync_native_dir(ext_path):
				changed = true
			_collect_active_gdext(ext_path, active_gdext_paths)
		folder_name = dir.get_next()
	dir.list_dir_end()

	# Ensure .godot/extension_list.cfg lists all active .gdextension files.
	# Godot reads this at startup to load GDExtension DLLs; without it,
	# .gdextension files inside .gdignore'd directories are never discovered.
	if _sync_extension_list_cfg(active_gdext_paths):
		changed = true

	if changed:
		print("[ExtRegistry] Native extension files changed — restart Godot to apply.")
	return changed


## Recursively collects paths of active .gdextension files in a directory.
## Skips vendored godot-cpp test directories.
static func _collect_active_gdext(dir_path: String, out: PackedStringArray) -> void:
	var nd := DirAccess.open(dir_path)
	if nd == null:
		return
	nd.list_dir_begin()
	var fname := nd.get_next()
	while fname != "":
		if nd.current_is_dir():
			if fname != "godot-cpp":
				_collect_active_gdext(dir_path + "/" + fname, out)
		elif fname.ends_with(".gdextension"):
			out.append(dir_path + "/" + fname)
		fname = nd.get_next()
	nd.list_dir_end()


## Reads .godot/extension_list.cfg, merges our active paths, writes back if changed.
## Returns true if the file was updated.
static func _sync_extension_list_cfg(active_paths: PackedStringArray) -> bool:
	var cfg_path := "res://.godot/extension_list.cfg"
	var existing: PackedStringArray = []
	if FileAccess.file_exists(cfg_path):
		var fa := FileAccess.open(cfg_path, FileAccess.READ)
		if fa != null:
			while not fa.eof_reached():
				var line := fa.get_line().strip_edges()
				if not line.is_empty():
					existing.append(line)
			fa.close()

	# Merge: keep non-GONODES entries, add our active paths.
	var merged: PackedStringArray = []
	for entry in existing:
		if not entry.contains("/gn_ext_"):
			merged.append(entry)
	for gn_path in active_paths:
		merged.append(gn_path)

	# Sort for stable comparison
	var merged_sorted := Array(merged)
	merged_sorted.sort()
	var existing_sorted := Array(existing)
	existing_sorted.sort()

	if merged_sorted == existing_sorted:
		return false

	var fa := FileAccess.open(cfg_path, FileAccess.WRITE)
	if fa == null:
		return false
	for entry in merged:
		fa.store_line(entry)
	fa.close()
	print("[ExtRegistry] Updated .godot/extension_list.cfg (%d entries)" % merged.size())
	return true


## Recursively scans a directory for `.gdextension` / `.gdextension.disabled`
## files and activates or deactivates them based on whether the library exists.
## Skips vendored godot-cpp test directories.
static func _sync_native_dir(native_dir_path: String) -> bool:
	var nd := DirAccess.open(native_dir_path)
	if nd == null:
		return false

	var changed := false
	nd.list_dir_begin()
	var file_name := nd.get_next()
	while file_name != "":
		if nd.current_is_dir():
			if file_name != "godot-cpp":
				if _sync_native_dir(native_dir_path + "/" + file_name):
					changed = true
		else:
			var is_active := file_name.ends_with(".gdextension")
			var is_disabled := file_name.ends_with(".gdextension.disabled")
			if is_active or is_disabled:
				var full_path := native_dir_path + "/" + file_name
				var has_binary := _gdextension_has_platform_binary(full_path)
				if has_binary and is_disabled:
					# Binary exists — activate
					var new_name := file_name.replace(".gdextension.disabled", ".gdextension")
					var err := nd.rename(file_name, new_name)
					if err == OK:
						print("[ExtRegistry] Activated native extension: %s" % new_name)
						changed = true
				elif not has_binary and is_active:
					# Binary missing — deactivate
					var new_name := file_name + ".disabled"
					var err := nd.rename(file_name, new_name)
					if err == OK:
						print("[ExtRegistry] Deactivated native extension (binary missing): %s → %s" % [file_name, new_name])
						changed = true
		file_name = nd.get_next()
	nd.list_dir_end()
	return changed


## Parses a `.gdextension` (or `.gdextension.disabled`) ConfigFile and checks
## whether the library binary for the current OS + build type + architecture
## exists on disk.  Also verifies any `[dependencies]` entries in the
## `.gdextension` file exist, and checks the companion `gn_extension.cfg` for
## `runtime_dlls` (system DLLs that must be loadable, e.g. NDI SDK runtime).
static func _gdextension_has_platform_binary(gdext_path: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(gdext_path) != OK:
		return false

	# Build platform keys to try, from most specific to least.
	# Godot tries: "<os>.<build>.<arch>" | "<os>.<arch>.<build>" → "<os>.<build>" → "<os>.<arch>" → "<os>"
	var os_name := OS.get_name().to_lower()   # "windows", "linux", "macos"
	var arch := Engine.get_architecture_name() # "x86_64", "arm64", etc.
	var build := "debug" if OS.is_debug_build() else "release"

	var keys_to_try: PackedStringArray = [
		"%s.%s.%s" % [os_name, build, arch],   # windows.debug.x86_64
		"%s.%s.%s" % [os_name, arch, build],   # windows.x86_64.debug  (gdCEF format)
		"%s.%s" % [os_name, build],             # macos.debug
		"%s.%s" % [os_name, arch],              # windows.x86_64
		os_name,                                # linux
	]

	var lib_found := false
	var matched_key := ""
	for key in keys_to_try:
		if cfg.has_section_key("libraries", key):
			var lib_path: String = cfg.get_value("libraries", key, "")
			if not lib_path.is_empty() and FileAccess.file_exists(lib_path):
				lib_found = true
				matched_key = key
				break

	if not lib_found:
		return false

	# Also verify [dependencies] entries exist (co-located DLLs like python312.dll).
	if cfg.has_section("dependencies"):
		for dep_key in keys_to_try:
			if cfg.has_section_key("dependencies", dep_key):
				var deps_val = cfg.get_value("dependencies", dep_key, {})
				if deps_val is Dictionary:
					for dep_path: String in deps_val.keys():
						if not dep_path.is_empty() and not FileAccess.file_exists(dep_path):
							return false
				break

	# Check runtime_dlls from the companion gn_extension.cfg.
	# These are external system DLLs (not bundled) that must be loadable
	# for the extension to work (e.g. NDI SDK runtime, Blackmagic drivers).
	# Example:  runtime_dlls = {"windows": ["Processing.NDI.Lib.x64.dll"]}
	var ext_dir := gdext_path.get_base_dir()
	var ext_cfg_path := ext_dir + "/gn_extension.cfg"
	if FileAccess.file_exists(ext_cfg_path):
		var ext_cfg := ConfigFile.new()
		if ext_cfg.load(ext_cfg_path) == OK:
			var rt_dlls = ext_cfg.get_value("extension", "runtime_dlls", {})
			if rt_dlls is Dictionary and rt_dlls.has(os_name):
				var dll_names: Array = rt_dlls[os_name]
				for dll_name: String in dll_names:
					var output: Array = []
					var exit_code: int
					if os_name == "windows":
						exit_code = OS.execute("where.exe", [dll_name], output)
					else:
						exit_code = OS.execute("which", [dll_name], output)
					if exit_code != 0:
						return false

	return true


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

	# ── Platform check ──
	# If the manifest declares a "platforms" key, skip this extension on non-matching OSes.
	# Values: "windows", "macos", "linux", "android", "ios", "web"
	var platforms: Array = cfg.get_value("extension", "platforms", [])
	if platforms.size() > 0:
		var current_os := OS.get_name().to_lower()
		var matched := false
		for plat in platforms:
			if current_os == str(plat).to_lower():
				matched = true
				break
		if not matched:
			print("[ExtRegistry] Extension '%s' skipped — platform '%s' not in %s" % [ext_name, current_os, str(platforms)])
			_loaded_extensions.append(folder_name)
			return

	# ── Architecture check ──
	# If the manifest declares an "architectures" key, skip on non-matching CPU architectures.
	# Values: "x86_64", "x86_32", "arm64", "arm32", etc. (from Engine.get_architecture_name())
	var architectures: Array = cfg.get_value("extension", "architectures", [])
	if architectures.size() > 0:
		var current_arch := Engine.get_architecture_name()
		var arch_matched := false
		for arch in architectures:
			if current_arch == str(arch).strip_edges():
				arch_matched = true
				break
		if not arch_matched:
			print("[ExtRegistry] Extension '%s' skipped — architecture '%s' not in %s" % [ext_name, current_arch, str(architectures)])
			_loaded_extensions.append(folder_name)
			return

	# ── Renderer check ──
	# If the manifest declares a "renderers" key, skip on non-matching rendering backends.
	# Values: "forward_plus", "mobile", "gl_compatibility"
	var renderers: Array = cfg.get_value("extension", "renderers", [])
	if renderers.size() > 0:
		var current_renderer := GNGpuContext.get_current_renderer()
		var renderer_matched := false
		for r in renderers:
			if current_renderer == str(r).strip_edges():
				renderer_matched = true
				break
		if not renderer_matched:
			print("[ExtRegistry] Extension '%s' skipped — renderer '%s' not in %s" % [ext_name, current_renderer, str(renderers)])
			_loaded_extensions.append(folder_name)
			return

	# ── Dependency check ──
	var deps: Array = cfg.get_value("extension", "dependencies", [])
	for dep_class in deps:
		if not ClassDB.class_exists(dep_class):
			print("[ExtRegistry] Extension '%s' skipped — missing dependency '%s'" % [ext_name, dep_class])
			return

	# ── Any-of dependency check (loads if ANY of the listed classes exist) ──
	var any_deps: Array = cfg.get_value("extension", "dependencies_any", [])
	if any_deps.size() > 0:
		var any_found := false
		for dep_class in any_deps:
			if ClassDB.class_exists(dep_class):
				any_found = true
				break
		if not any_found:
			print("[ExtRegistry] Extension '%s' skipped — none of %s found" % [ext_name, str(any_deps)])
			return

	# ── Register extension families ──
	# Sections named "family.<NAME>" declare custom port types.
	# GNFamily resolves core names to their enum IDs automatically;
	# unknown names get auto-assigned IDs >= 1000.
	for section in cfg.get_sections():
		if not section.begins_with("family."):
			continue
		var fam_name := section.substr("family.".length())
		var color_str: String = cfg.get_value(section, "color", "0.5,0.5,0.5")
		var parts := color_str.split(",")
		var color := Color(parts[0].to_float(), parts[1].to_float(), parts[2].to_float()) if parts.size() >= 3 else Color.WHITE
		var fam_id := GNFamily.register_family(fam_name, color)
		# Register data factory if the extension provides one
		var factory_script: String = cfg.get_value(section, "data_script", "")
		if not factory_script.is_empty() and ResourceLoader.exists(factory_script):
			var fac_scr: GDScript = load(factory_script) as GDScript
			if fac_scr != null:
				GNFamily.register_data_factory(fam_id, func(): return fac_scr.new())
		# Register data renderer if the extension provides one
		var renderer_path: String = cfg.get_value(section, "renderer_script", "")
		if not renderer_path.is_empty() and ResourceLoader.exists(renderer_path):
			var rend_scr: GDScript = load(renderer_path) as GDScript
			if rend_scr != null:
				GNFamily.register_renderer(fam_id, rend_scr.new())
		# Register for @input/@output annotation parsing in script nodes
		GNScriptHelper.register_script_family(fam_name.to_lower(), fam_id)
		# Register expression function name (e.g. "chop", "top", "sdf")
		var expr_func: String = cfg.get_value(section, "expression_func", "")
		if not expr_func.is_empty():
			GNFamily.register_expression_func(expr_func, fam_id)
		print("[ExtRegistry] Registered family '%s' (id=%d)" % [fam_name, fam_id])

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

		var entry := register_operator(op_class, family, loaded_script, desc, ext_name, op_section, ext_dir)

		# Per-operator capability tags
		if entry:
			entry.requires_compute = cfg.get_value(section, "requires_compute", false)
			var op_renderers: Array = cfg.get_value(section, "requires_renderers", [])
			if op_renderers.size() > 0:
				var psa := PackedStringArray()
				for r in op_renderers:
					psa.append(str(r))
				entry.requires_renderers = psa

		registered_count += 1

	_loaded_extensions.append(folder_name)
	print("[ExtRegistry] Loaded extension '%s' (%d operators)" % [ext_name, registered_count])

	# ── Run boot script ──
	# If the manifest declares a "boot_script" key, load and call its boot() method.
	# Boot scripts register extension hooks into core UI registries (viewer display
	# handlers, code editor languages, param row code params, etc.).
	var boot_path: String = cfg.get_value("extension", "boot_script", "")
	if not boot_path.is_empty():
		if ResourceLoader.exists(boot_path):
			var boot_scr: GDScript = load(boot_path) as GDScript
			if boot_scr != null and boot_scr.has_method("boot"):
				boot_scr.boot()
				print("[ExtRegistry] Ran boot script for '%s'" % ext_name)
			else:
				print("[ExtRegistry] Boot script '%s' has no static boot() method" % boot_path)
		else:
			print("[ExtRegistry] Boot script not found: '%s'" % boot_path)


# ═══════════════════════════════════════════════════════════════════════════════
# Core Operator Registration
# ═══════════════════════════════════════════════════════════════════════════════

## Registers all built-in (core) operators from the declarative manifest
## (`gn_core.cfg`).  Uses the same `_load_extension()` path as plugin
## extensions so that per-operator capability tags (requires_compute,
## requires_renderers, platforms, etc.) are handled uniformly.
func _register_core_operators() -> void:
	var cfg_path := "res://addons/gonodes/gn_core.cfg"
	if FileAccess.file_exists(cfg_path):
		_load_extension(cfg_path, "gonodes")
	else:
		GNLogger.error("ExtRegistry", "Core manifest not found: %s" % cfg_path)

	GNLogger.info("ExtRegistry",
		"Registered %d core operators" % _operators.size())




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
##
## Scan order (later overrides earlier on name conflict):
##   1. Extension assets: res://addons/gn_ext_*/assets/*.gnasset (read-only)
##   2. Project assets: res://custom_operators/*.gnasset (editable)
##   3. User-global assets: user://gonodes_assets/*.gnasset (editable)
func scan_custom_assets() -> void:
	var found_count := 0

	# Phase 1: Extension-shipped .gnasset files (read-only)
	found_count += _scan_extension_assets()

	# Phase 2+3: User/project assets (editable)
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
					if _register_custom_asset(full_path, false, "Custom", ""):
						found_count += 1
			file_name = dir.get_next()
		dir.list_dir_end()

	if found_count > 0:
		GNLogger.info("ExtRegistry", "Loaded %d custom asset(s)" % found_count)


## Scans all registered extension directories for assets/*.gnasset files.
## Extension-shipped assets are read-only (can be instantiated but not edited).
## Returns the number of assets found.
func _scan_extension_assets() -> int:
	var count := 0
	var addons_path := "res://addons"
	var dir := DirAccess.open(addons_path)
	if dir == null:
		return 0

	dir.list_dir_begin()
	var folder_name := dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and folder_name.begins_with("gn_ext_"):
			var ext_path := addons_path + "/" + folder_name
			var assets_dir := ext_path + "/assets"
			if DirAccess.dir_exists_absolute(assets_dir):
				# Determine extension display name from cfg
				var cfg_path := ext_path + "/gn_extension.cfg"
				var ext_display_name := folder_name.trim_prefix("gn_ext_").capitalize()
				if FileAccess.file_exists(cfg_path):
					var cfg := ConfigFile.new()
					if cfg.load(cfg_path) == OK:
						ext_display_name = cfg.get_value("extension", "name", ext_display_name)

				var ad := DirAccess.open(assets_dir)
				if ad != null:
					ad.list_dir_begin()
					var f := ad.get_next()
					while f != "":
						if not ad.current_is_dir() and f.ends_with(".gnasset"):
							var full_path := assets_dir + "/" + f
							if not _loaded_assets.has(full_path):
								if _register_custom_asset(full_path, true, ext_display_name, folder_name):
									count += 1
						f = ad.get_next()
					ad.list_dir_end()
		folder_name = dir.get_next()
	dir.list_dir_end()

	if count > 0:
		GNLogger.info("ExtRegistry", "Found %d extension-shipped asset(s)" % count)
	return count


## Registers a single .gnasset file as a custom operator.
## [param p_read_only]: if true, asset came from extension (no edit definition).
## [param p_section]: palette section name (extension display name or "Custom").
## [param p_extension_source]: extension folder name or "" for user assets.
## Returns true on success.
func _register_custom_asset(asset_path: String, p_read_only: bool = false,
		p_section: String = "Custom", p_extension_source: String = "") -> bool:
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
	var source_name: String = "custom_asset" if p_extension_source.is_empty() else p_extension_source
	var entry := register_operator(op_name, family_str, GNCustomOperator,
		desc, "custom_asset", p_section, asset_path)
	entry.is_custom_asset = true
	entry.asset_read_only = p_read_only
	_loaded_assets.append(asset_path)
	GNLogger.info("ExtRegistry", "Registered custom asset '%s' from %s%s" % [
		op_name, asset_path, " (read-only)" if p_read_only else ""])
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
