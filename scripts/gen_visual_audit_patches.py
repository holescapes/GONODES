#!/usr/bin/env python3
"""Generate tests/visual_audit/*.gnpatch packs for human visual review.

Creates:
  - Curated capability demos (wired to WindowOUT with Open ON)
  - Per-family inventory galleries (one node per class, annotated)
  - CHECKLIST.md master checklist

Usage:
  python scripts/gen_visual_audit_patches.py
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tests" / "visual_audit"
REG = ROOT / "scripts" / "operator_registry.json"


def v2i(x: int, y: int) -> dict:
	return {"_type": "Vector2i", "x": x, "y": y}


def node(nid: str, typ: str, x: float, y: float, params: dict | None = None) -> dict:
	d: dict = {"type": typ, "position": [x, y]}
	if params:
		cooked = {}
		for k, v in params.items():
			cooked[k] = {"value": v}
		d["parameters"] = cooked
	return d


def conn(src: str, sport: int, dst: str, dport: int) -> dict:
	return {
		"from_node": src,
		"from_port": sport,
		"to_node": dst,
		"to_port": dport,
	}


def note(text: str, x: float, y: float, w: float = 520, h: float = 160) -> dict:
	return {
		"id": f"ann_{abs(hash(text)) % 10_000_000}",
		"type": "note",
		"text": text,
		"position": [x, y],
		"size": [w, h],
		"color": [1.0, 0.95, 0.55, 0.92],
	}


def write_patch(name: str, nodes: dict, connections: list, annotations: list) -> None:
	path = OUT / name
	path.parent.mkdir(parents=True, exist_ok=True)
	payload = {
		"version": "1.0.0",
		"generator": "visual_audit",
		"nodes": nodes,
		"connections": connections,
		"annotations": annotations,
	}
	path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
	print("wrote", path.relative_to(ROOT))


def pack_window_basics() -> None:
	nodes = {
		"noise": node("noise", "NoiseTOP", 0, 200),
		"win": node(
			"win",
			"WindowOUT",
			400,
			200,
			{"open": True, "title": "VA: Window Basics", "resolution": v2i(640, 360)},
		),
	}
	write_patch(
		"01_window_out_basics.gnpatch",
		nodes,
		[conn("noise", 0, "win", 0)],
		[note(
			"VISUAL AUDIT 01 — WindowOUT\n"
			"□ Open is ON → window appears\n"
			"□ Toggle Open OFF → window hides\n"
			"□ Default res was 512; this pack uses 640×360\n"
			"□ Change monitor / always_on_top / vsync",
			-100, 20,
		)],
	)


def pack_top_generators() -> None:
	gens = [
		("NoiseTOP", "noise"),
		("RampTOP", "ramp"),
		("CircleTOP", "circle"),
		("RectangleTOP", "rect"),
		("ConstantTOP", "const"),
		("PatternTOP", "pattern"),
		("TextTOP", "text"),
		("TestCardTOP", "card"),
	]
	nodes: dict = {}
	for i, (typ, nid) in enumerate(gens):
		nodes[nid] = node(nid, typ, 0, i * 180)
	nodes["switch"] = node("switch", "SwitchTOP", 400, 400)
	# SwitchTOP typically needs dynamic inputs — connect first few
	nodes["win"] = node(
		"win", "WindowOUT", 800, 400, {"open": True, "title": "VA: TOP Generators", "resolution": v2i(640, 360)}
	)
	connections = []
	for i, (_typ, nid) in enumerate(gens[:8]):
		connections.append(conn(nid, 0, "switch", i if i < 8 else 0))
	connections.append(conn("switch", 0, "win", 0))
	write_patch(
		"02_top_generators.gnpatch",
		nodes,
		connections,
		[note(
			"VISUAL AUDIT 02 — TOP generators\n"
			"□ Select SwitchTOP index to flip sources\n"
			"□ Noise animates with time\n"
			"□ Text / TestCard readable\n"
			"□ Constant solid color",
			-120, -80, 480, 140,
		)],
	)


def pack_top_filters() -> None:
	nodes = {
		"noise": node("noise", "NoiseTOP", 0, 200),
		"blur": node("blur", "BlurTOP", 280, 200, {"size": 4.0}),
		"level": node("level", "LevelTOP", 560, 200),
		"hsv": node("hsv", "HSVAdjustTOP", 840, 200),
		"edge": node("edge", "EdgeTOP", 1120, 200),
		"win": node(
			"win", "WindowOUT", 1400, 200, {"open": True, "title": "VA: TOP Filters", "resolution": v2i(640, 360)}
		),
	}
	write_patch(
		"03_top_filter_chain.gnpatch",
		nodes,
		[
			conn("noise", 0, "blur", 0),
			conn("blur", 0, "level", 0),
			conn("level", 0, "hsv", 0),
			conn("hsv", 0, "edge", 0),
			conn("edge", 0, "win", 0),
		],
		[note(
			"VISUAL AUDIT 03 — filter chain\n"
			"Noise → Blur → Level → HSV → Edge → Window\n"
			"□ Tweak Blur size\n"
			"□ Level / HSV change look\n"
			"□ Edge outlines visible",
			-100, 20,
		)],
	)


def pack_mapper_dual() -> None:
	nodes = {
		"noise": node("noise", "NoiseTOP", 0, 200),
		"bezier": node("bezier", "BezierMapTOP", 350, 200),
		"win": node(
			"win",
			"WindowOUT",
			700,
			200,
			{"open": True, "title": "VA: Mapper Dual Panel", "resolution": v2i(800, 450)},
		),
	}
	write_patch(
		"04_mapper_dual_panel.gnpatch",
		nodes,
		[
			conn("noise", 0, "bezier", 0),
			conn("bezier", 0, "win", 0),
			conn("bezier", 1, "win", 1),  # panel → WindowOUT panel
		],
		[note(
			"VISUAL AUDIT 04 — dual interactive panel (Rule 25.42)\n"
			"□ Viewer on BezierMap Out: handles ON texture\n"
			"□ WindowOUT Open: handles ALSO in pop-out\n"
			"□ Drag either → both stay in sync\n"
			"□ No crash when wiring panel",
			-120, 20, 520, 160,
		)],
	)


def pack_3d_render() -> None:
	nodes = {
		"box": node("box", "BoxSOP", 0, 200),
		"geo": node("geo", "GeometryCOMP", 280, 200),
		"cam": node("cam", "CameraCOMP", 280, 400),
		"light": node("light", "LightCOMP", 280, 600),
		"render": node("render", "RenderTOP", 560, 300),
		"win": node(
			"win", "WindowOUT", 880, 300, {"open": True, "title": "VA: 3D Render", "resolution": v2i(640, 360)}
		),
	}
	write_patch(
		"05_3d_render.gnpatch",
		nodes,
		[
			conn("box", 0, "geo", 0),
			conn("geo", 0, "render", 0),
			conn("cam", 0, "render", 0),
			conn("light", 0, "render", 0),
			conn("render", 0, "win", 0),
		],
		[note(
			"VISUAL AUDIT 05 — 3D RenderTOP\n"
			"□ Cube visible in window\n"
			"□ Orbit camera / move light\n"
			"□ Post-FX NOT on RenderTOP — use EnvironmentCOMP\n"
			"□ cook_every_frame toggle",
			-100, 20,
		)],
	)


def pack_ui_panel() -> None:
	nodes = {
		"noise": node("noise", "NoiseTOP", 0, 200),
		"btn": node("btn", "ButtonUI", 0, 450),
		"slider": node("slider", "SliderUI", 0, 600),
		"container": node("container", "ContainerUI", 350, 500),
		"win": node(
			"win", "WindowOUT", 700, 300, {"open": True, "title": "VA: UI Panel", "resolution": v2i(640, 480)}
		),
	}
	write_patch(
		"06_ui_window_panel.gnpatch",
		nodes,
		[
			conn("noise", 0, "win", 0),
			conn("btn", 0, "container", 0),
			conn("slider", 0, "container", 0),
			conn("container", 0, "win", 1),
		],
		[note(
			"VISUAL AUDIT 06 — UI → WindowOUT panel\n"
			"□ Open window: texture + UI widgets\n"
			"□ Button / Slider clickable in window\n"
			"□ Viewer can pin UI state CHOPs",
			-100, 20,
		)],
	)


def pack_out_exporters_note() -> None:
	"""Gallery of exporter nodes (Active OFF) fed by a still — do not leave Active on."""
	nodes = {
		"noise": node("noise", "NoiseTOP", 0, 200),
		"to_img": node("to_img", "TOPtoIMG", 280, 200),
		"img_save": node("img_save", "ImageSaveOUT", 560, 50, {"active": False}),
		"tex_save": node("tex_save", "TextureSaveOUT", 560, 200, {"active": False}),
		"movie": node("movie", "MovieOUT", 560, 350, {"active": False}),
		"ffmpeg": node("ffmpeg", "FFmpegOUT", 560, 500, {"active": False}),
		"win": node(
			"win",
			"WindowOUT",
			900,
			200,
			{"open": True, "title": "VA: Exporters (preview)", "resolution": v2i(512, 288)},
		),
	}
	write_patch(
		"07_out_exporters.gnpatch",
		nodes,
		[
			conn("noise", 0, "to_img", 0),
			conn("to_img", 0, "img_save", 0),
			conn("noise", 0, "tex_save", 0),
			conn("to_img", 0, "movie", 0),
			conn("to_img", 0, "ffmpeg", 0),
			conn("noise", 0, "win", 0),
		],
		[note(
			"VISUAL AUDIT 07 — exporters (KEEP Active OFF unless intentional)\n"
			"□ ImageSave = sync still/sequence\n"
			"□ TextureSave = GPU readback + async write\n"
			"□ MovieOUT = numbered frames folder\n"
			"□ FFmpegOUT = Capture then background encode\n"
			"□ Confirm file pickers open (not plain strings)",
			-120, -40, 560, 180,
		)],
	)


def pack_audio_chain() -> None:
	nodes = {
		"audio": node("audio", "AudioFileInCHOP", 0, 200, {"play": False, "gain": 2.0}),
		"spec": node("spec", "AudioSpectrumCHOP", 320, 200),
		"band": node("band", "AudioBandCHOP", 640, 200),
		"noise": node("noise", "NoiseTOP", 0, 450),
		"win": node(
			"win", "WindowOUT", 640, 450, {"open": True, "title": "VA: Audio Chain", "resolution": v2i(512, 288)}
		),
	}
	write_patch(
		"08_audio_spectrum_band.gnpatch",
		nodes,
		[
			conn("audio", 0, "spec", 0),
			conn("spec", 0, "band", 0),
			conn("noise", 0, "win", 0),
		],
		[note(
			"VISUAL AUDIT 08 — audio analysis\n"
			"1. Set AudioFileIn file to a WAV/OGG\n"
			"2. Play ON, raise Gain if bands weak\n"
			"3. Viewer on Spectrum / Band — channels move\n"
			"□ start_pos cues playhead\n"
			"□ load_mode Auto/Memory/Stream",
			-100, 20, 520, 180,
		)],
	)


def family_galleries(registry: list | dict) -> list[tuple[str, int]]:
	"""One patch per family: grid of operators (unwired) for pick-and-view."""
	by_fam: dict[str, list[str]] = {}
	entries = registry if isinstance(registry, list) else registry.get("operators", [])
	if isinstance(registry, dict) and not entries:
		# flat dict class_name -> meta
		entries = [{"class_name": k, **v} for k, v in registry.items() if isinstance(v, dict)]
	for meta in entries:
		if not isinstance(meta, dict):
			continue
		name = str(meta.get("class_name", ""))
		if not name or name.endswith("Native"):
			continue
		fam = str(meta.get("family", "unknown")).lower()
		by_fam.setdefault(fam, []).append(name)

	counts: list[tuple[str, int]] = []
	for fam, names in sorted(by_fam.items()):
		names = sorted(names)
		nodes: dict = {}
		cols = 8
		for i, typ in enumerate(names):
			x = (i % cols) * 280
			y = (i // cols) * 200
			nid = f"n{i}"
			nodes[nid] = node(nid, typ, float(x), float(y))
		# optional window for TOP/IMG families
		anns = [note(
			f"VISUAL AUDIT — {fam.upper()} inventory ({len(names)} ops)\n"
			f"□ Click each node; check viewer / params match docs\n"
			f"□ Wire into a Null/Window as needed\n"
			f"□ Mark CHECKLIST.md when done",
			-200, -160, 640, 140,
		)]
		if fam in ("top", "img"):
			nodes["win"] = node(
				"win",
				"WindowOUT",
				float(cols * 280 + 100),
				0.0,
				{"open": False, "title": f"VA: {fam}", "resolution": v2i(512, 288)},
			)
			anns.append(note(
				"WindowOUT included (Open OFF).\n"
				"Wire any TOP/IMG → win when ready to fullscreen-check.",
				-200, -20, 400, 100,
			))
		safe = fam.replace("/", "_")
		write_patch(f"gallery/{safe}_inventory.gnpatch", nodes, [], anns)
		counts.append((fam, len(names)))
	return counts


def write_checklist(family_counts: list[tuple[str, int]]) -> None:
	lines = [
		"# GONODES Visual Audit Checklist",
		"",
		"Open patches from `tests/visual_audit/` in the editor (File → Open).",
		"For WindowOUT packs, confirm **Open** is ON (or toggle it).",
		"",
		"## Capability demos",
		"",
		"| Pack | Focus | Done |",
		"|------|-------|------|",
		"| `01_window_out_basics.gnpatch` | Open toggle, resolution, monitor | ☐ |",
		"| `02_top_generators.gnpatch` | Noise/Ramp/Circle/… via Switch | ☐ |",
		"| `03_top_filter_chain.gnpatch` | Blur → Level → HSV → Edge | ☐ |",
		"| `04_mapper_dual_panel.gnpatch` | Viewer + WindowOUT handles sync | ☐ |",
		"| `05_3d_render.gnpatch` | Box → Geo → Render → Window | ☐ |",
		"| `06_ui_window_panel.gnpatch` | ContainerUI in WindowOUT panel | ☐ |",
		"| `07_out_exporters.gnpatch` | Save/Movie/FFmpeg (keep Active OFF) | ☐ |",
		"| `08_audio_spectrum_band.gnpatch` | FileIn → Spectrum → Band | ☐ |",
		"",
		"## Family inventories (`gallery/`)",
		"",
		"| Family | Ops | Patch | Done |",
		"|--------|----:|-------|------|",
	]
	for fam, n in family_counts:
		lines.append(f"| {fam} | {n} | `gallery/{fam}_inventory.gnpatch` | ☐ |")
	lines += [
		"",
		"## Per-node notes",
		"",
		"While reviewing a gallery node, tick if:",
		"",
		"- [ ] Instantiates without error",
		"- [ ] Params match `docs/OPERATORS.md` / tooltip help",
		"- [ ] Cook produces expected family output in viewer",
		"- [ ] File/folder params use pickers (not bare strings)",
		"- [ ] Extension-gated ops warn clearly when DLL/model missing",
		"",
		"Regenerate packs: `python scripts/gen_visual_audit_patches.py`",
		"",
	]
	(OUT / "CHECKLIST.md").write_text("\n".join(lines), encoding="utf-8")
	print("wrote", (OUT / "CHECKLIST.md").relative_to(ROOT))


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	(OUT / "gallery").mkdir(parents=True, exist_ok=True)

	pack_window_basics()
	pack_top_generators()
	pack_top_filters()
	pack_mapper_dual()
	pack_3d_render()
	pack_ui_panel()
	pack_out_exporters_note()
	pack_audio_chain()

	registry = json.loads(REG.read_text(encoding="utf-8"))
	counts = family_galleries(registry)
	write_checklist(counts)

	readme = """# Visual Audit Packs

Human-driven visual review of GONODES operators.

## How to use

1. Run GONODES (Godot 4.7.2, Game embed off or Stretch to Fit).
2. **File → Open** a pack from this folder.
3. Follow the yellow note on the graph + `CHECKLIST.md`.
4. For packs with **WindowOUT**, set **Open = ON** if the window is closed.

## Contents

- `01`–`08` — curated capability demos (wired graphs).
- `gallery/*_inventory.gnpatch` — one instance of every registered op in that family.
- `CHECKLIST.md` — master tick list.

Regenerate after registry changes:

```bash
python scripts/gen_visual_audit_patches.py
```
"""
	(OUT / "README.md").write_text(readme, encoding="utf-8")
	print("done →", OUT)


if __name__ == "__main__":
	main()
