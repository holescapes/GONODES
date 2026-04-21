#!/usr/bin/env python3
"""Fix the 15 native variant help patch warnings by:
1. Cloning un-cloned original patches (replacing class name with Native variant)
2. Creating new patches where originals don't have enough to clone from.
"""

import json
import os
import copy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORE_HELP = os.path.join(ROOT, "addons", "gonodes", "help")
NATIVE_HELP = os.path.join(ROOT, "addons", "gn_ext_native", "help")

# Operators that need more native patches: (native_class, family_dir, orig_class, need_count)
# Computed from analysis: each needs enough patches to reach >= 3 total
OPERATORS = {
    "AttractPOPNative":       ("pop", "AttractPOP",       1),
    "BlendVOLNative":         ("vol", "BlendVOL",         2),
    "CHOPtoVOLNative":        ("vol", "CHOPtoVOL",        2),
    "DisplaceVOLNative":      ("vol", "DisplaceVOL",      1),
    "HeightfieldSOPNative":   ("sop", "HeightfieldSOP",   1),
    "LimitPOPNative":         ("pop", "LimitPOP",         1),
    "NoiseVOLNative":         ("vol", "NoiseVOL",         1),
    "OpticalFlowTOPNative":   ("top", "OpticalFlowTOP",   1),
    "ParticleStateTOPNative": ("top", "ParticleStateTOP", 2),
    "SOPtoCHOPNative":        ("chop", "SOPtoCHOP",       1),
    "SOPtoVOLNative":         ("vol", "SOPtoVOL",         2),
    "SourcePOPNative":        ("pop", "SourcePOP",        1),
    "TOPtoCHOPNative":        ("chop", "TOPtoCHOP",       1),
    "UVProjectSOPNative":     ("sop", "UVProjectSOP",     1),
    "VoronoiShatterSOPNative":("sop", "VoronoiShatterSOP",2),
}


def find_existing_native_patches(fam_dir, native_cls):
    """Return set of filenames that already contain this native class."""
    d = os.path.join(NATIVE_HELP, fam_dir)
    found = set()
    if not os.path.isdir(d):
        return found
    for f in os.listdir(d):
        if not f.endswith(".gnpatch"):
            continue
        with open(os.path.join(d, f), "r", encoding="utf-8") as fp:
            data = json.load(fp)
        for nd in data.get("nodes", {}).values():
            if nd.get("type") == native_cls:
                found.add(f)
                break
    return found


def find_clonable_originals(fam_dir, orig_cls, already_cloned):
    """Return list of (filename, data) for original patches containing orig_cls
    that haven't already been cloned."""
    d = os.path.join(CORE_HELP, fam_dir)
    result = []
    if not os.path.isdir(d):
        return result
    for f in sorted(os.listdir(d)):
        if not f.endswith(".gnpatch") or f in already_cloned:
            continue
        with open(os.path.join(d, f), "r", encoding="utf-8") as fp:
            data = json.load(fp)
        for nd in data.get("nodes", {}).values():
            if nd.get("type") == orig_cls:
                result.append((f, data))
                break
    return result


def clone_patch(data, orig_cls, native_cls):
    """Deep-copy patch data, replacing orig_cls with native_cls in node types."""
    cloned = copy.deepcopy(data)
    for nd in cloned.get("nodes", {}).values():
        if nd.get("type") == orig_cls:
            nd["type"] = native_cls
    return cloned


def write_patch(fam_dir, filename, data):
    """Write a .gnpatch file."""
    d = os.path.join(NATIVE_HELP, fam_dir)
    os.makedirs(d, exist_ok=True)
    fp = os.path.join(d, filename)
    with open(fp, "w", encoding="utf-8", newline="") as f:
        json.dump(data, f, indent="\t")
    return fp


# ---------- New patch templates for operators with insufficient originals ----------

V2I = lambda x, y: {"_type": "Vector2i", "x": x, "y": y}
WIN = {"resolution": {"value": V2I(512, 512)}, "open": {"value": True}}
RENDER_RES = {"resolution": {"value": V2I(512, 512)}}
RAYMARCH_DEFAULTS = {
    "width": {"value": 512}, "height": {"value": 512},
    "max_steps": {"value": 100}, "step_size": {"value": 0.012},
    "density_scale": {"value": 4.0}, "absorption": {"value": 8.0},
    "cam_dist": {"value": 2.2}
}

def pos(x, y):
    return {"_type": "Vector2i", "x": x, "y": y}


def make_vol_chain(focus_type, focus_id, focus_params, upstream_nodes, upstream_conns):
    """Build a VOL patch: upstream → focus → RaymarchVOL → WindowOUT."""
    nodes = {}
    for nid, ntype, nparams in upstream_nodes:
        nd = {"type": ntype, "position": pos(0, 0)}
        if nparams:
            nd["parameters"] = nparams
        nodes[nid] = nd

    focus_nd = {"type": focus_type, "position": pos(200, 0)}
    if focus_params:
        focus_nd["parameters"] = focus_params
    nodes[focus_id] = focus_nd

    nodes["raymarch1"] = {
        "type": "RaymarchVOL",
        "position": pos(400, 0),
        "parameters": RAYMARCH_DEFAULTS
    }
    nodes["window1"] = {
        "type": "WindowOUT",
        "position": pos(600, 0),
        "parameters": WIN
    }

    conns = list(upstream_conns) + [
        {"from": focus_id, "from_port": 0, "to": "raymarch1", "to_port": 0},
        {"from": "raymarch1", "from_port": 0, "to": "window1", "to_port": 0},
    ]
    return {"nodes": nodes, "connections": conns}


NEW_PATCHES = {
    # BlendVOLNative: 2 more needed. Create blend_weight and blend_dual_noise.
    "BlendVOLNative": [
        ("blend_weight.gnpatch", make_vol_chain(
            "BlendVOLNative", "blend1",
            {"weight": {"value": 0.3}},
            [
                ("noise_a", "NoiseVOL", {"seed": {"value": 1}, "frequency": {"value": 2.0}}),
                ("noise_b", "NoiseVOL", {"seed": {"value": 99}, "frequency": {"value": 4.0}}),
            ],
            [
                {"from": "noise_a", "from_port": 0, "to": "blend1", "to_port": 0},
                {"from": "noise_b", "from_port": 0, "to": "blend1", "to_port": 1},
            ]
        )),
        ("blend_dual_noise.gnpatch", make_vol_chain(
            "BlendVOLNative", "blend1",
            {"weight": {"value": 0.5}},
            [
                ("noise_a", "NoiseVOL", {"seed": {"value": 7}, "frequency": {"value": 1.5}, "amplitude": {"value": 0.8}}),
                ("noise_b", "NoiseVOL", {"seed": {"value": 42}, "frequency": {"value": 3.0}, "amplitude": {"value": 1.2}}),
            ],
            [
                {"from": "noise_a", "from_port": 0, "to": "blend1", "to_port": 0},
                {"from": "noise_b", "from_port": 0, "to": "blend1", "to_port": 1},
            ]
        )),
    ],

    # CHOPtoVOLNative: 2 more needed. 
    "CHOPtoVOLNative": [
        ("chop_to_vol_resolution.gnpatch", make_vol_chain(
            "CHOPtoVOLNative", "chop_to_vol1",
            {"res_x": {"value": 16}, "res_y": {"value": 16}, "res_z": {"value": 16}, "mapping": {"value": 0}},
            [
                ("noise1", "NoiseCHOP", {"seed": {"value": 10}, "channels": {"value": 3}, "roughness": {"value": 0.5}}),
            ],
            [
                {"from": "noise1", "from_port": 0, "to": "chop_to_vol1", "to_port": 0},
            ]
        )),
        ("chop_to_vol_mapping.gnpatch", make_vol_chain(
            "CHOPtoVOLNative", "chop_to_vol1",
            {"res_x": {"value": 32}, "res_y": {"value": 32}, "res_z": {"value": 32}, "mapping": {"value": 1}},
            [
                ("lfo1", "LFO_CHOP", {"frequency": {"value": 0.5}, "waveform": {"value": 0}}),
                ("noise1", "NoiseCHOP", {"seed": {"value": 5}, "channels": {"value": 3}}),
                ("merge1", "MergeCHOP", {}),
            ],
            [
                {"from": "lfo1", "from_port": 0, "to": "merge1", "to_port": 0},
                {"from": "noise1", "from_port": 0, "to": "merge1", "to_port": 1},
                {"from": "merge1", "from_port": 0, "to": "chop_to_vol1", "to_port": 0},
            ]
        )),
    ],

    # DisplaceVOLNative: 1 more needed.
    "DisplaceVOLNative": [
        ("displace_animated.gnpatch", make_vol_chain(
            "DisplaceVOLNative", "displace1",
            {"strength": {"value": 0.5}},
            [
                ("noise_vol", "NoiseVOL", {"seed": {"value": 3}, "frequency": {"value": 2.0}}),
                ("noise_vel", "NoiseVOL", {"seed": {"value": 77}, "frequency": {"value": 3.0}}),
            ],
            [
                {"from": "noise_vol", "from_port": 0, "to": "displace1", "to_port": 0},
                {"from": "noise_vel", "from_port": 0, "to": "displace1", "to_port": 1},
            ]
        )),
    ],

    # HeightfieldSOPNative: 1 more needed. SOP chain: HeightfieldSOP → GeometryCOMP + CameraCOMP → RenderTOP → WindowOUT
    "HeightfieldSOPNative": [
        ("heightfield_detailed.gnpatch", {
            "nodes": {
                "terrain1": {
                    "type": "HeightfieldSOPNative",
                    "position": pos(0, 0),
                    "parameters": {
                        "size_x": {"value": 20.0}, "size_z": {"value": 20.0},
                        "subdivisions": {"value": 256}, "height": {"value": 3.0},
                        "octaves": {"value": 8}, "frequency": {"value": 0.8},
                        "persistence": {"value": 0.45}
                    }
                },
                "geo1": {"type": "GeometryCOMP", "position": pos(200, 0)},
                "cam1": {
                    "type": "CameraCOMP",
                    "position": pos(200, 150),
                    "parameters": {
                        "tx": {"value": 5.0}, "ty": {"value": 6.0}, "tz": {"value": 12.0},
                        "rx": {"value": -30.0}, "ry": {"value": 20.0}
                    }
                },
                "render1": {
                    "type": "RenderTOP",
                    "position": pos(400, 0),
                    "parameters": RENDER_RES
                },
                "window1": {
                    "type": "WindowOUT",
                    "position": pos(600, 0),
                    "parameters": WIN
                }
            },
            "connections": [
                {"from": "terrain1", "from_port": 0, "to": "geo1", "to_port": 0},
                {"from": "geo1", "from_port": 0, "to": "render1", "to_port": 0},
                {"from": "cam1", "from_port": 0, "to": "render1", "to_port": 1},
                {"from": "render1", "from_port": 0, "to": "window1", "to_port": 0},
            ]
        }),
    ],

    # LimitPOPNative: 1 more needed. POP chain: SourcePOP → LimitPOP → RenderPOP → WindowOUT
    "LimitPOPNative": [
        ("limit_sphere.gnpatch", {
            "nodes": {
                "source1": {
                    "type": "SourcePOP",
                    "position": pos(0, 0),
                    "parameters": {"emit_rate": {"value": 200}}
                },
                "focus1": {
                    "type": "LimitPOPNative",
                    "position": pos(200, 0),
                    "parameters": {"shape": {"value": 1}, "radius": {"value": 2.0}}
                },
                "pop_render": {
                    "type": "RenderPOP",
                    "position": pos(400, 0),
                    "parameters": {"resolution": {"value": V2I(512, 512)}}
                },
                "window1": {
                    "type": "WindowOUT",
                    "position": pos(600, 0),
                    "parameters": WIN
                }
            },
            "connections": [
                {"from": "source1", "from_port": 0, "to": "focus1", "to_port": 0},
                {"from": "focus1", "from_port": 0, "to": "pop_render", "to_port": 0},
                {"from": "pop_render", "from_port": 0, "to": "window1", "to_port": 0},
            ]
        }),
    ],

    # ParticleStateTOPNative: 2 more needed. TOP chain: SourcePOP → ParticleStateTOP → WindowOUT
    "ParticleStateTOPNative": [
        ("particle_state_velocity.gnpatch", {
            "nodes": {
                "source1": {
                    "type": "SourcePOP",
                    "position": pos(0, 0),
                    "parameters": {"emit_rate": {"value": 500}}
                },
                "focus1": {
                    "type": "ParticleStateTOPNative",
                    "position": pos(200, 0),
                    "parameters": {"width": {"value": 512}, "attribute": {"value": 1}, "scale": {"value": 1.0}}
                },
                "window1": {
                    "type": "WindowOUT",
                    "position": pos(400, 0),
                    "parameters": WIN
                }
            },
            "connections": [
                {"from": "source1", "from_port": 0, "to": "focus1", "to_port": 0},
                {"from": "focus1", "from_port": 0, "to": "window1", "to_port": 0},
            ]
        }),
        ("particle_state_age.gnpatch", {
            "nodes": {
                "source1": {
                    "type": "SourcePOP",
                    "position": pos(0, 0),
                    "parameters": {"emit_rate": {"value": 300}}
                },
                "focus1": {
                    "type": "ParticleStateTOPNative",
                    "position": pos(200, 0),
                    "parameters": {"width": {"value": 512}, "attribute": {"value": 2}, "scale": {"value": 0.5}}
                },
                "window1": {
                    "type": "WindowOUT",
                    "position": pos(400, 0),
                    "parameters": WIN
                }
            },
            "connections": [
                {"from": "source1", "from_port": 0, "to": "focus1", "to_port": 0},
                {"from": "focus1", "from_port": 0, "to": "window1", "to_port": 0},
            ]
        }),
    ],
}


def main():
    total_cloned = 0
    total_created = 0

    for native_cls, (fam_dir, orig_cls, need) in OPERATORS.items():
        existing = find_existing_native_patches(fam_dir, native_cls)
        have = len(existing)
        still_need = max(0, 3 - have)

        if still_need == 0:
            print(f"  {native_cls}: already has {have} >= 3, skip")
            continue

        # Try cloning from originals first
        clonable = find_clonable_originals(fam_dir, orig_cls, existing)
        cloned = 0
        for fname, data in clonable:
            if cloned >= still_need:
                break
            patched = clone_patch(data, orig_cls, native_cls)
            fp = write_patch(fam_dir, fname, patched)
            print(f"  CLONED  {native_cls}: {fname}")
            cloned += 1
            total_cloned += 1

        still_need -= cloned

        # Create new patches if still needed
        if still_need > 0 and native_cls in NEW_PATCHES:
            templates = NEW_PATCHES[native_cls]
            for fname, data in templates:
                if still_need <= 0:
                    break
                fp = write_patch(fam_dir, fname, data)
                print(f"  CREATED {native_cls}: {fname}")
                still_need -= 1
                total_created += 1

        if still_need > 0:
            print(f"  WARNING {native_cls}: still needs {still_need} more patches!")

    print(f"\nDone: cloned={total_cloned}, created={total_created}")


if __name__ == "__main__":
    main()
