# GONODES Developer Documentation

> **Audience:** Contributors, plugin developers, and advanced users who need internals-level detail beyond the in-editor help system.

This folder contains architecture references, build internals, testing infrastructure, and design comparisons that go deeper than the user-facing help docs.

**For end-user documentation**, use the in-editor **Help** window (F1 or toolbar "📖 Help" button). User-facing guides live in `addons/gonodes/help/` and cover getting started, editor usage, expressions, the cook engine, player runtime, building, and extensions.


## File Index

| File | Audience | Contents |
|------|----------|----------|
| [CONTRIBUTING.md](CONTRIBUTING.md) | **All contributors** | **Start here.** Contribution rules, new operator checklist, code style, help system requirements, PR checklist, hard rules summary, common pitfalls, **extension authoring** (gn_extension.cfg format, platform/architecture/dependency guards) |
| [BUILD.md](BUILD.md) | Contributors, CI/release engineers | Full build system internals — Player/Editor export presets, release optimizations, GDExtension handling modes, main-scene swap mechanics, **native C++ library builds (gn_native)**, **CI pipelines for 5 platform targets** (GitHub Actions + GitLab CI), cross-compilation (ARM64, macOS universal), **UTF-8 encoding safeguards**. Condensed user version: `help/building.md` |
| [EDITOR.md](EDITOR.md) | Contributors, plugin developers | Editor internals — architecture, code file map, cook model deep dive, settings persistence implementation, Force Active mechanics, **compute shader detection & graceful degradation system** (renderer compatibility, skip logic, warning badges), **debug window & graph overlay system** (3-tab debug panel, 5-layer overlay with cook order/active dimming/dirty propagation/sink labels/data flow annotations, F2 toggle). User version: `help/editor.md` |
| [OPERATORS.md](OPERATORS.md) | Contributors | Static operator reference snapshot (may be outdated). Live reference is auto-generated in the Help window's Operators section. Useful for implementation details ("How it works" per operator) |
| [PLAYER.md](PLAYER.md) | Contributors, deployment engineers | Player runtime internals — boot sequence, Window management implementation, scene swap, headless operation, troubleshooting. User version: `help/player.md` |
| [INTEGRATION.md](INTEGRATION.md) | **Host app developers** | **LibGodot embedding guide** — C API reference (`gonodes_host.h`), GPU context sharing (Vulkan/Metal/OpenGL zero-copy), bridge operators (HostIn/OutTOP, CHOP, DAT), GNEmbeddedHost singleton, hot-reload, parameter encoding, error codes, build instructions, 5 example apps, file map |
| [TD_HOUDINI_COMPARISON.md](TD_HOUDINI_COMPARISON.md) | Core developers | Architecture deep dive comparing GONODES with TouchDesigner and Houdini — cooking models, data flow, parameter systems, performance, extensibility. Includes gap analysis and prioritized improvement recommendations |
| [GONODES_VS_THE_REST.md](GONODES_VS_THE_REST.md) | Core developers, architects | Feature-by-feature comparison of GONODES vs TouchDesigner, VVVV, Houdini. 16 sections + 19-item optimization roadmap. Covers C++/Python scripting strategy |
| [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) | **Release engineers** | **Step-by-step release process** — dependency setup, godot-cpp builds, native extension compilation, template export, Quick Build validation, libgonodes, version coupling rules, packaging. Use this for every release |
| [TESTING.md](TESTING.md) | Contributors | Test framework architecture, running tests, writing new tests, coverage matrix, bugs found by tests. 1,331 automated tests across 48 files (1,044 core + 287 extension) |
| [NATIVE_AUDIT.md](NATIVE_AUDIT.md) | Core developers | C++ migration audit — every operator classified by CPU intensity (HOT/WARM/COLD), Phase 1–9 migration tracking, 103 native C++ classes, extension C++ status |


## Relationship to Help System

| Topic | User Docs (in-editor) | Dev Docs (this folder) |
|-------|----------------------|----------------------|
| Editor usage | `help/editor.md` — shortcuts, toolbar, workflow | `EDITOR.md` — architecture, code map, internals |
| Building | `help/building.md` — quick start, common options | `BUILD.md` — full internals, CI, optimizations |
| Player | `help/player.md` — config, hotkeys, usage | `PLAYER.md` — boot sequence, internals, troubleshooting |
| Operators | Help window (auto-generated) | `OPERATORS.md` — implementation details (snapshot) |
| Architecture | `help/cook_engine.md` — user-level overview | `TD_HOUDINI_COMPARISON.md`, `GONODES_VS_THE_REST.md` — full comparisons |
| Releases | N/A | `RELEASE_CHECKLIST.md` — full release process |
| Testing | N/A | `TESTING.md` — framework, running, writing tests |
