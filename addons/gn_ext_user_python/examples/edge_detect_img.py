"""
Edge Detect IMG — Example: Sobel edge detection.

Demonstrates:
  - Reading input image pixels as numpy (H, W, C) array
  - Per-pixel convolution (Sobel filter)
  - Outputting processed image via make_img_result
"""

from gonodes.img import make_img_result, get_input_image
from gonodes.params import input_port, output_port, float_param, bool_param
import numpy as np


def get_port_definitions():
    return {"ports": [
        input_port("in", "IMG", required=True, label="Input image"),
        output_port("out", "IMG", label="Edge-detected image"),
    ]}


def get_param_definitions():
    return {"params": [
        float_param("strength", 1.0, 0.1, 5.0, 0.1, "Strength",
                     "Edge detection sensitivity."),
        bool_param("grayscale", True, "Grayscale",
                    "Output grayscale edges."),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    result = get_input_image(inputs, 0)
    if result is None:
        return {}

    pixels, w, h, c = result
    strength = params.get("strength", 1.0)
    grayscale = params.get("grayscale", True)

    # Convert to float for processing
    img = pixels.astype(np.float32) / 255.0

    # Convert to luminance for edge detection
    if c >= 3:
        lum = img[:, :, 0] * 0.299 + img[:, :, 1] * 0.587 + img[:, :, 2] * 0.114
    else:
        lum = img[:, :, 0]

    # Sobel kernels (manual convolution — no scipy dependency)
    # Gx: horizontal edges, Gy: vertical edges
    gx = np.zeros_like(lum)
    gy = np.zeros_like(lum)

    # Apply 3x3 Sobel via shifted slicing (fast, no loops)
    gx[1:-1, 1:-1] = (
        -1 * lum[:-2, :-2] + 1 * lum[:-2, 2:]
        - 2 * lum[1:-1, :-2] + 2 * lum[1:-1, 2:]
        - 1 * lum[2:, :-2] + 1 * lum[2:, 2:]
    )
    gy[1:-1, 1:-1] = (
        -1 * lum[:-2, :-2] - 2 * lum[:-2, 1:-1] - 1 * lum[:-2, 2:]
        + 1 * lum[2:, :-2] + 2 * lum[2:, 1:-1] + 1 * lum[2:, 2:]
    )

    edges = np.sqrt(gx ** 2 + gy ** 2) * strength
    edges = np.clip(edges, 0.0, 1.0)

    # Build output
    out = np.zeros((h, w, 4), dtype=np.uint8)
    if grayscale:
        edge_u8 = (edges * 255).astype(np.uint8)
        out[:, :, 0] = edge_u8
        out[:, :, 1] = edge_u8
        out[:, :, 2] = edge_u8
    else:
        out[:, :, 0] = (np.abs(gx) * strength * 255).clip(0, 255).astype(np.uint8)
        out[:, :, 1] = (np.abs(gy) * strength * 255).clip(0, 255).astype(np.uint8)
        out[:, :, 2] = (edges * 255).astype(np.uint8)
    out[:, :, 3] = 255

    return make_img_result(out, w, h, 4)
