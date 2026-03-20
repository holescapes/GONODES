"""
Wave Deform SOP — Example: Animated sine-wave vertex deformation.

Demonstrates:
  - Reading input geometry (positions as numpy array)
  - Vectorized per-vertex math with NumPy
  - Time-based animation using context["elapsed"]
  - Custom parameters (amplitude, frequency, speed)
"""

from gonodes.sop import make_sop_result, get_input_positions, get_input_normals
from gonodes.params import input_port, output_port, float_param
import numpy as np


def get_port_definitions():
    return {"ports": [
        input_port("geo_in", "SOP", required=True, label="Input geometry"),
        output_port("geo_out", "SOP", label="Deformed geometry"),
    ]}


def get_param_definitions():
    return {"params": [
        float_param("amplitude", 0.5, 0.0, 5.0, 0.01, "Amplitude",
                     "Wave height."),
        float_param("frequency", 3.0, 0.1, 20.0, 0.1, "Frequency",
                     "Spatial frequency of the wave."),
        float_param("speed", 2.0, 0.0, 10.0, 0.1, "Speed",
                     "Animation speed."),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    positions = get_input_positions(inputs, 0)
    if positions is None:
        return {}

    amp = params.get("amplitude", 0.5)
    freq = params.get("frequency", 3.0)
    speed = params.get("speed", 2.0)
    t = context.get("elapsed", 0.0)

    # Vectorized wave deformation — operates on all vertices at once
    positions[:, 1] += np.sin(positions[:, 0] * freq + t * speed) * amp
    positions[:, 1] += np.cos(positions[:, 2] * freq * 0.7 + t * speed * 0.5) * amp * 0.5

    normals = get_input_normals(inputs, 0)
    return make_sop_result(positions, normals=normals)
