"""
gonodes.top — TOP family helpers.

TOPs in Python receive/produce image data as pixel arrays.
For GPU-only shader work, use the GLSL TOP operators instead.
These helpers are for CPU-side texture generation passed back to TOP.
"""

import numpy as np


def make_top_result(pixels, width, height, channels=4, format="RGBA8"):
    """Build a TOP result from CPU-generated pixel data.

    Args:
        pixels:   ndarray — pixel data (H, W, C) uint8 or float32.
        width:    Texture width.
        height:   Texture height.
        channels: Channels (3=RGB, 4=RGBA).
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
