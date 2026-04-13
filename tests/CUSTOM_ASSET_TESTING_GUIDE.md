# Custom Asset System — Manual Testing Guide

Step-by-step walkthrough for testing the custom asset (.gnasset) architecture
using the interactive mapper assets shipped with `gn_ext_mapper`.

---

## Prerequisites

- GONODES editor running with all extensions loaded
- The `gn_ext_mapper` extension present with its `assets/` directory containing:
  - `interactive_quad_map.gnasset`
  - `interactive_bezier_map.gnasset`
  - `interactive_grid_warp.gnasset`
  - `interactive_stoner_map.gnasset`

---

## Part 1: Extension Asset Discovery & Palette

### 1.1 — Verify assets appear in palette
1. Press **Alt+A** to open the node palette.
2. Look for a **"Custom"** top-level section (gold colored).
3. Expand Custom → **TOP** → you should see a section named after
   the mapper extension (e.g., "Projection Mapping" or similar).
4. Under it, confirm all 4 assets are listed:
   - InteractiveQuadMap
   - InteractiveBezierMap
   - InteractiveGridWarp
   - InteractiveStonerMap

**Expected:** All 4 appear with gold text and "(read-only — from extension)" tooltip.

### 1.2 — Verify palette search
1. Press **Alt+A**, type "Interactive" in the search box.
2. All 4 mapper assets should appear in the filtered results.
3. Press Escape to close.

---

## Part 2: Placing & Using an Interactive Mapper Asset

### 2.1 — Place InteractiveQuadMap
1. Press **Alt+A** → type "InteractiveQuadMap" → select it.
2. A node appears on the graph. Confirm it shows:
   - Node type: "InteractiveQuadMap"
   - Family: TOP
   - 1 input port (texture)
   - 2 output ports (warped — TOP, panel — UI)

### 2.2 — Connect to a source texture
1. Add a **NoiseTOP** (Alt+A → "noise").
2. Connect NoiseTOP output → InteractiveQuadMap input (port 0).
3. Enable preview on the InteractiveQuadMap (click the node, press V).
4. You should see the noise texture pass through (initially no warp).

### 2.3 — Connect to WindowOUT with panel
1. Add a **WindowOUT** (Alt+A → "window").
2. Connect InteractiveQuadMap port 0 (warped) → WindowOUT port 0 (in).
3. Connect InteractiveQuadMap port 1 (panel) → WindowOUT port 1 (panel).
4. The output window should show the noise texture with a corner drag
   pad floating over it.

### 2.4 — Interactive adjustment
1. In the output window, drag the corners of the quad pad.
2. The noise texture should warp in real-time as you move corners.
3. This confirms: CornerDragUI → CHOP widget_state → QuadMapTOP
   expression wiring is working.

### 2.5 — Disconnect panel (hide UI)
1. Back in the graph editor, disconnect the panel wire
   (InteractiveQuadMap port 1 → WindowOUT port 1).
2. The output window should now show only the warped texture with no
   UI overlay.
3. Reconnect to bring the pad back.

---

## Part 3: Testing All 4 Mapper Assets

Repeat Part 2 for each asset type:

### 3.1 — InteractiveBezierMap
- 4×4 control point grid appears in the drag pad.
- Dragging inner points creates smooth curved deformations.
- All 32 params (16 points × x,y) should be expression-driven.

### 3.2 — InteractiveGridWarp
- NxM grid (default 4×4) appears in the drag pad.
- Dragging points distorts the texture bilinearly.
- Has extra custom params: Grid Columns, Grid Rows.

### 3.3 — InteractiveStonerMap
- Same corner drag as QuadMap but with keystone correction.
- Has extra custom params: Soft Edge L/R/T/B, Test Pattern.
- Try setting Test Pattern to "Grid" — should show grid overlay.

---

## Part 4: Custom Parameter Inspection

### 4.1 — Inspect custom params
1. Select an InteractiveQuadMap node.
2. In the inspector, confirm you see:
   - `show_panel` (Bool, default: true)
   - `pad_size` (Int, default: 250)
3. Toggle `show_panel` — note: this is currently metadata only
   (future versions will auto-hide the panel).
4. Change `pad_size` — note: this doesn't propagate into the inner
   drag UI yet (would need promoted param wiring). This tests that
   the custom param system is working.

### 4.2 — Stoner-specific params
1. Select an InteractiveStonerMap node.
2. Confirm extra params: Soft Edge Left/Right/Top/Bottom, Test Pattern.
3. These are exposed for direct adjustment on the custom operator.

---

## Part 5: Read-Only Viewing & Editing

### 5.1 — Dive into read-only inner network
1. Double-click an InteractiveQuadMap node.
2. You should see the inner network (in1, drag1, map1, out_tex, out_panel)
   in **read-only mode**.
3. A 🔒 breadcrumb banner should appear at the top.
4. Try to add a node (Alt+A) — should be blocked.
5. Try to delete a node (Delete key) — should be blocked.
6. Try to connect/disconnect wires — should be blocked.

### 5.2 — Edit Asset Definition
1. While inside the read-only view, click "Edit Asset Definition" in
   the breadcrumb banner.
2. The read-only lock should release.
3. You should now be able to move nodes, change connections, etc.
4. Press Backspace to navigate back out.

### 5.3 — Make Editable (one-way)
1. Right-click an InteractiveQuadMap node.
2. Select "Make Editable" from the context menu.
3. The node should convert to a plain SubNetworkNode.
4. Double-click to dive in — no read-only lock this time.
5. This is irreversible — the asset link is severed.

---

## Part 6: Export & Import

### 6.1 — Export SubNetwork as .gnpatch
1. Create a fresh SubNetworkNode (Ctrl+G on some selected nodes,
   or add one manually).
2. Right-click it → "Export Sub-Network…"
3. Save to a temporary location.
4. Verify the .gnpatch file is valid JSON with an inner_network block.

### 6.2 — Import .gnpatch
1. Right-click the graph background → "Import .gnpatch…"
2. Select the .gnpatch file from step 6.1.
3. A new SubNetworkNode should appear with the loaded inner network.

### 6.3 — Drag-and-drop .gnasset
1. Open the OS file manager and navigate to
   `addons/gn_ext_mapper/assets/`.
2. Drag `interactive_quad_map.gnasset` onto the graph canvas.
3. A new InteractiveQuadMap custom operator should appear.

### 6.4 — Drag-and-drop .gnpatch
1. Drag the .gnpatch file from step 6.1 onto the graph canvas.
2. A new SubNetworkNode should appear.

---

## Part 7: Serialization Round-Trip

### 7.1 — Save and reload
1. Place an InteractiveQuadMap with a noise source and WindowOUT.
2. Change `pad_size` to 300.
3. Save the patch (Ctrl+S).
4. Close and reopen the patch.
5. Select the InteractiveQuadMap — `pad_size` should still be 300.
6. The inner network should reload correctly from the .gnasset file.

### 7.2 — Copy as JSON
1. Select an InteractiveQuadMap node.
2. Right-click → "Copy as JSON".
3. Paste into a text editor — verify it shows `"type": "GNCustomOperator"`
   and `"asset_path"` but NOT the full inner network (compact serialization).

---

## Part 8: Switch Node Trick (Bonus)

### 8.1 — Using Switch to disable a chain
1. Add a SwitchTOP with 2 inputs connected.
2. Set index to the last (empty) input slot.
3. The SwitchTOP should hold its last valid output (cached_output).
4. Note: SwitchTOP does NOT output null — it freezes on the last valid
   frame. To truly null-out a chain, disconnect the wire entirely.

---

## Automated Tests

Run the automated test suite to validate the system programmatically:

```
godot --headless -s tests/test_runner.gd --test-filter=custom_asset
```

This runs `tests/unit/test_custom_assets.gd` which covers:
- Extension asset scanning and registration
- Asset loading and instantiation
- Inner network structure validation
- Custom parameter creation
- Expression wiring verification
- Serialization round-trips
- host_node back-reference

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Assets not in palette | Check `gn_ext_mapper/assets/` directory exists with .gnasset files |
| "Failed to load asset" | Verify JSON syntax in .gnasset file |
| Drag pad doesn't warp texture | Check expression wiring — map1 params should have `chop("drag1", ...)` expressions |
| Read-only not working | Ensure `gn_graph_editor.gd` has the `read_only` property and guards |
| Make Editable missing | Check context menu — should say "Make Editable" not "Make Unique" |
