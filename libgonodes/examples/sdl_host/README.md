# SDL Host Example

General-purpose GONODES embedding using **SDL2 + OpenGL 3.3**.

## What It Demonstrates

- Creating an SDL2 window with OpenGL context
- Sharing the GL context with GONODES via `gonodes_gpu_context_t`
- Loading a `.gnpatch` and cooking each frame
- Injecting an LFO value into a `HostInCHOP` node
- Rendering the output texture from a `HostOutTOP` as a fullscreen quad
- Auto-reload on patch file change
- Manual reload with the **R** key

## Build

```bash
cd libgonodes/build
cmake .. -DGONODES_BUILD_EXAMPLES=ON
cmake --build . --target sdl_host
```

## Run

A sample patch is included at `examples/patches/show.gnpatch`:

```bash
./sdl_host /path/to/gonodes_project ../patches/show.gnpatch
```

## Patch Layout

The included `show.gnpatch` contains:

1. **host_lfo** (`HostInCHOP`) — receives the sine LFO from the host
2. **noise1** (`NoiseTOP`) — animated noise driven by the host's LFO
3. **host_out** (`HostOutTOP`) — the texture rendered to screen

You can swap in your own patch — just keep the node IDs matching.

## Dependencies

- SDL2 (`brew install sdl2` / `apt install libsdl2-dev` / vcpkg)
- OpenGL 3.3+
- libgonodes (built from this repo)
- libgodot.dll / .so / .dylib (from Godot 4.6 source build with LibGodot enabled)
