# gn_ext_mapper — Projection Mapping Extension

Projection mapping toolkit for GONODES, inspired by TouchDesigner's Kantan Mapper.
All operators are pure GDScript + GPU shaders — no native library compilation required.

## Operators

| Operator | Family | Description |
|----------|--------|-------------|
| QuadMapTOP | TOP | 4-corner pin perspective warp (DLT homography) |
| BezierMapTOP | TOP | 4×4 Bezier mesh warp for curved surface mapping |
| GridWarpTOP | TOP | NxM bilinear grid warp with per-point control params |
| StonerTOP | TOP | Multi-projector Stoner–stitching with softedge blending |
| EdgeBlendTOP | TOP | Soft-edge gradient blending for multi-projector overlap |
| ProjectionMaskTOP | TOP | Polygon/rectangle mask for selective projection |
| ProjectorBlendTOP | TOP | Multi-projector compositing with overlap compensation |

## Workflow

Typical projection mapping pipeline:

```
ContentTOP → QuadMapTOP/BezierMapTOP → EdgeBlendTOP → WindowOUT (projector)
```

For multi-projector setups, use one mapping chain per projector region,
composited together before the final WindowOUT.

## Known Issues

- **GridWarpTOP** — The displacement texture input (2nd input) reads the texture
  on the CPU via `get_image()`, which introduces a GPU→CPU readback stall.
  For real-time use, prefer the per-point offset parameters or keep displacement
  textures small (≤256×256). Grid size is capped at 8×8 (64 control points).

## License

Pure GDScript + Godot shaders. Part of GONODES.
