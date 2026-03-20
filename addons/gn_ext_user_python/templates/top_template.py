"""TOP Template — Minimal texture generator."""

from gonodes.top import make_top_result
from gonodes.params import output_port, int_param
import numpy as np


def get_port_definitions():
    return {"ports": [
        output_port("out", "TOP", label="Output texture"),
    ]}


def get_param_definitions():
    return {"params": [
        int_param("width", 256, 1, 4096, "Width"),
        int_param("height", 256, 1, 4096, "Height"),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    w = int(params.get("width", 256))
    h = int(params.get("height", 256))

    pixels = np.zeros((h, w, 4), dtype=np.uint8)
    pixels[:, :, 3] = 255  # opaque black
    # Generate your texture here

    return make_top_result(pixels, w, h)
