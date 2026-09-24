# GONODES — Pre-Beta Audit

> **Purpose:** measure how final GONODES is against its own stated intent, before the first public Beta.
> **Status:** Phases 0–7 written. 4n and live audio/MIDI/OSC/DMX stay UNVERIFIED until a person runs them. Phase 5 scored all 585 operators mechanically; per-operator cook-vs-docstring behavior was not proven one by one.
> **Started:** 2026-09-23
> **Blockers found so far:** 14 (see `Blockers`) — help-patch corpus, CI gating, native extensions broken
> by missing runtime-DLL deployment after a documented clean build, a test suite that reports green
> while hiding 8 real failures, and copy-on-write that corrupts shared images depending on cook order.

This document is both the audit report and its own resume state. Every stage appends findings and rewrites
the `Resume here` block below, so the program survives across sessions and across models.

---

## Resume here

> Rewritten at the end of every stage. If you are a fresh agent picking this up, read only this section
> plus `Method legend`, then continue. Do not re-derive earlier phases.

- **Last completed stage:** Remediation of B-12, B-13, and B-8. The audit write-up (phases 0–7) still stands. 4n Actual cells stay empty until the human walkthrough.
- **Next:** Phase 7 rank item 4 — deploy `python310.dll` and `opencv_world4100.dll` (B-6, B-10). The full recommended-fix table is the `## Fix list` section. Do not invent a second list.
- **Do not redo:** the 585-operator score, the Windows rebuild, or the contract tests' assertions except the one doc-typo expectation recorded below.
- **Verified this pass:**
  - `test_cow_` 10/10 pass (was 6/10).
  - `test_pat_` 8/8 pass (was 4/8). `*_z` expectation now matches the matcher (`scale_z` only); `PATTERNS.md` §1.4 was the typo (F4e-01).
  - A throwaway bare `assert(false)` was counted as a failure and the runner exited 1. That probe file was deleted.
- **Walkthrough:** Phase 4n's table is waiting for Actual cells. Filling them does not block 5a.
- **New test:** `tests/unit/test_osc_roundtrip.gd` (2 pass). Do not weaken `test_cow_ownership.gd` or `test_pattern_language.gd`. Do not rebuild.
- **B-9 update:** the POP "zero particles" half is a test defect (F4i-01). Do not "fix" `test_cpu_fallback.gd` during the audit. The VOL readback assertion is still open.
- **User instruction (2026-09-23):** do not pause for confirmation between phases.
- **Do not:** rebuild, weaken `test_cow_ownership.gd` or `test_pattern_language.gd`, or re-derive the output-demand / transmit-sink inventory. Live audio/MIDI/OSC stays `UNVERIFIED` until 4k/4l. Phase 5 rubric points 9–10 stay binding.
- **Working directory:** `c:\Users\hesam\Documents\Projects\gonodes`
- **Shell:** PowerShell. No `&&` chaining (use `;`), no heredocs. Set `$env:PYTHONIOENCODING='utf-8'`
  before any script that prints check/cross marks or it dies with `UnicodeEncodeError`. Shell tool calls
  need `required_permissions: ["all"]` — this machine cannot enforce the default sandbox policy.
- **Environment state — do not redo:**
  - `scripts/operator_registry.json` and `scripts/port_registry.json` **regenerated** this session
    (585 and 717 entries respectively).
  - Build env verified by `check_env.py --strict`: MSVC 2022 Build Tools present (`cl.exe` NOT in PATH —
    builds need a Developer Command Prompt), SCons 4.10.1, Python 3.12.10, Godot 4.7.2 reachable via
    `$env:GONODES_GODOT`, godot-cpp cloned with 1 Windows release lib already built, Spout2 auto-fetched,
    ML + OpenCV + Python SDKs ready.
  - Missing optional SDKs (expected, pre-authorized non-blockers): DeckLink, Azure Kinect, RealSense,
    Ultraleap, NDI. Syphon is macOS-only. Do not treat these as Phase 2 failures.
  - **Phase 2 is complete — do NOT rebuild.** All 11 Windows extension DLLs are freshly compiled from
    source and present; 11 `.gdextension` files are active; `libgodot-cpp…lib` + its 1,022 objects intact.
  - `addons/gn_ext_user_native/toolchain/godot-cpp/` is now bundled (69 + 1,012 headers, 107 MB lib) —
    this was missing before and took a manual `bundle_toolchain.py --all` to create. Do not delete.
  - `templates/windows_x86_64/GONODESPlayer.exe` (104.1 MB) now exists. Quick Build depends on it.
  - Embedded CPython toolchain restored at `addons/gn_ext_user_python/toolchain/python` (3.10.11 +
    NumPy 1.26.4). `gn_python.gdextension` was **enabled** by running `setup_python.py`; note it is still
    missing `python310.dll` in `native/bin/win64/` — see F2-05, left unfixed deliberately so the defect
    stays observable.
  - Two orphaned headless Godot processes were killed (PIDs 16772, 17024). If builds start failing with
    access-denied on DLLs, check for new orphans first.
  - **Critical for any shell running builds:** this environment lacks the `ProgramFiles(x86)` variable.
    Set it before invoking `build_windows.ps1` (see F2-01).
- **Files created by this audit so far:** `PRE-BETA_AUDIT.md`, `tests/unit/test_cow_ownership.gd`
  (Phase 4b; 4 of 10 fail on purpose), `tests/unit/test_pattern_language.gd` (Phase 4e; 4 of 8 fail
  on purpose), `tests/unit/test_take_roundtrip.gd` (Phase 4d; passes),
  `tests/unit/test_osc_roundtrip.gd` (Phase 4l; 2 pass).
  Temp score artifacts (untracked, do not commit): `_pbaudit_score.py`, `_pbaudit_phase5.json`.
- **Files modified by this audit so far:** `.github/copilot-instructions.md` (added Hard Rule 25.46),
  `dev_docs/CONTRIBUTING.md` (added Rule 25.46), `AI_MEMORY.md` (added audit pointer + 25.46 entry),
  `scripts/operator_registry.json` + `scripts/port_registry.json` (regenerated, expected churn).
- **Build artifacts created by Phase 2** (regenerable, should not be committed): all
  `addons/gn_ext_*/native/bin/` contents, 182 `.obj` files, `templates/windows_x86_64/`,
  `addons/gn_ext_user_native/toolchain/godot-cpp/`.
- **Temp files:** none outstanding. Regenerate on demand:
  `python scripts/validate_all_patches.py > _pbaudit_validate.txt 2>&1` for the 147 patch failures;
  build logs via the `Tee-Object` commands above. Nothing temp should be committed.
- **Open questions for the user:** none blocking Phase 4d. Phase 4n still needs hands-on editor time
  (that is also the only way to close 4c's UNVERIFIED feel items). B-1/B-3 (help-patch corpus) remain
  cheap mechanical fixes if you want them done before more audit.
- **Deviations from plan:** Phase 4a did not write new headless M5 probes. Phase 4b did write the
  test sweep the plan asked for. Those tests are not all green: a full `test_runner.gd` run will
  now exit 1 on the 4 contract failures in `test_cow_ownership.gd`, on top of the 8 bare-assert
  failures the runner still hides (B-8). A test script that fails to **parse** is also counted as an
  empty pass (seen while loading `test_pattern_language.gd`). Do not delete the failing tests to
  restore a green suite. Phase 4c is M1+M2 only. Phase 4d did not re-run the existing expression
  suite and did not open the inspector (M7).
- **Pre-existing tree state (not caused by this audit):** `git status` at audit start showed uncommitted
  churn in `.gdextension` files, native `bin/` binaries, ~40 operator scripts, several docs, and the new
  `tests/visual_audit/` folder. This is prior session work, not audit output. Phase 2 must record this
  before touching the build tree.

---

## Method legend

Every finding is tagged with how it was verified. Anything resting only on **M1+M2** is a
*claim-consistency* check, never a behavioral pass.

| Code | Method | Strength |
|------|--------|----------|
| **M1** | Code read — implementation vs claim | Structural only |
| **M2** | Doc cross-check — claim-by-claim against a named doc section | Structural only |
| **M3** | Script evidence — ran a `scripts/*.py`, output recorded | Strong for counts/consistency |
| **M4** | Test evidence — existing test, or written during audit | Strong |
| **M5** | Headless run — Godot headless on a patch, asserted cook result/log | Strong |
| **M6** | Visual patch — `tests/visual_audit/` pack opened by a human | Strong for GPU/visual |
| **M7** | Human walkthrough — action / expected / actual | Only route for UX feel |
| **M8** | Build evidence — compiles, binary present, loads | Strong |
| **M9** | Registry diff — vs `operator_registry.json` / `port_registry.json` | Strong for ports/params |

Status vocabulary: `PASS`, `FAIL`, `PARTIAL`, `BLOCKED`, `UNVERIFIED`.
`UNVERIFIED` is never folded into `PASS` — it means no SDK, no platform, no hardware, or human-only judgment.

---

## Verdict

*Not yet written — Phase 7 deliverable.* Requires Phases 1-6 complete.

---

## Blockers

*IDs are stable. Phase 7 ranks them by what should be fixed first; the numbers below are not that order.*

| # | Blocker | Source | Why it blocks Beta |
|---|---------|--------|--------------------|
| B-1 | VOL family help patches are all structurally invalid (31 type mismatches; `GridSOP` wired into VOL inputs) | F1-04 | Every VOL operator's `?` example is non-functional. A whole family ships undemonstrable |
| B-2 | 26 operators have **zero** help patches — the entire NET family (15), 6 of 8 FIX, plus FeedbackCOMP, DMXDAT, SerialDAT, PixelDmxOUT, FilterSOP | F1-01 | Contradicts `README.md:169` "3+ per operator" and the CONTRIBUTING PR checklist minimum of one |
| B-3 | 28 help-patch references to nonexistent operators (`EmitterPOP`, `GDScriptSCRIPT`, `UserPython*`, `UserNative*`, `LFOCHOP`, `DepthSensorTOP`, `ScriptCHOP`) | F1-05 | Those patches fail to load, so the `?` button is broken for the affected operators |
| B-4 | No audit script is gated in CI | F1-10 | Every finding in this audit can silently regress the day after it is fixed |
| B-5 | 108 of 585 operators have fewer than 3 help patches | F1-01 | Weakens BC-3; less severe than B-2 since something exists |
| B-6 | `setup_python.py` hardcodes `python312.dll` while shipping a 3.10.11 toolchain, so `python310.dll` is never copied and UserPythonSCRIPT is excluded from exported Players | F2-05 | A advertised feature (README:114) is broken after a documented clean build, and the release-checklist gate for it can never pass |
| B-7 | The README Windows quick path omits `setup_python.py` and `bundle_toolchain.py`, leaving UserPythonSCRIPT and UserNativeSCRIPT non-functional while `check_builds.py` reports success | F2-06 | A user following the documented path gets a silently incomplete install |
| B-8 | The test runner reported `ALL PASSED` while bare `assert()` failures and a script that failed to parse were invisible | F3-01 | **Fixed 2026-09-23.** `tests/test_runner.gd` now fails the test on a script error during the call, and fails the suite when a file declares `func test_` but registers nothing. A full run will exit 1 on the previously hidden asserts until those tests are fixed. That is the gate working |
| B-9 | VOL CPU readback size is still wrong (F3-02, not re-tested this turn). The POP half of the original report is a test defect, not an operator defect: see F4i-01 | F3-02, F4i-01 | BC-5 still fails for VOL until that readback is re-run. POP emit itself is not the bug |
| B-10 | `gn_ext_opencv` cannot be loaded by Godot because `opencv_world4100.dll` is never deployed; 20 operators unavailable after a "successful" build | F3-03 | Same root pattern as B-6. Two of the three shipped native-SDK extensions are broken by missing runtime DLL deployment |
| B-11 | `check_builds.py` verifies file existence rather than loadability, so it reported 11/14 PASS on a tree with two unloadable extensions | F3-05 | It is the verification step the release checklist relies on; as written it cannot catch B-6, B-10, or F3-04 |
| B-12 | Copy-on-write did not protect a shared buffer. A viewer on the producer was not counted, and a passthrough restamped `_shared` from its own consumer count onto the producer's object | F4b-02, F4b-03 | **Fixed 2026-09-23.** Viewer sinks increment their own count. `_stamp_owned_output` does not write `_shared` onto an input object. `test_cow_` 10/10. `DATA_TYPES.md` §5 updated |
| B-13 | Index patterns `n-m:take,period` and exclude-only `!5-10` did not select what `PATTERNS.md` §3 says, because `parse_index_range` split on every comma | F4e-02, F4e-03 | **Fixed 2026-09-23.** `:take,period` stays one clause. Exclude-only starts from every index. `test_pat_` 8/8 |
| B-14 | `docs/OPERATORS.md` header says 585, but 127 class names never appear, there is no `## SDF`, `## NET`, or `## SCRIPT` section, and the per-family totals are an older catalog (TOP 72 vs 138, CHOP 67 vs 107, IMG 15 vs 41, DAT 34 vs 51, SOP 64 vs 85, COMP 12 vs 27, MAT 8 vs 12). Line 6740 points at an SDF section that is not in the file and says 26 operators, not 29 | F6-01, F6-02, F5-01 | Rule 25.45 names this file as the operator reference. SDF, most of IMG, and the host bridge are absent while the header claims the full set |

Doc-drift findings (F0-01 … F0-10) are tracked under `Intent vs reality` and are not individually
blockers, but shipping Beta with a README that miscounts its own tests and operator library is a
credibility problem — treated as one grouped blocker candidate in Phase 7.

---

## Non-blockers — what Beta is pre-authorized to ship without

Taken verbatim from the project's own Beta rationale (`dev_docs/RELEASE_CHECKLIST.md` lines 335-345).
These are **already accepted** and must not be re-litigated as blockers in Phase 7:

- No production deployments yet — internal testing cannot replicate real-world creative workflows.
- Native extensions requiring third-party SDKs (FFmpeg, NDI, Blackmagic, …) not validated on all platforms.
- `libgonodes` C API fully implemented but not stress-tested in production hosts.
- GPU context sharing zero-copy paths depend on matching drivers / shared device setup.
- `.gnasset` serialization format may still evolve before being locked for 1.0.
- Timeline performance under complex multi-track compositions not validated in the real world.
- First public betas may ship **Windows x64 first**, expanding desktop platforms afterwards.

Graduation criteria (Beta → Stable 1.0) at `RELEASE_CHECKLIST.md` lines 347-353 are explicitly
post-Beta and therefore **out of scope** for this audit.

---

## Phase 0 — Intent baseline

**Status: DONE.** Methods: M2 throughout, with M1 spot-checks on `gn_extension.cfg` counts.

### The yardstick

The audit measures against the project's own Beta criteria rather than inventing new ones. From
`dev_docs/RELEASE_CHECKLIST.md` "Release Stage: Beta (not Alpha) Rationale" (lines 319-334), the claims
that must hold for Beta, each mapped to the phase that tests it:

| # | Beta claim (source: RELEASE_CHECKLIST 325-333) | Tested by |
|---|-----------------------------------------------|-----------|
| BC-1 | 585 operators across 15 families — complete creative toolkit | Phase 1 (M3) |
| BC-2 | Automated test suite with near-full operator coverage | Phase 3 (M4) |
| BC-3 | Help example patches for operators | Phase 1 (M3) |
| BC-4 | Cook engine stable — expressions, dirty propagation, timeline, multi-family flow "all verified" | Phases 4a, 4d, 4g |
| BC-5 | GPU zero-copy discipline — "zero unjustified CPU-GPU roundtrips across the entire codebase" | Phases 4i, 5 (Rule 25.44) |
| BC-6 | Cross-platform build system functional on Windows, macOS, Linux | Phase 2 (M8) — macOS/Linux will be `UNVERIFIED` |
| BC-7 | Embedding API complete — 60+ C functions, zero-copy GPU exchange, comprehensive test suite | Phase 4m |

Supporting intent sources, frozen here so later phases cite a fixed target:

- **`README.md`** — the public promise. Four headline claims: *ship anywhere* (8 platform targets, no
  license fees), *GPU-powered* (Vulkan/Metal/D3D12/OpenGL + compute), *embeddable* (LibGodot into VJ
  hosts), *open source*. Plus the 15-family operator table, the 23-pack extension table, and the
  GPU/CPU boundary rule (line 45) that Rule 25.44 enforces.
- **`GONODES_CONTEXT.md` §1-§2** — target audience is visual/generative art and VJing; architecture
  decisions declared "Locked In"; LibGodot is the portability layer.
- **`GONODES_CONTEXT.md` §15** — 8 design principles. Three are directly auditable and carry into later
  phases: #3 lazy evaluation (Phase 4a), #6 robust error handling / cook errors never crash (Phases 4a,
  4g), #7 performance visibility / cook times always measurable (Phase 4g).
- **`dev_docs/ROADMAP.md`** — what is *admitted* unfinished. Anything here is by definition not a Beta
  blocker unless a doc elsewhere claims it as done.
- **`versions.env`** — Godot **4.7.2**, godot-cpp branch 4.5, libgonodes 2.5.0, gdCEF 0.19.2.

### Declared-incomplete inventory (from ROADMAP, not blockers)

Recorded so no later phase mistakes these for regressions: modular per-extension `.pck` distribution;
asset browser panel + sharing portal; FxPlug/FFGL export; laser DAC drivers (EtherDream, Helios,
ShowNET); palette multi-output discoverability; network collaboration. Plus optimisation Tiers 1-4
(expression compilation to callables, adaptive frame budget, GPU batch parallel cook,
`max_cooks_per_frame` on the parallel path, texture pooling, async GPU readback, and the Tier 3-4
research items).

Two ROADMAP Tier 1 items are worth flagging now because they contradict performance claims elsewhere and
will be re-examined in Phase 4a: **item 5** states the frame-budget cap `max_cooks_per_frame` *only works
in the sequential cook path*, and **item 4** states GPU nodes do not parallelise. Both are honest in
ROADMAP; the question for Phase 4a is whether `COOK_ENGINE.md` or `README.md` overstate them.

### §26 Known Bugs — reconciliation

All three entries in `GONODES_CONTEXT.md` §26 are resolved. No open bugs are tracked there.

| ID | Bug | Recorded status | Audit note |
|----|-----|-----------------|------------|
| 26.1 | SoftBodyCOMP — Jolt SoftBody3D incompatible with SubViewport | Fixed by full rewrite to CPU Verlet PBD | Behavior to re-verify in Phase 5 (COMP) via its two test patches |
| 26.2 | WindowOUT — ESC to exit fullscreen not working | FIXED via `Window.window_input` signal | Re-verify in Phase 4f (M6/M7) |
| 26.3 | COMP fan-out — single-ownership scene node | FIXED via `GNProxyTree` | Has real coverage: `tests/unit/core/test_proxy_tree.gd`, 19 test functions |

**Finding:** §26 is titled "Known Bugs" but contains only an archive of *fixed* bugs. There is no
open-defect register anywhere in the repo. For a project entering Beta — where the entire point is
surfacing real-world edge cases — the absence of a defect register is a process gap, not a code gap.
Flagged for Phase 7. (M2)

### Intent vs reality — Phase 0 findings

All doc-level (M2). None are code defects; all are public-facing claims that are wrong today.
Several are blocked on Phase 1 counts before the correct value can be written.

| ID | Location | Claim | Reality | Severity |
|----|----------|-------|---------|----------|
| F0-01 | `README.md:344` | Architecture diagram base layer reads "Godot 4.6 Engine" | `versions.env` and `README.md:3,221` say **4.7.2** | Low, public-facing |
| F0-02 | `README.md:331` | "Operator Library (402 + extensions)" | **585** total confirmed by `scan_operators.py` | Low, internally contradictory. Count confirmed in Phase 1 |
| F0-03 | `README.md:173` | "1,376 automated tests across 52 test files covering all 13 families" | Project has **15** families (confirmed Phase 1); test count pending Phase 3 (was 2,048 in a prior session run) | Medium — understates and miscounts |
| F0-04 | `README.md:373-382`, `README.md:355` | "Five working example apps", 5-row table | `libgonodes/examples/` holds **8**: adds `geometry_host`, `midi_osc_host`, `graph_edit_demo` | Low — undersells |
| F0-05 | `README.md:305` | Mapper extension "5" operators | `README.md:97` says 7; `gn_extension.cfg` declares **7** (Quad, Bezier, GridWarp, EdgeBlend, ProjectionMask, Stoner, ProjectorBlend) | Low, internally contradictory (M1+M2) |
| F0-06 | `README.md:117` | SDF extension "40+ operators" | **29** — confirmed by `scan_operators.py` (`sdf: 29 (29 ext)`); `README.md:35,93` are correct, `:117` is wrong | Low, internally contradictory. Resolved in Phase 1 |
| F0-07 | `GONODES_CONTEXT.md:11,28` | "built on Godot 4.6"; decision table "Godot 4.6 (with LibGodot)" | **4.7.2** | Medium — this is the architecture doc, and §2 is labelled "Locked In" |
| F0-08 | `GONODES_CONTEXT.md:30` | Decision table row "Patch Format (MVP) — Godot Resource (.tres)" | Superseded by the next row (JSON `.gnpatch`, IMPLEMENTED); reads as a current decision | Low — historical row not marked historical |
| F0-09 | `README.md:169` | "1,547 example patches — 3+ per operator" | **2,064** patches (understated by 517); and "3+ per operator" is **false** — 108 operators have fewer, 26 have none | **RESOLVED by Phase 1** — see F1-01, F1-02 |
| F0-10 | `dev_docs/ROADMAP.md:3` | "verified against the actual codebase as of June 2025" | Repo is ~15 months past that date; ROADMAP v1.1 | Low — staleness marker on the roadmap's own freshness claim |

**Pattern worth naming:** eight of ten findings are *stale counts and version strings*, and four are
internal contradictions where README disagrees with itself. Individually trivial; collectively they mean
**no count in any doc can be trusted without regeneration**. That is why Phase 1 runs before the
per-operator and doc phases, and why Phase 6 should treat every number as suspect by default.

A second pattern: the drift is all in the *human-written* narrative docs, while generated artifacts
(`operator_registry.json`, `port_registry.json`) are regenerable. This argues for Phase 7 recommending
generated count includes over hand-maintained tables — noted, not yet a recommendation.

---

## Phase 1 — Automated ground truth

**Status: DONE.** All ten scripts ran clean (exit 0, except `validate_all_patches.py` which correctly
exits 1 on failures). Methods: M3 throughout. Commands used:

```powershell
$env:PYTHONIOENCODING='utf-8'   # required, or scripts printing check marks die with UnicodeEncodeError
python scripts/scan_operators.py
python scripts/build_port_registry.py
python scripts/check_node_types.py
python scripts/audit_labels.py
python scripts/audit_help_patches.py
python scripts/check_coverage.py
python scripts/validate_all_patches.py
python scripts/count_patches.py
python scripts/check_versions.py
python scripts/check_env.py --strict
```

### What passed

| ID | Check | Result |
|----|-------|--------|
| P1-01 | Operator inventory | **585 across 15 families**, matching `README.md`'s family table row-for-row: top 138, chop 107, sop 85, dat 51, img 41, ui 33, sdf 29, comp 27, net 15, mat 12, pop 12, vol 12, output 12, fix 8, script 3. **BC-1 PASS** |
| P1-02 | Port labels (Rule 25.14) | 328 files with labels, **0** multi-port files missing them. **PASS** |
| P1-03 | Version consistency | `versions.env` ↔ `project.godot` ↔ CI workflows all agree. Godot **4.7.2.stable.official.ed1daf0bf** installed; app version **0.1.0-beta**; libgonodes 2.5.0. **PASS** |
| P1-04 | Build environment (`--strict`) | 17/23 passed, **0 failures**, 6 skipped. Skips are exactly the pre-authorized set: Blackmagic DeckLink, Azure Kinect, RealSense, Ultraleap, NDI (optional SDKs absent) + Syphon (macOS-only). MSVC 2022, SCons 4.10.1, Python 3.12.10, godot-cpp cloned with 1 release lib. **PASS** |
| P1-05 | `dev_docs/SCRIPTS.md` accuracy | 35 of 39 scripts documented. Only genuine omission: `gen_visual_audit_patches.py` (added in the prior session). The other three are underscore-prefixed private helpers (`_check_gdext`, `_peek_patch`, `_registry_utils`); `setup_deps.py` is documented and correctly lives at repo root. **PASS with a minor gap** |

### Findings

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F1-01 | **Help-patch coverage does not meet the README's "3+ per operator" claim.** 108 of 585 operators have fewer than 3, and **26 have zero**. Distribution: 0 patches ×26, <3 ×108, exactly 3 ×329, >3 ×148 | `check_coverage.py` | **Beta blocker candidate (BC-3)** |
| F1-02 | **True help-patch total is 2,064, not 1,547** as claimed at `README.md:169` — understated by 517 | `count_patches.py` | Low. Closes F0-09 |
| F1-03 | **147 of 2,064 help patches fail static validation** (92.9% pass). Raw breakdown: 69 type mismatches, 59 orphan nodes, 29 missing-WindowOUT-sink, 17 flat params, 28 unknown operator types | `validate_all_patches.py` | See triage below |
| F1-04 | **The VOL family's help patches are systematically broken.** 31 of the 69 type mismatches are VOL (17 in `addons/gonodes/help/vol`, 14 in `addons/gn_ext_native/help/vol`), all the same shape: `GridSOP` port 0 (SOP) wired into a `*VOL` node's port 0 that expects VOL. Hits Analyze/Blend/Blur/Displace/Fluid/Null VOL. Separately `AnalyzeVOL` port 0 outputs CHOP but is wired to `RaymarchTOP` expecting VOL | `validate_all_patches.py` | **High** — every VOL `?` example is non-functional |
| F1-05 | **28 references to operators that do not exist**, so those patches cannot load: `EmitterPOP` ×5, `GDScriptSCRIPT` ×4, `UserPython{DAT,SOP,IMG,CHOP,TOP}`, `UserNative{SOP,IMG,TOP,DAT,CHOP}`, `DepthSensorTOP` ×2, `ScriptCHOP`, `LFOCHOP` (real class is `LFO_CHOP`) | `validate_all_patches.py` | **High** — needs triage to split stale renames from registry gaps |
| F1-06 | **Help-patch annotation quality: 174 issues across 148 patches** (145 HIGH, 29 MEDIUM); 1,916/2,064 clean (92.8%). HIGH issues are auto-generated boilerplate — "More complex configuration....", "Default settings...." — which defeats the purpose stated in `dev_docs/HELP_PATCH_RULES.md`. Worst offenders: `gn_ext_pixel_mapper/fix` **0%** and `/top` **0%**, `gn_ext_sdf/sdf` **68%** (52 issues / 81 patches), `gn_ext_native/vol` 82%, `gn_ext_native/top` 83%, `comp` 88%, `gn_ext_native/sop` 88% | `audit_help_patches.py` | Medium |
| F1-07 | **Cross-family help-patch misfiling.** `help/top/filter_{basic,advanced,mode}.gnpatch` are annotated "FilterSOP", and `help/vol/select_{basic,variation}.gnpatch` + `select_vol_basic.gnpatch` are annotated "SelectSOP". This correlates with `FilterSOP` reporting **0** patches — its examples appear to have been generated into `help/top/` because its `node_type` is the bare string `filter`. Suggests the generator keys on `node_type` without disambiguating family. `top/filter_mode.gnpatch` also duplicates the `_basic` annotation text | `audit_help_patches.py` + `check_coverage.py` correlation | Medium |
| F1-08 | **`scan_operators.py` extracts parameters for only 538/585 operators** — 47 gaps. Phase 5 rubric point 2 cannot be checked mechanically for those 47; they need manual reading. Cause not yet determined (likely programmatic param construction or native operators) | `scan_operators.py` | Medium — affects Phase 5 method |
| F1-09 | **`port_registry.json` covers 717 operators vs 585 in `operator_registry.json`** — the extra 132 are the native C++ variants (585 + 131 = 716, +1). Not a defect, but Phase 5 must not treat the two registries as the same population | `build_port_registry.py` | Informational |
| F1-10 | **No audit script runs in CI.** `.github/workflows/tests.yml` runs only `tests/test_runner.gd`; `build-extensions.yml` and `release.yml` do only builds. None of the ten scripts — including `validate_all_patches.py`, which exits 1 on failure — is gated | M1 read of all 4 workflows | **High, process** |

### Triage of F1-03 — which failures are real

Not all 147 are defects, and the report should not pretend otherwise:

- **Real defects (114 issues):** 69 type mismatches + 28 unknown types + 17 flat params. A connection that
  cannot exist, a reference to a nonexistent operator, and a malformed parameter block are unambiguously wrong.
- **Largely validator strictness (29 "no sink"):** the check specifically requires a **WindowOUT** node
  (`validate_all_patches.py` docstring line 7, "Missing WindowOUT sink"). Help patches legitimately rely on
  the viewer rather than opening an OS window, so most of these are false positives. Distribution:
  chop 9, output 8, dat 6, top 2, ui/comp/script/sop 1 each.
- **Mixed (59 orphans):** single-node demos — e.g. `BlackmagicDAT` listing devices, an `InfoDAT` shown
  standalone — are intentionally unconnected and viewed directly. Needs per-case triage in Phase 6.

### Assessment

The generated/mechanical layer of the project is in good shape: counts, labels, versions, and the build
environment all pass cleanly, and `README.md`'s headline operator table is exactly right. **The weakness is
concentrated in the help-patch corpus** — the single largest user-facing surface at 2,064 files, and the
one with no CI gate. F1-01, F1-04, F1-05 and F1-07 all point the same direction: the corpus was
substantially machine-generated and never fully validated, so it carries generator artifacts
(boilerplate annotations, family misfiling, stale operator names, SOP-shaped inputs on VOL nodes).

F1-10 is the root cause worth fixing first. Every Phase 0 doc-drift finding and most of Phase 1's
findings would have been caught automatically had these scripts been wired into `tests.yml`. Adding them
is cheap and turns this audit's findings into permanent gates rather than a snapshot.

One caution against over-reacting: 92.9% of patches validate and 92.8% have acceptable annotations. The
failures cluster hard (VOL, SDF, pixel_mapper, native variants) rather than spreading thin, which means
targeted fixes should clear most of it.

---

## Phase 2 — Clean rebuild (Windows x64)

**Status: IN PROGRESS.** Build running in background; log at `build_pbaudit_phase2.log`.

### Pre-existing tree state (recorded before touching the build tree)

`git status` at audit start already showed uncommitted churn, which is **prior session work, not audit
output**: 12 `.gdextension` files converted from `.disabled` to active, 3 native `bin/` DLLs
(deleted/modified for azure_kinect, realsense, ultraleap), ~40 operator scripts, 8 docs, and the new
`tests/visual_audit/` folder (25 files). Phase 2 build output will add further `bin/` churn on top of this.

### Preparatory steps — all clean

| Step | Result |
|------|--------|
| `python setup_deps.py` | **PASS.** All deps already present — godot-cpp cloned, Spout2 vendored, ONNX Runtime SDK, OpenCV 4.10 SDK (`opencv_world4100.lib`), embedded Python + NumPy 1.26.4 |
| `python scripts/run_extension_setups.py --for-build --tier all` | **PASS.** 4 ok, 0 failed |
| `python scripts/check_env.py --strict` (re-run inside build pipeline) | **PASS.** 17/23, 0 failures, 6 skipped |

### Findings

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F2-01 | **`build_windows.ps1` fails instantly with a misleading error when `ProgramFiles(x86)` is unset.** Line 49 hard-codes `${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe` with no fallback. In an environment where that variable is absent (this agent's shell had only `ProgramFiles` and `ProgramW6432`), the path collapses to `\Microsoft Visual Studio\Installer\vswhere.exe` and the script aborts with *"vswhere.exe not found. Install Visual Studio 2022 Build Tools with C++ workload."* — while VS 2022 Build Tools **are** installed at `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools`. Note `check_env.py` detected MSVC correctly in the same shell, so the two have divergent detection logic | M8 — reproduced, then worked around with `[Environment]::SetEnvironmentVariable("ProgramFiles(x86)", "C:\Program Files (x86)")` | Low-Medium |

On F2-01's severity: a normal interactive Windows shell does set `ProgramFiles(x86)`, so most users will
never hit this. It is worth fixing anyway because the failure mode is maximally unhelpful — it tells the
user to install software they already have, and it will bite exactly the environments least able to
diagnose it (stripped CI containers, minimal shells, non-English installs where the fallback path differs).
A two-line fix: fall back to `${env:ProgramFiles}`, then a hardcoded `C:\Program Files (x86)`, then
`Get-Command vswhere`. Worth reusing `check_env.py`'s working detection instead of a second implementation.

### Build run 1 — incremental (relink only)

`build_windows.ps1` completed **exit 0 in 34 seconds**, which is itself the finding: object files were
already on disk, so this validated the build graph and the **link** step only, not compilation from
source. Recorded as evidence of the build system working, **not** as evidence that a fresh clone compiles.

Per-extension result, Windows x86_64, `target=template_release`:

| Extension | Result | Artifact |
|-----------|--------|----------|
| gn_ext_gpu_encode | **OK** | `libgn_gpu_encode…dll` 320 KB |
| gn_ext_hap | **OK** | `libgn_hap_codec…dll` 436 KB (incl. squish + snappy + hap) |
| gn_ext_host_bridge | **OK** | `libgn_host_bridge…dll` 392 KB |
| gn_ext_midi | **OK** | `libgn_midi…dll` 468 KB (incl. RtMidi) |
| gn_ext_ml | **OK** | `libgn_ml…dll` 397 KB (links onnxruntime) |
| gn_ext_opencv | **OK** | `libgn_opencv…dll` 436 KB (links opencv_world4100) |
| gn_ext_spout | **OK** | `libgn_spout…dll` 529 KB (incl. Spout2 SDK) |
| gn_ext_user_python | **OK** | `libgn_python…dll` 384 KB (links python310) |
| gn_ext_video_capture | **OK** | `libgn_video_capture…dll` 322 KB |
| gn_ext_native | **OK** | 2 shared libs |
| gn_ext_ffmpeg | **OK** | 9 shared libs (prebuilt EIRTeam) |
| gn_ext_blackmagic | `UNVERIFIED` | DeckLink SDK absent — pre-authorized |
| gn_ext_depth_sensor (azure_kinect / realsense / ultraleap) | `UNVERIFIED` | 3 device SDKs absent — pre-authorized |
| gn_ext_ndi | `UNVERIFIED` | NDI SDK absent — pre-authorized |
| gn_ext_syphon | `UNVERIFIED` | macOS-only |

`check_builds.py --all` reports **12/42 passed, 21 failed, 9 skipped** — but 21 "failed" are almost
entirely Linux and macOS binaries that cannot exist on a Windows machine. All 11 buildable Windows
extensions are present. Recording this as **PASS for Windows**, with the cross-platform rows
`UNVERIFIED`. See F2-04.

### Build run 2 — genuine clean rebuild: **PASS**

To make Phase 2 mean what the plan intended, all 195 extension `.obj` files (45.9 MB) were deleted while
preserving the 1,022 already-compiled godot-cpp objects and
`libgodot-cpp.windows.template_release.x86_64.lib` — rebuilding godot-cpp is the expensive part and was
not under test.

Two orphaned **headless** Godot processes (PIDs 16772 + 17024, started 2026-09-21, no window, no main
window title, 42 minutes of accumulated CPU on the first) were holding GDExtension DLLs and had to be
terminated before linking could proceed. These were leftovers from an earlier headless run, not a user
session. Worth noting as an operational hazard: a stale headless Godot silently blocks any rebuild.

Result after `clean_builds.py` + object purge + `build_windows.ps1`:

| Metric | Value |
|--------|-------|
| Translation units recompiled from source | **182** |
| Link invocations | 9 extensions + `gn_ext_native` |
| Compile errors | **0** |
| Compile warnings | **3**, all third-party: 2× `C4828` (illegal character in `Spout2/SpoutGL/SpoutCopy.cpp:845`), 1× `C4244` inside MSVC's own `xutility` header |
| Wall time | ~46 s |

All 11 Windows extensions produced fresh binaries (timestamps 03:36:45-03:36:49): gpu_encode 321 KB,
hap_codec 436 KB, host_bridge 392 KB, midi 469 KB, ml 397 KB, native 1,583 KB, opencv 436 KB, spout 529 KB,
python 384 KB, video_capture 322 KB, plus ffmpeg's 9 prebuilt libs.
`sync_gdextensions.py` then reactivated 11 `.gdextension` files. `check_builds.py` (Windows only):
**11/14 passed, 2 failed (Blackmagic, NDI — absent SDKs), 1 skipped (Syphon)**.

**Verdict: a documented clean build of all buildable Windows extensions succeeds from source with zero
errors.** BC-6 is satisfied for Windows x64; macOS and Linux remain `UNVERIFIED` on this hardware.

### Player template export — PASS

`build_templates.ps1 -Platforms windows_x86_64` produced
`templates/windows_x86_64/GONODESPlayer.exe` (**104.1 MB**), 1 successful / 0 failed. The script correctly
swapped `project.godot`'s main scene to `player_main.tscn` and restored it afterwards, filtered each
`.gdextension` down to libraries present on disk, and restored all of them on exit.

Note `templates/` did not exist before this run — so **Quick Build cannot work on a fresh clone** until
`build_templates.ps1` is run once. That is by design and documented, but it means "one-click export"
(`README.md:163`) has an undocumented prerequisite from the user's point of view.

### Findings

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F2-02 | **`clean_builds.py` crashes and leaves the repo half-cleaned when a DLL is locked.** `shutil.rmtree` at line 81 raises an unhandled `PermissionError: [WinError 5]` on a Godot lock artifact (`~libgn_gpu_encode.windows.template_release.x86_64.dll` — note the `~` prefix Godot creates for loaded GDExtensions). The script had already deactivated 2 of 10 `.gdextension` files before dying, so the tree is left inconsistent: some extensions disabled, others still active with binaries present. Worse than failing cleanly | M8 — reproduced | **Medium** |
| F2-03 | **`build_windows.ps1` passes `tier=all` to SCons, which warns it is unknown and "will be ignored"** — yet the GONODES `SConstruct` clearly does read it (it prints `tier filter: all` and correctly gates optional extensions). So the warning is false but alarming: a user watching a build sees their tier flag declared ignored. Likely a missing `Variables.Add` declaration in the SCons variable set | M8 — build log | Low |
| F2-04 | **`check_builds.py --all` and `bundle_toolchain.py --verify` conflate "not built for a foreign platform" with failure.** `check_builds.py --all` on Windows reports 21 failures, essentially all absent Linux/macOS binaries that cannot exist on this host (dropping `--all` gives the correct 11/14). `bundle_toolchain.py --all --verify` likewise reports `[X] bin/ — no release lib for linux` / `for macos` and concludes "Toolchain incomplete" even though the Windows lib is correctly bundled. Both should distinguish *missing but buildable here* from *not buildable here* | M3, M8 | Low |
| F2-05 | **`setup_python.py` has a hardcoded Python version that contradicts its own default, breaking UserPythonSCRIPT after a clean build.** The script's default toolchain is **3.10.11** and the extension links **`python310.lib`** (confirmed in the build log's `/LIBPATH:…toolchain\python\libs … python310.lib`), but line 370 hardcodes `for dll_name in ["python3.dll", "python312.dll"]` with the line 360 comment *"The DLL is linked against python312.lib, so Windows needs python312.dll"*. Consequences: (a) only the 65 KB `python3.dll` forwarder is copied into `native/bin/win64/` — the real **`python310.dll` (4.3 MB) is never copied**, though it exists in `toolchain/python/`; (b) `--verify` demands `python312.dll` and therefore **can never pass** on this toolchain, making the `RELEASE_CHECKLIST.md:65` gate unpassable. **Independently corroborated:** `build_templates.ps1` reported `Disabled: gn_ext_user_python/gn_python.gdextension (no libraries found on disk)` and excluded it from the Player export — so UserPythonSCRIPT would be **absent from an exported Player** | M8 — build log + two scripts agreeing | **High** |
| F2-06 | **The documented Windows quick path does not produce a working install.** `README.md:249-260` presents `check_env.py` → `build_windows.ps1` → `check_builds.py` as the Windows path, and `check_builds.py` reports `gn_ext_user_python` as **PASS**. But `build_windows.ps1` never runs `setup_python.py` (runtime DLLs) or `bundle_toolchain.py` (bundled godot-cpp for in-editor C++ compiles), so after following the advertised path both **UserPythonSCRIPT and UserNativeSCRIPT are non-functional** — the latter's toolchain was entirely absent (`include/`, `gen/include/`, `gdextension/`, `bin/`, `tools/godotcpp.py` all MISSING) until `bundle_toolchain.py --all` was run manually, which then succeeded (69 + 1,012 headers, 107 MB lib). These steps exist in `RELEASE_CHECKLIST.md` but not in the README quick path | M8 | **Medium-High** |
| F2-07 | **`~`-prefixed DLL lock artifacts are handled inconsistently across scripts.** `build_templates.ps1` explicitly cleans them (`Cleaned temp file: ~libgdffmpeg.windows.template_release.x86_64.dll`, with a code comment explaining that antivirus/indexers/Godot leave them), while `clean_builds.py` crashes on them (F2-02). The fix pattern already exists in the codebase and simply is not shared | M1, M8 | Low |
| F2-08 | **`gn_ext_native/example.gdextension` ships with no libraries** and gets auto-disabled on every export (`Disabled: gn_ext_native/example.gdextension (no libraries found on disk)`). Harmless but it is a stray template file inside a shipped extension | M8 | Low |

---

## Phase 3 — Test + patch validation

**Status: PARTIAL — the suite reports green, and that report is not trustworthy.**

Commands (M5):

```powershell
& $env:GONODES_GODOT --headless -s tests/test_runner.gd
& $env:GONODES_GODOT --headless -s tests/test_runner.gd --test-tag=patch
```

### Headline numbers

| Metric | Value | Source |
|--------|-------|--------|
| Suite result | `ALL PASSED — 2048 tests`, exit 0 | run above, 27.6 s |
| Test files | 47 | `tests/**/test_*.gd` |
| `--test-tag=patch` subset | `ALL PASSED — 9 tests`, exit 0 | run above, 10.9 s |
| Assertions the runner tracks | 2,399 `GNTestAssert.*` calls | grep over `tests/` |
| Assertions the runner does **not** track | 56 bare `assert(...)` calls | grep over `tests/` |
| Bare assertions currently **failing** | **8** | `SCRIPT ERROR: Assertion failed:` lines |

**F0-03 closed.** Real count is **2,048 tests across 47 files**. `dev_docs/TESTING.md` (1,376) and
`README.md:173` are both stale — understating, not overstating, so the doc drift itself is benign. The
count claim is now verified; the *meaning* of the count is the problem below.

### The suite is green while 8 assertions fail

The runner's pass/fail logic reads one source only:

```192:197:tests/test_runner.gd
	# Run test - catch assertion failures via GNTestAssert
	GNTestAssert._reset()
	if GNTestAssert._failure_count > 0:
		error_msg = GNTestAssert._last_failure
```

Failures are counted **only** when a test calls `GNTestAssert.*`. GDScript's built-in `assert(cond, "msg")`
prints `SCRIPT ERROR: Assertion failed: msg` to stderr and execution continues — the runner never sees it,
`_failed` stays 0, and `quit(1 if _failed > 0 else 0)` at line 64 exits **0**. So these eight real failures
are invisible to the developer, to `test_runner.gd`'s own output, and to CI:

```
SCRIPT ERROR: Assertion failed: Should have emitted particles
SCRIPT ERROR: Assertion failed: CPU mode with count > 0 should report particles
SCRIPT ERROR: Assertion failed: AttractPOP CPU should produce output
SCRIPT ERROR: Assertion failed: CollisionPOP CPU should produce output
SCRIPT ERROR: Assertion failed: ForcePOP CPU should produce output
SCRIPT ERROR: Assertion failed: LimitPOP CPU should produce output
SCRIPT ERROR: Assertion failed: TurbulencePOP CPU should produce output
SCRIPT ERROR: Assertion failed: CPU data should have res^3 elements for single-channel volume
```

All eight come from **`tests/unit/test_cpu_fallback.gd`** — which is the file covering BC-5 (graceful
degradation without compute). The one file whose failures matter most for a "runs everywhere" claim is
written entirely in the assertion style the runner ignores.

Seven of the eight look like **one root cause cascading**: `SourcePOP` in CPU mode emits zero particles
(`assert(pd.particle_count > 0, "Should have emitted particles")`, `test_cpu_fallback.gd:116`), so every
downstream POP test receives nothing and returns null:

```137:147:tests/unit/test_cpu_fallback.gd
func test_attract_pop_cpu_returns_particles() -> void:
	var src := _make_node(SourcePOP.new(), "src1")
	src.set_param_value("max_particles", 10)
	src.set_param_value("emit_rate", 10)
	var src_out := _cook_cpu_no_input(src)

	var attract := _make_node(AttractPOP.new(), "attract1")
	var inputs: Array[GNData] = [src_out]
	var out := _cook_cpu_with(attract, inputs)
	assert(out != null, "AttractPOP CPU should produce output")
```

**Honest limit on this claim:** I have established that the assertions fail and that the runner hides them.
I have *not* isolated whether the defect is in `SourcePOP`'s CPU path or in the test's `_cook_cpu_no_input`
helper. Root-cause attribution is Phase 4i work. Either way the reporting defect is real and independent.

### Two extensions fail to load at runtime after a clean, "successful" build

Both appeared as startup errors in the same run. Neither is reported by `check_builds.py`, which only
checks that a file exists on disk:

| Extension | Godot error | Root cause | Consequence |
|-----------|-------------|------------|-------------|
| `gn_ext_opencv` | `Can't open dynamic library: …/libgn_opencv.windows.template_release.x86_64.dll` | The 436 KB extension DLL **is** present; its dependency **`opencv_world4100.dll` (61.7 MB) is not**. It exists at three SDK paths under `native/opencv_extract*/` and `native/opencv_sdk/` but is never copied into `native/bin/win64/` | **All 20 OpenCV operators unavailable** at runtime |
| `gn_ext_depth_sensor` (ultraleap) | `No GDExtension library found for current OS and architecture (windows.x86_64)` + `dynamic library not found` | Both `gn_depth_ultraleap.gdextension` **and** `gn_depth_ultraleap.gdextension.disabled` exist simultaneously, plus a stale `.uid`. The DLL *is* at the declared path (350 KB). The vendor runtime `LeapC.dll` is also absent — the `.gdextension`'s own comment says it comes from the Ultraleap installer | Startup error spam; depth operators unavailable |

The OpenCV failure is **the same defect class as F2-05** (Python): the build links against an SDK import
library and never deploys the matching runtime DLL. That makes it a pattern rather than two accidents —
recorded as F3-03 and reflected in the blocker list.

The ultraleap duplicate-file state is a build-script artifact: `clean_builds.py`, `sync_gdextensions.py`,
and `build_templates.ps1`'s filter/restore cycle all rename these files, and the net result here left two
copies. I have not proven which script produced it.

### `--test-tag=patch` covers 9 tests against a 2,064-patch corpus

Nine patch-tagged tests, while `validate_all_patches.py` finds **147 failing patches** (F1-03). Combined
with F1-10 (no audit script runs in CI), the help-patch corpus is gated by **neither** the test suite nor
CI. This is the mechanism that let F1-03 reach this size.

### Shutdown hygiene

```
WARNING: 227306 ObjectDB instances were leaked at exit
ERROR: 545 resources still in use at exit
```

227k leaked objects is a test-harness teardown issue, not necessarily an engine leak — the runner
instantiates nodes per test and may never free them. It matters for the audit because it makes the log
unreadable at the tail (the last 30 lines are pure leak noise, which is why the `ALL PASSED` line is easy
to miss) and because it would mask a genuine leak regression. Not a Beta blocker on its own.

### Findings

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F3-01 | **The test runner silently ignores 56 bare `assert()` calls, 8 of which currently fail, and still reports `ALL PASSED — 2048 tests` with exit 0.** `test_runner.gd:192-197` counts failures only from `GNTestAssert._failure_count`; built-in `assert()` prints to stderr and is never tallied. CI therefore passes on a suite containing 8 real failures. This undermines BC-2 as a *gate* regardless of how many tests exist | M5 — run output + M1 — `test_runner.gd:64,192-197` | **High** |
| F3-02 | **POP CPU fallback produces no particles, and the VOL CPU readback is the wrong size.** 8 assertions in `tests/unit/test_cpu_fallback.gd` fail; 7 trace to `SourcePOP` emitting 0 particles in CPU mode. This is the exact path BC-5 / `README.md:81` ("compute nodes auto-skip… everything else keeps working") depends on, covering 12 POP and 12 VOL operators. Root cause (operator vs test helper) not yet isolated — Phase 4i | M5 | **High** (pending 4i triage) |
| F3-03 | **`gn_ext_opencv` cannot load: `opencv_world4100.dll` is never deployed next to the extension DLL.** Present at three SDK paths, absent from `native/bin/win64/`. All 20 OpenCV operators are unavailable after a build that `check_builds.py` reports as PASS. Same defect class as F2-05 — the build system deploys import libs' link-time artifacts but not their runtime DLLs | M5 — startup error + M8 — file listing | **High** |
| F3-04 | **`gn_ext_depth_sensor` is left with both `gn_depth_ultraleap.gdextension` and `.gdextension.disabled` present**, plus a stale `.uid`, and Godot fails to load it with `No GDExtension library found for current OS and architecture` even though the DLL is at the declared path. Vendor `LeapC.dll` is also absent. Produces startup error spam on every launch | M5, M8 | Medium |
| F3-05 | **`check_builds.py` verifies existence, not loadability.** It reported 11/14 PASS on a tree where two extensions cannot be loaded by Godot at all (F3-03, F3-04) and a third is excluded from exports (F2-05). A build-verification script that a release checklist depends on should attempt an actual headless load | M3, M5 | **Medium-High** |
| F3-06 | **`--test-tag=patch` runs 9 tests against 2,064 help patches, 147 of which fail static validation.** Neither the tagged subset nor CI (F1-10) gates the corpus | M5, M3 | Medium |
| F3-07 | **227,306 leaked ObjectDB instances and 545 resources still in use at exit.** Test-harness teardown rather than a proven engine leak, but it buries the result line under ~30 lines of warnings and would mask a real leak regression | M5 | Low |

---

## Phase 4 — Feature & UX audit

Thirteen subsystem batches (4a–4m) plus the hands-on walkthrough (4n). Each batch is scored on two
axes: correctness (docs claim vs code, coverage, failure mode, hard-rule compliance) and UX
(discoverable, gives feedback, undoable, consistent, holds up on a large graph, documented in
user-facing `addons/gonodes/help/`).

| Batch | Area | Primary methods | Status |
|-------|------|-----------------|--------|
| 4a | Cook flow & scheduling | M1, M2, M4 (M5 not run) | **DONE** |
| 4b | Data types, ownership & family bases | M4 | **PARTIAL** — B-12 |
| 4c | Editor UX | M1, M2 (M7 not run) | **PARTIAL** — surfaces present; EDITOR.md stale |
| 4d | Parameters, inspector, expressions | M1, M4 (M7 not run) | **PARTIAL** |
| 4e | Pattern matching language | M4 | **FAIL** — B-13 |
| 4f | Viewer, UI family, windows | M1 (M6 not run) | **PARTIAL** — dispatch exists; visuals UNVERIFIED |
| 4g | Timeline, cues, debugging, logging | M1, M2 (M5/M7 not run) | **PARTIAL** — four layers and F2 panel present |
| 4h | Scripting API | M1, M4 | **FAIL** — cook errors swallowed (F4h-01) |
| 4i | GPU architecture & graceful degradation | M1 + Phase 3 M5 | **PARTIAL** — POP zero-particle is a test defect (F4i-01); VOL readback still open |
| 4j | Three-tier resource loading & URL cache | M1, M4 | **PARTIAL** — 30 URL-cache tests pass; live HTTP UNVERIFIED |
| 4k | Audio subsystem | M1 (M7 not run) | **PARTIAL** — transmitters exist; F4k-01; unheard |
| 4l | Protocol interop | M4 (M7 not run) | **PARTIAL** — OSC wire format passes; live peers UNVERIFIED |
| 4m | Subnets, assets, export, embedding, extensions | M5, M3 (player/hosts not run) | **PARTIAL** |
| 4n | Hands-on UX walkthrough | M7 | **UNVERIFIED** — script written, 0 rows filled |

### Phase 4a — Cook flow & scheduling

**Status: DONE** (M1+M2+M4). No new M5 headless probes this session. BC-4 is only partly in scope
here (expressions + dirty propagation); timeline is 4g.

Sources: `addons/gonodes/core/gn_cook_engine.gd`, `addons/gonodes/core/gn_network.gd`,
`addons/gonodes/operators/net/sub_network_node.gd`, `dev_docs/COOK_ENGINE.md` (all 10 sections),
`addons/gonodes/help/cook_engine.md`, `tests/unit/test_cook_engine.gd`,
`tests/integration/test_cook_pipeline.gd`, `tests/integration/test_cook_chain.gd`.

#### Claim-by-claim vs COOK_ENGINE.md

| Doc claim | Code | Tests | Verdict |
|-----------|------|-------|---------|
| Demand-driven active set: BFS upstream from `active_sinks` + `is_sink` | `_compute_active_set()` at `gn_cook_engine.gd:386-455` | `test_active_set_with_sink`, `test_no_sinks_empty_active_set` | **PASS** (M4) |
| Expression refs and wireless `get_remote_dependencies()` join the active set | same function, lines 439-453 | `test_active_set_expression_ref_activates_node` | **PASS** (M4) |
| `get_active_input_indices()` prunes unused Switch/Math/CubeMap branches | lines 424-433 | **none** | **UNVERIFIED** |
| Expression-driven routing is 1-frame latent; Switch holds `cached_output` | routing snapshot in `_cook_single_node` 2148-2162; `_try_expression_dirty` 940-941 | **none** | **UNVERIFIED** (implemented, M1 only) |
| Cached Kahn topo, invalidated on topology Δ | `GNNetwork.get_topological_order` + `_topo_cache` | `test_cook_order_linear_chain`, `test_cook_order_diamond` | **PASS** (M4) |
| Wire cycles rejected at connect; leftover cycle logs and drops nodes from order | `connect_nodes` + `has_cycle`; `_compute_topological_order` 597-600 | `test_network.gd` only asserts *no* cycle on a linear graph | **PARTIAL** — reject path exists (M1), cycle-reject test missing |
| Pre-cook only on `is_active` | `_pre_cook_pass` 793-797 | implied by inactive-set tests | **PASS** (M1+M4) |
| Incremental dirty: only direct successors | `_dirty_immediate_downstream` 891-899 | `test_incremental_dirty_only_direct_successors`, `test_dirty_sibling_branch_not_affected` | **PASS** (M4) |
| Input hash guard skips cook when params + timestamps unchanged | see F4a-02 | `test_hash_guard_skips_unchanged` does **not** exercise the hash | **FAIL as documented** |
| Bypass passthrough, `_cook()` not called | `_cook_single_node` 2173-2188 | `test_bypass_passes_input_through`, `test_bypass_cook_time_zero` | **PASS** (M4) |
| Compute-unavailable → CPU fallback or skip + warning badge | 2190-2219 | `test_compute_guard_flag_default`; fallback *behavior* is B-9 / F3-02 | **PARTIAL** — skip path exists; fallback output is broken |
| `max_cooks_per_frame` aborts remaining work | only in sequential `else` at 775-776 | `test_max_cooks_per_frame_respected` (sequential) | **PASS sequential / FAIL parallel** — confirms ROADMAP item 5 |
| Level-based CPU parallel via WorkerThreadPool; GPU stays main-thread | `cook_frame` 698-757, `_cook_cpu_batch_parallel` 2292+ | **none** (`parallel_cook` / `multithreading` never appear in `tests/`) | **UNVERIFIED** |
| NRT: fixed `1/fps` step, deterministic | `_process` 252-257 also multiplies by `playback_speed` | only `test_expression_functions.gd` sets the flag | **PARTIAL** — exists (M1); determinism untested |
| Subnet: inner engine, `cooking_enabled = false`, parent `cook_frame`, `parent_engine` | `sub_network_node.gd` 77, 142-192 | no cook-engine-level subnet test | **UNVERIFIED** (M1 only) |
| Output demand culling, three sources | `_stamp_demanded_outputs` / `_build_wireless_demand_map` | **none** | **UNVERIFIED** |
| Shared-output `_shared` tagging when fan-out > 1 | `_cook_single_node` 2262-2264 | deferred to Phase 4b | — |
| Circular `par()` refs return fallback, don't crash | `_resolve_parameter_reference` 1570+ | `test_circular_self_reference`, `test_circular_mutual_reference` | **PASS** (M4) |

`GNOutBase` sets `is_sink = true` for the whole OUT family (`gn_out_base.gd:22`). Additional
structural sinks: HostOut\*, OutTunnel (toggled by demand), Spout/Syphon/MIDI/HAP/MovieFileOut,
DmxOutCHOP, AudioFileInCHOP while playing, SCRIPT `force_active`. Matches the documented model.

#### What the failure probes showed (M1, not M5)

- **Wire cycle:** `connect_nodes` refuses a cycle (`gn_network.gd:404-407`) and logs a warning. If a
  cycle is ever present anyway, Kahn returns a *partial* order and logs an error; the cyclic nodes
  simply never cook. No node badge. Actionable at connect time; silent at cook time.
- **Stalled / disconnected sink:** by design the chain is inactive. The user-facing route is F2 →
  Active Chains (`COOK_ENGINE.md` §9). No toast, no badge that says "this node is not in any active
  chain."
- **Never-clean node:** `time_dependent` nodes dirty themselves every pre-cook. The F2 dirty-flash
  layer is the diagnostic. There is no "this node has cooked N frames without going clean" counter
  beyond per-node `cook_time_ms`.

#### Scores

- **Correctness:** PARTIAL. The demand-driven loop, dirty propagation, expressions, bypass, and
  cycle-at-connect all hold and have tests. The two advertised Tier-2/Tier-3 wins (hash-guard skip,
  parallel frame budget) do not do what the docs say, and several load-bearing behaviours
  (Switch pruning, 1-frame hold, demand culling, parallel cook, subnet inner engine) have no test.
- **UX:** PARTIAL. F2 + §9 troubleshooting is real. User-facing `help/cook_engine.md` overstates
  dirty propagation ("through all connected nodes") and lists RenderTOP as a sink; RenderTOP is a
  TOP and only becomes a sink when the viewer selects it.

#### Findings

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F4a-01 | **`COOK_ENGINE.md` §1/§2 flowchart is stale.** It lists pre-cook → topo → active set. `cook_frame` does topo → **active set → then pre-cook** (`gn_cook_engine.gd:626-658`), and the code comment explains why (newly activated time-dependent nodes must see `is_active` during `_pre_cook`). The diagram is the old order | M1+M2 | Low (doc) |
| F4a-02 | **The input-hash-guard skip is unreachable from the cook loop.** `_classify_cook_status` only sends dirty (or just-dirtied-by-expression) nodes to `_cook_single_node`. The skip is `if hash == _last and not node.dirty` (`gn_cook_engine.gd:2168-2170`). `not node.dirty` is therefore always false on that path. `test_hash_guard_skips_unchanged` asserts the *same output object* on a clean second frame — that is the dirty-flag skip, not the hash. ROADMAP "parameter-level dirty tracking ✅ via input hash" and COOK_ENGINE.md §3.3 oversell an optimisation the loop cannot take. The engine still cooks correctly; it just recooks when a dirty flag arrives with unchanged params+timestamps | M1+M4 | **Medium** |
| F4a-03 | **`max_cooks_per_frame` is sequential-only**, exactly as ROADMAP Tier 1 item 5 already admits. The parallel branch (698-757) never consults it. Default is 0 (unlimited) and parallel is opt-in per patch (`multithreading_enabled`, off by default), so this is not a Beta ship-stopper — but COOK_ENGINE.md does not mention the restriction | M1, confirms ROADMAP | Low |
| F4a-04 | **Parallel-path `cooked_count` is inflated.** After `_cook_cpu_batch_parallel` the engine does `cooked_count += cpu_batch.size()` even though that helper `continue`s on a hash skip. Sequential path increments only on `r == 1`. Parallel cook is also entirely untested | M1 | Low |
| F4a-05 | **No tests for five documented behaviours:** selective `get_active_input_indices` pruning, 1-frame Switch hold, `is_output_demanded` culling, WorkerThreadPool parallel cook, subnet inner-engine `cook_frame`. Cycle *rejection* is also untested (`has_cycle` is only asserted false on a linear graph) | M4 gap | Medium (coverage) |
| F4a-06 | **NRT snippet in COOK_ENGINE.md §7 omits `playback_speed`.** Code is `(1.0 / non_realtime_fps) * playback_speed` (`gn_cook_engine.gd:253`) | M1+M2 | Low (doc) |
| F4a-07 | **Demand-culling operator list is stale.** COOK_ENGINE.md §4.1 says "15 operators currently" and lists OpenCV + MovieFileIn + MultiBufferRender. Code also guards `GLSLMultiTOP`, `SubNetworkNode` OutTunnels, and `GNTopInteractiveBase` panel ports | M1+M2 | Low (doc) |
| F4a-08 | **COOK_ENGINE.md §8 names the host `SubNetworkCOMP`.** The class is `SubNetworkNode` (`sub_network_node.gd`) | M1+M2 | Low (doc) |
| F4a-09 | **User help contradicts the incremental model.** `addons/gonodes/help/cook_engine.md` lines 12-14: dirtiness "propagates downstream through all connected nodes". Engine only dirties *immediate* successors and stops when a node does not cook. Same page lists RenderTOP as a sink; it is not `is_sink` | M2 | Medium (user-facing) |

#### Assessment

The cook engine as a *machine* is the strongest part of the project I have read so far. Demand-driven
active set, incremental dirty, expression consumer map, bypass, connect-time cycle reject, and
`is_sink` are real, match the design principles in `GONODES_CONTEXT.md` §15.3/#6, and have tests.

What is not true: that the hash guard is the thing keeping static graphs cheap (the dirty flag is),
that the frame budget applies whenever cooking is parallel, or that Switch pruning / demand culling /
parallel cook / subnet inner engines are "verified." BC-4's phrase "all verified" is an overstatement
until 4g (timeline) and the UNVERIFIED rows above have tests.

No new Beta blocker. F4a-02 is the one I would fix first after the existing B-list — one inverted
condition, and the documented Tier 2 win starts working. Do **not** fix it during this audit.

### Phase 4b — Data types, ownership & family bases

**Status: PARTIAL.** Methods: M1+M2 for the inventory, M4 for the ownership contract.
New file: `tests/unit/test_cow_ownership.gd` (10 tests, 6 pass, 4 fail). Run with
`--test-filter=test_cow_`. The 4 failures are the contract; do not weaken them.

#### Inventory

10 `GNData` subclasses, all override `duplicate_data()`:

| Class | Family | Deep copy? |
|-------|--------|------------|
| `GNTextureData` | TOP | No — shares `texture` / `viewport` (GPU handle, correct) |
| `GNImageData` | IMG | Yes — `image.duplicate()` |
| `GNChannelData` | CHOP | Yes — per-channel `PackedFloat32Array.duplicate()` |
| `GNGeoData` | SOP | Yes (existing `test_data_types.gd`) |
| `GNTableData` | DAT | Yes — row `duplicate()`. `has_header` defaults **true**, so `cell(0,0)` skips row 0 |
| `GNMaterialData` | MAT | Yes — `material.duplicate()` |
| `GNParticleData` | POP | CPU arrays duplicated; GPU buffer copied when present |
| `GNVolumeData` | VOL | CPU array duplicated; GPU texture copied via `texture_copy` |
| `GNCompData` | COMP | `scene_node` shared on purpose |
| `GNUIData` | UI | `control_node` shared on purpose; `widget_state` duplicated |

11 core family bases set `family` in `_init`: Top, Img, Chop, Sop, Dat, Mat, Comp, Pop, Vol, Ui, Out.
`GNTopInteractiveBase` is a TOP subclass, not an extra family. SDF and FIX bases live in their
extensions. SCRIPT and NET have no family base; they extend `GNNode`.

`_mutable_input()` (`gn_node.gd:939`) matches the documented snippet. Call sites in the whole
`addons/` tree: **`BlurIMG` and `PixelSortIMG` only**. Blur reads pixels into new images, so the
call is unused protection. PixelSort writes pixels in place (`pixel_sort_img.gd:97-98`) and then
`set_image`s that same `Image`.

#### What the tests showed

| Test | Result |
|------|--------|
| `_mutable_input` zero-copy when not shared; duplicates and isolates when shared | PASS |
| Image and table `duplicate_data` do not alias | PASS |
| Sole wire consumer leaves `_shared` false | PASS |
| Noise → PixelSort **and** Null, sort wired first | PASS (sort cooks while `_shared` is still true) |
| Two-wire fan-out sets consumer count > 1, but `_shared` is false after NullCHOP | **FAIL** |
| Viewer on the producer counts as a consumer | **FAIL** |
| Viewer on Noise + PixelSort as the only downstream (`is_sink`) | **FAIL** — same `Image` |
| Null wired **before** PixelSort | **FAIL** — same `Image` |

#### Scores

- **Correctness:** FAIL for the documented COW guarantee. The primitive (`_mutable_input`, deep
  `duplicate_data` on CPU families) is real. The engine's decision of *when* data is shared is wrong
  in two independent ways, and only two operators even call the primitive.
- **UX:** a viewer can show another node's mutation with no warning. That is the corruption case,
  not a missing tooltip.

#### Findings

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F4b-01 | **`_rebuild_consumer_counts` does not count the viewed node.** `gn_cook_engine.gd:963-967` walks `get_input_connections(sink_id)`, so a viewer on node A increments A's *inputs*, not A. The prose in `DATA_TYPES.md` §5 ("the viewer is also reading it") describes the case the code misses. The code snippet in that same section matches the implementation, so the snippet and the prose disagree | M1+M4 `test_cow_viewer_on_producer_counts_as_consumer` | **High** |
| F4b-02 | **Passthrough restamps `_shared` on the borrowed object.** `_null_cook` (`gn_node.gd:332-335`) returns `inputs[0]`. The engine then does `result._shared = count(this node) > 1` (`gn_cook_engine.gd:2264`). A Null with no further downstream writes `_shared = false` onto the producer's data. Same pattern: `dot_node.gd`, `out_tunnel.gd`, `animation_comp.gd`, `replicator_comp.gd`, and every `null_*.gd` (CHOP/TOP/SOP/DAT/IMG/MAT/COMP/POP/VOL plus SDF and FIX). Cook order is Kahn insertion order, so which wire was drawn first decides whether PixelSort still sees `_shared` | M4 `test_cow_wire_fanout_marks_shared`, `test_cow_null_cooked_before_sort_does_not_alias` | **High — B-12** |
| F4b-03 | **PixelSortIMG mutates the producer's Image when `_shared` is false.** With the viewer on Noise and Sort as the only downstream sink, both outputs hold the same `Image` | M4 `test_cow_viewer_on_noise_pixel_sort_does_not_alias` | **High — B-12** |
| F4b-04 | **COW is opt-in at two call sites, not a family rule.** `DATA_TYPES.md` §7 says IMG/CHOP/SOP/DAT/MAT need COW. Only BlurIMG and PixelSortIMG call `_mutable_input`. Other filters that allocate new output are safe; anything that mutates `inputs[0]` or returns it is not | M1 | Medium |
| F4b-05 | **`GONODES_CONTEXT.md` §21 still lists POP as "(future)"** and the per-family table omits IMG, UI, VOL, SDF. The thread-safety paragraph below that table is current. `DATA_TYPES.md` §6 sample calls the type `GNImgData`; the class is `GNImageData` | M2 | Low (doc) |

#### Assessment

Producer-owns-data is the right rule and the duplicate helpers implement it. The cook engine then
breaks the flag that those helpers trust. B-12 is a real image-corruption bug, not a doc nit, and
it is order-dependent, which is why a patch can look fine until someone inserts a Null.

Fix shape, not applied: stamp `_shared` on the producer once, and never write it from a node that
returned an object it does not own. Count `active_sinks` themselves as consumers of that node id,
not of their inputs. Then PixelSort's existing `_mutable_input` call is enough for the viewer case.

### Cross-cutting — output demand and transmit sinks

Folded in 2026-09-23 at the user's request. These two rules apply to Phase 5 (rubric points 9 and 10) and are re-checked in 4k/4l. This section is the inventory, not a per-operator pass.

**Demand rule.** Work that exists only to fill output port N runs only when `is_output_demanded(N)` is true. Demand is a wire to an active node, a wireless Select, an expression reference, or the viewer showing that port (`gn_cook_engine.gd:_stamp_demanded_outputs`). "Connected" in the user's wording means demanded, not merely drawn: an expression `chop("slider1", "value")` with no wire still demands the CHOP port.

**Transmit rule.** Audio, MIDI, OSC, and DMX do not leave the process because a CHOP cooked. They leave when a sink transmitter cooks. `SinkOUT` keeps a chain alive and sends nothing.

#### Transmitters that exist

| Data | Sink that actually sends | Sends when |
|------|--------------------------|------------|
| Audio samples | `AudioDeviceOUT` (`GNOutBase`, so `is_sink`) | `active` is on; pushes PCM via `AudioStreamGeneratorPlayback` |
| Audio file | `AudioFileInCHOP` sets `is_sink` while Play is on and plays to a bus that sends to Master | Play on — this one does **not** need AudioDeviceOUT |
| Audio/video record | `MovieOUT`, `FFmpegOUT`, HAP out, GPU-encode movie out | record/active |
| OSC | `OscOUT` (`is_sink`) | `active` (default **true**); UDP to host:port |
| MIDI | `RtMidiOutCHOP` (`is_sink`) | `active` (default true); needs `gn_ext_midi` |
| DMX | `DmxOutCHOP` (`is_sink`) | always cooks; Art-Net |
| Pixels to another app | Spout/Syphon/NDI outs | platform sinks |

`SinkOUT` accepts any family and cooks upstream. It is not a speaker, an OSC client, or a MIDI port.

#### Demand inventory (48 multi-output operators in `port_registry.json`)

| Group | Gated? | Evidence |
|-------|--------|----------|
| OpenCV trackers (7) + BlackmagicIn + DepthSensor | Yes, per port | `is_output_demanded` in each `_cook` |
| MovieFileInTOP audio (port 1) | Yes | `movie_file_in_top.gd:102` |
| MultiBufferRenderTOP depth/normal | Yes | ports 1 and 2 |
| GLSLMultiTOP extra passes | Yes | |
| SubNetwork OutTunnels | Yes | inner `is_sink` follows external demand |
| FixtureSamplerTOP CHOP | **Broken gate** | `is_output_demanded(1) or _total_leds > 0` — the second clause runs the sample whenever any LED exists |
| 33 UI widgets, CHOP `state` port | No | `GNUiBase.execute_cook` always calls `_build_state_chop()` |
| FluidVOL (2) and PyroVOL (3), plus native Fluid | No | sim writes every field every cook. COOK_ENGINE.md calls this inseparable; not yet proven |

UI state channels are cheap, and `chop("widget", "value")` must keep working with no wire, which the demand map already treats as demand. Building the CHOP when nothing demands port 1 is waste, not a wrong result. Fluid/Pyro are the expensive ungated case.

#### Findings

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F4x-01 | **FixtureSamplerTOP's demand check cannot fail** once LEDs exist, so the CHOP sample pass runs with the CHOP port idle | `fixture_sampler_top.gd:185` | Medium |
| F4x-02 | **Every UI widget rebuilds its CHOP state every cook**, whether or not port 1 is demanded. Safe for expressions; not demand-gated | `gn_ui_base.gd:121-124` | Low |
| F4x-03 | **FluidVOL / PyroVOL secondary fields are not demand-gated.** If those buffers are separable, this violates the rule. If the sim must write them, the row in Phase 5 must say why | no `is_output_demanded` in those files | Medium, unproven |
| F4x-04 | **Transmitters for audio, OSC, MIDI, and DMX exist and are sinks.** A bare WaveCHOP does not play; it needs `AudioDeviceOUT`. A bare CHOP of note channels does not emit MIDI; it needs `RtMidiOutCHOP`. OSC needs `OscOUT` | class reads above | Pass for "the sink exists" |
| F4x-05 | **`RtMidiOutCHOP` returns the input CHOP** (`midi_out_chop.gd:128`). Same `_shared` clobber as B-12: a MIDI sink downstream of a fan-out clears the producer's shared flag | M1, related to F4b-02 | Medium |
| F4x-06 | **`AudioDeviceOUT` stays `is_sink` when Active is off**, so the upstream chain still cooks. The push itself is gated. OscOUT closes UDP when inactive but also stays a sink | `GNOutBase._init` vs `audio_device_out.gd:54-59` | Low |

Live speaker, MIDI port, and OSC peer delivery stay `UNVERIFIED` until 4k/4l M7.

### Phase 4c — Editor UX

**PARTIAL.** Methods: M1+M2 against `dev_docs/EDITOR.md`, `addons/gonodes/help/editor.md`, `scenes/gn_editor.gd`, `addons/gonodes/ui/gn_graph_editor.gd`. M7 was not run. Every surface the plan named is present in code. Nothing here is a new blocker. Discoverability, gesture reliability, and large-graph behavior stay `UNVERIFIED`.

#### Surfaces

| Surface | Presence | Where |
|---------|----------|--------|
| Palette, including Custom → Family → Extension/User | Present | `gn_node_palette.gd`; opened with **Alt+A** (`gn_graph_editor.gd:420`), not Tab |
| Ctrl+F node search | Present | `KEY_F` → `GNGraphSearch.open_search()` (`gn_graph_editor.gd:427`) |
| Shortcuts the user help lists (B/L/H/V/M/W, Ctrl+Z/Y/L, bookmarks 1–9, ?) | Present | `gn_graph_editor.gd:_handle_key_input`. Copy/Cut/Paste/Duplicate/Select All are PopupMenu shortcuts on a menu that stays in the tree (`:341`, `:3261`) |
| File shortcuts Ctrl+N/O/S/Shift+S, Space, Escape, F1, F2, Backspace | Present | `gn_editor.gd:_unhandled_key_input` |
| Eight wire interactions (click-select, box-select, delete, highlight, double-click insert, cascade push, 6 px disconnect guard, right-click menu) | Present | `_selected_wires`, `_update_wire_box_selection`, `_delete_selected_wires`, `_draw_selected_wires`, `_begin_wire_insert`, `_cascade_push`, `_DISCONNECT_PORT_THRESHOLD := 6.0` |
| Shake-to-disconnect | Present | 3 reversals, 0.5 s, 200 px/s (`:242-244`, `:4087`) |
| Edge-scroll while dragging | Present | `_handle_edge_scroll` |
| Expression-reference overlay + logger toasts | Present | `_expr_ref_overlay`; `GNLogger.toast_sink` set in `_ready` |
| Annotations | Present | `GNAnnotationManager.setup` in `_ready` |
| Clipboard JSON (selection, debug dump, whole network) | Present | context-menu ids; `DisplayServer.clipboard_set` |
| Undo/redo (graph, positions with tween, parameter values) | Present | `UndoRedo` on the graph; `gn_param_row.gd:1001`; `_ur_animate_positions` |
| Preferences | Present | toolbar "Prefs" → `GNPreferencesDialog` |
| OS drop of `.gnpatch` / `.gnasset` | Present | `_can_drop_data` / `_drop_gnpatch` / `_drop_gnasset` |
| Multi-monitor DPI | Documented limitation, no local override | no `content_scale` in the editor or graph editor. Matches `EDITOR.md` "Known Limitations" |

User-facing `help/editor.md` agrees with the shortcut table above. `dev_docs/EDITOR.md` does not.

#### Findings

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F4c-01 | **`dev_docs/EDITOR.md` "Keyboard Shortcuts" describes a different editor than the one that ships.** It says node shortcuts live in `gn_editor.gd::_unhandled_key_input`, that **H = help** and **V = viewer**, and that **Tab** opens the palette. The code puts node shortcuts in `gn_graph_editor.gd:_handle_key_input`: **H aligns horizontally, V aligns vertically, the palette is Alt+A**. `help/editor.md` matches the code | `EDITOR.md:129-137` vs `gn_graph_editor.gd:419-478` and `help/editor.md:40-45` | Medium (doc). Behavior itself is implemented |
| F4c-02 | **Toolbar section is one redesign behind the code.** It describes two button rows plus a timeline, and "four" overlay toggles while naming five. `_setup_toolbar()` builds three scroll rows: file **and** view controls together, then transport/timeline, then debug. The five overlay names (`#Order`, `Dim`, `Dirty`, `Sinks`, `Flow`) match the code | `EDITOR.md:104-122` vs `gn_editor.gd:1070-1205` | Low |
| F4c-03 | **Shake detection doc drifts on two details.** The state table types `_shake_last_dir` as `int`; the field is a `Vector2`. Step 2 says the timer resets on every reversal; the code zeros it only on the first reversal, then lets the 0.5 s window run | `EDITOR.md:770-789` vs `gn_graph_editor.gd:238`, `:4096-4104` | Low |

Feel, whether PopupMenu shortcuts still fire while a parameter field is focused, and which of the two `_unhandled_key_input` handlers wins when Escape is pressed with search open, are `UNVERIFIED`. Both handlers consume Escape in some cases (`gn_graph_editor.gd:466`, `gn_editor.gd:1273`).

### Phase 4d — Parameters, inspector, expressions

**PARTIAL.** Methods: M1 against `gn_parameter.gd`, `gn_param_row.gd`, `gn_param_inspector.gd`, `gn_take_manager.gd`, `gn_param_preset_manager.gd`, and `GONODES_CONTEXT.md` §17. M4: existing `test_parameter.gd`, `test_expression_functions.gd`, `test_preset_manager.gd`, and the expression cook tests in `test_chop_chains.gd` (already in the Phase 3 suite; not re-run this turn). New M4: `tests/unit/test_take_roundtrip.gd` — 1 test, passed. M7 (autocomplete, widget feel) not run.

§17's two-mode model is what the code implements. `CONSTANT` and `EXPRESSION` only. `set_param_reference` / `set_chop_reference` write `par()` / `chop()` strings. A parse failure sets `expression_error`, logs it, and `gn_param_row.gd:update_expression_status` paints the field red, sets the tooltip to the error, and shows `→ err` on the resolved-value label. That meets the "surface on the row, not only in the log" probe at the code level. Whether a user notices it stays `UNVERIFIED`.

Spare parameters serialize with the node (`gn_node.gd:1088-1102`) and the inspector inserts a spare header (`gn_param_inspector.gd:231`). Preset copy includes them (`spare:` keys). Takes do not.

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F4d-01 | **Takes ignore spare parameters.** `capture_take` walks `node.parameters` only. A spare float changed after `capture_base` produced a take with 0 overrides | `gn_take_manager.gd:88`; `test_take_apply_revert_and_file` | Medium |
| F4d-02 | **`GNTakeManager.new(network)` is documented and does not exist.** No `_init`. Callers must assign `.network`. The take file round-trip itself works (`user://` save → new manager → `apply_take` restored 9.0) | class docstring vs `test_take_roundtrip.gd` | Low |
| F4d-03 | **Preset-manager docstring names two different user directories.** Line 12 says `user://gonodes_param_presets/`. Line 20 and `GNPresetPaths.USER_ROOT` say `user://gonodes/presets/`. The code uses the second | `gn_param_preset_manager.gd:12` vs `:20`; `gn_preset_paths.gd:21` | Low |

Named preset **files** (`save_preset` / `load_preset`) have no test. Clipboard copy/paste does (`test_preset_manager.gd`). Autocomplete popup exists (`gn_param_row.gd:70`) and was not exercised.

### Phase 4e — Pattern matching language

**FAIL.** Method: M4. `tests/unit/test_pattern_language.gd` encodes the example tables in `dev_docs/PATTERNS.md` §1.4, §2.4, §3, §4, §5, §6. Run: `--test-filter=test_pat_`. **4 pass, 4 fail.** Do not edit the failing assertions to go green.

What matches the doc: CSV include/exclude for **names** (including exclude-only implying `*`), character classes, expansion (numeric, alpha, cartesian, space-separated tokens), rename capture / bare-star shorthand / batch expansion, and `split_patterns`.

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F4e-01 | **`PATTERNS.md` §1.4 says `*_z` matches `tz`.** It matches `scale_z` only. `_` is a literal. The doc row is wrong; the matcher is right | `test_pat_14_wildcards` | Low (doc) |
| F4e-02 | **Houdini take-skip never runs.** `_parse_stride_range` implements `take,period`, but `parse_index_range` splits the whole string on `,` first. `0-19:2,5` becomes stride-2 plus the extra index 5 → `[0,2,4,5,6,8,…]`, not `[0,1, 5,6, 10,11, 15,16]`. `0-19:1,3` returns every index. `1-999:1,3` returns `1..count-1`, not every third starting at 1 | `gn_pattern.gd:136` vs `:237`; `test_pat_32_take_skip`, `test_pat_33` | **Blocker B-13** |
| F4e-03 | **Exclude-only index ranges return nothing.** `!5-10` with count 20 yields `[]`. Name patterns imply `*` when every term is an exclude; index ranges do not. `0-20, !10-12` (an include plus an exclude) does work | `test_pat_31_index_syntax`; `gn_pattern.gd:149-159` | **Blocker B-13** |

A script that fails to parse is still reported as a passing empty suite (seen when this file had a `const PackedStringArray`, which GDScript rejects). Same hole as B-8: the runner does not fail the process on `Parse Error`.

### Phase 4f — Viewer, UI family, windows

**PARTIAL.** Method: M1 only. M6 was not run. The packs in `tests/visual_audit/` (including `04_mapper_dual_panel.gnpatch`) stay `UNVERIFIED` until a person opens them. Do not treat the mapper sync fix as confirmed.

The two-tier path is real. `GNViewerPanel.update_from_node` picks a port (`_update_port_selector`) and calls `node.render_for_viewer(self, port)`. `GNNode.render_for_viewer` looks up `GNFamily.get_renderer(data.get_family())` and falls back to `get_preview_text()` when no renderer is registered. Eleven renderer scripts live under `addons/gonodes/ui/renderers/` (texture, image, channel, table, geo, volume, particle, material, comp, ui, plus the data base). The viewer exposes texture, embedded Control, info text, a shared 3D `SubViewport`, and `set_interactive_texture_overlay`.

`GNTopInteractiveBase` keeps a viewer panel and an export panel (`_ensure_viewer_panel`, `_ensure_export_panel`), pushes params to both, and gates the panel port with `_is_panel_port_demanded`. Quad, grid, bezier, and stoner mappers extend that base. Whether the two panels stay in sync, and whether the freed-object crash is gone, is `UNVERIFIED`.

`WindowOUT` creates a `Window`, positions it on a chosen monitor, supports fullscreen / borderless / windowed, reverts fullscreen on Escape, and adopts UI controls into the panel root (`_adopt_control`). Embedded fullscreen is a separate path for mobile/web. Multi-monitor DPI remains the upstream limitation recorded in 4c.

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F4f-01 | **Viewer, port picker, family renderers, dual interactive panels, and WindowOUT adoption are implemented.** None of it has been looked at on screen in this audit | M1 as above; `tests/visual_audit/README.md` | `UNVERIFIED` for behavior |

### Phase 4g — Timeline, cues, debugging, logging

**PARTIAL.** Method: M1+M2 against `dev_docs/TIMELINE.md` and the files it names. No new M5 transport probe this turn. Scrubber feel under load is `UNVERIFIED` (M7).

All four documented layers have code:

| Layer | Present |
|-------|---------|
| 1 Engine transport | `GNCookEngine` elapsed time / frame / NRT (scored in 4a); editor Space / Escape / step buttons |
| 2 TimelineCHOP | `timeline_chop.gd` exists (operator, not re-cooked here) |
| 3 CueDAT + CueCHOP | both `class_name`s exist and CueCHOP implements `_cook` |
| 4 Editor bar | scrubber, speed, loop, NRT fps — built in `gn_editor.gd::_setup_toolbar` (see 4c) |

The F2 panel has the three tabs the help page describes: Cook Chain, Active Chains, Parameter References (`gn_debug_panel.gd`). The graph overlay has the five toggles: cook order, dim, dirty flash, sinks, data flow (`gn_debug_overlay.gd:5-9`). `GNLogger.toast_sink` is wired (4c). Whether a user can discover a black or frozen output from these tools alone is `UNVERIFIED`.

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F4g-01 | **The four timeline layers and the debug surface exist in code.** Cue timing, NRT export determinism, and scrubber behavior were not executed | M1+M2 | `UNVERIFIED` for behavior |

### Phase 4h — Scripting API

**FAIL** for error reporting. Method: M1 against `help/scripting.md`, `gn_script_helper.gd`, `gdscript_script.gd`, `python_script.gd`, `native_script.gd`. M4: `--test-filter=test_script_` → **1 pass, 6 fail**.

`GNProxyTree` is the 3D scene proxy (`get_or_create_proxy`). It is not the scripting API. `GNOpProxy` is the expression `op()` object, already covered by `test_expression_functions.gd`. The user-script surface is `GNScriptHelper`: preamble injects `me`, `inputs`, `op`, `outputs`, `time`, `frame`, `dt`, plus `par` / `chop` / `top` / `sop` / `dat` / `set_par` / `network_*`. Help-page names `GDScriptSCRIPT`, `PythonSCRIPT`, and `NativeSCRIPT` match the three `class_name`s.

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F4h-01 | **A GDScript `cook()` that errors still counts as success.** `_safe_call` calls the method and returns `""`. Godot prints `SCRIPT ERROR` and execution continues. `cook_ok` stays true | `gn_script_helper.gd:291-297`; the six failing tests | Medium |
| F4h-02 | **GDScript compile failures never reach the node badge.** `compile_error` is logged only. `GDScriptSCRIPT` reads `node_warning` in the preview and never writes it. `PythonSCRIPT` and `NativeSCRIPT` do set `node_warning` | `gdscript_script.gd:104-106` vs `python_script.gd:125` and `native_script.gd:133` | Medium |
| F4h-03 | **The six script-CHOP tests fail because `@output chop` is a bare `GNData`.** `create_data_for_family` falls back to `GNData.new()` when no data factory is registered. Factories are registered only by `GNExtensionRegistry.scan_extensions()`, which the editor calls and this test does not. `set_single_value` then misses, F4h-01 swallows it, and the cast to `GNChannelData` is null. The one passing test asserts `true` | `gn_script_helper.gd:463-467`; `test_script_chop.gd:191-204`; editor scan at `gn_editor.gd:157` | Test hole plus F4h-01. Do not treat the editor happy-path as failed |

### Phase 4i — GPU and CPU fallback

**PARTIAL.** Compute detection is real: `GNGpuContext.is_compute_available()` caches whether `RenderingServer.get_rendering_device()` is non-null, and says Compatibility has none (`gn_gpu_context.gd:65-72`). The local `RenderingDevice` API (shaders, buffers, 3D textures, dispatch) is implemented. Phase 3 already ran `test_cpu_fallback.gd`.

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F4i-01 | **SourcePOP's CPU cook emits zero particles in that test because delta is 0, not because the emitter is empty.** `_cook_cpu` uses `int(rate * current_delta)`. The test calls `_cook_cpu` directly, and `GNNode.current_delta` defaults to `0.0`, so the emit count is 0. The test also sets `emit_rate`; the parameter is `rate` (label "Emit Rate"), default 1000, so the wrong name would not have zeroed a cook that had a real delta. A second assertion requires `cpu_positions.size() == particle_count`, but the pool is allocated to `max_particles` | `source_pop.gd:116-154`; `gn_node.gd:78`; `gn_pop_base.gd:172`; `test_cpu_fallback.gd:107-118` | Downgrades the POP half of B-9 to a test defect |
| F4i-02 | **VOL CPU readback size was not re-checked.** F3-02's eighth failure stays open | Phase 3 | Still part of B-9 |

Renderer matrix behavior (Forward+ vs Mobile vs Compatibility on a real GPU) stays `UNVERIFIED`.

### Phase 4j — Resource loading and URL cache

**PARTIAL.** `GNResourceLoader` implements the three tiers in its own header: `res://`, `project://`, and absolute filesystem paths, with type-specific loaders for image, font, audio (8/16-bit PCM only), shader, and video. M4: the URL-cache tests in `tests/unit/test_url_cache.gd` were run this turn in eight filtered slices. **30 tests, all passed** (URL classification, cache paths, invalidate/clear, resolve, and FileIn SOP / ImageFileIn IMG / AudioFileIn CHOP pending-vs-cached behavior).

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F4j-01 | **A URL cook whose node is not in the scene tree cannot start the download.** `HTTPRequest.request_raw` returns `ERR_UNCONFIGURED`. The operator still returns empty data, which is what the pending-URL tests assert, so the suite stays green. No live HTTP download was performed | `gn_url_cache.gd:78` and `:131`; Godot error during `test_imagefilein_img_url_pending_returns_empty` and the SOP/CHOP equivalents | Low. Live fetch `UNVERIFIED` |

Export-time media resolution (paths inside an exported player) was not run.

### Phase 4k — Audio

**PARTIAL.** Transmitters exist in code. Nothing was heard.

| Path | Sends audio? | Evidence |
|------|----------------|----------|
| `AudioDeviceOUT` | Yes, when **Active** is on. Active defaults **off**. `GNOutBase`, so it stays a cook sink either way | `audio_device_out.gd:31`, `:54-59` |
| `AudioFileInCHOP` | Yes, while **Play** is on. Sets `is_sink` from Play and sends its bus to Master | `audio_file_in_chop.gd:87`, `:753` |
| `AudioSourceCOMP` | Plays an `AudioStreamPlayer3D` only if the node cooks. It is **not** `is_sink`, and its only port is a COMP output | `audio_source_comp.gd:1-17` |
| `SinkOUT` | No. `is_sink` follows its Active flag and the cook sends nothing | `sink_out.gd:33-34` |
| A bare CHOP of samples | No | same rule as F4x-04 |

`GNAudioDevices` lists output and input devices and applies one global `AudioServer.output_device`. "Default" prefers the saved preference, then the current device, then the first listed. Godot has one output device at a time (`gn_audio_devices.gd:44-69`).

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F4k-01 | **`AudioSourceCOMP` does not keep itself cooking.** Dropping one into an empty patch does not make it a sink, so Play defaults on and still never starts. 3D audio needs a downstream demand or another sink | `audio_source_comp.gd` has no `is_sink = true` | Medium |
| F4k-02 | **Speaker output was not listened to** | M7 not run | `UNVERIFIED` |

### Phase 4l — Protocols

**PARTIAL.** Wire format passes. No packet left the machine.

`GNOscParser` encode/decode of int, float, string, and a two-message bundle passed (`tests/unit/test_osc_roundtrip.gd`, 2 tests). `OscOUT` is a sink, Active defaults **on**, and it sends UDP then returns null (`osc_out.gd:40`, `:53-79`). `RtMidiOutCHOP` is a sink and returns the input CHOP (already F4x-05 / B-12). `DmxOutCHOP` is a sink, Active defaults **off**, and both the idle path and the send path `return in_chop` (`dmx_out_chop.gd:43`, `:57-75`) — same shared-buffer restamp as B-12.

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F4l-01 | **OSC 1.0 int/float/string and bundles round-trip in memory** | `test_osc_roundtrip.gd` | Pass for the wire format |
| F4l-02 | **`DmxOutCHOP` returns the caller's CHOP object** after sending, same `_shared` clobber as MIDI out | `dmx_out_chop.gd:58` and `:75` | Medium, same bug as B-12 |
| F4l-03 | **No OSC client, MIDI port, or Art-Net node was contacted** | M7 not run | `UNVERIFIED` |

### Phase 4m — Subnets, assets, export, embedding

**PARTIAL.** Registry scan and asset load were run. The player and the C API were not.

This turn:

- `GNExtensionRegistry.scan_extensions()` loaded 25 extension folders. Core reported 468 operators, native acceleration 131. Skipped, matching Phase 2: Blackmagic, depth sensors, NDI, OpenCV, User Python (`GNPythonProcessor` missing), Web Render, and Syphon on Windows.
- `.gnasset` round-trip: `test_asset_to_dict_is_compact` and `test_asset_from_dict_restores_correctly` passed. Quad, bezier, and stoner map assets loaded. `test_inner_tunnels_have_correct_families` passed.
- `SubNetworkNode`, `InTunnel`, and `OutTunnel` exist. Out tunnels start as sinks and the subnet toggles that from external demand (`out_tunnel.gd:35-37`).
- Player boot is implemented in `scenes/player_main.gd`: `config.json`, `--patch`, log level, parallel cook, Escape quits, F1 debug overlay, F11 fullscreen. `templates/windows_x86_64/GONODESPlayer.exe` exists from Phase 2 and was not launched.
- `libgonodes/` has a README plus 8 example hosts (OpenGL, Metal, geometry, MIDI/OSC, graph edit, params, Vulkan, SDL). None were built or run.

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F4m-01 | **Player runtime and the libgonodes hosts were not executed.** The boot code and the eight example trees are present | M1 | `UNVERIFIED` |
| F4m-02 | **User Python is still skipped at registry scan** because `GNPythonProcessor` does not load. Same missing DLL as B-6 | scan log this turn | Already B-6 |

### Phase 4n — Hands-on walkthrough

**UNVERIFIED.** The script below is the deliverable. Every Actual cell is empty because nobody has run it in the editor. Do not mark a row pass from the code reads in 4c–4m.

| # | Action | Expected | Actual |
|---|--------|----------|--------|
| 1 | Press Alt+A, type a family name, place a node | Palette opens at the mouse. Tab does nothing | |
| 2 | Press H, then V, with two nodes selected | Nodes align. H is not help. V is not the viewer | |
| 3 | Ctrl+F, type a node id, then Escape | Search opens, then closes, and the timeline does not reset | |
| 4 | Shake one node left-right while dragging | Its wires disconnect. A toast says how many | |
| 5 | Open `tests/visual_audit/04_mapper_dual_panel.gnpatch`. Drag a corner in the viewer and in a WindowOUT | Both panels show the same warp. No freed-object error | |
| 6 | Scrub the timeline on a patch with more than a few dozen nodes | The playhead follows the mouse without a multi-frame stall | |
| 7 | WaveCHOP → AudioDeviceOUT, Active on | Sound from the selected output device. WaveCHOP alone is silent | |
| 8 | AudioFileInCHOP, Play on, no AudioDeviceOUT | The file is heard on Master | |
| 9 | AudioSourceCOMP alone, Playing on | Either it plays, or it is obvious that it will not cook. Silence with no warning is a fail (F4k-01) | |
| 10 | ConstantCHOP → OscOUT, Active on, a local listener on port 9001 | UDP packets arrive. A cook with no OscOUT is not a pass | |
| 11 | Note channels → RtMidiOutCHOP, Active on, a MIDI monitor | Messages arrive. No port open means UNVERIFIED, not pass | |
| 12 | Channels → DmxOutCHOP, Active on, an Art-Net listener | A DMX packet arrives. Active off must send nothing | |
| 13 | Type a bad expression on a float parameter | The field goes red and shows `→ err`, not only a log line | |
| 14 | GDScriptSCRIPT with a syntax error | The node shows a warning, not a silent empty cook (F4h-02) | |
| 15 | Quick Build a one-node patch and run `GONODESPlayer.exe` | A window opens. Escape quits | |

---

## Phase 5 — Per-operator audit (585)

**PARTIAL.** All 585 registry operators were scored by `_pbaudit_score.py` (M3) against `scripts/operator_registry.json`, `scripts/port_registry.json`, each `.gd`, each `.cfg` `description=`, and a class-name search of `docs/OPERATORS.md`. 397 had no mechanical flag. 188 had at least one. The flags are dominated by one docs hole (127 missing class names, F5-01 / B-14), not by stub cooks.

What this pass does **not** prove: that each docstring's behavior matches `_cook`. Zero operators lacked a class docstring, and zero `_cook` / `_cook_cpu` / `_cook_gpu` bodies were `pass` or `return null` only. That is presence, not a behavior proof. Point 1 stays UNVERIFIED operator-by-operator. Help-patch counts were not re-counted; they are B-1..B-5.

| Check | Result |
|-------|--------|
| Docstring present, cook not a stub | 585 / 585. Behavior match UNVERIFIED |
| Class name in `docs/OPERATORS.md` | 458 present, **127 absent** (F5-01) |
| `.cfg` entry | 583 present. `DMXDAT` and `SerialDAT` are deprecated and unregistered (F5b-02) |
| Empty `supported_platforms()` override | 0 |
| Multi-output without `is_output_demanded` | Only the 33 UI widgets and `FluidVOL` / `PyroVOL` — already F4x-02 and F4x-03. No new ungated multi-output |
| Help patches | Cite B-1..B-5. NET is the whole of B-2's zero-patch family |
| `node_type` shared across families | Many (`null`, `select`, `switch`, `filter`, `noise`, …). None of the collisions are two operators in the **same** family. `generate_help_patches.py:927` still stores the audit map as `all_existing[node_type]`, so a later family overwrites an earlier one. That is the mechanism behind F1-07 |

### F5-01 — 127 operators are absent from `docs/OPERATORS.md`

M3. Same fact as B-14. By family:

| Family | Missing | Names |
|--------|--------:|-------|
| SDF | 29 / 29 | Bend, Box, Capsule, Cone, Cylinder, Displace, Elongate, Gradient, Gyroid, Intersection, Material, Mirror, Null, Octahedron, Onion, Plane, Pyramid, Raymarch, Repeat, Round, Select, SmoothSubtract, SmoothUnion, Sphere, Subtract, Switch, Torus, Twist, Union |
| IMG | 24 / 41 | ArucoDetect, BackgroundSubtract, BlobTrack, CameraUndistort, ColorTrack, Contour, Convolve, DepthEstimate, DrawOverlay, FeatureMatch, HoughCircles, HoughLines, ImageFileIn, Morph, ObjectTrack, OpticalFlow, PerspectiveWarp, ScreenGrab, Segmentation, StereoDepth, StyleTransfer, Switch, Threshold, Webcam |
| DAT | 22 / 51 | ArucoPose, CHOP, CameraCalib, Cue, DMX, Error, Folder, MidiIn, Mqtt, MultiTouchIn, Network, ObjectDetect, PanelExecute, QRCode, RenderPick, Serial, SerialReceive, SerialSend, Table, WebServer, WebSocket, XML |
| CHOP | 18 / 107 | Beat, Channel, Clip, Cue, FaceDetect, Feedback, HandDetect, IK, Keyframe, LFO_, Object, OscIn, Perform, PoseDetect, Sequence, Skeleton, TabletIn, Timeline |
| COMP | 9 / 27 | Animation, Bone, Constraint, Engines, LOD, Navigation, Path, Replicator, Vehicle |
| NET | 9 / 15 | HostIn CHOP/DAT/POP/VOL, HostOut CHOP/DAT/POP/TOP/VOL |
| MAT | 4 / 12 | Line, NormalMap, Shader, Switch |
| SOP | 3 / 85 | FileIn, FileOut, ObjectMerge |
| TOP | 3 / 138 | Emboss, FFmpegIn, WebRender |
| SCRIPT | 2 / 3 | NativeSCRIPT, PythonSCRIPT (`GDScriptSCRIPT` is present, under the COMP chapter) |
| UI | 2 / 33 | Null, Switch |
| POP | 1 / 12 | Switch |
| VOL | 1 / 12 | Switch |

### Phase 5a — TOP (138) and CHOP (107)

**PARTIAL.** TOP: 17 flagged, 121 clean. CHOP: 19 flagged, 88 clean. Eighteen of the CHOP flags and three of the TOP flags are F5-01.

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F5a-01 | **`AudioRenderCHOP` writes a WAV and is not a cook sink.** Record and Export run inside `_cook`. With nothing downstream and the viewer elsewhere, the node never cooks, so the bounce never happens. Same shape as F4k-01 | `audio_render_chop.gd:42-79` — no `is_sink` | Medium |
| F5a-02 | **`RaymarchTOP` readbacks its compute texture to an `Image` on every cook** (`texture_get_data` then `ImageTexture`). Rule 25.44 forbids a silent GPU→CPU readback inside a TOP `_cook`. The bytes become the TOP output, so this is a performance path, not an IMG misfile | `raymarch_top.gd:199-204` | Medium |
| F5a-03 | **Five other TOPs call `texture.get_image()`.** `NDIOutTOP:60`, `SpoutOutTOP:58`, `SyphonOutTOP:55`, and `MovieFileOutTOP:110` do it as the send path. `FixtureSamplerTOP:306` samples LEDs (already F4x-01). These are named output/sample operators, not hidden analysis | those lines | Low |
| F5a-04 | **`BezierMapTOP` builds parameter names by concatenation, so `scan_operators.py` records zero params.** That is the concrete case behind F1-08. A `create_*` whose first argument is not a string literal is invisible to the registry. Grid warp still shows up because it also has literal names | `bezier_map_top.gd:46-48` | Low |
| F5a-05 | Mapper panel ports stay gated. `GNTopInteractiveBase.get_output_data` returns null unless `is_output_demanded` on the panel port. Typed `GNInteractivePanel` on `_create_interactive_panel` is the pattern Rule 25.41 already names | `gn_top_interactive_base.gd:152-177` | Pass for point 9 |

### Phase 5b — SOP (85) and DAT (51)

**PARTIAL.** SOP: 4 flagged (3 are F5-01, plus a comment). DAT: 25 flagged (22 are F5-01).

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F5b-01 | **`ArtnetDAT` broadcasts ArtPoll and is not `is_sink`.** Active defaults off. While Active is on, poll and expiry run only inside `_cook`, so an unwired, unviewed node discovers nothing and sends nothing | `artnet_dat.gd:31-62` | Medium |
| F5b-02 | **`DMXDAT` and `SerialDAT` set `deprecated = true` and are in no `.cfg`.** `DMXDAT` still encodes Art-Net OpDmx and is not `is_sink` (the live transmitter is `DmxOutCHOP`, already F4l). They also have zero help patches (B-2). A current editor cannot place them | `dmx_dat.gd:30-33`, `serial_dat.gd:19-22` | Low — already retired from the palette |
| F5b-03 | **`ObjectMergeSOP` is `deprecated=true` in its cfg and in code.** It is one of the three SOPs missing from OPERATORS.md | cfg + class | Low |
| F5b-04 | **`FilterSOP`'s TODO is a comment about a native expression mode, not an empty cook.** `_cook` exists at line 58 | `filter_sop.gd:109` | Low. Zero help patches remain B-2 |

### Phase 5c — IMG (41), UI (33), SDF (29)

**PARTIAL.** IMG: 24 flagged, all F5-01 (the OpenCV / ML / capture set). UI: all 33 flagged only because `GNUIBase` always builds the state CHOP (F4x-02); `NullUI` and `SwitchUI` are also F5-01. SDF: all 29 flagged, all F5-01. No SDF operator name appears in OPERATORS.md.

No new output-demand miss in this batch beyond F4x-02.

### Phase 5d — COMP (27), NET (15), MAT (12)

**PARTIAL.** COMP: 18 flagged. NET: 9 flagged, all F5-01 (the host bridge). MAT: 4 flagged, all F5-01. NET help patches are the whole of B-2's empty family.

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F5d-01 | **Nine COMP operators call `GNGeoRenderer` from `operators/`:** Animation, Camera, Geometry, Instance, Light, Merge, RigidBody, SoftBody, StaticBody. Rule 25.41 forbids a typed `ui/` class from operators. These are calls (`_ensure_viewer_scene`, `_viewer_mesh_instance`), so the script does not parse unless that UI class is loaded. DAT mentions of `GNTableRenderer` are comments only and are not this finding | `animation_comp.gd:222`, `geometry_comp.gd:104`, `camera_comp.gd:109`, and the same block in the other six | Medium |

`BoneCOMP` is missing from OPERATORS.md (F5-01) and does not call `GNGeoRenderer`.

### Phase 5e — POP (12), VOL (12), OUT (12), FIX (8), SCRIPT (3)

**PARTIAL.** OUT: 0 mechanical flags (`PixelDmxOUT` help is already B-2). FIX: 0 mechanical flags (6 of 8 help patches are already B-2). POP: only `SwitchPOP` (F5-01). VOL: `SwitchVOL` (F5-01) plus `FluidVOL` / `PyroVOL` (F4x-03). SCRIPT: `GDScriptSCRIPT` is documented; `PythonSCRIPT` and `NativeSCRIPT` are not.

Deprecated TOPs that are still registered, with a named replacement: `HighPassTOP` → `FilterTOP`, `ReorderTOP` → `ChannelMixTOP`, `ResolutionTOP` → `FitTOP` (`high_pass_top.gd:9-11`, `reorder_top.gd:16-18`, `resolution_top.gd:10-12`).

Point 10 for this batch does not add a transmitter. `SinkOUT` remains a non-transmitter, as in 4k.

---

## Phase 6 — Doc audit

**PARTIAL.** Structural pass (M2 + M3): family headings, stale totals, class-name coverage, extension README vs `gn_extension.cfg` (Rule 25.43), and relative links in root docs, `dev_docs/*.md`, `docs/OPERATORS.md`, `addons/gonodes/help/*.md`, extension READMEs, and `libgonodes/**/README.md`. Sentence-by-sentence reading of all 27 dev docs was not done. `dev_docs/` has **27** markdown files, not the 30 the plan assumed. Help pages: **16**, matching the plan. Extension READMEs: **25**.

| ID | Finding | Evidence | Severity |
|----|---------|----------|----------|
| F6-01 | **Per-family totals in `docs/OPERATORS.md` contradict its own header.** Header line 3 matches the registry (585 and the 15 family counts). Body totals: TOP 72 (line 47), IMG 15 (2201), CHOP 67 (2263), DAT 34 (3582), SOP 64 (4192), COMP 12 (5454), MAT 8 (5874). Quick reference line 6719 says core 394 and "total reaches 578" | those lines | High — this is B-14 |
| F6-02 | **No `## SDF`, `## NET`, or `## SCRIPT` heading.** Line 6740 says SDF was promoted to core (26 operators) and tells the reader to see the SDF section above. Registry SDF count is 29. SCRIPT exists only as a subsection under COMP (`GDScriptSCRIPT` at line 5766) | headings search; line 6740 | High — B-14 |
| F6-03 | **`README.md:169` still says "1,547 example patches — 3+ per operator".** Phase 1 measured 2,064 patches, 108 operators under 3, 26 at zero. The audit did not edit the README | `README.md:169`, F1-01, F1-02 | Medium — already recorded, still unfixed |
| F6-04 | **`dev_docs/README.md` links `OPERATORS.md` in the same folder.** That file is not there; the reference is `docs/OPERATORS.md`. The same index describes `TESTING.md` as "1,355 automated tests across 31 files covering all 13 families". Phase 3 counted 2,048 tests; there are 15 families | `dev_docs/README.md` file index | Medium |
| F6-05 | **User help points at the wrong build doc.** `addons/gonodes/help/building.md` links `../../dev_docs/BUILD.md`, which resolves under `addons/`. The file is `dev_docs/BUILD.md` at the repo root (`../../../dev_docs/BUILD.md`) | link check | Medium |
| F6-06 | **Three extension READMEs call IMG operators TOPs.** `gn_ext_ml` lists DepthEstimateTOP, StyleTransferTOP, SegmentationTOP; the cfg classes are `*IMG`. `gn_ext_blackmagic` lists BlackmagicInTOP / BlackmagicOutTOP; cfg has `BlackmagicInIMG` / `BlackmagicOutIMG`. `gn_ext_depth_sensor` lists DepthSensorTOP; cfg has `DepthSensorIMG`. Rule 25.43 (names must match the cfg) and 25.44 (readback belongs in IMG) | those READMEs vs `gn_extension.cfg` | Medium |
| F6-07 | **`gn_ext_native/README.md` says 93 native operators across 6 families.** The cfg and the wrapper scripts both contain 131. The README does not list class names, so it fails 25.43 on names and on the count | README lines 7-18; cfg `[operator.` count 131 | Medium |
| F6-08 | **User-script READMEs still describe operators that do not exist.** `gn_ext_user_python` tells you the wrapper is UserPythonSOP/CHOP/IMG/TOP/DAT. `gn_ext_user_native` says to add a UserNativeSOP. The registered classes are `PythonSCRIPT` and `NativeSCRIPT`. Those old names are the same ones B-3 found inside help patches | both READMEs; B-3 | Medium |
| F6-09 | **19 of 25 extension READMEs name every class in their cfg.** The six that do not are native, blackmagic, depth, ml, user_python, and user_native (F6-06..F6-08) | `_pbaudit_score.py` | Informational |

Two "dead links" were discarded as false positives: `GONODES_CONTEXT.md` uses the literal target `url`, and `dev_docs/BUILD.md` has a markdown link whose target is the C signature `int a, int b`.

---

## Phase 7 — Verdict

**Written.** This is a judgment on the evidence above. It is not a claim that every operator was cooked and watched.

I would not ship a public beta that repeats the README's promises. Two bugs return the wrong result with no error (shared images mutate, index patterns select the wrong channels), and the test suite reports green while that class of failure is invisible. Help examples and `docs/OPERATORS.md` do not cover the catalog the header advertises. A private build with the ships-without list printed on the download page is a different decision; the list is below.

### Readiness

| Area | Score | Why |
|------|-------|-----|
| Cook scheduling | 3/5 | Sequential cook matches the doc. Hash-guard skip is dead code (F4a-02). Parallel cook was not run |
| Data ownership | 1/5 | B-12. Fan-out through a Null can mutate the upstream image |
| Pattern language | 1/5 | B-13. Documented take-skip and exclude-only are silently wrong |
| Test suite as a gate | 1/5 | B-8. Exit 0 with failing asserts, and a parse error counts as an empty pass |
| Help examples | 1/5 | B-1, B-2, B-5. VOL examples do not load; 26 operators have none |
| Operator reference | 2/5 | B-14. Header is current; body totals and three families are not |
| Scripting | 2/5 | Cook errors are swallowed (F4h). User Python does not load after the documented build (B-6) |
| Native extensions | 2/5 | Windows rebuild produced the DLLs. OpenCV and Ultraleap do not load (B-10, F3-04). `check_builds.py` cannot see that (B-11) |
| Audio / MIDI / OSC / DMX | 2/5 | Real sinks exist (F4x-04). `AudioSourceCOMP` and `AudioRenderCHOP` are not sinks. Nothing was heard. No live peer |
| GPU fallback | 3/5 | The POP "zero particles" result was a bad test (F4i-01). VOL readback size is still open (B-9) |
| Per-operator structure | 4/5 | 397/585 clean on the mechanical rubric. No stub cooks. The misses are docs, nine UI-coupled COMPs, and the readback/sink rows in 5a–5b |
| Editor UX | 3/5 | Palette, align, expressions, viewer dispatch, and timeline layers are in the code. Feel is UNVERIFIED (4n, 15 blank rows) |
| Docs other than OPERATORS.md | 2/5 | F6-03..F6-08. Counts and operator names in READMEs lag the code |

### Fix first

1. **B-12** — stamp `_shared` on the producer once; do not let a passthrough restamp it. `gn_cook_engine.gd` around the consumer-count write after cook.
2. **B-13** — `parse_index_range` in `gn_pattern.gd`. Take-skip must survive the comma split. Exclude-only must mean "all except".
3. **B-8** — `tests/test_runner.gd` must count bare `assert()` failures and a script that fails to parse. Until it does, a green CI run is not evidence.
4. **B-6 and B-10** — copy `python310.dll` and `opencv_world4100.dll` next to the extension, or stop advertising those operators. **B-11** is what let both ship as a passing build.
5. **F4h** — `_safe_call` in `gn_script_helper.gd` must surface a cook error on the node. GDScriptSCRIPT must copy `compile_error` onto `node_warning` the way PythonSCRIPT already does.
6. **B-1, B-2** — VOL help patches wire a SOP into a VOL input. NET and six FIX operators have no example at all.
7. **B-14** — regenerate `docs/OPERATORS.md` from the registry, including SDF, NET, and SCRIPT, and delete the stale "Total:" lines.
8. **F4k-01, F5a-01, F5b-01** — `AudioSourceCOMP`, `AudioRenderCHOP`, and `ArtnetDAT` do their real work only when something else cooks them.
9. **F5d-01** — COMP viewer code should not call `GNGeoRenderer` from `operators/`.

### Beta ships without

Say these out loud if a build goes out before they are fixed. Do not describe them as working.

- macOS and Linux native builds (Phase 2 was Windows only)
- Audible audio, a live OSC peer, a MIDI port, and Art-Net (4n rows 7–12 and 15 are blank)
- Editor feel: palette, shake-to-disconnect, mapper panels, scrubber (4n rows 1–6, 13–14)
- OpenCV (20 operators) and Ultraleap until their runtime DLLs load
- User Python and user-native C++ under the names in those READMEs (`UserPython*`, `UserNative*`). The classes that exist are `PythonSCRIPT` and `NativeSCRIPT`, and Python does not load (B-6)
- VOL `?` examples, and any operator in the B-2 zero-patch list
- Index patterns `n-m:take,period` and `!5-10` (B-13)
- Fan-out safety when a Null or a MIDI/DMX sink sits on one branch (B-12, F4x-05, F4l-02)
- The SDF, host-bridge, and most IMG chapters of `docs/OPERATORS.md` (B-14)
- Parallel cook and the hash-guard skip (the skip cannot run; parallel was not measured)
- `AudioSourceCOMP` playing on its own, and `AudioRenderCHOP` bouncing with nothing connected

### What held up

The registry header count of 585 matches `scan_operators.py`. OSC int/float/string and bundles round-trip in memory. Mapper assets load. Transmitters for speakers, OSC, MIDI, and DMX exist and are sinks, with Active gating on the send itself. No operator's `_cook` is an empty stub. Output demand for secondary ports matches the earlier inventory: the only ungated cases are UI state CHOPs and Fluid/Pyro fields.

---

## Fix list

Every finding from this audit, with the fix to make. Status is as of the B-8 / B-12 / B-13 pass. "Same as" means do not fix it twice.

### Already fixed

| ID | Finding | Recommended fix |
|----|---------|-----------------|
| B-8, F3-01 | Runner hid bare `assert()` and a script that failed to parse | **Done.** `tests/test_runner.gd` fails the test on a script error and fails the suite if `func test_` never registers. Follow-up: run the full suite, fix the asserts that now fail honestly |
| B-12, F4b-01, F4b-02, F4b-03 | Viewer was not a consumer, and a passthrough cleared `_shared` on the producer's buffer | **Done.** Count the viewed node. `_stamp_owned_output` does not write `_shared` onto an input object. `DATA_TYPES.md` updated. `test_cow_` 10/10 |
| B-13, F4e-02, F4e-03 | `0-19:2,5` and `!5-10` selected the wrong indices | **Done.** `:take,period` stays one clause. Exclude-only starts from every index. `test_pat_` 8/8 |
| F4e-01 | `PATTERNS.md` said `*_z` matches `tz` | **Done.** The row now says `scale_z` only. `_` is literal |

### Cook, data, patterns

| ID | Finding | Recommended fix |
|----|---------|-----------------|
| F4a-01 | Cook flowchart order is stale | **Fixed.** `COOK_ENGINE.md` §1–§2 now matches `cook_frame`: topo, then active set, then pre-cook, with the reason active set runs first |
| F4a-02 | Input-hash skip cannot run | **Fixed.** Left scheduling alone. Commented the dead `not node.dirty` arm in `_cook_single_node` and `_cook_cpu_batch_parallel`. `COOK_ENGINE.md` §2, §3.3, and Example 4, plus the ROADMAP row, now say the skip is not taken; a static chain is skipped by the dirty flag |
| F4a-03 | Cook budget applies only to the sequential path | **Fixed.** Documented only. `COOK_ENGINE.md` §1 now says `max_cooks_per_frame` (default 0) is enforced on the sequential path and ignored by the parallel branch |
| F4a-04 | Parallel cook count includes nodes the hash skip continued past | **Fixed.** `_cook_cpu_batch_parallel` now returns how many nodes were prepared and cooked. The caller adds that, not `cpu_batch.size()`. The unreachable hash `continue` is excluded |
| F4a-05 | No tests for Switch pruning, 1-frame hold, demand culling, parallel cook, subnet engines, or cycle rejection | **Fixed.** `tests/unit/test_cook_behaviours.gd` — six tests, all passing: pruning, expression one-frame hold, demand stamp, parallel batch, subnet inner `cook_frame`, and `connect_nodes` cycle rejection |
| F4a-06 | NRT delta snippet omits `playback_speed` | **Fixed.** `COOK_ENGINE.md` §7 snippet is now `(1.0 / non_realtime_fps) * playback_speed`, matching `gn_cook_engine.gd:253` |
| F4a-07 | Demand-culling list stops at 15 operators | **Fixed.** §4.1 guard list now includes GLSLMultiTOP fallback, SubNetworkNode OutTunnel `is_sink`, and `GNTopInteractiveBase` panel ports. The "15 operators" census (nodes with 2+ ports) was left as-is |
| F4a-08 | Doc says `SubNetworkCOMP` | **Fixed.** `COOK_ENGINE.md` §8 now says `SubNetworkNode`, which matches `sub_network_node.gd` |
| F4a-09 | User help says dirtiness floods the whole chain, and lists RenderTOP as a sink | **Fixed.** `help/cook_engine.md` now says only immediate successors are dirtied, and the sink example is WindowOUT. RenderTOP does not set `is_sink` |
| F4b-04 | Only BlurIMG and PixelSortIMG call `_mutable_input` | **Fixed.** In-place POP processors now duplicate a shared buffer before writing: Force, Attract, Advect, Boids, Collision, Limit, Turbulence (GPU and CPU). SourcePOP was left alone; it writes its own particle buffer and only reads the SOP input |
| F4b-05 | Context §21 still calls POP future and says `GNImgData` | **Fixed.** §21 table now has IMG, POP (`GNParticleData`), VOL, UI, and SDF. `DATA_TYPES.md` §6 sample uses `GNImageData` |
| F4x-01 | FixtureSamplerTOP samples LEDs even when the CHOP port is idle | **Fixed.** The GPU sample pass in `fixture_sampler_top.gd` now runs only when `is_output_demanded(1)`. The `_total_leds > 0` term is gone. Port 0 still passes the texture through |
| F4x-02 | Every UI widget rebuilds its CHOP every cook | **Fixed.** `GNUiBase.execute_cook` calls `_build_state_chop()` only when the last output (the state CHOP) is demanded. The UI port still builds every cook |
| F4x-03 | FluidVOL and PyroVOL secondary fields are ungated | **Fixed.** No gate. Both solvers keep those fields as coupled state. `docs/OPERATORS.md` now says FluidVOL always writes velocity, and PyroVOL always writes temperature and velocity |
| F4x-04 | Audio, OSC, MIDI, and DMX sinks exist | No change |
| F4x-05, F4l-02 | MIDI out and DMX out return the input CHOP | **Fixed.** No return-path change. `test_cow_dmx_fanout_preserves_shared` cooks a ConstantCHOP into a Null and a DmxOutCHOP (Active off) and asserts the producer's `_shared` flag survives |
| F4x-06 | AudioDeviceOUT and OscOUT stay sinks while Active is off | **Fixed.** No behavior change. `docs/OPERATORS.md` now says Active gates the send and both nodes stay sinks, so upstream still cooks while Active is off |

### Editor, parameters, viewer, timeline

| ID | Finding | Recommended fix |
|----|---------|-----------------|
| F4c-01 | `EDITOR.md` says H=help, V=viewer, Tab=palette | **Fixed.** `EDITOR.md` Keyboard Shortcuts now follows `gn_graph_editor.gd::_handle_key_input`: H/V align, palette is Alt+A. `help/editor.md` was already right |
| F4c-02 | Toolbar doc is two rows and "four" overlays | **Fixed.** `EDITOR.md` toolbar section now describes three scroll rows and the five overlays `#Order`, Dim, Dirty, Sinks, Flow |
| F4c-03 | Shake doc types the direction as int and resets the timer on every reversal | **Fixed.** `EDITOR.md` now types `_shake_last_dir` as `Vector2` and says the timer clears only on the first reversal |
| F4d-01 | Takes skip spare parameters | **Fixed.** `capture_base`, `capture_take`, and `_apply_snapshot` include `spare_parameters` (built-in name wins on collision). `test_take_apply_revert_and_file` expects the spare override and checks revert/apply |
| F4d-02 | Docs call `GNTakeManager.new(network)` | **Fixed.** `GNTakeManager._init` takes an optional `GNNetwork`. `new()` and `new(network)` both work. The take round-trip test still passes |
| F4d-03 | Preset docstring names two user directories | **Fixed.** Removed the `user://gonodes_param_presets/` sentence. The docstring now matches `GNPresetPaths`: `user://gonodes/presets/params/` |
| F4f-01 | Viewer and WindowOUT were not opened | **Left unverified.** This row is a human visual run (`tests/visual_audit/`, especially `04_mapper_dual_panel.gnpatch`). No code change |
| F4g-01 | Cues and the scrubber were not run | **Left unverified.** This row is a human transport/cue walkthrough (rows 3 and 6). No code change |

### Scripting, GPU, files, audio, protocols, export

| ID | Finding | Recommended fix |
|----|---------|-----------------|
| F4h-01 | `_safe_call` treats a `cook()` script error as success | **Fixed.** `_safe_call` watches the call with a logger. A script error sets `node_warning` and makes `run_cook` return false. A clean call clears that warning |
| F4h-02 | GDScript compile errors never reach the badge | **Fixed.** When GDScript does not compile, `GDScriptSCRIPT._cook` copies `compile_error` onto `node_warning`, with a short fallback if that string is empty |
| F4h-03 | Script-CHOP tests cook a bare `GNData` because nothing registered the family factory | **Fixed.** `test_script_chop.gd` calls `scan_extensions()` in `before_all`. The syntax-error test allows one expected parse error and asserts `node_warning` is set. Six tests pass |
| F4i-01 | SourcePOP "zero particles" was the test | **Fixed.** `test_source_pop_cpu_emits_particles` sets `current_delta` and `rate`, expects `particle_count > 0`, and expects the position pool to be `max_particles`. SourcePOP was not changed |
| B-9, F4i-02, F3-02 | VOL CPU readback size is still unverified | **Fixed.** The buffer was 64³ because the test set a parameter named `resolution`. NoiseVOL uses `res_x` / `res_y` / `res_z`. The test now sets those to 16, and `cpu_data.size()` is 4096. The readback was not changed |
| F4j-01 | URL download never starts when the node is outside the tree | **Fixed.** If the caller is off the tree, `HTTPRequest` is parented to the scene-tree root before `request()`. `test_start_fetch_off_tree_caller_uses_scene_root` expects status pending, not `ERR_UNCONFIGURED`. A full public download was not run |
| F4k-01 | `AudioSourceCOMP` never cooks alone | **Fixed.** `_init` sets `is_sink` true (Playing defaults on). `parameter_changed` updates it when `playing` changes, before the next active-set rebuild. `_pre_cook` alone cannot start a node that is not already active |
| F4k-02 | Speakers were not heard | **Left unverified.** Walkthrough row 7. No code change until that fails |
| F4l-01 | OSC int/float/string and bundles round-trip | No change. Keep `test_osc_roundtrip.gd` |
| F4l-03 | No live OSC, MIDI, or Art-Net peer | **Left unverified.** Walkthrough rows 10–12 |
| F4m-01 | Player and the eight libgonodes hosts were not launched | **Left unverified.** Walkthrough row 15. No code change |
| F4m-02 | User Python skipped at scan | Same as B-6. Not fixed in this table |
| F5a-01 | `AudioRenderCHOP` only bounces while something else cooks it | **Fixed.** `is_sink` follows `record` or `export_now` (both default off), set in `_init` and updated from `parameter_changed` so the next active set sees it |
| F5a-02 | `RaymarchTOP` readbacks the compute texture every cook | **Fixed.** `_cook` returns `GNTextureData` wrapping the compute RID in a `Texture2DRD`. `texture_get_data` is gone from that path. The CPU fallback still builds an image when there is no GPU |
| F5a-03 | NDI, Spout, Syphon, and MovieFileOut read pixels back to send | No change. They are outputs |
| F5a-04 | `scan_operators.py` misses `create_*` whose name is not a string literal | **Fixed.** BezierMapTOP's 32 control-point floats are string literals. `scan_operators.py` now records them (539/585 operators with params). Cook still reads the same `_CP_NAMES` |
| F5a-05 | Mapper panel ports are demand-gated | No change |
| F5b-01 | `ArtnetDAT` polls only while cooked | **Fixed.** `is_sink` follows `active` (default off), set in `_init` and updated from `parameter_changed`, so a lone node cooks while Active is on |
| F5b-02 | `DMXDAT` and `SerialDAT` are deprecated and unregistered | **Fixed.** Left unregistered. `DMXDAT` now points at `DmxOutCHOP`. `SerialDAT` already pointed at `SerialSendDAT` and `SerialReceiveDAT` |
| F5b-03 | `ObjectMergeSOP` is deprecated and missing from the operator reference | **Fixed.** Kept `deprecated=true`. Docstring and OPERATORS.md point remote fetch at SelectSOP and filtering at FilterSOP. `apply_transform` has no replacement; the class stays so old patches load |
| F5b-04 | FilterSOP TODO is a comment, and it has no help patch | **Deferred to B-2.** Help patches stay in the next table. The native-expression TODO stays until that mode is built |
| F5d-01 | Nine COMPs call `GNGeoRenderer` from `operators/` | **Fixed.** Those nine `render_for_viewer` overrides call `GNViewerRenderHelpers`. `GNGeoRenderer` registers itself in `_static_init`. Operators and core no longer name that UI class. `test_geo_viewer_hook.gd` restores the live provider after each test |

### Help patches and operator reference

| ID | Finding | Recommended fix |
|----|---------|-----------------|
| B-1, F1-04 | VOL examples wire a SOP into a VOL input | **Fixed.** VOL inputs that were fed by `GridSOP` now use `NoiseVOL`. `SOPtoVOL` still takes SOP. Analyze patches no longer wire the CHOP output into `RaymarchTOP`; the same `NoiseVOL` feeds the raymarcher. The generator template uses `RaymarchTOP` (there is no `RaymarchVOL`) |
| B-2, F1-01 | 26 operators have no help patch, including all of NET | **Fixed.** One patch each for the 15 NET operators, the six FIX operators that had none, FeedbackCOMP, and PixelDmxOUT. FilterSOP already had patches after F1-07. DMXDAT and SerialDAT stay without patches |
| B-3, F1-05 | Patches name operators that do not exist | **Fixed.** Help patches now use `LFO_CHOP`, `DepthSensorIMG`, `SourcePOP`, `PythonSCRIPT`, and `NativeSCRIPT`. `ScriptCHOP` and `GDScriptSCRIPT (IMG template)` are `GDScriptSCRIPT`. `GDScriptSCRIPT` itself was already a real class and was not renamed |
| B-5 | 108 operators have fewer than 3 patches | **No change.** The generator writes the boilerplate F1-06 is removing, and it has no NET or FIX templates. Do not add filler patches to hit 3. The false "3+" claim is F1-02 |
| F1-02, F0-09, F6-03 | README says 1,547 patches and 3+ each | **Fixed.** README now says 2,085 example patches, counted from `addons/**/help`. The "3+" claim is gone |
| F1-03 | 147 patches fail validation | **Fixed for real defects.** Type mismatches 51→9, flat params 17→0, unknown types 1→0. The 9 left are DotNode, SnapshotTOP mode, and SinkOUT, which accept another family at runtime. Orphans (62) and missing WindowOUT (32) stay; the audit called those mostly false positives. The CI gate is B-4, not this row |
| F1-06 | 148 patches use boilerplate annotations | **Fixed.** 79 exact boilerplate bodies and 57 more that added a "Requires extension" line were replaced. 12 patches that had no annotation got one. Those three phrases are gone under `addons/**/help`. Pixel-mapper and SDF notes that already said something specific were left |
| F1-07 | Help generator keys patches by `node_type` alone, so FilterSOP landed in `help/top` | **Fixed.** `all_existing` is keyed by `(family, node_type)`. The three FilterSOP patches moved from `help/top` to `help/sop`. Duplicate SelectSOP files were removed from `help/vol`; `select_vol_basic.gnpatch` moved to `help/sop` |
| B-14, F5-01, F6-01, F6-02 | `OPERATORS.md` header says 585; 127 classes and the SDF, NET, and SCRIPT chapters are missing; section totals are the old catalog | **Fixed for the false counts and the missing headings.** Section totals and the quick-reference counts match the registry (585). SDF, NET, and SCRIPT sections are one line per class. Existing writeups were not replaced. The name lists in the quick reference are still the old catalog |
| F6-04 | `dev_docs/README.md` links a missing `OPERATORS.md` and quotes 1,355 tests / 13 families | **Fixed.** The link is `../docs/OPERATORS.md`. The index now says 2,082 `func test_` definitions across 81 files and 15 families |
| F6-05 | `help/building.md` points at `addons/dev_docs` | **Fixed.** The link is `../../../dev_docs/BUILD.md` |
| F6-06 | ML, Blackmagic, and depth READMEs call IMG operators TOPs | **Fixed.** Those READMEs now use `DepthEstimateIMG`, `StyleTransferIMG`, `SegmentationIMG`, `BlackmagicInIMG`, `BlackmagicOutIMG`, and `DepthSensorIMG` |
| F6-07 | Native README says 93 operators and does not list them | **Fixed.** The README lists all 131 cfg classes. Family counts are SOP 62, CHOP 44, POP 8, VOL 8, IMG 5, TOP 4 |
| F6-08, F6-09 | User Python and user-native READMEs tell you to add UserPythonSOP / UserNativeSOP | **Fixed.** Those READMEs now say to add `PythonSCRIPT` and `NativeSCRIPT`. The template dropdown picks the family. The old per-family class names are gone |

### Build, tests, and public counts

| ID | Finding | Recommended fix |
|----|---------|-----------------|
| B-6, F2-05, F4m-02 | `setup_python.py` copies `python312.dll` while the toolchain is 3.10.11 | **Fixed.** Windows setup copies `python3.dll` and `python310.dll` into `bin/win64/`, which is what `gn_python.gdextension` loads. `--verify` checks those files. `libgn_python.windows.template_release.x86_64.dll` is still not on disk, so the player export still skips the extension until that library is built |
| B-7, F2-06 | README Windows path never runs Python setup or the native toolchain bundle | **Fixed.** The Windows quick path runs `setup_python.py` and `scripts/bundle_toolchain.py` before `check_builds.py` |
| B-10, F3-03 | OpenCV loads without `opencv_world4100.dll` | **Fixed in the build.** The unified `build/SConstruct` now calls `copy_runtime_dlls()`, which the per-extension shim already did. A Windows OpenCV build copies `opencv_world4100.dll` into `native/bin/win64/`. This tree was not rebuilt, so the DLL is not on disk yet |
| B-11, F3-05 | `check_builds.py` treats a file on disk as a working extension | **Fixed.** After the on-disk checks it runs headless Godot and fails if an enabled `.gdextension` does not load. A run here exited 1 on `gn_ext_depth_sensor` (Ultraleap). OpenCV loaded. Disabled files are not failures |
| F2-01 | `build_windows.ps1` dies when `ProgramFiles(x86)` is unset | **Fixed.** If that variable is empty, the script sets it to `C:\Program Files (x86)` before the vswhere path |
| F2-02, F2-07 | `clean_builds.py` crashes on a `~`-locked DLL and leaves extensions half-disabled | **Fixed.** Names starting with `~` are skipped. A `PermissionError` on any other file skips deactivating that extension instead of aborting halfway |
| F2-03 | SCons warns that `tier=all` is ignored | **Fixed.** `build/SConstruct` drops `tier`, `ext`, and `exts` from `ARGUMENTS` after reading them and before it loads godot-cpp. Declaring the variable on the parent would not have silenced that child warning |
| F2-04 | `--all` on Windows fails for Linux and macOS binaries that cannot exist here | **Fixed.** `check_builds.py` and `bundle_toolchain.py` report foreign-platform gaps as not buildable on this host. Those gaps do not change the exit code. A missing host binary still fails |
| F3-04 | Ultraleap `.gdextension` and `.gdextension.disabled` are both present, and `LeapC.dll` is absent | **Fixed.** Only `gn_depth_ultraleap.gdextension.disabled` remains, so Godot does not load it. Sync turns it back on only when `LeapC.dll` / `libLeapC.so` is next to the built library or on the library search path. A duplicate pair is collapsed to one file |
| F3-06, B-4, F1-10 | CI runs the unit runner only. Patch validation and the audit scripts are not gated | **No change.** `validate_all_patches.py` still fails 84 patches. Gating it, or `check_coverage.py`, in CI would fail the build. The unit runner stays the CI gate |
| F3-07 | Test exit leaks hundreds of thousands of objects and hides the summary | **No change.** This is suite teardown. Do not free objects across the suite, and do not treat the leak count as an engine bug, until one test reproduces it |
| F1-08 | Scanner records no params for 47 operators | **Dropped.** A re-run records 585 operators, 46 with no parameters, and none of those 46 contain a `create_*` call. The extra miss was BezierMapTOP, already fixed as F5a-04 |
| F1-09 | Port registry has 717 entries because it includes 131 native variants | **No change.** That registry includes the 131 native variants. It is a different list from the 585 GDScript operators |
| F0-01, F0-07 | README diagram and `GONODES_CONTEXT.md` still say Godot 4.6 | **Fixed.** The README diagram and the current-version lines in `GONODES_CONTEXT.md` say 4.7.2. The README "4.6+" minimum and historical notes were left |
| F0-02 | README diagram says 402 operators | **Fixed.** The diagram says `Operator Library (585)`. That total already includes extensions |
| F0-03 | README says 1,376 tests and 13 families | **Fixed.** That sentence now says 2,082 automated tests, 81 test files, and 15 families |
| F0-04 | README says five libgonodes examples | **Fixed.** The LibGONODES section names eight example apps, including `geometry_host`, `midi_osc_host`, and `graph_edit_demo` |
| F0-05 | Mapper count is 5 in one README line and 7 in the cfg | **Fixed.** The `gn_ext_mapper` row says 7 and names the same seven operators as the earlier Mapper row |
| F0-06 | One README line says SDF has 40+ operators | **Fixed.** That sentence says 29 operators |
| F0-08 | Context decision table still shows `.tres` patches as current | **Fixed.** That row is labelled historical and says it was superseded by JSON `.gnpatch` |
| F0-10 | Roadmap says it was verified in June 2025 | **Fixed.** The roadmap no longer says the list is verified. It says the list was last checked in June 2025 and has not been re-checked since |

### Not a code fix until someone runs them

| ID | What is unverified | What to do |
|----|--------------------|------------|
| 4n | All 15 walkthrough rows | Fill the Actual column in the Phase 4n table. Code changes wait on a failed row |
| F4k-02, F4l-03, F4m-01 | Hearing audio, a live peer, the player | Those are rows 7–12 and 15 of that walkthrough |

---

## Progress

| Stage | Area | Status |
|-------|------|--------|
| 0 | Intent baseline | **DONE** |
| 1 | Automated ground truth | **DONE** |
| 2 | Clean rebuild (Windows x64) | **DONE** — clean rebuild PASS (Windows); macOS/Linux UNVERIFIED |
| 3 | Test + patch validation | **PARTIAL** — 2,048 tests pass, but the runner hides 8 real failures (B-8); 2 extensions unloadable (B-10, F3-04) |
| 4a | Cook flow & scheduling | **DONE** — M1+M2+M4; hash-guard skip unreachable (F4a-02); five behaviours UNVERIFIED |
| 4b | Data types, ownership & family bases | **PARTIAL** — B-12; 6/10 new tests pass, 4 contract failures left failing |
| 4c | Editor UX | **PARTIAL** — implementation present (M1+M2); feel UNVERIFIED; F4c-01..03 doc drift |
| 4d | Parameters, inspector, expressions | **PARTIAL** — expressions and take file round-trip tested; spare params omitted from takes; feel UNVERIFIED |
| 4e | Pattern matching language | **FAIL** — B-13; 4/8 new tests pass, 4 left failing on purpose |
| 4f | Viewer, UI family, windows | **PARTIAL** — two-tier dispatch and WindowOUT present; visual packs not opened |
| 4g | Timeline, cues, debugging, logging | **PARTIAL** — layers and debug UI present; transport/cues not executed |
| 4h | Scripting API | **FAIL** — 6/7 `test_script_` fail; runtime cook errors are ignored |
| 4i | GPU architecture & graceful degradation | **PARTIAL** — F4i-01 isolates the POP failure; VOL size still open |
| 4j | Resource loading & URL cache | **PARTIAL** — 30 cache tests pass; live download not run (F4j-01) |
| 4k | Audio subsystem | **PARTIAL** — device list and sinks present; AudioSourceCOMP is not a sink; unheard |
| 4l | Protocol interop | **PARTIAL** — OSC round-trip passed; DMX returns the input CHOP; no live peer |
| 4m | Subnets, assets, export, embedding, extensions | **PARTIAL** — registry scan + asset/tunnel tests passed; player and libgonodes not launched |
| 4n | Hands-on UX walkthrough | **UNVERIFIED** — 15-row script written, none executed |
| 5a | Per-operator — TOP, CHOP | **PARTIAL** — 121/138 TOP and 88/107 CHOP mechanically clean; F5a-01..04; behavior match UNVERIFIED |
| 5b | Per-operator — SOP, DAT | **PARTIAL** — SOP nearly clean; 22 DATs absent from OPERATORS.md; ArtnetDAT is not a sink |
| 5c | Per-operator — IMG, UI, SDF | **PARTIAL** — SDF 29/29 and IMG 24/41 undocumented; UI demand gap is F4x-02 |
| 5d | Per-operator — COMP, NET, MAT | **PARTIAL** — F5d-01 nine COMPs call GNGeoRenderer; NET help is B-2; host ops undocumented |
| 5e | Per-operator — POP, VOL, OUT, FIX, SCRIPT | **PARTIAL** — OUT and FIX mechanically clean; PythonSCRIPT and NativeSCRIPT undocumented |
| 6 | Doc audit | **PARTIAL** — structural pass done; 27 dev_docs not read line by line; B-14, F6-03..F6-08 |
| 7 | Verdict | **DONE** — not a public beta; ships-without list is in Phase 7 |
