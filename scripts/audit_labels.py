"""Audit which multi-port operators still lack port labels."""
import os, re

_script_dir = os.path.dirname(os.path.abspath(__file__))
_root = os.path.dirname(_script_dir)
root = os.path.join(_root, "addons", "gonodes", "operators")
labeled = 0
unlabeled = []

for dirpath, dirs, files in os.walk(root):
    for f in files:
        if not f.endswith(".gd"):
            continue
        path = os.path.join(dirpath, f)
        text = open(path, "r", encoding="utf-8").read()
        # add_input has 5 args (name, family, multi, desc, label)
        # add_output has 4 args (name, family, desc, label)
        # Labels can be plain strings or use % formatting: "Label %d" % var
        _str = r'"[^"]*"(?:\s*%\s*\w+)?'  # matches "text" or "text %d" % var
        has_input_label = bool(re.search(
            rf'add_input\("[^"]+",\s*[^,]+,\s*(?:true|false),\s*{_str},\s*{_str}', text))
        has_output_label = bool(re.search(
            rf'add_output\("[^"]+",\s*[^,]+,\s*{_str},\s*{_str}', text))
        has_label = has_input_label or has_output_label
        inputs = re.findall(r"add_input\(", text)
        outputs = re.findall(r"add_output\(", text)
        if has_label:
            labeled += 1
        elif len(inputs) > 1 or len(outputs) > 1:
            rel = os.path.relpath(path, _root)
            unlabeled.append(f"{rel} ({len(inputs)}in/{len(outputs)}out)")

print(f"Files with labels: {labeled}")
print(f"Multi-port files WITHOUT labels: {len(unlabeled)}")
for x in sorted(unlabeled):
    print(f"  {x}")
