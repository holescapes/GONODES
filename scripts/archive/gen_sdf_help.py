#!/usr/bin/env python3
"""Generate all SDF help patches (3 per operator, 78 total)."""
import json, os, pathlib

OUT = pathlib.Path(r"c:\MeOwn\Gonodes\addons\gn_ext_sdf\help\top")
OUT.mkdir(parents=True, exist_ok=True)

# ---------- helpers ----------------------------------------------------------

V2I = lambda x,y: {"_type":"Vector2i","x":x,"y":y}
V3  = lambda x,y,z: {"_type":"Vector3","x":x,"y":y,"z":z}

def lfo(name, pos, freq=1.0, amp=1.0, offset=0.0, phase=0.0, wave=0):
    return name, {
        "type": "LFO_CHOP", "position": pos,
        "parameters": {
            "frequency": {"value": freq}, "amplitude": {"value": amp},
            "offset": {"value": offset}, "phase": {"value": phase},
            "waveform": {"value": wave}, "duty_cycle": {"value": 0.5}
        }
    }

def raymarch(name, pos, res=512):
    return name, {
        "type": "RaymarchSDF", "position": pos,
        "parameters": {
            "resolution": {"value": V2I(res,res)},
            "cam_distance": {"value": 5.0},
            "cam_angle_x": {"value": 0.3},
            "cam_angle_y": {"value": 0.4},
            "fov": {"value": 60.0},
            "show_ao": {"value": True},
            "soft_shadows": {"value": True}
        }
    }

def window(name, pos, res=512):
    return name, {
        "type": "WindowOUT", "position": pos,
        "parameters": {"resolution": {"value": V2I(res,res)}, "open": {"value": True}}
    }

def ann(text, px=-150, py=-180, w=520, h=120):
    return {"id":"ann_1","type":"note","text":text,
            "position":[px,py],"size":[w,h],"color":[1,1,1,0.8]}

def expr_float(expr_str, default=0.0):
    return {"mode":"EXPRESSION","value":default,
            "expression":expr_str}

def expr_v3(exprs, default=None):
    if default is None: default = V3(0,0,0)
    return {"mode":"EXPRESSION","value":default,
            "component_expressions":[
                {"expression":e,"mode":"EXPRESSION"} for e in exprs]}

def patch(nodes_list, connections, annotations):
    nodes = {}
    for n,v in nodes_list:
        nodes[n] = v
    return json.dumps({"version":"1.0.0","generator":"GONODES",
                        "nodes":nodes,"connections":connections,
                        "annotations":annotations}, indent=2)

def conn(f,fp,t,tp):
    return {"from":f,"from_port":fp,"to":t,"to_port":tp}

def write(name, content):
    (OUT / name).write_text(content, encoding="utf-8")

# ============================================================================
# PRIMITIVES   (10 × 3 = 30)
# ============================================================================

primitives = [
    # (file_prefix, class_name, default_params, anim_param, anim_desc, special_name, special_params, special_ann, special_lfo_config)
    ("sphere_sdf", "SphereSDF",
     {"radius":{"value":1.0},"position":{"value":V3(0,0,0)}},
     "radius", "Radius pulses with LFO",
     "morphing", {"radius":expr_float('abs(chop("lfo1","out",0))*0.8+0.5'),"position":{"value":V3(0,0,0)}},
     "Pulsing sphere — LFO drives the radius parameter.", (1.2, 1.0, 0.5)),
    ("box_sdf", "BoxSDF",
     {"size":{"value":V3(1,1,1)},"position":{"value":V3(0,0,0)}},
     "position", "Position.y bounces with LFO",
     "scaled", {"size":expr_v3(['abs(chop("lfo1","out",0))*0.5+0.5','abs(chop("lfo1","out",0))*0.5+0.5','abs(chop("lfo1","out",0))*0.5+0.5'], V3(1,1,1)),"position":{"value":V3(0,0,0)}},
     "Breathing box — LFO drives all size axes uniformly.", (0.8, 1.0, 0.5)),
    ("torus_sdf", "TorusSDF",
     {"major_radius":{"value":1.0},"minor_radius":{"value":0.3},"position":{"value":V3(0,0,0)}},
     "major_radius", "Major radius modulated by LFO",
     "radii", {"major_radius":expr_float('chop("lfo1","out",0)*0.4+1.0',1.0),"minor_radius":expr_float('abs(chop("lfo2","out",0))*0.15+0.15',0.3),"position":{"value":V3(0,0,0)}},
     "Both radii animated — LFO1 drives major, LFO2 drives minor.", (0.6, 0.4, 1.0)),
    ("cylinder_sdf", "CylinderSDF",
     {"radius":{"value":0.5},"height":{"value":2.0},"position":{"value":V3(0,0,0)}},
     "height", "Height driven by LFO",
     "tall", {"radius":{"value":0.5},"height":expr_float('abs(chop("lfo1","out",0))*2.0+0.5',2.0),"position":{"value":V3(0,0,0)}},
     "Growing cylinder — LFO stretches the height.", (0.5, 2.0, 1.0)),
    ("capsule_sdf", "CapsuleSDF",
     {"radius":{"value":0.3},"height":{"value":2.0},"position":{"value":V3(0,0,0)}},
     "height", "Height pulses with LFO",
     "stretch", {"radius":{"value":0.3},"height":expr_float('abs(chop("lfo1","out",0))*2.0+1.0',2.0),"position":{"value":V3(0,0,0)}},
     "Stretching capsule — LFO drives height.", (0.7, 2.0, 1.0)),
    ("plane_sdf", "PlaneSDF",
     {"normal":{"value":V3(0,1,0)},"offset":{"value":0.0}},
     "offset", "Offset slides up/down with LFO",
     "tilting", {"normal":{"value":V3(0,1,0)},"offset":expr_float('chop("lfo1","out",0)*0.5',0.0)},
     "Tilting plane — LFO modulates the offset.", (0.4, 0.5, 0.0)),
    ("cone_sdf", "ConeSDF",
     {"angle":{"value":30.0},"height":{"value":2.0},"position":{"value":V3(0,0,0)}},
     "angle", "Cone angle widens/narrows with LFO",
     "angle_sweep", {"angle":expr_float('chop("lfo1","out",0)*20.0+40.0',30.0),"height":{"value":2.0},"position":{"value":V3(0,0,0)}},
     "Angle sweep — LFO drives the cone angle from narrow to wide.", (0.3, 20.0, 40.0)),
    ("pyramid_sdf", "PyramidSDF",
     {"base":{"value":1.0},"height":{"value":1.5},"position":{"value":V3(0,0,0)}},
     "base", "Base widens with LFO",
     "growing", {"base":expr_float('abs(chop("lfo1","out",0))*0.8+0.5',1.0),"height":expr_float('abs(chop("lfo2","out",0))*1.0+0.8',1.5),"position":{"value":V3(0,0,0)}},
     "Growing pyramid — LFO1 drives base, LFO2 drives height.", (0.5, 0.8, 0.5)),
    ("octahedron_sdf", "OctahedronSDF",
     {"size":{"value":1.0},"position":{"value":V3(0,0,0)}},
     "size", "Size pulses with LFO",
     "pulsing", {"size":expr_float('abs(chop("lfo1","out",0))*0.6+0.5',1.0),"position":{"value":V3(0,0,0)}},
     "Pulsing octahedron — LFO drives the size parameter.", (1.5, 0.6, 0.5)),
    ("gyroid_sdf", "GyroidSDF",
     {"scale":{"value":1.0},"thickness":{"value":0.1},"position":{"value":V3(0,0,0)}},
     "thickness", "Thickness modulated by LFO",
     "evolving", {"scale":expr_float('chop("lfo1","out",0)*0.3+1.2',1.0),"thickness":expr_float('abs(chop("lfo2","out",0))*0.08+0.05',0.1),"position":{"value":V3(0,0,0)}},
     "Evolving gyroid — LFO1 drives scale, LFO2 drives thickness.", (0.3, 0.3, 1.2)),
]

for prim in primitives:
    pfx, cls, defaults, anim_p, anim_desc, spec_name, spec_params, spec_ann, lfo_cfg = prim
    label = cls.replace("SDF","").strip()

    # --- basic ---
    write(f"{pfx}_basic.gnpatch", patch(
        [("sdf1", {"type":cls,"position":[200,200],"parameters":defaults}),
         raymarch("raymarch1",[600,200]),
         window("window1",[1000,200])],
        [conn("sdf1",0,"raymarch1",0), conn("raymarch1",0,"window1",0)],
        [ann(f"{label} SDF — Basic\n\nDefault parameters.\nSDF primitive -> RaymarchSDF -> WindowOUT.")]
    ))

    # --- animated (position bounce or float param) ---
    if anim_p == "position":
        anim_params = dict(defaults)
        anim_params["position"] = expr_v3([
            '0', 'chop("lfo1","out",0)*1.5', '0'], V3(0,0,0))
    elif anim_p == "offset":
        anim_params = dict(defaults)
        anim_params["offset"] = expr_float('chop("lfo1","out",0)*0.5', 0.0)
    else:
        anim_params = dict(defaults)
        anim_params[anim_p] = expr_float(f'abs(chop("lfo1","out",0))*0.5+0.5', defaults.get(anim_p,{}).get("value",1.0))

    write(f"{pfx}_animated.gnpatch", patch(
        [lfo("lfo1",[60,400],freq=0.8,amp=1.0),
         ("sdf1", {"type":cls,"position":[300,200],"parameters":anim_params}),
         raymarch("raymarch1",[700,200]),
         window("window1",[1100,200])],
        [conn("sdf1",0,"raymarch1",0), conn("raymarch1",0,"window1",0)],
        [ann(f"{label} SDF — Animated\n\n{anim_desc}.\nLFO CHOP is referenced via chop() expression (no wire).")]
    ))

    # --- special ---
    lfo_nodes = [lfo("lfo1",[60,400],freq=lfo_cfg[0],amp=lfo_cfg[1],offset=lfo_cfg[2])]
    if "lfo2" in json.dumps(spec_params):
        lfo_nodes.append(lfo("lfo2",[60,580],freq=lfo_cfg[0]*1.7,amp=lfo_cfg[1]*0.8,offset=lfo_cfg[2]*0.5))
    write(f"{pfx}_{spec_name}.gnpatch", patch(
        lfo_nodes +
        [("sdf1", {"type":cls,"position":[300,200],"parameters":spec_params}),
         raymarch("raymarch1",[700,200]),
         window("window1",[1100,200])],
        [conn("sdf1",0,"raymarch1",0), conn("raymarch1",0,"window1",0)],
        [ann(f"{label} SDF — {spec_name.replace('_',' ').title()}\n\n{spec_ann}")]
    ))

# ============================================================================
# BOOLEANS   (5 × 3 = 15)
# ============================================================================

booleans = [
    ("union_sdf","UnionSDF","Union","Keeps the closer surface (min).",
     "multi", "Sphere + Box union.", {"position":{"value":V3(0.8,0,0)}}),
    ("intersection_sdf","IntersectionSDF","Intersection","Keeps only overlapping volume (max).",
     "shapes", "Sphere intersected with a box.",{"position":{"value":V3(0,0,0)}}),
    ("subtract_sdf","SubtractSDF","Subtract","Carves input B from input A.",
     "carve", "Box with sphere carved out.",{"size":{"value":V3(1.2,1.2,1.2)},"position":{"value":V3(0,0,0)}}),
    ("smooth_union_sdf","SmoothUnionSDF","Smooth Union","Blends two SDFs with adjustable smoothness.",
     "blend", "LFO drives the smoothness parameter.",{"smoothness":expr_float('abs(chop("lfo2","out",0))*0.8+0.1',0.5)}),
    ("smooth_subtract_sdf","SmoothSubtractSDF","Smooth Subtract","Smooth subtraction with blend radius.",
     "morph", "LFO drives the smoothness parameter.",{"smoothness":expr_float('abs(chop("lfo2","out",0))*0.8+0.1',0.5)}),
]

for b in booleans:
    pfx,cls,label,desc,spec_name,spec_ann,extra = b
    has_smooth = "smooth" in pfx

    # --- basic ---
    write(f"{pfx}_basic.gnpatch", patch(
        [("sphere1",{"type":"SphereSDF","position":[100,100],"parameters":{"radius":{"value":1.0},"position":{"value":V3(-0.5,0,0)}}}),
         ("sphere2",{"type":"SphereSDF","position":[100,350],"parameters":{"radius":{"value":0.8},"position":{"value":V3(0.5,0,0)}}}),
         ("bool1",{"type":cls,"position":[450,200],"parameters":({"smoothness":{"value":0.5}} if has_smooth else {})}),
         raymarch("raymarch1",[800,200]),
         window("window1",[1200,200])],
        [conn("sphere1",0,"bool1",0),conn("sphere2",0,"bool1",1),
         conn("bool1",0,"raymarch1",0),conn("raymarch1",0,"window1",0)],
        [ann(f"{label} SDF — Basic\n\n{desc}\nTwo spheres combined with {label.lower()}.")]
    ))

    # --- animated ---
    write(f"{pfx}_animated.gnpatch", patch(
        [lfo("lfo1",[0,500],freq=0.6,amp=1.5),
         ("sphere1",{"type":"SphereSDF","position":[200,100],"parameters":{"radius":{"value":1.0},"position":{"value":V3(-0.5,0,0)}}}),
         ("sphere2",{"type":"SphereSDF","position":[200,350],"parameters":{
            "radius":{"value":0.8},
            "position":expr_v3(['chop("lfo1","out",0)*1.0','0','0'],V3(0.5,0,0))}}),
         ("bool1",{"type":cls,"position":[550,200],"parameters":({"smoothness":{"value":0.5}} if has_smooth else {})}),
         raymarch("raymarch1",[900,200]),
         window("window1",[1300,200])],
        [conn("sphere1",0,"bool1",0),conn("sphere2",0,"bool1",1),
         conn("bool1",0,"raymarch1",0),conn("raymarch1",0,"window1",0)],
        [ann(f"{label} SDF — Animated\n\nLFO drives the position of sphere B.\nWatch the {label.lower()} change as spheres overlap/separate.")]
    ))

    # --- special ---
    if "subtract" in pfx or "intersection" in pfx:
        # Use box as shape A for carve/shapes demos
        sdf_a = ("box1",{"type":"BoxSDF","position":[100,100],"parameters":extra})
    else:
        sdf_a = ("sphere1",{"type":"SphereSDF","position":[100,100],"parameters":{"radius":{"value":1.0},"position":{"value":V3(-0.4,0,0)}}})

    spec_bool_params = {}
    spec_lfos = [lfo("lfo1",[0,500],freq=0.5,amp=1.2)]
    if "smooth" in pfx:
        spec_bool_params = extra  # has smoothness expression
        spec_lfos.append(lfo("lfo2",[0,680],freq=0.4,amp=0.8,offset=0.1))

    write(f"{pfx}_{spec_name}.gnpatch", patch(
        spec_lfos +
        [sdf_a,
         ("sphere_b",{"type":"SphereSDF","position":[100,350],"parameters":{
            "radius":{"value":0.9},
            "position":expr_v3(['chop("lfo1","out",0)*0.8','0','0'],V3(0.5,0,0))}}),
         ("bool1",{"type":cls,"position":[450,200],"parameters":spec_bool_params}),
         raymarch("raymarch1",[800,200]),
         window("window1",[1200,200])],
        [conn(sdf_a[0],0,"bool1",0),conn("sphere_b",0,"bool1",1),
         conn("bool1",0,"raymarch1",0),conn("raymarch1",0,"window1",0)],
        [ann(f"{label} SDF — {spec_name.replace('_',' ').title()}\n\n{spec_ann}")]
    ))

# ============================================================================
# DOMAIN MODIFIERS   (8 × 3 = 24)
# ============================================================================

modifiers = [
    # (pfx, cls, label, defaults, anim_param, anim_expr, anim_desc, spec_name, spec_params, spec_ann, spec_lfo)
    ("repeat_sdf","RepeatSDF","Repeat",
     {"spacing":{"value":V3(3,3,3)},"limit":{"value":V3(0,0,0)}},
     "spacing", None, "Spacing pulses with LFO",
     "grid", {"spacing":{"value":V3(2.5,2.5,2.5)},"limit":{"value":V3(2,2,2)}},
     "Finite grid — spacing with 2×2×2 limit for a bounded array of shapes.", None),
    ("mirror_sdf","MirrorSDF","Mirror",
     {"mirror_x":{"value":True},"mirror_y":{"value":False},"mirror_z":{"value":False}},
     None, None, "Mirror across X axis",
     "xyz", {"mirror_x":{"value":True},"mirror_y":{"value":True},"mirror_z":{"value":True}},
     "All three axes mirrored — creates 8-fold symmetry.", None),
    ("twist_sdf","TwistSDF","Twist",
     {"amount":{"value":1.0},"axis":{"value":0}},
     "amount", 'chop("lfo1","out",0)*3.0', "Twist amount animated by LFO",
     "spin", None, "Continuous twist — LFO drives twist amount for a spinning effect.",
     (0.3, 3.0, 0.0)),
    ("bend_sdf","BendSDF","Bend",
     {"amount":{"value":0.5},"axis":{"value":0}},
     "amount", 'chop("lfo1","out",0)*2.0', "Bend amount animated by LFO",
     "wave", None, "Wave bending — LFO drives bend amount back and forth.",
     (0.5, 2.0, 0.0)),
    ("elongate_sdf","ElongateSDF","Elongate",
     {"amount":{"value":V3(0,0.5,0)}},
     "amount", None, "Elongation animated by LFO",
     "stretch", None, "Stretching along Y — LFO drives the elongation amount.",
     (0.6, 1.0, 0.0)),
    ("round_sdf","RoundSDF","Round",
     {"radius":{"value":0.1}},
     "radius", 'abs(chop("lfo1","out",0))*0.3+0.02', "Rounding radius animated by LFO",
     "smooth", None, "Smooth rounding — LFO modulates rounding radius on a box.",
     (0.8, 0.3, 0.02)),
    ("onion_sdf","OnionSDF","Onion",
     {"thickness":{"value":0.1},"layers":{"value":1}},
     "thickness", 'abs(chop("lfo1","out",0))*0.15+0.03', "Thickness pulsing with LFO",
     "layers", {"thickness":{"value":0.08},"layers":{"value":3}},
     "Multi-layer onion skin — 3 concentric shells.", None),
    ("displace_sdf","DisplaceSDF","Displace",
     {"amount":{"value":0.2},"frequency":{"value":5.0},"time_offset":{"value":0.0}},
     "frequency", 'abs(chop("lfo1","out",0))*8.0+2.0', "Frequency animated by LFO",
     "organic", None, "Organic displacement — LFO drives frequency for morphing surface detail.",
     (0.4, 8.0, 2.0)),
]

for m in modifiers:
    pfx,cls,label,defaults,anim_p,anim_expr,anim_desc,spec_name,spec_params,spec_ann,spec_lfo = m

    # Use a box for round (to see rounding), sphere for others
    child_cls = "BoxSDF" if pfx in ("round_sdf","elongate_sdf") else "SphereSDF"
    child_params = {"size":{"value":V3(0.8,0.8,0.8)},"position":{"value":V3(0,0,0)}} if child_cls=="BoxSDF" else {"radius":{"value":0.8},"position":{"value":V3(0,0,0)}}

    # --- basic ---
    write(f"{pfx}_basic.gnpatch", patch(
        [("child1",{"type":child_cls,"position":[100,200],"parameters":child_params}),
         ("mod1",{"type":cls,"position":[450,200],"parameters":defaults}),
         raymarch("raymarch1",[800,200]),
         window("window1",[1200,200])],
        [conn("child1",0,"mod1",0),conn("mod1",0,"raymarch1",0),conn("raymarch1",0,"window1",0)],
        [ann(f"{label} SDF — Basic\n\nDefault {label.lower()} on a {child_cls.replace('SDF','').lower()}.\nModifier -> RaymarchSDF -> WindowOUT.")]
    ))

    # --- animated ---
    if anim_p and anim_expr:
        anim_mod_params = dict(defaults)
        anim_mod_params[anim_p] = expr_float(anim_expr, defaults.get(anim_p,{}).get("value",1.0))
    elif anim_p == "amount" and "elongate" in pfx:
        anim_mod_params = {"amount": expr_v3([
            '0', 'abs(chop("lfo1","out",0))*1.0+0.1', '0'], V3(0,0.5,0))}
    elif anim_p == "spacing":
        anim_mod_params = {"spacing": expr_v3([
            'abs(chop("lfo1","out",0))*2.0+1.5',
            'abs(chop("lfo1","out",0))*2.0+1.5',
            'abs(chop("lfo1","out",0))*2.0+1.5'], V3(3,3,3)),
            "limit":{"value":V3(0,0,0)}}
    else:
        # Mirror has no continuous anim param — animate the child position instead
        anim_mod_params = dict(defaults)

    anim_child_params = dict(child_params)
    if anim_p is None:  # mirror — animate child position instead
        anim_child_params["position"] = expr_v3([
            'chop("lfo1","out",0)*0.8', '0', '0'], V3(0,0,0))

    write(f"{pfx}_animated.gnpatch", patch(
        [lfo("lfo1",[0,450],freq=0.6,amp=1.0),
         ("child1",{"type":child_cls,"position":[200,200],"parameters":anim_child_params}),
         ("mod1",{"type":cls,"position":[550,200],"parameters":anim_mod_params}),
         raymarch("raymarch1",[900,200]),
         window("window1",[1300,200])],
        [conn("child1",0,"mod1",0),conn("mod1",0,"raymarch1",0),conn("raymarch1",0,"window1",0)],
        [ann(f"{label} SDF — Animated\n\n{anim_desc}.\nLFO CHOP referenced via chop() expression.")]
    ))

    # --- special ---
    spec_mod_params = spec_params if spec_params else dict(defaults)
    spec_child = child_cls
    spec_child_params = dict(child_params)

    if spec_lfo:
        spec_mod_params_final = dict(spec_mod_params)
        if anim_expr and spec_lfo:
            spec_mod_params_final[anim_p] = expr_float(
                anim_expr.replace("*3.0",f"*{spec_lfo[1]}").replace("*2.0",f"*{spec_lfo[1]}").replace("*8.0",f"*{spec_lfo[1]}").replace("+0.02",f"+{spec_lfo[2]}"),
                defaults.get(anim_p,{}).get("value",1.0))
        spec_lfo_nodes = [lfo("lfo1",[0,450],freq=spec_lfo[0],amp=spec_lfo[1],offset=spec_lfo[2])]
    else:
        spec_mod_params_final = spec_mod_params
        spec_lfo_nodes = []

    write(f"{pfx}_{spec_name}.gnpatch", patch(
        spec_lfo_nodes +
        [("child1",{"type":spec_child,"position":[100 if not spec_lfo_nodes else 200,200],"parameters":spec_child_params}),
         ("mod1",{"type":cls,"position":[450 if not spec_lfo_nodes else 550,200],"parameters":spec_mod_params_final}),
         raymarch("raymarch1",[800 if not spec_lfo_nodes else 900,200]),
         window("window1",[1200 if not spec_lfo_nodes else 1300,200])],
        [conn("child1",0,"mod1",0),conn("mod1",0,"raymarch1",0),conn("raymarch1",0,"window1",0)],
        [ann(f"{label} SDF — {spec_name.replace('_',' ').title()}\n\n{spec_ann}")]
    ))

# ============================================================================
# MATERIAL   (2 × 3 = 6)
# ============================================================================

# MaterialSDF
write("material_sdf_basic.gnpatch", patch(
    [("sphere1",{"type":"SphereSDF","position":[100,200],"parameters":{"radius":{"value":1.0},"position":{"value":V3(0,0,0)}}}),
     ("mat1",{"type":"MaterialSDF","position":[450,200],"parameters":{"albedo":{"value":{"_type":"Color","r":0.8,"g":0.2,"b":0.2,"a":1.0}},"roughness":{"value":0.5},"metallic":{"value":0.0},"emission":{"value":0.0}}}),
     raymarch("raymarch1",[800,200]),
     window("window1",[1200,200])],
    [conn("sphere1",0,"mat1",0),conn("mat1",0,"raymarch1",0),conn("raymarch1",0,"window1",0)],
    [ann("Material SDF — Basic\n\nRed diffuse material on a sphere.\nAlbedo, roughness, metallic, and emission parameters.")]
))

write("material_sdf_animated.gnpatch", patch(
    [lfo("lfo1",[0,450],freq=0.4,amp=1.0),
     ("sphere1",{"type":"SphereSDF","position":[200,200],"parameters":{"radius":{"value":1.0},"position":{"value":V3(0,0,0)}}}),
     ("mat1",{"type":"MaterialSDF","position":[550,200],"parameters":{
        "albedo":{"value":{"_type":"Color","r":0.8,"g":0.2,"b":0.2,"a":1.0}},
        "roughness":{"value":0.5},"metallic":{"value":0.0},
        "emission":expr_float('abs(chop("lfo1","out",0))*2.0',0.0)}}),
     raymarch("raymarch1",[900,200]),
     window("window1",[1300,200])],
    [conn("sphere1",0,"mat1",0),conn("mat1",0,"raymarch1",0),conn("raymarch1",0,"window1",0)],
    [ann("Material SDF — Animated\n\nLFO drives the emission parameter.\nThe sphere pulses with emissive glow.")]
))

write("material_sdf_metallic.gnpatch", patch(
    [("sphere1",{"type":"SphereSDF","position":[100,200],"parameters":{"radius":{"value":1.0},"position":{"value":V3(0,0,0)}}}),
     ("mat1",{"type":"MaterialSDF","position":[450,200],"parameters":{"albedo":{"value":{"_type":"Color","r":0.9,"g":0.85,"b":0.7,"a":1.0}},"roughness":{"value":0.1},"metallic":{"value":1.0},"emission":{"value":0.0}}}),
     raymarch("raymarch1",[800,200]),
     window("window1",[1200,200])],
    [conn("sphere1",0,"mat1",0),conn("mat1",0,"raymarch1",0),conn("raymarch1",0,"window1",0)],
    [ann("Material SDF — Metallic\n\nPolished gold-like material.\nHigh metallic, low roughness, warm albedo.")]
))

# GradientSDF
write("gradient_sdf_basic.gnpatch", patch(
    [("sphere1",{"type":"SphereSDF","position":[100,200],"parameters":{"radius":{"value":1.2},"position":{"value":V3(0,0,0)}}}),
     ("grad1",{"type":"GradientSDF","position":[450,200],"parameters":{"color_near":{"value":{"_type":"Color","r":1.0,"g":0.3,"b":0.1,"a":1.0}},"color_far":{"value":{"_type":"Color","r":0.1,"g":0.3,"b":1.0,"a":1.0}},"range":{"value":2.0},"roughness":{"value":0.5}}}),
     raymarch("raymarch1",[800,200]),
     window("window1",[1200,200])],
    [conn("sphere1",0,"grad1",0),conn("grad1",0,"raymarch1",0),conn("raymarch1",0,"window1",0)],
    [ann("Gradient SDF — Basic\n\nWarm-to-cool gradient mapped by distance.\nNear color (orange) to far color (blue).")]
))

write("gradient_sdf_animated.gnpatch", patch(
    [lfo("lfo1",[0,450],freq=0.3,amp=2.0,offset=2.0),
     ("sphere1",{"type":"SphereSDF","position":[200,200],"parameters":{"radius":{"value":1.2},"position":{"value":V3(0,0,0)}}}),
     ("grad1",{"type":"GradientSDF","position":[550,200],"parameters":{
        "color_near":{"value":{"_type":"Color","r":1.0,"g":0.3,"b":0.1,"a":1.0}},
        "color_far":{"value":{"_type":"Color","r":0.1,"g":0.3,"b":1.0,"a":1.0}},
        "range":expr_float('abs(chop("lfo1","out",0))*3.0+0.5',2.0),
        "roughness":{"value":0.5}}}),
     raymarch("raymarch1",[900,200]),
     window("window1",[1300,200])],
    [conn("sphere1",0,"grad1",0),conn("grad1",0,"raymarch1",0),conn("raymarch1",0,"window1",0)],
    [ann("Gradient SDF — Animated\n\nLFO drives the gradient range.\nWatch the color blend zone expand and contract.")]
))

write("gradient_sdf_warm.gnpatch", patch(
    [("torus1",{"type":"TorusSDF","position":[100,200],"parameters":{"major_radius":{"value":1.0},"minor_radius":{"value":0.35},"position":{"value":V3(0,0,0)}}}),
     ("grad1",{"type":"GradientSDF","position":[450,200],"parameters":{"color_near":{"value":{"_type":"Color","r":1.0,"g":0.8,"b":0.2,"a":1.0}},"color_far":{"value":{"_type":"Color","r":0.9,"g":0.2,"b":0.1,"a":1.0}},"range":{"value":1.5},"roughness":{"value":0.4}}}),
     raymarch("raymarch1",[800,200]),
     window("window1",[1200,200])],
    [conn("torus1",0,"grad1",0),conn("grad1",0,"raymarch1",0),conn("raymarch1",0,"window1",0)],
    [ann("Gradient SDF — Warm\n\nYellow-to-red warm gradient on a torus.\nShorter range for a more dramatic color shift.")]
))

# ============================================================================
# RAYMARCH   (1 × 3 = 3)
# ============================================================================

write("raymarch_sdf_basic.gnpatch", patch(
    [("sphere1",{"type":"SphereSDF","position":[200,200],"parameters":{"radius":{"value":1.0},"position":{"value":V3(0,0,0)}}}),
     raymarch("raymarch1",[600,200]),
     window("window1",[1000,200])],
    [conn("sphere1",0,"raymarch1",0),conn("raymarch1",0,"window1",0)],
    [ann("Raymarch SDF — Basic\n\nMinimal scene: single sphere rendered via raymarching.\nOrbit camera with AO and soft shadows enabled.")]
))

write("raymarch_sdf_camera.gnpatch", patch(
    [lfo("lfo1",[0,450],freq=0.15,amp=3.14),
     lfo("lfo2",[0,630],freq=0.1,amp=0.6,offset=0.3),
     ("sphere1",{"type":"SphereSDF","position":[200,100],"parameters":{"radius":{"value":0.6},"position":{"value":V3(0,0,0)}}}),
     ("box1",{"type":"BoxSDF","position":[200,350],"parameters":{"size":{"value":V3(0.5,0.5,0.5)},"position":{"value":V3(1.5,0,0)}}}),
     ("union1",{"type":"UnionSDF","position":[500,200],"parameters":{}}),
     ("raymarch1",{"type":"RaymarchSDF","position":[800,200],"parameters":{
        "resolution":{"value":V2I(512,512)},
        "cam_distance":{"value":6.0},
        "cam_angle_x":expr_float('chop("lfo1","out",0)',0.3),
        "cam_angle_y":expr_float('chop("lfo2","out",0)',0.4),
        "fov":{"value":60.0},"show_ao":{"value":True},"soft_shadows":{"value":True}}}),
     window("window1",[1200,200])],
    [conn("sphere1",0,"union1",0),conn("box1",0,"union1",1),
     conn("union1",0,"raymarch1",0),conn("raymarch1",0,"window1",0)],
    [ann("Raymarch SDF — Camera Orbit\n\nLFO1 drives horizontal camera angle.\nLFO2 drives vertical camera angle.\nThe camera orbits around the scene.")]
))

write("raymarch_sdf_full_scene.gnpatch", patch(
    [lfo("lfo1",[0,600],freq=0.4,amp=1.5),
     lfo("lfo2",[0,780],freq=0.25,amp=0.8,offset=0.5),
     ("sphere1",{"type":"SphereSDF","position":[200,100],"parameters":{"radius":{"value":0.8},"position":{"value":V3(0,0.3,0)}}}),
     ("box1",{"type":"BoxSDF","position":[200,350],"parameters":{"size":{"value":V3(1.2,0.3,1.2)},"position":{"value":V3(0,-0.8,0)}}}),
     ("torus1",{"type":"TorusSDF","position":[200,550],"parameters":{
        "major_radius":{"value":1.0},"minor_radius":{"value":0.15},
        "position":expr_v3(['0','chop("lfo1","out",0)*0.3','0'],V3(0,0,0))}}),
     ("smooth1",{"type":"SmoothUnionSDF","position":[500,200],"parameters":{"smoothness":{"value":0.3}}}),
     ("union1",{"type":"UnionSDF","position":[700,300],"parameters":{}}),
     ("mat1",{"type":"MaterialSDF","position":[900,300],"parameters":{
        "albedo":{"value":{"_type":"Color","r":0.7,"g":0.5,"b":0.3,"a":1.0}},
        "roughness":{"value":0.3},"metallic":{"value":0.5},"emission":{"value":0.0}}}),
     ("raymarch1",{"type":"RaymarchSDF","position":[1200,300],"parameters":{
        "resolution":{"value":V2I(512,512)},
        "cam_distance":expr_float('chop("lfo2","out",0)*1.0+5.0',5.0),
        "cam_angle_x":{"value":0.5},"cam_angle_y":{"value":0.35},
        "fov":{"value":55.0},"show_ao":{"value":True},"soft_shadows":{"value":True}}}),
     window("window1",[1600,300])],
    [conn("sphere1",0,"smooth1",0),conn("box1",0,"smooth1",1),
     conn("smooth1",0,"union1",0),conn("torus1",0,"union1",1),
     conn("union1",0,"mat1",0),conn("mat1",0,"raymarch1",0),
     conn("raymarch1",0,"window1",0)],
    [ann("Raymarch SDF — Full Scene\n\nComplex scene: sphere+box smooth union, torus, material.\nLFO1 animates torus position, LFO2 modulates camera distance.\nDemonstrates composing multiple SDF operators.", -150, -180, 600, 140)]
))

# ---------- report -----------------------------------------------------------
count = len(list(OUT.glob("*.gnpatch")))
print(f"Generated {count} help patches in {OUT}")
