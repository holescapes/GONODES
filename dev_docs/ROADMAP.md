# GONODES Roadmap — v1.1

> Single source of truth for planned work. Items verified against the actual codebase as of June 2025.
> Completed items have been removed — see CHANGELOG.md and commit history.

---

## Features

### Modular Extension Distribution (PCK)

Currently all extensions are baked into the monolithic `.pck` at export time. Ship extensions as individual `.pck` files that can be installed/removed without re-exporting. Includes:

- Per-extension `.pck` export in `build_templates.ps1`
- `user://extensions/gn_ext_*` scan path in `GNExtensionRegistry.scan_extensions()`
- In-app Extensions settings panel (list installed, enable/disable, version guards)
- Hot-reload of extensions without restart

**Ref:** [GONODES_CONTEXT.md § Extension distribution](../GONODES_CONTEXT.md), [CONTRIBUTING.md § Extension isolation](CONTRIBUTING.md)

### Asset Browser Panel

The `.gnasset` custom operator format and `scan_custom_assets()` runtime loading are implemented. What's missing:

- `gn_asset_browser.gd` — dedicated UI panel with search, family/tag filter, promoted-param preview, install/uninstall
- Community sharing portal (web service for publishing/discovering `.gnasset` files)

**Ref:** [README.md § Custom Operators](../README.md)

### FxPlug / FFGL Plugin Export

Export GONODES patches as FxPlug (macOS) or FFGL (cross-platform) plugins for use inside Final Cut Pro, Resolume, VDMX, etc. Requires a thin host adapter wrapping libgonodes.

**Ref:** [README.md § Roadmap](../README.md)

### Laser DAC Drivers (GDExtension)

The `LaserCHOP` data model (ILDA point channels) exists. What's missing are native GDExtension drivers for:

- EtherDream (UDP)
- Helios DAC (USB)
- ShowNET (network)

**Ref:** [README.md § Roadmap](../README.md)

### Network Collaboration (Shared Editing)

Real-time multi-user editing of the same `.gnpatch` — cursor presence, node locking, operation broadcasting (OT or CRDT-based).

**Ref:** [README.md § Roadmap](../README.md)

---

## Native C++ Migration

All Phase 9 SOP operators have been migrated to native C++, including `boolean_sop` (BSP-tree CSG). No remaining items.

---

## Optimisation — Tier 1 (High Impact, Achievable Now)

| # | Item | Description | Effort |
|---|------|-------------|--------|
| 2 | **Expression compilation to callables** | `_compiled_expression` cache exists but still calls `Expression.execute()` at runtime. Replace with pre-compiled GDScript callables; skip re-parse when source unchanged. 2–5× faster expression eval. | Medium |
| 3 | **Adaptive frame budget** | When frame time exceeds target, automatically reduce SubViewport resolution on non-critical TOPs. Priority levels per sink. | Medium |
| 4 | **Parallel cook: GPU batch** | Currently CPU nodes parallelise but GPU nodes are sequential. Group independent TOP chains and submit `UPDATE_ONCE` flags in a single batch. 10–30% GPU utilisation improvement for multi-chain patches. | Medium-High |
| 5 | **`max_cooks_per_frame` for parallel path** | Frame budget cap only works in sequential cook path. Extend to parallel path — abort remaining topo levels when budget exceeded. | Low |

## Optimisation — Tier 2 (Moderate Effort)

| # | Item | Description | Effort |
|---|------|-------------|--------|
| 6 | **Texture pool / SubViewport recycling** | Pool SubViewports by resolution+format. Swap from pool on resolution change; recycle from deleted nodes. Reduces GPU memory fragmentation. | Medium |
| 9 | **Async GPU readback** | For TOPtoCHOP, TOPtoIMG, and GPU→CPU bridges, use `RenderingDevice` async readback with fences instead of synchronous `texture_2d_get()`. 1–5ms saved per readback node per frame. | Medium |

## Optimisation — Tier 3 (High Effort, Future Architecture)

| # | Item | Description | Effort |
|---|------|-------------|--------|
| 10 | **Godot multi-window render queues** | Use per-SubViewport render queues to parallelise independent TOP chains on the GPU. Depends on Godot upstream. | Upstream |
| 11 | **SOP chain fusion (compiled blocks)** | Fuse linear SOP chains into single-pass operations (Transform→Normal→Peak → one pass). Requires intermediate representation. | Very High |
| 12 | **VEX-like bytecode VM for expressions** | Purpose-built stack-based VM for expression vocabulary (`chop`, `par`, `fit`, `noise`, `ramp`). 5–20× faster than `Expression.execute()`. | High |
| 13 | **Partial frame cook (time-slicing)** | Pause mid-topo-order, resume next frame. Low-priority branches at reduced framerate. Smooth degradation under load. | High |
| 14 | **Persistent SPIR-V shader caching** | In-memory `_shader_cache` exists in `gn_gpu_context.gd`. Extend to disk-persistent cross-session cache. Skip recompilation on patch load when shader source unchanged. | Medium |
| 15 | **Compute shader for CHOP math** | Offload array-math CHOPs to GPU compute when channel length × count exceeds threshold (10K+ samples). 10–100× speedup for large datasets. | Medium-High |

## Optimisation — Tier 4 (Speculative / Research)

| # | Item | Description |
|---|------|-------------|
| 16 | **Warp-level GPU scheduling** | Fine-grained GPU work distribution via Vulkan compute queues. Requires low-level Vulkan access beyond Godot. |
| 17 | **Distributed cook (network)** | Split graph across machines — network-transparent node evaluation. Like Houdini PDG but real-time. |
| 18 | **ML-accelerated shader compilation** | Predict optimal shader variants based on input resolution and GPU. Research territory. |
| 19 | **GDScript JIT in Godot core** | If Godot ships a GDScript JIT, all Script operators get faster for free. Monitor godot-proposals. |

**Ref:** [GONODES_VS_THE_REST.md § Optimisation Roadmap](GONODES_VS_THE_REST.md)

---

## COMP Scene-Node Proxy Architecture (Multi-Consumer Fan-Out)

### Current Limitation

COMP operators (GeometryCOMP, CameraCOMP, LightCOMP, etc.) own a singleton Godot `Node3D` scene node. When a consumer (RenderTOP, MergeCOMP) needs that node, it **reparents** it into its own SubViewport/group. Since a Node3D can only have one parent, only one consumer gets the node — the last one to cook wins; all others render an empty scene.

**Affected operators:**
- **RenderTOP** — reparents upstream COMP scene nodes into its SubViewport for 3D rendering
- **MergeCOMP** — reparents upstream COMP scene nodes into its `_group_node`

**Not affected:**
- COMP→COMP wiring where the downstream creates its *own* node (e.g., RigidBodyCOMP reads upstream mesh data to build its own RigidBody3D — no reparenting)
- All non-COMP families (TOP, CHOP, SOP, DAT, IMG, MAT, etc.) — these use GNData with ref-counted copy-on-write semantics and support unlimited fan-out

**Workaround:** Each COMP should feed exactly one reparenting consumer. For multi-camera setups, duplicate the COMP chain.

### Proposed Solution: Visual Proxy Nodes

Replace the reparenting model with a proxy model. COMPs keep their scene nodes in place. Consumers create lightweight **proxy** Node3D instances in their own SubViewport, sharing the same GPU resources (Mesh, Material, Texture — all Godot `Resource` objects, ref-counted, zero-copy).

**Architecture:**

```
Current:  GeometryCOMP._mesh_instance ──[reparent]──► RenderTOP.SubViewport
                                        (exclusive)

Proposed: GeometryCOMP._mesh_instance  (stays put, source of truth)
              │
              ├── .mesh ──────────────► RenderTOP_A creates proxy MeshInstance3D
              │   .material_override     sharing same Mesh + Material resources
              │   .transform
              │
              └── .mesh ──────────────► RenderTOP_B creates its own proxy
                  .material_override     sharing same Mesh + Material resources
                  .transform
```

**What's shared (zero cost):** Mesh vertex buffers (GPU memory), materials, textures — all Godot Resources, ref-counted, one GPU copy regardless of how many proxies reference them.

**What's per-consumer (cheap):** A proxy Node3D in each SubViewport — just a transform matrix + resource pointers. Trivial memory (~200 bytes).

**No cook ordering risk:** The cook engine is demand-driven DAG — COMPs always cook before their downstream RenderTOPs. Proxy sync runs inside RenderTOP's `_cook()`, before the SubViewport renders (`UPDATE_ONCE`). No stale frames.

### Implementation: CompVisualState Struct

A base-class struct in `GNCompBase` captures all visual properties needed for proxy creation:

```gdscript
# In gn_comp_base.gd

## Snapshot of all visual properties needed to create/sync a proxy.
## Stored as a lightweight value object — no Node3D references.
class CompVisualState:
    var node_type: StringName       # "MeshInstance3D", "Camera3D", "Light3D", etc.
    var transform: Transform3D
    var visible: bool
    var layers: int
    var cast_shadow: int
    # Mesh
    var mesh: Mesh
    var material_override: Material
    var surface_material_count: int
    var surface_materials: Array[Material]
    # Camera
    var fov: float
    var near: float
    var far: float
    var projection: int
    # Light
    var light_color: Color
    var light_energy: float
    var shadow_enabled: bool
    var light_type: int             # directional, omni, spot
    # Skeleton (bone transforms as flat array)
    var bone_count: int
    var bone_transforms: Array[Transform3D]

## Called by COMP subclasses at end of _cook() to snapshot visual state.
func _capture_visual_state() -> CompVisualState:
    # read from _scene_node, populate struct
    ...

## Called by RenderTOP to create or sync a proxy from a visual state.
static func sync_proxy(state: CompVisualState, proxy: Node3D) -> Node3D:
    # if proxy is null or wrong type, create new one
    # copy all fields from state to proxy
    # return proxy
    ...
```

**Why this design:**
1. **Single source of truth** — adding a new visual property means updating `CompVisualState` + `_capture_visual_state()` + `sync_proxy()`. Three places, all in one file, all in the base class (rule 25.25).
2. **Decoupled from Node3D** — the state struct is a plain value object. RenderTOP never touches the source node.
3. **Testable** — capture + sync can be unit tested without a real scene tree.
4. **Extensible** — subclasses can extend `CompVisualState` or add `custom_data: Dictionary` for COMP-specific state.

### Real Drawbacks

1. **Proxy lifecycle management.** RenderTOP must create proxies when COMPs connect, destroy them on disconnect, handle COMP type changes (MeshInstance3D → Camera3D on same port), and survive undo/redo. Bookkeeping code — not hard, but edge-case-prone.

2. **Non-visual Node3D properties don't proxy:**
   - **Collision shapes** — a proxy MeshInstance3D renders but doesn't collide. Second viewport can't do raycasts against proxied bodies.
   - **Skeleton3D / BoneAttachment3D** — proxying a skinned mesh requires recreating the bone hierarchy. For a 60-bone character at 60fps, that's 3,600 transform writes per proxy per frame. Cheap individually, adds up with multiple skeletons × viewports.
   - **GPUParticles3D** — particle state is per-instance. A proxy would simulate independently (different random seeds, different positions). Not visual copies.

3. **Godot shader uniforms set via code** — if a COMP modifies `material.set_shader_parameter()` per-frame, the proxy shares the same material and gets the same uniforms automatically. But per-viewport uniforms (e.g., per-camera effects) would require material duplication, breaking zero-copy.

4. **MergeCOMP subtree proxying** — a MergeCOMP with 10 children means recursively proxying 10+ nodes per consumer viewport, each individually synced.

5. **Environment/VoxelGI/ReflectionProbe** — these are per-World3D, not per-node. EnvironmentCOMP would need special proxy handling (apply Environment to the proxy viewport's world, not create a proxy node).

### Phased Rollout

| Phase | Scope | Covers |
|-------|-------|--------|
| Phase 1 | MeshInstance3D proxies only | GeometryCOMP, RigidBodyCOMP, StaticBodyCOMP, SoftBodyCOMP — vast majority of use cases |
| Phase 2 | Camera3D + Light3D proxies | Multi-camera renders, picture-in-picture |
| Phase 3 | Skeleton3D bone sync | Animated character multi-view |
| Phase 4 | MergeCOMP recursive proxying | Complex scene fan-out |

**Priority:** Post-beta. The current single-ownership model covers 95% of real use cases. Multi-camera is the primary unblocked use case.

**Files affected:** `gn_comp_base.gd` (CompVisualState + capture/sync), `render_top.gd` (proxy creation instead of reparenting), `merge_comp.gd` (proxy instead of reparenting). COMP subclasses unchanged — they keep returning `_build_comp_data()`.

---

## Items Confirmed Done (Removed from Roadmap)

These were listed as pending in various docs but are actually implemented:

| Item | Status | Evidence |
|------|--------|----------|
| NDI Out TOP | ✅ Done | `addons/gn_ext_ndi/operators/ndi_out_top.gd` |
| Phase 9 native SOPs (7/8) | ✅ Done | smooth, remesh, polybevel, wireframe, polystitch, blur_vol, fluid_vol all native |
| Phase 9 boolean_sop native | ✅ Done | BSP-tree CSG in `gn_native_boolean_sop.cpp` — no scene tree dependency |
| LibGONODES v1.1 gaps (10 functions) | ✅ Done | All implemented in `gonodes_host.cpp` |
| Parameter-level dirty tracking | ✅ Done | Input hash guard (`_compute_cook_input_hash`) |
| In-memory SPIR-V shader cache | ✅ Done | `_shader_cache` dict in `gn_gpu_context.gd` |
| Hot-reloadable C++ user nodes | ✅ Done | `gn_ext_user_native` |
| Embedded Python + NumPy | ✅ Done | `gn_ext_user_python` |
| GPU Particles (POP family) | ✅ Done | 10 POP operators + 7 compute shaders |
| Volumetric 3D Textures (VOL family) | ✅ Done | 10 VOL operators + 11 compute shaders |
| Custom Operator Assets (.gnasset) | ✅ Done | `GNCustomOperator`, `scan_custom_assets()` |
| Spare Parameters | ✅ Done | `add_spare_parameter()` / `remove_spare_parameter()` on GNNode |
| Take System | ✅ Done | `GNTakeManager`, `.gntake` format, blend UI |
| Timeline / Cue System | ✅ Done | 4-layer system: engine transport, TimelineCHOP, CueDAT+CueCHOP, editor UI |
| LibGodot embedding | ✅ Done | Full C API, 6 bridge operators, GPU context sharing |
| Multi-threaded cook engine | ✅ Done | Level-based parallelism via WorkerThreadPool |
| FFmpeg GDExtension | ✅ Done | H.264/H.265/VP9/AV1/ProRes decode + encode |
| HAP codec | ✅ Done | `gn_ext_hap` — HapInTOP + HapOutTOP |
