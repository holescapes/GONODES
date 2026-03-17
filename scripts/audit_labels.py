"""Audit which multi-port operators still lack port labels."""
import os, re

root = r"c:\MeOwn\Gonodes\addons\gonodes\operators"
labeled = 0
unlabeled = []

for dirpath, dirs, files in os.walk(root):
    for f in files:
        if not f.endswith(".gd"):
            continue
        path = os.path.join(dirpath, f)
        text = open(path, "r", encoding="utf-8").read()
        has_label = bool(re.search(
            r'add_(input|output)\([^)]+,[^)]+,[^)]+,[^)]+,\s*"[A-Z]', text))
        inputs = re.findall(r"add_input\(", text)
        outputs = re.findall(r"add_output\(", text)
        if has_label:
            labeled += 1
        elif len(inputs) > 1 or len(outputs) > 1:
            rel = os.path.relpath(path, r"c:\MeOwn\Gonodes")
            unlabeled.append(f"{rel} ({len(inputs)}in/{len(outputs)}out)")

print(f"Files with labels: {labeled}")
print(f"Multi-port files WITHOUT labels: {len(unlabeled)}")
for x in sorted(unlabeled):
    print(f"  {x}")
