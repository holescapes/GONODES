# Visual Audit Packs

Human-driven visual review of GONODES operators.

## How to use

1. Run GONODES (Godot 4.7.2, Game embed off or Stretch to Fit).
2. **File → Open** a pack from this folder.
3. Follow the yellow note on the graph + `CHECKLIST.md`.
4. For packs with **WindowOUT**, set **Open = ON** if the window is closed.

## Contents

- `01`–`08` — curated capability demos (wired graphs).
- `gallery/*_inventory.gnpatch` — one instance of every registered op in that family.
- `CHECKLIST.md` — master tick list.

Regenerate after registry changes:

```bash
python scripts/gen_visual_audit_patches.py
```
