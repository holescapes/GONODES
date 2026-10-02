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
| 2 | `tests/human_gate/02_align_and_shake.gnpatch` | Select both nodes. Press H. Undo (Ctrl+Z) or reopen the patch. Press V only | H makes a row (same Y, different X) and is not help. V makes a column (same X, different Y) and is not a viewer. Do not press V after H without undoing: the second align collapses both axes onto one point | H opens help, V opens a viewer, or V-alone changes Y |
| 3 | Same patch, or any patch with a named node | Ctrl+F, type the node id (`noise`), then Escape | Search opens, finds the node, then closes. The timeline playhead does not jump back to zero | Search does nothing, or Escape resets the timeline |
| 4 | `02_align_and_shake.gnpatch` again | Drag the right node and shake it left-right | The wire disconnects. A toast says how many wires dropped | The wire stays, or it drops with no toast |
| 5 | `tests/visual_audit/04_mapper_dual_panel.gnpatch` | Drag a corner in the viewer and in the WindowOUT | Both panels show the same warp. The Output panel has no freed-object error | The panels disagree, or Godot prints a freed-object error |
| 6 | `tests/human_gate/06_timeline_density.gnpatch` | Drag the timeline playhead back and forth | The playhead follows the mouse. No multi-frame stall | The playhead lags by several frames or the editor freezes |
| 7 | `tests/human_gate/07_wave_to_speakers.gnpatch` | Listen. Then turn Active off on AudioDeviceOUT | A quiet 440 Hz tone from the selected device. Active off stops it. WaveCHOP alone, with the OUT deleted, is silence | Silence while Active is on, or the tone continues after Active is off |
| 8 | `tests/human_gate/08_audio_file_master.gnpatch` | Set File to a short WAV, OGG, or MP3 you already own. Turn Play on. Turn Active on on AudioDeviceOUT | You hear the file | Play is on, the file is valid, Active is on on AudioDeviceOUT, and there is silence. Play on with no AudioDeviceOUT is silence (not a fail). 24-bit WAV is unsupported; use another file before calling it a fail. No file picked is UNVERIFIED |
| 9 | `tests/human_gate/09_audio_source.gnpatch` | Set File, then turn Playing on | You hear it, or the node shows that it will not cook | Playing is on, a real file is set, and there is silence with no warning |
| 10 | `tests/human_gate/10_osc_out.gnpatch` | Before opening it, in a terminal: `python -c "import socket; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.bind(('0.0.0.0',9001)); print('listening'); print(s.recvfrom(4096))"` | A UDP packet prints while Active is on. Active off sends nothing | Active is on and the listener stays silent. No listener running is UNVERIFIED |
| 11 | `tests/human_gate/11_midi_out.gnpatch` | Open a virtual MIDI port (loopMIDI or similar) and a MIDI monitor. Pick that port on RtMidiOutCHOP | A note from channel `n60` shows in the monitor while Active is on. Active off sends nothing | Active is on, a port is selected, and the monitor stays empty. An empty port menu is UNVERIFIED |
| 12 | `tests/human_gate/12_dmx_out.gnpatch` | Listen on UDP 6454 before turning Active on. QLC+, or: `python -c "import socket; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.bind(('0.0.0.0',6454)); print('listening'); print(s.recvfrom(4096))"` | Active off sends nothing. Active on delivers one Art-Net packet | A packet arrives while Active is off, or Active on stays silent. No listener is UNVERIFIED |
| 13 | `tests/human_gate/13_bad_expression.gnpatch` | Look at Frequency. Then replace `1 +` with `sin(time)` | The bad expression turns the field red and shows an error marker, not only a log line. `sin(time)` then moves the value | The field stays neutral, or `sin(time)` does not move |
| 14 | `tests/human_gate/14_script_syntax_error.gnpatch` | Look at the script node | The node shows a warning | The node looks clean and cooks as if the script were empty |
| 15 | `tests/human_gate/15_quick_build.gnpatch` | Save the patch. Use the editor Build button (Quick Build). Run the `GONODESPlayer.exe` it writes | A window opens. Escape quits | No window, or Escape does nothing |

Rows 7–12 and 15 are also F4k-02, F4l-03, and F4m-01. One report covers both.

Rows 1–15 passed on 28 Sep 2026.

## Next: what to look at

Do not walk the 585 operators one by one. Unit tests and the mechanical audit already covered structure. The gallery files under `tests/visual_audit/gallery/` are that one-by-one pass, and they can wait. What still needs eyes is a picture on screen, a click in a window, and a few editor panels.

Open these the same way as the first 15. Report a failure with the same block. `UNVERIFIED` still means the speaker, file, or device was not there.

| # | Open | Do this | Pass | Not a pass |
|---|------|---------|------|------------|
| 16 | `tests/visual_audit/01_window_out_basics.gnpatch` | Turn Open on. Then turn it off | A second window shows the picture while Open is on. Open off hides that window. The editor window staying open is normal | No picture window, or Open off leaves the picture window up |
| 17 | `tests/visual_audit/02_top_generators.gnpatch` | Change the Switch index. Watch Noise, Text, and Constant | Each index shows a different picture. Noise moves. Text is readable. Constant is a solid color | A black window, or Switch does nothing |
| 18 | `tests/visual_audit/03_top_filter_chain.gnpatch` | Change Blur size, then Level or HSV | The picture in the window changes when those parameters change. Edge shows outlines | The chain stays visually frozen |
| 19 | `tests/visual_audit/05_3d_render.gnpatch` | Look at the window. Move the camera or the light | A cube is visible. Moving the camera or the light changes the view | A black window, or the view ignores the camera |
| 20 | `tests/visual_audit/06_ui_window_panel.gnpatch` | Turn the window Open on. Click the button and drag the slider in that window | The widgets in the picture window take clicks. A save prompt after moving the slider is expected | The widgets are drawn and ignore the mouse |
| 21 | `tests/visual_audit/07_out_exporters.gnpatch` | Leave Active off. Click a file or folder parameter | A file picker opens. Nothing is written to disk | The parameter is a plain text line, or a file is written while Active is off |
| 22 | `tests/visual_audit/08_audio_spectrum_band.gnpatch` | Set AudioFileIn to a short file you own. Turn Play on. Pin the viewer to Spectrum or Band | The viewer channels move. Silence from the speakers is expected: this patch has no AudioDeviceOUT | Play is on, the file is valid, and the viewer stays flat. No file picked is UNVERIFIED |
| 23 | `addons/gonodes/help/comp/sub_network_basic.gnpatch` | Double-click the subnet. Use the breadcrumb to come back out | The inner network opens, then the parent network comes back | Double-click does nothing, or there is no way back |
| 24 | A new empty graph | Alt+A, type `chop` (at least 2 letters) | A node whose main family is not CHOP, but which also outputs CHOP, shows the suffix `also outputs: CHOP` | The suffix never appears |
| 25 | Preferences → Extensions | Uncheck one GDScript extension. Open the palette. Check it again | Its operators leave the palette without a restart, then come back. A native row says a restart is still required | The operators stay after uncheck, or a native row claims it unloaded live |
| 26 | Preferences → Asset Browser | Type in the search box and change the family dropdown | The list filters. Install stays UNVERIFIED without a `.gnasset`. Uninstall must refuse anything outside `user://gonodes_assets/` | Search or the family dropdown leaves the list unchanged |

Rows 16–20 passed on 28 Sep 2026.

Rows 21–26 passed on 1 Oct 2026. Row 22 first failed the same day: Play was audible with no AudioDeviceOUT, and WindowOUT stayed blank until a node was clicked. Both were fixed before this pass.

Skip `tests/visual_audit/04_mapper_dual_panel.gnpatch`. That was row 5.

Pack 07 can write image sequences and video if Active is turned on. Leave Active off unless you mean to write files.

Rows 21–26 passed on 1 Oct 2026. A picture window that stays blank until you click a node is a fail on every row below.

Help patches already have a note on the canvas. Follow the Do this column. Report a failure with the same block as before.

## Editor actions

| # | Open | Do this | Pass | Not a pass |
|---|------|---------|------|------------|
| 27 | `addons/gonodes/help/top/text_basic.gnpatch` | Look at the output window | The window shows the words Hello GONODES | A blank window, or different text |
| 28 | Same patch | Change the Text parameter. Press Ctrl+Z | The words go back to Hello GONODES | Undo does nothing, or it undoes something else |
| 29 | Same patch | Select the text node. Press Ctrl+D. Then Ctrl+Z | A second node appears and its id ends in `_copy`. Undo removes that copy and leaves the original wired to the window | No copy, the original id changes, or undo deletes the original |
| 30 | Same patch | Select the text node. Press L. Try to edit Text. Press L again | While locked, the inspector will not take the edit and the node shows a lock mark. The second L edits again | The text changes while locked, or the second L stays locked |
| 31 | Same patch | Select the text node. Press Ctrl+1. Pan the graph away. Press 1 | The text node is selected and centered, with a blue 1 badge | 1 does nothing, or it types into a parameter |
| 32 | Same patch | Right-click the text node. Choose Node Help | A help window describes TextTOP, including its parameters | No help window, or the page is empty |
| 33 | `tests/visual_audit/03_top_filter_chain.gnpatch` | Select the Blur node. Press B. Press B again | The picture gets sharper while bypass is on, and the node shows ⏩. The second B brings the blur back | The picture does not change, or bypass stays on |
| 34 | `addons/gonodes/help/top/text_basic.gnpatch` | Press F2 | The Cook Chain lists the text node and the window. The window row is active. Double-click a row selects that node in the graph | The panel does not open, or every row says inactive |
| 35 | Same patch | Change Font Size. Ctrl+click that field | Font Size returns to its default | Ctrl+click does nothing, or it clears the text |
| 36 | Same patch | Open Takes on the timeline row (Shift+T). Capture Base. Change Text to `TAKE`. Capture Take. Revert to Base. Apply the take | Revert shows Hello GONODES. Apply shows TAKE | The window text does not follow the take, or there is no Takes panel |

Rows 27–36 passed on 1 Oct 2026. On that day, before the pass: the text window did not appear until WindowOUT was clicked; L did not lock parameters; bookmark 1 lagged across frames; F2 double-click did not select and center the node; bypass showed on the node while the picture still cooked. Those were fixed before that pass.

## More pictures

These windows open with the patch. You do not need to turn Open on.

| # | Open | Do this | Pass | Not a pass |
|---|------|---------|------|------------|
| 37 | `addons/gonodes/help/top/feedback_basic.gnpatch` | Watch the window. Lower Mix on the feedback node | The noise leaves a trail. Lower Mix thins that trail | A still frame, a black window, or Mix does nothing |
| 38 | `addons/gonodes/help/sop/box_basic.gnpatch` | Look at the window. Change the box Size X | A box is visible. Size X changes its width | No mesh, or Size X does nothing |
| 39 | `addons/gonodes/help/vol/noise_basic.gnpatch` | Look at the window. Change Frequency | A volume picture is visible. Frequency changes it | A black window, or Frequency does nothing |
| 40 | `addons/gonodes/help/pop/boids_basic.gnpatch` | Watch the window for a few seconds | A cloud of points moves. A short hitch on open is fine | A black window, a frozen frame, or the editor stalls for several seconds |
| 41 | `addons/gonodes/help/img/imgtotop_basic.gnpatch` | Look at the window | A noise picture, from the image node through ImgToTOP | A black or empty window |
| 42 | `addons/gonodes/help/chop/lfo_basic.gnpatch` | Watch the window | The trace moves | A flat line that never moves, or a black window |
| 43 | `addons/gonodes/help/script/script_chop_basic.gnpatch` | Turn Time Dependent on for the script node | The trace moves. The node has no warning badge | A warning badge, or the trace stays still after Time Dependent is on |

Rows 37–43 passed on 2 Oct 2026.

## Tables and expressions

| # | Open | Do this | Pass | Not a pass |
|---|------|---------|------|------------|
| 44 | `addons/gonodes/help/dat/system_basic.gnpatch` | Click `system1` and read the docked viewer | The viewer lists `screen_0_width` and its value is a number. The picture window is the Text node’s own text | The viewer has no `screen_0_width` row |
| 45 | Same patch | On `texttop1`, click C next to Font Size. Enter `lookupf("system1", "property", "screen_0_dpi", "value")` | Font Size shows the same number as the `screen_0_dpi` row | The field stays red, or the number does not match that row |
| 46 | Same patch | Replace that expression with `cellf("system1", "Engine", "value")` | Font Size shows the same number as the first Engine row's value | The field stays red, or the number does not match |
| 47 | `addons/gonodes/help/dat/info_basic.gnpatch` | Click `info1` and read the docked viewer | The viewer lists `fps` and `os` | Those rows are missing |
| 48 | `addons/gonodes/help/top/text_basic.gnpatch` | On Font Size, click C and enter `48 + sin(time) * 10` | The text size pulses. You can keep typing while a suggestion list is open; Up and Down move the highlight | The size stays still, the field stays red, or the suggestion list steals the keyboard |

## Keys, mouse, and devices

No MIDI port, no OSC sender, or no microphone is `UNVERIFIED`, not a pass and not a fail.

| # | Open | Do this | Pass | Not a pass |
|---|------|---------|------|------------|
| 49 | `addons/gonodes/help/chop/keyboardin_basic.gnpatch` | Click the output window. Hold a letter key, then release it | The picture changes while the key is down and changes back when you release it | The picture ignores the key |
| 50 | `addons/gonodes/help/chop/mousein_basic.gnpatch` | Move the mouse | The picture changes as the pointer moves | The picture stays still |
| 51 | `addons/gonodes/help/chop/midi_in_basic.gnpatch` | Pin the viewer to `null1`. Play a note on a MIDI device | A channel moves while the note is held. No MIDI device is UNVERIFIED | A device is connected and the viewer stays flat |
| 52 | `addons/gonodes/help/chop/osc_in_basic.gnpatch` | Pin the viewer to `null1`. Send one OSC message to UDP port 8000 | A channel appears for that address. No sender running is UNVERIFIED | A message was sent and the viewer stays empty |
| 53 | `addons/gonodes/help/chop/audioin_filtered.gnpatch` | Talk or tap the microphone. There is no AudioDeviceOUT in this patch | The window trace moves. The speakers stay silent. No microphone is UNVERIFIED | The trace stays flat while the mic is live, or you hear the mic from this patch |

## Scene and materials

These windows open with the patch.

| # | Open | Do this | Pass | Not a pass |
|---|------|---------|------|------------|
| 54 | `addons/gonodes/help/mat/pbr_basic.gnpatch` | Look at the window. Set Albedo Color to red | A sphere is visible, then it turns red | No sphere, or the color stays white |
| 55 | Same patch | Click `geo1` | The docked viewer shows the sphere, and the label at the top of that viewer stays readable | The viewer is empty, or a solid plate covers that label |
| 56 | `addons/gonodes/help/comp/light_basic.gnpatch` | Set Energy on `focus1` to 0. Then set it back to 1 | The sphere gets darker, then brightens | Energy does nothing |
| 57 | `addons/gonodes/help/comp/animation_basic.gnpatch` | Watch for a few seconds. Then set Loop to Linear (Loop) | The sphere turns once and stops. After Linear (Loop), it keeps turning | It never turns, or Linear (Loop) plays once and stops |
| 58 | `addons/gonodes/help/comp/instance_basic.gnpatch` | Look at the window. Set Instance Count to 4 | Many copies of a sphere. Count 4 leaves four | One sphere, a black window, or the count does nothing |
| 59 | `addons/gonodes/help/comp/null_comp_basic.gnpatch` | Look at the window | A box is visible. The render reads it through the Null | A black window |

## SOP edits

| # | Open | Do this | Pass | Not a pass |
|---|------|---------|------|------------|
| 60 | `addons/gonodes/help/sop/transform_basic.gnpatch` | Change Translate X on the transform node | The sphere moves sideways | It stays put |
| 61 | `addons/gonodes/help/sop/twist_basic.gnpatch` | Set Angle to 0 | The twisted box becomes a plain box | The shape does not change |
| 62 | `addons/gonodes/help/sop/switch_basic.gnpatch` | Set Index to 1, then back to 0 | Index 1 is a torus. Index 0 is a sphere | Both indexes look the same |

## Window and graph

| # | Open | Do this | Pass | Not a pass |
|---|------|---------|------|------------|
| 63 | `tests/visual_audit/01_window_out_basics.gnpatch` | Set Window Mode to Borderless | The picture window stays 640×360. It does not grow to the monitor | Borderless fills the screen |
| 64 | Same patch | Set Window Mode to Fullscreen. Press Esc in that window | Fullscreen fills the monitor. Esc returns to a window | Fullscreen stays letterboxed, or Esc does nothing |
| 65 | `tests/visual_audit/07_out_exporters.gnpatch` | On `tex_save`, open the file list (the path control, not the … button) | The list stays well under the height of the editor window and scrolls when it is long | The list grows to the whole window |
| 66 | `addons/gonodes/help/top/text_basic.gnpatch` | Click the V on the text node’s title. Then click another node. Click that V again | The viewer stays on the text node until the second click. The V key is align, not this pin | Clicking another node changes the viewer while the pin is on |
| 67 | Same patch | Right-click empty canvas. Add Sticky Note. Type a word | A note appears where you clicked and keeps that word | No note, or the word disappears |
| 68 | Same patch | Press F | The graph frames into view | The view does not move |

## Tables in the viewer

A Text node does not draw a wired table. Read the docked viewer on these rows.

| # | Open | Do this | Pass | Not a pass |
|---|------|---------|------|------------|
| 69 | `addons/gonodes/help/dat/sop_to_dat_basic.gnpatch` | Click `s2d1` | The viewer has columns `px`, `py`, and `pz`, and the cells are numbers | The viewer is empty, or those columns are missing |
| 70 | `addons/gonodes/help/dat/table_basic.gnpatch` | Click `table1` | The viewer headers are `name`, `value`, and `weight` | The headers are missing |
| 71 | Same patch | Change Rows from 4 to 6 | The viewer gains two rows | The row count stays at 4 |

## Widgets in the window

Click inside the picture window. These windows open with the patch.

| # | Open | Do this | Pass | Not a pass |
|---|------|---------|------|------------|
| 72 | `addons/gonodes/help/ui/button_basic.gnpatch` | Click the button labeled Click Me | The button takes the click | The button is drawn and ignores the mouse |
| 73 | `addons/gonodes/help/ui/slider_basic.gnpatch` | Drag the Mix slider | The handle follows the pointer | The handle stays put |
| 74 | `addons/gonodes/help/ui/knob_basic.gnpatch` | Drag the knob | The knob turns. The noise behind it does not have to change | The knob ignores the drag |
| 75 | `addons/gonodes/help/ui/xypad_basic.gnpatch` | Drag inside the pad | The marker follows the pointer | The marker stays in the middle |

## Channel traces

| # | Open | Do this | Pass | Not a pass |
|---|------|---------|------|------------|
| 76 | `addons/gonodes/help/chop/math_basic.gnpatch` | Operation is already Multiply. Set Operand to 0, then back to 2 | The trace goes flat, then moves again | Operand does nothing |
| 77 | `addons/gonodes/help/chop/lag_basic.gnpatch` | The trace is a square wave. Set Attack to 2 | The corners round off | The square stays sharp |
| 78 | `addons/gonodes/help/chop/noise_basic.gnpatch` | Set Seed to 7 | The jagged shape changes, and it keeps moving | The shape stays the same, or the trace is frozen |
| 79 | `addons/gonodes/help/chop/filter_basic.gnpatch` | Set Cutoff to 0.01 | The trace gets smoother | Cutoff does nothing |

## More pictures

| # | Open | Do this | Pass | Not a pass |
|---|------|---------|------|------------|
| 80 | `addons/gonodes/help/mat/wireframe_basic.gnpatch` | Set Wire Color to red | A wire sphere turns red | A solid sphere, a black window, or the color stays green |
| 81 | `addons/gonodes/help/pop/force_basic.gnpatch` | Watch the points. Set Gravity Y to 0 | They drift downward, then that drift stops. A short hitch on open is fine | A black window, or Gravity Y does nothing |
| 82 | `addons/gonodes/help/img/blurimg_basic.gnpatch` | Set Radius to 20 | The noise gets blurrier | The picture stays as sharp as it opened |
| 83 | `addons/gonodes/help/top/level_basic.gnpatch` | Set Brightness to 0, then back to 1 | The picture goes dark, then comes back | Brightness does nothing |

## Inspector and names

| # | Open | Do this | Pass | Not a pass |
|---|------|---------|------|------------|
| 84 | `addons/gonodes/help/top/text_basic.gnpatch` | Set Text to `COPY`. Click Copy. Click Reset. Click Paste | Reset changes the words. Paste brings `COPY` back | Paste does nothing, or Reset leaves `COPY` in place |
| 85 | Same patch | Double-click the text node’s title. Rename it to `hello` and press Enter. Then Ctrl+Z | The window still shows the words, and the node id is `hello`. Undo restores the old id | The window goes blank, or the id does not change |
| 86 | Same patch | Select the text node. Right-click. Add Network Box | A box labeled Group sits around that node | No box |
| 87 | Same patch | Delete the wire into the window. Then Ctrl+Z | The window goes blank. Undo brings the words back | The wire will not delete, or undo leaves the window blank |

## Optional, not in the table

From the repo root: `.\scripts\pack_extension.ps1 -ExtensionName gn_ext_mapper`. It should write `templates/extensions/gn_ext_mapper.pck` and refuse `gn_ext_native`. Skip it if you are staying in the editor.

Hash-skip, the SubViewport pool, and simple expression callables already have headless tests. You do not need to re-prove those.
