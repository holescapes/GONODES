# gn_ext_video_capture — Video Capture Device Extension

Cross-platform webcam and video capture device input for GONODES.

## Platform Backends

| Platform | API | Notes |
|----------|-----|-------|
| Windows | Media Foundation | Ships with Windows 7+, no extra dependencies |
| macOS | AVFoundation | Ships with macOS 10.7+, no extra dependencies |
| Linux | Video4Linux2 (V4L2) | Kernel-level API, no extra dependencies |

## Building

```bash
cd addons/gn_ext_video_capture/native
scons platform=windows target=template_release -j4   # Windows
scons platform=macos target=template_release -j4      # macOS
scons platform=linux target=template_release -j4      # Linux
```

Requires godot-cpp shared via junction/symlink from `gn_ext_native/native/godot-cpp/`.

## Operators

| Operator | Family | Description |
|----------|--------|-------------|
| VideoDeviceInTOP | TOP | Capture live video from a webcam or capture device |

## License

Uses only OS-provided APIs. This extension wrapper is part of GONODES.
