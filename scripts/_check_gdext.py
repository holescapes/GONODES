#!/usr/bin/env python3
"""Check which .gdextension files have their DLLs and write extension_list.cfg."""
import os
import configparser
import glob

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
entries = []

for f in sorted(glob.glob(os.path.join(root, "addons", "**", "*.gdextension"), recursive=True)):
    if "godot-cpp" in f:
        continue
    rel = f.replace(root + os.sep, "").replace(os.sep, "/")
    cp = configparser.ConfigParser()
    cp.read(f, encoding="utf-8")

    lib = None
    for key in ["windows.release.x86_64", "windows.debug.x86_64"]:
        if cp.has_option("libraries", key):
            lib = cp.get("libraries", key).strip('"')
            break

    if lib:
        abs_lib = lib.replace("res://", root + os.sep).replace("/", os.sep)
        exists = os.path.isfile(abs_lib)
        size = os.path.getsize(abs_lib) if exists else 0
        if exists and size < 10240:
            mark = "STUB"
            exists = False  # treat tiny placeholders as missing
        elif exists:
            mark = "OK"
        else:
            mark = "MISSING"
        print(f"  [{mark:7s}] {rel}")
        print(f"           -> {lib}  ({size} bytes)" if size else f"           -> {lib}")
        if exists:
            entries.append("res://" + rel)
    else:
        print(f"  [NO KEY ] {rel}")

cfg_path = os.path.join(root, ".godot", "extension_list.cfg")
with open(cfg_path, "w", encoding="utf-8", newline="\n") as fh:
    for e in entries:
        fh.write(e + "\n")
print(f"\nWrote {len(entries)} entries to .godot/extension_list.cfg")
