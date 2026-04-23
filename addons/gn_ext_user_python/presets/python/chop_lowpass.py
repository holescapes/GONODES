"""
Lowpass Filter CHOP — Example: Stateful IIR smoothing.

Demonstrates:
  - Reading input CHOP channels with get_input_channel()
  - Persistent state via `me` dict across cook calls
  - setup() for state initialization
  - IIR lowpass: y[n] = alpha * x[n] + (1-alpha) * y[n-1]
"""

from gonodes.chop import make_chop_result, get_input_channel
from gonodes.params import input_port, output_port, float_param, bool_param
import numpy as np


def get_port_definitions():
    return {"ports": [
        input_port("in", "CHOP", required=True, label="Input channels"),
        output_port("out", "CHOP", label="Filtered channels"),
    ]}


def get_param_definitions():
    return {"params": [
        float_param("cutoff", 5.0, 0.01, 100.0, 0.01, "Cutoff",
                     "Cutoff frequency in Hz. Lower = smoother."),
        bool_param("reset", False, "Reset", "Clear filter state."),
    ]}


def setup(me, context):
    me["_prev"] = {}


def cook(me, params, inputs, context):
    cutoff = params.get("cutoff", 5.0)
    reset = params.get("reset", False)
    dt = context.get("dt", 1.0 / 60.0)

    if "_prev" not in me or reset:
        me["_prev"] = {}
    prev = me["_prev"]

    # IIR coefficient: alpha = dt / (RC + dt), RC = 1/(2*pi*cutoff)
    rc = 1.0 / (2.0 * np.pi * max(cutoff, 0.001))
    alpha = dt / (rc + dt)

    if len(inputs) == 0 or inputs[0] is None:
        return {}

    in_data = inputs[0]
    if not isinstance(in_data, dict) or "channels" not in in_data:
        return {}

    in_channels = in_data["channels"]
    out_channels = {}

    for name, samples in in_channels.items():
        arr = np.asarray(samples, dtype=np.float32)
        length = len(arr)

        if name not in prev or len(prev[name]) != length:
            prev[name] = arr.copy()

        prev_arr = prev[name]
        filtered = alpha * arr + (1.0 - alpha) * prev_arr
        prev[name] = filtered.copy()
        out_channels[name] = filtered

    return make_chop_result(out_channels)
