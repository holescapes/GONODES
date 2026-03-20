"""
gonodes.params — Helpers for defining ports and parameters.

Port and param definitions are returned from get_port_definitions()
and get_param_definitions() as dicts. These helpers build those dicts.
"""


# ── Port builders ────────────────────────────────────────────

def port(name, family="SOP", direction="input", required=False, label=""):
    """Build a port definition dict.

    Args:
        name:      Port identifier (e.g. "in", "geo_out").
        family:    "SOP", "CHOP", "IMG", "TOP", "DAT".
        direction: "input" or "output".
        required:  Whether the input must be connected.
        label:     Human-readable label.
    """
    return {
        "name": str(name),
        "family": str(family).upper(),
        "direction": str(direction),
        "required": bool(required),
        "label": str(label) if label else str(name),
    }


def input_port(name, family="SOP", required=False, label=""):
    """Shortcut for an input port."""
    return port(name, family, "input", required, label)


def output_port(name, family="SOP", label=""):
    """Shortcut for an output port."""
    return port(name, family, "output", False, label)


# ── Parameter builders ───────────────────────────────────────

def param(name, type="float", default=0.0, min=0.0, max=1.0,
          step=0.01, label="", description="", options=None):
    """Build a parameter definition dict.

    Args:
        name:        Parameter identifier.
        type:        "float", "int", "bool", "string", "color", "enum", "vector2", "vector3".
        default:     Default value (type-appropriate).
        min, max:    Range bounds (float/int only).
        step:        Step increment (float only).
        label:       Human-readable label.
        description: Tooltip text.
        options:     List of strings (enum type only).
    """
    p = {
        "name": str(name),
        "type": str(type),
        "default": default,
        "label": str(label) if label else str(name).replace("_", " ").title(),
        "description": str(description),
    }
    if type in ("float", "int"):
        p["min"] = min
        p["max"] = max
        if type == "float":
            p["step"] = step
    if type == "enum" and options is not None:
        p["options"] = list(options)
    return p


def float_param(name, default=0.0, min=0.0, max=1.0, step=0.01,
                label="", description=""):
    """Shortcut for a float parameter."""
    return param(name, "float", default, min, max, step, label, description)


def int_param(name, default=0, min=0, max=100, label="", description=""):
    """Shortcut for an int parameter."""
    return param(name, "int", default, min, max, label=label,
                 description=description)


def bool_param(name, default=False, label="", description=""):
    """Shortcut for a bool parameter."""
    return param(name, "bool", default, label=label, description=description)


def string_param(name, default="", label="", description=""):
    """Shortcut for a string parameter."""
    return param(name, "string", default, label=label, description=description)


def color_param(name, default=None, label="", description=""):
    """Shortcut for a color parameter (RGBA dict)."""
    if default is None:
        default = {"r": 1.0, "g": 1.0, "b": 1.0, "a": 1.0}
    return param(name, "color", default, label=label, description=description)


def enum_param(name, options, default=0, label="", description=""):
    """Shortcut for an enum parameter."""
    return param(name, "enum", default, options=options, label=label,
                 description=description)
