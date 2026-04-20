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

### UIs

| Operator | Description |
|----------|-------------|
| CornerDragUI | 4-corner drag pad — outputs positions as CHOP channels |
| BezierDragUI | 4×4 control point grid — outputs positions as CHOP channels |
| GridDragUI | NxM grid drag pad — outputs per-point offsets as CHOP channels |

## Interactive Viewer Overlays

QuadMapTOP, StonerTOP, BezierMapTOP and GridWarpTOP all support **interactive
viewer overlays**. When you view one of these TOPs in the viewer, draggable
control point handles appear directly on the output texture:

- **Click + drag** a handle to move it
- Handles highlight on hover and turn bright yellow when active
- Corner outlines / grid wireframe drawn for visual reference
- Param values update in real-time, triggering a re-cook

This uses the viewer's `set_texture_overlay()` API — a transparent Control
layer that draws in texture pixel space, automatically tracking pan/zoom.

## Standalone UI Operators

For use in PanelTOP or other UI-driven workflows, the extension provides
standalone drag widgets (CornerDragUI, BezierDragUI, GridDragUI). Each
outputs its state as CHOP channels with names matching the corresponding
mapping TOP's parameters — wire them via CHOP-to-param expressions.

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
