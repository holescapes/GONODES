# Annotations & Network Organization

Annotations help you organize and document complex patches. GONODES supports
**sticky notes** for adding comments and **network boxes** for visually
grouping related nodes.

---

## Sticky Notes

Sticky notes are colored labels you place directly on the graph canvas.
Use them to explain sections of your patch, leave reminders, or label
signal flow.

### Creating a Sticky Note

- **Right-click** the graph background → **Add Sticky Note**
- If nodes are selected, the note wraps around the selection automatically
- If nothing is selected, the note is placed at the cursor with a default
  size of 200 × 120 pixels

### Editing

- **Double-click** the note to open the inline text editor
- Type your text (multi-line, word wrapping enabled)
- Click outside the note or press **Tab** to finish editing
- Default text is "Note" — replace with your own content

### Moving and Resizing

- **Click and drag** the note body to move it
- **Drag the bottom-right corner** handle to resize (minimum 80 × 40)
- Notes move with nodes when you drag a selection that overlaps them

### Changing Color

- **Right-click** the note → **Change Color…**
- A color picker popup appears — choose any color
- Default color is yellow (ideal for contrast on dark backgrounds)

### Deleting

- **Right-click** the note → **Delete Note**

### Context Menu Summary

| Action | Result |
|--------|--------|
| Edit Text | Opens inline editor |
| Change Color… | Opens color picker |
| Delete Note | Removes the note |

---

## Network Boxes

Network boxes are larger rectangular annotations that visually group
related nodes. They sit behind nodes (lower z-order) and are useful
for marking logical sections of a patch.

### Creating a Network Box

- **Right-click** the graph background → **Add Network Box**
- If nodes are selected, the box wraps around them with padding
- Default size is 300 × 200, default color is blue, default label is "Group"

### Behavior

- Network boxes display a title label at the top
- They sit behind all nodes and sticky notes (z-index -10)
- When you drag nodes inside a box, the box can move with them

---

## Tips

- Use **color coding** to distinguish annotation types:
  yellow for notes, blue for groups, red for warnings, green for
  "done" sections.
- Place sticky notes at the **input** side of a node chain to explain
  what the chain does: "Audio → FFT → spectrum bars".
- Keep notes brief — a few words or one short sentence is ideal.
- Annotations are saved with the `.gnpatch` file and appear in
  example patches opened from the help system.
- You can have as many sticky notes and network boxes as you like —
  they have negligible performance cost.
