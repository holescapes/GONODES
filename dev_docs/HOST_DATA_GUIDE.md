# Host App Data Format Guide

> **Audience:** Developers building host applications that inject data into and read data from GONODES patches via the libgonodes C API.

This guide documents the exact memory layouts, array formats, and field semantics for every data type that crosses the host–GONODES boundary. Each section covers one data family: what arrays to allocate, which fields are required vs optional, supported formats, and byte-level layout.

---

## Table of Contents

1. [General Rules](#1-general-rules)
2. [TOP — Textures / Images (CPU Path)](#2-top--textures--images-cpu-path)
3. [TOP — Textures (GPU Path)](#3-top--textures-gpu-path)
4. [CHOP — Channels (Float Samples)](#4-chop--channels-float-samples)
5. [DAT — Tables (JSON Text)](#5-dat--tables-json-text)
6. [SOP — Geometry (Vertex Data)](#6-sop--geometry-vertex-data)
7. [VOL — Volumetric Grids](#7-vol--volumetric-grids)
8. [POP — Particle Systems](#8-pop--particle-systems)
9. [Output Reading Summary](#9-output-reading-summary)
10. [Format Enum Reference](#10-format-enum-reference)
11. [Error Handling](#11-error-handling)

---

## 1. General Rules

**Pointer lifetime:** All input data pointers must remain valid until `gonodes_cook_frame()` returns. GONODES reads directly from your buffers via a single `memcpy` during the cook — after the call returns, you may free or overwrite your buffers.

**Zero-copy design:** The C API passes pointer addresses through an internal command queue. The GONODES engine reads your data with exactly one `memcpy` per data type — no temp files, no serialization, no double copies. For tightly-packed pixel data, the original pointer is used directly; for row-padded pixels, the API allocates a packed copy automatically (freed after the cook).

**Output pointer lifetime:** All `const` pointers returned by `gonodes_get_output_*()` are valid only until the *next* call to `gonodes_cook_frame()`. Copy any data you need to retain.

**Coordinate system:** GONODES uses a right-handed Y-up coordinate system (same as Godot). Positions are in world units (meters by convention). UV coordinates use bottom-left origin (0,0) to top-right (1,1).

**Byte order:** All data is native-endian (host CPU byte order). No byte-swapping is performed.

**NULL = omitted:** For optional fields (normals, UVs, velocities, colors, ages), pass `NULL` to omit. GONODES will use default values or skip that attribute.

---

## 2. TOP — Textures / Images (CPU Path)

### Input: `gonodes_set_input_pixels()`

Pushes raw pixel data into a **HostInTOP** node from CPU memory.

```c
int gonodes_set_input_pixels(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const void* pixels,     // Row-major pixel data, top-to-bottom
    int width,              // Image width in pixels (> 0)
    int height,             // Image height in pixels (> 0)
    int format,             // gonodes_texture_format enum
    int row_stride           // Bytes per row (0 = tightly packed)
);
```

#### Memory Layout

Pixels are stored in **row-major order, top-to-bottom** (row 0 is the top of the image). Each row contains `width` pixels, each pixel occupying `bpp` bytes determined by the format.

```
Row 0:  [pixel_0] [pixel_1] [pixel_2] ... [pixel_(w-1)] [padding...]
Row 1:  [pixel_0] [pixel_1] [pixel_2] ... [pixel_(w-1)] [padding...]
...
Row h-1: [pixel_0] [pixel_1] ... [pixel_(w-1)] [padding...]
```

- **Tightly packed** (`row_stride = 0`): each row is exactly `width × bpp` bytes, no padding.
- **Padded rows** (`row_stride > 0`): each row starts at offset `row × row_stride`. The first `width × bpp` bytes are pixel data; remaining bytes are padding (ignored by GONODES). Use this when your source image has alignment padding (e.g., OpenCV's `cv::Mat.step`).

#### Pixel Component Order by Format

| Format | Enum | BPP | Component Order | Component Type | Typical Use |
|--------|------|-----|-----------------|----------------|-------------|
| `GONODES_FORMAT_RGBA8` | 0 | 4 | R, G, B, A | uint8 (0–255) | Standard color + alpha |
| `GONODES_FORMAT_RGBA16F` | 1 | 8 | R, G, B, A | float16 (IEEE 754) | HDR color |
| `GONODES_FORMAT_RGBA32F` | 2 | 16 | R, G, B, A | float32 | Full-precision HDR |
| `GONODES_FORMAT_R8` | 3 | 1 | R | uint8 (0–255) | Grayscale / mask |
| `GONODES_FORMAT_RG8` | 4 | 2 | R, G | uint8 (0–255) | Normal map (2-channel) |
| `GONODES_FORMAT_BGRA8` | 5 | 4 | B, G, R, A | uint8 (0–255) | Windows GDI / DirectShow |
| `GONODES_FORMAT_R16F` | 6 | 2 | R | float16 | Depth / displacement |
| `GONODES_FORMAT_RG16F` | 7 | 4 | R, G | float16 | Motion vectors |

#### Buffer Size Calculation

```c
int bpp;  // from table above
int tight_row = width * bpp;
int actual_row = (row_stride > 0) ? row_stride : tight_row;
size_t total_bytes = (size_t)actual_row * height;
```

#### Example: Push a 1920×1080 RGBA8 Frame

```c
uint8_t* frame = my_camera_get_frame();  // 1920 × 1080 × 4 = 8,294,400 bytes

gonodes_set_input_pixels(gn, patch, "host_in_top",
    frame,                      // pixels
    1920, 1080,                 // width, height
    GONODES_FORMAT_RGBA8,       // format
    0);                         // row_stride (0 = tightly packed)
```

#### Example: Push with Row Padding (OpenCV)

```c
cv::Mat bgr_frame = capture.read();
cv::Mat rgba_frame;
cv::cvtColor(bgr_frame, rgba_frame, cv::COLOR_BGR2RGBA);

gonodes_set_input_pixels(gn, patch, "host_in_top",
    rgba_frame.data,
    rgba_frame.cols, rgba_frame.rows,
    GONODES_FORMAT_RGBA8,
    (int)rgba_frame.step[0]);   // row_stride includes padding
```

#### Example: Push BGRA8 (Windows Capture / DirectShow)

```c
// DirectShow / MSMF delivers BGRA8 — pass directly, no conversion needed.
gonodes_set_input_pixels(gn, patch, "cam_in",
    bgra_buffer,
    1920, 1080,
    GONODES_FORMAT_BGRA8,
    0);
```

#### Example: Push HDR Data (float32)

```c
// EXR loader delivers RGBA float32 — 16 bytes per pixel.
float* hdr_pixels = load_exr("environment.exr", &w, &h);

gonodes_set_input_pixels(gn, patch, "hdr_in",
    hdr_pixels, w, h,
    GONODES_FORMAT_RGBA32F,
    0);
```

### Output: `gonodes_read_output_pixels()`

Reads output texture into a CPU buffer (GPU→CPU readback).

```c
int bpp = 4;  // RGBA8
int buf_size = width * height * bpp;
uint8_t* out = (uint8_t*)malloc(buf_size);

int bytes_written = gonodes_read_output_pixels(gn, patch, "host_out_top",
    out, buf_size, GONODES_FORMAT_RGBA8, &out_w, &out_h);
```

Returns the number of bytes written, or a negative error code. Pre-allocate enough space — use `gonodes_get_texture_info()` first if you don't know the output size.

---

## 3. TOP — Textures (GPU Path)

### Input: `gonodes_set_input_texture()`

Pushes a native GPU texture handle — **zero-copy** when host and GONODES share the same GPU device.

```c
int gonodes_set_input_texture(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    uint64_t texture_handle,    // VkImage / GLuint / MTLTexture*
    int width, int height,
    int format                   // gonodes_texture_format enum
);
```

The handle type depends on the graphics API:

| API | Handle Type | Cast |
|-----|-------------|------|
| Vulkan | `VkImage` | `(uint64_t)vk_image` |
| OpenGL | `GLuint` | `(uint64_t)gl_texture_id` |
| Metal | `MTLTexture*` | `(uint64_t)(void*)mtl_texture` |

### Output: `gonodes_get_output_texture()`

```c
int out_w, out_h;
uint64_t tex = gonodes_get_output_texture(gn, patch, "host_out", &out_w, &out_h);
// tex is a VkImage / GLuint / MTLTexture* — same API as the shared GPU context.
```

---

## 4. CHOP — Channels (Float Samples)

### Input: `gonodes_set_input_chop()` — Single Channel

Pushes one named channel into a **HostInCHOP** node. Call multiple times for multiple channels.

```c
int gonodes_set_input_chop(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const char* channel_name,   // e.g., "tx", "rx", "audio_l"
    const float* samples,       // Array of float32 samples
    int num_samples              // Number of samples (> 0)
);
```

#### Memory Layout

```
samples[0]  samples[1]  samples[2]  ...  samples[num_samples-1]
  float       float       float              float
```

Each sample is a 32-bit IEEE 754 float. No interleaving — this pushes a single channel. For multi-channel data, call once per channel or use the `_direct` variant below.

#### Limits

- Max ~1000 samples per push via the command-queue path (values are CSV-encoded into a 4 KB data buffer).
- For larger channel data, use `gonodes_set_input_chop_direct()`.

#### Example: Push Sensor Data

```c
// Three channels: accelerometer XYZ, 1 sample each (current value).
float ax = 0.5f, ay = -9.8f, az = 0.1f;
gonodes_set_input_chop(gn, patch, "accel_in", "tx", &ax, 1);
gonodes_set_input_chop(gn, patch, "accel_in", "ty", &ay, 1);
gonodes_set_input_chop(gn, patch, "accel_in", "tz", &az, 1);
```

### Input: `gonodes_set_input_chop_direct()` — Multi-Channel

Pushes all channels in one call via pointer lending. No size limit.

```c
int gonodes_set_input_chop_direct(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const char** channel_names,   // Array of C strings
    const float** channel_data,   // Array of float* pointers (one per channel)
    const int* sample_counts,     // Samples per channel
    int num_channels               // Number of channels
);
```

#### Memory Layout

Channels are **not interleaved**. Each channel is a separate contiguous float array:

```
channel_names:  ["chan0",       "chan1",       "chan2"     ]
channel_data:   [float* → [...], float* → [...], float* → [...]]
sample_counts:  [1024,          1024,          512        ]
```

Channels can have different sample counts.

#### Example: Push Audio Buffers

```c
const char* names[] = {"audio_l", "audio_r"};
float left[512], right[512];
// ... fill buffers from audio callback ...
const float* data[] = {left, right};
int counts[] = {512, 512};

gonodes_set_input_chop_direct(gn, patch, "audio_in", names, data, counts, 2);
```

### Output: `gonodes_get_output_chop()` — Single Channel

```c
float buffer[4096];
int n = gonodes_get_output_chop(gn, patch, "host_out_chop", "tx", buffer, 4096);
// n = number of samples written.
```

### Output: `gonodes_get_output_chop_direct()` — All Channels

```c
gonodes_chop_data_t chop;
gonodes_get_output_chop_direct(gn, patch, "host_out_chop", &chop);

for (int i = 0; i < chop.channel_count; ++i) {
    printf("Channel '%s': %d samples\n",
           chop.channels[i].name, chop.channels[i].num_samples);
    // chop.channels[i].samples[0..num_samples-1]
}
// chop.sample_rate — nominal sample rate (Hz)
```

---

## 5. DAT — Tables (JSON Text)

### Input: `gonodes_set_input_table()`

Pushes JSON-encoded table data into a **HostInDAT** node.

```c
int gonodes_set_input_table(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const char* json_data       // JSON string (null-terminated)
);
```

#### JSON Format

Tables are 2D row-major arrays. The first row is the header:

```json
[
  ["name",   "x",    "y",    "active"],
  ["point1", "1.0",  "2.5",  "true"],
  ["point2", "-0.5", "3.1",  "false"]
]
```

All cell values are strings. GONODES operators parse numeric strings as needed.

For key–value text data, use a single-column table:

```json
[["text"], ["Hello, World!"]]
```

#### Limits

- Command-queue path: max ~4 KB JSON per push (truncated silently).
- For larger tables, use `gonodes_set_input_table_direct()`.

### Input: `gonodes_set_input_table_direct()`

Pointer-lending variant — no size limit.

```c
int gonodes_set_input_table_direct(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const char* json_data,      // JSON string (need not be null-terminated)
    int length                   // Byte length of json_data
);
```

### Output: `gonodes_get_output_table()`

```c
const char* json = gonodes_get_output_table(gn, patch, "host_out_dat");
// json is a null-terminated JSON string — valid until next cook_frame().
// Parse with your preferred JSON library.
```

---

## 6. SOP — Geometry (Vertex Data)

### Input: `gonodes_set_input_geometry()`

Pushes vertex attributes into a **HostInSOP** node.

```c
int gonodes_set_input_geometry(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const float* positions,     // REQUIRED — xyz per vertex
    const float* normals,       // Optional (NULL to omit)
    const float* uvs,           // Optional (NULL to omit)
    int vertex_count,           // Number of vertices (> 0)
    const uint32_t* indices,    // Optional (NULL = non-indexed)
    int index_count              // Number of indices (0 if non-indexed)
);
```

#### Required vs Optional Fields

| Field | Required | Elements per Vertex | Type | Default if NULL |
|-------|----------|---------------------|------|-----------------|
| `positions` | **Yes** | 3 (x, y, z) | float32 | — |
| `normals` | No | 3 (nx, ny, nz) | float32 | Auto-computed by GONODES |
| `uvs` | No | 2 (u, v) | float32 | All zeros |
| `indices` | No | 1 per index | uint32 | Non-indexed draw |

#### Memory Layout — Positions

Flat array of `float`, 3 components per vertex (x, y, z), tightly packed:

```
positions[0]  = vertex_0.x
positions[1]  = vertex_0.y
positions[2]  = vertex_0.z
positions[3]  = vertex_1.x
positions[4]  = vertex_1.y
positions[5]  = vertex_1.z
...
positions[vertex_count*3 - 1] = last_vertex.z
```

Total: `vertex_count × 3` floats = `vertex_count × 12` bytes.

#### Memory Layout — Normals

Same layout as positions: 3 floats per vertex (nx, ny, nz). Unit-length vectors recommended but not enforced.

```
normals[0] = vertex_0.nx,  normals[1] = vertex_0.ny,  normals[2] = vertex_0.nz
normals[3] = vertex_1.nx,  ...
```

Total: `vertex_count × 3` floats = `vertex_count × 12` bytes.

#### Memory Layout — UVs

2 floats per vertex (u, v):

```
uvs[0] = vertex_0.u,  uvs[1] = vertex_0.v
uvs[2] = vertex_1.u,  uvs[3] = vertex_1.v
...
```

Total: `vertex_count × 2` floats = `vertex_count × 8` bytes.

#### Memory Layout — Indices

Flat array of `uint32_t`. For triangles, every 3 consecutive indices form one triangle:

```
indices[0], indices[1], indices[2]  →  triangle 0
indices[3], indices[4], indices[5]  →  triangle 1
...
```

Total: `index_count` uint32s = `index_count × 4` bytes. When `indices` is NULL (non-indexed), GONODES draws `vertex_count / 3` triangles directly.

### Input: `gonodes_set_input_geometry_direct()`

Extended variant with vertex colors:

```c
int gonodes_set_input_geometry_direct(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const float* positions,     // REQUIRED — 3 floats per vertex
    const float* normals,       // Optional (NULL)
    const float* uvs,           // Optional (NULL)
    const float* colors,        // Optional — 4 floats per vertex (RGBA)
    int vertex_count,
    const uint32_t* indices,    // Optional (NULL)
    int index_count
);
```

The `colors` array adds per-vertex RGBA color (4 float32 per vertex, range 0.0–1.0):

```
colors[0] = vertex_0.r,  colors[1] = vertex_0.g
colors[2] = vertex_0.b,  colors[3] = vertex_0.a
colors[4] = vertex_1.r,  ...
```

Total: `vertex_count × 4` floats = `vertex_count × 16` bytes.

#### Example: Push a Triangle

```c
float positions[] = {
     0.0f,  1.0f, 0.0f,   // vertex 0: top
    -1.0f, -1.0f, 0.0f,   // vertex 1: bottom-left
     1.0f, -1.0f, 0.0f    // vertex 2: bottom-right
};

gonodes_set_input_geometry(gn, patch, "host_in_sop",
    positions,   // positions (required)
    NULL,        // normals   (omitted — auto-compute)
    NULL,        // uvs       (omitted)
    3,           // vertex_count
    NULL,        // indices   (non-indexed)
    0);          // index_count
```

#### Example: Push an Indexed Quad with UVs

```c
float positions[] = {
    -1.0f, -1.0f, 0.0f,   // v0: bottom-left
     1.0f, -1.0f, 0.0f,   // v1: bottom-right
     1.0f,  1.0f, 0.0f,   // v2: top-right
    -1.0f,  1.0f, 0.0f    // v3: top-left
};
float normals[] = {
    0.0f, 0.0f, 1.0f,     // all face +Z
    0.0f, 0.0f, 1.0f,
    0.0f, 0.0f, 1.0f,
    0.0f, 0.0f, 1.0f
};
float uvs[] = {
    0.0f, 0.0f,            // v0
    1.0f, 0.0f,            // v1
    1.0f, 1.0f,            // v2
    0.0f, 1.0f             // v3
};
uint32_t indices[] = {
    0, 1, 2,               // triangle 0
    0, 2, 3                // triangle 1
};

gonodes_set_input_geometry(gn, patch, "mesh_in",
    positions, normals, uvs, 4,    // 4 vertices
    indices, 6);                    // 6 indices (2 triangles)
```

### Output: `gonodes_get_output_geometry()`

```c
const gonodes_geometry_data_t* geo = gonodes_get_output_geometry(gn, patch, "host_out_sop");
if (geo) {
    // geo->positions: float[vertex_count * 3]
    // geo->normals:   float[vertex_count * 3] or NULL
    // geo->uvs:       float[vertex_count * 2] or NULL
    // geo->colors:    float[vertex_count * 4] or NULL
    // geo->indices:   uint32_t[index_count] or NULL
    // geo->primitive_type: 0=triangles, 1=lines, 2=points
}
```

---

## 7. VOL — Volumetric Grids

### Input: `gonodes_set_input_volume()` (CPU)

Pushes a 3D voxel grid into a **HostInVOL** node.

```c
int gonodes_set_input_volume(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const float* voxels,        // Flat voxel array
    int width,                   // Grid X dimension
    int height,                  // Grid Y dimension
    int depth,                   // Grid Z dimension
    int channels,                // Values per voxel (1–4)
    const char* field_name       // Semantic label (e.g., "density", "velocity")
);
```

#### Memory Layout

Voxels are stored in **X-major** order (X varies fastest, then Y, then Z), with `channels` float32 values per voxel:

```
Index = ((z * height + y) * width + x) * channels + c

voxels[0]  = voxel(0,0,0).channel_0
voxels[1]  = voxel(0,0,0).channel_1   (if channels >= 2)
...
voxels[channels]   = voxel(1,0,0).channel_0
voxels[channels+1] = voxel(1,0,0).channel_1
...
```

Total: `width × height × depth × channels` floats = `w × h × d × ch × 4` bytes.

#### Field Names

The `field_name` is a semantic label that tells downstream operators how to interpret the data:

| Field Name | Channels | Typical Use |
|------------|----------|-------------|
| `"density"` | 1 | Smoke/fog density, SDF fields |
| `"temperature"` | 1 | Heat maps, thermal sims |
| `"velocity"` | 3 | Velocity fields (vx, vy, vz) |
| `"color"` | 3–4 | Colored volumes (RGB or RGBA) |
| `"pressure"` | 1 | Fluid pressure fields |

Pass `NULL` for field_name to default to `"density"`.

#### Example: Push a 64³ Density Field

```c
const int W = 64, H = 64, D = 64;
float* voxels = (float*)malloc(W * H * D * sizeof(float));

// Fill with a sphere SDF:
for (int z = 0; z < D; ++z)
    for (int y = 0; y < H; ++y)
        for (int x = 0; x < W; ++x) {
            float fx = (float)x / W - 0.5f;
            float fy = (float)y / H - 0.5f;
            float fz = (float)z / D - 0.5f;
            float dist = sqrtf(fx*fx + fy*fy + fz*fz);
            voxels[(z * H + y) * W + x] = dist < 0.3f ? 1.0f : 0.0f;
        }

gonodes_set_input_volume(gn, patch, "vol_in",
    voxels, W, H, D,
    1,                  // 1 channel (scalar density)
    "density");         // field name

free(voxels);
```

#### Example: Push a 3-Channel Velocity Field

```c
const int W = 32, H = 32, D = 32;
float* voxels = (float*)malloc(W * H * D * 3 * sizeof(float));

for (int z = 0; z < D; ++z)
    for (int y = 0; y < H; ++y)
        for (int x = 0; x < W; ++x) {
            int i = ((z * H + y) * W + x) * 3;
            voxels[i + 0] = 0.0f;    // vx
            voxels[i + 1] = 1.0f;    // vy (upward)
            voxels[i + 2] = 0.0f;    // vz
        }

gonodes_set_input_volume(gn, patch, "vel_in",
    voxels, W, H, D,
    3,                  // 3 channels (velocity XYZ)
    "velocity");

free(voxels);
```

### Input: `gonodes_set_input_volume_gpu()` (GPU)

Pushes a native 3D texture handle — zero-copy.

```c
int gonodes_set_input_volume_gpu(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    uint64_t texture_handle,    // VkImage / GLuint / MTLTexture* (3D texture)
    int width, int height, int depth, int channels,
    const char* field_name
);
```

### Output: `gonodes_get_output_volume_gpu()`

```c
gonodes_volume_gpu_handle_t vol;
gonodes_get_output_volume_gpu(gn, patch, "vol_out", &vol);
// vol.native_handle — 3D texture handle
// vol.width, vol.height, vol.depth, vol.channels, vol.format
```

> **Note:** `gonodes_get_output_volume()` (CPU readback) is not yet implemented. Use the GPU variant.

---

## 8. POP — Particle Systems

### Input: `gonodes_set_input_particles()` (CPU)

Pushes particle attribute arrays into a **HostInPOP** node.

```c
int gonodes_set_input_particles(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    const float* positions,     // REQUIRED — xyz per particle
    const float* velocities,    // Optional (NULL to omit)
    const float* colors,        // Optional (NULL to omit)
    const float* ages,          // Optional (NULL to omit)
    int particle_count           // Number of particles (> 0)
);
```

#### Required vs Optional Fields

| Field | Required | Elements per Particle | Type | Default if NULL |
|-------|----------|----------------------|------|-----------------|
| `positions` | **Yes** | 3 (x, y, z) | float32 | — |
| `velocities` | No | 3 (vx, vy, vz) | float32 | (0, 0, 0) |
| `colors` | No | 4 (r, g, b, a) | float32 | (1, 1, 1, 1) white |
| `ages` | No | 1 | float32 | 0.0 |

#### Memory Layout — Positions

Same as SOP positions: 3 floats per particle, tightly packed.

```
positions[0] = p0.x,  positions[1] = p0.y,  positions[2] = p0.z
positions[3] = p1.x,  positions[4] = p1.y,  positions[5] = p1.z
...
```

Total: `particle_count × 3` floats = `particle_count × 12` bytes.

#### Memory Layout — Velocities

3 floats per particle (vx, vy, vz). Units: meters/second.

```
velocities[0] = p0.vx,  velocities[1] = p0.vy,  velocities[2] = p0.vz
velocities[3] = p1.vx,  ...
```

Total: `particle_count × 3` floats = `particle_count × 12` bytes.

#### Memory Layout — Colors

4 floats per particle (r, g, b, a). Range: 0.0–1.0, but values > 1.0 are valid for HDR.

```
colors[0] = p0.r,  colors[1] = p0.g,  colors[2] = p0.b,  colors[3] = p0.a
colors[4] = p1.r,  ...
```

Total: `particle_count × 4` floats = `particle_count × 16` bytes.

#### Memory Layout — Ages

1 float per particle. Typically seconds since birth. Used by particle operators for lifetime-based effects.

```
ages[0] = p0.age,  ages[1] = p1.age,  ages[2] = p2.age,  ...
```

Total: `particle_count` floats = `particle_count × 4` bytes.

#### Example: Push Only Positions (Minimum)

```c
float positions[] = {
    0.0f, 0.0f, 0.0f,    // particle 0
    1.0f, 2.0f, 0.0f,    // particle 1
    3.0f, 1.0f, -1.0f    // particle 2
};

gonodes_set_input_particles(gn, patch, "pop_in",
    positions,
    NULL,       // no velocities
    NULL,       // no colors
    NULL,       // no ages
    3);         // 3 particles
```

#### Example: Push Full Particle State

```c
const int N = 10000;
float* pos = (float*)malloc(N * 3 * sizeof(float));
float* vel = (float*)malloc(N * 3 * sizeof(float));
float* col = (float*)malloc(N * 4 * sizeof(float));
float* age = (float*)malloc(N * sizeof(float));

for (int i = 0; i < N; ++i) {
    pos[i*3+0] = random_float(-5, 5);    // x
    pos[i*3+1] = random_float(0, 10);    // y
    pos[i*3+2] = random_float(-5, 5);    // z

    vel[i*3+0] = 0.0f;                   // vx
    vel[i*3+1] = random_float(1, 5);     // vy (upward)
    vel[i*3+2] = 0.0f;                   // vz

    col[i*4+0] = 1.0f;                   // r
    col[i*4+1] = 0.5f;                   // g
    col[i*4+2] = 0.0f;                   // b
    col[i*4+3] = 1.0f;                   // a

    age[i] = (float)i * 0.01f;           // staggered ages
}

gonodes_set_input_particles(gn, patch, "pop_in",
    pos, vel, col, age, N);

free(pos); free(vel); free(col); free(age);
```

### Input: `gonodes_set_input_particles_gpu()` (GPU)

Pushes a native SSBO / buffer handle — zero-copy.

```c
int gonodes_set_input_particles_gpu(
    gonodes_instance_t inst, gonodes_patch_t patch,
    const char* node_id,
    uint64_t buffer_handle,     // VkBuffer / MTLBuffer / GL buffer object
    int particle_count,
    int stride,                  // Bytes per particle in the buffer
    int buffer_size              // Total buffer size in bytes
);
```

The buffer layout (attribute packing, stride) must match what the GONODES POP operators expect. See the `gonodes_particle_gpu_handle_t` struct for the output format.

### Output: `gonodes_get_output_particles_gpu()`

```c
gonodes_particle_gpu_handle_t pop;
gonodes_get_output_particles_gpu(gn, patch, "pop_out", &pop);
// pop.native_handle — GPU buffer handle
// pop.particle_count, pop.stride, pop.buffer_size
```

> **Note:** `gonodes_get_output_particles()` (CPU readback) is not yet implemented. Use the GPU variant.

---

## 9. Output Reading Summary

| Data Type | CPU Output | GPU Output |
|-----------|-----------|------------|
| **TOP** | `gonodes_read_output_pixels()` | `gonodes_get_output_texture()` |
| **CHOP** | `gonodes_get_output_chop()` / `_direct()` | — |
| **DAT** | `gonodes_get_output_table()` | — |
| **SOP** | `gonodes_get_output_geometry()` | — |
| **VOL** | *(not yet implemented)* | `gonodes_get_output_volume_gpu()` |
| **POP** | *(not yet implemented)* | `gonodes_get_output_particles_gpu()` |

---

## 10. Format Enum Reference

### `gonodes_texture_format`

| Name | Value | BPP | Channels | Component Type | Godot Image.Format |
|------|-------|-----|----------|----------------|-------------------|
| `GONODES_FORMAT_RGBA8` | 0 | 4 | 4 | uint8 | `FORMAT_RGBA8` |
| `GONODES_FORMAT_RGBA16F` | 1 | 8 | 4 | float16 | `FORMAT_RGBAH` |
| `GONODES_FORMAT_RGBA32F` | 2 | 16 | 4 | float32 | `FORMAT_RGBAF` |
| `GONODES_FORMAT_R8` | 3 | 1 | 1 | uint8 | `FORMAT_R8` |
| `GONODES_FORMAT_RG8` | 4 | 2 | 2 | uint8 | `FORMAT_RG8` |
| `GONODES_FORMAT_BGRA8` | 5 | 4 | 4 | uint8 | *(swizzled to RGBA8)* |
| `GONODES_FORMAT_R16F` | 6 | 2 | 1 | float16 | `FORMAT_RH` |
| `GONODES_FORMAT_RG16F` | 7 | 4 | 2 | float16 | `FORMAT_RGH` |

### `gonodes_graphics_api`

| Name | Value | Rendering Method |
|------|-------|------------------|
| `GONODES_GFX_AUTO` | 0 | Auto-detect best available |
| `GONODES_GFX_VULKAN` | 1 | `forward_plus` (Vulkan) |
| `GONODES_GFX_METAL` | 2 | `forward_plus` (Metal) |
| `GONODES_GFX_OPENGL` | 3 | `gl_compatibility` |
| `GONODES_GFX_MOBILE` | 4 | `mobile` (Vulkan/Metal mobile backend) |

---

## 11. Error Handling

All `gonodes_set_input_*()` functions return `GONODES_OK` (0) on success, or a negative error code:

| Code | Name | Meaning |
|------|------|---------|
| 0 | `GONODES_OK` | Success |
| -1 | `GONODES_ERR_INVALID_HANDLE` | NULL or invalid instance/patch handle |
| -5 | `GONODES_ERR_NODE_NOT_FOUND` | `node_id` not found, or NULL required param |
| -7 | `GONODES_ERR_BUFFER_TOO_SMALL` | Too many staged inputs (max 32 per type) |
| -99 | `GONODES_ERR_INTERNAL` | Internal error (e.g., temp file write failed) |

Use `gonodes_get_last_error(inst)` for a human-readable description of the most recent error.

```c
int err = gonodes_set_input_pixels(gn, patch, "host_in", pixels, w, h, fmt, 0);
if (err != GONODES_OK) {
    fprintf(stderr, "GONODES error %d: %s\n", err, gonodes_get_last_error(gn));
}
```
