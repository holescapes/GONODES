# Protocols — MIDI, OSC & DMX

GONODES can send and receive MIDI, OSC, and DMX data for live performance
control, lighting, and hardware integration. OSC and DMX are built-in. MIDI
has two paths (see below).

---

## MIDI

### Which MIDI path?

| Operator | Where | When to use |
|----------|-------|-------------|
| **MidiInCHOP** / **MidiInDAT** | Core (`addons/gonodes`) | Built-in Godot MIDI; no native build. Good default for desktop editor work. |
| **RtMidiInCHOP** / **RtMidiOutCHOP** | Extension `gn_ext_midi` | Cross-platform RtMidi (incl. output, mobile). Requires the extension native binary. |

Prefer **one path per patch** — do not wire both core MidiIn and RtMidiIn to the same device.

### Requirements (RtMidi extension)

Full RtMidi I/O requires the **gn_ext_midi** extension, which uses the RtMidi
native library for low-latency communication. Available on Windows, macOS,
Linux, Android, and iOS. Not available on Web.

### RtMidiInCHOP — Receiving MIDI

Receives MIDI messages and outputs them as CHOP channels.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `port` | Int | 0 | MIDI input port index |
| `channel_filter` | Int | -1 | MIDI channel (-1 = all channels) |
| `notes` | Bool | On | Output note velocity channels |
| `ccs` | Bool | On | Output CC value channels |
| `normalize` | Bool | On | Values 0.0–1.0 instead of 0–127 |

**Output channels:**

| Channel | Description |
|---------|-------------|
| `n0`–`n127` | Note velocities (sparse — only active notes appear) |
| `cc0`–`cc127` | CC values (sparse — only received CCs appear) |
| `pitch_bend` | Pitch bend (-1.0 to 1.0 normalized, or 0–16383 raw) |

### RtMidiOutCHOP — Sending MIDI

Reads CHOP channel data and sends it as MIDI messages.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `port` | Int | 0 | MIDI output port index |
| `channel` | Int | 0 | MIDI channel to send on (0–15) |
| `active` | Bool | On | Enable/disable output |
| `normalized_input` | Bool | On | Input values are 0.0–1.0 |

**Channel → MIDI mapping:**

| Input Channel | MIDI Message |
|---------------|-------------|
| `n0`–`n127` | Note On/Off (tracks velocity transitions) |
| `cc0`–`cc127` | Control Change messages |
| `pitch_bend` | Pitch Bend message |

### MIDI Workflow Example

```
RtMidiInCHOP "midi1"     →  MathCHOP "scale1"    →  (use in expressions)
  port=0, normalize=On        gain=1.0, offset=0.0
```

1. Connect your MIDI controller
2. Add **RtMidiInCHOP** — set `port` to your device index
3. The output updates live with note/CC values
4. Reference in expressions: `chop("midi1", "cc1")` for the mod wheel

---

## OSC (Open Sound Control)

OSC is a UDP-based protocol widely used in live performance tools.
GONODES has built-in OSC support — no extension required.

### OscInCHOP — Receiving OSC as Channels

Listens for OSC messages on a UDP port and outputs numeric values as
CHOP channels.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `port` | Int | 9000 | UDP port to listen on |
| `active` | Bool | On | Enable/disable listener |
| `address_filter` | String | `""` | Only accept matching prefix (empty = all) |
| `normalize_names` | Bool | On | Strip leading `/` from channel names |
| `max_channels` | Int | 128 | Maximum channels to track |
| `reset` | Pulse | — | Clear all stored channels |

**Channel naming rules:**

| OSC Message | Channel Name |
|-------------|-------------|
| `/foo` + 1 float | `foo` |
| `/bar` + 3 floats | `bar:0`, `bar:1`, `bar:2` |
| `/a/b/c` + 1 float | `a:b:c` (slashes → colons) |

Non-numeric arguments are silently ignored. Use OscInDAT for raw messages.

### OscInDAT — Receiving OSC as Table

Logs incoming OSC messages into a DAT table — useful for debugging or
processing string/blob arguments.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `port` | Int | 9000 | UDP port |
| `max_rows` | Int | 100 | Ring buffer size (1–10000) |
| `active` | Bool | On | Enable/disable |
| `address_filter` | String | `""` | Prefix filter |
| `clear` | Pulse | — | Clear the table |

**Output columns:** `address`, `types`, `arg0`–`arg3`, `timestamp`

### OscOUT — Sending OSC

Sends CHOP channel data as OSC messages over UDP.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `host` | String | `127.0.0.1` | Target host |
| `port` | Int | 9001 | Target UDP port |
| `active` | Bool | On | Enable/disable |
| `prefix` | String | `/gonodes` | OSC address prefix |
| `send_mode` | Enum | Individual | **Individual** (one msg per channel) or **Bundle** |

**Address format:** `prefix/channel_name` — e.g., `/gonodes/tx`

### OSC Workflow Example

```
ConstantCHOP "ctl1"  →  OscOUT "osc_out1"
  name0="tx", value0=1.5    host="192.168.1.100", port=8000
```

Receiving from another app:
```
OscInCHOP "osc_in1"   →  (use in expressions)
  port=9000
```

Reference: `chop("osc_in1", "fader1")` in any expression.

---

## DMX (Art-Net)

GONODES has built-in DMX support via the Art-Net protocol (UDP). No
external libraries needed.

### DmxOutCHOP

Sends CHOP channel values as DMX-512 via Art-Net broadcast.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `universe` | Int | 0 | DMX universe number (0–32767) |
| `ip` | String | `255.255.255.255` | Destination IP (broadcast default) |
| `port` | Int | 6454 | Art-Net UDP port |
| `active` | Bool | Off | Enable Art-Net transmission |
| `channels` | Int | 512 | Number of active DMX channels (1–512) |

**Input:** Connect a CHOP with channels named `dmx1`–`dmx512` (values 0–255).

**Output:** Passes input CHOP through unchanged.

### DmxInCHOP

Receives Art-Net DMX-512 data as CHOP channels (`dmx1`–`dmx512`, 0.0–255.0).

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `universe` | Int | 0 | DMX universe to listen on |
| `port` | Int | 6454 | Art-Net UDP port |
| `active` | Bool | Off | Enable Art-Net listening |

### ArtnetDAT

Art-Net network discovery — broadcasts ArtPoll, collects ArtPollReply,
outputs a table of detected nodes with IP, name, firmware, universes.

### DMX Workflow Example

```
ConstantCHOP "dmx_vals"  →  DmxOutCHOP "dmx_out1"
  dmx1=255, dmx2=128          universe=0, active=On
```

1. Add a **ConstantCHOP** with channels named `dmx1`, `dmx2`, etc.
2. Set values 0–255 for each DMX channel
3. Connect to **DmxOutCHOP**
4. Set `active = On` to start broadcasting
5. For receiving, use **DmxInCHOP** and read the output channels

### DMX Scene Automation with Cues

```
CueDAT → CueCHOP → (expressions drive ConstantCHOP) → DmxOutCHOP
  Cue data: {"dmx_vals/dmx1": 255, "dmx_vals/dmx2": 0}
```

---

## Port Reference

| Protocol | Default Port | Standard |
|----------|-------------|----------|
| OSC In | 9000 | Common convention |
| OSC Out | 9001 | Common convention |
| Art-Net (DMX) | 6454 | Art-Net standard |
| MIDI | N/A | Hardware port index |
