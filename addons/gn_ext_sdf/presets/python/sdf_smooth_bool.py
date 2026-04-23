"""
SDF Smooth Boolean — Example: Smooth-union two SDF inputs.

Demonstrates:
  - SDF input and output port declarations
  - Reading SDF input trees with get_input_sdf()
  - sdf_smooth_union() helper
"""

from gonodes.sdf import make_sdf_result, sdf_smooth_union, get_input_sdf
from gonodes.params import input_port, output_port, float_param


def get_port_definitions():
    return {"ports": [
        input_port("sdf_a", "SDF", required=False, label="First SDF shape"),
        input_port("sdf_b", "SDF", required=False, label="Second SDF shape"),
        output_port("out", "SDF", label="Combined SDF"),
    ]}


def get_param_definitions():
    return {"params": [
        float_param("smoothness", 0.5, 0.0, 10.0, 0.01, "Smoothness",
                     "Blending radius for smooth union."),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    smoothness = params.get("smoothness", 0.5)

    a = get_input_sdf(inputs, 0)
    b = get_input_sdf(inputs, 1)

    if a is None and b is None:
        return {}
    if a is None:
        return make_sdf_result(b)
    if b is None:
        return make_sdf_result(a)

    tree = sdf_smooth_union(a, b, smoothness)
    return make_sdf_result(tree)
