"""
SDF Sphere — Example: Generate an SDF sphere primitive.

Demonstrates:
  - SDF output port declaration
  - Building SDF tree dict with make_sdf_result()
  - sdf_sphere() convenience helper
  - Connect output to RaymarchSDF → WindowOUT to visualize
"""

from gonodes.sdf import make_sdf_result, sdf_sphere
from gonodes.params import output_port, float_param


def get_port_definitions():
    return {"ports": [
        output_port("out", "SDF", label="SDF sphere"),
    ]}


def get_param_definitions():
    return {"params": [
        float_param("radius", 1.0, 0.01, 100.0, 0.01, "Radius", "Sphere radius."),
        float_param("pos_x", 0.0, -100.0, 100.0, 0.01, "Position X"),
        float_param("pos_y", 0.0, -100.0, 100.0, 0.01, "Position Y"),
        float_param("pos_z", 0.0, -100.0, 100.0, 0.01, "Position Z"),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    radius = params.get("radius", 1.0)
    pos = (params.get("pos_x", 0.0), params.get("pos_y", 0.0), params.get("pos_z", 0.0))
    tree = sdf_sphere(radius, pos)
    return make_sdf_result(tree)
