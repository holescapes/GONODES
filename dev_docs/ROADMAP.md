# GONODES Roadmap — v1.1

> Single source of truth for planned work. The list was last checked against the actual codebase in June 2025 and has not been re-checked since.
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

### Palette Multi-Output Discoverability

Operators with cross-family outputs (e.g. MovieFileInTOP: port 0 = TOP, port 1 = CHOP audio) are only listed under their primary family. Users searching the secondary output's family won't find the node.

Three approaches, in order of increasing scope:

| Approach | Effort | Effect |
|----------|--------|--------|
| **1. Search matches all output types** | Small | Palette text search shows operators by ANY output port family, not just the node's primary family |
| **2. Cross-list multi-output nodes** | Medium | Family pill filter also shows nodes with a secondary output of that family, with a visual badge (e.g. "also outputs: CHOP") |
| **3. Tag/capability system** | Large | Operators declare semantic tags ("audio", "video", "file", "camera") as an orthogonal search dimension |

Port family data for all operators already exists in `port_registry.json`. Approach 1 requires only a palette search change. Approach 2 adds a second pass to the family pill filter. Approach 3 is a new metadata system.

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

## COMP Scene-Node Proxy Architecture (Multi-Consumer Fan-Out) — IMPLEMENTED

### Problem (Solved)

COMP operators own a singleton Godot `Node3D` scene node. Since a Node3D can only have one parent, fan-out to multiple consumers (RenderTOP, MergeCOMP) caused the last cook to win.

### Solution: GNProxyTree

Implemented in `addons/gonodes/core/gn_proxy_tree.gd`. The first consumer adopts the original scene node (zero overhead); subsequent consumers get lightweight visual proxies that share GPU resources (Mesh, Material, MultiMesh). Physics bodies become plain Node3D placeholders.

**Operators using GNProxyTree:** RenderTOP, MergeCOMP, BoneCOMP, LODCOMP, PathCOMP, VehicleCOMP, NavigationCOMP.

**Proxied node types:** MeshInstance3D, MultiMeshInstance3D, Camera3D, DirectionalLight3D, OmniLight3D, SpotLight3D. Unknown types become Node3D placeholders.

**Tests:** `tests/unit/core/test_proxy_tree.gd` — 19 test functions.

See Hard Rule 25.11 and 25.27 for guidelines on adding new COMP node types.

---

## Items Confirmed Done (Removed from Roadmap)

These were listed as pending in various docs but are actually implemented:

| Item | Status | Evidence |
|------|--------|----------|
| NDI Out TOP | ✅ Done | `addons/gn_ext_ndi/operators/ndi_out_top.gd` |
| Phase 9 native SOPs (7/8) | ✅ Done | smooth, remesh, polybevel, wireframe, polystitch, blur_vol, fluid_vol all native |
| Phase 9 boolean_sop native | ✅ Done | BSP-tree CSG in `gn_native_boolean_sop.cpp` — no scene tree dependency |
| LibGONODES v1.1 gaps (10 functions) | ✅ Done | All implemented in `gonodes_host.cpp` |
| Parameter-level dirty tracking | ✅ Done | Input hash computed/stored per cook (`_compute_cook_input_hash`); hash-based skip arm present but unreachable from dirty-only cook loop (see COOK_ENGINE.md §3.3) |
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
