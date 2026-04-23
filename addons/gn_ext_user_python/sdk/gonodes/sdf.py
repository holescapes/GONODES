"""
gonodes.sdf — SDF (Signed Distance Field) family helpers.

SDF operators pass an AST (Abstract Syntax Tree) between each other.
Each tree node is a dict::

    {
        "op":       str,    # "sphere", "box", "union", "twist", etc.
        "params":   dict,   # op-specific parameters
        "children": list,   # child SDF tree dicts (for booleans/modifiers)
        "material": dict,   # optional PBR: albedo, roughness, metallic, emission
    }

The final RaymarchSDF operator compiles this AST into GLSL for rendering.

Available primitive ops:
    sphere, box, torus, cylinder, capsule, plane, cone,
    pyramid, octahedron, gyroid

Available boolean ops (expect 2 children):
    union, intersection, subtract, smooth_union, smooth_subtract

Available modifier ops (expect 1 child):
    repeat, mirror, twist, bend, elongate, round, onion, displace
"""


# ─── Tree Construction ───────────────────────────────────────────────────────

def make_sdf_node(op, params=None, children=None, material=None):
    """Build an SDF tree node.

    Args:
        op:       Operator name (e.g. "sphere", "union", "twist").
        params:   Dict of op-specific parameters.
        children: List of child SDF tree dicts.
        material: Optional PBR material dict.

    Returns:
        dict — SDF tree node.
    """
    node = {"op": op, "params": params or {}, "children": children or []}
    if material:
        node["material"] = material
    return node


def make_sdf_result(sdf_tree):
    """Wrap an SDF tree dict into the result format for cook().

    Args:
        sdf_tree: The root SDF tree node dict.

    Returns:
        dict ready for the C++ bridge.
    """
    return {"sdf_tree": sdf_tree, "tree_hash": hash(str(sdf_tree))}


# ─── Primitive Helpers ────────────────────────────────────────────────────────

def sdf_sphere(radius=1.0, position=(0, 0, 0)):
    """Sphere primitive."""
    return make_sdf_node("sphere", {
        "radius": float(radius),
        "position": {"x": float(position[0]), "y": float(position[1]),
                      "z": float(position[2])},
    })


def sdf_box(size=(1, 1, 1), position=(0, 0, 0)):
    """Box primitive."""
    return make_sdf_node("box", {
        "size": {"x": float(size[0]), "y": float(size[1]), "z": float(size[2])},
        "position": {"x": float(position[0]), "y": float(position[1]),
                      "z": float(position[2])},
    })


def sdf_torus(major_radius=1.0, minor_radius=0.3, position=(0, 0, 0)):
    """Torus primitive."""
    return make_sdf_node("torus", {
        "major_radius": float(major_radius),
        "minor_radius": float(minor_radius),
        "position": {"x": float(position[0]), "y": float(position[1]),
                      "z": float(position[2])},
    })


def sdf_cylinder(radius=0.5, height=2.0, position=(0, 0, 0)):
    """Cylinder primitive."""
    return make_sdf_node("cylinder", {
        "radius": float(radius),
        "height": float(height),
        "position": {"x": float(position[0]), "y": float(position[1]),
                      "z": float(position[2])},
    })


# ─── Boolean Helpers ─────────────────────────────────────────────────────────

def sdf_union(a, b):
    """Union of two SDF trees."""
    return make_sdf_node("union", {}, [a, b])


def sdf_smooth_union(a, b, smoothness=0.5):
    """Smooth union of two SDF trees."""
    return make_sdf_node("smooth_union", {"smoothness": float(smoothness)}, [a, b])


def sdf_subtract(a, b):
    """Subtraction: a minus b."""
    return make_sdf_node("subtract", {}, [a, b])


def sdf_intersection(a, b):
    """Intersection of two SDF trees."""
    return make_sdf_node("intersection", {}, [a, b])


# ─── Modifier Helpers ────────────────────────────────────────────────────────

def sdf_twist(child, amount=1.0):
    """Twist modifier around Y axis."""
    return make_sdf_node("twist", {"amount": float(amount)}, [child])


def sdf_repeat(child, spacing=(3, 3, 3)):
    """Repeat in 3D space."""
    return make_sdf_node("repeat", {
        "spacing": {"x": float(spacing[0]), "y": float(spacing[1]),
                     "z": float(spacing[2])},
    }, [child])


def sdf_mirror(child, x=True, y=False, z=False):
    """Mirror across axes."""
    return make_sdf_node("mirror", {
        "mirror_x": bool(x), "mirror_y": bool(y), "mirror_z": bool(z),
    }, [child])


def sdf_round(child, radius=0.1):
    """Round edges."""
    return make_sdf_node("round", {"radius": float(radius)}, [child])


# ─── Material Helpers ────────────────────────────────────────────────────────

def sdf_material(child, albedo=(0.8, 0.8, 0.8), roughness=0.5, metallic=0.0,
                 emission=0.0):
    """Apply PBR material to an SDF tree node.

    Returns a deep copy of child with material properties attached.
    """
    import copy
    result = copy.deepcopy(child)
    result["material"] = {
        "albedo": {"r": float(albedo[0]), "g": float(albedo[1]),
                    "b": float(albedo[2])},
        "roughness": float(roughness),
        "metallic": float(metallic),
        "emission": float(emission),
    }
    return result


# ─── Input Helpers ────────────────────────────────────────────────────────────

def get_input_sdf(inputs, index=0):
    """Extract an input SDF tree dict, or None if not available."""
    if index >= len(inputs) or inputs[index] is None:
        return None
    d = inputs[index]
    if not isinstance(d, dict) or "sdf_tree" not in d:
        return None
    return d["sdf_tree"]


def has_input_sdf(inputs, index=0):
    """Check whether an input SDF is connected and non-empty."""
    tree = get_input_sdf(inputs, index)
    return tree is not None and len(tree) > 0
