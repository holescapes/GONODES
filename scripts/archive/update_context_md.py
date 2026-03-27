#!/usr/bin/env python3
"""[ARCHIVED] One-shot script to update stale info in GONODES_CONTEXT.md.
Note: References to ScriptCHOP/SOP/DAT/IMG and GenericScriptNode are from
before the March 2026 script consolidation into GDScriptSCRIPT."""
import re

fp = "GONODES_CONTEXT.md"
text = open(fp, "r", encoding="utf-8").read()
lines = text.split("\n")
changes = 0

def replace_once(old, new, label):
    global text, changes
    if old not in text:
        print(f"  SKIP (not found): {label}")
        return
    count = text.count(old)
    if count > 1:
        print(f"  WARN ({count} occurrences): {label}")
    text = text.replace(old, new, 1)
    changes += 1
    print(f"  OK: {label}")

print("=== Updating GONODES_CONTEXT.md ===\n")

# ── #1: Header line 4 — operator counts ──
replace_once(
    "348 operators (81 TOP, 14 IMG, 68 CHOP, 33 DAT, 62 SOP, 10 POP, 11 VOL, 20 COMP, 9 MAT, 9 OUT, 31 UI). 11 families. 11 GDExtension addons (native, shadertoy, isf, ffmpeg, hap, spout, syphon, video_capture, midi, gpu_encode, mapper)",
    "545 operators (129 TOP, 21 IMG, 112 CHOP, 47 DAT, 120 SOP, 20 POP, 22 VOL, 20 COMP, 10 MAT, 13 OUT, 31 UI). 11 families. 19 GDExtension addons (native, shadertoy, isf, ffmpeg, hap, spout, syphon, video_capture, midi, gpu_encode, mapper, ndi, ml, depth_sensor, sdf, serial, blackmagic, user_native, user_python)",
    "#1 header operator+extension counts"
)

# ── #2: Header help patch count ──
replace_once(
    "1,014 core help .gnpatch example files",
    "1,140 core help .gnpatch example files",
    "#2a header core help patches"
)
replace_once(
    "+ 70 extension patches = 1,084 total",
    "+ 242 extension patches = 1,382 total",
    "#2b header extension+total help patches"
)

# ── #3: Class hierarchy counts (§something around line 308) ──
replace_once(
    "GNTopBase (30 TOP operators)",
    "GNTopBase (129 TOP operators)",
    "#3a class hierarchy TOP count"
)
replace_once(
    "GNImgBase (7 IMG operators)",
    "GNImgBase (21 IMG operators)",
    "#3b class hierarchy IMG count"
)
replace_once(
    "GNChopBase (23 CHOP operators, incl. DATtoCHOP bridge, RampCHOP)",
    "GNChopBase (112 CHOP operators)",
    "#3c class hierarchy CHOP count"
)
replace_once(
    "GNDatBase (13 DAT operators)",
    "GNDatBase (47 DAT operators)",
    "#3d class hierarchy DAT count"
)
replace_once(
    "GNSopBase (15 SOP operators)",
    "GNSopBase (120 SOP operators)",
    "#3e class hierarchy SOP count"
)
replace_once(
    "GNCompBase (4 COMP operators)",
    "GNCompBase (20 COMP operators)",
    "#3f class hierarchy COMP count"
)
replace_once(
    "GNMatBase (6 MAT operators)",
    "GNMatBase (10 MAT operators)",
    "#3g class hierarchy MAT count"
)

# ── #4: Test count (line 1762) ──
replace_once(
    "All 690 tests passing",
    "All 1,044 tests passing across 32 test files",
    "#4 test count"
)

# ── #5: Thread Safety section ──
replace_once(
    """### Thread Safety (Future)

When the cook engine moves to threaded cooking:
- GNData becomes **immutable after cook** — the producing node creates a new GNData for each cook, and the old one can be read by consumers on other threads.
- Or: **double-buffering** — each node has two GNData slots (front/back), consumers read front while producer writes back.
- For MVP (single-threaded `_process`), reference passing with read-only contract is sufficient.""",
    """### Thread Safety

Thread-safe parallel cooking is implemented with three safeguards:

1. **Expression edges in topological levels.** `_rebuild_expr_consumer_map()` builds expression dependency edges (e.g., `chop("B","out")` → A depends on B) and injects them into `network._expression_edges`. `_compute_topological_levels()` adds these to the Kahn's algorithm adjacency graph so expression-linked nodes never land on the same parallel level.

2. **Per-operator `thread_safe` flag.** `GNNode.thread_safe: bool = true` (default). Operators that call `set_par()` on other nodes, use the Network API (`network_add_node`, etc.), or rely on non-thread-safe I/O are marked `thread_safe = false`. Currently 19 operators are marked unsafe: all Script operators (ScriptCHOP/SOP/DAT/IMG, GenericScriptNode, CallbackDAT), CueCHOP, and all I/O operators (MqttDAT, NetworkDAT, OscOUT, OscInCHOP, OscInDAT, WebDAT, AudioInCHOP, MidiInCHOP, RtMidiInCHOP, RtMidiOutCHOP, SerialReceiveDAT, SerialSendDAT).

3. **Parallel batch splitting.** `_cook_cpu_batch_parallel()` separates each topo level into `parallel_prepared` (thread_safe=true) and `sequential_prepared` (thread_safe=false). Thread-safe nodes dispatch to `WorkerThreadPool`; unsafe nodes cook sequentially on the main thread after the parallel batch completes.

**Patch-level opt-in:** `GNNetwork.multithreading_enabled: bool = false` — parallel cooking requires both `parallel_cook_enabled` (engine global) and `multithreading_enabled` (per-patch toggle). This is off by default since multi-threading is experimental. Serialized in `.gnpatch` files.

**COW safety:** `_mutable_input()` duplicates input data into a local copy, so in-place operators never mutate the shared upstream GNData object.""",
    "#5 thread safety section"
)

# ── #6: Duplicate §20 — renumber to §37 ──
replace_once(
    "## 20. Open Questions (To Resolve During Implementation)",
    "## 37. Open Questions (Historical — most resolved)",
    "#6 renumber duplicate §20 → §37"
)

# ── #7: Duplicate §21 — renumber to §38 ──
replace_once(
    "## 21. Phase 3 Architecture: Node Graph UI",
    "## 38. Phase 3 Architecture: Node Graph UI (Historical)",
    "#7 renumber duplicate §21 → §38"
)

# ── #8: Operator Registry in §38 — update ──
replace_once(
    """### Operator Registry

Currently hardcoded in `GNGraphEditor.get_operator_registry()` as a static Dictionary:

```gdscript
{ "noise_top": NoiseTOP, "composite_top": CompositeTOP, ... }
```

New operators must be manually added to this dictionary.""",
    """### Operator Registry

> **Note:** This section describes the historical Phase 3 approach. The hardcoded dictionary was replaced by `GNExtensionRegistry` — core operators are declared in `addons/gonodes/gn_core.cfg` manifest (376 operators) and loaded via `_load_extension()`. Extension operators come from `gn_ext_*/gn_extension.cfg` manifests (169 operators across 19 extensions). No hardcoded dictionary exists.""",
    "#8 operator registry description"
)

# ── #9: Duplicate §22 — renumber to §39 ──
replace_once(
    "## 22. Phase 4 Architecture: Parameters & Inspector",
    "## 39. Phase 4 Architecture: Parameters & Inspector",
    "#9 renumber duplicate §22 → §39"
)

# ── #10: Registration guidance in Hard Rules ──
replace_once(
    "Registration in _register_core_operators() (or in the extension's gn_extension.cfg)",
    "Registration in `gn_core.cfg` manifest (core ops) or `gn_extension.cfg` manifest (extension ops)",
    "#10 registration guidance"
)

# ── #11: New operator checklist step 7 ──
# Find the one that says "Register in GNExtensionRegistry._register_core_operators()"
# Need exact surrounding context
replace_once(
    "Registration in `GNExtensionRegistry._register_core_operators()`",
    "Add operator entry to `addons/gonodes/gn_core.cfg` manifest",
    "#11a new operator checklist (alt text)"
)
# Try another variant
replace_once(
    "Register in `GNExtensionRegistry._register_core_operators()`",
    "Add operator entry to `addons/gonodes/gn_core.cfg` manifest",
    "#11b new operator checklist"
)
# Try without backticks
replace_once(
    "Register in GNExtensionRegistry._register_core_operators()",
    "Add operator entry to `addons/gonodes/gn_core.cfg` manifest",
    "#11c new operator checklist (no backticks)"
)

# ── #12: §28.2 registry description ──
replace_once(
    "all 93 core operators are registered via `_register_core_operators()`",
    "all 376 core operators are declared in `gn_core.cfg` and loaded via `_load_extension()`",
    "#12 §28.2 registry count"
)
# Also fix the "93" mention without surrounding context
replace_once(
    "at which point all 93 core operators are registered via `_register_core_operators()`",
    "at which point all 376 core operators are loaded from `gn_core.cfg` via `_load_extension()`",
    "#12b §28.2 alternate"
)

# ── #13: Loading flow step 2 — 82 core operators ──
replace_once(
    "`instance()` creates the singleton and runs `_register_core_operators()` (82 core operators)",
    "`instance()` creates the singleton and loads `gn_core.cfg` via `_load_extension()` (376 core operators)",
    "#13 loading flow step 2"
)

# ── #14: §35.11 Updated Totals ──
replace_once(
    "- **348 operators** (81 TOP, 14 IMG, 68 CHOP, 33 DAT, 62 SOP, 10 POP, 11 VOL, 20 COMP, 9 MAT, 9 OUT, 31 UI)",
    "- **545 operators** (129 TOP, 21 IMG, 112 CHOP, 47 DAT, 120 SOP, 20 POP, 22 VOL, 20 COMP, 10 MAT, 13 OUT, 31 UI)",
    "#14 §35.11 operator totals"
)

replace_once(
    "- **14 GDExtension addons**: gn_ext_native (92 C++ operators), gn_ext_shadertoy, gn_ext_isf, gn_ext_ffmpeg, gn_ext_hap, gn_ext_spout, gn_ext_syphon, gn_ext_video_capture, gn_ext_midi, gn_ext_gpu_encode, gn_ext_mapper, gn_ext_ndi (NDI video/audio I/O), gn_ext_ml (ONNX Runtime ML inference — pose/hand/face/depth/style/segmentation/detection), gn_ext_depth_sensor (Azure Kinect + RealSense + Ultraleap — depth/color/IR/skeleton/hand tracking/point cloud)",
    "- **19 GDExtension addons**: gn_ext_native (92 C++ operators), gn_ext_shadertoy, gn_ext_isf, gn_ext_ffmpeg, gn_ext_hap, gn_ext_spout, gn_ext_syphon, gn_ext_video_capture, gn_ext_midi, gn_ext_gpu_encode, gn_ext_mapper, gn_ext_ndi, gn_ext_ml, gn_ext_depth_sensor, gn_ext_sdf, gn_ext_serial, gn_ext_blackmagic, gn_ext_user_native, gn_ext_user_python",
    "#14b §35.11 extension count"
)

replace_once(
    "- **1,120 help patches** (1,014 core + 106 extension) across all 11 families — 3+ per operator",
    "- **1,382 help patches** (1,140 core + 242 extension) across all 11 families — 3+ per operator",
    "#14c §35.11 help patches"
)

# ── #15: §36.1 native operator counts ──
replace_once(
    """**43 native C++ operators** across 4 families via `gn_ext_native` / `gn_native` GDExtension:

| Family | Count | Operators |
|--------|-------|-----------|
| SOP (24) | Geometry | Particle, Metaball, PolyReduce, IsoSurface, Ray, Facet, Fuse, Subdivide, Copy, LSystem, Spring, Noise, Mountain, Blend, Scatter, Sweep, Extrude, Bend, Taper, Twist, Lattice, Magnet, PolyLoft, Skin |
| CHOP (13) | Signal | Smooth, Noise, Wave, Math, Filter, Resample, Trail, Slope, Warp, Interpolate, Physics, Pattern, AudioSpectrum |
| IMG (4) | Image | Blur, Noise, PixelSort, EdgeDetect |
| TOP (2) | Texture | OpticalFlow, Analyze |""",
    """**92 native C++ operators** across 6 families via `gn_ext_native` / `gn_native` GDExtension (Phases 1–6 all complete):

| Family | Count | Operators |
|--------|-------|-----------|
| SOP (42) | Geometry | Particle, Metaball, PolyReduce, IsoSurface, Ray, Facet, Fuse, Subdivide, Copy, LSystem, Spring, Noise, Mountain, Blend, Scatter, Sweep, Extrude, Bend, Taper, Twist, Lattice, Magnet, PolyLoft, Skin, TOPtoSOP, Point, Clip, Sort, Transform, Divide, Normal, Mirror, Cap, Delete, Carve, UVProject, Attribute + 5 more |
| CHOP (23) | Signal | Smooth, Noise, Wave, Math, Filter, Resample, Trail, Slope, Warp, Interpolate, Physics, Pattern, AudioSpectrum, Expression, AudioDynamics, Stretch, Lookup + 6 more |
| IMG (5) | Image | Blur, Noise, PixelSort, EdgeDetect, Checkerboard |
| TOP (4) | Texture | OpticalFlow, Analyze, CHOPtoTOP, ParticleState |
| VOL (9) | Volume | MarchingCubes, CHOPtoVOL, Analyze + 6 more |
| POP (9) | Particle | Instance, Render + 7 more |""",
    "#15 §36.1 native op table"
)

# ── #16: §36.2 audit — update total ref ──
replace_once(
    "Every operator in the 348-operator codebase was evaluated",
    "Every operator in the 545-operator codebase was evaluated",
    "#16 §36.2 audit total"
)

# ── #17: §36.8 phase conclusion ──
replace_once(
    "This would bring total native coverage from **43 → 53 operators**",
    "Phases 4–6 are now complete. Total native coverage: **92 operators**",
    "#17 §36.8 phase 4 conclusion"
)

# ── #18: §36.9 Future Phases — mark as done ──
replace_once(
    """**Phase 5** (Tier 2 remainder + Tier 3 high-value): ParticleStateTOP, UVProjectSOP, AttributeSOP, ExpressionCHOP, AudioDynamicsCHOP, TransformSOP, DivideSOP, NormalSOP → **53 → 61 operators**.

**Phase 6** (Tier 3 remainder): MirrorSOP, CapSOP, DeleteSOP, CarveSOP, RenderPOP, CheckerboardIMG, StretchCHOP, LookupCHOP → **61 → 69 operators**.""",
    """**Phase 5** (Tier 2 remainder + Tier 3 high-value): ParticleStateTOP, UVProjectSOP, AttributeSOP, ExpressionCHOP, AudioDynamicsCHOP, TransformSOP, DivideSOP, NormalSOP — ✅ **COMPLETE**.

**Phase 6** (Tier 3 remainder): MirrorSOP, CapSOP, DeleteSOP, CarveSOP, RenderPOP, CheckerboardIMG, StretchCHOP, LookupCHOP — ✅ **COMPLETE**.

All 6 native migration phases are complete. 92 native C++ operators across 6 families (42 SOP, 23 CHOP, 5 IMG, 4 TOP, 9 VOL, 9 POP).""",
    "#18 §36.9 future phases → done"
)

# ── #19: §27.8 registration step ──
replace_once(
    "7. Register in `GNExtensionRegistry._register_core_operators()`",
    "7. Add operator entry to `addons/gonodes/gn_core.cfg` manifest",
    "#19 §27.8 script family checklist"
)

# ── #20: §25 new operator checklist — fix step 2 ──
replace_once(
    "Registration in `_register_core_operators()` (or in the extension's `gn_extension.cfg`)",
    "Registration in `gn_core.cfg` manifest (core ops) or `gn_extension.cfg` manifest (extension ops)",
    "#20 §25 operator checklist registration"
)

# ── #21: line 4936 — "bringing the total to ... 348 operators" ──
replace_once(
    "bringing the total to 11 families and 348 operators",
    "bringing the total to 11 families and 545 operators",
    "#21 §35 POP/VOL total"
)

# ── #22: Header "1,084 `.gnpatch` example files" ──
replace_once(
    "1,084 `.gnpatch` example files across all 11 help families",
    "1,382 `.gnpatch` example files across all 11 help families",
    "#22 header help patch count (alt)"
)

# ── Write result ──
open(fp, "w", encoding="utf-8", newline="").write(text)
print(f"\n=== Done. {changes} replacements applied. ===")
