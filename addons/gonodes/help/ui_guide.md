# GONODES — UI & Workflow Guide

Quick reference for every keyboard shortcut, context menu entry, toolbar button,
mouse interaction, and inspector control in the GONODES editor.

---

## Keyboard Shortcuts

### File Operations (from top-level editor)

| Shortcut           | Action                          |
|--------------------|---------------------------------|
| **Ctrl + N**       | New patch (clears everything)   |
| **Ctrl + O**       | Open patch file (.gonodes)      |
| **Ctrl + S**       | Save current patch              |
| **Ctrl + Shift + S** | Save As… (pick new file)     |

### Graph Editing

| Shortcut           | Action                                    |
|--------------------|-------------------------------------------|
| **Alt + A**        | Open the **Add Node** palette at cursor   |
| **Ctrl + C**       | Copy selected nodes                       |
| **Ctrl + X**       | Cut selected nodes                        |
| **Ctrl + V**       | Paste clipboard at cursor                 |
| **Ctrl + D**       | Duplicate selected nodes                  |
| **Delete**         | Delete selected nodes                     |
| **Ctrl + A**       | Select all nodes                          |
| **Ctrl + Z**       | Undo                                      |
| **Ctrl + Y** / **Ctrl + Shift + Z** | Redo                   |

### Node State & Layout (no modifiers — just press the key)

| Shortcut | Action                                                                 |
|----------|------------------------------------------------------------------------|
| **B**    | **Bypass** toggle — selected nodes pass their first input through unchanged. Bypassed nodes show ⏩ in the title and are dimmed. |
| **L**    | **Lock** toggle — selected nodes become read-only. Locked nodes show 🔒 in the title; the inspector dims all parameters and disables editing. |
| **F**    | **Fit to view** — zooms and pans to frame the selected nodes (or the entire graph if nothing is selected). |
| **H**    | **Align Horizontal** — moves 2+ selected nodes so they share the same vertical center (average Y). |
| **V**    | **Align Vertical** — moves 2+ selected nodes so they share the same horizontal center (average X). |
| **M**    | **Minimap** toggle — show/hide the corner minimap. |
| **W**    | **Wire style** — cycle through Curved → Straight → Right-Angle wire rendering. |
| **Ctrl + L** | **Auto-layout** — arrange all nodes using topological layering. Undoable. |
| **?** (Shift+/) | **Shortcut reference card** — show/hide the keyboard shortcuts overlay. Press ? or Escape to dismiss. |

### Node Bookmarks

| Shortcut       | Action                                                     |
|----------------|-------------------------------------------------------------|
| **Ctrl + 1-9** | Set a **bookmark** on the currently selected single node.   |
| **1-9**        | Jump to the bookmarked node (selects & centers it in view). |

Bookmarked nodes display a small blue numbered badge. Up to 9 bookmarks are
available per session. Re-assigning a slot replaces the previous bookmark.

---

## Mouse Interactions

### Graph Canvas

| Action                        | Effect                                          |
|-------------------------------|------------------------------------------------|
| **Left-click** node           | Select node (deselects others)                  |
| **Shift + Left-click** node   | Add/remove node from selection                  |
| **Left-drag** on empty space  | Box-select (rubber-band selection)              |
| **Left-drag** a node          | Move node (snaps to 20px grid)                  |
| **Left-drag** from port       | Start a wire connection                         |
| **Right-click** on empty space / node | Open the **context menu**               |
| **Right-drag** from an input port | Disconnect the wire (right-disconnects mode) |
| **Scroll wheel**              | Zoom in/out (0.25× – 2.5×, step 0.1)          |
| **Middle-click drag**         | Pan the graph canvas                            |

### Node View

| Action                           | Effect                                        |
|----------------------------------|-----------------------------------------------|
| **Double-click title bar**       | Start **inline rename** — type a new ID and press Enter |
| **Click `?` button** (title bar) | Open the **node help** window for that operator |
| **Drag** node                    | Reposition node (with undo/redo support)       |

---

## Context Menu (Right-click)

Right-click anywhere on the graph canvas to open the context menu.
Greyed-out items require a selection, clipboard content, or ≥2 nodes.

| Menu Item          | Shortcut        | Notes                                              |
|--------------------|-----------------|-----------------------------------------------------|
| **Add Node…**      | Alt + A         | Opens the node palette search popup                 |
| **Copy**           | Ctrl + C        | Copies selected nodes + internal wires              |
| **Cut**            | Ctrl + X        | Cut (copy then delete)                              |
| **Paste**          | Ctrl + V        | Paste at cursor position (IDs get `_copy` suffix)   |
| **Duplicate**      | Ctrl + D        | Copy + paste in one step                            |
| **Delete**         | Delete          | Remove selected nodes and their wires               |
| **Select All**     | Ctrl + A        | Select every node in the graph                      |
| **Undo**           | Ctrl + Z        | Undo last graph action                              |
| **Redo**           | Ctrl + Y        | Redo last undone action                             |
| **Open Viewer**    | —               | Opens a floating viewer window (needs 1 TOP selected) |
| **Toggle Preview** | —               | Shows/hides the inline preview on selected nodes    |
| **Bypass: ON/OFF** | B               | Toggle bypass on selected nodes                     |
| **Lock: ON/OFF**   | L               | Toggle lock on selected nodes                       |
| **Align Horizontal** | H             | Align selected nodes to same Y (needs 2+)          |
| **Align Vertical** | —               | Align selected nodes to same X (needs 2+)          |
| **Node Help**      | —               | Open help window (needs exactly 1 node selected)   |

### Quick-Access Keys (not in context menu)

| Key       | Action                            |
|-----------|-----------------------------------|
| **M**     | Toggle minimap                    |
| **W**     | Cycle wire style                  |
| **Ctrl + L** | Auto-layout entire graph       |
| **?**     | Show shortcut reference card      |
| **1-9**   | Jump to bookmark                  |
| **Ctrl + 1-9** | Set bookmark on selected node |

---

## Toolbar (Info Bar)

The toolbar runs across the bottom of the editor. From left to right:

| Button / Toggle    | Effect                                                        |
|--------------------|---------------------------------------------------------------|
| **New**            | Create a new empty patch (Ctrl + N)                           |
| **Open**           | Open a `.gonodes` file (Ctrl + O)                             |
| **Save**           | Save the current patch (Ctrl + S)                             |
| **Save As**        | Save to a new file (Ctrl + Shift + S)                         |
| **Previews** ☑     | Master toggle — show/hide inline preview thumbnails on all nodes |
| **Perf** ☑         | Show/hide per-node cook-time overlay (ms + warning badges)    |
| **+ Viewer**       | Open a floating viewer window for the currently viewed TOP    |
| **Stress Test**    | Generate a 55+ node test network for benchmarking             |
| **Minimap** ☑      | Show/hide the corner minimap (same as M key)                  |
| **Wire style** ▾   | Dropdown: Curved / Straight / Right-Angle (same as W key)     |
| **Layout**         | Auto-layout all nodes using topological order (Ctrl+L)        |
| *(Info label)*     | Displays: FPS, frame count, cook time (ms), node count, viewed node ID |

---

## Parameter Inspector

When a node is selected, the **Parameter Inspector** panel on the right shows
its parameters. Each parameter row has interactive controls:

### Parameter Modes: C / E Toggle

Every parameter has a small **C/E button** on the left:

- **C** (Constant) — value is set directly via the spinbox, slider, color
  picker, checkbox, or dropdown. This is the default mode.
- **E** (Expression) — value is computed by a GDScript expression string
  every cook frame. A text field appears for entering the expression.

Click the C/E button to toggle between modes.

### Multi-Component Parameters (Vector2, Vector3, Vector4, Color)

Multi-dimensional parameters show **per-component** C/E toggles:

```
[C] X  [ 1.00 ]
[E] Y  chop("lfo1")[0]
[C] Z  [ 0.00 ]
```

Each axis (X, Y, Z, W / R, G, B, A) can independently be in Constant or
Expression mode, just like TouchDesigner.

### Value Controls by Type

| Type      | Control                                                         |
|-----------|-----------------------------------------------------------------|
| Float     | SpinBox (drag to scrub, type to set)                            |
| Int       | SpinBox (integer steps)                                         |
| Bool      | CheckBox                                                        |
| String    | LineEdit                                                        |
| Enum      | OptionButton (dropdown)                                         |
| Color     | ColorPickerButton + per-component RGBA spinboxes                |
| Vector2/3/4 | Per-component spinboxes (one per axis)                        |
| File      | FileDialog button (filters by allowed extensions)               |

### Locked Nodes

When a node is **locked** (🔒), the inspector **immediately** updates:
- Dims all parameter rows
- Disables all mouse input on controls (prevents accidental edits)
- Shows **"🔒 LOCKED"** in the status label

Unlock with the **L** key or the context menu to resume editing.

---

## Node Visual Indicators

Nodes display status through visual cues on the title bar and body:

| Indicator          | Meaning                                                      |
|--------------------|--------------------------------------------------------------|
| White title text   | Node ID only (family name shown in tooltip on hover)          |
| Dark outline       | Title text and ? button have a dark outline for readability   |
| ⏩ prefix          | Node is **bypassed** — passes input through without cooking  |
| 🔒 prefix          | Node is **locked** — parameters cannot be edited             |
| Dimmed appearance  | Node is bypassed (body color reduced to 50% opacity)          |
| Family color bar   | Title bar is tinted per family (CHOP=green, TOP=purple, etc.) |
| Preview thumbnail  | Inline output preview (80px tall, live-updating)              |
| Perf overlay       | Cook time in ms (when Perf toggle is on)                      |
| Error badge        | Cook errors appear in the perf overlay                        |

### Family Colors

| Family | Color                          |
|--------|--------------------------------|
| CHOP   | Green                          |
| TOP    | Purple                         |
| SOP    | Blue                           |
| DAT    | Olive / Yellow-green           |
| MAT    | Orange / Amber                 |
| COMP   | Pink / Magenta                 |

---

## Expression Reference Lines

When a parameter's expression references another node via `chop("node_id")`,
`op("node_id")`, `top("node_id")`, `sop()`, `dat()`, or `mat()`, the editor
draws **dashed cyan lines with arrowheads** from the referencing node to the
referenced node.

- Lines update every cook frame automatically
- The arrow points from the node *containing the expression* toward the node
  *being referenced*
- Both main expressions and per-component expressions are scanned
- Toggle visibility via the `expr_refs_visible` property

---

## Graph Navigation

| Feature              | Details                                                  |
|----------------------|----------------------------------------------------------|
| **Minimap**          | 200×150px minimap in the corner (toggle with M or toolbar) |
| **Zoom range**       | 0.25× to 2.5× (scroll wheel, step 0.1)                  |
| **Default zoom**     | 0.8×                                                     |
| **Snap grid**        | 20px grid snapping (enabled by default)                  |
| **Fit to view (F)**  | Frames selected nodes or all nodes with padding          |
| **Bookmarks (1-9)**  | Ctrl+# to set, # to jump — instant node navigation      |
| **Wire styles (W)**  | Curved (default), Straight, or Right-Angle connections   |
| **Auto-layout (Ctrl+L)** | Topological layered arrangement, undoable            |

---

## Node Palette (Add Node)

Open with **Alt + A** or **right-click → Add Node…**

- Search field with instant filtering (type to narrow results)
- Nodes are organized by family (CHOP, TOP, SOP, DAT, MAT, COMP)
- Click a node type to place it at the cursor position
- New nodes get auto-generated IDs (e.g., `lfo1`, `noisechop1`)

---

## Wire Connections

| Action                              | Result                              |
|-------------------------------------|-------------------------------------|
| Drag from output port → input port  | Create a connection                 |
| Drag from input port → empty space  | Disconnect (right-disconnects mode) |
| Right-drag from connected input     | Disconnect the wire                 |
| Delete a node                       | All connected wires are removed     |
| Press **W**                         | Cycle wire style (Curved → Straight → Right-Angle) |

Wires are type-checked — you can only connect ports of matching families
(CHOP→CHOP, TOP→TOP, etc.). Invalid connections are silently rejected.

### Wire Styles

| Style          | Curvature | Description                              |
|----------------|-----------|------------------------------------------|
| **Curved**     | 0.5       | Default smooth Bézier curves             |
| **Straight**   | 0.0       | Direct line from port to port            |
| **Right-Angle**| 1.5       | Sharp bend for schematic-style wiring    |

Toggle from the toolbar dropdown or press **W** to cycle.

---

## Inline Node Rename

1. **Double-click** the title bar of a node
2. An inline text field appears with the current ID pre-selected
3. Type the new name and press **Enter** (or click away to confirm)
4. The node, all wire references, and expression references update automatically
5. Empty names or unchanged names are ignored

Duplicated nodes automatically receive an `_copy` suffix (e.g., `lfo1` → `lfo1_copy`).

---

## Viewer Windows

- **Main viewer**: Bottom-right panel, shows the output of the last-clicked TOP node
- **Floating viewers**: Click **+ Viewer** in the toolbar or **Open Viewer** in
  the context menu to open a separate resizable window tied to a specific TOP
- Multiple floating viewers can be open simultaneously
- Viewers update live every cook frame

---

## Help System

- **? button** on each node's title bar → opens a formatted help window
- **Node Help** in the context menu (1 node selected)
- Help windows show: description, parameters table, inputs/outputs, tips,
  example expressions, and related nodes
- The help window can be left open and updates when a different node is queried
- See also: `help/expressions_guide.md` for expression system documentation

---

## Undo / Redo

Full undo/redo support for:
- Adding / deleting nodes
- Creating / removing wire connections
- Moving nodes (drag)
- Renaming nodes
- Copy / paste / duplicate / cut operations

History is cleared on **New** or **Open**.

| Shortcut                     | Action |
|------------------------------|--------|
| **Ctrl + Z**                 | Undo   |
| **Ctrl + Y** / **Ctrl + Shift + Z** | Redo |

---

## Serialization

Patches are saved as `.gonodes` JSON files containing:
- All node definitions (type, ID, position, parameters, expressions)
- All wire connections
- Node states (bypass, locked, preview enabled)

Bypass and lock states are persisted — reloading a patch restores all node states.
