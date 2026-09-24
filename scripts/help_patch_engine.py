"""
GONODES Help Patch Generator — Core Engine
Generates and audits .gnpatch help files for all 348 operators.
"""
import json
import os
import copy
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts" / "operator_registry.json"

# ── Visualization chain templates ──────────────────────────────────

def window_out(name="window1", x=1200, y=100, res=512):
    return name, {
        "type": "WindowOUT",
        "position": [x, y],
        "parameters": {
            "resolution": {"value": {"_type": "Vector2i", "x": res, "y": res}},
            "open": {"value": True}
        }
    }

def window_out_ui(name="window1", x=1200, y=100, w=320, h=350):
    return name, {
        "type": "WindowOUT",
        "position": [x, y],
        "parameters": {
            "resolution": {"value": {"_type": "Vector2i", "x": w, "y": h}},
            "open": {"value": True}
        }
    }

def chop_to_top(name="choptop1", x=850, y=100):
    return name, {
        "type": "CHOPtoTOP",
        "position": [x, y],
        "parameters": {
            "resolution": {"value": {"_type": "Vector2i", "x": 512, "y": 512}}
        }
    }

def img_to_top(name="imgtotop1", x=850, y=100):
    return name, {
        "type": "ImgToTOP",
        "position": [x, y],
        "parameters": {}
    }

def text_top(name="texttop1", x=850, y=100, text_content=None):
    params = {
        "resolution": {"value": {"_type": "Vector2i", "x": 512, "y": 512}},
        "font_size": {"value": 14}
    }
    if text_content:
        params["text"] = {"value": text_content}
    return name, {
        "type": "TextTOP",
        "position": [x, y],
        "parameters": params
    }

def sop_render_chain(geo_name="geo_view", cam_name="cam_view", render_name="render_view",
                     geo_x=700, cam_y_offset=200, render_x=1000):
    """Returns (nodes_dict, connections_list) for SOP→Render chain"""
    nodes = {}
    nodes[geo_name] = {
        "type": "GeometryCOMP",
        "position": [geo_x, 100],
        "parameters": {}
    }
    nodes[cam_name] = {
        "type": "CameraCOMP",
        "position": [geo_x, 100 + cam_y_offset],
        "parameters": {"tx": {"value": 0}, "ty": {"value": 0.5}, "tz": {"value": 3}}
    }
    nodes[render_name] = {
        "type": "RenderTOP",
        "position": [render_x, 100],
        "parameters": {
            "resolution": {"value": {"_type": "Vector2i", "x": 512, "y": 512}}
        }
    }
    conns = [
        conn(geo_name, 0, render_name, 0),
        conn(cam_name, 0, render_name, 1),
    ]
    return nodes, conns

def vol_render_chain(vol_name="raymarch1", x=700, y=100):
    """Returns (nodes_dict, connections_list) for VOL→Raymarch→Window"""
    nodes = {}
    nodes[vol_name] = {
        "type": "RaymarchTOP",
        "position": [x, y],
        "parameters": {}
    }
    return nodes, []

# Note: POP uses RenderPOP → Window
def pop_render(name="renderpop1", x=700, y=100):
    return name, {
        "type": "RenderPOP",
        "position": [x, y],
        "parameters": {
            "resolution": {"value": {"_type": "Vector2i", "x": 512, "y": 512}}
        }
    }


# ── Connection helper ──────────────────────────────────────────────

def conn(from_n, from_p, to_n, to_p):
    return {"from": from_n, "from_port": from_p, "to": to_n, "to_port": to_p}


# ── Annotation helper ──────────────────────────────────────────────

def annotation(text, x=-100, y=-100, w=400, h=100):
    return {
        "id": "ann_1",
        "type": "note",
        "text": text,
        "position": [float(x), float(y)],
        "size": [float(w), float(h)],
        "color": [1.0, 1.0, 1.0, 0.8]
    }


# ── Patch builder ──────────────────────────────────────────────────

def build_patch(nodes_dict, connections, annotation_text=""):
    """Build a complete .gnpatch JSON dict."""
    patch = {
        "version": "1.0.0",
        "generator": "GONODES",
        "nodes": nodes_dict,
        "connections": connections,
        "annotations": []
    }
    if annotation_text:
        patch["annotations"].append(annotation(annotation_text))
    return patch


# ── Family-specific full chain builders ────────────────────────────

def build_top_chain(focus_node_name, focus_node, extra_nodes=None, extra_conns=None, annotation_text="", win_x=1200):
    """TOP → WindowOUT"""
    nodes = {}
    if extra_nodes:
        nodes.update(extra_nodes)
    nodes[focus_node_name] = focus_node
    wn, wv = window_out(x=win_x)
    nodes[wn] = wv
    conns = []
    if extra_conns:
        conns.extend(extra_conns)
    conns.append(conn(focus_node_name, 0, wn, 0))
    return build_patch(nodes, conns, annotation_text)


def build_chop_chain(focus_node_name, focus_node, extra_nodes=None, extra_conns=None, annotation_text="", win_x=1550):
    """CHOP → CHOPtoTOP → WindowOUT"""
    nodes = {}
    if extra_nodes:
        nodes.update(extra_nodes)
    nodes[focus_node_name] = focus_node
    cn, cv = chop_to_top(x=win_x - 400)
    nodes[cn] = cv
    wn, wv = window_out(x=win_x)
    nodes[wn] = wv
    conns = []
    if extra_conns:
        conns.extend(extra_conns)
    conns.append(conn(focus_node_name, 0, cn, 0))
    conns.append(conn(cn, 0, wn, 0))
    return build_patch(nodes, conns, annotation_text)


def build_sop_chain(focus_node_name, focus_node, extra_nodes=None, extra_conns=None, annotation_text="", geo_x=700, win_x=1550):
    """SOP → GeometryCOMP + CameraCOMP → RenderTOP → WindowOUT"""
    nodes = {}
    if extra_nodes:
        nodes.update(extra_nodes)
    nodes[focus_node_name] = focus_node
    render_nodes, render_conns = sop_render_chain(geo_x=geo_x, render_x=geo_x + 300)
    nodes.update(render_nodes)
    wn, wv = window_out(x=win_x)
    nodes[wn] = wv
    conns = []
    if extra_conns:
        conns.extend(extra_conns)
    conns.append(conn(focus_node_name, 0, "geo_view", 0))
    conns.extend(render_conns)
    conns.append(conn("render_view", 0, wn, 0))
    return build_patch(nodes, conns, annotation_text)


def build_dat_chain(focus_node_name, focus_node, extra_nodes=None, extra_conns=None, annotation_text="", win_x=1550):
    """DAT → (view via TextTOP or CHOPtoDAT chain) → WindowOUT"""
    nodes = {}
    if extra_nodes:
        nodes.update(extra_nodes)
    nodes[focus_node_name] = focus_node
    # DAT → TextTOP (which displays table content) → WindowOUT
    tn, tv = text_top(x=win_x - 400)
    nodes[tn] = tv
    wn, wv = window_out(x=win_x)
    nodes[wn] = wv
    conns = []
    if extra_conns:
        conns.extend(extra_conns)
    conns.append(conn(focus_node_name, 0, tn, 0))
    conns.append(conn(tn, 0, wn, 0))
    return build_patch(nodes, conns, annotation_text)


def build_img_chain(focus_node_name, focus_node, extra_nodes=None, extra_conns=None, annotation_text="", win_x=1550):
    """IMG → ImgToTOP → WindowOUT"""
    nodes = {}
    if extra_nodes:
        nodes.update(extra_nodes)
    nodes[focus_node_name] = focus_node
    itn, itv = img_to_top(x=win_x - 400)
    nodes[itn] = itv
    wn, wv = window_out(x=win_x)
    nodes[wn] = wv
    conns = []
    if extra_conns:
        conns.extend(extra_conns)
    conns.append(conn(focus_node_name, 0, itn, 0))
    conns.append(conn(itn, 0, wn, 0))
    return build_patch(nodes, conns, annotation_text)


def build_mat_chain(focus_node_name, focus_node, sop_type="SphereSOP", extra_nodes=None, extra_conns=None, annotation_text="", win_x=1550):
    """MAT → GeometryCOMP (port 1 for MAT, port 0 for SOP) + CameraCOMP → RenderTOP → WindowOUT"""
    nodes = {}
    if extra_nodes:
        nodes.update(extra_nodes)
    nodes[focus_node_name] = focus_node
    nodes["sphere1"] = {
        "type": sop_type,
        "position": [100, 300],
        "parameters": {}
    }
    nodes["geo1"] = {
        "type": "GeometryCOMP",
        "position": [700, 100],
        "parameters": {}
    }
    nodes["cam1"] = {
        "type": "CameraCOMP",
        "position": [700, 300],
        "parameters": {"tx": {"value": 0}, "ty": {"value": 0.5}, "tz": {"value": 3}}
    }
    nodes["render1"] = {
        "type": "RenderTOP",
        "position": [win_x - 400, 100],
        "parameters": {
            "resolution": {"value": {"_type": "Vector2i", "x": 512, "y": 512}}
        }
    }
    wn, wv = window_out(x=win_x)
    nodes[wn] = wv
    conns = []
    if extra_conns:
        conns.extend(extra_conns)
    conns.extend([
        conn("sphere1", 0, "geo1", 0),
        conn(focus_node_name, 0, "geo1", 1),
        conn("geo1", 0, "render1", 0),
        conn("cam1", 0, "render1", 1),
        conn("render1", 0, wn, 0),
    ])
    return build_patch(nodes, conns, annotation_text)


def build_comp_chain(focus_node_name, focus_node, extra_nodes=None, extra_conns=None, annotation_text="", is_passthrough=False, win_x=1550):
    """COMP → RenderTOP → WindowOUT (scene comps); pass-through comps route through"""
    nodes = {}
    if extra_nodes:
        nodes.update(extra_nodes)
    nodes[focus_node_name] = focus_node
    # For scene comps (camera, light, geo, etc.) that connect into render
    nodes["render1"] = {
        "type": "RenderTOP",
        "position": [win_x - 400, 100],
        "parameters": {
            "resolution": {"value": {"_type": "Vector2i", "x": 512, "y": 512}}
        }
    }
    wn, wv = window_out(x=win_x)
    nodes[wn] = wv
    conns = []
    if extra_conns:
        conns.extend(extra_conns)
    conns.append(conn("render1", 0, wn, 0))
    return build_patch(nodes, conns, annotation_text)


def build_pop_chain(focus_node_name, focus_node, extra_nodes=None, extra_conns=None, annotation_text="", win_x=1550):
    """POP → (source chain) → RenderPOP → RenderTOP ← CameraCOMP → WindowOUT"""
    nodes = {}
    if extra_nodes:
        nodes.update(extra_nodes)
    nodes[focus_node_name] = focus_node
    rn, rv = pop_render(x=win_x - 800)
    nodes[rn] = rv
    nodes["camera1"] = {
        "type": "CameraCOMP",
        "position": [win_x - 600, 300],
        "parameters": {
            "tx": {"value": 0.0},
            "ty": {"value": 0.0},
            "tz": {"value": 5.0}
        }
    }
    nodes["render1"] = {
        "type": "RenderTOP",
        "position": [win_x - 400, 100],
        "parameters": {
            "resolution": {"value": {"_type": "Vector2i", "x": 512, "y": 512}}
        }
    }
    wn, wv = window_out(x=win_x)
    nodes[wn] = wv
    conns = []
    if extra_conns:
        conns.extend(extra_conns)
    conns.append(conn(rn, 0, "render1", 0))
    conns.append(conn("camera1", 0, "render1", 1))
    conns.append(conn("render1", 0, wn, 0))
    return build_patch(nodes, conns, annotation_text)


def build_vol_chain(focus_node_name, focus_node, extra_nodes=None, extra_conns=None, annotation_text="", win_x=1550):
    """VOL → RaymarchTOP → WindowOUT (Raymarch outputs a TOP)"""
    nodes = {}
    if extra_nodes:
        nodes.update(extra_nodes)
    nodes[focus_node_name] = focus_node
    nodes["raymarch1"] = {
        "type": "RaymarchTOP",
        "position": [win_x - 400, 100],
        "parameters": {
            "resolution": {"value": {"_type": "Vector2i", "x": 512, "y": 512}}
        }
    }
    wn, wv = window_out(x=win_x)
    nodes[wn] = wv
    conns = []
    if extra_conns:
        conns.extend(extra_conns)
    conns.append(conn(focus_node_name, 0, "raymarch1", 0))
    conns.append(conn("raymarch1", 0, wn, 0))
    return build_patch(nodes, conns, annotation_text)


def build_ui_chain(focus_node_name, focus_node, extra_nodes=None, extra_conns=None, annotation_text="", win_w=320, win_h=350, win_x=1200):
    """UI → WindowOUT (port 1)"""
    nodes = {}
    if extra_nodes:
        nodes.update(extra_nodes)
    nodes[focus_node_name] = focus_node
    wn, wv = window_out_ui(x=win_x, w=win_w, h=win_h)
    nodes[wn] = wv
    conns = []
    if extra_conns:
        conns.extend(extra_conns)
    conns.append(conn(focus_node_name, 0, wn, 1))
    return build_patch(nodes, conns, annotation_text)


def build_out_chain(focus_node_name, focus_node, extra_nodes=None, extra_conns=None, annotation_text=""):
    """OUT operators are self-terminal"""
    nodes = {}
    if extra_nodes:
        nodes.update(extra_nodes)
    nodes[focus_node_name] = focus_node
    conns = []
    if extra_conns:
        conns.extend(extra_conns)
    return build_patch(nodes, conns, annotation_text)


# ── Node helper ────────────────────────────────────────────────────

def node(type_name, x, y, params=None):
    """Create a node dict."""
    n = {"type": type_name, "position": [x, y], "parameters": params or {}}
    return n


def p(value):
    """Wrap a parameter value."""
    return {"value": value}


def vec2i(x, y):
    return {"value": {"_type": "Vector2i", "x": x, "y": y}}


def color(r, g, b, a=1.0):
    return {"value": {"_type": "Color", "r": r, "g": g, "b": b, "a": a}}


# ── File I/O ───────────────────────────────────────────────────────

def write_patch(patch_dict, filepath):
    """Write patch to disk as formatted JSON."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    content = json.dumps(patch_dict, indent=4)
    with open(filepath, 'w', encoding='utf-8', newline='') as f:
        f.write(content)


def read_patch(filepath):
    """Read and parse a .gnpatch file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)


# ── Audit ──────────────────────────────────────────────────────────

def audit_patch(filepath, family):
    """
    Audit a patch file for quality criteria.
    Returns (is_ok, issues_list).
    """
    issues = []
    try:
        patch = read_patch(filepath)
    except Exception as e:
        return False, [f"JSON parse error: {e}"]

    nodes = patch.get("nodes", {})
    connections = patch.get("connections", [])

    # Check: must have at least 2 nodes (except OUT which can be self-terminal)
    if family != "output" and len(nodes) < 2:
        issues.append(f"Only {len(nodes)} node(s) — needs visualization chain")

    # Check: OUT family — must be self-terminal (no WindowOUT needed)
    if family == "output":
        # OUT nodes should exist and have meaningful source connections
        pass
    else:
        # Non-OUT: must end with WindowOUT
        has_window = any(n.get("type") == "WindowOUT" for n in nodes.values())
        if not has_window:
            issues.append("Missing WindowOUT terminal node")
        else:
            # Check WindowOUT has open:true and resolution
            for nk, nv in nodes.items():
                if nv.get("type") == "WindowOUT":
                    params = nv.get("parameters", {})
                    if not params.get("open", {}).get("value", False):
                        issues.append("WindowOUT missing open:true")
                    res = params.get("resolution", {}).get("value", {})
                    if not res.get("_type") == "Vector2i":
                        issues.append("WindowOUT missing resolution with Vector2i type")

    # Check: connections exist
    if len(connections) == 0 and len(nodes) > 1:
        issues.append("No connections between nodes")

    # Check: correct chain type for family
    if family == "chop" and not any(n.get("type") == "CHOPtoTOP" for n in nodes.values()):
        # CHOP should go through CHOPtoTOP (unless it's a converter like DATtoCHOP)
        node_types = [n.get("type", "") for n in nodes.values()]
        if not any("TOP" in t for t in node_types if t != "WindowOUT"):
            issues.append("CHOP patch missing CHOPtoTOP visualization")

    if family == "img" and not any(n.get("type") == "ImgToTOP" for n in nodes.values()):
        issues.append("IMG patch missing ImgToTOP conversion")

    if family == "sop":
        has_geo = any(n.get("type") == "GeometryCOMP" for n in nodes.values())
        has_render = any(n.get("type") == "RenderTOP" for n in nodes.values())
        if not (has_geo and has_render):
            issues.append("SOP patch missing GeometryCOMP+RenderTOP chain")

    if family == "dat":
        has_text = any(n.get("type") == "TextTOP" for n in nodes.values())
        has_choptotop = any(n.get("type") == "CHOPtoTOP" for n in nodes.values())
        if not (has_text or has_choptotop):
            issues.append("DAT patch missing TextTOP visualization")

    if family == "ui":
        # UI should connect to WindowOUT port 1
        has_ui_conn = any(
            c.get("to_port") == 1
            for c in connections
            if any(nodes.get(c.get("to", ""), {}).get("type") == "WindowOUT" for _ in [1])
        )
        # Simpler check: any connection to window port 1
        for c in connections:
            to_node = c.get("to", "")
            if nodes.get(to_node, {}).get("type") == "WindowOUT" and c.get("to_port") == 1:
                has_ui_conn = True
                break
        else:
            has_ui_conn = False
        if not has_ui_conn:
            issues.append("UI patch not connected to WindowOUT port 1")

    return len(issues) == 0, issues


# ── Discovery ──────────────────────────────────────────────────────

def get_help_dir(op_info):
    """Get the help directory for an operator."""
    family = op_info["family"]
    ext = op_info.get("extension")
    if ext:
        return ROOT / "addons" / ext / "help" / family
    else:
        return ROOT / "addons" / "gonodes" / "help" / family


def find_existing_patches(op_info):
    """Find existing help patches for an operator.

    Matches by node_type prefix OR by scanning JSON for the class_name type.
    """
    help_dir = get_help_dir(op_info)
    node_type = op_info["node_type"]
    class_name = op_info["class_name"]
    patches = []
    if not help_dir.exists():
        return patches

    # First pass: direct node_type prefix match
    matched_paths = set()
    for f in help_dir.glob(f"{node_type}_*.gnpatch"):
        patches.append(f)
        matched_paths.add(f)

    # Second pass: scan all .gnpatch files for this operator's class_name
    for f in help_dir.glob("*.gnpatch"):
        if f in matched_paths:
            continue
        try:
            with open(f, 'r', encoding='utf-8') as fh:
                content = fh.read()
                if f'"type": "{class_name}"' in content or f'"type":  "{class_name}"' in content:
                    patches.append(f)
                    matched_paths.add(f)
        except Exception:
            pass

    return sorted(patches)


def load_registry():
    """Load operator registry."""
    with open(REGISTRY, 'r', encoding='utf-8') as f:
        return json.load(f)
