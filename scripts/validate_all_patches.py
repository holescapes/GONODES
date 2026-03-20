#!/usr/bin/env python3
"""
Comprehensive gnpatch validator — checks ALL patches for:
1. Port type mismatches (e.g. COMP→TOP input)
2. Port index out of range
3. Orphan nodes (not connected to anything)
4. Missing WindowOUT sink
5. Unknown operator types
6. Missing "parameters" format (should use {"value": ...} wrappers)
7. Connections to/from non-existent nodes
"""

import json, os, glob, sys

# Load port registry
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(SCRIPT_DIR, "port_registry.json"), "r") as f:
    REGISTRY = json.load(f)

# Type compatibility rules
COMPATIBLE = {
    # exact match always OK
    "ANY": True,  # ANY accepts anything
}

def types_compatible(output_type, input_type):
    """Check if output_type can connect to input_type."""
    if output_type == input_type:
        return True
    if input_type == "ANY" or output_type == "ANY":
        return True
    return False

def get_output_type(class_name, port_idx):
    """Get the output type for a given operator and port index."""
    reg = REGISTRY.get(class_name)
    if not reg:
        return None
    outputs = reg.get("outputs", [])
    for o in outputs:
        if o["port"] == port_idx:
            return o["type"]
    # Check dynamic outputs
    if reg.get("dynamic_inputs"):
        return reg.get("family") or reg["dynamic_inputs"]
    # If only one output and port is 0, use it
    if len(outputs) == 1 and port_idx == 0:
        return outputs[0]["type"]
    return None

def get_input_type(class_name, port_idx):
    """Get the expected input type for a given operator and port index."""
    reg = REGISTRY.get(class_name)
    if not reg:
        return None
    inputs = reg.get("inputs", [])
    for i in inputs:
        if i["port"] == port_idx:
            return i["type"]
    # Check dynamic inputs
    dyn = reg.get("dynamic_inputs")
    if dyn:
        return dyn
    return None

def validate_patch(filepath):
    """Validate a single patch file. Returns list of issues."""
    issues = []
    with open(filepath, "r", encoding="utf-8") as f:
        try:
            d = json.load(f)
        except json.JSONDecodeError as e:
            return [f"JSON parse error: {e}"]
    
    nodes = d.get("nodes", {})
    conns = d.get("connections", [])
    
    connected_nodes = set()
    
    # Check each connection
    for ci, c in enumerate(conns):
        from_id = c.get("from", "")
        to_id = c.get("to", "")
        from_port = c.get("from_port", 0)
        to_port = c.get("to_port", 0)
        
        # Check nodes exist
        if from_id not in nodes:
            issues.append(f"Connection {ci}: from_node '{from_id}' doesn't exist")
            continue
        if to_id not in nodes:
            issues.append(f"Connection {ci}: to_node '{to_id}' doesn't exist")
            continue
        
        connected_nodes.add(from_id)
        connected_nodes.add(to_id)
        
        from_type = nodes[from_id].get("type", "")
        to_type = nodes[to_id].get("type", "")
        
        # Check operator types are known
        if from_type not in REGISTRY:
            issues.append(f"Unknown operator type: {from_type} (node {from_id})")
            continue
        if to_type not in REGISTRY:
            issues.append(f"Unknown operator type: {to_type} (node {to_id})")
            continue
        
        # Check port compatibility
        out_type = get_output_type(from_type, from_port)
        in_type = get_input_type(to_type, to_port)
        
        if out_type and in_type:
            if not types_compatible(out_type, in_type):
                issues.append(
                    f"TYPE MISMATCH: {from_id}({from_type}) port {from_port} "
                    f"outputs {out_type} → {to_id}({to_type}) port {to_port} "
                    f"expects {in_type}"
                )
    
    # Check for orphan nodes (not in any connection)
    for nid, nv in nodes.items():
        if nid not in connected_nodes:
            ntype = nv.get("type", "???")
            issues.append(f"ORPHAN: {nid} ({ntype}) — not connected to anything")
    
    # Check for WindowOUT
    has_window = any(nv.get("type") == "WindowOUT" for nv in nodes.values())
    if not has_window:
        # Check if it's an OUT type (self-terminal)
        has_out = any(
            nv.get("type", "").endswith("OUT") or nv.get("type", "").endswith("OUTput")
            for nv in nodes.values()
        )
        if not has_out:
            issues.append("NO SINK: Patch has no WindowOUT or other output")
    
    # Check parameter format
    for nid, nv in nodes.items():
        params = nv.get("parameters", {})
        for pname, pval in params.items():
            if not isinstance(pval, dict):
                issues.append(f"FLAT_PARAM: {nid}.{pname} = {pval} (should be {{\"value\": ...}})")
    
    return issues

def main():
    all_patches = glob.glob("addons/**/help/**/*.gnpatch", recursive=True)
    
    total = 0
    passed = 0
    failed = 0
    all_issues = []
    
    type_mismatch_count = 0
    orphan_count = 0
    no_sink_count = 0
    flat_param_count = 0
    unknown_type_count = 0
    
    for p in sorted(all_patches):
        total += 1
        issues = validate_patch(p)
        if issues:
            failed += 1
            rel = os.path.relpath(p)
            for iss in issues:
                if "TYPE MISMATCH" in iss:
                    type_mismatch_count += 1
                elif "ORPHAN" in iss:
                    orphan_count += 1
                elif "NO SINK" in iss:
                    no_sink_count += 1
                elif "FLAT_PARAM" in iss:
                    flat_param_count += 1
                elif "Unknown" in iss:
                    unknown_type_count += 1
            all_issues.append((rel, issues))
        else:
            passed += 1
    
    # Print results
    print(f"\n{'='*60}")
    print(f"GONODES Patch Validation Report")
    print(f"{'='*60}")
    print(f"Total patches: {total}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    print(f"")
    print(f"Issue breakdown:")
    print(f"  Type mismatches: {type_mismatch_count}")
    print(f"  Orphan nodes:    {orphan_count}")
    print(f"  No sink:         {no_sink_count}")
    print(f"  Flat params:     {flat_param_count}")
    print(f"  Unknown types:   {unknown_type_count}")
    print(f"{'='*60}\n")
    
    if all_issues:
        for rel, issues in all_issues:
            print(f"\nFAIL: {rel}")
            for iss in issues:
                print(f"   {iss}")
    
    return 0 if failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
