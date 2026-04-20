# gn_ext_syphon — Syphon Texture Sharing Extension

macOS-only Syphon texture sharing for GONODES. Allows sending and receiving
GPU textures between GONODES and other Syphon-compatible applications (VDMX,
MadMapper, CoGe, Processing, etc.).

## Requirements

- **macOS only** — Syphon uses IOSurface for zero-copy GPU texture sharing.
- **godot-cpp** — shared via symlink from `gn_ext_native/native/godot-cpp/`.
- **Syphon Framework** — see setup below.

## Syphon Framework Setup

The Syphon Framework is **BSD-licensed** and is **not** bundled in the
repository. You must clone it yourself.

```bash
cd addons/gn_ext_syphon/native
git clone https://github.com/Syphon/Syphon-Framework.git
```

Or from the repo root:
```bash
python setup_deps.py
```

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

## Third-Party Licenses

This extension uses the [Syphon Framework](https://github.com/Syphon/Syphon-Framework)
(BSD 3-Clause, (c) Syphon Project contributors). The framework source is cloned
by the user and compiled with the extension.

Full license text is in `THIRD_PARTY_LICENSES` in this directory.
