# MIDI/OSC Host Example

Demonstrates the v2.0 protocol bridge, events, transport, and resolution APIs (Gaps 5, 6, 8, 10 from the VDMX/VUO audit).

## What It Shows

1. **MIDI event injection** — Note On/Off, CC messages, multi-channel chords
2. **OSC message routing** — Single/multi-arg messages, bare triggers, animated sweeps
3. **Event/trigger system** — Fire named events with JSON payloads, receive events via callback
4. **Timeline/transport** — Play/pause/stop, speed control, seek, time query
5. **Resolution override** — Override output to 4K, 720p, revert to patch default

## Build

```bash
cd libgonodes/build
cmake .. -DGONODES_BUILD_EXAMPLES=ON
cmake --build . --target midi_osc_host
```

## Run

```bash
./midi_osc_host path/to/gonodes_project path/to/midi_osc_demo.gnpatch
```

## Patch Requirements

The demo expects a patch with:
- `host_out` — a `HostOutTOP` node for resolution override demo
- MIDI/OSC operators that respond to injected protocol data
- (Optional) Event trigger operators

See `../patches/midi_osc_demo.gnpatch`.
