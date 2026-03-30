# Metal Host Example (macOS)

Demonstrates GONODES embedding with **Metal** for zero-copy texture sharing
on macOS.

## What It Demonstrates

- Creating an `MTLDevice` and `MTLCommandQueue`
- Sharing them with GONODES via `gonodes_gpu_context_t`
- Querying the **Host I/O manifest** via `gonodes_get_host_io()`
- Using an `MTKView` delegate for the render loop
- Blitting the output `MTLTexture` directly to the `CAMetalDrawable`
- Zero-copy: the texture lives on the same GPU — no staging copies

## Build (macOS only)

```bash
cd libgonodes/build
cmake .. -DGONODES_BUILD_EXAMPLES=ON
cmake --build . --target metal_host
```

## Run

A sample patch is included at `examples/patches/show.gnpatch`:

```bash
./metal_host /path/to/gonodes_project ../patches/show.gnpatch
```

## Dependencies

- macOS 12+ with Metal support
- Xcode command line tools
- libgonodes + libgodot
