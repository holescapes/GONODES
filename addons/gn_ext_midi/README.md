# gn_ext_midi — MIDI I/O Extension

Cross-platform MIDI input and output for GONODES using RtMidi.

## Platform Backends

| Platform | Backend |
|----------|---------|
| Windows | Windows Multimedia (WinMM) |
| macOS | CoreMIDI |
| Linux | ALSA |

## Building

```bash
cd addons/gn_ext_midi/native
scons platform=<windows|macos|linux> target=template_release -j4
```

Requires godot-cpp shared via junction/symlink from `gn_ext_native/native/godot-cpp/`.

## Operators

| Operator | Family | Description |
|----------|--------|-------------|
| RtMidiInCHOP | CHOP | Receive MIDI messages — notes, CC, pitch bend, etc. |
| RtMidiOutCHOP | CHOP | Send MIDI messages to external devices or DAWs |

## Third-Party Licenses

This extension bundles [RtMidi](https://github.com/thestk/rtmidi) (MIT,
(c) 2003-2023 Gary P. Scavone). No external SDKs are required — RtMidi
uses OS-provided MIDI APIs (WinMM / CoreMIDI / ALSA).

Full license text is in `THIRD_PARTY_LICENSES` in this directory.
