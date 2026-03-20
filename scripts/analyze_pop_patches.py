#!/usr/bin/env python3
"""Analyze all POP patches for connection issues."""
import json, os, glob

patches = glob.glob('addons/**/help/pop/*.gnpatch', recursive=True)
print(f'Found {len(patches)} POP patches\n')

for p in sorted(patches):
    with open(p, 'r', encoding='utf-8') as f:
        d = json.load(f)
    nodes = d.get('nodes', {})
    conns = d.get('connections', [])
    
    issues = []
    # Find all node types
    type_map = {}
    for nid, nv in nodes.items():
        type_map[nid] = nv.get('type', '???')
    
    # Check connections
    for c in conns:
        fr = c.get('from', '')
        to = c.get('to', '')
        ft = type_map.get(fr, '???')
        tt = type_map.get(to, '???')
        fp = c.get('from_port', 0)
        tp = c.get('to_port', 0)
        
        # Self loops
        if fr == to:
            issues.append(f"SELF-LOOP: {fr}({ft})")
        
        # POP → RenderTOP (missing RenderPOP)
        if ft.endswith('POP') and ft != 'RenderPOP' and tt == 'RenderTOP':
            issues.append(f"POP->RenderTOP: {fr}({ft})->{to}({tt})")
        
        # SourcePOP → RenderTOP 
        if ft == 'SourcePOP' and tt == 'RenderTOP':
            issues.append(f"SourcePOP->RenderTOP: {fr}->{to}")
    
    # Check if RenderPOP exists and is wired correctly
    has_renderpop = False
    renderpop_id = None
    for nid, t in type_map.items():
        if t == 'RenderPOP':
            has_renderpop = True
            renderpop_id = nid
    
    if has_renderpop:
        # Check what renderpop connects to
        for c in conns:
            if c.get('from') == renderpop_id:
                target = c.get('to', '')
                tt = type_map.get(target, '???')
                if tt == 'RenderTOP':
                    pass  # OK
                elif tt == 'WindowOUT':
                    issues.append(f"RenderPOP->WindowOUT: {renderpop_id}->{target} (MISSING RenderTOP)")
    else:
        # No RenderPOP - might be a problem for POP patches
        has_render_top = any(t == 'RenderTOP' for t in type_map.values())
        if has_render_top:
            # POP might be going directly to RenderTOP
            pass
    
    if issues:
        print(f"  {os.path.relpath(p)}:")
        for i in issues:
            print(f"    {i}")
    else:
        # Check if chain is: last_POP -> RenderPOP -> RenderTOP -> WindowOUT
        chain = []
        for c in conns:
            fr = c.get('from', '')
            to = c.get('to', '')
            ft = type_map.get(fr, '???')
            tt = type_map.get(to, '???')
            chain.append(f"{fr}({ft})->{to}({tt})")
        # Just note OK
        print(f"  OK: {os.path.relpath(p)}")
