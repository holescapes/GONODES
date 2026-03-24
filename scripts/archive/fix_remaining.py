#!/usr/bin/env python3
"""Fix remaining orphans and missing sinks."""
import json, os

def fix_orphan_dat(path, orphan_id):
    """Update texttop1 expression to reference the orphan DAT."""
    if not os.path.exists(path):
        return
    with open(path, 'r', encoding='utf-8') as f:
        d = json.load(f)
    nodes = d['nodes']
    if orphan_id in nodes and 'texttop1' in nodes:
        expr = 'str(op("' + orphan_id + '"))'
        nodes['texttop1']['parameters']['text'] = {
            'value': 'DAT Output',
            'expression': expr,
            'mode': 'EXPRESSION'
        }
        with open(path, 'w', encoding='utf-8', newline='') as f:
            json.dump(d, f, indent=4)
        print(f'  FIXED: {path}')

def add_window_out_chop(path):
    with open(path, 'r', encoding='utf-8') as f:
        d = json.load(f)
    nodes = d['nodes']
    conns = d['connections']
    if any(nv.get('type') == 'WindowOUT' for nv in nodes.values()):
        print(f'  SKIP: {path} already has WindowOUT')
        return
    outgoing = set(c.get('from', '') for c in conns)
    for nid in nodes:
        if nid not in outgoing:
            tp = nodes[nid].get('position', [400, 100])
            nodes['choptotop1'] = {
                'type': 'CHOPtoTOP', 'position': [tp[0]+300, tp[1]], 'parameters': {}
            }
            nodes['window1'] = {
                'type': 'WindowOUT', 'position': [tp[0]+600, tp[1]],
                'parameters': {
                    'resolution': {'value': {'_type': 'Vector2i', 'x': 512, 'y': 512}},
                    'open': {'value': True}
                }
            }
            conns.append({'from': nid, 'from_port': 0, 'to': 'choptotop1', 'to_port': 0})
            conns.append({'from': 'choptotop1', 'from_port': 0, 'to': 'window1', 'to_port': 0})
            with open(path, 'w', encoding='utf-8', newline='') as f:
                json.dump(d, f, indent=4)
            print(f'  FIXED: {path}')
            return

def add_window_out_dat(path):
    with open(path, 'r', encoding='utf-8') as f:
        d = json.load(f)
    nodes = d['nodes']
    conns = d['connections']
    if any(nv.get('type') == 'WindowOUT' for nv in nodes.values()):
        print(f'  SKIP: {path} already has WindowOUT')
        return
    outgoing = set(c.get('from', '') for c in conns)
    for nid in nodes:
        if nid not in outgoing:
            tp = nodes[nid].get('position', [400, 100])
            nodes['texttop1'] = {
                'type': 'TextTOP', 'position': [tp[0]+300, tp[1]],
                'parameters': {'resolution': {'value': {'_type': 'Vector2i', 'x': 512, 'y': 512}}}
            }
            nodes['window1'] = {
                'type': 'WindowOUT', 'position': [tp[0]+600, tp[1]],
                'parameters': {
                    'resolution': {'value': {'_type': 'Vector2i', 'x': 512, 'y': 512}},
                    'open': {'value': True}
                }
            }
            conns.append({'from': 'texttop1', 'from_port': 0, 'to': 'window1', 'to_port': 0})
            with open(path, 'w', encoding='utf-8', newline='') as f:
                json.dump(d, f, indent=4)
            print(f'  FIXED: {path}')
            return

# Fix orphan DATs  
fix_orphan_dat('addons/gn_ext_blackmagic/help/dat/bm_devices.gnpatch', 'bm_dat1')
fix_orphan_dat('addons/gn_ext_serial/help/dat/serial_receive_basic.gnpatch', 'serial_rx1')
fix_orphan_dat('addons/gn_ext_serial/help/dat/serial_receive_raw.gnpatch', 'serial_rx1')
fix_orphan_dat('addons/gonodes/help/dat/dmx_receive.gnpatch', 'dmx1')
fix_orphan_dat('addons/gonodes/help/dat/mqtt_subscribe.gnpatch', 'mqtt1')

# Fix missing WindowOUT
add_window_out_chop('addons/gonodes/help/chop/laser_spiral.gnpatch')
add_window_out_dat('addons/gonodes/help/dat/renderpick_scene.gnpatch')

print('\nDone!')
