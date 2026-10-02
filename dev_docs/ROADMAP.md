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

### Show control — sequence and mapping

Research note, 1 Oct 2026. A tester keeps pixels in TouchDesigner and does time and data in [Chataigne](http://www.benjamin.kuperberg.fr/chataigne/), joined by OSC. Chataigne is a conductor: it does not generate the picture. Derivative forum threads and r/TouchDesigner describe the same split. The project timeline is a clock. The Animation COMP is the keyframe editor, and that editor is what people call terrible.

What they keep saying:

- In sequential mode the editor draws the project clock, not the animation’s own playhead, so a long sequence cannot be edited by eye.
- Scrubbing the animation playhead does not evaluate the channels. Users are told to scrub a different bar.
- A cut from one held value to another is hidden. You select the segment, not the keys, and set `constant()`. People who use the editor daily did not know that.
- Starting a scene does not reliably put the playhead at 0, and it drifts from a movie. The working recipe is a Timer CHOP index driving both the animation and the movie.
- One clock for the whole file. Independent sequences are assembled from extra Timer CHOPs. A dance-score thread says the editor has been clunky for years. Reddit’s timing thread says Touch is not built for linear programming, and names Chataigne (or Ableton, against the music waveform) as the place to draw time, with OSC back into Touch.

Chataigne’s pieces that GONODES does not have: modules that expose named values and commands (Resolume, QLab, Ableton, and the rest), a mapping (range, smooth, condition, several inputs, one target) instead of a node chain, a router across protocols, shared variables and presets that other programs write into, a Time Machine whose layers are triggers, automation curves, color, audio, and 2D maps, plus dashboard, detective, and parrot (record any value and play it back). OSC, MIDI, DMX, TimelineCHOP, CueDAT, and CueCHOP already exist. They are the clock and the cue table, not that editor.

Do not start with a Resolume module. The tester’s OSC workflow works once a sequence and a mapping exist.

| Step | What | Effort |
|------|------|--------|
| 1 | One sequence with its own length and playhead. Lanes: trigger, automation (hold is a normal curve, not a hidden mode), color. Scrubbing sets that playhead and the driven values update immediately. The drawn playhead is the sequence’s playhead. | High. About a month of focused work for a first version that can be used on a show. A curve editor, not a DAW. |
| 2 | A mapping: CHOP channel, OSC address, MIDI, or a variable, through range, smooth, and a condition, onto a parameter or an outgoing OSC address. Several inputs, one target. | Medium. About a week after the sequence’s targets exist. |
| 3 | Arm a mapping and record the incoming values onto an automation lane. | Low, once 1 and 2 exist. A few days. |
| 4 | Named modules (Resolume, QLab, Ableton) as saved address lists on top of the mapping. | Open-ended. Not part of the month. |

The cook clock stays the frame clock. Show time is a separate object. Items 3 and 4 in the optimisation tables below are unrelated and stay unscheduled.

That month fixes the three complaints that are about the editor lying: the playhead you drag is the sequence’s own time, scrubbing updates the driven values, and a hold is a normal key. It also covers a movie that reads that same time, which is the reset-and-drift complaint. It does not replace Ableton or Chataigne for a full score against a music waveform. Many lanes and recording onto a lane are later steps.

A take is a named parameter state. A sequence trigger will recall one with apply. Capture Take is the snapshot form of recording onto a lane: one instant, where a lane is those values over time.

### Where Touch users are unhappy

Research note, 1 Oct 2026. The plan is still to reach Touch’s usefulness as a live picture tool. These are the places people already leave Touch, or work around it, where GONODES can be the better tool without becoming Chataigne and without pretending to have Touch’s operator catalog.

| Complaint | What they say | What GONODES can offer |
|-----------|----------------|------------------------|
| Timeline | Animation COMP playhead is the wrong clock, scrubbing does not evaluate, a hold is hidden, and sequences drift from movies. People draw time in Chataigne or Ableton and send OSC back. Sources: Derivative forum (animation editor, constant keys, dance-score thread) and r/TouchDesigner timing and Animation COMP reset threads. | The sequence above. One panel, Godot `Animation` keys underneath, no second editor whose clock is different. |
| Data between programs | Routing, range, and smoothing a value onto a target is easier in Chataigne than as a chain of CHOPs. | The mapping above. The graph stays the picture. The mapping is the small object for one number. |
| Project files | `.toe` / `.tox` are binary. Git can store them and cannot diff or merge them. Teams externalize toxes by hand, or use unofficial collapse tools. A text format is still a Derivative wishlist with no public release. Sources: Matthew Ragan on Git (2017), forum threads on source control and git-compatible toe files. | Already true: a patch is text. Keep save order stable so a diff shows the edit and not noise. |
| License on show day | Commercial keys fail open as non-commercial, or need a dongle, including before a show. Shipping a locked project wants a Pro license plus a player license or a dongle. Sources: r/TouchDesigner licensing threads. | No key server and no dongle. A built player runs the patch. |
| Cook times lie | The performance monitor’s “cook” for a TOP is CPU submit time, not GPU time. Under load, Null and In nodes show multi-millisecond cooks because the CPU was elsewhere. Derivative documents this as expected. | Keep telling the truth in the debug panel: cooked, skipped, or waiting on the GPU. Do not print a time that includes another app. |
| Python on the frame | Extra modules (Open3D and others) crash the process because they share Touch’s interpreter. Scripts that run every frame dominate the frame and the advice is to replace them with CHOPs. | GDScript and the engine cook the frame. Python stays an optional worker, not the clock. |

Do not spend the next stretch trying to match POPs, Kantan Mapper, or the size of the community palette. Those are why people stay on Touch. The rows above are why some of them would leave.

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
