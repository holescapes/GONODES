# GPU Architecture — Unified Single-Device Model

> **Audience:** Core developers, GPU operator authors.  
> **Status:** Implemented — unified single device (June 2026).
> Previously used a two-device split (April–June 2026); see git history.


## Decision

**One RenderingDevice in GNGpuContext:**

- **`rd`** — the renderer's own device from
  `RenderingServer.get_rendering_device()`. All operators (TOP, POP, VOL)
  dispatch compute shaders and create textures on this single device.
  `main_rd` is kept as an alias for backward compatibility.


## Rationale

### Why a single device?

POP and VOL operators never call `submit()`/`sync()` — they dispatch
compute shaders and pass GPU RIDs (buffers, 3D textures) downstream.
The only synchronization points are GPU-side pipeline barriers, which the
renderer's own device handles automatically.

With all data on the renderer's device:

- **Zero-copy** between all families: TOP→VOL, POP→TOP, VOL→SOP bridges
  pass RIDs directly — no CPU roundtrip.
- **Texture2DRD** works everywhere: any GPU texture can be wrapped for
  display (viewer, TextureRect, Sprite2D) with no readback.
- **Host I/O native handles** (`buffer_get_native_handle()`,
  `texture_get_native_handle()`) resolve to the same Vulkan device the
  host application sees, enabling NDI GPU, Spout, Direct3D interop.

### CPU readback points (unavoidable)

| Readback | Why it exists |
|----------|--------------|
| Disk export (SnapshotTOP save, VOL export) | Writing to file requires CPU data — one-shot, not per-frame |
| Non-GPU host fallback | When host app lacks GPU interop, fall back to `buffer_get_data()` / `texture_get_data()` |

All viewer rendering (POP, VOL) now uses compute→Texture2DRD — zero-copy.


## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    GNGpuContext (singleton)              │
│                                                         │
│  ┌────────────────────────────────────────────────────┐ │
│  │ rd = main_rd (renderer device)                     │ │
│  │ NO submit/sync (engine-owned)                      │ │
│  │                                                    │ │
│  │  TOPs  → compute dispatch → Texture2DRD output     │ │
│  │  POPs  → compute dispatch → SSBO (RID passthrough) │ │
│  │  VOLs  → compute dispatch → 3D texture (RID)       │ │
│  │  POP viewer → compute → Texture2DRD (zero-copy)    │ │
│  │  VOL viewer → compute → Texture2DRD (zero-copy)    │ │
│  └────────────────────────────────────────────────────┘ │
│                                                         │
│  CompositorEffectTOP: uses main device directly         │
│  (runs inside renderer's own submission pipeline)       │
└─────────────────────────────────────────────────────────┘
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
| VOL → SOP (marching cubes) | Vertex extraction from GPU volume — CPU geometry output |
| Export/save (disk write) | Writing textures/volumes to file — one-shot, not per-frame |
| Non-GPU host fallback | When host app lacks GPU interop (native handles unavailable) |

These operators call `rd.texture_get_data()` / `rd.buffer_get_data()`
explicitly. This is fine — it's on-demand, not every frame.

POP and VOL viewers now use compute→Texture2DRD (zero-copy) — no readback.


## GPU-Side Frame Buffering (Blit SubViewport Pattern)

Several temporal operators previously used a GPU→CPU→GPU readback
anti-pattern: `viewport.get_texture().get_image()` → `ImageTexture.update()`.
This has been replaced with a **blit SubViewport ring buffer** approach
that keeps all textures on the GPU.

### `GNTopBase._create_blit_viewport(parent, name, size, transparent)`

Static helper that creates a lightweight SubViewport + TextureRect child.
To capture a texture: set `blit.canvas.texture = source_texture`, then
`execute_cook` triggers `UPDATE_ONCE` on the viewport.  Read back via
`blit.viewport.get_texture()` — a `ViewportTexture` that stays GPU-resident.

### Ring Buffer TOPs (N-frame history)

**CacheTOP** and **TimeMachineTOP** use a ring of N blit viewports:

| Aspect | Implementation |
|--------|---------------|
| Storage | `Array[Dictionary]` of `{ viewport: SubViewport, canvas: TextureRect }` |
| Write | Each frame, set canvas texture on write slot → UPDATE_ONCE |
| Read | Read from ring at delay offset via `viewport.get_texture()` |
| execute_cook override | Reverts all ring slots to UPDATE_DISABLED except `_pending_write_vp` — prevents `GNTopBase.execute_cook` from re-blitting all N slots |

### Single-Frame Feedback TOPs

**FeedbackTOP**, **TrailTOP**, **CellularAutomataTOP** — blit VP captures
the main shader viewport's output each frame for next-frame feedback input.
Both viewports (shader + blit) render via `execute_cook` — no override needed.

**FrameDifferenceTOP** — blit VP captures the *input texture* (not the
diff output) for next-frame comparison.

**GlitchTOP** — blit VP captures viewport output probabilistically.
`execute_cook` override suppresses the blit VP on frames where the stale
buffer should remain unchanged.

### Future: Texture2DArray for bulk GPU reads

Operators that need to sample many frames simultaneously in a single shader
pass (e.g. temporal accumulation, motion blur with N-tap) would benefit
from a `Texture2DArray` ring on the RenderingDevice.  The current SubViewport
blit approach outputs one `ViewportTexture` per slot — fine for operators
that select/output a single frame, but requires N texture binds for
multi-frame shaders.  A `Texture2DArray` with layered writes via compute
would allow a single bind for all N frames.  This is a future optimization
and not yet implemented.


## Migration Checklist

- [x] **GNGpuContext**: Unified single device — `rd = main_rd = RenderingServer.get_rendering_device()`. No local device created. `shutdown()` does not call `rd.free()` (engine-owned).
- [x] **dispatch()**: Fire-and-forget — no `submit()`/`sync()`. GPU pipeline barriers are handled by the renderer.
- [x] **`*_on_main()` helpers**: `dispatch_on_main()`, `get_shader_on_main()`, etc. delegate to their base equivalents. Kept for backward API compatibility.
- [x] **is_compute_available()**: Probes `get_rendering_device() != null` (does not submit/sync).
- [x] **GLSLMultiTOP**: Uses `ctx.rd`. Output textures use `Texture2DRD` (zero readback). No `submit()`/`sync()`.
- [x] **ComputeShaderTOP**: Same as GLSLMultiTOP — `ctx.rd`, `Texture2DRD` output, no readback.
- [x] **POP/VOL operators**: Use `ctx.rd` (same device). `dispatch()` is fire-and-forget.
- [x] **PointCloudRenderTOP**: Binds POP particle SSBO directly — no bulk copy. Dispatches compute, wraps output as `Texture2DRD`. Zero-copy.
- [x] **POP viewer**: `render_pop_gpu()` → compute→Texture2DRD (zero-copy). No MultiMesh/SubViewport.
- [x] **VOL viewer**: `render_vol_gpu()` → compute→Texture2DRD (zero-copy). No CPU `texture_get_data()`.
- [x] **SnapshotTOP**: POP/VOL modes use `render_pop_gpu()`/`render_vol_gpu()` — no viewport needed.
- [x] **CompositorEffectTOP**: Uses `RenderingServer.get_rendering_device()` directly (runs inside renderer pipeline).
- [x] **Output texture usage bits**: MRT and compute output textures include `TEXTURE_USAGE_SAMPLING_BIT`.
- [x] **Cleanup**: Operators no longer call `_rd.free()`. Individual RIDs still freed via `free_rid()`.
- [ ] **Compatibility fallback**: If `get_rendering_device()` returns `null` (Compatibility renderer), fall back to SubViewport path (existing fallback code in GLSLMultiTOP).

### dispatch() policy

All operators use fire-and-forget `dispatch()`. No operator calls
`submit()` or `sync()`. The renderer's device handles GPU synchronization
via internal pipeline barriers.


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
