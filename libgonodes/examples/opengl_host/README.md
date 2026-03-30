# OpenGL Host Example

Minimal GONODES embedding with **GLFW + OpenGL 3.3**.

## What It Demonstrates

- Creating a GLFW window with an OpenGL 3.3 Core context
- Extracting the platform-specific GL context handle (HGLRC on Windows)
- Sharing it with GONODES for same-context texture access
- Querying the **Host I/O manifest** via `gonodes_get_host_io()`
- Rendering the GONODES output texture to the window

## Build

```bash
cd libgonodes/build
cmake .. -DGONODES_BUILD_EXAMPLES=ON
cmake --build . --target opengl_host
```

## Run

A sample patch is included at `examples/patches/show.gnpatch`:

```bash
./opengl_host /path/to/gonodes_project ../patches/show.gnpatch
```

## Dependencies

- GLFW 3.3+ (`brew install glfw` / `apt install libglfw3-dev` / vcpkg)
- OpenGL 3.3+
- libgonodes + libgodot
