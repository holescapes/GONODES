"""
gonodes.sop — SOP family helpers.

Builds result dicts that the C++ bridge converts back to GNGeoData.
"""

import numpy as np


def make_sop_result(positions, normals=None, uvs=None, colors=None,
                    indices=None, primitive=3):
    """Build a geometry result dictionary.

    Args:
        positions: ndarray (N,3) float32 — vertex positions.
        normals:   ndarray (N,3) float32 or None.
        uvs:       ndarray (N,2) float32 or None.
        colors:    ndarray (N,4) float32 [RGBA 0-1] or None.
        indices:   ndarray int32 or None.
        primitive: Mesh.PrimitiveType int (3 = TRIANGLES, 1 = LINES, 0 = POINTS).

    Returns:
        dict ready for the C++ bridge.
    """
    result = {
        "positions": np.ascontiguousarray(positions, dtype=np.float32).ravel(),
        "primitive": int(primitive),
    }
    if normals is not None:
        result["normals"] = np.ascontiguousarray(normals, dtype=np.float32).ravel()
    if uvs is not None:
        result["uvs"] = np.ascontiguousarray(uvs, dtype=np.float32).ravel()
    if colors is not None:
        result["colors"] = np.ascontiguousarray(colors, dtype=np.float32).ravel()
    if indices is not None:
        result["indices"] = np.ascontiguousarray(indices, dtype=np.int32).ravel()
    return result


def make_point_cloud(positions, colors=None):
    """Convenience for point clouds (primitive = POINTS)."""
    return make_sop_result(positions, colors=colors, primitive=0)


def get_input_positions(inputs, index=0):
    """Extract positions as (N,3) ndarray from input dict."""
    if index >= len(inputs) or inputs[index] is None:
        return None
    d = inputs[index]
    if "positions" not in d:
        return None
    flat = np.asarray(d["positions"], dtype=np.float32)
    return flat.reshape(-1, 3)


def get_input_normals(inputs, index=0):
    """Extract normals as (N,3) ndarray from input dict."""
    if index >= len(inputs) or inputs[index] is None:
        return None
    d = inputs[index]
    if "normals" not in d:
        return None
    flat = np.asarray(d["normals"], dtype=np.float32)
    return flat.reshape(-1, 3)
