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
| **L**    | **Lock** toggle — selected nodes become read-only. Locked nodes show ?? in the title; the inspector dims all parameters and disables editing. |
| **F**    | **Fit to view** — zooms and pans to frame the selected nodes (or the entire graph if nothing is selected). |
| **H**    | **Align Horizontal** — moves 2+ selected nodes so they share the same vertical center (average Y). |
| **V**    | **Align Vertical** — moves 2+ selected nodes so they share the same horizontal center (average X). |

Sticky notes: right-click a note → **Text Size** to choose 12, 16, 24, or 32 px (saved with the patch). Enable **Wrap sticky notes** in Preferences → Interface to grow notes so wrapped text stays inside the box.
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
| **Left-click** wire           | Select wire (deselects other wires)             |
| **Shift + Left-click** wire   | Toggle wire in/out of selection                 |
| **Double-click** wire         | Insert a new node on that wire                  |
| **Left-drag** on empty space  | Box-select (rubber-band selection for nodes and wires) |
| **Left-drag** a node          | Move node (snaps to 20px grid)                  |
| **Shake** a node rapidly      | **Shake-to-disconnect** — detach all wires (see below) |
| **Left-drag** from port       | Start a wire connection                         |
| **Right-click** on empty space / node | Open the **context menu**               |
| **Right-click** wire          | Select wire and open context menu               |
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
| **Add Node…**      | Alt + A         | Palette search: name, family, secondary output, and tags (`audio`, `video`, `file`, `camera`). Several words must each match a word in the name (`audio out` finds AudioDeviceOUT) |
| **Copy**           | Ctrl + C        | Copies selected nodes + internal wires              |
| **Cut**            | Ctrl + X        | Cut (copy then delete)                              |
| **Paste**          | Ctrl + V        | Paste at cursor position (IDs get `_copy` suffix)   |
| **Duplicate**      | Ctrl + D        | Copy + paste in one step                            |
| **Delete**         | Delete          | Remove selected nodes and/or wires              |
| **Select All**     | Ctrl + A        | Select every node in the graph                      |
| **Undo**           | Ctrl + Z        | Undo last graph action                              |
| **Redo**           | Ctrl + Y        | Redo last undone action                             |
| **Open Viewer**    | —               | Opens a floating viewer window (needs 1 TOP selected) |
| **Toggle Preview** | —               | Shows/hides the inline preview on selected nodes    |
| **Bypass: ON/OFF** | B               | Toggle bypass on selected nodes                     |
| **Lock: ON/OFF**   | L               | Toggle lock on selected nodes                       |
| **Align Horizontal** | H             | Align selected nodes to same Y (needs 2+)          |
| **Align Vertical** | —               | Align selected nodes to same X (needs 2+)          |
| **Add Spare Parameter…** | —         | Add a custom parameter to the selected node (needs 1 selected) |
| **Node Help**      | —               | Open help window (needs exactly 1 node selected)   |
| **Copy as JSON**   | —               | Copies selected nodes + connections as JSON         |
| **Copy Debug Info** | —              | Copies single node's full debug state dump          |
| **Copy Network JSON** | —            | Copies entire network as JSON                       |
| **Delete Wires**   | Delete          | Remove selected wires (shown when wires are selected) |
| **Insert Node on Wire** | —          | Insert a node on the selected wire (filtered palette) |

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
| *(Info label)*     | Displays: FPS, frame count, cook time (ms), active/total nodes, viewed node ID |

---

## Parameter Inspector

When a node is selected, the **Parameter Inspector** panel on the right shows
its parameters. Each parameter row has interactive controls:

### Parameter Modes: C / E Toggle

Every parameter has a small **C/E button** on the left:

- **C** (Constant) — value is set directly via the numeric field, color
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

### Numeric Fields (Houdini-style virtual slider)

Float and Int parameters each have their own dedicated control —
**GNFloatField** and **GNIntField** — both extending a shared
**GNNumericField** base class.  They share the same interaction model
(click-to-type, drag-to-scrub, ladder popup) but differ in value type,
ladder tiers, and visual extras.

**Interactions (both Float and Int):**

| Action | Effect |
|--------|--------|
| **Click** | Enter text editing mode — type any value, press Enter to confirm, Escape to cancel |
| **Click outside** | Applies text and exits edit mode |
| **Ctrl+Click** | Reset parameter to its default value |
| **Horizontal drag** | Virtual slider — scrub the value smoothly using the active sensitivity tier |
| **Shift + drag** | Fine mode (sensitivity ÷ 10) |
| **Ctrl + drag** | Coarse mode (sensitivity × 10) |
| **Middle-button drag** | Open the **ladder popup** — drag vertically to select a sensitivity tier (no value change during selection). All other UI is blocked while the ladder is open. |

**Ladder popup:** When you middle-click and drag, a popup appears to the left
of the field showing multiplier tiers.  Float fields range from ×0.001 (finest)
to ×100 (coarsest).  Int fields range from ×1 to ×100 (no sub-integer tiers).
Drag up from the origin for coarser tiers, down for finer. The active tier is
highlighted with a blue bar and shows the real per-pixel sensitivity (e.g.
"0.01/px") beside the multiplier label. Release middle-button to confirm your
tier selection — subsequent left-drag scrubs at the new sensitivity.

During ladder pick, a full-screen input blocker prevents any other UI element
from highlighting or receiving mouse events.

**Ranged vs. rangeless:** Parameters with defined min/max (e.g. Energy 0–16)
show a subtle **fill bar** behind the value text indicating position within
the range. Rangeless parameters (e.g. Translate X, Rotate Y) show a darker
background — the value is completely unclamped.

**Int-specific extras:** Ranged Int fields show clickable **◂ ▸ step arrows**
at the left and right edges — click to decrement/increment by 1.  Int drag
uses an internal float accumulator so sub-integer mouse movements don't get
lost; the displayed value only jumps when the accumulator crosses an integer
boundary.

### Value Controls by Type

| Type      | Control                                                         |
|-----------|-----------------------------------------------------------------|
| Float     | GNFloatField (virtual slider drag, ladder, click-to-type)       |
| Int       | GNIntField (integer steps, ◂ ▸ arrows on ranged, int ladder)   |
| Bool      | CheckBox                                                        |
| String    | LineEdit                                                        |
| Enum      | OptionButton (dropdown)                                         |
| Color     | ColorPickerButton + per-component RGBA spinboxes                |
| Vector2/3/4 | Per-component GNFloatField (one per axis)                     |
| File      | FileDialog button (filters by allowed extensions)               |

### Locked Nodes

When a node is **locked** (??), the inspector **immediately** updates:
- Dims all parameter rows
- Disables all mouse input on controls (prevents accidental edits)
- Shows **"?? LOCKED"** in the status label

Unlock with the **L** key or the context menu to resume editing.

### Spare Parameters

You can add **spare (custom) parameters** to any node via the context menu:
**right-click → Add Spare Parameter…**

The dialog lets you choose:
- **Name** — internal parameter name (e.g. `my_scale`)
- **Type** — Float, Int, Bool, String, Color, Vector2, Vector2i
- **Min / Max** (Float and Int only) — optional range bounds.  Leave empty
  for a rangeless parameter.  When set, the numeric field shows a fill bar
  (and Int fields get ◂ ▸ step arrows).
- **Display label** — optional human-readable label (defaults to the
  capitalized name)

Spare parameters appear in the inspector alongside built-in parameters
and can use expressions just like any other parameter.  They are saved
and restored with the patch.

---

## Node Visual Indicators

Nodes display status through visual cues on the title bar and body:

### Title Bar Layout

Each node has a two-row colored title bar:

| Row | Contents |
|-----|----------|
| **Top row** | Node name + **?** (help button) |
| **Bottom row** | **B** (bypass) + **L** (lock) + **P** (preview) + **V** (viewer pin) + status badges |

The BLPV buttons have dark pill backgrounds for readability on any family color.
Inactive buttons are gray; active buttons light up in distinct colors:

| Button | Active Color | Meaning |
|--------|--------------|---------|
| **B** | Yellow | Node is bypassed — passes input through without cooking |
| **L** | Orange-red | Node is locked — output is frozen, not recooking |
| **P** | Cyan | Preview thumbnail is visible |
| **V** | Teal | Node is pinned to the docked viewer |

### Status Badges

Status badges appear on the right side of the bottom title row:

| Badge | Color | Meaning |
|-------|-------|---------|
| **ERR** | Red | Cook error — hover for details |
| **WRN** | Yellow | Warning — hover for details |
| **DEP** | Orange | Operator is deprecated — hover for replacement info |

Errors and warnings are cleared at the start of each cook cycle and re-set if
the condition persists. See [Node Errors & Warnings](troubleshooting.md#node-errors--warnings)
for the full list of what triggers each.

### Other Visual Cues

| Indicator          | Meaning                                                      |
|--------------------|--------------------------------------------------------------|
| Dimmed appearance  | Node is bypassed (body color reduced to 50% opacity)          |
| Family color bar   | Title bar is tinted per family (CHOP=green, TOP=purple, etc.) |
| Preview thumbnail  | Inline output preview (80px tall, live-updating)              |
| Perf overlay       | Cook time in ms (when Perf toggle is on)                      |
| **zzz** overlay    | Node is **inactive** — not in any active chain (frozen output)|

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
`op("node_id")`, `top("node_id")`, `sop()`, `dat()`, `cell()`, `lookup()`,
`mat()`, `vol()`, `img()`, or `output()`, the editor
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
| **Edge-scroll**      | Drag a node near any edge to auto-scroll the canvas. Selected nodes follow the scroll. |
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

### Selecting Wires

| Action                              | Result                              |
|-------------------------------------|-------------------------------------|
| **Left-click** a wire               | Select it (deselects other wires)   |
| **Shift + Left-click** a wire       | Toggle wire in/out of selection     |
| **Box-select** (drag on empty space)| Selects all wires intersecting the rectangle |
| **Right-click** a wire              | Auto-selects the wire and opens context menu |

Selected wires are highlighted in gold, following the actual wire curve.

### Deleting Wires

| Action                              | Result                              |
|-------------------------------------|-------------------------------------|
| **Delete** key with wires selected  | Removes selected wires (with undo)  |
| Right-click → **Delete Wires**      | Same as Delete key                  |

Wire deletion is fully undoable (Ctrl+Z).

### Inserting a Node on a Wire

**Double-click** a wire to insert a new node inline:

1. Double-click the wire — a filtered operator palette opens showing only
   operators whose first input accepts the upstream family.
2. Pick an operator — it is created and spliced into the wire automatically.
3. If there isn't enough room, surrounding nodes slide apart with a smooth
   animation to make space (cascade push).

The entire operation (disconnect old wire, create node, connect new wires,
reposition nodes) is a single undo action.  Pressing Ctrl+Z undoes the
insert and smoothly animates nodes back to their original positions.

### Shake-to-Disconnect (Houdini-style)

Rapidly shake a node left-right while dragging to **disconnect all its wires**.
This is a fast alternative to manually disconnecting wires one by one.

- **How:** While dragging a node, shake it horizontally with enough speed
  (≥ 150 px/s) and at least 3 direction reversals within 0.5 seconds.
- **Effect:** All input and output wires are removed. If the node was
  in the middle of a chain (upstream → node → downstream), the upstream
  and downstream nodes are automatically **reconnected** to preserve the
  data flow (bypass reconnection).
- **Undo:** The entire operation is a single undo action — Ctrl+Z restores
  all original connections.
- **Toast:** A brief notification confirms the disconnect.

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
4. The node, all wire references, and expression references update automatically:
   - All `chop()`, `op()`, `top()`, `sop()`, `dat()`, `cell()`, `lookup()`, `mat()`, `vol()`, `img()`, `output()`, `par()`, `set_par()` references
   - Per-component expressions on Vector2/3/4 and Color parameters
   - Script operator code bodies (GDScriptSCRIPT, PythonSCRIPT, NativeSCRIPT)
   - CallbackDAT callback slots (on_start, on_cook, on_value_change, on_create)
   - Hierarchical paths: `"subnet1/old_name"` → `"subnet1/new_name"`
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

## Take Panel

Toggle the **Takes** button on the timeline row to show the Take panel —
a parameter layer system for live performance preset switching. Shift+T toggles it.

- **Capture Base**: Snapshot all current parameter values as the reference state
- **Capture Take**: Save current parameter differences as a named take
- **Apply**: Instantly apply a take's overrides on top of Base
- **Revert to Base**: Restore all parameters to the base state
- **Blend slider**: Smoothly interpolate between Base and a take (float, int, Color, Vector lerp)
- **Save / Load**: Persist takes to `.gntake` files (JSON)

See `help/takes.md` for full documentation.

---

## Help System

- **? button** on each node's title bar → opens a formatted help window
- **Node Help** in the context menu (1 node selected)
- Help windows show: description, parameters table, inputs/outputs, tips,
  example expressions, and related nodes
- The help window can be left open and updates when a different node is queried
- See also: `help/expressions.md` for expression system documentation

---

## Undo / Redo

Full undo/redo support for:
- Adding / deleting nodes
- Creating / removing wire connections
- Moving nodes (drag)
- Renaming nodes
- **Parameter value changes** (numeric scrub, checkbox toggle, dropdown, color, etc.)
- **Parameter mode changes** (Constant ↔ Expression)
- Copy / paste / duplicate / cut operations
- Shake-to-disconnect

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

---

## Toast Notifications

Brief, non-intrusive notifications appear in the **center** of the graph
canvas for transient feedback — e.g., "Shake disconnect: removed 3 wires",
"Pasted 5 nodes", or error messages from failed operations. Toasts fade
out automatically after ~2 seconds and do not require dismissal.

---

## Active Chain Cooking

GONODES automatically optimizes performance by only cooking nodes that feed a
**live sink** — a node whose output is currently being displayed. This is
always-on with no toggle required.

### What counts as a sink?

| Sink Type               | When active                                       |
|--------------------------|---------------------------------------------------|
| **Viewer panel**         | The node you last clicked, any family. A WindowOUT cooks when the patch opens, without that click |
| **Floating viewer window** | Each pinned viewer window targets a specific node |
| **is_sink operators**    | Any node with `is_sink = true` (WindowOUT, future SpoutOut, MIDIOut, OSCOut, NDIOut, etc.) |

### How it works

1. Every frame, the editor tells the cook engine which nodes are sinks.
2. The cook engine walks **upstream** from each sink via BFS to find all
   contributing nodes — this is the **active set**.
3. The walk follows both **wire connections** and **expression references**
   (e.g., `chop("lfo1", "out")` makes `lfo1` part of the active chain).
4. Nodes **outside** the active set skip cooking entirely. Their `cached_output`
   is frozen at whatever it last produced.
5. When you click a different node, it becomes the viewer target (a new sink),
   and its entire upstream chain activates instantly.
6. The active set is **event-driven** — it only recomputes when topology,
   viewer targets, or expressions change (not every frame).

### Visual feedback

- **Info bar** shows `Active: N/M` — how many nodes are cooking vs. total.
- **Perf overlay** shows `zzz` in gray on inactive nodes (when the Perf toggle
  is on).
- Selecting a node immediately activates it and its upstream chain.


## Rendering Backend

The editor always launches with **Forward+** (Vulkan / D3D12) for the best preview quality. If the GPU or driver doesn't support Vulkan, Godot automatically falls back to **Compatibility** (OpenGL 3.3) thanks to the `fallback_to_opengl3 = true` project setting.

| Platform | Primary   | Fallback         |
|----------|-----------|------------------|
| Windows  | D3D12     | OpenGL 3.3       |
| macOS    | MoltenVK  | OpenGL 3.3       |
| Linux    | Vulkan    | OpenGL 3.3       |

There is no manual renderer selection in the editor — it is fully automatic. Power users can force a specific renderer from the command line:

```
godot --rendering-method mobile
godot --rendering-method gl_compatibility
```

---

## Logs

The **Logs** button opens the log panel. Capture is already on; the panel only draws the latest lines (50 by default). **DBG** stays off until you check it. **Preferences → Log file name** is empty by default. A file name, not a path, appends the full log beside the current patch. **Preferences → Log Level** sets what is captured. The Debug button does not turn logging on. See [troubleshooting.md](troubleshooting.md).

## Debug Panel & Overlay

Press **F2** or click the **Debug** toolbar button to toggle the debug system.

### Debug Panel (3 Tabs)

The panel docks below the graph canvas. Double-click any row to select and
scroll to that node.

| Tab | Shows | Columns |
|-----|-------|---------|
| **Cook Chain** | All nodes in topological cook order | #, Node, Family, Status, Cook (ms), Active |
| **Active Chains** | Tree rooted at each sink, showing upstream dependencies | Node, Family, Cook (ms) |
| **Param Refs** | All expression-mode parameters and their cross-references | Source Node, Parameter, Expression, References, Eval (μs) |

**Cook Chain status column:**

| Status | Color | Meaning |
|--------|-------|---------|
| **⟳ cooking** | Cyan | Node was actually cooked this frame (time-dependent, param changed, or first cook) |
| **— cached** | Gray | Valid output from a previous cook; skipped this frame (no work done) |
| **● dirty** | Orange | Marked dirty but hasn't cooked yet (waiting in queue) |
| **✗ error** | Red | Last cook failed (returned null) |
| **inactive** | Dim gray | Not in any active chain (no sink downstream) |

A static node (e.g. ConstantTOP) will show "⟳ cooking" once on creation, then
settle to "— cached" on every subsequent frame. A node cooks every frame only
while its own logic says it is live: MovieFileInTOP while it is playing at a
non-zero speed, NoiseTOP while its time offset reads time. RenderTOP cooks
every frame while it is in the active chain.

**Multi-select:** Ctrl+click or Shift+click to select multiple rows in any tab.

**Clipboard buttons (toolbar):**

| Button | Shortcut | Action |
|--------|----------|--------|
| **Copy Selected** | Ctrl+C | Copies selected rows as tab-separated text (with headers) |
| **Copy All** | — | Copies every row from the current tab to clipboard |

The output is tab-separated values, ready for pasting into spreadsheets,
text editors, or chat.

### Graph Overlay (5 Layers)

When Debug is active, toggle individual overlay layers with the sub-buttons:

| Toggle | Layer | What it shows |
|--------|-------|---------------|
| **#Order** | Cook order badges | Small `#N` on each node's top-left |
| **Dim** | Active chain dimming | Inactive nodes drawn at 40% opacity |
| **Dirty** | Dirty propagation flash | Orange border flash on nodes dirtied this frame |
| **Sinks** | Sink labels | Colored halo rings on sinks, dots on upstream |
| **Flow** | Data flow annotations | Data dimensions on wires (resolution, channels, vertices, etc.) |

---

## Clipboard Export (Context Menu)

Three context menu entries for sharing node networks and debug information:

| Menu Item | Needs | What it copies |
|-----------|-------|----------------|
| **Copy as JSON** | 1+ nodes selected | Selected nodes + their connections as pretty-printed JSON |
| **Copy Debug Info** | Exactly 1 node | Full state dump: type, family, params, output, connections, warnings, cook time |
| **Copy Network JSON** | — | Entire network (all nodes, connections, metadata) as JSON |

**Use cases:**
- Share a node configuration with someone via chat or email
- Paste debug info into a bug report
- Archive the full network state for comparison

---

## Settings Persistence

Editor state is saved to `user://gonodes_settings.cfg` via `_save_setting()` / `_load_setting()`. Persisted values include:

- Toggle states (Previews, Perf, Log, NRT)
- Log level, log file name, and how many lines the log panel draws (**Preferences**)
- NRT target FPS
- Split container offsets (panel sizes)
- Last opened patch path

**Interface scale** (Preferences → Interface) scales the entire GONODES editor UI at 100–200% and is stored in `user://gn_ui_prefs.cfg`. **Side panel minimum width** there defaults to 260 px, the viewer and parameter column's floor. The preset buttons stay at label width and move to the next line if that column is narrower.
