# Troubleshooting & FAQ

Common issues, debugging techniques, and performance tips for GONODES.

---

## Debugging Tools

### Node Error & Warning Badges

Nodes display status badges in their title bar:

| Badge | Color | Meaning |
|-------|-------|---------|
| ✖ | Red | Cook error — hover for details |
| ⚠ | Yellow | Warning — hover for details |

Errors and warnings are set during `cook()` and cleared each cycle.
If a badge persists, the issue recurs every frame.

### Bypass (B Key)

Press **B** on selected nodes to toggle bypass. A bypassed node passes
its first input through unchanged and shows a ⏩ indicator. Use this to:

- Isolate which node in a chain causes a problem
- A/B test with and without an effect
- Temporarily disable expensive processing

### Lock (L Key)

Press **L** to lock selected nodes. Locked nodes show a 🔒 indicator
and their parameters become read-only in the inspector. Use this to
protect reference setups from accidental changes.

### Performance Overlay

Toggle the **Perf** button in the toolbar to show per-node cook times
overlaid on the graph. Format: `✓ 0.12ms` or `✗ 0.45ms`. Helps identify
which nodes are expensive.

### VRAM Monitor

Toggle the **VRAM** button in the toolbar to show GPU memory usage in
the info bar. Useful for tracking texture memory when working with
many TOPs.

### GNLogger

GONODES uses an internal logging system. Categories include CookEngine,
Editor, Network, Extensions, etc. Errors route to Godot's `push_error()`,
warnings to `push_warning()`, and info/debug to `print()`. Check the
Godot Output panel for messages.

### Debug Panel (F2)

Press **F2** to open the debug panel below the graph. Three tabs:

- **Cook Chain** — see every node's cook order, status, and timing
- **Active Chains** — tree view of which nodes feed each sink
- **Param Refs** — all expressions and what they reference

Multi-select rows (Ctrl+click, Shift+click) and use **Copy Selected** or
**Copy All** to export debug data to clipboard as tab-separated text.

### Clipboard Export (Right-Click)

Three context menu items for sharing debug information:

- **Copy Debug Info** — select one node, right-click → copies its full state
  (type, params, output, connections, warnings, cook time) as JSON
- **Copy as JSON** — copies selected nodes + connections as JSON
- **Copy Network JSON** — copies the entire network as JSON

Paste into a text editor, bug report, or chat for easy sharing.

---

## Common Issues

### "Node produces no output"

**Symptoms:** Downstream nodes show nothing; viewer is blank.

**Causes & fixes:**

1. **Missing input**: The node requires an input but nothing is connected.
   Check the help page (? button) for required inputs.
2. **Wrong data type**: A SOP node connected to a TOP input. Ensure
   families match between connected ports.
3. **Cook error**: Look for a red ✖ badge — hover to read the error.
4. **Bypassed node upstream**: An upstream node is bypassed and has no
   input to pass through (first node in chain).

### "Frame rate is low"

**Symptoms:** Choppy playback, high cook times.

**Fixes:**

1. **Reduce TOP resolution**: Lower the resolution of texture operators
   where full resolution isn't needed. 512×512 is often sufficient for
   intermediate processing.
2. **Check expensive nodes**: Enable the Perf overlay to find bottlenecks.
   CPU-bound nodes (ScriptCHOP, ScriptSOP, CPU-side IMG operators) are
   often the culprits.
3. **Disconnect unused branches**: The cook engine only evaluates the
   active chain (nodes feeding output sinks). Disconnect experimental
   branches to skip them.
4. **Use NRT mode**: For recording or offline rendering, switch to
   Non-Realtime mode for frame-perfect output at any speed.
5. **Reduce geometry**: SOP chains with high vertex counts slow down.
   Use lower subdivision levels during development.

### "Shader compile stutter on first frame"

**Symptom:** The first frame after loading a patch takes a long time.

**Fix:** Enable `shader_baker/enabled=true` in your export preset. This
pre-compiles shaders during the build step. For development, the stutter
is normal and only happens once per shader variant.

### "TOPtoIMG shows black on first frame"

**Symptom:** TOPtoIMG produces a black image for the first frame after a
change, then shows the correct image on the next frame.

**Explanation:** This is expected behavior. TOPtoIMG reads pixels from an
upstream TOP's ViewportTexture, but Godot defers viewport rendering to end
of frame. The operator uses a one-frame delay: the first cook caches the
current image and schedules a re-cook; the second cook reads the freshly
rendered pixels. This means the output is always one frame behind the
upstream TOP. For most workflows this is imperceptible.

### "Node re-cooks every frame even though nothing changed"

**Symptom:** A node shows as active and cooking every frame in the debug
panel Cook Chain tab, even though its inputs haven't changed.

**Causes:**
1. The node has `time_dependent` enabled — nodes like LFO, Noise, Clock,
   and Timer re-cook every frame by design.
2. An upstream node is time-dependent — dirty flags propagate downstream.
3. An expression references `time`, `frame`, or `dt` — the expression
   system marks the parameter dirty each frame.

### "GDExtension DLL not found"

**Symptom:** Extension operators (MIDI, NDI, Spout, etc.) fail to load.

**Fixes:**

1. Check that the extension's native library is present in the correct
   directory (`addons/gn_ext_*/native/`)
2. Verify the `.gdextension` file points to the correct library paths
3. For builds, use `-GDExtensions "auto"` to auto-detect available
   extensions, or `"none"` to skip all native extensions

### "Export template not found"

**Symptom:** Build or Quick Build fails with template error.

**Fixes:**

1. Open Godot → **Editor → Manage Export Templates** → install templates
   for your Godot version
2. Open **Project → Export** → verify preset names match what the build
   script expects
3. For cross-platform builds, you need export templates for the target OS

### "OSC/MIDI not receiving data"

**Symptoms:** OscInCHOP or RtMidiInCHOP shows no channels.

**Fixes:**

1. **Port conflict**: Another application may be using the same UDP port.
   Change the port number.
2. **Firewall**: Windows Firewall may block UDP traffic. Allow Godot
   through the firewall for the configured port.
3. **Active toggle**: Ensure the `active` parameter is On.
4. **Wrong port index (MIDI)**: Try different `port` values (0, 1, 2…)
   to find your device.
5. **Address filter (OSC)**: If `address_filter` is set, only matching
   messages are accepted. Clear it to accept all.

### "Sub-network shows no output"

**Symptoms:** SubNetworkNode produces null output.

**Fixes:**

1. **Missing OutTunnel**: The inner graph needs at least one OutTunnel
   for the sub-network to produce output. Dive in and add one.
2. **Disconnected OutTunnel**: The OutTunnel must be connected to
   something inside the sub-network.
3. **Wrong tunnel family**: The OutTunnel family must match the data
   type flowing through it.

---

## Performance Tips

| Technique | Impact | Description |
|-----------|--------|-------------|
| Lower TOP resolution | High | Use 512×512 or 256×256 for intermediate processing |
| Bypass heavy nodes | High | Press B to skip processing during development |
| Disconnect unused branches | Medium | Unconnected nodes are free; connected but unused branches still cook if they reach a sink |
| Use GPU operators | High | TOP/shader operators run on GPU; prefer them over CPU-side IMG operators |
| Reduce SOP subdivisions | Medium | Low poly during development, increase for final output |
| NRT for recording | High | Frame-perfect output at any speed, no dropped frames |
| Profile with Perf overlay | — | Identify bottlenecks before optimizing |

---

## GPU Compute Operators (POP, VOL)

### Compute Shader Requirements

POP (GPU particles) and VOL (volumetric) operators require compute shaders,
which are only available on **Forward+** and **Mobile** renderers. The
**Compatibility** renderer (OpenGL 3.3 / WebGL2) does not support compute.

### "My POP/VOL nodes show a ⚠ badge and don't cook"

This means compute shaders are unavailable on your current renderer.

**Check your renderer:**
- Forward+ (Vulkan/D3D12/Metal) — compute available ✅
- Mobile (Vulkan/Metal simplified) — compute available ✅
- Compatibility (OpenGL 3.3/WebGL2) — no compute ❌

**Fixes:**
- Ensure you're running on Forward+ or Mobile renderer (check the Godot
  editor title bar or console output at startup).
- On older GPUs or VMs, Godot may silently fall back to Compatibility.
- On Web exports, compute is never available (WebGL2 has no compute).
- The ⚠ badge and skip behavior are correct — the engine gracefully
  degrades so the rest of your graph keeps working.

### "GPU particles look different on different machines"

Floating-point precision varies between GPUs. POP operators use SSBO compute
with 32-bit floats, but results may differ slightly between NVIDIA and AMD,
or between desktop and mobile GPUs. This is expected for particle systems.

### CPU Fallback

ParticleSOP provides a CPU-based particle system as an alternative to POP
operators. It runs on all renderers including Compatibility and Web. Use it
when you need particle effects on platforms without compute support.

---

## SDF Operators

### "SDF operators are missing from the palette"

The SDF family is provided by the `gn_ext_sdf` extension. Check:

1. The `addons/gn_ext_sdf/` folder exists with `gn_extension.cfg`.
2. The extension isn't being skipped by platform/renderer guards.
3. Check the console at startup for extension loading messages.

### "SDF viewer shows 'Empty SDF tree'"

SDF nodes build a tree of signed distance field instructions. If the viewer
shows "Empty SDF tree", the upstream SDF chain has no valid data. Check:

1. The SDF chain starts with a primitive (SphereSDF, BoxSDF, etc.).
2. Boolean operators (UnionSDF, IntersectSDF, SubtractSDF) have at least
   two connected inputs.
3. The RaymarchSDF node is connected at the end — it renders the SDF tree
   into a texture (TOP output).

### "SDF raymarching is slow"

RaymarchSDF runs a shader-based raymarcher every frame. To improve performance:

- Lower the resolution parameter on RaymarchSDF.
- Reduce max steps (default is 128 — try 64 for previewing).
- Simplify the SDF tree — deep nesting with many smooth booleans is expensive.
- Use the Perf overlay to measure actual cook time.

---

## Multi-Monitor DPI / Scaling Issues

### "Editor layout scrambles when resizing across monitors with different DPI"

**Symptoms:** Moving or resizing the Godot editor (or a WindowOUT window)
between monitors that have different display scaling (e.g., 150% on your
laptop and 100% on an external monitor) causes the editor UI to become
misaligned, overlapping, or scrambled. The issue may persist even after
moving the window back to the original monitor.

**Root cause:** This is a **known Godot Engine limitation**, not a GONODES
bug. Godot currently uses "system DPI aware" mode on Windows, meaning it
reads the primary monitor's scale factor and applies it globally. It does
not yet support per-monitor DPI awareness, so moving windows between
monitors with different scale factors causes layout miscalculations in
Godot's internal Control layout tree.

GONODES (including WindowOUT) does not manipulate DPI or content scale
settings — the issue is entirely within Godot's windowing/UI layer.

**Workaround:** Set all your monitors to the **same display scaling
percentage** in your operating system settings:

- **Windows:** Settings → Display → Scale → set the same percentage on
  all monitors (e.g., 100% on all, or 125% on all)
- **Linux (X11):** Use `xrandr` or your desktop environment's display
  settings to match DPI across screens
- **Linux (Wayland):** Per-monitor scaling may work better depending on
  your compositor, but is still not fully supported by Godot

**Status:** Waiting for Godot Engine to implement per-monitor DPI
awareness. Track progress on these upstream issues:

- [godotengine/godot#56341](https://github.com/godotengine/godot/issues/56341)
  — *Implement support for seamless display scaling on Windows and Linux*
  (root feature request, open since Dec 2021)
- [godotengine/godot#84948](https://github.com/godotengine/godot/issues/84948)
  — *Resolution issue with dual monitors with different DPI*
- [godotengine/godot#86943](https://github.com/godotengine/godot/pull/86943)
  — PR: *Use PER_MONITOR_DPI_AWARE option if it's supported by OS*
- [godotengine/godot#111271](https://github.com/godotengine/godot/issues/111271)
  — *UI and viewport scale become incorrect when using Stretch across
  monitors with different DPI scaling*

Once Godot ships per-monitor DPI support, this issue should resolve
automatically with no changes needed on the GONODES side.

---

## Keyboard Quick Reference

| Key | Action |
|-----|--------|
| **Space** | Play / Pause |
| **Escape** | Reset to frame 0 |
| **B** | Toggle Bypass |
| **L** | Toggle Lock |
| **F** | Fit view to selection |
| **M** | Toggle minimap |
| **W** | Cycle wire style |
| **Click wire** | Select wire |
| **Shift+Click wire** | Add wire to selection |
| **Delete** | Delete selected nodes/wires |
| **Double-click wire** | Insert node on wire |
| **H** / **V** | Align horizontal / vertical |
| **Ctrl+L** | Auto-layout graph |
| **Ctrl+G** | Group into sub-network |
| **Backspace** | Navigate up from sub-network |
| **Enter** | Dive into sub-network |
| **?** | Toggle shortcuts overlay |
| **F1** | Open Help reference |
| **Alt+A** | Open node palette |
| **1–9** | Jump to bookmark |
| **Ctrl+1–9** | Set bookmark |
