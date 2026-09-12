# GONODES — AI Memory (cross-tool)

> Curated facts and decisions for AI assistants. **Tool-agnostic** — Copilot Memories,
> Cursor User Rules, and chat context should all point here.
>
> Add dated entries when you learn something worth keeping. Keep entries short.

## How to use

- **Copilot:** reference this file in chat or add to workspace custom instructions.
- **Cursor:** `.cursor/rules/gonodes.mdc` instructs the agent to read this file.
- **You:** edit this file directly — it lives in git and syncs across machines.

## Entries

### 2026-09-12 — Interactive panels + hard rules 25.40–25.44

- Interactive TOPs use `GNInteractivePanel` + `GNTopInteractiveBase` (panel UI port → WindowOUT)
- DragUI ops removed; operator total **585** (UI 33; extension ops 116)
- New rules: 25.40 counts from scanner, 25.41 core≠ui class_names, 25.42 panel demand gating, 25.43 README=cfg, 25.44 TOP/IMG boundary
- Canonical Godot for this repo remains `versions.env` → **4.6.1**; set `$env:GONODES_GODOT` to the console .exe for tests

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
