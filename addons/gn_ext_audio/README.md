# gn_ext_audio — Audio Synthesis & Effects

Audio synthesis, effects, and processing extension for GONODES.

## Platform Support

| Platform | Status |
|----------|--------|
| Windows  | ✅     |
| macOS    | ✅     |
| Linux    | ✅     |

All operators are pure GDScript — no native dependencies.

## Operators (13)

### Tier 1 — Synthesis & Generation

| Operator | Type | Description |
|----------|------|-------------|
| AudioOscillatorCHOP | CHOP | Audio-rate waveform generator (sine, saw, square, triangle, noise, pulse) with FM/AM modulation |
| AudioFilterCHOP | CHOP | Biquad IIR audio filter (lowpass, highpass, bandpass, notch, allpass, peak, shelf) |
| AudioParaEQCHOP | CHOP | Multi-band parametric equalizer (up to 8 bands) |
| AudioMixCHOP | CHOP | Multi-input audio mixer with per-input gain, pan, mute, solo |

### Tier 2 — Playback & Streaming

| Operator | Type | Description |
|----------|------|-------------|
| AudioMovieCHOP | CHOP | Extract audio track from video file |
| AudioRenderCHOP | CHOP | Offline render of CHOP audio chain to buffer |
| AudioStreamInCHOP | CHOP | Receive audio over UDP (GNAU packet protocol; pairs with AudioStreamOutCHOP) |
| AudioStreamOutCHOP | CHOP | Send audio over UDP (GNAU packet protocol; pairs with AudioStreamInCHOP) |

Tier 2 operators are pure GDScript. AudioMovieCHOP uses Godot's audio bus capture (OGV natively; MP4/MOV via `gn_ext_ffmpeg`). AudioRenderCHOP bounces a CHOP chain to WAV on demand.

### Tier 3 — Effects & Processing

| Operator | Type | Description |
|----------|------|-------------|
| AudioReverbCHOP | CHOP | Algorithmic reverb (Schroeder/FDN) |
| AudioDelayCHOP | CHOP | Sample-accurate delay line with feedback |
| AudioPitchCHOP | CHOP | Pitch shift without tempo change (granular) |
| AudioEnvelopeCHOP | CHOP | Amplitude envelope follower (attack/release) |
| AudioGateCHOP | CHOP | Noise gate with threshold, attack, hold, release |

## Dependencies

None — pure GDScript.

## License

MIT — see main project LICENSE.
