# Vulkan Host Example

Demonstrates GONODES embedding with a **Vulkan** rendering context for
**zero-copy GPU texture sharing**.

## What It Demonstrates

- Creating a Vulkan instance, physical device, logical device, and queue
- Sharing the entire Vulkan device with GONODES via `gonodes_gpu_context_t`
- Loading a `.gnpatch` and cooking in a headless loop
- Reading the output `VkImage` handle directly — no CPU copies
- Performance stats via `gonodes_get_stats()`

## Key Concept: Zero-Copy

When the host and GONODES share the same `VkDevice`, output textures are
`VkImage` handles on the **same device memory**.  The host can bind them
directly in its own render pass — no staging buffer, no readback, no upload.

## Build

```bash
cd libgonodes/build
cmake .. -DGONODES_BUILD_EXAMPLES=ON
cmake --build . --target vulkan_host
```

## Run

A sample patch is included at `examples/patches/show.gnpatch`:

```bash
./vulkan_host /path/to/gonodes_project ../patches/show.gnpatch
```

## Dependencies

- Vulkan SDK 1.2+ (https://vulkan.lunarg.com/sdk/home)
- libgonodes + libgodot
