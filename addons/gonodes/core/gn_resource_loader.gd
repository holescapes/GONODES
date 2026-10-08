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
##   • Image/Texture  — Image.load() → ImageTexture.create_from_image()
##                      Includes PNG/JPG/WebP and KTX/KTX2 (ETC2/DXT/ASTC when
##                      present).  Compressed Image formats upload as GPU-native
##                      blocks on GLES/mobile (e.g. ETC2 on Raspberry Pi).
##   • Font           — FontFile.new() + load_dynamic_font()
##   • Audio          — AudioStreamWAV/Ogg/MP3.load_from_file (filesystem);
##                      8/16-bit PCM WAV only (24-bit/float refused).
##                      Call load_audio from a worker thread for large Memory loads.
##   • Shader         — FileAccess.get_as_text() → Shader.new() + set code
##   • Video          — ResourceLoader (Godot-imported only; raw .ogv not loadable)
##
## Thread safety: all methods are stateless and safe to call from any thread.




## Prefix for project-relative paths stored in patch files.
const PROJECT_PREFIX := "project://"

## Filesystem image extensions handled by [method load_image] / [method load_texture].
## ktx / ktx2 may keep ETC2 (or other VRAM) compression inside Image — do not
## decompress unless you must resize or sample on CPU.
const IMAGE_EXTENSIONS: Array[String] = [
	"png", "jpg", "jpeg", "webp", "bmp", "tga", "svg", "hdr", "exr",
	"ktx", "ktx2",
]




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
			var _ret0 := res as Texture2D
			return _ret0
		if res is Image:
			return ImageTexture.create_from_image(res as Image)
		return null


	# Tier 2/3: Filesystem — Image.load() (PNG/JPG/WebP/KTX2/…)
	var resolved := resolve(path, project_dir)
	if resolved.is_empty() or not FileAccess.file_exists(resolved):
		GNLogger.warn("ResourceLoader", "Texture file not found: %s" % path)
		return null
	var img := _load_image_file(resolved)
	if img == null:
		return null
	# Keep ETC2/DXT/ASTC compressed when present — ImageTexture uploads
	# compressed blocks on GPUs that support the format (GLES/mobile).
	return ImageTexture.create_from_image(img)



## Loads a raw Image (CPU-side) from any path tier.
## KTX/KTX2 may return a still-compressed Image (e.g. FORMAT_ETC2_*).
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
			var _ret0 := res as Image
			return _ret0
		if res is Texture2D:
			return (res as Texture2D).get_image()
		return null


	var resolved := resolve(path, project_dir)
	if resolved.is_empty() or not FileAccess.file_exists(resolved):
		GNLogger.warn("ResourceLoader", "Image file not found: %s" % path)
		return null
	return _load_image_file(resolved)


## Loads an image from an absolute filesystem path via Godot's Image loaders
## (includes libktx for .ktx / .ktx2 when the KTX module is enabled).
static func _load_image_file(absolute_path: String) -> Image:
	var img := Image.new()
	var err := img.load(absolute_path)
	if err != OK:
		GNLogger.warn("ResourceLoader",
			"Failed to load image '%s' (error %d)" % [absolute_path, err])
		return null
	return img


## True when [param img] holds VRAM-compressed texel blocks (ETC2, DXT, ASTC, …).
## These can upload to the GPU without a pixel decode on supporting hardware.
static func is_vram_compressed_image(img: Image) -> bool:
	return img != null and img.is_compressed()


## Ensures [param img] can be resized / CPU-filtered.  Decompresses VRAM-
## compressed formats onto a duplicate when needed.
static func ensure_cpu_editable_image(img: Image) -> Image:
	if img == null:
		return null
	if not img.is_compressed():
		return img
	var copy := img.duplicate() as Image
	var err := copy.decompress()
	if err != OK:
		GNLogger.warn("ResourceLoader",
			"Failed to decompress VRAM image (error %d)" % err)
		return img
	return copy




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
			var _ret0 := res as Font
			return _ret0
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
				var _ret1 := res as Font
				return _ret1
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
			var _ret0 := res as AudioStream
			return _ret0
		return null


	var resolved := resolve(path, project_dir)
	if resolved.is_empty() or not FileAccess.file_exists(resolved):
		GNLogger.warn("ResourceLoader", "Audio file not found: %s" % path)
		return null
	var ext := resolved.get_extension().to_lower()
	if ext == "ogg":
		# Prefer static loaders when available (Godot 4.3+).
		if ClassDB.class_has_method(&"AudioStreamOggVorbis", &"load_from_file"):
			var ogg_file: AudioStream = AudioStreamOggVorbis.load_from_file(resolved)
			if ogg_file != null:
				return ogg_file
		var file := FileAccess.open(resolved, FileAccess.READ)
		if file == null:
			return null
		var data := file.get_buffer(file.get_length())
		file.close()
		return AudioStreamOggVorbis.load_from_buffer(data)
	if ext == "wav":
		return _load_wav_stream(resolved, path)
	if ext == "mp3":
		if ClassDB.class_exists(&"AudioStreamMP3") and ClassDB.class_has_method(&"AudioStreamMP3", &"load_from_file"):
			var mp3_stream: AudioStream = AudioStreamMP3.load_from_file(resolved)
			if mp3_stream != null:
				return mp3_stream
	GNLogger.warn("ResourceLoader",
		"Unsupported audio format: %s" % path)
	return null




## Load a WAV for playback. Godot only plays 8/16-bit PCM natively.
## 24-bit / float / other formats are refused (convert externally to 16-bit WAV or OGG).
static func _load_wav_stream(resolved: String, original_path: String) -> AudioStream:
	var info: Dictionary = _peek_wav_header(resolved)
	if info.is_empty():
		GNLogger.warn("ResourceLoader", "Not a valid WAV: %s" % original_path)
		return null


	var bits: int = int(info.get("bits", 0))
	var fmt: int = int(info.get("format", 0))
	var native_pcm: bool = fmt == 1 and (bits == 8 or bits == 16)


	if not native_pcm:
		GNLogger.warn("ResourceLoader",
			"Unsupported WAV (%d-bit, format %d). Use 8/16-bit PCM WAV or OGG. File: %s" % [
				bits, fmt, original_path])
		return null


	if ClassDB.class_has_method(&"AudioStreamWAV", &"load_from_file"):
		var wav_stream: AudioStreamWAV = AudioStreamWAV.load_from_file(resolved)
		if wav_stream != null and wav_stream.data.size() > 0:
			return wav_stream
	var parsed: AudioStreamWAV = _load_wav_pcm_slice(resolved)
	if parsed != null:
		return parsed


	GNLogger.warn("ResourceLoader", "Failed to load WAV: %s" % original_path)
	return null




## Public WAV layout for disk streaming (header only — does not load PCM).
## Keys: format, channels, sample_rate, bits, data_offset, data_size, resolved.
## Empty Dictionary on failure.
static func peek_wav_layout(path: String, project_dir: String = "") -> Dictionary:
	if path.is_empty():
		return {}
	var resolved := resolve(path, project_dir)
	if resolved.is_empty() or not FileAccess.file_exists(resolved):
		return {}
	var layout := _peek_wav_layout_resolved(resolved)
	if not layout.is_empty():
		layout["resolved"] = resolved
	return layout




## True when layout is 8/16-bit PCM (disk-streamable + Godot-native).
static func wav_layout_is_streamable(layout: Dictionary) -> bool:
	if layout.is_empty():
		return false
	var fmt: int = int(layout.get("format", 0))
	var bits: int = int(layout.get("bits", 0))
	return fmt == 1 and (bits == 8 or bits == 16) and int(layout.get("data_size", 0)) > 0




## Read fmt chunk only (does not load the audio payload).
static func _peek_wav_header(resolved_path: String) -> Dictionary:
	var layout := _peek_wav_layout_resolved(resolved_path)
	if layout.is_empty():
		return {}
	return {
		"format": layout.get("format", 0),
		"channels": layout.get("channels", 1),
		"sample_rate": layout.get("sample_rate", 44100),
		"bits": layout.get("bits", 16),
	}




## Walk RIFF chunks for fmt + data offsets without reading the PCM body.
static func _peek_wav_layout_resolved(resolved_path: String) -> Dictionary:
	var file := FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		return {}
	var file_len: int = file.get_length()
	if file_len < 44:
		file.close()
		return {}
	var riff: PackedByteArray = file.get_buffer(12)
	if riff.size() < 12 \
			or riff.slice(0, 4).get_string_from_ascii() != "RIFF" \
			or riff.slice(8, 12).get_string_from_ascii() != "WAVE":
		file.close()
		return {}


	var fmt_info: Dictionary = {}
	var data_offset: int = -1
	var data_size: int = 0
	var offset: int = 12
	while offset + 8 <= file_len:
		file.seek(offset)
		var chunk_hdr: PackedByteArray = file.get_buffer(8)
		if chunk_hdr.size() < 8:
			break
		var chunk_id: String = chunk_hdr.slice(0, 4).get_string_from_ascii()
		var chunk_size: int = chunk_hdr.decode_u32(4)
		var chunk_data: int = offset + 8
		if chunk_id == "fmt ":
			file.seek(chunk_data)
			var fmt_bytes: PackedByteArray = file.get_buffer(mini(chunk_size, 64))
			fmt_info = _parse_wav_fmt(fmt_bytes)
		elif chunk_id == "data":
			data_offset = chunk_data
			data_size = mini(chunk_size, file_len - chunk_data)
			break
		offset = chunk_data + chunk_size + (chunk_size & 1)


	file.close()
	if fmt_info.is_empty() or data_offset < 0 or data_size <= 0:
		return {}
	fmt_info["data_offset"] = data_offset
	fmt_info["data_size"] = data_size
	return fmt_info




static func _parse_wav_fmt(fmt: PackedByteArray) -> Dictionary:
	if fmt.size() < 16:
		return {}
	var audio_format: int = fmt.decode_u16(0)
	var channels: int = fmt.decode_u16(2)
	var sample_rate: int = fmt.decode_u32(4)
	var bits_per_sample: int = fmt.decode_u16(14)
	if audio_format == 0xFFFE and fmt.size() >= 40:
		audio_format = fmt.decode_u16(24)
	return {
		"format": audio_format,
		"channels": channels,
		"sample_rate": sample_rate,
		"bits": bits_per_sample,
	}




## Fast path for already-playable 8/16-bit PCM (no per-sample loops).
static func _load_wav_pcm_slice(resolved_path: String) -> AudioStreamWAV:
	var file := FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		return null
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	if bytes.size() < 44:
		return null


	var offset: int = 12
	var audio_format: int = 1
	var channels: int = 1
	var sample_rate: int = 44100
	var bits_per_sample: int = 16
	var data_offset: int = -1
	var data_size: int = 0


	while offset + 8 <= bytes.size():
		var chunk_id: String = bytes.slice(offset, offset + 4).get_string_from_ascii()
		var chunk_size: int = bytes.decode_u32(offset + 4)
		var chunk_data: int = offset + 8
		if chunk_id == "fmt ":
			if chunk_data + 16 > bytes.size():
				return null
			audio_format = bytes.decode_u16(chunk_data)
			channels = bytes.decode_u16(chunk_data + 2)
			sample_rate = bytes.decode_u32(chunk_data + 4)
			bits_per_sample = bytes.decode_u16(chunk_data + 14)
		elif chunk_id == "data":
			data_offset = chunk_data
			data_size = mini(chunk_size, bytes.size() - chunk_data)
			break
		offset = chunk_data + chunk_size + (chunk_size & 1)


	if data_offset < 0 or data_size <= 0:
		return null
	if audio_format != 1 or bits_per_sample not in [8, 16]:
		return null


	var stream := AudioStreamWAV.new()
	stream.format = (
		AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16
		else AudioStreamWAV.FORMAT_8_BITS)
	stream.mix_rate = sample_rate
	stream.stereo = channels >= 2
	stream.data = bytes.slice(data_offset, data_offset + data_size)
	return stream




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
			var _ret0 := res as Shader
			return _ret0
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
			var _ret0 := res as VideoStream
			return _ret0
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
	if ext in IMAGE_EXTENSIONS:
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
