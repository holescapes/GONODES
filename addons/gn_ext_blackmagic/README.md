# Blackmagic Video I/O Extension

Professional SDI/HDMI video capture and output via the Blackmagic DeckLink SDK.

## Requirements

- **Hardware**: Any Blackmagic DeckLink capture/output card (DeckLink Mini Recorder, DeckLink 4K Extreme, UltraStudio, Intensity Pro, etc.)
- **Drivers**: [Blackmagic Desktop Video](https://www.blackmagicdesign.com/support/) drivers installed
- **SDK**: DeckLink SDK (C++ headers — bundled at build time)

## Architecture

```
GDScript operators ←→ GNBlackmagic (GDExtension) ←→ DeckLink SDK ←→ Hardware
```

The GDExtension (`GNBlackmagic`) wraps the DeckLink C++ API:
- Device enumeration (`IDeckLinkIterator`)
- Input capture (`IDeckLinkInput` → callback → ring buffer → Godot Image)
- Output playback (`IDeckLinkOutput` → scheduled frame output)

## Operators

| Operator | Family | Description |
|----------|--------|-------------|
| `BlackmagicInTOP` | TOP | Capture SDI/HDMI input as texture (UYVY → RGBA conversion) |
| `BlackmagicOutTOP` | TOP | Output TOP texture to SDI/HDMI (RGBA → UYVY conversion) |
| `BlackmagicDAT` | DAT | Device enumeration and info table |

## Supported Formats

- SD: NTSC, PAL
- HD: 720p50/59.94/60, 1080i50/59.94/60, 1080p23.98/24/25/29.97/30/50/59.94/60
- UHD: 2160p23.98/24/25/29.97/30/50/59.94/60
- 8K: 4320p (DeckLink 8K Pro)

## Build

See `native/` for build instructions. Requires:
1. Blackmagic DeckLink SDK headers (download from Blackmagic support)
2. godot-cpp (submodule)
3. SCons build system

```bash
cd native
scons platform=windows target=template_release
```

## Status

**Scaffold only** — GDScript operator shells are complete. The C++ GDExtension
(`GNBlackmagic`) needs to be implemented with the DeckLink SDK before the
operators will function. The operators will gracefully report "GNBlackmagic
not available" if the native library is not present.
