#!/usr/bin/env python3
"""Fix SDF operators: replace create_vector3() with 3 separate create_float() params.
Also fix _cook() to reconstruct Vector3 from the 3 float components.
Also fix raymarch_sdf.gd uniform collection and tree uniform setting."""
import re, pathlib

SDF = pathlib.Path(r"c:\MeOwn\Gonodes\addons\gn_ext_sdf\operators\top")

# ---------- Map of create_vector3 replacements per file ----------------------
# Each entry: (filename, vector3_param_name, label, desc, defaults (x,y,z), min, max, step)
# We'll auto-detect these from the file contents.

def fix_file(path: pathlib.Path):
    text = path.read_text(encoding="utf-8")
    if "create_vector3" not in text:
        return False

    original = text

    # Find all create_vector3 calls with their params
    # Pattern: add_parameter(GNParameter.create_vector3("name", Vector3(x, y, z),\n\t\t"Label", "Desc"))
    # or Vector3.ZERO
    pattern = re.compile(
        r'add_parameter\(GNParameter\.create_vector3\(\s*"(\w+)"\s*,\s*(Vector3(?:\.\w+|\([^)]*\)))\s*,'
        r'\s*\n\s*"([^"]+)"\s*,\s*"([^"]+)"\)\)',
        re.MULTILINE
    )

    def parse_v3(v3str):
        if v3str == "Vector3.ZERO":
            return (0.0, 0.0, 0.0)
        m = re.match(r'Vector3\(([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)\)', v3str)
        if m:
            return (float(m.group(1)), float(m.group(2)), float(m.group(3)))
        return (0.0, 0.0, 0.0)

    replacements = []
    for m in pattern.finditer(text):
        name = m.group(1)
        v3 = parse_v3(m.group(2))
        label = m.group(3)
        desc = m.group(4)
        replacements.append((m.group(0), name, v3, label, desc))

    for old_text, name, defaults, label, desc in replacements:
        # Determine range based on the param name
        if name == "normal":
            mn, mx, step = -1.0, 1.0, 0.01
        elif name == "limit":
            mn, mx, step = 0.0, 100.0, 1.0
        elif name == "light_dir":
            mn, mx, step = -1.0, 1.0, 0.01
        elif name == "spacing":
            mn, mx, step = 0.0, 100.0, 0.01
        elif name == "amount":  # elongate
            mn, mx, step = 0.0, 50.0, 0.01
        elif name == "size":
            mn, mx, step = 0.01, 100.0, 0.01
        else:  # position
            mn, mx, step = -100.0, 100.0, 0.01

        new_lines = []
        for axis, comp in zip(["x", "y", "z"], defaults):
            pname = f"{name}_{axis}"
            plabel = f"{label} {axis.upper()}"
            new_lines.append(
                f'\tadd_parameter(GNParameter.create_float("{pname}", {comp}, {mn}, {mx}, {step},\n'
                f'\t\t"{plabel}", "{desc}"))'
            )
        new_text = "\n".join(new_lines)
        text = text.replace(old_text, new_text)

    # Fix _cook() — replace get_param_value("name") with Vector3 reconstruction
    # Pattern: "name": get_param_value("name"),
    for _, name, _, _, _ in replacements:
        # Match: "name": get_param_value("name"),
        old_cook = f'"{name}": get_param_value("{name}")'
        new_cook = f'"{name}": Vector3(get_param_value("{name}_x"), get_param_value("{name}_y"), get_param_value("{name}_z"))'
        text = text.replace(old_cook, new_cook)

    if text != original:
        path.write_text(text, encoding="utf-8")
        return True
    return False

# Fix all SDF operator files
fixed = []
for gd in sorted(SDF.glob("*.gd")):
    if gd.name == "raymarch_sdf.gd":
        continue  # handle separately
    if fix_file(gd):
        fixed.append(gd.name)

print(f"Fixed {len(fixed)} operator files: {', '.join(fixed)}")

# ---------- Fix raymarch_sdf.gd separately -----------------------------------
rm = SDF / "raymarch_sdf.gd"
text = rm.read_text(encoding="utf-8")

# 1. Fix the light_dir parameter
text = text.replace(
    'add_parameter(GNParameter.create_vector3("light_dir", Vector3(-0.5, 0.8, 0.6),\n\t\t"Light Direction", "Directional light direction."))',
    'add_parameter(GNParameter.create_float("light_dir_x", -0.5, -1.0, 1.0, 0.01,\n'
    '\t\t"Light Dir X", "Directional light X component."))\n'
    '\tadd_parameter(GNParameter.create_float("light_dir_y", 0.8, -1.0, 1.0, 0.01,\n'
    '\t\t"Light Dir Y", "Directional light Y component."))\n'
    '\tadd_parameter(GNParameter.create_float("light_dir_z", 0.6, -1.0, 1.0, 0.01,\n'
    '\t\t"Light Dir Z", "Directional light Z component."))'
)

# 2. Fix the light_dir uniform setting in _cook
text = text.replace(
    'var ld: Vector3 = get_param_value("light_dir")',
    'var ld := Vector3(get_param_value("light_dir_x"), get_param_value("light_dir_y"), get_param_value("light_dir_z"))'
)

# 3. Fix _collect_uniforms: vec3 uniforms need to be 3 separate floats
# Actually no — the GLSL shader still uses vec3 uniforms. The GDScript side passes
# Vector3 values via set_shader_parameter which Godot converts to vec3.
# So the GLSL uniforms stay as vec3. The issue is only in _set_tree_uniforms
# where we need to reconstruct Vector3 from AST params dict.
# The AST params dict already stores Vector3 objects (from the operator's _cook()),
# so _set_tree_uniforms receiving Vector3 values is fine.

# Actually wait — the _set_v3 helper and set_shader_parameter("u_pos_0", Vector3(...))
# will still work because Godot maps GDScript Vector3 → GLSL vec3 uniform.
# The GLSL uniforms are still `uniform vec3 u_pos_0;` which is correct.
# set_shader_parameter accepts Vector3 for vec3 uniforms.

# So the raymarch compiler's GLSL side is fine. Only the _init_parameters and _cook
# in the operator files needed fixing.

rm.write_text(text, encoding="utf-8")
print("Fixed raymarch_sdf.gd (light_dir parameter)")

# ---------- Verify no more create_vector3 remain -----------------------------
remaining = []
for gd in sorted(SDF.glob("*.gd")):
    content = gd.read_text(encoding="utf-8")
    if "create_vector3" in content:
        remaining.append(gd.name)

if remaining:
    print(f"WARNING: create_vector3 still found in: {', '.join(remaining)}")
else:
    print("All create_vector3 calls removed successfully!")
