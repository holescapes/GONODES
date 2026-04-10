"""
Regenerate broken help patches where the focus operator is entirely missing.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

ROOT = Path(__file__).resolve().parent.parent
HELP_DIR = ROOT / "addons" / "gonodes" / "help"
REG_PATH = ROOT / "scripts" / "operator_registry.json"

reg_data = json.load(open(REG_PATH, encoding="utf-8"))
nt_fam_to_class = {}
nt_fam_to_entry = {}
for e in reg_data:
    key = (e["node_type"], e["family"])
    nt_fam_to_class[key] = e["class_name"]
    nt_fam_to_entry[key] = e

from help_patch_engine import (
    node, conn, annotation, p, vec2i, window_out,
    sop_render_chain, pop_render, vol_render_chain, chop_to_top,
)
from fix_help_patches import load_descriptions, human_name, _variant_from_filename


def find_broken_patches(scope="all"):
    broken = []
    family_dirs = []
    if scope in ("all", "core") and HELP_DIR.exists():
        for fdir in sorted(HELP_DIR.iterdir()):
            if fdir.is_dir():
                family_dirs.append((fdir, fdir.name))
    if scope in ("all", "extensions"):
        for ext_help in sorted(ROOT.glob("addons/gn_ext_*/help")):
            for fdir in sorted(ext_help.iterdir()):
                if fdir.is_dir():
                    family_dirs.append((fdir, fdir.name))

    for fdir, family in family_dirs:
        for pf in sorted(fdir.glob("*.gnpatch")):
            stem = pf.stem
            for sfx in ("_basic", "_advanced"):
                if stem.endswith(sfx):
                    stem = stem[:-len(sfx)]
                    break
            else:
                parts = stem.rsplit("_", 1)
                if len(parts) > 1:
                    stem = parts[0]

            key = (stem, family)
            if key not in nt_fam_to_class:
                continue

            expected = nt_fam_to_class[key]
            try:
                patch = json.load(open(pf, encoding="utf-8"))
            except Exception:
                continue

            types_in_patch = {nd.get("type") for nd in patch.get("nodes", {}).values()}
            if expected not in types_in_patch:
                broken.append((pf, family, stem, expected, nt_fam_to_entry[key]))
    return broken


def _wnd(nodes, name, x, y):
    n, d = window_out(name, x, y)
    nodes[n] = d
    return n


def regen(pf, family, node_type, cls, entry, dry_run):
    nodes = {}
    conns = []

    if family == "top":
        nodes["src_noise"] = node("NoiseTOP", 100, 100,
            {"resolution": vec2i(512, 512), "scale": p(4.0), "monochrome": p(True)})
        nodes["focus1"] = node(cls, 450, 100, {})
        w = _wnd(nodes, "window1", 800, 100)
        conns = [conn("src_noise", 0, "focus1", 0), conn("focus1", 0, w, 0)]

    elif family == "chop":
        nodes["src_wave"] = node("WaveCHOP", 100, 100, {"frequency": p(2.0), "amplitude": p(1.0)})
        nodes["focus1"] = node(cls, 450, 100, {})
        cn, cd = chop_to_top("choptop1", 800, 100)
        nodes[cn] = cd
        w = _wnd(nodes, "window1", 1150, 100)
        conns = [conn("src_wave", 0, "focus1", 0), conn("focus1", 0, cn, 0), conn(cn, 0, w, 0)]

    elif family == "sop":
        nodes["src_grid"] = node("GridSOP", 100, 100, {"rows": p(10), "cols": p(10)})
        nodes["focus1"] = node(cls, 450, 100, {})
        rc_n, rc_c = sop_render_chain(geo_x=800, render_x=1100)
        nodes.update(rc_n)
        w = _wnd(nodes, "window1", 1450, 100)
        conns = [conn("src_grid", 0, "focus1", 0), conn("focus1", 0, "geo_view", 0)] + rc_c + [conn("render_view", 0, w, 0)]

    elif family == "dat":
        nodes["src_text"] = node("TextDAT", 100, 100, {"text": p("Hello\\nworld\\n1,2,3")})
        nodes["focus1"] = node(cls, 450, 100, {})
        nodes["display1"] = node("TextTOP", 800, 100, {"resolution": vec2i(512, 512), "font_size": p(24)})
        w = _wnd(nodes, "window1", 1150, 100)
        conns = [conn("src_text", 0, "focus1", 0), conn("focus1", 0, "display1", 0), conn("display1", 0, w, 0)]

    elif family == "img":
        nodes["focus1"] = node(cls, 100, 100, {"resolution": vec2i(512, 512)})
        nodes["to_top"] = node("ImgToTOP", 450, 100, {})
        w = _wnd(nodes, "window1", 800, 100)
        conns = [conn("focus1", 0, "to_top", 0), conn("to_top", 0, w, 0)]

    elif family == "mat":
        nodes["src_sphere"] = node("SphereSOP", 100, 100, {})
        nodes["focus1"] = node(cls, 100, 250, {})
        rc_n, rc_c = sop_render_chain(geo_x=450, render_x=750)
        nodes.update(rc_n)
        w = _wnd(nodes, "window1", 1100, 100)
        conns = [conn("src_sphere", 0, "geo_view", 0), conn("focus1", 0, "geo_view", 1)] + rc_c + [conn("render_view", 0, w, 0)]

    elif family == "comp":
        nodes["src_sphere"] = node("SphereSOP", 100, 100, {})
        nodes["focus1"] = node(cls, 100, 250, {})
        rc_n, rc_c = sop_render_chain(geo_x=450, render_x=750)
        nodes.update(rc_n)
        w = _wnd(nodes, "window1", 1100, 100)
        conns = [conn("src_sphere", 0, "geo_view", 0), conn("focus1", 0, "render_view", 2)] + rc_c + [conn("render_view", 0, w, 0)]

    elif family in ("vol", "sdf"):
        nodes["src_grid"] = node("GridSOP", 100, 100, {"rows": p(20), "cols": p(20)})
        nodes["focus1"] = node(cls, 450, 100, {})
        vr_n, vr_c = vol_render_chain("raymarch1", 800, 100)
        nodes.update(vr_n)
        w = _wnd(nodes, "window1", 1150, 100)
        conns = [conn("src_grid", 0, "focus1", 0), conn("focus1", 0, "raymarch1", 0), conn("raymarch1", 0, w, 0)]

    elif family == "pop":
        nodes["source1"] = node("SourcePOP", 100, 100, {"emit_rate": p(100)})
        nodes["focus1"] = node(cls, 450, 100, {})
        pn, pd = pop_render("pop_render", 800, 100)
        nodes[pn] = pd
        w = _wnd(nodes, "window1", 1150, 100)
        conns = [conn("source1", 0, "focus1", 0), conn("focus1", 0, pn, 0), conn(pn, 0, w, 0)]

    elif family == "ui":
        nodes["focus1"] = node(cls, 100, 100, {})
        w = _wnd(nodes, "window1", 450, 100)
        conns = [conn("focus1", 0, w, 0)]

    elif family == "output":
        nodes["src_noise"] = node("NoiseTOP", 100, 100,
            {"resolution": vec2i(512, 512), "scale": p(4.0)})
        nodes["focus1"] = node(cls, 450, 100, {})
        conns = [conn("src_noise", 0, "focus1", 0)]

    else:
        nodes["focus1"] = node(cls, 100, 100, {})
        w = _wnd(nodes, "window1", 450, 100)
        conns = [conn("focus1", 0, w, 0)]

    descs = load_descriptions()
    desc = descs.get(cls, f"Demonstrates {cls} functionality.")
    hname = human_name(cls)
    variant = _variant_from_filename(pf.stem)

    patch_data = {
        "version": "1.0.0",
        "generator": "GONODES",
        "nodes": nodes,
        "connections": conns,
        "annotations": [annotation(f"{hname} — {variant}\n\n{desc}", -100, -100, 500, 120)],
    }

    if not dry_run:
        with open(pf, "w", encoding="utf-8", newline="") as f:
            json.dump(patch_data, f, indent=4, ensure_ascii=False)
            f.write("\n")
    return True


if __name__ == "__main__":
    dry_run = "--dry-run" in sys.argv
    scope = "extensions" if "--extensions-only" in sys.argv else ("core" if "--core-only" in sys.argv else "all")
    broken = find_broken_patches(scope=scope)
    print(f"Found {len(broken)} broken patches.")

    fixed = failed = 0
    for pf, family, nt, expected, entry in broken:
        try:
            ok = regen(pf, family, nt, expected, entry, dry_run)
            if ok:
                fixed += 1
                print(f"  [{'WOULD REGEN' if dry_run else 'REGEN'}] {family}/{pf.name} ({expected})")
            else:
                failed += 1
        except Exception as e:
            failed += 1
            print(f"  [ERROR] {family}/{pf.name}: {e}")

    print(f"\n{'Dry-run' if dry_run else 'Done'}: {fixed} regenerated, {failed} failed, {len(broken)} total")
