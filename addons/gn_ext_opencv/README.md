# gn_ext_opencv — OpenCV Computer Vision Extension

20 purpose-built computer-vision operators powered by OpenCV 4.x (Apache 2.0).
All image-processing operators live in the **IMG** family (CPU-side `Image` data)
to match the native Image pipeline. Companion CHOP/DAT operators output
structured numeric or tabular data from the CV results.

Requires the `GNOpenCV` GDExtension (`native/` directory).

## Operators

### Tier 1 — Installation Essentials

| Operator | Family | Description |
|----------|--------|-------------|
| ThresholdIMG | IMG | Binary / Otsu / adaptive Gaussian-mean thresholding |
| MorphIMG | IMG | Erode, dilate, open, close, gradient, top-hat, black-hat |
| BlobTrackIMG | IMG | Blob detection with persistent ID tracking across frames |
| BackgroundSubtractIMG | IMG | Adaptive background model (MOG2 / KNN) foreground mask |
| ContourIMG | IMG | Find and draw contours on a binary / thresholded image |

### Tier 2 — Motion & Tracking

| Operator | Family | Description |
|----------|--------|-------------|
| OpticalFlowIMG | IMG | Dense Farneback optical flow — RG motion field |
| ColorTrackIMG | IMG | Track a color range in HSV space — binary mask output |
| ObjectTrackIMG | IMG | Single-object visual tracker (KCF / CSRT / MOSSE) |

### Tier 3 — Geometry Detection

| Operator | Family | Description |
|----------|--------|-------------|
| HoughLinesIMG | IMG | Probabilistic Hough line detection + drawn overlay |
| HoughCirclesIMG | IMG | Hough circle detection + drawn overlay |
| ConvolveIMG | IMG | Arbitrary NxN kernel convolution |

### Tier 4 — Calibration & Projection Mapping

| Operator | Family | Description |
|----------|--------|-------------|
| CameraCalibDAT | DAT | Chessboard / circle-grid intrinsics calibration |
| CameraUndistortIMG | IMG | Lens undistortion from calibration data |
| PerspectiveWarpIMG | IMG | 4-point homography warp |

### Tier 5 — Markers & Recognition

| Operator | Family | Description |
|----------|--------|-------------|
| ArucoDetectIMG | IMG | ArUco / AprilTag fiducial marker detection + overlay |
| ArucoPoseDAT | DAT | 3D pose estimation from ArUco markers + calibration |
| QRCodeDAT | DAT | QR / barcode detection and decoding |
| FeatureMatchIMG | IMG | Keypoint matching (ORB / SIFT / AKAZE) between two images |

### Tier 6 — Utility

| Operator | Family | Description |
|----------|--------|-------------|
| StereoDepthIMG | IMG | Depth map from stereo image pair (left / right cameras) |
| DrawOverlayIMG | IMG | Overlay bounding boxes, text, polylines, circles, crosshairs |

### Companion CHOP

| Operator | Family | Description |
|----------|--------|-------------|
| BlobTrackCHOP | CHOP | id, cx, cy, area, width, height channels per blob |

## Architecture

- All GDScript operators delegate heavy lifting to the C++ `GNOpenCV` bridge
  class via `ClassDB.instantiate(&"GNOpenCV")`.
- Static helper: `GNOpenCVHelper` — availability check, `Image` ↔ RGBA
  conversion, instance caching.
- No GPU / CUDA dependency — fully CPU. For GPU-accelerated flow, use ISF /
  compute-shader approaches.

## Requirements

- **GNOpenCV GDExtension**: Native C++ library wrapping OpenCV 4.x functions
- **Platforms**: Windows, macOS, Linux

## OpenCV SDK Setup

The OpenCV library is licensed under **Apache 2.0** and is **not** bundled in
GONODES. You must obtain it separately.

### Windows

1. Download **OpenCV 4.10.0** (or compatible 4.x) from
   <https://opencv.org/releases/>
2. Run the self-extracting archive — it creates an `opencv/` folder.
3. Copy the SDK files into this extension:
   ```
   addons/gn_ext_opencv/native/
   └── opencv_sdk/
       └── opencv/
           └── build/
               ├── include/
               │   └── opencv2/  (headers)
               └── x64/
                   └── vc16/
                       └── lib/
                           └── opencv_world4100.lib
   ```
4. Copy the runtime DLL to the bin directory:
   ```
   addons/gn_ext_opencv/native/bin/win64/
   └── opencv_world4100.dll
   ```

### Linux

Install the development packages via your package manager:

```bash
# Ubuntu / Debian
sudo apt install libopencv-dev

# Fedora
sudo dnf install opencv-devel
```

No SDK files need to be placed manually — the system libraries are linked
directly.

### macOS

Install via Homebrew:

```bash
brew install opencv
```

### Build

```bash
cd addons/gn_ext_opencv/native
scons platform=windows   # or linux / macos
```
