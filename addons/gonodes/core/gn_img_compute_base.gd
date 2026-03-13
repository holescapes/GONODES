class_name GNImgComputeBase
extends GNImgBase
## Base class for GPU-compute-accelerated IMG operators.
##
## Extends GNImgBase with:
##   • Automatic Image ↔ GPU texture upload/download via GNGpuContext
##   • Compute shader compilation and caching
##   • Push-constant dispatch helper
##   • Graceful CPU fallback when compute is unavailable
##
## Subclasses override:
##   _get_shader_path() → String   — path to the .glsl compute shader
##   _cook_cpu(inputs)  → GNData   — CPU fallback when compute is unavailable
##   _dispatch_compute(input_rids, output_rid, width, height) — shader dispatch

# ── GPU State (lazily created, reused across cooks) ──────────────────────────

## Cached input texture RIDs from previous cook — freed on next cook.
var _gpu_input_rids: Array[RID] = []

## Cached output texture RID from previous cook — freed on next cook.
var _gpu_output_rid: RID = RID()

## Cached shader RID (compiled once, reused).
var _shader_rid: RID = RID()

## Previous output resolution (detect resize → recreate textures).
var _prev_width: int = 0
var _prev_height: int = 0


func requires_compute() -> bool:
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# Subclass API — Override These
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the resource path to the .glsl compute shader file.
## Override in subclass.
func _get_shader_path() -> String:
	return ""


## CPU fallback cook — called when GPU compute is not available.
## Override in subclass to provide a CPU implementation.
func _cook_cpu(inputs: Array[GNData]) -> GNData:
	node_warning = "GPU compute unavailable — no CPU fallback"
	return _prepare_image()


## Dispatches the compute shader with input/output texture RIDs.
## Override in subclass to set up uniforms and push constants.
## The base implementation provides a simple 1-input → 1-output dispatch.
func _dispatch_compute(ctx: GNGpuContext, input_rids: Array[RID],
		output_rid: RID, width: int, height: int) -> void:
	pass


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	# Fallback to CPU when compute is unavailable
	if not GNGpuContext.is_compute_available():
		return _cook_cpu(inputs)

	var ctx := GNGpuContext.get_context()
	if ctx.rd == null:
		return _cook_cpu(inputs)

	# Compile shader on first cook
	var shader_path := _get_shader_path()
	if not _shader_rid.is_valid() and not shader_path.is_empty():
		_shader_rid = ctx.get_shader(shader_path)
		if not _shader_rid.is_valid():
			node_error = "Failed to compile compute shader: %s" % shader_path
			return _cook_cpu(inputs)

	# Free previous GPU textures
	_free_gpu_textures(ctx)

	# Upload input images to GPU
	_gpu_input_rids.clear()
	for i in range(inputs.size()):
		var img_data := _get_input_img(inputs, i)
		if img_data != null and img_data.image != null:
			var rid := ctx.upload_image(img_data.image)
			_gpu_input_rids.append(rid)
		else:
			_gpu_input_rids.append(RID())

	# Determine output resolution from first valid input (or parameter)
	var width: int = 0
	var height: int = 0
	for i in range(inputs.size()):
		var img_data := _get_input_img(inputs, i)
		if img_data != null and img_data.image != null:
			width = img_data.image.get_width()
			height = img_data.image.get_height()
			break

	if width == 0 or height == 0:
		return _prepare_image()

	# Create output texture
	_gpu_output_rid = ctx.create_texture_2d(width, height)
	_prev_width = width
	_prev_height = height

	# Dispatch compute shader (subclass implements the details)
	_dispatch_compute(ctx, _gpu_input_rids, _gpu_output_rid, width, height)

	# Download result
	var result_img := ctx.download_image(_gpu_output_rid, width, height)
	var out := _prepare_image()
	if result_img != null:
		out.set_image(result_img)
	else:
		node_warning = "GPU readback failed"

	return out


func _free_gpu_textures(ctx: GNGpuContext) -> void:
	for rid in _gpu_input_rids:
		if rid.is_valid():
			ctx.free_rid(rid)
	_gpu_input_rids.clear()
	if _gpu_output_rid.is_valid():
		ctx.free_rid(_gpu_output_rid)
		_gpu_output_rid = RID()
