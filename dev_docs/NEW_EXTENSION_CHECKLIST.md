# New Native Extension Checklist

> **Audience:** Extension authors adding a C++ GDExtension pack (`gn_ext_*`).
> **Related:** [BUILD.md](BUILD.md) (build system), [EXTENSIONS.md](EXTENSIONS.md) (runtime manifest), [CONTRIBUTING.md](CONTRIBUTING.md) (PR rules).

Extensions are **auto-discovered** from `addons/gn_ext_<name>/native/build.cfg`. No edits to `build/SConstruct`, CI matrices, or central registries are required.

---

## 1. Folder layout

```
addons/gn_ext_<name>/
├── gn_extension.cfg          # Runtime manifest (operators, guards)
├── README.md                 # User + author docs (required)
├── gn_<lib>.gdextension.disabled
├── setup_<name>.py           # Optional — SDK download (auto-run by setup_deps.py)
├── native/
│   ├── build.cfg             # Build policy + link rules (required for native)
│   ├── SConstruct            # 6-line shim → gn_build.build_extension()
│   └── src/                  # C++ sources
└── operators/                # GDScript wrappers
```

---

## 2. `build.cfg` policy fields

```ini
[library]
name = gn_myext
entry_symbol = gn_myext_init
platforms = windows, macos, linux
tier = extension          # core | extension | optional
default = true            # include in tier=minimal when true
optional = false          # true → missing SDK skips instead of failing unified build
setup = setup_myext.py --no-enable   # optional SDK script

[windows]
libs = mysdk
lib_dirs = mysdk/lib
probe = mysdk/lib/mysdk.lib   # optional — auto-derived from libs+lib_dirs if omitted
```

| `tier` | Fresh-clone `scons` (shipped mode) | When to use |
|--------|-----------------------------------|-------------|
| `core` | **Yes** — always attempted, including `scons tier=core` | HAP, MIDI, ML, host_bridge, user_python, … |
| `extension` | **Yes** on a normal shipped build. Left out of `scons tier=core` | Syphon, Spout, OpenCV, FFmpeg, web renderer |
| `optional` | **No** — only with `tier=all` or `tier=optional` | NDI, Blackmagic, depth_sensor backends |

**Rules:**

- Set `optional = true` for proprietary or large third-party SDKs.
- Add per-platform `probe` paths (or rely on auto-probe from `lib_dirs` + `libs`).
- Use `libs_<suffix>` / `optional_sdks` for partial backends inside one extension (see depth_sensor).

---

## 3. Runtime manifest

1. Create `gn_extension.cfg` — operators, `dependencies`, platform guards.
2. Ship `.gdextension.disabled`; `sync_gdextensions.py` activates after build.
3. Add `boot.gd` only if you need runtime registration hooks.

See [EXTENSIONS.md](EXTENSIONS.md) for the full manifest format.

---

## 4. Setup script (if external SDK)

1. Add `setup_<name>.py` in the extension root.
2. Declare it in `native/build.cfg`: `setup = setup_<name>.py --no-enable`
3. Support `--no-enable` (don't rename `.gdextension` during deps-only fetch).
4. `setup_deps.py` and `scripts/run_extension_setups.py --for-build` run it before compile.
5. Document manual fallback steps in `README.md`.

---

## 5. Build and verify

```bash
python scripts/check_env.py
python scripts/run_extension_setups.py --for-build --tier all
python scripts/list_extensions.py --tier all   # preview max-build plan
cd build && scons -j8                         # bare scons = shipped (core + extension)
cd build && scons tier=all -j8                # include optional tier (build_windows default)
python scripts/check_builds.py
```

On a **fresh clone**, `scripts/build_windows.ps1` defaults to **`tier=all`** (after running extension setups). Bare `scons` builds **core + extension** only (`shipped`). Extensions are **skipped** (not failed) when:

- Platform is unsupported (e.g. Syphon on Windows)
- SDK `probe` files are missing (e.g. NDI, Blackmagic — manual install)
- Extension is `tier=optional` and you used bare `scons` without `tier=all`

---

## 6. Tests and docs

- [ ] Operator unit tests in `addons/gn_ext_<name>/tests/` if applicable
- [ ] `README.md` with operators, SDK setup, and build commands
- [ ] Help patches per [NEW_OPERATOR_CHECKLIST.md](NEW_OPERATOR_CHECKLIST.md) for new operators
- [ ] Run `python scripts/verify_new_operator.py` for each new operator

---

## 7. PR checklist

- [ ] `native/build.cfg` has correct `tier`, `optional`, and `probe`
- [ ] No SDK binaries or `native/bin/` committed (source-only repo)
- [ ] `.gdextension.disabled` shipped, not pre-enabled
- [ ] `python scripts/list_extensions.py --shipped` shows extension in plan on target platform
