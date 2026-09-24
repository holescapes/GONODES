# Human gate

Run this in the Godot editor, not headless. Open the project, press Play so the GONODES editor is up, then **Ctrl+O** and pick the patch named in each row.

Each patch has a yellow note on the canvas. Do the action. Write what actually happened.

## How to report a failure

Reply with one block per failed or unverified row:

```
Row: 7
Patch: tests/human_gate/07_wave_to_speakers.gnpatch
Result: FAIL
Saw: Active is on, no tone, no warning on the node
Godot output: (paste the red lines, if any)
```

Use `PASS`, `FAIL`, or `UNVERIFIED`. `UNVERIFIED` means the hardware or the other program was not there (no MIDI port, no Art-Net listener, no wav file). That is not a pass. Do not fill the Actual column in `PRE-BETA_AUDIT.md` yourself; send the notes back and the next pass will record them.

Startup lines about Ultraleap ("No GDExtension library") and a missing OpenCV DLL are already known. Do not report those unless a new line appears.

## Setup

1. Launch `C:\Users\hesam\OneDrive\Documents\Godot\Godot_v4.7.2-stable_win64.exe` and open this project.
2. Press Play so the editor scene is running.
3. Keep the Godot Output panel visible.

## The 15 walkthrough rows

| # | Open | Do this | Pass | Not a pass |
|---|------|---------|------|------------|
| 1 | A new empty graph (Ctrl+N or File → New, if that is how you start a graph) | Alt+A. Type `chop`. Place a node. Then type `audio` (at least 3 letters). Place an audio-tagged node. Type `cam`. | Palette opens at the mouse. `chop` lists CHOP operators. `audio` lists audio-tagged operators. `cam` lists camera-tagged operators. Tab does nothing | Palette opens elsewhere, Tab inserts a node, or `audio` / `cam` find nothing |
| 2 | `tests/human_gate/02_align_and_shake.gnpatch` | Select both nodes. Press H. Then press V | Nodes align. H is not help. V is not a viewer | Either key opens help or a viewer |
| 3 | Same patch, or any patch with a named node | Ctrl+F, type the node id (`noise`), then Escape | Search opens, finds the node, then closes. The timeline playhead does not jump back to zero | Search does nothing, or Escape resets the timeline |
| 4 | `02_align_and_shake.gnpatch` again | Drag the right node and shake it left-right | The wire disconnects. A toast says how many wires dropped | The wire stays, or it drops with no toast |
| 5 | `tests/visual_audit/04_mapper_dual_panel.gnpatch` | Drag a corner in the viewer and in the WindowOUT | Both panels show the same warp. The Output panel has no freed-object error | The panels disagree, or Godot prints a freed-object error |
| 6 | `tests/human_gate/06_timeline_density.gnpatch` | Drag the timeline playhead back and forth | The playhead follows the mouse. No multi-frame stall | The playhead lags by several frames or the editor freezes |
| 7 | `tests/human_gate/07_wave_to_speakers.gnpatch` | Listen. Then turn Active off on AudioDeviceOUT | A quiet 440 Hz tone from the selected device. Active off stops it. WaveCHOP alone, with the OUT deleted, is silence | Silence while Active is on, or the tone continues after Active is off |
| 8 | `tests/human_gate/08_audio_file_master.gnpatch` | Set File to a short WAV, OGG, or MP3 you already own. Turn Play on. Do not add an AudioDeviceOUT | You hear the file on Master | Play is on, the file is valid, and there is silence. 24-bit WAV is unsupported; use another file before calling it a fail. No file picked is UNVERIFIED |
| 9 | `tests/human_gate/09_audio_source.gnpatch` | Set File, then turn Playing on | You hear it, or the node shows that it will not cook | Playing is on, a real file is set, and there is silence with no warning |
| 10 | `tests/human_gate/10_osc_out.gnpatch` | Before opening it, in a terminal: `python -c "import socket; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.bind(('0.0.0.0',9001)); print('listening'); print(s.recvfrom(4096))"` | A UDP packet prints while Active is on. Active off sends nothing | Active is on and the listener stays silent. No listener running is UNVERIFIED |
| 11 | `tests/human_gate/11_midi_out.gnpatch` | Open a virtual MIDI port (loopMIDI or similar) and a MIDI monitor. Pick that port on RtMidiOutCHOP | A note from channel `n60` shows in the monitor while Active is on. Active off sends nothing | Active is on, a port is selected, and the monitor stays empty. An empty port menu is UNVERIFIED |
| 12 | `tests/human_gate/12_dmx_out.gnpatch` | Listen on UDP 6454 before turning Active on. QLC+, or: `python -c "import socket; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.bind(('0.0.0.0',6454)); print('listening'); print(s.recvfrom(4096))"` | Active off sends nothing. Active on delivers one Art-Net packet | A packet arrives while Active is off, or Active on stays silent. No listener is UNVERIFIED |
| 13 | `tests/human_gate/13_bad_expression.gnpatch` | Look at Frequency. Then replace `1 +` with `sin(time)` | The bad expression turns the field red and shows an error marker, not only a log line. `sin(time)` then moves the value | The field stays neutral, or `sin(time)` does not move |
| 14 | `tests/human_gate/14_script_syntax_error.gnpatch` | Look at the script node | The node shows a warning | The node looks clean and cooks as if the script were empty |
| 15 | `tests/human_gate/15_quick_build.gnpatch` | Save the patch. Use the editor Build button (Quick Build). Run the `GONODESPlayer.exe` it writes | A window opens. Escape quits | No window, or Escape does nothing |

Rows 7–12 and 15 are also F4k-02, F4l-03, and F4m-01. One report covers both.

## Features that shipped after the audit

These are not in the 15-row table. Check them the same way and report a failure in the same format.

1. **Also-outputs badge.** Alt+A, type `chop` with at least 2 letters. A node whose main family is not CHOP but which also outputs CHOP should appear with the suffix `also outputs: CHOP`.
2. **Extensions panel.** Preferences → Extensions. Uncheck a GDScript extension (not a native one). Its operators should leave the palette without a restart. Check it again. They should come back. A native row should say a restart is still required. Load Extension Pack can stay untested if you have no `.pck`; say UNVERIFIED.
3. **Asset browser.** Preferences → Asset Browser. Search and the family dropdown should filter the list. Install is only worth testing if you have a `.gnasset`. Uninstall must refuse anything that is not under `user://gonodes_assets/`.
4. **Extension pack script (optional).** From the repo root: `.\scripts\pack_extension.ps1 -ExtensionName gn_ext_mapper`. It should write `templates/extensions/gn_ext_mapper.pck` and refuse `gn_ext_native`.

Hash-skip, the SubViewport pool, and simple expression callables already have headless tests. You do not need to re-prove those unless row 13's `sin(time)` value does not move.
