# GONODES — LLM Context File

> **Last updated:** 2026-03-14
> **Status:** Phase 6 Complete — **Mobile/Web Export Phases 1-8 ALL COMPLETE.** **New: 2-Layer Logging & Warning System** $([char]0x2014) editor-only diagnostics: Layer 1 per-node warning/error badges (`node_warning`/`node_error` on GNNode, $([char]0x2605)/$([char]0x2716) overlay on GNNodeView, self-healing per-frame clear), Layer 2 Textport log panel (GNLogPanel 500-entry ring buffer, GNLogger singleton, debug/info/warn/error levels, filter buttons, color-coded RichTextLabel). `GNCookEngine.editor_mode` flag gates all status tracking $([char]0x2014) exported player builds have zero overhead. WindowOUT fan-out detection warns when two WindowOUTs share the same UI widget. **New: Native Acceleration GDExtension** (`gn_ext_native`) — C++ GDExtension with 92 native operators across 6 families (42 SOP, 23 CHOP, 5 IMG, 4 TOP, 9 VOL, 9 POP) built in 6 phases. GDScript wrapper operators auto-fallback to pure GDScript when C++ binaries are unavailable. Zero preload() calls — all operators registered by class_name. **Viewer panel IMG stability fix** — cached ImageTexture reuse prevents per-frame texture recreation flicker. **COW viewer-aware consumer counts** — cook engine now counts viewer sinks as additional consumers so in-place operators (BlurIMG, PixelSortIMG) properly duplicate upstream data when viewed. Save/load, copy/paste, undo/redo, live node previews with per-node toggle, family base classes, right-click context menu, performance profiling overlay, stress test (59 nodes). GNExtensionRegistry dynamic operator architecture with input-family cache for port-aware filtering. 3D scene pipeline (SOP→MAT→COMP→RenderTOP) live with per-object materials, shadow system, and MergeCOMP scene composition. WindowOUT open/close toggle. Active chain cooking (only cook nodes feeding live sinks). Scripting operators (ScriptCHOP, ScriptDAT, ScriptSOP, ScriptIMG) with runtime GDScript compilation, @param/@input annotations, dynamic ports, presets. IMG family for CPU-side image processing (NoiseIMG, CheckerboardIMG, BlurIMG, EdgeDetectIMG, PixelSortIMG, ImgToTOP bridge) with lightweight text preview (no GPU upload). Drop-wire-to-add-node workflow: drop a wire on empty canvas → filtered palette (only compatible operators) → auto-connect + ghost wire visual. Dynamic palette family iteration from GNFamily.FAMILY_NAMES. Windowed code editor (GNCodeEditor) for Script operators and CustomShaderTOP with syntax highlighting, preset integration, and "Edit ↗" button in param row. Phases 1–6 complete. 204 operators across 8 families (57 TOP, 14 IMG, 52 CHOP, 25 DAT, 39 SOP, 13 COMP, 6 MAT, 1 OUT). New: file save/export operators (ImageSaveOUT/TOP/DAT, MovieOUT, FFmpegOUT, RecordOUT), WebcamIMG, TOPtoIMG bridge. Still-image input operators moved to IMG family (ImageFileInIMG, ImageSequenceIMG) for CPU-first pipeline; video operators stay as TOPs (MovieFileInTOP, FFmpegInTOP) since Godot only exposes decoded frames as GPU textures. Cook-once pulse on Script/CustomShader operators. Clean editor/engine separation — headless execution carries zero UI overhead. **New: RAMP parameter type** with curve editor (cubic Hermite interpolation, GNRampEditor widget, `ramp()` expression function). **New: Canvas annotations** — network boxes and sticky notes for graph organization (GNNetworkBox, GNStickyNote), serialized in .gnpatch files. **New: RampCHOP** — dynamic ramp curve CHOP with 1–16 user-editable ramp slots, multi-sample output, serialization round-trip, `from_dict()` override for dynamic slot restoration. **New: Spare Parameters** added to long-term roadmap (Houdini-style add-any-param-to-any-node). **New: Wire replacement** — connecting to an occupied input auto-disconnects the old wire (with compound undo). **New: Operator palette sections** — sub-sections within family groups (e.g. "Shadertoy" under TOPs) with extension-level auto-section inheritance. **New: PostProcessTOP merged into RenderTOP** — camera/environment post-processing FX (glow, DOF near+far with bokeh, tonemap, SSAO, SSIL, SSR, adjustments, volumetric fog) integrated directly into RenderTOP. **New: Jolt Physics COMPs** — RigidBodyCOMP, StaticBodyCOMP, SoftBodyCOMP, AreaCOMP, JointCOMP for full physics simulation within RenderTOP's isolated World3D. PhysicsCHOP bridge reads back transform/velocity/sleeping state. RenderTOP generic COMP fallback adopts any GNCompBase subclass. **New: Help system example patches** — 1,084 `.gnpatch` example files across all 11 help families providing 3+ visual demos per operator. `test_scenes/` deprecated — help patches replace manual test scenes as the primary visual verification method. **New: 23 additional TOPs** — AnalyzeTOP, CacheTOP, TimeMachineTOP, ChannelMixTOP, ChromaKeyTOP, ColorMapTOP, DepthTOP, FitTOP, LayoutTOP, MonoTOP, NormalMapTOP, SharpenTOP, ConvolutionTOP, CornerPinTOP, DilateErodeTOP, LensDistortTOP, LumaBlurTOP, PatternTOP, ProjectionTOP, RemapTOP, SlopeTOP, SVGTOP, TriangleTOP — closing the TouchDesigner TOP gap. **New: 20 additional CHOPs** — SmoothCHOP, SpringCHOP, DelayCHOP, EnvelopeCHOP, AnalyzeCHOP, ClockCHOP, InterpolateCHOP, LookupCHOP, StretchCHOP, ResampleCHOP, TrimCHOP, ExtendCHOP, JoinCHOP, ShuffleCHOP, SplitCHOP, FanCHOP, DeleteCHOP, CopyCHOP, CompositeCHOP, ExpressionCHOP — signal processing, time manipulation, and channel management. **New: 17 additional SOPs** — NormalSOP, ReverseSOP, PeakSOP, SortSOP, FacetSOP, DeleteSOP, ScatterSOP, MirrorSOP, ClipSOP, ExtrudeSOP, CopySOP, PointSOP, AttributeSOP, BooleanSOP, TubeSOP, SweepSOP, SkinSOP — closing the TouchDesigner SOP/CHOP gap. All utilize Godot features (SurfaceTool, CSGMesh3D, Expression class, RandomNumberGenerator, parallel transport frames). **New: 36 additional operators closing the final TouchDesigner gap** — 6 TOPs (MatteTOP, PremultiplyTOP, PosterizeTOP, RadialBlurTOP, AntiAliasTOP, PaletteTOP), 7 CHOPs (KeyboardInCHOP, MouseInCHOP, GamepadCHOP, ParameterCHOP, TrailCHOP, SOPtoCHOP, TOPtoCHOP), 10 DATs (FileInDAT, JSONDAT, WebDAT, SubstituteDAT, InsertDAT, DeleteDAT, FIFODAT, SOPtoDAT, TOPtoDAT, OPFindDAT), 7 SOPs (BendSOP, TwistSOP, TaperSOP, FontSOP, TrailSOP, UVProjectSOP, DivideSOP), 2 COMPs (NullCOMP, SwitchCOMP), 4 MATs (ConstantMAT, WireframeMAT, PointSpriteMAT, DepthMAT). Total: 204 operators. 7 complex operators deferred to roadmap (ScreenGrabTOP, InstanceCOMP, AnimationCOMP, SpringSOP, ParticleSOP, AudioDeviceOUT). **New: EnvironmentCOMP** — dedicated environment/post-processing COMP (background, ambient, tonemap, glow, SSAO, SSIL, SSR, adjustments, volumetric fog) extracted from RenderTOP. RenderTOP keeps lightweight fallback env (bg color + ambient) when no EnvironmentCOMP is connected; full post-processing requires EnvironmentCOMP. Total: 205 operators (12 COMP). 6 complex operators remain deferred. **New: Advanced Scripting Infrastructure** — GenericScriptNode (family-less multi-output via `# @output` annotations, extends GNNode directly, COMP family for gray color), CallbackDAT (event-driven scripting — observes upstream node signals: `on_start`, `on_cook`, `on_value_change`, `on_create` with rolling event log table), `set_par()` writable parameter references (2-arg self / 3-arg cross-node, auto-dirty-propagation), Network API (`network_add_node`, `network_remove_node`, `network_connect`, `network_disconnect`, `network_node_ids`, `network_node_info`) for procedural graph construction from scripts. All new functions injected into GNScriptHelper preamble — available in every Script operator. Total: 207 operators (13 COMP, 25 DAT). 6 complex operators remain deferred. **New: Main Help Window + Help System Improvements** — (1) GNMainHelpWindow centralized reference hub (sidebar Tree + content pane, Markdown→BBCode via GNMarkdownRenderer), opened via "📖 Help" toolbar button or F1 key, 5 guide .md files in `help/`. (2) Code editor integration fixed for GenericScriptNode + CallbackDAT. (3) 35 preset examples across 7 script/shader categories. (4) CustomShaderTOP GLSL preset folder. (5) Help patch naming convention fixed. (6) Help .md files at `help/` root — folders reserved for operator .gnpatch files. (7) Added Player and Building help sections from dev_docs/ folder content. (8) Renamed `docs/` to `dev_docs/` — developer/advanced docs refocused for contributors. Total: 7 help .md files. **New: 13 advanced operators** — 4 SOP generators (LSystemSOP, MetaballSOP, IsoSurfaceSOP, ParticleSOP), 3 SOP deformers (MagnetSOP, CarveSOP, PolyReduceSOP), 4 cross-family bridges (CHOPtoSOP, DATtoSOP, TOPtoSOP, CHOPtoTOP), 1 COMP (InstanceCOMP — MultiMesh instancing). LSystemSOP: L-System grammar turtle geometry with tube extrusion and taper. MetaballSOP + IsoSurfaceSOP: marching cubes implicit surfaces (shared MC lookup tables). ParticleSOP: CPU particle system with emitter surface, gravity, turbulence, floor collision, attractor. MagnetSOP: vertex attraction/repulsion deformer with 4 falloff modes. CarveSOP: parametric U-range mesh trimming for reveal/wipe. PolyReduceSOP: quadric error metric edge-collapse decimation. CHOPtoSOP/DATtoSOP/TOPtoSOP: cross-family data conversion to geometry. CHOPtoTOP: CPU-rendered waveform/heatmap/graph visualisation. InstanceCOMP: MultiMeshInstance3D instancing with point cloud placement, CHOP animation, per-instance randomisation. InstanceCOMP and ParticleSOP moved from deferred roadmap to implemented. Total: 221 operators (59 TOP, 14 IMG, 52 CHOP, 25 DAT, 50 SOP, 14 COMP, 6 MAT, 1 output). All 4 previously-deferred operators now implemented: ScreenGrabIMG (viewport capture → CPU Image), AnimationCOMP (AnimationPlayer wrapper for keyframe animation on COMP transforms), SpringSOP (damped spring vertex deformer), AudioDeviceOUT (CHOP → AudioStreamGenerator PCM output). Total: 225 operators (59 TOP, 15 IMG, 53 CHOP, 25 DAT, 51 SOP, 15 COMP, 6 MAT, 1 output). Zero deferred operators remain. 16 new help `.gnpatch` example files added for all new operators. **New: 15 TD-parity operators (Tier 1+2)** — 3 TOPs (OpticalFlowTOP Horn-Schunck motion vectors, GlueTOP grid atlas packer, EmbossTOP relief filter shader), 3 CHOPs (BeatCHOP energy-based onset detection, IKCHOP FABRIK inverse kinematics, WarpCHOP time-warp retime), 6 SOPs (FuseSOP spatial-hash vertex merge, RaySOP Möller-Trumbore raycast projection, CapSOP boundary-hole triangle fan cap, LatticeSOP FFD trilinear lattice deformer, PolyLoftSOP cross-section lofting, MountainSOP noise vertex displacement), 2 DATs (TableDAT manual CSV editor, NetworkDAT TCP/UDP via Godot StreamPeerTCP/PacketPeerUDP), 1 COMP (ReplicatorCOMP table-driven replicator with hash change detection). Total: 288 operators (63 TOP, 12 IMG, 61 CHOP, 29 DAT, 57 SOP, 20 COMP, 6 MAT, 9 OUT, 31 UI). 1,014 core help `.gnpatch` example files (197 CHOP, 198 TOP, 188 SOP, 104 DAT, 61 COMP, 27 MAT, 39 IMG, 28 OUT, 99 UI, 35 POP, 34 VOL, 4 bridge) + 70 extension patches = 1,084 total — 3+ patches per operator, ALL ending with WindowOUT (512×512, open=true) via meaningful family-appropriate visualization chains per Hard Rule 25.22. Zero deferred operators remain. **New: UI family — interactive 2D widgets** — Separated-context architecture: interactive panels wire to WindowOUT panel port (SubViewportContainer-based native input), render-to-texture panels wire through PanelTOP → TOP chain (pixels only). GNUiBase base class (extends GNNode, manages `_control_node: Control`). 31 UI widgets (8 original: ButtonUI, SliderUI, ToggleUI, LabelUI, KnobUI, XYPadUI, DropdownUI, ContainerUI; 23 new across 4 tiers: TextureRectUI, ColorRectUI, LineEditUI, TextEditUI, ProgressBarUI, SpinBoxUI, ColorPickerUI, RichTextLabelUI, ScrollContainerUI, TabContainerUI, SplitContainerUI, MarginContainerUI, PanelContainerUI, TreeUI, ItemListUI, TabBarUI, MenuButtonUI, CheckBoxUI, TextureButtonUI, SeparatorUI, NinePatchRectUI, LinkButtonUI, TextureProgressBarUI). GNPanelSource deprecated — panel_sources removed from GNTextureData and all TOPs. WindowOUT has two input ports: port 0 (TOP, background texture), port 1 (UI, interactive panel with SubViewportContainer). PanelTOP is render-to-texture only (non-interactive), with CHOP output for widget state. Total: 288 operators (63 TOP, 12 IMG, 61 CHOP, 29 DAT, 57 SOP, 20 COMP, 6 MAT, 9 OUT, 31 UI). **RenderTOP pass-through COMP resolution** — `_resolve_comp_scene_node()` walks upstream through pass-through COMPs (NullCOMP, SwitchCOMP, AnimationCOMP) to find scene nodes; AnimationCOMP now sets `_scene_node` from upstream during cook. **TouchDesigner parity: ~80% surface coverage** — deep audit confirmed many "gaps" are false (GONODES operators cover multiple TD equivalents under different names). Key equivalences: CompositeTOP covers Under/Multiply/Screen/Overlay/Add/etc. (blend modes), ChannelMixTOP covers Reorder (channel swizzle), LevelTOP covers Threshold/Contrast/Gamma, BlurTOP covers DirectionalBlur via kernel_size param, ResampleCHOP covers Speed (playback rate), MergeCHOP covers Join (concatenation mode). **Roadmap: GPU Particles (POP family)** -- IMPLEMENTED (section 35). 10 POP operators + 7 GLSL compute shaders. SSBO-based GPU particle system (GNPopBase), GNGpuContext singleton, ParticleStateTOP bridge. **Roadmap: Volumetric 3D Textures (VOL family)** -- IMPLEMENTED (section 35). 10 VOL operators + 11 GLSL compute shaders. 3D texture volumes (GNVolBase), Navier-Stokes fluid sim, marching cubes, raymarcher, POP-VOL advection. Total: 348 operators (81 TOP, 14 IMG, 68 CHOP, 33 DAT, 62 SOP, 10 POP, 11 VOL, 20 COMP, 9 MAT, 9 OUT, 31 UI). 11 families. 11 GDExtension addons (native, shadertoy, isf, ffmpeg, hap, spout, syphon, video_capture, midi, gpu_encode, mapper). **Roadmap: Custom Operator Assets (.gnasset) — IMPLEMENTED.** GNCustomOperator runtime class (extends SubNetworkNode) with `load_from_asset()`, parameter proxying, compact serialization. GNAssetPromotionDialog wizard for identity + promoted param selection. `scan_custom_assets()` called at startup in editor and player. Scanned from 3 directories: `res://addons/gonodes/assets/`, `res://custom_operators/`, `user://gonodes_assets/`. **Roadmap: Spare Parameters — IMPLEMENTED.** Houdini-style add-any-param-to-any-node system: `spare_parameters` Dictionary on GNNode, `add_spare_parameter()`/`remove_spare_parameter()`, inspector "Spare Parameters" collapsible section, full serialization in .gnpatch, types: Float, Int, Bool, String, Color, Vector2, Vector2i. **New: MultiBufferRenderTOP** — 3-output RenderTOP variant (color, depth, normal) with secondary SubViewports sharing primary's World3D. **New: CI Pipelines for Native Builds** — Unified build system: `build/gn_build.py` shared module + declarative `build.cfg` per extension + `build/SConstruct` root orchestrator. GitHub Actions (`.github/workflows/build-extensions.yml`) with dynamic matrix discovery + GitLab CI (`.gitlab-ci.yml`) for 5 platform targets: Linux x86_64, Linux ARM64 (cross-compile), macOS universal (lipo), Windows x86_64, Windows ARM64. Auto-discovers any extension with `native/build.cfg` — no workflow edits needed when adding new extensions. Per-extension SConstructs are thin 6-line shims delegating to `gn_build.py`. **New: ARM64 GDExtension Support** — `gn_native.gdextension` expanded with ARM64 paths for Linux + Windows. **New: Debug Window & Overlay System** — F2 toggles docked debug panel (3 tabs: Cook Chain table with topo order/status/cook time, Active Chains tree rooted at sinks, Parameter References with expression cross-refs and set_par() writes, click-to-select navigates graph). Graph overlay with 5 independently toggleable layers: cook order badges (#N), active chain dimming (40% opacity on inactive nodes), dirty propagation flash (orange border on nodes dirtied this frame, fades over ~0.3s), sink labels (colored halo rings + upstream dots), data flow annotations (data dimensions on wires — resolution for TOP/IMG, channel count×length for CHOP, vertex count for SOP, rows×cols for DAT). `GNDebugPanel` (docked tabs, ui/), `GNDebugOverlay` (canvas overlay, ui/), `last_topo_order` exposed on GNCookEngine. Respects editor/engine separation — all UI in ui/, reads from engine's existing public properties.

---

## 1. Project Overview

**GONODES** is a real-time node-based visual programming framework built on Godot 4.6, inspired by Derivative TouchDesigner. It targets **visual/generative art and VJing** workflows.

### Key Differentiator

GONODES uses **LibGodot** (Godot 4.6's embeddable engine library) as its portability layer. This means:
- The GONODES editor is a full Godot application
- For embedding in host apps (VDMX, Resolume, etc.), LibGodot is embedded in the host process
- The same GONODES framework code (GDExtension) runs in both contexts
- Godot's renderer, audio, compute, and physics systems are available everywhere
- This follows the same model as VUO patches embedded in VDMX via FxPlug

---

## 2. Architecture Decisions (Locked In)

| Decision               | Choice                                              |
|------------------------|-----------------------------------------------------|
| Engine                 | Godot 4.6 (with LibGodot)                           |
| Primary Language       | GDScript (GDExtension/C++ for hot paths later)      |
| Patch Format (MVP)     | Godot Resource (.tres)                              |
| Patch Format           | JSON (.gnpatch) for cross-app portability — IMPLEMENTED |
| Project Name           | GONODES                                             |
| Target Use Case        | Visual/generative art, VJing                        |
| Priority OP Families   | TOPs (textures) and CHOPs (channels/signals) first  |
| MVP Scope              | Node graph UI + LFO CHOP driving a Noise TOP        |
| MVP Timeline           | 4–6 weeks                                           |
| I/O Protocols          | Spout, OSC, MIDI, Audio OUT — IMPLEMENTED; NDI planned |
| Runtime Model          | Standalone app + LibGodot embedding in host apps     |
| Dev Strategy           | GDScript-first, GDExtension for perf optimization   |
| Editor Platforms       | Windows, macOS, Linux (no ARM devices for editor)    |
| Export Targets         | All Godot-supported platforms (incl. mobile/web)     |
| Renderer Selection     | Automatic: Forward+ with fallback to Compatibility   |
| Param References       | Cross-node parameter/data referencing (like TD)      |

---

## 3. High-Level Architecture

```
├──────────────────────────────────────────────────┐
│  GONODES Editor (Godot 4.6 Application)          │
│                                                  │
│  ├─────────────────────────────────────────────┐ │
│  │  UI Layer                                   │ │
│  │  GraphEdit canvas, Inspector panel,         │ │
│  │  Viewer windows, Node palette, Timeline     │ │
│  ├─────────────────────────────────────────────┤ │
│  │  GNExtensionRegistry                        │ │
│  │  Core operators + gn_ext_* addon operators  │ │
│  │  Dynamic factory, descriptions, manifests   │ │
│  ├─────────────────────────────────────────────┤ │
│  │  Operator Library                           │ │
│  │  Built-in TOPs, CHOPs, SOPs, DATs, MATs     │ │
│  │  Each is a GNNode subclass with cook()      │ │
│  ├─────────────────────────────────────────────┤ │
│  │  Cook Engine                                │ │
│  │  DAG traversal, dirty propagation,          │ │
│  │  lazy evaluation, caching                   │ │
│  ├─────────────────────────────────────────────┤ │
│  │  Node Graph Model                           │ │
│  │  GNNetwork, GNNode, GNConnection, GNPort    │ │
│  │  Type system, serialization                 │ │
│  ├─────────────────────────────────────────────┤ │
│  │  Data Types                                 │ │
│  │  GNTextureData, GNChannelData, GNGeoData,   │ │
│  │  GNTableData, GNMaterialData                │ │
│  ├─────────────────────────────────────────────┤ │
│  │  Godot Engine (renderer, audio, compute)    │ │
│  └─────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────┘

Embedding Model (libgonodes — IMPLEMENTED):
├──────────────────────────────────────────────┐
│  Host App (VDMX, Resolume, custom C/C++)     │
│  ├────────────────────────────────────────┐  │
│  │ libgonodes.so/dll (C API)              │  │
│  │  ├─ gonodes_bootstrap (loads LibGodot) │  │
│  │  ├─ gonodes_host (30+ API functions)   │  │
│  │  └─ GNEmbeddedHost (GDScript bridge)   │  │
│  │  + GONODES Framework (GDExtension)     │  │
│  └────────────────────────────────────────┘  │
│  GPU context sharing: Vulkan/Metal/OpenGL    │
│  Host feeds data in → HostIn{TOP,CHOP,DAT}  │
│  ← reads textures out  HostOut{TOP,CHOP,DAT}│
│  Loads .gnpatch via API, hot-reload capable  │
│  5 example host apps (SDL, Vulkan, GLFW,     │
│  Metal, headless params demo)                │
└──────────────────────────────────────────────┘
```

---

## 4. TouchDesigner → GONODES Concept Mapping

| TouchDesigner         | GONODES Implementation                                   |
|-----------------------|----------------------------------------------------------|
| Operator (OP)         | `GNNode` (Node subclass) with `cook()` method             |
| TOP (Texture OP)      | `GNTopBase` — SubViewport + ShaderMaterial (infra in base class) |
| CHOP (Channel OP)     | `GNChopNode` — processes named float arrays              |
| SOP (Surface OP)      | `GNSopNode` — produces ArrayMesh via GNGeoData           |
| POP (Point OP)        | `GNPopBase` — GPU particle/point cloud via SSBO compute          |
| VOL3D (Volume OP)     | `GNVol3DData` — 3D texture ops via compute shaders               |
| DAT (Data OP)         | `GNDatNode` — tables/text via GNTableData                |
| MAT (Material OP)     | `GNMatNode` — PBR or custom ShaderMaterial               |
| COMP (Component OP)   | `GNCompNode` — 3D scene components (Camera, Light, Geo)  |
| Network / Canvas      | `GNNetwork` (Resource) displayed in `GraphEdit`          |
| Wire / Connection     | `GNConnection` — typed, family-checked                   |
| Cook / Evaluate       | `GNCookEngine` — topological DAG walk + dirty flags      |
| Parameter Reference   | GDScript expression evaluated at cook time               |
| Timeline              | Godot `_process()` driving cook engine each frame        |
| Parameter             | `GNParameter` — typed value with optional expression     |
| Param References      | `op("name").par.X` / `chop("name").value("ch")` syntax   |
| Patch Export           | Godot export system → standalone runnable per platform   |

---

## 5. Core Data Types

### GNData (Base)
```
GNData (RefCounted)
├── valid: bool
├── timestamp: int (cook frame)
├── _shared: bool (set by cook engine — true when output feeds 2+ consumers)
└── type() -> GNFamily
```

**Copy-on-Write (COW) data sharing:** Node outputs are shared by reference. When a node's output feeds multiple downstream consumers (fan-out), the cook engine sets `_shared = true` on the output data. Operators that need to **mutate** input data must call `_mutable_input(data)` (on GNNode) which duplicates only when `_shared` is true — zero-copy for single-consumer chains. The `_consumer_counts` dictionary in GNCookEngine is rebuilt from connection topology only when wires or viewer targets change (not per-frame). **Viewer-aware consumer counts:** The viewer panel reads `cached_output` outside the data-flow graph — effectively an invisible consumer. `_rebuild_consumer_counts()` now also counts each viewer sink's upstream inputs as additional consumers, ensuring `_shared = true` when a node is being viewed *and* its output is consumed by a downstream in-place operator. Without this, operators like PixelSortIMG would mutate NoiseIMG's `cached_output` in-place (since the wire-only consumer count = 1), causing the viewer to show the same mutated image regardless of which node is selected.

**Example — BlurIMG:** A NoiseIMG fans out to both BlurIMG and PixelSortIMG. BlurIMG needs to modify pixels in-place (sliding-window accumulator). It calls `_mutable_input(src)` which sees `_shared = true` (two consumers) and returns a duplicate — BlurIMG blurs its own copy, PixelSortIMG gets the original untouched. If NoiseIMG only fed BlurIMG (no fan-out), `_mutable_input()` returns the original — zero copy, BlurIMG modifies it directly.

**TOPs are immune:** Each TOP renders into its own SubViewport, producing a fresh GPU texture every cook. Downstream TOPs sample that texture via shader `uniform sampler2D` — inherently read-only. No downstream TOP can mutate an upstream TOP's framebuffer, so COW is unnecessary for the GPU pipeline.

**Affected families:** IMG (Image pixels), SOP (mesh arrays), CHOP (channel arrays), DAT (table rows), MAT (Material properties) — all CPU-side heap objects passed by reference in GDScript.

**Built-in operators** use `_mutable_input()` when they need to modify input data (e.g., BlurIMG, PixelSortIMG). **Script operators** do NOT auto-copy — if user code mutates `inputs[0]` directly at a fan-out point, it will corrupt upstream data. Users must `duplicate()` manually (see §27.3.3).

### GNTextureData (TOP output)
```
GNTextureData extends GNData (RefCounted)
├── texture: Texture2D (result of SubViewport rendering)
├── viewport: SubViewport (owned by the TOP node)
├── resolution: Vector2i
└── format: Image.Format
```

### GNChannelData (CHOP output)
```
GNChannelData extends GNData (RefCounted)
├── channels: Dictionary[String, PackedFloat32Array]
│   e.g., {"tx": [0.0, 0.1, ...], "ty": [...], "tz": [...]}
├── sample_rate: float
├── length: int (number of samples)
└── get_channel(name: String) -> PackedFloat32Array
└── get_value(channel: String, index: int = -1) -> float
    (index=-1 returns last sample, useful for single-value CHOPs)
```

### GNTableData (DAT output)
```
GNTableData extends GNData (RefCounted)
├── is_table: bool           # true = 2D table mode, false = plain text mode
├── headers: PackedStringArray
├── rows: Array[PackedStringArray]
├── text: String             # Plain text content (text mode only)
├── cell(row, col) -> String
├── cell_by_name(row, col_name) -> String
├── cell_as_float(row, col) -> float
├── set_headers(headers: PackedStringArray)
├── append_row(row: PackedStringArray)
├── set_text(text: String)
├── to_tsv() -> String       # Export as tab-separated values
└── from_tsv(tsv: String)    # Import from tab-separated values
```

### GNGeoData (SOP output)
```
GNGeoData extends GNData (RefCounted)
├── mesh: ArrayMesh          # Godot native mesh — the actual geometry
├── transform: Transform3D   # Object-space transform
├── bounds: AABB             # Bounding box
├── vertex_count: int
├── point_attribs: Dictionary # Custom per-point attributes
├── set_surface_arrays(arrays: Array, primitive: Mesh.PrimitiveType)
├── set_from_surface_tool(st: SurfaceTool)
├── set_mesh(primitive_mesh: PrimitiveMesh)  # Copy from Godot PrimitiveMesh
├── get_positions() -> PackedVector3Array
├── get_normals() -> PackedVector3Array
├── get_uvs() -> PackedVector2Array
└── has_geometry() -> bool
```

GNGeoData wraps Godot's native `ArrayMesh`, leveraging Godot's built-in mesh types (`BoxMesh`, `SphereMesh`, `CylinderMesh`, `TorusMesh`) via `set_mesh()` and Godot's `SurfaceTool` for procedural generation.

### GNMaterialData (MAT output)
```
GNMaterialData extends GNData (RefCounted)
├── material: Material       # Godot Material base class (StandardMaterial3D, ShaderMaterial, etc.)
├── material_label: String   # Human-readable label for UI preview (e.g., "PBR", "Shader: custom_toon")
├── get_family() -> MAT
├── invalidate()             # Clears material and label
└── duplicate_data() -> GNData  # Deep-copies Material resource
```

GNMaterialData wraps Godot's `Material` base class, allowing any material type (StandardMaterial3D, ShaderMaterial, ORMMaterial3D) to flow through the graph. MAT operators produce GNMaterialData, which GeometryCOMP consumes as an optional material override.

---

## 6. Operator Base Class

### GNNode (Root Base)

GNNode is **fully type-agnostic** — it contains no references to any family-specific data types. Preview dispatch lives in GNNode itself, keyed on the **actual output data type** (not the family). This means cross-family nodes (e.g. a VOL operator outputting a texture, or a POP operator outputting SOP geometry) automatically get the correct preview without per-node overrides.

```gdscript
class_name GNNode extends Node

enum GNFamily { TOP, CHOP, SOP, POP, DAT, MAT, COMP }

# Identity
var id: String                     # Unique ID within network
var node_type: String              # e.g., "noise", "lfo", "composite"
var family: GNFamily               # Which OP family

# Ports
var input_ports: Array[GNPort]     # Defined by subclass
var output_ports: Array[GNPort]    # Defined by subclass

# Parameters
var parameters: Dictionary         # name -> GNParameter

# Cook state
var dirty: bool = true
var cached_output: GNData = null
var cook_time_ms: float = 0.0      # Profiling
var cook_valid: bool = false
var time_dependent: bool = false    # Always dirty each frame (LFO, Noise, etc.)

# Active chain cooking
var is_sink: bool = false           # True for output operators (WindowOUT, SpoutOut, MIDIOut, etc.)
                                    # Set by operator in _init(). Engine auto-detects these as sinks.
var is_active: bool = true          # Set by cook engine per frame. False = skip cooking.
                                    # Inactive nodes keep cached_output frozen.

# Timing (injected by GNCookEngine before each cook)
var current_delta: float = 0.0     # Frame delta in seconds
var elapsed_time: float = 0.0      # Total time since engine start
var current_frame: int = 0         # Frame counter

# UI metadata (stored but not used by cook engine)
var graph_position: Vector2 = Vector2.ZERO

# Interface
func _init_ports() -> void: pass          # Override: define ports
func _init_parameters() -> void: pass     # Override: define params
func _cook(inputs: Array[GNData]) -> GNData: return null  # Override: produce output
func _mutable_input(data: GNData) -> GNData: ...  # COW: duplicates only if data._shared
func get_input(index: int) -> GNData: ...  # Resolved by cook engine
func mark_dirty() -> void: ...             # Propagates downstream

# Preview — output-type dispatch (in GNNode base class)
# create_preview_control() checks first output port family:
#   TOP → TextureRect,  everything else → Label
# update_preview_control() dispatches on cached_output type:
#   GNTextureData → texture thumbnail
#   GNChannelData → channel:value pairs
#   GNGeoData     → vertex/surface counts
#   GNTableData   → header + first 3 rows
#   GNImageData   → resolution + format
#   GNParticleData → particle count
#   GNVolumeData  → resolution + field name
#   GNMaterialData → material label
# For multi-output nodes, port 0 (cached_output) is previewed;
# use a Null node to inspect other outputs.
func create_preview_control() -> Control: ...   # Output-type TextureRect or Label
func update_preview_control(ctrl: Control) -> void: ...  # Output-type dispatch

### Family Base Classes

Eleven intermediate base classes sit between GNNode and the individual operators. Each sets the `family` and provides family-specific helpers. **Preview logic is NOT in the family bases** — GNNode handles all preview dispatch based on the actual output data type. Family bases only override `update_preview_control()` when they have non-data state to display (COMP: `_scene_node`, UI: `_control_node`, OUT: sink status).

| Base Class | Family | Cached Data | Preview Override? | Helpers |
|------------|--------|-------------|-------------------|--------|
| `GNTopBase` | TOP | `_viewport`, `_material`, `_canvas`, `_cached_tex_data` | No (GNNode handles GNTextureData) | `_get_input_top()`, `_create_viewport()`, `_ensure_viewport()`, `_init_shader_viewport()`, `execute_cook()` |
| `GNImgBase` | IMG | `_cached_image_data: GNImageData` | No (GNNode handles GNImageData) | `_prepare_image()`, `_get_input_img()` |
| `GNChopBase` | CHOP | `_cached_channel_data: GNChannelData` | No (GNNode handles GNChannelData) | `_prepare_output(sr)`, `_get_input_chop()` |
| `GNDatBase` | DAT | `_cached_table: GNTableData` | No (GNNode handles GNTableData) | `_prepare_table(clear)`, `_get_input_dat()` |
| `GNSopBase` | SOP | `_cached_geo: GNGeoData` | No (GNNode handles GNGeoData) | `_prepare_geo()`, `_get_input_sop()`, `_require_input_geo()` |
| `GNPopBase` | POP | SSBO via `_allocate_particles()` | No (GNNode handles GNParticleData) | `_get_input_pop()`, `_allocate_particles()`, compute helpers |
| `GNVolBase` | VOL | 3D texture via `_create_volume()` | No (GNNode handles GNVolumeData) | `_get_input_vol()`, `_create_volume()`, workgroups helpers |
| `GNCompBase` | COMP | `_scene_node: Node3D` | Yes (`_scene_node` state) | auto `_notification(PREDELETE)` cleanup, `get_scene_node()` |
| `GNMatBase` | MAT | `_cached_mat_data: GNMaterialData` | No (GNNode handles GNMaterialData) | `_prepare_output()` |
| `GNOutBase` | OUT | (sink — no output) | Yes ("sink" status label) | `is_sink = true` |
| `GNUiBase` | UI | `_control_node: Control` | Yes (`_control_node` + `widget_state`) | `_create_control()`, widget APIs |

**Class Hierarchy:**
```
GNNode (type-agnostic base)
├── GNTopBase (30 TOP operators)
├── GNImgBase (7 IMG operators)
├── GNChopBase (23 CHOP operators, incl. DATtoCHOP bridge, RampCHOP)
├── GNDatBase (13 DAT operators)
├── GNSopBase (15 SOP operators)
├── GNCompBase (4 COMP operators)
└── GNMatBase (6 MAT operators)
```

**GNTopBase** provides the shared viewport/texture infrastructure used by all TOP operators:
- **`_viewport: SubViewport`** — primary render viewport (null until first cook).
- **`_material: ShaderMaterial`** — shader material applied to the canvas (null for non-shader TOPs like Text, Movie).
- **`_canvas: Control`** — a `ColorRect` (generators) or `TextureRect` (filters) that fills the viewport.
- **`_cached_tex_data: GNTextureData`** — reusable output data wrapping the viewport texture.
- **`_create_viewport()`** — factory that creates a SubViewport with `UPDATE_DISABLED` and sensible defaults.
- **`_ensure_viewport(size)`** — lazily creates `_viewport` + `_cached_tex_data`. Used by custom TOPs (Constant, Text, Blur, etc.).
- **`_init_shader_viewport(shader_path, transparent_bg, use_texture_rect, size)`** — full pipeline setup: SubViewport → ShaderMaterial → canvas → GNTextureData. Used by the 17 standard shader TOPs.
- **`execute_cook()`** — overrides GNNode to trigger `UPDATE_ONCE` on all child SubViewports after `_cook()` completes, eliminating wasted GPU work on non-dirty frames.

Generator TOPs pass `get_param_value("resolution")` as the viewport size. Filter TOPs pass `tex_in.resolution` (matching their input). No hardcoded sizes.

**GNImgBase** provides the CPU-side image infrastructure used by all IMG operators:
- **`_cached_image_data: GNImageData`** — reusable output data wrapping the CPU Image.
- **`_prepare_image()`** — lazily creates `_cached_image_data`. Operators write a new Image into it via `set_image()`.
- **`_get_input_img(inputs, port)`** — safely extracts `GNImageData` from inputs.
- **Preview** — creates `TextureRect`, uploads Image to `ImageTexture` on-the-fly during `update_preview_control()`.
- **No SubViewport** — no `execute_cook()` override needed, uses GNNode's default cook cycle.

**ImgToTOP** extends `GNTopBase` (not GNImgBase) because its output is TOP texture data. Overrides `execute_cook()` to skip the SubViewport render logic.

**DATtoCHOP** extends `GNChopBase` (not GNDatBase) because its output is CHOP channel data.

### Node Lifecycle
- `_init()` — set `node_type`, `family`, `time_dependent`, `is_sink` (runs before entering tree)
- `initialize(id)` — sets `name = id`, `process_mode = DISABLED`, calls `_init_ports()` / `_init_parameters()`
- Processing is disabled on GNNodes — only the cook engine drives cooking
- TOPs add SubViewport as `add_child()` during first `_cook()` — auto-freed on removal
- `execute_cook()` (GNTopBase override) — after `_cook()` completes, sets `UPDATE_ONCE` on all child SubViewports so they render exactly once per cook cycle
- CookEngine adopts all network nodes as children via `add_child()` in `_ready()`
- During adoption, CookEngine connects `parameter_changed` signal per node + topology signals (`node_added`, `node_removed`, `connection_added`, `connection_removed`) to invalidate the active chain set
- `queue_free()` cascades to SubViewport/Window children (no manual cleanup needed)

---

## 7. Port System

```gdscript
class_name GNPort extends RefCounted

var port_name: String
var family: GNNode.GNFamily    # Type of data this port accepts/produces
var index: int                 # Port index on the node
var is_input: bool
var multi_input: bool = false  # DEPRECATED — use dynamic input ports instead
```

### Connection Rules
- Ports can only connect within the same family (TOP→TOP, CHOP→CHOP)
- Exception: Bridge operators (CHOPtoTOP, TOPtoCHOP) have mixed port types
- One output can connect to many inputs (fan-out)
- Each input port accepts exactly one connection
- **Dynamic input ports** — Operators like MergeCOMP, MergeSOP, and RenderTOP use auto-growing numbered ports: connecting to the last empty port automatically adds a new empty slot; disconnecting collapses trailing empties
- No cycles allowed (DAG enforcement)

### Family Colors (UI)
| Family | Color        |
|--------|-------------|
| TOP    | Purple      |
| IMG    | Teal        |
| CHOP   | Green       |
| SOP    | Blue        |
| POP    | Cyan        |
| VOL    | Rose        |
| DAT    | Yellow      |
| MAT    | Red/Orange  |
| COMP   | Gray        |
| UI     | Sky Blue    |
| OUT    | Red         |

---

## 8. Network & Cook Engine

### GNNetwork
```gdscript
class_name GNNetwork extends Resource

var nodes: Dictionary = {}            # id -> GNNode
var connections: Array[GNConnection] = []

signal node_added(node_id: String)
signal node_removed(node_id: String)
signal connection_added(connection: GNConnection)
signal connection_removed(connection: GNConnection)
signal node_renamed(old_id: String, new_id: String)
signal graph_changed()

func add_node(node: GNNode) -> bool
func remove_node(id: String) -> bool
func rename_node(old_id: String, new_id: String) -> bool
func connect_nodes(from_id: String, from_port: int,
                   to_id: String, to_port: int) -> bool
func disconnect_nodes(from_id: String, from_port: int,
                      to_id: String, to_port: int) -> void
func get_topological_order() -> Array[GNNode]
func get_upstream_nodes(id: String) -> Array[GNNode]
func get_downstream_nodes(id: String) -> Array[GNNode]
func has_cycle() -> bool
func generate_unique_id(base_type: String) -> String
func prune_stale_connections(node_id: String) -> void

# Canvas annotations (network boxes & sticky notes)
var annotations: Array[Dictionary] = []
signal annotations_changed()

func add_annotation(ann_type: String, position: Vector2,
    size: Vector2, text: String, color: Color) -> String
func get_annotation(ann_id: String) -> Variant
func update_annotation(ann_id: String, changes: Dictionary) -> void
func remove_annotation(ann_id: String) -> bool
```

**Annotations** provide canvas-level organization (like TouchDesigner's network boxes and sticky notes). Each annotation is a Dictionary with `{id, type, position, size, text, color}`. Serialized in `.gnpatch` files as `annotations` array. Counter-based unique IDs (`ann_1`, `ann_2`, …) restored on load to avoid collisions.

**`GNNetworkBox`** (extends Control) — colored rectangle drawn behind graph nodes (`z_index = -10`) for visual grouping. Title bar with inline edit (double-click), drag-move, bottom-right resize handle, right-click context menu (Rename, Change Color, Delete). Signals: `box_changed`, `text_changed`, `delete_requested`, `color_changed`.

**`GNStickyNote`** (extends Control) — editable text note on the canvas (`z_index = -9`). Multi-line text display, inline TextEdit (double-click), drag-move, resize, right-click context menu (Edit Text, Change Color, Delete). Default yellow color. Signals: `note_changed`, `text_changed`, `delete_requested`, `color_changed`.

**`rename_node()` updates:** nodes dictionary key, `GNNode.id`, `GNNode.name`, all `GNConnection.from_node`/`to_node` references, and expression strings across all parameters in the network via regex-based path-segment replacement (`_update_expressions_for_rename()`). The rename engine handles:
- **Main expressions** on every parameter in EXPRESSION mode
- **Per-component expressions** (Vector2/3/4, Color) — recompiled after text replacement
- **Script operator code** (`scriptchop`, `scriptdat`, `scriptsop`, `scriptimg`, `genericscript`) — the `code` parameter's GDScript source is scanned and updated
- **CallbackDAT callback slots** (`on_start`, `on_cook`, `on_value_change`, `on_create`)
- **Hierarchical paths** — `"subnet1/old_id"` → `"subnet1/new_id"` via per-segment matching (splits by `/`, replaces exact segments only)
- **All reference functions** — `chop[sfi]()`, `op()`, `top()`, `sop()`, `dat()`, `mat()`, `vol()`, `img()`, `output()`, `par[sfi]()`, `set_par()`

Validates: alphanumeric/underscore only, no duplicates, no empty. Emits `node_renamed` then `graph_changed`.

### GNConnection
```gdscript
class_name GNConnection extends RefCounted

var from_node: String    # GNNode id
var from_port: int       # Output port index
var to_node: String      # GNNode id
var to_port: int         # Input port index
```

### GNCookEngine
```gdscript
class_name GNCookEngine extends Node

var network: GNNetwork
var frame_count: int = 0

# Active chain cooking state
var active_sinks: Array[String] = []    # UI-level sinks (viewer, floating windows)
var _active_set: Dictionary = {}        # { node_id: true } — cached active node set
var _active_set_dirty: bool = true      # Recompute on next cook frame
var _expr_resolved_this_frame: Dictionary = {}  # { node_id: true } — prevents double expression eval
static var _expr_ref_regex: RegEx       # Regex for chop()/op()/top()/sop()/dat()/mat()/vol()/img()/output() refs

func _process(delta: float) -> void:
    cook_frame(delta)

func cook_frame(delta: float) -> void:
    # 1. _pre_cook_pass — mark time-dependent nodes dirty
    # 2. Get topological order (Kahn's BFS, cached by GNNetwork)
    # 3. Propagate dirty flags downstream in one BFS pass
    # 3b. If _active_set_dirty: recompute active set, stamp node.is_active
    # 4. Cook dirty+active nodes in topo order (skip inactive)
    #    - Clear _expr_resolved_this_frame
    #    - For non-dirty active nodes: _try_expression_dirty() evaluates
    #      expressions cheaply and only marks dirty if values changed
    #    - Inject timing (current_delta, elapsed_time, current_frame)
    #    - Resolve parameters (expressions, binds, exports)
    #      (skips re-eval if _expr_resolved_this_frame[node.id] set)
    #    - Gather inputs from upstream cached_output
    #    - Handle bypass (pass-through first input)
    #    - Call node.execute_cook(inputs, frame)
    # 5. Process export mappings (CHOP exports, post-MVP stub)
    # 6. Frame bookkeeping — increment frame_count, emit frame_cooked

# Expression change detection — avoids unnecessary cooks
func _try_expression_dirty(node: GNNode) -> bool:
    # For clean (non-dirty) nodes that have expression parameters:
    # 1. Save old resolved_value for each expression param
    # 2. Inject timing context + evaluate expressions (_resolve_node_parameters)
    # 3. Compare new resolved_value vs old for each expression param
    # 4. If any changed → mark_dirty(), return true
    # 5. If none changed → return false (node stays clean, skips cooking)
    # This keeps expression evaluation cheap (just GDScript Expression.execute())
    # while avoiding the full _cook() when upstream CHOP values haven't changed.

# Active chain cooking — finds all nodes feeding live sinks
func _compute_active_set() -> Dictionary:
    # 1. Seed queue with active_sinks (UI viewers)
    # 2. Auto-detect structural sinks (node.is_sink == true)
    # 3. Fallback: if no sinks found, all nodes are active
    # 4. BFS upstream following:
    #    a. Wire connections (get_input_connections — cached adjacency)
    #    b. Expression references (chop/op/top/sop/dat/mat regex scan)
    # Returns { node_id: true } dict

# Expression reference extraction (engine-level, no editor dependency)
func _get_expression_refs(node_id: String) -> Array[String]:
    # Scans all parameters of the node for expression-mode strings
    # Regex extracts node IDs from chop("id")/op("id")/top("id") etc.
    # Returns list of referenced node IDs (excludes self-references)

# Invalidation signals (wired during _adopt_network_nodes):
#   network.node_added      → _active_set_dirty = true + adopt
#   network.node_removed    → _active_set_dirty = true
#   network.connection_added/removed → _active_set_dirty = true
#   node.parameter_changed  → _active_set_dirty = true (per-node)
#   set_active_sinks()      → _active_set_dirty = true (from editor)
```

### Cook Architecture: Demand-Driven Flat Pass

GONODES uses a **demand-driven flat-pass** cook model — a hybrid that achieves the lazy semantics of pull-based systems (Houdini, TouchDesigner) while executing as a single linear sweep instead of recursive descent.

**Comparison with other systems:**

| Feature | Pure Push (vvvv) | Pure Pull (Houdini/TD) | **GONODES** |
|---------|-----------------|------------------------|-------------|
| Cook trigger | Any input change | Sink demands output | Frame tick (like TD) |
| What gets cooked | Everything downstream | Only upstream of requester | **Only dirty + active nodes** |
| Inactive subgraphs | Cooked anyway | Never touched | **Skipped** (active chain) |
| Clean nodes | Re-cooked | Skipped | **Skipped** (dirty flag) |
| Time-dependent | All re-cook | Only if demanded | Only if `is_time_dependent` |
| Execution model | Event cascade | Recursive descent | **Linear topo-sorted pass** |

**Why not pure pull?** In a pull system, each node's `_cook()` recursively calls `input.cook()` on demand — the call stack depth mirrors the dependency chain length. GONODES instead does a single linear pass over the topo-sorted dirty+active list. Advantages:

- **No deep recursion** — pull systems can stack-overflow on deep chains (hundreds of nodes). Linear pass has O(1) stack depth.
- **Predictable timing** — one pass, no re-entrant cook calls, easier to profile.
- **Batch-friendly** — all SubViewport renders happen in topo order within the same frame (`_reorder_children_to_topo` ensures GPU render order matches dependency order).

**Why not pure push?** Push systems (vvvv, early dataflow engines) propagate immediately on any input change, cooking every downstream node whether its output is consumed or not. GONODES avoids this via the active chain — only nodes feeding a live sink (viewer, WindowOUT, `is_sink` operator) are cooked. Disconnected subgraphs are completely inert.

**The result:** GONODES achieves the same work-avoidance as a pull system (skip inactive, skip clean, skip non-time-dependent) but with the execution simplicity and GPU-friendliness of a flat forward pass.

### Cook Semantics
- **Time-dependent nodes** (LFO, Noise with `time` param) are always dirty.
- **Parameter-changed nodes** are marked dirty when a parameter changes.
- **Input-changed nodes** are marked dirty via `propagate_dirty()`.
- **Expression nodes** are evaluated every frame, but **only cook if a resolved value actually changed** (`_try_expression_dirty()`). This means a node using `chop("slider1", "slider1:value")` will evaluate the expression cheaply each frame but avoid a full `_cook()` when the slider hasn't moved.
- **Nodes only cook when dirty AND active** — lazy evaluation + active chain cooking.
- **Each node cooks at most once per frame** — results are cached.
- **Cook order** = topological sort of the dirty subgraph.
- **Inactive nodes** (not feeding any sink) keep `cached_output` frozen and skip cooking entirely.
- **Active set** is event-driven — recomputed only when graph topology, sinks, or expressions change.

**Expression dependency notification — IMPLEMENTED:** The cook engine now uses an event-driven expression consumer map (`_expr_consumer_map`) built by `_rebuild_expr_consumer_map()`. Instead of polling every frame, `_should_eval_expressions()` checks whether referenced upstream nodes actually cooked this frame or are time-dependent, skipping expression evaluation entirely on quiet frames.

### Non-Realtime Mode (NRT)

A global cook engine toggle that replaces wall-clock delta with a fixed timestep
for deterministic, frame-perfect recording.  When NRT is active, every cook frame
advances virtual time by exactly `1.0 / non_realtime_fps` seconds, regardless of
how long the frame actually takes to compute.

```gdscript
# GNCookEngine — new NRT state
var non_realtime: bool = false       # Global toggle (toolbar "NRT" CheckButton)
var non_realtime_fps: float = 30.0   # Target FPS (toolbar SpinBox, 1–240)

func _process(delta: float) -> void:
    # ...
    if non_realtime:
        current_delta = 1.0 / non_realtime_fps
        elapsed_time += current_delta
    else:
        current_delta = delta
        elapsed_time += delta
    cook_frame(current_delta)
```

**Key properties:**

| Aspect | Realtime (default) | Non-Realtime |
|--------|-------------------|--------------|
| Delta source | Godot's `_process(delta)` — wall clock | Fixed: `1.0 / non_realtime_fps` |
| Time advancement | Real wall-clock time | Virtual: `elapsed_time += fixed_delta` |
| Frame drops | Possible under load | Impossible — every frame cooks fully |
| Use case | Live performance, interactive | Offline recording, heavy FX render |

**Workflow:** Enable NRT via toolbar "NRT" toggle → set target FPS via the adjacent
SpinBox → activate a recording sink (ImageSaveOUT, MovieOUT, FFmpegOUT) →
play the timeline.  Every frame is captured at the exact specified interval — no
drops, no jitter, deterministic output regardless of scene complexity.

**Persisted:** NRT enabled state and FPS value are saved/restored via
`_save_setting()`/`_load_setting()` across editor sessions.

### Logging & Warning System (Editor-Only)

Two-layer diagnostics architecture for the GONODES editor. All logging is
gated behind `GNCookEngine.editor_mode` — exported player builds have zero
logging overhead.

**Layer 1 — Per-Node Warning / Error Badges:**
- `GNNode.node_warning` (String) — yellow ⚠ badge, recoverable issues
- `GNNode.node_error` (String) — red ✖ badge, failures
- Both cleared at the start of each cook cycle (self-healing)
- `GNNodeView._status_badge` renders the badge overlay with tooltip
- Cook engine sets `node_error` on null cook results, expression failures
- Operators can set `node_warning`/`node_error` in `_cook()`

**Layer 2 — Textport (GNLogPanel):**
- Collapsible log panel at the bottom of the editor (toggle via Log button)
- `GNLogger` singleton: `.debug()`, `.info()`, `.warn()`, `.error()`
- `GNLogger.log_sink` — `Callable` set by `GNLogPanel._ready()` (editor-only)
- 500-entry ring buffer, DBG/INF/WRN/ERR filter buttons, color-coded output
- `GNLogger.enabled` defaults to `false` — player never enables it

**`log()` bridge (user-facing):**
- Script preamble injects `log()`, `log_debug()`, `log_warn()`, `log_error()`
- Each routes to `GNLogger.info/debug/warn/error` with `me.id` as category
- Expression context exposes `log(message)` (INFO level) via CookEngine method
- No-op in player builds (GNLogger.enabled stays false)

**Editor-only guard (`editor_mode`):**
```
GNCookEngine.editor_mode: bool = false  (default)
  — gn_editor.gd sets it to true
  — player_main.gd leaves it false
When false:
  — node_warning/node_error never cleared or set by cook engine
  — WindowOUT fan-out detection skipped
  — GNLogPanel never instantiated
  — GNLogger.enabled stays false
```

**WindowOUT fan-out detection:**
When two WindowOUT nodes wire to the same UI operator, `_adopt_control()`
detects the stolen Control parent and sets `node_warning` on both nodes
+ logs via `GNLogger.warn()`. Warning self-clears if the conflict is resolved.

### Right-Click Export Output

Any node's cached output can be exported to disk via the context menu.  Right-click
a single node → **Export Output…** opens a FileDialog with family-appropriate
format filters.  The menu item is disabled when no node is selected, multiple nodes
are selected, or the selected node has no valid `cached_output` (exception: COMP
nodes with a live `get_scene_node()` are also exportable even when `cached_output`
is null — this covers LightCOMP and CameraCOMP which return null data but own
a Light3D / Camera3D).

**Format mapping by family:**

| Data Type | Family | Formats | Notes |
|-----------|--------|---------|-------|
| `GNTextureData` | TOP | PNG, WebP, EXR | GPU→CPU readback via `texture.get_image()` |
| `GNImageData` | IMG | PNG, WebP, EXR | Direct CPU Image save |
| `GNGeoData` | SOP | glTF Binary (.glb) | Bare mesh, no material |
| Any COMP | COMP | glTF Binary (.glb) | Full scene graph via `get_scene_node().duplicate()` + `GLTFDocument` |
| `GNChannelData` | CHOP | CSV, JSON | CSV: channels as columns, header row = names |
| `GNTableData` | DAT | CSV, JSON, Text | JSON: array of {header: value} dicts |
| `GNMaterialData` | MAT | .tres | Godot `ResourceSaver` |

**COMP export supports the full scene graph:**

| COMP Operator | Scene Node | glTF Result |
|---------------|-----------|-------------|
| GeometryCOMP | `MeshInstance3D` + `material_override` | Mesh + material + transform |
| LightCOMP | `DirectionalLight3D` / `OmniLight3D` / `SpotLight3D` | glTF KHR_lights_punctual extension |
| CameraCOMP | `Camera3D` | glTF camera node (perspective or orthographic) |
| MergeCOMP | `Node3D` group with children | Full subtree — meshes, lights, cameras, transforms |

Exporting a MergeCOMP that combines GeometryCOMPs, LightCOMPs, and a CameraCOMP
produces a complete .glb scene ready to import in Blender, Unity, Unreal, or
any glTF-compatible tool.

**Implementation:**

- `_CtxID.EXPORT_OUTPUT` added to context menu enum
- `_begin_export_output()` — validates selection (checks `cached_output` OR `get_scene_node()` for COMPs), lazy-inits `FileDialog`, sets filters
- `_on_export_file_selected(path)` — dispatches to family-specific export functions
- `_export_texture()`, `_export_image()`, `_export_geo_glb()`, `_export_comp_glb()`,
  `_export_channel()`, `_export_table()`, `_export_material()`
- `_export_comp_glb()` — deep-clones via `get_scene_node().duplicate()`, works for any COMP type
- `_write_gltf_scene()` — shared helper: parents clone under tmp root, calls `_set_owner_recursive()` so GLTFDocument traverses the full subtree, then `append_from_scene()` + `write_to_filesystem()`
- `_set_owner_recursive()` — sets `owner` on all descendants (required for GLTFDocument to see children)

**COMP vs SOP glTF export:** SOP exports a bare mesh (no material).  COMP
nodes export from the scene graph level — GeometryCOMP provides mesh + material,
LightCOMP provides light nodes, CameraCOMP provides camera, and MergeCOMP
exports entire hierarchies.  This mirrors how 3D DCC tools work: the COMP layer
is the "scene" while SOP is raw geometry data.

---

## 9. MVP Operators

### TOP Family

#### NoiseTOP
- **Outputs:** 1 texture (SubViewport render)
- **Inputs:** 0
- **Parameters:**
  - `resolution`: Vector2i (default 512×512)
  - `noise_type`: enum (Simplex, Perlin, Voronoi, White)
  - `scale`: float (default 4.0)
  - `offset`: Vector2 (default 0,0)
  - `time_offset`: float (driven by time or manual)
  - `seed`: int
  - `monochrome`: bool (default true)
- **Implementation:** SubViewport + ColorRect + ShaderMaterial running a noise GLSL shader
- **Time-dependent:** Yes (if time_offset is linked to global time)

#### CompositeTOP
- **Outputs:** 1 texture
- **Inputs:** 2 textures (A and B)
- **Parameters:**
  - `operation`: enum (Add, Multiply, Over, Screen, Subtract, Difference)
  - `opacity`: float (0–1, default 1.0)
- **Implementation:** SubViewport + shader that samples both inputs

#### LevelTOP
- **Outputs:** 1 texture
- **Inputs:** 1 texture
- **Parameters:**
  - `brightness`: float (default 1.0)
  - `contrast`: float (default 1.0)
  - `gamma`: float (default 1.0)
  - `invert`: bool (default false)
  - `opacity`: float (default 1.0)

### CHOP Family

#### LFO_CHOP
- **Outputs:** 1 channel set (single channel "out")
- **Inputs:** 0
- **Parameters:**
  - `waveform`: enum (Sine, Triangle, Square, Sawtooth, Pulse)
  - `frequency`: float (default 1.0 Hz)
  - `amplitude`: float (default 1.0)
  - `offset`: float (default 0.0)
  - `phase`: float (default 0.0)
  - `duty_cycle`: float (for Pulse, default 0.5)
- **Time-dependent:** Yes (always cooks)

#### MathCHOP
- **Outputs:** 1 channel set
- **Inputs:** 1–2 channel sets
- **Parameters:**
  - `operation`: enum (Add, Subtract, Multiply, Divide, Abs, Sin, Cos, Pow)
  - `operand`: float (for single-input operations)

#### NoiseCHOP
- **Outputs:** 1 channel set (configurable number of channels)
- **Inputs:** 0
- **Parameters:**
  - `num_channels`: int (default 1)
  - `channel_names`: String (comma-separated, default "chan1")
  - `roughness`: float
  - `period`: float
  - `seed`: int
- **Time-dependent:** Yes

### Bridge Operators

#### CHOPtoTOP (Parameter Reference Bridge)
This is not a traditional operator — it's a mechanism for CHOP channels to drive TOP parameters.

**Implementation approach for MVP:**
Parameter expressions on any GNNode can reference CHOP outputs:
```
# On NoiseTOP.scale parameter expression:
chop("lfo1").value("out")   # Gets last sample of channel "out" from node "lfo1"
```

This is resolved during cook: the cook engine evaluates parameter expressions before calling `_cook()`, injecting resolved values.

---

## 10. UI Architecture

### Main Editor Layout
```
├──────────────────────────────────────────────────┐
│  HSplitContainer                                │
├─────────────────────────────┬────────────────────┤
│                             │  VSplitContainer   │
│  GraphPanel (stretch 2x)    ├────────────────────┤
│  └─ GraphEdit               │  ViewerPanel       │
│     + Node Palette popup    │  (stretch 1.5)     │
│                             │  └─ GNViewerPanel  │
│     ├───┐    ├───┐          │    Family-aware:   │
│     │LFO│───▶│NOI│          │    TOP → pan/zoom  │
│     │ ðŸ‘│    │SE │          │    CHOP → waveform │
│     └───┘    └───┘          │    DAT → spreadsht │
│                             │    SOP → 3D orbit  │
│                             │    MAT → 3D sphere │
│                             ├────────────────────┤
│                             │  InspectorPanel   │
│                             │  (stretch 1.0)     │
│                             │  └─ GNParamInsp.  │
│                             │    260px min width │
├─────────────────────────────┴────────────────────┤
│  InfoBar: FPS | Frame | Cook | Viewing: nodeID  │
└──────────────────────────────────────────────────┘
```

**Scene file:** `scenes/gn_editor.tscn`
- **GNViewerPanel** (replaces old TextureRect): family-aware viewer that switches visualization mode based on the pinned node's family
- Both panels: `clip_contents = true`, `custom_minimum_size.y = 40` (freely resizable via VSplit splitter)
- Window stretch: `canvas_items` mode, `expand` aspect (set in `project.godot`)

### GNViewerPanel (`addons/gonodes/ui/gn_viewer_panel.gd`)
Family-aware viewer panel that displays any node family's output. Only one visualization mode is active at a time. Rendering logic is shared with SnapshotTOP via `GNViewerRenderer` (`addons/gonodes/core/gn_viewer_renderer.gd`) — a static utility class providing viewport creation (SOP/POP/MAT SubViewports with cameras, lights, gizmos), orbit camera positioning, volume slice extraction, CHOP waveform rendering, and DAT table rendering. Changes to `GNViewerRenderer` automatically update both the viewer panel and SnapshotTOP.

**Visualization modes:**

| Family | Display Widget | Description |
|--------|---------------|-------------|
| **TOP** | TextureRect + pan/zoom | Full-resolution display. Left-click or middle-click drag to pan, scroll wheel to zoom. Shift+F to fit, Home for 1:1. |
| **IMG** | TextureRect + pan/zoom | Same as TOP — uploads `Image` → `ImageTexture` on-the-fly |
| **CHOP** | GNWaveformView (`_draw()`) | GPU-accelerated polylines, fixed-scale grid, zoom/pan, multi-channel with legends |
| **DAT** | Tree (spreadsheet) | Column headers, scrollable rows, selection highlight |
| **SOP** | SubViewport + Camera3D | Orbit camera (left/middle-click drag), zoom (scroll), XYZ axis gizmo, dark environment |
| **MAT** | SubViewport + preview sphere | Material applied to sphere mesh, 3D lit, orbit controls |
| **COMP** | Info label | Shows component type — COMPs have no visual output (navigate into them instead) |

**Key design decisions:**
- SubViewports only for SOP/MAT (3D rendering). TOP/IMG/CHOP/DAT use lighter-weight approaches.
- **Docked viewer** (`eager_3d = true`): 3D SubViewports pre-created via `call_deferred("_warm_up_3d")` after `_ready()` — no hitch on first SOP/MAT click.
- **Floating viewers** (`eager_3d = false`, default): 3D SubViewports lazily created on first view. Small one-time hitch per window, acceptable for secondary viewers.
- SubViewport sizes snapped to 64px boundaries to avoid resize churn during panel drag.
- Pan/zoom/orbit state resets when switching to a different node.
- **XYZ axis gizmo** in SOP viewer: `ImmediateMesh` lines at origin — X=red, Y=green, Z=blue (unshaded `StandardMaterial3D`, always visible).

**Cook-frame update strategy:**
- `update_from_node()` is called every cook frame by the editor.
- **Fast-path optimisation:** `_show_texture()`, `_show_3d_mesh()`, `_show_waveform()`, and `_show_material()` all compare incoming state against the current display. If unchanged, they return immediately without hiding/re-showing Controls or re-laying out. This preserves in-progress pan/zoom/orbit drags across cook frames.
- When the texture *does* change (e.g., the TOP re-cooks with new content), a full layout + `_fit_to_panel()` is triggered.
- **Future optimisation:** replace per-frame polling with an event-driven model — the cook engine would emit `node_output_changed(node_id)` only for nodes that actually re-cooked, and the viewer would subscribe. Eliminates the per-frame function call entirely, but current cost is negligible.

**Viewer pin behaviour:**
- `_viewer_pinned` flag in `gn_editor.gd` — when `true`, node selection only updates the inspector, NOT the viewer target.
- Clicking the eye icon toggles pin on/off (same node = unpin, different node = re-pin).
- Pinned node's eye icon shows ?? (teal); unpinned nodes show ðŸ‘ (gray).
- Pin state + highlights reset on New, Load, and Dive-into-subnet operations.
- `update_viewer_pin_highlights("")` is called after `bind_network()` on load/new to ensure all eye icons start in unpinned state.

**Toolbar:** Family icon + node name + Fit button + zoom percentage label
**Info bar:** Resolution (TOP/IMG), channel count + sample rate (CHOP), row × col (DAT), vert/surface count (SOP)

### GNWaveformView (`addons/gonodes/ui/gn_waveform_view.gd`)
Custom `Control._draw()` that renders CHOP channel data as waveform polylines.
- Uses Godot's GPU-accelerated `draw_polyline()` — no SubViewport needed.
- 8 per-channel colors (green, cyan, yellow, magenta, orange, lavender, teal, red)
- **Fixed-scale grid:** Y-axis range is computed once on first data (with 10% headroom, snapped to a "nice" number like 1/2/5×10^n). Grid lines and value labels stay **static** — the data is plotted within the fixed context.
- **Y zoom:** Scroll wheel changes the visible Y half-range. Grid labels update to match the new scale.
- **X zoom:** Shift+scroll changes the visible time window (sample range).
- **Pan:** Left-click or middle-click drag to pan vertically (Y center) and horizontally (X offset).
- View resets (`reset_view()`) when switching to a different node target; preserved during per-frame cook updates.
- `_snap_to_nice()` rounds grid step sizes to 1/2/5×10^n for clean labels.
- Channel name + current value legend
- Single-sample (scalar) channels rendered as horizontal lines
- **Future upgrade path:** Replace `_draw()` polylines with a SubViewport + shader for glow, trail persistence, and oscilloscope-style phosphor decay effects. Not needed for V1.

### Viewer Pin Button (Eye Icon ðŸ‘ / ??)
Every node has an eye icon (ðŸ‘) in its title bar (next to the ? help button).
- Click → **toggles pin** for that node to the docked viewer panel (any family, not just TOPs)
- Click same pinned node again → **unpins** (returns to follow-selection mode)
- Pinned state: ?? (teal) — "Pinned to viewer (click to unpin)"
- Unpinned state: ðŸ‘ (gray) — "Pin to viewer"
- When pinned, selecting other nodes does NOT switch the viewer — only the inspector updates
- Signal: `GNNodeView.viewer_pin_requested` → `GNGraphEditor.viewer_pin_requested` → `gn_editor._on_viewer_pin_requested()`
- All pin highlights reset on New / Load / Dive-into-subnet via `update_viewer_pin_highlights("")`

### GNViewerWindow (Floating)
`GNViewerWindow` now embeds a full `GNViewerPanel` (`eager_3d = false`) — same family-aware display as docked viewer, with lazy 3D SubViewport creation.
- Right-click → "Open Viewer" opens for any family (not just TOPs)
- Each window pinned to a node ID, updated each cook frame via `update_from_node()`

### GNGraphEditor (extends GraphEdit)
- Renders GNNetwork as GraphNode instances
- Handles drag-and-drop from palette, wiring, deletion
- Color-codes connections by family
- Tab key opens node palette popup (unfiltered)
- **Drop-wire-to-add-node**: dropping a wire on empty canvas opens a filtered palette showing only compatible operators:
  - `connection_to_empty` signal (output → canvas): filters to operators accepting that output's family
  - `connection_from_empty` signal (canvas → input): filters to operators producing that input's family
  - Selected operator auto-connects to the first compatible port (with undo/redo support)
  - **Ghost wire**: semi-transparent line drawn from the source port to the drop point while the palette is open, cleared on palette close/select
  - Pending connection and ghost wire state stored in `_pending_connection` / `_ghost_wire` dicts, cleared on palette close
- **Right-click context menu** (`PopupMenu`) with contextual options:
  - Add Node…, Copy, Cut, Paste, Duplicate, Delete, Select All, Undo, Redo
  - Add Network Box, Add Sticky Note — canvas annotation tools
  - Copy Node Path → `op("name")`, Copy Output Ref → family-appropriate reference (chop/top/op)
  - Items grayed out when not applicable (e.g., no selection → copy/cut/delete disabled)
  - Shortcut hints displayed in menu items
- Emits `operator_selected` / `operator_deselected` signals
- Handles node rename: disconnects visual wires under old name, updates view identity, reconnects under new name
- Connects to `network.node_renamed` signal for model-driven rename updates
- `previews_visible` flag — controls whether inline previews are shown; respects toggle on newly created views
- `perf_overlay_visible` flag — controls per-node cook time badge; respects toggle on newly created views
- `set_previews_visible(enabled)` — shows/hides all existing node preview controls; newly created views auto-hide if `previews_visible` is false
- `set_perf_overlay_visible(enabled)` — shows/hides all existing perf overlay labels; newly created views auto-show if `perf_overlay_visible` is true
- `update_previews()` — skips updates when `previews_visible` is false (zero cost when hidden)
- `update_perf_overlays()` — skips updates when `perf_overlay_visible` is false

### GNNodePalette (extends Popup)
- Tree-based operator browser grouped by family, with search filtering
- Family groups iterate `GNFamily.FAMILY_NAMES` dynamically (not hardcoded) — adding a new family auto-populates the palette
- Operator descriptions fetched from `GNExtensionRegistry.get_description()` for tooltips
- **Filtered mode** via `popup_at_filtered(global_pos, allowed_operators: PackedStringArray)`: only shows operators in the allowed list. Used by drop-wire-to-add-node.
- **Unfiltered mode** via `popup_at(global_pos)`: shows all operators (Tab key, right-click → Add Node)
- Filter cleared automatically on `popup_hide` signal

### GNNodeView (extends GraphNode)
- Visual representation of a GNNode
- Shows typed input/output ports with family colors
- Family-colored title bar via StyleBoxFlat theme overrides
- Title format: `"nodeId  [FAMILY]"` (e.g., `"noise1  [TOP]"`)
- **Double-click title bar to rename** — inline LineEdit overlay, commits on Enter or focus-lost
- `rename_requested(old_id, new_id)` signal emitted on commit
- Dynamic port rebuilding via `rebuild_slots()` + `reset_size()`
- Port/node tooltips from descriptions
- **Live preview** via `_setup_preview()` → family base class `create_preview_control()`
- `show_preview()` / `hide_preview()` — toggle preview control visibility with `reset_size()` to resize the node
- **Performance overlay** via `_perf_label` (Label): color-coded cook time badge (✓/✗ + ms)
- `show_perf_overlay()` / `hide_perf_overlay()` / `update_perf_overlay()` — lazy label creation, color-coded by threshold

### GNInspector (GNParamInspector, extends PanelContainer)
- Shows parameters for the currently selected node
- Header shows node ID (updates on rename) + status line (family, type, port count, resolution for TOPs)
- Resolution display for TOPs: `In [in0:512x512, in1:256x256] | Out 512x512`
- Renders appropriate controls per parameter type:
  - float → HSlider + SpinBox
  - int → SpinBox
  - Vector2 → 2x SpinBox
  - Color → ColorPickerButton
  - enum → OptionButton
  - bool → CheckBox
  - String → LineEdit
  - RAMP → GNRampEditor (custom `_draw()` curve editor with add/remove/drag keypoints, tangent handles, auto-smooth toggle)
- Expression toggle: switch from value to expression mode
- **Per-component expressions** (TD-style): multi-dimensional types (Vector2, Vector2i, Vector3, Vector4, Color) have independent C/E toggles per component (X/Y/Z/W or R/G/B/A). Each component can independently be a constant or an expression. Managed by `GNParameter.component_modes[]`, `component_expressions[]`, serialized in `to_dict()`/`from_dict()`, evaluated per-component in `GNCookEngine._evaluate_component_expressions()`.

### GNViewer (TextureRect in ViewerPanel)
- Aspect-correct preview of a selected TOP's output
- `stretch_mode = KEEP_ASPECT_CENTERED`, `expand_mode = IGNORE_SIZE`
- Panel freely resizable via VSplitContainer splitter
- `clip_contents = true` on ViewerPanel prevents texture aspect from forcing panel size

---

## 11. Folder Structure

```
GONODES/
├── project.godot
├── GONODES_CONTEXT.md              ← This file
├── addons/
│   └── gonodes/
│       ├── plugin.cfg
│       ├── gonodes_plugin.gd       # EditorPlugin entry (for editor mode)
│       ├── core/
│       │   ├── gn_data.gd          # GNData base class (RefCounted)
│       │   ├── gn_texture_data.gd  # GNTextureData (RefCounted)
│       │   ├── gn_channel_data.gd  # GNChannelData (RefCounted)
│       │   ├── gn_table_data.gd    # GNTableData — DAT output (RefCounted)
│       │   ├── gn_geo_data.gd      # GNGeoData — SOP output, wraps ArrayMesh (RefCounted)
│       │   ├── gn_node.gd          # GNNode base operator class (Node) — type-agnostic
│       │   ├── gn_top_base.gd      # GNTopBase — TOP family base (viewport infra, shader pipeline, render-once-per-cook)
│       │   ├── gn_chop_base.gd     # GNChopBase — CHOP family base (channel data cache, label preview)
│       │   ├── gn_dat_base.gd      # GNDatBase — DAT family base (table cache, label preview)
│       │   ├── gn_sop_base.gd      # GNSopBase — SOP family base (geo cache, label preview)
│       │   ├── gn_comp_base.gd     # GNCompBase — COMP family base (scene node, auto-cleanup)
│       │   ├── gn_port.gd          # GNPort definition (RefCounted)
│       │   ├── gn_connection.gd    # GNConnection (RefCounted)
│       │   ├── gn_network.gd       # GNNetwork (Resource — serialization boundary)
│       │   ├── gn_cook_engine.gd   # GNCookEngine (Node)
│       │   ├── gn_parameter.gd     # GNParameter (Resource — typed param with expressions + profiling)
│       │   ├── gn_expression_functions.gd # GNExpressionFunctions — custom function registry (static)
│       │   ├── gn_extension_registry.gd # GNExtensionRegistry — dynamic operator registry + extension loader
│       │   ├── gn_family.gd        # GNFamily enum constants
│       │   ├── gn_logger.gd        # GNLogger — centralized logging with level filtering
│       │   ├── gn_resource_loader.gd # GNResourceLoader — three-tier resource loading (res://, project://, absolute)
│       │   └── gn_project_manager.gd # GNProjectManager — project folder lifecycle & scanning
│       ├── operators/
│       │   ├── top/
│       │   │   ├── noise_top.gd         # + 19 more TOPs (blur, ramp, circle, etc.)
│       │   │   ├── composite_top.gd
│       │   │   ├── level_top.gd
│       │   │   └── render_top.gd        # RenderTOP — 3D SubViewport bridge (COMP→TOP)
│       │   ├── chop/
│       │   │   ├── lfo_chop.gd          # + 20 more CHOPs (wave, pattern, filter, ramp, etc.)
│       │   │   ├── math_chop.gd
│       │   │   ├── ramp_chop.gd          # Dynamic ramp curves → CHOP channels (1–16 slots)
│       │   │   └── noise_chop.gd
│       │   ├── dat/
│       │   │   ├── constant_dat.gd      # 4×4 editable table
│       │   │   ├── text_dat.gd          # Plain text
│       │   │   ├── null_dat.gd          # Passthrough
│       │   │   ├── select_dat.gd        # Row/col range selection
│       │   │   ├── merge_dat.gd         # Row or column merge
│       │   │   ├── transpose_dat.gd     # Transpose rows/cols
│       │   │   ├── sort_dat.gd          # Sort by column (alpha/numeric)
│       │   │   ├── evaluate_dat.gd      # Expression cells (=expr)
│       │   │   ├── switch_dat.gd        # Index-based input select
│       │   │   ├── chop_to_dat.gd       # CHOP→DAT bridge
│       │   │   ├── dat_to_chop.gd       # DAT→CHOP bridge (family=CHOP)
│       │   │   ├── info_dat.gd          # System info table (time-dependent)
│       │   │   └── osc_in_dat.gd        # OSC input (stub for future UDP)
│       │   ├── sop/
│       │   │   ├── grid_sop.gd          # Subdivided plane (SurfaceTool)
│       │   │   ├── box_sop.gd           # Godot BoxMesh
│       │   │   ├── sphere_sop.gd        # Godot SphereMesh
│       │   │   ├── torus_sop.gd         # Godot TorusMesh
│       │   │   ├── cylinder_sop.gd      # Godot CylinderMesh
│       │   │   ├── line_sop.gd          # Line strip
│       │   │   ├── circle_sop.gd        # Filled disc or wire circle
│       │   │   ├── transform_sop.gd     # TRS with 6 transform orders
│       │   │   ├── noise_sop.gd         # FastNoiseLite vertex displacement
│       │   │   ├── subdivide_sop.gd     # Triangle→4 split (up to 4 iterations)
│       │   │   ├── wireframe_sop.gd     # Triangles→lines (edge dedup)
│       │   │   ├── merge_sop.gd         # Multi-input surface append
│       │   │   ├── null_sop.gd          # Passthrough
│       │   │   └── switch_sop.gd        # Index-based input select
│       │   ├── comp/
│       │   │   ├── geometry_comp.gd     # MeshInstance3D wrapper (SOP→3D scene)
│       │   │   ├── camera_comp.gd       # Camera3D wrapper (perspective/ortho)
│       │   │   └── light_comp.gd        # Light3D wrapper (dir/omni/spot)
│       │   ├── bridge/
│       │   │   └── chop_to_top.gd       # (or parameter expression system)
│       │   └── output/
│       │       └── window_out.gd        # WindowOUT — multi-window display output
│       ├── ui/
│       │   ├── gn_graph_editor.gd
│       │   ├── gn_graph_editor.tscn
│       │   ├── gn_node_view.gd
│       │   ├── gn_node_view.tscn
│       │   ├── gn_inspector.gd
│       │   ├── gn_inspector.tscn
│       │   ├── gn_viewer.gd
│       │   ├── gn_viewer.tscn
│       │   ├── gn_node_palette.gd
│       │   ├── gn_node_palette.tscn
│       │   ├── gn_ramp_editor.gd    # GNRampEditor — custom _draw() curve editor for RAMP parameters
│       │   ├── gn_debug_panel.gd    # GNDebugPanel — 3-tab debug panel (Cook Chain, Active Chains, Param Refs)
│       │   ├── gn_debug_overlay.gd  # GNDebugOverlay — 5-layer canvas overlay (cook order, dimming, dirty flash, sinks, data flow)
│       │   ├── gn_network_box.gd    # GNNetworkBox — canvas annotation: colored grouping rectangle
│       │   ├── gn_sticky_note.gd    # GNStickyNote — canvas annotation: editable text note
│       │   └── gn_main_editor.tscn # Main layout scene
│       ├── shaders/
│       │   ├── noise_simplex.gdshader
│       │   ├── noise_perlin.gdshader
│       │   ├── noise_voronoi.gdshader
│       │   ├── composite.gdshader
│       │   └── levels.gdshader
│       └── icons/
│           ├── top_icon.svg
│           ├── chop_icon.svg
│           └── ... (per-operator icons)
│   └── gn_ext_ffmpeg/                  # ← First GNExtension addon (reference impl)
│       ├── gn_extension.cfg            # Manifest: name, deps, operator list
│       ├── README.md
│       └── operators/top/
│           └── ffmpeg_in_top.gd        # FFmpegInTOP — dynamic ClassDB.instantiate("FFmpegVideoStream")
│   └── gn_ext_shadertoy/              # ← Shadertoy shader pack extension
│       ├── gn_extension.cfg            # Manifest: 11 operators (5 gen + 5 fx + 1 runtime)
│       ├── README.md
│       ├── shadertoy_translator.gd     # ShadertoyTranslator — GLSL→Godot shader converter
│       ├── shaders/                    # 10 pre-converted .gdshader files
│       └── operators/top/
│   └── gn_ext_native/                 # ← Native Acceleration extension (GDScript wrappers)
│       ├── gn_extension.cfg            # Manifest: 16 operators (Phase 1 + Phase 2)
│       ├── README.md
│       ├── help/
│       │   ├── img/                         # Help patches for IMG native ops
│       │   ├── sop/                         # Help patches for SOP native ops
│       │   └── chop/                        # Help patches for CHOP native ops
│       └── operators/
│           ├── img/
│           │   ├── blur_img_native.gd       # BlurIMGNative — delegates to GNNativeBlur
│           │   ├── noise_img_native.gd      # NoiseIMGNative — delegates to GNNativeNoise
│           │   ├── pixel_sort_img_native.gd # PixelSortIMGNative — delegates to GNNativePixelSort
│           │   └── edge_detect_img_native.gd # EdgeDetectIMGNative — delegates to GNNativeEdgeDetect
│           ├── sop/
│           │   ├── particle_sop_native.gd   # ParticleSOPNative — delegates to GNNativeParticle
│           │   ├── metaball_sop_native.gd   # MetaballSOPNative — delegates to GNNativeMetaball
│           │   ├── polyreduce_sop_native.gd # PolyReduceSOPNative — delegates to GNNativePolyReduce
│           │   ├── isosurface_sop_native.gd # IsoSurfaceSOPNative — delegates to GNNativeIsoSurface
│           │   ├── ray_sop_native.gd        # RaySOPNative — delegates to GNNativeRay
│           │   ├── facet_sop_native.gd      # FacetSOPNative — delegates to GNNativeFacet
│           │   ├── fuse_sop_native.gd       # FuseSOPNative — delegates to GNNativeFuse
│           │   ├── subdivide_sop_native.gd  # SubdivideSOPNative — delegates to GNNativeSubdivide
│           │   ├── copy_sop_native.gd       # CopySOPNative — delegates to GNNativeCopy
│           │   ├── lsystem_sop_native.gd    # LSystemSOPNative — delegates to GNNativeLSystem
│           │   └── spring_sop_native.gd     # SpringSOPNative — delegates to GNNativeSpring
│           └── chop/
│               └── smooth_chop_native.gd    # SmoothCHOPNative — delegates to GNNativeSmooth
│   └── gn_native/                     # ← C++ GDExtension source (requires godot-cpp + scons build)
│       ├── gn_native.gdextension              # Active — Windows DLL compiled
│       ├── bin/win64/libgn_native.windows.template_debug.x86_64.dll  # 677 KB
│       ├── SConstruct                      # SCons build file
│       └── src/
│           ├── register_types.cpp/.h        # Entry point registering all 16 C++ classes
│           ├── img/                         # GNNativeBlur, GNNativeNoise, GNNativePixelSort, GNNativeEdgeDetect
│           ├── sop/                         # GNNativeParticle, GNNativeMetaball, GNNativePolyReduce + 8 Phase 2 SOPs
│           └── chop/                        # GNNativeSmooth
│           └── shadertoy_top.gd         # ShadertoyTOP — runtime paste/fetch/inline translator (single operator, 10 factory GLSL presets)
├── build/
│   ├── gn_build.py                     # Shared build module (platform detection, env setup, source collection)
│   ├── SConstruct                      # Root entry point — auto-discovers and builds all extensions
│   └── ci_discover.py                  # CI helper — outputs GitHub Actions matrix JSON
├── scenes/
│   └── main.tscn                   # Application entry scene
├── tests/
│   ├── test_cook_engine.gd
│   ├── test_network.gd
│   └── test_operators.gd
└── assets/
```

---

## 12. Development Phases

### Phase 1: Core Framework (Week 1) ✅
- [x] Set up Godot 4.6 project structure
- [x] Implement GNData, GNTextureData, GNChannelData
- [x] Implement GNPort, GNConnection
- [x] Implement GNParameter (value + expression support)
- [x] Implement GNNode base class with cook lifecycle
- [x] Implement GNNetwork (graph model, topological sort, cycle detection)
- [x] Implement GNCookEngine (dirty propagation, frame cook loop)
- [ ] Write unit tests for graph operations and cook order

### Phase 2: First Operators (Week 2) ✅
- [x] Implement NoiseTOP (SubViewport + noise shader)
- [x] Implement LFO_CHOP (waveform generator)
- [x] Wire up cook engine to process a test network from code
- [x] Test scene: LFO_CHOP expression driving NoiseTOP.time_offset
- [x] Implement CompositeTOP
- [x] Implement LevelTOP
- [x] Implement NoiseCHOP, MathCHOP
- [x] Implement WindowOUT (multi-window/multi-display output)
- [x] Implement GNLogger (centralized logging with toggle)
- [x] Resource → Node/RefCounted migration
- [x] Expression system debugging & rearchitecture (base_instance model)
- [x] WindowOUT rendering fix (anchors + zero-copy texture routing)
- [x] Cook engine performance optimization (cached adjacency, zero-alloc inputs)
- [x] Verified: animated noise, movable output window, stable cook times

### Phase 3: Node Graph UI (Week 3) ✅
- [x] Implement GNGraphEditor (GraphEdit wrapper with bidirectional network sync)
- [x] Implement GNNodeView (GraphNode per operator with family-colored title bar)
- [x] Port rendering with family colors via `set_slot()` typed port slots
- [x] Wire connection UI with type checking
- [x] Add/remove nodes via UI (Tab / right-click palette)
- [x] Connect/disconnect wires via UI
- [x] Sync UI ↔ GNNetwork model bidirectionally (signal-driven)
- [x] Implement GNNodePalette (popup with search + family grouping)
- [x] Editor scene (gn_editor.tscn) with HSplit layout: graph + viewer/inspector

### Phase 4: Parameters & Inspector (Week 4) ✅
- [x] Implement GNParamInspector panel (family color bar, header, scrollable params)
- [x] Implement GNParamRow (per-parameter widget with type-specific controls)
- [x] Render parameter controls by type (FLOAT: slider+spinbox, INT: spinbox, BOOL: checkbox, ENUM: dropdown, COLOR: picker, VECTOR2/2I: dual spinbox, STRING: line edit, FILE: project file picker button with FileDialog)
- [x] Parameter mode toggle (C=constant green / E=expression orange)
- [x] Expression inline editor with focus guard (no 60fps text clobbering)
- [x] Parameter change → mark node dirty → recook
- [x] GNViewer panel showing TOP output in real-time (VSplit: viewer top, inspector bottom)
- [x] Expression mode: CHOP channel references in parameter fields
- [x] Per-component expressions for multi-dimensional params (Vector2, Vector3, Vector4, Color — TD-style independent C/E per component)
- [x] Live cook time display per node in inspector header
- [x] NoiseTOP noise_type enum wired to shader (4 algorithms: Simplex/Perlin/Voronoi/White)
- [x] WindowOUT `_window_params_dirty` flag — only reconfigures on own param changes, not upstream cook-dirty

### Phase 5: Polish & More Operators (Week 5) ✅
- [x] MathCHOP, NoiseCHOP (completed in Phase 2)
- [x] Massive operator expansion — 20 new TOPs + 17 new CHOPs
  - **New TOP generators:** RampTOP, CircleTOP, RectangleTOP, ConstantTOP, TextTOP
  - **New TOP filters:** BlurTOP (2-pass Gaussian), TransformTOP, HSVAdjustTOP, EdgeTOP, ThresholdTOP, FlipTOP, TileTOP, CropTOP, FeedbackTOP, ResolutionTOP
  - **New TOP combiners:** CrossTOP, DisplaceTOP, LookupTOP
  - **New TOP utility:** NullTOP, SwitchTOP
  - **New CHOP generators:** ConstantCHOP, WaveCHOP, PatternCHOP, TimerCHOP
  - **New CHOP filters:** FilterCHOP, LagCHOP, LimitCHOP, TriggerCHOP, SpeedCHOP, CountCHOP, HoldCHOP, SelectCHOP
  - **New CHOP combiners:** LogicCHOP, MergeCHOP, CrossCHOP
  - **New CHOP utility:** NullCHOP, SwitchCHOP
- [x] 14 new GPU shaders (blur, ramp, circle, rectangle, transform2d, hsv_adjust, edge, threshold, displace, flip, tile, cross, crop, lookup, feedback)
- [x] All operators registered in palette registry
- [x] CustomShaderTOP — user-editable GLSL shaders with live recompilation
- [x] Right-click context menu on graph canvas (moved to Phase 6)
- [x] Copy/paste nodes (moved to Phase 6)
- [x] Undo/redo (Godot's UndoRedo system) (moved to Phase 6)
- [x] Mini preview thumbnails on all nodes (moved to Phase 6)
- [x] Expression reference lines (dashed/stippled cyan overlay with arrowheads between nodes when a parameter references another node via `chop()`/`op()`/`top()`/`sop()`/`dat()`/`mat()` expressions)

### Phase 5.5: DAT, SOP, COMP & 3D Pipeline ✅
- [x] **GNTableData** — DAT output data type (2D string table + text mode, headers, TSV import/export)
- [x] **GNGeoData** — SOP output data type wrapping Godot's native `ArrayMesh`
- [x] **12 DAT operators:** ConstantDAT, TextDAT, NullDAT, SelectDAT, MergeDAT, TransposeDAT, SortDAT, EvaluateDAT, SwitchDAT, CHOPDAT (CHOP→DAT bridge), DATtoCHOP (DAT→CHOP bridge), InfoDAT
  - OscInDAT stub for future UDP/OSC input
- [x] **14 SOP operators:** GridSOP, BoxSOP, SphereSOP, TorusSOP, CylinderSOP, LineSOP, CircleSOP, TransformSOP, NoiseSOP, SubdivideSOP, WireframeSOP, MergeSOP, NullSOP, SwitchSOP
  - SOP generators use Godot native meshes: BoxMesh, SphereMesh, CylinderMesh, TorusMesh
  - Procedural generators use Godot SurfaceTool (GridSOP, LineSOP, CircleSOP)
  - NoiseSOP uses Godot FastNoiseLite for vertex displacement
- [x] **3 COMP operators:** GeometryCOMP, CameraCOMP, LightCOMP
  - GeometryCOMP: wraps MeshInstance3D, applies SOP geometry + StandardMaterial3D + TOP texture
  - CameraCOMP: wraps Camera3D, perspective/ortho, look-at mode
  - LightCOMP: wraps DirectionalLight3D / OmniLight3D / SpotLight3D with shadow control
- [x] **5 Physics COMP operators:** RigidBodyCOMP, StaticBodyCOMP, SoftBodyCOMP, AreaCOMP, JointCOMP
  - RigidBodyCOMP: RigidBody3D with auto collision shape from mesh, CHOP force input, axis locking
  - StaticBodyCOMP: StaticBody3D for immovable colliders (floor, walls)
  - SoftBodyCOMP: SoftBody3D for deformable mesh physics (cloth, jelly)
  - AreaCOMP: Area3D force field with gravity/damping overrides, debug visualization
  - JointCOMP: Joint3D subtypes (Pin, Hinge, Slider, ConeTwist, 6DOF) with network-walked body connections
- [x] **PhysicsCHOP** — readback bridge (COMP → CHOP) for physics state (position, rotation, velocity, sleeping)
- [x] **RenderTOP** — 3D SubViewport bridge (COMP → TOP texture pipeline)
  - Own `World3D` per viewport (isolated 3D scene + physics space)
  - Walks network connections to adopt GeometryCOMP/CameraCOMP/LightCOMP nodes
  - Generic COMP fallback: any GNCompBase subclass (including physics COMPs) is adopted via `get_scene_node()`
  - Default camera fallback if no CameraCOMP connected
  - WorldEnvironment with configurable ambient/background
  - MSAA control (Off/2x/4x/8x), transparent background option
- [x] **All operators registered** in graph editor registry + palette
- [x] **Codebase review & bug fixes:**
  - Fixed multi-input port data loss in `_gather_inputs()` (MergeSOP, CompositeTOP now work)
  - Fixed stale `cached_output` when cook returns null
  - Fixed COMP null-return warning suppression
  - Fixed PatternCHOP per-frame RNG allocation (moved to member variable)
  - Fixed `_select_first_leaf` recursive tree traversal in palette

### Phase 5.6: UI Polish & Node Renaming ✅
- [x] **Canvas anchoring fix** — all 21 TOP operators now use `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` for SubViewport canvas sizing (replaces manual `_canvas.size = Vector2(res)`)
- [x] **Viewer panel sizing fix** — TextureRect `expand_mode = 1` (IGNORE_SIZE), `clip_contents = true` on both ViewerPanel and InspectorPanel, prevents texture aspect ratio from forcing panel width
- [x] **Node renaming** — double-click title bar to rename nodes inline; full ID update chain: nodes dict, GNNode.id/name, all GNConnection references, expression strings, visual wires
- [x] **Inspector refresh on rename** — header label updates when re-inspecting a renamed node
- [x] **Documentation update** — GONODES_CONTEXT.md updated with Hard Rules 25.16–25.18

### Phase 5.7: File Parameters & Media Input ✅
- [x] **FILE parameter type** — new `ValueType.FILE` in GNParameter with `file_filters` (PackedStringArray of wildcard patterns). `create_file()` factory method. Stores `res://` paths.
- [x] **File picker UI** — GNParamRow renders FILE params as a Button (showing filename) + "X" clear button. Opens Godot's native FileDialog scoped to `ACCESS_RESOURCES` (project directory only). Filter extensions from parameter's `file_filters`.
- [x] **TextTOP font selection** — new `font_file` FILE parameter accepting TTF, OTF, WOFF, WOFF2. Loads via `ResourceLoader`, applies with `add_theme_font_override("font", ...)`. Empty = default theme font.
- [x] **ImageFileInIMG** — loads image files (PNG, JPG, WebP, BMP, TGA, SVG, HDR, EXR, .tres/.res) as CPU Image. Pure CPU, no SubViewport. Resize param, reload pulse. Chain → ImgToTOP for GPU.
- [x] **MovieFileInTOP** — plays .ogv Theora video as live GPU texture stream. Uses Godot's native `VideoStreamPlayer`. Play/pause, loop, seek, speed controls. Video decodes internally to GPU — no CPU image access (Godot limitation).
  - **Codec limitations:** Godot's built-in Theora decoder outputs RGB only (no alpha). For alpha video, use image sequences (PNG/WebP).

### Phase 5.8: Extension Registry Architecture ✅
- [x] **GNExtensionRegistry** — centralized operator registry (`addons/gonodes/core/gn_extension_registry.gd`). Lazy singleton with `instance()`. Replaces the static match-factory in GNGraphEditor and the static description dictionary in GNNodePalette.
  - `OperatorEntry` inner class: family, GDScript, description, source ("core" or extension name)
  - `register_operator()` / `unregister_operator()` — dynamic operator registration API
  - `create_instance(class_name)` → GNNode — data-driven factory (no more match block)
  - `get_operator_registry()` → Dictionary grouped by family — same shape as before
  - `get_description(class_name)` → String — tooltip text for palette
  - `has_operator()`, `get_operator_count()`, `get_all_operator_names()`, `get_loaded_extensions()` — query API
- [x] **Extension scanning** — `scan_extensions()` discovers `res://addons/gn_ext_*/gn_extension.cfg` manifest files (ConfigFile format). Each manifest declares:
  - `[extension]` section: name, version, author, description, dependencies (ClassDB class names)
  - `[operator.<ClassName>]` sections: family, script path, description
  - Dependency guard via `ClassDB.class_exists()` — skips extensions whose GDExtension deps are missing
- [x] **Refactored GNGraphEditor** — `_create_operator_instance()` and `get_operator_registry()` now delegate to GNExtensionRegistry (replaced ~230-line match block + ~40-line static dictionary)
- [x] **Refactored GNNodePalette** — `_get_operator_description()` now delegates to GNExtensionRegistry (replaced ~80-line static dictionary)
- [x] **Editor startup** — `gn_editor.gd._ready()` calls `GNExtensionRegistry.instance().scan_extensions()` before network setup

### Phase 6: Integration & Stabilization (Week 6) ✅
- [x] **Save/load patches** (`.gnpatch` JSON files) — full serialization pipeline:
  - `GNParameter.to_dict()` / `from_dict()` — serializes value, mode, expression, bind info. Custom `_variant_to_json()` / `_json_to_variant()` handles Vector2, Vector2i, Vector3, Vector4, Color → typed JSON dicts.
  - `GNNode.to_dict()` / `from_dict()` — serializes operator type, graph position, all parameters.
  - `GNNetwork.to_dict()` / `from_dict()` — serializes all nodes + connections. Uses `GNExtensionRegistry.create_instance()` for reconstruction.
  - `GNNetwork.save_to_file(path)` / `load_from_file(path)` — JSON read/write with pretty-printing.
  - Editor UI: New / Open / Save / Save As buttons in bottom bar + Ctrl+N / Ctrl+O / Ctrl+S / Ctrl+Shift+S keyboard shortcuts. FileDialog for file picker. Window title shows current file name.
- [x] **Node copy/paste** — clipboard-based with ID remapping:
  - `GNGraphEditor._clipboard` stores serialized nodes + internal connections.
  - Copy (Ctrl+C): serializes selected nodes via `to_dict()`, gathers connections where both endpoints are selected.
  - Paste (Ctrl+V): reconstructs with fresh IDs via `generate_unique_id()`, offsets positions +50/+50, remaps internal connections, auto-selects pasted nodes.
  - Cut (Ctrl+X): copy then delete. Duplicate (Ctrl+D): copy then paste in one step.
- [x] **Undo/redo** — Godot `UndoRedo` command pattern:
  - Tracks: add node, delete node(s), connect, disconnect, move node(s), rename.
  - Keyboard shortcuts: Ctrl+Z (undo), Ctrl+Y / Ctrl+Shift+Z (redo).
  - `_ur_*` helper methods on GNGraphEditor operate on the network model; network signals update views automatically.
  - Delete snapshots node dict + connections for full reconstruction on undo.
  - Move tracked via GraphEdit `begin_node_move`/`end_node_move` signals with position diffing.
  - Paste/duplicate record compound actions (all pasted nodes removed on undo).
  - History cleared on New/Load to avoid cross-patch undo.
- [x] **Mini preview thumbnails** on all nodes (generic preview system):
  - `GNNode.create_preview_control()` — virtual, returns a custom `Control` for family-specific previews. Returns null by default (type-agnostic GNNode).
  - `GNNode.update_preview_control(control)` — virtual, called each cook frame to update previews. No-op by default.
  - Family base classes override these: GNTopBase (TextureRect), GNImgBase (Label: resolution/format — no GPU upload), GNChopBase (Label: channel values), GNDatBase (Label: table rows), GNSopBase (Label: mesh stats), GNCompBase (Label: node class), GNMatBase (Label: material type).
  - `GNNodeView._setup_preview()` — creates preview control via `gn_node.create_preview_control()` (120×80px min size).
  - `GNGraphEditor.update_previews()` iterates ALL node views each cook frame (skipped when hidden).
  - Extensible: any operator can override `create_preview_control()` for operator-specific rendering.
- [x] **Family base classes** — 6 intermediate bases between GNNode and operators:
  - `GNTopBase` (36 TOPs), `GNImgBase` (7 IMGs), `GNChopBase` (30 CHOPs), `GNDatBase` (23 DATs), `GNSopBase` (22 SOPs), `GNCompBase` (6 COMPs), `GNMatBase` (6 MATs).
  - Each sets family, provides cached data helpers, and overrides preview methods.
  - All 108 operators migrated. GNNode is now fully type-agnostic.
- [x] **Preview toggle** — global toolbar `CheckButton` ("Previews") to show/hide inline node previews:
  - `GNGraphEditor.previews_visible` flag controls whether `update_previews()` processes updates.
  - `GNGraphEditor.set_previews_visible(enabled)` shows/hides all preview controls on existing views.
  - Newly created views auto-hide their preview if `previews_visible` is false.
  - `GNNodeView.show_preview()` / `hide_preview()` toggle visibility with `reset_size()` to reflow node layout.
- [x] **Right-click context menu** — contextual `PopupMenu` on graph canvas:
  - Items: Add Node…, Copy, Cut, Paste, Duplicate, Delete, Select All, Undo, Redo.
  - Selection-aware: copy/cut/delete/duplicate grayed out when nothing is selected.
  - Clipboard-aware: paste grayed out when clipboard is empty.
  - Undo/redo state-aware: grayed out when no history available.
  - Shortcut hints displayed beside each item.
- [x] **Performance profiling overlay** — per-node cook time badge with toolbar toggle:
  - `GNNodeView._perf_label` (Label) shows `✓ 0.12ms` or `✗ 0.00ms` with color coding.
  - Color thresholds: green (<1ms), yellow (<5ms), red (≥5ms).
  - Created lazily on first `show_perf_overlay()` call (zero cost when never enabled).
  - `GNGraphEditor.perf_overlay_visible` flag; `set_perf_overlay_visible(enabled)` toggles all views.
  - `GNGraphEditor.update_perf_overlays()` called each cook frame (skipped when hidden).
  - Newly created views auto-show overlay if `perf_overlay_visible` is true.
  - Editor toolbar "Perf" `CheckButton` (off by default) wired to `_on_perf_toggled()`.
- [x] **MAT family** — material operators with per-object material binding:
  - `GNMaterialData` data type wrapping Godot's `Material` base class.
  - `GNMatBase` family base class with `_prepare_output()` helper and material label preview.
  - `PBR_MAT` — StandardMaterial3D wrapper: albedo color, metallic, roughness, specular, emission (toggle/color/energy), normal scale, transparency mode (Disabled/Alpha/Alpha Scissor/Depth Pre-Pass), alpha scissor threshold, cull mode (Back/Front/Disabled), triplanar UV. 3 optional TOP inputs (albedo texture, normal map, ORM texture).
  - `Shader_MAT` — ShaderMaterial wrapper: inline shader code (string param) or external `.gdshader` file. 8 float uniforms (u0–u7), 2 color uniforms (color0, color1), 2 optional TOP inputs (tex0, tex1). Lazy shader recompilation (only when source changes).
  - GeometryCOMP updated: 3 inputs (SOP, MAT, TOP). MAT input overrides fallback PBR; when disconnected, built-in PBR params still work.
- [x] **MergeCOMP** — groups multiple COMP scene nodes under a single Node3D parent:
  - Dynamic input COMP ports (auto-grow). Full transform params (t/r/s xyz) + visible toggle.
  - `_populate_from_network()` walks upstream connections, reparents COMP scene nodes **sorted by input port index** (port 0 = first child, port 1 = second, …). Users control hierarchy by which port they wire into.
  - RenderTOP updated to recognize MergeCOMP and adopt entire group node.
- [x] **Shadow system** — per-light and global shadow controls:
  - LightCOMP: shadow_bias, shadow_normal_bias, shadow_blur, shadow_opacity, directional shadow mode (Orthogonal/PSSM2/PSSM4).
  - RenderTOP: shadow atlas size, directional shadow size, shadow filter quality.
  - RenderTOP: integrated post-processing (tonemap, glow/bloom, DOF near+far with bokeh, SSAO, SSIL, SSR, adjustments, volumetric fog) applied directly to the render viewport's Environment and active camera.
  - GeometryCOMP: cast_shadow mode (Off/On/Double-Sided/Shadows Only).
- [x] **Bug fixes** — family assignment (`_init()` override without `super()`), expression re-cook (`_pre_cook` detection + `mode_changed` signal), torus Y-axis rotation visibility.
- [x] **Multiple viewer windows** — floating viewer windows pinned to any TOP node:
  - `GNViewerWindow` extends Window — dark background, TextureRect with aspect-preserving display.
  - Each window is pinned to a specific node via `node_id` and updates every cook frame.
  - Spawned via toolbar "+ Viewer" button (uses current viewer target) or right-click "Open Viewer" on a selected TOP node.
  - Windows track node renames automatically and clean up on new/load.
  - Multiple windows can be open simultaneously, each showing a different node's output.
  - Close button frees the window and removes it from the tracked array.
- [x] Stress test: 50+ node network (59 nodes across all 6 families, toolbar button + auto-report)
- [x] **Per-node preview toggle** — right-click context menu "Preview: ON/OFF":
  - `GNNode.preview_enabled` flag (default true, persists with save/load).
  - Global "Previews" toolbar toggle acts as master switch (sets all per-node flags).
  - Per-node toggle works independently — turn global off, then selectively re-enable specific nodes.
  - `update_previews()` skips nodes with `preview_enabled = false` (zero cost).
  - TOGGLE_PREVIEW added to `_CtxID` enum. Shows current state in menu label.
- [x] **WindowOUT open/close toggle** — `open` boolean parameter:
  - Default `false` (window doesn't pop up on creation). Resolution default changed to 512×512.
  - Close button sets `open = false` in inspector. Toggle back to `true` to reopen.
  - `_cook()` syncs `_window.visible` with param each frame.
- [x] README and basic documentation

### Phase 7: Creative Tools, Performance & Workflow
- [x] **ScriptCHOP** — user-editable GDScript for custom channel processing:
  - Runtime GDScript compilation via `GDScript.new()` + `reload()`.
  - `cook()` entry point with `me`, `inputs`, `op` (GNChannelData), `time`, `frame`, `dt` context.
  - `@param` annotations for dynamic inspector parameters.
  - `@input` annotations for dynamic multi-family input ports.
  - Optional `setup()` runs once after compilation. Instance reused across frames.
  - `time_dependent` toggle (default off). `from_dict()` override for save/load.
- [x] **ScriptDAT** — user-editable GDScript for table/text processing:
  - Same architecture as ScriptCHOP. `op` is GNTableData.
  - Default template builds a row table with configurable columns.
- [x] **ScriptIMG** — CPU-side pixel generation via GDScript:
  - `op` is GNImageData with `set_image(img)` method.
  - Extends GNImgBase — no SubViewport, pure CPU Image.
  - Replaces ScriptTOP (CPU image work separated from GPU TOP pipeline).
  - Use ImgToTOP bridge to convert output to GPU texture.
- [x] **ScriptSOP** — procedural geometry via GDScript:
  - `op` is GNGeoData. User builds mesh via SurfaceTool then `op.set_from_surface_tool(st)`.
  - Default template scatters random points in a sphere.
- [x] **GNScriptHelper** — shared static helper class for all 4 Script operators:
  - Runtime compilation, annotation parsing, context injection, preset management.
  - Factory presets at `res://addons/gonodes/presets/<family>/`.
- [x] **IMG family** — CPU-side image processing operators (new family):
  - `GNImageData` (wraps Image, no GPU texture) and `GNImgBase` (no SubViewport).
  - Teal color in graph editor. Family enum `GNFamily.Type.IMG`.
  - **Generators:** `NoiseIMG` (value/white noise via FastNoiseLite), `CheckerboardIMG` (configurable grid).
  - **Filters:** `BlurIMG` (separable box blur), `EdgeDetectIMG` (Sobel/Prewitt), `PixelSortIMG` (glitch art).
  - **Bridge:** `ImgToTOP` — uploads CPU Image to GPU ImageTexture for TOP pipeline. `TOPtoIMG` — GPU→CPU readback (reverse).
  - **Scripting:** `ScriptIMG` — user GDScript with `@param`/`@input` annotations.
  - **Sinks:** `ImageSaveOUT` (save to disk), `MovieOUT` (image sequence), `FFmpegOUT` (video encode via CLI).
  - User presets at `user://gonodes_presets/<family>/` (load/save via static methods).
  - Dynamic param rebuild with value preservation (same pattern as CustomShaderTOP).
- [x] **IMG preview optimization** — changed GNImgBase preview from TextureRect (GPU upload every cook) to lightweight text Label showing “512×320\nRGBA8”. No GPU upload, consistent with SOP/CHOP/DAT label-based previews. Helper `_format_name()` maps `Image.Format` enums to short names.
- [x] **Dynamic palette family iteration** — GNNodePalette now iterates `GNFamily.FAMILY_NAMES` dynamically instead of a hardcoded array. Adding a new family enum auto-populates the palette with zero code changes. Removed `_family_name_to_enum()` helper.
- [x] **Drop-wire-to-add-node workflow** — dropping a wire on empty canvas opens a filtered palette:
  - `GNExtensionRegistry.get_operators_accepting_family(family)` / `get_operators_producing_family(family)` with lazy `_input_family_cache` (built by instantiating all operators + `_init_ports()` to inspect ports, freed immediately).
  - `GNNodePalette.popup_at_filtered(pos, allowed_operators)` shows only compatible operators. Filter cleared on popup hide.
  - `GNGraphEditor` connects `connection_to_empty` / `connection_from_empty` signals. Stores `_pending_connection` dict, opens filtered palette, auto-connects first compatible port on selection (with undo/redo).
  - **Ghost wire**: semi-transparent line from source port to drop point while palette is open, drawn on expression-ref overlay. Stored in `_ghost_wire` dict, cleared on palette close.
- [x] **OSC input/output operators**:
  - `OscInCHOP` — receives OSC messages on configurable UDP port, maps numeric args to channels.
    - Channel naming: `/foo` → channel `foo`, `/bar` with 3 floats → `bar:0`, `bar:1`, `bar:2`.
    - Address filter, normalize names, max channels, reset pulse params.
  - `OscOUT` — sends CHOP channel values as OSC messages to target host:port.
    - Individual or bundle send mode. Prefix param. `is_sink = true`.
  - `OscInDAT` — receives OSC messages and logs as table rows (address, types, arg0-3, timestamp).
    - Replaced stub with actual UDP listener + `GNOscParser` integration. Ring buffer.
  - **Shared infrastructure:** `GNOscParser` static class (`addons/gonodes/core/gn_osc_parser.gd`) —
    lightweight OSC 1.0 binary parser/builder. Handles int32, float32, string, blob, bool, null,
    bundles. All encoding/decoding is pure GDScript using `PacketPeerUDP` for transport.
- [x] **MIDI input operators**:
  - `MidiInCHOP` — receives MIDI note/CC/pitch bend via Godot's built-in `InputEventMIDI`.
    - Channels: note, velocity, gate, channel, pitchbend, aftertouch, cc:N (auto-created per CC number).
    - Device filter, channel filter, normalize (0-1) toggle, reset pulse.
    - Uses `OS.open_midi_inputs()` / `_unhandled_input()` for event capture.
  - `MidiInDAT` — raw MIDI message log as table rows (type, channel, note, velocity, cc_num, cc_val, pitchbend, pressure, timestamp).
    - Same MIDI API, ring buffer with configurable max rows.
  - Device selection parameter (index-based, -1 = all devices).
- [x] **Audio input CHOP**:
  - `AudioInCHOP` — microphone capture via `AudioStreamMicrophone` + `AudioEffectCapture` on a
    dedicated AudioServer bus. Outputs left/right waveform channels + RMS level.
    - Creates/destroys bus dynamically. Mutes playback bus to prevent feedback.
  - `AudioSpectrumCHOP` — FFT analysis via Godot's `AudioEffectSpectrumAnalyzer`.
    - Logarithmic frequency distribution, configurable band count/range/FFT size.
    - Temporal smoothing. Convenience bass/mid/treble aggregate channels.
    - Can analyze any audio bus (Master, or AudioInCHOP's capture bus).
  - `AudioFileInCHOP` — audio file playback (WAV/OGG) with waveform capture.
    - Transport: play, stop, seek, loop. Volume (dB), mute toggle.
    - Output channels: left, right, level, pos, length, playing.
    - Dedicated AudioServer bus with capture effect for PCM extraction.
- [x] **Webcam / video input TOP**:
  - WebcamIMG — live camera feed via CameraServer as CPU Image. Chain → ImgToTOP for GPU.
  - Device selection (index), resolution, active toggle, horizontal mirror params.
- [x] **ImageSequenceIMG** — numbered frame playback as CPU Images:
  - PNG/WebP/JPG sequences with auto-discovery from any frame in the sequence.
  - Configurable frame range via file path, speed, loop modes (Loop, Hold First, Hold Last, Ping-Pong).
  - Expression-driven frame index for precise sequencing (`index` param, -1 for auto).
  - On-demand frame caching with optional preload-all toggle.
  - Auto-resolution from first frame. Pure CPU — no SubViewport.
- [x] **Performance: SubViewport UPDATE_ONCE** for non-time-dependent TOPs:
  - All SubViewports now created with `UPDATE_DISABLED`. `GNTopBase.execute_cook()` triggers `UPDATE_ONCE` after each cook — TOPs render exactly once per dirty cycle.
  - Time-dependent TOPs (e.g., CustomShaderTOP with `time_dependent` toggle) are re-cooked each frame by the cook engine, so they naturally re-render via the same mechanism.
  - Reduces GPU load significantly for static texture chains.
- [x] **Performance: Viewport pooling** — **DEFERRED (low value)**:
  - Original idea: reuse freed SubViewports instead of creating/destroying. Pool tracks available viewports by resolution to reduce allocation churn.
  - **Analysis concluded this is near-zero net gain.** Arguments:
    1. **Size mismatch kills reuse.** TOPs have varying resolutions (1024×1024 noise, 512×512 blur, 1920×1080 composite). A pooled viewport only helps if the next requester wants the exact same size. Resizing a SubViewport is just as expensive as creating one — Godot destroys and recreates the internal framebuffer on `size` change.
    2. **Allocation is infrequent.** Viewports are created once when a TOP first cooks (lazy creation), then persist for the node's lifetime. The churn scenario (rapid create/destroy cycles) rarely happens — users build a patch and run it.
    3. **Active-chain cooking already eliminates the biggest cost.** Inactive TOPs never cook, so their lazily-created viewports never allocate. The pool would only help nodes that *do* cook, and those need their viewports alive anyway.
    4. **Resolution buckets waste VRAM.** Rounding sizes up to power-of-2 buckets (256, 512, 1024, 2048) increases hit rates but trades allocation churn for memory bloat on oversized buffers.
    5. **Narrow use case.** The only scenario with measurable benefit: a patch with dozens of same-resolution TOPs that gets loaded/unloaded repeatedly (e.g., VJ set with everything at 1920×1080). Real but uncommon.
  - **Conclusion:** The existing lazy viewport creation + active-chain cooking + UPDATE_ONCE already cover this. Multi-threaded cook, C++ hot-paths, and GPU compute would deliver far greater measurable gains. Not implementing — documented as intentionally deferred.
- [x] **Performance: Active chain cooking**:
  - Only cook subgraphs that feed into a live sink (viewer, floating window, or any `is_sink` node).
  - Disconnected/orphan subgraphs skip cooking entirely (keep cached_output frozen).
  - **Engine-level** (editor-independent): structural sinks auto-detected via `GNNode.is_sink` flag — operators set `is_sink = true` in `_init()` (WindowOUT, future SpoutOut, MIDIOut, OSCOut, NDIOut, etc.).
  - **Editor-level**: UI sinks (viewer panel, floating windows) passed via `active_sinks`.
  - BFS follows wire connections and expression references (`chop()/op()/top()` calls) — implicit dependencies are tracked.
  - Event-driven: active set recomputed only when topology, sinks, or expressions change (not per-frame).
  - `GNNode.is_active` flag updated every frame; perf overlay shows "zzz" for inactive nodes.
  - Always-on (no toggle) — info bar shows "Active: N/M" count.
  - Clicking a node routes the viewer to it, making it a sink and instantly activating its chain.
- [x] **Performance: Lazy viewport creation**:
  - Viewport creation is deferred to first `_cook()` call — `_init_shader_viewport()` and `_ensure_viewport()` guard with `if _viewport != null: return`.
  - Disconnected TOPs have zero GPU footprint until first cook.
- [x] **Performance: GPU memory budget monitoring**:
  - **Opt-in toggle** ("VRAM" CheckButton in toolbar, default OFF) — zero overhead when disabled.
  - When enabled, reads `RenderingServer.get_rendering_info()` each frame for:
    - `RENDERING_INFO_TEXTURE_MEM_USED` — texture memory (SubViewport FBOs, imported textures, etc.)
    - `RENDERING_INFO_BUFFER_MEM_USED` — GPU buffer memory (meshes, particles, SSBOs)
  - Info bar displays: `VRAM: 142MB (tex 120 + buf 22)`.
  - Optional budget warning: `_vram_budget_mb` threshold — when exceeded, appends `⚠ >NMB` to the display.
  - Cost: `get_rendering_info()` reads an internal engine counter — effectively free (no GPU readback, no stall).
    Toggle exists for user peace of mind and to avoid visual clutter, not for performance reasons.
  - **Design rule for all perf metrics:** Always compute if it's free, only gate the *display* if it adds clutter. Any future perf metric that's just reading an engine counter (draw calls, object count, etc.) should follow the same approach: compute always, toggle the display. Only add a compute-level gate if the measurement itself is expensive (e.g., profiling individual node cook times per-frame at scale).
- [x] **Performance: Resolution downscaling for previews** — **DEFERRED (low value)**:
  - Original idea: render inline preview thumbnails at Â¼ or Â½ res; full res only for viewer + sinks.
  - **Analysis concluded this is near-zero net gain.** Arguments:
    1. **Viewport resize = GPU reallocation** — `SubViewport.size = x` destroys and recreates the render buffer; resizing 30 viewports at once causes a visible hitch.
    2. **Dual viewports per TOP doubles overhead** — the idle full-res viewport still holds VRAM; downstream consumers need full-res input textures as shader uniforms regardless.
    3. **Snapshot approach (GPU→CPU readback → ImageTexture thumbnail) adds work, not saves it** — the full-res `ViewportTexture` already exists in VRAM for downstream nodes; a TextureRect sampling it at 120×80 during UI draw is essentially free (one texture sample). CPU readback + resize + re-upload is strictly more expensive.
    4. **The only real case** is leaf TOPs (no downstream, not viewer target, not sink) where the SubViewport could render at Â¼ res. But active-chain cooking already **skips these entirely** (they don't cook, so their viewport never renders). The overlap makes the optimization redundant.
  - **Conclusion:** The big GPU wins (active-chain cooking, UPDATE_ONCE, lazy viewport creation) already cover this. Marked done — not implementing, documented as intentionally deferred.
- [x] **Keyboard shortcuts & workflow polish** (partial — core features done):
  - [x] Consistent shortcut reference card (help overlay, '?' key — semi-transparent overlay listing all shortcuts).
  - [x] Node alignment tools (H key = align horizontal, V key = align vertical) — context menu entries.
  - [x] Fit-to-view (F key zooms/pans to selected nodes or entire graph).
  - [x] Node bypass/disable toggle (B key — node passes input through unchanged, ⏩ indicator, dimmed, cook engine pass-through).
  - [x] Node lock toggle (L key — prevents parameter changes, ?? indicator, inspector dims and disables inputs).
  - [x] Wire style options (W key to cycle, toolbar dropdown — curved/straight/right-angle via `connection_lines_curvature`).
- [x] **Expression & scripting system refinement**:
  - [x] Autocomplete / intellisense for expression fields — via GNExpressionEditor CodeEdit autocomplete. Family-aware node filtering (chop(" shows CHOPs only, top(" shows TOPs only, op("/par("/set_par(" show all). Hierarchical path completion (type "subnet1/" to browse subnetwork nodes, "../" for parent). par()/set_par() context detection with second-arg param name suggestions. Node IDs color-coded by family.
  - [x] Expression syntax highlighting (CodeHighlighter in GNExpressionEditor — GONODES keywords green/purple, context vars cyan, math funcs blue, built-in utilities teal, GDScript keywords pink).
  - [x] Custom user-defined expression functions — `GNExpressionFunctions` registry + `fn()` dispatch on CookEngine. Register via `GNExpressionFunctions.register()`, call via `fn("name", args...)`.
  - [x] Multi-line expression editor popup — `GNExpressionEditor` (Window) with CodeEdit, syntax highlighting, live validation, autocomplete, Ctrl+Enter confirm, Escape cancel. Opened via ↗ button next to expression fields.
  - [x] Expression presets / snippets — Snippets ▾ dropdown in expression editor with 30+ templates across 6 categories (Time, Remapping, Smoothing, Noise, Node References, Math Patterns).
  - [x] Expression profiling — per-expression eval time (Âµs) tracked on `GNParameter.expression_eval_usec/avg_usec`, shown in expression field tooltip + editor info bar. Per-component timing independent.
  - [x] Built-in utility functions on CookEngine: `fit()`, `fit01()`, `smooth()`, `lag()`, `pulse()`, `step()`, `smoothstep()`, `cycle()`, `bounce()`, `noise1()`, `noise2()`, `trigger()`. Stateful functions use per-key state dicts.
  - [x] **`par()` / `parf()` / `pari()` / `pars()`** — parameter-to-parameter references (Houdini `ch()` equivalent). Self-reference with 1 arg, cross-node with 2 args. Typed variants guarantee return type. Circular dependency guard via `_evaluating_params` set. Demand-driven evaluation for EXPRESSION-mode targets.
  - [x] **`chop()` / `chopf()` / `chopi()` / `chops()`** — CHOP channel value references. `chop()` returns raw Variant, typed variants guarantee float/int/String. `chops()` formats floats to 4 decimal places.
  - [x] Windowed code editor for Script operators & CustomShaderTOP — `GNCodeEditor` (extends `GNBaseCodeEditor`) with CodeEdit, mode-adaptive syntax highlighting (GDScript for Script ops, GLSL for shaders), preset load/save via GNScriptHelper, reference cheatsheet, Ctrl+Enter confirm. Opened via "Edit ↗" button in GNParamRow. Both `GNCodeEditor` and `GNExpressionEditor` share a common base class (`GNBaseCodeEditor`) providing Window layout, CodeEdit configuration, key bindings, and status bar.
  - Reference: `help/expressions.md` for complete expression system docs.
- [x] **File output / save-to-disk operators** — all implemented with `is_sink = true` and `active` toggle:
  - **ImageSaveOUT** (IMG family) — saves CPU Image to disk (PNG, WebP, EXR). Auto-numbering for sequences.
  - **TextureSaveOUT** (TOP family) — GPU→CPU readback via `get_image()`, saves to disk (PNG, WebP, EXR). Auto-numbering.
  - **TableSaveOUT** (DAT family) — exports table/text to disk (CSV, TSV, JSON, plain text). Proper CSV escaping.
  - **MovieOUT** (IMG family / sink) — saves image sequence as numbered frames (PNG/WebP). Configurable prefix, padding, folder.
  - **FFmpegOUT** (IMG family / sink) — records frames to temp dir, encodes to video (H.264/H.265/VP9/ProRes) via `ffmpeg` CLI on deactivation. Requires `ffmpeg` on PATH.
  - **RecordOUT** (CHOP family) — accumulates channel samples into buffer, saves to CSV/JSON via rising-edge pulse. Max samples with ring-buffer trim.
  - All output operators set `is_sink = true` so active-chain cooking keeps them alive.
  - Common UX: `active` bool param — when checked, saving occurs every cook. Toggle off to stop.
- [x] **TOPtoIMG bridge** — GPU Texture → CPU Image conversion (`Texture2D.get_image()`). Reverse of ImgToTOP.
- [x] **Cook-once pulse** for Script operators (ScriptCHOP/DAT/SOP/IMG) and CustomShaderTOP:
  - New `cook_once` bool param (default OFF). Toggle ON → forces one cook, auto-resets to OFF.
  - Implemented in `_pre_cook()`: calls `mark_dirty()` then `set_param_value("cook_once", false)`.
  - Flexible in combination with `time_dependent`: TD=OFF + cook_once = cook exactly when pulsed.
- [x] **Renderer selection UI**:
  - **Automatic renderer with fallback**: `fallback_to_opengl3 = true` in project.godot.
  - Both editor and Player try Forward+ (Vulkan/D3D12) first, fall back to Compatibility (OpenGL 3.3) if the GPU doesn't support Vulkan.
  - No manual selection UI in the editor or Build dialog — fully automatic.
  - Power users can force a renderer via CLI: `--rendering-method mobile` or `--rendering-method gl_compatibility`.
  - Works cross-platform: Windows (D3D12/OpenGL), macOS (MoltenVK/OpenGL), Linux (Vulkan/OpenGL).
- [x] **Patch export to standalone apps** — **Phase 8: Quick Build implemented**:
  - **Two export modes** (both share the same generated project structure):
    - **Quick Build (Player copy)** ✅: Ship a pre-built `GONODESPlayer.exe` alongside the editor — copies Player + `.gnpatch` + assets to output folder. Instant, no setup required. Supports patch hot-swap (edit `.gnpatch` in-place, restart Player). Desktop only (Win/Mac/Linux).
    - **Full Export (Godot export pipeline)**: (future) Generates a minimal Godot project from the patch, then invokes `godot --export-release` to produce a single self-contained binary or web/mobile package. Requires Godot export templates installed (~500MB one-time download). Supports all Godot platforms including web (WASM) and mobile (Android/iOS). **Required for web/mobile** — no filesystem access means patches must be baked into `.pck`.
  - **Runtime performance is identical** between both modes — once the patch is loaded and nodes are in VRAM, the cook engine runs the same code path. Quick Build adds only ~10-50ms startup overhead for filesystem I/O vs `.pck` memory-mapped loading.
  - **Implementation:**
    - `scenes/player_main.gd` + `scenes/player_main.tscn` — minimal Player runtime:
      - Loads `config.json` + `.gnpatch`, boots GNCookEngine, WindowOUTs auto-open their OS windows.
      - CLI args: `--patch <path>`, `--rendering-method <method>`. Escape key quits.
      - Minimal info label as fallback display (shown when no WindowOUT opens).
      - No editor UI — pure cook engine + output.
    - `addons/gonodes/core/gn_patch_exporter.gd` — Quick Build logic:
      - `quick_build()` → copies Player binary + `.pck` + `.gnpatch` + project folder + `config.json` to output dir.
      - Player binary discovery: searches next to exe, project root, `player/`, `build/` subdirs.
      - `config.json` format: just `patch` filename.  No renderer/VSync/FPS — all automatic via fallback + WindowOUTs.
      - Recursive directory copy for project assets (skips hidden dirs).
      - Progress + completed signals for UI feedback.
    - `addons/gonodes/ui/gn_export_dialog.gd` — export dialog Window:
      - Form: output directory picker only.  All runtime settings are automatic.
      - Default output dir: `<patch_stem>_build/` sibling to the `.gnpatch`.
      - Progress label shows real-time build status. Green checkmark on success, red on failure.
      - "Build" button starts Quick Build, "Cancel" closes dialog.
    - `gn_editor.gd` wiring:
      - "Build" toolbar button. Requires saved patch (prompts if unsaved).
      - Preloads `_GNExportDialogScript`, creates dialog as hidden child window.
  - **Renderer in standalone apps:**
    - Automatic via `fallback_to_opengl3 = true` baked into project.godot / `.pck`.
    - No self-relaunch logic needed. Power users can override with `--rendering-method` CLI flag.
  - **Extension distribution for exported apps**: When GONODES ships as a
    standalone application (not running inside the Godot editor), users will need
    a way to install extensions without touching `res://addons/`. Design a
    user-facing `Extensions/` folder (e.g. next to the executable or in
    `user://extensions/`) that `scan_extensions()` also searches. This keeps the
    same `gn_ext_<name>/gn_extension.cfg` manifest convention but lets
    end-users drag-and-drop extension folders without rebuilding the project.
    Consider:
    - Scanning both `res://addons/gn_ext_*` (dev) and `user://extensions/gn_ext_*` (end-user).
    - An in-app "Extensions" settings panel listing installed / available extensions with enable/disable toggles.
    - Version compatibility checks (engine version, GONODES version) in the manifest.
    - Hot-reload of extensions without restarting the editor.
- [x] **Node help system**:
  - `?` button in node header **and** right-click context menu opens a help Window.
  - Help window: `Window` + `RichTextLabel` rendering per-node documentation.
  - Custom `.md` docs stored in `res://addons/gonodes/help/<family>/<node_type>.md`.
  - File naming convention: `<node_type>.md` (e.g. `noise_top.md`, `lfo_chop.md`).
  - Auto-generation: builds docs from existing `node_description`, port descriptions,
    and parameter descriptions already defined in each operator — zero manual authoring.
  - Template: family-colored header, description, inputs table, outputs table,
    parameters table (with type/default/range), properties section.
  - **Example patches**: `.gnpatch` files in `help/<family>/` whose filename starts
    with `<node_type>_` are auto-discovered via directory scan (e.g., `noise_color.gnpatch`,
    `noise_simple.gnpatch`). Multiple examples per node supported — each gets its own button.
  - Discovery is lazy (scans when help is opened), no manifest or startup registration needed.
  - "Open Example Patch" buttons at bottom of help page open the patch in a new
    floating editor window (current work stays untouched).
  - Implementation: `GNHelpWindow` class (`addons/gonodes/ui/gn_help_window.gd`),
    `?` button via `_setup_help_button()` in `GNNodeView`, `NODE_HELP` context
    menu item in `GNGraphEditor`, wired through `gn_editor.gd`.
  - **Main Help Window**: `GNMainHelpWindow` (`addons/gonodes/ui/gn_main_help_window.gd`) —
    centralized reference hub with sidebar Tree + content pane. Opened via "📖 Help" toolbar
    button or F1 key. Uses `GNMarkdownRenderer` (`addons/gonodes/ui/gn_markdown_renderer.gd`)
    for Markdown→BBCode conversion. See Section 29 for full details.
  - **108 example patches** across all 6 help families (see Hard Rule 25.21):
    - CHOP: 32 patches covering all 31 node types (lfo, noise, constant, math, wave, pattern, filter, lag, cross, merge, hold, speed, count, trigger, timer, logic, limit, switch, select, rename, ramp, RecordOUT, physics, scriptchop, audiofilein, audioin, audiospectrum, midiin, oscin, oscout, null)
    - TOP: 29 patches covering all 28 node types (noise, blur, circle, composite, constant, crop, cross, displace, edge, feedback, flip, hsv_adjust, level, lookup, ramp, rectangle, text, threshold, tile, transform, resolution, switch, null, TextureSaveOUT, moviefilein, glsl, postprocess, render)
    - SOP: 15 patches covering all 15 node types (box, circle, cylinder, grid, line, sphere, torus, noise, transform, merge, subdivide, wireframe, null, switch, scriptsop)
    - COMP: 13 patches covering all 12 node types (camera×2, geo, light, rigid_body, static_body, joint, area, soft_body, merge_comp, subnet, in_tunnel, out_tunnel)
    - DAT: 16 patches covering all 16 node types (constant, text, scriptdat, sort, transpose, select, merge, evaluate, chop_to_dat, dat_to_chop, null, switch, info, TableSaveOUT, midiin, oscin)
    - MAT: 3 patches covering all 2 node types (pbr×2, shader)
  - Folder structure:
    ```
    addons/gonodes/help/
    ├── top/                               # 29 patches
    │   ├── noise_simple.gnpatch           # NoiseTOP basic demo
    │   ├── noise_color.gnpatch            # NoiseTOP color mode
    │   ├── blur_basic.gnpatch
    │   ├── render_scene.gnpatch
    │   └── ...
    ├── chop/                              # 32 patches
    │   ├── lfo_basic.gnpatch
    │   ├── lfo_waveforms.gnpatch
    │   ├── math_operations.gnpatch
    │   └── ...
    ├── sop/                               # 15 patches
    │   ├── box_basic.gnpatch
    │   ├── noise_terrain.gnpatch
    │   └── ...
    ├── comp/                              # 13 patches
    │   ├── camera_basic.gnpatch
    │   ├── light_setup.gnpatch
    │   └── ...
    ├── dat/                               # 16 patches
    │   ├── constant_basic.gnpatch
    │   ├── scriptdat_table.gnpatch
    │   └── ...
    └── mat/                               # 3 patches
        ├── pbr_metallic.gnpatch
        ├── pbr_emissive.gnpatch
        └── shader_gradient.gnpatch
    ```
  - **Extension help patches**: GN extensions (`gn_ext_*`) ship their own
    help patches in `res://addons/gn_ext_<name>/help/<family>/`. The help window
    scans both core help dirs and extension help dirs automatically (see §28.10).
- [x] **Node grouping / sub-networks** — **Done: SubNetworkNode, InTunnel, OutTunnel, hierarchical op() paths, undo/redo, copy/paste, help**:
  - Select multiple nodes → Ctrl+G "Group into Sub-Network" creates SubNetworkNode with auto-generated tunnels.
  - Double-click body or press Enter to dive into sub-network. Backspace or breadcrumb click to dive out.
  - Breadcrumb bar above graph editor shows navigation stack (root > subnet1 > ...).
  - InTunnel/OutTunnel pseudo-nodes bridge data between parent and inner networks.
  - Inner cook engine runs recursively — injected data into InTunnels, reads OutTunnel results.
  - Multi-output support via `get_output_data(port_index)` virtual in GNNode, overridden in SubNetworkNode.
  - Hierarchical expression paths: `op("subnet1/noise1")`, `chop("../lfo1", "out")`, `top("/root_node")`.
  - Full serialization via nested `inner_network.to_dict()` / `from_dict()`.
  - **Undo/redo**: Group-into-subnet is a single UndoRedo action — Ctrl+Z restores original nodes and connections.
  - **Cross-level clipboard**: Copy/paste works across sub-network levels (clipboard persists during navigation). Undo history cleared on level change to prevent cross-level replay.
  - **Help tooltips**: SubNetworkNode, InTunnel, OutTunnel have rich node_description with usage hints. SubNetworkNode tooltip shows inner node count.
  - **Cold-cache robustness**: All files referencing sub-network types use explicit `preload()` constants instead of bare `class_name` for reliable first-import on fresh projects.
  - Files: `in_tunnel.gd`, `out_tunnel.gd`, `sub_network_node.gd` (COMP family). Modified: `gn_cook_engine.gd`, `gn_node.gd`, `gn_graph_editor.gd`, `gn_node_view.gd`, `gn_editor.gd`, `gn_extension_registry.gd`.
- [x] **Minimap**:
  - Built-in GraphEdit minimap (200×150px). Toggle with M key or toolbar CheckButton.
  - Click to navigate. Viewport rectangle shows current zoom region.
- [x] **Node bookmarks**:
  - Ctrl+1-9 to set bookmark on selected node. 1-9 to jump to bookmarked node.
  - Blue numbered badge displayed on bookmarked nodes. Up to 9 per session.
- [x] **Auto-layout**:
  - Ctrl+L or toolbar "Layout" button. Topological BFS layering (sources at left, sinks at right).
  - Configurable spacing (280px horizontal, 100px vertical). Undoable via Ctrl+Z.
  - Context menu entry "Auto-Layout All" with Ctrl+L shortcut.
- [x] **Parameter presets**:
  - **GNParamPresetManager** (`gn_param_preset_manager.gd`) — static utility class for parameter snapshot management:
    - **Copy / Paste**: In-memory clipboard. `copy_params(node)` serializes all params via `GNParameter.to_dict()`. `paste_params(node)` applies only to same operator type (matched by `get_script().get_global_name()`). `can_paste(node)` gate.
    - **Named Snapshots**: `save_preset(node, name)` writes JSON to `user://gonodes_param_presets/<OperatorType>/<name>.json`. `load_preset(node, path)` reads JSON and applies matching params. `get_preset_list(operator_type)` scans both factory (`res://addons/gonodes/presets/params/`) and user dirs.
    - **Delete**: `delete_preset(path)` removes user presets (factory presets protected). **Reset**: `reset_to_defaults(node)` constructs a temp default instance and copies initial values.
    - JSON format: `{ operator_type, preset_name, version, params: { name → GNParameter.to_dict() } }`.
  - **Context menu** — 5 new entries in `_CtxID` enum (`COPY_PARAMS`, `PASTE_PARAMS`, `RESET_PARAMS`, `SAVE_PARAM_PRESET`, `LOAD_PARAM_PRESET_BASE`):
    - Copy/Paste/Reset enabled when single node selected. Paste gated on clipboard type match.
    - "Load Param Preset" is a dynamic submenu populated from `get_preset_list()`.
    - "Save Param Preset…" opens a name-input dialog.
  - **Inspector toolbar** — `GNParamInspector` header gains Copy / Paste / Reset buttons + "Presets ▾" `MenuButton`:
    - Presets dropdown dynamically lists saved presets with "Save Preset…" at top and "Delete: name" for user presets.
    - All actions trigger `node.parameters_changed` signal → inspector auto-rebuilds rows.

### Phase 7.5: Three-Tier Resource System ✅
- [x] **GNResourceLoader** (`gn_resource_loader.gd`) — unified resource loading abstraction:
  - Static utility class (~340 lines). Handles all three path tiers transparently.
  - `PathTier` enum: `BUNDLED` (res://), `PROJECT` (project://), `ABSOLUTE`, `EMPTY`.
  - `classify(path)` → PathTier. `resolve(path, project_dir)` → absolute filesystem path.
  - `to_project_relative(abs_path, project_dir)` → project:// path. `to_saveable(abs_path, project_dir)` → best portable path.
  - `exists(path, project_dir)` — works across all tiers.
  - Type-specific loaders: `load_texture()`, `load_image()`, `load_font()`, `load_audio()`, `load_shader()`, `load_video()`, `load_any()`.
  - Tier 1 (res://) uses `ResourceLoader.load()`. Tier 2/3 use filesystem APIs: `Image.load_from_file()`, `FontFile.load_dynamic_font()`, `AudioStreamOggVorbis.load_from_buffer()`, `Shader.code = FileAccess.get_as_text()`, `VideoStreamTheora.file = path`.
  - `scan_directory(dir_path, extensions)` — lists files matching extensions in a given directory.
- [x] **GNProjectManager** (`gn_project_manager.gd`) — project folder lifecycle:
  - `set_from_patch_path(path)` — creates sibling folder to `.gnpatch` file with standard subfolders.
  - `SUBFOLDERS`: textures, fonts, video, audio, models, shaders, presets, scripts, data.
  - `scan_subfolder()`, `scan_all_subfolders()` — lists project files by category.
  - `resolve_path(rel)` → absolute. `to_saveable(abs)` → project:// path. `has_project()` → bool.
  - `signal project_changed(project_dir: String)`.
- [x] **project_dir injection pipeline**: `GNProjectManager` → `GNCookEngine.project_dir` → `GNNode.project_dir` (set each frame alongside `current_delta`, `elapsed_time`, `current_frame`).
- [x] **All 7 file-loading operators migrated** from `ResourceLoader.load()` to `GNResourceLoader`:
  - `AudioFileInCHOP` → `GNResourceLoader.load_audio()`
  - `MovieFileInTOP` → `GNResourceLoader.load_video()`
  - `TextTOP` → `GNResourceLoader.load_font()`
  - `ShaderMAT` → `GNResourceLoader.load_shader()`
  - `ImageFileInIMG` → `GNResourceLoader.load_image()`
  - `ImageSequenceIMG` → `GNResourceLoader.load_image()` + `resolve()` + `exists()`
  - `FFmpegInTOP` → `GNResourceLoader.resolve()` before `_create_ffmpeg_stream()`
- [x] **File param UI updated** to three-tier dropdown:
  - `_create_file_control()` in `gn_param_row.gd`: OptionButton with Browse "…", Refresh "↻", Clear "X" buttons.
  - `_populate_file_dropdown()`: Three sections with separators — "── Bundled ──" (res://), "── Project ──" (project folder), "── External ──" (absolute paths with ⚠ warning).
  - `_open_file_browse_dialog()`: Native FileDialog, auto-converts to project:// if file is inside project folder.
- [x] **Editor wired to GNProjectManager**: save/load/new/setup/auto-restore all update `_project` and `cook_engine.project_dir`.
- [x] File output operators (TextureSaveOUT, TableSaveOUT, RecordOUT, MovieOUT, FFmpegOUT) confirmed write-only, use STRING params — not affected by resource loader migration.

### Phase 7.6: Parameter References & Copy Path ✅
- [x] **`par()` expression function** — Houdini-style `ch()` equivalent for parameter-to-parameter references:
  - Self-reference: `par("scale")` reads own node's param (most common, like Houdini's `ch("scale")`)
  - Cross-node: `par("noise1", "scale")` reads another node's param
  - Hierarchical: `par("../lfo1", "frequency")` with path resolution
  - Typed variants: `parf()` (guaranteed float), `pari()` (guaranteed int), `pars()` (guaranteed String)
  - Implementation: methods on GNCookEngine, `_current_eval_node` tracks which node's expression is being evaluated, single-arg `par()` resolves against self
- [x] **Circular dependency guard** (simple guard, Option A):
  - `_evaluating_params: Dictionary` tracks `"node_id:param_name"` keys currently being evaluated
  - If `par()` encounters a key already in the set → cycle detected → returns `fallback_value` + warns
  - Guard keys are pushed before eval and erased after, covering both scalar and component expressions
  - Demand-driven: if target param is EXPRESSION mode and not yet evaluated this frame, evaluates it inline with guard protection
  - **Future: Full Parameter DAG** — build a mini topological sort of all parameter dependencies per cook frame for optimal evaluation order and guaranteed cycle detection. Current simple guard handles the 99% case; full DAG would also enable lazy re-evaluation (only re-eval params whose deps changed).
- [x] **Copy Node Path** (right-click context menu on graph editor):
  - "Copy Node Path" → copies `op("node_id")` to clipboard
  - "Copy Output Ref" → copies family-appropriate reference:
    - CHOP: `chop("name", "out")` (uses first channel name if available)
    - TOP: `top("name")`
    - Other: `op("name")`
  - Both require exactly one node selected; disabled otherwise
  - Menu items show the actual reference string that will be copied
- [x] **Copy Parameter Reference** (right-click on param name label in inspector):
  - Three options per parameter:
    - "Copy Self Ref" → `par("param_name")` (for expressions on the same node)
    - "Copy Cross Ref" → `par("node_id", "param_name")` (for expressions on other nodes)
    - "Copy op() Ref" → `op("node_id", "param_name")` (alternative syntax)
  - Right-click the parameter name label → popup with all three options
  - Selected reference is copied to system clipboard for paste into expression fields
  - Files modified: `gn_cook_engine.gd`, `gn_graph_editor.gd`, `gn_param_row.gd`

### Phase 7.8: Wire Replacement, Palette Sections & Camera Post-Processing ✅
- [x] **Wire replacement UX** — connecting to an already-occupied input auto-disconnects the old wire and connects the new one. Compound undo action (remove old + add new). `GNNetwork.connect_nodes()` detects existing connections, removes old, emits `connection_removed`, then connects new. `GNGraphEditor._on_connection_request()` snapshots old connection for undo.
- [x] **Operator palette sections** — sub-sections within family groups in the node palette:
  - `OperatorEntry.section` field; `register_operator()` accepts optional section parameter.
  - `get_operator_registry_sectioned()` and `get_section()` query APIs.
  - `GNNodePalette._populate_tree()` renders section sub-headings (non-selectable, lighter colour).
- [x] **Extension-level auto-sections** — `[extension]` header in `gn_extension.cfg` supports `section=` key. All operators from that extension inherit the section (per-operator override still possible). Defaults to extension name.
  - Shadertoy manifest: `section="Shadertoy"` at extension level (removed per-operator overrides).
  - FFmpeg manifest: `section="FFmpeg"` at extension level.
- [x] **RenderTOP integrated post-processing** — camera/environment post-processing FX built into RenderTOP (no separate operator needed):
  - Applied directly to RenderTOP's 3D SubViewport `Environment` and active camera.
  - **Glow/Bloom:** intensity, strength, bloom, HDR threshold, 5 blend modes.
  - **Depth of Field:** near + far blur with distance/transition, bokeh size + shape (box/hex/circle).
  - **Tonemap:** Linear, Reinhard, Filmic, ACES with exposure and white point.
  - **SSAO:** radius, intensity, power.
  - **SSIL:** radius, intensity, sharpness, normal rejection.
  - **SSR:** max steps, fade in/out, depth tolerance.
  - **Adjustments:** brightness, contrast, saturation.
  - **Volumetric Fog:** density, albedo, emission, energy, length.
  - DOF applied to the active camera (CameraCOMP or default) via `_apply_dof_to_active_camera()`.

### Near-term
- [x] SOP family (procedural geometry: Grid, Box, Sphere, Torus, Cylinder, Line, Circle, Transform, Noise, Subdivide, Wireframe, Merge, Null, Switch)
- [x] DAT family (Constant, Text, Select, Merge, Transpose, Sort, Evaluate, Switch, bridges)
- [x] MAT family (PBR_MAT, Shader_MAT)
- [x] COMP family (GeometryCOMP, CameraCOMP, LightCOMP, MergeCOMP + RenderTOP bridge)
- [x] Physics COMPs (RigidBodyCOMP, StaticBodyCOMP, SoftBodyCOMP, AreaCOMP, JointCOMP + PhysicsCHOP readback)
- [x] Keyboard shortcuts and workflow polish (Alt+A palette, context menu shortcuts, per-node preview toggle)

### Phase 7.7: Ramp Parameters & Canvas Annotations ✅
- [x] **RAMP parameter type** — new `ValueType.RAMP` (index 12) in GNParameter. Data: Array of keypoint dicts `[{pos, value, left_tangent, right_tangent}]`. `create_ramp()` factory with default linear ramp (0→0, 1→1). `sample_ramp()` static method with cubic Hermite interpolation.
- [x] **GNRampEditor widget** (`gn_ramp_editor.gd`, ~290 lines) — custom `_draw()` curve editor. Grid background, curve rendering, filled area, draggable keypoints, tangent handles, add/remove points, Ctrl+click smooth toggle.
- [x] **RAMP in inspector** — `_create_ramp_control()` in GNParamRow, wired into dispatch and `_update_value_display()`.
- [x] **RAMP serialization** — `_variant_to_json()` wraps as `{"_type": "Ramp", "keys": [...]}`, `_json_to_variant()` unwraps (with raw array fallback). Full `to_dict()`/`from_dict()` round-trip.
- [x] **`ramp()` expression function** on CookEngine — `ramp("param", t)` (self-ref) or `ramp("node", "param", t)` (cross-node). Delegates to `GNParameter.sample_ramp()`.
- [x] **Expression editor** — `ramp()` added to autocomplete, two snippet presets (self + cross-node).
- [x] **Network annotations** — `GNNetwork.annotations` Array[Dictionary] with CRUD methods (add/get/update/remove), `annotations_changed` signal. Counter-based unique IDs.
- [x] **GNNetworkBox** (`gn_network_box.gd`, ~200 lines) — colored grouping rectangle, z_index=-10, title edit, drag/resize, context menu.
- [x] **GNStickyNote** (`gn_sticky_note.gd`, ~195 lines) — editable text note, z_index=-9, drag/resize, context menu, default yellow.
- [x] **Annotation integration** — context menu items in GNGraphEditor, view lifecycle management, serialization in `.gnpatch` files.
- [x] **23 new tests** in `test_ramp_and_annotations.gd` — ramp factory, sampling, serialization, annotation CRUD, round-trip. All 167 tests passing.
- [x] **RampCHOP** (`ramp_chop.gd`, ~120 lines) — dynamic ramp curve → CHOP channel operator. `count` param (1–16) dynamically creates/removes `nameN`/`rampN` parameter pairs at cook time, triggering `parameters_changed` for live inspector rebuild. `samples` param (1–4096) controls curve evaluation resolution (1 = scalar for `chop()` reads). `from_dict()` override restores dynamic slot count before base-class param restore. 9 new tests in `test_ramp_chop.gd`. All 690 tests passing.

### Medium-term
- [x] File output operators (ImageSaveOUT, TextureSaveOUT, TableSaveOUT, MovieOUT, FFmpegOUT, RecordOUT + TOPtoIMG bridge)
- [x] POP family (GPU point/particle operators — see Section 18)
- [x] LibGodot embedding — **IMPLEMENTED** (`libgonodes/` C shared library)
  - Full C API (`gonodes_host.h`) with 30+ functions: lifecycle, patch management, frame loop, input injection, output reading, introspection, callbacks, stats
  - GPU context sharing: Vulkan (VkDevice), Metal (MTLDevice), OpenGL (HGLRC/EGLContext) — zero-copy texture exchange on shared device
  - GNEmbeddedHost GDScript singleton replaces player_main.gd for embedded mode
  - 6 bridge operators: HostInTOP, HostInCHOP, HostInDAT, HostOutTOP, HostOutCHOP, HostOutDAT
  - Stateful hot-reload (preserves CHOP values, timers, feedback textures)
  - 5 example host apps: SDL+OpenGL, Vulkan, GLFW+OpenGL, Metal (macOS), params demo (headless)
  - CMake build system, integration guide in `dev_docs/INTEGRATION.md`
- [ ] Syphon (macOS) / Spout (Windows) texture sharing
- [x] FFmpeg GDExtension addon (`gn_ext_ffmpeg`) — **Done: first reference extension for GNExtensionRegistry**
  - Wraps [EIRTeam/EIRTeam.FFmpeg](https://github.com/EIRTeam/EIRTeam.FFmpeg) GDExtension
  - FFmpegInTOP: H.264, H.265, VP9, AV1, ProRes playback via dynamic `ClassDB.instantiate("FFmpegVideoStream")`
  - Demonstrates `gn_extension.cfg` manifest, `ClassDB.class_exists()` dependency guards
  - Core MovieFileInTOP always available (Theora .ogv); FFmpegInTOP appears only when GDExtension installed
- [x] HAP codec GDExtension — GPU-direct S3TC/DXT video playback for VJ workflows — **IMPLEMENTED** (`gn_ext_hap`)
  - HAP, HAP Alpha, HAP Q variants via native C++ GNHapDecoder/GNHapEncoder (Vidvox/hap + Snappy + squish)
  - HapInTOP: GPU-direct DXT playback — raw S3TC blocks upload to GPU with zero CPU pixel decode
  - HapOUT: Encode input texture to HAP MOV via DXT compression + Snappy + QuickTime muxer
  - Enables alpha-channel video without image sequences
  - **Exception to CPU-first philosophy:** HAP frames are already GPU-compressed (S3TC/DXT), so the playback operator is a TOP — CPU detour would be counterproductive.
- [ ] **CPU-side video frame decoder GDExtension** (`gn_ext_video_decoder`) — enables IMG-family video operators
  - Custom GDExtension (~300-500 LOC C++) using FFmpeg's C API directly (libavcodec/libavformat/libswscale).
  - **Motivation:** Godot's `VideoStreamPlayback` only exposes GPU textures (`get_video_texture()`). Internally, both Theora and FFmpeg decode to CPU pixel buffers first, then immediately upload to GPU via `RenderingServer::texture_2d_update()` — but this CPU data is never exposed via any public API. EIRTeam.FFmpeg also doesn't expose it (just another `VideoStream` subclass).
  - Exposes a `VideoFrameDecoder` class to GDScript:
    - `open(path) → Error`, `decode_next_frame() → Image`, `seek(time_sec)`, `get_duration()`, `get_fps()`, `close()`
  - Decodes video frames to `Image::create_from_data()` — stays CPU-side, zero GPU involvement.
  - Would enable proper **MovieFileInIMG** and **FFmpegInIMG** operators outputting `GNImageData` directly into the IMG pipeline.
  - The FFmpeg shared libraries are already shipped in `addons/gn_ext_ffmpeg/native/win64/` and `linux64/`.
  - Eliminates the wasteful CPU→GPU→CPU roundtrip that `get_video_texture().get_image()` would cause (~1-4ms stall per frame).
  - Frame-accurate seeking, frame stepping — things `VideoStreamPlayer` handles poorly.
  - **OpenCV was considered and rejected:** no production-ready Godot 4 GDExtension exists, and `cv::VideoCapture` just wraps FFmpeg internally anyway — massive dependency for nothing extra.
- [x] Custom GLSL shader TOP (user-editable shader code) — **Done: CustomShaderTOP**
- [x] ComputeShaderTOP (user-editable GPU compute shader — see Section 27)
- [x] **Multi-buffer RenderTOP** — auxiliary render buffer outputs from the 3D viewport:
  - RenderTOP gains additional TOP outputs: depth, normals, velocity (motion vectors).
  - Downstream canvas_item shader TOPs can use depth+color as two texture inputs.
  - Enables hybrid 2D post-processing chains fed by 3D scene data (e.g., DOF TOP = color + depth).
  - Implementation: second SubViewport pass with `Viewport.DEBUG_DRAW_*` or custom shader pass extracting buffers.
  - Works with existing canvas_item shader infrastructure.

### Performance & GPU Optimizations (Post-Phase 7)
- [ ] **Multi-threaded cook engine (Tier 3 — automatic level-based parallelism)**:
  - Group topo-sorted nodes into dependency "levels" (nodes at the same level have no mutual dependencies).
  - Cook each level in parallel using Godot's `WorkerThreadPool.add_group_task()`.
  - Main-thread-affine nodes (TOPs with SubViewport, UI widgets) are fenced — they cook on the main thread between parallel batches.
  - CPU-only families (CHOP, DAT, SOP, IMG) are the primary parallel candidates.
  - Requires `Mutex` guards on `_cooked_this_frame`, `last_dirty_ids`, and `_dirty_immediate_downstream()`.
  - Expected speedup: proportional to independent branch count (2-4× for typical networks with parallel chains).
- [ ] **User-facing thread regions (Tier 4 — annotation-based parallel groups)**:
  - Users mark network boxes as "parallel regions" via a checkbox on GNNetworkBox.
  - Nodes inside a parallel-region box are cooked concurrently using `WorkerThreadPool`.
  - Adds user control over parallelism — experts can force-parallelize known-safe subgraphs.
  - Requires validation: warn if a parallel region contains main-thread-affine nodes (TOPs, UI).
  - Deferred until Tier 3 infrastructure is stable.
- [x] **Input hash guard (Tier 2 — parameter-level cook skipping)** — before cooking a dirty node, hashes all resolved parameter values + upstream input data timestamps. If hash matches last frame, the cook is skipped entirely (not just propagation — the node doesn't execute `_cook()` at all). 100% accurate for parameter-driven changes. Time-dependent nodes include frame timing in hash so they always cook. `_dirty_immediate_downstream()` marks only direct successors when a node does cook — cascade continues in topo order. Replaces the former output fingerprinting approach (`compute_fingerprint()` / `is_gpu_resident()` removed from all GNData classes).
- ~~GPU compute shaders for CHOPs~~ — **REMOVED.** CPU readback latency (upload SSBO → dispatch → fence → readback) negates parallelism gains for typical CHOP data sizes (control-rate: ~4 KB, audio-rate: ~172 KB/ch). CHOPs need data back on CPU for expressions, parameter driving, and cook engine hashing. Already covered by 92 native C++ operators via GDExtension (pointer arithmetic inner loops within 2-3× of GPU compute for these sizes). Users needing extreme parallel processing can use ComputeShaderTOP (stays on GPU) or ScriptCHOP with native helper.
- [x] **Cook engine Tier 1 optimizations** — three quick wins implemented:
  - **Active-only pre-cook**: `_pre_cook_pass()` skips inactive nodes entirely.
  - **Expression consumer map**: `_should_eval_expressions()` checks whether upstream sources cooked this frame before re-evaluating expressions. Avoids per-frame polling of every expression on every active node.
  - **Inactive dirty propagation cutoff**: `propagate_dirty()` marks inactive nodes dirty but does not BFS through them — prunes frozen subgraphs from the walk.
- [x] **CPU fallback for compute-dependent operators** — enables Compatibility renderer (Web/WebGL2, old hardware). See Section 34 Phase 3:
  - **POP family CPU fallback**: CPU particle simulation using `PackedVector3Array` + `MultiMesh.set_instance_transform()`. Slower than GPU compute but functional for small particle counts (~10K). Each POP operator would have a `_cook_cpu()` path alongside the existing GPU `_cook()`.
  - **VOL family CPU fallback**: CPU voxel grid using `PackedFloat32Array`. Iterative passes (blur, advect, pressure solve) run on CPU. Usable for low-resolution volumes (32³–64³). Fluid sim would be significantly slower.
  - **ComputeShaderTOP CPU fallback**: Not feasible — user-written GLSL compute code can't run on CPU. Instead, suggest users use CustomShaderTOP (`shader_type canvas_item` fragment shader) which works on all renderers including Compatibility.
  - **Graceful degradation already implemented**: `requires_compute()` virtual on `GNNode` + cook engine skip logic with warning badge. Incompatible nodes are skipped with a yellow ⚠ badge and downstream chains receive null input (same as disconnected ports).
  - **Priority**: Low — desktop targets always have Vulkan/D3D12. Only needed if Web or legacy-GPU export becomes a user requirement.
- [x] **GDExtension (C++) hot-path migration — Phase 1 & 2 complete** (source written and compiled — Windows x86_64 binary live):
  - **Architecture:** C++ GDExtension provides `RefCounted` processor classes (e.g., `GNNativeBlur`) with `process()` methods. GDScript wrapper operators (e.g., `BlurIMGNative`) delegate hot loops to C++ when available, falling back to pure GDScript otherwise. Extension pattern: `addons/gn_ext_native/native/` for C++ source, `addons/gn_ext_native/` for GDScript wrappers + `gn_extension.cfg`.
  - **Phase 1 — 6 operators ported (source):** 3 IMG (GNNativeBlur, GNNativeNoise, GNNativePixelSort) + 3 SOP (GNNativeParticle, GNNativeMetaball, GNNativePolyReduce). Each has `.cpp` + `.h` files in `addons/gn_ext_native/native/src/img/` and `src/sop/`.
  - **Phase 2 — 10 operators ported (source):** 8 SOP (GNNativeIsoSurface, GNNativeRay, GNNativeFacet, GNNativeFuse, GNNativeSubdivide, GNNativeCopy, GNNativeLSystem, GNNativeSpring) + 1 IMG (GNNativeEdgeDetect) + 1 CHOP (GNNativeSmooth). Files in `src/sop/`, `src/img/`, `src/chop/`.
  - **Phases 3–7 — 53 additional operators ported:** Remaining SOP deformers/generators, CHOP signal processors, IMG pixel operators, TOP compute helpers, VOL analyzers, POP renderers. Brought total from 16 to 69.
  - **Phase 8 — 23 CPU-hot migration operators:** 5 SOP (GNNativeSmoothSop, GNNativeRemeshSop, GNNativePolyBevelSop, GNNativePolyStitchSop, GNNativeWireframeSop) + 5 CHOP (GNNativeIkChop, GNNativeSopToChop, GNNativeLaserChop, GNNativeCompositeChop, GNNativeFanChop) + 6 VOL (GNNativeBlurVol, GNNativeNoiseVol, GNNativeDisplaceVol, GNNativeBlendVol, GNNativeSopToVol, GNNativeFluidVol) + 7 POP (GNNativeAdvectPop, GNNativeAttractPop, GNNativeCollisionPop, GNNativeForcePop, GNNativeTurbulencePop, GNNativeSourcePop, GNNativeLimitPop). All 23 audited as CPU-hot from NATIVE_AUDIT.md Tier 1. Files in `src/sop/`, `src/chop/`, `src/vol/`, `src/pop/`.
  - **Total: 92 native operators** across 6 families (42 SOP, 23 CHOP, 5 IMG, 4 TOP, 9 VOL, 9 POP), with help patches.
  - **Build:** godot-cpp submodule present at `addons/gn_ext_native/native/godot-cpp/`. Windows x86_64 compiled with `scons platform=windows target=template_debug arch=x86_64` → `bin/win64/libgn_native.windows.template_debug.x86_64.dll` (677 KB). `gn_native.gdextension` is active. Linux/macOS builds require running scons on those platforms (or CI).
  - **IMG operators (highest priority):** Pixel loops (`get_pixel`/`set_pixel` over 262K+ pixels) are the biggest GDScript bottleneck. BlurIMG, EdgeDetectIMG, PixelSortIMG, NoiseIMG all iterate every pixel. Port `_cook()` internals to C++ with direct `uint8_t*` pointer arithmetic. Alternative: rewrite as GPU compute shaders (even faster than C++ for batch pixel ops).
  - **SOP operators (high priority):** Vertex-heavy mesh construction (SubdivideSOP, NoiseSOP, BooleanSOP) scales with vertex count. SurfaceTool overhead in GDScript is significant at 10K+ verts. Port vertex loops to C++ via GDExtension.
  - **CHOP operators (medium priority, audio-rate only):** Control-rate CHOPs (few hundred samples) are fine in GDScript. Audio-rate CHOPs (44.1K samples: AudioInCHOP, AudioSpectrumCHOP) need native inner loops.
  - **Keep in GDScript (low priority, not worth porting):**
    - Cook engine / core: graph traversal is O(node_count), typically hundreds — negligible overhead.
    - TOP operators: already GPU-bound (GDScript just sets shader uniforms + triggers SubViewport render).
    - DAT operators: string/table ops backed by native Godot `String` — rarely a bottleneck.
    - Expression system: evaluated once per parameter per frame, microsecond overhead.
    - Extension registry / UI: trivially cheap.
  - **Migration strategy:** Architecture already supports this — each operator's `_cook()` is a clean seam. Options: (a) C++ GDExtension class replacing the GDScript operator entirely, (b) C++ helper library called from GDScript `_cook()` for just the inner loop, (c) GPU compute shader via `RenderingDevice` (best for IMG batch pixel ops).
  - **Remaining Phase 2 work:** Compile binaries (requires godot-cpp), add help patches for 6 native operators, write tests.
- [x] ~~GPU compute shaders for IMG operators~~ — **REMOVED.** GpuBlurIMG and GpuEdgeDetectIMG deleted: GPU pixel processing belongs in the TOP family (BlurTOP, EdgeTOP, ComputeShaderTOP), not IMG. IMG is strictly CPU-side `Image` processing. The shader code was preserved as ComputeShaderTOP help patch examples (`help/top/compute_gaussian_blur.gnpatch`, `help/top/compute_edge_filter.gnpatch`). GNImgComputeBase base class removed. GNGpuContext 2D texture helpers (`create_texture_2d`, `upload_image`, `download_image`) retained — used by VOL/POP operators.

### Long-term
- [x] **Spare Parameters** — DONE: Houdini-style "add any parameter type to any node" system:
  - Right-click → "Add Spare Parameter…" dialog with type picker (Float, Int, Bool, String, Color, Vector2, Vector2i)
  - `spare_parameters: Dictionary` storage on GNNode, separate from `_init_parameters()`
  - Inspector UI renders spare params under collapsible "Spare Parameters" section
  - Full serialization/deserialization in `.gnpatch` format
  - Same `get_parameter_value()` / `set_parameter_value()` API as regular params
- [ ] NDI video streaming (NDI In/Out TOPs — would be a GDExtension `gn_ext_ndi` wrapping the NDI SDK)
- [x] Spout / Syphon texture sharing — **Done**: `gn_ext_spout` (Windows: SpoutInTOP, SpoutOutTOP) and `gn_ext_syphon` (macOS: SyphonInTOP, SyphonOutTOP). Both are GDExtension addons with ClassDB.class_exists() runtime guards and `platforms` manifest key for cross-platform skip. `.gdignore` in `native/` prevents Godot from loading the wrong platform's `.gdextension` file.
- [x] ScreenGrabTOP — **Done as ScreenGrabIMG**: `operators/img/screen_grab_img.gd`. Viewport-only capture (main or editor viewport) → CPU Image. Moved to IMG family since `Viewport.get_texture().get_image()` returns a CPU Image. Chain → ImgToTOP for GPU texture.
- [x] VideoDeviceInIMG — live webcam/capture-card input as CPU Image; Godot has no native webcam API — GDExtension wrapping Media Foundation (Windows), AVFoundation (macOS), V4L2 (Linux). Built as IMG family since native API returns PackedByteArray. Chain → ImgToTOP for GPU texture.
- [x] AntiAliasTOP — **Done**: `operators/top/anti_alias_top.gd`. Simplified FXAA with configurable strength and edge threshold. Standalone TOP that applies to any texture chain.
- [x] MovieFileOutTOP — **Done**: `gn_ext_gpu_encode/operators/top/movie_file_out_top.gd`. GPU-side H.264 encoding via GDExtension (Media Foundation / VideoToolbox). Also: MovieOUT (CPU image sequence) and FFmpegOUT (CLI-based H.264/H.265/VP9/ProRes).
- [x] MidiOutCHOP — **Done**: `gn_ext_midi/operators/chop/midi_out_chop.gd` (RtMidiOutCHOP). Native RtMidi GDExtension backend with note on/off, CC, pitch bend mapping from CHOP channels.
- [ ] FxPlug / FFGL plugin export (for VDMX, Resolume)
- [x] Generic ScriptNode (family-less, multi-type output via `# @output` annotations) — **Done**: `operators/comp/generic_script_node.gd`
- [x] CallbackDAT (event-driven scripting callbacks) — **Done**: `operators/dat/callback_dat.gd`
- [x] `set_par()` writable parameter references — **Done**: in `gn_cook_engine.gd` + GNScriptHelper preamble
- [x] Network API (`network_add_node`, `network_remove_node`, `network_connect`, `network_disconnect`, `network_node_ids`, `network_node_info`) — **Done**: in `gn_cook_engine.gd` + GNScriptHelper preamble
- [x] Preset dropdown parameter (Option B — inspector renders preset as dropdown)
- [ ] Network collaboration (shared editing)
- [ ] Asset/patch marketplace
- [x] Mobile/web export for patches — **Phase 1-8 ALL COMPLETE** (renderer/platform detection, shader audit, CPU fallback for POP/VOL, export presets, thread detection, WindowOUT embedded mode, web runtime JS bridge, export compatibility report UI). See Section 34.
- [ ] ~~**ListCOMP**~~ — **DEPRIORITIZED.** Godot's built-in Tree and ItemList nodes cover most data-grid needs. Existing TreeUI and ItemListUI operators already wrap these. A full TD-style ListCOMP with column definitions, click-to-sort, and scroll virtualization would be a large effort for marginal gain over what `TreeUI` with `columns` param already provides. Revisit if users request it.
- [x] **SDF Composition Extension** (`gn_ext_sdf`) — **IMPLEMENTED** (26 operators + 78 help patches):
  - **Not a new family** — intermediate data is a `GNSDFData` (extends GNData) carrying an SDF scene-graph AST. Final node compiles to GLSL and renders to GNTextureData (TOP output).
  - **SDF Primitives** (10): SphereSDF, BoxSDF, TorusSDF, CylinderSDF, CapsuleSDF, PlaneSDF, ConeSDF, PyramidSDF, OctahedronSDF, GyroidSDF
  - **Boolean Operators** (5): UnionSDF, IntersectionSDF, SubtractSDF, SmoothUnionSDF, SmoothSubtractSDF
  - **Domain Modifiers** (8): RepeatSDF, MirrorSDF, TwistSDF, BendSDF, ElongateSDF, RoundSDF, OnionSDF, DisplaceSDF
  - **Material/Color** (2): MaterialSDF, GradientSDF
  - **Renderer** (1): RaymarchSDF TOP — orbit camera, AO, soft shadows, Blinn-Phong shading
  - **Base classes**: GNSDFData (AST carrier with hash), GNSdfBase (extends GNNode)
  - **Help patches**: 78 interactive/animated patches (3 per operator, LFO-driven `chop()` expressions)
- [x] **MidiOutCHOP** — **Done**: `gn_ext_midi/operators/chop/midi_out_chop.gd` (RtMidiOutCHOP). C++ GDExtension (`GNMidiOut`) wrapping RtMidi with `send_note_on()`, `send_cc()`, `send_pitch_bend()`, `send_raw()`. Maps CHOP channels (n0-n127 for notes, cc0-cc127 for CCs, pitch_bend) to outgoing MIDI. Note on/off edge detection with previous-state tracking.

### GPU Particles (POP Family)  IMPLEMENTED — Roadmap

**Status: IMPLEMENTED -- 10 POP operators + 7 GLSL compute shaders live**

CPU ParticleSOP exists for basic point-cloud emission. A GPU-native POP family
would enable millions of particles in real time using Godot's `RenderingDevice`
compute pipeline.

**Architecture decisions (from design review):**

- **Primary storage: SSBOs (Shader Storage Buffer Objects)**, not textures.
  Particle state (position, velocity, age, life, id, pscale, Cd, etc.) stored as
  flat `RDStorageBuffer` arrays on the GPU. Rationale:
  - Godot 4's `RenderingDevice` API is buffer-centric — creating/binding SSBOs is
    simpler than managing 3D render targets.
  - Particles are a 1D list, not a 2D grid — no awkward `idx → (x, y)` mapping.
  - Arbitrary struct layout — one buffer can hold interleaved per-particle data, or
    use struct-of-arrays for cache-friendly access patterns.
  - No texture dimension limits (max 16384×16384 ≈ 268M pixels, awkward for
    non-power-of-2 particle counts).

- **Attribute bridge: `GNGeoData.point_attribs` ↔ GPU.**(CPU↔GPU attribute bridge)
  The existing CPU-side `point_attribs` dictionary (`String → PackedFloat32Array`)
  on `GNGeoData` serves as the abstraction layer. For GPU POPs:
  - **Upload:** pack `point_attribs` into `RDStorageBuffer` when crossing into GPU
    compute (e.g., SOP→POP conversion).
  - **Readback:** download SSBO data back into `point_attribs` for downstream CPU
    nodes (e.g., POP→SOP for rendering via InstanceCOMP).
  - This keeps the existing SOP attribute workflow (AttributeSOP setting `pscale`,
    `Cd`, etc.) fully compatible with GPU particles.

- **Texture bridge for spatial operations.**
  While SSBOs are the primary storage, some operations benefit from hardware
  texture filtering (bilinear interpolation, blur, mip-maps). The design uses
  a **scatter/gather** pattern when spatial convolution is needed:
  ```
  [SSBO particle state] → scatter → [3D texture grid]
                                          ↓
                                     blur / filter / diffuse (texture ops)
                                          ↓
  [SSBO particle state] ← gather ← [3D texture grid]
  ```
  Scatter/gather is one compute dispatch each, only invoked when a spatial-filter
  node is in the chain. No filter node → pure SSBO path, zero overhead.

- **TOP output via `ParticleStateTOP`.**
  A dedicated bridge operator reads the SSBO and writes particle data into a 2D
  texture (RGBA32F — RGB=position, A=age, or similar encoding). This feeds the
  existing TOP chain for visualization, compositing, or feedback without special
  plumbing.

**Planned POP operators:**

| Operator | Description |
|----------|-------------|
| `EmitterPOP` | Emit particles from SOP surface, points, or volume |
| `ForcePOP` | Apply forces: gravity, wind, attractors, turbulence |
| `CollisionPOP` | SDF or mesh-based collision response |
| `AgePOP` | Kill by age, life ratio, bounds, or expression |
| `AdvectPOP` | Move particles by a velocity field (VOL3D input) |
| `SpritePOP` | Render particles as camera-facing quads (instanced) |
| `PointCloudPOP` | Render as point cloud (GL_POINTS or MultiMesh) |
| `ParticleStateTOP` | SSBO → TOP texture bridge for visualization |
| `SOPtoPOP` | Upload SOP point cloud + attribs to GPU buffers |
| `POPtoSOP` | Download GPU particle state back to CPU GNGeoData |

**Godot implementation details:**
- Each POP operator wraps a compute shader dispatched via `RenderingDevice`.
- Double-buffered SSBOs for simulation (read buffer A → write buffer B → swap).
- Shared `GNPopData` resource holding buffer RIDs, particle count, attribute layout.
- `GNPopBase` family base class (extends GNNode) — handles buffer lifecycle,
  dispatch helpers, attribute upload/download.

### Volumetric 3D Textures (VOL Family) -- IMPLEMENTED — Roadmap

**Status: IMPLEMENTED -- 10 VOL operators + 11 GLSL compute shaders live**

Inspired by Josef Pelz's T3D plugin for TouchDesigner, a volumetric 3D texture
extension would bring surfaces, volumetrics, fluid simulation, and abstract
spatial data to GONODES — all without users writing GLSL.

**Background:** T3D provides a family of operators that work on 3D textures
(voxel grids where each position stores up to RGBA float values). Operators
mirror standard 2D TOP operations (add, blur, noise, displace) but in 3D.
Rendering operators extract iso-surfaces (marching cubes) or render volumetric
density via raymarching. A fluid simulator (`fluidT3D`) enables real-time
Navier-Stokes smoke/liquid simulation with a few node connections.

In TD, T3D was built as compute shaders hidden inside glslTOPs with extensive
OP Create dialog hacks. GONODES has a clean extension architecture that makes
this more straightforward — `gn_ext_vol3d/` with `gn_extension.cfg` registration.

**Extension structure:**

```
addons/gn_ext_vol3d/
├── gn_extension.cfg
├── README.md
├── core/
│   └── gn_vol3d_data.gd            # GNVol3DData — wraps 3D texture RID
├── operators/
│   ├── noise_vol3d.gd              # 3D noise field (Perlin, simplex, Voronoi)
│   ├── constant_vol3d.gd           # Uniform density/color fill
│   ├── sdf_vol3d.gd                # SOP → signed distance field
│   ├── add_vol3d.gd                # Add/subtract/multiply two 3D fields
│   ├── blur_vol3d.gd               # 3D Gaussian/box blur
│   ├── displace_vol3d.gd           # Warp field by vector field
│   ├── level_vol3d.gd              # Brightness/contrast/gamma on 3D field
│   ├── feedback_vol3d.gd           # Previous frame's volume (sim loops)
│   ├── fluid_vol3d.gd              # Navier-Stokes (advection + pressure + diffusion)
│   ├── surface_vol3d.gd            # Marching cubes → SOP mesh output
│   └── volume_render_vol3d.gd      # Raymarcher → renders to TOP (2D image)
├── shaders/
│   ├── noise3d.glsl
│   ├── add3d.glsl
│   ├── blur3d.glsl
│   ├── level3d.glsl
│   ├── displace3d.glsl
│   ├── advect.glsl                 # Semi-Lagrangian advection
│   ├── divergence.glsl             # Velocity divergence
│   ├── pressure_jacobi.glsl        # Jacobi pressure solve
│   ├── projection.glsl             # Velocity projection (div-free)
│   ├── sdf_from_mesh.glsl          # Mesh → SDF voxelization
│   ├── marching_cubes.glsl         # GPU iso-surface extraction
│   └── raymarch.glsl               # Volumetric density raymarcher
└── help/
    └── vol3d/
        ├── noise_vol3d_basic.gnpatch
        ├── fluid_smoke.gnpatch
        └── surface_extract.gnpatch
```

**Godot 3D texture capabilities (confirmed suitable):**
- `RDTextureFormat` with `texture_type = TEXTURE_TYPE_3D` — arbitrary resolution,
  R32F / RGBA32F / RGBA16F formats.
- `layout(set, binding, r32f) uniform image3D` for compute shader write access.
- `uniform sampler3D` for filtered read access (hardware bilinear interpolation).
- Compute dispatch with `(res/8, res/8, res/8)` work groups for per-voxel ops.
- No built-in 3D render targets or automatic mip-gen — manual compute passes needed.
- No `SubViewport` for 3D slices — all 3D texture writes via compute only.

**Data type:** `GNVol3DData` (extends `GNData`) wrapping:
- 3D texture `RID` on `RenderingDevice`
- Resolution (`Vector3i`), format, grid bounds (AABB)
- Helper methods: `create(res, format)`, `destroy()`, `get_rd_rid()`

**Key technical challenges:**
1. **Fluid sim** — Navier-Stokes: semi-Lagrangian advection, divergence compute,
   Jacobi iteration pressure solve, velocity projection. Each step = one compute
   dispatch. Vorticity confinement and buoyancy for realistic smoke behavior.
2. **GPU marching cubes** — Variable triangle output requires atomic counter +
   pre-allocated output buffer (Godot RD supports atomics but not append buffers).
3. **Volume raymarcher** — Step size tuning, jittered sampling to prevent banding,
   early termination, density-to-color transfer function.
4. **Noise/blur/add/displace** — Straightforward single-pass compute shaders,
   a few dozen GLSL lines each.

**POP ↔ VOL3D interaction:**
- `AdvectPOP` reads a VOL3D velocity field to move particles.
- Scatter POP positions into a VOL3D density grid for fluid-coupled particles.
- VOL3D `surface_vol3d` extracts a mesh that POP particles can collide with.

### Custom Operator Assets (.gnasset) — Roadmap

**Status:** Planned — 4-phase implementation  
**Inspired by:** Houdini Digital Assets (HDA) / TouchDesigner .tox  
**Core Idea:** Let users promote any SubNetwork into a reusable, shareable custom operator with its own name, icon, family, and promoted parameter interface.

#### Design Strategy

The .gnasset system is designed to plug into existing infrastructure with minimal new code:

| Existing System | How .gnasset Uses It |
|---|---|
| `SubNetworkNode` | `GNCustomOperator extends SubNetworkNode` — inherits inner network, tunnels, cook logic |
| `GNExtensionRegistry` | `scan_custom_assets()` added alongside `scan_extensions()` — registers assets via existing `register_operator()` API |
| `GNNodePalette` | Custom assets appear in a **"Custom"** section per family — no palette changes needed |
| `.gnpatch` format | Asset stores its inner network in identical `nodes`/`connections`/`annotations` dict format |
| `GNParameter` | Promoted parameters use same `ValueType` enum, `to_dict()`/`from_dict()`, expression support |

#### Phase 1 — Foundation (Core Runtime)

**`.gnasset` JSON format:**
```json
{
  "asset_version": "1.0",
  "identity": {
    "op_name": "MyBlur",
    "family": "TOP",
    "description": "Custom multi-pass blur with controllable iterations",
    "author": "user",
    "version": "1.0.0",
    "icon": "",
    "section": "Custom",
    "tags": ["blur", "filter", "post-process"]
  },
  "promoted_parameters": [
    {
      "inner_node_id": "blur_top_1",
      "inner_param_name": "radius",
      "promoted_name": "Blur Radius",
      "promoted_order": 0
    },
    {
      "inner_node_id": "blur_top_1",
      "inner_param_name": "iterations",
      "promoted_name": "Iterations",
      "promoted_order": 1
    }
  ],
  "inner_network": {
    "nodes": { },
    "connections": [ ],
    "annotations": [ ]
  }
}
```

**`GNCustomOperator` class (extends SubNetworkNode):**
- Stores `asset_path: String` pointing to source `.gnasset` file
- On `_ready()` / `load_from_asset(path)`: deserialises the inner network from JSON, creates `InTunnel`/`OutTunnel` nodes, wires connections
- Builds promoted parameter proxies: each promoted param entry creates a top-level `GNParameter` on the custom op that reads/writes the corresponding inner node's parameter
- `op_type` returns the asset's `op_name`; `family` returns the asset's family
- `to_dict()` stores `{ "type": "GNCustomOperator", "asset_path": "user://gonodes_assets/MyBlur.gnasset", ... }` — inner network is NOT re-serialised (it lives in the `.gnasset` file)
- `from_dict()` loads the asset, then applies any per-instance parameter overrides from the patch

**Asset scanning (on `GNExtensionRegistry`):**
- `scan_custom_assets()` scans **3 directories** in order:
  1. `res://addons/gonodes/assets/` — built-in / shipped assets
  2. `user://gonodes_assets/` — user-created assets (primary save location)
  3. `res://custom_operators/` — project-local assets for version control
- Each `.gnasset` file is parsed, validated, and registered via `register_operator(op_name, family, GNCustomOperator, description, "custom_asset", section, asset_dir)`
- Called during editor startup after `scan_extensions()`

**Palette integration:**
- Registered assets appear in the palette tree under their family → "Custom" section automatically
- No changes to `GNNodePalette` code needed — existing section support handles it

**Serialisation in `.gnpatch`:**
- `GNCustomOperator.to_dict()` saves `asset_path` + promoted param overrides only (compact)
- `GNCustomOperator.from_dict()` reloads the `.gnasset` at the stored path, then applies overrides

#### Phase 2 — Promotion Dialog

**Trigger:** Right-click a SubNetwork node → "Promote to Custom Asset…"

**`GNAssetPromotionDialog` (popup window):**
1. **Identity section:** Name, Family (auto-detected from SubNetwork contents), Description, Author, Version, Tags
2. **Parameter Interface Builder:** Checkbox table listing every parameter on every inner node. User checks which params to promote, sets promoted display name and order. Drag-to-reorder rows.
3. **Save Location Picker:** Radio buttons — `user://gonodes_assets/` (default) or `res://custom_operators/` (project-local)
4. **"Create Asset" button:** Serialises the SubNetwork's inner network + selected promoted params into `.gnasset` JSON, writes file, calls `scan_custom_assets()` to hot-register

**Workflow:**
1. User builds a SubNetwork with inner nodes
2. Right-click → "Promote to Custom Asset…"
3. Dialog opens pre-filled (name from SubNetwork label, family auto-detected)
4. User selects params to promote, names them, reorders
5. Clicks "Create Asset" → `.gnasset` written → immediately available in palette
6. Original SubNetwork replaced with new `GNCustomOperator` instance (optional)

#### Phase 3 — Editing & Polish

- **Unpack to SubNetwork:** Right-click a `GNCustomOperator` → "Unpack to SubNetwork" reverses promotion — creates a vanilla SubNetwork with the asset's inner network content, useful for one-off modifications
- **Edit Asset:** Right-click → "Edit Asset" opens the `.gnasset`'s inner network in a nested editor tab; changes saved back to the `.gnasset` file propagate to all instances on next cook
- **Versioning:** `version` field in identity; on load, if a patch references version `1.0.0` but the asset is `1.1.0`, log a warning
- **Duplicate detection:** On scan, if two assets share the same `op_name` + `family`, warn and prefer the one from the highest-priority directory
- **Icon support:** Optional `icon` field in identity — path to a `.svg` or `.png` displayed in the palette and on the node header

#### Phase 4 — Ecosystem

- **Asset Browser Panel:** Dedicated UI panel listing all installed assets with search, filter by family/tags, preview of promoted params, and install/uninstall actions
- **Import / Export:** `.gnasset` files are self-contained JSON — share by copying the file. "Import Asset…" menu action copies a `.gnasset` into `user://gonodes_assets/` and hot-registers it
- **Dependency Resolution:** If a `.gnasset`'s inner network references another custom asset, the loader checks that the dependency is installed; logs an error with the missing asset name if not
- **Community Sharing:** Future — integration with a simple asset index (GitHub repo or web API) for browsing and one-click install of community assets

#### Design Decisions

| Decision | Rationale |
|---|---|
| Extend `SubNetworkNode`, don't fork | Reuse 100% of inner-network cook logic, tunnels, serialisation |
| Store inner network in `.gnasset` file, not inline in `.gnpatch` | Single source of truth; patches stay compact; updates propagate |
| 3 scan directories with priority | Supports shipped assets, user assets, and project-local assets under version control |
| Promoted params as proxies | Avoids duplicating parameter logic; expressions/ramps just work |
| "Custom" palette section per family | Zero palette code changes; assets sorted alongside built-in ops |
| JSON format (not binary) | Human-readable, diffable, mergeable in version control |

#### Files to Create / Modify

| File | Action |
|---|---|
| `addons/gonodes/core/gn_custom_operator.gd` | **Create** — `GNCustomOperator` class |
| `addons/gonodes/core/gn_extension_registry.gd` | **Modify** — add `scan_custom_assets()`, asset directory constants |
| `addons/gonodes/ui/gn_asset_promotion_dialog.gd` | **Create** — Phase 2 promotion UI |
| `addons/gonodes/ui/gn_asset_browser.gd` | **Create** — Phase 4 asset browser panel |
| `addons/gonodes/core/gn_network.gd` | **Minor modify** — context menu entry for "Promote to Custom Asset" |
| `tests/test_custom_operator.gd` | **Create** — unit tests for .gnasset load/save/cook |

---

## 13.4. Unit Tests

**Framework:** Lightweight, dependency-free GDScript test runner — no GdUnit4 or GUT required.

**Run command:**
```bash
godot --headless -s tests/test_runner.gd
godot --headless -s tests/test_runner.gd --test-filter=parameter   # filter by name
```

**Structure:**
```
tests/
├── test_runner.gd          # GNTestRunner (extends SceneTree) — discovers & runs test_*.gd scripts
├── test_assert.gd          # GNTestAssert — static assertion helpers (assert_eq, assert_approx, etc.)
├── test_parameter.gd       # GNParameter: factory constructors, clamping, mode switching, serialization, legacy migration, per-component expressions
├── test_cook_engine.gd     # GNCookEngine: expression eval (time/frame/dt), par() self/cross-node, parf/pari/pars, chop(), circular guard, component expressions, error recovery
├── test_network.gd         # GNNetwork: add/remove nodes, connect/disconnect, topo sort, cycle detection, dirty propagation, rename, serialization structure
├── test_channel_data.gd    # GNChannelData: single/multi-sample channels, index bounds, invalidate, duplicate_data deep copy
├── test_preset_manager.gd  # GNParamPresetManager: clipboard copy/paste, type mismatch rejection, reset to defaults
├── test_ramp_and_annotations.gd  # RAMP parameter: factory, sampling, serialization round-trip. Annotations: CRUD, serialization round-trip
├── test_ramp_chop.gd        # RampCHOP: default init, single/multi-sample output, dynamic count, custom curves, serialization round-trip, chop() expression integration
└── README.md
```

**Conventions:**
- Test files: `tests/test_*.gd`, each extends `Node`
- Test methods: `test_*()` — discovered automatically by the runner
- Lifecycle hooks: `before_all()`, `after_all()`, `before_each()`, `after_each()` (optional)
- Assertions: non-throwing — failures are recorded, allowing multiple assertions per test
- Runner adds test instances to the scene tree root so `add_child()` works (needed for GNCookEngine, GNNetwork tests)

**What's tested (core logic, no GPU):** GNParameter (incl. RAMP type), GNCookEngine expression eval (incl. ramp()), GNNetwork graph model (incl. annotations), GNChannelData, GNParamPresetManager, RampCHOP (dynamic slots, serialization, cook engine integration).

**What's NOT tested (deferred):** UI widgets, GPU TOPs (need SubViewport), hardware I/O (MIDI, OSC, audio, webcam), file-based preset save/load (needs user:// filesystem).

### Integration Tests (Automated)

Full cook-cycle tests that exercise the entire `cook_frame()` pipeline through real multi-node networks, running headless alongside the unit tests.

```
tests/integration/
├── test_chop_chains.gd        # 13 tests — Constant→Math→Null chains, merge, bypass, expressions, dirty propagation, diamond topology
├── test_script_chop.gd        # 7 tests — ScriptCHOP generator/filter, @param annotations, time var, syntax error recovery, script→math chain
├── test_network_roundtrip.gd  # 6 tests — Serialization round-trip: empty network, params, connections, expression mode, cook-after-deserialize
```

**Total automated tests:** 690 (661 unit + 29 integration) — all passing.

### Manual Test Scenes

**DEPRECATED — replaced by help example patches.** Legacy test scenes remain in `test_scenes/` for reference but are no longer the primary visual verification method. The 1,084 help example patches across `addons/gonodes/help/<family>/` and extension help directories provide 3+ visual demos per operator and are accessible directly from the `?` help button on each node.

```
test_scenes/                           # ⚠️ DEPRECATED — use help patches instead
├── README.md                          # Legacy checklists (kept for reference)
├── 01_chop_chain_basics.gnpatch       # → covered by chop/ help patches
├── 02_script_chop.gnpatch             # → covered by scriptchop_generator.gnpatch
├── 03_custom_shader_top.gnpatch       # → covered by glsl_radial_wave.gnpatch
├── 04_expression_animation.gnpatch    # → covered by lfo_basic + circle_basic patches
├── 05_top_compositing_chain.gnpatch   # → covered by composite_blend + edge_detect + level patches
├── 06_physics_rigid_bodies.gnpatch    # → covered by rigid_body_basic + static_body_floor patches
├── 07_physics_forces_properties.gnpatch # → covered by comp/ help patches
└── 08_physics_joints_area_softbody.gnpatch # → covered by joint_hinge + area_gravity patches
```

**Why help patches replace test_scenes:**
- Help patches are discoverable from the node's `?` button — no need to remember file names
- One-to-one per-operator coverage (108 patches vs 8 test scenes that each test multi-node combos)
- New operators automatically get help patch coverage as part of the new operator checklist (Hard Rule 25.21)
- Test scenes tested integration scenarios; help patches test individual operators — integration testing is better served by automated tests in `tests/integration/`

---

## 13.5. Coding Guidelines

These principles guide all GONODES development. Follow them when adding new operators, refactoring existing code, or reviewing contributions.

### 1. Consolidate Common Members in Family Base Classes

Shared properties, cached data, and helper methods that appear in more than one operator within a family **must** live in the family base class (`GNTopBase`, `GNChopBase`, `GNDatBase`, `GNSopBase`, `GNCompBase`, `GNMatBase`), not duplicated across subclasses.

**Why:** Reduces boilerplate, prevents drift between implementations, and makes family-wide behavioral changes (like the UPDATE_ONCE render lifecycle) possible in one place.

**Examples:**
- `GNTopBase._viewport`, `_material`, `_canvas`, `_cached_tex_data` — every TOP needs viewport infrastructure.
- `GNChopBase._cached_channel_data` — every CHOP caches channel output.
- `GNDatBase._cached_table` — every DAT caches table output.

**Rule of thumb:** If you're about to declare the same `var` in a third subclass, move it to the base.

### 2. Prefer Godot Built-in Classes

Use Godot's native types and engine classes wherever possible instead of building custom abstractions.

**Why:** Godot's built-in classes are optimized, well-documented, and battle-tested. Wrapping them adds indirection with no benefit. Leveraging the engine's type system (Node, Resource, RefCounted) also enables automatic memory management, serialization, and editor integration for free.

**Concrete preferences:**
| Instead of … | Use … |
|---|---|
| Custom render pipeline | `SubViewport` + `ShaderMaterial` + `ColorRect`/`TextureRect` |
| Manual memory management | `RefCounted` subclasses (freed automatically) |
| Custom mesh format | `ArrayMesh` / `SurfaceTool` / `PrimitiveMesh` |
| Custom material wrapper | `StandardMaterial3D` / `ShaderMaterial` |
| Custom signal bus | Godot signals, `Node.notification()` |
| Manual tree cleanup | `queue_free()` cascade, `_notification(PREDELETE)` |
| Custom serialization | `Resource` with `@export` properties |
| Custom logging | `GNLogger` wrapping Godot's `push_warning()` / `push_error()` |

### 3. Resolution Follows Context

- **Generator TOPs** (no input): viewport size = `get_param_value("resolution")`.
- **Filter TOPs** (has input): viewport size = `tex_in.resolution` (matches input).
- Never hardcode viewport sizes (e.g., `Vector2i(512, 512)`) in operator `_cook()` methods. The factory defaults in `_create_viewport()` are only fallbacks for when no resolution is available yet.

### 4. Render Only When Needed

SubViewports must be created with `UPDATE_DISABLED`. The base class (`GNTopBase.execute_cook()`) triggers `UPDATE_ONCE` after each successful cook. Operators must **not** set `UPDATE_ALWAYS` or manually trigger renders — the base class owns the render lifecycle.

Exception: `process_mode = PROCESS_MODE_ALWAYS` is acceptable for media-playback TOPs (Movie, FFmpeg) that need Godot's built-in `_process()` for decoder advancement.

---

## 14. Technical Notes

### SubViewport Strategy for TOPs
Each TOP node owns a `SubViewport` for rendering its output texture. The infrastructure lives in **GNTopBase**:

- **Creation:** `_create_viewport()` factory produces a SubViewport with `UPDATE_DISABLED`, `gui_disable_input = true`, and optional transparency / 3D. Higher-level helpers `_ensure_viewport()` and `_init_shader_viewport()` build upon it.
- **Canvas:** A `ColorRect` or `TextureRect` with `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` auto-fills the viewport — no manual `_canvas.size` management (see Hard Rule 25.16).

  **ColorRect vs TextureRect — the decision rule and why it matters:**
  - **ColorRect** → **generators** and **multi-input compositors** (Noise, Ramp, Rectangle, Circle, Cross, Composite, Displace, Feedback, Lookup). These either produce pixels from pure math/uniforms (no input texture) or blend multiple inputs passed entirely as `uniform sampler2D` shader parameters. A ColorRect always draws regardless — it needs no `.texture` property.
  - **TextureRect** → **single-input filters** (Level, Edge, Flip, Crop, Threshold, Tile, Transform, Blur vertical pass). These transform one upstream texture. Each cook sets `(_canvas as TextureRect).texture = tex_in.texture`, which (a) ensures the canvas draws — **a TextureRect with null `.texture` skips `_draw()` entirely**, so the shader material never executes and the viewport renders blank — and (b) makes the input available as the built-in `TEXTURE` sampler in the shader, in addition to any explicit `uniform sampler2D`.
  - **Rule:** no input or multiple inputs → `ColorRect`; single-input filter → `TextureRect`. The `_init_shader_viewport()` helper's `use_texture_rect` parameter controls this (`false` = ColorRect, `true` = TextureRect).
  - **Gotcha:** Forgetting to set `.texture` on a TextureRect canvas produces a silent blank viewport — no error, no warning, just transparent pixels. This was the root cause of the BlurTOP sporadic blank output bug (the vertical-pass TextureRect was never given its `.texture`).

- **Resolution:** Generator TOPs pass `get_param_value("resolution")` as the viewport size. Filter TOPs pass `tex_in.resolution` (matching their input). No hardcoded sizes.
- **Render lifecycle:** Viewports are created with `UPDATE_DISABLED`. `GNTopBase.execute_cook()` triggers `UPDATE_ONCE` on every child SubViewport after `_cook()` sets uniforms/textures, so each TOP renders **exactly once per cook cycle** — no wasted GPU passes on non-dirty frames.
- **Input textures** are passed as shader uniforms (zero-copy GPU references).
- **Output:** The `ViewportTexture` is wrapped in `GNTextureData` and becomes the node's `cached_output`.
- **Cleanup:** Viewports are children of the GNNode; `queue_free()` cascades automatically.

**Performance consideration:** Each SubViewport is a render pass. For large networks, viewport pooling or deferred rendering may be needed. For MVP, one viewport per TOP is acceptable.

### Cook Engine Optimizations (Implemented)

The cook engine has been optimized with these patterns:

1. **Cached adjacency maps** — `GNNetwork._downstream_map` and `_input_conn_map` are rebuilt only when the graph structure changes (node/connection add/remove). All per-frame lookups (dirty propagation, input gathering) use O(1) dictionary lookups instead of scanning all connections.

2. **Upfront dirty propagation** — Dirty flags are propagated in a single BFS pass BEFORE the cook loop starts, not interleaved with cooking. This eliminates redundant BFS calls (previously one per producing node).

3. **Cached input arrays** — `_input_cache` stores a reusable `Array[GNData]` per node. Arrays are cleared and refilled each frame instead of being reallocated. Zero per-frame allocations in steady state.

4. **Skip-already-dirty BFS** — `propagate_dirty()` stops traversal at nodes already marked dirty, avoiding redundant downstream walks.

5. **SubViewport render-once-per-cook** — All TOP SubViewports are created with `UPDATE_DISABLED` instead of `UPDATE_ALWAYS`. Previously every SubViewport rendered every frame regardless of whether the TOP was dirty, wasting GPU passes on static texture chains. Now `GNTopBase.execute_cook()` sets `UPDATE_ONCE` on each child SubViewport only after `_cook()` finishes setting uniforms/textures. This means a TOP renders **exactly once per dirty cycle** — if it isn't cooked, its viewport never re-renders. For a network with N TOPs where only K are dirty, this reduces per-frame GPU render passes from N to K.

6. **Lazy viewport creation** — `_init_shader_viewport()` and `_ensure_viewport()` are guarded with `if _viewport != null: return`, deferring SubViewport allocation to the first `_cook()` call. TOPs that are never cooked (disconnected, orphaned) have zero GPU footprint — no SubViewport, no texture memory, no render passes.

7. **Active chain cooking** — Only nodes that feed a live sink are cooked. The active set is computed via BFS upstream from sinks, following both wire connections and expression references. Key design points:

   **Architecture (engine vs. editor separation):**
   - `GNCookEngine._compute_active_set()` is engine-level — works without an editor (headless, game embed).
   - Structural sinks (operators with `is_sink = true`) are auto-detected by the engine.
   - UI sinks (viewer panel, floating windows) are passed from the editor via `set_active_sinks()`.
   - If no sinks exist at all, fallback activates everything (backward compatible).

   **Sink detection — extensibility via `GNNode.is_sink` flag:**
   - Operators set `is_sink = true` in their `_init()` — no hardcoded type strings in the engine.
   - Current sinks: `WindowOUT`.
   - Future sinks: `SpoutOutTOP`, `NDIOutTOP`, `MIDIOutCHOP`, `OscOUT`, `AudioOutCHOP`, etc.
   - To make any new output operator a sink: add `is_sink = true` to its `_init()`. Zero engine changes.

   **Dependency tracking (wires + expressions):**
   - Wire connections: followed via `network.get_input_connections()` (cached adjacency, O(1) per node).
   - Expression references: regex scans for `chop("id")/op("id")/top("id")/sop("id")/dat("id")/mat("id")` patterns.
   - Both are followed recursively — if A references B which references C, all three are active.
   - `_get_expression_refs()` scans main expressions AND per-component expressions (Vector2/3/4, Color).
   - Same regex pattern as `GNGraphEditor._scan_expr_references()` (dashed overlay lines).

   **Invalidation triggers (event-driven, not per-frame):**
   | Trigger | Signal / Method | Source |
   |---------|-----------------|--------|
   | Connection added | `network.connection_added` | Engine listens in `_adopt_network_nodes()` |
   | Connection removed | `network.connection_removed` | Engine listens in `_adopt_network_nodes()` |
   | Node added | `network.node_added` | Engine listens in `_adopt_network_nodes()` |
   | Node removed | `network.node_removed` | Engine listens in `_adopt_network_nodes()` |
   | Parameter/expression edit | `node.parameter_changed` | Engine connects per-node in `_adopt_network_nodes()` |
   | Viewer target changed | `set_active_sinks()` | Editor calls `_push_active_sinks()` |
   | Viewer window opened/closed | `set_active_sinks()` | Editor calls `_push_active_sinks()` |
   | Node renamed | `set_active_sinks()` | Editor rebuilds sink list with new IDs |
   | New/load patch | `set_active_sinks()` | Editor calls `_push_active_sinks()` after rebind |
   | Engine reset | `reset()` | Internal — clears `_active_set`, sets dirty |

   During steady-state playback (no user interaction), the per-frame cost is exactly one `if _active_set_dirty:` bool check — the BFS does not run.

8. **Active-only pre-cook pass** — `_pre_cook_pass()` only calls `_pre_cook(delta)` on active nodes. Inactive nodes (not feeding any sink) are skipped entirely — marking them dirty would only waste a BFS walk that the cook loop would then skip. When nodes become active again (sink change, viewer change), they already have `dirty = true` from construction or prior state.

9. **Inactive-branch dirty propagation cutoff** — `propagate_dirty()` still marks inactive downstream nodes as dirty (so they pick it up when reactivated), but does NOT continue BFS traversal through them. This prunes entire frozen subgraphs from the BFS walk. A network with 200 nodes where only 30 are active only BFS-walks through those 30.

10. **Expression consumer map** — `_expr_consumer_map` is a reverse index: `upstream_node_id → [consumer_node_ids]` built alongside the active set (event-driven, not per-frame). During the cook loop, `_should_eval_expressions()` checks whether any of a non-dirty node's expression sources actually cooked this frame before calling `_try_expression_dirty()`. This avoids re-evaluating every expression on every active node every frame — only nodes whose data sources changed get expression re-eval. Nodes with expressions that don't reference other nodes (only `time`/`frame`/`dt`) always re-evaluate (they depend on frame timing).

   **Adding a new invalidation trigger:**
   - If a new feature can change which nodes feed sinks (e.g., dynamic port rewiring, node groups):
     1. Call `cook_engine.invalidate_active_set()` from the code that makes the change, OR
     2. Connect the relevant signal to `_on_topology_changed` / `_on_connection_changed`.
   - The active set will recompute on the next cook frame automatically.

   **Visual feedback:**
   - Info bar: `Active: N/M` — active nodes vs. total.
   - Perf overlay: inactive nodes show dimmed `zzz` instead of cook time.
   - `GNNode.is_active` is readable by any code (operators, inspector, etc.).

11. **Input hash guard (Tier 2)** — Parameter-level cook skipping replaces the former output fingerprinting. Before cooking a dirty+active node, the cook engine hashes all resolved parameter values (built-in + spare) plus upstream input data timestamps into a single int (`_compute_cook_input_hash()`). If the hash matches the previous frame's hash (`_last_cook_input_hash` on GNNode), the cook is skipped entirely — `_cook()` is never called, `cached_output` stays frozen, and no downstream propagation occurs.

    **Why input hashing beats output fingerprinting:**
    - **100% accurate for parameters**: Parameter values are small typed data (float, int, Vector2, Color, String, Array). `hash()` on these is exact.
    - **100% accurate for inputs**: Data timestamps track the frame of last cook. If upstream re-cooked, the timestamp changes and the hash differs. No heuristic pixel/vertex sampling.
    - **Skips the cook itself**: Output fingerprinting still had to cook the node before checking. Input hashing skips the entire `_cook()` call — zero GPU/CPU work for unchanged nodes.
    - **No GPU-resident special cases**: Output fingerprinting needed `is_gpu_resident()` to force propagation for TOPs/POPs/VOLs (GPU data can't be cheaply compared). Input hashing doesn't look at output data at all — works identically for all families.
    - **Simpler code**: No `compute_fingerprint()` or `is_gpu_resident()` overrides on 9 data classes. One method on the cook engine + one hash field on GNNode.

    **Time-dependent nodes**: Include `elapsed_time` in the hash, so it always differs frame-to-frame and the node always cooks. This is correct — their output depends on wall-clock time.

    **Expression-dirty nodes**: When `_try_expression_dirty()` changes a parameter's `resolved_value`, the node falls through to the cook section where the input hash will see the changed param value and allow the cook.

    **Incremental propagation**: When a node does cook (hash mismatch), `_dirty_immediate_downstream()` marks only direct successors dirty. Those successors then run their own input hash check in topo order — cascading stops at the first node whose inputs haven't changed.

    **Key invariants:**
    - First frame: `_last_cook_input_hash = -1` (sentinel), so hash never matches → all nodes cook.
    - `invalidate_all()` marks all nodes dirty — they cook regardless of hash on the next frame.
    - Bypass nodes: input hash guard runs before bypass check. If hash matches (same passthrough input + same params), bypass is skipped entirely.
    - Compute-unavailable nodes: skipped before hash check (handled by `requires_compute()` early-out).

### CHOP Channel Model
CHOPs produce `GNChannelData` which contains:
- Named channels (e.g., "tx", "ty", "tz" or "out", "chan1")
- Each channel is a `PackedFloat32Array`
- Single-value CHOPs (like LFO) have arrays of length 1
- Multi-sample CHOPs (like audio) have arrays of length N
- `sample_rate` field enables time-domain operations

### Parameter Expression System
Parameters support two modes:
1. **Value mode:** Direct value (float, int, vec2, etc.)
2. **Expression mode:** GDScript expression string evaluated at cook time

**CRITICAL — Expression Architecture (Godot's Expression class):**

Godot's `Expression` class resolves function calls as **method lookups on `base_instance`**, NOT as calls to input variables. You cannot pass Callables as input variables and expect to call them — they will be treated as data, not functions.

Therefore:
- `chop()`, `op()`, `top()` are **real public methods on GNCookEngine**
- `Expression.execute()` uses `self` (the cook engine) as `base_instance`
- Input variables are limited to data: `["me", "time", "frame", "dt"]`
- The expression `chop("lfo1", "out") * 5.0` calls `GNCookEngine.chop("lfo1", "out")` directly

This was a hard-won architectural insight — the original design passed Callable lambdas as input vars, which silently failed (Expression returned 0.0 fallback → static noise).

Expression context provides:
- `me` — reference to the owning node (GNNode)
- `chop(name, channel)` — method on base_instance, returns float
- `op(name, param)` — method on base_instance, returns Variant
- `top(name, property)` — method on base_instance, returns Variant
- `time` — current time in seconds (input variable)
- `frame` — current frame number (input variable)
- `dt` — delta time (input variable)

Example: `chop("lfo1", "out") * 5.0`

### Godot Version Requirements
- **Godot 4.6** (for LibGodot support)
- Uses: GraphEdit, GraphNode, SubViewport, ShaderMaterial, Resource serialization
- GDScript typed syntax throughout
- Static typing enforced where possible

### Renderer Compatibility & Selection
Godot 4.x offers three rendering backends. GONODES must support all three so exported patches run on any target device:

| Renderer       | GPU Target              | Use Case              | Notes for GONODES                      |
|----------------|-------------------------|-----------------------|----------------------------------------|
| **Forward+**   | Desktop Vulkan/D3D12    | Full quality, desktop | Default for editor. All features.      |
| **Mobile**     | Mobile Vulkan/Metal     | Mobile devices        | Fewer shader features. TOPs must use compatible shaders. |
| **Compatibility** | OpenGL 3.3 / WebGL2  | Web, old hardware     | No compute shaders. CHOP/POP fallbacks needed. |

**Editor behavior:**
- A dropdown in the editor toolbar lets the user switch renderers live while editing.
- This allows previewing how a patch will look on each target platform.
- Operators should report if they are incompatible with the current renderer (e.g., compute-based POP on Compatibility).

**Implementation:**
- `ProjectSettings.set_setting("rendering/renderer/rendering_method", ...)` at runtime.
- Each operator can declare `supported_renderers: Array[String]` (default: all three).
- The cook engine skips or substitutes incompatible operators and shows a warning badge in the UI.

### Patch Export System
Patches should be exportable as standalone applications on all Godot-supported platforms:

**How it works:**
1. The GONODES editor saves the network as a `.tres` resource (MVP) or `.GNNode` JSON (future).
2. A "Export Patch" command generates a minimal Godot project:
   - `project.godot` configured for the selected renderer
   - The patch resource
   - A thin `main.tscn` that loads the patch into a `GNCookEngine` + output `SubViewport`
   - Only the needed operator scripts/shaders (tree-shaken)
3. Godot's standard export system packages it for the target platform.

**Supported export targets:**
- Windows, macOS, Linux (desktop)
- Android, iOS (mobile — requires Mobile or Compatibility renderer)
- Web/HTML5 (requires Compatibility renderer)
- Headless/server (for installations, compute-only patches)

**Patch runtime:**
- The exported app is a self-contained Godot application.
- It runs the cook engine at target FPS, rendering to the screen or a texture.
- Input can come from: command-line args, config file, OSC, MIDI (if those operators are included).
- Output can go to: screen, Syphon/Spout, NDI, file recording.

---

## 15. Design Principles

1. **Data flows left to right** — Inputs on left, outputs on right, consistent with TD.
2. **Type safety at wire level** — Only compatible ports connect. Errors are prevented, not reported.
3. **Lazy evaluation** — Nothing cooks unless it needs to. Dirty flags propagate downstream.
4. **Separation of model and view** — GNNetwork is the pure data model (Resource). GNNode is a Node in the scene tree but doesn't do UI — the cook engine drives it. UI reads/writes the model but doesn't own it.
5. **Operators are self-describing** — Each operator declares its ports, parameters, and family. The UI renders them generically. Adding a new operator = one new script file.
6. **Robust error handling** — Cook errors don't crash the app. Failed nodes output null/default data and show error state in UI.
7. **Performance visibility** — Cook times are always measurable. Users can see which nodes are expensive.
8. **Godot-native, not Godot-shy** — This framework is permanently married to Godot. We do NOT abstract away from Godot or build engine-agnostic layers. Use Godot's built-in systems aggressively:
   - `SubViewport` for TOP rendering (not a custom framebuffer abstraction)
   - `GraphEdit` / `GraphNode` for the node editor UI
   - `Resource` serialization for patch save/load
   - `ShaderMaterial` / `.gdshader` for GPU processing
   - `RenderingDevice` + compute shaders for POP/CHOP GPU work
   - `AudioServer` / `AudioStreamPlayer` for audio CHOPs
   - `UndoRedo` for undo/redo
   - `EditorPlugin` APIs when running as a plugin
   - `Expression` class for parameter expressions
   - `Tween` / `AnimationPlayer` where useful for timeline
   - `MultiMeshInstance3D` for point cloud / particle rendering
   - `GPUParticles3D` as a possible backend for simple particle POPs
   - `ProjectSettings` for renderer switching
   - Godot's export pipeline for patch export
   - `HTTPRequest`, `TCPServer`, `UDPServer` for networking operators
   - `MIDIMessage` / `InputEventMIDI` for MIDI input
   - Signals for event-driven communication between components
   - `ConfigFile` / `JSON` for settings and future .GNNode format
   - `ResourceLoader` / `ResourceSaver` for async resource management
   - `Thread` / `Mutex` / `Semaphore` for future multi-threaded cook engine
   
   If Godot has a built-in for something, use it. Don't reinvent. This maximizes compatibility with Godot updates, reduces code surface, and ensures patches export cleanly to all Godot platforms.

---

## 16. Naming Conventions

| Element                | Convention                    | Example               |
|------------------------|-------------------------------|-----------------------|
| GDScript files         | `snake_case.gd`              | `gn_node.gd`          |
| Class names            | `PascalCase`                 | `GNNode`, `GNNetwork` |
| Variables              | `snake_case`                 | `cook_time_ms`         |
| Constants/Enums        | `UPPER_SNAKE_CASE`           | `GNFamily.TOP`        |
| Signals                | `snake_case` (past tense)    | `node_cooked`         |
| Shader files           | `snake_case.gdshader`        | `noise_simplex.gdshader` |
| Scene files            | `snake_case.tscn`            | `gn_graph_editor.tscn` |
| Operator scripts       | `type_family.gd`             | `noise_top.gd`        |
| Resource prefix        | `GN` (all core classes)      | `GNData`, `GNPort`    |

---

## 17. Parameter Referencing System (Cross-Node References)

One of TouchDesigner's most powerful features is referencing parameters and data from any node inside the parameters of another node. GONODES replicates this with a multi-mode system.

### 17.1 Parameter Modes

GONODES uses a **two-mode** parameter system: **Constant** and **Expression**. All cross-node referencing (parameter binds, CHOP channel reads, math, conditionals) is handled through expression functions rather than separate mode machinery.

```
GNParameter.Mode:
├── CONSTANT     — Direct literal value. No evaluation overhead.
└── EXPRESSION   — String evaluated each cook frame. Handles par(), chop(), op(), top() references.
```

#### Mode 1: CONSTANT (MVP)
A typed literal value set by the user.
```
scale = 4.0       # Just a float
offset = (0.5, 0.3)  # Just a Vector2
```
No per-frame evaluation. Cheapest mode. Node is only dirty when user changes the value via the inspector.

#### Mode 2: EXPRESSION (MVP)
A string evaluated every cook frame (or when dependencies change). This is where **all** cross-node referencing lives — parameter binds, CHOP channel reads, math, conditionals, everything.
```
scale = chop("lfo1", "out") * 10.0        # CHOP channel reference (replaces old EXPORT mode)
offset.x = par("ctrl_panel", "master_x")  # Parameter reference (replaces old BIND mode)
```
Has per-frame evaluation cost (pre-compiled Expression + execution). See Section 17.2 for full expression syntax.

#### Why Only Two Modes (Architecture Decision)

Previous versions had four modes: CONSTANT, EXPRESSION, BIND, and EXPORT.  BIND and EXPORT were removed because:

1. **Expressions already cover both use cases** with identical performance:
   - Old BIND mode: `param.set_bind("ctrl_panel", "master_scale")` → now: `par("ctrl_panel", "master_scale")`
   - Old EXPORT mode: CHOP push mapping → now: `chop("lfo1", "out") * 10.0`

2. **Expressions are strictly better**:
   - Same-frame evaluation (EXPORT had 1-frame lag since it ran after all nodes cooked)
   - Composable with math (`chop("lfo1", "out") * 2.0 + 1.0` vs. separate scale/offset fields)
   - No separate mapping infrastructure to maintain
   - ~300 fewer lines of code in the engine

3. **Houdini precedent**: Houdini uses expressions for everything — `ch("../lfo1/tx")` is simultaneously a "bind" and a "reference". No separate bind/export modes.

4. **TD forum consensus**: [Multiple](https://forum.derivative.ca/t/exporting-chop-vs-chop-reference/4636/2) [threads](https://forum.derivative.ca/t/export-chop-vs-relative-reference/2848) confirm exports vs. references are nearly identical in performance and interchangeable.

**UX sugar** ensures users who don't want to type expressions still get a good experience:
- **Right-click any parameter** → "Insert Parameter Reference…" or "Insert CHOP Reference…" → dialog picks source → auto-generates the `par()` or `chop()` expression
- **Right-click a CHOP node** in the graph → "Insert CHOP Reference…" → dialog picks channel + target param → writes expression
- **Copy Reference** context menu entries put expression-ready strings on the clipboard
- `GNParameter.set_param_reference()` and `GNParameter.set_chop_reference()` convenience methods for code-level use

**Legacy migration**: Saved patches with old BIND-mode params are automatically converted to `par()` expressions on load. Old EXPORT-mode params revert to CONSTANT (users should re-create as `chop()` expressions).

### 17.2 Expression Syntax (Detail)

Inside any parameter's expression field, users can write references:

```gdscript
# Reference own node's parameters (self-reference, Houdini ch() style)
par("scale")                      # Own 'scale' param (most common pattern)
par("offset_x") + par("offset_y") # Combine own params
parf("scale")                      # Guaranteed float return
pari("seed")                       # Guaranteed int return
pars("file")                       # Guaranteed string return

# Reference another node's parameter
par("noise1", "scale")            # Cross-node param reference
par("../lfo1", "frequency")       # Hierarchical path
op("noise1", "scale")             # Alternative syntax (same result)

# Reference CHOP channel values
chop("lfo1", "out")               # Last sample of channel 'out' from CHOP 'lfo1'
chop("noise_chop1", "tx")         # Last sample of channel 'tx'
chop("math1", "out", 5)           # Sample at index 5

# Reference TOP properties
top("noise1", "resolution").x     # Width of TOP output
top("noise1", "resolution").y     # Height of TOP output

# Math with references
chop("lfo1", "out") * 10.0 + par("offset")
sin(time * par("noise1", "rate"))

# Ternary / conditional
1.0 if chop("toggle", "out") > 0.5 else 0.0
```

#### Copy Reference Workflow
Right-click a node in the graph → "Copy Node Path" or "Copy Output Ref" to get an expression-ready string in the clipboard. Right-click a parameter name in the inspector → "Copy Self Ref", "Copy Cross Ref", or "Copy op() Ref". Paste directly into any expression field.

#### Insert Reference Workflow (no-typing UX)
For users who prefer not to type expressions:
- **Right-click any parameter label** → "Insert Parameter Reference…" → dialog picks source node + param → auto-generates `par("node", "param")` expression and switches to EXPRESSION mode.
- **Right-click any parameter label** → "Insert CHOP Reference…" → dialog picks CHOP node + channel + optional scale/offset → auto-generates `chop("lfo1", "out") * 2.0 + 1.0` expression.
- **Right-click a CHOP node** in the graph → "Insert CHOP Reference…" → same dialog but pre-filled with the CHOP node ID and channels from its cached output.
- **Programmatic:** `param.set_param_reference("ctrl_panel", "master_scale")` and `param.set_chop_reference("lfo1", "out", 2.0, 1.0)` generate expressions automatically.

#### Circular Dependency Protection
If `par("a")` references `par("b")` which references `par("a")`, the engine detects the cycle at runtime and returns the fallback value with a warning. No infinite loops or stack overflows.

### 17.3 Reference Proxies by Family

Each family has its own reference proxy with family-specific accessors. **MVP implements CHOP and TOP proxies. Others are designed here for future implementation.**

#### `op(name)` — Generic (all families)
```gdscript
op("any_node", "param_name")     # Resolved parameter value (2-arg shortcut)
op("any_node").par.<param_name>   # Resolved parameter value (proxy dict)
op("any_node").family             # GNFamily enum
op("any_node").cook_time          # Last cook duration in ms
op("any_node").valid              # Whether node cooked successfully
```

#### `par(name)` / `par(node, name)` — Parameter Reference (Houdini ch() equivalent) ✅
```gdscript
par("scale")                      # Self-reference: own node's 'scale' param
par("offset_x") * 2.0             # Self-reference with math
par("noise1", "scale")            # Cross-node: noise1's 'scale' param
par("../lfo1", "frequency")       # Hierarchical cross-node reference
parf("noise1", "scale")           # Cross-node, guaranteed float
pari("noise1", "seed")            # Cross-node, guaranteed int
pars("noise1", "file")            # Cross-node, guaranteed string
```
**Features:** Self-reference via single arg, cross-node via two args, typed variants (parf/pari/pars), circular dependency guard, demand-driven evaluation.

#### `ramp(param, t)` — Ramp Sampling ✅
```gdscript
ramp("falloff", 0.5)               # Sample own 'falloff' RAMP param at t=0.5
ramp("falloff", chop("lfo1","out")) # Animate ramp lookup with a CHOP
ramp("noise1", "gradient", 0.75)    # Cross-node: sample noise1's 'gradient' RAMP at t=0.75
```
**Features:** Self-reference (2 args) or cross-node (3 args). Cubic Hermite interpolation between keypoints. Clamps `t` to 0–1. Returns float 0–1. Implementation: `GNParameter.sample_ramp()` static method.

**Ramp data structure:** Array of keypoint dictionaries `[{"pos": float, "value": float, "left_tangent": float, "right_tangent": float}]`. Sorted by `pos`. JSON-native serialization (no Godot Curve resource).

**GNRampEditor widget:** Custom `_draw()` curve editor for RAMP parameters in the inspector. Grid background (0.25 increments), draggable keypoints with tangent handles, left-click to add point, right-click to remove, Ctrl+click to toggle smooth/linear tangents.

#### `chop(name)` — CHOP Proxy (MVP)
```gdscript
chop("lfo1").value("out")         # Last sample of channel (float)
chop("lfo1").value("out", 5)      # Sample at index 5
chop("lfo1").channels             # Array of channel names: ["out"]
chop("lfo1").length               # Sample count per channel
chop("lfo1").sample_rate          # Sample rate (float)
chop("lfo1")["out"]               # Shorthand for .value("out") — TD syntax compatibility
```

#### `top(name)` — TOP Proxy (MVP)
```gdscript
top("noise1").resolution          # Vector2i (width, height)
top("noise1").resolution.x        # Width
top("noise1").resolution.y        # Height
top("noise1").aspect              # float (width / height)
```

#### `sop(name, port)` — SOP Output Access
```gdscript
sop("grid1")                      # → GNGeoData from first SOP port
sop("grid1", "out")               # → GNGeoData by port name
sop("grid1", 0)                   # → GNGeoData by port index
```
**Note:** Returns the raw `GNGeoData` object. Attribute-level proxy (`.num_points`, `.point(0).P`) is planned.

#### `pop(name)` — POP Proxy (Future)
```gdscript
pop("particles1").num_points      # Point count
pop("particles1").num_prims       # Primitive count
pop("particles1").point(0).P      # Position (GPU readback — expensive)
pop("particles1").point(0).PartVel    # Velocity
pop("particles1").point(0).PartAge    # Age
pop("particles1").attr("custom_attr") # Custom attribute value at point 0
```

#### `dat(name, port)` — DAT Output Access
```gdscript
dat("table1")                     # → GNTableData from first DAT port
dat("table1", "out")              # → GNTableData by port name
dat("table1", 0)                  # → GNTableData by port index
```
**Note:** Returns the raw `GNTableData` object. Cell-level proxy (`.cell()`, `.num_rows`) is planned.

#### `mat(name, port)` — MAT Output Access
```gdscript
mat("pbr1")                       # → GNMaterialData from first MAT port
mat("pbr1", "out")                # → GNMaterialData by port name
```

#### `img(name, port)` — IMG Output Access
```gdscript
img("noise_img1")                 # → GNImageData from first IMG port
img("noise_img1", 0)              # → GNImageData by port index
```

#### `vol(name, port)` — VOL Output Access
```gdscript
vol("fluid1")                     # → GNVolumeData from first VOL port
vol("fluid1", "Density")          # → GNVolumeData by port label
vol("fluid1", "density_out")      # → GNVolumeData by port name
vol("fluid1", 1)                  # → GNVolumeData by port index
```

#### `output(name, port)` — Generic Output Access
```gdscript
output("fluid1", "Density")       # → GNData by port label (any family)
output("fluid1", 0)               # → GNData by port index
output("fluid1")                  # → GNData from port 0
```

### 17.4 Node Path Resolution (Hierarchical — Designed, Flat for MVP)

**MVP:** `op("name")` resolves by flat string lookup within the current network (`GNNetwork.nodes[name]`). Node names must be unique within a network.

**Future (when COMPs are added):**
Paths follow a filesystem-like hierarchy:

```gdscript
# Flat (current network) — always works
op("noise1")

# Relative paths (from the current node's network context)
op("../sibling")           # Node in the parent network
op("./child_comp/noise1")  # Node inside a child COMP
op("../../uncle/node1")    # Two levels up, into a sibling COMP

# Absolute paths (from the root network)
op("/root/comp1/noise1")   # Fully qualified path

# Self and parent references
me                         # The current node
me.parent()                # The COMP containing the current node
me.parent().par.scale      # Parameter of the parent COMP
```

**Implementation design (future):**
```gdscript
func resolve_node_path(from_node: GNNode, path: String) -> GNNode:
    if path.begins_with("/"):
        # Absolute path: walk from root network
        return _resolve_absolute(path)
    elif path.begins_with("..") or path.begins_with("./"):
        # Relative path: walk from current node's network
        return _resolve_relative(from_node, path)
    else:
        # Simple name: lookup in current network (MVP behavior)
        return from_node.network.nodes.get(path, null)
```

**For MVP**, path is always a simple string name. The resolver function is written to make the upgrade to hierarchical paths a non-breaking change — expressions using `op("name")` will continue to work identically.

### 17.5 Expression Evaluation Engine

```gdscript
class_name GNExpressionEngine

var network: GNNetwork
var expression_cache: Dictionary = {}  # "node_id:param_name" -> Expression
var dependency_map: Dictionary = {}    # "node_id:param_name" -> Array[String] (referenced node IDs)

func resolve_parameter(node: GNNode, param_name: String) -> Variant:
    var param: GNParameter = node.parameters[param_name]
    match param.mode:
        GNParameter.Mode.CONSTANT:
            return param.value
        GNParameter.Mode.EXPRESSION:
            return _evaluate_expression(node, param_name, param)
    return param.value

func _evaluate_expression(node: GNNode, param_name: String, param: GNParameter) -> Variant:
    var expr: Expression = _get_or_compile(node.id, param_name, param.expression)
    var result = expr.execute(_build_context(node), self)  # self = CookEngine (provides chop/par/op/top)
    if expr.has_execute_failed():
        push_warning("Expression error on %s.%s: %s" % [node.id, param_name, expr.get_error_text()])
        return param.fallback_value  # Return last good value or default
    param.resolved_value = result    # Cache for UI tooltip display
    return result

func _build_context(node: GNNode) -> Array:
    # Build the bindings array for Expression.execute()
    # Returns: [op_func, chop_func, top_func, me_ref, time, frame, dt, ...]
    pass

func get_expression_dependencies(node: GNNode, param_name: String) -> Array[String]:
    # Parse expression string to find op("..."), chop("..."), top("...") references
    # Returns list of node IDs this expression depends on
    # Used by cook engine for implicit dirty propagation
    pass

func invalidate_cache(node_id: String, param_name: String) -> void:
    # Called when expression text changes — removes compiled Expression from cache
    expression_cache.erase("%s:%s" % [node_id, param_name])
    dependency_map.erase("%s:%s" % [node_id, param_name])
```

### 17.6 Dependency Tracking & Dirty Propagation

Parameter references create **implicit dependency edges** in addition to wire-based connections:

```
Wire dependencies (explicit, via connections):
    LFO_CHOP ──wire──► NoiseTOP        (data flows through port)

Expression dependencies (implicit, via param references):
    LFO_CHOP ··expr··► CompositeTOP    (CompositeTOP.opacity expression reads chop("lfo1"))
    ControlPanel ··expr··► NoiseTOP    (NoiseTOP.scale has expression par("ctrl", "master_scale"))
```

**Both dependency types** feed into the same DAG for topological sort and cycle detection. The cook engine treats them uniformly:
1. Collect all edges: wire connections + expression deps
2. Topological sort the full graph
3. Detect cycles (reject if found)
4. Cook in order

**Dirty propagation:**
- Wire: upstream cooks → downstream marked dirty (standard)
- Expression: referenced node parameter changes → mark this node dirty

### 17.7 Circular Reference Protection
- All expression references add edges to the dependency DAG
- If adding a reference would create a cycle, it is rejected immediately
- Expression mode: error shown inline in the expression text field
- Self-references via `me.par.X` within the same parameter are always rejected
- Runtime guard: `_evaluating_params` dictionary in cook engine prevents infinite recursion; if a param is already being evaluated, the guard returns the fallback value instead of recursing

### 17.8 UI Integration

**Parameter field behavior by mode:**

| Mode       | Inspector Display                                    | Node Badge | Graph Visual               |
|------------|------------------------------------------------------|------------|-----------------------------|
| CONSTANT   | Standard input control (slider, spinner, color, etc.) | None       | None                        |
| EXPRESSION | Text field with syntax highlighting. Resolved value shown on hover. | `fx`       | None (expression is invisible in graph) |

**Mode switching:** Click the C/E toggle button on any parameter row, or right-click → "Insert Parameter Reference…" / "Insert CHOP Reference…" to auto-generate an expression.

**Autocomplete (planned for MVP):**
- When typing `op("` in an expression field, show dropdown of available node names
- After `op("noise1").par.`, show dropdown of parameter names for that node
- After `chop("lfo1").value("`, show dropdown of channel names
- Provides discoverability without memorizing node/param names

**Drag-and-drop parameter linking (planned):**
- Drag a parameter label from one node's inspector to another node's parameter field
- Automatically creates an EXPRESSION with `par("source", "param")` pre-filled
- Hold Ctrl while dragging to create a `chop()` reference if source is a CHOP

---

## 18. POP (Point Operators) Family — Future Planning

TouchDesigner's POPs are a relatively new operator family (GPU-accelerated point/particle system). GONODES should plan for this from the architecture level, even though implementation is post-MVP.

### What TD's POPs Are

POPs (Point Operators) are a **GPU-native geometry processing system**. Key characteristics:
- All computation runs on the GPU (unlike legacy Particle SOP which was CPU-bound)
- Operates on **point clouds** — arrays of points with arbitrary attributes
- Supports particles (with physics sim), but also static/procedural geometry
- Uses a feedback loop architecture: Particle POP → downstream processing → Null POP → feedback back into Particle POP
- Can handle millions of points at real-time framerates
- Points carry typed attributes (position, velocity, age, lifespan, mass, drag, custom)
- Rendered via Render TOP (instancing, point sprites, or geometry)

### TD POP Operator Categories

| Category           | Examples                                   | Purpose                              |
|--------------------|--------------------------------------------|--------------------------------------|
| **Generators**     | Particle POP, Grid POP, Box POP, Sphere POP, Circle POP | Create point clouds/particles |
| **Modifiers**      | Noise POP, Transform POP, Point POP, Math POP, Force Radial POP | Modify attributes |
| **Attributes**     | Attribute POP, Attribute Combine POP, Attribute Convert POP | Create/edit/convert attributes |
| **Structure**      | Copy POP, Merge POP, Delete POP, Sort POP, Group POP | Structural operations |
| **Simulation**     | Particle POP (with feedback), Field POP, Limit POP | Physics simulation |
| **IO/Bridge**      | SOP to POP, CHOP to POP, DAT to POP, TOP to POP, File In/Out POP | Cross-family conversion |
| **GPU Code**       | GLSL POP, GLSL Advanced POP, GLSL Create POP | Custom GPU compute |
| **Rendering**      | Texture Map POP, Projection POP            | Apply textures to points |
| **Analysis**       | Analyze POP, Neighbor POP, Histogram POP   | Analyze point clouds |

### POP Data Model: GNPointData

```gdscript
class_name GNPointData extends GNData

# Core: all attribute data lives on GPU buffers
var point_count: int
var attributes: Dictionary = {}
# Each attribute: name -> { type: "float"|"vec2"|"vec3"|"vec4"|"int"|"uint",
#                           buffer: RID (GPU buffer) }

# Reserved particle attributes (created by ParticlePOP):
# "P"            : vec3  — position
# "PartVel"      : vec3  — velocity
# "PartAge"      : float — age in seconds
# "PartLifeSpan" : float — expected lifespan
# "PartForce"    : vec3  — accumulated forces
# "PartMass"     : float — mass
# "PartDrag"     : float — drag coefficient
# "PartId"       : uint  — unique particle ID
# "PartDeath"    : uint  — death flag (1 = remove next frame)

# Primitive types
enum PrimitiveType { POINTS, LINES, LINESTRIPS, TRIANGLES, QUADS }
var primitive_type: PrimitiveType = PrimitiveType.POINTS
var primitives: PackedInt32Array = []  # Vertex indices

func get_attribute(name: String) -> RID: ...
func set_attribute(name: String, type: String, data: PackedFloat32Array) -> void: ...
func read_back_positions() -> PackedVector3Array: ...  # GPU → CPU readback (expensive)
```

### Godot Implementation Strategy

Godot 4.x provides several GPU-side systems we can leverage:

1. **GPUParticles3D / GPUParticles2D** — Built-in particle system with process materials (ParticleProcessMaterial)
   - Good for basic particle effects
   - Limited: can't easily chain operations or do attribute manipulation

2. **Compute Shaders** (Forward+ and Mobile renderers only) — Full GPGPU via `RenderingDevice`
   - Create SSBO (Shader Storage Buffer Objects) for point attributes
   - Each POP operator = a compute shader dispatch
   - Chain operators by passing SSBOs between dispatches
   - **This is the right approach for GONODES POPs**

3. **MultiMeshInstance3D** — For rendering point clouds as instanced geometry
   - Each point → one instance with transform from position attribute
   - Efficient for up to millions of instances

**Architecture:**
```
ParticlePOP (generator)
  ↓ SSBO (positions, velocities, attributes)
NoisePOP (modifier) — compute shader reads/writes SSBO
  ↓ same SSBO, modified
ForcePOP (forces) — compute shader adds to PartForce attribute
  ↓
NullPOP (feedback endpoint)
  ↓ feeds back to ParticlePOP next frame
  ↓ also feeds to...
Render TOP — reads SSBO, renders via MultiMesh or custom shader
```

**Renderer constraints:**
- Compute shaders require Forward+ or Mobile renderer
- Compatibility renderer (OpenGL 3.3) has NO compute shaders
- For Compatibility: fall back to CPU-side particle sim using `PackedVector3Array` + `MultiMesh.set_instance_transform()` (much slower, limited particle count)
- Operator should declare: `supported_renderers = ["forward_plus", "mobile"]` and the cook engine handles the fallback

### Feedback Loop Architecture

TD's particle system uses a feedback loop for simulation. In GONODES:

```
frame N:  ParticlePOP reads previous frame's output from NullPOP
          → births new particles, removes dead ones
          → applies Time Integration (F → V → P)
          → outputs current frame's SSBO
          ↓
          downstream POPs modify attributes
          ↓
          NullPOP caches the final state
          ↓
frame N+1: ParticlePOP reads NullPOP again (feedback)
```

This is a **controlled cycle** in the DAG — the only allowed exception to the no-cycles rule. Implementation:
- `GNNetwork` allows one feedback edge per ParticlePOP, flagged as `is_feedback = true`
- The cook engine handles feedback connections specially: reads from previous frame's cache, not current frame
- This gives one frame of latency, which is standard for particle systems

### POP ↔ Other Family Bridges

| Bridge             | Direction     | What it does                                    |
|--------------------|---------------|-------------------------------------------------|
| SOP to POP         | SOP → POP     | Convert mesh points to POP points               |
| CHOP to POP        | CHOP → POP    | Map channel values to point attributes           |
| TOP to POP         | TOP → POP     | Sample texture to set point colors/positions     |
| DAT to POP         | DAT → POP     | Read point data from table                       |
| POP to SOP         | POP → SOP     | Convert POP points back to mesh (future)         |
| POP to TOP         | POP → TOP     | Render POP via Render TOP (output = texture)     |

### Phase Planning for POPs

**Phase A (foundation):** After SOP family is working
- Implement `GNPointData` with GPU buffer management
- Implement basic generators: Grid POP, Sphere POP
- Implement Transform POP (compute shader: modify P attribute)
- Implement Render TOP integration (MultiMesh from POP points)

**Phase B (particles):** 
- Implement Particle POP with feedback loop
- Time Integration (force → velocity → position)
- Birth/death system
- Force Radial POP, Noise POP
- Limit POP (bounding box, kill/bounce)

**Phase C (advanced):**
- GLSL POP (custom compute shader operator)
- Attribute system (create/combine/convert)
- Neighbor POP (spatial queries using GPU sort)
- Copy POP (point instancing)

---

## 19. Portability & Export Architecture

### Editor Platform Targets
The GONODES editor runs on **desktop only**:
- Windows (x86_64)
- macOS (x86_64 + Apple Silicon)
- Linux (x86_64)

No ARM/mobile editor — too complex a UI for small screens.

### Patch Export Targets
Exported patches (standalone runnables) can target **all Godot-supported platforms**:

| Platform       | Renderer Options               | Notes                                |
|----------------|--------------------------------|--------------------------------------|
| Windows        | Forward+, Mobile, Compat       | Primary desktop target               |
| macOS          | Forward+, Mobile, Compat       | Metal via MoltenVK                   |
| Linux          | Forward+, Mobile, Compat       | Vulkan or OpenGL                     |
| Android        | Mobile, Compat                 | No Forward+ (too heavy)              |
| iOS            | Mobile, Compat                 | Metal via MoltenVK                   |
| Web (HTML5)    | Compat only                    | WebGL2. No compute shaders.          |
| Headless       | N/A (no rendering)             | For data-processing-only patches     |

### Renderer-Aware Operators

Every operator declares which renderers it supports:

```gdscript
# In GNNode base class:
func get_supported_renderers() -> Array[String]:
    return ["forward_plus", "mobile", "gl_compatibility"]  # Default: all

# Override in specific operators:
# e.g., compute-shader-based POP:
func get_supported_renderers() -> Array[String]:
    return ["forward_plus", "mobile"]  # No compute on Compatibility
```

The cook engine checks compatibility at cook time:
- If an operator is incompatible with current renderer → skip cook, output null data, show warning badge
- The export system validates that all operators in a patch support the chosen export renderer
- A "Renderer Compatibility" panel shows which operators work on which targets

### Export Workflow

```
1. User clicks "Export Patch..." in editor
2. Export dialog:
   - Select target platform (Windows/macOS/Linux/Android/iOS/Web)
   - Select renderer (auto-selected based on platform, overridable)
   - Configure: resolution, FPS target, input sources, output mode
   - Compatibility check: warns about unsupported operators
3. GONODES generates a minimal Godot project:
   - project.godot (configured for target renderer)
   - The patch resource (.tres or .GNNode)
   - A runtime main.tscn:
     - GNCookEngine (loads patch, runs cook loop)
     - Output viewport (fullscreen or configurable)
     - Optional: OSC/MIDI input listeners
     - Optional: Syphon/Spout/NDI output
   - Only the needed operator scripts and shaders (tree-shaking)
4. Godot's export pipeline packages it for the target platform
5. Result: a standalone executable / .apk / .ipa / HTML page
```

### Renderer Live-Switching in Editor

The editor allows switching renderers at runtime for preview purposes:
- Toolbar dropdown: `[Forward+ ▼]` → `Mobile` → `Compatibility`
- Triggers `ProjectSettings` change + viewport recreation
- All SubViewports (TOP outputs) are recreated with new renderer
- Operators re-cook
- Incompatible operators show error state immediately
- This lets artists preview exactly how their patch will look on mobile/web before exporting

**Technical note:** Godot 4.x requires a restart for full renderer change. For live preview, we may use a secondary viewport with the alternate renderer, or simply restart the embedded preview. Investigate during implementation.

---

## 19.5. Three-Tier Resource Loading System

### Problem Statement
`ResourceLoader.load()` only works for `res://` paths (bundled Godot resources). Standalone exported apps and user projects need to reference files on the filesystem — textures, fonts, audio, video, shaders — that live alongside the `.gnpatch` file, not inside the Godot project tree.

### Path Tiers

| Tier | Prefix | Example | Resolution | Use Case |
|------|--------|---------|------------|----------|
| **1 — Bundled** | `res://` | `res://addons/gonodes/shaders/top/noise.gdshader` | `ResourceLoader.load()` | Built-in resources shipped with the editor/export |
| **2 — Project** | `project://` | `project://textures/logo.png` | Resolve against `project_dir` → absolute path, then filesystem APIs | User assets stored alongside the `.gnpatch` file |
| **3 — Absolute** | `/` or `C:\` | `C:\Users\me\Desktop\photo.jpg` | Direct filesystem access | Quick one-off references (not portable — shown with ⚠ warning) |

### Project Folder Convention

When a user saves `MyPatch.gnpatch`, `GNProjectManager` creates a sibling folder `MyPatch_data/` with standard subfolders:

```
MyPatch.gnpatch
MyPatch_data/
├── textures/
├── fonts/
├── video/
├── audio/
├── models/
├── shaders/
├── presets/
├── scripts/
└── data/
```

Users place media assets into the appropriate subfolder. The file param dropdown scans these folders automatically.

### Data Flow: project_dir Injection

```
GNProjectManager.set_from_patch_path(path)
    │
    ├── Creates MyPatch_data/ folder + subfolders (if needed)
    └── Sets project_dir = "C:/path/to/MyPatch_data"
           │
           ▼
GNCookEngine.project_dir = project_dir
           │
           ▼ (each cook frame, for every node)
GNNode.project_dir = cook_engine.project_dir
           │
           ▼ (inside operator _cook())
GNResourceLoader.load_texture(file_path, project_dir)
```

The editor sets `project_dir` during save, load, new, setup, and auto-restore operations via `gn_editor.gd`.

### GNResourceLoader API

All methods are **static** — no instance needed.

| Method | Signature | Returns | Notes |
|--------|-----------|---------|-------|
| `classify` | `(path: String) → PathTier` | PathTier enum | Checks `res://`, `project://`, or absolute |
| `resolve` | `(path: String, project_dir: String) → String` | Absolute filesystem path | project:// → project_dir + relative; res:// and absolute pass through |
| `to_project_relative` | `(abs_path: String, project_dir: String) → String` | `project://...` or original | Converts absolute into project-relative if under project_dir |
| `to_saveable` | `(abs_path: String, project_dir: String) → String` | Best portable path | Prefers project:// > res:// > absolute |
| `exists` | `(path: String, project_dir: String) → bool` | bool | Works across all three tiers |
| `load_texture` | `(path, project_dir) → Texture2D` | Texture2D or null | res:// → ResourceLoader; filesystem → Image.load_from_file() + ImageTexture |
| `load_image` | `(path, project_dir) → Image` | Image or null | res:// → ResourceLoader + get_image(); filesystem → Image.load_from_file() |
| `load_font` | `(path, project_dir) → Font` | Font or null | res:// → ResourceLoader; filesystem → FontFile.load_dynamic_font() |
| `load_audio` | `(path, project_dir) → AudioStream` | AudioStream or null | res:// → ResourceLoader; filesystem → format-specific buffer loading (OGG, WAV, MP3) |
| `load_shader` | `(path, project_dir) → Shader` | Shader or null | res:// → ResourceLoader; filesystem → Shader.new() + code from FileAccess |
| `load_video` | `(path, project_dir) → VideoStream` | VideoStream or null | res:// → ResourceLoader; filesystem → VideoStreamTheora.file = path |
| `load_any` | `(path, project_dir) → Resource` | Resource or null | Tries ResourceLoader.load() for res://, delegates to type-specific for others |
| `scan_directory` | `(dir_path, extensions) → Array[String]` | File paths | Lists matching files, supports res:// via DirAccess |

### File Param UI (Three-Tier Dropdown)

The `FILE` parameter type in `gn_param_row.gd` renders as:

```
[OptionButton ▼ dropdown]  [… Browse]  [↻ Refresh]  [X Clear]
```

The OptionButton dropdown is populated with three sections:

```
── Bundled ──
  res://addons/gonodes/shaders/top/noise.gdshader
  res://addons/gonodes/shaders/top/blur.gdshader
── Project ──
  project://textures/logo.png
  project://fonts/custom.ttf
── External ──
  ⚠ C:\Users\me\Desktop\photo.jpg
```

- **Browse "…"** opens a native `FileDialog`. If the selected file is inside the project folder, it's auto-converted to `project://` relative path.
- **Refresh "↻"** re-scans both bundled and project directories.
- **Clear "X"** resets the parameter to empty string.
- External files show a ⚠ warning icon — they are not portable across machines.

### Operator Migration Summary

All operators that load external files were migrated from raw `ResourceLoader.load()` to type-specific `GNResourceLoader` methods:

| Operator | Family | Old Method | New Method |
|----------|--------|-----------|------------|
| AudioFileInCHOP | CHOP | `ResourceLoader.load(path)` | `GNResourceLoader.load_audio(path, project_dir)` |
| MovieFileInTOP | TOP | `ResourceLoader.load(path)` | `GNResourceLoader.load_video(path, project_dir)` |
| TextTOP | TOP | `ResourceLoader.load(path)` | `GNResourceLoader.load_font(path, project_dir)` |
| ShaderMAT | MAT | `ResourceLoader.load(path)` | `GNResourceLoader.load_shader(path, project_dir)` |
| ImageFileInIMG | IMG | `ResourceLoader.load(path)` | `GNResourceLoader.load_image(path, project_dir)` |
| ImageSequenceIMG | IMG | `ResourceLoader.load(path)` | `GNResourceLoader.load_image()` + `resolve()` + `exists()` |
| FFmpegInTOP | TOP (ext) | `_create_ffmpeg_stream(path)` | `GNResourceLoader.resolve(path, project_dir)` then `_create_ffmpeg_stream()` |

**Not migrated** (write-only, use STRING params): TextureSaveOUT, TableSaveOUT, RecordOUT, MovieOUT, FFmpegOUT.

---

## 20.5. 3D Scene Pipeline (SOP → COMP → RenderTOP)

GONODES uses Godot's native scene graph for 3D rendering instead of building a custom 3D engine. SOPs produce geometry data, COMPs wrap Godot Node3D types, and RenderTOP renders everything through a SubViewport back into the TOP texture pipeline.

### Architecture

```
SOP Chain (geometry)    MAT Layer        COMP Layer (3D scene)              TOP Pipeline
├──────────┐  ├────────────┐             ├──────────────┐                     ├───────────┐
│ GridSOP  │→→│TransformSOP│──→──┐       │              │                     │           │
└──────────┘  └────────────┘     ├──→─── │GeometryCOMP  │ (MeshInstance3D)─┐  │           │
                   ├─────────┐  │       │              │                  │  │           │
                   │ PBR_MAT │──→──┘     └──────────────┘                  ├──│ RenderTOP │→→ texture
                   └─────────┘           ├──────────────┐                  │  │           │   output
                                         │ CameraCOMP   │ (Camera3D) ─────┤  │           │
                                         └──────────────┘                  │  │           │
                                         ├──────────────┐                  │  │           │
                                         │ LightCOMP    │ (Light3D) ──────┤  │           │
                                         └──────────────┘                  │  └───────────┘
                                         ├──────────────┐                  │
                                         │ MergeCOMP    │ (Node3D group)──┘
                                         └──────────────┘
```

### Key Design Decisions

1. **Godot-native 3D nodes** — GeometryCOMP creates a real `MeshInstance3D`, CameraCOMP creates a real `Camera3D`, LightCOMP creates a real `DirectionalLight3D`/`OmniLight3D`/`SpotLight3D`. No custom rendering abstraction.

2. **Isolated World3D** — Each RenderTOP creates a `SubViewport` with an explicit `world_3d = World3D.new()` assigned before tree entry, giving it a separate 3D scene. This prevents 3D content from appearing in the main editor viewport and allows multiple independent 3D scenes in one network.

3. **Scene population via network walk** — RenderTOP's `_populate_scene_from_network()` walks upstream connections to discover COMP nodes, then reparents their Node3D children into the RenderTOP's viewport. This means the 3D scene is defined by network wiring, not by Godot scene tree structure.

4. **MAT input on GeometryCOMP** — GeometryCOMP accepts 3 inputs: SOP (geometry), MAT (material override), TOP (albedo texture for fallback PBR). When a MAT is connected, its Material is used directly via `material_override`; when disconnected, built-in PBR params + TOP texture build a fallback `StandardMaterial3D`.

5. **Default camera fallback** — If no CameraCOMP is connected to a RenderTOP, it creates a default perspective camera at (0, 2, 5) looking at origin, ensuring there's always a valid render.

6. **MergeCOMP for scene composition** — MergeCOMP groups multiple COMP scene nodes under a single `Node3D` parent. Inputs use **dynamic numbered ports** (comp0, comp1, comp2, …) that auto-grow when connected. Port index determines the scene graph child order (port 0 = first child, port 1 = second, …), giving the user deterministic control via which port they wire into. RenderTOP recognizes MergeCOMP and adopts the entire group node, enabling multi-object scenes wired through a single connection.

7. **Shadow system** — Shadows are controlled at three levels: per-light (LightCOMP: bias, normal_bias, blur, opacity, directional shadow mode), per-object (GeometryCOMP: cast_shadow mode), and global quality (RenderTOP: shadow atlas size, directional shadow size, shadow filter).

### COMP Family Details

COMPs are unique in that they don't produce data output (no `GNData` return from cook). Instead, they create and maintain Godot Node3D instances that other nodes access via API methods:

- `GeometryCOMP.get_mesh_instance() → MeshInstance3D`
- `CameraCOMP.get_camera() → Camera3D`
- `LightCOMP.get_light() → Light3D`
- `MergeCOMP.get_group_node() → Node3D`

The cook engine suppresses null-output warnings for COMP family nodes since this is intentional design.

### SOP Data Flow

SOPs output `GNGeoData` which wraps an `ArrayMesh`:

```
SOP generators (BoxSOP, SphereSOP, etc.)
  → create GNGeoData with ArrayMesh
  → pass downstream via SOP ports

SOP filters (TransformSOP, NoiseSOP, etc.)
  → read input GNGeoData
  → extract vertex arrays
  → modify and produce new GNGeoData

GeometryCOMP (terminal SOP consumer)
  → reads GNGeoData from SOP input
  → applies mesh to its MeshInstance3D
  → if MAT input connected: uses Material directly (material_override)
  → else: builds fallback StandardMaterial3D from params + optional TOP albedo texture
```

### Godot Types Used

| GONODES Operator | Godot Type Used |
|---|---|
| BoxSOP | `BoxMesh` |
| SphereSOP | `SphereMesh` |
| CylinderSOP | `CylinderMesh` |
| TorusSOP | `TorusMesh` |
| GridSOP, LineSOP, CircleSOP | `SurfaceTool` → `ArrayMesh` |
| NoiseSOP | `FastNoiseLite` + `SurfaceTool` |
| TransformSOP | Manual vertex transform via `Basis` |
| GeometryCOMP | `MeshInstance3D` + `StandardMaterial3D` |
| CameraCOMP | `Camera3D` |
| LightCOMP | `DirectionalLight3D` / `OmniLight3D` / `SpotLight3D` |
| RenderTOP | `SubViewport` + `WorldEnvironment` + `Environment` |

---

## 21. Data Ownership & Passing Model

### How TouchDesigner Does It
- **TOPs:** Textures live on the GPU. Downstream nodes receive a **handle/reference** to the GPU texture, not a pixel copy. The producer node owns its framebuffer; consumers sample it read-only via shader uniforms. Zero-copy.
- **CHOPs:** Channel arrays are passed by reference. The cook engine manages lifecycle. Consumers read the producing node's output; only the producing node writes.
- **SOPs/POPs:** Geometry/point data is passed by reference. Copy-on-write only when a node modifies geometry (e.g., Transform SOP creates its own output, doesn't mutate input).
- **Core rule: producer owns the data, consumers borrow it read-only.**

### GONODES Data Passing Rules

```
Ownership Rule:
  1. Each node OWNS its cached_output (the GNData it produced last cook).
  2. The cook engine passes cached_output REFERENCES to downstream _cook(inputs) calls.
  3. Downstream nodes MUST NEVER mutate input data — always create new output data.
  4. GNTextureData: the ViewportTexture is a live GPU reference (zero-copy on GPU).
  5. GNChannelData: PackedFloat32Array is copy-on-write in GDScript — safe as long as
     downstream doesn't mutate it. The contract forbids mutation.
```

### Per-Family Behavior

| Family | Data Type         | GPU/CPU | Passing Strategy                                     |
|--------|-------------------|---------|------------------------------------------------------|
| TOP    | GNTextureData     | GPU     | ViewportTexture reference. Zero-copy. Texture stays on GPU. Downstream samples via shader uniform. |
| CHOP   | GNChannelData     | CPU     | Reference to channels Dictionary. Read-only. PackedFloat32Array is CoW-safe. |
| SOP    | GNGeoData         | CPU/GPU | Reference to ArrayMesh. Transform ops create new output. Mesh data on GPU after upload. |
| POP    | (future)          | GPU     | GPU buffer handle. Zero-copy. Downstream compute shaders bind the buffer. |
| DAT    | GNTableData       | CPU     | Reference to table/text data. Read-only. Lightweight string arrays. |
| COMP   | null (scene nodes) | N/A    | COMPs return null from cook. Access via API: get_mesh_instance(), get_camera(), get_light(). |

### GNTextureData Reuse

Previously, each TOP cook created a new `GNTextureData` every frame. This caused unnecessary GC pressure.

**New rule:** Each TOP creates its `GNTextureData` once (during `_ensure_viewport()`) and reuses it across cooks. Only metadata (resolution, timestamp) is updated. The `ViewportTexture` reference is stable — it auto-updates when the SubViewport re-renders.

```gdscript
# In each TOP's _cook():
# BAD (old):
var data := GNTextureData.new()  # Allocates every frame
data.texture = _viewport.get_texture()
return data

# GOOD (new):
_cached_tex_data.resolution = res
return _cached_tex_data  # Same object, reused
```

### Thread Safety (Future)

When the cook engine moves to threaded cooking:
- GNData becomes **immutable after cook** — the producing node creates a new GNData for each cook, and the old one can be read by consumers on other threads.
- Or: **double-buffering** — each node has two GNData slots (front/back), consumers read front while producer writes back.
- For MVP (single-threaded `_process`), reference passing with read-only contract is sufficient.

---

## 22. Node-Based Architecture (GNNode extends Node)

GNNode extends Godot's `Node` class instead of `Resource`. This gives operators direct scene tree participation, allowing TOPs to own SubViewports as children and WindowOUTs to create OS windows naturally.

### Why Not Resource?
- **No scene tree lifecycle** — Resources have no `_ready()`, `_process()`, `_exit_tree()`. This forced workarounds: a centralized ViewportManager for TOPs, `Engine.get_frames_per_second()` hacks for delta time, manual `cleanup()` methods for SubViewport teardown.
- **Accidental copy risk** — `Resource.duplicate()` creates broken shallow copies of viewport/material references. Resource's serialization machinery was never used (patches serialize via GNNetwork, not individual nodes).
- **Per-frame allocation overhead** — GNData as Resource had unnecessary serialization infrastructure for transient compute results.

### The Tiered Design

| Class | Extends | Why |
|---|---|---|
| **GNNode** | **Node** | Scene tree access, TOPs own SubViewports, auto-cleanup via queue_free() |
| **GNData/GNTextureData/GNChannelData** | **RefCounted** | Transient compute results — lightest possible allocation |
| **GNPort** | **RefCounted** | Lightweight struct, no serialization needed |
| **GNConnection** | **RefCounted** | Lightweight struct, network serializes connection info |
| **GNParameter** | **Resource** | Benefits from @export for inspector + value persistence |
| **GNNetwork** | **Resource** | The serialization boundary — saves/loads patch files as .tres |

### Scene Tree Structure

```
MainScene (Node)
  ├── Viewer (TextureRect)
  ├── InfoLabel (Label)
  └── CookEngine (GNCookEngine extends Node)
        ├── lfo1 (LFO_CHOP extends GNNode extends Node)
        ├── noise1 (NoiseTOP extends GNNode extends Node)
        │   └── VP_noise1 (SubViewport)       ← owned by TOP, auto-freed
        │       └── Canvas (ColorRect + ShaderMaterial)
        ├── level1 (LevelTOP extends GNNode extends Node)
        │   └── VP_level1 (SubViewport)       ← owned by TOP, auto-freed
        │       └── Canvas (TextureRect + ShaderMaterial)
        └── win1 (WindowOUT extends GNNode extends Node)
            └── GNOutput_win1 (Window)        ← separate OS window, auto-freed
                └── Display (TextureRect)
```

### Timing Injection

Since `process_mode = DISABLED` on GNNodes, they can't self-tick. The cook engine injects timing each frame:

```gdscript
# In GNCookEngine.cook_frame():
for node in topo_order:
    node.current_delta = current_delta    # Frame delta (seconds)
    node.elapsed_time = elapsed_time      # Total time since start
    node.current_frame = frame_count      # Frame counter
```

Operators use `self.current_delta` instead of the old `Engine.get_frames_per_second()` hack.

### Node Adoption

The cook engine parents all network nodes as children in `_ready()`:

```gdscript
func _adopt_network_nodes() -> void:
    for node_id in network.nodes:
        var node: GNNode = network.nodes[node_id]
        if node.get_parent() == null:
            add_child(node)
```

When `network.remove_node()` is called, it removes the node from the tree and calls `queue_free()`, cascading cleanup to all child SubViewports and Windows.

---

## 23. Multi-Window & Multi-Display Output

GONODES supports multiple output windows, each displayable on any connected monitor. This is essential for VJing (editor on laptop screen, output on projector).

### Godot's Multi-Window Support

Godot 4.x provides:
- `Window` node — creates an OS-level window, can be moved/resized/fullscreened
- `DisplayServer.get_screen_count()` — enumerate connected monitors
- `DisplayServer.get_screen_position(idx)` / `get_screen_size(idx)` — monitor geometry
- `DisplayServer.window_set_mode()` — fullscreen, borderless, windowed
- Each `Window` can host its own `SubViewportContainer` to display content

### WindowOUT Operator

A new TOP operator that takes a texture input and displays it in a standalone OS window.

```
WindowOUT
├── Inputs: 1 (TOP texture)
├── Outputs: 0 (display-only, terminal node)
├── Parameters:
│   ├── title: String ("GONODES Output")
│   ├── monitor: int (0 = primary, 1 = secondary, ...)
│   ├── window_mode: enum (Windowed, Fullscreen, Borderless)
│   ├── resolution: Vector2i (1920×1080)
│   ├── position: Vector2i (auto = centered on target monitor)
│   ├── always_on_top: bool (false)
│   └── vsync: bool (true)
└── Implementation:
    ├── Creates a Godot Window node
    ├── Inside: SubViewportContainer + SubViewport + TextureRect
    ├── TextureRect.texture = input TOP's ViewportTexture
    ├── Window positioned on target monitor
    └── Updates every frame (the TextureRect auto-updates from ViewportTexture)
```

### Multi-Window Architecture

```
Scene Tree:
  Root (Window — main editor)
  ├── MainEditor (editor UI, graph, inspector)
  └── CookEngine (GNCookEngine)
        ├── noise1 (NoiseTOP)
        │   └── VP_noise1 (SubViewport)
        │       └── Canvas (ColorRect)
        ├── level1 (LevelTOP)
        │   └── VP_level1 (SubViewport)
        │       └── Canvas (TextureRect)
        ├── win1 (WindowOUT — second monitor, fullscreen)
        │   └── GNOutput_win1 (Window — OS window)
        │       └── Display (TextureRect → level1's ViewportTexture)
        └── win2 (WindowOUT — projector, borderless)
            └── GNOutput_win2 (Window — OS window)
                └── Display (TextureRect → noise1's ViewportTexture)
```

### Monitor Enumeration at Runtime

```gdscript
# Available to WindowOUT and the editor's display picker:
# Note: Godot 4.x uses screen_get_position/screen_get_size (not get_screen_*).
for i in range(DisplayServer.get_screen_count()):
    var pos := DisplayServer.screen_get_position(i)
    var size := DisplayServer.screen_get_size(i)
    print("Display %d: %s at %s" % [i, size, pos])
```

### Texture Routing

WindowOUT does NOT copy the texture. It assigns the upstream TOP's `ViewportTexture` directly to its internal TextureRect — a live GPU reference. The Window's render tree samples the same GPU texture as the graph viewer. **Zero-copy output.**

**Important — TextureRect layout in programmatic Windows:**
When creating a TextureRect inside a Window node via code, do NOT use the `anchors_preset` property setter — it only sets anchors but leaves offsets at 0, resulting in a 0×0 rect. Always call `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` AFTER adding the control to the tree.

**Important — ViewportTexture cross-viewport usage:**
When assigning a ViewportTexture programmatically (not via the editor), it works across Viewport boundaries because it references the source SubViewport by RID, not by scene-relative path. Direct assignment (`texture_rect.texture = viewport.get_texture()`) works correctly even when the TextureRect lives inside a secondary Window.

### VJ Workflow

1. Build patch in the editor (monitor 1)
2. Add a WindowOUT node, set `monitor = 1` (projector), `window_mode = Borderless`
3. Wire the final TOP chain into the WindowOUT
4. The projector shows the live output, borderless, fullscreen
5. Multiple WindowOUTs can show different parts of the patch on different displays
6. Parameters (monitor, fullscreen, resolution) can be driven by CHOPs for live switching

---

## 24. Logging System (GNLogger)

GNLogger is a static utility class (`extends RefCounted`, `class_name GNLogger`) providing centralized, toggleable logging across the framework.

### Design

- **Static API** — call from anywhere without instantiation: `GNLogger.info("Category", "message")`
- **Master toggle** — `GNLogger.enabled` (off by default, no output when disabled)
- **Level filtering** — `GNLogger.level` with `DEBUG`, `INFO`, `WARN`, `ERROR`, `NONE`
- **Category muting** — `GNLogger.muted_categories["CookEngine"] = true` to silence a subsystem
- **Routing** — `WARN` → `push_warning()`, `ERROR` → `push_error()`, others → `print()`
- **Per-line metadata** — frame number, optional timestamps

### Usage

```gdscript
GNLogger.enabled = true
GNLogger.level = GNLogger.Level.DEBUG  # See everything

GNLogger.info("CookEngine", "Frame cooked in %.2fms" % t)
GNLogger.debug("NoiseTOP", "Viewport created: %s" % vp.name)
GNLogger.warn("Network", "Cycle detected")
GNLogger.error("Parameter", "Expression compile failed")
```

### Coverage

| Subsystem | Logged Events |
|---|---|
| GNCookEngine | Engine ready, node adoption, per-frame summary (DEBUG), per-node cook timing (DEBUG), expression/bind errors, proxy lookup failures, invalidate/reset |
| GNNetwork | Node add/remove, connect/disconnect, cycle detection, topo sort recomputation |
| GNNode | Initialize (ports/params), null cook output |
| TOP operators | Viewport creation, missing input warnings |
| WindowOUT | Window creation, window hidden by user |
| CHOP operators | Missing input warnings |
| GNParameter | Expression compile success/failure |

### UI Toggle

The test scene includes a `CheckButton` (top-right corner, "Debug Log") that toggles `GNLogger.enabled` at runtime.

---

## 20. Open Questions (To Resolve During Implementation)

1. **GraphEdit vs custom canvas:** Godot's `GraphEdit` has limitations (styling, custom port shapes, minimap). May need custom drawing. Evaluate during Phase 3.
2. **Expression sandboxing:** GDScript `Expression` class is limited. May need a custom expression parser for the `op()/chop()` syntax. Evaluate during Phase 4.
3. **Viewport performance ceiling:** How many SubViewports can run simultaneously before frame drops? Profile during Phase 6.
4. **Thread safety:** When moving cook engine to threads (future), GNData needs immutable snapshots or double-buffering. Design for this but don't implement in MVP.
5. ~~**LibGodot API surface:**~~ **RESOLVED.** LibGodot exposes `godot_setup()`, `godot_start()`, `godot_iteration()`, `godot_shutdown()`. GONODES wraps these in `libgonodes/src/gonodes_bootstrap.cpp` with dynamic loading. Full C API implemented in `gonodes_host.h` (30+ functions). See `dev_docs/INTEGRATION.md`.
6. **Renderer live-switching:** Does Godot 4.6 support hot-swapping renderers without restart? If not, what's the best workaround for editor preview?
7. **Compute shader availability:** Verify that `RenderingDevice` compute dispatches work in Mobile renderer on all targets (some mobile GPUs have limitations).
8. **POP feedback loops:** Validate that the one-frame-latency feedback model works smoothly with Godot's `SubViewport` / buffer management.
9. **Export tree-shaking:** Can we reliably detect which operator scripts/shaders a patch uses and exclude unused ones from the export?

---

*This file should be read by the LLM at the start of each session to maintain continuity.*

---

## 21. Phase 3 Architecture: Node Graph UI

### Overview

The editor UI is built on Godot's `GraphEdit` and `GraphNode` controls with bidirectional sync to the `GNNetwork` model. Flow is left-to-right (Godot `GraphEdit` is hardcoded horizontal — vertical layout would require replacing the entire widget).

### Files

| File | Class | Purpose |
|------|-------|---------|
| `addons/gonodes/ui/gn_node_view.gd` | `GNNodeView` | GraphNode wrapper per operator. Family-colored title bar (StyleBoxFlat), typed port slots via `set_slot()`, position sync via `position_offset_changed` |
| `addons/gonodes/ui/gn_graph_editor.gd` | `GNGraphEditor` | GraphEdit canvas. Handles connection/disconnection/deletion, bidirectional sync with GNNetwork via signals, hosts palette. Signals: `operator_selected(node_id)`, `operator_deselected()` |
| `addons/gonodes/ui/gn_node_palette.gd` | `GNNodePalette` | PopupPanel with search LineEdit + Tree grouped by family. Tab/right-click to open. Spawns operators via `_create_operator_instance()` |
| `scenes/gn_editor.tscn` | — | HSplitContainer layout: GraphPanel (left) + RightPanel (VSplit: Viewer + Inspector) + InfoBar (bottom) |
| `scenes/gn_editor.gd` | — | Wires graph_editor + inspector + cook_engine. Demo network: lfo1→noise1→level1→win1 |

### Operator Registry

Currently hardcoded in `GNGraphEditor.get_operator_registry()` as a static Dictionary:

```gdscript
{ "noise_top": NoiseTOP, "composite_top": CompositeTOP, ... }
```

New operators must be manually added to this dictionary.

### Signal Flow

```
User drags wire → GraphEdit.connection_request
  → GNGraphEditor._on_connection_request()
    → GNNetwork.connect_nodes()
      → GNNetwork.connection_added signal
        → GNGraphEditor._on_network_connection_added()
          → GraphEdit.connect_node() (visually)
```

Same pattern for disconnection, node add/remove.

---

## 22. Phase 4 Architecture: Parameters & Inspector

### Overview

The parameter inspector is a right-side panel that shows all parameters for the selected node, with type-specific UI controls, live expression editing, and mode toggling.

### Files

| File | Class | Purpose |
|------|-------|---------|
| `addons/gonodes/ui/gn_param_row.gd` | `GNParamRow` | Per-parameter widget. Type-specific controls (FLOAT: HSlider+SpinBox, INT: SpinBox, BOOL: CheckBox, ENUM: OptionButton, COLOR: ColorPickerButton, VECTOR2/2I: dual SpinBox, STRING: LineEdit, FILE: Button+FileDialog picker, RAMP: GNRampEditor curve editor). Mode toggle button (C=green, E=orange). Expression LineEdit with focus guard. ↗ expand buttons open multi-line editor. Code params get "Edit ↗" button opening GNCodeEditor. Profiling tooltip. |
| `addons/gonodes/ui/gn_base_code_editor.gd` | `GNBaseCodeEditor` | Abstract base class (extends Window) for modal code-editing windows. Provides shared layout: MarginContainer → VBox → info label → toolbar hook → CodeEdit (line numbers, auto-indent, brace completion, word wrap) → status label → Cancel/OK buttons. Key bindings (Ctrl+Enter, Escape). Virtual hooks: `_build_toolbar()`, `_setup_code_edit()`, `_build_bottom_bar()`, `_on_ok()`. Helper methods: `_focus_end()`, `_set_status()`. |
| `addons/gonodes/ui/gn_expression_editor.gd` | `GNExpressionEditor` | Extends GNBaseCodeEditor. Expression editing with family-aware code completion (chop(" filters CHOPs, top(" filters TOPs, par("/set_par(" show all; hierarchical path completion via `_suggest_hierarchical_nodes()` for subnetwork browsing; node IDs color-coded by family), live validation, Snippets ▾ dropdown (30+ built-in + user snippets persisted to disk), reference cheatsheet. |
| `addons/gonodes/ui/gn_ramp_editor.gd` | `GNRampEditor` | Custom `_draw()` curve editor for RAMP parameters. Grid background (0.25 increments), cubic Hermite curve rendering, draggable keypoints with tangent handles, left-click to add point, right-click to remove (min 2), Ctrl+click to toggle smooth/linear tangents. Signal: `ramp_changed(keys)`. |
| `addons/gonodes/ui/gn_network_box.gd` | `GNNetworkBox` | Canvas annotation: colored rectangle behind graph nodes (z_index=-10) for visual grouping. Title bar with inline edit (double-click), drag-move, bottom-right resize, right-click context menu. Signals: `box_changed`, `text_changed`, `delete_requested`, `color_changed`. |
| `addons/gonodes/ui/gn_sticky_note.gd` | `GNStickyNote` | Canvas annotation: editable text note (z_index=-9). Multi-line TextEdit (double-click), drag-move, resize, right-click context menu. Default yellow. Signals: `note_changed`, `text_changed`, `delete_requested`, `color_changed`. |
| `addons/gonodes/ui/gn_code_editor.gd` | `GNCodeEditor` | Extends GNBaseCodeEditor. Script operator / CustomShaderTOP code editing with GDScript or GLSL syntax highlighting (mode-adaptive), preset load/save toolbar (via GNScriptHelper), save-preset dialog, reference cheatsheet. |
| `addons/gonodes/ui/gn_main_help_window.gd` | `GNMainHelpWindow` | Main help reference hub. HSplitContainer: sidebar Tree (search bar + expandable sections/families/operators) + ScrollContainer>RichTextLabel. Loads .md files from `help/` via GNMarkdownRenderer, generates operator docs from registry metadata. Singleton toggled via toolbar or F1. |
| `addons/gonodes/ui/gn_markdown_renderer.gd` | `GNMarkdownRenderer` | Static utility (extends RefCounted) converting Markdown to BBCode. Handles headers, bold, italic, inline code, code blocks, tables, lists, blockquotes, horizontal rules, links. Used by GNMainHelpWindow. |
| `addons/gonodes/ui/gn_param_inspector.gd` | `GNParamInspector` | PanelContainer with family color bar, header (node ID, type, cook time), scrollable GNParamRow list, placeholder label when nothing selected |

### Key Design Decisions

1. **Per-cook updates are lightweight:** Inspector connects to `node_cooked` signal. Per-cook path only calls `update_expression_status()` (error label colors), NEVER `_update_mode_display()` (which sets text).
2. **Focus guard:** `_expr_edit.has_focus()` is checked before setting text in any update path to prevent clobbering user edits.
3. **Expression commit on focus-out:** `focus_exited` signal on expression LineEdit triggers `_apply_expression_text()`.
4. **Mode toggle:** Single button cycles C→E (E→C). Button text and color update immediately.

### Editor Layout

```
HSplitContainer
├── GraphPanel (split_offset ratio ~2:1)
│   └── GNGraphEditor (GraphEdit)
│   └── GNDebugOverlay (5-layer canvas overlay, F2 toggle)
└── RightPanel (VSplitContainer)
    ├── ViewerPanel (TextureRect, split ~1.5)
    │   └── _viewer_rect (shows selected TOP output)
    └── InspectorPanel (split ~1.0)
        └── GNParamInspector
GNDebugPanel (3-tab docked panel, below graph — visible when Debug on)
InfoBar (bottom)
└── FPS label (yellow)
```

---

## 25. Hard Rules & Lessons Learned

These are non-negotiable constraints discovered during development. **Never violate these.**

### 25.1 No CPU Roundtrips for Real-Time Texture Data

**NEVER** call `Texture2D.get_image()` or `Image.get_data()` in a per-frame path. This triggers a GPU→CPU readback that stalls the rendering pipeline and can cost 5-15ms per call.

- Use `ViewportTexture` (live GPU reference) for texture routing between nodes
- Use `ImageTexture` snapshots ONLY for one-time captures (thumbnails, file export)
- All real-time texture passing stays on the GPU via SubViewport → ViewportTexture → TextureRect chain
- If you need CPU-side pixel data (e.g., for a DAT or CHOP reading color values), do it async via `RenderingServer` and accept one-frame latency

### 25.2 Godot Expression base_instance Architecture

- Functions called inside an `Expression` are **method lookups on `base_instance`**, not calls to input variables
- Passing Callables as input variables and calling them will **silently fail** (returns null, no error)
- Always make expression-callable functions **real methods** on the base_instance object

### 25.3 GNFamily.get_name → get_family_name

- Static methods on classes extending `Object` must not shadow built-in methods
- `Object.get_name()` takes 0 args; a custom `get_name(family)` with 1 arg causes a signature collision at runtime
- Use unique names: `get_family_name()`, not `get_name()`

### 25.4 WindowOUT Cook-Dirty vs Param-Dirty

- `dirty` on a sink node (WindowOUT) is `true` every frame when upstream contains time_dependent nodes
- Using `if dirty:` to apply window config causes per-frame reconfiguration → 15fps
- Use a dedicated `_window_params_dirty` flag, set only by overriding `_on_parameter_changed()`
- Cook-dirty (upstream data changed) ≠ parameter-dirty (this node's params changed)
- Any future config-heavy sink nodes should use the same pattern

### 25.5 Anchors Preset vs set_anchors_and_offsets_preset

- `Control.anchors_preset = PRESET_FULL_RECT` only sets anchors, NOT offsets → 0×0 size
- Always use `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` for full-rect layout
- Must be called AFTER the control is added to the tree

### 25.6 embed_subwindows

- `project.godot` must have `window/subwindows/embed_subwindows=false` for WindowOUT to create real OS-level windows
- Without this, Window nodes render as embedded panels inside the main window

### 25.7 DisplayServer API (Godot 4.x)

- Use `DisplayServer.screen_get_size()` / `screen_get_position()` (not `get_screen_size/position`)
- Use `DisplayServer.window_set_vsync_mode(mode, window_id)` for per-window vsync

### 25.8 GraphEdit / GraphNode Signal Naming

- `GraphEdit` has built-in signals named `node_selected` and `selection_cleared`
- Custom signals on subclasses must use different names to avoid shadowing
- Use `operator_selected` / `operator_deselected` instead

### 25.9 Inspector Per-Cook Updates

- Inspector is called every cook frame via `node_cooked` signal
- NEVER call `_update_mode_display()` (which sets `_expr_edit.text`) per-cook — clobbers edits 60x/sec
- Use lightweight `update_expression_status()` per-cook (only updates error label colors)
- Check `_expr_edit.has_focus()` before setting text in any update path

### 25.10 Dynamic Input Ports (Auto-Grow)

- Operators that accept a variable number of inputs use **dynamic input ports** instead of fixed port counts or the old `multi_input` flag.
- **Operators using auto-grow:** MergeSOP, MergeCOMP, RenderTOP, MergeCHOP, SwitchTOP, SwitchCHOP, SwitchSOP, SwitchDAT (8 total).
- **Mechanism:** `GNNode._enable_dynamic_inputs()` is called in `_init_ports()`. It stores the family/prefix and creates an initial empty port.
- **Auto-grow:** After every `connect_nodes()`, the network calls `_update_dynamic_node_inputs()` which ensures `max_connected_port + 2` ports exist (one trailing empty slot for the next connection).
- **Auto-shrink:** After every `disconnect_nodes()`, trailing empty ports are collapsed back, keeping at least one empty slot.
- **Port index = hierarchy order:** For MergeCOMP/MergeSOP, the input port index directly determines the processing/child order. Port 0 is first, port 1 is second, etc. No Y-position sorting hack needed.
- **Switch operators:** Override `update_dynamic_inputs()` to auto-adjust the `index` parameter's `max_value` to match `input_ports.size() - 2` (highest connected port). The old `num_inputs` parameter is removed — wiring is the source of truth.
- **Serialization:** `to_dict()` saves `dynamic_input_count`, `from_dict()` restores it before connections are loaded. Post-load safety: `_update_dynamic_node_inputs()` runs for all dynamic nodes.
- **Cook engine path:** `_gather_inputs()` uses a single code path — port-indexed array with possible null entries for disconnected ports. Operators must handle null inputs.
- Supersedes the old `port.multi_input` flag and the `num_inputs` parameter pattern. `GNPort.multi_input` still exists but is unused (deprecated).

### 25.11 COMP Nodes Return Null Output

- COMPs (GeometryCOMP, CameraCOMP, LightCOMP) intentionally return `null` from `_cook()`
- Their "output" is a Godot Node3D (MeshInstance3D, Camera3D, Light3D), not a GNData subclass
- Downstream access is via API methods: `get_mesh_instance()`, `get_camera()`, `get_light()`
- The cook engine must suppress null-output warnings for `GNFamily.COMP` nodes
- RenderTOP accesses COMP nodes by walking the network graph, not by reading cook output

### 25.12 SubViewport World3D for Isolated 3D Scenes

- RenderTOP assigns `SubViewport.world_3d = World3D.new()` before tree entry to create an isolated 3D world (without `own_world_3d = true`, which caused a duplicate World3D bug with Jolt Physics)
- Without this, 3D content from RenderTOP would appear in the main editor viewport
- Each RenderTOP has its own Environment/WorldEnvironment for independent lighting/sky

### 25.13 Lazy Cook / No Unnecessary Work

- **A node must NOT cook (or render) if nothing changed.** A cook fires only when:
  1. `time_dependent = true` → always dirty each frame
  2. A parameter value changed (expression eval, UI edit, script)
  3. An upstream input produced new output (dirty propagation)
- **Applies to ALL families equally** — TOPs, CHOPs, DATs, SOPs, COMPs
- **TOP-specific rule — SubViewport update mode:**
  - `time_dependent = true` → `UPDATE_ALWAYS` (renders every frame)
  - `time_dependent = false` → `UPDATE_ONCE` on cook (Godot renders one frame, then auto-flips to `UPDATE_DISABLED`)
  - `_ensure_viewport()` should default to `UPDATE_DISABLED` (not `UPDATE_ALWAYS`) so the viewport never renders before first cook
- **No per-frame overhead when static:** A non-time-dependent NoiseTOP with unchanged params produces zero GPU render passes after its initial cook
- **Expression-driven params are safe:** Expression evaluation that changes a param marks the node dirty → re-cook → `UPDATE_ONCE` fires → exactly one render pass. No difference from `UPDATE_ALWAYS` in that scenario, but saves the render pass when the expression result is unchanged
- **SOP/DAT/CHOP equivalent:** The cook engine already skips `_cook()` on clean nodes. No additional mechanism needed — just never set `time_dependent = true` unless the operator genuinely changes every frame

### 25.14 Tooltip Descriptions — Mandatory for Every Operator

- **Every operator MUST provide three levels of description:**
  1. `node_description` — set in `_init()` alongside `node_type` and `family`. Short sentence describing the node's purpose (shown in palette tooltip and node header).
  2. **Port descriptions** — last argument (`desc`) on every `add_input()` / `add_output()` call in `_init_ports()`. Describes what the port expects or produces.
  3. **Parameter descriptions** — last argument (`p_description`) on every `GNParameter.create_*()` call in `_init_parameters()`. Describes what the parameter controls.
- **Factory method pattern:** `p_description` is always the LAST positional argument, after `p_label`. If a parameter has no custom label, pass `""` for `p_label` before the description: `create_float("size", 1.0, 0.0, 10.0, 0.1, "", "Widget size in pixels")`.
- **Port method pattern:** `desc` is the last arg: `add_input("in", GNFamily.Type.TOP, false, "Input texture")`.
- **UI wiring (already implemented):**
  - Inspector: `GNParamRow` sets `tooltip_text` on the parameter name label from `param.description`.
  - Graph ports: `GNNodeView._build_slots()` sets `tooltip_text` on the row container from port descriptions.
  - Palette: `GNNodePalette` shows `_get_operator_description()` as tree-item tooltip.
- **When adding a new operator:** follow this rule or the node will have empty tooltips.

### 25.15 Dynamic Port Counts — Runtime-Adjustable I/O Ports

- **Goal:** Nodes whose input (or output) count is logically variable should expose a parameter or auto-detection mechanism that adds/removes ports at runtime instead of wasting fixed slots.
- **Base-class API (GNNode):**
  - `set_input_count(count, port_family, name_prefix, desc_prefix)` — clears all input ports, rebuilds `count` sequentially-named ports, emits `ports_changed(node_id)`.
  - `set_output_count(…)` — same for outputs.
  - `signal ports_changed(node_id: String)` — fired after any port-count change.
- **Graph wiring (GNGraphEditor + GNNetwork):**
  - `GNGraphEditor` connects to `ports_changed` **before** `GNNodeView.setup()` so stale wires are pruned first.
  - `GNNetwork.prune_stale_connections(node_id)` removes any connection whose port index exceeds the node's current port count, emitting `connection_removed` for each.
  - `GNNodeView` listens for `ports_changed` and calls `rebuild_slots()` to update the visual GraphNode.
- **Parameter-driven pattern (DEPRECATED — replaced by dynamic auto-grow):**
  - The old approach used a `num_inputs` INT parameter (min 2, max 8, default 2) with `_on_parameter_changed` calling `set_input_count()`.
  - **Superseded by `_enable_dynamic_inputs()`** — all Switch and Merge operators now use auto-grow.
- **Dynamic auto-grow pattern (Switch / Merge nodes):**
  - In `_init_ports()`, call `_enable_dynamic_inputs(family, prefix, desc)` instead of manual `add_input()`.
  - Ports auto-grow on connect (trailing empty slot) and auto-shrink on disconnect.
  - Switch operators override `update_dynamic_inputs()` to adjust the `index` parameter's `max_value` to match the highest connected port (excludes trailing empty slot).
  - Applies to: MergeSOP, MergeCOMP, RenderTOP, MergeCHOP, SwitchTOP, SwitchCHOP, SwitchDAT, SwitchSOP.
  - No `num_inputs` parameter needed — wiring is the source of truth.
- **Shader-driven pattern (CustomShaderTOP):**
  - On shader recompile, scan for `uniform sampler2D gn_tex<N>` declarations.
  - Rebuild input ports to match the highest `gn_tex` index found + 1 (clamped 0-8).
  - No explicit `num_inputs` parameter — the shader source is the single source of truth.
- **Resource motivation:** Every unused TOP input port can imply an idle SubViewport. Fewer ports = fewer GPU resources wasted.
- **When adding a new operator with variable port count:** follow either the parameter-driven or auto-detection pattern above. Always emit `ports_changed` after modifying port arrays.

### 25.16 Canvas Anchoring in TOP SubViewports

- **Problem:** Setting `_canvas.size = Vector2(res)` manually causes rendering glitches when switching between inputs with different resolutions. The canvas can end up smaller than the viewport or positioned incorrectly, producing clipped or offset output.
- **Root cause:** Manual size management has timing issues with Godot's layout system. When the viewport resizes, the canvas may not update in the same frame.
- **Solution:** Use `_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` AFTER `add_child(_canvas)` (anchors require a parent). The canvas auto-fills its parent viewport at any resolution. In `_cook()`, only set `_viewport.size = res` — the canvas follows automatically via anchors.
- **Critical:** Use `set_anchors_and_offsets_preset()`, NOT `set_anchors_preset()`. The latter only sets anchor values but adjusts offsets to maintain the current rect (which is zero-sized), resulting in an invisible canvas. `set_anchors_and_offsets_preset()` properly zeroes offsets so the Control fills the parent.
- **Applies to:** All 21 TOP operators with SubViewports (every file in `operators/top/` except null_top, switch_top, render_top). WindowOUT is now in `operators/output/window_out.gd`.
- **Special cases:** `blur_top.gd` has 2 canvases (`_canvas_h`, `_canvas_v`), `text_top.gd` has `_bg` + `_label` — all get anchors.

### 25.17 Viewer Panel Sizing — TextureRect expand_mode

- **Problem:** The ViewerPanel (TOP preview) forces the entire right panel to grow when displaying a wide texture (e.g., 512x256 = 2:1 ratio doubles the panel width).
- **Root cause:** `TextureRect.expand_mode = EXPAND_FIT_HEIGHT` (value 3) scales the texture to fit the panel's height, then demands width matching the texture's aspect ratio. This feeds back into the SplitContainer's minimum size calculation.
- **Solution:** Use `expand_mode = EXPAND_IGNORE_SIZE` (value 1). The TextureRect reports zero minimum size, so the panel is freely resizable. Combined with `stretch_mode = KEEP_ASPECT_CENTERED` (value 5), the texture renders with correct proportions inside whatever space is available.
- **Also:** Set `clip_contents = true` and a small `custom_minimum_size.y = 40` on both ViewerPanel and InspectorPanel so the VSplitContainer allows them to shrink freely.

### 25.18 Node Renaming — Full ID Update Chain

- **Feature:** Double-click a node's title bar to rename it inline. Press Enter or click away to commit.
- **Implementation chain:**
  1. `GNNodeView._gui_input()` detects double-click in the title bar area (y <= 30px)
  2. A `LineEdit` is added as an overlay (NOT as a GraphNode child row — but since GraphNode auto-slots children, we must call `reset_size()` after removal to prevent height growth)
  3. On commit, `rename_requested(old_id, new_id)` signal fires
  4. `GNGraphEditor._on_node_rename_requested()` calls `network.rename_node()`
  5. `GNNetwork.rename_node()` updates: nodes dict key, `GNNode.id`, `GNNode.name`, all `GNConnection` references, expression strings across all params (regex-based path-segment replacement including component_expressions, script code bodies, and CallbackDAT callback slots), then emits `node_renamed`
  6. `GNGraphEditor._on_network_node_renamed()` disconnects visual wires under old name, updates `_node_views` dict key, calls `view.apply_rename()`, reconnects wires, re-emits `operator_selected`
  7. `gn_editor.gd._on_node_renamed()` updates `_viewer_node_id` if renamed node was being viewed
  8. Inspector refreshes header label on re-inspect of same node object
- **Validation:** IDs must match `^[a-zA-Z_][a-zA-Z0-9_]*$` (alphanumeric + underscore, starts with letter or underscore). Empty and duplicate IDs are rejected.
- **GraphNode.name matters:** GraphEdit uses `GraphNode.name` for wire routing. The `name` property MUST be updated atomically with the visual wire disconnect/reconnect to avoid orphaned connections.

### 25.19 GNNode Lifecycle — `.new()` vs `initialize()` vs `_init_ports()`

- **Problem:** `create_instance()` calls `.new()` which runs `_init()`, but `_init_ports()` is NOT called in the constructor — it’s deferred to `initialize(id)`. This means a freshly `.new()`’d operator has **empty `input_ports` and `output_ports` arrays**.
- **Root cause:** GDScript constructors (`_init()`) cannot reliably call virtual methods on subclasses. `_init_ports()` is virtual and overridden by every operator, so it must be called after construction.
- **Lifecycle:**
  1. `_init()` (constructor) — sets `node_type`, `family`, `node_description`, `time_dependent`, `is_sink`. **No ports, no parameters.**
  2. `initialize(id)` — sets ID, disables processing, calls `_init_ports()` + `_init_parameters()`, wires parameter signals.
  3. Full `initialize()` is only needed for nodes entering the network (need ID, need param signal wiring).
- **When you only need ports** (e.g., building the input-family cache for the palette filter): call `node._init_ports()` explicitly after `.new()`. Do NOT call full `initialize()` — it requires a unique ID and wires signals that are unnecessary for introspection.
- **When you only need identity** (family, node_type): `.new()` alone is sufficient.
- **Applies to:** `GNExtensionRegistry._build_input_family_cache()` which instantiates all operators, calls `_init_ports()`, inspects port arrays, then frees them. Without the explicit `_init_ports()` call, the cache would be empty and palette filtering would show all operators unfiltered.

### 25.20 Editor/Engine Separation — Headless Safety

- **Rule:** Core engine code (`core/`, `operators/`) must NEVER import or reference UI code (`ui/`). The cook engine, network model, and all operators run without the editor present.
- **Preview methods** (`create_preview_control()`, `update_preview_control()`) live in family base classes under `core/` but are virtual no-ops that create simple `Label`/`TextureRect` nodes. They are ONLY called by `GNNodeView` (in `ui/`) — never by the cook engine. In headless mode, no caller exists, so no Controls are created.
- **Verified clean:** No file in `core/` or `operators/` uses `preload()`/`load()` on any `ui/` path. No operator references `GNNodeView`, `GNGraphEditor`, `GNParamInspector`, or any UI class.
- **Cache building** (`_build_input_family_cache`): instantiates operators via `.new()` + `_init_ports()` only. Operator `_init()` methods set trivial string/bool fields — no viewports, shaders, textures, or Controls created. Nodes freed immediately after inspection.

### 25.21 Help Example Patches Required for Every New Operator

- **Rule:** Every new operator MUST ship with at least one `.gnpatch` example file in `addons/gonodes/help/<family>/`.
- **Naming:** `<node_type>_<descriptive_label>.gnpatch` where `<node_type>` is the lowercase node type string (e.g. `noise`, `lfo`, `box`). The label should be a short, descriptive slug (e.g. `basic`, `color`, `waveforms`, `metallic`).
- **Content requirements:**
  - The patch's `type` field in each node must use the operator's `class_name` (e.g. `"NoiseTOP"`, `"LFOCHOP"`).
  - Must demonstrate the operator's primary functionality with non-default parameter values that produce a visually interesting result.
  - Should be self-contained (no external file dependencies) unless the operator is specifically a file-input operator.
  - Keep patch complexity low — ideally 1–4 nodes. Users should understand what the operator does at a glance.
- **Multiple patches encouraged:** For operators with distinct modes or use cases, create 2 patches (e.g. `pbr_metallic.gnpatch` + `pbr_emissive.gnpatch`). Maximum ~3 per operator to keep help manageable.
- **New operator checklist:** When implementing a new operator, the PR/change must include:
  1. The operator script in `operators/<family>/`
  2. Registration in `_register_core_operators()` (or in the extension's `gn_extension.cfg`)
  3. At least one help example patch in `help/<family>/`
  4. A `node_description` string and tooltip descriptions on all parameters (Hard Rule 25.14)
- **Extension operators:** GN extensions (`gn_ext_*`) include help patches in their own `help/<family>/` subdirectory. The help window scans extension dirs automatically (see §28.10).
- **Validation:** Help patches are discovered at runtime via directory scan — no manifest needed. To verify coverage, compare operator names from the registry against filenames in `help/<family>/`.

### 25.22 Help Patch Sink Rule — Meaningful Visualization Chain to WindowOUT

- **HARD RULE:** Every help `.gnpatch` example must terminate with a `WindowOUT` node (resolution 512×512, `open: true`) via a **meaningful, family-appropriate visualization chain**.
- **"Meaningful" means:** The connection path from the demonstrated operator to WindowOUT must respect port family compatibility and produce a visible result that actually demonstrates the operator. Simply connecting any node to WindowOUT regardless of family is invalid — it creates broken connections and dead-end branches.
- **Required chains by family:**
  - **TOP** → WindowOUT (direct — TOP outputs are textures)
  - **IMG** → ImgToTOP → WindowOUT (CPU image → GPU texture bridge)
  - **CHOP** → CHOPtoTOP → WindowOUT (waveform/graph visualization)
  - **SOP** → GeometryCOMP + CameraCOMP → RenderTOP → WindowOUT (3D render)
  - **COMP (scene COMPs: Geo, Rigid, Static, Soft, Instance, Merge, Area)** → RenderTOP + CameraCOMP → WindowOUT (3D render)
  - **COMP (pass-through COMPs: Null, Switch, Animation, Replicator, SubNetwork)** → must be **in the active chain** feeding RenderTOP, not bypassed. Route data *through* the demonstrated COMP, not around it.
  - **DAT** → TextTOP → WindowOUT (text display)
  - **MAT** → GeometryCOMP (MAT on port 1, SOP on port 0) + CameraCOMP → RenderTOP → WindowOUT
- **Pass-through COMP rule:** If the demonstrated operator is a pass-through COMP (NullCOMP, SwitchCOMP, AnimationCOMP), the chain must route through it: `GeoComp → PassThroughCOMP → RenderTOP`. Never bypass it with a direct GeoComp → RenderTOP connection while leaving the pass-through as a dead end — the cook engine won't cook dead-end nodes, making them appear broken.
- **WindowOUT parameters (mandatory):** `resolution: {"_type":"Vector2i","x":512,"y":512}`, `open: {"value": true}`.
- **Purpose:** When users open a help patch, the result is immediately visible in a real OS window — no manual viewer setup needed.
- **Applies retroactively:** All 1,084 existing help patches follow this rule.

### 25.23 File Encoding — UTF-8 Without BOM, No PowerShell String Manipulation

- **All text files** (`.md`, `.gd`, `.cfg`, `.tscn`, `.gnpatch`) **must be UTF-8 without BOM**.
- **NEVER** use PowerShell `Get-Content` / `Set-Content` on files containing non-ASCII characters (em-dashes, arrows, accented letters, emoji). PowerShell defaults to the system ANSI codepage (Windows-1252), causing double-encoding corruption that compounds with each read/write cycle.
- **If you must use PowerShell**, always pass `-Encoding UTF8` on **both** `Get-Content` and `Set-Content`.
- **Prefer Python** for any text manipulation involving non-ASCII: `open(fp, 'r', encoding='utf-8')` is reliable.
- **Corruption signature:** `Ã¢â‚¬â€` instead of `—`, `Ã¶` instead of `ö`, `Ã©` instead of `é`. If you see these, STOP — the file has been re-encoded through Win-1252 and needs byte-level repair (see `scripts/fix_encoding.py`).

---

## 26. Known Bugs

### 26.1 SoftBodyCOMP: Jolt SoftBody3D Incompatible with SubViewport — Replaced with CPU Verlet

- **Issue:** SoftBody3D cloth mesh rendered at the correct position but did not simulate (no draping under gravity). Jolt's `set_transform` error: `Condition "!in_space()" is true` at `jolt_soft_body_3d.cpp:564`.
- **Root cause (confirmed via diagnostics):** Jolt's internal C++ `in_space()` flag returns `false` even when `PhysicsServer3D.soft_body_get_space()` returns the correct space RID. This only occurs with SubViewport + custom World3D — the standard Jolt viewport path works. GDScript diagnostics confirmed: `in_tree=true`, valid `physics_rid`, matching space RIDs, mesh assigned, `phys_process_internal=true` — but Jolt's C++ side disagrees. **Unfixable from GDScript.**
- **Fix applied:** Complete rewrite of `soft_body_comp.gd` to use CPU-side Verlet position-based dynamics, bypassing Jolt/SoftBody3D entirely:
  1. Extracts vertex positions, indices, UVs, normals from upstream GeometryCOMP mesh.
  2. Transforms vertices to world space using the operator's transform.
  3. Builds unique edge constraints from the triangle index buffer.
  4. Computes vertex pinning based on bounding-box relative position (pin modes: None, Top Edge, Top Corners, All Edges).
  5. Per-frame `_cook()`: Verlet integration (pos + velocity * damping + gravity * dt²), iterative distance constraint solving, floor plane collision, mesh rebuild with normal recomputation.
  6. Uses `MeshInstance3D` (not SoftBody3D) — no physics engine dependency.
  7. `time_dependent = true` ensures per-frame cooking.
- **Parameters:** `iterations` (constraint solver passes), `gravity`, `damping`, `stiffness`, `floor_collision`/`floor_y`, `pin_mode`/`pin_threshold`.
- **Also cleaned up:** RenderTOP's `_recursive_register_bodies` no longer force-enables `set_physics_process_internal` on SoftBody3D (legacy Jolt workaround removed).
- **Test patches:** `soft_body_cloth.gnpatch` (20×20 cloth draping onto floor with camera/light), `soft_body_basic.gnpatch` (minimal grid → cloth example).

---

### 26.2 WindowOUT: ESC to Exit Fullscreen Not Working — FIXED

- **Issue:** When the output window is in Fullscreen or Borderless mode with Always On Top enabled, the user cannot escape back to windowed mode
- **Root cause:** Input events in a child `Window` node stay in that window's viewport tree. `Input.is_action_just_pressed()` polled from the parent node's `_process()` never sees them.
- **Fix applied:** Connected `Window.window_input` signal to `_on_window_input()` handler that listens for `KEY_ESCAPE`. On ESC press while in Fullscreen or Borderless mode, sets `window_mode` parameter back to Windowed and marks window params dirty. The inspector reflects the change immediately via `set_param_value()`.

---

## 27. Code-Based / Scriptable Operators — Architecture

This section documents the scripting operator system: operators where the user writes executable GDScript code that runs every cook. These are the GONODES equivalents of TouchDesigner's Script CHOP, Script SOP, Script DAT, and GLSL TOP.

### 27.1 Design Philosophy

1. **Sandboxed execution** — User code runs inside a dynamically-compiled `RefCounted` subclass. The framework injects context variables; the user's code sees only what's exposed.
2. **Stable API contract** — Each Script operator defines a fixed output type (per family) but dynamic input ports and parameters via comment annotations. User code plugs into `cook()` and optionally `setup()`.
3. **Graceful failure** — GDScript compilation errors are caught. Runtime errors print to console but don't crash the network. The operator falls back to its last-good cached output.
4. **Hot-reload** — Code changes trigger recompilation + `setup()` re-run without restarting the cook engine. The compiled instance is reused across frames (state persists).
5. **Per-family, not generic** — Each Script operator belongs to its family (ScriptCHOP extends GNChopBase, etc.), inheriting family colors, preview, output helpers. A generic multi-output ScriptNode is on the roadmap.

### 27.2 Implemented: CustomShaderTOP (GLSL TOP)

**Status: ✅ Done**

GPU-side shader operator. The user provides a full `shader_type canvas_item;` shader. Dynamic texture input ports from `uniform sampler2D gn_tex<N>` declarations. Dynamic inspector parameters from non-reserved uniform declarations. Recompiles on code change. Default template included.

See CustomShaderTOP source for full implementation details (uniform parsing, dynamic port/param rebuild, generator vs. filter mode).

### 27.3 Implemented: Script Operators (GDScript)

**Status: ✅ Done — ScriptCHOP, ScriptDAT, ScriptSOP, ScriptIMG**

All four share `GNScriptHelper` for compilation, annotation parsing, and execution.

#### 27.3.1 Operator Table

| Operator | Extends | Output Type | `node_type` | `op` object |
|----------|---------|-------------|-------------|-------------|
| ScriptCHOP | GNChopBase | GNChannelData | `"scriptchop"` | GNChannelData (`add_channel`, `set_single_value`, etc.) |
| ScriptDAT | GNDatBase | GNTableData | `"scriptdat"` | GNTableData (`set_headers`, `append_row`, `set_text`, etc.) |
| ScriptSOP | GNSopBase | GNGeoData | `"scriptsop"` | GNGeoData (`set_from_surface_tool`, `set_surface_arrays`, etc.) |
| ScriptIMG | GNImgBase | GNImageData | `"scriptimg"` | GNImageData (`set_image(img)`, `image`, `resolution`, etc.) |

#### 27.3.2 Execution Engine — Runtime GDScript Compilation

```gdscript
# How it works internally:
var script = GDScript.new()
script.source_code = PREAMBLE + user_code  # Preamble injects context vars + helpers
script.reload()                             # Compiles — error code if fails
var instance = script.new()                 # Create RefCounted instance
# Instance is reused across frames — state persists
```

**Lifecycle:**
1. Recompile only when code text changes (tracked via `_last_compiled_code`)
2. Reuse the instance across frames — user-defined `var` declarations persist
3. Inject fresh context (`me`, `inputs`, `op`, `time`, `frame`, `dt`, `_engine`) before each `cook()` call
4. Call `setup()` once after successful compilation (if method exists)
5. Call `cook()` every frame (when node is dirty + active)

#### 27.3.3 User Code API

The user writes code that looks like this:

```gdscript
# @input chop  Upstream channels
# @input dat   Config table
# @param float speed 1.0 Animation speed
# @param int count 4 Number of output channels

func setup():
    # Runs once after compilation. Can initialize persistent state.
    print("Initialized for ", me.id)

func cook():
    # Runs every frame when dirty. Must populate `op` with output data.
    var src = inputs[0]  # GNChannelData from first input
    for i in range(par("count")):
        op.set_single_value("chan%d" % i, sin(time * par("speed") + i))
```

**Injected context variables:**

| Variable | Type | Description |
|----------|------|-------------|
| `me` | GNNode | This node instance |
| `inputs` | Array[GNData] | Upstream data, ordered by input port index |
| `op` | family-specific | Pre-prepared output object (see operator table) |
| `time` | float | Elapsed seconds since start |
| `frame` | int | Current frame number |
| `dt` | float | Delta time this frame |
| `_engine` | Node | CookEngine reference (for advanced use) |

**Injected helper functions:**

| Function | Returns | Description |
|----------|---------|-------------|
| `par(name)` | Variant | Shorthand for `me.get_param_value(name)` |
| `chop(id, chan, index)` | Variant | Cross-reference CHOP channel value |
| `op_ref(id, param_name)` | Variant | Cross-reference any node's parameter |
| `top(id, property)` | Variant | Cross-reference TOP info |
| `sop(id)` | Variant | Cross-reference SOP data |
| `dat(id, row, col)` | Variant | Cross-reference DAT cell |

Note: `op_ref()` is used instead of `op()` because `op` is already the output object variable name.

> **⚠ Data Aliasing Warning for Script Operators:** Input data (`inputs[N]`) is passed by reference from upstream nodes' `cached_output`. If this node sits at a fan-out point (the upstream output feeds other nodes too), mutating the input data in-place will **corrupt** all other consumers. Built-in operators use `_mutable_input()` to handle this automatically, but Script operators do **not** auto-copy for performance reasons. If your Script code modifies input data (e.g., `inputs[0].image.resize()`), **duplicate first**:
> ```gdscript
> var img = inputs[0].image.duplicate()
> img.resize(512, 512)  # safe — your own copy
> op.set_image(img)
> ```
> This only matters at fan-out. If the upstream node feeds only this Script, mutation is safe.

#### 27.3.4 Annotation System — @param

Dynamic inspector parameters are declared via `# @param` comment annotations:

```
# @param <type> <name> <default> <description...>
```

| Type | GNParameter.ValueType | Default format | Example |
|------|----------------------|----------------|---------|
| `float` | FLOAT | `1.0` | `# @param float speed 1.0 Animation speed` |
| `int` | INT | `42` | `# @param int count 4 Channels` |
| `bool` | BOOL | `true`/`false` | `# @param bool loop true Enable loop` |
| `color` | COLOR | `#rrggbb` | `# @param color tint #ff0000 Tint` |
| `vec2` | VECTOR2 | `x,y` | `# @param vec2 offset 0.0,0.0 Position` |
| `vec2i` | VECTOR2I | `x,y` | `# @param vec2i size 256,256 Size` |
| `string` | STRING | `"text"` | `# @param string label "hello" Label` |
| `file` | FILE | (ignored) | `# @param file texture *.png Path` |

**Rebuild cycle:** Identical to CustomShaderTOP — regex parses annotations, diffs old vs. new, preserves values for same name+type, disconnects/reconnects signals, emits `parameters_changed`.

#### 27.3.5 Annotation System — @input

Dynamic input ports with per-port family type:

```
# @input <family> <description...>
```

| Family | Port Type | Expected GNData |
|--------|-----------|-----------------|
| `top` | GNFamily.Type.TOP | GNTextureData |
| `img` | GNFamily.Type.IMG | GNImageData |
| `chop` | GNFamily.Type.CHOP | GNChannelData |
| `dat` | GNFamily.Type.DAT | GNTableData |
| `sop` | GNFamily.Type.SOP | GNGeoData |
| `comp` | GNFamily.Type.COMP | GNCompData |
| `mat` | GNFamily.Type.MAT | GNMaterialData |

Ports are rebuilt when annotations change, same `ports_changed.emit()` pattern. No `@input` annotations = no input ports (generator mode).

**Cross-family inputs:** A ScriptIMG can accept IMG + CHOP + DAT inputs simultaneously:
```gdscript
# @input img   Background image
# @input chop  Animation data
# @input dat   Label table

func cook():
    var bg = inputs[0]    # GNImageData
    var anim = inputs[1]  # GNChannelData
    var labels = inputs[2] # GNTableData
```

#### 27.3.6 Static Parameters

All Script operators share two static (non-annotation) parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `time_dependent` | bool | `false` | Re-cook every frame. Default off — scripts only cook when dirty. |
| `code` | string | Default template | The user's GDScript code |

`time_dependent` is respected via `_pre_cook()` override (same pattern as CustomShaderTOP).

#### 27.3.7 ScriptIMG — CPU Image Output

ScriptIMG extends GNImgBase (not GNTopBase) — pure CPU Image pipeline:
- **No SubViewport** — output is `GNImageData` wrapping a CPU `Image`
- **`op` is GNImageData** — the user calls `op.set_image(img)` to publish output
- **No `execute_cook()` override needed** — GNImgBase uses GNNode's default (no viewport logic)
- **Use ImgToTOP** to convert to GPU texture for the TOP pipeline
- **Complementary to CustomShaderTOP** — use ScriptIMG for CPU logic, CustomShaderTOP for GPU shaders

### 27.4 IMG Family — CPU Image Operators

**Status: ✅ Done**

The IMG family provides CPU-side image processing as a first-class citizen, cleanly separated from the GPU-based TOP pipeline.

#### CPU-First Input Philosophy

**Principle:** When source data originates on the CPU (files on disk, camera feeds, procedural generation), the operator should live in the **IMG family** and output `GNImageData`. The user explicitly bridges to GPU via `→ ImgToTOP` only when needed. This gives maximum flexibility — CPU processing (ScriptIMG, BlurIMG, OpenCV via GDExtension, etc.) can happen *before* any GPU upload, and users who never need GPU textures avoid the upload entirely.

**Rationale for the split:**

| Source | Family | Why |
|--------|--------|-----|
| Image files (PNG, JPG, EXR, etc.) | **IMG** (ImageFileInIMG) | `ResourceLoader` returns CPU `Image` — data is natively CPU-side. |
| Numbered image sequences | **IMG** (ImageSequenceIMG) | Same — loads frames from disk as CPU Images. |
| Webcam / camera feed | **IMG** (WebcamIMG) | CameraFeed frame data is CPU-accessible. |
| Video playback (.ogv Theora) | **TOP** (MovieFileInTOP) | Godot's `VideoStreamPlayer` only exposes decoded frames as GPU textures via `get_video_texture()` — no CPU-side Image API exists. |
| FFmpeg video (H.264, VP9, etc.) | **TOP** (FFmpegInTOP) | Same — EIRTeam.FFmpeg GDExtension decodes to GPU texture internally. |

**Exceptions exist** — some future sources may bypass CPU entirely and deliver directly to GPU:
- **HAP codec** (S3TC/DXT compressed video) — frames are already in GPU-native compressed format. A HAP operator would be a **TOP**, uploading S3TC blocks directly to GPU texture without CPU pixel decoding. CPU detour would be counterproductive.
- **Spout / NDI / Syphon** texture sharing — shared GPU textures arrive on the GPU. These will be TOPs.
- Any future GPU-direct capture or decode path where CPU-side data simply doesn't exist.

#### 27.4.1 Architecture

| Component | Description |
|-----------|-------------|
| `GNFamily.Type.IMG` | New enum value. Teal color `(0.3, 0.7, 0.7)` in graph editor. |
| `GNImageData` | Data class wrapping `Image`. `set_image()`, `resolution`, `format`. Deep-copies on `duplicate_data()`. |
| `GNImgBase` | Family base class. No SubViewport. `_prepare_image()` helper. Lightweight text Label preview showing resolution + format (no GPU upload). |
| `@input img` | Annotation support in Script operators. Maps to `GNFamily.Type.IMG`. |

#### 27.4.2 Operators

| Operator | Type | Description |
|----------|------|-------------|
| NoiseIMG | Generator | Value noise (FastNoiseLite) or white noise. Mono/RGB, octaves, persistence, seed. |
| CheckerboardIMG | Generator | 2-color grid. Configurable cells, optional softness (anti-aliased edges). |
| BlurIMG | Filter | Separable box blur with sliding-window accumulator. Multi-pass for Gaussian approximation. |
| EdgeDetectIMG | Filter | Sobel or Prewitt 3×3 kernels. Grayscale or color-encoded gradient direction. |
| PixelSortIMG | Filter | Glitch art pixel sorting. Sort by brightness/hue/saturation/channel. Threshold-controlled spans. |
| ScriptIMG | Scripting | User GDScript with `@param`/`@input` annotations. Full GNScriptHelper integration. |
| ImgToTOP | Bridge | Uploads CPU Image to GPU ImageTexture → GNTextureData output. Overrides `execute_cook()` to skip SubViewport logic. |
| TOPtoIMG | Bridge | GPU Texture → CPU Image via `get_image()`. Reverse of ImgToTOP. |
| ImageSaveOUT | Sink | Saves CPU Image to disk (PNG/WebP/EXR). `active` toggle, auto-numbering, quality param. `is_sink = true`. |
| MovieOUT | Sink | Numbered image sequence output (PNG/WebP). Configurable prefix, padding, folder. `is_sink = true`. |
| FFmpegOUT | Sink | Records frames to temp dir, encodes via `ffmpeg` CLI (H.264/H.265/VP9/ProRes) on deactivation. `is_sink = true`. |

### 27.5 GNScriptHelper — Shared Infrastructure

`GNScriptHelper` (extends RefCounted) is instantiated per Script operator. It manages:

| Responsibility | Method |
|----------------|--------|
| Compilation | `compile(code)` — wraps user code in preamble, `GDScript.new().reload()`, creates instance |
| Annotation parsing | `parse_param_annotations(code)`, `parse_input_annotations(code)` — regex-based line scanning |
| Dynamic param rebuild | `rebuild_dynamic_params(node, code)` — diff + preserve + reconnect signals |
| Dynamic port rebuild | `rebuild_input_ports(node, code)` — diff + emit `ports_changed` |
| Full code change | `on_code_changed(node, code)` — ports → params → compile (in order) |
| Context injection + execution | `run_cook(node, inputs, output, engine)` — injects context, calls `setup()` once, calls `cook()` |
| Preset management | Static `get_preset_list()`, `load_preset()`, `save_preset()` |
| Save/load support | Static `restore_dynamic_param_values()` |

**Preamble injection:** The preamble extends `RefCounted` and declares `var me`, `var inputs`, `var op`, `var time`, `var frame`, `var dt`, `var _engine`, plus helper functions (`par()`, `chop()`, `op_ref()`, `top()`, `sop()`, `dat()`). The user's code is appended after the preamble.

### 27.6 Presets — Factory & User

**Storage layout:**
```
res://addons/gonodes/presets/          # Factory (read-only, ships with addon)
    scriptchop/
        sine_waves.gd
        smooth_channels.gd
        beat_clock.gd
    scriptdat/
        chop_to_table.gd
        empty_table.gd
    scriptsop/
        scatter_points.gd
        wave_deform.gd
    scriptimg/
        gradient.gd
        cpu_threshold.gd

user://gonodes_presets/                 # User (read-write, created on first save)
    scriptchop/
        my_custom_lfo.gd
    ...
```

Each preset file is raw user code (annotations + `cook()` + `setup()` + helpers). Pure text, no wrapper.

**UI — Option A (current):** Load/Save buttons in the inspector. Load opens a file dialog scoped to preset directories. Save prompts for a name.

**Roadmap — Option B:** Preset dropdown parameter in inspector, populated by scanning preset directories.

### 27.7 Save/Load

Each Script operator overrides `from_dict()` following the CustomShaderTOP pattern:
1. `super.from_dict(d)` — restores static params (`code`, `time_dependent`, position, etc.)
2. `_helper.on_code_changed(self, code)` — recompiles, creates dynamic params + ports
3. `GNScriptHelper.restore_dynamic_param_values()` — restores dynamic param values from saved dict, skipping static param names

### 27.8 Adding a New Script Family

To add a Script operator for a new family (e.g., ScriptMAT):
1. Create `script_mat.gd` extending `GNMatBase`
2. Instantiate `GNScriptHelper` as `_helper`
3. Set `node_type`, define static params (`time_dependent`, `code`)
4. In `_cook()`: prepare output via family helper, call `_helper.run_cook()`
5. Override `from_dict()` with the 3-step pattern above
6. Create default code template with `@input`/`@param` annotations
7. Register in `GNExtensionRegistry._register_core_operators()`
8. Add factory presets to `res://addons/gonodes/presets/scriptmat/`

### 27.9 ComputeShaderTOP (GPU Compute)

**Status: ✅ Done**

Uses Godot's `RenderingDevice` compute shader API for massively parallel GPU operations. User writes a GLSL 450 compute shader that writes to an `image2D gn_output` storage texture.

**Binding layout:**
- set 0, binding 0 — `image2D gn_output` (rgba8 storage, write)
- set 1, binding N — `sampler2D gn_tex<N>` (input textures, read)
- push_constant — `PushConstants` struct with auto-bound `gn_time`, `gn_frame`, `gn_res_x`, `gn_res_y`; additional `float`/`int` fields become inspector parameters automatically

**Features:**
- Live GLSL recompile on code change (SPIR-V compilation via local RenderingDevice)
- Dynamic input ports from `sampler2D gn_tex<N>` declarations (up to 8)
- Dynamic inspector parameters from push constant user fields (float/int)
- Workgroup size parsed from `layout(local_size_x = ...)` qualifier
- GPU→CPU readback via `ImageTexture` for TOP pipeline compatibility
- Resolution parameter (generator mode) or inherited from input (filter mode)

**File:** `addons/gonodes/operators/top/compute_shader_top.gd`
**Help:** `addons/gonodes/help/top/compute_plasma.gnpatch`

### 27.10 Generic ScriptNode (Multi-Output)

**Status: ✅ Done**

A family-less node with annotated output ports (`# @output chop`, `# @output top`). Extends `GNNode` directly with `family = GNFamily.Type.COMP` for gray/neutral color. Multi-output via `outputs[]` array — each `# @output` annotation creates a typed output port with a pre-prepared `GNData` subclass. The per-family Script operators remain the 90% use case; GenericScriptNode is for advanced multi-output pipelines.

**File:** `addons/gonodes/operators/comp/generic_script_node.gd`

### 27.10a CallbackDAT (Event-Driven Scripting)

**Status: ✅ Done**

An event-driven DAT that observes an upstream node and runs user scripts on events (`on_start`, `on_cook`, `on_value_change`, `on_create`). Connects to target node's `node_cooked` and `parameter_changed` signals. Events are queued in `_pending_events` and processed during cook to avoid re-entrancy. Output is a rolling event log table (max 50 rows). Each callback gets its own `GNScriptHelper` instance.

**File:** `addons/gonodes/operators/dat/callback_dat.gd`

### 27.10b Writable References — set_par()

**Status: ✅ Done**

Scripts can now modify parameters on any reachable node:
- 2-arg: `set_par("param_name", value)` — sets param on the calling node
- 3-arg: `set_par("node_id", "param_name", value)` — sets param on another node

Target node is automatically marked dirty. Works in all Script operators via preamble injection.

**File:** `addons/gonodes/core/gn_cook_engine.gd` (method) + `gn_script_helper.gd` (preamble)

### 27.10c Network API — Procedural Graph Construction

**Status: ✅ Done**

Six functions available in all Script operators for runtime graph manipulation:
- `network_add_node(operator_type, node_id)` → creates node via GNExtensionRegistry
- `network_remove_node(node_id)` → removes node and its connections
- `network_connect(from_id, from_port, to_id, to_port)` → wires two nodes
- `network_disconnect(from_id, from_port, to_id, to_port)` → removes a wire
- `network_node_ids()` → returns all node IDs in the network
- `network_node_info(node_id)` → returns type/family/valid/position dict

**File:** `addons/gonodes/core/gn_cook_engine.gd` (methods) + `gn_script_helper.gd` (preamble)

### 27.11 Implementation Priorities

| Priority | Operator | Status |
|----------|----------|--------|
| ✅ Done | CustomShaderTOP | GPU shaders with dynamic uniforms |
| ✅ Done | ScriptCHOP | GDScript channel generation/processing |
| ✅ Done | ScriptDAT | GDScript table/text generation/processing |
| ✅ Done | ScriptSOP | GDScript geometry generation/processing |
| ✅ Done | ScriptIMG | CPU-side Image manipulation via GDScript |
| ✅ Done | IMG family | NoiseIMG, CheckerboardIMG, BlurIMG, EdgeDetectIMG, PixelSortIMG, ImgToTOP, TOPtoIMG, ImageSaveOUT, MovieOUT, FFmpegOUT |
| ✅ Done | Output operators | TextureSaveOUT, TableSaveOUT, RecordOUT — file save sinks with `active` toggle |
| ✅ Done | WebcamIMG | Live camera feed as CPU Image via CameraServer |
| ✅ Done | Cook-once pulse | `cook_once` param on Script ops + CustomShaderTOP — auto-reset after one cook |
| ✅ Done | Generic ScriptNode | Multi-output, family-less COMP |
| ✅ Done | CallbackDAT | Event-driven scripting callbacks |
| ✅ Done | set_par() | Writable parameter references |
| ✅ Done | Network API | Procedural graph construction (6 functions) |
| ✅ Done    | ComputeShaderTOP | GPU compute via RenderingDevice |

---

## 28. Extension Architecture (GNExtensionRegistry)

### 28.1 Overview

GONODES uses a dynamic operator registry (`GNExtensionRegistry`) to manage all operators — both built-in core operators and third-party extension-provided operators. This replaces the previous approach of hardcoded match-block factories and static description dictionaries, enabling a plugin-friendly architecture where GDExtension addons can register new operators without modifying core code.

### 28.2 Registry Singleton

`GNExtensionRegistry` is a `RefCounted`-based lazy singleton accessed via `GNExtensionRegistry.instance()`. It is initialized on first access, at which point all 93 core operators are registered via `_register_core_operators()`. Extension scanning happens explicitly via `scan_extensions()`, called during editor startup (`gn_editor.gd._ready()`).

### 28.3 OperatorEntry

Each registered operator is stored as an `OperatorEntry` with:
- `family: String` — TOP, CHOP, SOP, DAT, MAT, COMP, POP
- `script: GDScript` — the preloaded GDScript class (supports `.new()`)
- `description: String` — one-line tooltip for the palette
- `source: String` — "core" or the extension name that provided it

### 28.4 API Surface

| Method | Returns | Purpose |
|--------|---------|---------|
| `register_operator(name, family, script, desc, source)` | void | Register an operator |
| `unregister_operator(name)` | void | Remove an operator |
| `create_instance(name)` | GNNode | Data-driven factory (replaces match block) |
| `get_operator_registry()` | Dictionary | `{ "TOP": [...], "CHOP": [...] }` — palette data |
| `get_description(name)` | String | Tooltip text |
| `has_operator(name)` | bool | Existence check |
| `get_operator_count()` | int | Total registered operators |
| `get_all_operator_names()` | PackedStringArray | All registered names |
| `get_loaded_extensions()` | PackedStringArray | Loaded extension folder names |
| `get_operators_accepting_family(family)` | Array[String] | Operators with an input port matching `family` |
| `get_operators_producing_family(family)` | Array[String] | Operators with an output port matching `family` |
| `scan_extensions()` | void | Discover and load `gn_ext_*` addons |

**Input-family cache:** `get_operators_accepting_family()` and `get_operators_producing_family()` are backed by a lazy `_input_family_cache` dictionary built on first call. The cache instantiates every registered operator (`.new()` + `_init_ports()` only — not full `initialize()`) to inspect their port arrays, then frees them. Cache is invalidated on `register_operator()` / `unregister_operator()`. Used by the drop-wire-to-add-node feature to filter the palette to compatible operators.

### 28.5 Extension Convention

Extensions live under `res://addons/gn_ext_<name>/` and contain a `gn_extension.cfg` manifest (ConfigFile format):

```ini
[extension]
name="FFmpeg Video Support"
version="1.0.0"
author="GONODES"
description="FFmpeg-powered video decoding. Adds FFmpegInTOP with H.264, H.265, VP9, AV1 and broad format support."
dependencies=["FFmpegVideoStream"]

[operator.FFmpegInTOP]
family="TOP"
script="res://addons/gn_ext_ffmpeg/operators/top/ffmpeg_in_top.gd"
description="FFmpeg video decoder. H.264, H.265, VP9, AV1 and more."
```

Optional keys in the `[extension]` section:

| Key | Type | Purpose | Example |
|-----|------|---------|---------|
| `platforms` | Array of strings | Restrict to specific OSes. Values: `"windows"`, `"macos"`, `"linux"`, `"android"`, `"ios"`, `"web"` (from `OS.get_name().to_lower()`). Omit = loads everywhere. | `platforms=["windows"]` |
| `architectures` | Array of strings | Restrict to specific CPU architectures. Values: `"x86_64"`, `"x86_32"`, `"arm64"`, `"arm32"`, etc. (from `Engine.get_architecture_name()`). Omit = loads on all architectures. | `architectures=["x86_64"]` |
| `dependencies` | Array of strings | GDExtension class names required at load time (checked via `ClassDB.class_exists()`). | `dependencies=["FFmpegVideoStream"]` |
| `section` | String | Palette section label — groups operators under this heading. | `section="Video"` |

Platform and architecture guards are checked sequentially before dependency checks. If either fails, the extension is silently skipped (logged at debug level) and marked as loaded to prevent re-scan.

### 28.6 Platform & Architecture Guards

The registry runs three sequential checks before loading an extension's operators:

1. **Platform check** — if `platforms` is declared and the current OS (`OS.get_name().to_lower()`) is not in the list, skip.
2. **Architecture check** — if `architectures` is declared and the current CPU arch (`Engine.get_architecture_name()`) is not in the list, skip.
3. **Dependency check** — `ClassDB.class_exists()` for each class in `dependencies`. If any missing, skip.

All three are optional. Omitting a key means "no restriction" for that axis. This allows fine-grained control:
- Spout: `platforms=["windows"]`, `architectures=["x86_64"]` — Windows x86_64 only.
- Syphon: `platforms=["macos"]` — any macOS architecture (universal dylib covers both x86_64 and arm64).
- GPU Encode: `platforms=["windows", "macos"]` — no architecture restriction (macOS universal, Windows x86_64 native lib handled by `.gdextension`).

If any guard fails, the extension is skipped with a warning and marked as loaded to prevent repeated scan attempts.

### 28.7 Loading Flow

1. **Editor startup** → `gn_editor.gd._ready()` calls `GNExtensionRegistry.instance().scan_extensions()`
2. **First access** → `instance()` creates the singleton and runs `_register_core_operators()` (82 core operators)
3. **scan_extensions()** → iterates `res://addons/gn_ext_*/gn_extension.cfg`, checks platform/architecture/dependencies, loads operator scripts
4. **Palette/Factory** → `GNGraphEditor.get_operator_registry()` and `_create_operator_instance()` delegate to the registry
5. **Palette tooltips** → `GNNodePalette._get_operator_description()` delegates to registry

### 28.8 Future Extensions (Roadmap)

| Extension | Folder | Dependencies | Operators | Platform / Arch Guard | Status |
|-----------|--------|-------------|-----------|----------------------|--------|
| FFmpeg | `gn_ext_ffmpeg` | `FFmpegVideoStream` | FFmpegInTOP | — (dep guard) | ✅ Done |
| Shadertoy | `gn_ext_shadertoy` | — | ShadertoyTOP (10 factory GLSL presets) | — (pure GDScript) | ✅ Done |
| Native Accel | `gn_ext_native` | 92 C++ processor classes | 92 native operators (42 SOP, 23 CHOP, 5 IMG, 4 TOP, 9 VOL, 9 POP) | — (dep guard + runtime fallback) | ✅ Built & active (Windows x86_64); Linux/macOS pending |
| ISF | `gn_ext_isf` | — | ISFTOP + 10 factory presets | — (pure GDScript) | ✅ Done |
| Spout | `gn_ext_spout` | Spout2 SDK (BSD, compiled inline) | SpoutInTOP, SpoutOutTOP | `platforms=["windows"]`, `architectures=["x86_64"]` | ✅ Built (Windows x86_64) |
| Syphon | `gn_ext_syphon` | Syphon Framework (BSD) | SyphonInTOP, SyphonOutTOP | `platforms=["macos"]` | ✅ Code complete (macOS — needs macOS build) |
| Video Capture | `gn_ext_video_capture` | OS APIs (MF/AVFoundation/V4L2) | VideoDeviceInIMG | — (runtime check) | ✅ Built (Windows x86_64); macOS/Linux pending |
| MIDI | `gn_ext_midi` | RtMidi (MIT, compiled inline) | RtMidiInCHOP, RtMidiOutCHOP | — (runtime check) | ✅ Built (Windows x86_64); macOS/Linux pending |
| GPU Encode | `gn_ext_gpu_encode` | OS APIs (MF/VideoToolbox) | MovieFileOutTOP | `platforms=["windows", "macos"]` | ✅ Built (Windows x86_64); macOS pending |
| Mapper | `gn_ext_mapper` | — | 7 mapping TOPs | — (pure GDScript) | ✅ Done |
| Kinect | `gn_ext_kinect` | `KinectTracker` | KinectCHOP, KinectPointCloudSOP | Planned | Planned |
| NDI | `gn_ext_ndi` | `NDIFinder` | NDIInTOP, NDIOutTOP | Planned | Planned |

### 28.10 Extension Help Patches

**Status: ✅ Done**

GN extensions ship their own help example patches alongside their operator scripts.

**Convention:**

```
addons/gn_ext_<name>/
├── gn_extension.cfg
├── operators/
│   └── <family>/
│       └── <operator>.gd
└── help/                              # Extension help patches
    └── <family>/
        ├── <node_type>_basic.gnpatch
        └── <node_type>_advanced.gnpatch
```

Example for `gn_ext_shadertoy`:
```
addons/gn_ext_shadertoy/
├── gn_extension.cfg
├── operators/top/
│   ├── shadertoy_fire_top.gd
│   ├── shadertoy_plasma_top.gd
│   └── ...
└── help/
    └── top/
        ├── shadertoy_fire_basic.gnpatch
        ├── shadertoy_plasma_audio.gnpatch
        └── ...
```

**Implementation:**
- `OperatorEntry` in `GNExtensionRegistry` now stores `extension_dir` (base dir of the extension, e.g. `res://addons/gn_ext_shadertoy/`).
- `GNExtensionRegistry.get_entry_by_script(script)` — linear scan lookup by GDScript reference (handles operators without `class_name`).
- `GNHelpWindow._find_example_patches()` scans both core help dir AND `<extension_dir>/help/` for the operator's family.
- Shared `_scan_dir_for_patches()` helper deduplicates scanning logic.
- Extension patches appear alongside core patches in the help window — no distinction needed in UI.

**Files:** `gn_extension_registry.gd` (OperatorEntry.extension_dir, get_entry_by_script), `gn_help_window.gd` (_find_example_patches, _scan_dir_for_patches)

---

### 28.9 Audio Recording & Muxing (Roadmap)

**Status: IMPLEMENTED -- 10 POP operators + 7 GLSL compute shaders live**

TD's Movie File Out TOP can record an audio track alongside video by wiring a
time-sliced CHOP into its audio input.  GONODES needs an equivalent pipeline.

**Design sketch:**

1. **AudioOutCHOP** (new operator) — routes a CHOP's sample buffer to Godot's
   AudioServer as an `AudioStreamGenerator`.  Enables live monitoring and provides
   the raw PCM data for recording.

2. **Audio track on FFmpegOUT** — when an AudioOutCHOP/CHOP is wired to a
   secondary input, the recorder writes PCM samples alongside the temp PNG frames.
   On finalization, FFmpeg muxes the audio track (WAV/PCM) into the output
   container (MP4/MKV/WebM) with `-i audio.wav -c:a aac` (or `-c:a libopus` for
   WebM).

3. **Time-sliced CHOP accumulation** — in NRT mode, each cook frame appends
   `length` samples from the audio CHOP to a growing `PackedFloat32Array` buffer.
   The sample rate comes from `GNChannelData.sample_rate` (e.g., 44100 Hz).
   Frames produce `sample_rate / non_realtime_fps` samples each (e.g., 1470
   samples per frame at 44100 Hz / 30 fps).

4. **WAV export helper** — `_write_wav(path, samples, sample_rate, channels)`
   utility writes a standard 16-bit PCM WAV file for FFmpeg to consume.

**Dependencies:** Godot's `AudioStreamGenerator` + `AudioStreamGeneratorPlayback`
for live output; FFmpeg CLI for muxing (already used by FFmpegOUT).

**Interaction with NRT mode:** Audio recording is most useful in Non-Realtime
mode where every frame is guaranteed to produce the correct number of audio
samples.  In real-time mode, dropped frames could cause audio gaps — a warning
badge should indicate when frames are dropped during audio recording.

- `GNParamRow` creates a `CodeEdit` instead of `LineEdit` for CODE-type params
- `CodeEdit` supports syntax highlighting for `.gdshader` and `.gd` automatically
- Apply-on-blur or explicit "Compile" button to avoid recompiling on every keystroke

## 29. Main Help Window (GNMainHelpWindow)

### Purpose
An organized in-editor reference hub that provides centralized access to all GONODES documentation. Opened via the **📖 Help** toolbar button or **F1** key. Singleton window — created on first use, toggled visible/hidden thereafter.

### Architecture
- **GNMainHelpWindow** (`addons/gonodes/ui/gn_main_help_window.gd`) — extends `Window`. HSplitContainer layout: sidebar Tree (left, 240px) + ScrollContainer>RichTextLabel (right). Dark background matching per-node help windows (Color 0.10, 0.10, 0.12).
- **GNMarkdownRenderer** (`addons/gonodes/ui/gn_markdown_renderer.gd`) — static utility class (`extends RefCounted`) that converts Markdown to BBCode for RichTextLabel display. Handles `#/##/###` headers, `**bold**`, `*italic*`, `` `inline code` ``, triple-backtick code blocks, `| tables |`, `- bullet lists`, `1. ordered lists`, `> blockquotes`, `---` horizontal rules, and `[link](url)` links.

### Sidebar Sections
1. **📖 Getting Started** — `help/getting_started.md` — overview, families, first-patch walkthrough
2. **?? Editor Guide** — `help/editor.md` — keyboard shortcuts, mouse, toolbar, inspector
3. **ðŸ“ Expressions & Scripting** — `help/expressions.md` — expression language, cross-node refs, set_par, Network API
4. **?? Operators Reference** — dynamic from `GNExtensionRegistry.get_operator_registry_sectioned()` — expandable tree: Family → Section → Operator. Clicking a family shows an overview listing; clicking an operator shows auto-generated docs (ports, params, description) + optional per-operator `.md` file from `help/<family>/<op_name>.md`
5. **⚙️ Cook Engine** — `help/cook_engine.md` — how cooking works, dirty propagation, active chains, NRT mode
6. **?? Player** — `help/player.md` — standalone runtime, config.json, hotkeys, window management, headless mode
7. **ðŸ—️ Building** — `help/building.md` — build scripts, Quick Build, export presets, GDExtension handling
8. **?? Extensions** — `help/extensions.md` — extension structure, manifest format, writing operators, dependency guards

### Features
- **Search bar** — filters sidebar tree items by text match (recursive, auto-expands matching parents)
- **Lazy loading** — markdown files loaded and rendered to BBCode only when a section is clicked; results cached in `_content_cache` dictionary
- **Operator auto-docs** — operators are instantiated temporarily to read their ports/params metadata (same technique as GNHelpWindow per-node help). Tables show port names/families/descriptions and parameter names/types/defaults/descriptions.
- **Fallback generators** — sections without .md files get inline BBCode content from generator functions
- **Keyboard shortcuts** — **Escape** to close, **Ctrl+F** to focus the search bar

### Editor Integration
- `gn_editor.gd` preloads `_GNMainHelpWindowScript` and stores `_main_help_window: GNMainHelpWindow`
- **Toolbar**: "📖 Help" button added to Row 2 of `_setup_toolbar()` (after Layout, before export dialog)
- **F1 key**: handled in `_unhandled_key_input()` — calls `_toggle_main_help_window()`
- **Toggle function**: `_toggle_main_help_window()` creates the window on first call, shows/hides on subsequent calls

### Help Content Files
| File | Section | Source |
|------|---------|--------|
| `help/getting_started.md` | Getting Started | New |
| `help/editor.md` | Editor Guide | Existing (renamed from ui_guide.md) |
| `help/expressions.md` | Expressions & Scripting | Existing (renamed from expressions_guide.md) |
| `help/cook_engine.md` | Cook Engine | New |
| `help/player.md` | Player | New (from dev_docs/PLAYER.md) |
| `help/building.md` | Building | New (from dev_docs/BUILD.md) |
| `help/extensions.md` | Extensions | New |

## 30. Session Changelog — 2026-03-04 / 2026-03-05

Comprehensive session covering code editor integration fixes, preset creation, help system improvements, and the Main Help Window feature.

### 30.1 Code Editor Integration Fixes

**Problem:** GenericScriptNode and CallbackDAT lacked "Edit ↗" code editor buttons in the inspector.

- **`gn_param_row.gd`** — `_is_code_editor_param()` only matched `node_type.begins_with("script")`. GenericScriptNode uses `node_type = "genericscript"` (doesn't start with "script"), and CallbackDAT's callback params (`on_start`, `on_cook`, `on_value_change`, `on_create`) weren't recognized.
  - Added `_is_script_node()` helper returning true for `begins_with("script")` OR `== "genericscript"`
  - Expanded `_is_code_editor_param()` to recognize genericscript's `"code"` param and callbackdat's callback params
- **`gn_code_editor.gd`** — `_get_preset_folder()` returned "" for genericscript/callbackdat/shader_code.
  - Added returns: `"genericscript"`, `"callbackdat"`, `"glsl"` for CustomShaderTOP's `shader_code` param
  - Added syntax highlighting keywords: `@output`, `outputs`, `target`, `event`, `event_param`, `set_par`, `network_*`

### 30.2 Preset Coverage (35 presets across 7 folders)

Created 22 new presets + verified 13 existing, bringing all 7 script/shader categories to 5+ presets each:

| Folder | New Presets | Total |
|--------|-------------|-------|
| `presets/scriptchop/` | additive_harmonics.gd, envelope_follower.gd | 5 |
| `presets/scriptdat/` | fibonacci_table.gd, json_parser.gd, random_table.gd, system_info.gd | 6 |
| `presets/scriptsop/` | fibonacci_sphere.gd, ring_mesh.gd, parametric_column.gd | 5 |
| `presets/scriptimg/` | fractal_noise.gd, concentric_rings.gd, color_correct.gd | 5 |
| `presets/genericscript/` | triple_output_oscillator.gd, signal_analyzer.gd, network_inspector.gd | 5 |
| `presets/callbackdat/` | on_create_init.gd, param_guard.gd, cook_profiler.gd | 5 |
| `presets/glsl/` (NEW) | plasma.gdshader, voronoi.gdshader, radial_warp.gdshader, kaleidoscope.gdshader, gradient_map.gdshader | 5 |

- **`gn_script_helper.gd`** — `_scan_preset_dir()` updated to accept `.gdshader` alongside `.gd`

### 30.3 Help Patch Naming Fix

4 help patches had broken names that didn't match the `<node_type>_<label>.gnpatch` convention:

| Old Name | New Name | Now shows on |
|----------|----------|--------------|
| `set_par_demo.gnpatch` | `scriptchop_set_par.gnpatch` | ScriptCHOP |
| `network_api_demo.gnpatch` | `scriptdat_network_api.gnpatch` | ScriptDAT |
| `generic_script_multi_output.gnpatch` | `genericscript_multi_output.gnpatch` | GenericScriptNode |
| `callback_dat_basic.gnpatch` | `callbackdat_basic.gnpatch` | CallbackDAT |

### 30.4 Main Help Window (GNMainHelpWindow)

Built a centralized in-editor reference hub — new feature accessible via toolbar "📖 Help" button or F1 key.

**New files created:**
- `addons/gonodes/ui/gn_main_help_window.gd` — Window with HSplitContainer: sidebar Tree (240px, searchable) + ScrollContainer>RichTextLabel content pane. Dark theme matching per-node help windows.
- `addons/gonodes/ui/gn_markdown_renderer.gd` — Static Markdown→BBCode converter. Handles `#/##/###` headers, `**bold**`, `*italic*`, `` `code` ``, triple-backtick code blocks, `| tables |`, `- bullet lists`, `1. ordered lists`, `> blockquotes`, `---` rules, `[links](url)`.

**New help content .md files:**
- `help/getting_started.md` — families overview, first-patch walkthrough, key concepts
- `help/cook_engine.md` — dirty propagation, active chains, topological sort, NRT mode, bypass/lock
- `help/extensions.md` — manifest format, writing operators, dependency guards, loaded extensions list

**Editor integration (`gn_editor.gd`):**
- Added `_GNMainHelpWindowScript` preload + `_main_help_window` variable
- "📖 Help" button in toolbar Row 2
- F1 key handler in `_unhandled_key_input()`
- `_toggle_main_help_window()` — singleton create-on-first-use, toggle visibility thereafter

**Sidebar sections:**
1. 📖 Getting Started → `help/getting_started.md`
2. ?? Editor Guide → `help/editor.md`
3. ðŸ“ Expressions & Scripting → `help/expressions.md`
4. ?? Operators Reference → dynamic per-family/per-operator tree from GNExtensionRegistry
5. ⚙️ Cook Engine → `help/cook_engine.md`
6. ?? Player → `help/player.md`
7. ðŸ—️ Building → `help/building.md`
8. ?? Extensions → `help/extensions.md`

### 30.5 Help File Reorganization

Renamed 5 guide `.md` files for consistency and placed at `help/` root (folders reserved for operator `.gnpatch` files):

| Before | After |
|--------|-------|
| `help/ui_guide.md` | `help/editor.md` |
| `help/expressions_guide.md` | `help/expressions.md` |
| `help/cook_engine_guide.md` | `help/cook_engine.md` |
| `help/extensions_guide.md` | `help/extensions.md` |
| `help/getting_started.md` | `help/getting_started.md` (unchanged) |

Updated all references in `gn_main_help_window.gd` (`_SECTION_FILES`), `GONODES_CONTEXT.md`, and internal cross-references in `editor.md`.

### Help directory structure (final)

```
addons/gonodes/help/
  getting_started.md         ← Guide .md files at root (7 files)
  editor.md
  expressions.md
  cook_engine.md
  player.md
  building.md
  extensions.md
  chop/                      ← CHOP .gnpatch example patches (64 files)
  top/                       ← TOP .gnpatch example patches (64 files)
  dat/                       ← DAT .gnpatch example patches (30 files)
  sop/                       ← SOP .gnpatch example patches (56 files)
  comp/                      ← COMP .gnpatch example patches (22 files)
  mat/                       ← MAT .gnpatch example patches (7 files)
```

---

## 31. Session Changelog — 2026-03-06

TouchDesigner parity deep audit + implementation of 15 gap operators (Tier 1 + Tier 2) + help patch overhaul.

### 31.1 TouchDesigner Parity Audit

Deep comparison of GONODES vs TouchDesigner operator inventory:
- GONODES covers ~80% of TD's surface area across all families
- Many apparent "gaps" were false — operators just have different names or are bundled into multi-mode operators
- Key equivalences documented: CompositeTOP→Under/Multiply/Screen (blend modes), ChannelMixTOP→Reorder (swizzle), LevelTOP→Threshold/Contrast/Gamma, BlurTOP→DirectionalBlur, ResampleCHOP→Speed, MergeCHOP→Join

### 31.2 Tier 1 Operators (5 high-impact)

| Operator | Family | Algorithm / Notes |
|----------|--------|-------------------|
| FuseSOP | SOP | Spatial hash grid O(N) merge of coincident vertices within distance threshold |
| RaySOP | SOP | Möller-Trumbore CPU raycast projecting source vertices onto target surface |
| BeatCHOP | CHOP | RMS energy-based onset detection with adaptive threshold + de-bounce; synthetic BPM fallback |
| ReplicatorCOMP | COMP | Table-driven replicator via GNNetwork API with hash-based change detection |
| OpticalFlowTOP | TOP | Horn-Schunck GLSL fragment shader for motion vector estimation |

### 31.3 Tier 2 Operators (10 complementary)

| Operator | Family | Algorithm / Notes |
|----------|--------|-------------------|
| CapSOP | SOP | Boundary edge detection → loop tracing → triangle fan caps (centroid fill) |
| LatticeSOP | SOP | Free-form deformation via cubic lattice with trilinear interpolation + FastNoiseLite |
| PolyLoftSOP | SOP | Cross-section ring lofting with auto-resample + subdivisions + end caps |
| MountainSOP | SOP | FastNoiseLite FBM vertex displacement along normals (Simplex/Perlin/Cellular/Value) |
| IKCHOP | CHOP | FABRIK inverse kinematics chain solver with optional Y constraint |
| WarpCHOP | CHOP | Time-warp/retime with speed multiplier, offset, or input warp curve |
| TableDAT | DAT | Manual CSV-style editable data table with merge-input mode |
| NetworkDAT | DAT | TCP/UDP network I/O via Godot StreamPeerTCP/PacketPeerUDP (client + listen modes) |
| EmbossTOP | TOP | Directional emboss relief filter via GLSL shader (`emboss.gdshader`) |
| GlueTOP | TOP | Grid atlas texture packer (up to 4 inputs, configurable layout + padding) |

### 31.4 Help Patch Overhaul

- Created 15 new help patches for all new operators
- **WindowOUT sink rule (Hard Rule 25.22):** ALL help patches must end with WindowOUT (512×512, open=true) via meaningful, family-appropriate visualization chains
- Bulk-updated 227 existing patches via PowerShell script (`scripts/add_window_to_help.ps1`)
- Manually fixed 2 patches with non-standard JSON keys (`from_node`/`to_node` vs `from`/`to`)
- Second overhaul (`scripts/fix_help_patch_sinks.ps1`): replaced blind cross-family WindowOUT connections with proper chains (CHOPtoTOP for CHOPs, RenderTOP+CameraCOMP for SOPs/COMPs/MATs, TextTOP for DATs)
- Fixed 4 COMP help patches where pass-through COMPs (NullCOMP, SwitchCOMP, AnimationCOMP) were dead-end branches bypassed by direct Geo→RenderTOP connections
- Final count: 1,084 help patches across 11 families (3+ per operator), all compliant with the sink rule

### 32.3 C++ GDExtension Native Acceleration Extension

Built a complete C++ GDExtension source tree for 69 CPU-heavy operators across 6 build phases, plus GDScript wrapper operators with automatic fallback.

**C++ source (`addons/gn_ext_native/native/`):**
- `SConstruct` — SCons build file using godot-cpp (special case: not managed by unified build system)
- `src/register_types.cpp` + `.h` — entry point registering 16 classes across 3 families
- `src/img/` — 4 IMG processors: GNNativeBlur, GNNativeNoise, GNNativePixelSort, GNNativeEdgeDetect
- `src/sop/` — 11 SOP processors: GNNativeParticle, GNNativeMetaball, GNNativePolyReduce, GNNativeIsoSurface, GNNativeRay, GNNativeFacet, GNNativeFuse, GNNativeSubdivide, GNNativeCopy, GNNativeLSystem, GNNativeSpring
- `src/chop/` — 1 CHOP processor: GNNativeSmooth
- `gn_native.gdextension` is **active**; `bin/win64/libgn_native.windows.template_debug.x86_64.dll` compiled (677 KB, 2026-03-10). Linux/macOS require building on those platforms.

**Phase 1 GDScript wrappers (6):**
- `operators/img/blur_img_native.gd` (BlurIMGNative) — delegates to `GNNativeBlur.process()`
- `operators/img/noise_img_native.gd` (NoiseIMGNative) — delegates to `GNNativeNoise.process()`
- `operators/img/pixel_sort_img_native.gd` (PixelSortIMGNative) — delegates to `GNNativePixelSort.process()`
- `operators/sop/particle_sop_native.gd` (ParticleSOPNative) — stateful: `set_emitter()` + `step()`
- `operators/sop/metaball_sop_native.gd` (MetaballSOPNative) — delegates to `GNNativeMetaball.process()`
- `operators/sop/polyreduce_sop_native.gd` (PolyReduceSOPNative) — delegates to `GNNativePolyReduce.process()`

**Phase 2 GDScript wrappers (10):**
- `operators/sop/isosurface_sop_native.gd` (IsoSurfaceSOPNative) — marching cubes iso-surface with 5 field types
- `operators/sop/ray_sop_native.gd` (RaySOPNative) — Möller–Trumbore ray-cast projection
- `operators/sop/facet_sop_native.gd` (FacetSOPNative) — unique/consolidate with spatial hash
- `operators/sop/fuse_sop_native.gd` (FuseSOPNative) — vertex welding within threshold
- `operators/sop/subdivide_sop_native.gd` (SubdivideSOPNative) — uniform 1→4 subdivision
- `operators/sop/copy_sop_native.gd` (CopySOPNative) — copy-to-points with normal alignment + pscale
- `operators/sop/lsystem_sop_native.gd` (LSystemSOPNative) — grammar rewriting + turtle, line/tube mesh
- `operators/sop/spring_sop_native.gd` (SpringSOPNative) — semi-implicit Euler spring deformer
- `operators/img/edge_detect_img_native.gd` (EdgeDetectIMGNative) — Sobel/Prewitt convolution
- `operators/chop/smooth_chop_native.gd` (SmoothCHOPNative) — biquad Butterworth IIR filter

**Help patches:** 16 `.gnpatch` files in `help/sop/`, `help/img/`, `help/chop/` — one per operator.

**Architecture pattern:** C++ `RefCounted` processor classes bound via `ClassDB::bind_method`. GDScript wrappers check `ClassDB.class_exists("GNNativeXxx")` at init — if available, instantiate and delegate; otherwise, return null for fallback to core GDScript operator. Extension manifest (`gn_extension.cfg`) registers all 16 operators under "Native" section.

**Bugs fixed during implementation:**
- `create_menu()` does not exist on GNParameter — fixed to `create_int()` in NoiseIMGNative and PixelSortIMGNative
- `GNNativePolyreduce` → `GNNativePolyReduce` casing fix in `register_types.cpp`

**Compile errors fixed on first build (Phase 2 code, 2026-03-10):**
- `Quadric` struct declared `private` in `gn_native_polyreduce.h` — moved to `public` so the free helper `_compute_collapse()` in the `.cpp` could access `GNNativePolyReduce::Quadric` by name
- `p_positions.duplicate()` / `p_indices.duplicate()` on `const&` parameters in `polyreduce.cpp` — `.duplicate()` is non-const in godot-cpp; replaced with plain copy assignment (`positions = p_positions`)
- Same `.duplicate()` issue in `spring.cpp` (`_positions = target_positions.duplicate()` → `_positions = target_positions`)
- Missing `#include <vector>` in `gn_native_particle.h` (needed for `std::vector<Triangle> _triangles`)
- Missing `#include <vector>` in `gn_native_edge_detect.cpp` (needed for `std::vector<float> lum`)

### 32.4 Viewer Panel IMG Stability Fix

**Problem:** Clicking between IMG nodes showed the same "stuck" image. Two bugs:

1. **Per-frame ImageTexture recreation**: `update_from_node()` called `ImageTexture.create_from_image()` every frame for IMG nodes, producing a new texture object. `_show_texture()`'s fast-path identity check (`_tex_display.texture == tex`) never matched, causing every frame to run `_hide_all_displays()` → `_show_texture()` → `_fit_to_panel()` — flicker + pan/zoom reset.

2. **COW bypass by viewer**: `_consumer_counts` only counted wire connections, not the viewer. When NoiseIMG → PixelSortIMG (1 consumer via wires), `_shared = false`. PixelSortIMG's `_mutable_input()` returned NoiseIMG's data without duplicating, sorting the upstream Image in-place. NoiseIMG's `cached_output.image` was permanently mutated to the sorted version.

**Fixes applied:**
- **`gn_viewer_panel.gd`**: Added `_img_texture: ImageTexture` cache. First frame creates texture via `create_from_image()`; subsequent frames use `update()` for zero-allocation pixel refresh. Full layout only triggers on resolution change. `set_target()` clears `_img_texture = null` to force fresh texture on node switch.
- **`gn_cook_engine.gd`**: `_rebuild_consumer_counts()` now counts each viewer sink's upstream inputs as additional consumers. `set_active_sinks()` sets `_consumer_counts_dirty = true` so counts recompute when viewer target changes.

### 31.5 Updated Totals

- **288 operators** (63 TOP, 12 IMG, 61 CHOP, 29 DAT, 57 SOP, 20 COMP, 6 MAT, 9 OUT, 31 UI)
- **1,084 help patches** (1,014 core + 70 extension) across all 11 families — 3+ per operator
- Zero deferred operators remain

---

## 32. Session Changelog — 2026-03-10

### 32.1 AnimationCOMP / Pass-Through COMP Bug Fix

- **AnimationCOMP** (`animation_comp.gd`): Set `_scene_node` to upstream COMP's scene node during `_cook()` so `get_scene_node()` returns non-null. `destroy_scene_node()` clears `_scene_node` without freeing it (we don't own it — upstream COMP does). Same for `_notification(PREDELETE)`.
- **RenderTOP** (`render_top.gd`): Added `_resolve_comp_scene_node()` method that walks upstream through pass-through COMPs (NullCOMP, SwitchCOMP, AnimationCOMP, etc.) to find the actual scene node. Uses cycle-guarded recursive walk with `visited` dictionary. Only fires for the generic `GNCompBase` fallback — typed COMPs (GeometryCOMP, CameraCOMP, LightCOMP, MergeCOMP, EnvironmentCOMP) use their existing fast paths unchanged. Zero performance impact on common case.
- **Root cause:** Pass-through COMPs don't own a scene node (`_scene_node = null`), so RenderTOP's `get_scene_node()` returned null → nothing rendered. The cook engine's active chain only cooks nodes upstream of sinks — if a COMP is a dead-end branch (not feeding RenderTOP), it never cooks.

### 32.2 Help Patch Connection Fixes

- **animation_comp.gnpatch**: Fixed chain to `box → geo → anim → render ← cam → window` (was: geo fed both anim and render independently, leaving anim as dead end)
- **null_comp_basic.gnpatch**: Fixed chain to `box → geo → null → render ← cam → window` + added BoxSOP input for geometry
- **switch_comp_basic.gnpatch**: Fixed chain to `box → geo1 → sw ← geo2 ← sphere; sw → render ← cam → window` + added BoxSOP and SphereSOP inputs
- **Hard Rule 25.22 updated**: Expanded from simple "end with WindowOUT" to require meaningful, family-appropriate visualization chains with specific required chain patterns per family

---

## 33. Session Changelog — UI Family Implementation

### 33.1 UI Family (10th Operator Family)

- **GNFamily enum**: Added `UI` type with name "UI" and color Sky Blue `Color(0.2, 0.7, 0.9)`. GONODES now has 10 operator families: TOP, IMG, CHOP, SOP, POP, DAT, MAT, COMP, UI, OUT.
- **GNUiBase** (`core/gn_ui_base.gd`): New base class extending GNNode. Manages `_control_node: Control` (parallel to GNCompBase's `_scene_node: Node3D`). Same lifecycle pattern: lazy create via `_ensure_control_node()`, `_notification(PREDELETE)` cleanup, reparenting into PanelTOP's SubViewport. Default output port "out" of type UI. **Every UI widget automatically gets a "state" CHOP output port** (appended as the last output in `initialize()` after `_init_ports()`). The base class `execute_cook()` override calls `_build_state_chop()` after `_cook()`, converting `widget_state` dict to `GNChannelData` with channels named `<id>:<key>`. ContainerUI overrides `_build_state_chop()` to aggregate all connected children's states.

### 33.2 Separated Context Architecture (Replaces panel_sources)

**Two paths for UI panels:**
- **Interactive path**: UI widgets → ContainerUI → WindowOUT panel port (port 1). WindowOUT creates a SubViewportContainer that provides native Godot input routing (mouse, keyboard, focus). No manual push_input, no coordinate remapping.
- **Render-to-texture path**: UI widgets → PanelTOP → TOP chain → WindowOUT TOP port (port 0). Pixels only, non-interactive. Useful for recording, screenshots, shader effects on UI.

**What was removed:**
- `panel_sources: Array` removed from GNTextureData.
- `carry_panel_sources_from()`, `merge_panel_sources()` removed from GNTextureData.
- All panel_sources handling removed from 13+ TOP operators.
- `GNTopBase.execute_cook()` no longer auto-carries panel_sources.
- All custom input forwarding removed from WindowOUT (~200 lines).

### 33.3 PanelTOP — Render to Texture (Non-Interactive)

- **PanelTOP** (`operators/top/panel_top.gd`): Extends GNTopBase. Creates SubViewport (`gui_disable_input = true`) with `_ui_root` container inside.
- Uses `_enable_dynamic_inputs(GNFamily.Type.UI)` for unlimited widget connections.
- Parameters: resolution, layout (VBox/HBox/Grid/Flow), padding, bg_color, transparent_bg, spacing.
- During `_cook()`: reparents connected widgets' `_control_node` into `_ui_root`, outputs GNTextureData (pixels only, no panel_sources).
- Output port 0: TOP (GNTextureData, non-interactive). No CHOP output — widget state comes from each UI widget's own "state" CHOP port (via GNUiBase).

### 33.3b WindowOUT — Interactive Panel Layer

- WindowOUT has two input ports: port 0 (TOP, background texture), port 1 (UI, interactive panel).
- Panel layer uses SubViewportContainer + SubViewport for native Godot input routing.
- Controls are adopted from the connected UI widget into the panel SubViewport.
- Overlay system (CanvasLayer) for dropdowns, color pickers, menus.
- Panel viewport resizes to match window size.

### 33.4 UI Widget Operators (8 Widgets)

All in `operators/ui/`, extend GNUiBase:
- **ButtonUI**: Godot Button. Params: text, font_size, color. State channels: press (0/1), click_count.
- **SliderUI**: HSlider/VSlider. Params: min, max, step, value, orientation. State channel: value.
- **ToggleUI**: CheckButton. Params: text, default_state. State channel: state (0/1).
- **LabelUI**: Label (display only). Params: text, font_size, color, alignment.
- **KnobUI**: Custom Control with `_draw()`. Params: min, max, value, size, color. State channels: value, angle.
- **XYPadUI**: Custom Control with `_draw()`. Params: x_range, y_range, size. State channels: x, y.
- **DropdownUI**: OptionButton. Params: items (comma-separated), default_index. State channel: index.
- **ContainerUI**: HBox/VBox/Grid/Flow layout container for nesting widgets. Dynamic UI inputs.

### 33.5 WindowOUT Panel Layer

- WindowOUT `_update_panel_layer()` adopts UI controls into SubViewportContainer's SubViewport.
- Window's `_on_window_input` callback handles ESC (fullscreen→windowed) only — all other input is routed natively by SubViewportContainer.
- No manual push_input, no coordinate remapping, no custom keyboard forwarding.

### 33.6 TOP Operators — No Panel Source Handling

- TOPs are pure texture processors. No panel_sources metadata, no inverse transform math.
- GNTopBase `execute_cook()` just triggers SubViewport render — no panel_sources carry logic.
- All 13 spatial TOPs that previously handled panel_sources have been simplified to pure texture math.

### 33.7 Extension Registry & Help Patches

- PanelTOP registered under "TOPs: Panel" section.
- 31 UI widgets registered under "UIs: Widgets" section (8 original + 23 new across 4 tiers).
- 99 help patches in `help/ui/` (3+ per UI operator).

### 33.8 Updated Totals

- **288 operators** (63 TOP, 12 IMG, 61 CHOP, 29 DAT, 57 SOP, 20 COMP, 6 MAT, 9 OUT, 31 UI)
- **1,084 help patches** (1,014 core + 70 extension) across all 11 families — 3+ per operator
- 10 operator families: TOP, IMG, CHOP, SOP, POP, DAT, MAT, COMP, UI, OUT

---

## §34 — UI Family Expansion (Godot Control Mirror)

23 new UI operators mirroring Godot's Control hierarchy, organized in 4 tiers:

**Tier 1 — High-Value (8):** TextureRectUI (TOP+MAT→TextureRect), ColorRectUI (MAT→ColorRect, clickable), LineEditUI (single-line text input), TextEditUI (DAT→multi-line editor), ProgressBarUI (CHOP-driven progress), SpinBoxUI (numeric spin box with prefix/suffix), ColorPickerUI (RGBA channels as state), RichTextLabelUI (BBCode label from DAT).

**Tier 2 — Containers (5):** ScrollContainerUI (scrollable child area), TabContainerUI (DAT tab names + UI pages), SplitContainerUI (H/V draggable divider), MarginContainerUI (configurable margins), PanelContainerUI (styled background with corner radius).

**Tier 3 — Data-Driven (4):** TreeUI (DAT→Tree with parent/child), ItemListUI (DAT→selectable list + TOP icon), TabBarUI (DAT→standalone tabs), MenuButtonUI (DAT→popup menu).

**Tier 4 — Completeness (6):** CheckBoxUI (classic checkbox), TextureButtonUI (3 TOP inputs: normal/pressed/hover), SeparatorUI (H/V separator line), NinePatchRectUI (stretchable TOP), LinkButtonUI (underlined text link), TextureProgressBarUI (3 TOP layers + CHOP driver).

All 23 follow the same GNUiBase pattern: lazy `_ensure_*()` Control creation, `widget_state` Dictionary for CHOP channels, signal-based `mark_dirty()`, and `destroy_control_node()` with signal disconnection cleanup. Registered in GNExtensionRegistry under tiered comment sections.

---

## §35 — POP & VOL Families (GPU Particle + 3D Volume)

### 35.1 New Operator Families: POP and VOL

Two new GPU-accelerated operator families implemented, bringing the total to **11 families** and **348 operators**.

- **POP** (GPU Particles): Cyan `Color(0.2, 0.8, 0.8)`. SSBO-based GPU particle system using GLSL compute shaders via `RenderingDevice`. 64-byte stride standard layout (pos vec4, vel vec4, color vec4, age/life/mass/pscale floats). Generators allocate, processors write in-place, COW on fan-out.
- **VOL** (3D Volumes): Rose `Color(0.85, 0.35, 0.55)`. 3D texture-based volumetric data using GLSL compute shaders. Configurable bit depth: R16F, R32F, RGBA16F, RGBA32F. Texture pool for ping-pong allocation.
- **ParticleSOP** kept as CPU fallback alongside new GPU POP family.

### 35.2 Core Infrastructure

- **GNGpuContext** (`core/gn_gpu_context.gd`): Singleton wrapping shared `RenderingDevice` (via `RenderingServer.create_local_rendering_device()`). Provides `create_buffer()`, `create_texture_3d()`, `acquire_texture_3d()` (pooled), compute pipeline compilation, uniform set creation, and dispatch helpers.
- **GNParticleData** (`core/gn_particle_data.gd`): `GNData` subclass wrapping GPU SSBO (`RID`). Fields: `rd_buffer`, `particle_count`, `max_particles`, `stride`, `attribute_layout` (Dictionary of `AttribDesc`), `bounds` (AABB). Inner class `AttribDesc` with `offset: int` and `type: String`. `duplicate_data()` does GPU-to-GPU buffer copy. `get_attrib_offset()` for named attribute lookup.
- **GNVolumeData** (`core/gn_volume_data.gd`): `GNData` subclass wrapping GPU 3D texture (`RID`). Fields: `rd_texture`, `resolution` (Vector3i), `bounds` (AABB), `data_format`, `channel_count`, `field_name`. `duplicate_data()` does GPU-to-GPU texture copy. `has_volume()`, `voxel_count()`, `bytes_per_voxel()` helpers.
- **GNPopBase** (`core/gn_pop_base.gd`): Base class for POP operators. `STANDARD_STRIDE = 64` bytes. `_get_standard_layout()` returns canonical attribute offsets. `_allocate_particles()`, `_encode_push_constants()`, `_workgroups()` helpers. All POP operators are `time_dependent = true`.
- **GNVolBase** (`core/gn_vol_base.gd`): Base class for VOL operators. `_create_volume()`, `_acquire_volume()` (pooled), `_channels_for_format()`, `_encode_push_constants()`, `_workgroups_3d()`, `_f32()`/`_i32()` byte encoding helpers.
- **GNFamily enum**: `VOL` added with rose color. 11 families: TOP, IMG, CHOP, SOP, POP, VOL, DAT, MAT, COMP, UI, OUT.

### 35.3 POP Operators (10)

All in `operators/pop/`, extend GNPopBase:
- **SourcePOP**: Emit particles from SOP surface or origin. Params: max_particles, emit_rate, life, speed, spread, color.
- **ForcePOP**: Gravity, wind, directional force. Params: gravity, wind, force_scale.
- **TurbulencePOP**: Curl noise turbulence. Params: frequency, amplitude, roughness, octaves.
- **CollisionPOP**: Ground plane / bounding box collision. Params: mode (ground/box), ground_y, bounce, friction, box_min/max.
- **AttractPOP**: Point/line/geometry attractor. Params: mode (point/line/geo), target, strength, falloff, max_distance.
- **LimitPOP**: Kill by age/bounds/speed. Params: enable_age/bounds/speed, max_age, bounds_min/max, max_speed.
- **AdvectPOP**: Advect particles by VOL velocity field. Params: scale.
- **InstancePOP**: Copy SOP instances onto particles → COMP output.
- **RenderPOP**: Particle rendering → COMP output. Params: point_size, blend_mode.
- **ParticleStateTOP**: POP → TOP visualization bridge. Registered under "TOP" family.

### 35.4 POP GLSL Compute Shaders (7)

All in `shaders/pop/`, 64-byte stride std430 layout:
`source_pop.glsl`, `force_pop.glsl`, `turbulence_pop.glsl`, `collision_pop.glsl`, `attract_pop.glsl`, `limit_pop.glsl`, `advect_pop.glsl`.

### 35.5 VOL Operators (10)

All in `operators/vol/`, extend GNVolBase:
- **NoiseVOL**: 3D noise density generation. Params: resolution, frequency, amplitude, octaves, lacunarity, seed, format, field_name.
- **BlendVOL**: Combine/blend two volumes. Params: mode (add/subtract/multiply/max/min/lerp), mix.
- **BlurVOL**: 3D Gaussian/box blur. Params: radius, mode (gaussian/box).
- **DisplaceVOL**: Warp density by velocity field. Params: scale.
- **FluidVOL**: Navier-Stokes sim (4-pass: advect, divergence, pressure, project). Params: resolution, viscosity, dissipation, pressure_iterations, force, force_radius, format.
- **MarchingCubesVOL**: Iso-surface extraction → SOP (CPU). Params: threshold, close_boundary. Outputs GNGeoData.
- **RaymarchVOL**: Volume rendering → TOP. Params: resolution, step_count, density_scale, light_dir, absorption. Outputs GNTextureData.
- **SOPtoVOL**: Rasterize SOP mesh → density grid. Params: resolution, radius.
- **CHOPtoVOL**: CHOP channels → volume slices. Params: resolution.
- **AnalyzeVOL**: Min/max/mean/sum statistics. Outputs GNChannelData.

### 35.6 VOL GLSL Compute Shaders (11)

All in `shaders/vol/`:
`noise_vol.glsl`, `blend_vol.glsl`, `blur_vol.glsl`, `displace_vol.glsl`, `fluid_advect.glsl`, `fluid_divergence.glsl`, `fluid_pressure.glsl`, `fluid_project.glsl`, `raymarch_vol.glsl`, `sop_to_vol.glsl`, `analyze_vol.glsl`.

### 35.7 Viewer Integration

- **POP viewer** (`gn_viewer_panel.gd`): 3D SubViewport + Camera3D + MultiMeshInstance3D with billboard quads. Orbit camera (mouse drag/scroll). GPU readback of pos/color/pscale from SSBO to build MultiMesh. GPU render toggle button.
- **VOL viewer** (`gn_viewer_panel.gd`): Three orthogonal slice displays (XY, XZ, YZ) + MIP toggle. Full 3D texture readback, slice extraction as Image, scroll wheel changes slice position. Max intensity projection sums density across Z axis.

### 35.8 Extension Registry

All 20 POP+VOL operators registered in `gn_extension_registry.gd`:
- 9 POP operators under "POPs" section
- 10 VOL operators under "VOLs" section
- ParticleStateTOP registered under "TOPs: Particle Bridge" section

### 35.9 Tests

- `tests/operators/pop/test_pop_operators.gd`: ~50 test methods covering all 10 POP operators, GNParticleData, GNPopBase standard layout, GNGpuContext singleton.
- `tests/operators/vol/test_vol_operators.gd`: ~50 test methods covering all 10 VOL operators, GNVolumeData, GNVolBase helpers, GNGpuContext singleton.

### 35.10 Other Session Changes

- `.gitlab-ci.yml`: Created GitLab CI config with 3 jobs (Windows, Linux, macOS) for multi-platform native builds.
- `physics_chop_native.gd`: Added missing `_resolve_upstream_comp()` method.
- `tests/README.md`: Updated with operator test folder structure and boilerplate guide.
- `.gitignore` + `.vscode/settings.json`: Fixed VS Code git crash caused by `godot-cpp/` untracked nested repo.

### 35.11 Updated Totals

- **348 operators** (81 TOP, 14 IMG, 68 CHOP, 33 DAT, 62 SOP, 10 POP, 11 VOL, 20 COMP, 9 MAT, 9 OUT, 31 UI)
- **11 operator families**: TOP, IMG, CHOP, SOP, POP, VOL, DAT, MAT, COMP, UI, OUT
- **11 GDExtension addons**: gn_ext_native (92 C++ operators), gn_ext_shadertoy, gn_ext_isf, gn_ext_ffmpeg, gn_ext_hap (HAP GPU-direct video codec — HapInTOP, HapOUT), gn_ext_spout, gn_ext_syphon, gn_ext_video_capture, gn_ext_midi, gn_ext_gpu_encode, gn_ext_mapper
- **1,084 help patches** (1,014 core + 70 extension) across all 11 families — 3+ per operator
- **18 GLSL compute shaders** (7 POP + 11 VOL)
- POP and VOL roadmap items moved to implemented. Custom Operator Assets (.gnasset) remains on roadmap.

---

## §36 — Roadmap: C++ Native Operator Migration (Comprehensive Audit)

### 36.1 Current State

**43 native C++ operators** across 4 families via `gn_ext_native` / `gn_native` GDExtension:

| Family | Count | Operators |
|--------|-------|-----------|
| SOP (24) | Geometry | Particle, Metaball, PolyReduce, IsoSurface, Ray, Facet, Fuse, Subdivide, Copy, LSystem, Spring, Noise, Mountain, Blend, Scatter, Sweep, Extrude, Bend, Taper, Twist, Lattice, Magnet, PolyLoft, Skin |
| CHOP (13) | Signal | Smooth, Noise, Wave, Math, Filter, Resample, Trail, Slope, Warp, Interpolate, Physics, Pattern, AudioSpectrum |
| IMG (4) | Image | Blur, Noise, PixelSort, EdgeDetect |
| TOP (2) | Texture | OpticalFlow, Analyze |

Architecture: each native op is a C++ class in `gn_native/src/` compiled via SCons into a GDExtension `.dll`/`.so`/`.dylib`. A thin GDScript wrapper in `gn_ext_native/operators/` extends the appropriate family base class, delegates `_cook()` to the native class, and adapts inputs/outputs to the GNData pipeline.

### 36.2 Audit Methodology

Every operator in the 348-operator codebase was evaluated for C++ migration candidacy using these criteria:

1. **Algorithmic complexity** — triple-nested loops, O(N²/N³) vertex/voxel scans, per-element interpreted expression calls
2. **Data volume** — operations on 50K+ vertices, 128³+ voxels, 44.1K+ audio samples, or 512²+ pixels per frame
3. **SIMD friendliness** — contiguous float array transforms, matrix multiplies, reductions, interpolations
4. **Workflow frequency** — how often the operator appears in real patches

Operators that delegate to Godot's GPU pipeline (GLSL compute shaders, ShaderMaterial, SubViewport rendering) or wrap Godot scene nodes (COMP, MAT, UI) are excluded — their bottleneck is the GPU or Godot API, not GDScript interpretation.

### 36.3 Tier 1 — Critical (heavy CPU bottlenecks, 20-100× expected speedup)

| # | Operator | Family | Bottleneck Analysis |
|---|----------|--------|---------------------|
| 1 | **MarchingCubesVOL** | VOL→SOP | Triple-nested `(res-1)³` cell loop: 8 field lookups + edge interpolation + triangle emit + gradient normals per cell. At 128³ ≈ 2M cells. Heaviest pure-CPU operator in the project. |
| 2 | **InstancePOP** | POP→SOP | GPU→CPU readback + O(instances × source_verts) vertex transform loop. 10K instances × 100 verts = 1M transforms in GDScript. SIMD-friendly matrix multiply. |
| 3 | **TOPtoSOP** | TOP→SOP | Heightfield: `res×res` pixel reads (up to 512² = 262K), then per-triangle face normals (cross products), then per-vertex normal averaging. 3 passes over all data. |
| 4 | **PointSOP** | SOP | **3× `Expression.execute()` per vertex** for X/Y/Z with 11 variable bindings each. 50K verts = 150K interpreted evaluations. Could use compiled expression trees in C++. |
| 5 | **ClipSOP** | SOP | Per-triangle plane classification + split-edge lerp + mesh rebuild. Real-time clipping with vertex interpolation on every triangle. |

### 36.4 Tier 2 — High (10-50× expected speedup, frequent in workflows)

| # | Operator | Family | Bottleneck Analysis |
|---|----------|--------|---------------------|
| 6 | **CHOPtoVOL** | CHOP→VOL | Up to 256³ = 16.7M float→byte encodes + channel mapping loops. Simple but massive volume data. |
| 7 | **AnalyzeVOL** | VOL→CHOP | Full 3D texture readback + statistical reduction (min/max/sum/histogram). O(N³) scan. SIMD reduction ideal. |
| 8 | **ParticleStateTOP** | POP→TOP | Full SSBO readback (64 bytes × particle count) + struct decode + `set_pixel()` per particle. 100K particles = 100K pixel operations. |
| 9 | **CHOPtoTOP** | CHOP→TOP | `W×H` nested `set_pixel()` loop for waveform/heatmap rendering. 512×256 = 131K CPU pixel writes per frame. |
| 10 | **TOPtoCHOP** | TOP→CHOP | `W×H` nested `get_pixel()` loop summing RGBA. 512² = 262K pixel reads per frame. |
| 11 | **SortSOP** | SOP | O(N log N) sort with per-vertex `distance_squared_to()` + 5-array remap through sort permutation. |
| 12 | **UVProjectSOP** | SOP | Per-vertex `atan2()`/`sqrt()` for cylindrical/spherical + AABB prepass. 2 passes over all vertices with transcendental math. |
| 13 | **AttributeSOP** | SOP | 1× `Expression.execute()` per vertex (same expression overhead as PointSOP). |
| 14 | **AudioDynamicsCHOP** | CHOP | Per-sample `pow()`/`log()` dB conversions at audio rate (44.1K samples/sec). Textbook DSP inner loop. |
| 15 | **ExpressionCHOP** | CHOP | `Expression.execute()` per sample × per channel. 10K samples = 10K interpreted evaluations. |

### 36.5 Tier 3 — Medium (5-20×, solid improvement for large meshes)

| # | Operator | Family | Bottleneck Analysis |
|---|----------|--------|---------------------|
| 16 | **TransformSOP** | SOP | Per-vertex matrix multiply (positions + normals). Simple but universal — every pipeline uses it. |
| 17 | **DivideSOP** | SOP | Per-face triangulation + degenerate removal. Two passes over all triangles. |
| 18 | **MirrorSOP** | SOP | 3× per-element passes: vertex reflect, normal reflect (dot+normalize), winding flip. |
| 19 | **NormalSOP** | SOP | Flat mode: per-triangle cross product + vertex unsharing rebuild. |
| 20 | **CapSOP** | SOP | Boundary edge detection with Dictionary hash dedup + adjacency graph + loop tracing. Hidden hotspot on complex meshes. |
| 21 | **DeleteSOP** | SOP | Per-triangle classification + SurfaceTool mesh rebuild of kept geometry. |
| 22 | **CarveSOP** | SOP | Per-triangle centroid + parametric U test + vertex array rebuild. |
| 23 | **RenderPOP** | POP→COMP | Per-particle MultiMesh transform setup loop. Moderate — bottleneck is Godot API calls. |
| 24 | **CheckerboardIMG** | IMG | `W×H` pixel loop with trig for soft edges. Same `set_pixel()` bottleneck. |
| 25 | **StretchCHOP** | CHOP | Per-sample Catmull-Rom interpolation for time-stretch resampling. |
| 26 | **LookupCHOP** | CHOP | Per-sample table lookup with linear/cubic interpolation. |

### 36.6 Tier 4 — Low (marginal gains, small data, or simple math)

WireframeSOP, PeakSOP, GroupSOP, PrimitiveSOP, TransformCHOP, BlendCHOP, SOPtoCHOP, CHOPtoSOP. These operate on small data sets or have very simple per-element ops where GDScript overhead is negligible.

### 36.7 What's NOT a Candidate

- **All pure GPU operators** — POP forces/emission/turbulence, VOL noise/blur/blend/fluid/displace/SOPtoVOL, most TOPs. Already running GLSL compute shaders; C++ can't beat the GPU.
- **Pass-throughs** — Null nodes, Switch nodes. Zero computation.
- **Godot API wrappers** — COMP nodes (Node3D scene tree), MAT nodes (ShaderMaterial), UI nodes (Control hierarchy). Bottleneck is Godot's own API, not GDScript.
- **Scene-based ops** — RenderTOP, EnvironmentCOMP, light/camera COMPs. Rendering is GPU-bound.
- **DAT family** — String/table operations on small data sets. Not worth native overhead.

### 36.8 Recommended Phase 4 (Next Native Batch)

Priority selection of **10 operators** that would cover every known CPU bottleneck in the POP/VOL/cross-family pipeline:

1. **MarchingCubesVOL** — single highest-impact operator in the entire project
2. **InstancePOP** — second highest-impact, directly in fluid/particle workflows
3. **CHOPtoVOL** — enables high-res CHOP→VOL pipelines
4. **AnalyzeVOL** — enables responsive VOL statistics
5. **TOPtoSOP** — heightfield displacement is a major use case
6. **PointSOP** — expression-driven vertex manipulation, universally used
7. **ClipSOP** — real-time boolean/sculpting workflows
8. **SortSOP** — sorting large vertex arrays for rendering order
9. **CHOPtoTOP** — cross-family bridge, high pixel-write volume
10. **TOPtoCHOP** — cross-family bridge, high pixel-read volume

This would bring total native coverage from **43 → 53 operators** and eliminate every known CPU bottleneck in the POP, VOL, and cross-family bridge pipeline.

### 36.9 Future Phases

**Phase 5** (Tier 2 remainder + Tier 3 high-value): ParticleStateTOP, UVProjectSOP, AttributeSOP, ExpressionCHOP, AudioDynamicsCHOP, TransformSOP, DivideSOP, NormalSOP → **53 → 61 operators**.

**Phase 6** (Tier 3 remainder): MirrorSOP, CapSOP, DeleteSOP, CarveSOP, RenderPOP, CheckerboardIMG, StretchCHOP, LookupCHOP → **61 → 69 operators**.

At 92 native operators (26% of 348), every CPU-intensive operator is now in C++. Remaining GDScript operators are GPU-bound, pass-through, or API-wrapper nodes where native code provides no benefit.

### 36.10 ISF Extension — IMPLEMENTED

`gn_ext_isf` — **ISF (Interactive Shader Format)** compatibility for the VJ/live-visual world (VDMX, MadMapper, Millumin, CoGe, Synesthesia).

**Architecture — runtime translation only (no pre-baked shaders):**

- **ISFTranslator** (`isf_translator.gd`) — parses `.fs`/`.isf` files, extracts JSON header, translates ISF GLSL → Godot `canvas_item` shaders at runtime. Maps ISF built-ins: `RENDERSIZE`→uniform vec2, `TIME`→Godot TIME, `isf_FragNormCoord`→UV, `IMG_PIXEL()`/`IMG_NORM_PIXEL()`/`IMG_THIS_PIXEL()`→texture() calls, `IMG_SIZE()`→uniform vec2 per image, `gl_FragColor`→COLOR.
- **ISFTOP** — single runtime node with inline code editor, ISF syntax highlighting, and preset system. Auto-parses JSON `INPUTS` → auto-creates GNParameters (float/bool/long/point2D/color) and TOP input ports (image type) → translates and compiles shader. Drop any ISF file, get a working node with full parameter UI.
- **Multi-pass support** — `PASSES`/`TARGET`/`PERSISTENT`/`FLOAT` → multiple SubViewport render passes with persistent buffers.
- **10 factory presets** (.fs files in `presets/isf/`): 5 generators (color_bars, sine_warp, kaleidoscope, gradient_map, lissajous), 5 effects (kaleidoscope_fx, glitch, mirror, edge_glow, cross_hatch).
- **2 help patches**: `isf_generator.gnpatch`, `isf_fx.gnpatch`.
- ISF INPUT type mapping: float→Float param, bool→Bool param, long→Enum param (VALUES+LABELS), point2D→Vector2 param, color→Color param, event→momentary Bool, image→TOP input port.
- **Audio input support** (stretch goal) — ISF `audio`/`audioFFT` input types → accept CHOP data, render as 1D texture for audio-reactive VJ shaders.

**Design decision:** No ISFBaseTOP or pre-baked `.gdshader` conversions. The ISFTranslator handles all translation at runtime, so every ISF shader works through a single node. This avoids class proliferation and keeps the extension maintainable.

---

## 34. Mobile / Web Export — Renderer & Platform Compatibility

### 34.1 Overview

GONODES targets all Godot-supported platforms: desktop (Windows, macOS, Linux), mobile (Android, iOS), and web (HTML5). Compatibility is tracked on two orthogonal axes:

**Axis 1 — Renderer** (GPU capability):

| Renderer           | GPU Target              | Compute Shaders | Platforms                    |
|--------------------|-------------------------|-----------------|------------------------------|
| **Forward+**       | Vulkan / D3D12          | Yes             | Desktop                      |
| **Mobile**         | Vulkan-lite / Metal     | Yes (subset)    | Mobile, some desktop         |
| **Compatibility**  | OpenGL 3.3 / WebGL2     | No              | Web, old hardware            |

**Axis 2 — Platform** (OS capability):

| Platform   | Filesystem | Multi-Window | CLI (OS.execute) | Threads | MIDI |
|------------|------------|--------------|-------------------|---------|------|
| Windows    | ✓          | ✓            | ✓                 | ✓       | ✓    |
| macOS      | ✓          | ✓            | ✓                 | ✓       | ✓    |
| Linux      | ✓          | ✓            | ✓                 | ✓       | ✓    |
| Android    | ✓ (scoped) | ✗            | ✗                 | ✓       | ✓    |
| iOS        | ✓ (scoped) | ✗            | ✗                 | ✓       | ✗    |
| Web        | ✗          | ✗            | ✗                 | ✗¹      | ✗    |

¹ Web supports threads only with SharedArrayBuffer + COOP/COEP headers.

### 34.2 Renderer Detection (Phase 1 — IMPLEMENTED)

**`GNGpuContext.get_current_renderer()`** — static method returning the active rendering method string (`"forward_plus"`, `"mobile"`, or `"gl_compatibility"`). Reads from `ProjectSettings` once, cached for session lifetime.

**`GNNode.supported_renderers()`** — virtual method returning a `PackedStringArray` of compatible renderer strings. Default returns all three (`["forward_plus", "mobile", "gl_compatibility"]`). Operators override this to declare restrictions.

**Cook engine check** — In `cook_frame()`, after the existing `requires_compute()` early-out, a second check compares `node.supported_renderers()` against `_current_renderer`. Incompatible nodes are skipped with a warning badge (same pattern as compute guard: `node_warning` set, `cook_valid = false`, `cook_time_ms = 0`, downstream receives null).

### 34.3 Platform Detection (Phase 2.5 — IMPLEMENTED)

**`GNGpuContext.get_current_platform()`** — static method returning the OS name as a lowercase string (`"windows"`, `"macos"`, `"linux"`, `"android"`, `"ios"`, `"web"`). Wraps `OS.get_name().to_lower()`, cached.

**`GNNode.supported_platforms()`** — virtual method returning a `PackedStringArray` of compatible platform strings. Default returns all six platforms. Operators override this to declare OS-level restrictions.

**Cook engine check** — In `cook_frame()`, after the renderer guard, a third check compares `node.supported_platforms()` against `_current_platform`. Same skip pattern (warning badge, `cook_valid = false`, null downstream).

### 34.4 Why Two Axes

Renderer and platform are orthogonal:
- **ComputeShaderTOP** needs Vulkan/Metal (renderer constraint) but works on any OS that has those GPUs.
- **FFmpegOUT** needs `OS.execute()` (platform constraint) but works on any renderer.
- **WindowOUT** works on ALL renderers AND all platforms — it adapts behavior internally (multi-window on desktop, main-viewport fallback on mobile/web in Phase 6).
- Conflating these into a single axis would wrongly skip WindowOUT on desktop + Compatibility renderer.

### 34.5 Operator Compatibility Matrix

**Tier A — All Renderers, All Platforms** (default, majority of operators):

| Family | Count | Notes |
|--------|-------|-------|
| CHOP   | 68    | CPU-only data processing |
| DAT    | ~30   | String/table operations (except file I/O, see Tier D) |
| SOP    | ~60   | SurfaceTool / ArrayMesh (except file I/O, see Tier D) |
| IMG    | 14    | CPU Image pixel ops |
| COMP   | 20    | Scene tree nodes (Camera, Light, etc.) |
| MAT    | 9     | ShaderMaterial / StandardMaterial3D |
| TOP    | ~70   | SubViewport + `canvas_item` fragment shaders |
| UI     | 31    | Godot Control nodes |
| SDF    | 26    | RaymarchSDF compiles to `canvas_item` fragment shader |
| WindowOUT | 1  | Platform-adaptive: multi-window on desktop, main viewport on mobile/web |
| AudioDeviceOUT | 1 | AudioStreamGenerator works everywhere |
| OscOUT | 1 | UDP works on all platforms with network access |

**Tier B — Renderer-restricted** (no Compatibility / WebGL2):
Operators that require GPU compute (`RenderingDevice` API):

| Operator | Family | Override |
|----------|--------|----------|
| All POP operators (10) | POP | `supported_renderers → ["forward_plus", "mobile"]` |
| All VOL operators (11) | VOL | `supported_renderers → ["forward_plus", "mobile"]` |
| ComputeShaderTOP | TOP | `supported_renderers → ["forward_plus", "mobile"]` |

**Tier C — Renderer-restricted** (Forward+ only):

| Operator | Family | Override |
|----------|--------|----------|
| CompositorEffectTOP | TOP | `supported_renderers → ["forward_plus"]` |

**Tier D — Platform-restricted** (no web):
Operators that require local filesystem, CLI, or platform-specific hardware:

| Operator | Family | Override | Reason |
|----------|--------|----------|--------|
| FFmpegOUT | OUT | `supported_platforms → ["windows", "macos", "linux"]` | Needs `OS.execute()` for ffmpeg CLI |
| FFmpegInTOP | TOP (ext) | `supported_platforms → desktop + mobile` | File access for video decoding |
| VideoDeviceInIMG | IMG (ext) | `supported_platforms → ["windows", "macos", "linux"]` | Native capture APIs (MF/AVF/V4L2) |
| RtMidiInCHOP | CHOP (ext) | `supported_platforms → desktop + mobile` | No MIDI hardware on web |
| RtMidiOutCHOP | CHOP (ext) | `supported_platforms → desktop + mobile` | No MIDI hardware on web |
| FileInDAT | DAT | `supported_platforms → desktop + mobile` | FileAccess to local paths |
| FolderDAT | DAT | `supported_platforms → desktop + mobile` | DirAccess directory listing |
| XMLDAT | DAT | `supported_platforms → desktop + mobile` | FileAccess (file source mode) |
| FileInSOP | SOP | `supported_platforms → desktop + mobile` | FileAccess to OBJ/glTF files |
| FileOutSOP | SOP | `supported_platforms → desktop + mobile` | FileAccess write |
| ImageSaveOUT | OUT | `supported_platforms → desktop + mobile` | Disk write |
| MovieOUT | OUT | `supported_platforms → desktop + mobile` | Disk write sequence |
| TextureSaveOUT | OUT | `supported_platforms → desktop + mobile` | GPU→CPU readback + disk write |
| TableSaveOUT | OUT | `supported_platforms → desktop + mobile` | Disk write |
| RecordOUT | OUT | `supported_platforms → desktop + mobile` | Disk write on save |

**Tier E — Extension-level platform guards** (handled at extension registry level via `gn_extension.cfg`):

| Extension | cfg Guard | Operators |
|-----------|-----------|-----------|
| `gn_ext_spout` | `platforms=["windows"]` | SpoutInTOP, SpoutOutTOP |
| `gn_ext_syphon` | `platforms=["macos"]` | SyphonInTOP, SyphonOutTOP |
| `gn_ext_gpu_encode` | `dependencies=["GNGpuEncoder"]` | MovieFileOutTOP |

**Tier F — All platforms, no guards needed** (pure shader / CPU / Godot APIs):

| Extension | Operators | Why no guards |
|-----------|-----------|---------------|
| `gn_ext_isf` | ISFTOP (1) | Pure `canvas_item` shader compilation |
| `gn_ext_shadertoy` | ShadertoyTOP (1) | Pure `canvas_item` shader + HTTP |
| `gn_ext_sdf` | 26 SDF operators | Shader AST → `canvas_item` raymarcher |
| `gn_ext_mapper` | 7 projection/warp TOPs | Pure `canvas_item` shaders |
| `gn_ext_native` | 64 accelerated ops | Runtime ClassDB fallback to GDScript |

### 34.6 WindowOUT — Platform-Adaptive Design

WindowOUT works on ALL platforms. Instead of being platform-restricted, it adapts internally:

| Platform | Behavior |
|----------|----------|
| Desktop  | Creates a standalone OS `Window` node — multi-monitor, fullscreen, positioning |
| Mobile   | (Phase 6) Renders TextureRect + UI panel into main viewport. `monitor`/`position`/`window_mode` params become no-ops. |
| Web      | (Phase 6) Same as mobile — TextureRect in main viewport, sized to HTML canvas. |

**Multi-WindowOUT validation:** On mobile/web (single-window platforms), if more than one WindowOUT has `open = true`, all but the first display a warning: "Multiple WindowOUT nodes open — [Platform] supports only one window." This is checked every cook frame via a static `_open_instance_ids` tracker.

### 34.7 Shader Compatibility Audit (Phase 2 — IMPLEMENTED)

**All 57 `.gdshader` files** across the project use `shader_type canvas_item` — compatible with all three Godot renderers (Forward+, Mobile, Compatibility/WebGL2).

**GLSL feature audit — CLEAN:**
- No `textureGather` (GLES3 optional, not in WebGL2)
- No `imageStore` / `imageLoad` (compute-only)
- No `texelFetch` with MSAA
- No `layout(binding=...)` beyond WebGL2 limits
- `textureSize()` used in optical_flow.gdshader — supported in GLES3 / WebGL2
- `dFdx` / `dFdy` / `fwidth` — not used in any shader

**Shader translators — all safe:**
- **ShadertoyTranslator** → outputs `shader_type canvas_item` (line 109)
- **ISFTranslator** → outputs `shader_type canvas_item` (line 435)
- **RaymarchSDF** → compiles to `shader_type canvas_item` (line 131)

### 34.8 Web-Specific Limitations (addressed in future phases)

| Limitation | Affected Operators | Status |
|------------|-------------------|--------|
| No local filesystem | FileInDAT, FolderDAT, FileInSOP, FileOutSOP, etc. | ✓ Platform-guarded via `supported_platforms()` |
| No compute shaders | All POP (10), all VOL (11), ComputeShaderTOP, CompositorEffectTOP | ✓ Renderer-guarded via `supported_renderers()` |
| No CLI | FFmpegOUT | ✓ Platform-guarded (desktop only) |
| Single window | WindowOUT | Phase 6 — main viewport fallback + multi-WindowOUT warning (implemented) |
| No `Thread.new()` | Future multi-threaded cook engine | Phase 5 — detect & single-thread |
| No MIDI | MidiInCHOP, MidiInDAT | Extension platform guard |
| SharedArrayBuffer requirement | All (Godot web export) | Phase 7 — document server headers |

### 34.9 Remaining Phases — ALL IMPLEMENTED

- **Phase 3 — CPU Fallback for Compute Operators** ✅: `has_cpu_fallback()` + `_cook_cpu()` virtual methods on GNNode. Cook engine branches: compute unavailable + has_cpu_fallback → call `_cook_cpu()` with full timing/caching. All 11 POP operators + all 11 VOL operators have CPU fallback implementations. GNParticleData/GNVolumeData store CPU-side arrays (zero overhead when GPU path is used — empty arrays are ~24 bytes each). POP CPU fallbacks: SourcePOP (emission + age/death), ForcePOP (gravity/wind/drag), AttractPOP (inverse-square), CollisionPOP (ground plane), TurbulencePOP (FastNoiseLite curl), LimitPOP (bounds/speed), AdvectPOP (velocity field sampling), NullPOP (pass-through), InstancePOP (MultiMesh from CPU arrays), RenderPOP (delegates to read_positions/read_float_attrib). VOL CPU fallbacks: NoiseVOL (FBM), BlurVOL (3D box blur), BlendVOL (6 blend modes), DisplaceVOL (trilinear), NullVOL (pass-through), AnalyzeVOL (statistics), FluidVOL (full Navier-Stokes), CHOPtoVOL (3 fill modes), SOPtoVOL (sphere splatting), MarchingCubesVOL (direct CPU read), RaymarchVOL (CPU ray marcher with Beer-Lambert compositing).
- **Phase 4 — Export Presets & Build Pipeline** ✅: Added Android ARM64 (preset 10, Compatibility renderer, APK, ETC2/ASTC), iOS ARM64 (preset 11, Mobile renderer, IPA), and Web/WASM (preset 12, Compatibility renderer, PWA, thread support enabled) export presets to `export_presets.cfg`. All use `shader_baker/enabled=true`, `embed_pck=true`, `script_export_mode=2`.
- **Phase 5 — Thread Detection** ✅: `GNGpuContext.are_threads_available()` returns false on web. Cook engine caches `_threads_available` flag on first frame, logs thread status at startup.
- **Phase 6 — WindowOUT Mobile/Web Adaptation** ✅: `_embedded_mode` flag detects single-window platforms (android/ios/web). `_ensure_embedded()` creates fullscreen Control → TextureRect + VBoxContainer UI panel in main viewport. Window params (monitor, position, window_mode) become no-ops in embedded mode.
- **Phase 7 — Web Runtime** ✅: `player_main.gd` supports URL-based patch loading via `_fetch_patch_from_url()` (HTTPRequest), browser URL query parameter reading via `_get_url_param()` (JavaScriptBridge), and JS↔GDScript bridge via `_register_js_bridge()` exposing `window.gonodesLoadPatch(url)` and `window.gonodesSetParam(nodeId, paramName, value)`. Signals: `player_ready`, `patch_loaded`, `player_error`.
- **Phase 8 — Export Compatibility Report** ✅: `GNCompatReportPanel` editor panel with platform/renderer dropdowns, live network scan showing incompatible nodes (red = no fallback, yellow = CPU fallback available), 4-column Tree (Node, Family, Issue, Detail), "Copy Report" button for clipboard export. Toggled via "Compat" CheckButton in editor toolbar row 2. Click-to-select navigates to flagged node in graph.

### 34.10 Implementation Files Changed (Phase 1-8)

| File | Change |
|------|--------|
| `addons/gonodes/core/gn_node.gd` | Added `supported_renderers()` + `supported_platforms()` (Phase 1-2), `has_cpu_fallback()` + `_cook_cpu()` (Phase 3) |
| `addons/gonodes/core/gn_gpu_context.gd` | Added `get_current_renderer()` + `get_current_platform()` (Phase 1-2), `are_threads_available()` (Phase 5) |
| `addons/gonodes/core/gn_cook_engine.gd` | Renderer + platform guards (Phase 1-2), CPU fallback branching + `_threads_available` (Phase 3/5) |
| `addons/gonodes/core/gn_particle_data.gd` | CPU mode: `is_cpu`, 7 CPU arrays, updated `has_particles()`/`read_positions()`/`read_float_attrib()`/`duplicate_data()` (Phase 3) |
| `addons/gonodes/core/gn_volume_data.gd` | CPU mode: `is_cpu`, `cpu_data`, updated `has_volume()`/`duplicate_data()` (Phase 3) |
| `addons/gonodes/core/gn_pop_base.gd` | `supported_renderers → ["forward_plus", "mobile"]` (Phase 2), `has_cpu_fallback() → true`, `_allocate_particles_cpu()`, `_get_input_pop_cpu()` (Phase 3) |
| `addons/gonodes/core/gn_vol_base.gd` | `supported_renderers → ["forward_plus", "mobile"]` (Phase 2), `has_cpu_fallback() → true`, CPU helpers (Phase 3) |
| All 11 POP operators | `_cook_cpu()` implementations (Phase 3) |
| All 11 VOL operators | `_cook_cpu()` implementations (Phase 3) |
| `addons/gonodes/operators/output/window_out.gd` | Removed wrong renderer override (Phase 2), multi-WindowOUT warning (Phase 2), embedded mode `_ensure_embedded()` for mobile/web (Phase 6) |
| `scenes/player_main.gd` | Web runtime: `_patch_url`, JS bridge signals, URL fetch, `_register_js_bridge()`, `_get_url_param()` (Phase 7) |
| `addons/gonodes/ui/gn_compat_report_panel.gd` | **NEW** — Export compatibility report panel (Phase 8) |
| `scenes/gn_editor.gd` | Added `compat_panel` + `compat_toggle`, `_setup_compat_panel()`, `_on_compat_toggled()`, updated `_layout_debug_panel()` (Phase 8) |
| `export_presets.cfg` | Added presets 10-12: Android ARM64, iOS ARM64, Web/WASM (Phase 4) |
| `addons/gonodes/operators/top/compute_shader_top.gd` | Override: `supported_renderers → ["forward_plus", "mobile"]` |
| `addons/gonodes/operators/top/compositor_effect_top.gd` | Override: `supported_renderers → ["forward_plus"]` |
| `addons/gonodes/operators/output/ffmpeg_out.gd` | Override: `supported_platforms → ["windows", "macos", "linux"]` |
| `addons/gonodes/operators/dat/file_in_dat.gd` | Override: `supported_platforms → desktop + mobile` |
| `addons/gonodes/operators/dat/folder_dat.gd` | Override: `supported_platforms → desktop + mobile` |
| `addons/gonodes/operators/sop/file_in_sop.gd` | Override: `supported_platforms → desktop + mobile` |
| `addons/gonodes/operators/sop/file_out_sop.gd` | Override: `supported_platforms → desktop + mobile` |
| `addons/gonodes/operators/output/image_save_out.gd` | Override: `supported_platforms → desktop + mobile` |
| `addons/gonodes/operators/output/movie_out.gd` | Override: `supported_platforms → desktop + mobile` |
| `addons/gonodes/operators/output/texture_save_out.gd` | Override: `supported_platforms → desktop + mobile` |
| `addons/gonodes/operators/output/table_save_out.gd` | Override: `supported_platforms → desktop + mobile` |
| `addons/gonodes/operators/output/record_out.gd` | Override: `supported_platforms → desktop + mobile` |
| `addons/gn_ext_ffmpeg/operators/top/ffmpeg_in_top.gd` | Override: `supported_platforms → desktop + mobile` (file access for video) |
| `addons/gn_ext_video_capture/operators/img/video_device_in_img.gd` | Override: `supported_platforms → ["windows", "macos", "linux"]` (native capture APIs) |
| `addons/gn_ext_midi/operators/chop/midi_in_chop.gd` | Override: `supported_platforms → desktop + mobile` (no MIDI on web) |
| `addons/gn_ext_midi/operators/chop/midi_out_chop.gd` | Override: `supported_platforms → desktop + mobile` (no MIDI on web) |
| `dev_docs/CONTRIBUTING.md` | Added "Platform & Renderer Compatibility for Extensions" section |

---

## Session — TD Gap Bridge Implementation

### New Features

| Feature | Files Modified | Description |
|---------|---------------|-------------|
| **Parallel cook engine** | `gn_cook_engine.gd`, `gn_network.gd` | Level-based topological sort with WorkerThreadPool parallel dispatch. CPU-family nodes at the same dependency level cook concurrently; GPU families (TOP/POP/VOL) cook sequentially on main thread. Config: `parallel_cook_enabled`, `parallel_min_batch`. |
| **Named output ports** | `gn_port.gd`, `gn_node.gd`, `gn_node_view.gd`, `gn_help_window.gd`, `gn_main_help_window.gd`, `gn_cook_engine.gd` | Added `label: String` and `display_name()` to GNPort. `add_input`/`add_output` now accept optional `port_label`. UI displays label when set, falls back to port_name. All multi-port operators labeled. Expression functions `output()`, `vol()`, `sop()`, `dat()`, `img()`, `mat()` resolve ports by index, name, or label (case-insensitive) via `GNNode.get_output_data_by_name()`. |
| **.gnasset Edit-in-Place (Phase 3)** | `gn_custom_operator.gd`, `gn_graph_editor.gd`, `gn_editor.gd` | Right-click GNCustomOperator: "Edit Asset" enters edit mode (snapshot + dive-in + Save/Discard/Re-promote banner). "Make Unique" detaches to plain SubNetworkNode. Save writes inner network back to .gnasset, validates promoted params, reloads sibling instances. |
| **Dot routing node** | `operators/dot_node.gd` | Family-agnostic pass-through node for wire routing. Auto-adapts family from connected port via `adapt_to_family()`. |

### New Operators (23)

| Operator | Family | Description |
|----------|--------|-------------|
| KeyframeCHOP | CHOP | Keyframe curve animation via ramp curves sampled over time |
| SequenceCHOP | CHOP | Sequence inputs end-to-end with optional crossfade |
| ClipCHOP | CHOP | Play back recorded CHOP data with transport controls |
| ChannelCHOP | CHOP | Named channels from parameter values (expression-friendly) |
| ObjectCHOP | CHOP | Read COMP transform as tx/ty/tz/rx/ry/rz/sx/sy/sz channels |
| SkeletonCHOP | CHOP | Read Skeleton3D bone transforms with bone filter |
| TabletInCHOP | CHOP | Pen tablet input (position, pressure, tilt) |
| DotNode | CHOP | Wire routing point (family-agnostic pass-through) |
| DeformTOP | TOP | Texture deformation via displacement map (displace/refract/warp) |
| ReorderTOP | TOP | RGBA channel swizzle/reorder |
| SmoothSOP | SOP | Laplacian vertex smoothing with border pinning |
| PolyBevelSOP | SOP | Bevel polygon edges with offset and rounding |
| RemeshSOP | SOP | Retopologize to uniform density via midpoint subdivision |
| ObjectMergeSOP | SOP | Fetch geometry from another SOP by path reference |
| TextureSOP | SOP | Apply TOP texture as vertex color or displacement |
| PolyBridgeSOP | SOP | Bridge two polygon edge loops |
| PolyPatchSOP | SOP | Bilinear Coons patch surface from boundary |
| PolySplineSOP | SOP | Catmull-Rom spline curve/tube/ribbon |
| PolyStitchSOP | SOP | Stitch boundaries by nearest vertex pairs |
| SerialDAT | DAT | Serial port (COM) communication |
| DMXDAT | DAT | DMX/Art-Net lighting protocol controller |
| RenderPickDAT | DAT | Ray-cast object picking from 3D render |
| PanelExecuteDAT | DAT | Log panel/UI events as table rows |

### Updated Totals

Total: **371 operators** (83 TOP, 14 IMG, 76 CHOP, 37 DAT, 71 SOP, 10 POP, 11 VOL, 20 COMP, 9 MAT, 9 OUT, 31 UI). 11 families.

### TD Gap Resolution

| Gap | Status | Notes |
|-----|--------|-------|
| Multi-threaded cook engine | ✅ Implemented | Level-based parallel dispatch via WorkerThreadPool |
| Keyframe animation | ✅ Implemented | KeyframeCHOP, SequenceCHOP, ClipCHOP, ChannelCHOP |
| Named output ports | ✅ Implemented | GNPort.label + display_name() |
| Dot/routing nodes | ✅ Implemented | DotNode with family adaptation |
| ObjectCHOP | ✅ Implemented | Read COMP transforms as channels |
| SkeletonCHOP (Pose/Skeleton) | ✅ Implemented | Bone transform readout with filter |
| PolyBevelSOP | ✅ Implemented | Vertex-pull bevel with divisions |
| SmoothSOP | ✅ Implemented | Iterative Laplacian smoothing |
| RemeshSOP | ✅ Implemented | Midpoint subdivision remeshing |
| SerialDAT | ✅ Implemented | Framework ready (native transport pluggable) |
| DMXDAT | ✅ Implemented | Art-Net UDP protocol |
| RenderPickDAT | ✅ Implemented | Physics ray-cast picking |
| DeformTOP | ✅ Implemented | Shader-based displacement |
| ReorderTOP | ✅ Implemented | Channel swizzle shader |
| ObjectMergeSOP | ✅ Implemented | Reference-based geometry fetch |
| TextureSOP | ✅ Implemented | TOP→vertex color/displacement |
| PolyBridge/Patch/Spline/StitchSOP | ✅ Implemented | 4 poly construction operators |
| TabletInCHOP | ✅ Implemented | Pen/stylus input |
| PanelExecuteDAT | ✅ Implemented | UI event logging |

