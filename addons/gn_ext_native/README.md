# gn_ext_native — Native C++ Acceleration

C++ accelerated operators for CPU-heavy algorithms.  Each operator checks
for the native class at init and falls back to GDScript if the DLL/dylib
is unavailable.

## Operator Count

**93 native operators** across 6 families:

| Family | Count | Examples |
|--------|------:|---------|
| SOP | 43 | smooth, boolean (BSP-tree CSG), subdivide, remesh, polyreduce |
| CHOP | 23 | noise, filter, math, resample, physics, IK |
| POP | 9 | source, force, attract, collision, turbulence |
| VOL | 9 | fluid, noise, blur, marching cubes, SOP↔VOL |
| IMG | 5 | blur, edge detect, noise, pixel sort, checkerboard |
| TOP | 4 | analyze, optical flow, CHOP→TOP, particle state |

## Architecture

Each native operator follows the same pattern:

```
addons/gn_ext_native/
├── native/
│   ├── SConstruct                    # godot-cpp build
│   └── src/
│       ├── register_types.cpp        # ClassDB registration
│       └── sop/
│           ├── gn_native_smooth_sop.h
│           └── gn_native_smooth_sop.cpp
└── operators/
    └── sop/
        └── smooth_sop_native.gd      # GDScript wrapper
```

**GDScript wrapper** — extends the family base class (e.g. `GNSopBase`),
sets the same `node_type` as the GDScript-only version, instantiates the
C++ class via `ClassDB.instantiate()`, and delegates the heavy computation
in `_cook()`.

**C++ class** — registered with `ClassDB::register_class<>()` in
`register_types.cpp`.  Exposes a `process()` method that takes typed
arrays (PackedVector3Array, PackedInt32Array, etc.) and returns result
arrays.  No Godot scene tree access — pure computation.

## Building

```bash
cd addons/gn_ext_native/native
scons platform=windows target=template_release
```

Requires godot-cpp headers (cloned by `setup_deps.py`).

Supported platforms: **Windows** (win64), **Linux** (linux64), **macOS** (universal).

## Adding a New Native Operator

1. Create C++ header + source in `native/src/<family>/`
2. Register in `register_types.cpp`
3. Create GDScript wrapper in `operators/<family>/`
4. Add `[operator.ClassName]` to `gn_extension.cfg`
5. Rebuild: `scons platform=windows target=template_release`
6. Follow the standard operator checklist (`dev_docs/NEW_OPERATOR_CHECKLIST.md`)
