# Graph Edit Demo

Demonstrates the v2.0 dynamic graph editing API (Gap 7 from the VDMX/VUO audit).

This capability is **unique vs TouchEngine** — TouchEngine's SDK only provides read-only graph access.  LibGONODES matches and exceeds VUO's dynamic composition modification.

## What It Shows

1. **Insert a node** — Disconnect an existing wire, create a BlurTOP, and re-wire it inline
2. **Build a chain** — Create multiple nodes (LevelTOP, HSVAdjustTOP) and wire a full processing pipeline programmatically
3. **Delete nodes** — Remove nodes (connections are auto-cleaned), then rewire
4. **Animated sweep** — Animate parameters on dynamically-created nodes over 30 frames
5. **Restore original** — Clean up all dynamic nodes and restore the original graph

## Build

```bash
cd libgonodes/build
cmake .. -DGONODES_BUILD_EXAMPLES=ON
cmake --build . --target graph_edit_demo
```

## Run

```bash
./graph_edit_demo path/to/gonodes_project path/to/graph_edit_base.gnpatch
```

## Patch Requirements

The demo expects a minimal patch with:
- `noise1` — a NoiseTOP node
- `host_out` — a HostOutTOP node
- A connection from `noise1` port 0 to `host_out` port 0

See `../patches/graph_edit_base.gnpatch`.
