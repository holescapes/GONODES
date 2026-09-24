# gn_ext_ml — Machine Learning Bridge (ONNX Runtime)

**ML inference for GONODES** — body pose, hand tracking, face mesh, depth estimation, style transfer, segmentation, and object detection from pre-trained ONNX models.

## Operators

| Operator | Family | Description |
|----------|--------|-------------|
| **PoseDetectCHOP** | CHOP | Body pose estimation (BlazePose) — 33 keypoints as x/y/z/visibility channels |
| **HandDetectCHOP** | CHOP | Hand landmark tracking — 21 points per hand |
| **FaceDetectCHOP** | CHOP | Face mesh landmarks — 468 points (or key subset) |
| **DepthEstimateIMG** | IMG | Monocular depth estimation (MiDaS) — grayscale depth map |
| **StyleTransferIMG** | IMG | Neural style transfer — apply artistic styles to textures |
| **SegmentationIMG** | IMG | Person/background segmentation — binary/soft mask |
| **ObjectDetectDAT** | DAT | Object detection (YOLOv8) — table of bounding boxes + labels |

## Quick Setup (Recommended)

Run the automated setup script to download the ONNX Runtime SDK and all
pre-trained models in one step:

```bash
python addons/gn_ext_ml/setup_ml.py
```

Options:
- `--sdk-only` — download SDK only, skip models
- `--models-only` — download models only, skip SDK
- `--version 1.19.2` — use a specific ONNX Runtime version

After setup, build: `cd addons/gn_ext_ml/native && scons platform=<your_platform>`

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

| Model File | Operator | Source | Size |
|-----------|----------|--------|------|
| `pose_landmark_lite.onnx` | PoseDetectCHOP | MediaPipe BlazePose | ~12 MB |
| `hand_landmark_lite.onnx` | HandDetectCHOP | MediaPipe Hands | ~4 MB |
| `face_landmark.onnx` | FaceDetectCHOP | MediaPipe Face Mesh | ~4 MB |
| `midas_v21_small_256.onnx` | DepthEstimateIMG | MiDaS v2.1 Small | ~25 MB |
| `style_mosaic.onnx` | StyleTransferIMG | Fast Neural Style | ~7 MB |
| `style_candy.onnx` | StyleTransferIMG | Fast Neural Style | ~7 MB |
| `style_udnie.onnx` | StyleTransferIMG | Fast Neural Style | ~7 MB |
| `selfie_segmentation.onnx` | SegmentationIMG | MediaPipe Selfie | ~2 MB |
| `yolov8n.onnx` | ObjectDetectDAT | Ultralytics YOLOv8n | ~12 MB |

**Model sources:**
- MediaPipe: https://github.com/google-ai-edge/mediapipe (export to ONNX via tf2onnx)
- MiDaS: https://github.com/isl-org/MiDaS/releases
- Fast Neural Style: https://github.com/onnx/models/tree/main/validated/vision/style_transfer
- YOLOv8: `pip install ultralytics && yolo export model=yolov8n.pt format=onnx`
- Selfie Segmentation: https://github.com/google-ai-edge/mediapipe

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

Set the provider **before** loading a model — it configures the ONNX Runtime session options.

## Architecture

```
GNOnnxInference (C++ GDExtension, RefCounted)
    │
    ├── load_model(path)           — Load any ONNX model
    ├── set_input_from_image()     — Auto-resize + NCHW + normalize
    ├── run()                      — Execute inference
    └── get_output_float/int()     — Read output tensors
    │
    ▼
GDScript Operators (model-specific pre/post processing)
    ├── PoseDetectCHOP    — BlazePose → 33 keypoint channels
    ├── HandDetectCHOP    — Hand landmarks → 21 point channels
    ├── FaceDetectCHOP    — Face mesh → 468 landmark channels
    ├── DepthEstimateIMG  — MiDaS → depth map texture
    ├── StyleTransferIMG  — Style model → stylized texture
    ├── SegmentationIMG   — Selfie seg → mask texture
    └── ObjectDetectDAT   — YOLOv8 → detection table
```

The C++ layer is a single generic `GNOnnxInference` class. All model-specific logic (keypoint naming, output parsing, image reconstruction) lives in GDScript — making it easy to add new ML operators without recompiling the extension.
