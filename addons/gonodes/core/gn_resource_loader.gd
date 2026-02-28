class_name GNResourceLoader
extends RefCounted
## Unified resource loading abstraction for GONODES.
##
## Handles three path tiers transparently:
##   Tier 1 — Bundled:  "res://…"  → uses ResourceLoader.load()
##   Tier 2 — Project:  "project://textures/bg.png" → resolved against the project folder
##   Tier 3 — Absolute: "C:/Media/font.ttf"  → loaded from the raw filesystem
##
## Operators call GNResourceLoader methods instead of ResourceLoader.load()
## directly.  The loader picks the right strategy based on path prefix.
##
## Supported resource types and their filesystem loading strategies:
##   • Image/Texture  — Image.load_from_file() → ImageTexture.create_from_image()
##   • Font           — FontFile.new() + load_dynamic_font()
##   • Audio          — FileAccess raw bytes → AudioStreamWAV / AudioStreamOGGVorbis
##   • Shader         — FileAccess.get_as_text() → Shader.new() + set code
##   • Video          — ResourceLoader (Godot-imported only; raw .ogv not loadable)
##
## Thread safety: all methods are stateless and safe to call from any thread.


## Prefix for project-relative paths stored in patch files.
const PROJECT_PREFIX := "project://"


# ═══════════════════════════════════════════════════════════════════════════════
# Path Classification
# ═══════════════════════════════════════════════════════════════════════════════

enum PathTier {
	BUNDLED,   ## res:// — packed into the executable
	PROJECT,   ## project:// — relative to project folder
	ABSOLUTE,  ## Raw filesystem path (C:/… or /home/…)
	EMPTY,     ## No path specified
}


## Classifies a path into its tier.
static func classify(path: String) -> PathTier:
	if path.is_empty():
		return PathTier.EMPTY
	if path.begins_with("res://"):
		return PathTier.BUNDLED
	if path.begins_with(PROJECT_PREFIX):
		return PathTier.PROJECT
	return PathTier.ABSOLUTE


## Resolves a path to an absolute filesystem path.
## [param path]         — the stored path (any tier).
## [param project_dir]  — absolute path to the project folder (Tier 2 root).
## Returns the resolved absolute path, or "" if unresolvable.
static func resolve(path: String, project_dir: String = "") -> String:
	var tier := classify(path)
	match tier:
		PathTier.EMPTY:
			return ""
		PathTier.BUNDLED:
			return path  # res:// paths are used as-is
		PathTier.PROJECT:
			if project_dir.is_empty():
				GNLogger.warn("ResourceLoader",
					"Cannot resolve project:// path without a project directory: %s" % path)
				return ""
			var relative := path.substr(PROJECT_PREFIX.length())
			return project_dir.path_join(relative)
		PathTier.ABSOLUTE:
			return path
	return ""


## Converts an absolute filesystem path to a project-relative path
## if it falls within the project directory.  Otherwise returns the path as-is.
## [param abs_path]     — absolute filesystem path.
## [param project_dir]  — absolute path to the project folder.
static func to_project_relative(abs_path: String, project_dir: String) -> String:
	if project_dir.is_empty() or abs_path.is_empty():
		return abs_path
	# Normalize separators for comparison
	var norm_abs := abs_path.replace("\\", "/")
	var norm_dir := project_dir.replace("\\", "/")
	if not norm_dir.ends_with("/"):
		norm_dir += "/"
	if norm_abs.begins_with(norm_dir):
		return PROJECT_PREFIX + norm_abs.substr(norm_dir.length())
	return abs_path


## Converts a stored path to the best portable representation for saving.
## - res:// paths stay as-is  (Tier 1)
## - Paths inside project_dir become project:// (Tier 2)
## - All other paths stay absolute (Tier 3)
static func to_saveable(abs_path: String, project_dir: String) -> String:
	if abs_path.is_empty() or abs_path.begins_with("res://") or abs_path.begins_with(PROJECT_PREFIX):
		return abs_path
	return to_project_relative(abs_path, project_dir)


# ═══════════════════════════════════════════════════════════════════════════════
# Resource Existence Check
# ═══════════════════════════════════════════════════════════════════════════════

## Checks whether a resource exists at the given path.
static func exists(path: String, project_dir: String = "") -> bool:
	var tier := classify(path)
	match tier:
		PathTier.EMPTY:
			return false
		PathTier.BUNDLED:
			return ResourceLoader.exists(path)
		PathTier.PROJECT, PathTier.ABSOLUTE:
			var resolved := resolve(path, project_dir)
			if resolved.is_empty():
				return false
			return FileAccess.file_exists(resolved)
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# Texture / Image Loading
# ═══════════════════════════════════════════════════════════════════════════════

## Loads a Texture2D from any path tier.
## Returns null on failure.
static func load_texture(path: String, project_dir: String = "") -> Texture2D:
	if path.is_empty():
		return null
	var tier := classify(path)

	# Tier 1: Bundled — use Godot's resource system
	if tier == PathTier.BUNDLED:
		if not ResourceLoader.exists(path):
			return null
		var res := ResourceLoader.load(path)
		if res is Texture2D:
			return res as Texture2D
		if res is Image:
			return ImageTexture.create_from_image(res as Image)
		return null

	# Tier 2/3: Filesystem — use Image.load_from_file()
	var resolved := resolve(path, project_dir)
	if resolved.is_empty() or not FileAccess.file_exists(resolved):
		GNLogger.warn("ResourceLoader", "Texture file not found: %s" % path)
		return null
	var img := Image.new()
	var err := img.load(resolved)
	if err != OK:
		GNLogger.warn("ResourceLoader",
			"Failed to load image '%s' (error %d)" % [path, err])
		return null
	return ImageTexture.create_from_image(img)


## Loads a raw Image (CPU-side) from any path tier.
## Returns null on failure.
static func load_image(path: String, project_dir: String = "") -> Image:
	if path.is_empty():
		return null
	var tier := classify(path)

	if tier == PathTier.BUNDLED:
		if not ResourceLoader.exists(path):
			return null
		var res := ResourceLoader.load(path)
		if res is Image:
			return res as Image
		if res is Texture2D:
			return (res as Texture2D).get_image()
		return null

	var resolved := resolve(path, project_dir)
	if resolved.is_empty() or not FileAccess.file_exists(resolved):
		GNLogger.warn("ResourceLoader", "Image file not found: %s" % path)
		return null
	var img := Image.new()
	var err := img.load(resolved)
	if err != OK:
		GNLogger.warn("ResourceLoader",
			"Failed to load image '%s' (error %d)" % [path, err])
		return null
	return img


# ═══════════════════════════════════════════════════════════════════════════════
# Font Loading
# ═══════════════════════════════════════════════════════════════════════════════

## Loads a Font from any path tier.
## Supports .ttf, .otf, .woff, .woff2 (dynamic) and .tres/.res (Godot resource).
## Returns null on failure.
static func load_font(path: String, project_dir: String = "") -> Font:
	if path.is_empty():
		return null
	var tier := classify(path)

	if tier == PathTier.BUNDLED:
		if not ResourceLoader.exists(path):
			return null
		var res := ResourceLoader.load(path)
		if res is Font:
			return res as Font
		return null

	var resolved := resolve(path, project_dir)
	if resolved.is_empty() or not FileAccess.file_exists(resolved):
		GNLogger.warn("ResourceLoader", "Font file not found: %s" % path)
		return null
	var ext := resolved.get_extension().to_lower()
	if ext in ["ttf", "otf", "woff", "woff2"]:
		var font := FontFile.new()
		var err := font.load_dynamic_font(resolved)
		if err != OK:
			GNLogger.warn("ResourceLoader",
				"Failed to load font '%s' (error %d)" % [path, err])
			return null
		return font
	# .tres / .res — try resource loader with absolute path
	if ext in ["tres", "res"]:
		if ResourceLoader.exists(resolved):
			var res := ResourceLoader.load(resolved)
			if res is Font:
				return res as Font
	GNLogger.warn("ResourceLoader",
		"Unsupported font format: %s" % path)
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Audio Loading
# ═══════════════════════════════════════════════════════════════════════════════

## Loads an AudioStream from any path tier.
## Supports .wav and .ogg files.
## Returns null on failure.
static func load_audio(path: String, project_dir: String = "") -> AudioStream:
	if path.is_empty():
		return null
	var tier := classify(path)

	if tier == PathTier.BUNDLED:
		if not ResourceLoader.exists(path):
			return null
		var res := ResourceLoader.load(path)
		if res is AudioStream:
			return res as AudioStream
		return null

	var resolved := resolve(path, project_dir)
	if resolved.is_empty() or not FileAccess.file_exists(resolved):
		GNLogger.warn("ResourceLoader", "Audio file not found: %s" % path)
		return null
	var ext := resolved.get_extension().to_lower()
	if ext == "ogg":
		var file := FileAccess.open(resolved, FileAccess.READ)
		if file == null:
			return null
		var data := file.get_buffer(file.get_length())
		file.close()
		var stream := AudioStreamOggVorbis.load_from_buffer(data)
		return stream
	if ext == "wav":
		# WAV loading from raw filesystem requires reading bytes and parsing
		# For now, WAV files from the filesystem are loaded via ResourceLoader
		# if they happen to be in a scanned resource path.  Full raw WAV parsing
		# can be added later if needed.
		GNLogger.warn("ResourceLoader",
			"Raw .wav loading from filesystem not yet supported: %s" % path)
		return null
	GNLogger.warn("ResourceLoader",
		"Unsupported audio format: %s" % path)
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Shader Loading
# ═══════════════════════════════════════════════════════════════════════════════

## Loads a Shader from any path tier.
## Returns null on failure.
static func load_shader(path: String, project_dir: String = "") -> Shader:
	if path.is_empty():
		return null
	var tier := classify(path)

	if tier == PathTier.BUNDLED:
		if not ResourceLoader.exists(path):
			return null
		var res := ResourceLoader.load(path)
		if res is Shader:
			return res as Shader
		return null

	var resolved := resolve(path, project_dir)
	if resolved.is_empty() or not FileAccess.file_exists(resolved):
		GNLogger.warn("ResourceLoader", "Shader file not found: %s" % path)
		return null
	var file := FileAccess.open(resolved, FileAccess.READ)
	if file == null:
		return null
	var code := file.get_as_text()
	file.close()
	var shader := Shader.new()
	shader.code = code
	return shader


# ═══════════════════════════════════════════════════════════════════════════════
# Video Loading
# ═══════════════════════════════════════════════════════════════════════════════

## Loads a VideoStream from any path tier.
## Note: Godot's VideoStreamTheora requires imported resources for res://
## paths.  Filesystem .ogv files can be loaded via VideoStreamTheora directly.
## Returns null on failure.
static func load_video(path: String, project_dir: String = "") -> VideoStream:
	if path.is_empty():
		return null
	var tier := classify(path)

	if tier == PathTier.BUNDLED:
		if not ResourceLoader.exists(path):
			return null
		var res := ResourceLoader.load(path)
		if res is VideoStream:
			return res as VideoStream
		return null

	var resolved := resolve(path, project_dir)
	if resolved.is_empty() or not FileAccess.file_exists(resolved):
		GNLogger.warn("ResourceLoader", "Video file not found: %s" % path)
		return null
	# VideoStreamTheora can load from an absolute path via .file property
	var stream := VideoStreamTheora.new()
	stream.file = resolved
	return stream


# ═══════════════════════════════════════════════════════════════════════════════
# Generic / Fallback Loading
# ═══════════════════════════════════════════════════════════════════════════════

## Attempts to load any resource from any path tier.
## For Tier 1, uses ResourceLoader.  For Tier 2/3, tries type-specific
## loaders based on file extension.
## Returns null on failure.
static func load_any(path: String, project_dir: String = "") -> Resource:
	if path.is_empty():
		return null
	var tier := classify(path)

	if tier == PathTier.BUNDLED:
		if not ResourceLoader.exists(path):
			return null
		return ResourceLoader.load(path)

	# For filesystem paths, infer type from extension
	var ext := path.get_extension().to_lower()
	if ext in ["png", "jpg", "jpeg", "webp", "bmp", "tga", "svg", "hdr", "exr"]:
		return load_texture(path, project_dir)
	if ext in ["ttf", "otf", "woff", "woff2"]:
		return load_font(path, project_dir)
	if ext in ["ogg", "wav"]:
		return load_audio(path, project_dir)
	if ext in ["gdshader"]:
		return load_shader(path, project_dir)
	if ext in ["ogv"]:
		return load_video(path, project_dir)

	# Try raw ResourceLoader for .tres / .res
	if ext in ["tres", "res"]:
		var resolved := resolve(path, project_dir)
		if not resolved.is_empty() and ResourceLoader.exists(resolved):
			return ResourceLoader.load(resolved)

	GNLogger.warn("ResourceLoader",
		"Cannot determine loader for '%s'" % path)
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Directory Scanning
# ═══════════════════════════════════════════════════════════════════════════════

## Scans a directory recursively for files matching the given extensions.
## Works for both res:// directories (via DirAccess) and filesystem paths.
## [param dir_path]   — directory to scan (absolute or res://).
## [param extensions] — list of lowercase extensions without dots (e.g. ["png", "jpg"]).
## [param results]    — accumulator array (passed by reference for recursion).
static func scan_directory(dir_path: String, extensions: Array[String],
		results: Array[String] = []) -> Array[String]:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			if file_name != ".godot" and file_name != ".import":
				scan_directory(full_path, extensions, results)
		else:
			if extensions.is_empty():
				results.append(full_path)
			else:
				var ext := file_name.get_extension().to_lower()
				if ext in extensions:
					results.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results
