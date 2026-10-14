# gn_ext_ml — Machine Learning Bridge (ONNX Runtime)

**ML inference for GONODES** — body pose, hand tracking, face mesh, depth estimation, style transfer, segmentation, and object detection from pre-trained ONNX models.

## Operators

| Operator | Family | Description |
|----------|--------|-------------|
| **PoseDetectCHOP** | CHOP | Body pose estimation (BlazePose) — 33 keypoints as x/y/z/visibility channels |
| **HandDetectCHOP** | CHOP | Hand landmark tracking — 21 points per hand |
| **FaceDetectCHOP** | CHOP | Face mesh landmarks — 468 points (or key subset) |
| **DepthEstimateIMG** | IMG | Monocular depth estimation (MiDaS) — grayscale depth map |
| **StyleTransferIMG** | IMG | Fast neural style. Menu: Mosaic, Candy, Udnie, Rain Princess, Pointillism, or Custom |
| **SegmentationIMG** | IMG | Person/background segmentation — binary/soft mask |
| **ObjectDetectDAT** | DAT | YOLO table of boxes and labels. You supply the ONNX file |

Pose, hand, face, and object detection take an IMG. Put `TOPtoIMG` in front of a TOP source.

## What is included

The operators and the ONNX Runtime library are part of the build. No weight file is in git, and a release export leaves `addons/gn_ext_ml/models/` out. A new `.onnx` file does not require a rebuild.

`native/build.cfg` calls `setup_ml.py --sdk-only`. That is what `setup_deps.py` and CI run. It fetches the SDK and does not fetch weights.

## Weights

Permissive weights, downloaded only when you ask:

```bash
python addons/gn_ext_ml/setup_ml.py --models-only
```

That writes MiDaS (MIT) and the five Johnson styles (BSD-3-Clause) into `addons/gn_ext_ml/models/`.

These are never downloaded. Place the ONNX file on the operator's Model parameter:

| File the operator expects | Why it is not fetched |
|---------------------------|------------------------|
| `pose_landmark_lite.onnx` | Google does not publish BlazePose as ONNX |
| `hand_landmark_lite.onnx` | Google does not publish the hand landmarker as ONNX |
| `face_landmark.onnx` | Google does not publish the face landmarker as ONNX |
| `selfie_segmentation.onnx` | Google does not publish the selfie segmenter as ONNX |
| a YOLO file | Ultralytics YOLOv8 weights are AGPL-3.0 |

A from-source tree that wants the SDK and the permissive weights together can run `python addons/gn_ext_ml/setup_ml.py`, then `cd addons/gn_ext_ml/native && scons platform=<your_platform>`. `--version 1.19.2` selects the ONNX Runtime version. `--sdk-only` skips weights.

## Requirements (Manual Setup)

### ONNX Runtime SDK

1. Download ONNX Runtime from https://github.com/microsoft/onnxruntime/releases
   - Windows: `onnxruntime-win-x64-<version>.zip`
   - Linux: `onnxruntime-linux-x64-<version>.tgz`
   - macOS: `onnxruntime-osx-universal2-<version>.tgz`

2. Extract to `addons/gn_ext_ml/native/onnxruntime/`:
   ```
   addons/gn_ext_ml/native/onnxruntime/
   ├── include/
   │   ├── onnxruntime_c_api.h
   │   ├── onnxruntime_cxx_api.h
   │   └── ...
   └── lib/
       ├── x86_64-windows/
       │   └── onnxruntime.dll / onnxruntime.lib
       ├── x86_64-linux/
       │   └── libonnxruntime.so
       └── (macOS universal)
           └── libonnxruntime.dylib
   ```

3. Copy the runtime DLL/SO to the bin directory or ensure it's on the system PATH.

### ONNX Models

Download pre-trained ONNX models and place them in `addons/gn_ext_ml/models/`:

`setup_ml.py --models-only` downloads MiDaS and the five Johnson style models. The build does not run that step. It does not download MediaPipe or YOLO weights.

| Model File | Operator | Source | Fetched |
|-----------|----------|--------|---------|
| `midas_v21_small_256.onnx` | DepthEstimateIMG | MiDaS v2.1 Small (MIT) | yes |
| `style_mosaic.onnx` | StyleTransferIMG | Johnson fast style, Mosaic (BSD-3-Clause) | yes |
| `style_candy.onnx` | StyleTransferIMG | Johnson fast style, Candy (BSD-3-Clause) | yes |
| `style_udnie.onnx` | StyleTransferIMG | Johnson fast style, Udnie (BSD-3-Clause) | yes |
| `style_rain_princess.onnx` | StyleTransferIMG | Johnson fast style, Rain Princess (BSD-3-Clause) | yes |
| `style_pointilism.onnx` | StyleTransferIMG | Johnson fast style, Pointillism (BSD-3-Clause) | yes |
| `pose_landmark_lite.onnx` | PoseDetectCHOP | MediaPipe BlazePose | no — Google does not publish this as ONNX |
| `hand_landmark_lite.onnx` | HandDetectCHOP | MediaPipe Hands | no — convert it yourself |
| `face_landmark.onnx` | FaceDetectCHOP | MediaPipe Face Mesh | no — convert it yourself |
| `selfie_segmentation.onnx` | SegmentationIMG | MediaPipe Selfie | no — convert it yourself |
| `yolov8n.onnx` | ObjectDetectDAT | a YOLO file you supply | no — Ultralytics YOLOv8 weights are AGPL-3.0 |

The style files come from the Hugging Face `onnxmodelzoo` repos (`mosaic-9`, `candy-9`, `udnie-9`, `rain-princess-9`, `pointilism-9`). The ONNX Model Zoo Git LFS files were retired. The built-in styles are 224x224. Custom uses the spatial size declared in the file, and 224 when that size is dynamic. The other styles ignore the model path.

The build copies `onnxruntime.dll` next to the extension library. Windows otherwise loads an older `onnxruntime.dll` from `System32`, and inference crashes.

MiDaS: https://github.com/isl-org/MiDaS/releases

ObjectDetectDAT still decodes the YOLOv8 output layout. Point Model at an ONNX file you are allowed to use. This extension does not ship or download Ultralytics weights.

## Building

```bash
cd addons/gn_ext_ml/native
scons platform=windows   # or linux / macos
```

The build system uses the shared GONODES `build/gn_build.py` orchestrator. See `dev_docs/BUILD.md` for details.

## Execution Providers

All operators have a **Provider** parameter:

| Provider | Platform | GPU Acceleration |
|----------|----------|-----------------|
| CPU | All | No (default, always works) |
| DirectML | Windows | Yes (any DirectX 12 GPU) |
| CUDA | Windows/Linux | Yes (NVIDIA GPUs, requires CUDA toolkit) |
| CoreML | macOS | Yes (Apple Neural Engine / GPU) |

Changing Provider reloads the model. If DirectML, CUDA, or CoreML cannot attach, the load fails and the operator reports that error. It does not silently run on CPU.

## Architecture

```
GNOnnxInference (C++ GDExtension, RefCounted)
    │  one process-wide Ort::Env
    │  res:// and user:// are globalized; project:// joins the project directory
    │
    ▼
GNMlSession (GDScript RefCounted, next to the operators)
    │  begin / run_image / run_image_normalized
    │
    ▼
Operators keep their own decode
    ├── PoseDetectCHOP    — BlazePose → 33 keypoint channels
    ├── HandDetectCHOP    — Hand landmarks → 21 point channels
    ├── FaceDetectCHOP    — Face mesh → 468 landmark channels
    ├── DepthEstimateIMG  — MiDaS → depth map
    ├── StyleTransferIMG  — Johnson style menu → stylized image
    ├── SegmentationIMG   — Selfie seg → mask
    └── ObjectDetectDAT   — YOLO layout → detection table
```

`GNOnnxInference` is the loader. `GNMlSession` holds one loader for an operator. A later AI job can hold a `GNMlSession`. It does not subclass it. Keypoint names, YOLO decode, and image reconstruction stay in the operator scripts.
