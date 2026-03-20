"""SOP Template — Minimal geometry processor."""

from gonodes.sop import make_sop_result, get_input_positions
from gonodes.params import input_port, output_port, float_param
import numpy as np


def get_port_definitions():
    return {"ports": [
        input_port("in", "SOP", label="Input geometry"),
        output_port("out", "SOP", label="Output geometry"),
    ]}


def get_param_definitions():
    return {"params": [
        float_param("scale", 1.0, 0.0, 10.0, 0.01, "Scale"),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    positions = get_input_positions(inputs, 0)
    if positions is None:
        return {}

    scale = params.get("scale", 1.0)
    positions *= scale

    return make_sop_result(positions)
