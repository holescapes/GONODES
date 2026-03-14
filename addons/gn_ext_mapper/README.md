# gn_ext_mapper — Projection Mapping Extension

Projection mapping toolkit for GONODES, inspired by TouchDesigner's Kantan Mapper.
All operators are pure GDScript + GPU shaders — no native library compilation required.

## Operators

| Operator | Family | Description |
|----------|--------|-------------|
| QuadMapTOP | TOP | 4-corner pin perspective warp (homography) |
| BezierMapTOP | TOP | Bezier mesh warp for curved surface mapping |
| GridWarpTOP | TOP | Grid-based mesh warp with draggable control points |
| EdgeBlendTOP | TOP | Soft-edge gradient blending for multi-projector overlap |
| ProjectionMaskTOP | TOP | Polygon/rectangle mask for selective projection |

## Workflow

Typical projection mapping pipeline:

```
ContentTOP → QuadMapTOP/BezierMapTOP → EdgeBlendTOP → WindowOUT (projector)
```

For multi-projector setups, use one mapping chain per projector region,
composited together before the final WindowOUT.

## License

Pure GDScript + Godot shaders. Part of GONODES.
