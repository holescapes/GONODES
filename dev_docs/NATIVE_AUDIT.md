# GONODES C++ (GDExtension) Rewrite Audit

Complete classification of every operator file in the project.
Audited: all `_cook()` and `_cook_cpu()` methods plus the cook engine.

---

## Classification Legend

| Rating | Meaning | Criteria |
|--------|---------|----------|
| **🔴 HOT** | C++ candidate | Per-vertex/per-pixel/per-voxel loops over large data, multi-pass iteration, O(n²+) algorithms |
| **🟡 WARM** | Borderline | Single-pass moderate loops (<1K typical), per-sample CHOP ops on small buffers |
| **🟢 COLD** | Keep GDScript | Pass-through, parameter assembly, GPU-delegated (shader), UI/events, I/O, generators of small fixed-size data |

---

## Cook Engine — `addons/gonodes/core/gn_cook_engine.gd`

**Rating: 🟡 WARM**

The cook engine itself has moderate per-node overhead each frame:
- **Hash computation** (`_compute_cook_input_hash`): iterates all parameters + inputs per node and hashes them
- **Expression resolution** (`_resolve_node_parameters`): regex parsing + GDScript `Expression.execute()` per expression parameter
- **Input gathering** (`_gather_inputs`): dictionary lookups per input port
- **Topological sort**: cached, rebuilt only on topology changes
- **Parallel dispatch**: already uses `WorkerThreadPool` for CPU-family nodes at the same topo level

**Verdict**: The per-node overhead is proportional to parameter count, not data size. For typical graphs (50-200 nodes), this is manageable in GDScript. The expression resolution is the most expensive per-node cost — if expressions are heavily used, the regex + `Expression.execute()` overhead becomes noticeable. A C++ rewrite of the hash computation and expression resolver would help large graphs but is not the primary bottleneck.

---

## SOP Family — `addons/gonodes/operators/sop/` (71 files)

### 🔴 HOT (26 operators)

| Operator | File | Bottleneck | Data Scale | Inner-loop Math |
|----------|------|-----------|------------|-----------------|
| **smooth** | `smooth_sop.gd` | `iterations × vertices × neighbors` — Laplacian smoothing with adjacency build, border detection, normal recompute | 1K-100K verts × 1-100 iters | lerp, normalize, cross |
| **subdivide** | `subdivide_sop.gd` | `iterations × triangles` — Each pass 4× triangle count. 2 iters on 10K tris = 160K tris | Exponential growth: 10K → 40K → 160K | midpoint, UV interp |
| **remesh** | `remesh_sop.gd` | `iterations × triangles` — Adaptive edge-length subdivision + optional Laplacian smooth pass + normal recompute | 1K-100K tris × 1-4 iters | distance, midpoint, normalize |
| **isosurface** | `isosurface_sop.gd` | Triple-nested `(res+1)³` field evaluation + `res³` marching cubes + per-triangle 6-tap gradient normals | res=40 → 68K field evals + 64K cube cells | sin, cos, sqrt, lerp, cross, normalize |
| **metaball** | `metaball_sop.gd` | Triple-nested `(res+1)³ × balls` field evaluation + `res³` marching cubes + per-vertex gradient | res=40 → 68K × 2-20 balls = 136K-1.36M evals | dist², reciprocal, lerp, normalize |
| **polyreduce** | `polyreduce_sop.gd` | Quadric error metric edge collapse: O(T) init + iterative O(E) linear scan for minimum cost + collapse + requadric | 10K-100K tris, iterative collapses | 4×4 quadric matrix ops, dot, cross |
| **copy** | `copy_sop.gd` | `target_points × src_vertices` — Transforms every src vertex for every copy | 100-10K pts × 100-10K verts = up to 100M | matrix*vector, normalize |
| **polybevel** | `polybevel_sop.gd` | `vertices × ring_count × ring_vertices` — Multi-ring bevel per edge | rings(1-8) × edge verts | lerp, normal compute |
| **facet** | `facet_sop.gd` | O(V²) vertex fusion (nested loop comparing all pairs) + per-vertex normal ops | 1K-100K verts, worst case O(V²) | distance_to, normalize |
| **fuse** | `fuse_sop.gd` | Spatial-hash vertex welding: per-vertex 3³=27 cell neighbor scan | 1K-100K verts × 27 neighbors | distance_to |
| **lattice** | `lattice_sop.gd` | Lattice grid build + per-vertex trilinear deformation over (dx+1)(dy+1)(dz+1) control points | 1K-100K verts, lattice typically 4³ | trilinear lerp per vertex |
| **magnet** | `magnet_sop.gd` | `vertices × attractors` double loop + normal recompute | 1K-100K verts × 1-100 attractors | distance, normalized, lerp |
| **spring** | `spring_sop.gd` | Per-vertex spring integration every frame (time-dependent) + normal recompute | 1K-100K verts/frame | force, accel, velocity integration |
| **particle** | `particle_sop.gd` | Per-particle physics simulation every frame + triangle-surface emission sampling | 100-100K particles/frame | force, velocity, life, random point on tri |
| **noise** | `noise_sop.gd` | Per-vertex noise displacement per surface | 1K-100K verts | FastNoiseLite eval, normalize |
| **mountain** | `mountain_sop.gd` | Per-vertex noise displacement along normals | 1K-100K verts | noise eval, normal scale |
| **point** | `point_sop.gd` | Per-vertex expression evaluation | 1K-100K verts | user expressions |
| **ray** | `ray_sop.gd` | Per-vertex raycast against target triangle soup (brute-force) | 1K-100K verts × target tris | ray-tri intersection |
| **scatter** | `scatter_sop.gd` | Random triangle sampling with area-weighted CDF | up to 100K samples | random, barycentric interp |
| **clip** | `clip_sop.gd` | Per-triangle plane intersection with vertex interpolation | 1K-100K tris | dot, lerp per edge |
| **sort** | `sort_sop.gd` | Per-vertex sort with custom comparator (GDScript sort_custom) | 1K-100K verts | distance_squared_to, comparator |
| **top_to_sop** | `top_to_sop.gd` | Per-pixel heightfield/point-cloud generation from texture (up to 512×512) | up to 262K pixels | luminance, grid build |
| **lsystem** | `lsystem_sop.gd` | Iterative string production (exponential growth) + 3D turtle with mesh gen | string length grows exponentially per iter | sin, cos, matrix rotations |
| **extrude** | `extrude_sop.gd` | Per-vertex displacement + per-triangle side wall generation | 1K-100K tris | normal scale, new tri build |
| **polystitch** | `polystitch_sop.gd` | O(A×B) brute-force closest-point pairing | up to 10K×10K = 100M | distance_squared_to |
| **wireframe** | `wireframe_sop.gd` | Per-triangle edge extraction with dedup | 1K-100K tris | hash, vert copy |

### 🟡 WARM (18 operators)

| Operator | File | Notes |
|----------|------|-------|
| **attribute** | `attribute_sop.gd` | Per-vertex attribute modification — moderate loops but simple math (set/add/mult) |
| **blend** | `blend_sop.gd` | Per-vertex lerp between two meshes — moderate |
| **bend** | `bend_sop.gd` | Per-vertex bend deformation — sin/cos per vertex |
| **normal** | `normal_sop.gd` | Per-vertex normal recompute — same as internal helper used by hot SOPs |
| **peak** | `peak_sop.gd` | Per-vertex displacement along normal — simple |
| **delete** | `delete_sop.gd` | Per-vertex/per-tri filter evaluation |
| **carve** | `carve_sop.gd` | Per-tri U/V carve evaluation |
| **divide** | `divide_sop.gd` | Triangulation (fan/Delaunay) |
| **mirror** | `mirror_sop.gd` | Per-vertex mirror + copy |
| **texture** | `texture_sop.gd` | Per-vertex UV projection |
| **cap** | `cap_sop.gd` | Boundary loop detection + fan triangulation |
| **group** | `group_sop.gd` | Per-vertex/per-tri group classification |
| **polyloft** | `polyloft_sop.gd` | Per-ring × per-vertex loft with interpolation |
| **polyspline** | `polyspline_sop.gd` | Catmull-Rom + tube sweep — moderate vertex counts |
| **polybridge** | `polybridge_sop.gd` | Per-division per-vertex bridge generation |
| **polypatch** | `polypatch_sop.gd` | (rows+1)×(cols+1) bicubic patch evaluation |
| **sweep** | `sweep_sop.gd` | Per-ring instanced sweep along curve |
| **skin** | `skin_sop.gd` | Ring-to-ring surface generation |

### 🟢 COLD (27 operators)

| Operator | File | Reason |
|----------|------|--------|
| **null** | `null_sop.gd` | Pass-through |
| **select** | `select_sop.gd` | Reference fetch |
| **switch** | `switch_sop.gd` | Input selection |
| **box** | `box_sop.gd` | Fixed-size generator (24 verts) |
| **sphere** | `sphere_sop.gd` | Fixed-size generator |
| **torus** | `torus_sop.gd` | Fixed-size generator |
| **cylinder** | `cylinder_sop.gd` | Fixed-size generator |
| **tube** | `tube_sop.gd` | Fixed-size generator |
| **grid** | `grid_sop.gd` | Small grid generator (rows×cols, typically <100×100) |
| **circle** | `circle_sop.gd` | Small ring generator |
| **line** | `line_sop.gd` | Small line generator |
| **font** | `font_sop.gd` | Delegates to Godot TextMesh |
| **file_in** | `file_in_sop.gd` | File I/O |
| **file_out** | `file_out_sop.gd` | File I/O (vertex loop for OBJ export — moderate) |
| **merge** | `merge_sop.gd` | Surface append (no per-vertex work) |
| **objectmerge** | `objectmerge_sop.gd` | Reference fetch + optional transform |
| **dat_to_sop** | `dat_to_sop.gd` | Table → points converter (small data) |
| **chop_to_sop** | `chop_to_sop.gd` | Channel → points converter (small data) |
| **boolean** | `boolean_sop.gd` | Delegates to Godot CSGMesh3D (engine-native) |
| **script** | `script_sop.gd` | User-written GDScript |
| **primitive** | `primitive_sop.gd` | Primitive attribute layer |
| **reverse** | `reverse_sop.gd` | Index reversal |
| **trail** | `trail_sop.gd` | History cache management |

---

## CHOP Family — `addons/gonodes/operators/chop/` (74 files)

### 🔴 HOT (14 operators)

| Operator | File | Bottleneck | Data Scale |
|----------|------|-----------|------------|
| **top_to_chop** | `top_to_chop.gd` | Per-pixel `Image.get_pixel()` iteration (Average: w×h; Row/Col: w×h) | 1920×1080 = 2M pixel reads |
| **noise** | `noise_chop.gd` | `num_channels × sample_count × octaves` noise evaluation | 1-16 ch × 100-48000 samp × 1-8 oct |
| **pattern** | `pattern_chop.gd` | `num_channels × sample_count` per-sample waveform math | 1-32 ch × 100-48000 samples |
| **wave** | `wave_chop.gd` | `num_channels × sample_count` per-sample oscillator | 1-32 ch × 100-48000 samples |
| **math** | `math_chop.gd` | Per-sample per-channel arithmetic (all channels matched) | 1-32 ch × 100-48000 samples |
| **filter** | `filter_chop.gd` | Per-sample per-channel IIR/FIR filter | 1-32 ch × 100-48000 samples |
| **smooth** | `smooth_chop.gd` | Per-sample rolling average | samples × window size |
| **expression** | `expression_chop.gd` | Per-sample `Expression.execute()` with GDScript interpreter | up to 48K samples |
| **ik** | `ik_chop.gd` | `iterations × joints` FABRIK solver with forward+backward pass | 10-50 iters × 2-100 joints |
| **sop_to_chop** | `sop_to_chop.gd` | Per-vertex extraction from mesh surfaces | 1K-100K verts |
| **audio_dynamics** | `audio_dynamics_chop.gd` | Per-sample compression/limiting | 48000 samples/sec |
| **laser** | `laser_chop.gd` | Per-point laser blanking + shape generation | 100-30000 points |
| **composite** | `composite_chop.gd` | Per-sample multi-input composite on all channels | N inputs × channels × samples |
| **fan** | `fan_chop.gd` | `count × samples` fan-out expansion | up to 1K channels × 48K samples |

### 🟡 WARM (25 operators)

| Operator | File | Notes |
|----------|------|-------|
| **slope** | `slope_chop.gd` | Per-sample derivative |
| **lag** | `lag_chop.gd` | Per-sample exponential lag |
| **resample** | `resample_chop.gd` | Per-new-sample interpolation |
| **stretch** | `stretch_chop.gd` | Per-sample resample |
| **warp** | `warp_chop.gd` | Per-sample time warp |
| **lookup** | `lookup_chop.gd` | Per-sample LUT lookup |
| **cross** | `cross_chop.gd` | Per-sample cross-fade |
| **limit** | `limit_chop.gd` | Per-sample clamp |
| **logic** | `logic_chop.gd` | Per-sample boolean op |
| **blend** | `blend_chop.gd` | Per-sample weighted blend |
| **copy** | `copy_chop.gd` | Per-sample copy |
| **extend** | `extend_chop.gd` | Per-sample extension fill |
| **interpolate** | `interpolate_chop.gd` | Per-sample lerp |
| **trim** | `trim_chop.gd` | Per-sample subset copy |
| **split** | `split_chop.gd` | Per-sample subset copy |
| **join** | `join_chop.gd` | Per-segment per-sample concatenation |
| **transform** | `transform_chop.gd` | Per-sample matrix math |
| **ramp** | `ramp_chop.gd` | Per-slot per-sample curve eval |
| **envelope** | `envelope_chop.gd` | Per-sample envelope follower |
| **keyframe** | `keyframe_chop.gd` | Per-key interpolation |
| **spring** | `spring_chop.gd` | Spring integration per frame |
| **physics** | `physics_chop.gd` | Physics integration per frame |
| **audio_spectrum** | `audio_spectrum_chop.gd` | FFT bin processing |
| **audio_file_in** | `audio_file_in_chop.gd` | Audio frame decode |
| **audio_in** | `audio_in_chop.gd` | Real-time capture |

### 🟢 COLD (35 operators)

| Operator | File | Reason |
|----------|------|--------|
| **null** | `null_chop.gd` | Pass-through |
| **select** | `select_chop.gd` | Reference + filter |
| **switch** | `switch_chop.gd` | Input selection |
| **feedback** | `feedback_chop.gd` | Previous-frame cache return |
| **constant** | `constant_chop.gd` | Parameter reads |
| **channel** | `channel_chop.gd` | Parameter reads |
| **clock** | `clock_chop.gd` | Time read |
| **timer** | `timer_chop.gd` | Timer state |
| **count** | `count_chop.gd` | Counter state |
| **beat** | `beat_chop.gd` | Beat detection |
| **lfo** | `lfo_chop.gd` | Single-sample oscillator |
| **speed** | `speed_chop.gd` | Integration |
| **hold** | `hold_chop.gd` | Value hold |
| **trigger** | `trigger_chop.gd` | Event trigger |
| **delay** | `delay_chop.gd` | Time shift |
| **clip** | `clip_chop.gd` | Simple clamp |
| **mouse_in** | `mouse_in_chop.gd` | Input device |
| **keyboard_in** | `keyboard_in_chop.gd` | Input device |
| **gamepad** | `gamepad_chop.gd` | Input device |
| **tabletin** | `tabletin_chop.gd` | Input device |
| **osc_in** | `osc_in_chop.gd` | Network input |
| **midi_in** | `midi_in_chop.gd` | MIDI input |
| **host_in** | `host_in_chop.gd` | Host API |
| **rename** | `rename_chop.gd` | Name remapping |
| **delete** | `delete_chop.gd` | Channel filter |
| **shuffle** | `shuffle_chop.gd` | Channel reorder |
| **merge** | `merge_chop.gd` | Channel merge |
| **sequence** | `sequence_chop.gd` | Channel ordering |
| **trail** | `trail_chop.gd` | History buffer shift |
| **perform** | `perform_chop.gd` | Performance counters |
| **object** | `object_chop.gd` | Scene-tree read |
| **skeleton** | `skeleton_chop.gd` | Bone read |
| **parameter** | `parameter_chop.gd` | Parameter export |
| **script** | `script_chop.gd` | User GDScript |
| **dat_to_chop** | `dat_to_chop.gd` | DAT converter |

---

## TOP Family — `addons/gonodes/operators/top/` (68 files)

### 🔴 HOT (1 operator)

| Operator | File | Bottleneck |
|----------|------|-----------|
| **chop_to_top** | `chop_to_top.gd` | Per-channel × per-pixel CPU `Image.set_pixel()` loop — draws waveforms/bars/fill into Image on CPU. channels × width × height. | 

### 🟡 WARM (2 operators)

| Operator | File | Notes |
|----------|------|-------|
| **convolution** | `convolution_top.gd` | Small CPU loop for kernel matrix parsing; actual convolution is GPU shader |
| **layout** | `layout_top.gd` | Small loop (max 8 inputs) for tile positioning |

### 🟢 COLD (65 operators)

**All GPU shader-based** — `_cook()` sets shader uniforms and kicks a SubViewport render:

analyze, anti_alias, blur, cache, channel_mix, chroma_key, circle, color_map, composite, compute_shader, compositor_effect, constant, corner_pin, crop, cross, custom_shader, deform, depth, dilate_erode, displace, edge, emboss, feedback, fit, flip, geometry_buffer, glue, host_in, hsv_adjust, lens_distort, level, lookup, luma_blur, matte, mono, movie_file_in, multi_buffer_render, noise, normal_map, null, optical_flow, palette, panel, pattern, posterize, premultiply, projection, radial_blur, ramp, rectangle, remap, render, reorder, resolution, sharpen, slope, snapshot, svg, switch, text, threshold, tile, time_machine, transform, triangle

---

## IMG Family — `addons/gonodes/operators/img/` (13 files)

### 🔴 HOT (5 operators)

| Operator | File | Bottleneck | Data Scale |
|----------|------|-----------|------------|
| **blur** | `blur_img.gd` | `passes × h × (w + radius)` separable box blur via CPU `Image` pixel manipulation | 512×512 × 1-4 passes × r=1-10 |
| **noise** | `noise_img.gd` | `w × h` per-pixel FastNoiseLite eval + `Image.set_pixel()` | Up to 1024×1024 = 1M pixels |
| **edge_detect** | `edge_detect_img.gd` | `w × h × 3×3` Sobel kernel per pixel on CPU | 512×512 × 9 taps = 2.3M reads |
| **pixel_sort** | `pixel_sort_img.gd` | Per-row or per-column pixel sort with O(n log n) sort segments | 1920×1080 columns × sort |
| **checkerboard** | `checkerboard_img.gd` | `w × h` per-pixel pattern generation | Up to 1024×1024 |

### 🟡 WARM (1 operator)

| Operator | File | Notes |
|----------|------|-------|
| **script** | `script_img.gd` | User-provided pixel loop |

### 🟢 COLD (7 operators)

| Operator | File | Reason |
|----------|------|--------|
| **null** | `null_img.gd` | Pass-through |
| **top_to_img** | `top_to_img.gd` | Texture → Image conversion (single call) |
| **img_to_top** | `img_to_top.gd` | Image → Texture conversion (single call) |
| **webcam** | `webcam_img.gd` | Device capture |
| **screen_grab** | `screen_grab_img.gd` | Screen capture |
| **image_file_in** | `image_file_in_img.gd` | File loading |
| **image_sequence** | `image_sequence_img.gd` | Sequence playback |

---

## VOL Family — `addons/gonodes/operators/vol/` (11 files)

**Architecture note**: All VOL operators have dual paths: GPU `_cook()` using compute shaders and CPU `_cook_cpu()` fallback. The GPU path is COLD (just dispatches compute). The CPU fallback is where the heat is.

### 🔴 HOT — CPU fallbacks (9 operators)

| Operator | File | CPU Bottleneck | Data Scale |
|----------|------|---------------|------------|
| **fluid** | `fluid_vol.gd` | Full Navier-Stokes: advect + diverge + pressure_iters × res³ + project. Multiple triple-nested loops per frame | 64³=262K voxels × 20 pressure iters = 5.2M voxel ops/frame |
| **blur** | `blur_vol.gd` | `passes × res³ × (2r+1)³` — 6-deep nested loop. MOST EXPENSIVE operator in entire project | 64³ × r=2 × 1 pass = 262K × 125 = 32.7M ops |
| **noise** | `noise_vol.gd` | `res³` per-voxel noise evaluation | 64³ = 262K noise evals |
| **displace** | `displace_vol.gd` | `res³` per-voxel displacement lookup | 64³ = 262K |
| **marching_cubes** | `marching_cubes_vol.gd` | `res³` marching cubes extraction — identical to isosurface_sop but from volume data | 64³ = 262K cells |
| **analyze** | `analyze_vol.gd` | `res³` min/max/sum/histogram | 64³ = 262K |
| **blend** | `blend_vol.gd` | `res³` per-voxel blend operation | 64³ = 262K |
| **chop_to_vol** | `chop_to_vol.gd` | Channel data → voxel fill, multiple modes | Up to 64³ = 262K fills |
| **sop_to_vol** | `sop_to_vol.gd` | Per-vertex + per-voxel radius scan with triple-nested inner loop | verts × (2r+1)³ voxels per vert |
| **raymarch** | `raymarch_vol.gd` | `w × h × max_steps` per-pixel raymarching with trilinear volume sampling | 512×512 × 256 steps = 67M |

### 🟢 COLD (2 operators)

| Operator | File | Reason |
|----------|------|--------|
| **null** | `null_vol.gd` | Pass-through |
| (GPU paths of all above) | | Compute shader dispatch only |

---

## POP Family — `addons/gonodes/operators/pop/` (11 files)

**Architecture note**: Like VOL, all POP operators have GPU `_cook()` (compute shader on SSBO) and CPU `_cook_cpu()` fallback. GPU path is COLD. CPU fallback is HOT.

### 🔴 HOT — CPU fallbacks (9 operators)

| Operator | File | CPU Bottleneck | Data Scale |
|----------|------|---------------|------------|
| **advect** | `advect_pop.gd` | Per-particle velocity field trilinear lookup | 1K-100K particles |
| **attract** | `attract_pop.gd` | Per-particle force computation toward attractors | 1K-100K particles |
| **collision** | `collision_pop.gd` | Per-particle collision detection | 1K-100K particles |
| **force** | `force_pop.gd` | Per-particle force integration (gravity, wind, etc.) | 1K-100K particles |
| **turbulence** | `turbulence_pop.gd` | Per-particle 3D noise force evaluation | 1K-100K particles × noise |
| **source** | `source_pop.gd` | Per-emit-point particle creation + per-particle age/life management | up to 100K particles |
| **limit** | `limit_pop.gd` | Per-particle bounds checking | 1K-100K particles |
| **instance** | `instance_pop.gd` | `particles × src_vertices` mesh instancing on CPU — transforms + copies every vertex | 10K particles × 100 verts = 1M transforms |
| **render** | `render_pop.gd` | Per-particle billboard/point generation | 1K-100K particles |

### 🟡 WARM (1 operator)

| Operator | File | Notes |
|----------|------|-------|
| **particle_state_top** | `particle_state_top.gd` | Per-particle → image pixel write for visualization |

### 🟢 COLD (1 operator)

| Operator | File | Reason |
|----------|------|--------|
| **null** | `null_pop.gd` | Pass-through |

---

## COMP Family — `addons/gonodes/operators/comp/` (20 files)

### 🟢 ALL COLD

Every COMP is parameter assembly + scene tree management. No data loops.

geometry_comp, camera_comp, light_comp, environment_comp, instance_comp, animation_comp, engines_comp, merge_comp, null_comp, switch_comp, sub_network_node, in_tunnel, out_tunnel, generic_script_node, replicator_comp, static_body_comp, rigid_body_comp, soft_body_comp, area_comp, joint_comp

---

## MAT Family — `addons/gonodes/operators/mat/` (9 files)

### 🟢 ALL COLD

Every MAT is material property assembly. No data loops.

pbr_mat, constant_mat, shader_mat, depth_mat, line_mat, normal_map_mat, null_mat, point_sprite_mat, wireframe_mat

---

## OUTPUT Family — `addons/gonodes/operators/output/` (12 files)

### 🟢 ALL COLD

All outputs are I/O operations (file writes, window display, network sends).

window_out, texture_save_out, table_save_out, record_out, osc_out, movie_out, image_save_out, host_out_top, host_out_dat, host_out_chop, ffmpeg_out, audio_device_out

---

## UI Family — `addons/gonodes/operators/ui/` (31 files)

### 🟢 ALL COLD

All UIs are Godot Control widget parameter wiring. No data loops.

button_ui, check_box_ui, color_picker_ui, color_rect_ui, container_ui, dropdown_ui, item_list_ui, knob_ui, label_ui, line_edit_ui, link_button_ui, margin_container_ui, menu_button_ui, nine_patch_rect_ui, panel_container_ui, progress_bar_ui, rich_text_label_ui, scroll_container_ui, separator_ui, slider_ui, spin_box_ui, split_container_ui, tab_bar_ui, tab_container_ui, text_edit_ui, texture_button_ui, texture_progress_bar_ui, texture_rect_ui, toggle_ui, tree_ui, xy_pad_ui

---

## DAT Family — `addons/gonodes/operators/dat/` (39 files)

### 🟡 WARM (4 operators)

| Operator | File | Notes |
|----------|------|-------|
| **sort** | `sort_dat.gd` | Table row sort — could be large for big tables |
| **substitute** | `substitute_dat.gd` | Per-cell regex substitution |
| **evaluate** | `evaluate_dat.gd` | Per-cell expression evaluation |
| **sop_to_dat** | `sop_to_dat.gd` | Per-vertex data extraction to table rows |

### 🟢 COLD (35 operators)

All remaining DATs are: text storage, table assembly, network I/O, file I/O, event handlers, pass-through, or small-data converters.

callback_dat, chop_to_dat, constant_dat, dat_to_chop, delete_dat, dmx_dat, error_dat, fifo_dat, file_in_dat, folder_dat, host_in_dat, info_dat, insert_dat, json_dat, merge_dat, midi_in_dat, multi_touch_in_dat, network_dat, null_dat, op_find_dat, osc_in_dat, panel_execute_dat, render_pick_dat, script_dat, select_dat, serial_dat, switch_dat, table_dat, text_dat, top_to_dat, transpose_dat, web_dat, web_server_dat, web_socket_dat, xml_dat

---

## Extension Operators — `addons/gn_ext_*/operators/`

### gn_ext_native (already C++) — 🟢 COLD

These **are** the C++ native rewrites. The GDScript wrappers just delegate to GDExtension.

**103 native C++ classes** across 9 build phases:

| Phase | Family | Count | Classes |
|-------|--------|-------|---------|
| 1–2 | SOP | 11 | Particle, Metaball, PolyReduce, IsoSurface, Ray, Facet, Fuse, Subdivide, Copy, LSystem, Spring |
| 3 | SOP | 13 | Noise, Mountain, Blend, Scatter, Sweep, Extrude, Bend, Taper, Twist, Lattice, Magnet, PolyLoft, Skin |
| 4–6 | SOP | 10 | TopToSop, Point, Clip, Sort, UVProject, Attribute, Transform, Divide, Normal, Mirror, Cap, Delete, Carve |
| 8 | SOP | 5 | Smooth, Remesh, PolyBevel, PolyStitch, Wireframe |
| **9** | **SOP** | **7** | **Cloth, Texture, Peak, Group, PolySpline, PolyPatch, PolyBridge** |
| 2–6 | CHOP | 20 | Smooth, Noise, Wave, Math, Filter, Resample, Trail, Slope, Warp, Interpolate, Physics, Pattern, AudioSpectrum, TopToChop, Expression, AudioDynamics, Stretch, Lookup |
| 8 | CHOP | 5 | IK, SopToChop, Laser, Composite, Fan |
| **9** | **CHOP** | **3** | **Transform, Lag, Blend** |
| 1–6 | IMG | 5 | Blur, PixelSort, Noise, EdgeDetect, Checkerboard |
| 3–5 | TOP | 4 | OpticalFlow, Analyze, ChopToTop, ParticleState |
| 4–8 | VOL | 9 | MarchingCubes, ChopToVol, Analyze, Fluid, Blur, Noise, Displace, Blend, SopToVol |
| 4–8 | POP | 9 | Instance, Render, Advect, Attract, Collision, Force, Turbulence, Source, Limit |
| 7 | Serial | 1 | SerialPort |
| | **Total** | **103** | |

### Phase 9 — CPU-Hot Audit Migration (2026-03-19)

The Phase 9 batch was identified by auditing all operators for CPU hotspots that lacked C++ bindings:

| Class | Source | Key Optimization |
|-------|--------|------------------|
| GNNativeClothSop | `sop/gn_native_cloth_sop.cpp` | Verlet PBD + distance constraints with raw pointer loops, `unordered_set` edge dedup |
| GNNativeTextureSop | `sop/gn_native_texture_sop.cpp` | Per-vertex UV→pixel sampling (color + displacement modes) |
| GNNativePeakSop | `sop/gn_native_peak_sop.cpp` | Per-vertex pos + normal × distance |
| GNNativeGroupSop | `sop/gn_native_group_sop.cpp` | BBox + normal-cone per-vertex classification |
| GNNativePolySplineSop | `sop/gn_native_polyspline_sop.cpp` | Catmull-Rom spline eval + tube mesh generation |
| GNNativePolyPatchSop | `sop/gn_native_polypatch_sop.cpp` | Bilinear Coons patch with grid subdivision |
| GNNativePolyBridgeSop | `sop/gn_native_polybridge_sop.cpp` | Edge loop bridge with Rodrigues' twist rotation |
| GNNativeTransformChop | `chop/gn_native_transform_chop.cpp` | Precomputed Euler→matrix, per-sample SRT application |
| GNNativeLagChop | `chop/gn_native_lag_chop.cpp` | Stateful exp smoothing with separate attack/release |
| GNNativeBlendChop | `chop/gn_native_blend_chop.cpp` | N-input weighted blend with normalization |

### Extension C++ Status

| Extension | C++ Status | Notes |
|-----------|-----------|-------|
| gn_ext_ndi | ~95% complete | Full receiver + sender, needs NDI SDK download |
| gn_ext_depth_sensor | ~95% complete | 3 backends (Azure Kinect, RealSense, Ultraleap), needs vendor SDKs |
| gn_ext_ml | ~95% complete | ONNX Runtime wrapper (CUDA/DirectML/CoreML), needs ORT download |
| gn_ext_blackmagic | 100% scaffolded | Full .cpp stub + register_types + SConstruct + build.cfg + .gdextension; needs DeckLink SDK |

**CHOP**: wave_chop_native, warp_chop_native, trail_chop_native, top_to_chop_native, stretch_chop_native, smooth_chop_native, slope_chop_native, resample_chop_native, physics_chop_native, pattern_chop_native, noise_chop_native, math_chop_native, lookup_chop_native, interpolate_chop_native, filter_chop_native, expression_chop_native, audio_spectrum_chop_native, audio_dynamics_chop_native

**SOP**: uv_project_sop_native, twist_sop_native, transform_sop_native, top_to_sop_native, taper_sop_native, sweep_sop_native, subdivide_sop_native, spring_sop_native, sort_sop_native, skin_sop_native, scatter_sop_native, ray_sop_native, polyreduce_sop_native, polyloft_sop_native, point_sop_native, particle_sop_native, normal_sop_native, noise_sop_native, mountain_sop_native, mirror_sop_native, metaball_sop_native, magnet_sop_native, lsystem_sop_native, lattice_sop_native, isosurface_sop_native, fuse_sop_native, facet_sop_native, extrude_sop_native, divide_sop_native, delete_sop_native, copy_sop_native, clip_sop_native, carve_sop_native, cap_sop_native, blend_sop_native, bend_sop_native, attribute_sop_native

**IMG**: pixel_sort_img_native, noise_img_native, edge_detect_img_native, checkerboard_img_native, blur_img_native

**TOP**: particle_state_top_native, optical_flow_top_native, chop_to_top_native, analyze_top_native

**VOL**: marching_cubes_vol_native, chop_to_vol_native, analyze_vol_native

**POP**: render_pop_native, instance_pop_native

### gn_ext_sdf (20 files) — 🟢 ALL COLD

All SDF operators compose GLSL shader graphs. No CPU loops. Pure GPU.

bend, box, capsule, cone, cylinder, displace, elongate, gradient, gyroid, intersection, material, mirror, octahedron, onion, plane, pyramid, raymarch, repeat, round, smooth_subtract, smooth_union, sphere, subtract, torus, twist, union

### gn_ext_shadertoy — 🟢 COLD
Translates ShaderToy GLSL → Godot shader, renders on GPU.

### gn_ext_isf — 🟢 COLD
Translates ISF shaders → Godot shader, renders on GPU.

### gn_ext_mapper (6 files) — 🟢 ALL COLD
All shader-based projection mapping: bezier_map, edge_blend, grid_warp, projection_mask, projector_blend, quad_map, stoner

### gn_ext_spout/syphon — 🟢 COLD
Video sharing I/O (native library calls).

### gn_ext_ffmpeg — 🟢 COLD
External FFmpeg process I/O.

### gn_ext_gpu_encode — 🟢 COLD
GPU hardware encoding.

### gn_ext_midi — 🟢 COLD
MIDI device I/O.

### gn_ext_serial — 🟢 COLD
Serial port DAT operators.

### gn_ext_video_capture — 🟢 COLD
Video device capture (native).

---

## Summary: Priority C++ Migration List

### Tier 1 — Highest Impact (not yet natively migrated)

These GDScript operators have the worst CPU bottlenecks and do NOT yet have `gn_ext_native` counterparts:

| Operator | Family | Why |
|----------|--------|-----|
| **smooth_sop** | SOP | iterations×vertices×neighbors — O(I×V×N) |
| **remesh_sop** | SOP | iterations×triangles adaptive subdivision |
| **polybevel_sop** | SOP | vertices×rings — complex topology |
| **polystitch_sop** | SOP | O(A×B) brute-force matching |
| **wireframe_sop** | SOP | Per-triangle edge extraction |
| **boolean_sop** | SOP | CSG fallback could be native |
| **fluid_vol** CPU | VOL | Navier-Stokes triple loop × pressure iters |
| **blur_vol** CPU | VOL | 6-deep nested loop — worst in project |
| **noise_vol** CPU | VOL | res³ noise eval |
| **displace_vol** CPU | VOL | res³ displacement |
| **blend_vol** CPU | VOL | res³ blend |
| **sop_to_vol** CPU | VOL | vertex+voxel rasterization |
| **raymarch_vol** CPU | VOL | w×h×steps raymarching |
| **advect_pop** CPU | POP | Per-particle volume lookup |
| **attract_pop** CPU | POP | Per-particle force |
| **collision_pop** CPU | POP | Per-particle collision |
| **force_pop** CPU | POP | Per-particle integration |
| **turbulence_pop** CPU | POP | Per-particle noise |
| **source_pop** CPU | POP | Particle emission |
| **limit_pop** CPU | POP | Per-particle bounds |
| **top_to_chop** | CHOP | Per-pixel Image.get_pixel() iteration |
| **chop_to_top** | TOP | Per-pixel Image.set_pixel() loop |
| **composite_chop** | CHOP | Multi-input per-sample |

### Tier 2 — Already Have Native Counterparts

These are already migrated to `gn_ext_native` — ensure the native versions cover all parameter paths:

SOP: attribute, bend, blend, cap, carve, clip, copy, delete, divide, extrude, facet, fuse, isosurface, lattice, lsystem, magnet, metaball, mirror, mountain, noise, normal, particle, point, polyloft, polyreduce, ray, scatter, skin, sort, spring, subdivide, sweep, taper, top_to_sop, transform, twist, uv_project

CHOP: audio_dynamics, audio_spectrum, expression, filter, interpolate, lookup, math, noise, pattern, physics, resample, slope, smooth, stretch, top_to_chop, trail, warp, wave

IMG: blur, checkerboard, edge_detect, noise, pixel_sort

TOP: analyze, chop_to_top, optical_flow, particle_state

VOL: analyze, chop_to_vol, marching_cubes

POP: instance, render

### Tier 3 — Cook Engine Improvements

| Target | Benefit |
|--------|---------|
| Expression resolver | Avoid GDScript `Expression.execute()` per parameter |
| Cook input hash | Avoid per-parameter `hash()` calls in GDScript |
| Topological sort cache | Already cached — low priority |

---

## Statistics

| Family | Total | 🔴 HOT | 🟡 WARM | 🟢 COLD |
|--------|-------|-------|---------|---------|
| SOP | 71 | 26 | 18 | 27 |
| CHOP | 74 | 14 | 25 | 35 |
| TOP | 68 | 1 | 2 | 65 |
| IMG | 13 | 5 | 1 | 7 |
| VOL | 11 | 9* | 0 | 2 |
| POP | 11 | 9* | 1 | 1 |
| DAT | 39 | 0 | 4 | 35 |
| COMP | 20 | 0 | 0 | 20 |
| MAT | 9 | 0 | 0 | 9 |
| OUTPUT | 12 | 0 | 0 | 12 |
| UI | 31 | 0 | 0 | 31 |
| Extensions | ~115 | 0 | 0 | ~115 |
| **TOTAL** | **~474** | **64** | **51** | **~359** |

*VOL/POP HOT ratings are for CPU fallback paths only — GPU primary paths are COLD.

**Bottom line**: ~64 operators (13.5%) are CPU-heavy and benefit from C++ rewrite. ~38 of those already had native counterparts in `gn_ext_native`. **Phase 8 migration complete:** All 23 remaining unmigrated HOT operators (5 SOP, 5 CHOP, 6 VOL, 7 POP) now have C++ GDExtension implementations. Total native operators: 92 (42 SOP, 23 CHOP, 5 IMG, 4 TOP, 9 VOL, 9 POP). Zero HOT operators remain in pure GDScript.
