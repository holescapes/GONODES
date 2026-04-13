# Custom Assets (.gnasset)

Custom assets let you promote sub-networks into reusable, shareable
operators with their own name, family, and parameter interface. They
appear in the palette and behave like built-in operators.

---

## Overview

A **custom asset** is a `.gnasset` JSON file that stores:
- **Identity** — operator name, family, description, author, version
- **Inner network** — the full node graph (same format as `.gnpatch`)
- **Parameter interface** — defined by spare parameters on the original
  SubNetwork

All instances of a custom asset share the same definition file. Edits to
the asset propagate to every instance.

---

## Creating a Custom Asset

### Step 1: Build a Sub-Network

Create a SubNetworkNode (Ctrl+G or manually) containing the inner nodes
and connections you want to reuse.

### Step 2: Define the Parameter Interface

Add spare parameters to the SubNetworkNode for each value you want exposed:

- **Add manually:** Right-click the SubNetwork → "Add Spare
  Parameter…" → choose type (Float, Int, Bool, String, Color, Vector2,
  Vector2i).
- **Promote from inside:** Dive into the sub-network, right-click any
  parameter on an inner node → "Promote to Parent (Spare Param)". This
  creates a spare parameter on the parent SubNetwork and auto-wires the
  inner param to read from it via `par("../", "name")`.

All spare parameters on the SubNetwork become the custom asset's public
interface. Zero spare parameters is valid (parameterless asset).

### Step 3: Promote to Custom Asset

Right-click the SubNetworkNode → "Promote to Custom Asset…"

Fill in the identity dialog:
- **Name** — the operator name shown in the palette
- **Family** — auto-detected from the inner network contents
- **Description** — brief description of what it does
- **Author / Version** — optional metadata
- **Save location** — project-local or user-global directory

Click "Create" — the `.gnasset` is saved and immediately available in the
palette under the Custom section.

---

## Using Custom Assets

Custom assets appear in the palette under:

```
Custom → Family → User → Asset Name
```

Add them to your graph just like any built-in operator. Each instance
references the shared `.gnasset` file.

---

## Editing a Custom Asset

### Viewing (Read-Only)

Double-click a custom asset node to dive in. The inner network opens in
**read-only mode** — no edits allowed. A 🔒 banner in the breadcrumb
indicates locked state.

### Editing In-Place

Click "Edit Asset Definition" in the breadcrumb banner. After making
changes, a confirmation dialog appears:

- **Save to All** — writes changes to the `.gnasset` file; all instances
  update.
- **Save As New Asset…** — creates a new `.gnasset` with a different name.
- **Cancel** — discards changes.

### Make Editable (One-Way)

Right-click a custom asset → "Make Editable" converts it into a plain
SubNetworkNode. The asset link is permanently severed. The inner nodes
become a standalone copy you can freely modify. This action is
irreversible.

---

## Export & Import

### Export Sub-Network as .gnpatch

Right-click a SubNetwork → "Export Sub-Network…" saves the inner network
as a standalone `.gnpatch` file. Unlike `.gnasset`, this is a stateless
snapshot with no link back to the source.

### Import .gnpatch

Right-click the graph background → "Import .gnpatch…" loads a `.gnpatch`
file and creates a SubNetworkNode with the loaded inner network.

### Drag-and-Drop

Drag `.gnpatch` or `.gnasset` files from your file manager directly onto
the graph canvas:
- **.gnpatch** → creates a SubNetworkNode
- **.gnasset** → creates a GNCustomOperator instance

---

## Extension-Shipped Assets

Extensions can include pre-built custom assets in their `assets/`
directory. These appear in the palette under the extension name and are
**read-only** — you cannot edit them in-place, but you can "Make Editable"
to create a local copy.

---

## .gnpatch vs .gnasset

| Feature | .gnpatch | .gnasset |
|---------|----------|----------|
| Purpose | Stateless snapshot | Shared linked definition |
| Tracking | None — fire-and-forget | All instances reference the file |
| Edit propagation | N/A | Edits update all instances |
| Parameter interface | None | Spare parameters |
| Palette appearance | N/A | Custom section |
| Format | JSON | JSON |

---

## Tips

- Use "Promote to Parent" inside a sub-network to quickly build up the
  parameter interface before promoting to a custom asset.
- Custom assets can contain other custom assets (nested).
- If you save a graph with unsaved asset edits, a dialog will ask
  whether to save the assets first.
- Extension-shipped assets can be overridden by user assets with the same
  name and family — user assets take priority.
