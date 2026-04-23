"""
SDF Procedural Scene — Example: Full scene with booleans, modifiers, materials.

Demonstrates:
  - Building a complete SDF scene tree in Python
  - sdf_sphere, sdf_box, sdf_twist, sdf_smooth_union helpers
  - sdf_material for PBR properties
  - Connect output to RaymarchSDF → WindowOUT to visualize
"""

from gonodes.sdf import (
    make_sdf_result, sdf_sphere, sdf_box, sdf_twist,
    sdf_smooth_union, sdf_material,
)
from gonodes.params import output_port, float_param


def get_port_definitions():
    return {"ports": [
        output_port("out", "SDF", label="SDF scene"),
    ]}


def get_param_definitions():
    return {"params": [
        float_param("twist_amount", 2.0, 0.0, 20.0, 0.1, "Twist Amount",
                     "Twist around Y axis."),
        float_param("sphere_radius", 0.8, 0.1, 10.0, 0.01, "Sphere Radius"),
        float_param("box_size", 0.6, 0.1, 10.0, 0.01, "Box Size",
                     "Box half-size."),
        float_param("smoothness", 0.3, 0.0, 5.0, 0.01, "Smoothness",
                     "Smooth union blending."),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    twist = params.get("twist_amount", 2.0)
    sph_r = params.get("sphere_radius", 0.8)
    box_sz = params.get("box_size", 0.6)
    smooth = params.get("smoothness", 0.3)

    # Sphere → Material → Twist
    sphere = sdf_sphere(sph_r)
    mat_sphere = sdf_material(sphere,
                               albedo=(0.9, 0.2, 0.1),
                               roughness=0.3)
    twisted = sdf_twist(mat_sphere, twist)

    # Box with material
    box = sdf_box(size=(box_sz, box_sz, box_sz),
                  position=(1.5, 0.0, 0.0))
    mat_box = sdf_material(box,
                           albedo=(0.1, 0.3, 0.9),
                           roughness=0.6,
                           metallic=0.8)

    # Smooth union
    tree = sdf_smooth_union(twisted, mat_box, smooth)
    return make_sdf_result(tree)
