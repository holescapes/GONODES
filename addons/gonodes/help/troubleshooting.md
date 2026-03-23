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
