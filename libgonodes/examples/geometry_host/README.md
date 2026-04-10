# Geometry Host Example

Demonstrates the v1.1.0 geometry/SOP exchange API (Gap 4 from the VDMX/VUO audit).

## What It Shows

- **Pushing geometry**: Generate a procedural grid and push vertex data into a `HostInSOP` node
- **Reading geometry**: Extract cooked geometry (positions, normals, UVs, indices) from SOP outputs
- **Texture info query**: Use `gonodes_get_texture_info()` to inspect output format metadata
- **Animated geometry**: Morph a mesh over time by re-pushing vertices each frame

## Build

```bash
cd libgonodes/build
cmake .. -DGONODES_BUILD_EXAMPLES=ON
cmake --build . --target geometry_host
```

## Run

```bash
./geometry_host path/to/gonodes_project path/to/geometry_demo.gnpatch
```

## Patch Requirements

The demo expects a patch with:
- `host_geo_in` — a `HostInSOP` node receiving geometry from the host
- `sop_out` — a SOP or COMP node whose geometry is read back
- `vis_out` — (optional) a `HostOutTOP` for texture info query

See `../patches/geometry_demo.gnpatch`.
