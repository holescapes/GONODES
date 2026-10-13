# GONODES — AI Memory (cross-tool)

> Curated facts and decisions for AI assistants. Any model can read this file.
> The index is `ai/README.md`.
>
> Add dated entries when you learn something worth keeping. Keep entries short.

## How to use

- **Any agent:** `ai/README.md` tells you to read this after the hard rules.
- **You:** edit this file. It lives in git.

## Active long-running work

- **Pre-Beta Audit — WRITTEN, remediation started.** B-12, B-13, and B-8 are fixed (see `PRE-BETA_AUDIT.md`
  Resume). 4n and live audio/MIDI/OSC/DMX are still UNVERIFIED. Do not duplicate findings here.

## Entries

### 2026-10-13 — Agent docs live in `ai/`

- Brief an agent from `ai/README.md`. Engine work then follows `.github/copilot-instructions.md`. Patch writing follows root `llms.txt`.
- `origin` is `git@github.com:holescapes/GONODES.git`. The GitLab remote is named `gitlab` and is not the push target.

### 2026-10-08 — `time_dependent` is operator logic, not a user toggle

- `GNNode.update_time_dependency()` runs at the start of `_pre_cook`. Override it when a node is only live while a rate, playback flag, jitter, or referenced node is changing. Clocks, devices, and GlitchTOP stay on because their output always moves with time. MovieFileIn holds when paused or speed is 0. TimeMachine holds in Position mode and in Speed mode at speed 0. The cook loop iterates the active set. Live nodes skip the parameter hash while elapsed time is moving. Lag, Filter, and Smooth drop time_dependent once their carried state settles.

### 2026-10-07 — FIXED: ImageFileInIMG `async_load` + SCRIPT code-body demand + Select wireless

- **`keep_dirty_after_cook`** on `GNNode`: async / one-frame lag operators set this in `_cook`; `execute_cook` re-dirties and clears `_last_cook_input_hash` so the hash guard cannot skip the follow-up. Used by ImageFileInIMG, TOPtoIMG, BloomTOP (replaces `call_deferred("mark_dirty")`).
- **SCRIPT demand:** `_get_expression_refs` / `_build_wireless_demand_map` scan STRING script bodies (`code`, `py_source`, `cpp_source`) for `chop()`/`dat()`/etc. — same as expression params.
- **Select\*:** removed blanket `time_dependent`; wireless refresh via `_wireless_consumer_map` + remote hash. All Select\* resolve network via `GNNode.get_owning_network()` (CookEngine parent), not a `GNNetwork` scene parent.

### 2026-10-11 — Hard Rule 25.48: build scripts and guides stay in step

- A download, probe path, `setup`/`vendor_clone` line, or Actions step updates the script and `dev_docs/BUILD.md` (plus the extension README) in the same change

### 2026-09-23 — Hard Rule 25.46: multi-stage work must be resumable

- Stage isn't done until findings + honest progress status + `## Resume here` block are written
- Resume block must carry environment state that cost real time (built extensions, templates) so a fresh agent never repeats an expensive build
- Task doc holds the log; `ai/MEMORY.md` holds only a one-line pointer

### 2026-09-12 — Hard Rule 25.45: docs sync with code

- Param/port/behavior/format changes must update `docs/OPERATORS.md` + `.cfg` description in the **same** change
- Cursor rule + CONTRIBUTING §11 + copilot-instructions updated

### 2026-09-12 — AudioFileIn seek scrubber + refuse 24-bit

- Seek was unusable: cook reset `seek_pos` to 0 after every jump (`if seek_pos > 0`). Now a real scrubber (ranged 0…duration, follows playhead)
- 24-bit / float WAV **refused** with a clear warning — use 16-bit PCM WAV or OGG (no in-engine convert)

### 2026-09-12 — AudioFileIn Load Mode Auto|Memory|Stream

- Default **Auto**: disk-stream 8/16/24-bit PCM WAV (no full-file RAM decode); OGG/MP3 use Memory
- Large/24-bit WAV never full-decodes even if Memory is selected (forces Stream) — avoids editor freeze
- Memory decode uses a worker thread and **awaits** completion (never `wait_to_finish` while alive)
- Keep `_current_load_mode` as the UI enum value so cook() does not reload every frame

### 2026-09-12 — AudioFileIn Load Mode Memory|Stream

- Param `load_mode`: **Memory** (default, all formats, threaded full decode) or **Stream** (disk-stream 8/16-bit PCM WAV via `AudioStreamGenerator` + `FileAccess`)
- Stream unsupported formats (OGG/MP3/24-bit) log a warning and fall back to Memory
- `GNResourceLoader.peek_wav_layout()` / `wav_layout_is_streamable()` for header-only probes
- FFmpeg still not used for playback

### 2026-09-12 — Audio playback: thread load, no FFmpeg

- Godot `ResourceLoader.load_threaded_*` only works for imported `res://` assets — project/filesystem WAVs use `AudioStreamWAV.load_from_file` (sync)
- `AudioFileInCHOP` loads on a **background Thread**; main thread only attaches `AudioStreamPlayer`
- Godot plays 8/16-bit PCM WAV natively; 24-bit/float convert **in-process** (no FFmpeg). Prefer 16-bit WAV or OGG for large songs
- FFmpeg remains for **FFmpegOUT** encode only, not playback

### 2026-09-12 — Windows build gotchas fixed

- `check_env.py` must use `vswhere -products *` or VS **Build Tools** is missed
- Depth backends use `libs_<sdk>` optional_sdks; probes now require `.lib` files (empty SDK dirs used to pass then LNK1181)
- First-time path: `check_env.py` → `build_windows.ps1` → `check_builds.py`; docs in `dev_docs/BUILD.md`

### 2026-09-12 — Godot 4.7.2 bump

- Engine: `versions.env` → **GODOT_VERSION=4.7.2** (`GODOTCPP_BRANCH` still **4.5** — no 4.7 godot-cpp branch yet)
- Editor + console: `C:\Users\hesam\OneDrive\Documents\Godot\Godot_v4.7.2-stable_win64.exe\`
- Export templates installed to `%APPDATA%\Godot\export_templates\4.7.2.stable\` from the `.tpz`
- Set `$env:GONODES_GODOT` to the `*_console.exe` for headless tests

### 2026-09-12 — Interactive panels + hard rules 25.40–25.44

- Interactive TOPs use `GNInteractivePanel` + `GNTopInteractiveBase` (params SoT; viewer + WindowOUT each own a panel view)
- DragUI ops removed; operator total **585** (UI 33; extension ops 116)
- New rules: 25.40 counts from scanner, 25.41 core≠ui class_names, 25.42 N panel views / params SoT, 25.43 README=cfg, 25.44 TOP/IMG boundary
- Canonical Godot for this repo: `versions.env` → **4.7.2**; set `$env:GONODES_GODOT` to the console .exe for tests

<!-- Add new entries above this line, newest first -->

### 2026-07-01 — Extension setup pipeline and Windows max build

- `build/gn_ext_setup.py` runs `setup` / `vendor_clone` from each `native/build.cfg`
- `scripts/run_extension_setups.py --for-build` matches the upcoming scons tier (default `all`)
- `scripts/build_windows.ps1` default: `tier=all` after SDK fetch; `-Shipped` for core+extension only
- Bare `scons` remains **shipped** (core + extension); use `scons tier=all` or `build_windows.ps1` for optional tier

### 2026-07-01 — Repo hygiene and novice build path

- Repo is **source only**: SDKs (`opencv_sdk/`, `toolchain/python/`), `native/bin/`, and extension-root `bin/` are gitignored — never commit them
- Extension author checklist: `dev_docs/NEW_EXTENSION_CHECKLIST.md`
- `setup_deps.py` reads `build.cfg` and runs extension SDK scripts (failures non-fatal)
- NDI and OpenCV are **optional** extensions — included in `tier=all`; skipped when SDK probes missing
- Build planner: `build/gn_ext_plan.py` — `tier`, `default`, `optional`, `probe`, `setup`, `vendor_clone` in each `native/build.cfg`
- OpenCV: `addons/gn_ext_opencv/setup_opencv.py` (not bundled in git)

### 2026-07-01 — Windows dev environment setup

- Primary dev machine path: `C:\Users\hesam\Documents\Projects\gonodes`
- GitLab remote: `git@gitlab.com:kino-dome/gonodes.git`
- SSH auth configured for `@kino-dome`
- Python 3.12.10 installed via winget; set `$env:PYTHONUTF8 = "1"` before running setup scripts (avoids cp1252 Unicode errors)
- Godot 4.6.3 at `C:\Users\hesam\OneDrive\Documents\Projects\Godot_v4.6.3\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe`
- First-time clone: run `godot --headless --path <project> --import` before tests (creates `.godot/` and registers `class_name` globals)
- VS 2022 Build Tools install required for native `scons` builds (was in progress during initial setup)
