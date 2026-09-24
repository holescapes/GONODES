# Blackmagic Video I/O Extension

Professional SDI/HDMI video capture and output via the Blackmagic DeckLink SDK.

## Requirements

- **Hardware**: Any Blackmagic DeckLink capture/output card (DeckLink Mini Recorder, DeckLink 4K Extreme, UltraStudio, Intensity Pro, etc.)
- **Drivers**: [Blackmagic Desktop Video](https://www.blackmagicdesign.com/support/) drivers installed
- **SDK**: DeckLink SDK (C++ headers — see below)

## DeckLink SDK Setup

The DeckLink SDK is **proprietary** (free to download) and **cannot** be
bundled in GONODES. You must obtain it yourself.

### 1  Download the SDK

Go to <https://www.blackmagicdesign.com/support/> → **Developer SDK** section
→ download the **Blackmagic DeckLink SDK** for your platform.

### 2  Copy SDK Files

After extracting the SDK archive, copy the required files into:

```
addons/gn_ext_blackmagic/native/
└── decklink_sdk/
    └── include/
        ├── DeckLinkAPI.h
        ├── DeckLinkAPI_i.c
        └── (other DeckLink headers)
```

**Windows** — The SDK typically extracts to a folder like
`Blackmagic DeckLink SDK 14.x/Win/include/`.

**Linux** — The SDK has a `Linux/include/` folder.

### 3  Build

```bash
cd addons/gn_ext_blackmagic/native
scons platform=windows   # or linux
```

### 4  Runtime Requirements

At runtime you need:
- Blackmagic Desktop Video drivers installed
- A DeckLink card physically installed or a UltraStudio device connected

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
| `BlackmagicInIMG` | IMG | Capture SDI/HDMI input as texture (UYVY → RGBA conversion) |
| `BlackmagicOutIMG` | IMG | Output TOP texture to SDI/HDMI (RGBA → UYVY conversion) |
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
