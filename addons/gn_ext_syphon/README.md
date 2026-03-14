# gn_ext_syphon — Syphon Texture Sharing Extension

macOS-only Syphon texture sharing for GONODES. Allows sending and receiving
GPU textures between GONODES and other Syphon-compatible applications (VDMX,
MadMapper, CoGe, Processing, etc.).

## Requirements

- **macOS only** — Syphon uses IOSurface for zero-copy GPU texture sharing.
- **godot-cpp** — shared via symlink from `gn_ext_native/native/godot-cpp/`.
- **Syphon framework** — cloned automatically by SConstruct or placed at
  `native/Syphon-Framework/`.

## Building

```bash
cd addons/gn_ext_syphon/native
# Clone Syphon if not present
git clone https://github.com/Syphon/Syphon-Framework.git
# Build
scons platform=macos target=template_release -j4
```

## Operators

| Operator | Family | Description |
|----------|--------|-------------|
| SyphonInTOP | TOP | Receive a shared texture from a Syphon server |
| SyphonOutTOP | TOP | Share a texture via Syphon to other applications |

## License

Syphon Framework is BSD-licensed. This extension wrapper is part of GONODES.
