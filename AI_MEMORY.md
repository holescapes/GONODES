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

<!-- Add new entries above this line, newest first -->

### 2026-07-01 — Repo hygiene and novice build path

- Repo is **source only**: SDKs (`opencv_sdk/`, `toolchain/python/`), `native/bin/`, and extension-root `bin/` are gitignored — never commit them
- Fresh clone: `python scripts/check_env.py` → `python setup_deps.py` → `scripts/build_windows.ps1` (Windows) or manual steps in `dev_docs/BUILD.md`
- `setup_deps.py` runs `setup_opencv.py`, `setup_python.py`, `setup_ml.py` (extension failures non-fatal for optional models)
- NDI and OpenCV are **optional** extensions — use `tier=optional` or `scons tier=all`; skipped when SDK probes missing
- Build planner: `build/gn_ext_plan.py` — `tier`, `default`, `optional`, `probe` in each `native/build.cfg`
- OpenCV: `addons/gn_ext_opencv/setup_opencv.py` (not bundled in git)

### 2026-07-01 — Windows dev environment setup

- Primary dev machine path: `C:\Users\hesam\Documents\Projects\gonodes`
- GitLab remote: `git@gitlab.com:kino-dome/gonodes.git`
- SSH auth configured for `@kino-dome`
- Python 3.12.10 installed via winget; set `$env:PYTHONUTF8 = "1"` before running setup scripts (avoids cp1252 Unicode errors)
- Godot 4.6.3 at `C:\Users\hesam\OneDrive\Documents\Projects\Godot_v4.6.3\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe`
- First-time clone: run `godot --headless --path <project> --import` before tests (creates `.godot/` and registers `class_name` globals)
- VS 2022 Build Tools install required for native `scons` builds (was in progress during initial setup)
