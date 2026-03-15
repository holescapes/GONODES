class_name GNGpuContext
extends RefCounted
## Singleton providing a shared RenderingDevice for all GPU-compute operators
## (POP and VOL families).  Manages shader compilation, pipeline caching,
## and a 3D texture pool for ping-pong VOL operations.
##
## Usage:
##   var ctx := GNGpuContext.get_context()
##   var rd := ctx.rd                # shared RenderingDevice

# ═══════════════════════════════════════════════════════════════════════════════
# Singleton
# ═══════════════════════════════════════════════════════════════════════════════

static var _instance: GNGpuContext = null


static func get_context() -> GNGpuContext:
	if _instance == null:
		_instance = GNGpuContext.new()
		_instance._init_rd()
	return _instance


# ═══════════════════════════════════════════════════════════════════════════════
# State
# ═══════════════════════════════════════════════════════════════════════════════

## The shared local RenderingDevice.  All POP/VOL operators use this.
var rd: RenderingDevice = null

## Compiled shader cache: shader_source_path → RID
var _shader_cache: Dictionary = {}

## Compute pipeline cache: shader_rid → RID
var _pipeline_cache: Dictionary = {}

## 3D texture pool for VOL ping-pong: key = "WxHxD:format" → Array[RID]
var _texture_pool: Dictionary = {}


# ═══════════════════════════════════════════════════════════════════════════════
# Initialisation
# ═══════════════════════════════════════════════════════════════════════════════

## Returns true if the current renderer supports compute shaders.
## Forward+ and Mobile renderers provide a RenderingDevice; Compatibility does not.
## Cached after first call — the renderer cannot change at runtime.
static var _compute_available: int = -1  # -1 = unchecked, 0 = no, 1 = yes

static func is_compute_available() -> bool:
	if _compute_available < 0:
		var rd := RenderingServer.create_local_rendering_device()
		if rd != null:
			_compute_available = 1
			rd.free()
		else:
			_compute_available = 0
	return _compute_available == 1


## Returns the active rendering method as a string.
## Possible values: "forward_plus", "mobile", "gl_compatibility".
## Cached after first call — the renderer cannot change at runtime.
static var _current_renderer: String = ""

static func get_current_renderer() -> String:
	if _current_renderer.is_empty():
		_current_renderer = str(
			ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")
		).strip_edges()
		# Normalize — Godot stores "forward_plus", "mobile", or "gl_compatibility".
		if _current_renderer.is_empty():
			_current_renderer = "forward_plus"
	return _current_renderer


## Returns the current platform as a lowercase string.
## Possible values: "windows", "macos", "linux", "android", "ios", "web".
## Cached after first call — the platform cannot change at runtime.
static var _current_platform: String = ""

static func get_current_platform() -> String:
	if _current_platform.is_empty():
		_current_platform = OS.get_name().to_lower()
	return _current_platform


func _init_rd() -> void:
	rd = RenderingServer.create_local_rendering_device()
	if rd == null:
		push_error("GNGpuContext: Failed to create local RenderingDevice — GPU compute unavailable")


# ═══════════════════════════════════════════════════════════════════════════════
# Shader Compilation
# ═══════════════════════════════════════════════════════════════════════════════

## Loads and compiles a GLSL compute shader from the given resource path.
## Returns the compiled shader RID (cached on repeat calls).
## Uses the Godot import pipeline first; falls back to direct compilation
## from raw GLSL text if the import cache is stale or missing.
func get_shader(glsl_path: String) -> RID:
	if glsl_path in _shader_cache:
		return _shader_cache[glsl_path]
	if rd == null:
		return RID()

	# --- Try the Godot import pipeline first ---
	var spirv: RDShaderSPIRV = null
	var shader_file := load(glsl_path) as RDShaderFile
	if shader_file != null and "" in shader_file.get_version_list():
		spirv = shader_file.get_spirv()

	# --- Fallback: compile directly from raw GLSL text ---
	if spirv == null:
		spirv = _compile_glsl_from_text(glsl_path)
	if spirv == null:
		push_error("GNGpuContext: Failed to compile shader '%s'" % glsl_path)
		return RID()

	var err_msg: String = spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
	if err_msg != "":
		push_error("GNGpuContext: Shader compile error in '%s': %s" % [glsl_path, err_msg])
		return RID()
	var shader_rid: RID = rd.shader_create_from_spirv(spirv)
	_shader_cache[glsl_path] = shader_rid
	return shader_rid


## Reads a .glsl file as raw text, strips the [compute] section header,
## and compiles it directly via RenderingDevice — bypasses the import cache.
func _compile_glsl_from_text(glsl_path: String) -> RDShaderSPIRV:
	var raw := FileAccess.get_file_as_string(glsl_path)
	if raw.is_empty():
		push_error("GNGpuContext: Cannot read shader file '%s'" % glsl_path)
		return null
	# Strip the [compute] section header — keep everything from #version onward.
	var ver_pos := raw.find("#version")
	if ver_pos < 0:
		push_error("GNGpuContext: No #version directive in '%s'" % glsl_path)
		return null
	var glsl_code := raw.substr(ver_pos)
	var src := RDShaderSource.new()
	src.source_compute = glsl_code
	return rd.shader_compile_spirv_from_source(src)


## Returns a cached compute pipeline for the given shader RID.
func get_pipeline(shader_rid: RID) -> RID:
	if shader_rid in _pipeline_cache:
		return _pipeline_cache[shader_rid]
	if rd == null:
		return RID()
	var pipeline: RID = rd.compute_pipeline_create(shader_rid)
	_pipeline_cache[shader_rid] = pipeline
	return pipeline


# ═══════════════════════════════════════════════════════════════════════════════
# SSBO Helpers (POP)
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a storage buffer of [param byte_size] bytes.
func create_buffer(byte_size: int) -> RID:
	if rd == null:
		return RID()
	var data := PackedByteArray()
	data.resize(byte_size)
	data.fill(0)
	return rd.storage_buffer_create(byte_size, data)


## Reads back [param byte_size] bytes from a storage buffer.
func read_buffer(buffer_rid: RID, byte_size: int) -> PackedByteArray:
	if rd == null:
		return PackedByteArray()
	return rd.buffer_get_data(buffer_rid, 0, byte_size)


## Frees a GPU resource (buffer or texture).
func free_rid(rid: RID) -> void:
	if rd != null and rid.is_valid():
		rd.free_rid(rid)


# ═══════════════════════════════════════════════════════════════════════════════
# 3D Texture Helpers (VOL)
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a 3D texture with the given resolution and format.
## [param data_format] — RenderingDevice.DATA_FORMAT_* constant.
func create_texture_3d(resolution: Vector3i,
		data_format: int = RenderingDevice.DATA_FORMAT_R32_SFLOAT) -> RID:
	if rd == null:
		return RID()
	var fmt := RDTextureFormat.new()
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	fmt.width = resolution.x
	fmt.height = resolution.y
	fmt.depth = resolution.z
	fmt.format = data_format
	fmt.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	)
	fmt.mipmaps = 1
	return rd.texture_create(fmt, RDTextureView.new())


## Acquires a pooled 3D texture of matching resolution/format.
## Returns a recycled texture or creates a new one.
func acquire_texture_3d(resolution: Vector3i,
		data_format: int = RenderingDevice.DATA_FORMAT_R32_SFLOAT) -> RID:
	var key := "%dx%dx%d:%d" % [resolution.x, resolution.y, resolution.z, data_format]
	if key in _texture_pool:
		var pool: Array = _texture_pool[key]
		if pool.size() > 0:
			return pool.pop_back()
	return create_texture_3d(resolution, data_format)


## Returns a 3D texture to the pool for reuse.
func release_texture_3d(rid: RID, resolution: Vector3i,
		data_format: int = RenderingDevice.DATA_FORMAT_R32_SFLOAT) -> void:
	var key := "%dx%dx%d:%d" % [resolution.x, resolution.y, resolution.z, data_format]
	if key not in _texture_pool:
		_texture_pool[key] = []
	_texture_pool[key].append(rid)


# ═══════════════════════════════════════════════════════════════════════════════
# Uniform Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Creates an RDUniform for a storage buffer at [param binding].
func uniform_buffer(binding: int, buffer_rid: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = binding
	u.add_id(buffer_rid)
	return u


## Creates an RDUniform for a storage image (read/write texture) at [param binding].
func uniform_image(binding: int, texture_rid: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(texture_rid)
	return u


## Creates an RDUniform for a sampler + texture at [param binding].
func uniform_sampler(binding: int, sampler_rid: RID, texture_rid: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(sampler_rid)
	u.add_id(texture_rid)
	return u


## Creates a default linear sampler.
func create_linear_sampler() -> RID:
	if rd == null:
		return RID()
	var ss := RDSamplerState.new()
	ss.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss.mip_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	ss.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	ss.repeat_w = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	return rd.sampler_create(ss)


# ═══════════════════════════════════════════════════════════════════════════════
# 2D Texture Helpers (IMG compute)
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a 2D storage texture for compute shaders (RGBA8).
func create_texture_2d(width: int, height: int,
		data_format: int = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM) -> RID:
	if rd == null:
		return RID()
	var fmt := RDTextureFormat.new()
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	fmt.width = width
	fmt.height = height
	fmt.depth = 1
	fmt.format = data_format
	fmt.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	)
	fmt.mipmaps = 1
	return rd.texture_create(fmt, RDTextureView.new())


## Uploads a Godot Image into a GPU storage texture. Returns the texture RID.
## Creates a new texture each time — caller is responsible for freeing old ones.
func upload_image(image: Image) -> RID:
	if rd == null or image == null:
		return RID()
	# Ensure RGBA8 format for consistent compute shader access
	var img := image
	if img.get_format() != Image.FORMAT_RGBA8:
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)
	var tex_rid := create_texture_2d(img.get_width(), img.get_height())
	if not tex_rid.is_valid():
		return RID()
	rd.texture_update(tex_rid, 0, img.get_data())
	return tex_rid


## Downloads a GPU storage texture back to a Godot Image (RGBA8).
func download_image(tex_rid: RID, width: int, height: int) -> Image:
	if rd == null or not tex_rid.is_valid():
		return null
	var data: PackedByteArray = rd.texture_get_data(tex_rid, 0)
	if data.is_empty():
		return null
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)


# ═══════════════════════════════════════════════════════════════════════════════
# Dispatch Helper
# ═══════════════════════════════════════════════════════════════════════════════

## Dispatches a compute shader with the given uniform set and workgroup counts.
func dispatch(shader_rid: RID, uniform_set: RID,
		groups_x: int, groups_y: int = 1, groups_z: int = 1,
		push_constants: PackedByteArray = PackedByteArray()) -> void:
	if rd == null:
		return
	var pipeline: RID = get_pipeline(shader_rid)
	var compute_list: int = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	if push_constants.size() > 0:
		rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
	rd.compute_list_dispatch(compute_list, groups_x, groups_y, groups_z)
	rd.compute_list_end()
	rd.submit()
	rd.sync()


# ═══════════════════════════════════════════════════════════════════════════════
# Shutdown
# ═══════════════════════════════════════════════════════════════════════════════

## Frees all cached shaders, pipelines, and pooled textures.
## Call before application exit.
func shutdown() -> void:
	if rd == null:
		return
	for key in _shader_cache:
		rd.free_rid(_shader_cache[key])
	_shader_cache.clear()
	for key in _pipeline_cache:
		rd.free_rid(_pipeline_cache[key])
	_pipeline_cache.clear()
	for key in _texture_pool:
		for rid in _texture_pool[key]:
			rd.free_rid(rid)
	_texture_pool.clear()
	rd.free()
	rd = null
	_instance = null
