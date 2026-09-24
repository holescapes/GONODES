# gn_ext_native — Native C++ Acceleration

C++ accelerated operators for CPU-heavy algorithms.  Each operator checks
for the native class at init and falls back to GDScript if the DLL/dylib
is unavailable.

## Operator Count

**131 native operators** across 6 families:

| Family | Count |
|--------|------:|
| SOP | 62 |
| CHOP | 44 |
| POP | 8 |
| VOL | 8 |
| IMG | 5 |
| TOP | 4 |

## Operators

| Class | Family | Description |
|-------|--------|-------------|
| BlurIMGNative | IMG | Box blur with native C++ acceleration. |
| NoiseIMGNative | IMG | Procedural noise generator with native C++ acceleration. |
| PixelSortIMGNative | IMG | Pixel-sorting glitch effect with native C++ acceleration. |
| ParticleSOPNative | SOP | CPU particle system with native C++ acceleration. |
| MetaballSOPNative | SOP | Metaball iso-surface via marching cubes with native C++ acceleration. |
| PolyReduceSOPNative | SOP | QEM mesh decimation with native C++ acceleration. |
| IsoSurfaceSOPNative | SOP | Implicit iso-surface generator (Gyroid, Schwarz-P/D, etc.) via marching cubes with native C++ acceleration. |
| RaySOPNative | SOP | Ray-cast projection of source vertices onto target geometry with native C++ acceleration. |
| FacetSOPNative | SOP | Facet unique / consolidate points with native C++ acceleration. |
| FuseSOPNative | SOP | Merge coincident points within threshold with native C++ acceleration. |
| SubdivideSOPNative | SOP | Uniform triangle subdivision with native C++ acceleration. |
| CopySOPNative | SOP | Copy-to-points instancing with native C++ acceleration. |
| LSystemSOPNative | SOP | L-System fractal/branching geometry with native C++ acceleration. |
| SpringSOPNative | SOP | Damped spring vertex deformer with native C++ acceleration. |
| EdgeDetectIMGNative | IMG | CPU edge detection (Sobel/Prewitt) with native C++ acceleration. |
| SmoothCHOPNative | CHOP | Biquad Butterworth filter (LP/HP/BP) with native C++ acceleration. |
| NoiseCHOPNative | CHOP | Smooth noise channel generator with native C++ acceleration. |
| WaveCHOPNative | CHOP | Multi-channel waveform generator with native C++ acceleration. |
| MathCHOPNative | CHOP | Per-sample math operations with native C++ acceleration. |
| FilterCHOPNative | CHOP | IIR low-pass/high-pass filter with native C++ acceleration. |
| ResampleCHOPNative | CHOP | Channel resampling/interpolation with native C++ acceleration. |
| TrailCHOPNative | CHOP | Ring-buffer trail recorder with native C++ acceleration. |
| SlopeCHOPNative | CHOP | Per-sample derivative with native C++ acceleration. |
| WarpCHOPNative | CHOP | Time-warp/retime channels with native C++ acceleration. |
| InterpolateCHOPNative | CHOP | Channel interpolation with easing curves, native C++ acceleration. |
| PhysicsCHOPNative | CHOP | Physics body readback with native C++ acceleration. |
| PatternCHOPNative | CHOP | Multi-sample pattern generator with native C++ acceleration. |
| AudioSpectrumCHOPNative | CHOP | FFT spectrum analysis with native C++ acceleration. |
| NoiseSOPNative | SOP | 3D noise vertex displacement with native C++ acceleration. |
| MountainSOPNative | SOP | Fractal noise mountain displacement with native C++ acceleration. |
| BlendSOPNative | SOP | Geometry morph/blend with native C++ acceleration. |
| ScatterSOPNative | SOP | Area-weighted point scattering with native C++ acceleration. |
| SweepSOPNative | SOP | Profile sweep along backbone with native C++ acceleration. |
| ExtrudeSOPNative | SOP | Face extrusion along normals with native C++ acceleration. |
| BendSOPNative | SOP | Circular arc bend deformation with native C++ acceleration. |
| TaperSOPNative | SOP | Axis-aligned taper deformation with native C++ acceleration. |
| TwistSOPNative | SOP | Twist deformation around axis with native C++ acceleration. |
| LatticeSOPNative | SOP | Free-form lattice deformation with native C++ acceleration. |
| MagnetSOPNative | SOP | Magnet point attractor deformation with native C++ acceleration. |
| PolyLoftSOPNative | SOP | Cross-section lofting with native C++ acceleration. |
| SkinSOPNative | SOP | Cross-section skinning with native C++ acceleration. |
| OpticalFlowTOPNative | TOP | Horn-Schunck optical flow with native C++ acceleration. |
| AnalyzeTOPNative | TOP | Pixel min/max/avg/sum statistics with native C++ acceleration. |
| TOPtoSOPNative | SOP | Convert TOP texture to heightfield mesh with native C++ acceleration. |
| PointSOPNative | SOP | Per-vertex expression deformation with native C++ acceleration. |
| ClipSOPNative | SOP | Plane-based geometry clipping with native C++ acceleration. |
| SortSOPNative | SOP | Vertex reordering by axis/distance/random with native C++ acceleration. |
| UVProjectSOPNative | SOP | UV projection (planar/cylindrical/spherical) with native C++ acceleration. |
| AttributeSOPNative | SOP | Custom point attribute creation with native C++ acceleration. |
| TransformSOPNative | SOP | Transform geometry (translate/rotate/scale) with native C++ acceleration. |
| DivideSOPNative | SOP | Polygon triangulation and cleanup with native C++ acceleration. |
| NormalSOPNative | SOP | Normal recomputation (smooth/flat/custom) with native C++ acceleration. |
| MirrorSOPNative | SOP | Mirror geometry across an axis with native C++ acceleration. |
| CapSOPNative | SOP | Close open boundary holes with native C++ acceleration. |
| DeleteSOPNative | SOP | Delete triangles by range/bbox/random with native C++ acceleration. |
| CarveSOPNative | SOP | Trim triangles by parametric U range with native C++ acceleration. |
| TOPtoCHOPNative | CHOP | Sample TOP pixels as CHOP channels with native C++ acceleration. |
| ExpressionCHOPNative | CHOP | Per-channel math expression evaluation with native C++ acceleration. |
| AudioDynamicsCHOPNative | CHOP | Compressor/limiter/expander/gate with native C++ acceleration. |
| StretchCHOPNative | CHOP | Resample channels to new length with native C++ acceleration. |
| LookupCHOPNative | CHOP | Table lookup with interpolation with native C++ acceleration. |
| CHOPtoTOPNative | TOP | Render CHOP channels as texture with native C++ acceleration. |
| ParticleStateTOPNative | TOP | Visualize particle attributes as 2D texture with native C++ acceleration. |
| CheckerboardIMGNative | IMG | Checkerboard pattern generator with native C++ acceleration. |
| MarchingCubesSOPNative | SOP | Marching cubes iso-surface extraction with native C++ acceleration. |
| CHOPtoVOLNative | VOL | Convert CHOP channels to 3D volume with native C++ acceleration. |
| AnalyzeVOLNative | VOL | Volume density statistics with native C++ acceleration. |
| InstanceSOPNative | SOP | Copy geometry onto particles with native C++ acceleration. |
| RenderPOPNative | POP | Render particles as point cloud/billboards with native C++ acceleration. |
| SmoothSOPNative | SOP | Laplacian vertex smoothing with border pinning - native C++ accelerated. |
| RemeshSOPNative | SOP | Adaptive edge-length remeshing with midpoint subdivision - native C++ accelerated. |
| PolyBevelSOPNative | SOP | Vertex-pull edge bevel with rounded divisions - native C++ accelerated. |
| PolyStitchSOPNative | SOP | Nearest-pair stitching between two point sets - native C++ accelerated. |
| WireframeSOPNative | SOP | Triangle edge extraction as line geometry - native C++ accelerated. |
| IkCHOPNative | CHOP | FABRIK inverse kinematics solver - native C++ accelerated. |
| SOPtoCHOPNative | CHOP | Extract vertex attributes as CHOP channels - native C++ accelerated. |
| LaserCHOPNative | CHOP | ILDA laser pattern generator - native C++ accelerated. |
| CompositeCHOPNative | CHOP | Multi-input channel blending - native C++ accelerated. |
| FanCHOPNative | CHOP | Channel fan/spread with offset - native C++ accelerated. |
| BlurVOLNative | VOL | Multi-pass 3D box blur - native C++ accelerated. |
| NoiseVOLNative | VOL | FBM value noise volume generator - native C++ accelerated. |
| DisplaceVOLNative | VOL | Velocity-field density displacement - native C++ accelerated. |
| BlendVOLNative | VOL | Two-volume arithmetic blend - native C++ accelerated. |
| SOPtoVOLNative | VOL | Point-splatting SOP to density volume - native C++ accelerated. |
| FluidVOLNative | VOL | Navier-Stokes fluid simulation - native C++ accelerated. |
| SourcePOPNative | POP | Particle emitter with age/kill - native C++ accelerated. |
| ForcePOPNative | POP | Gravity/wind/drag force integration - native C++ accelerated. |
| CollisionPOPNative | POP | Ground plane collision with bounce/kill - native C++ accelerated. |
| TurbulencePOPNative | POP | Curl noise turbulence - native C++ accelerated. |
| AttractPOPNative | POP | Inverse-square point attractor - native C++ accelerated. |
| AdvectPOPNative | POP | Volume-field particle advection - native C++ accelerated. |
| LimitPOPNative | POP | Bounding box kill + speed clamp - native C++ accelerated. |
| BooleanSOPNative | SOP | Boolean operations (union, intersect, subtract) via BSP-tree - native C++ accelerated. |
| BlendCHOPNative | CHOP | Weighted channel blend with easing - native C++ accelerated. |
| LagCHOPNative | CHOP | Attack/release exponential smoothing - native C++ accelerated. |
| TransformCHOPNative | CHOP | TRS transform on xyz channel groups - native C++ accelerated. |
| ClothSOPNative | SOP | Verlet cloth simulation - native C++ accelerated. |
| TextureSOPNative | SOP | Per-vertex texture sampling (color/displace) - native C++ accelerated. |
| GroupSOPNative | SOP | Vertex grouping by BBox/normal/all - native C++ accelerated. |
| PolySplineSOPNative | SOP | Catmull-Rom spline with optional tube mesh - native C++ accelerated. |
| PolyPatchSOPNative | SOP | Bilinear Coons patch from 4 corners - native C++ accelerated. |
| PolyBridgeSOPNative | SOP | Bridge two edge loops with connecting geometry - native C++ accelerated. |
| AreaCHOPNative | CHOP | Numerical integration (trapezoidal/Simpson/rectangle) - native C++ accelerated. |
| CopyCHOPNative | CHOP | Copy/combine channels by name matching - native C++ accelerated. |
| AudioBandCHOPNative | CHOP | Multi-band frequency analysis with envelope followers - native C++ accelerated. |
| RampCHOPNative | CHOP | Ramp curve sampling with cubic Hermite interpolation - native C++ accelerated. |
| CrossCHOPNative | CHOP | Cross-fade between two CHOP inputs - native C++ accelerated. |
| LimitCHOPNative | CHOP | Clamp/Loop/Zig-Zag value limiting - native C++ accelerated. |
| LogicCHOPNative | CHOP | Boolean logic (AND/OR/XOR/NAND/NOR/NOT) - native C++ accelerated. |
| JoinCHOPNative | CHOP | Join (concatenate) two channel arrays - native C++ accelerated. |
| AnalyzeCHOPNative | CHOP | Statistical analysis (avg/min/max/sum/RMS) - native C++ accelerated. |
| AudioOscillatorCHOPNative | CHOP | Audio oscillator (sine/saw/square/tri) with FM/AM - native C++ accelerated. |
| AudioFilterCHOPNative | CHOP | Biquad audio filter (LP/HP/BP/notch/peak/shelf) - native C++ accelerated. |
| AudioParaEQCHOPNative | CHOP | 8-band parametric EQ - native C++ accelerated. |
| AudioMixCHOPNative | CHOP | Multi-input audio mixer with pan/gain/mute/solo - native C++ accelerated. |
| AudioReverbCHOPNative | CHOP | Schroeder reverb with comb + allpass filters - native C++ accelerated. |
| AudioDelayCHOPNative | CHOP | Audio delay with feedback - native C++ accelerated. |
| AudioPitchCHOPNative | CHOP | Granular pitch shifter - native C++ accelerated. |
| AudioEnvelopeCHOPNative | CHOP | Envelope follower with attack/release - native C++ accelerated. |
| AudioGateCHOPNative | CHOP | Noise gate with sidechain - native C++ accelerated. |
| PeakSOPNative | SOP | Vertex displacement along normals - native C++ accelerated. |
| MeasureSOPNative | SOP | Geometry measurement (area/perimeter/curvature) - native C++ accelerated. |
| CreepSOPNative | SOP | Move points along target surface - native C++ accelerated. |
| ProjectSOPNative | SOP | Orthographic projection onto surface - native C++ accelerated. |
| HoleSOPNative | SOP | Cut holes in polygon surfaces - native C++ accelerated. |
| ConvertLineSOPNative | SOP | Convert polylines to bezier/subdivision - native C++ accelerated. |
| VoronoiShatterSOPNative | SOP | Voronoi fracture geometry into pieces - native C++ accelerated. |
| HeightfieldSOPNative | SOP | Heightfield terrain mesh generation - native C++ accelerated. |
| TrailRibbonSOPNative | SOP | Trail ribbon mesh from particle paths - native C++ accelerated. |
| PrimitiveSOPNative | SOP | Per-primitive attribute computation - native C++ accelerated. |
| ResampleSOPNative | SOP | Resample polylines to even spacing - native C++ accelerated. |

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
