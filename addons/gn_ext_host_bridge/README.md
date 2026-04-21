# gn_ext_host_bridge

Internal GDExtension bridge between the libgonodes C API and the GNEmbeddedHost GDScript singleton.

## Purpose

Replaces the per-frame environment-variable IPC layer with direct pointer-based
access to the C command queue and response slots. This is invisible infrastructure
that runs only in embedded (LibGodot) mode.

## Architecture

Two directions:

- **Inbound** (C -> GDScript): `GNHostBridge.drain_commands()` reads the C ring buffer
  directly and returns an Array of command dictionaries.
- **Outbound** (GDScript -> C): `GNHostBridge.set_*_output()` methods write data directly
  into the C response slot structs (tex, CHOP, DAT, param, introspection, stats).

All access is single-threaded: GDScript runs synchronously inside
`gn_bootstrap_iteration()`, so no locking is needed.

## Data Read Helpers

For CPU data injection (pixels, geometry, volume, particles, CHOP, DAT),
the C API passes pointer addresses through the command queue. GNHostBridge provides
`read_bytes()`, `read_float32()`, `read_int32()`, `read_image()`, `read_vector3()`,
`read_vector2()`, and `read_color()` methods that do a single memcpy from the
source pointer into Godot types.

## Build

```
cd addons/gn_ext_host_bridge/native
scons platform=<windows|linux|macos> target=template_release
```

Requires godot-cpp checked out to `godot-cpp/` subdirectory.
