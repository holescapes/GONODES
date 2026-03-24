#!/usr/bin/env python3
"""Fix DAT→WindowOUT by inserting TextTOP bridge."""
import json, os, glob

patches = glob.glob('addons/**/help/**/*.gnpatch', recursive=True)
with open('scripts/port_registry.json') as rf:
    reg = json.load(rf)

fixed = 0
for p in sorted(patches):
    with open(p, 'r', encoding='utf-8') as f:
        d = json.load(f)
    nodes = d.get('nodes', {})
    conns = d.get('connections', [])
    
    modified = False
    new_conns = []
    for c in conns:
        fr = c.get('from', '')
        to = c.get('to', '')
        ft = nodes.get(fr, {}).get('type', '')
        tt = nodes.get(to, {}).get('type', '')
        
        if tt == 'WindowOUT' and c.get('to_port', 0) == 0:
            src_reg = reg.get(ft, {})
            out_type = None
            for o in src_reg.get('outputs', []):
                if o['port'] == c.get('from_port', 0):
                    out_type = o['type']
                    break
            
            if out_type == 'DAT':
                win_pos = nodes[to].get('position', [1200, 100])
                expr = 'str(op("' + fr + '"))'
                nodes['texttop1'] = {
                    'type': 'TextTOP',
                    'position': [win_pos[0] - 200, win_pos[1]],
                    'parameters': {
                        'text': {
                            'value': 'DAT Output',
                            'expression': expr,
                            'mode': 'EXPRESSION'
                        },
                        'resolution': {
                            'value': {'_type': 'Vector2i', 'x': 512, 'y': 512}
                        }
                    }
                }
                new_conns.append({
                    'from': 'texttop1', 'from_port': 0,
                    'to': to, 'to_port': 0
                })
                modified = True
                continue
        
        new_conns.append(c)
    
    if modified:
        d['connections'] = new_conns
        with open(p, 'w', encoding='utf-8', newline='') as f:
            json.dump(d, f, indent=4)
        fixed += 1
        print(f'  FIXED: {os.path.relpath(p)}')

# Fix laser_spiral (missing WindowOUT, CHOP terminal)
p = 'addons/gonodes/help/chop/laser_spiral.gnpatch'
if os.path.exists(p):
    with open(p, 'r', encoding='utf-8') as f:
        d = json.load(f)
    nodes = d['nodes']
    conns = d['connections']
    outgoing = set(c.get('from', '') for c in conns)
    terminal = None
    for nid in nodes:
        if nid not in outgoing:
            terminal = nid
            break
    if terminal:
        tp = nodes[terminal].get('position', [400, 100])
        nodes['choptotop1'] = {
            'type': 'CHOPtoTOP',
            'position': [tp[0] + 300, tp[1]],
            'parameters': {}
        }
        nodes['window1'] = {
            'type': 'WindowOUT',
            'position': [tp[0] + 600, tp[1]],
            'parameters': {
                'resolution': {'value': {'_type': 'Vector2i', 'x': 512, 'y': 512}},
                'open': {'value': True}
            }
        }
        conns.append({'from': terminal, 'from_port': 0, 'to': 'choptotop1', 'to_port': 0})
        conns.append({'from': 'choptotop1', 'from_port': 0, 'to': 'window1', 'to_port': 0})
        with open(p, 'w', encoding='utf-8', newline='') as f:
            json.dump(d, f, indent=4)
        fixed += 1
        print(f'  FIXED: laser_spiral (added WindowOUT)')

# Fix renderpick_scene  
p = 'addons/gonodes/help/dat/renderpick_scene.gnpatch'
if os.path.exists(p):
    with open(p, 'r', encoding='utf-8') as f:
        d = json.load(f)
    nodes = d['nodes']
    conns = d['connections']
    outgoing = set(c.get('from', '') for c in conns)
    terminal = None
    for nid in nodes:
        if nid not in outgoing:
            terminal = nid
            break
    if terminal:
        tp = nodes[terminal].get('position', [400, 100])
        nodes['texttop1'] = {
            'type': 'TextTOP',
            'position': [tp[0] + 300, tp[1]],
            'parameters': {
                'resolution': {'value': {'_type': 'Vector2i', 'x': 512, 'y': 512}}
            }
        }
        nodes['window1'] = {
            'type': 'WindowOUT',
            'position': [tp[0] + 600, tp[1]],
            'parameters': {
                'resolution': {'value': {'_type': 'Vector2i', 'x': 512, 'y': 512}},
                'open': {'value': True}
            }
        }
        conns.append({'from': 'texttop1', 'from_port': 0, 'to': 'window1', 'to_port': 0})
        with open(p, 'w', encoding='utf-8', newline='') as f:
            json.dump(d, f, indent=4)
        fixed += 1
        print(f'  FIXED: renderpick_scene (added WindowOUT)')

print(f'\nFixed {fixed} patches total')
