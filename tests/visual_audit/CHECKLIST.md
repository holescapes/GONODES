# GONODES Visual Audit Checklist

Open patches from `tests/visual_audit/` in the editor (File → Open).
For WindowOUT packs, confirm **Open** is ON (or toggle it).

## Capability demos

| Pack | Focus | Done |
|------|-------|------|
| `01_window_out_basics.gnpatch` | Open toggle, resolution, monitor | ☐ |
| `02_top_generators.gnpatch` | Noise/Ramp/Circle/… via Switch | ☐ |
| `03_top_filter_chain.gnpatch` | Blur → Level → HSV → Edge | ☐ |
| `04_mapper_dual_panel.gnpatch` | Viewer + WindowOUT handles sync | ☐ |
| `05_3d_render.gnpatch` | Box → Geo → Render → Window | ☐ |
| `06_ui_window_panel.gnpatch` | ContainerUI in WindowOUT panel | ☐ |
| `07_out_exporters.gnpatch` | Save/Movie/FFmpeg (keep Active OFF) | ☐ |
| `08_audio_spectrum_band.gnpatch` | FileIn → Spectrum → Band | ☐ |

## Family inventories (`gallery/`)

| Family | Ops | Patch | Done |
|--------|----:|-------|------|
| chop | 107 | `gallery/chop_inventory.gnpatch` | ☐ |
| comp | 27 | `gallery/comp_inventory.gnpatch` | ☐ |
| dat | 51 | `gallery/dat_inventory.gnpatch` | ☐ |
| fix | 8 | `gallery/fix_inventory.gnpatch` | ☐ |
| img | 41 | `gallery/img_inventory.gnpatch` | ☐ |
| mat | 12 | `gallery/mat_inventory.gnpatch` | ☐ |
| net | 15 | `gallery/net_inventory.gnpatch` | ☐ |
| output | 12 | `gallery/output_inventory.gnpatch` | ☐ |
| pop | 12 | `gallery/pop_inventory.gnpatch` | ☐ |
| script | 3 | `gallery/script_inventory.gnpatch` | ☐ |
| sdf | 29 | `gallery/sdf_inventory.gnpatch` | ☐ |
| sop | 85 | `gallery/sop_inventory.gnpatch` | ☐ |
| top | 138 | `gallery/top_inventory.gnpatch` | ☐ |
| ui | 33 | `gallery/ui_inventory.gnpatch` | ☐ |
| vol | 12 | `gallery/vol_inventory.gnpatch` | ☐ |

## Per-node notes

While reviewing a gallery node, tick if:

- [ ] Instantiates without error
- [ ] Params match `docs/OPERATORS.md` / tooltip help
- [ ] Cook produces expected family output in viewer
- [ ] File/folder params use pickers (not bare strings)
- [ ] Extension-gated ops warn clearly when DLL/model missing

Regenerate packs: `python scripts/gen_visual_audit_patches.py`
