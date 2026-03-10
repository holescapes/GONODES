class_name CompositorEffectTOP
extends RenderTOP
## Renders a 3D COMP scene and applies a pipeline-level CompositorEffect.
##
## Extends RenderTOP: all scene management (geometry, camera, lights,
## environment, shadows, DOF) works identically.  On top of the normal
## colour output a CompositorEffect is attached to the SubViewport's
## Compositor resource, providing access to the raw depth buffer via
## Godot's RenderingDevice API.
##
## Built-in effects:
##   0  Outline     — Sobel edge-detection on the depth buffer, blends an
##                    outline colour over geometry silhouettes and creases.
##   1  Depth Fog   — depth-based exponential fog overlay.
##   2  Depth View  — replaces colour with a greyscale depth visualisation.
##
## Requires Godot 4.3+ (CompositorEffect API).

# ─── Outline compute shader (GLSL 450) ────────────────────────────────────────
## The shader reads the depth buffer via a sampler, runs a 3×3 Sobel filter,
## and blends the outline colour into the colour storage image.
const _EFFECT_GLSL := \
"""#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Colour buffer — storage image (rgba16f in Forward+).
layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

// Depth buffer — sampled (D32_SFLOAT, read as .r component).
layout(set = 1, binding = 0) uniform sampler2D depth_sampler;

// Push constants — all float for straightforward byte packing.
// mode_f: 0=outline  1=depth_fog  2=depth_view
layout(push_constant, std430) uniform Params {
    float threshold;
    float strength;
    float r; float g; float b; float a;
    float mode_f;
    float _pad;
} pc;

void main() {
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size   = imageSize(color_image);
    if (coords.x >= size.x || coords.y >= size.y) return;

    vec2 texel = 1.0 / vec2(size);
    vec2 uv    = (vec2(coords) + 0.5) * texel;
    int  mode  = int(pc.mode_f);

    if (mode == 0) {
        // ─── Outline from depth Sobel ──────────────────────────────────
        // 3x3 neighbourhood samples (row-major, top-left = d[0]).
        float d[9];
        for (int row = 0; row < 3; row++)
            for (int col = 0; col < 3; col++)
                d[row * 3 + col] = texture(depth_sampler,
                    uv + vec2(float(col - 1), float(row - 1)) * texel).r;

        float sx = -d[0] - 2.0*d[3] - d[6] + d[2] + 2.0*d[5] + d[8];
        float sy = -d[0] - 2.0*d[1] - d[2] + d[6] + 2.0*d[7] + d[8];
        float edge  = sqrt(sx*sx + sy*sy);
        float alpha = smoothstep(pc.threshold * 0.5, pc.threshold, edge) * pc.strength;

        vec4 col = imageLoad(color_image, coords);
        col.rgb  = mix(col.rgb, vec3(pc.r, pc.g, pc.b), alpha * pc.a);
        imageStore(color_image, coords, col);

    } else if (mode == 1) {
        // ─── Depth fog ─────────────────────────────────────────────────
        // Godot Forward+ uses reverse-Z (1=near, 0=far).  Squaring biases
        // the fog to distant surfaces.
        float depth  = 1.0 - texture(depth_sampler, uv).r;
        float factor = clamp(pow(depth, 2.0) * pc.strength, 0.0, 1.0);
        vec4 col = imageLoad(color_image, coords);
        col.rgb  = mix(col.rgb, vec3(pc.r, pc.g, pc.b), factor * pc.a);
        imageStore(color_image, coords, col);

    } else {
        // ─── Depth greyscale view ───────────────────────────────────────
        float d = texture(depth_sampler, uv).r;
        imageStore(color_image, coords, vec4(d, d, d, 1.0));
    }
}
"""


# ─── Inner CompositorEffect class ─────────────────────────────────────────────

## Manages the RenderingDevice lifetime for the depth-aware compute shader.
class _GNCompositorEffect extends CompositorEffect:
	## Public parameters — updated each cook frame by the outer operator.
	var mode: int         = 0
	var threshold: float  = 0.1
	var strength: float   = 1.0
	var effect_color: Color = Color.BLACK

	## RD handles — created lazily on first callback.
	var _rd: RenderingDevice     = null
	var _shader_rid: RID         = RID()
	var _pipeline_rid: RID       = RID()
	var _sampler_rid: RID        = RID()

	func _init() -> void:
		effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
		access_resolved_color = true
		access_resolved_depth = true


	func _render_callback(p_type: int, p_data: RenderData) -> void:
		if p_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
			return

		var scene_bufs: RenderSceneBuffersRD = \
			p_data.get_render_scene_buffers() as RenderSceneBuffersRD
		if scene_bufs == null:
			return

		var size: Vector2i = scene_bufs.get_internal_size()
		if size.x == 0 or size.y == 0:
			return

		if _rd == null:
			_rd = RenderingServer.get_rendering_device()

		_ensure_pipeline()

		var color_tex: RID = scene_bufs.get_color_layer(0)
		var depth_tex: RID = scene_bufs.get_depth_layer(0)
		if not color_tex.is_valid() or not depth_tex.is_valid():
			return

		# ── Uniform set 0: colour storage image ───────────────────────
		var u_color := RDUniform.new()
		u_color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u_color.binding      = 0
		u_color.add_id(color_tex)
		var set0: RID = _rd.uniform_set_create([u_color], _shader_rid, 0)

		# ── Uniform set 1: depth combined sampler ─────────────────────
		var u_depth := RDUniform.new()
		u_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u_depth.binding      = 0
		u_depth.add_id(_sampler_rid)
		u_depth.add_id(depth_tex)
		var set1: RID = _rd.uniform_set_create([u_depth], _shader_rid, 1)

		if not set0.is_valid() or not set1.is_valid():
			return

		# ── Push constants (8 × float32 = 32 bytes) ───────────────────
		var pc := PackedFloat32Array([
			threshold,
			strength,
			effect_color.r,
			effect_color.g,
			effect_color.b,
			effect_color.a,
			float(mode),
			0.0  # pad
		])
		var pc_bytes: PackedByteArray = pc.to_byte_array()

		# ── Dispatch ──────────────────────────────────────────────────
		var cl: int = _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(cl, _pipeline_rid)
		_rd.compute_list_bind_uniform_set(cl, set0, 0)
		_rd.compute_list_bind_uniform_set(cl, set1, 1)
		_rd.compute_list_set_push_constant(cl, pc_bytes, pc_bytes.size())
		_rd.compute_list_dispatch(cl,
			ceili(size.x / 8.0),
			ceili(size.y / 8.0), 1)
		_rd.compute_list_end()


	## Lazily compile and cache the compute pipeline.
	func _ensure_pipeline() -> void:
		if _pipeline_rid.is_valid():
			return
		if _rd == null:
			return

		# Compile shader
		var src := RDShaderSource.new()
		src.source_compute = CompositorEffectTOP._EFFECT_GLSL
		var spirv: RDShaderSPIRV = _rd.shader_compile_spirv_from_source(src)
		if not spirv.compile_error_compute.is_empty():
			push_error("CompositorEffectTOP shader error: %s" % spirv.compile_error_compute)
			return

		_shader_rid   = _rd.shader_create_from_spirv(spirv)
		_pipeline_rid = _rd.compute_pipeline_create(_shader_rid)

		# Create a linear sampler for the depth texture.
		var ss := RDSamplerState.new()
		ss.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		ss.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		ss.address_mode_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		ss.address_mode_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		_sampler_rid = _rd.sampler_create(ss)


	## Free all RD resources when the effect is destroyed.
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			if _rd != null:
				if _sampler_rid.is_valid():
					_rd.free_rid(_sampler_rid)
				if _pipeline_rid.is_valid():
					_rd.free_rid(_pipeline_rid)
				if _shader_rid.is_valid():
					_rd.free_rid(_shader_rid)


# ─── CompositorEffectTOP outer class ──────────────────────────────────────────

var _effect: _GNCompositorEffect = null
var _compositor: Compositor      = null


func _init() -> void:
	super._init()
	node_type        = "compositor_effect"
	node_description = "Render 3D scene with pipeline-level compositor effect (outline, fog, depth view). Requires Godot 4.3+."


func _init_parameters() -> void:
	super._init_parameters()  # all RenderTOP params first
	# ── Effect parameters appended after RenderTOP's params ───────────
	add_parameter(GNParameter.create_enum("effect_mode",
		PackedStringArray(["Outline", "Depth Fog", "Depth View"]),
		0, "Effect Mode",
		"Outline = depth Sobel silhouette · Fog = depth-based fog · Depth View = greyscale depth buffer"))
	add_parameter(GNParameter.create_float("effect_threshold", 0.08, 0.001, 1.0, 0.005,
		"Effect Threshold",
		"Sobel magnitude threshold (Outline) — lower = more edges detected"))
	add_parameter(GNParameter.create_float("effect_strength", 1.0, 0.0, 4.0, 0.05,
		"Effect Strength", "Overall effect intensity"))
	add_parameter(GNParameter.create_color("effect_color", Color.BLACK,
		"Effect Color", "Outline / fog tint colour (alpha controls blend weight)"))


func _cook(inputs: Array[GNData]) -> GNData:
	# Render the scene via RenderTOP base (creates viewport + populates scene).
	var result: GNData = super._cook(inputs)

	# Attach the compositor to the viewport on first cook.
	_setup_compositor_effect()

	# Push current parameter values to the effect object.
	# The effect reads these in its next _render_callback invocation.
	if _effect != null:
		_effect.mode         = get_param_value("effect_mode")
		_effect.threshold    = get_param_value("effect_threshold")
		_effect.strength     = get_param_value("effect_strength")
		_effect.effect_color = get_param_value("effect_color")

	return result


## Lazily creates the Compositor resource and attaches the effect.
## Called after super._cook() so _viewport is guaranteed to exist.
func _setup_compositor_effect() -> void:
	if _compositor != null or _viewport == null:
		return
	_effect     = _GNCompositorEffect.new()
	_compositor = Compositor.new()
	_compositor.effects.append(_effect)
	_viewport.compositor = _compositor


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _effect != null:
			_effect = null
		_compositor = null
