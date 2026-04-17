#!/usr/bin/env python3
"""Generate help .gnpatch files for the 32 operators that are missing them."""

import json
import os

# Standard blocks
def p(val):
    return {"value": val}

def pv2i(x, y):
    return {"value": {"_type": "Vector2i", "x": x, "y": y}}

def pcolor(r, g, b, a=1.0):
    return {"value": {"_type": "Color", "r": r, "g": g, "b": b, "a": a}}

def ann(text, pos=(-100, -100), size=(500, 120)):
    return [{"id": "ann_1", "type": "note", "text": text,
             "position": list(pos), "size": list(size),
             "color": [1.0, 1.0, 1.0, 0.8]}]

# Common vis chain endings
WINDOW = {
    "type": "WindowOUT", "position": [1450, 100],
    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}
}

# --- Patch definitions ---
# Each entry: (output_path, patch_dict)
patches = []


def add(path, nodes, connections, annotation_text, ann_size=(500, 120)):
    patches.append((path, {
        "version": "1.0.0",
        "generator": "GONODES",
        "nodes": nodes,
        "connections": connections,
        "annotations": ann(annotation_text, size=ann_size)
    }))


# ============================================================
# COMP — SelectCOMP
# ============================================================
add("addons/gonodes/help/comp/select_basic.gnpatch",
    {
        "geo1": {"type": "GeometryCOMP", "position": [100, 100], "parameters": {}},
        "focus1": {"type": "SelectCOMP", "position": [450, 100], "parameters": {}},
        "render1": {"type": "RenderTOP", "position": [800, 100],
                    "parameters": {"resolution": pv2i(512, 512)}},
        "cam1": {"type": "CameraCOMP", "position": [800, 300],
                 "parameters": {"tz": p(5)}},
        "window1": {"type": "WindowOUT", "position": [1150, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "geo1", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "render1", "to_port": 0},
        {"from": "cam1", "from_port": 0, "to": "render1", "to_port": 1},
        {"from": "render1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Select COMP — Basic\n\nReference another COMP by name or wire.\nUseful for re-using a component without duplicating it.")

# ============================================================
# DAT — BlackmagicDAT
# ============================================================
add("addons/gn_ext_blackmagic/help/dat/blackmagic_basic.gnpatch",
    {
        "bm1": {"type": "BlackmagicDAT", "position": [200, 100],
                "parameters": {"rescan": p(False)}},
        "dattotop1": {"type": "DATtoTOP", "position": [600, 100],
                      "parameters": {"resolution": pv2i(512, 256)}},
        "window1": {"type": "WindowOUT", "position": [1000, 100],
                    "parameters": {"resolution": pv2i(512, 256), "open": p(True)}},
    },
    [
        {"from": "bm1", "from_port": 0, "to": "dattotop1", "to_port": 0},
        {"from": "dattotop1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Blackmagic DAT — Basic\n\nLists detected Blackmagic DeckLink devices.\nOutputs a table of device names, modes, and status.\nToggle Rescan to refresh connected hardware.")

# ============================================================
# IMG — BackgroundSubtractIMG
# ============================================================
add("addons/gn_ext_opencv/help/img/bg_subtract_basic.gnpatch",
    {
        "src1": {"type": "NoiseTOP", "position": [100, 100],
                 "parameters": {"resolution": pv2i(512, 512), "monochrome": p(True)}},
        "top2img": {"type": "TOPtoIMG", "position": [400, 100], "parameters": {}},
        "focus1": {"type": "BackgroundSubtractIMG", "position": [700, 100],
                   "parameters": {"method": p(0), "history": p(500),
                                  "threshold": p(16.0), "detect_shadows": p(True),
                                  "active": p(True)}},
        "img2top": {"type": "ImgToTOP", "position": [1000, 100], "parameters": {}},
        "window1": {"type": "WindowOUT", "position": [1300, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "src1", "from_port": 0, "to": "top2img", "to_port": 0},
        {"from": "top2img", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "img2top", "to_port": 0},
        {"from": "img2top", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Background Subtract IMG — Basic\n\nSubtracts a learned background model to isolate foreground motion.\nAdjust history length and threshold to tune sensitivity.\ndetect_shadows separates shadow pixels from foreground.",
    (520, 140))

# IMG — SelectIMG
add("addons/gonodes/help/img/selectimg_basic.gnpatch",
    {
        "src1": {"type": "NoiseTOP", "position": [100, 100],
                 "parameters": {"resolution": pv2i(512, 512)}},
        "top2img": {"type": "TOPtoIMG", "position": [400, 100], "parameters": {}},
        "focus1": {"type": "SelectIMG", "position": [700, 100], "parameters": {}},
        "img2top": {"type": "ImgToTOP", "position": [1000, 100], "parameters": {}},
        "window1": {"type": "WindowOUT", "position": [1300, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "src1", "from_port": 0, "to": "top2img", "to_port": 0},
        {"from": "top2img", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "img2top", "to_port": 0},
        {"from": "img2top", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Select IMG — Basic\n\nReference another IMG operator by name or wire.\nUseful for re-using image data without duplicating processing.")

# IMG — SwitchIMG
add("addons/gonodes/help/img/switchimg_basic.gnpatch",
    {
        "src_a": {"type": "NoiseTOP", "position": [100, 100],
                  "parameters": {"resolution": pv2i(512, 512), "monochrome": p(True)}},
        "src_b": {"type": "NoiseTOP", "position": [100, 300],
                  "parameters": {"resolution": pv2i(512, 512), "seed": p(42)}},
        "top2img_a": {"type": "TOPtoIMG", "position": [400, 100], "parameters": {}},
        "top2img_b": {"type": "TOPtoIMG", "position": [400, 300], "parameters": {}},
        "focus1": {"type": "SwitchIMG", "position": [700, 200], "parameters": {}},
        "img2top": {"type": "ImgToTOP", "position": [1000, 200], "parameters": {}},
        "window1": {"type": "WindowOUT", "position": [1300, 200],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "src_a", "from_port": 0, "to": "top2img_a", "to_port": 0},
        {"from": "src_b", "from_port": 0, "to": "top2img_b", "to_port": 0},
        {"from": "top2img_a", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "top2img_b", "from_port": 0, "to": "focus1", "to_port": 1},
        {"from": "focus1", "from_port": 0, "to": "img2top", "to_port": 0},
        {"from": "img2top", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Switch IMG — Basic\n\nSelect one of multiple IMG inputs by index.\nWire several image sources and use the index parameter to pick which one passes through.")

# ============================================================
# MAT — SelectMAT / SwitchMAT
# ============================================================
add("addons/gonodes/help/mat/select_mat_basic.gnpatch",
    {
        "grid1": {"type": "GridSOP", "position": [100, 100],
                  "parameters": {"rows": p(20), "cols": p(20)}},
        "const_mat": {"type": "ConstantMAT", "position": [100, 300],
                      "parameters": {"color": pcolor(0.2, 0.8, 1.0)}},
        "focus1": {"type": "SelectMAT", "position": [450, 300], "parameters": {}},
        "geo1": {"type": "GeometryCOMP", "position": [450, 100], "parameters": {}},
        "cam1": {"type": "CameraCOMP", "position": [800, 300], "parameters": {"tz": p(4)}},
        "render1": {"type": "RenderTOP", "position": [800, 100],
                    "parameters": {"resolution": pv2i(512, 512)}},
        "window1": {"type": "WindowOUT", "position": [1150, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "grid1", "from_port": 0, "to": "geo1", "to_port": 0},
        {"from": "const_mat", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "geo1", "to_port": 1},
        {"from": "geo1", "from_port": 0, "to": "render1", "to_port": 0},
        {"from": "cam1", "from_port": 0, "to": "render1", "to_port": 1},
        {"from": "render1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Select MAT — Basic\n\nReference another material by name or wire.\nRe-use a material across multiple geometry components without duplicating it.")

add("addons/gonodes/help/mat/switch_mat_basic.gnpatch",
    {
        "grid1": {"type": "GridSOP", "position": [100, 100],
                  "parameters": {"rows": p(20), "cols": p(20)}},
        "mat_a": {"type": "ConstantMAT", "position": [100, 300],
                  "parameters": {"color": pcolor(1.0, 0.2, 0.2)}},
        "mat_b": {"type": "ConstantMAT", "position": [100, 500],
                  "parameters": {"color": pcolor(0.2, 1.0, 0.2)}},
        "focus1": {"type": "SwitchMAT", "position": [450, 400], "parameters": {}},
        "geo1": {"type": "GeometryCOMP", "position": [450, 100], "parameters": {}},
        "cam1": {"type": "CameraCOMP", "position": [800, 300], "parameters": {"tz": p(4)}},
        "render1": {"type": "RenderTOP", "position": [800, 100],
                    "parameters": {"resolution": pv2i(512, 512)}},
        "window1": {"type": "WindowOUT", "position": [1150, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "grid1", "from_port": 0, "to": "geo1", "to_port": 0},
        {"from": "mat_a", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "mat_b", "from_port": 0, "to": "focus1", "to_port": 1},
        {"from": "focus1", "from_port": 0, "to": "geo1", "to_port": 1},
        {"from": "geo1", "from_port": 0, "to": "render1", "to_port": 0},
        {"from": "cam1", "from_port": 0, "to": "render1", "to_port": 1},
        {"from": "render1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Switch MAT — Basic\n\nSelect one of multiple material inputs by index.\nWire several materials and switch between them for A/B comparison or animated transitions.")

# ============================================================
# OUTPUT — HapOUT, HostOutPOP, HostOutVOL
# ============================================================
add("addons/gn_ext_hap/help/output/hapout_basic.gnpatch",
    {
        "src1": {"type": "NoiseTOP", "position": [100, 100],
                 "parameters": {"resolution": pv2i(1920, 1080)}},
        "focus1": {"type": "HapOUT", "position": [500, 100],
                   "parameters": {"file_path": p("output.mov"),
                                  "variant": p(0), "fps": p(30),
                                  "record": p(False)}},
        "window1": {"type": "WindowOUT", "position": [900, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "src1", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "src1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Hap OUT — Basic\n\nRecord TOP texture to HAP-encoded .mov video file.\nHAP uses GPU-accelerated compression for real-time recording.\nSet file_path, fps, and toggle record to start/stop capture.",
    (520, 140))

add("addons/gonodes/help/output/host_out_pop_basic.gnpatch",
    {
        "emitter1": {"type": "EmitterPOP", "position": [100, 100],
                     "parameters": {"rate": p(200)}},
        "focus1": {"type": "HostOutPOP", "position": [500, 100],
                   "parameters": {"label": p("particles")}},
    },
    [
        {"from": "emitter1", "from_port": 0, "to": "focus1", "to_port": 0},
    ],
    "HostOut POP — Basic\n\nExpose particle data to the host application via libgonodes.\nSet label to identify this output when reading from C/C++/Python.")

add("addons/gonodes/help/output/host_out_vol_basic.gnpatch",
    {
        "noise_vol": {"type": "NoiseVOL", "position": [100, 100], "parameters": {}},
        "focus1": {"type": "HostOutVOL", "position": [500, 100],
                   "parameters": {"label": p("density")}},
    },
    [
        {"from": "noise_vol", "from_port": 0, "to": "focus1", "to_port": 0},
    ],
    "HostOut VOL — Basic\n\nExpose volume data to the host application via libgonodes.\nSet label to identify this output when reading from C/C++/Python.")

# ============================================================
# POP — HostInPOP, SelectPOP, SwitchPOP
# ============================================================
add("addons/gonodes/help/pop/host_in_pop_basic.gnpatch",
    {
        "focus1": {"type": "HostInPOP", "position": [200, 100],
                   "parameters": {"label": p("input_particles"),
                                  "max_particles": p(10000)}},
        "pstate1": {"type": "ParticleStateTOP", "position": [600, 100],
                    "parameters": {"width": p(512), "attribute": p(0)}},
        "window1": {"type": "WindowOUT", "position": [1000, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "focus1", "from_port": 0, "to": "pstate1", "to_port": 0},
        {"from": "pstate1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "HostIn POP — Basic\n\nReceive particle data from the host application via libgonodes.\nSet label to match the host's particle source name.\nmax_particles caps the buffer size.",
    (520, 140))

add("addons/gonodes/help/pop/select_basic.gnpatch",
    {
        "emit1": {"type": "EmitterPOP", "position": [100, 100],
                  "parameters": {"rate": p(500)}},
        "focus1": {"type": "SelectPOP", "position": [450, 100], "parameters": {}},
        "pstate1": {"type": "ParticleStateTOP", "position": [800, 100],
                    "parameters": {"width": p(512)}},
        "window1": {"type": "WindowOUT", "position": [1150, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "emit1", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "pstate1", "to_port": 0},
        {"from": "pstate1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Select POP — Basic\n\nReference another POP operator by name or wire.\nUseful for branching particle pipelines without duplicating emitters.")

add("addons/gonodes/help/pop/switch_basic.gnpatch",
    {
        "emit_a": {"type": "EmitterPOP", "position": [100, 100],
                   "parameters": {"rate": p(200)}},
        "emit_b": {"type": "EmitterPOP", "position": [100, 300],
                   "parameters": {"rate": p(1000)}},
        "focus1": {"type": "SwitchPOP", "position": [450, 200], "parameters": {}},
        "pstate1": {"type": "ParticleStateTOP", "position": [800, 200],
                    "parameters": {"width": p(512)}},
        "window1": {"type": "WindowOUT", "position": [1150, 200],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "emit_a", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "emit_b", "from_port": 0, "to": "focus1", "to_port": 1},
        {"from": "focus1", "from_port": 0, "to": "pstate1", "to_port": 0},
        {"from": "pstate1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Switch POP — Basic\n\nSelect one of multiple particle inputs by index.\nUseful for toggling between different emitter configurations at runtime.")

# ============================================================
# SCRIPT — NativeSCRIPT, PythonSCRIPT
# ============================================================
add("addons/gn_ext_user_native/help/script/nativescript_basic.gnpatch",
    {
        "noise1": {"type": "NoiseCHOP", "position": [100, 100],
                   "parameters": {"length": p(100)}},
        "focus1": {"type": "NativeSCRIPT", "position": [450, 100],
                   "parameters": {"template": p(0),
                                  "auto_build": p(True),
                                  "time_dep": p(False)}},
        "choptotop1": {"type": "CHOPtoTOP", "position": [800, 100],
                       "parameters": {"resolution": pv2i(512, 512)}},
        "window1": {"type": "WindowOUT", "position": [1150, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "noise1", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "choptotop1", "to_port": 0},
        {"from": "choptotop1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Native SCRIPT — Basic\n\nUser-authored C++ operator compiled at edit time.\nSet cpp_source to your .cpp file path and pick a template.\nauto_build recompiles on save. Output type follows template selection.",
    (520, 140))

add("addons/gn_ext_user_python/help/script/pythonscript_basic.gnpatch",
    {
        "noise1": {"type": "NoiseCHOP", "position": [100, 100],
                   "parameters": {"length": p(100)}},
        "focus1": {"type": "PythonSCRIPT", "position": [450, 100],
                   "parameters": {"template": p(0),
                                  "auto_reload": p(True),
                                  "time_dep": p(False)}},
        "choptotop1": {"type": "CHOPtoTOP", "position": [800, 100],
                       "parameters": {"resolution": pv2i(512, 512)}},
        "window1": {"type": "WindowOUT", "position": [1150, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "noise1", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "choptotop1", "to_port": 0},
        {"from": "choptotop1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Python SCRIPT — Basic\n\nUser-authored Python operator with hot-reload.\nSet py_source to your .py file path and pick a template.\nauto_reload refreshes on save. Output type follows template selection.",
    (520, 140))

# ============================================================
# SDF — NullSDF, SelectSDF, SwitchSDF
# ============================================================
add("addons/gn_ext_sdf/help/null_sdf_basic.gnpatch",
    {
        "sphere1": {"type": "SphereSDF", "position": [200, 200], "parameters": {}},
        "focus1": {"type": "NullSDF", "position": [550, 200], "parameters": {}},
        "raymarch1": {"type": "RaymarchSDF", "position": [900, 200],
                      "parameters": {"resolution": pv2i(512, 512),
                                     "cam_distance": p(5.0),
                                     "show_ao": p(True)}},
        "window1": {"type": "WindowOUT", "position": [1300, 200],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "sphere1", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "raymarch1", "to_port": 0},
        {"from": "raymarch1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Null SDF — Basic\n\nPass-through for SDF fields.\nUseful for organization, named references, and debugging.\nPlace between SDF operators to inspect intermediate fields.",
    (500, 130))

add("addons/gn_ext_sdf/help/select_sdf_basic.gnpatch",
    {
        "box1": {"type": "BoxSDF", "position": [200, 200], "parameters": {}},
        "focus1": {"type": "SelectSDF", "position": [550, 200], "parameters": {}},
        "raymarch1": {"type": "RaymarchSDF", "position": [900, 200],
                      "parameters": {"resolution": pv2i(512, 512),
                                     "cam_distance": p(5.0),
                                     "show_ao": p(True)}},
        "window1": {"type": "WindowOUT", "position": [1300, 200],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "box1", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "raymarch1", "to_port": 0},
        {"from": "raymarch1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Select SDF — Basic\n\nReference another SDF operator by name or wire.\nRe-use an SDF field in multiple places without recalculating it.")

add("addons/gn_ext_sdf/help/switch_sdf_basic.gnpatch",
    {
        "sphere1": {"type": "SphereSDF", "position": [200, 100], "parameters": {}},
        "box1": {"type": "BoxSDF", "position": [200, 300], "parameters": {}},
        "focus1": {"type": "SwitchSDF", "position": [550, 200], "parameters": {}},
        "raymarch1": {"type": "RaymarchSDF", "position": [900, 200],
                      "parameters": {"resolution": pv2i(512, 512),
                                     "cam_distance": p(5.0),
                                     "show_ao": p(True)}},
        "window1": {"type": "WindowOUT", "position": [1300, 200],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "sphere1", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "box1", "from_port": 0, "to": "focus1", "to_port": 1},
        {"from": "focus1", "from_port": 0, "to": "raymarch1", "to_port": 0},
        {"from": "raymarch1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Switch SDF — Basic\n\nSelect one of multiple SDF inputs by index.\nToggle between different SDF shapes or scenes at runtime.")

# ============================================================
# TOP — BlackmagicInTOP, BlackmagicOutTOP
# ============================================================
add("addons/gn_ext_blackmagic/help/top/blackmagicin_basic.gnpatch",
    {
        "focus1": {"type": "BlackmagicInTOP", "position": [200, 100],
                   "parameters": {"device": p(0),
                                  "resolution": pv2i(1920, 1080),
                                  "fps": p(30), "active": p(True)}},
        "window1": {"type": "WindowOUT", "position": [700, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "focus1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Blackmagic In TOP — Basic\n\nCapture video from a Blackmagic DeckLink device.\nSet device index, resolution, and fps to match your hardware.\nToggle active to start/stop capture.")

add("addons/gn_ext_blackmagic/help/top/blackmagicout_basic.gnpatch",
    {
        "src1": {"type": "NoiseTOP", "position": [100, 100],
                 "parameters": {"resolution": pv2i(1920, 1080)}},
        "focus1": {"type": "BlackmagicOutTOP", "position": [500, 100],
                   "parameters": {"device": p(0),
                                  "resolution": pv2i(1920, 1080),
                                  "fps": p(30), "active": p(True)}},
        "window1": {"type": "WindowOUT", "position": [900, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "src1", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "src1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Blackmagic Out TOP — Basic\n\nSend TOP texture to a Blackmagic DeckLink output.\nResolution and fps must match the device's current mode.\nToggle active to start/stop output.")

# TOP — CubeMapTOP
add("addons/gonodes/help/top/cube_map_basic.gnpatch",
    {
        "src1": {"type": "NoiseTOP", "position": [100, 100],
                 "parameters": {"resolution": pv2i(512, 512), "scale": p(2.0)}},
        "focus1": {"type": "CubeMapTOP", "position": [500, 100],
                   "parameters": {"mode": p(0), "face_size": p(256)}},
        "window1": {"type": "WindowOUT", "position": [900, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "src1", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Cube Map TOP — Basic\n\nConvert between equirectangular and cube map layouts.\nmode selects conversion direction. face_size controls output face resolution.\nUseful for environment maps and 360-degree content.")

# TOP — DepthEstimateTOP
add("addons/gn_ext_ml/help/top/depthestimate_basic.gnpatch",
    {
        "src1": {"type": "NoiseTOP", "position": [100, 100],
                 "parameters": {"resolution": pv2i(512, 512), "scale": p(3.0)}},
        "focus1": {"type": "DepthEstimateTOP", "position": [500, 100],
                   "parameters": {"resolution": pv2i(512, 512),
                                  "normalize": p(True), "active": p(True)}},
        "window1": {"type": "WindowOUT", "position": [900, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "src1", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Depth Estimate TOP — Basic\n\nEstimate depth map from a single RGB image using an ML model.\nSet model_path to your ONNX model. normalize maps output to 0-1 range.\ninvert flips near/far. Uses ONNX Runtime inference.",
    (520, 140))

# TOP — ParticleStateTOP
add("addons/gonodes/help/top/particle_state_basic.gnpatch",
    {
        "emit1": {"type": "EmitterPOP", "position": [100, 100],
                  "parameters": {"rate": p(500)}},
        "focus1": {"type": "ParticleStateTOP", "position": [500, 100],
                   "parameters": {"width": p(512), "attribute": p(0),
                                  "scale": p(1.0)}},
        "window1": {"type": "WindowOUT", "position": [900, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "emit1", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Particle State TOP — Basic\n\nVisualize POP particle attributes as a texture.\nwidth sets texture width. attribute selects which field to display\n(position, velocity, color, age, etc.). scale controls value mapping.")

# TOP — SegmentationTOP
add("addons/gn_ext_ml/help/top/segmentation_basic.gnpatch",
    {
        "src1": {"type": "NoiseTOP", "position": [100, 100],
                 "parameters": {"resolution": pv2i(512, 512)}},
        "focus1": {"type": "SegmentationTOP", "position": [500, 100],
                   "parameters": {"resolution": pv2i(512, 512),
                                  "threshold": p(0.5), "soft_mask": p(True),
                                  "active": p(True)}},
        "window1": {"type": "WindowOUT", "position": [900, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "src1", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Segmentation TOP — Basic\n\nSegment foreground/background using an ML model.\nthreshold controls mask cutoff. soft_mask outputs smooth alpha edges.\nUses ONNX Runtime. Set model_path to your segmentation model.",
    (520, 140))

# TOP — StyleTransferTOP
add("addons/gn_ext_ml/help/top/styletransfer_basic.gnpatch",
    {
        "src1": {"type": "NoiseTOP", "position": [100, 100],
                 "parameters": {"resolution": pv2i(512, 512), "scale": p(3.0)}},
        "focus1": {"type": "StyleTransferTOP", "position": [500, 100],
                   "parameters": {"resolution": pv2i(512, 512),
                                  "strength": p(1.0), "active": p(True)}},
        "window1": {"type": "WindowOUT", "position": [900, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "src1", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Style Transfer TOP — Basic\n\nApply artistic style transfer using an ML model.\nstrength controls blend between original and stylized output.\nSet model_path to your style ONNX model. Uses ONNX Runtime.")

# TOP — TestCardTOP
add("addons/gonodes/help/top/testcard_basic.gnpatch",
    {
        "focus1": {"type": "TestCardTOP", "position": [200, 100],
                   "parameters": {"resolution": pv2i(1920, 1080),
                                  "card_type": p(0),
                                  "show_grid": p(True),
                                  "show_center": p(True),
                                  "show_color_bars": p(True),
                                  "show_safe_area": p(True)}},
        "window1": {"type": "WindowOUT", "position": [700, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "focus1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Test Card TOP — Basic\n\nGenerate calibration/test pattern textures.\ncard_type selects pattern style. Toggle individual elements:\ngrid, center crosshair, color bars, grayscale ramp, safe area.\nUseful for monitor calibration and debugging output pipelines.",
    (520, 140))

# TOP — WebRenderTOP
add("addons/gn_ext_webrender/help/top/webrender_basic.gnpatch",
    {
        "focus1": {"type": "WebRenderTOP", "position": [200, 100],
                   "parameters": {"mode": p(0),
                                  "url": p("https://example.com")}},
        "window1": {"type": "WindowOUT", "position": [700, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "focus1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Web Render TOP — Basic\n\nRender a web page or custom HTML to a texture.\nmode selects URL or inline HTML. Set url for web pages.\nUse html parameter for custom markup.\nPowered by an embedded Chromium renderer.")

# ============================================================
# UI — NullUI, SwitchUI
# ============================================================
add("addons/gonodes/help/ui/null_ui_basic.gnpatch",
    {
        "slider1": {"type": "SliderUI", "position": [100, 100],
                    "parameters": {"label": p("Value"), "default_value": p(0.5)}},
        "focus1": {"type": "NullUI", "position": [450, 100], "parameters": {}},
        "window1": {"type": "WindowOUT", "position": [800, 100],
                    "parameters": {"resolution": pv2i(256, 128), "open": p(True)}},
    },
    [
        {"from": "slider1", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "window1", "to_port": 1},
    ],
    "Null UI — Basic\n\nPass-through for UI widgets.\nUseful for organizing UI chains and creating named references.")

add("addons/gonodes/help/ui/switch_ui_basic.gnpatch",
    {
        "slider_a": {"type": "SliderUI", "position": [100, 100],
                     "parameters": {"label": p("Opacity"), "default_value": p(0.7)}},
        "slider_b": {"type": "SliderUI", "position": [100, 300],
                     "parameters": {"label": p("Brightness"), "default_value": p(0.3)}},
        "focus1": {"type": "SwitchUI", "position": [450, 200], "parameters": {}},
        "window1": {"type": "WindowOUT", "position": [800, 200],
                    "parameters": {"resolution": pv2i(256, 128), "open": p(True)}},
    },
    [
        {"from": "slider_a", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "slider_b", "from_port": 0, "to": "focus1", "to_port": 1},
        {"from": "focus1", "from_port": 0, "to": "window1", "to_port": 1},
    ],
    "Switch UI — Basic\n\nSelect one of multiple UI widget inputs by index.\nToggle between different control configurations at runtime.")

# ============================================================
# VOL — HostInVOL, SelectVOL, SwitchVOL
# ============================================================
add("addons/gonodes/help/vol/host_in_vol_basic.gnpatch",
    {
        "focus1": {"type": "HostInVOL", "position": [200, 100],
                   "parameters": {"label": p("density_field"),
                                  "field_name": p("density")}},
        "raymarch1": {"type": "RaymarchVOL", "position": [600, 100], "parameters": {}},
        "window1": {"type": "WindowOUT", "position": [1000, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "focus1", "from_port": 0, "to": "raymarch1", "to_port": 0},
        {"from": "raymarch1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "HostIn VOL — Basic\n\nReceive volume data from the host application via libgonodes.\nSet label and field_name to match the host's volume source.")

add("addons/gonodes/help/vol/select_vol_basic.gnpatch",
    {
        "noise_vol": {"type": "NoiseVOL", "position": [100, 100], "parameters": {}},
        "focus1": {"type": "SelectVOL", "position": [450, 100], "parameters": {}},
        "raymarch1": {"type": "RaymarchVOL", "position": [800, 100], "parameters": {}},
        "window1": {"type": "WindowOUT", "position": [1150, 100],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "noise_vol", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "focus1", "from_port": 0, "to": "raymarch1", "to_port": 0},
        {"from": "raymarch1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Select VOL — Basic\n\nReference another VOL operator by name or wire.\nRe-use a volume field without recalculating it.")

add("addons/gonodes/help/vol/switch_vol_basic.gnpatch",
    {
        "noise_a": {"type": "NoiseVOL", "position": [100, 100], "parameters": {}},
        "noise_b": {"type": "NoiseVOL", "position": [100, 300],
                    "parameters": {"seed": p(42)}},
        "focus1": {"type": "SwitchVOL", "position": [450, 200], "parameters": {}},
        "raymarch1": {"type": "RaymarchVOL", "position": [800, 200], "parameters": {}},
        "window1": {"type": "WindowOUT", "position": [1150, 200],
                    "parameters": {"resolution": pv2i(512, 512), "open": p(True)}},
    },
    [
        {"from": "noise_a", "from_port": 0, "to": "focus1", "to_port": 0},
        {"from": "noise_b", "from_port": 0, "to": "focus1", "to_port": 1},
        {"from": "focus1", "from_port": 0, "to": "raymarch1", "to_port": 0},
        {"from": "raymarch1", "from_port": 0, "to": "window1", "to_port": 0},
    ],
    "Switch VOL — Basic\n\nSelect one of multiple volume inputs by index.\nToggle between different volume fields at runtime.")


# ============================================================
# Write all patches
# ============================================================
def main():
    created = 0
    skipped = 0
    for path, data in patches:
        full = os.path.join(os.path.dirname(__file__), "..", path)
        full = os.path.normpath(full)
        if os.path.exists(full):
            print(f"  SKIP (exists): {path}")
            skipped += 1
            continue
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8", newline="") as f:
            json.dump(data, f, indent=4)
            f.write("\n")
        print(f"  CREATED: {path}")
        created += 1
    print(f"\nDone: {created} created, {skipped} skipped (already exist)")
    print(f"Total patches defined: {len(patches)}")


if __name__ == "__main__":
    main()
