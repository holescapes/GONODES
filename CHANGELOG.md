# GONODES Changelog

All notable changes to GONODES are documented here. This changelog is
organized by date and covers major features, operator additions, architecture
changes, and bug fixes.

For the full development journal with implementation details, see
[GONODES_CONTEXT.md](GONODES_CONTEXT.md).

---

## 2026-10-13 — Editor settings stay local

- **README** keeps the Godot essay and a one-line note that every operator has help. Image slots are unchanged.
- **Editor folders:** `.cursor` and `.vscode` are personal and gitignored. The shared brief is `ai/`. Hard rules live in `ai/RULES.md`.
- **Audit notes** moved to `dev_docs/PRE-BETA_AUDIT.md` and `dev_docs/HUMAN_GATE.md`.

## 2026-10-13 — The public page points onward, and agent notes share one folder

- **README** is the public page: what GONODES is, how to start, and links to the user help and the dev docs. Operator and extension tables stay in `docs/OPERATORS.md` and each extension README. Named image slots are `hero`, `patch`, `player`, and `display`.
- **`ai/`** is the brief any model can read. Engine work starts there and then follows the hard rules. Patch writing stays in root `llms.txt`.

## 2026-10-12 — GitHub Actions artifacts expire sooner

- **Extension builds** are kept for 7 days. **Release bundles** are kept for 1 day. The GitHub Release still holds the player and editor downloads. CEF is still uploaded once per Release and already expired after a day.

## 2026-10-12 — Standalone editors download players on first export

- **Release editors** are standalone programs. Godot is packed inside the executable. Each editor ships with the player for its own OS. The first Build for another desktop target or the web downloads that player from the matching GitHub release.
- **Players** in the release cover Windows x86_64, Windows ARM64, Linux x86_64, Linux ARM64, macOS, and web. Android and iOS stay a manual `build_templates` run. A `TEMPLATE_VERSION.txt` stamp makes an editor replace a player from a different Godot or GONODES version.
- **Windows and Linux ARM64 extension builds** download the matching `godot-cpp` library before they link.

## 2026-10-12 — OpenCV and Spout join the extension tier

- **OpenCV** and **Spout** stay in a normal shipped build and drop out of `scons tier=core`. OpenCV on Linux and macOS is skipped until the system package is installed.
- **FFmpeg** has a `native/build.cfg` at `tier = extension` with nothing to compile. The LGPL libraries stay a manual install.

## 2026-10-11 — Permissive SDKs download at build time

- **setup_deps.py and GitHub Actions** use the same `setup` and `vendor_clone` lines. Python, ONNX Runtime, OpenCV, Spout2, Syphon, and CEF are fetched into gitignored folders. YOLOv8 weights are not part of that download.
- **NDI, Blackmagic, Azure Kinect, Ultraleap, and RealSense** stay a manual install. `python scripts/show_manual_sdks.py` prints the download page and the folder the build looks for.
- **Rule 25.48:** a change to a download script, probe path, or Actions step updates the guide in the same change.

## 2026-10-11 — Release builds ship the Python runtime

- **Python nodes** in a GitHub release and in a template export include CPython 3.10 and NumPy. The build downloads them. They are not committed to the repository. NDI, Blackmagic, and the other device runtimes stay out of the download. Those vendors do not allow us to ship their libraries, and compiling GONODES does not change that.

## 2026-10-11 — A background image load cannot crash the editor

- **Logging** from a worker thread is handed to the main thread before it touches the log panel or a toast. A missing picture no longer kills the editor while the graph is opening.

## 2026-10-10 — Outside models get a patch-writing brief

- **`llms.txt`** at the repo root is the plain-Markdown brief for writing a `.gnpatch`. The operator catalog stays in `docs/OPERATORS.md`. Rule 25.47: update the brief in the same change when one of its sentences would become false.

## 2026-10-10 — A feedback Select is not a cook error on the first frame

- **CrossTOP** treats a missing input as the chain warming up. It is a debug line, same as Fit, Cache, and Composite.
- **SelectTOP** with a target that exists but has not cooked yet outputs nothing and does not raise a cook error. A missing target, or a target that is not a texture, still does.

## 2026-10-10 — Player exports omit native extensions the target cannot load

- **Template builds** (`auto`, the default) leave an extension out of a platform export when that OS and architecture has no library on the build machine. The project tree is restored afterward. `-GDExtensions all` still packs every config.

## 2026-10-09 — Opening a patch no longer warns about its own parameters

- **Script and shader nodes** build `@param` and uniform parameters after the file is read, then put the saved values back. Load no longer warns that those names are unknown.
- **A null cook** is an error only when every input already had data. A composite whose picture is not ready yet, with a title texture on the other port, stays quiet.
- **Feedback loops** and a Cache, Fit, or Composite that is still waiting on its input are debug lines.

## 2026-10-09 — CHOPtoTOP follows key and mouse channels

- **KeyboardIn and MouseIn** no longer emit a `window_name` channel hashed from the window title. That value sat near two billion, so CHOPtoTOP auto-range crushed every 0–1 line onto one pixel and the output window looked frozen.
- **CHOPtoTOP** keeps one Image and one ImageTexture. It redraws only when the samples, style, or fitted range change. It does not create a SubViewport. WindowOUT redraws when that texture is updated in place.

## 2026-10-09 — Logs keep every line, including Godot's

- **Logs** are captured whether or not the log panel is open. The panel only draws, and it keeps the latest 50 lines unless Preferences changes that. Debug cook lines stay off until the DBG filter or Log Level asks for them.
- **Log file name** in Preferences (empty by default) writes the full log next to the current patch. An unsaved patch holds those lines until the first save.
- **Log lines** are colored by severity. The panel hides DBG by default.
- **Bottom panels** restack from the toolbar whenever Logs, Debug, Compat, or Takes is toggled. A closed panel does not process, scan, or draw.
- **Startup lines** are captured from plugin load onward, including the extension scan. Godot's version and GPU line are rebuilt. Its codec list is printed before any addon runs, so it is not copied.
- **Godot's own prints, warnings, and errors** are copied into that same log under the Godot category. They are not printed again.
- **ErrorDAT** connects to the logger when the node is initialized. A startup probe was connecting a copy that had no parameters, so the next log line warned `unknown parameter 'level_filter'`.
- **A null cook** is logged only when the node received real input. An image or texture that has no pixels yet is a load still in flight, so ImgToTOP stays quiet until the file arrives.

## 2026-10-09 — LayoutTOP spare input grows

- **ParameterCHOP** finds its target through the cook engine. It was walking the scene tree for a GNNetwork, which operators are not parented to, so the channel list stayed empty and CHOPtoTOP cooked null.
- **ImageSequenceIMG** uses the same resolution rule. `(0, 0)` stays native. A resize happens only when both sides are greater than 0.

- **LayoutTOP** opts into dynamic inputs. Connecting the unnamed spare adds the next input, up to the 8 textures the shader can sample. It used to draw that spare and then ignore it.

## 2026-10-08 — Cook only when the node is actually live

- **`GNNode.update_time_dependency()`** — operators set `time_dependent` from their own logic each frame (rate, playback, jitter, a time-dependent target). Not a user toggle. NoiseTOP is still unless `time_offset` reads time; NoiseSOP / Voronoi / Ripple / ScanLine / FilmGrain follow the same rule. ParameterCHOP, ParameterDAT, and ObjectCHOP follow the target. ErrorDAT dirties from the log sink. SystemDAT cooks every frame only while memory is shown. ImageSequence cooks every frame only while playing.
- **Expression eval** — nodes with no expressions skip `_try_expression_dirty`. Time builtins re-eval; constant expressions do not.
- **Active set** — a leftover expression string on a CONSTANT param no longer rebuilds topology. Topo rebuilds only when expression edges change.
- **Parallel cook** stamps per-port demand before worker `_cook`.
- **Editor** — reference overlay, previews, and status badges redraw only when their inputs change. Status badges update for nodes that cooked or whose warning text changed.
- **One reference scan** — `GNReferenceScanner.scan_node` captures reads and call names together. Wireless family demand and the inspector reuse that cache. `MovieFileIn` cooks every frame only while playing at non-zero speed. `TimeMachine` cooks every frame in Speed (non-zero) and Ramp modes. `Glitch` cooks every frame only while intensity, channel shift, or tears are on.
- **Active-set cook loop** — pre-cook and both cook paths iterate the active nodes only. Live nodes whose elapsed time moved skip the parameter hash. The editor clears warnings only on nodes that have one, and refreshes a viewer only when that node cooked.
- **Component expressions** mark the node dirty when a single vector component changes. `ExpressionCHOP` is live only when its expression reads time. `HoldCHOP` cooks from its inputs. Lag, Filter, and Smooth stop cooking once their output settles.

## 2026-10-07 — Graph dependency UX + async I/O rollout

- **Graph reference overlay (A–D)** — read lines (cyan), static write lines (`set_par`, `network_connect`, `# @affects`), runtime side-effect lines from last cook, wireless hover refs. All on by default; toggles + colors in **Preferences → Graph References**.
- **`GNReferenceScanner`** — shared static scan for cook demand and graph overlay; `# @affects node[:param]` in script/callback bodies.
- **Runtime side-effect ledger** — `set_par` / `network_connect` recorded per cook frame; inspector **Dependencies** panel (Reads / Writes / Wired inputs / Referenced by).
- **Async / keep_dirty** — FileInDAT `async_load`, ImageSequenceIMG per-frame async, WebDAT pending fetch, FileInSOP URL pending, AudioFileInCHOP, TextureSaveOUT GPU readback.
- **Tests:** `test_reference_scanner`, cook pipeline side-effect ledger, WebDAT keep_dirty, FileInDAT async.

## 2026-10-07 — Cook-chain hardening (async requeue, SCRIPT demand, Select wireless)

- **`GNNode.keep_dirty_after_cook`** — operators that need a follow-up frame (async ImageFileIn, TOPtoIMG ViewportTexture lag, Bloom pipeline rebuild) set this during `_cook`; `execute_cook` restores dirty and invalidates the input-hash guard. Replaces fragile `call_deferred("mark_dirty")`.
- **SCRIPT / Native / Python code bodies** — cook engine scans `code` / `py_source` / `cpp_source` STRING params for `chop()`/`dat()`/… so wireless demand and the active set match expression refs (no `@input`-only workaround).
- **Select\*** — drop blanket `time_dependent`; rely on wireless consumer dirty + remote input hash. Resolve owning network via `get_owning_network()` (CookEngine parent).
- **Tests:** `test_cook_pipeline` — script code-body demand, SelectCHOP wireless update, ImageFileIn async via `cook_frame`; img unit asserts keep-dirty while pending.

## 2026-10-07 — RichTextTOP
- **RichTextTOP** — BBCode multi-style text → texture via `RichTextLabel` (bold/color/size spans, outline/shadow/margin, transparent HUD overlays). 588 operators / TOP 140.

## 2026-10-07 — Multiline string params in inspector
- **GNParameter** — `create_string(..., multiline=true)` / `is_multiline` flag
- **GNParamRow** — multiline strings use an editable `TextEdit` (not a one-line `LineEdit`)
- Enabled for **TextTOP**, **TextDAT**, **JSONDAT** `json_string`, **WebDAT** `body`, **LabelUI**, **RichTextLabelUI**, **FontSOP**

## 2026-10-07 — IMG viewer format mismatch on update
- **GNImageRenderer** — recreate `ImageTexture` when image format changes (not only size). Fixes `ImageTexture.update()` error when switching JPG/RGB8 ↔ PNG/RGBA8 at the same resolution.

## 2026-10-06 — Player READY smoke marker (WindowOUT)

- Player logs `[GONODES_PLAYER_READY]` once open WindowOUT sinks cook with a texture and no cook errors (also `player_ready.ok` next to the exe). Failures/timeouts write `[GONODES_PLAYER_READY_FAIL]` / `[GONODES_PLAYER_READY_TIMEOUT]` + `player_ready.fail`.
- **Export fix:** Player/Editor presets now `include_filter="*.cfg"` (and exclude `export_presets.cfg`) so `gn_core.cfg` / `gn_extension.cfg` ship in the `.pck`. Without this, exported Players loaded every operator as a placeholder.

## 2026-10-06 — BitRots operators (TouchPaint, FileCopy, async ImageFileIn)

### New operators
- **TouchPaintTOP** — accumulate grayscale radial touch/damage mask for sort regions
- **FileCopyOUT** — rising-edge atomic file copy (seed day folders from display assets)

### Enhanced
- **TextTOP** — outline + drop shadow via Godot Label theme overrides; transparent bg for overlays
- **TextureSaveOUT** — Continuous | Pulse Once save modes; resolve `project://` before mkdir
- **ImageFileInIMG** — `async_load` worker-thread preload holding last good frame (`keep_dirty_after_cook` requeue)
- **FolderDAT** — `project://` resolve, Name/Modified sort, size via `get_length`, modified column
- **File picker (GNParamRow)** — `*.*` means all files; keep current `project://` selection when scan misses

### Exhibition
- BitRots patch lives under `Projects/BIT ROTS/` (outside this repo). MouseIn + FolderDAT can use SCRIPT body `chop()`/`dat()` demand (no `@input` required for cook activation).

---

## 2026-10-02 — Degrees match the inspector, and a window cooks on open

- **PatternTOP, TriangleTOP, TransformTOP, ProjectionTOP, FeedbackTOP, and TwirlTOP** rotation and twist values are degrees, matching the inspector.
- **Opening a patch** cooks its WindowOUT without selecting a node first.
- **FeedbackTOP** keeps the previous frame on a second viewport.
- **BoidsPOP** samples up to 48 other particles instead of every particle.
- **Menu parameters** accept an expression that returns the option index or the option name.
- **Expression compile** no longer writes a cast on the same line as `return`, which was stopping the editor.

---

## 2026-06-XX — libgonodes v2.5: Direct Bridge Architecture

### Architecture
- **Eliminated per-frame env-var IPC layer** (~490 lines removed from
  `gonodes_bootstrap.cpp`). The `gn_dispatch_queue_to_env()` and
  `gn_collect_responses_from_env()` functions are deleted entirely.
- **GNHostBridge GDExtension** moved to dedicated `addons/gn_ext_host_bridge/`
  extension. Extended with `drain_commands()` (reads C command queue directly)
  and `set_*_output()` methods (writes to C response slots directly).
- **Single inbound/outbound path:** Commands flow C → ring buffer →
  `GNHostBridge.drain_commands()` → GDScript. Responses flow GDScript →
  `GNHostBridge.set_*_output()` → C struct fields. No string formatting,
  no getenv/setenv per frame.
- **One remaining env var:** `GONODES_BRIDGE_INSTANCE_PTR` set once during
  `gonodes_create()` for initial pointer registration. GPU context env vars
  in `gn_bootstrap_init()` remain for one-time Vulkan/GL/Metal device
  injection.

### GNEmbeddedHost (GDScript)
- `_poll_commands()` (230 lines, env var iteration) replaced by
  `_drain_and_dispatch()` (150 lines, direct command dispatch from Array).
- `_publish_introspection()` (100 lines, env var writes) replaced by
  `_publish_to_bridge()` (90 lines, direct `GNHostBridge.set_*()` calls).
- `_get_possible_chop_channels()` helper removed (commands carry exact
  channel names now).
- Pixel/geometry/volume/particle input handlers rewritten to accept
  command fields directly instead of parsing CSV from env vars.

### Version
- libgonodes bumped from 2.0.0 to 2.5.0.

---

## 2026-06-12 — Unified GPU Architecture, NET Family, Viewer Readback Elimination

### Architecture
- **Unified single-device GPU model:** GNGpuContext now uses one
  RenderingDevice (`rd = main_rd = RenderingServer.get_rendering_device()`).
  Removed local device creation. `dispatch()` is fire-and-forget (no
  `submit()`/`sync()`). All `*_on_main()` helpers delegate to base
  equivalents for backward compatibility.
- **NET family:** New family for network infrastructure operators. 15
  operators moved from COMP/OUT/TOP/CHOP/DAT/VOL/POP/SOP to NET:
  SubNetworkNode, InTunnel, OutTunnel, HostIn{TOP,CHOP,DAT,VOL,POP,SOP},
  HostOut{TOP,CHOP,DAT,VOL,POP,SOP}. All now live in `operators/net/`.
- **POP viewer zero-copy:** `render_pop_gpu()` replaces MultiMesh/SubViewport
  with compute shader → Texture2DRD (uses `point_cloud_render.glsl`).
  GNParticleRenderer rewritten to ~20 lines.
- **VOL viewer zero-copy:** New `vol_viewer_composite.glsl` compute shader
  and `render_vol_gpu()` helper. 2×2 slice composite + MIP rendered entirely
  on GPU → Texture2DRD. GNVolumeRenderer simplified.
- **PointCloudRenderTOP simplified:** Removed SSBO bulk copy (POP buffer now
  on same device). Binds `pd.rd_buffer` directly — true zero-copy.
- **SnapshotTOP updated:** POP/VOL modes now use GPU paths
  (`render_pop_gpu()`, `render_vol_gpu()`). POP viewport infrastructure
  removed.
- **Host I/O manifest:** `gn_network.gd generate_host_io()` now covers all
  6 data families (was missing VOL, POP, SOP).

### New Files
- `shaders/vol/vol_viewer_composite.glsl` — GPU compute shader for volume
  viewer 2×2 slice/MIP composite.

---

## 2026-04-10 — Pattern Matching, Paste from JSON, Bug Fixes

### New Features
- **Global pattern matching system (GNPattern):** New static utility class
  (`addons/gonodes/core/gn_pattern.gd`) providing glob matching, multi-pattern
  CSV with `!` exclusion, index ranges with stride/take-skip, pattern expansion
  (`[1-4]`, `[rgb]`, cartesian product), and wildcard capture rename (`*(0)`,
  `?(0)`). Inspired by TouchDesigner and Houdini pattern systems. Full docs in
  `dev_docs/PATTERNS.md`.
- **Operators retrofitted to use GNPattern:** SelectCHOP, DeleteCHOP (+ new
  "By Index Range" mode), RenameCHOP (+ new Pattern mode with capture),
  OPFindDAT, FolderDAT — all now delegate to GNPattern instead of inline
  pattern matching.
- **Paste from JSON:** New right-click menu item "Paste from JSON" in the graph
  editor. Reads JSON from the OS clipboard, normalizes connection key formats
  (`"from"/"to"` and `"from_node"/"to_node"`), and pastes with full ID
  deduplication, mouse-position centering, and undo support. Accepts both
  "Copy as JSON" output and raw `.gnpatch` snippets.
- **Unsaved changes guard:** Editor now tracks `_modified` flag, shows `*` in
  title bar for dirty patches, and prompts Save/Don't Save/Cancel on New, Open,
  and window close (WM_CLOSE_REQUEST).

### Bug Fixes
- **depth_of_field.gdshader:** Removed illegal `return` in `fragment()` and
  replaced `switch` with `if/else if/else` (not supported in Godot shading
  language).
- **motion_blur.gdshader:** Fixed invisible blur — velocity was divided by
  texture pixel size, reducing flow-map-driven offset to sub-pixel values.
- **lut_top.gd:** Fixed `project://` paths not being resolved before
  `FileAccess.open()`. Now uses `GNResourceLoader.resolve()`. Added
  `node_error` messages for path resolution failures, missing files, and
  unsupported formats.
- **lut_top.gd:** Fixed `split_floats()` type mismatch in `.3dl` parser
  (`PackedFloat64Array` assigned to `PackedStringArray`).
- **gn_editor.gd:** Added missing `var _modified: bool` declaration. Fixed
  dangling one-shot connection when user cancels Save-As after choosing "Save"
  in the unsaved-changes dialog. Fixed "Don't Save" not updating title bar.

---

## 2026-04-02 — Viewer Architecture v2: Nodes Own Rendering

### Architecture
- **Viewer panel stripped to minimal host:** `GNViewerPanel` reduced from ~1530
  to ~440 lines.  The viewer now provides four display modes — `set_texture()`
  (pan/zoom), `set_control()`, `set_info()`, and `get_3d_viewport()` (lazy 3D
  SubViewport) — and forwards all input to the node via `handle_viewer_input()`.
  Family-specific viewports, orbit cameras, waveform widgets, volume slice logic,
  and extension display handlers all removed from the viewer.
- **Renamed:** `display_in_viewer()` → `render_for_viewer()` across all 11 family
  bases and 10 COMP operators.  `GNViewerRenderer` → `GNViewerRenderHelpers`.
- **Static shared viewer objects:** 3D families (SOP, POP, MAT) own static scene
  nodes (`_viewer_camera`, `_viewer_light`, `_viewer_mesh_instance`, etc.) with
  `_viewer_` prefix.  These are reparented into the viewer's shared 3D SubViewport
  on each render, eliminating per-family viewport overhead.
- **Node-owned interaction:** SOP/POP handle orbit via `handle_viewer_input()` →
  `GNViewerRenderHelpers.handle_orbit_input()`.  VOL handles slice scroll via
  `handle_scroll_input()`.  Viewer re-renders by calling `render_for_viewer()`
  after input is consumed.
- **Extension display handlers deprecated:** Extensions now override
  `render_for_viewer()` directly instead of registering via
  `GNViewerPanel.register_display_handler()`.  SDF extension updated as reference.

---

## 2026-04-01 — Houdini-Style Parameter Controls & Rangeless Transforms

### UI
- **GNFloatField — Houdini-style numeric control:** New `GNFloatField` widget replaces all HSlider+SpinBox combos for Float/Int inspector params. Click to type, horizontal drag for virtual slider, middle-button drag for ladder tier picker (×0.001 through ×100 with per-pixel sensitivity display), Shift=fine (÷10), Ctrl=coarse (×10), Ctrl+Click=reset to default. Ranged params show a fill bar; rangeless params show darker background with ◂ ▸ arrow indicators. Full-screen input blocker during ladder pick prevents accidental UI interaction.
- **Viewer auto-resize:** Viewer panel SubViewports (SOP, MAT, POP, UI) and all display rects now auto-resize when the panel is resized. Uses a debounced timer (0.15s) so the resize fires once after the user finishes dragging — no continuous re-rendering during the drag.

### Parameters
- **Rangeless transform params:** All translate, rotate, and scale parameters across 14 operator files (11 COMPs + TransformSOP + TransformCHOP + TransformSOPNative) changed from hardcoded numeric ranges to fully unclamped (`null` min/max). Rotation was previously clamped to ±360° or ±90°, scale to 0.001–100, animation translate to ±100 — all now rangeless.

---

## 2026-03-30 — Viewer Refactor, time_dependent Audit, Clipboard Export, Debug Panel UX

### Architecture
- **Viewer refactor — node-driven display dispatch:** Added `display_in_viewer(viewer)`
  virtual method to `GNNode` base class. All 10 family base classes (TOP, IMG,
  CHOP, DAT, SOP, MAT, COMP, POP, VOL, UI) override it with family-appropriate
  visualization. `GNViewerPanel.update_from_node()` simplified from ~100-line
  if/elif cascade to a single `node.display_in_viewer(self)` call. Legacy
  extension display handlers preserved via `has_ext_display_handler()` /
  `call_ext_display_handler()` fallback in the GNNode base.
- **GNViewerPanel public API:** New typed methods — `show_image()`,
  `show_waveform()`, `show_spreadsheet()`, `show_3d_mesh()`, `show_material()`,
  `show_pop_particles()`, `show_vol_slices()`, `show_ui_preview()`,
  `update_zoom_label()` — called by family bases instead of the viewer
  switching modes internally.

### Bug Fixes
- **TOPtoIMG black output fix:** `get_image()` on ViewportTexture during cook
  returned stale/black pixels because the upstream SubViewport hadn't rendered
  yet (Godot defers viewport rendering to end-of-frame). Fixed with a
  `_readback_pending` one-frame delay pattern — first cook returns previous
  cache and schedules a second cook via `mark_dirty()`, second cook performs
  the actual GPU→CPU readback.
- **time_dependent audit — 8 operators fixed:** Removed incorrect
  `time_dependent = true` from operators that are pure functions of their inputs:
  - Core: PointCloudRenderTOP, HostInTOP, FIFODAT, HostInDAT
  - ML extension: StyleTransferTOP, SegmentationTOP, DepthEstimateTOP,
    ObjectDetectDAT
  These operators were unnecessarily re-cooking every frame.

### New Features
- **Graph editor clipboard export** — three new context menu items:
  - "Copy as JSON" — selected nodes + connections as pretty-printed JSON
  - "Copy Debug Info" — single node's full state dump (type, family, params,
    output summary, connections, warnings, time_dependent, cook_time)
  - "Copy Network JSON" — entire network as JSON (all nodes + connections)
- **Debug panel clipboard & multi-select:**
  - All three Tree tabs (Cook Chain, Active Chains, Param Refs) now support
    multi-row selection (Ctrl+click, Shift+click)
  - "Copy Selected" button — copies selected rows as tab-separated text with
    column headers (also bound to Ctrl+C)
  - "Copy All" button — copies every row from the current tab to clipboard
    (preserves tree hierarchy indentation for Active Chains tab)

### Documentation
- Updated EDITOR.md, help/editor.md, help/troubleshooting.md, GONODES_CONTEXT.md

---

## 2026-03-29 — Host I/O Manifest, SinkOUT, CI Workflows, Example Apps

### New Operators (1)
- **SinkOUT** — multi-family keep-alive sink for headless chains. Accepts any
  family input, toggleable `active` parameter controls `is_sink` status. No
  viewer, no window — pure cook-chain preservation.

### New Features
- **Host I/O Manifest** — standardized `.gnpatch` interface contract for
  LibGodot embedding. Patches declare inputs (texture/CHOP/DAT), outputs, and
  exposed parameters in a `host_io` JSON key. Auto-generated from bridge
  operators if not authored manually.
  - `gn_network.gd`: `host_io` variable, `generate_host_io()`, serialization
  - `gn_embedded_host.gd`: `get_host_io()`, `GONODES_HOST_IO` env var
  - `gonodes_host.h`: `gonodes_get_host_io()` C API function
  - Editor: "Host I/O" toolbar button + manifest dialog with JSON editor
- **GitHub Actions CI/CD** — two new workflows:
  - `release.yml` — full release pipeline on `v*` tags (build, test, export, release)
  - `tests.yml` — headless test suite on push/PR

### Example Apps
- All 5 host examples (sdl_host, vulkan_host, opengl_host, metal_host,
  params_demo) now query `gonodes_get_host_io()` after patch load
- 3 new example patches with varied I/O profiles:
  - `video_mixer.gnpatch` — 2 TOP + 1 CHOP in, 1 TOP out (camera mixing)
  - `data_pipeline.gnpatch` — 1 DAT + 1 CHOP in, 1 DAT + 1 CHOP out (headless)
  - `sensor_viz.gnpatch` — 1 CHOP in, 1 TOP + 1 CHOP out (cross-family)
- Existing patches (`show.gnpatch`, `params_test.gnpatch`) updated with
  `host_io` manifests

### Documentation
- Updated all docs to 535 operators, 14 OUT family operators
- `dev_docs/INTEGRATION.md` — full Host I/O Manifest section (format spec,
  auto-generation, C API, editor workflow, backward compatibility)
- `libgonodes/README.md` — Host I/O section + example patches table
- All example READMEs updated for Host I/O

---

## 2026-03-27 — Full Codebase Audit & Script Consolidation

### Architecture
- **Script operator consolidation** — Replaced 4 per-family script operators
  (ScriptCHOP, ScriptDAT, ScriptSOP, ScriptIMG) and GenericScriptNode with
  a single **GDScriptSCRIPT** operator using a Template dropdown (CHOP, SOP,
  DAT, IMG, Generic). SCRIPT family now has 3 operators: GDScriptSCRIPT,
  PythonSCRIPT, NativeSCRIPT.
- **Extension decoupling** — Core UI files (viewer panel, code editor, param
  row) have zero hardcoded extension references. All coupling flows through
  3 static registries + boot scripts.
- **SDF family migration** — SDF operators moved from core to `gn_ext_sdf`
  extension with runtime family registration via boot script.

### Fixes
- Fixed `_SCRIPT_NODE_TYPES` in `gn_network.gd` (was listing deleted per-family
  script node types)
- Fixed `assert_equal` → `assert_eq` in `gn_ext_user_python` test file
- Added headless guard to SDF boot script

### Documentation
- Updated all docs to reflect 535 operators across 13 families
- Updated test counts to 1,355 across 31+ test files
- Created `dev_docs/EXTENSIONS.md` — extension system architecture deep-dive
- Created `dev_docs/DATA_TYPES.md` — data type hierarchy and COW model
- Created `help/scripting.md` — user-facing scripting guide
- Regenerated `scripts/operator_registry.json` (removed 5 stale entries)
- Updated GONODES_VS_THE_REST.md, CONTRIBUTING.md, TESTING.md, README.md,
  getting_started.md, extensions.md

---

## 2026-03-24 — Preview Refactor & Extension Registry

### Architecture
- **Preview system refactor** — Consolidated node preview rendering into
  `GNViewerRenderHelpers` with cached texture reuse for IMG stability.
- **GNExtensionRegistry** — Dynamic operator loading from `gn_ext_*` addon
  folders via `gn_extension.cfg` manifests with platform/architecture/renderer
  guards.

---

## 2026-03-20 — TouchDesigner Comparison & Parity Audit

### Documentation
- Created `dev_docs/GONODES_VS_THE_REST.md` — consolidated 19-section comparison
  of GONODES vs TouchDesigner, VVVV, Houdini covering cook models, GPU pipeline,
  parameters, scripting, I/O, and operator coverage.
- Feature parity audit: 26/27 items complete.

---

## 2026-03-10 — Native C++ Acceleration (Phase 6 Complete)

### New Features
- **92 native C++ operators** across 6 families (42 SOP, 23 CHOP, 5 IMG,
  4 TOP, 9 VOL, 9 POP) via GDExtension.
- GDScript wrapper operators with automatic fallback when C++ binaries are
  unavailable.
- CI pipelines: GitHub Actions + GitLab CI for 5 platform targets.

### Architecture
- Unified build system: `build/gn_build.py` + declarative `build.cfg` per
  extension + `build/SConstruct` root orchestrator.
- ARM64 GDExtension support for Linux + Windows.

---

## 2026-03-06 — TD Parity Operators & Help Patch Overhaul

### New Operators (15)
- **SOPs:** FuseSOP, RaySOP, CapSOP, LatticeSOP, PolyLoftSOP, MountainSOP
- **CHOPs:** BeatCHOP, IKCHOP, WarpCHOP
- **TOPs:** OpticalFlowTOP, EmbossTOP, GlueTOP
- **DATs:** TableDAT, NetworkDAT
- **COMPs:** ReplicatorCOMP

### Fixes
- All 1,084 help patches updated to end with WindowOUT (512×512) via
  family-appropriate visualization chains (Hard Rule 25.22).
- Fixed pass-through COMP chain in 4 help patches (AnimationCOMP, NullCOMP,
  SwitchCOMP dead-end branches).

---

## 2026-03-05 — POP & VOL Families (GPU Compute)

### New Families
- **POP** (GPU Particles) — 20 operators. SSBO-based GPU particle system with
  compute shaders, double-buffered dispatches, CPU readback for SOP/CHOP bridging.
- **VOL** (3D Volumes) — 22 operators. Texture3D compute volumes with
  Navier-Stokes fluid sim, raymarching, marching cubes, POP-VOL advection.

### Infrastructure
- `GNGpuContext` singleton for shared RenderingDevice
- Compute shader detection + graceful degradation on OpenGL/WebGL2
- `requires_compute()` virtual on GNNode, cook engine skip logic with ⚠ badge

---

## 2026-03-04 — Main Help Window & Code Editor

### New Features
- **Main Help Window** (F1) — centralized reference hub with sidebar navigation,
  Markdown→BBCode rendering, 8 guide sections + per-operator auto-generated docs.
- **Code editor integration** — windowed editor for Script operators and
  CustomShaderTOP with syntax highlighting, presets, and "Edit ↗" button.
- **35 presets** across 7 script/shader categories.

---

## 2026-03-03 — UI Family (31 Widgets)

### New Family
- **UI** (User Interface) — 31 interactive 2D widget operators.
- Separated-context architecture: interactive panels via WindowOUT panel port
  (SubViewportContainer with native input), render-to-texture via PanelTOP.
- GNUiBase base class with automatic state CHOP output.
- 99 help patches in `help/ui/`.

### Removed
- `panel_sources` removed from GNTextureData and all TOPs — replaced by the
  separated-context panel architecture.

---

## 2026-02 — Timeline & Cue System

### New Features
- **Engine Transport** — frame range, speed, seek, step, loop modes on
  GNCookEngine. Expression functions: `fps()`, `speed()`, `tstart()`, `tend()`.
- **TimelineCHOP** — independent local time sources.
- **CueDAT + CueCHOP** — show control / cue sequencing.
- **Editor Timeline UI** — visual scrubbing, transport controls in toolbar.

---

## 2026-02 — Take System

### New Features
- **GNTakeManager** — named parameter layer overrides for live performance.
  Capture base, capture sparse delta, instant apply, revert, type-aware blend
  (float/int/Color/Vector). Serialization to `.gntake` JSON.
- Take panel UI with blend slider (0–100%).

---

## 2026-02 — Scripting & Network API

### New Features
- **GDScriptSCRIPT** — multi-output via `# @output` annotations, extends GNNode
  directly, template dropdown for CHOP/SOP/DAT/IMG/Generic.
- **CallbackDAT** — event-driven scripting: `on_start`, `on_cook`,
  `on_value_change`, `on_create` with rolling event log table.
- **`set_par()`** — writable parameter references (self and cross-node) with
  auto-dirty propagation.
- **Network API** — `network_add_node()`, `network_remove_node()`,
  `network_connect()`, `network_disconnect()`, `network_node_ids()`,
  `network_node_info()` for procedural graph construction from scripts.

---

## 2026-01 — Custom Operator Assets & Spare Parameters

### New Features
- **Custom Operator Assets (.gnasset)** — save sub-networks as reusable operators
  with parameter proxying and compact serialization.
- **Spare Parameters** — Houdini-style add-any-param-to-any-node system
  (Float, Int, Bool, String, Color, Vector2, Vector2i).

---

## 2026-01 — 3D Scene Pipeline & Physics

### New Features
- **3D scene pipeline** — SOP → MAT → COMP → RenderTOP with per-object
  materials, shadow system, and MergeCOMP scene composition.
- **Jolt Physics COMPs** — RigidBodyCOMP, StaticBodyCOMP, SoftBodyCOMP,
  AreaCOMP, JointCOMP. PhysicsCHOP bridge for transform readback.
- **InstanceCOMP** — MultiMesh instancing with point cloud placement, CHOP
  animation, per-instance color and uniform scale.
- **EnvironmentCOMP** — dedicated environment/post-processing COMP.

---

## 2025-12 — Operator Expansion

### New Operators (36+)
- 6 TOPs, 7 CHOPs, 10 DATs, 7 SOPs, 2 COMPs, 4 MATs (closing final TD gap)
- 13 advanced operators: LSystemSOP, MetaballSOP, IsoSurfaceSOP, ParticleSOP,
  MagnetSOP, CarveSOP, PolyReduceSOP, CHOPtoSOP, DATtoSOP, TOPtoSOP,
  CHOPtoTOP, InstanceCOMP
- 23 additional TOPs (AnalyzeTOP through TriangleTOP)
- 20 additional CHOPs (SmoothCHOP through ExpressionCHOP)
- 17 additional SOPs (NormalSOP through SkinSOP)

---

## 2025-11 — Core Foundation

### New Features
- **Cook engine** — frame-driven topological sort with active chain cooking,
  input hash guard, parallel cook via WorkerThreadPool.
- **Expression system** — `chop()`, `op()`, `top()`, `par()`, `set_par()`
  with autocomplete and auto-rename.
- **Node graph UI** — GraphEdit canvas, inspector panel, viewer, palette.
- **Save/load** — `.gnpatch` JSON format with full serialization round-trip.
- **Undo/redo, copy/paste, bypass, lock** — all wired up.
- **Ramp parameter type** with cubic Hermite curve editor.
- **Canvas annotations** — network boxes and sticky notes.
- **Debug window (F2)** — 3-tab debug panel + 5-layer graph overlay.
- **MVP operators** — initial TOP, CHOP, SOP, DAT, MAT, COMP, IMG, OUT families.
- **GONODES Player** — standalone export via Quick Build system.
- **LibGONODES** — C API for embedding in host applications via LibGodot.

---

## Extensions

The following extensions ship with GONODES:

| Extension | Description |
|-----------|-------------|
| Shadertoy | Paste any `mainImage` GLSL shader — auto-translated uniforms |
| ISF | Interactive Shader Format v2 with auto-generated parameters |
| HAP | GPU-direct video codec (S3TC/DXT) |
| Spout | Windows GPU texture sharing |
| Syphon | macOS GPU texture sharing |
| Video Capture | Cross-platform webcam input |
| MIDI | RtMidi I/O — notes, CC, pitch bend |
| GPU Encode | Hardware H.264 MP4 recording |
| Mapper | Projection mapping toolkit |
| SDF | Signed distance field composition (26 operators, own family) |
| Serial | Serial port I/O |
| NDI | NDI video/audio network I/O |
| ML | ONNX Runtime inference (pose, hand, face, depth, etc.) |
| Depth Sensor | Azure Kinect + RealSense + Ultraleap |
| Blackmagic | Capture card input/output |
| User Native | Custom C++ operators with hot-reload |
| User Python | Custom Python operators with NumPy |
| Native | 92 C++ accelerated core operator variants |
