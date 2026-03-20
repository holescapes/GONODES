"""
gonodes.img — IMG family helpers.

Builds result dicts for CPU-side image processing.
Image pixel data is passed as a flat uint8 or float32 numpy array.
"""

import numpy as np


def make_img_result(pixels, width, height, channels=4, format="RGBA8"):
    """Build an image result dictionary.

    Args:
        pixels:   ndarray — pixel data. For RGBA8: uint8 (H, W, 4).
                  For RGBAF: float32 (H, W, 4).
        width:    Image width.
        height:   Image height.
        channels: Number of channels (3=RGB, 4=RGBA).
        format:   "RGBA8" or "RGBAF".

    Returns:
        dict ready for the C++ bridge.
    """
    if format == "RGBAF":
        flat = np.ascontiguousarray(pixels, dtype=np.float32).ravel()
    else:
        flat = np.ascontiguousarray(pixels, dtype=np.uint8).ravel()

    return {
        "pixels": flat,
        "width": int(width),
        "height": int(height),
        "channels": int(channels),
        "format": format,
    }


def get_input_image(inputs, index=0):
    """Extract input image as (H, W, C) ndarray.

    Returns:
        tuple(ndarray, width, height, channels) or None.
    """
    if index >= len(inputs) or inputs[index] is None:
        return None
    d = inputs[index]
    if "pixels" not in d:
        return None
    width = d.get("width", 0)
    height = d.get("height", 0)
    channels = d.get("channels", 4)
    fmt = d.get("format", "RGBA8")

    if fmt == "RGBAF":
        pixels = np.asarray(d["pixels"], dtype=np.float32)
    else:
        pixels = np.asarray(d["pixels"], dtype=np.uint8)

    return pixels.reshape(height, width, channels), width, height, channels
