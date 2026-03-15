# gn_ext_sdf — SDF Composition

> **Status**: Active — 26 operators, 1 renderer

Signed Distance Field composition system for GONODES. Build 3D scenes by composing SDF primitives with boolean operations and domain modifiers, assign materials, then render via raymarching to a TOP texture.

## Architecture

SDF operators do **not** create a new family. Instead:

1. **SDF operators** (family = TOP, section = "SDF") output `GNSDFData` — an AST tree that describes the scene
2. **RaymarchSDF** (a TOP) consumes the `GNSDFData`, compiles it into a single GLSL `canvas_item` fragment shader, and renders it via a SubViewport
3. The output is a standard `GNTextureData` — compatible with all downstream TOPs (Comp, Level, Blur, WindowOUT, etc.)

### AST Format

Each node in the SDF tree is a Dictionary:
```
{
  "op": "sphere",
  "params": { "position": Vector3(0,0,0), "radius": 1.0 },
  "children": [],
  "material": {}   # optional — set by MaterialSDF / GradientSDF
}
```

Tree hashing via `var_to_str()` triggers shader recompilation only when the tree structure changes. Per-node parameter values are passed as indexed uniforms (`u_pos_0`, `u_radius_0`, etc.) and updated every cook without recompilation.

## Operators

### Primitives (10)

| Operator | Class | Parameters |
|----------|-------|------------|
| Sphere SDF | `SphereSDF` | position, radius |
| Box SDF | `BoxSDF` | position, size |
| Torus SDF | `TorusSDF` | position, major_radius, minor_radius |
| Cylinder SDF | `CylinderSDF` | position, radius, height |
| Capsule SDF | `CapsuleSDF` | position, radius, height |
| Plane SDF | `PlaneSDF` | normal, offset |
| Cone SDF | `ConeSDF` | position, angle, height |
| Pyramid SDF | `PyramidSDF` | position, base, height |
| Octahedron SDF | `OctahedronSDF` | position, size |
| Gyroid SDF | `GyroidSDF` | position, scale, thickness |

### Booleans (5)

| Operator | Class | Inputs | Parameters |
|----------|-------|--------|------------|
| Union SDF | `UnionSDF` | 2 SDF | — |
| Intersection SDF | `IntersectionSDF` | 2 SDF | — |
| Subtract SDF | `SubtractSDF` | 2 SDF | — |
| Smooth Union SDF | `SmoothUnionSDF` | 2 SDF | smoothness |
| Smooth Subtract SDF | `SmoothSubtractSDF` | 2 SDF | smoothness |

### Domain Modifiers (8)

| Operator | Class | Parameters |
|----------|-------|------------|
| Repeat SDF | `RepeatSDF` | spacing, limit |
| Mirror SDF | `MirrorSDF` | mirror_x, mirror_y, mirror_z |
| Twist SDF | `TwistSDF` | amount, axis |
| Bend SDF | `BendSDF` | amount, axis |
| Elongate SDF | `ElongateSDF` | amount (vec3) |
| Round SDF | `RoundSDF` | radius |
| Onion SDF | `OnionSDF` | thickness, layers |
| Displace SDF | `DisplaceSDF` | amount, frequency, time_offset |

### Material (2)

| Operator | Class | Parameters |
|----------|-------|------------|
| Material SDF | `MaterialSDF` | albedo, roughness, metallic, emission |
| Gradient SDF | `GradientSDF` | color_near, color_far, range, roughness |

### Renderer (1)

| Operator | Class | Parameters |
|----------|-------|------------|
| Raymarch SDF | `RaymarchSDF` | resolution, max_steps, max_dist, epsilon, cam_distance, cam_angle_x, cam_angle_y, fov, bg_color, light_dir, ambient, show_ao, soft_shadows |

## GLSL Compilation Pipeline

1. **Uniform collection** — walks the AST, emits `uniform` declarations per node (indexed)
2. **Domain function generation** — for modifiers like Repeat/Twist/Bend, emits standalone GLSL helper functions that transform `p` before evaluating children
3. **Scene function** — recursive `_emit_sdf()` builds the `sdf_scene(vec3 p) -> vec2(dist, id)` expression tree
4. **Material function** — `get_material(vec3 p, float d)` returns albedo based on material annotations in the AST
5. **Raymarch + shading** — orbit camera, sphere-traced raymarching, normals via central differences, Blinn-Phong shading, AO (5-tap), soft shadows

## Directory Layout

```
addons/gn_ext_sdf/
  gn_extension.cfg       Extension manifest
  gn_sdf_data.gd         GNSDFData — AST carrier
  gn_sdf_base.gd         GNSdfBase — base class for SDF operators
  README.md              This file
  operators/
    top/
      sphere_sdf.gd      10 primitives
      box_sdf.gd
      ...
      union_sdf.gd        5 booleans
      ...
      repeat_sdf.gd       8 domain modifiers
      ...
      material_sdf.gd     2 material nodes
      gradient_sdf.gd
      raymarch_sdf.gd      Renderer
  help/
    top/
      sphere_sdf_basic.gnpatch    3 help patches per operator
      sphere_sdf_animated.gnpatch
      ...
```
