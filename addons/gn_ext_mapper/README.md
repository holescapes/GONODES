# gn_ext_mapper — Projection Mapping Extension

Projection mapping toolkit for GONODES, inspired by TouchDesigner's Kantan Mapper.
All operators are pure GDScript + GPU shaders — no native library compilation required.

## Operators

### TOPs

| Operator | Description |
|----------|-------------|
| QuadMapTOP | 4-corner pin perspective warp (DLT homography) |
| BezierMapTOP | 4×4 Bezier mesh warp for curved surface mapping |
| GridWarpTOP | NxM bilinear grid warp with per-point control params |
| StonerTOP | Multi-projector Stoner–stitching with softedge blending |
| EdgeBlendTOP | Soft-edge gradient blending for multi-projector overlap |
| ProjectionMaskTOP | Polygon/rectangle mask for selective projection |
| ProjectorBlendTOP | Multi-projector compositing with overlap compensation |

### Interactive panel output

QuadMapTOP, StonerTOP, BezierMapTOP, and GridWarpTOP expose a **panel** UI
output port (via `GNTopInteractiveBase`). Node params are the source of truth.
The viewer and WindowOUT each get their own interactive panel instance; both
stay in sync when you drag handles in either place:

```
ContentTOP → QuadMapTOP ─┬─ out (TOP)  → WindowOUT in  (+ viewer Out still interactive)
                         └─ panel (UI) → WindowOUT panel
```

Drag handles in the viewer **or** in WindowOUT — both update the same params.
(LED fixture handles use the same pattern on **FixtureSamplerTOP** in
`gn_ext_pixel_mapper` — not this extension.)

## Interactive Viewer Overlays

QuadMapTOP, StonerTOP, BezierMapTOP and GridWarpTOP support **interactive
viewer overlays**. When you view one of these TOPs in the viewer, draggable
control point handles appear directly on the output texture:

- **Click + drag** a handle to move it
- Handles highlight on hover and turn bright yellow when active
- Corner outlines / grid wireframe drawn for visual reference
- Param values update in real-time, triggering a re-cook

Implementation: `GNInteractivePanel` + `GNTopInteractiveBase` in core;
`set_interactive_texture_overlay()` on the viewer routes pointer events in UV space.

## SubNetwork Presets

Ready-made SubNetwork presets in `presets/`:

| Preset | Contents |
|--------|----------|
| quad_surface.gnpatch | InTunnel → QuadMapTOP → OutTunnel |
| stoner_surface.gnpatch | InTunnel → StonerTOP → OutTunnel |
| bezier_surface.gnpatch | InTunnel → BezierMapTOP → OutTunnel |
| grid_warp_surface.gnpatch | InTunnel → GridWarpTOP → OutTunnel |

## Workflow

Typical projection mapping pipeline:

```
ContentTOP → QuadMapTOP/BezierMapTOP → EdgeBlendTOP → WindowOUT (projector)
```

For multi-projector setups, use one mapping chain per projector region,
composited together before the final WindowOUT.

## Known Issues

- **GridWarpTOP** — Grid size is capped at 8×8 (64 control points).

## License

Pure GDScript + Godot shaders. Part of GONODES.
