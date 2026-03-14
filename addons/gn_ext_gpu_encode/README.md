# gn_ext_gpu_encode — GPU Video Encoding Extension

Hardware-accelerated video encoding for GONODES. Records texture output to
video files using platform GPU encoders.

## Platform Backends

| Platform | API | Codecs |
|----------|-----|--------|
| Windows | Media Foundation | H.264 (via Intel QSV / AMD AMF / NVIDIA NVENC auto-selected) |
| macOS | VideoToolbox | H.264 / H.265 (Apple Silicon hardware encoder) |

## Building

```bash
cd addons/gn_ext_gpu_encode/native
scons platform=windows target=template_release -j4
scons platform=macos target=template_release -j4
```

Requires godot-cpp shared via junction/symlink from `gn_ext_native/native/godot-cpp/`.

## Operators

| Operator | Family | Description |
|----------|--------|-------------|
| MovieFileOutTOP | TOP | Record input texture to video file via GPU encoding |

## Notes

- Media Foundation and VideoToolbox automatically select the best available
  hardware encoder (Intel QSV, AMD AMF, NVIDIA NVENC on Windows; Apple M-series
  on macOS). No proprietary SDK dependencies.
- Container format: MP4 (`.mp4`).
- Falls back to software encoding if no GPU encoder is available.

## License

Uses only OS-provided APIs. This extension wrapper is part of GONODES.
