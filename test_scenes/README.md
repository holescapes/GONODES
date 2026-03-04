# GONODES Manual Test Scenes

These `.gnpatch` files are pre-built networks for visual / interactive testing
inside the GONODES editor. Open each file through **File → Open** and verify the
checklist items below.

---

## 01 — CHOP Chain Basics
**File:** `01_chop_chain_basics.gnpatch`

| # | What to check | Pass? |
|---|---------------|-------|
| 1 | LFO → Math(×) → Math(+) → Null chain cooks without errors | ☐ |
| 2 | Null viewer shows animated signal oscillating between 100 ± 5 | ☐ |
| 3 | NoiseTOP resolution is driven by `chop("null1")["chan1"]` expression | ☐ |
| 4 | TextTOP text updates via `pars("value")` expression from Constant | ☐ |
| 5 | Changing LFO `frequency` parameter live updates the downstream chain | ☐ |

---

## 02 — ScriptCHOP
**File:** `02_script_chop.gnpatch`

| # | What to check | Pass? |
|---|---------------|-------|
| 1 | Generator ScriptCHOP produces 3 channels (`wave_0..2`) | ☐ |
| 2 | `@param speed`, `@param channels`, `@param spread` appear in the UI | ☐ |
| 3 | Changing `speed` live affects oscillation rate | ☐ |
| 4 | Filter ScriptCHOP outputs `abs_wave_0..2` (absolute values) | ☐ |
| 5 | Filter reads upstream input correctly (no error in log) | ☐ |

---

## 03 — Custom Shader TOP
**File:** `03_custom_shader_top.gnpatch`

| # | What to check | Pass? |
|---|---------------|-------|
| 1 | Generator shader (`shader_gen`) renders animated sine bars | ☐ |
| 2 | `speed`, `scale`, `color_r/g/b` uniforms appear as parameters | ☐ |
| 3 | Filter shader (`shader_filter`) distorts its input texture | ☐ |
| 4 | Multi-input shader (`shader_blend`) blends two TOP inputs | ☐ |
| 5 | `gn_tex0` / `gn_tex1` auto-create two input ports on blend node | ☐ |
| 6 | Adjusting `mix` parameter live blends between the two sources | ☐ |

---

## 04 — Expression Animation
**File:** `04_expression_animation.gnpatch`

| # | What to check | Pass? |
|---|---------------|-------|
| 1 | CircleTOP center moves in a smooth Lissajous pattern | ☐ |
| 2 | LFO CHOPs animate `center_x` and `center_y` via `chop()` expressions | ☐ |
| 3 | RampTOP provides a radial gradient background | ☐ |
| 4 | CompositeTOP composites Circle over Ramp without errors | ☐ |
| 5 | TextTOP label renders "Lissajous" overlay text | ☐ |

---

## 05 — TOP Compositing Chain
**File:** `05_top_compositing_chain.gnpatch`

| # | What to check | Pass? |
|---|---------------|-------|
| 1 | Two NoiseTOPs render different noise patterns | ☐ |
| 2 | CompositeTOP (Add) blends both noises at 50 % opacity | ☐ |
| 3 | HSVAdjustTOP shifts hue / boosts saturation visibly | ☐ |
| 4 | EdgeTOP produces visible edge lines from noise input | ☐ |
| 5 | CompositeTOP (Screen) merges HSV result with edge result | ☐ |
| 6 | LevelTOP adjusts brightness / contrast of the final image | ☐ |
| 7 | NullTOP at the end shows the complete composited result | ☐ |

---

## 06 — Physics: Rigid Bodies
**File:** `06_physics_rigid_bodies.gnpatch`

| # | What to check | Pass? |
|---|---------------|-------|
| 1 | Red box (RigidBodyCOMP) and blue sphere fall under gravity | ☐ |
| 2 | Both objects bounce off the gray static ground plane | ☐ |
| 3 | PhysicsCHOP shows live tx/ty/tz, rx/ry/rz, vel_x/y/z, speed channels | ☐ |
| 4 | MergeCOMP collects rigid + ground into one scene group | ☐ |
| 5 | RenderTOP displays the full 3D physics scene correctly | ☐ |
| 6 | Adjusting `mass` or `bounce` on rigid bodies changes simulation behaviour | ☐ |

---

## 07 — Physics: Joints, Soft Body & Area
**File:** `07_physics_joints_soft_area.gnpatch`

| # | What to check | Pass? |
|---|---------------|-------|
| 1 | HingeJoint constrains the rigid box pendulum to the static anchor | ☐ |
| 2 | Pendulum swings within ±90° hinge limits | ☐ |
| 3 | SoftBodyCOMP grid deforms under gravity (cloth drape) | ☐ |
| 4 | AreaCOMP wind pushes objects sideways (visible on pendulum or cloth) | ☐ |
| 5 | Area debug visualization sphere is visible in the render | ☐ |
| 6 | All objects land on or interact with the static ground plane | ☐ |

---

### How to run
1. Launch the GONODES editor scene (`scenes/gn_editor.tscn`).
2. **File → Open** and select a `.gnpatch` file from `test_scenes/`.
3. The network loads — verify nodes appear and connections are wired.
4. The network cooks automatically — verify each item below.
5. Mark ☐ → ☑ as you verify each item.
