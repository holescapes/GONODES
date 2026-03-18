# Takes — Parameter Layer Overrides

Takes let you capture named parameter snapshots and switch between them
instantly during live performance. Each take stores only parameters that
differ from **Base** (sparse delta), so they are lightweight and easy to
manage.

---

## Quick Start

1. **Open the Take panel**: Click the **Takes** toggle in the toolbar.
2. **Capture Base**: Click **Capture Base** to snapshot all current parameter values across the network.
3. **Modify parameters**: Tweak any node's parameters to the look you want.
4. **Capture a Take**: Type a name in the text field and click **Capture Take**. Only parameters that differ from Base are stored.
5. **Switch takes**: Click a take in the list and press **Apply**, or double-click a take. All parameters revert to Base first, then the take's overrides are applied.
6. **Revert**: Click **Revert to Base** to restore all parameters to their original state.

---

## Blend Slider

The **Blend** slider at the bottom of the Take panel lets you smoothly
interpolate between Base and the selected take:

| Parameter Type | Blend Behaviour |
|---------------|-----------------|
| Float | Linear interpolation (lerp) |
| Int | Lerped and rounded |
| Color | Per-component lerp (RGBA) |
| Vector2 / Vector3 / Vector4 | Per-component lerp |
| Other (String, Bool, Enum) | Snaps at 50% blend |

Set the slider to **0%** = Base, **100%** = full take override. Values
in between produce a smooth mix — ideal for crossfading between visual
looks during a live set.

---

## Saving and Loading

- **Save…**: Writes all takes plus the base snapshot to a `.gntake` file
  (JSON format). Store alongside your `.gnpatch` file.
- **Load…**: Reads a `.gntake` file and replaces the current take set.

The `.gntake` format:

```json
{
  "version": 1,
  "base": { "node_id/param_name": { ... }, ... },
  "takes": {
    "Take Name": { "node_id/param_name": { ... }, ... },
    ...
  }
}
```

---

## Tips

- Capture Base **before** making any changes — it's your reference state.
- Takes are sparse: a take with 3 overrides stores exactly 3 parameter
  entries, not the entire network state.
- You can rename or delete takes from the list.
- The blend slider is independent per selected take — select a different
  take and the blend applies to that take.
- Takes survive save/load cycles via `.gntake` files.
- For per-node presets (copy/paste individual node settings), use the
  existing **Parameter Presets** system (right-click a node → Presets).

---

## Architecture

- **GNTakeManager** (`core/gn_take_manager.gd`): Core class that captures,
  applies, blends, and serializes takes. Holds a reference to the active
  `GNNetwork`.
- **GNTakePanel** (`ui/gn_take_panel.gd`): Editor panel UI with list,
  buttons, blend slider, and file dialogs.
- Takes are global to the current network — they capture all nodes in the
  top-level network.

---

## Example Patches

- `help/takes/takes_basic.gnpatch` — Step-by-step walkthrough of capture,
  apply, and revert.
- `help/takes/takes_blend.gnpatch` — Demonstrates smooth blending between
  two visual looks.
