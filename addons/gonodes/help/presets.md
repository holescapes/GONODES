# Parameter Presets

Parameter presets let you save, load, and transfer node settings. GONODES
supports clipboard-based copy/paste between nodes, named preset files on
disk, and a factory preset library.

---

## Copy & Paste Parameters

The fastest way to transfer settings between nodes of the same type.

### How To

1. **Right-click** a node → **Copy Parameters**
2. **Right-click** another node of the same operator type → **Paste Parameters**
3. All matching parameters are applied

### Rules

- Copy/Paste works between nodes of the **same operator type** only
  (e.g., NoiseTOP → NoiseTOP, not NoiseTOP → BlurTOP)
- Spare (user-added) parameters are included
- The paste count is reported in the status bar

---

## Named Presets (Save & Load)

Save a node's parameter state to a JSON file and reload it later —
across sessions, patches, and projects.

### Saving a Preset

1. **Right-click** a node → **Save Param Preset…**
2. Type a name (e.g., "warm_noise", "fast_blur")
3. Click **Save**

The preset is stored as a `.json` file in your user preset directory.

### Loading a Preset

1. **Right-click** a node → **Load Param Preset ▸**
2. A submenu shows all available presets for this operator type
3. Click a preset name to apply it

Factory presets (shipped with GONODES or extensions) appear alongside
your user presets. Factory presets cannot be deleted.

### Preset File Format

```json
{
  "operator_type": "noise",
  "preset_name": "warm_noise",
  "version": 1,
  "params": {
    "seed": { "value": 42 },
    "scale": { "value": 3.5 },
    "octaves": { "value": 4 }
  }
}
```

### Preset Directories

| Location | Path | Writable |
|----------|------|----------|
| User presets | `user://gonodes/presets/params/` | Yes |
| Factory presets | `res://addons/gonodes/presets/params/` | No |
| Extension presets | `res://addons/gn_ext_*/presets/params/` | No |

Presets are organized by operator type in subdirectories.

---

## Reset to Defaults

To restore a node's parameters to their original default values:

1. **Right-click** a node → **Reset to Defaults**

This constructs a fresh instance of the operator internally and copies
all default parameter values back to the selected node.

---

## Deleting a Preset

Only **user** presets can be deleted. Factory and extension presets are
read-only.

1. Currently, delete preset files manually from:
   `user://gonodes/presets/params/<operator_type>/`
   (On Windows: `%APPDATA%/Godot/app_userdata/GONODES/gonodes/presets/params/`)

---

## Code Presets

The script/code editor (for ScriptCHOP, ScriptSOP, GLSLTOP, etc.) has
its own **Presets ▾** menu button for saving and loading code snippets.
These are stored separately in `user://gonodes/presets/code/`.

---

## Tips

- Use presets to build a **library of looks** — save your favorite
  NoiseTOP, BlurTOP, and GLSLTOP configurations for quick recall.
- Presets work across patches — save a preset in one project and load
  it in another.
- Combine with **Takes** for live performance: Takes handle per-show
  parameter snapshots; Presets handle reusable per-operator templates.
- The clipboard is session-only — it does not persist across editor
  restarts. Use named presets for permanent storage.
