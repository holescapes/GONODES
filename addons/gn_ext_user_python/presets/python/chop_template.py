"""CHOP Template — Minimal channel generator."""

from gonodes.chop import make_chop_result
from gonodes.params import output_port, float_param
import numpy as np


def get_port_definitions():
    return {"ports": [
        output_port("out", "CHOP", label="Output channels"),
    ]}


def get_param_definitions():
    return {"params": [
        float_param("value", 0.0, -10.0, 10.0, 0.01, "Value"),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    val = params.get("value", 0.0)
    channels = {"ch0": np.array([val], dtype=np.float32)}
    return make_chop_result(channels)
