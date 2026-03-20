"""IMG Template — Minimal image processor."""

from gonodes.img import make_img_result, get_input_image
from gonodes.params import input_port, output_port
import numpy as np


def get_port_definitions():
    return {"ports": [
        input_port("in", "IMG", label="Input image"),
        output_port("out", "IMG", label="Output image"),
    ]}


def get_param_definitions():
    return {"params": []}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    result = get_input_image(inputs, 0)
    if result is None:
        return {}

    pixels, w, h, c = result
    # Pass through — modify pixels here
    return make_img_result(pixels, w, h, c)
