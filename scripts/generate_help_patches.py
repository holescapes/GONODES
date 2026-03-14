"""
GONODES Help Patch Auto-Generator
Generates 3 patches per operator using family-specific templates
and operator parameter data from the registry.
"""
import json
import os
import sys
from pathlib import Path

# Add scripts dir to path
sys.path.insert(0, str(Path(__file__).parent))

from help_patch_engine import *

# Try to import hand-crafted patches
try:
    from patches_chop import get_chop_patches
    HAS_CHOP_PATCHES = True
except ImportError:
    HAS_CHOP_PATCHES = False


# ──────────────────────────────────────────────────────────────────
# Source nodes for upstream inputs (per family)
# ──────────────────────────────────────────────────────────────────

TOP_SOURCES = {
    "noise": ("NoiseTOP", {"resolution": vec2i(512, 512), "scale": p(4.0), "monochrome": p(True)}),
    "ramp": ("RampTOP", {"resolution": vec2i(512, 512)}),
    "circle": ("CircleTOP", {"resolution": vec2i(512, 512), "radius": p(0.3)}),
    "constant": ("ConstantTOP", {"resolution": vec2i(512, 512)}),
    "pattern": ("PatternTOP", {"resolution": vec2i(512, 512)}),
    "text": ("TextTOP", {"resolution": vec2i(512, 512), "text": p("Hello GONODES"), "font_size": p(48)}),
}

CHOP_SOURCES = {
    "lfo": ("LFO_CHOP", {"frequency": p(1.0), "amplitude": p(1.0)}),
    "noise": ("NoiseCHOP", {"amplitude": p(1.0)}),
    "wave": ("WaveCHOP", {"waveform": p(0), "frequency": p(2.0)}),
    "constant": ("ConstantCHOP", {"value0": p(1.0)}),
}

SOP_SOURCES = {
    "grid": ("GridSOP", {"rows": p(10), "cols": p(10)}),
    "sphere": ("SphereSOP", {}),
    "box": ("BoxSOP", {}),
    "torus": ("TorusSOP", {}),
}

DAT_SOURCES = {
    "constant": ("ConstantDAT", {}),
    "text": ("TextDAT", {"text": p("Hello World")}),
}


# ──────────────────────────────────────────────────────────────────
# Determine best source for an operator based on its inputs
# ──────────────────────────────────────────────────────────────────

def pick_source(family, node_type, variant=0):
    """Pick a good upstream source for the operator."""
    src_keys = {
        "top": ["noise", "ramp", "circle", "pattern", "text", "constant"],
        "chop": ["lfo", "noise", "wave", "constant"],
        "sop": ["grid", "sphere", "box", "torus"],
        "dat": ["constant", "text"],
    }
    sources_map = {"top": TOP_SOURCES, "chop": CHOP_SOURCES, "sop": SOP_SOURCES, "dat": DAT_SOURCES}
    keys = src_keys.get(family, [])
    sources = sources_map.get(family, {})
    if not keys:
        return None, None, {}
    idx = variant % len(keys)
    key = keys[idx]
    type_name, params = sources[key]
    return f"src_{key}", type_name, params


# ──────────────────────────────────────────────────────────────────
# Operator-specific parameter variations for 3 patches
# ──────────────────────────────────────────────────────────────────

def get_param_variations(op_info):
    """Return 3 sets of param overrides for basic/feature/advanced patches."""
    params = op_info.get("params", [])
    variations = [{}, {}, {}]  # basic, feature, advanced

    for param in params:
        name = param["name"]
        ptype = param["type"]
        default = param.get("default")

        if ptype == "float":
            if default is not None:
                variations[0][name] = p(default)
                # Feature: half value
                variations[1][name] = p(default * 0.5 if default != 0 else 0.5)
                # Advanced: double value
                variations[2][name] = p(default * 2.0 if default != 0 else 1.0)
            else:
                variations[0][name] = p(0.5)
                variations[1][name] = p(0.25)
                variations[2][name] = p(1.0)
        elif ptype == "int":
            if default is not None:
                variations[0][name] = p(default)
                variations[1][name] = p(max(0, default - 1))
                variations[2][name] = p(default + 2)
            else:
                variations[0][name] = p(1)
                variations[1][name] = p(0)
                variations[2][name] = p(3)
        elif ptype == "bool":
            variations[0][name] = p(default if default is not None else False)
            variations[1][name] = p(True)
            variations[2][name] = p(not (default if default is not None else False))
        elif ptype == "string":
            if default:
                variations[0][name] = p(default)
        elif ptype == "menu":
            variations[0][name] = p(0)
            variations[1][name] = p(1)
            variations[2][name] = p(2)
        elif ptype == "vector2i":
            variations[0][name] = vec2i(512, 512)
            variations[1][name] = vec2i(256, 256)
            variations[2][name] = vec2i(1024, 1024)
        elif ptype == "color":
            variations[0][name] = color(1.0, 1.0, 1.0)
            variations[1][name] = color(1.0, 0.4, 0.2)
            variations[2][name] = color(0.2, 0.6, 1.0)

    return variations


# ──────────────────────────────────────────────────────────────────
# Label generation
# ──────────────────────────────────────────────────────────────────

def make_labels(op_info):
    """Generate 3 patch labels: basic, feature-specific, advanced."""
    params = op_info.get("params", [])
    node_type = op_info["node_type"]
    class_name = op_info["class_name"]

    # Find interesting param for middle patch
    feature_param = None
    for param in params:
        if param["type"] in ("menu", "float", "bool") and param["name"] not in ("resolution",):
            feature_param = param["name"]
            break

    if feature_param:
        middle = feature_param.replace("_", " ").lower()
    else:
        middle = "options"

    return [
        f"{node_type}_basic",
        f"{node_type}_{feature_param or 'variation'}",
        f"{node_type}_advanced",
    ]


def make_annotations(op_info, variant):
    """Generate annotation text for each variant."""
    class_name = op_info["class_name"]
    family = op_info["family"].upper()
    params = op_info.get("params", [])
    ext = op_info.get("extension")
    ext_note = f"\nRequires {ext} extension." if ext else ""

    titles = ["Basic", "Parameters", "Advanced"]
    descs = [
        f"Default settings.{ext_note}",
        f"Alternate parameter values.{ext_note}",
        f"More complex configuration.{ext_note}",
    ]

    param_names = [p["name"] for p in params[:3]]
    if param_names:
        descs[1] = f"Showcases: {', '.join(param_names)}.{ext_note}"

    return f"{class_name} — {titles[variant]}\n\n{descs[variant]}"


# ──────────────────────────────────────────────────────────────────
# Family-specific auto-generators
# ──────────────────────────────────────────────────────────────────

def auto_gen_top(op_info, variant):
    nt = op_info["node_type"]
    cn = op_info["class_name"]
    params_list = get_param_variations(op_info)
    param_set = params_list[variant]
    ann = make_annotations(op_info, variant)

    # Generators (no input needed)
    generators = {"noise", "ramp", "circle", "rectangle", "constant", "text", "pattern",
                  "triangle", "svg", "compute", "panel", "snapshot", "compositor_effect",
                  "geometry_buffer", "multi_buffer_render", "render", "choptotop"}
    # Converters that take CHOP input
    chop_input = {"choptotop"}
    # Converters that take SOP input
    sop_base = {"toptosop"}

    if nt in generators:
        # Self-sufficient — just add resolution if not set
        if "resolution" not in param_set:
            param_set["resolution"] = vec2i(512, 512)
        return build_top_chain(f"{nt}1",
            node(cn, 100, 100, param_set),
            annotation_text=ann)
    elif nt in chop_input:
        src_name, src_type, src_params = pick_source("chop", nt, variant)
        return build_top_chain(f"{nt}1",
            node(cn, 450, 100, param_set),
            extra_nodes={src_name: node(src_type, 100, 100, src_params)},
            extra_conns=[conn(src_name, 0, f"{nt}1", 0)],
            annotation_text=ann)
    else:
        # Filter/effect — needs TOP input
        src_name, src_type, src_params = pick_source("top", nt, variant)
        return build_top_chain(f"{nt}1",
            node(cn, 450, 100, param_set),
            extra_nodes={src_name: node(src_type, 100, 100, src_params)},
            extra_conns=[conn(src_name, 0, f"{nt}1", 0)],
            annotation_text=ann)


def auto_gen_chop(op_info, variant):
    """Fallback for CHOPs not in hand-crafted definitions."""
    nt = op_info["node_type"]
    cn = op_info["class_name"]
    params_list = get_param_variations(op_info)
    param_set = params_list[variant]
    ann = make_annotations(op_info, variant)

    generators = {"noise", "lfo", "wave", "constant", "pattern", "ramp", "clock",
                  "expression", "beat", "timer", "perform", "keyboardin", "mousein",
                  "gamepad", "audioin", "audiofilein", "oscin", "midiin", "parameter",
                  "rtmidiin"}

    if nt in generators:
        return build_chop_chain(f"{nt}1",
            node(cn, 100, 100, param_set),
            annotation_text=ann)
    else:
        src_name, src_type, src_params = pick_source("chop", nt, variant)
        return build_chop_chain(f"{nt}1",
            node(cn, 450, 100, param_set),
            extra_nodes={src_name: node(src_type, 100, 100, src_params)},
            extra_conns=[conn(src_name, 0, f"{nt}1", 0)],
            annotation_text=ann)


def auto_gen_sop(op_info, variant):
    nt = op_info["node_type"]
    cn = op_info["class_name"]
    params_list = get_param_variations(op_info)
    param_set = params_list[variant]
    ann = make_annotations(op_info, variant)

    generators = {"grid", "box", "sphere", "torus", "cylinder", "line", "circle", "tube",
                  "font", "metaball", "isosurface", "lsystem"}

    if nt in generators:
        return build_sop_chain(f"{nt}1",
            node(cn, 100, 100, param_set),
            annotation_text=ann)
    else:
        src_name, src_type, src_params = pick_source("sop", nt, variant)
        return build_sop_chain(f"{nt}1",
            node(cn, 450, 100, param_set),
            extra_nodes={src_name: node(src_type, 100, 100, src_params)},
            extra_conns=[conn(src_name, 0, f"{nt}1", 0)],
            annotation_text=ann)


def auto_gen_dat(op_info, variant):
    nt = op_info["node_type"]
    cn = op_info["class_name"]
    params_list = get_param_variations(op_info)
    param_set = params_list[variant]
    ann = make_annotations(op_info, variant)

    generators = {"constant", "text", "info", "oscin", "midiin", "json", "web",
                  "webserver", "websocket", "filein", "folder", "error",
                  "multitouchin", "table", "network", "xml", "opfind",
                  "callbackdat", "scriptdat"}

    if nt in generators:
        return build_dat_chain(f"{nt}1",
            node(cn, 100, 100, param_set),
            annotation_text=ann)
    else:
        src_name, src_type, src_params = pick_source("dat", nt, variant)
        return build_dat_chain(f"{nt}1",
            node(cn, 450, 100, param_set),
            extra_nodes={src_name: node(src_type, 100, 100, src_params)},
            extra_conns=[conn(src_name, 0, f"{nt}1", 0)],
            annotation_text=ann)


def auto_gen_img(op_info, variant):
    nt = op_info["node_type"]
    cn = op_info["class_name"]
    params_list = get_param_variations(op_info)
    param_set = params_list[variant]
    ann = make_annotations(op_info, variant)

    generators = {"noiseimg", "checkerboardimg", "imagefileinimg", "imagesequenceimg",
                  "screengrab", "webcamimg", "videodeviceinimg", "scriptimg"}
    if nt == "imgtotop":
        # Special: needs IMG input → outputs TOP directly
        return build_top_chain(f"{nt}1",
            node(cn, 450, 100, param_set),
            extra_nodes={"noiseimg1": node("NoiseIMG", 100, 100, {})},
            extra_conns=[conn("noiseimg1", 0, f"{nt}1", 0)],
            annotation_text=ann)
    elif nt == "toptoimg":
        # TOP → IMG → ImgToTOP → Window
        return build_img_chain(f"{nt}1",
            node(cn, 450, 100, param_set),
            extra_nodes={"noise_top": node("NoiseTOP", 100, 100, {"resolution": vec2i(256, 256)})},
            extra_conns=[conn("noise_top", 0, f"{nt}1", 0)],
            annotation_text=ann)
    elif nt in generators:
        return build_img_chain(f"{nt}1",
            node(cn, 100, 100, param_set),
            annotation_text=ann)
    else:
        # Filter IMG — needs IMG input
        return build_img_chain(f"{nt}1",
            node(cn, 450, 100, param_set),
            extra_nodes={"noiseimg1": node("NoiseIMG", 100, 100, {})},
            extra_conns=[conn("noiseimg1", 0, f"{nt}1", 0)],
            annotation_text=ann)


def auto_gen_mat(op_info, variant):
    nt = op_info["node_type"]
    cn = op_info["class_name"]
    params_list = get_param_variations(op_info)
    param_set = params_list[variant]
    ann = make_annotations(op_info, variant)

    sop_types = ["SphereSOP", "BoxSOP", "TorusSOP"]
    return build_mat_chain(f"{nt}1",
        node(cn, 100, 100, param_set),
        sop_type=sop_types[variant % len(sop_types)],
        annotation_text=ann)


def auto_gen_comp(op_info, variant):
    nt = op_info["node_type"]
    cn = op_info["class_name"]
    params_list = get_param_variations(op_info)
    param_set = params_list[variant]
    ann = make_annotations(op_info, variant)

    # CameraCOMP — needs geo + render
    if nt == "camera":
        nodes = {
            "sphere1": node("SphereSOP", 100, 100, {}),
            f"{nt}1": node(cn, 700, 300, param_set),
            "geo1": node("GeometryCOMP", 400, 100, {}),
            "render1": node("RenderTOP", 1000, 100, {"resolution": vec2i(512, 512)}),
        }
        conns_list = [
            conn("sphere1", 0, "geo1", 0),
            conn("geo1", 0, "render1", 0),
            conn(f"{nt}1", 0, "render1", 1),
        ]
        wn, wv = window_out(x=1400)
        nodes[wn] = wv
        conns_list.append(conn("render1", 0, wn, 0))
        return build_patch(nodes, conns_list, ann)

    # GeometryCOMP — needs sop + render
    elif nt == "geo":
        sops = [("SphereSOP", {}), ("BoxSOP", {}), ("TorusSOP", {})]
        sop_type, sop_params = sops[variant % len(sops)]
        nodes = {
            "sop1": node(sop_type, 100, 100, sop_params),
            f"{nt}1": node(cn, 400, 100, param_set),
            "cam1": node("CameraCOMP", 700, 300, {"tx": p(0), "ty": p(0.5), "tz": p(3)}),
            "render1": node("RenderTOP", 1000, 100, {"resolution": vec2i(512, 512)}),
        }
        conns_list = [
            conn("sop1", 0, f"{nt}1", 0),
            conn(f"{nt}1", 0, "render1", 0),
            conn("cam1", 0, "render1", 1),
        ]
        wn, wv = window_out(x=1400)
        nodes[wn] = wv
        conns_list.append(conn("render1", 0, wn, 0))
        return build_patch(nodes, conns_list, ann)

    # LightCOMP — add to a scene render
    elif nt == "light":
        nodes = {
            "sphere1": node("SphereSOP", 100, 100, {}),
            "geo1": node("GeometryCOMP", 400, 100, {}),
            f"{nt}1": node(cn, 400, 300, param_set),
            "cam1": node("CameraCOMP", 700, 300, {"tz": p(3)}),
            "render1": node("RenderTOP", 1000, 100, {"resolution": vec2i(512, 512)}),
        }
        conns_list = [
            conn("sphere1", 0, "geo1", 0),
            conn("geo1", 0, "render1", 0),
            conn("cam1", 0, "render1", 1),
        ]
        wn, wv = window_out(x=1400)
        nodes[wn] = wv
        conns_list.append(conn("render1", 0, wn, 0))
        return build_patch(nodes, conns_list, ann)

    # EnvironmentCOMP — same as light
    elif nt == "environment":
        nodes = {
            "sphere1": node("SphereSOP", 100, 100, {}),
            "geo1": node("GeometryCOMP", 400, 100, {}),
            f"{nt}1": node(cn, 400, 450, param_set),
            "cam1": node("CameraCOMP", 700, 300, {"tz": p(3)}),
            "render1": node("RenderTOP", 1000, 100, {"resolution": vec2i(512, 512)}),
        }
        conns_list = [
            conn("sphere1", 0, "geo1", 0),
            conn("geo1", 0, "render1", 0),
            conn("cam1", 0, "render1", 1),
        ]
        wn, wv = window_out(x=1400)
        nodes[wn] = wv
        conns_list.append(conn("render1", 0, wn, 0))
        return build_patch(nodes, conns_list, ann)

    # Pass-through COMPs (Null, Switch, Animation, Merge, Replicator)
    elif nt in ("null", "switch", "animation", "merge_comp", "replicator"):
        nodes = {
            "sphere1": node("SphereSOP", 100, 100, {}),
            "geo1": node("GeometryCOMP", 400, 100, {}),
            f"{nt}1": node(cn, 700, 100, param_set),
            "cam1": node("CameraCOMP", 1000, 300, {"tz": p(3)}),
            "render1": node("RenderTOP", 1200, 100, {"resolution": vec2i(512, 512)}),
        }
        conns_list = [
            conn("sphere1", 0, "geo1", 0),
            conn("geo1", 0, f"{nt}1", 0),
            conn(f"{nt}1", 0, "render1", 0),
            conn("cam1", 0, "render1", 1),
        ]
        wn, wv = window_out(x=1600)
        nodes[wn] = wv
        conns_list.append(conn("render1", 0, wn, 0))
        return build_patch(nodes, conns_list, ann)

    # Physics COMPs (RigidBody, StaticBody, SoftBody, Area, Joint)
    elif nt in ("rigid_body", "static_body", "soft_body", "area", "joint"):
        nodes = {
            "box1": node("BoxSOP", 100, 100, {}),
            "geo1": node("GeometryCOMP", 400, 100, {}),
            f"{nt}1": node(cn, 700, 100, param_set),
            "cam1": node("CameraCOMP", 1000, 300, {"tz": p(5)}),
            "render1": node("RenderTOP", 1200, 100, {"resolution": vec2i(512, 512)}),
        }
        conns_list = [
            conn("box1", 0, "geo1", 0),
            conn("geo1", 0, f"{nt}1", 0),
            conn(f"{nt}1", 0, "render1", 0),
            conn("cam1", 0, "render1", 1),
        ]
        wn, wv = window_out(x=1600)
        nodes[wn] = wv
        conns_list.append(conn("render1", 0, wn, 0))
        return build_patch(nodes, conns_list, ann)

    # InstanceCOMP
    elif nt == "instance":
        nodes = {
            "sphere1": node("SphereSOP", 100, 100, {}),
            "geo1": node("GeometryCOMP", 400, 100, {}),
            f"{nt}1": node(cn, 700, 100, param_set),
            "cam1": node("CameraCOMP", 1000, 300, {"tz": p(5)}),
            "render1": node("RenderTOP", 1200, 100, {"resolution": vec2i(512, 512)}),
        }
        conns_list = [
            conn("sphere1", 0, "geo1", 0),
            conn("geo1", 0, f"{nt}1", 0),
            conn(f"{nt}1", 0, "render1", 0),
            conn("cam1", 0, "render1", 1),
        ]
        wn, wv = window_out(x=1600)
        nodes[wn] = wv
        conns_list.append(conn("render1", 0, wn, 0))
        return build_patch(nodes, conns_list, ann)

    # SubNetwork tunnels
    elif nt in ("in_tunnel", "out_tunnel", "subnet"):
        nodes = {
            "noise1": node("NoiseTOP", 100, 100, {"resolution": vec2i(512, 512)}),
            f"{nt}1": node(cn, 400, 100, param_set),
        }
        conns_list = [conn("noise1", 0, f"{nt}1", 0)]
        wn, wv = window_out(x=800)
        nodes[wn] = wv
        conns_list.append(conn(f"{nt}1", 0, wn, 0))
        return build_patch(nodes, conns_list, ann)

    # EnginesCOMP — performance monitor
    elif nt == "engines":
        nodes = {
            f"{nt}1": node(cn, 100, 100, param_set),
            "choptop1": node("CHOPtoTOP", 450, 100, {"resolution": vec2i(512, 512)}),
        }
        conns_list = [conn(f"{nt}1", 0, "choptop1", 0)]
        wn, wv = window_out(x=800)
        nodes[wn] = wv
        conns_list.append(conn("choptop1", 0, wn, 0))
        return build_patch(nodes, conns_list, ann)

    # GenericScriptNode
    elif nt == "genericscript":
        nodes = {
            "noise1": node("NoiseTOP", 100, 100, {"resolution": vec2i(512, 512)}),
            f"{nt}1": node(cn, 400, 100, param_set),
        }
        conns_list = [conn("noise1", 0, f"{nt}1", 0)]
        wn, wv = window_out(x=800)
        nodes[wn] = wv
        conns_list.append(conn(f"{nt}1", 0, wn, 0))
        return build_patch(nodes, conns_list, ann)

    # Default — render chain
    else:
        return build_comp_chain(f"{nt}1",
            node(cn, 400, 100, param_set),
            annotation_text=ann)


def auto_gen_pop(op_info, variant):
    nt = op_info["node_type"]
    cn = op_info["class_name"]
    params_list = get_param_variations(op_info)
    param_set = params_list[variant]
    ann = make_annotations(op_info, variant)

    # SourcePOP is the generator
    if nt == "source":
        return build_pop_chain(f"{nt}1",
            node(cn, 100, 100, param_set),
            extra_conns=[conn(f"{nt}1", 0, "renderpop1", 0)],
            annotation_text=ann)
    elif nt == "render":
        # RenderPOP — needs source + this is the renderer
        nodes = {
            "source1": node("SourcePOP", 100, 100, {}),
            f"{nt}1": node(cn, 400, 100, param_set),
        }
        wn, wv = window_out(x=800)
        nodes[wn] = wv
        conns_list = [
            conn("source1", 0, f"{nt}1", 0),
            conn(f"{nt}1", 0, wn, 0),
        ]
        return build_patch(nodes, conns_list, ann)
    elif nt == "particle_state":
        # ParticleStateTOP — reads POP state
        nodes = {
            "source1": node("SourcePOP", 100, 100, {}),
            f"{nt}1": node(cn, 400, 100, param_set),
        }
        wn, wv = window_out(x=800)
        nodes[wn] = wv
        conns_list = [
            conn("source1", 0, f"{nt}1", 0),
            conn(f"{nt}1", 0, wn, 0),
        ]
        return build_patch(nodes, conns_list, ann)
    else:
        # POP modifier — needs source → this → render
        nodes = {
            "source1": node("SourcePOP", 100, 100, {}),
            f"{nt}1": node(cn, 400, 100, param_set),
            "renderpop1": node("RenderPOP", 700, 100, {"resolution": vec2i(512, 512)}),
        }
        wn, wv = window_out(x=1100)
        nodes[wn] = wv
        conns_list = [
            conn("source1", 0, f"{nt}1", 0),
            conn(f"{nt}1", 0, "renderpop1", 0),
            conn("renderpop1", 0, wn, 0),
        ]
        return build_patch(nodes, conns_list, ann)


def auto_gen_vol(op_info, variant):
    nt = op_info["node_type"]
    cn = op_info["class_name"]
    params_list = get_param_variations(op_info)
    param_set = params_list[variant]
    ann = make_annotations(op_info, variant)

    generators = {"noise"}
    if nt in generators:
        return build_vol_chain(f"{nt}1",
            node(cn, 100, 100, param_set),
            annotation_text=ann)
    elif nt == "raymarch":
        # Raymarch IS the renderer — needs noise vol input
        nodes = {
            "noisevol1": node("NoiseVOL", 100, 100, {}),
            f"{nt}1": node(cn, 400, 100, param_set),
        }
        wn, wv = window_out(x=800)
        nodes[wn] = wv
        conns_list = [
            conn("noisevol1", 0, f"{nt}1", 0),
            conn(f"{nt}1", 0, wn, 0),
        ]
        return build_patch(nodes, conns_list, ann)
    elif nt == "marchingcubes":
        # MarchingCubes → SOP
        nodes = {
            "noisevol1": node("NoiseVOL", 100, 100, {}),
            f"{nt}1": node(cn, 400, 100, param_set),
        }
        # Output is SOP, needs render chain
        nodes["geo1"] = node("GeometryCOMP", 700, 100, {})
        nodes["cam1"] = node("CameraCOMP", 700, 300, {"tz": p(3)})
        nodes["render1"] = node("RenderTOP", 1000, 100, {"resolution": vec2i(512, 512)})
        wn, wv = window_out(x=1400)
        nodes[wn] = wv
        conns_list = [
            conn("noisevol1", 0, f"{nt}1", 0),
            conn(f"{nt}1", 0, "geo1", 0),
            conn("geo1", 0, "render1", 0),
            conn("cam1", 0, "render1", 1),
            conn("render1", 0, wn, 0),
        ]
        return build_patch(nodes, conns_list, ann)
    else:
        # VOL filter — needs vol input → raymarch
        return build_vol_chain(f"{nt}1",
            node(cn, 400, 100, param_set),
            extra_nodes={"noisevol1": node("NoiseVOL", 100, 100, {})},
            extra_conns=[conn("noisevol1", 0, f"{nt}1", 0)],
            annotation_text=ann)


def auto_gen_ui(op_info, variant):
    """Generate interactive UI patches. Each must drive a visible change."""
    nt = op_info["node_type"]
    cn = op_info["class_name"]
    params_list = get_param_variations(op_info)
    param_set = params_list[variant]
    ann = make_annotations(op_info, variant)

    # Container types — contain other UI nodes
    containers = {"container", "scrollcontainer", "tabcontainer", "splitcontainer",
                  "margincontainer", "panelcontainer"}
    # Display-only widgets
    display_only = {"label", "colorrect", "texturerect", "richtextlabel",
                    "separator", "ninepatchrect", "progressbar", "textureprogressbar",
                    "linkbutton"}

    if nt in containers:
        # Container with child widgets → window
        children = [
            ("btn_child", node("ButtonUI", 100, 50, {"label": p("Button A")})),
            ("slider_child", node("SliderUI", 100, 180, {"label": p("Param"), "default_val": p(0.5)})),
            ("toggle_child", node("ToggleUI", 100, 310, {"label": p("Enable")})),
        ]
        nodes = {}
        for cname, cnode in children:
            nodes[cname] = cnode
        nodes[f"{nt}1"] = node(cn, 500, 100, param_set)
        # Container drives a noise TOP via panel
        nodes["noise_top"] = node("NoiseTOP", 900, 100, {"resolution": vec2i(512, 512)})
        wn, wv = window_out_ui(x=1300, w=400, h=450)
        nodes[wn] = wv
        conns_list = []
        for cname, _ in children:
            conns_list.append(conn(cname, 0, f"{nt}1", 0))
        conns_list.append(conn(f"{nt}1", 0, wn, 1))
        conns_list.append(conn("noise_top", 0, wn, 0))
        return build_patch(nodes, conns_list, ann)

    elif nt in display_only:
        # Display widget + interactive companion that changes it
        nodes = {
            f"{nt}1": node(cn, 100, 100, param_set),
            "slider_ctrl": node("SliderUI", 100, 250, {"label": p("Control"), "default_val": p(0.5)}),
            "container1": node("ContainerUI", 500, 100, {"layout": p(0)}),
        }
        wn, wv = window_out_ui(x=900, w=320, h=280)
        nodes[wn] = wv
        conns_list = [
            conn(f"{nt}1", 0, "container1", 0),
            conn("slider_ctrl", 0, "container1", 0),
            conn("container1", 0, wn, 1),
        ]
        return build_patch(nodes, conns_list, ann)

    else:
        # Interactive widget — drives a visible parameter
        # Pattern: UI widget → WindowOUT port 1, plus a TOP chain on port 0
        # that the widget conceptually controls
        if variant == 0:
            # Basic: just the widget + window
            nodes = {
                f"{nt}1": node(cn, 100, 100, param_set),
                "noise1": node("NoiseTOP", 500, 100, {"resolution": vec2i(512, 512), "scale": p(4.0)}),
            }
            wn, wv = window_out_ui(x=900, w=512, h=512)
            nodes[wn] = wv
            conns_list = [
                conn(f"{nt}1", 0, wn, 1),
                conn("noise1", 0, wn, 0),
            ]
            return build_patch(nodes, conns_list, ann)
        elif variant == 1:
            # Feature: widget + companion in container
            nodes = {
                f"{nt}1": node(cn, 100, 100, param_set),
                "label1": node("LabelUI", 100, 250, {"text": p(f"Testing {cn}")}),
                "container1": node("ContainerUI", 400, 100, {"layout": p(0), "spacing": p(8)}),
                "ramp1": node("RampTOP", 700, 100, {"resolution": vec2i(512, 512)}),
            }
            wn, wv = window_out_ui(x=1100, w=512, h=550)
            nodes[wn] = wv
            conns_list = [
                conn(f"{nt}1", 0, "container1", 0),
                conn("label1", 0, "container1", 0),
                conn("container1", 0, wn, 1),
                conn("ramp1", 0, wn, 0),
            ]
            return build_patch(nodes, conns_list, ann)
        else:
            # Advanced: multiple widgets controlling a visual chain
            nodes = {
                f"{nt}1": node(cn, 100, 100, param_set),
                "slider1": node("SliderUI", 100, 250, {"label": p("Amount"), "default_val": p(0.5)}),
                "toggle1": node("ToggleUI", 100, 400, {"label": p("Enable")}),
                "container1": node("ContainerUI", 400, 100, {"layout": p(0), "spacing": p(6)}),
                "noise1": node("NoiseTOP", 700, 50, {"resolution": vec2i(512, 512)}),
                "blur1": node("BlurTOP", 900, 50, {"size": p(4.0)}),
            }
            wn, wv = window_out_ui(x=1200, w=512, h=600)
            nodes[wn] = wv
            conns_list = [
                conn(f"{nt}1", 0, "container1", 0),
                conn("slider1", 0, "container1", 0),
                conn("toggle1", 0, "container1", 0),
                conn("container1", 0, wn, 1),
                conn("noise1", 0, "blur1", 0),
                conn("blur1", 0, wn, 0),
            ]
            return build_patch(nodes, conns_list, ann)


def auto_gen_output(op_info, variant):
    """OUT family — self-terminal. Source feeds into the OUT node."""
    nt = op_info["node_type"]
    cn = op_info["class_name"]
    params_list = get_param_variations(op_info)
    param_set = params_list[variant]
    ann = make_annotations(op_info, variant)

    # WindowOUT needs a source TOP
    if nt == "window":
        src_keys = ["noise", "ramp", "pattern"]
        src_key = src_keys[variant % len(src_keys)]
        src_type, src_params = TOP_SOURCES[src_key]
        nodes = {
            f"src_{src_key}": node(src_type, 100, 100, src_params),
            f"{nt}1": node(cn, 500, 100, {
                "resolution": vec2i(512, 512),
                "open": p(True),
            }),
        }
        conns_list = [conn(f"src_{src_key}", 0, f"{nt}1", 0)]
        return build_patch(nodes, conns_list, ann)

    # Audio OUT — needs CHOP input
    elif nt in ("audioout",):
        src_name, src_type, src_params = pick_source("chop", nt, variant)
        nodes = {
            src_name: node(src_type, 100, 100, src_params),
            f"{nt}1": node(cn, 500, 100, param_set),
        }
        conns_list = [conn(src_name, 0, f"{nt}1", 0)]
        return build_patch(nodes, conns_list, ann)

    # OSC OUT — needs CHOP input
    elif nt in ("oscout",):
        src_name, src_type, src_params = pick_source("chop", nt, variant)
        if "active" in param_set:
            param_set["active"] = p(False)  # Don't send by default
        else:
            param_set["active"] = p(False)
        nodes = {
            src_name: node(src_type, 100, 100, src_params),
            f"{nt}1": node(cn, 500, 100, param_set),
        }
        conns_list = [conn(src_name, 0, f"{nt}1", 0)]
        return build_patch(nodes, conns_list, ann)

    # Movie/Record/FFmpeg OUT — needs TOP input
    elif nt in ("movieout", "recordout", "ffmpegout", "moviefileouttop"):
        src_keys = ["noise", "ramp", "circle"]
        src_key = src_keys[variant % len(src_keys)]
        src_type, src_params = TOP_SOURCES[src_key]
        nodes = {
            f"src_{src_key}": node(src_type, 100, 100, src_params),
            f"{nt}1": node(cn, 500, 100, param_set),
        }
        conns_list = [conn(f"src_{src_key}", 0, f"{nt}1", 0)]
        return build_patch(nodes, conns_list, ann)

    # Image/Texture save — needs TOP input
    elif nt in ("imagesave", "texturesave"):
        src_type, src_params = TOP_SOURCES["noise"]
        nodes = {
            "src_noise": node(src_type, 100, 100, src_params),
            f"{nt}1": node(cn, 500, 100, param_set),
        }
        conns_list = [conn("src_noise", 0, f"{nt}1", 0)]
        return build_patch(nodes, conns_list, ann)

    # Table save — needs DAT input
    elif nt in ("tablesave",):
        nodes = {
            "const_dat": node("ConstantDAT", 100, 100, {}),
            f"{nt}1": node(cn, 500, 100, param_set),
        }
        conns_list = [conn("const_dat", 0, f"{nt}1", 0)]
        return build_patch(nodes, conns_list, ann)

    # Default OUT
    else:
        nodes = {
            "lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)}),
            f"{nt}1": node(cn, 500, 100, param_set),
        }
        conns_list = [conn("lfo1", 0, f"{nt}1", 0)]
        return build_patch(nodes, conns_list, ann)


# ──────────────────────────────────────────────────────────────────
# Master dispatcher
# ──────────────────────────────────────────────────────────────────

AUTO_GENERATORS = {
    "top": auto_gen_top,
    "chop": auto_gen_chop,
    "sop": auto_gen_sop,
    "dat": auto_gen_dat,
    "img": auto_gen_img,
    "mat": auto_gen_mat,
    "comp": auto_gen_comp,
    "pop": auto_gen_pop,
    "vol": auto_gen_vol,
    "ui": auto_gen_ui,
    "output": auto_gen_output,
}


def generate_patches_for_op(op_info):
    """Generate 3 patches for an operator. Returns list of (filename, patch_dict)."""
    family = op_info["family"]
    nt = op_info["node_type"]

    # Check for hand-crafted patches first
    if HAS_CHOP_PATCHES and family == "chop":
        chop_patches = get_chop_patches()
        if nt in chop_patches:
            return chop_patches[nt]

    # Auto-generate
    gen = AUTO_GENERATORS.get(family)
    if gen is None:
        print(f"  WARNING: No generator for family '{family}' ({op_info['class_name']})")
        return []

    labels = make_labels(op_info)
    results = []
    for i in range(3):
        try:
            patch = gen(op_info, i)
            results.append((labels[i], patch))
        except Exception as e:
            print(f"  ERROR generating {labels[i]}: {e}")
    return results


# ──────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────

def main():
    import argparse
    parser = argparse.ArgumentParser(description="GONODES Help Patch Generator")
    parser.add_argument("--audit-only", action="store_true", help="Only audit existing patches")
    parser.add_argument("--dry-run", action="store_true", help="Don't write files, just report")
    parser.add_argument("--family", help="Only process one family")
    parser.add_argument("--operator", help="Only process one operator (node_type)")
    args = parser.parse_args()

    registry = load_registry()
    print(f"Loaded {len(registry)} operators from registry")

    # Filter
    if args.family:
        registry = [op for op in registry if op["family"] == args.family]
    if args.operator:
        registry = [op for op in registry if op["node_type"] == args.operator]

    # ── Phase 1: Audit existing patches ──
    print("\n=== AUDIT EXISTING PATCHES ===")
    audit_results = {"ok": 0, "bad": 0, "fixed": []}
    all_existing = {}

    for op in registry:
        existing = find_existing_patches(op)
        all_existing[op["node_type"]] = existing
        for patch_path in existing:
            ok, issues = audit_patch(str(patch_path), op["family"])
            if ok:
                audit_results["ok"] += 1
            else:
                audit_results["bad"] += 1
                audit_results["fixed"].append((str(patch_path), issues))
                if not args.audit_only:
                    print(f"  BAD: {patch_path.name}: {', '.join(issues)}")

    print(f"  Existing patches: {audit_results['ok']} OK, {audit_results['bad']} need fixing")

    if args.audit_only:
        for path, issues in audit_results["fixed"]:
            print(f"  BAD: {Path(path).name}: {', '.join(issues)}")
        return

    # ── Phase 2: Generate patches ──
    print("\n=== GENERATING PATCHES ===")
    stats = {"written": 0, "skipped": 0, "replaced": 0, "errors": 0}

    for op in registry:
        nt = op["node_type"]
        family = op["family"]
        help_dir = get_help_dir(op)
        existing = all_existing.get(nt, [])
        existing_names = {p.stem for p in existing}

        # Generate all 3 patches
        patches = generate_patches_for_op(op)
        if not patches:
            stats["errors"] += 1
            continue

        # Determine which we need
        needed_count = 3 - len(existing)

        if len(existing) >= 3:
            # Already have 3+ patches — audit and replace bad ones
            for patch_path in existing:
                ok, issues = audit_patch(str(patch_path), family)
                if not ok:
                    # Replace bad patch
                    if not args.dry_run:
                        # Find matching generated patch or use first available
                        for fname, patch_data in patches:
                            if fname == patch_path.stem:
                                write_patch(patch_data, str(patch_path))
                                stats["replaced"] += 1
                                print(f"  REPLACED: {patch_path.name}")
                                break
                        else:
                            # No matching name — overwrite with first generated
                            write_patch(patches[0][1], str(patch_path))
                            stats["replaced"] += 1
                            print(f"  REPLACED: {patch_path.name}")
                    else:
                        print(f"  WOULD REPLACE: {patch_path.name}")
            stats["skipped"] += max(0, len(existing) - audit_results["bad"])
        else:
            # Need to audit existing and add missing
            # First, replace bad existing ones
            for patch_path in existing:
                ok, issues = audit_patch(str(patch_path), family)
                if not ok:
                    for fname, patch_data in patches:
                        if fname == patch_path.stem:
                            if not args.dry_run:
                                write_patch(patch_data, str(patch_path))
                                stats["replaced"] += 1
                            break

            # Then add missing patches (up to 3 total)
            for fname, patch_data in patches:
                if fname in existing_names:
                    continue
                if len(existing_names) >= 3:
                    break
                filepath = help_dir / f"{fname}.gnpatch"
                if not args.dry_run:
                    write_patch(patch_data, str(filepath))
                    stats["written"] += 1
                    print(f"  NEW: {filepath.relative_to(ROOT)}")
                else:
                    print(f"  WOULD CREATE: {filepath.relative_to(ROOT)}")
                existing_names.add(fname)

    print(f"\n=== SUMMARY ===")
    print(f"  Written: {stats['written']}")
    print(f"  Replaced: {stats['replaced']}")
    print(f"  Skipped (already good): {stats['skipped']}")
    print(f"  Errors: {stats['errors']}")

    # Final count
    total_patches = 0
    for op in registry:
        help_dir = get_help_dir(op)
        nt = op["node_type"]
        if help_dir.exists():
            total_patches += len(list(help_dir.glob(f"{nt}_*.gnpatch")))
    print(f"\n  Total help patches on disk: {total_patches}")


if __name__ == "__main__":
    main()
