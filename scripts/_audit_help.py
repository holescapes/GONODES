#!/usr/bin/env python3
"""Audit all help .gnpatch files: quality, coverage, missing operators."""

import json
import os
import glob
import sys

def main():
    os.chdir(os.path.join(os.path.dirname(__file__), ".."))

    # Load registry
    with open("scripts/operator_registry.json", "r", encoding="utf-8") as f:
        registry = json.load(f)

    # Build (family, node_type) -> registry entry map
    by_family_nt = {}
    fam_suffixes = ["chop", "sop", "top", "dat", "img", "mat", "comp",
                    "ui", "pop", "vol", "out", "sdf", "script"]
    for r in registry:
        key = (r["family"], r["node_type"])
        by_family_nt[key] = r

    # Build prefix->key lookup: for each operator, the basename might be:
    # 1) node_type (e.g., "blur")
    # 2) lowered class_name (e.g., "blurimg")
    # 3) lowered class_name with family suffix stripped (e.g., "blur")
    # 4) node_type with underscores removed (e.g., "audiofilein")
    prefix_to_key = {}  # (family, prefix) -> (family, node_type)
    for r in registry:
        fam = r["family"]
        nt = r["node_type"]
        cn_lower = r["class_name"].lower()
        cn_stripped = cn_lower
        for sfx in fam_suffixes:
            if cn_lower.endswith(sfx):
                cn_stripped = cn_lower[:-len(sfx)]
                break
        nt_no_us = nt.replace("_", "")
        for prefix in set([nt, cn_lower, cn_stripped, nt_no_us]):
            if prefix:
                prefix_to_key.setdefault((fam, prefix), (fam, nt))

    # Find all help files
    help_files = glob.glob("addons/gonodes/help/**/*.gnpatch", recursive=True)
    help_files += glob.glob("addons/gn_ext_*/help/**/*.gnpatch", recursive=True)

    covered_keys = set()  # (family, node_type)
    issues = []
    empty_patches = []
    trivial_patches = []
    quality_issues = []  # (file, issue_description)

    # Map directory names to families
    dir_to_family = {
        "chop": "chop", "sop": "sop", "top": "top", "dat": "dat",
        "img": "img", "mat": "mat", "comp": "comp", "ui": "ui",
        "pop": "pop", "vol": "vol", "output": "output", "sdf": "sdf",
        "script": "script", "bridge": "output", "takes": "comp",
    }

    # Map extension directory to family (for SDF and others without subfolder)
    ext_to_family = {
        "gn_ext_sdf": "sdf",
    }

    for fp in sorted(help_files):
        try:
            with open(fp, "r", encoding="utf-8") as f:
                data = json.load(f)
        except json.JSONDecodeError as e:
            issues.append(f"INVALID JSON: {fp}: {e}")
            continue

        nodes = data.get("nodes", {})
        conns = data.get("connections", [])

        if len(nodes) == 0:
            empty_patches.append(fp)
            continue

        if len(nodes) == 1 and len(conns) == 0:
            trivial_patches.append(fp)

        # Check for non-default parameters (sign of meaningful content)
        has_params = False
        for nid, nd in nodes.items():
            params = nd.get("parameters", {})
            if params:
                has_params = True
                break

        if not has_params and len(nodes) > 1:
            quality_issues.append((fp, "no non-default parameters set on any node"))

        # Determine family from path
        parts = fp.replace("\\", "/").split("/")
        family_dir = None
        for p in parts:
            if p in dir_to_family:
                family_dir = dir_to_family[p]
                break
        if not family_dir:
            for p in parts:
                if p in ext_to_family:
                    family_dir = ext_to_family[p]
                    break

        if not family_dir:
            continue

        # Try to match basename to an operator using prefix lookup
        basename = os.path.splitext(os.path.basename(fp))[0]
        # Get all prefixes for this family, sorted longest first
        family_prefixes = sorted(
            [p for (f, p) in prefix_to_key if f == family_dir],
            key=len, reverse=True
        )
        for prefix in family_prefixes:
            if basename.startswith(prefix + "_") or basename == prefix:
                key = prefix_to_key[(family_dir, prefix)]
                covered_keys.add(key)
                break

    print(f"Total help files: {len(help_files)}")
    print(f"Invalid JSON: {len([i for i in issues if 'INVALID' in i])}")
    print(f"Empty patches (0 nodes): {len(empty_patches)}")
    print(f"Trivial patches (1 node, 0 connections): {len(trivial_patches)}")
    print(f"No non-default params: {len(quality_issues)}")

    # Find operators WITHOUT help patches
    all_keys = set(by_family_nt.keys())
    missing_keys = all_keys - covered_keys

    print(f"\nOperators with help: {len(covered_keys)}/{len(all_keys)}")
    print(f"Operators WITHOUT help: {len(missing_keys)}")

    if missing_keys:
        by_fam = {}
        for fam, nt in sorted(missing_keys):
            r = by_family_nt[(fam, nt)]
            by_fam.setdefault(fam, []).append((nt, r["class_name"]))
        for fam in sorted(by_fam.keys()):
            items = by_fam[fam]
            print(f"  {fam} ({len(items)}):")
            for nt, cls in items:
                print(f"    {nt} ({cls})")

    if empty_patches:
        print(f"\nEmpty patches ({len(empty_patches)}):")
        for ep in empty_patches:
            print(f"  {ep}")

    if trivial_patches:
        print(f"\nTrivial patches — 1 node, 0 connections ({len(trivial_patches)}):")
        for tp in trivial_patches:
            print(f"  {tp}")

    if quality_issues:
        print(f"\nNo non-default params ({len(quality_issues)}):")
        for fp, desc in quality_issues[:30]:
            print(f"  {fp}: {desc}")
        if len(quality_issues) > 30:
            print(f"  ... and {len(quality_issues) - 30} more")

    if issues:
        print(f"\nJSON issues ({len(issues)}):")
        for i in issues:
            print(f"  {i}")


if __name__ == "__main__":
    main()
