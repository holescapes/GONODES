# GONODES Extensions and Licensing

> How GONODES handles external libraries, vendor SDKs, and licensing across
> 21 extensions — for both shipped-editor users and build-from-source users.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Extension Tiers](#extension-tiers)
3. [How Extensions Load](#how-extensions-load)
4. [Tier Details and User Setup](#tier-details-and-user-setup)
5. [Shipped Editor vs Build From Source](#shipped-editor-vs-build-from-source)
6. [Licensing Scenarios](#licensing-scenarios)
7. [Extension Reference Table](#extension-reference-table)

---

## Architecture Overview

GONODES is MIT-licensed. The core engine (`addons/gonodes/`) has zero external
dependencies — it's pure GDScript running on Godot 4.6.

Extensions (`addons/gn_ext_*/`) add optional functionality. Each extension has:

- A **`gn_extension.cfg`** manifest declaring operators, dependencies, and metadata
- Operator scripts (`.gd`) that register into the node palette
- Optionally, a **native DLL/SO** (GDExtension) that provides C++ acceleration or
  hardware access

The extension system is designed so that **missing components degrade gracefully**:
operators either show a warning or fall back to a pure-GDScript implementation.
Nothing crashes.

---

## Extension Tiers

Extensions fall into 5 tiers based on what they ship and what the user needs:

### Tier 1 — Pure GDScript (no native code)

| Extension | What it does |
|-----------|-------------|
| gn_ext_isf | ISF shader format translator |
| gn_ext_mapper | Projection mapping tools |
| gn_ext_sdf | Signed distance field operators |
| gn_ext_shadertoy | Shadertoy shader importer |
| gn_ext_serial | Serial port comms (delegates to gn_ext_native) |

**Always available.** No DLLs, no SDKs, no setup.

### Tier 2 — We Build and Ship the DLL (permissive license)

| Extension | License | What the DLL does |
|-----------|---------|-------------------|
| gn_ext_native | MIT (our code, godot-cpp) | ~75 C++ accelerated operators |
| gn_ext_hap | BSD-2/BSD-3 | HAP + Snappy codec (source bundled) |
| gn_ext_midi | MIT | RtMidi for MIDI I/O (source bundled) |
| gn_ext_spout | BSD-2 | Spout2 texture sharing (Windows) |
| gn_ext_gpu_encode | N/A (OS APIs) | HW video encoding via Media Foundation/VideoToolbox |
| gn_ext_video_capture | N/A (OS APIs) | Webcam capture via OS APIs |

**Shipped with GONODES editor.** We compile these DLLs, we own the code or it's
permissively licensed. Users do nothing — operators just work.

### Tier 3 — We Ship Our DLL + LGPL/Large Dependencies

| Extension | License concern | What's bundled |
|-----------|----|----------------|
| gn_ext_ffmpeg | LGPL 2.1+ (FFmpeg) + MIT (wrapper) | EIRTeam.FFmpeg + 6 FFmpeg shared libs per platform |
| gn_ext_webrender | MIT/BSD (gdCEF/Chromium) | ~550MB Chromium binaries (downloaded via setup script) |

**Shipped with GONODES editor**, but with license obligations:
- FFmpeg: LGPL requires dynamic linking (done), source availability on request,
  and allowing users to substitute their own FFmpeg build
- Chromium: large download, MIT/BSD licensed — no restrictions but significant
  disk footprint

### Tier 4 — We Ship Our DLL, User Installs Vendor Runtime

| Extension | Vendor Runtime Needed | Vendor License |
|-----------|----------------------|----------------|
| gn_ext_blackmagic | DeckLink drivers + Desktop Video | Proprietary (free) |
| gn_ext_ndi | NDI Runtime (`Processing.NDI.Lib.x64.dll`) | Proprietary (free SDK) |
| gn_ext_depth_sensor | k4a.dll / realsense2.dll / LeapC.dll | Proprietary / Apache 2.0 |

**We ship our DLL** (MIT-licensed wrapper we compiled). The **vendor's runtime
DLL** is NOT bundled — the user installs vendor software (drivers, SDK runtime)
which puts the vendor DLL on the system PATH. GONODES detects it automatically.

If the vendor runtime is not installed:
- The specific backend DLL fails to load
- The extension's operators show "not available" warnings
- Everything else keeps working

### Tier 5 — Downloaded by the release build, not committed to git

| Extension | What the release downloads | License |
|-----------|---------------------------|---------|
| gn_ext_user_python | CPython 3.10 + NumPy | PSF-2.0 / BSD-3 |
| gn_ext_ml | ONNX Runtime (not YOLOv8 weights) | MIT |
| gn_ext_opencv | OpenCV SDK on Windows; distro package on Linux and macOS | Apache 2.0 |
| gn_ext_syphon | Syphon Framework source clone | BSD-3 |
| gn_ext_spout | Spout2 source clone | BSD |
| gn_ext_webrender | prebuilt CEF | MIT/BSD |

`python setup_deps.py` and the GitHub Actions build both read `setup` and
`vendor_clone` from each `native/build.cfg`. The bytes land in gitignored
folders. YOLOv8 weights are AGPL-3.0 and that download does not include them.

Python is also copied next to a release player for the OS that ran the build.
The interpreter is not committed to the repository.

Building GONODES from source does not grant a right the license withholds.
NDI, Blackmagic Desktop Video, Ultraleap, and Azure Kinect are proprietary
runtimes. A from-source GONODES still needs those vendor installers.
RealSense is Apache 2.0, but the Windows package is an installer this repo
does not unpack. `python scripts/show_manual_sdks.py` prints the download
page and the folder each probe expects.

---

## How Extensions Load

### Step 1: Godot loads GDExtension DLLs

When Godot starts, it scans for `.gdextension` files and tries to load the
specified DLLs. If a DLL is missing or its vendor dependencies can't be found:

- Godot logs a warning and skips that `.gdextension`
- The classes it would have registered (e.g., `GNDepthAzureKinect`) do NOT
  appear in ClassDB
- This is silent and non-fatal

### Step 2: Extension Registry checks dependencies

`GNExtensionRegistry` scans `addons/gn_ext_*/gn_extension.cfg` manifests.
For each extension:

```
dependencies = ["ClassName"]         → ALL listed classes must exist in ClassDB
dependencies_any = ["A", "B", "C"]   → at least ONE listed class must exist
```

If the check fails, the extension is **silently skipped** — none of its operators
register in the palette.

### Step 3: Per-operator ClassDB guards

Even after an extension loads, individual operators guard their native calls:

```gdscript
func _init() -> void:
    if ClassDB.class_exists(&"GNNativeBlur"):
        _processor = ClassDB.instantiate(&"GNNativeBlur")

func _cook(inputs):
    if _processor != null:
        # Fast C++ path
    else:
        # GDScript fallback (or warning)
```

This three-layer system ensures **nothing crashes** regardless of which DLLs
are present.

### Depth Sensor: Multi-Backend Architecture

The depth sensor extension demonstrates the most sophisticated pattern:

```
─── gn_ext_depth_sensor/
    ├── gn_extension.cfg
    │     dependencies_any = ["GNDepthAzureKinect", "GNDepthRealSense", "GNDepthUltraleap"]
    │
    ├── native/azure_kinect/
    │     └── libgn_depth_azure_kinect.dll  → links only k4a.dll
    ├── native/realsense/
    │     └── libgn_depth_realsense.dll     → links only realsense2.dll
    └── native/ultraleap/
          └── libgn_depth_ultraleap.dll     → links only LeapC.dll
```

Each backend is a **separate DLL** with its own `.gdextension`. If the user
has only a RealSense camera installed, only `libgn_depth_realsense.dll` loads.
The Azure Kinect and Ultraleap DLLs fail silently (vendor runtimes not on PATH).
The extension loads because `dependencies_any` sees `GNDepthRealSense` in ClassDB.

The GDScript helper discovers which backends are available at runtime:
```gdscript
# GNDepthSensorHelper finds loaded backends via ClassDB
static func get_backends() -> PackedStringArray:
    for backend_name in BACKEND_CLASSES:
        if ClassDB.class_exists(BACKEND_CLASSES[backend_name]):
            _backends.append(backend_name)
```

---

## Tier Details and User Setup

### Tier 4 — Vendor Runtime Setup (shipped editor)

These scenarios assume the user is running a **pre-built GONODES editor**.

#### Blackmagic (DeckLink)

1. Install [Blackmagic Desktop Video](https://www.blackmagic-design.com/support/) (free download)
   — this installs the DeckLink drivers and puts DLLs on PATH
2. Launch GONODES — `BlackmagicInIMG` and `BlackmagicOutIMG` appear in the palette
3. If not installed → operators show "DeckLink not available" warning

#### NDI

1. Install [NDI Tools](https://ndi.video/tools/) (free download)
   — includes `Processing.NDI.Lib.x64.dll` on PATH
2. Launch GONODES — `NDIInTOP` and `NDIOutTOP` appear
3. If not installed → extension skipped (dependencies check fails)

#### Depth Sensors

1. Install the vendor software for your sensor:
   - **Azure Kinect**: [Azure Kinect SDK](https://learn.microsoft.com/en-us/azure/kinect-dk/sensor-sdk-download)
     + [Body Tracking SDK](https://learn.microsoft.com/en-us/azure/kinect-dk/body-sdk-download)
   - **Intel RealSense**: [Intel RealSense SDK 2.0](https://github.com/IntelRealSense/librealsense/releases)
   - **Ultraleap**: [Ultraleap Gemini Tracking Software](https://developer.leapmotion.com/)
2. Launch GONODES — `DepthSensorIMG` and `DepthSensorDAT` appear if any one
   backend loaded
3. Only the backends whose vendor runtime is on PATH will appear in the
   "Device" dropdown

#### OpenCV

`python setup_deps.py` downloads the Windows SDK. On Linux and macOS, install
the distro package (`libopencv-dev` or `brew install opencv`). GitHub Actions
installs that package itself. Then build and launch — OpenCV operators appear.

#### Syphon (macOS only)

`python setup_deps.py` clones the Syphon Framework into
`addons/gn_ext_syphon/native/Syphon-Framework/`. Build the extension
(see [BUILD.md](BUILD.md)), then launch. `SyphonInTOP` and `SyphonOutTOP` appear.

### Tier 5 — SDK + Build From Source

#### ONNX Runtime (ML operators)

```bash
cd addons/gn_ext_ml
python setup_ml.py --sdk-only   # ONNX Runtime only. YOLOv8 weights are AGPL.
cd native && scons              # Builds the DLL
```

Then launch GONODES — ML operators appear. Export your own `.onnx` files for
the model nodes.

#### Python Scripting

A release download already contains the runtime. A from-source build fetches it with:

```bash
cd addons/gn_ext_user_python
python setup_python.py --bundle   # CPython 3.10 + NumPy, redistributable
cd native && scons                # Builds the DLL against that Python
```

---

## Shipped Editor vs Build From Source

### Shipped Editor (pre-built download)

What's included out of the box:

| Included | Extensions |
|----------|-----------|
| **Always works** | All Tier 1 (GDScript) + All Tier 2 (shipped DLLs) + Tier 3 (FFmpeg, WebRender) |
| **Works after vendor install** | Tier 4 — user installs free vendor software, operators auto-detect |
| **Included in the release** | Python nodes (CPython 3.10 + NumPy), downloaded at build time |
| **Not included** | ONNX Runtime and model weights — `setup_ml.py` |

The shipped editor includes:
- Core GONODES engine
- All GDScript extensions
- Pre-built DLLs for: native, hap, midi, spout, gpu_encode, video_capture, ffmpeg, webrender
- Pre-built DLLs for: blackmagic, ndi, depth_sensor (all three backends), opencv, syphon
  — these load only if vendor runtime is installed

### Build From Source

```bash
git clone https://github.com/user/gonodes.git
cd gonodes

# Build godot-cpp (required once)
cd addons/gn_ext_native/native/godot-cpp
scons target=template_release

# Build all extensions
cd ../../../../
python build/gn_build.py --all

# Or build a specific extension
cd addons/gn_ext_depth_sensor/native/ultraleap
scons
```

For extensions requiring external SDKs, place the SDK files in the expected
directory (see each extension's README.md) before building.

---

## Licensing Scenarios

### Scenario 1: Distributing GONODES as a free editor

| Component | License | Obligation |
|-----------|---------|-----------|
| GONODES core | MIT | Include copyright notice |
| godot-cpp / Godot | MIT | Include copyright notice |
| HAP, Snappy, Squish | BSD-2/BSD-3 | Include copyright notices |
| RtMidi | MIT | Include copyright notice |
| Spout2 | BSD-2 | Include copyright notice |
| EIRTeam.FFmpeg | MIT | Include copyright notice |
| FFmpeg libraries | **LGPL 2.1+** | Dynamic linking (done), source available on request, user can swap libraries |
| gdCEF / Chromium | MIT/BSD | Include copyright notices |

**All THIRD_PARTY_LICENSES files in each extension directory satisfy the notice
requirements.** The LGPL obligation for FFmpeg is met by shipping the `.dll`/`.so`
files as separate dynamic libraries (not statically linked).

### Scenario 2: User creates a commercial project with GONODES

GONODES is MIT — the user's project can be any license (commercial, proprietary,
etc.). The user must:
1. Include the MIT/BSD/LGPL copyright notices from THIRD_PARTY_LICENSES
2. If redistributing, allow end-users to swap FFmpeg shared libraries (LGPL)
3. Vendor SDKs (Blackmagic, NDI, Ultraleap, Azure Kinect) are the user's
   responsibility — they must comply with each vendor's redistribution terms

### Scenario 3: User wants to use a proprietary-SDK extension (e.g., NDI)

1. User downloads and installs the NDI SDK/Runtime (free, proprietary license)
2. GONODES auto-detects the runtime and enables NDI operators
3. The user's GONODES project can use NDI nodes to send/receive video
4. If the user **ships** their project, they must NOT bundle the NDI DLL — end
   users must install the NDI Runtime themselves (per NDI SDK license terms)

### Scenario 4: User wants depth sensor support

The user only needs to install the vendor software for their specific sensor:

- Has an Azure Kinect? Install Azure Kinect SDK → `azure_kinect` backend loads
- Has a RealSense? Install Intel RealSense SDK → `realsense` backend loads
- Has a Leap Motion? Install Ultraleap Tracking → `ultraleap` backend loads
- Has all three? All three backends load, all devices appear in the dropdown

No recompilation needed (for shipped editor). Each backend is a separate DLL
that depends only on its own vendor runtime.

### Scenario 5: User wants ML operators

1. Run `python addons/gn_ext_ml/setup_ml.py` to download:
   - ONNX Runtime (MIT — can redistribute freely)
   - Model weights (varies: MIT, Apache 2.0, **AGPL-3.0 for YOLOv8**)
2. Build: `cd addons/gn_ext_ml/native && scons`
3. **WARNING**: YOLOv8 model weights are AGPL-3.0. If the user ships a project
   using YOLOv8 detection, AGPL may require open-sourcing the entire project.
   Alternative: use a YOLOv8 model with a different license, or use MediaPipe
   (Apache 2.0) / MiDaS (MIT) operators instead.

---

## Extension Reference Table

| Extension | Tier | License | Ships In Editor | Vendor Install Needed | Build From Source |
|-----------|:----:|---------|:---:|:---:|:---:|
| gn_ext_isf | 1 | N/A | Yes | No | No |
| gn_ext_mapper | 1 | N/A | Yes | No | No |
| gn_ext_sdf | 1 | N/A | Yes | No | No |
| gn_ext_shadertoy | 1 | N/A | Yes | No | No |
| gn_ext_serial | 1 | N/A | Yes | No | No |
| gn_ext_native | 2 | MIT | Yes | No | No |
| gn_ext_hap | 2 | BSD | Yes | No | No |
| gn_ext_midi | 2 | MIT | Yes | No | No |
| gn_ext_spout | 2 | BSD-2 | Yes (Win) | No | No |
| gn_ext_gpu_encode | 2 | N/A | Yes (Win/Mac) | No | No |
| gn_ext_video_capture | 2 | N/A | Yes | No | No |
| gn_ext_ffmpeg | 3 | MIT + **LGPL** | Yes | No | No |
| gn_ext_webrender | 5 | MIT/BSD | Yes | No | `setup_cef.py` via `setup_deps.py` |
| gn_ext_blackmagic | 4 | Proprietary | Yes (our DLL) | DeckLink drivers | No |
| gn_ext_ndi | 4 | Proprietary | Yes (our DLL) | NDI Runtime | No |
| gn_ext_depth_sensor | 4 | Mixed | Yes (3 DLLs) | Sensor vendor SW | No |
| gn_ext_opencv | 5 | Apache 2.0 | Yes (our DLL) | OpenCV runtime | `setup_opencv.py` via `setup_deps.py` |
| gn_ext_syphon | 5 | BSD-3 | Yes (Mac) | Syphon Framework | cloned by `setup_deps.py` |
| gn_ext_ml | 5 | MIT + **AGPL** | No | ONNX Runtime | `setup_ml.py` + `scons` |
| gn_ext_user_python | 5 | PSF/BSD | Yes (release build) | No | `setup_python.py --bundle` |
| gn_ext_user_native | 5 | N/A | Yes (scaffold) | C++ compiler | User writes code |

---

## Detection Mechanisms Summary

| Mechanism | When Used | Effect |
|-----------|----------|--------|
| `.gdextension` → Godot DLL loader | Engine startup | Missing DLL → class not in ClassDB (silent) |
| `dependencies=["Class"]` in cfg | Extension registry load | ALL must exist → extension skipped if any missing |
| `dependencies_any=["A","B","C"]` in cfg | Extension registry load | AT LEAST ONE must exist → extension skipped if none found |
| `platforms=["windows"]` in cfg | Extension registry load | Wrong platform → extension skipped |
| `ClassDB.class_exists()` in operator .gd | Operator init / cook | Missing class → graceful fallback or warning |

These layers mean a user never sees a crash from missing libraries — only
warnings or absent operators in the palette.
