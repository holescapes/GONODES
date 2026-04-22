# gn_ext_sdf — Signed Distance Field Extension

Signed Distance Field operators for GONODES: primitives, booleans, domain modifiers, materials, and a GPU raymarcher.

## Overview

The SDF extension introduces its own **SDF family** — a node-graph approach to constructing SDF scenes. Operators build an SDF tree (a lightweight description of shapes and operations), and the `RaymarchSDF` operator compiles that tree into a single GLSL fragment shader for real-time rendering.

**Pure GDScript — no native binaries or external dependencies required.**

## Operators (29)

### Primitives (10)

| Operator | Description |
|----------|-------------|
| SphereSDF | Sphere with position and radius |
| BoxSDF | Box with position and half-extents |
| TorusSDF | Torus with major and minor radii |
| CylinderSDF | Cylinder with radius and height |
| CapsuleSDF | Capsule with radius and height |
| PlaneSDF | Infinite plane with normal and offset |
| ConeSDF | Cone with angle and height |
| PyramidSDF | Pyramid with base size and height |
| OctahedronSDF | Octahedron with size |
| GyroidSDF | Triply periodic minimal surface |

### Boolean Operations (5)

| Operator | Description |
|----------|-------------|
| UnionSDF | Combines two SDFs (min) |
| IntersectionSDF | Keeps overlapping volume (max) |
| SubtractSDF | Carves B from A |
| SmoothUnionSDF | Blended union with smooth radius |
| SmoothSubtractSDF | Blended subtraction with smooth radius |

### Domain Modifiers (8)

| Operator | Description |
|----------|-------------|
| RepeatSDF | Repeats along axes with spacing and limit |
| MirrorSDF | Mirrors across selected axes |
| TwistSDF | Twists around a selected axis |
| BendSDF | Bends around a selected axis |
| ElongateSDF | Stretches along each axis |
| RoundSDF | Rounds edges by subtracting a radius |
| OnionSDF | Hollows with configurable thickness and layers |
| DisplaceSDF | Sine-based procedural surface detail |

### Materials (2)

| Operator | Description |
|----------|-------------|
| MaterialSDF | Attaches albedo, roughness, metallic, emission |
| GradientSDF | Maps distance to a near/far color gradient |

### Utility (3)

| Operator | Description |
|----------|-------------|
| NullSDF | Pass-through for organization and gating |
| SelectSDF | Wireless SDF tree routing by name |
| SwitchSDF | Switches between multiple inputs by index |

### Renderer (1)

| Operator | Description |
|----------|-------------|
| RaymarchSDF | Compiles SDF tree to GLSL, renders with orbit camera, AO, and soft shadows |

## Typical Pipeline

```
SphereSDF ──┐
            ├── SmoothUnionSDF → TwistSDF → MaterialSDF → RaymarchSDF → WindowOUT
BoxSDF ─────┘
```

## Requirements

None — pure GDScript extension with no external dependencies.
