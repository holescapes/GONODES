#!/usr/bin/env python3
"""
Add time-based expressions to gnpatch parameters for animation.
Only modifies patches that don't already have any expressions.
Picks the most visually meaningful parameter per focus node.
"""

import json, os, glob, random

# ── Expression templates by semantic meaning ──
EXPRESSIONS = {
    # Oscillating values (0-1 range)
    'norm_sin': 'sin(time * 2.0) * 0.5 + 0.5',
    'norm_cos': 'cos(time * 1.5) * 0.5 + 0.5', 
    'abs_sin': 'abs(sin(time * 2.0))',
    'bounce': 'abs(sin(time * 3.0))',
    'pulse': '0.5 + 0.5 * sin(time * 4.0)',
    # Small oscillation
    'wobble': 'sin(time * 2.0) * 0.2',
    'gentle': 'sin(time * 1.0) * 0.1',
    # Sweep
    'sweep': 'time % 4.0 / 4.0',
    'ramp_loop': '(time % 2.0) / 2.0',
    # Rotation  
    'rotate': 'time * 45.0',
    'slow_rotate': 'time * 15.0',
    # Scale pulse
    'scale_pulse': '0.8 + 0.2 * sin(time * 3.0)',
    'breathe': '0.7 + 0.3 * sin(time * 1.5)',
    # Position drift
    'drift_x': 'sin(time * 0.8) * 2.0',
    'drift_y': 'cos(time * 0.6) * 1.5',
}

# ── Parameter-name to expression mapping ──
PARAM_EXPR_MAP = {
    # Blur/filter params
    'blur': 'norm_sin',
    'blur_amount': 'norm_sin',
    'radius': 'breathe', 
    'size': 'breathe',
    'strength': 'abs_sin',
    'amount': 'abs_sin',
    'intensity': 'pulse',
    'gain': 'pulse',
    
    # Color/level params  
    'brightness': 'wobble',
    'contrast': 'norm_sin',
    'saturation': 'norm_sin',
    'hue_shift': 'sweep',
    'opacity': 'abs_sin',
    'alpha': 'abs_sin',
    'threshold': 'norm_sin',
    'gamma': 'scale_pulse',
    
    # Transform params
    'tx': 'drift_x',
    'ty': 'drift_y',
    'tz': 'gentle',
    'rx': 'slow_rotate',
    'ry': 'rotate',
    'rz': 'slow_rotate',
    'sx': 'scale_pulse',
    'sy': 'scale_pulse',
    'sz': 'scale_pulse',
    'scale': 'breathe',
    'rotate': 'rotate',
    'rotation': 'rotate',
    'angle': 'rotate',
    
    # Noise/oscillation params
    'frequency': 'breathe',
    'amplitude': 'abs_sin',
    'phase': 'sweep',
    'offset': 'wobble',
    'speed': 'norm_sin',
    'lac': 'norm_sin',  # lacunarity
    'roughness': 'norm_sin',
    'octaves': None,  # Don't animate integer params
    'seed': None,
    
    # Particle params
    'rate': 'pulse',
    'emit_rate': 'pulse',
    'max_particles': None,
    'life': 'breathe',
    'force_x': 'wobble',
    'force_y': 'gentle',
    'point_size': 'breathe',
    
    # Time/animation params
    'blend': 'norm_sin',
    'mix': 'norm_sin',
    'weight': 'abs_sin',
    'bias': 'norm_sin',
    'power': 'scale_pulse',
}

# ── Parameters that should NOT be animated ──
SKIP_PARAMS = {
    'resolution', 'res_x', 'res_y', 'res_z', 'format', 'mode', 'type',
    'method', 'device', 'device_index', 'backend', 'filename', 'file',
    'path', 'url', 'name', 'text', 'code', 'script', 'open', 'active',
    'port', 'baud', 'ip', 'address', 'channel', 'universe',
    'name0', 'name1', 'name2', 'max_particles', 'use_pscale', 'billboard',
    'label', 'title', 'font', 'font_size', 'align', 'color',
}


def should_animate(param_name, param_val):
    """Check if a parameter is suitable for expression animation."""
    if param_name in SKIP_PARAMS:
        return False
    if not isinstance(param_val, dict):
        return False
    if param_val.get('mode') == 'EXPRESSION':
        return False
    v = param_val.get('value')
    if isinstance(v, (int, float)):
        return True
    return False


def pick_expression(param_name, current_value):
    """Pick the best expression for a parameter based on its name and value."""
    # Check direct mapping
    name_lower = param_name.lower()
    for key, expr_name in PARAM_EXPR_MAP.items():
        if key in name_lower:
            if expr_name is None:
                return None
            return EXPRESSIONS[expr_name]
    
    # Default based on value range
    if isinstance(current_value, (int, float)):
        if 0 <= current_value <= 1:
            return EXPRESSIONS['norm_sin']
        elif -1 <= current_value < 0:
            return EXPRESSIONS['wobble']
        elif current_value > 1:
            expr = f'({current_value} * (0.5 + 0.5 * sin(time * 2.0)))'
            return expr
        else:
            return EXPRESSIONS['wobble']
    
    return EXPRESSIONS['norm_sin']


def add_expressions_to_patch(filepath):
    """Add expressions to a patch that doesn't have any."""
    with open(filepath, 'r', encoding='utf-8') as f:
        d = json.load(f)
    
    nodes = d.get('nodes', {})
    conns = d.get('connections', [])
    
    # Check if patch already has expressions
    for nid, nv in nodes.items():
        for pname, pval in nv.get('parameters', {}).items():
            if isinstance(pval, dict) and pval.get('mode') == 'EXPRESSION':
                return False  # Already has expressions
    
    # Find the focus node (the node the patch teaches about)
    # Heuristic: the node that appears first in path name, or has most parameters
    focus_node = None
    focus_id = None
    
    # Exclude utility nodes
    utility_types = {'WindowOUT', 'NullTOP', 'NullCHOP', 'NullSOP', 'NullDAT', 
                     'NullPOP', 'RenderTOP', 'CameraCOMP', 'GeometryCOMP',
                     'CHOPtoTOP', 'TextTOP', 'DATtoTOP'}
    
    for nid, nv in nodes.items():
        ntype = nv.get('type', '')
        if ntype in utility_types:
            continue
        if focus_node is None or len(nv.get('parameters', {})) > len(focus_node.get('parameters', {})):
            focus_node = nv
            focus_id = nid
    
    if not focus_node or not focus_id:
        return False
    
    # Find animatable parameters on the focus node
    params = focus_node.get('parameters', {})
    animated_count = 0
    
    for pname in list(params.keys()):
        pval = params[pname]
        if not should_animate(pname, pval):
            continue
        
        expr = pick_expression(pname, pval.get('value', 0))
        if expr is None:
            continue
        
        # Add expression
        pval['expression'] = expr
        pval['mode'] = 'EXPRESSION'
        animated_count += 1
        
        # Only animate 1-2 params per patch for clarity
        if animated_count >= 2:
            break
    
    if animated_count == 0:
        return False
    
    # Save
    with open(filepath, 'w', encoding='utf-8', newline='') as f:
        json.dump(d, f, indent=4)
    return True


def main():
    patches = glob.glob('addons/**/help/**/*.gnpatch', recursive=True)
    added = 0
    skipped = 0
    
    for p in sorted(patches):
        if add_expressions_to_patch(p):
            added += 1
        else:
            skipped += 1
    
    print(f"Added expressions to {added} patches")
    print(f"Skipped {skipped} patches (already have expressions or no suitable params)")


if __name__ == "__main__":
    main()
