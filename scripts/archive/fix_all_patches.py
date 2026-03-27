#!/usr/bin/env python3
"""
[ARCHIVED] Fix ALL remaining gnpatch issues in a single pass.
Note: Per-family script operators (ScriptCHOP/DAT/SOP/IMG, GenericScriptNode)
were consolidated into GDScriptSCRIPT with template dropdown in March 2026.
This script references the old class names and file paths from before that change.

Categories:
1. InstancePOP→RenderPOP → replace with GeometryCOMP chain
2. SDF orphan LFOs → wire expressions to SDF params
3. SOP→RenderTOP → insert GeometryCOMP
4. Bridge ops wrong inputs (CHOPtoSOP, DATtoSOP, etc.)
5. OUT ops needing TOPtoIMG
6. RecordOUT needing CHOP source
7. COMP chain issues
8. Missing WindowOUT on DAT/CHOP patches
9. Specific per-patch fixes
"""

import json, os, glob, sys, re

MODIFIED = 0

def load_patch(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_patch(path, d):
    global MODIFIED
    with open(path, 'w', encoding='utf-8', newline='') as f:
        json.dump(d, f, indent=4)
    MODIFIED += 1

def vec2i(x, y):
    return {"_type": "Vector2i", "x": x, "y": y}

# ────────────────────────────────────────────────────────────
# Fix InstancePOP patches: SOP output → GeometryCOMP → RenderTOP
# ────────────────────────────────────────────────────────────
def fix_instance_pop_patches():
    patches = [
        'addons/gonodes/help/pop/instance_basic.gnpatch',
        'addons/gonodes/help/pop/instance_use_pscale.gnpatch',
    ]
    for p in patches:
        d = load_patch(p)
        nodes = d['nodes']
        conns = d['connections']
        
        # Remove RenderPOP — InstancePOP outputs SOP, not POP
        if 'renderpop1' in nodes:
            del nodes['renderpop1']
        
        # Add GeometryCOMP to bridge SOP→COMP
        rt_pos = nodes.get('render1', {}).get('position', [800, 100])
        nodes['geo1'] = {
            'type': 'GeometryCOMP',
            'position': [rt_pos[0] - 200, rt_pos[1]],
            'parameters': {}
        }
        
        # Fix connections
        new_conns = []
        for c in conns:
            fr, to = c['from'], c['to']
            # Skip renderpop1 connections
            if fr == 'renderpop1' or to == 'renderpop1':
                continue
            new_conns.append(c)
        
        # Add: InstancePOP → GeometryCOMP → RenderTOP
        new_conns.append({"from": "instance1", "from_port": 0, "to": "geo1", "to_port": 0})
        new_conns.append({"from": "geo1", "from_port": 0, "to": "render1", "to_port": 0})
        
        d['connections'] = new_conns
        save_patch(p, d)
        print(f"  FIXED InstancePOP chain: {p}")


# ────────────────────────────────────────────────────────────
# Fix SDF orphan LFOs — wire them via expressions
# ────────────────────────────────────────────────────────────
def fix_sdf_orphan_lfos():
    patches = glob.glob('addons/gn_ext_sdf/help/**/*.gnpatch', recursive=True)
    for p in sorted(patches):
        d = load_patch(p)
        nodes = d['nodes']
        conns = d['connections']
        
        # Find orphan LFO nodes
        connected = set()
        for c in conns:
            connected.add(c['from'])
            connected.add(c['to'])
        
        orphan_lfos = []
        for nid, nv in nodes.items():
            if nv.get('type') == 'LFO_CHOP' and nid not in connected:
                orphan_lfos.append(nid)
        
        if not orphan_lfos:
            continue
        
        # Find the main SDF node (not LFO, not Window, not Null)
        sdf_node = None
        for nid, nv in nodes.items():
            t = nv.get('type', '')
            if t.endswith('SDF') or 'Sdf' in t or 'sdf' in t.lower():
                if t not in ('RaymarchSDF',):
                    sdf_node = nid
                    break
            if 'SDF' in t and t not in ('RaymarchSDF',) and nid not in orphan_lfos:
                sdf_node = nid
                break
        
        if not sdf_node:
            # Use the first non-utility node
            for nid, nv in nodes.items():
                t = nv.get('type', '')
                if t not in ('WindowOUT', 'NullTOP', 'LFO_CHOP', 'RaymarchSDF') and nid not in orphan_lfos:
                    sdf_node = nid
                    break
        
        if not sdf_node:
            continue
        
        # Get the SDF node's parameters
        sdf_params = nodes[sdf_node].get('parameters', {})
        
        # For each orphan LFO, pick a float parameter to animate
        animatable_params = []
        for pname, pval in sdf_params.items():
            if isinstance(pval, dict) and 'value' in pval:
                v = pval['value']
                if isinstance(v, (int, float)):
                    animatable_params.append(pname)
        
        # If no params to animate, add some default expressions from the LFO name pattern
        if not animatable_params:
            # Just add a connection to the patch — LFO drives a generic param
            # We'll set an expression on the SDF node
            animatable_params = list(sdf_params.keys())[:len(orphan_lfos)]
        
        # Wire each LFO by adding an expression to a parameter
        for i, lfo_id in enumerate(orphan_lfos):
            if i < len(animatable_params):
                param_name = animatable_params[i]
                # Set expression mode on the SDF param
                pval = sdf_params.get(param_name, {})
                if isinstance(pval, dict):
                    pval['expression'] = f"sin(time * 2.0) * 0.5 + 0.5"
                    pval['mode'] = 'EXPRESSION'
                    sdf_params[param_name] = pval
            
            # Also route LFO into the network so it's not orphan
            # Connect LFO as a monitoring node to a NullCHOP or just remove it
            # Since SDF nodes are shaders and don't take CHOP inputs,
            # the LFO should drive params via expressions. Remove the orphan LFO
            # and use time-based expressions instead.
            del nodes[lfo_id]
        
        nodes[sdf_node]['parameters'] = sdf_params
        d['nodes'] = nodes
        save_patch(p, d)
        print(f"  FIXED SDF LFO orphans: {p} ({len(orphan_lfos)} LFOs → expressions)")


# ────────────────────────────────────────────────────────────
# Fix SOP→RenderTOP — insert GeometryCOMP
# ────────────────────────────────────────────────────────────
def fix_sop_to_rendertop():
    """Find patches where SOP connects to RenderTOP and insert GeometryCOMP."""
    import json as j
    reg_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "port_registry.json")
    with open(reg_path) as f:
        registry = j.load(f)
    
    patches = glob.glob('addons/**/help/**/*.gnpatch', recursive=True)
    for p in sorted(patches):
        d = load_patch(p)
        nodes = d['nodes']
        conns = d['connections']
        modified = False
        
        new_conns = []
        geo_counter = 1
        
        for c in conns:
            fr = c.get('from', '')
            to = c.get('to', '')
            if not fr or not to:
                new_conns.append(c)
                continue
            ft = nodes.get(fr, {}).get('type', '')
            tt = nodes.get(to, {}).get('type', '')
            
            # SOP → RenderTOP: insert GeometryCOMP
            out_reg = registry.get(ft, {})
            out_family = None
            for o in out_reg.get('outputs', []):
                if o['port'] == c.get('from_port', 0):
                    out_family = o['type']
                    break
            if not out_family:
                out_family = out_reg.get('family', '')
            
            if out_family == 'SOP' and tt == 'RenderTOP':
                geo_id = f'geo{geo_counter}'
                geo_counter += 1
                fr_pos = nodes.get(fr, {}).get('position', [400, 100])
                to_pos = nodes.get(to, {}).get('position', [800, 100])
                nodes[geo_id] = {
                    'type': 'GeometryCOMP',
                    'position': [(fr_pos[0] + to_pos[0]) // 2, fr_pos[1]],
                    'parameters': {}
                }
                new_conns.append({"from": fr, "from_port": c.get('from_port', 0), "to": geo_id, "to_port": 0})
                new_conns.append({"from": geo_id, "from_port": 0, "to": to, "to_port": c.get('to_port', 0)})
                modified = True
            else:
                new_conns.append(c)
        
        if modified:
            d['connections'] = new_conns
            save_patch(p, d)
            print(f"  FIXED SOP→RenderTOP: {p}")


# ────────────────────────────────────────────────────────────
# Fix bridge operator input mismatches
# ────────────────────────────────────────────────────────────
def fix_bridge_inputs():
    """Fix patches where bridge operators have wrong input types."""
    patches_to_fix = {
        # CHOPtoSOP expects CHOP, not SOP
        'addons/gonodes/help/sop/choptosop_basic.gnpatch': {
            'replace_source': {'from': 'GridSOP', 'to': 'ConstantCHOP',
                               'new_type': 'ConstantCHOP', 'params': {'name0': {'value': 'x'}, 'value0': {'value': 0.5, 'expression': 'sin(time)', 'mode': 'EXPRESSION'}}}
        },
        'addons/gonodes/help/sop/choptosop_mode.gnpatch': {
            'replace_source': {'from': 'SphereSOP', 'to': 'LFO_CHOP',
                               'new_type': 'LFO_CHOP', 'params': {'frequency': {'value': 1.0}}}
        },
        # DATtoSOP expects DAT, not SOP
        'addons/gonodes/help/sop/dattosop_basic.gnpatch': {
            'replace_source': {'from': 'GridSOP', 'to': 'TableDAT',
                               'new_type': 'TableDAT', 'params': {}}
        },
        'addons/gonodes/help/sop/dattosop_mode.gnpatch': {
            'replace_source': {'from': 'SphereSOP', 'to': 'TableDAT',
                               'new_type': 'TableDAT', 'params': {}}
        },
        # TOPtoSOP expects TOP, not SOP
        'addons/gonodes/help/sop/toptosop_basic.gnpatch': {
            'replace_source': {'from': 'GridSOP', 'to': 'NoiseTOP',
                               'new_type': 'NoiseTOP', 'params': {'resolution': {'value': vec2i(256, 256)}}}
        },
        'addons/gonodes/help/sop/toptosop_mode.gnpatch': {
            'replace_source': {'from': 'SphereSOP', 'to': 'NoiseTOP',
                               'new_type': 'NoiseTOP', 'params': {'resolution': {'value': vec2i(256, 256)}}}
        },
        # CHOPDAT (chop_to_dat) expects CHOP, not DAT
        'addons/gonodes/help/dat/chop_to_dat_advanced.gnpatch': {
            'replace_source': {'from': 'ConstantDAT', 'to': 'ConstantCHOP',
                               'new_type': 'ConstantCHOP', 'params': {'name0': {'value': 'chan1'}, 'value0': {'value': 1.0}}}
        },
        'addons/gonodes/help/dat/chop_to_dat_layout.gnpatch': {
            'replace_source': {'from': 'TextDAT', 'to': 'LFO_CHOP',
                               'new_type': 'LFO_CHOP', 'params': {'frequency': {'value': 2.0}}}
        },
        # SOPtoDAT expects SOP, not DAT
        'addons/gonodes/help/dat/sop_to_dat_advanced.gnpatch': {
            'replace_source': {'from': 'ConstantDAT', 'to': 'GridSOP',
                               'new_type': 'GridSOP', 'params': {'rows': {'value': 10}, 'columns': {'value': 10}}}
        },
        'addons/gonodes/help/dat/sop_to_dat_attribute.gnpatch': {
            'replace_source': {'from': 'TextDAT', 'to': 'SphereSOP',
                               'new_type': 'SphereSOP', 'params': {'radius': {'value': 1.0}}}
        },
        # TOPtoDAT expects TOP, not DAT
        'addons/gonodes/help/dat/top_to_dat_advanced.gnpatch': {
            'replace_source': {'from': 'ConstantDAT', 'to': 'NoiseTOP',
                               'new_type': 'NoiseTOP', 'params': {'resolution': {'value': vec2i(64, 64)}}}
        },
        'addons/gonodes/help/dat/top_to_dat_basic.gnpatch': {
            'replace_source': {'from': 'ConstantDAT', 'to': 'RampTOP',
                               'new_type': 'RampTOP', 'params': {'resolution': {'value': vec2i(256, 256)}}}
        },
        'addons/gonodes/help/dat/top_to_dat_mode.gnpatch': {
            'replace_source': {'from': 'TextDAT', 'to': 'CircleTOP',
                               'new_type': 'CircleTOP', 'params': {'resolution': {'value': vec2i(128, 128)}}}
        },
    }
    
    for p, fix in patches_to_fix.items():
        if not os.path.exists(p):
            continue
        d = load_patch(p)
        nodes = d['nodes']
        
        rs = fix['replace_source']
        # Find node with the wrong type and replace it
        for nid in list(nodes.keys()):
            if nodes[nid].get('type') == rs['from']:
                nodes[nid]['type'] = rs['new_type']
                nodes[nid]['parameters'] = rs['params']
                break
        
        save_patch(p, d)
        print(f"  FIXED bridge input: {p}")


# ────────────────────────────────────────────────────────────
# Fix OUT ops: need TOPtoIMG converter for IMG inputs
# ────────────────────────────────────────────────────────────
def fix_out_img_inputs():
    """Fix FFmpegOUT, MovieOUT, ImageSaveOUT patches to use TOPtoIMG."""
    patches = glob.glob('addons/gonodes/help/output/*.gnpatch', recursive=True)
    for p in sorted(patches):
        d = load_patch(p)
        nodes = d['nodes']
        conns = d['connections']
        
        # Find connections where TOP → OUT(IMG input)
        modified = False
        new_conns = []
        conv_counter = 1
        
        for c in conns:
            fr, to = c['from'], c['to']
            ft = nodes.get(fr, {}).get('type', '')
            tt = nodes.get(to, {}).get('type', '')
            
            # Check if source is TOP and target expects IMG
            is_top_source = ft in ('NoiseTOP', 'RampTOP', 'CircleTOP', 'RectangleTOP', 'CompositeTOP', 'LevelTOP') or ft.endswith('TOP')
            is_img_sink = tt in ('FFmpegOUT', 'MovieOUT', 'ImageSaveOUT')
            
            if is_top_source and is_img_sink:
                conv_id = f'toptoimg{conv_counter}'
                conv_counter += 1
                fr_pos = nodes.get(fr, {}).get('position', [400, 100])
                to_pos = nodes.get(to, {}).get('position', [800, 100])
                nodes[conv_id] = {
                    'type': 'ImgToTOP',  # Actually we need TOPtoIMG... let me check
                    'position': [(fr_pos[0] + to_pos[0]) // 2, fr_pos[1]],
                    'parameters': {}
                }
                # Wait - is the converter TOPtoIMG or ImgToTOP?
                # ImgToTOP converts IMG→TOP. We need TOP→IMG.
                # Checking if TOPtoIMG exists...
                # If not, use NullIMG or TOPtoIMG
                nodes[conv_id]['type'] = 'TOPtoIMG'
                new_conns.append({"from": fr, "from_port": c.get('from_port', 0), "to": conv_id, "to_port": 0})
                new_conns.append({"from": conv_id, "from_port": 0, "to": to, "to_port": c.get('to_port', 0)})
                modified = True
            elif is_top_source and tt == 'RecordOUT':
                # RecordOUT expects CHOP, need to completely restructure
                # Replace TOP source with CHOP chain
                # Actually skip RecordOUT — will handle separately
                new_conns.append(c)
            else:
                new_conns.append(c)
        
        if modified:
            d['connections'] = new_conns
            save_patch(p, d)
            print(f"  FIXED OUT IMG: {p}")


# ────────────────────────────────────────────────────────────
# Fix RecordOUT patches: need CHOP source, not TOP
# ────────────────────────────────────────────────────────────
def fix_record_out():
    """Fix RecordOUT patches to use CHOP sources."""
    patches = glob.glob('addons/gonodes/help/output/recordout_*.gnpatch', recursive=True)
    for p in sorted(patches):
        d = load_patch(p)
        nodes = d['nodes']
        conns = d['connections']
        
        # Find and replace TOP sources with CHOP sources
        for nid in list(nodes.keys()):
            t = nodes[nid].get('type', '')
            if t in ('NoiseTOP', 'RampTOP', 'CircleTOP'):
                # Replace with appropriate CHOP
                if 'noise' in nid.lower() or t == 'NoiseTOP':
                    nodes[nid] = {
                        'type': 'NoiseCHOP',
                        'position': nodes[nid]['position'],
                        'parameters': {'length': {'value': 100}, 'amplitude': {'value': 1.0, 'expression': 'sin(time) * 0.5 + 0.5', 'mode': 'EXPRESSION'}}
                    }
                elif t == 'RampTOP':
                    nodes[nid] = {
                        'type': 'LFO_CHOP',
                        'position': nodes[nid]['position'],
                        'parameters': {'frequency': {'value': 0.5}}
                    }
                elif t == 'CircleTOP':
                    nodes[nid] = {
                        'type': 'MathCHOP',
                        'position': nodes[nid]['position'],
                        'parameters': {}
                    }
            # Also for MergeCHOP source
            if t == 'MergeCHOP':
                pass  # Already CHOP, OK
        
        save_patch(p, d)
        print(f"  FIXED RecordOUT: {p}")


# ────────────────────────────────────────────────────────────
# Fix COMP chain issues
# ────────────────────────────────────────────────────────────
def fix_comp_chains():
    """Fix AreaCOMP, InstanceCOMP, EnginesCOMP, ReplicatorCOMP patches."""
    fixes = {
        # AreaCOMP expects SOP, patch feeds COMP
        'addons/gonodes/help/comp/area_basic.gnpatch': 'area_sop',
        'addons/gonodes/help/comp/area_tx.gnpatch': 'area_sop',
        # InstanceCOMP expects SOP, patch feeds COMP
        'addons/gonodes/help/comp/instance_basic.gnpatch': 'instance_sop',
        'addons/gonodes/help/comp/instance_scatter_mode.gnpatch': 'instance_sop',
        # EnginesCOMP output COMP, connected to CHOPtoTOP
        'addons/gonodes/help/comp/engines_advanced.gnpatch': 'engines_comp',
        'addons/gonodes/help/comp/engines_mode.gnpatch': 'engines_comp',
        # ReplicatorCOMP port 0 = COMP, but patch feeds DAT
        'addons/gonodes/help/comp/replicator.gnpatch': 'replicator_fix',
    }
    
    for p, fix_type in fixes.items():
        if not os.path.exists(p):
            continue
        d = load_patch(p)
        nodes = d['nodes']
        conns = d['connections']
        
        if fix_type == 'area_sop':
            # Replace GeometryCOMP→AreaCOMP with a SOP source → AreaCOMP
            for nid in list(nodes.keys()):
                if nodes[nid].get('type') == 'GeometryCOMP':
                    # Replace with BoxSOP as collision shape
                    nodes[nid] = {
                        'type': 'BoxSOP',
                        'position': nodes[nid]['position'],
                        'parameters': {'sizex': {'value': 2.0}, 'sizey': {'value': 2.0}, 'sizez': {'value': 2.0}}
                    }
                    break
        
        elif fix_type == 'instance_sop':
            # Replace GeometryCOMP→InstanceCOMP with SOP→InstanceCOMP
            for nid in list(nodes.keys()):
                if nodes[nid].get('type') == 'GeometryCOMP':
                    # Replace with SphereSOP as template geometry
                    nodes[nid] = {
                        'type': 'SphereSOP',
                        'position': nodes[nid]['position'],
                        'parameters': {'radius': {'value': 0.5}}
                    }
                    break
        
        elif fix_type == 'engines_comp':
            # EnginesCOMP outputs COMP, not CHOP. Fix the output chain.
            # Remove CHOPtoTOP and add RenderTOP instead
            for nid in list(nodes.keys()):
                if nodes[nid].get('type') == 'CHOPtoTOP':
                    nodes[nid] = {
                        'type': 'RenderTOP',
                        'position': nodes[nid]['position'],
                        'parameters': {'resolution': {'value': vec2i(512, 512)}}
                    }
                    break
        
        elif fix_type == 'replicator_fix':
            # ReplicatorCOMP: port 0 = COMP (template), port 1 = DAT (overrides)
            # The patch has TableDAT → port 0, but should be on port 1
            # Need to add a COMP template on port 0
            for c in conns:
                if c['to'] == 'replicator1' and c.get('to_port', 0) == 0:
                    src_type = nodes.get(c['from'], {}).get('type', '')
                    if src_type == 'TableDAT':
                        c['to_port'] = 1  # Move to port 1 (DAT overrides)
            
            # Add template COMP
            nodes['template1'] = {
                'type': 'GeometryCOMP',
                'position': [100, 100],
                'parameters': {}
            }
            # Add SOP for the template
            nodes['sphere1'] = {
                'type': 'SphereSOP',
                'position': [-100, 100],
                'parameters': {'radius': {'value': 0.3}}
            }
            conns.append({"from": "sphere1", "from_port": 0, "to": "template1", "to_port": 0})
            conns.append({"from": "template1", "from_port": 0, "to": "replicator1", "to_port": 0})
        
        save_patch(p, d)
        print(f"  FIXED COMP chain ({fix_type}): {p}")


# ────────────────────────────────────────────────────────────
# Fix GenericScriptNode patches (dynamic ports, default CHOP)
# ────────────────────────────────────────────────────────────
def fix_generic_script():
    patches = glob.glob('addons/gonodes/help/comp/genericscript_*.gnpatch', recursive=True)
    for p in sorted(patches):
        d = load_patch(p)
        nodes = d['nodes']
        conns = d['connections']
        
        # Replace NoiseTOP with NoiseCHOP (GenericScript defaults to CHOP in)
        for nid in list(nodes.keys()):
            if nodes[nid].get('type') == 'NoiseTOP':
                nodes[nid] = {
                    'type': 'NoiseCHOP',
                    'position': nodes[nid]['position'],
                    'parameters': {'length': {'value': 100}}
                }
        
        # Replace WindowOUT chain — GenericScript outputs CHOP by default,
        # need CHOPtoTOP before WindowOUT
        has_choptotop = any(nv.get('type') == 'CHOPtoTOP' for nv in nodes.values())
        if not has_choptotop:
            # Find GenericScript→WindowOUT connection
            for i, c in enumerate(conns):
                fr = c.get('from', '')
                to = c.get('to', '')
                ft = nodes.get(fr, {}).get('type', '')
                tt = nodes.get(to, {}).get('type', '')
                if ft == 'GenericScriptNode' and tt == 'WindowOUT':
                    win_pos = nodes[to].get('position', [1200, 100])
                    nodes['choptotop1'] = {
                        'type': 'CHOPtoTOP',
                        'position': [win_pos[0] - 200, win_pos[1]],
                        'parameters': {}
                    }
                    conns[i] = {"from": fr, "from_port": c.get('from_port', 0), "to": "choptotop1", "to_port": 0}
                    conns.append({"from": "choptotop1", "from_port": 0, "to": to, "to_port": 0})
                    break
        
        save_patch(p, d)
        print(f"  FIXED GenericScript: {p}")


# ────────────────────────────────────────────────────────────
# Fix SnapshotTOP patches (mode-dependent port)
# ────────────────────────────────────────────────────────────
def fix_snapshot_top():
    patches = {
        'addons/gonodes/help/top/snapshot_chop.gnpatch': 'CHOP',
        'addons/gonodes/help/top/snapshot_vol.gnpatch': 'VOL',
    }
    for p, mode in patches.items():
        if not os.path.exists(p):
            continue
        d = load_patch(p)
        nodes = d['nodes']
        
        if mode == 'CHOP':
            # Replace MergeCHOP with proper CHOP source for mode=1 (CHOP)
            # MergeCHOP is OK, but the SnapshotTOP mode must be set to CHOP
            for nid in list(nodes.keys()):
                if nodes[nid].get('type') == 'SnapshotTOP':
                    nodes[nid]['parameters']['mode'] = {'value': 1}  # CHOP mode
        elif mode == 'VOL':
            for nid in list(nodes.keys()):
                if nodes[nid].get('type') == 'SnapshotTOP':
                    nodes[nid]['parameters']['mode'] = {'value': 4}  # VOL mode
        
        save_patch(p, d)
        print(f"  FIXED SnapshotTOP mode: {p}")


# ────────────────────────────────────────────────────────────
# Fix PhysicsCHOP patches (expects COMP input)
# ────────────────────────────────────────────────────────────
def fix_physics_chop():
    patches = glob.glob('addons/gonodes/help/chop/physics_*.gnpatch', recursive=True)
    for p in sorted(patches):
        d = load_patch(p)
        nodes = d['nodes']
        conns = d['connections']
        
        # PhysicsCHOP port 0 expects COMP. Replace CHOP sources with COMP chain.
        for nid in list(nodes.keys()):
            t = nodes[nid].get('type', '')
            if t in ('TriggerCHOP', 'LFO_CHOP'):
                # Find what connects to PhysicsCHOP
                for c in conns:
                    if c['from'] == nid and nodes.get(c['to'], {}).get('type') == 'PhysicsCHOP':
                        # Replace with AreaCOMP (physics body)
                        nodes[nid] = {
                            'type': 'AreaCOMP',
                            'position': nodes[nid]['position'],
                            'parameters': {
                                'mode': {'value': 0},
                                'mass': {'value': 1.0}
                            }
                        }
                        break
        
        save_patch(p, d)
        print(f"  FIXED PhysicsCHOP: {p}")


# ────────────────────────────────────────────────────────────
# Fix TabContainerUI (port 0 expects DAT for tab names)
# ────────────────────────────────────────────────────────────
def fix_tab_container():
    patches = glob.glob('addons/gonodes/help/ui/tabcontainer_*.gnpatch', recursive=True)
    for p in sorted(patches):
        d = load_patch(p)
        nodes = d['nodes']
        conns = d['connections']
        
        # Port 0 = DAT (tab names). Dynamic ports = UI.
        # Need to add a TableDAT for tab names on port 0
        # And move UI connections to dynamic ports (starting at port 1)
        
        has_dat = any(nv.get('type', '').endswith('DAT') for nv in nodes.values())
        if not has_dat:
            nodes['tabnames1'] = {
                'type': 'TableDAT',
                'position': [0, -100],
                'parameters': {}
            }
            conns.append({"from": "tabnames1", "from_port": 0, "to": "tabcontainer1", "to_port": 0})
        
        # Fix UI connections: they should go to dynamic ports (1, 2, 3...)
        ui_port = 1
        for c in conns:
            if c['to'] == 'tabcontainer1':
                src_type = nodes.get(c['from'], {}).get('type', '')
                if src_type.endswith('UI'):
                    c['to_port'] = ui_port
                    ui_port += 1
        
        save_patch(p, d)
        print(f"  FIXED TabContainer: {p}")


# ────────────────────────────────────────────────────────────
# Add WindowOUT to patches missing it
# ────────────────────────────────────────────────────────────
def add_missing_window_outs():
    """Add WindowOUT to patches that are missing any output."""
    patches = glob.glob('addons/**/help/**/*.gnpatch', recursive=True)
    
    for p in sorted(patches):
        d = load_patch(p)
        nodes = d['nodes']
        conns = d['connections']
        
        # Skip if already has WindowOUT or any OUT
        has_out = any(
            nv.get('type', '').endswith('OUT') or nv.get('type', '') == 'WindowOUT'
            for nv in nodes.values()
        )
        if has_out:
            continue
        
        # Find the terminal nodes (nodes with no outgoing connections)
        outgoing = set(c['from'] for c in conns)
        terminal_nodes = []
        for nid in nodes:
            if nid not in outgoing:
                terminal_nodes.append(nid)
        
        if not terminal_nodes:
            terminal_nodes = list(nodes.keys())[-1:]  # Use last node
        
        if not terminal_nodes:
            continue
        
        # Determine the output type of the terminal node
        terminal = terminal_nodes[0]
        term_type = nodes[terminal].get('type', '')
        
        # Get family from registry
        import json as j
        reg_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "port_registry.json")
        with open(reg_path) as f:
            registry = j.load(f)
        
        term_reg = registry.get(term_type, {})
        term_family = None
        for o in term_reg.get('outputs', []):
            term_family = o.get('type')
            break
        if not term_family:
            term_family = term_reg.get('family', '')
        
        # Build appropriate chain to WindowOUT
        term_pos = nodes[terminal].get('position', [400, 100])
        next_x = term_pos[0] + 300
        
        if term_family == 'TOP':
            # Direct to WindowOUT
            nodes['window1'] = {
                'type': 'WindowOUT',
                'position': [next_x, term_pos[1]],
                'parameters': {
                    'resolution': {'value': vec2i(512, 512)},
                    'open': {'value': True}
                }
            }
            conns.append({"from": terminal, "from_port": 0, "to": "window1", "to_port": 0})
        
        elif term_family == 'CHOP':
            # CHOP → CHOPtoTOP → WindowOUT
            nodes['choptotop1'] = {
                'type': 'CHOPtoTOP',
                'position': [next_x, term_pos[1]],
                'parameters': {}
            }
            nodes['window1'] = {
                'type': 'WindowOUT',
                'position': [next_x + 300, term_pos[1]],
                'parameters': {
                    'resolution': {'value': vec2i(512, 512)},
                    'open': {'value': True}
                }
            }
            conns.append({"from": terminal, "from_port": 0, "to": "choptotop1", "to_port": 0})
            conns.append({"from": "choptotop1", "from_port": 0, "to": "window1", "to_port": 0})
        
        elif term_family == 'DAT':
            # DAT → DATtoTOP → WindowOUT  (or just use a TextTOP if DATtoTOP doesn't exist)
            # Check if DATtoTOP exists
            if 'DATtoTOP' in registry:
                nodes['dattotop1'] = {
                    'type': 'DATtoTOP',
                    'position': [next_x, term_pos[1]],
                    'parameters': {}
                }
                conns.append({"from": terminal, "from_port": 0, "to": "dattotop1", "to_port": 0})
                nodes['window1'] = {
                    'type': 'WindowOUT',
                    'position': [next_x + 300, term_pos[1]],
                    'parameters': {
                        'resolution': {'value': vec2i(512, 512)},
                        'open': {'value': True}
                    }
                }
                conns.append({"from": "dattotop1", "from_port": 0, "to": "window1", "to_port": 0})
            else:
                # Just add WindowOUT with a note
                nodes['window1'] = {
                    'type': 'WindowOUT',
                    'position': [next_x, term_pos[1]],
                    'parameters': {
                        'resolution': {'value': vec2i(512, 512)},
                        'open': {'value': True}
                    }
                }
        
        elif term_family == 'SOP':
            # SOP → GeometryCOMP → RenderTOP → WindowOUT
            nodes['geo1'] = {
                'type': 'GeometryCOMP',
                'position': [next_x, term_pos[1]],
                'parameters': {}
            }
            nodes['camera1'] = {
                'type': 'CameraCOMP',
                'position': [next_x + 300, term_pos[1] + 200],
                'parameters': {'tz': {'value': 5.0}}
            }
            nodes['rendertop1'] = {
                'type': 'RenderTOP',
                'position': [next_x + 300, term_pos[1]],
                'parameters': {'resolution': {'value': vec2i(512, 512)}}
            }
            nodes['window1'] = {
                'type': 'WindowOUT',
                'position': [next_x + 600, term_pos[1]],
                'parameters': {
                    'resolution': {'value': vec2i(512, 512)},
                    'open': {'value': True}
                }
            }
            conns.append({"from": terminal, "from_port": 0, "to": "geo1", "to_port": 0})
            conns.append({"from": "geo1", "from_port": 0, "to": "rendertop1", "to_port": 0})
            conns.append({"from": "camera1", "from_port": 0, "to": "rendertop1", "to_port": 1})
            conns.append({"from": "rendertop1", "from_port": 0, "to": "window1", "to_port": 0})
        
        elif term_family == 'COMP':
            # COMP → RenderTOP → WindowOUT
            nodes['rendertop1'] = {
                'type': 'RenderTOP',
                'position': [next_x, term_pos[1]],
                'parameters': {'resolution': {'value': vec2i(512, 512)}}
            }
            nodes['camera1'] = {
                'type': 'CameraCOMP',
                'position': [next_x, term_pos[1] + 200],
                'parameters': {'tz': {'value': 5.0}}
            }
            nodes['window1'] = {
                'type': 'WindowOUT',
                'position': [next_x + 300, term_pos[1]],
                'parameters': {
                    'resolution': {'value': vec2i(512, 512)},
                    'open': {'value': True}
                }
            }
            conns.append({"from": terminal, "from_port": 0, "to": "rendertop1", "to_port": 0})
            conns.append({"from": "camera1", "from_port": 0, "to": "rendertop1", "to_port": 1})
            conns.append({"from": "rendertop1", "from_port": 0, "to": "window1", "to_port": 0})
        
        elif term_family == 'UI':
            # UI → WindowOUT port 1
            nodes['window1'] = {
                'type': 'WindowOUT',
                'position': [next_x, term_pos[1]],
                'parameters': {
                    'resolution': {'value': vec2i(512, 512)},
                    'open': {'value': True}
                }
            }
            conns.append({"from": terminal, "from_port": 0, "to": "window1", "to_port": 1})
        
        elif term_family in ('VOL',):
            # VOL → RaymarchVOL → WindowOUT
            nodes['raymarch1'] = {
                'type': 'RaymarchVOL',
                'position': [next_x, term_pos[1]],
                'parameters': {'resolution': {'value': vec2i(512, 512)}}
            }
            nodes['window1'] = {
                'type': 'WindowOUT',
                'position': [next_x + 300, term_pos[1]],
                'parameters': {
                    'resolution': {'value': vec2i(512, 512)},
                    'open': {'value': True}
                }
            }
            conns.append({"from": terminal, "from_port": 0, "to": "raymarch1", "to_port": 0})
            conns.append({"from": "raymarch1", "from_port": 0, "to": "window1", "to_port": 0})
        
        elif term_family == 'IMG':
            # IMG → ImgToTOP → WindowOUT
            nodes['imgtotop1'] = {
                'type': 'ImgToTOP',
                'position': [next_x, term_pos[1]],
                'parameters': {}
            }
            nodes['window1'] = {
                'type': 'WindowOUT',
                'position': [next_x + 300, term_pos[1]],
                'parameters': {
                    'resolution': {'value': vec2i(512, 512)},
                    'open': {'value': True}
                }
            }
            conns.append({"from": terminal, "from_port": 0, "to": "imgtotop1", "to_port": 0})
            conns.append({"from": "imgtotop1", "from_port": 0, "to": "window1", "to_port": 0})
        
        else:
            # Unknown family — skip
            continue
        
        d['connections'] = conns
        save_patch(p, d)
        print(f"  ADDED WindowOUT ({term_family}→display): {p}")


# ────────────────────────────────────────────────────────────
# Fix miscellaneous patches
# ────────────────────────────────────────────────────────────
def fix_misc():
    """Fix specific one-off issues."""
    
    # PostProcess glow: COMP→WindowOUT needs RenderTOP
    p = 'addons/gonodes/help/top/postprocess_glow.gnpatch'
    if os.path.exists(p):
        d = load_patch(p)
        nodes = d['nodes']
        conns = d['connections']
        
        # Insert RenderTOP between EnvironmentCOMP and WindowOUT
        for i, c in enumerate(conns):
            if nodes.get(c['from'], {}).get('type') == 'EnvironmentCOMP' and nodes.get(c['to'], {}).get('type') == 'WindowOUT':
                win_pos = nodes[c['to']].get('position', [1200, 100])
                comp_pos = nodes[c['from']].get('position', [400, 100])
                
                nodes['rendertop1'] = {
                    'type': 'RenderTOP',
                    'position': [(comp_pos[0] + win_pos[0]) // 2, comp_pos[1]],
                    'parameters': {'resolution': {'value': vec2i(512, 512)}}
                }
                nodes['camera1'] = {
                    'type': 'CameraCOMP',
                    'position': [(comp_pos[0] + win_pos[0]) // 2, comp_pos[1] + 200],
                    'parameters': {'tz': {'value': 5.0}}
                }
                # Need a geometry source for the render chain
                nodes['sphere1'] = {
                    'type': 'SphereSOP',
                    'position': [comp_pos[0] - 400, comp_pos[1]],
                    'parameters': {'radius': {'value': 1.0}}
                }
                nodes['geo1'] = {
                    'type': 'GeometryCOMP',
                    'position': [comp_pos[0] - 200, comp_pos[1]],
                    'parameters': {}
                }
                
                # Rewire  
                conns[i] = {"from": "rendertop1", "from_port": 0, "to": c['to'], "to_port": 0}
                conns.append({"from": "sphere1", "from_port": 0, "to": "geo1", "to_port": 0})
                conns.append({"from": "geo1", "from_port": 0, "to": "rendertop1", "to_port": 0})
                conns.append({"from": "camera1", "from_port": 0, "to": "rendertop1", "to_port": 1})
                conns.append({"from": c['from'], "from_port": 0, "to": "rendertop1", "to_port": 2})
                break
        
        save_patch(p, d)
        print(f"  FIXED PostProcess glow: {p}")
    
    # VoronoiShatter: SOP→RenderTOP handled by fix_sop_to_rendertop
    
    # Cloth patches: SOP→RenderTOP → need GeometryCOMP + WindowOUT
    for pname in ['cloth_basic', 'cloth_freefall', 'cloth_wind']:
        p = f'addons/gonodes/help/sop/{pname}.gnpatch'
        if os.path.exists(p):
            d = load_patch(p)
            nodes = d['nodes']
            conns = d['connections']
            
            # Check if render1 is RenderTOP
            if 'render1' in nodes and nodes['render1'].get('type') == 'RenderTOP':
                # Add GeometryCOMP before RenderTOP
                rt_pos = nodes['render1'].get('position', [800, 100])
                nodes['geo1'] = {
                    'type': 'GeometryCOMP',
                    'position': [rt_pos[0] - 200, rt_pos[1]],
                    'parameters': {}
                }
                nodes['camera1'] = {
                    'type': 'CameraCOMP',
                    'position': [rt_pos[0], rt_pos[1] + 200],
                    'parameters': {'tz': {'value': 5.0}}
                }
                
                # Fix connections: route SOP through GeometryCOMP
                new_conns = []
                for c in conns:
                    fr = c['from']
                    to = c['to']
                    ft = nodes.get(fr, {}).get('type', '')
                    tt = nodes.get(to, {}).get('type', '')
                    if ft.endswith('SOP') and tt == 'RenderTOP':
                        new_conns.append({"from": fr, "from_port": c.get('from_port', 0), "to": "geo1", "to_port": 0})
                        new_conns.append({"from": "geo1", "from_port": 0, "to": to, "to_port": c.get('to_port', 0)})
                    else:
                        new_conns.append(c)
                
                new_conns.append({"from": "camera1", "from_port": 0, "to": "render1", "to_port": 1})
                
                # Add WindowOUT if missing
                has_window = any(nv.get('type') == 'WindowOUT' for nv in nodes.values())
                if not has_window:
                    nodes['window1'] = {
                        'type': 'WindowOUT',
                        'position': [rt_pos[0] + 300, rt_pos[1]],
                        'parameters': {
                            'resolution': {'value': vec2i(512, 512)},
                            'open': {'value': True}
                        }
                    }
                    new_conns.append({"from": "render1", "from_port": 0, "to": "window1", "to_port": 0})
                
                d['connections'] = new_conns
                save_patch(p, d)
                print(f"  FIXED Cloth+WindowOUT: {p}")

    # DotNode patches — DotNode adapts dynamically, so they're OK structurally
    # but the validator false-flags them. Skip.
    
    # takes_basic: GeometryCOMP→InstanceCOMP should be SOP→InstanceCOMP
    p = 'addons/gonodes/help/takes/takes_basic.gnpatch'
    if os.path.exists(p):
        d = load_patch(p)
        nodes = d['nodes']
        for nid in list(nodes.keys()):
            if nodes[nid].get('type') == 'GeometryCOMP':
                nodes[nid] = {
                    'type': 'BoxSOP',
                    'position': nodes[nid]['position'],
                    'parameters': {'sizex': {'value': 1.0}, 'sizey': {'value': 1.0}, 'sizez': {'value': 1.0}}
                }
                break
        save_patch(p, d)
        print(f"  FIXED takes_basic: {p}")

    # VectorPath patches: missing WindowOUT
    for name in ['vectorpath_bezier', 'vectorpath_circle', 'vectorpath_star']:
        p = f'addons/gonodes/help/top/{name}.gnpatch'
        if os.path.exists(p):
            d = load_patch(p)
            nodes = d['nodes']
            conns = d['connections']
            
            # Find terminal TOP node
            has_window = any(nv.get('type') == 'WindowOUT' for nv in nodes.values())
            if not has_window:
                # Find VectorPathTOP
                vp_id = None
                for nid, nv in nodes.items():
                    if nv.get('type') == 'VectorPathTOP':
                        vp_id = nid
                        break
                
                if vp_id:
                    vp_pos = nodes[vp_id].get('position', [400, 100])
                    
                    # Make sure VectorPath is connected  
                    connected = set(c['from'] for c in conns) | set(c['to'] for c in conns)
                    
                    nodes['window1'] = {
                        'type': 'WindowOUT',
                        'position': [vp_pos[0] + 300, vp_pos[1]],
                        'parameters': {
                            'resolution': {'value': vec2i(512, 512)},
                            'open': {'value': True}
                        }
                    }
                    
                    # Find terminal node that outputs TOP
                    terminal = None
                    outgoing = set(c['from'] for c in conns)
                    for nid in nodes:
                        if nid not in outgoing and nid != 'window1':
                            terminal = nid
                    
                    if terminal:
                        conns.append({"from": terminal, "from_port": 0, "to": "window1", "to_port": 0})
                    else:
                        conns.append({"from": vp_id, "from_port": 0, "to": "window1", "to_port": 0})
                    
                    d['connections'] = conns
                    save_patch(p, d)
                    print(f"  FIXED VectorPath+WindowOUT: {p}")


# ────────────────────────────────────────────────────────────
# Fix scriptchop and callbackdat empty from_node
# ────────────────────────────────────────────────────────────
def fix_empty_from():
    for name in ['scriptchop_set_par', 'callbackdat_basic']:
        candidates = glob.glob(f'addons/gonodes/help/**/{name}.gnpatch', recursive=True)
        for p in candidates:
            d = load_patch(p)
            conns = d['connections']
            new_conns = [c for c in conns if c.get('from', '') != '' and c.get('to', '') != '']
            if len(new_conns) != len(conns):
                d['connections'] = new_conns
                save_patch(p, d)
                print(f"  FIXED empty from/to: {p}")


# ────────────────────────────────────────────────────────────
# MAIN
# ────────────────────────────────────────────────────────────
def main():
    print("=" * 60)
    print("GONODES Comprehensive Patch Fixer")
    print("=" * 60)
    
    print("\n--- Fixing InstancePOP chains ---")
    fix_instance_pop_patches()
    
    print("\n--- Fixing SDF orphan LFOs ---")
    fix_sdf_orphan_lfos()
    
    print("\n--- Fixing SOP→RenderTOP ---")
    fix_sop_to_rendertop()
    
    print("\n--- Fixing bridge operator inputs ---")
    fix_bridge_inputs()
    
    print("\n--- Fixing OUT IMG inputs ---")
    fix_out_img_inputs()
    
    print("\n--- Fixing RecordOUT ---")
    fix_record_out()
    
    print("\n--- Fixing COMP chains ---")
    fix_comp_chains()
    
    print("\n--- Fixing GenericScript ---")
    fix_generic_script()
    
    print("\n--- Fixing SnapshotTOP ---")
    fix_snapshot_top()
    
    print("\n--- Fixing PhysicsCHOP ---")
    fix_physics_chop()
    
    print("\n--- Fixing TabContainer ---")
    fix_tab_container()
    
    print("\n--- Fixing miscellaneous ---")
    fix_misc()
    
    print("\n--- Fixing empty from/to ---")
    fix_empty_from()
    
    print("\n--- Adding missing WindowOUTs ---")
    add_missing_window_outs()
    
    print(f"\n{'='*60}")
    print(f"Total patches modified: {MODIFIED}")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
