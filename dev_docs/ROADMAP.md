# GONODES Roadmap — v1.2

> Single source of truth for planned work. Open items were checked against the code on 24 Sep 2026.
> Completed items have been removed — see CHANGELOG.md and commit history.
> Adaptive frame budget and GPU-batch submission stay on this list and are not scheduled.
> Shipped since the 24 Sep check, and removed from the open list: per-extension `.pck` (`scripts/pack_extension.ps1`), the Extensions panel, the in-app asset browser, and palette tags (`audio`, `video`, `file`, `camera`). Native libraries still need a restart. There is no engine-version gate.

---

## Features

### Community asset portal

The in-app asset browser is shipped (Preferences → Asset Browser: search, family filter, promoted-parameter preview, install/uninstall under `user://gonodes_assets/`). Still open: a web service for publishing and discovering `.gnasset` files.

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

## Optimisation — Tier 1 (High Impact, Achievable Now)

| # | Item | Description | Effort |
|---|------|-------------|--------|
| 3 | **Adaptive frame budget** | When frame time exceeds target, automatically reduce SubViewport resolution on non-critical TOPs. Priority levels per sink. Not scheduled. | Medium |
| 4 | **Parallel cook: GPU batch** | CPU nodes parallelise. GPU nodes are sequential. Group independent TOP chains and submit `UPDATE_ONCE` flags in a single batch. Not threads, and not scheduled. Godot still submits viewport updates on the main thread. | Medium-High |
| 5 | **`max_cooks_per_frame` for parallel path** | The cap is applied on the sequential cook path only (`gn_cook_engine.gd`). Extend it to the parallel path — abort remaining topo levels when the budget is exceeded. | Low |

## Optimisation — Tier 2 (Moderate Effort)

| # | Item | Description | Effort |
|---|------|-------------|--------|
| 9 | **Viewport readback stays synchronous** | Godot 4.7 has no async RenderingServer texture read. SubViewport bridges (TOPtoCHOP, TOPtoIMG, and the other `ViewportTexture` readers) still call `get_image()` every cook. `Texture2DRD` already uses `texture_get_data_async`. | Upstream |

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
