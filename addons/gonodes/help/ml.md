# Machine Learning

The ML operators run an ONNX model on an image. The operators and the ONNX Runtime library ship with GONODES. The weight files do not.

ONNX Runtime is not its own extension. `GNOnnxInference` is the loader inside `gn_ext_ml`. The seven operators use it through `GNMlSession`.

## Nothing to install for the nodes

A release editor already has the ML library. CPU is the provider that library can run. DirectML, CUDA, and CoreML are in the Provider menu, and a load with one of those selected fails on this CPU build. GPU runtimes are not part of the download.

## Weights you download

In a source checkout, this writes the permissive weights into `addons/gn_ext_ml/models/`:

```bash
python addons/gn_ext_ml/setup_ml.py --models-only
```

| File | Operator | License |
|------|----------|---------|
| `midas_v21_small_256.onnx` | DepthEstimateIMG | MIT |
| `style_mosaic.onnx` | StyleTransferIMG | BSD-3-Clause |
| `style_candy.onnx` | StyleTransferIMG | BSD-3-Clause |
| `style_udnie.onnx` | StyleTransferIMG | BSD-3-Clause |
| `style_rain_princess.onnx` | StyleTransferIMG | BSD-3-Clause |
| `style_pointilism.onnx` | StyleTransferIMG | BSD-3-Clause |

A new weight file does not need a rebuild. The folder is not in git, and a release export leaves it out. The running app does not download a weight by itself.

## Weights you supply

These operators cook only after you set Model to an ONNX file you already have:

| Operator | Why nothing is downloaded |
|----------|---------------------------|
| PoseDetectCHOP | Google does not publish BlazePose as ONNX |
| HandDetectCHOP | Google does not publish the hand landmarker as ONNX |
| FaceDetectCHOP | Google does not publish the face landmarker as ONNX |
| SegmentationIMG | Google does not publish the selfie segmenter as ONNX |
| ObjectDetectDAT | Ultralytics YOLOv8 weights are AGPL-3.0. The node still decodes a YOLO file you supply |

## A first patch

Style, from a webcam:

1. Add **WebcamIMG**.
2. Add **StyleTransferIMG** and connect the webcam to it. Style starts on Mosaic.
3. Add **ImgToTOP**, then **WindowOUT** at 512×512 with Open on.
4. Connect Style to ImgToTOP to the window.

Pose, hand, face, and object detection take an IMG, not a TOP. A TOP source goes through **TOPtoIMG** first. Pose then goes **PoseDetectCHOP** to **CHOPtoTOP** to **WindowOUT**. Object detection goes **ObjectDetectDAT** to **TextTOP** to **WindowOUT**.

Right-click a node and choose Help for a patch that already has that chain.
