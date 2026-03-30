# gn_ext_spout — Spout2 Texture Sharing Extension

Windows-only Spout2 texture sharing for GONODES. Allows sending and receiving
GPU textures between GONODES and other Spout-compatible applications (Resolume,
TouchDesigner, OBS with Spout plugin, etc.).

## Requirements

- **Windows only** — Spout uses DirectX 11 shared textures, which is a Windows-specific API.
- **godot-cpp** — shared from `gn_ext_native/native/godot-cpp/` (cloned by `setup_deps.py`).
- **Spout2 SDK** — cloned by `setup_deps.py` into `native/Spout2/` (gitignored).

## Setup

```bash
# From repo root (if not already done):
python setup_deps.py
```

Or manually:
```bash
git clone --depth 1 https://github.com/leadedge/Spout2.git addons/gn_ext_spout/native/Spout2
```

## Building

```powershell
cd addons/gn_ext_spout/native
scons platform=windows target=template_release -j4
```

## Operators

| Operator | Description |
|----------|-------------|
| SpoutInTOP | Receive shared texture from a named Spout sender |
| SpoutOutTOP | Share input texture as a named Spout sender |
