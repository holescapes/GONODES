# GPU Architecture — Shared RenderingDevice

> **Audience:** Core developers, GPU operator authors.  
> **Status:** Architecture decision — implementation in progress.


## Decision

**One RenderingDevice for all of GONODES**, shared across all operators,
all families, and all patches within the process. This is the **main RD**
obtained via `RenderingServer.get_rendering_device()`.


## Rationale

### Why not local RDs?

The original implementation used `RenderingServer.create_local_rendering_device()`
in `GNGpuContext` and individual operators (GLSLMultiTOP, ComputeShaderTOP).
This created isolated GPU contexts that **cannot share resources** with the
scene renderer, forcing a costly readback path:

```
Local RD (render/compute) → texture_get_data() → CPU RAM → ImageTexture.update() → Main RD (display)
```

This added 3–6 ms per cook per operator (GPU→CPU stall + readback + re-upload).

### Why the main RD?

`RenderingServer.get_rendering_device()` returns the renderer's own
RenderingDevice. Resources created on it **are directly usable** by the
scene renderer:

- `Texture2DRD` wraps an RD texture RID as a scene-usable `Texture2D`
  with **zero readback** — the GPU texture IS the display texture.
- Compute buffers written by POPs can be read by TOPs in the same frame.
- One GPU context = less driver overhead, no memory duplication.

### "But sync() stalls the renderer!"

The cook engine runs in `_process()` on the main thread. The frame cannot
finish rendering until `cook_frame()` returns. Whether we stall a local RD
or the main RD, the frame is blocked either way — there is no parallelism
to lose.

### Isolation trade-off

A rogue shader on the main RD could theoretically corrupt the scene renderer.
This is a debugging concern, not a production one. The benefit of zero-copy
GPU output vastly outweighs this risk.


## Architecture

```
┌─────────────────────────────────────────────────────┐
│           RenderingServer.get_rendering_device()     │
│                    (Main RD — singleton)             │
│                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌────────────┐  │
│  │ GNGpuContext │  │ Scene       │  │ Compositor │  │
│  │ (singleton)  │  │ Renderer    │  │ Effects    │  │
│  │             │  │             │  │            │  │
│  │  POPs ──────┤  │  SubViewport│  │  PostFX    │  │
│  │  VOLs ──────┤  │  TOPs ─────┤  │            │  │
│  │  Compute ───┤  │             │  │            │  │
│  │  GLSLMulti ─┤  │             │  │            │  │
│  └─────────────┘  └─────────────┘  └────────────┘  │
│                                                     │
│  All RIDs visible to all operators — zero-copy      │
└─────────────────────────────────────────────────────┘
```

### GNGpuContext

Process-wide singleton (`GNGpuContext.get_context()`). All GPU operators
obtain their RD reference from here. Provides:

- Shader compilation + caching
- Compute pipeline caching
- SSBO helpers (POP buffers)
- 3D texture pool (VOL ping-pong)
- 2D texture helpers (compute image ops)
- Uniform creation helpers
- Linear sampler creation


### Output Path — Texture2DRD (zero-copy)

GPU operators that produce textures (GLSLMultiTOP, ComputeShaderTOP) wrap
their output RD texture RIDs as `Texture2DRD`:

```gdscript
# Create output texture on the main RD
var tex_rid := rd.texture_create(format, view)

# Wrap as scene-usable Texture2D — zero readback
var tex_2d := Texture2DRD.new()
tex_2d.texture_rd_rid = tex_rid

# Assign to GNTextureData (typed as Texture2D — Texture2DRD is a subclass)
output_data.texture = tex_2d
```

The viewer, preview thumbnails, and downstream TOPs all consume `Texture2D`,
so `Texture2DRD` slots in with no changes to consumers.


### Input Path — texture_get_rd_texture() (zero-copy)

When a GPU operator receives an input texture from ANY upstream TOP
(SubViewport-based, `Texture2DRD`, `ImageTexture`, etc.), it obtains
the RD texture RID directly — no CPU readback, no re-upload:

```gdscript
# ANY Texture2D → RD texture RID (zero-copy, stays on GPU)
var rs_rid := texture.get_rid()
var rd_rid := RenderingServer.texture_get_rd_texture(rs_rid)
```

Since all textures live on the main RD, the RID is directly usable in
uniform sets for shader binding. For unconnected inputs, a 1×1 white
placeholder texture (owned) is used.


### When CPU readback IS needed

Some operators legitimately need CPU-side data:

| Operator | Why readback is needed |
|----------|----------------------|
| POP → SOP bridge | Particle positions feed CPU-side geometry |
| VOL → viewer | Volume slicing for the 3D viewer reads voxels |
| Export/save | Writing textures to disk |

These operators call `rd.texture_get_data()` / `rd.buffer_get_data()`
explicitly. This is fine — it's on-demand, not every frame.


## Migration Checklist

- [x] **GNGpuContext**: Changed `_init_rd()` to use `RenderingServer.get_rendering_device()`. Removed `rd.free()` from `shutdown()`.
- [x] **is_compute_available()**: Now probes `get_rendering_device() != null` instead of creating/freeing a local RD.
- [x] **GLSLMultiTOP**: Uses `GNGpuContext.get_context().rd`. Output textures use `Texture2DRD` (zero readback). Added `SAMPLING_BIT`. Removed `submit()`/`sync()`/`texture_get_data()` readback loop. Removed `_rd.free()`.
- [x] **ComputeShaderTOP**: Same as GLSLMultiTOP — uses shared context, `Texture2DRD` output, no readback.
- [x] **Output texture usage bits**: MRT and compute output textures include `TEXTURE_USAGE_SAMPLING_BIT`.
- [x] **Cleanup**: Operators no longer call `_rd.free()`. Individual RIDs still freed via `free_rid()`.
- [ ] **Compatibility fallback**: If `get_rendering_device()` returns `null` (Compatibility renderer), fall back to SubViewport path (existing fallback code in GLSLMultiTOP).
- [ ] **Viewer panel**: Remove readback path in `gn_viewer_panel.gd` for VOL display if output is already a `Texture2DRD`.

### submit() / sync() policy

| Operator | submit/sync needed? | Why |
|----------|-------------------|-----|
| GLSLMultiTOP | **No** | Output is `Texture2DRD` — scene renderer uses it directly |
| ComputeShaderTOP | **No** | Same — `Texture2DRD` wraps the compute output |
| POP operators | **Yes** | `read_buffer()` after dispatch needs data on CPU (particle positions for physics) |
| VOL operators | **Yes** | `texture_get_data()` after dispatch for volume slicing / marching cubes |
| GNGpuContext.dispatch() | **Yes** | Generic helper used by POPs/VOLs that need immediate readback |


## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Rogue shader corrupts renderer | Validate SPIR-V before creating shader. Log errors, don't crash. |
| Resource leak on main RD | Existing `_cleanup_mrt()` / `_notification(PREDELETE)` logic already frees RIDs. |
| Thread safety | Cook engine is single-threaded (`_process`). No concurrent RD access. |
| Compatibility renderer | `get_rendering_device()` returns `null` → fall back to SubViewport path (already implemented). |


## RD Resource Lifecycle Rules

Sharing the main RD means resources can be invalidated or freed by the
engine outside our control. These rules prevent crashes from stale RIDs.

### Borrowed vs Owned RIDs

| RID type | Owned? | Free it? |
|----------|--------|----------|
| Output textures (MRT color attachments, compute output) | **Yes** | Yes — operator created them |
| Placeholder textures (1×1 white fallback) | **Yes** | Yes — operator created them |
| Uniform sets | **Yes** | Yes — but check validity first (see below) |
| Shaders, pipelines, samplers, framebuffers | **Yes** | Yes — `RID.is_valid()` guard is sufficient |
| Input texture RIDs from `texture_get_rd_texture()` | **No** | **Never** — upstream owns them |

### Uniform Set Auto-Invalidation

When a texture referenced by a uniform set is freed (e.g. upstream resizes
its output), the RD **silently invalidates** the uniform set. Calling
`free_rid()` on an auto-invalidated uniform set crashes (the RID maps to
nothing, or worse, a recycled resource).

**Rule: Always check `rd.uniform_set_is_valid(us)` before `free_rid(us)`.**

```gdscript
# WRONG — crashes if the set was auto-invalidated
if _input_uniform_set.is_valid():
    _rd.free_rid(_input_uniform_set)

# RIGHT
if _input_uniform_set.is_valid() and _rd.uniform_set_is_valid(_input_uniform_set):
    _rd.free_rid(_input_uniform_set)
_input_uniform_set = RID()
```

This applies to every uniform set: input, output, and any created in cleanup paths.

### Texture2DRD: Detach Before Free

`Texture2DRD` internally holds a reference to its `texture_rd_rid`. If you
free the underlying RD texture while the wrapper still references it,
assigning a new RID triggers an internal double-free of the old (dead) RID.

**Rule: Set `texture_rd_rid = RID()` before freeing the RD texture.**

```gdscript
# WRONG — Texture2DRD tries to free the stale RID on next assignment
_rd.free_rid(_output_tex_rid)
_output_tex2d_rd.texture_rd_rid = new_rid   # 💥 double-free

# RIGHT
_output_tex2d_rd.texture_rd_rid = RID()     # detach first
_rd.free_rid(_output_tex_rid)               # now safe
```

### Shutdown / PREDELETE Ordering

During engine exit or patch close, the main RD may tear down resources
before operators get their `NOTIFICATION_PREDELETE`. Cached shaders,
pipelines, and pooled textures may already be gone.

**Rule: Guard every `free_rid()` in shutdown paths with `RID.is_valid()`
(and `uniform_set_is_valid()` for uniform sets).** `GNGpuContext.shutdown()`
follows this pattern for all three caches (shaders, pipelines, texture pool).
