# gn_ext_depth_sensor — Depth Sensor Extension

Unified depth sensor interface for GONODES supporting **Azure Kinect**, **Intel RealSense**, and **Ultraleap** with capability-based feature detection.

## Architecture

```
┌─────────────────────────────────────────────┐
│           GNDepthSensor (C++)               │
│    Godot RefCounted, exposed to GDScript    │
├─────────────────────────────────────────────┤
│           DepthSensorBackend                │
│    Abstract interface (virtual methods)     │
├───────────────┬───────────────┬─────────────┤
│ AzureKinect   │  RealSense    │  Ultraleap  │
│ Backend       │  Backend      │  Backend    │
│ (k4a + k4abt) │ (librealsense)│  (LeapC)    │
└───────────────┴───────────────┴─────────────┘
```

One `GNDepthSensor` instance wraps one backend and one device. Multiple operator instances can target different devices simultaneously.

## Device Discovery & Runtime Scanning

All operators use a **dynamic device dropdown** instead of hardcoded backend names. The flow:

```
Compile Time (C++)                    Runtime (GDScript)
──────────────────────────                    ─────────────────────
#ifdef GN_DEPTH_HAS_AZURE_KINECT      GNDepthSensorHelper.get_backends()
  → "azure_kinect"                       → queries C++ once, caches
#ifdef GN_DEPTH_HAS_REALSENSE
  → "realsense"                        GNDepthSensorHelper.get_device_menu()
#ifdef GN_DEPTH_HAS_ULTRALEAP             → calls enumerate_devices()
  → "ultraleap"                           → probes each backend for USB devices
                                          → ["First Available",
                                             "Azure Kinect (S/N: 000123)",
                                             "Ultraleap (S/N: LP789)"]
```

### GNDepthSensorHelper

All operators share `GNDepthSensorHelper` (`depth_sensor_helper.gd`), a static utility class that caches the compiled backend list and discovered device list. Key methods:

| Method | Description |
|--------|-------------|
| `is_available()` | Returns `true` if `GNDepthSensor` native class is loaded |
| `get_backends()` | Compiled backend names from C++ (`get_available_backends()`) |
| `get_device_menu()` | `PackedStringArray` for the Device dropdown (index 0 = "First Available") |
| `get_device_at(index)` | Returns `{serial, name, backend}` Dictionary for a dropdown index |
| `rescan()` | Clears caches; next call re-probes hardware |
| `rescan_and_update_param(node)` | Rescans + updates node's device enum + triggers inspector rebuild |

### Runtime Rescan

Every operator has a **Rescan Devices** pulse button. When pressed:

1. `_pre_cook()` detects the pulse and calls `GNDepthSensorHelper.rescan_and_update_param(self)`
2. Caches are cleared, `enumerate_devices()` re-probes USB hardware
3. The Device dropdown's `enum_options` are overwritten with the fresh list
4. `parameters_changed` signal triggers inspector rebuild — dropdown updates live
5. Pulse auto-resets to `false`

Since the cache is static, rescanning from *any* operator refreshes the device list for *all* depth sensor operators.

## Capability Flags

Each backend declares which features it supports. Operators check capabilities at runtime and degrade gracefully:

| Capability | Azure Kinect | RealSense D400 | Ultraleap | Flag |
|-----------|:---:|:---:|:---:|---|
| Depth | yes | yes | **no** | `CAP_DEPTH` (1) |
| Color | yes | yes | **no** | `CAP_COLOR` (2) |
| IR | yes | yes | **no** | `CAP_IR` (4) |
| Skeleton | yes | **no** | **no** | `CAP_SKELETON` (8) |
| Point Cloud | yes | yes | **no** | `CAP_POINT_CLOUD` (16) |
| Player Index | yes | **no** | **no** | `CAP_PLAYER_INDEX` (32) |
| Floor Plane | yes | **no** | **no** | `CAP_FLOOR_PLANE` (64) |
| Hand Tracking | **no** | **no** | yes | `CAP_HAND_TRACK` (128) |

**RealSense skeleton fallback:** Chain `DepthSensorIMG` (color stream) → `PoseDetectCHOP` from gn_ext_ml for ML-based body tracking from the camera image.

## Operators

| Operator | Family | Purpose |
|----------|--------|---------|
| **DepthSensorIMG** | IMG | Depth / color / IR / player index image streams |
| **DepthSkeletonCHOP** | CHOP | Hardware skeleton joint tracking (positions, rotations, confidence) |
| **DepthHandCHOP** | CHOP | Hand and finger bone tracking (positions, rotations, grab/pinch) |
| **DepthPointCloudSOP** | SOP | Dense 3D point cloud mesh with optional color |
| **DepthSensorDAT** | DAT | Lists connected sensors and their capabilities |

## SDK Setup

### Azure Kinect (Windows/Linux)

1. **Azure Kinect SDK v1.4+**: Download from [Microsoft](https://learn.microsoft.com/en-us/azure/kinect-dk/sensor-sdk-download)
2. **Azure Kinect Body Tracking SDK v1.1+**: Required for skeleton/player index
3. Place SDK files:
   ```
   addons/gn_ext_depth_sensor/native/
   ├── azure_kinect_sdk/
   │   ├── include/
   │   │   ├── k4a/k4a.h
   │   │   └── k4abt.h
   │   └── lib/
   │       ├── k4a.lib        (Windows)
   │       └── k4abt.lib      (Windows)
   ```
4. On Linux: `sudo apt install libk4a1.4-dev libk4abt1.1-dev`

### Intel RealSense (Windows/Linux)

1. **Intel RealSense SDK 2.0**: Download from [Intel](https://www.intelrealsense.com/sdk-2/)
2. Place SDK files:
   ```
   addons/gn_ext_depth_sensor/native/
   ├── realsense_sdk/
   │   ├── include/
   │   │   └── librealsense2/rs.hpp
   │   └── lib/
   │       └── realsense2.lib  (Windows)
   ```
3. On Linux: `sudo apt install librealsense2-dev`

### Ultraleap (Windows/Linux)

1. **Ultraleap Gemini Tracking Software v5.x+**: Download from [Ultraleap](https://developer.leapmotion.com/tracking-software-download)
2. Place SDK files:
   ```
   addons/gn_ext_depth_sensor/native/
   ├── ultraleap_sdk/
   │   ├── include/
   │   │   └── LeapC.h
   │   └── lib/
   │       └── x64/
   │           └── LeapC.lib   (Windows)
   ```
3. On Linux: Install Ultraleap tracking software which provides `libLeapC.so`

### Build

```bash
cd addons/gn_ext_depth_sensor/native
scons platform=windows   # or linux
```

The build system uses `GN_DEPTH_HAS_AZURE_KINECT`, `GN_DEPTH_HAS_REALSENSE`, and `GN_DEPTH_HAS_ULTRALEAP` preprocessor defines. Only backends whose SDKs are found will be compiled — the other backend stubs return `nullptr`.

## Multi-Sensor Usage

Multiple sensors can run simultaneously. Each operator instance manages its own device connection via the Device dropdown:

```
[DepthSensorIMG]              [DepthSensorIMG]
 Device: Azure Kinect (000123)  Device: RealSense D435 (847212)
 Stream: depth                  Stream: color
```

Operators sharing the same device serial and backend share one hardware connection internally via the C++ class's reference counting.

## Adding a New Sensor Backend

1. Create `backend_newsensor.cpp` in `native/src/`
2. Implement the `DepthSensorBackend` interface (all virtual methods + `get_hands()` stub)
3. Add `extern` factory function declaration in `gn_depth_sensor.cpp`
4. Add `#ifdef GN_DEPTH_HAS_NEWSENSOR` guard and factory call in `_get_compiled_backends()` and `_create_backend()`
5. Add SDK paths to `build.cfg` under the new define
6. **Zero changes needed in any GDScript operator** — the new backend appears in device dropdowns automatically via `get_available_backends()` and `enumerate_devices()`

## Joint Name Vocabulary

Azure Kinect skeleton uses 32 joints with these canonical names:

```
pelvis, spine_navel, spine_chest, neck,
clavicle_left, shoulder_left, elbow_left, wrist_left,
hand_left, handtip_left, thumb_left,
clavicle_right, shoulder_right, elbow_right, wrist_right,
hand_right, handtip_right, thumb_right,
hip_left, knee_left, ankle_left, foot_left,
hip_right, knee_right, ankle_right, foot_right,
head, nose, eye_left, eye_right, ear_left, ear_right
```

All positions are in meters (sensor-local coordinates). Orientations are quaternions converted to Euler degrees in the CHOP output.

## Hand Bone Names (Ultraleap)

DepthHandCHOP outputs 27 bones per hand (palm + wrist + 5 fingers × 5 bones):

```
palm, wrist
thumb_metacarpal, thumb_proximal, thumb_intermediate, thumb_distal, thumb_tip
index_metacarpal, index_proximal, index_intermediate, index_distal, index_tip
middle_metacarpal, middle_proximal, middle_intermediate, middle_distal, middle_tip
ring_metacarpal, ring_proximal, ring_intermediate, ring_distal, ring_tip
pinky_metacarpal, pinky_proximal, pinky_intermediate, pinky_distal, pinky_tip
```

Additional scalar channels per hand: `grab_strength`, `pinch_strength`, `confidence`, `is_left`.
