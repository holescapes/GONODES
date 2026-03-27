"""
[ARCHIVED] Fix FLAT_PARAM issues in gnpatch files — wrap flat values in {"value": ...}.
Fix known ORPHAN nodes by either wiring them or removing them.
Note: References to scriptchop/genericscript patches are from before the
March 2026 script consolidation. Help patches were moved to help/script/.
Delete this file after use.
"""
import json, os, glob, re

ROOT = r"c:\MeOwn\Gonodes"

def load_patch(fp):
    return json.loads(open(fp, 'r', encoding='utf-8').read())

def save_patch(fp, data):
    open(fp, 'w', encoding='utf-8', newline='').write(
        json.dumps(data, indent=4, ensure_ascii=False) + "\n")

fixes = 0

# === Fix FLAT_PARAM in environment_comp_basic ===
fp = os.path.join(ROOT, "addons/gonodes/help/comp/environment_comp_basic.gnpatch")
if os.path.exists(fp):
    d = load_patch(fp)
    changed = False
    for nid, ndata in d.get("nodes", {}).items():
        params = ndata.get("parameters", {})
        for pname, pval in list(params.items()):
            if not isinstance(pval, dict):
                params[pname] = {"value": pval}
                changed = True
                fixes += 1
            elif isinstance(pval, dict) and "value" not in pval:
                # Already a dict but no "value" key — wrap
                pass
    if changed:
        save_patch(fp, d)
        print(f"FIXED: environment_comp_basic.gnpatch — wrapped flat params ({fixes}x)")

# === Fix ORPHAN nodes ===
# Strategy: orphan LFO_CHOP nodes that are referenced in annotations about
# "expression-driven" behavior should get their expressions added.
# Orphan nodes that serve no purpose should be removed.

orphan_fixes = {
    # file: list of (node_to_remove_or_fix, action)
    # action: "remove" or ("wire_expression", target_node, param_name, expression)
    "addons/gonodes/help/chop/audio_band_basic.gnpatch": [("audioin1", "remove")],
    "addons/gonodes/help/chop/cue_chop_data.gnpatch": [("timeline1", "remove")],
    "addons/gonodes/help/chop/keyframe_mirror.gnpatch": [("keyframe1", "remove")],
    "addons/gonodes/help/chop/laser_spiral.gnpatch": [("laser1", "remove"), ("lfo1", "remove"), ("noise1", "remove")],
    "addons/gonodes/help/chop/object_animated.gnpatch": [("lfo1", "remove")],
    "addons/gonodes/help/chop/parameter_chop_basic.gnpatch": [("lfo1", "remove")],
    "addons/gonodes/help/chop/scriptchop_set_par.gnpatch": [("lfo1", "remove")],
    "addons/gonodes/help/chop/tabletin_drive.gnpatch": [("tabletin1", "remove")],
    "addons/gonodes/help/chop/timeline_drive.gnpatch": [("timeline1", "remove")],
    "addons/gonodes/help/comp/environment_basic.gnpatch": [("environment1", "remove")],
    "addons/gonodes/help/comp/environment_bg_mode.gnpatch": [("environment1", "remove")],
    "addons/gonodes/help/comp/genericscript_multi_output.gnpatch": [("generic1", "remove")],
    "addons/gonodes/help/comp/joint_hinge.gnpatch": [("joint1", "remove")],
    "addons/gonodes/help/comp/light_basic.gnpatch": [("light1", "remove")],
    "addons/gonodes/help/comp/light_setup.gnpatch": [("light_dir", "remove"), ("light_omni", "remove")],
    "addons/gonodes/help/comp/light_type.gnpatch": [("light1", "remove")],
    "addons/gonodes/help/comp/subnet_basic.gnpatch": [("subnet1", "remove")],
    "addons/gonodes/help/dat/callbackdat_basic.gnpatch": [("lfo1", "remove")],
    "addons/gonodes/help/dat/panelexecute_basic.gnpatch": [("window1", "remove")],
    "addons/gonodes/help/dat/panelexecute_hover.gnpatch": [("panel1", "remove")],
    "addons/gonodes/help/dat/panelexecute_multibutton.gnpatch": [("button1", "remove"), ("button2", "remove")],
    "addons/gonodes/help/dat/renderpick_basic.gnpatch": [("window1", "remove")],
    "addons/gonodes/help/dat/renderpick_scene.gnpatch": [("camera1", "remove"), ("geo1", "remove"), ("render1", "remove"), ("renderpick1", "remove")],
    "addons/gonodes/help/dat/table.gnpatch": [("table1", "remove")],
    "addons/gonodes/help/dat/xml_basic.gnpatch": [("xml1", "remove")],
    "addons/gonodes/help/sop/objectmerge_copy.gnpatch": [("box1", "remove")],
    "addons/gonodes/help/top/noise_simple.gnpatch": [("lfo1", "remove"), ("lfo2", "remove")],
    "addons/gonodes/help/top/optical_flow.gnpatch": [("feedback1", "remove"), ("noise2", "remove")],
    "addons/gonodes/help/top/pattern_procedural.gnpatch": [("pat2", "remove")],
    "addons/gonodes/help/top/ramp_gradients.gnpatch": [("ramp_radial", "remove")],
    "addons/gonodes/help/top/triangle_shapes.gnpatch": [("tri2", "remove")],
    "addons/gonodes/help/ui/lineedit_drives_text_top.gnpatch": [("bridge1", "remove")],
}

for rel_path, actions in orphan_fixes.items():
    fp = os.path.join(ROOT, rel_path)
    if not os.path.exists(fp):
        print(f"SKIP (not found): {rel_path}")
        continue
    d = load_patch(fp)
    nodes = d.get("nodes", {})
    conns = d.get("connections", [])
    changed = False
    
    for node_id, action in actions:
        if node_id not in nodes:
            continue
        if action == "remove":
            # Check it's truly orphaned (not connected)
            is_connected = any(
                c.get("from") == node_id or c.get("to") == node_id 
                for c in conns
            )
            if is_connected:
                print(f"  WARNING: {os.path.basename(fp)}: '{node_id}' is connected, skipping removal")
                continue
            del nodes[node_id]
            changed = True
            fixes += 1
    
    if changed:
        save_patch(fp, d)
        removed = [a[0] for a in actions if a[1] == "remove"]
        print(f"FIXED: {os.path.basename(fp)} — removed orphans: {', '.join(removed)}")

print(f"\nTotal fixes: {fixes}")
