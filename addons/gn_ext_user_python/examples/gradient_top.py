"""
Gradient TOP — Example: Animated gradient texture generation.

Demonstrates:
  - Generating textures from scratch with NumPy
  - Resolution parameters
  - Time-based animation
  - Color interpolation
"""

from gonodes.top import make_top_result
from gonodes.params import output_port, int_param, float_param, enum_param
import numpy as np


def get_port_definitions():
    return {"ports": [
        output_port("out", "TOP", label="Gradient texture"),
    ]}


def get_param_definitions():
    return {"params": [
        int_param("width", 512, 1, 4096, "Width"),
        int_param("height", 512, 1, 4096, "Height"),
        enum_param("direction", ["horizontal", "vertical", "radial", "angular"],
                    0, "Direction"),
        float_param("speed", 1.0, 0.0, 10.0, 0.01, "Speed"),
        float_param("offset", 0.0, 0.0, 1.0, 0.01, "Offset"),
    ]}


_DIRECTIONS = ["horizontal", "vertical", "radial", "angular"]


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    w = int(params.get("width", 512))
    h = int(params.get("height", 512))
    dir_idx = int(params.get("direction", 0))
    direction = _DIRECTIONS[dir_idx] if dir_idx < len(_DIRECTIONS) else "horizontal"
    speed = params.get("speed", 1.0)
    offset = params.get("offset", 0.0)
    t = context.get("elapsed", 0.0)

    anim_offset = (t * speed + offset) % 1.0

    y = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    x = np.linspace(0, 1, w, dtype=np.float32)[None, :]

    if direction == "horizontal":
        grad = (x + anim_offset) % 1.0
    elif direction == "vertical":
        grad = (y + anim_offset) % 1.0
    elif direction == "radial":
        cx, cy = 0.5, 0.5
        grad = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) * 2.0
        grad = (grad + anim_offset) % 1.0
    elif direction == "angular":
        cx, cy = 0.5, 0.5
        grad = (np.arctan2(y - cy, x - cx) / (2.0 * np.pi) + 0.5 + anim_offset) % 1.0
    else:
        grad = x

    # Map gradient to a warm colour ramp
    pixels = np.zeros((h, w, 4), dtype=np.uint8)
    pixels[:, :, 0] = (grad * 255).astype(np.uint8)
    pixels[:, :, 1] = ((1.0 - grad) * 180).astype(np.uint8)
    pixels[:, :, 2] = ((np.sin(grad * np.pi) * 200)).astype(np.uint8)
    pixels[:, :, 3] = 255

    return make_top_result(pixels, w, h)
