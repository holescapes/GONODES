#!/usr/bin/env python3
"""
ci_discover.py — Scan addons/ for GDExtensions with native/build.cfg.

Outputs GitHub Actions matrix JSON for dynamic job generation.
Called from the 'discover' job in build-extensions.yml.

Output format (to GITHUB_OUTPUT):
  matrix=["gn_ext_hap","gn_ext_spout","gn_ext_midi",...]
  vendor_setup={"gn_ext_ml":"setup_ml.py --sdk-only --no-enable",...}
  vendor_clone={"gn_ext_spout":"https://...git Spout2",...}

Vendor setup keys are read from build.cfg [library] section:
  vendor_setup = setup_ml.py --sdk-only --no-enable
  vendor_clone = https://github.com/.../Spout2.git Spout2
"""

import configparser
import json
import os
import sys

addons_dir = os.path.join(os.path.dirname(__file__), "..", "addons")
addons_dir = os.path.abspath(addons_dir)


def _parse_vendor_keys(cfg_path):
    """Read vendor_setup and vendor_clone from a build.cfg file."""
    cp = configparser.ConfigParser()
    cp.read(cfg_path, encoding="utf-8")
    result = {}
    if cp.has_option("library", "vendor_setup"):
        result["vendor_setup"] = cp.get("library", "vendor_setup").strip()
    if cp.has_option("library", "vendor_clone"):
        result["vendor_clone"] = cp.get("library", "vendor_clone").strip()
    return result


extensions = []
vendor_setup = {}  # ext_name -> "script.py --flags"
vendor_clone = {}  # ext_name -> "https://...git dir_name"

for entry in sorted(os.listdir(addons_dir)):
    if not entry.startswith("gn_ext_") or entry == "gn_ext_native":
        continue
    native_dir = os.path.join(addons_dir, entry, "native")
    # Top-level build.cfg
    cfg_path = os.path.join(native_dir, "build.cfg")
    if os.path.isfile(cfg_path):
        extensions.append(entry)
        vk = _parse_vendor_keys(cfg_path)
        if "vendor_setup" in vk:
            vendor_setup[entry] = vk["vendor_setup"]
        if "vendor_clone" in vk:
            vendor_clone[entry] = vk["vendor_clone"]
        continue
    # Sub-directory build configs (e.g. native/azure_kinect/build.cfg)
    if os.path.isdir(native_dir):
        for sub in sorted(os.listdir(native_dir)):
            sub_cfg = os.path.join(native_dir, sub, "build.cfg")
            if os.path.isfile(sub_cfg):
                ext_key = f"{entry}/{sub}"
                extensions.append(ext_key)
                vk = _parse_vendor_keys(sub_cfg)
                if "vendor_setup" in vk:
                    vendor_setup[ext_key] = vk["vendor_setup"]
                if "vendor_clone" in vk:
                    vendor_clone[ext_key] = vk["vendor_clone"]


print(f"matrix={json.dumps(extensions)}")
if vendor_setup:
    print(f"vendor_setup={json.dumps(vendor_setup)}")
if vendor_clone:
    print(f"vendor_clone={json.dumps(vendor_clone)}")

if extensions:
    print(f"  Discovered {len(extensions)} buildable extensions:", file=sys.stderr)
    for ext in extensions:
        extra = []
        if ext in vendor_setup:
            extra.append(f"setup: {vendor_setup[ext]}")
        if ext in vendor_clone:
            extra.append(f"clone: {vendor_clone[ext]}")
        suffix = f"  ({', '.join(extra)})" if extra else ""
        print(f"    - {ext}{suffix}", file=sys.stderr)
else:
    print("  No buildable extensions found.", file=sys.stderr)
