# gn_ext_ffmpeg — FFmpeg Video Support for GONODES

GONODES extension that adds **FFmpegInTOP**, an FFmpeg-powered video decoder
supporting H.264, H.265, VP9, AV1, and many more codecs.

## Requirements

This extension requires the **EIRTeam.FFmpeg** GDExtension:
<https://github.com/EIRTeam/EIRTeam.FFmpeg>

A normal GONODES build treats this extension as `tier = extension` (`native/build.cfg`). Nothing here is compiled. The LGPL libraries are not downloaded.

### Setup

1. Download or build the EIRTeam.FFmpeg GDExtension from the repository above.
2. Place it in your project's `addons/` folder as `addons/EIRTeam.FFmpeg/`.
3. Restart Godot / GONODES.

GONODES detects it automatically via `ClassDB.class_exists("FFmpegVideoStream")`.
If EIRTeam.FFmpeg is **not** installed, this extension is silently skipped and
`FFmpegInTOP` does not appear in the palette.

### Licensing Note

EIRTeam.FFmpeg is **MIT** licensed. However, it links against FFmpeg libraries
which are **LGPL 2.1+** (or GPL if built with certain optional features).
If you distribute an application using this extension, review the FFmpeg
license terms. See `THIRD_PARTY_LICENSES` in this directory for details.

## How it works

| Component | Purpose |
|---|---|
| `gn_extension.cfg` | Manifest declaring the extension name, version, ClassDB dependencies, and operator list |
| `operators/top/ffmpeg_in_top.gd` | FFmpegInTOP operator — creates `FFmpegVideoStream` dynamically via ClassDB |

When GONODES starts, `GNExtensionRegistry.scan_extensions()` discovers this
folder (prefix `gn_ext_`), loads the manifest, checks that `FFmpegVideoStream`
exists in ClassDB, and — if satisfied — registers `FFmpegInTOP` in the operator
palette under the TOP family.

If the EIRTeam.FFmpeg GDExtension is **not** installed, the extension is
silently skipped and `FFmpegInTOP` does not appear.

## Operators

### FFmpegInTOP

| Parameter | Type | Default | Description |
|---|---|---|---|
| `file` | File | `""` | Video file path (.mp4, .mkv, .webm, .avi, .mov, .ogv, .flv, .wmv, .ts, .m4v) |
| `resolution` | Vector2i | 512×512 | Output resolution (auto-detected from video) |
| `play` | Bool | `true` | Play / pause toggle |
| `loop` | Bool | `true` | Loop playback |
| `speed` | Float | `1.0` | Playback speed multiplier |
| `seek` | Float | `-1.0` | Seek to time in seconds (-1 = disabled) |
| `bg_color` | Color | Black | Background color |
| `volume_db` | Float | `-80.0` | Audio volume in dB (-80 = muted) |

## vs MovieFileInTOP

| Feature | MovieFileInTOP (core) | FFmpegInTOP (this extension) |
|---|---|---|
| Always available | ✅ | Only with EIRTeam.FFmpeg |
| .ogv (Theora) | ✅ | ✅ |
| .mp4 / H.264 | Only if FFmpeg installed globally | ✅ (explicit FFmpegVideoStream) |
| .mkv / H.265 / VP9 / AV1 | Only if FFmpeg installed globally | ✅ |
| Guaranteed FFmpeg path | ❌ (uses Godot resource loader) | ✅ (ClassDB.instantiate) |
