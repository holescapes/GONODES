# gn_ext_hap — HAP GPU-Direct Video Codec for GONODES

GONODES extension providing **HAP** video playback and recording — the standard
GPU-direct codec used by VJs and real-time visual artists.

## What is HAP?

[HAP](https://hap.video/) is a family of video codecs that store **S3TC/DXT
compressed texture data** in each frame. Unlike H.264 or ProRes, the GPU can
consume HAP frames directly — there is no CPU decode step, just a
`memcpy` → `glCompressedTexImage2D`. This makes HAP ideal for:

- Multi-layer VJ playback (8+ HD streams simultaneously)
- Low-latency video walls and projection mapping
- Any scenario where CPU decode is the bottleneck

### HAP Variants

| Variant   | DXT Format | Alpha | Quality | Size    |
|-----------|-----------|-------|---------|---------|
| **HAP**   | DXT1 (BC1) | No   | Good    | Small   |
| **HAP Alpha** | DXT5 (BC3) | Yes | Good | Medium |
| **HAP Q** | Scaled YCoCg DXT5 | No | Better | Larger |

## Requirements

This extension requires the **GNHapCodec** GDExtension (shipped in `native/`).
The native library wraps [Vidvox/hap](https://github.com/Vidvox/hap) (BSD
license) for frame-level DXT encode/decode, and uses
[AV Foundation](https://developer.apple.com/av-foundation/) (macOS) or a
minimal AVI/MOV muxer (Windows/Linux) for container I/O.

## Operators

| Operator     | Family | Description |
|-------------|--------|-------------|
| **HapInTOP**  | TOP | GPU-direct HAP video playback — DXT frames upload to GPU with zero CPU decode |
| **HapOUT** | OUT | Encode input texture to HAP video file (DXT compression on CPU, packaged in .mov) |

## Architecture

```
HapInTOP (.gd)                    HapOUT (.gd)
    │                                  │
    ▼                                  ▼
GNHapDecoder (C++)              GNHapEncoder (C++)
    │                                  │
    ├─ open(path)                      ├─ start(path, w, h, fps, variant)
    ├─ decode_next_frame()             ├─ encode_frame(rgba_data)
    │   → PackedByteArray (DXT)        │   (RGBA → DXT compress → write)
    ├─ get_width/height/fps()          ├─ finish()
    └─ close()                         └─ get_frame_count()
    │
    ▼
Image.create_from_data(w, h, false,
    Image.FORMAT_DXT1/DXT5, dxt_data)
    │
    ▼
ImageTexture (GPU upload — DXT native)
```

## How it Works (Decode)

1. **Container demux** — GNHapDecoder reads .mov container, extracts
   HAP-tagged frame chunks.
2. **Snappy decompress** — HAP frames are optionally Snappy-compressed;
   the native library transparently decompresses.
3. **DXT passthrough** — The raw DXT block data is returned as a
   `PackedByteArray`. No pixel-level decode happens on CPU.
4. **GPU upload** — GDScript creates an `Image` with `FORMAT_DXT1` or
   `FORMAT_DXT5` from the raw data, then uploads via `ImageTexture`.
   The GPU natively understands DXT — zero conversion.

## Platforms

- **Windows**: x86_64 (DLL)
- **macOS**: universal (Framework)
- **Linux**: x86_64 (SO)
