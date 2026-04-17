#!/usr/bin/env python3
"""Generate ALL_CORE_*.gnpatch comprehensive manual test patches.

Creates one patch per family that chains ALL operators together in meaningful
groups, routed through a SwitchTOP → WindowOUT for easy visual inspection.

Pattern (matching ALL_CORE_TOPs.gnpatch):
  - Operators grouped into functional chains
  - Each chain ends in a NullTOP labelled "OUTChainN"
  - All OUTChains feed a SwitchTOP → WindowOUT
  - Operators have non-default params to exercise functionality
  - Visualization: CHOPs → CHOPtoTOP, SOPs → GeoCOMP+CameraCOMP+RenderTOP,
    DATs → TextTOP, IMGs → ImgToTOP, MATs → GeoCOMP+CameraCOMP+RenderTOP,
    UIs → PanelTOP, POPs → PointCloudRenderTOP, VOLs → RaymarchVOL+SnapshotTOP

Usage:
    python scripts/gen_all_core_patches.py
"""

import json
import os
import sys

MANUAL_DIR = os.path.join(os.path.dirname(__file__), "..", "tests", "manual")

# Layout constants
COL_W = 300       # horizontal spacing between nodes
ROW_H = 200       # vertical spacing between chains
SWITCH_X = -400   # SwitchTOP X position
CHAIN_START_X = 0 # first node in chain X


class PatchBuilder:
    """Builds a .gnpatch with chains routed to a SwitchTOP → WindowOUT."""

    def __init__(self, family_label):
        self.family_label = family_label
        self.nodes = {}
        self.connections = []
        self.chain_idx = 0
        self._id_counter = {}

    def _uid(self, prefix):
        """Generate unique id like 'noise1', 'noise2', etc."""
        n = self._id_counter.get(prefix, 0) + 1
        self._id_counter[prefix] = n
        return f"{prefix}{n}"

    def add_node(self, node_id, class_name, x, y, params=None):
        entry = {"type": class_name, "position": [x, y]}
        if params:
            entry["parameters"] = params
        self.nodes[node_id] = entry
        return node_id

    def connect(self, from_id, from_port, to_id, to_port):
        self.connections.append({
            "from": from_id, "from_port": from_port,
            "to": to_id, "to_port": to_port,
        })

    def add_chain(self, nodes_list, chain_label=None):
        """Add a chain of nodes. Returns the last node id and OUTChain id.

        nodes_list: list of (class_name, params_dict_or_None, extra_inputs_list)
            extra_inputs is list of (src_id, src_port, dst_port) for multi-input nodes.
        """
        self.chain_idx += 1
        chain_y = self.chain_idx * ROW_H

        prev_id = None
        for i, item in enumerate(nodes_list):
            if len(item) == 2:
                cls, params = item
                extras = []
            else:
                cls, params, extras = item

            # Make a short prefix from class name
            prefix = cls.lower().replace("top", "").replace("chop", "").replace("sop", "")
            prefix = prefix.replace("dat", "").replace("img", "").replace("mat", "")
            prefix = prefix.replace("comp", "").replace("vol", "").replace("pop", "")
            prefix = prefix.replace("sdf", "").replace("out", "").replace("ui", "")
            prefix = prefix.replace("script", "").replace("net", "")
            if not prefix:
                prefix = "node"
            nid = self._uid(prefix)

            x = CHAIN_START_X + i * COL_W
            self.add_node(nid, cls, x, chain_y, params)

            if prev_id is not None:
                self.connect(prev_id, 0, nid, 0)
            prev_id = nid

        # End chain with NullTOP
        out_id = f"OUTChain{self.chain_idx}"
        self.add_node(out_id, "NullTOP",
                      SWITCH_X + 200, chain_y)
        if prev_id:
            self.connect(prev_id, 0, out_id, 0)

        return out_id

    def add_chop_vis_chain(self, chop_nodes, chain_label=None):
        """Add a CHOP chain that ends with CHOPtoTOP → NullTOP for visualization."""
        self.chain_idx += 1
        chain_y = self.chain_idx * ROW_H
        prev_id = None

        for i, item in enumerate(chop_nodes):
            if len(item) == 2:
                cls, params = item
            else:
                cls, params = item[0], item[1]
            prefix = cls.lower().replace("chop", "").replace("_", "")
            if not prefix:
                prefix = "ch"
            nid = self._uid(prefix)
            x = CHAIN_START_X + i * COL_W
            self.add_node(nid, cls, x, chain_y, params)
            if prev_id:
                self.connect(prev_id, 0, nid, 0)
            prev_id = nid

        # CHOPtoTOP for visualization
        c2t = self._uid("choptotop")
        self.add_node(c2t, "CHOPtoTOP",
                      CHAIN_START_X + len(chop_nodes) * COL_W, chain_y)
        if prev_id:
            self.connect(prev_id, 0, c2t, 0)

        out_id = f"OUTChain{self.chain_idx}"
        self.add_node(out_id, "NullTOP", SWITCH_X + 200, chain_y)
        self.connect(c2t, 0, out_id, 0)
        return out_id

    def add_sop_vis_chain(self, sop_nodes, chain_label=None):
        """SOP chain → GeoCOMP + CameraCOMP → RenderTOP → NullTOP."""
        self.chain_idx += 1
        chain_y = self.chain_idx * ROW_H
        prev_id = None

        for i, item in enumerate(sop_nodes):
            cls, params = (item[0], item[1]) if len(item) >= 2 else (item[0], None)
            prefix = cls.lower().replace("sop", "").replace("_", "")
            if not prefix:
                prefix = "s"
            nid = self._uid(prefix)
            x = CHAIN_START_X + i * COL_W
            self.add_node(nid, cls, x, chain_y, params)
            if prev_id:
                self.connect(prev_id, 0, nid, 0)
            prev_id = nid

        n = len(sop_nodes)
        geo = self._uid("geo")
        cam = self._uid("cam")
        render = self._uid("render")
        self.add_node(geo, "GeometryCOMP", CHAIN_START_X + n * COL_W, chain_y)
        self.add_node(cam, "CameraCOMP", CHAIN_START_X + n * COL_W, chain_y + 100)
        self.add_node(render, "RenderTOP", CHAIN_START_X + (n + 1) * COL_W, chain_y)

        if prev_id:
            self.connect(prev_id, 0, geo, 0)
        self.connect(geo, 0, render, 0)
        self.connect(cam, 0, render, 1)

        out_id = f"OUTChain{self.chain_idx}"
        self.add_node(out_id, "NullTOP", SWITCH_X + 200, chain_y)
        self.connect(render, 0, out_id, 0)
        return out_id

    def add_dat_vis_chain(self, dat_nodes, chain_label=None):
        """DAT chain → TextTOP → NullTOP."""
        self.chain_idx += 1
        chain_y = self.chain_idx * ROW_H
        prev_id = None

        for i, item in enumerate(dat_nodes):
            cls, params = (item[0], item[1]) if len(item) >= 2 else (item[0], None)
            prefix = cls.lower().replace("dat", "").replace("_", "")
            if not prefix:
                prefix = "d"
            nid = self._uid(prefix)
            x = CHAIN_START_X + i * COL_W
            self.add_node(nid, cls, x, chain_y, params)
            if prev_id:
                self.connect(prev_id, 0, nid, 0)
            prev_id = nid

        text_top = self._uid("texttop")
        self.add_node(text_top, "TextTOP",
                      CHAIN_START_X + len(dat_nodes) * COL_W, chain_y,
                      {"text": {"value": "", "expression": "dat('" + prev_id + "', 0, 0)"}})

        out_id = f"OUTChain{self.chain_idx}"
        self.add_node(out_id, "NullTOP", SWITCH_X + 200, chain_y)
        self.connect(text_top, 0, out_id, 0)
        return out_id

    def add_img_vis_chain(self, img_nodes, chain_label=None):
        """IMG chain → ImgToTOP → NullTOP."""
        self.chain_idx += 1
        chain_y = self.chain_idx * ROW_H
        prev_id = None

        for i, item in enumerate(img_nodes):
            cls, params = (item[0], item[1]) if len(item) >= 2 else (item[0], None)
            prefix = cls.lower().replace("img", "").replace("_", "")
            if not prefix:
                prefix = "im"
            nid = self._uid(prefix)
            x = CHAIN_START_X + i * COL_W
            self.add_node(nid, cls, x, chain_y, params)
            if prev_id:
                self.connect(prev_id, 0, nid, 0)
            prev_id = nid

        i2t = self._uid("imgtotop")
        self.add_node(i2t, "ImgToTOP",
                      CHAIN_START_X + len(img_nodes) * COL_W, chain_y)
        if prev_id:
            self.connect(prev_id, 0, i2t, 0)

        out_id = f"OUTChain{self.chain_idx}"
        self.add_node(out_id, "NullTOP", SWITCH_X + 200, chain_y)
        self.connect(i2t, 0, out_id, 0)
        return out_id

    def finalize(self):
        """Add SwitchTOP → WindowOUT, connect all OUTChains."""
        switch_id = "switch_main"
        self.add_node(switch_id, "SwitchTOP", SWITCH_X, 0)

        win_id = "window_out1"
        self.add_node(win_id, "WindowOUT", SWITCH_X - COL_W, 0,
                      {"resolution": {"value": {"_type": "Vector2i", "x": 512, "y": 512}},
                       "open": {"value": True}})
        self.connect(switch_id, 0, win_id, 0)

        # UI panel for chain selection
        slider_id = "chain_slider"
        self.add_node(slider_id, "SliderUI", SWITCH_X - COL_W, 200,
                      {"label": {"value": "Chain"},
                       "min": {"value": 0.0},
                       "max": {"value": float(self.chain_idx)},
                       "value": {"value": 0.0}})
        label_id = "chain_label"
        self.add_node(label_id, "LabelUI", SWITCH_X - COL_W, 400,
                      {"text": {"value": f"ALL CORE {self.family_label} — {self.chain_idx} chains"}})

        panel_id = "panel_container"
        self.add_node(panel_id, "PanelContainerUI", SWITCH_X - COL_W - 200, 200)
        self.connect(slider_id, 0, panel_id, 0)
        self.connect(label_id, 0, panel_id, 1)
        self.connect(panel_id, 0, win_id, 1)

        # Connect all OUTChains to switch
        for i in range(1, self.chain_idx + 1):
            out_id = f"OUTChain{i}"
            if out_id in self.nodes:
                self.connect(out_id, 0, switch_id, i - 1)

        return {
            "version": "1.0.0",
            "generator": "GONODES_manual_test",
            "nodes": self.nodes,
            "connections": self.connections,
        }


def write_patch(family, name, data):
    d = os.path.join(MANUAL_DIR, family)
    os.makedirs(d, exist_ok=True)
    fp = os.path.join(d, name + ".gnpatch")
    with open(fp, "w", encoding="utf-8", newline="") as f:
        json.dump(data, f, indent="\t")
    print(f"  Wrote {fp} ({len(data['nodes'])} nodes, {len(data['connections'])} connections)")
    return fp


def p(key, val):
    """Shorthand for parameter dict."""
    return {key: {"value": val}}


def pv2i(key, x, y):
    return {key: {"value": {"_type": "Vector2i", "x": x, "y": y}}}


def pcolor(key, r, g, b, a=1.0):
    return {key: {"value": {"_type": "Color", "r": r, "g": g, "b": b, "a": a}}}


def merge_params(*dicts):
    result = {}
    for d in dicts:
        result.update(d)
    return result


# ═══════════════════════════════════════════════════════════════════════════════
# CHOP — 85 operators
# ═══════════════════════════════════════════════════════════════════════════════

def build_chop_patch():
    b = PatchBuilder("CHOPs")

    # Chain 1: Generators — LFO → Noise → Wave → Pattern → Constant
    b.add_chop_vis_chain([
        ("LFO_CHOP", p("frequency", 2.0)),
        ("NoiseCHOP", merge_params(p("type", 1), p("channels", 3))),
        ("MathCHOP", merge_params(p("gain", 2.0), p("operation", 0))),
        ("NullCHOP", None),
    ])

    # Chain 2: Wave shapes + analysis
    b.add_chop_vis_chain([
        ("WaveCHOP", merge_params(p("shape", 2), p("frequency", 3.0), p("length", 100))),
        ("AnalyzeCHOP", p("function", 0)),
    ])

    # Chain 3: Pattern + Ramp + Lookup + Channel
    b.add_chop_vis_chain([
        ("PatternCHOP", merge_params(p("type", 0), p("length", 200))),
        ("RampCHOP", None),
        ("LookupCHOP", None),
        ("ChannelCHOP", None),
    ])

    # Chain 4: Channel management — Constant → Merge → Rename → Select → Shuffle
    b.add_chop_vis_chain([
        ("ConstantCHOP", merge_params(p("value0", 1.0), p("name0", "tx"))),
        ("RenameCHOP", p("from0", "tx")),
        ("SelectCHOP", p("pattern", "*")),
        ("ShuffleCHOP", p("method", 0)),
        ("NullCHOP", None),
    ])

    # Chain 5: Signal processing — LFO → Lag → Smooth → Filter → Limit → Clip
    b.add_chop_vis_chain([
        ("LFO_CHOP", p("frequency", 4.0)),
        ("LagCHOP", merge_params(p("lag_up", 0.2), p("lag_down", 0.1))),
        ("SmoothCHOP", p("width", 5)),
        ("FilterCHOP", merge_params(p("type", 0), p("cutoff", 0.3))),
        ("LimitCHOP", merge_params(p("min", -0.5), p("max", 0.5))),
        ("ClipCHOP", merge_params(p("min", -0.3), p("max", 0.3))),
    ])

    # Chain 6: Time ops — Wave → Delay → Stretch → Trim → Extend → Speed → Resample
    b.add_chop_vis_chain([
        ("WaveCHOP", merge_params(p("shape", 0), p("length", 100))),
        ("DelayCHOP", p("delay", 10)),
        ("StretchCHOP", p("length", 200)),
        ("TrimCHOP", merge_params(p("start", 10), p("end", 80))),
        ("ExtendCHOP", p("extend_left", 1)),
        ("SpeedCHOP", p("speed", 2.0)),
        ("ResampleCHOP", p("rate", 30.0)),
    ])

    # Chain 7: Combiners — Constant → Composite → Cross → Blend
    b.add_chop_vis_chain([
        ("ConstantCHOP", merge_params(p("value0", 3.0), p("name0", "a"))),
        ("CompositeCHOP", p("operation", 0)),
        ("CrossCHOP", p("cross", 0.5)),
        ("BlendCHOP", p("blend", 0.5)),
    ])

    # Chain 8: Animation — Keyframe → Sequence → Timer → Cue
    b.add_chop_vis_chain([
        ("KeyframeCHOP", None),
        ("SequenceCHOP", None),
        ("TimerCHOP", None),
        ("CueCHOP", None),
    ])

    # Chain 9: Logic + Expression + Hold + Parameter
    b.add_chop_vis_chain([
        ("LFO_CHOP", p("frequency", 1.0)),
        ("LogicCHOP", p("operation", 0)),
        ("HoldCHOP", None),
        ("ExpressionCHOP", None),
        ("ParameterCHOP", None),
    ])

    # Chain 10: Timing — Clock → Count → Trigger → Trail
    b.add_chop_vis_chain([
        ("ClockCHOP", None),
        ("CountCHOP", merge_params(p("threshold", 0.5), p("limit_max", 10))),
        ("TriggerCHOP", merge_params(p("attack", 0.1), p("decay", 0.5))),
        ("TrailCHOP", None),
    ])

    # Chain 11: Spring + IK + Warp + Envelope + Beat + Object
    b.add_chop_vis_chain([
        ("NoiseCHOP", merge_params(p("type", 0), p("channels", 1))),
        ("SpringCHOP", merge_params(p("stiffness", 10.0), p("damping", 0.5))),
        ("EnvelopeCHOP", p("attack", 0.1)),
        ("BeatCHOP", p("threshold", 0.3)),
        ("ObjectCHOP", None),
    ])

    # Chain 12: Copy + Delete + Join + Split + Fan
    b.add_chop_vis_chain([
        ("WaveCHOP", merge_params(p("shape", 1), p("length", 50))),
        ("CopyCHOP", p("copies", 3)),
        ("DeleteCHOP", p("channel_names", "chan2")),
        ("JoinCHOP", None),
        ("FanCHOP", p("fan_out", 4)),
        ("SplitCHOP", None),
    ])

    # Chain 13: Transform + Slope + Interpolate + Skeleton + IK
    b.add_chop_vis_chain([
        ("NoiseCHOP", p("channels", 3)),
        ("TransformCHOP", merge_params(p("tx", 1.0), p("ry", 45.0))),
        ("SlopeCHOP", None),
        ("InterpolateCHOP", p("length", 200)),
        ("SkeletonCHOP", None),
        ("IKCHOP", None),
    ])

    # Chain 14: Input devices — Perform + Timeline + Keyboard + Mouse + Tablet + Gamepad
    b.add_chop_vis_chain([
        ("PerformCHOP", None),
        ("TimelineCHOP", None),
        ("KeyboardInCHOP", None),
        ("MouseInCHOP", None),
        ("TabletInCHOP", None),
        ("GamepadCHOP", None),
    ])

    # Chain 15: Bridges — SOPtoCHOP + TOPtoCHOP + DATtoCHOP + Feedback + Warp
    b.add_chop_vis_chain([
        ("WaveCHOP", merge_params(p("shape", 3), p("length", 100))),
        ("SOPtoCHOP", None),
        ("TOPtoCHOP", None),
        ("DATtoCHOP", None),
        ("FeedbackCHOP", None),
        ("WarpCHOP", p("speed", 1.5)),
    ])

    # Chain 16: Audio chain — AudioIn → AudioFileIn → Spectrum → Band → Dynamics
    b.add_chop_vis_chain([
        ("AudioInCHOP", None),
        ("AudioFileInCHOP", None),
        ("AudioSpectrumCHOP", None),
        ("AudioBandCHOP", p("bands", 8)),
        ("AudioDynamicsCHOP", None),
    ])

    # Chain 17: Laser + Physics
    b.add_chop_vis_chain([
        ("LaserCHOP", merge_params(p("points", 50), p("shape", 0))),
        ("PhysicsCHOP", None),
        ("NullCHOP", None),
    ])

    # Chain 18: Switch + Merge
    b.add_chop_vis_chain([
        ("NoiseCHOP", p("channels", 2)),
        ("MergeCHOP", None),
        ("SwitchCHOP", p("index", 0)),
    ])

    # Chain 19: MIDI — MidiIn + RtMidiIn + RtMidiOut
    b.add_chop_vis_chain([
        ("MidiInCHOP", None),
        ("RtMidiInCHOP", None),
        ("RtMidiOutCHOP", None),
    ])

    # Chain 20: OSC + NDI Audio
    b.add_chop_vis_chain([
        ("OscInCHOP", p("port", 7000)),
        ("NDIAudioInCHOP", None),
        ("NDIAudioOutCHOP", None),
    ])

    # Chain 21: Host I/O + ML detection
    b.add_chop_vis_chain([
        ("HostInCHOP", None),
        ("HostOutCHOP", None),
    ])

    # Chain 22: ML — DepthHand + DepthSkeleton + FaceDetect + HandDetect + PoseDetect
    b.add_chop_vis_chain([
        ("DepthHandCHOP", None),
        ("DepthSkeletonCHOP", None),
        ("FaceDetectCHOP", None),
        ("HandDetectCHOP", None),
        ("PoseDetectCHOP", None),
    ])

    data = b.finalize()
    write_patch("chop", "ALL_CORE_CHOPs", data)


# ═══════════════════════════════════════════════════════════════════════════════
# SOP — 76 operators
# ═══════════════════════════════════════════════════════════════════════════════

def build_sop_patch():
    b = PatchBuilder("SOPs")

    # Chain 1: Primitives — Box, Sphere, Grid, Torus, Cylinder, Circle, Line, Tube
    b.add_sop_vis_chain([
        ("BoxSOP", merge_params(p("size_x", 0.5), p("size_y", 0.5), p("size_z", 0.5))),
        ("TransformSOP", merge_params(p("tx", 0.0), p("ry", 30.0), p("scale", 1.2))),
        ("NullSOP", None),
    ])

    # Chain 2: More primitives
    b.add_sop_vis_chain([
        ("SphereSOP", merge_params(p("radius", 0.5), p("rows", 24), p("columns", 24))),
        ("NoiseSOP", merge_params(p("amplitude", 0.1), p("frequency", 3.0))),
        ("SmoothSOP", p("iterations", 2)),
    ])

    # Chain 3: Grid → Mountain → Subdivide → PolyReduce
    b.add_sop_vis_chain([
        ("GridSOP", merge_params(p("rows", 20), p("columns", 20))),
        ("MountainSOP", merge_params(p("amplitude", 0.3), p("frequency", 4.0))),
        ("SubdivideSOP", p("iterations", 1)),
        ("PolyReduceSOP", p("target_percentage", 50.0)),
    ])

    # Chain 4: Deformers — Cylinder → Bend → Twist → Taper
    b.add_sop_vis_chain([
        ("CylinderSOP", merge_params(p("rows", 16), p("height", 2.0))),
        ("BendSOP", merge_params(p("angle", 45.0), p("axis", 2))),
        ("TwistSOP", merge_params(p("angle", 90.0), p("axis", 1))),
        ("TaperSOP", merge_params(p("amount", 0.5), p("axis", 1))),
    ])

    # Chain 5: Topology — Grid → Extrude → PolyBevel → Facet → Normal
    b.add_sop_vis_chain([
        ("GridSOP", merge_params(p("rows", 5), p("columns", 5))),
        ("ExtrudeSOP", p("distance", 0.3)),
        ("PolyBevelSOP", merge_params(p("offset", 0.05), p("segments", 2))),
        ("FacetSOP", p("mode", 0)),
        ("NormalSOP", None),
    ])

    # Chain 6: Scatter + Peak + Sort + Reverse + Delete + Clip
    b.add_sop_vis_chain([
        ("GridSOP", p("rows", 10)),
        ("ScatterSOP", p("count", 200)),
        ("SortSOP", p("mode", 0)),
        ("DeleteSOP", merge_params(p("mode", 0), p("start", 0), p("end", 50))),
        ("NullSOP", None),
    ])

    # Chain 7: Boolean + Merge + Copy + Mirror + Fuse
    b.add_sop_vis_chain([
        ("BoxSOP", p("size_x", 0.8)),
        ("BooleanSOP", None),
        ("MirrorSOP", merge_params(p("axis", 0), p("distance", 0.5))),
        ("FuseSOP", p("tolerance", 0.01)),
        ("CopySOP", p("copies", 3)),
        ("MergeSOP", None),
    ])

    # Chain 8: Curves — Circle → Sweep → Skin → Cap
    b.add_sop_vis_chain([
        ("CircleSOP", merge_params(p("radius", 0.5), p("divisions", 16))),
        ("SweepSOP", None),
        ("SkinSOP", None),
        ("CapSOP", None),
    ])

    # Chain 9: Carve + Magnet + Lattice + Spring + Ray
    b.add_sop_vis_chain([
        ("TorusSOP", merge_params(p("radius_major", 0.5), p("radius_minor", 0.2))),
        ("CarveSOP", merge_params(p("u_start", 0.0), p("u_end", 0.7))),
        ("MagnetSOP", merge_params(p("strength", 0.3), p("radius", 0.5))),
        ("SpringSOP", None),
        ("RaySOP", None),
    ])

    # Chain 10: Point + Attribute + Primitive + Group + Select + ObjectMerge
    b.add_sop_vis_chain([
        ("BoxSOP", None),
        ("PointSOP", None),
        ("AttributeSOP", None),
        ("PrimitiveSOP", None),
        ("GroupSOP", None),
        ("SelectSOP", None),
        ("ObjectMergeSOP", None),
    ])

    # Chain 11: LSystem
    b.add_sop_vis_chain([
        ("LSystemSOP", merge_params(p("axiom", "F"), p("rule0", "F=F[+F]F[-F]F"), p("generations", 3))),
        ("NullSOP", None),
    ])

    # Chain 12: Font + Divide + UVProject + Remesh
    b.add_sop_vis_chain([
        ("FontSOP", merge_params(p("text", "GONODES"), p("size", 0.5))),
        ("DivideSOP", p("max_sides", 3)),
        ("UVProjectSOP", p("mode", 0)),
        ("RemeshSOP", p("target_edge_length", 0.05)),
    ])

    # Chain 13: Blend + Switch + Wireframe
    b.add_sop_vis_chain([
        ("GridSOP", None),
        ("BlendSOP", p("mix", 0.5)),
        ("SwitchSOP", p("index", 0)),
        ("WireframeSOP", p("width", 0.02)),
    ])

    # Chain 14: Peak + Clip + Reverse
    b.add_sop_vis_chain([
        ("GridSOP", merge_params(p("rows", 10), p("columns", 10))),
        ("PeakSOP", p("distance", 0.2)),
        ("ClipSOP", merge_params(p("distance", 0.1), p("axis", 1))),
        ("ReverseSOP", None),
    ])

    # Chain 15: Trail + TrailRibbon + Line
    b.add_sop_vis_chain([
        ("LineSOP", merge_params(p("length", 2.0), p("points", 20))),
        ("TrailSOP", None),
        ("TrailRibbonSOP", None),
    ])

    # Chain 16: Metaball + IsoSurface
    b.add_sop_vis_chain([
        ("MetaballSOP", p("num_balls", 3)),
        ("IsoSurfaceSOP", None),
    ])

    # Chain 17: Poly ops — PolyLoft + PolySpline + PolyPatch + PolyStitch + PolyBridge
    b.add_sop_vis_chain([
        ("TubeSOP", merge_params(p("rows", 8), p("columns", 16))),
        ("PolyLoftSOP", None),
        ("PolySplineSOP", None),
        ("PolyPatchSOP", None),
        ("PolyStitchSOP", None),
        ("PolyBridgeSOP", None),
        ("LatticeSOP", p("divisions_x", 3)),
    ])

    # Chain 18: Cloth + VoronoiShatter + Particle
    b.add_sop_vis_chain([
        ("SphereSOP", p("radius", 0.4)),
        ("ClothSOP", None),
        ("VoronoiShatterSOP", p("num_points", 10)),
        ("ParticleSOP", None),
    ])

    # Chain 19: HeightField + Texture
    b.add_sop_vis_chain([
        ("HeightfieldSOP", merge_params(p("resolution", 64), p("amplitude", 0.5))),
        ("TextureSOP", None),
    ])

    # Chain 20: File I/O
    b.add_sop_vis_chain([
        ("BoxSOP", None),
        ("FileOutSOP", merge_params(p("file_path", ""), p("active", False))),
        ("FileInSOP", None),
    ])

    # Chain 21: Bridges — CHOPtoSOP + DATtoSOP + TOPtoSOP + DepthPointCloud
    b.add_sop_vis_chain([
        ("CHOPtoSOP", None),
        ("TOPtoSOP", None),
        ("DATtoSOP", None),
        ("DepthPointCloudSOP", None),
    ])

    # Chain 22: Host I/O
    b.add_sop_vis_chain([
        ("HostInSOP", None),
        ("HostOutSOP", None),
    ])

    data = b.finalize()
    write_patch("sop", "ALL_CORE_SOPs", data)


# ═══════════════════════════════════════════════════════════════════════════════
# DAT — 48 operators
# ═══════════════════════════════════════════════════════════════════════════════

def build_dat_patch():
    b = PatchBuilder("DATs")

    # Chain 1: Generators — Table → Sort → Transpose → Select
    b.add_dat_vis_chain([
        ("TableDAT", None),
        ("SortDAT", merge_params(p("column", 0), p("order", 0))),
        ("TransposeDAT", None),
        ("SelectDAT", p("rows", "0-2")),
    ])

    # Chain 2: Constant → Merge → Insert → Delete → Substitute
    b.add_dat_vis_chain([
        ("ConstantDAT", None),
        ("MergeDAT", None),
        ("InsertDAT", merge_params(p("row", 0), p("value", "inserted"))),
        ("DeleteDAT", merge_params(p("mode", 0), p("row", 1))),
        ("SubstituteDAT", merge_params(p("find", "inserted"), p("replace", "REPLACED"))),
    ])

    # Chain 3: Text → Evaluate → FIFO → Null → Switch
    b.add_dat_vis_chain([
        ("TextDAT", p("text", "Hello GONODES!\nLine 2\nLine 3")),
        ("EvaluateDAT", None),
        ("FIFODAT", p("max_rows", 100)),
        ("NullDAT", None),
        ("SwitchDAT", p("index", 0)),
    ])

    # Chain 4: JSON + XML
    b.add_dat_vis_chain([
        ("JSONDAT", p("json_string", '{"name":"test","value":42}')),
        ("XMLDAT", p("xml_string", "<root><item>Test</item></root>")),
        ("NullDAT", None),
    ])

    # Chain 5: File + Folder + OPFind + Info
    b.add_dat_vis_chain([
        ("FileInDAT", None),
        ("FolderDAT", p("path", "res://addons/gonodes/")),
        ("OPFindDAT", None),
        ("InfoDAT", None),
    ])

    # Chain 6: Error + Callback + PanelExecute + RenderPick
    b.add_dat_vis_chain([
        ("ErrorDAT", None),
        ("CallbackDAT", None),
        ("PanelExecuteDAT", None),
        ("RenderPickDAT", None),
    ])

    # Chain 7: Network — OSC + MQTT + Network + WebSocket + WebServer + Web
    b.add_dat_vis_chain([
        ("OscInDAT", p("port", 7000)),
        ("MqttDAT", None),
        ("NetworkDAT", None),
        ("WebSocketDAT", None),
        ("WebServerDAT", None),
        ("WebDAT", None),
    ])

    # Chain 8: Serial I/O
    b.add_dat_vis_chain([
        ("SerialDAT", None),
        ("SerialReceiveDAT", None),
        ("SerialSendDAT", None),
    ])

    # Chain 9: Bridges — CHOPDAT + SOPtoDAT + TOPtoDAT + DATtoCHOP
    b.add_dat_vis_chain([
        ("CHOPDAT", None),
        ("SOPtoDAT", None),
        ("TOPtoDAT", None),
        ("DATtoCHOP", None),
    ])

    # Chain 10: Cue + DMX + MIDI + MultiTouch
    b.add_dat_vis_chain([
        ("CueDAT", None),
        ("DMXDAT", None),
        ("MidiInDAT", None),
        ("MultiTouchInDAT", None),
    ])

    # Chain 11: ML/CV — ArucoPose + CameraCalib + QRCode + ObjectDetect + DepthSensor
    b.add_dat_vis_chain([
        ("ArucoPoseDAT", None),
        ("CameraCalibDAT", None),
        ("QRCodeDAT", None),
        ("ObjectDetectDAT", None),
        ("DepthSensorDAT", None),
    ])

    # Chain 12: Extension DATs — Blackmagic
    b.add_dat_vis_chain([
        ("BlackmagicDAT", None),
        ("NullDAT", None),
    ])

    # Chain 13: Host I/O
    b.add_dat_vis_chain([
        ("HostInDAT", None),
        ("HostOutDAT", None),
    ])

    data = b.finalize()
    write_patch("dat", "ALL_CORE_DATs", data)


# ═══════════════════════════════════════════════════════════════════════════════
# IMG — 34 operators
# ═══════════════════════════════════════════════════════════════════════════════

def build_img_patch():
    b = PatchBuilder("IMGs")

    # Chain 1: Generators — Noise → Blur → EdgeDetect → Threshold → Morph
    b.add_img_vis_chain([
        ("NoiseIMG", pv2i("resolution", 256, 256)),
        ("BlurIMG", p("radius", 3)),
        ("EdgeDetectIMG", None),
        ("ThresholdIMG", p("threshold", 128)),
        ("MorphIMG", None),
    ])

    # Chain 2: Checkerboard → PixelSort → Histogram → Convolve → Contour
    b.add_img_vis_chain([
        ("CheckerboardIMG", merge_params(pv2i("resolution", 256, 256), p("size", 32))),
        ("PixelSortIMG", p("threshold", 0.3)),
        ("HistogramIMG", None),
        ("ConvolveIMG", None),
        ("ContourIMG", None),
    ])

    # Chain 3: Image I/O — ImageFileIn + ImageSequence + TOPtoIMG
    b.add_img_vis_chain([
        ("ImageFileInIMG", None),
        ("ImageSequenceIMG", None),
        ("TOPtoIMG", None),
    ])

    # Chain 4: Stereogram + Stereoscopy — Noise → Stereogram + StereoDepth
    b.add_img_vis_chain([
        ("NoiseIMG", pv2i("resolution", 128, 128)),
        ("StereogramIMG", None),
        ("StereoDepthIMG", None),
    ])

    # Chain 5: Null + Select + Switch
    b.add_img_vis_chain([
        ("NoiseIMG", pv2i("resolution", 256, 256)),
        ("NullIMG", None),
        ("SelectIMG", None),
        ("SwitchIMG", p("index", 0)),
    ])

    # Chain 6: ScreenGrab + DrawOverlay + PerspectiveWarp
    b.add_img_vis_chain([
        ("ScreenGrabIMG", None),
        ("DrawOverlayIMG", None),
        ("PerspectiveWarpIMG", None),
    ])

    # Chain 7: Webcam + VideoDeviceIn + CameraUndistort + BackgroundSubtract
    b.add_img_vis_chain([
        ("WebcamIMG", None),
        ("VideoDeviceInIMG", None),
        ("CameraUndistortIMG", None),
        ("BackgroundSubtractIMG", None),
    ])

    # Chain 8: CV Detection — ColorTrack + BlobTrack + ObjectTrack + OpticalFlow + HoughLines + HoughCircles
    b.add_img_vis_chain([
        ("NoiseIMG", pv2i("resolution", 256, 256)),
        ("ColorTrackIMG", None),
        ("BlobTrackIMG", None),
        ("ObjectTrackIMG", None),
        ("OpticalFlowIMG", None),
    ])

    # Chain 9: Feature detection
    b.add_img_vis_chain([
        ("NoiseIMG", pv2i("resolution", 256, 256)),
        ("HoughLinesIMG", None),
        ("HoughCirclesIMG", None),
        ("FeatureMatchIMG", None),
        ("ArucoDetectIMG", None),
    ])

    data = b.finalize()
    write_patch("img", "ALL_CORE_IMGs", data)


# ═══════════════════════════════════════════════════════════════════════════════
# MAT — 12 operators
# ═══════════════════════════════════════════════════════════════════════════════

def build_mat_patch():
    b = PatchBuilder("MATs")

    # For MATs, each chain: SOP → GeoCOMP(+MAT on port 1) + CameraCOMP → RenderTOP
    families = [
        ("PbrMAT", merge_params(p("roughness", 0.5), p("metallic", 0.3),
                                pcolor("albedo_color", 0.8, 0.2, 0.2))),
        ("ConstantMAT", pcolor("color", 0.2, 0.8, 0.2)),
        ("WireframeMAT", merge_params(pcolor("color", 1.0, 1.0, 0.0), p("width", 2.0))),
        ("PointSpriteMAT", merge_params(p("point_size", 5.0), pcolor("color", 0.0, 0.5, 1.0))),
        ("DepthMAT", merge_params(p("near", 0.1), p("far", 10.0))),
        ("NormalMapMAT", None),
        ("LineMAT", merge_params(pcolor("color", 1.0, 0.5, 0.0), p("width", 3.0))),
        ("ShaderMAT", None),
        ("FluidSurfaceMAT", merge_params(pcolor("deep_color", 0.0, 0.1, 0.3),
                                          p("roughness", 0.05))),
        ("NullMAT", None),
        ("SelectMAT", None),
        ("SwitchMAT", p("index", 0)),
    ]

    for mat_cls, mat_params in families:
        b.chain_idx += 1
        chain_y = b.chain_idx * ROW_H

        # Source SOP
        sop_id = b._uid("box")
        b.add_node(sop_id, "SphereSOP", CHAIN_START_X, chain_y,
                   merge_params(p("radius", 0.5), p("rows", 24), p("columns", 24)))

        # Material
        mat_id = b._uid("mat")
        b.add_node(mat_id, mat_cls, CHAIN_START_X + COL_W, chain_y + 100, mat_params)

        # GeoCOMP
        geo_id = b._uid("geo")
        b.add_node(geo_id, "GeometryCOMP", CHAIN_START_X + COL_W, chain_y)
        b.connect(sop_id, 0, geo_id, 0)
        b.connect(mat_id, 0, geo_id, 1)

        # Camera
        cam_id = b._uid("cam")
        b.add_node(cam_id, "CameraCOMP", CHAIN_START_X + 2 * COL_W, chain_y + 100)

        # Render
        render_id = b._uid("render")
        b.add_node(render_id, "RenderTOP", CHAIN_START_X + 2 * COL_W, chain_y)
        b.connect(geo_id, 0, render_id, 0)
        b.connect(cam_id, 0, render_id, 1)

        # OUTChain
        out_id = f"OUTChain{b.chain_idx}"
        b.add_node(out_id, "NullTOP", SWITCH_X + 200, chain_y)
        b.connect(render_id, 0, out_id, 0)

    data = b.finalize()
    write_patch("mat", "ALL_CORE_MATs", data)


# ═══════════════════════════════════════════════════════════════════════════════
# UI — 33 operators in ~5 chains
# ═══════════════════════════════════════════════════════════════════════════════

def build_ui_patch():
    b = PatchBuilder("UIs")

    # For UIs: widgets → containers → PanelTOP → NullTOP
    # Chain 1: Core controls — Button, Slider, Toggle, Knob, XYPad, Dropdown
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    widgets = [
        ("ButtonUI", "btn", p("label", "Test Button")),
        ("SliderUI", "slider", merge_params(p("label", "Slider"), p("min", 0.0), p("max", 100.0))),
        ("ToggleUI", "toggle", p("label", "Toggle")),
        ("KnobUI", "knob", merge_params(p("label", "Knob"), p("min", 0.0), p("max", 1.0))),
        ("XYPadUI", "xypad", p("label", "XY Pad")),
        ("DropdownUI", "dropdown", p("label", "Dropdown")),
    ]
    container = b._uid("container")
    b.add_node(container, "ContainerUI", CHAIN_START_X + len(widgets) * COL_W, chain_y)
    for i, (cls, prefix, params) in enumerate(widgets):
        nid = b._uid(prefix)
        b.add_node(nid, cls, CHAIN_START_X + i * COL_W, chain_y, params)
        b.connect(nid, 0, container, i)
    panel = b._uid("paneltop")
    b.add_node(panel, "PanelTOP", CHAIN_START_X + (len(widgets) + 1) * COL_W, chain_y)
    b.connect(container, 0, panel, 0)
    out_id = f"OUTChain{b.chain_idx}"
    b.add_node(out_id, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(panel, 0, out_id, 0)

    # Chain 2: Text inputs — Label, LineEdit, TextEdit, RichTextLabel, SpinBox
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    widgets2 = [
        ("LabelUI", "label", p("text", "Hello GONODES")),
        ("LineEditUI", "lineedit", p("placeholder", "Type here...")),
        ("TextEditUI", "textedit", None),
        ("RichTextLabelUI", "rtlabel", p("bbcode_text", "[b]Bold[/b] [i]Italic[/i]")),
        ("SpinBoxUI", "spinbox", merge_params(p("min", 0.0), p("max", 100.0), p("value", 50.0))),
    ]
    container2 = b._uid("container")
    b.add_node(container2, "ScrollContainerUI", CHAIN_START_X + len(widgets2) * COL_W, chain_y)
    for i, (cls, prefix, params) in enumerate(widgets2):
        nid = b._uid(prefix)
        b.add_node(nid, cls, CHAIN_START_X + i * COL_W, chain_y, params)
        b.connect(nid, 0, container2, i)
    panel2 = b._uid("paneltop")
    b.add_node(panel2, "PanelTOP", CHAIN_START_X + (len(widgets2) + 1) * COL_W, chain_y)
    b.connect(container2, 0, panel2, 0)
    out_id2 = f"OUTChain{b.chain_idx}"
    b.add_node(out_id2, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(panel2, 0, out_id2, 0)

    # Chain 3: Pickers & Indicators — ColorPicker, ProgressBar, CheckBox, TextureProgressBar
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    widgets3 = [
        ("ColorPickerUI", "colorpicker", None),
        ("ProgressBarUI", "progressbar", p("value", 65.0)),
        ("CheckBoxUI", "checkbox", p("label", "Check me")),
        ("TextureProgressBarUI", "texprogress", p("value", 50.0)),
    ]
    container3 = b._uid("container")
    b.add_node(container3, "MarginContainerUI", CHAIN_START_X + len(widgets3) * COL_W, chain_y)
    for i, (cls, prefix, params) in enumerate(widgets3):
        nid = b._uid(prefix)
        b.add_node(nid, cls, CHAIN_START_X + i * COL_W, chain_y, params)
        b.connect(nid, 0, container3, i)
    panel3 = b._uid("paneltop")
    b.add_node(panel3, "PanelTOP", CHAIN_START_X + (len(widgets3) + 1) * COL_W, chain_y)
    b.connect(container3, 0, panel3, 0)
    out_id3 = f"OUTChain{b.chain_idx}"
    b.add_node(out_id3, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(panel3, 0, out_id3, 0)

    # Chain 4: Containers & Navigation — Tab, Split, PanelContainer, Scroll, Margin
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    widgets4 = [
        ("TabContainerUI", "tabcontainer", None),
        ("SplitContainerUI", "splitcontainer", None),
        ("PanelContainerUI", "panelcontainer", None),
        ("TabBarUI", "tabbar", None),
        ("MenuButtonUI", "menubutton", p("text", "Menu")),
    ]
    container4 = b._uid("container")
    b.add_node(container4, "ContainerUI", CHAIN_START_X + len(widgets4) * COL_W, chain_y)
    for i, (cls, prefix, params) in enumerate(widgets4):
        nid = b._uid(prefix)
        b.add_node(nid, cls, CHAIN_START_X + i * COL_W, chain_y, params)
        b.connect(nid, 0, container4, i)
    panel4 = b._uid("paneltop")
    b.add_node(panel4, "PanelTOP", CHAIN_START_X + (len(widgets4) + 1) * COL_W, chain_y)
    b.connect(container4, 0, panel4, 0)
    out_id4 = f"OUTChain{b.chain_idx}"
    b.add_node(out_id4, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(panel4, 0, out_id4, 0)

    # Chain 5: Lists, Trees, Buttons, Misc — Tree, ItemList, TextureRect, ColorRect, etc.
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    widgets5 = [
        ("TreeUI", "tree", None),
        ("ItemListUI", "itemlist", None),
        ("TextureRectUI", "texrect", None),
        ("ColorRectUI", "colorrect", pcolor("color", 0.3, 0.6, 0.9)),
        ("NinePatchRectUI", "ninepatch", None),
        ("SeparatorUI", "separator", None),
        ("LinkButtonUI", "linkbtn", p("text", "Click Me")),
        ("TextureButtonUI", "texbtn", None),
    ]
    container5 = b._uid("container")
    b.add_node(container5, "ContainerUI", CHAIN_START_X + len(widgets5) * COL_W, chain_y)
    for i, (cls, prefix, params) in enumerate(widgets5):
        nid = b._uid(prefix)
        b.add_node(nid, cls, CHAIN_START_X + i * COL_W, chain_y, params)
        b.connect(nid, 0, container5, i)
    panel5 = b._uid("paneltop")
    b.add_node(panel5, "PanelTOP", CHAIN_START_X + (len(widgets5) + 1) * COL_W, chain_y)
    b.connect(container5, 0, panel5, 0)
    out_id5 = f"OUTChain{b.chain_idx}"
    b.add_node(out_id5, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(panel5, 0, out_id5, 0)

    # Chain 6: Null + Switch
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    null_ui = b._uid("nullui")
    b.add_node(null_ui, "NullUI", CHAIN_START_X, chain_y)
    switch_ui = b._uid("switchui")
    b.add_node(switch_ui, "SwitchUI", CHAIN_START_X + COL_W, chain_y, p("index", 0))
    b.connect(null_ui, 0, switch_ui, 0)
    panel6 = b._uid("paneltop")
    b.add_node(panel6, "PanelTOP", CHAIN_START_X + 2 * COL_W, chain_y)
    b.connect(switch_ui, 0, panel6, 0)
    out_id6 = f"OUTChain{b.chain_idx}"
    b.add_node(out_id6, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(panel6, 0, out_id6, 0)

    # Chain 7: Drag controls — BezierDrag + CornerDrag + GridDrag
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    widgets7 = [
        ("BezierDragUI", "bezierdrag", None),
        ("CornerDragUI", "cornerdrag", None),
        ("GridDragUI", "griddrag", None),
    ]
    container7 = b._uid("container")
    b.add_node(container7, "ContainerUI", CHAIN_START_X + len(widgets7) * COL_W, chain_y)
    for i, (cls, prefix, params) in enumerate(widgets7):
        nid = b._uid(prefix)
        b.add_node(nid, cls, CHAIN_START_X + i * COL_W, chain_y, params)
        b.connect(nid, 0, container7, i)
    panel7 = b._uid("paneltop")
    b.add_node(panel7, "PanelTOP", CHAIN_START_X + (len(widgets7) + 1) * COL_W, chain_y)
    b.connect(container7, 0, panel7, 0)
    out_id7 = f"OUTChain{b.chain_idx}"
    b.add_node(out_id7, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(panel7, 0, out_id7, 0)

    data = b.finalize()
    write_patch("ui", "ALL_CORE_UIs", data)


# ═══════════════════════════════════════════════════════════════════════════════
# POP — 13 operators
# ═══════════════════════════════════════════════════════════════════════════════

def build_pop_patch():
    b = PatchBuilder("POPs")

    # Chain 1: Source → Force → Turbulence → Limit → CollisionPOP → PointCloudRender
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    src = b._uid("source")
    b.add_node(src, "SourcePOP", CHAIN_START_X, chain_y,
               merge_params(p("emit_rate", 500), p("lifetime", 3.0)))
    force_id = b._uid("force")
    b.add_node(force_id, "ForcePOP", CHAIN_START_X + COL_W, chain_y,
               merge_params(p("gravity_y", -9.81), p("strength", 1.0)))
    b.connect(src, 0, force_id, 0)
    turb = b._uid("turbulence")
    b.add_node(turb, "TurbulencePOP", CHAIN_START_X + 2 * COL_W, chain_y,
               merge_params(p("amplitude", 2.0), p("frequency", 1.5)))
    b.connect(force_id, 0, turb, 0)
    limit = b._uid("limit")
    b.add_node(limit, "LimitPOP", CHAIN_START_X + 3 * COL_W, chain_y,
               p("max_particles", 5000))
    b.connect(turb, 0, limit, 0)
    coll = b._uid("collision")
    b.add_node(coll, "CollisionPOP", CHAIN_START_X + 4 * COL_W, chain_y,
               p("floor_y", -1.0))
    b.connect(limit, 0, coll, 0)
    pcr = b._uid("pointcloud")
    b.add_node(pcr, "PointCloudRenderTOP", CHAIN_START_X + 5 * COL_W, chain_y)
    b.connect(coll, 0, pcr, 0)
    out1 = f"OUTChain{b.chain_idx}"
    b.add_node(out1, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(pcr, 0, out1, 0)

    # Chain 2: Source → Attract → Boids → PointCloudRender
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    src2 = b._uid("source")
    b.add_node(src2, "SourcePOP", CHAIN_START_X, chain_y,
               merge_params(p("emit_rate", 300), p("lifetime", 5.0)))
    attract = b._uid("attract")
    b.add_node(attract, "AttractPOP", CHAIN_START_X + COL_W, chain_y,
               merge_params(p("strength", 3.0), p("radius", 2.0)))
    b.connect(src2, 0, attract, 0)
    boids = b._uid("boids")
    b.add_node(boids, "BoidsPOP", CHAIN_START_X + 2 * COL_W, chain_y,
               merge_params(p("separation", 0.5), p("alignment", 1.0), p("cohesion", 0.8)))
    b.connect(attract, 0, boids, 0)
    pcr2 = b._uid("pointcloud")
    b.add_node(pcr2, "PointCloudRenderTOP", CHAIN_START_X + 3 * COL_W, chain_y)
    b.connect(boids, 0, pcr2, 0)
    out2 = f"OUTChain{b.chain_idx}"
    b.add_node(out2, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(pcr2, 0, out2, 0)

    # Chain 3: Source → AdvectPOP, Null, Select, Switch, Instance, Render
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    src3 = b._uid("source")
    b.add_node(src3, "SourcePOP", CHAIN_START_X, chain_y, p("emit_rate", 200))
    advect = b._uid("advect")
    b.add_node(advect, "AdvectPOP", CHAIN_START_X + COL_W, chain_y)
    b.connect(src3, 0, advect, 0)
    null_pop = b._uid("null")
    b.add_node(null_pop, "NullPOP", CHAIN_START_X + 2 * COL_W, chain_y)
    b.connect(advect, 0, null_pop, 0)
    sel_pop = b._uid("select")
    b.add_node(sel_pop, "SelectPOP", CHAIN_START_X + 3 * COL_W, chain_y)
    b.connect(null_pop, 0, sel_pop, 0)
    sw_pop = b._uid("switch")
    b.add_node(sw_pop, "SwitchPOP", CHAIN_START_X + 4 * COL_W, chain_y, p("index", 0))
    b.connect(sel_pop, 0, sw_pop, 0)
    pcr3 = b._uid("pointcloud")
    b.add_node(pcr3, "PointCloudRenderTOP", CHAIN_START_X + 5 * COL_W, chain_y)
    b.connect(sw_pop, 0, pcr3, 0)
    # ParticleState bridge
    pst = b._uid("particlestate")
    b.add_node(pst, "ParticleStateTOP", CHAIN_START_X + 5 * COL_W, chain_y + 100)
    b.connect(sw_pop, 0, pst, 0)
    out3 = f"OUTChain{b.chain_idx}"
    b.add_node(out3, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(pcr3, 0, out3, 0)

    # Chain 4: InstancePOP + RenderPOP + Host I/O
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    src4 = b._uid("source")
    b.add_node(src4, "SourcePOP", CHAIN_START_X, chain_y, p("emit_rate", 100))
    inst_pop = b._uid("instance")
    b.add_node(inst_pop, "InstancePOP", CHAIN_START_X + COL_W, chain_y)
    b.connect(src4, 0, inst_pop, 0)
    rend_pop = b._uid("render")
    b.add_node(rend_pop, "RenderPOP", CHAIN_START_X + 2 * COL_W, chain_y)
    b.connect(inst_pop, 0, rend_pop, 0)
    pcr4 = b._uid("pointcloud")
    b.add_node(pcr4, "PointCloudRenderTOP", CHAIN_START_X + 3 * COL_W, chain_y)
    b.connect(rend_pop, 0, pcr4, 0)
    out4 = f"OUTChain{b.chain_idx}"
    b.add_node(out4, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(pcr4, 0, out4, 0)

    # Chain 5: Host I/O
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    host_in_pop = b._uid("hostin")
    b.add_node(host_in_pop, "HostInPOP", CHAIN_START_X, chain_y)
    host_out_pop = b._uid("hostout")
    b.add_node(host_out_pop, "HostOutPOP", CHAIN_START_X + COL_W, chain_y)
    b.connect(host_in_pop, 0, host_out_pop, 0)
    pcr5 = b._uid("pointcloud")
    b.add_node(pcr5, "PointCloudRenderTOP", CHAIN_START_X + 2 * COL_W, chain_y)
    b.connect(host_in_pop, 0, pcr5, 0)
    out5 = f"OUTChain{b.chain_idx}"
    b.add_node(out5, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(pcr5, 0, out5, 0)

    data = b.finalize()
    write_patch("pop", "ALL_CORE_POPs", data)


# ═══════════════════════════════════════════════════════════════════════════════
# VOL — 15 operators
# ═══════════════════════════════════════════════════════════════════════════════

def build_vol_patch():
    b = PatchBuilder("VOLs")

    # Chain 1: NoiseVOL → BlurVOL → AnalyzeVOL → RaymarchVOL → SnapshotTOP
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    noise_vol = b._uid("noise")
    b.add_node(noise_vol, "NoiseVOL", CHAIN_START_X, chain_y,
               merge_params(p("resolution", 64), p("frequency", 3.0)))
    blur_vol = b._uid("blur")
    b.add_node(blur_vol, "BlurVOL", CHAIN_START_X + COL_W, chain_y, p("iterations", 2))
    b.connect(noise_vol, 0, blur_vol, 0)
    analyze_vol = b._uid("analyze")
    b.add_node(analyze_vol, "AnalyzeVOL", CHAIN_START_X + 2 * COL_W, chain_y)
    b.connect(blur_vol, 0, analyze_vol, 0)
    raymarch = b._uid("raymarch")
    b.add_node(raymarch, "RaymarchVOL", CHAIN_START_X + 3 * COL_W, chain_y)
    b.connect(analyze_vol, 0, raymarch, 0)
    snap = b._uid("snapshot")
    b.add_node(snap, "SnapshotTOP", CHAIN_START_X + 4 * COL_W, chain_y)
    b.connect(raymarch, 0, snap, 0)
    out1 = f"OUTChain{b.chain_idx}"
    b.add_node(out1, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(snap, 0, out1, 0)

    # Chain 2: NoiseVOL → DisplaceVOL → BlendVOL → MarchingCubes → render
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    noise2 = b._uid("noise")
    b.add_node(noise2, "NoiseVOL", CHAIN_START_X, chain_y, p("resolution", 32))
    displace = b._uid("displace")
    b.add_node(displace, "DisplaceVOL", CHAIN_START_X + COL_W, chain_y,
               p("amplitude", 0.2))
    b.connect(noise2, 0, displace, 0)
    blend = b._uid("blend")
    b.add_node(blend, "BlendVOL", CHAIN_START_X + 2 * COL_W, chain_y, p("mix", 0.5))
    b.connect(displace, 0, blend, 0)
    mc = b._uid("marchingcubes")
    b.add_node(mc, "MarchingCubesVOL", CHAIN_START_X + 3 * COL_W, chain_y,
               p("threshold", 0.3))
    b.connect(blend, 0, mc, 0)
    # MarchingCubes outputs SOP → render via GeoCOMP
    geo = b._uid("geo")
    b.add_node(geo, "GeometryCOMP", CHAIN_START_X + 4 * COL_W, chain_y)
    b.connect(mc, 0, geo, 0)
    cam = b._uid("cam")
    b.add_node(cam, "CameraCOMP", CHAIN_START_X + 4 * COL_W, chain_y + 100)
    render = b._uid("render")
    b.add_node(render, "RenderTOP", CHAIN_START_X + 5 * COL_W, chain_y)
    b.connect(geo, 0, render, 0)
    b.connect(cam, 0, render, 1)
    out2 = f"OUTChain{b.chain_idx}"
    b.add_node(out2, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(render, 0, out2, 0)

    # Chain 3: FluidVOL → PyroVOL → Raymarch
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    fluid = b._uid("fluid")
    b.add_node(fluid, "FluidVOL", CHAIN_START_X, chain_y, p("resolution", 32))
    pyro = b._uid("pyro")
    b.add_node(pyro, "PyroVOL", CHAIN_START_X + COL_W, chain_y)
    b.connect(fluid, 0, pyro, 0)
    raymarch2 = b._uid("raymarch")
    b.add_node(raymarch2, "RaymarchVOL", CHAIN_START_X + 2 * COL_W, chain_y)
    b.connect(pyro, 0, raymarch2, 0)
    snap2 = b._uid("snapshot")
    b.add_node(snap2, "SnapshotTOP", CHAIN_START_X + 3 * COL_W, chain_y)
    b.connect(raymarch2, 0, snap2, 0)
    out3 = f"OUTChain{b.chain_idx}"
    b.add_node(out3, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(snap2, 0, out3, 0)

    # Chain 4: SOPtoVOL + CHOPtoVOL + GPUMarchingCubes
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    soptovol = b._uid("soptovol")
    b.add_node(soptovol, "SOPtoVOL", CHAIN_START_X, chain_y, p("resolution", 32))
    # Feed a sphere as source
    sphere = b._uid("sphere")
    b.add_node(sphere, "SphereSOP", CHAIN_START_X - COL_W, chain_y, p("radius", 0.4))
    b.connect(sphere, 0, soptovol, 0)
    choptovol = b._uid("choptovol")
    b.add_node(choptovol, "CHOPtoVOL", CHAIN_START_X + COL_W, chain_y)
    b.connect(soptovol, 0, choptovol, 0)
    gpumc = b._uid("gpumc")
    b.add_node(gpumc, "GPUMarchingCubesVOL", CHAIN_START_X + 2 * COL_W, chain_y)
    b.connect(choptovol, 0, gpumc, 0)
    geo2 = b._uid("geo")
    b.add_node(geo2, "GeometryCOMP", CHAIN_START_X + 2 * COL_W, chain_y)
    b.connect(gpumc, 0, geo2, 0)
    cam2 = b._uid("cam")
    b.add_node(cam2, "CameraCOMP", CHAIN_START_X + 2 * COL_W, chain_y + 100)
    render2 = b._uid("render")
    b.add_node(render2, "RenderTOP", CHAIN_START_X + 3 * COL_W, chain_y)
    b.connect(geo2, 0, render2, 0)
    b.connect(cam2, 0, render2, 1)
    out4 = f"OUTChain{b.chain_idx}"
    b.add_node(out4, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(render2, 0, out4, 0)

    # Chain 5: Null + Select + Switch
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    noise3 = b._uid("noise")
    b.add_node(noise3, "NoiseVOL", CHAIN_START_X, chain_y, p("resolution", 16))
    null_vol = b._uid("null")
    b.add_node(null_vol, "NullVOL", CHAIN_START_X + COL_W, chain_y)
    b.connect(noise3, 0, null_vol, 0)
    sel_vol = b._uid("select")
    b.add_node(sel_vol, "SelectVOL", CHAIN_START_X + 2 * COL_W, chain_y)
    b.connect(null_vol, 0, sel_vol, 0)
    sw_vol = b._uid("switch")
    b.add_node(sw_vol, "SwitchVOL", CHAIN_START_X + 3 * COL_W, chain_y, p("index", 0))
    b.connect(sel_vol, 0, sw_vol, 0)
    ray3 = b._uid("raymarch")
    b.add_node(ray3, "RaymarchVOL", CHAIN_START_X + 4 * COL_W, chain_y)
    b.connect(sw_vol, 0, ray3, 0)
    snap3 = b._uid("snapshot")
    b.add_node(snap3, "SnapshotTOP", CHAIN_START_X + 5 * COL_W, chain_y)
    b.connect(ray3, 0, snap3, 0)
    out5 = f"OUTChain{b.chain_idx}"
    b.add_node(out5, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(snap3, 0, out5, 0)

    # Chain 6: Host I/O
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    hostin_vol = b._uid("hostin")
    b.add_node(hostin_vol, "HostInVOL", CHAIN_START_X, chain_y)
    hostout_vol = b._uid("hostout")
    b.add_node(hostout_vol, "HostOutVOL", CHAIN_START_X + COL_W, chain_y)
    b.connect(hostin_vol, 0, hostout_vol, 0)
    ray4 = b._uid("raymarch")
    b.add_node(ray4, "RaymarchVOL", CHAIN_START_X + 2 * COL_W, chain_y)
    b.connect(hostin_vol, 0, ray4, 0)
    snap4 = b._uid("snapshot")
    b.add_node(snap4, "SnapshotTOP", CHAIN_START_X + 3 * COL_W, chain_y)
    b.connect(ray4, 0, snap4, 0)
    out6 = f"OUTChain{b.chain_idx}"
    b.add_node(out6, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(snap4, 0, out6, 0)

    data = b.finalize()
    write_patch("vol", "ALL_CORE_VOLs", data)


# ═══════════════════════════════════════════════════════════════════════════════
# OUT — 10 operators
# ═══════════════════════════════════════════════════════════════════════════════

def build_out_patch():
    b = PatchBuilder("OUTs")

    # Chain 1: Noise → WindowOUT (already exists but include for completeness)
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    noise = b._uid("noise")
    b.add_node(noise, "NoiseTOP", CHAIN_START_X, chain_y)
    sink = b._uid("sink")
    b.add_node(sink, "SinkOUT", CHAIN_START_X + COL_W, chain_y)
    b.connect(noise, 0, sink, 0)
    out1 = f"OUTChain{b.chain_idx}"
    b.add_node(out1, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(noise, 0, out1, 0)

    # Chain 2: Image save chain
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    noise2 = b._uid("noise")
    b.add_node(noise2, "NoiseTOP", CHAIN_START_X, chain_y)
    img_save = b._uid("imgsave")
    b.add_node(img_save, "ImageSaveOUT", CHAIN_START_X + COL_W, chain_y,
               merge_params(p("file_path", ""), p("active", False)))
    b.connect(noise2, 0, img_save, 0)
    tex_save = b._uid("texsave")
    b.add_node(tex_save, "TextureSaveOUT", CHAIN_START_X + 2 * COL_W, chain_y,
               merge_params(p("file_path", ""), p("active", False)))
    b.connect(noise2, 0, tex_save, 0)
    out2 = f"OUTChain{b.chain_idx}"
    b.add_node(out2, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(noise2, 0, out2, 0)

    # Chain 3: Movie/FFmpeg/Record OUTs
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    noise3 = b._uid("noise")
    b.add_node(noise3, "NoiseTOP", CHAIN_START_X, chain_y)
    movie = b._uid("movieout")
    b.add_node(movie, "MovieOUT", CHAIN_START_X + COL_W, chain_y,
               merge_params(p("file_path", ""), p("active", False)))
    b.connect(noise3, 0, movie, 0)
    ffmpeg_out = b._uid("ffmpegout")
    b.add_node(ffmpeg_out, "FFmpegOUT", CHAIN_START_X + 2 * COL_W, chain_y,
               merge_params(p("file_path", ""), p("active", False)))
    b.connect(noise3, 0, ffmpeg_out, 0)
    record = b._uid("record")
    b.add_node(record, "RecordOUT", CHAIN_START_X + 3 * COL_W, chain_y,
               merge_params(p("file_path", ""), p("active", False)))
    b.connect(noise3, 0, record, 0)
    out3 = f"OUTChain{b.chain_idx}"
    b.add_node(out3, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(noise3, 0, out3, 0)

    # Chain 4: Network OUTs — OSC, Audio, TableSave
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    wave = b._uid("wave")
    b.add_node(wave, "WaveCHOP", CHAIN_START_X, chain_y,
               merge_params(p("shape", 0), p("length", 100)))
    c2t = b._uid("choptotop")
    b.add_node(c2t, "CHOPtoTOP", CHAIN_START_X + COL_W, chain_y)
    b.connect(wave, 0, c2t, 0)
    osc_out = b._uid("oscout")
    b.add_node(osc_out, "OscOUT", CHAIN_START_X + COL_W, chain_y + 100,
               merge_params(p("address", "/test"), p("host", "127.0.0.1"), p("port", 9000),
                            p("active", False)))
    b.connect(wave, 0, osc_out, 0)
    audio = b._uid("audiodevice")
    b.add_node(audio, "AudioDeviceOUT", CHAIN_START_X + 2 * COL_W, chain_y + 100,
               p("active", False))
    b.connect(wave, 0, audio, 0)
    table_save = b._uid("tablesave")
    b.add_node(table_save, "TableSaveOUT", CHAIN_START_X + 3 * COL_W, chain_y + 100,
               merge_params(p("file_path", ""), p("active", False)))
    out4 = f"OUTChain{b.chain_idx}"
    b.add_node(out4, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(c2t, 0, out4, 0)

    # Chain 5: Hap + Movie/FFmpeg recording (extension)
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    noise4 = b._uid("noise")
    b.add_node(noise4, "NoiseTOP", CHAIN_START_X, chain_y)
    hap_out = b._uid("hapout")
    b.add_node(hap_out, "HapOUT", CHAIN_START_X + COL_W, chain_y,
               merge_params(p("file_path", ""), p("active", False)))
    b.connect(noise4, 0, hap_out, 0)
    out5 = f"OUTChain{b.chain_idx}"
    b.add_node(out5, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(noise4, 0, out5, 0)

    # Chain 6: Host OUT operators — HostOutTOP + HostOutCHOP + HostOutDAT + HostOutSOP + HostOutPOP + HostOutVOL
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    noise5 = b._uid("noise")
    b.add_node(noise5, "NoiseTOP", CHAIN_START_X, chain_y)
    host_top = b._uid("hostouttop")
    b.add_node(host_top, "HostOutTOP", CHAIN_START_X + COL_W, chain_y)
    b.connect(noise5, 0, host_top, 0)
    host_chop = b._uid("hostoutchop")
    b.add_node(host_chop, "HostOutCHOP", CHAIN_START_X + 2 * COL_W, chain_y)
    host_dat = b._uid("hostoutdat")
    b.add_node(host_dat, "HostOutDAT", CHAIN_START_X + 3 * COL_W, chain_y)
    host_sop = b._uid("hostoutsop")
    b.add_node(host_sop, "HostOutSOP", CHAIN_START_X + 4 * COL_W, chain_y)
    host_pop = b._uid("hostoutpop")
    b.add_node(host_pop, "HostOutPOP", CHAIN_START_X + 5 * COL_W, chain_y)
    host_vol = b._uid("hostoutvol")
    b.add_node(host_vol, "HostOutVOL", CHAIN_START_X + 6 * COL_W, chain_y)
    out6 = f"OUTChain{b.chain_idx}"
    b.add_node(out6, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(noise5, 0, out6, 0)

    data = b.finalize()
    write_patch("output", "ALL_CORE_OUTs", data)


# ═══════════════════════════════════════════════════════════════════════════════
# SDF — 29 operators (extension)
# ═══════════════════════════════════════════════════════════════════════════════

def build_sdf_patch():
    b = PatchBuilder("SDFs")

    # Chain 1: Primitives — Box + Sphere → Union → Raymarch
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    box = b._uid("box")
    b.add_node(box, "BoxSDF", CHAIN_START_X, chain_y,
               merge_params(p("size_x", 0.3), p("size_y", 0.3), p("size_z", 0.3)))
    sphere = b._uid("sphere")
    b.add_node(sphere, "SphereSDF", CHAIN_START_X, chain_y + 120, p("radius", 0.4))
    union = b._uid("union")
    b.add_node(union, "UnionSDF", CHAIN_START_X + COL_W, chain_y)
    b.connect(box, 0, union, 0)
    b.connect(sphere, 0, union, 1)
    ray = b._uid("raymarch")
    b.add_node(ray, "RaymarchSDF", CHAIN_START_X + 2 * COL_W, chain_y)
    b.connect(union, 0, ray, 0)
    out1 = f"OUTChain{b.chain_idx}"
    b.add_node(out1, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(ray, 0, out1, 0)

    # Chain 2: Torus → SmoothUnion with Capsule → Round → Raymarch
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    torus = b._uid("torus")
    b.add_node(torus, "TorusSDF", CHAIN_START_X, chain_y,
               merge_params(p("radius_major", 0.4), p("radius_minor", 0.1)))
    capsule = b._uid("capsule")
    b.add_node(capsule, "CapsuleSDF", CHAIN_START_X, chain_y + 120,
               merge_params(p("height", 0.6), p("radius", 0.15)))
    smooth_union = b._uid("smoothunion")
    b.add_node(smooth_union, "SmoothUnionSDF", CHAIN_START_X + COL_W, chain_y,
               p("smoothness", 0.1))
    b.connect(torus, 0, smooth_union, 0)
    b.connect(capsule, 0, smooth_union, 1)
    round_sdf = b._uid("round")
    b.add_node(round_sdf, "RoundSDF", CHAIN_START_X + 2 * COL_W, chain_y, p("radius", 0.02))
    b.connect(smooth_union, 0, round_sdf, 0)
    ray2 = b._uid("raymarch")
    b.add_node(ray2, "RaymarchSDF", CHAIN_START_X + 3 * COL_W, chain_y)
    b.connect(round_sdf, 0, ray2, 0)
    out2 = f"OUTChain{b.chain_idx}"
    b.add_node(out2, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(ray2, 0, out2, 0)

    # Chain 3: Cone + Cylinder → Subtract → SmoothSubtract
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    cone = b._uid("cone")
    b.add_node(cone, "ConeSDF", CHAIN_START_X, chain_y,
               merge_params(p("height", 0.6), p("radius", 0.3)))
    cyl = b._uid("cylinder")
    b.add_node(cyl, "CylinderSDF", CHAIN_START_X, chain_y + 120,
               merge_params(p("height", 0.8), p("radius", 0.15)))
    subtract = b._uid("subtract")
    b.add_node(subtract, "SubtractSDF", CHAIN_START_X + COL_W, chain_y)
    b.connect(cone, 0, subtract, 0)
    b.connect(cyl, 0, subtract, 1)
    smooth_sub = b._uid("smoothsubtract")
    b.add_node(smooth_sub, "SmoothSubtractSDF", CHAIN_START_X + 2 * COL_W, chain_y,
               p("smoothness", 0.1))
    b.connect(subtract, 0, smooth_sub, 0)
    ray3 = b._uid("raymarch")
    b.add_node(ray3, "RaymarchSDF", CHAIN_START_X + 3 * COL_W, chain_y)
    b.connect(smooth_sub, 0, ray3, 0)
    out3 = f"OUTChain{b.chain_idx}"
    b.add_node(out3, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(ray3, 0, out3, 0)

    # Chain 4: Octahedron → Intersection with Plane → Onion → Elongate
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    octa = b._uid("octahedron")
    b.add_node(octa, "OctahedronSDF", CHAIN_START_X, chain_y, p("size", 0.5))
    plane = b._uid("plane")
    b.add_node(plane, "PlaneSDF", CHAIN_START_X, chain_y + 120)
    intersect = b._uid("intersection")
    b.add_node(intersect, "IntersectionSDF", CHAIN_START_X + COL_W, chain_y)
    b.connect(octa, 0, intersect, 0)
    b.connect(plane, 0, intersect, 1)
    onion = b._uid("onion")
    b.add_node(onion, "OnionSDF", CHAIN_START_X + 2 * COL_W, chain_y, p("thickness", 0.03))
    b.connect(intersect, 0, onion, 0)
    elongate = b._uid("elongate")
    b.add_node(elongate, "ElongateSDF", CHAIN_START_X + 3 * COL_W, chain_y,
               merge_params(p("x", 0.2), p("y", 0.0), p("z", 0.0)))
    b.connect(onion, 0, elongate, 0)
    ray4 = b._uid("raymarch")
    b.add_node(ray4, "RaymarchSDF", CHAIN_START_X + 4 * COL_W, chain_y)
    b.connect(elongate, 0, ray4, 0)
    out4 = f"OUTChain{b.chain_idx}"
    b.add_node(out4, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(ray4, 0, out4, 0)

    # Chain 5: Pyramid → Bend → Twist → Mirror → Repeat
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    pyramid = b._uid("pyramid")
    b.add_node(pyramid, "PyramidSDF", CHAIN_START_X, chain_y, p("height", 0.5))
    bend = b._uid("bend")
    b.add_node(bend, "BendSDF", CHAIN_START_X + COL_W, chain_y, p("amount", 0.5))
    b.connect(pyramid, 0, bend, 0)
    twist = b._uid("twist")
    b.add_node(twist, "TwistSDF", CHAIN_START_X + 2 * COL_W, chain_y, p("amount", 2.0))
    b.connect(bend, 0, twist, 0)
    mirror = b._uid("mirror")
    b.add_node(mirror, "MirrorSDF", CHAIN_START_X + 3 * COL_W, chain_y)
    b.connect(twist, 0, mirror, 0)
    repeat = b._uid("repeat")
    b.add_node(repeat, "RepeatSDF", CHAIN_START_X + 4 * COL_W, chain_y,
               merge_params(p("period_x", 2.0), p("period_y", 2.0), p("period_z", 2.0)))
    b.connect(mirror, 0, repeat, 0)
    ray5 = b._uid("raymarch")
    b.add_node(ray5, "RaymarchSDF", CHAIN_START_X + 5 * COL_W, chain_y)
    b.connect(repeat, 0, ray5, 0)
    out5 = f"OUTChain{b.chain_idx}"
    b.add_node(out5, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(ray5, 0, out5, 0)

    # Chain 6: Gyroid + Displace + Material + Gradient
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    gyroid = b._uid("gyroid")
    b.add_node(gyroid, "GyroidSDF", CHAIN_START_X, chain_y, p("scale", 3.0))
    displace = b._uid("displace")
    b.add_node(displace, "DisplaceSDF", CHAIN_START_X + COL_W, chain_y, p("amplitude", 0.1))
    b.connect(gyroid, 0, displace, 0)
    material = b._uid("material")
    b.add_node(material, "MaterialSDF", CHAIN_START_X + 2 * COL_W, chain_y,
               pcolor("color", 0.8, 0.3, 0.1))
    b.connect(displace, 0, material, 0)
    gradient = b._uid("gradient")
    b.add_node(gradient, "GradientSDF", CHAIN_START_X + 3 * COL_W, chain_y)
    b.connect(material, 0, gradient, 0)
    ray6 = b._uid("raymarch")
    b.add_node(ray6, "RaymarchSDF", CHAIN_START_X + 4 * COL_W, chain_y)
    b.connect(gradient, 0, ray6, 0)
    out6 = f"OUTChain{b.chain_idx}"
    b.add_node(out6, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(ray6, 0, out6, 0)

    # Chain 7: Null + Select + Switch
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    sphere2 = b._uid("sphere")
    b.add_node(sphere2, "SphereSDF", CHAIN_START_X, chain_y, p("radius", 0.3))
    null_sdf = b._uid("null")
    b.add_node(null_sdf, "NullSDF", CHAIN_START_X + COL_W, chain_y)
    b.connect(sphere2, 0, null_sdf, 0)
    sel_sdf = b._uid("select")
    b.add_node(sel_sdf, "SelectSDF", CHAIN_START_X + 2 * COL_W, chain_y)
    b.connect(null_sdf, 0, sel_sdf, 0)
    sw_sdf = b._uid("switch")
    b.add_node(sw_sdf, "SwitchSDF", CHAIN_START_X + 3 * COL_W, chain_y, p("index", 0))
    b.connect(sel_sdf, 0, sw_sdf, 0)
    ray7 = b._uid("raymarch")
    b.add_node(ray7, "RaymarchSDF", CHAIN_START_X + 4 * COL_W, chain_y)
    b.connect(sw_sdf, 0, ray7, 0)
    out7 = f"OUTChain{b.chain_idx}"
    b.add_node(out7, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(ray7, 0, out7, 0)

    # SDF goes to separate extension test dir
    d = os.path.join(os.path.dirname(__file__), "..", "addons", "gn_ext_sdf", "tests", "manual")
    os.makedirs(d, exist_ok=True)
    fp = os.path.join(d, "ALL_CORE_SDFs.gnpatch")
    data = b.finalize()
    with open(fp, "w", encoding="utf-8", newline="") as f:
        json.dump(data, f, indent="\t")
    print(f"  Wrote {fp} ({len(data['nodes'])} nodes, {len(data['connections'])} connections)")


# ═══════════════════════════════════════════════════════════════════════════════
# TOP — 143 operators  (all TOP-family operators in comprehensive chains)
# ═══════════════════════════════════════════════════════════════════════════════

def build_top_patch():
    b = PatchBuilder("TOPs")

    # Chain 1: Blur family — Noise → Blur → BilateralBlur → BokehBlur → DirectionalBlur
    #          → LumaBlur → RadialBlur → MedianBlur → HighPass → Sharpen
    b.add_chain([
        ("NoiseTOP", None),
        ("BlurTOP", p("size", 5.0)),
        ("BilateralBlurTOP", None),
        ("BokehBlurTOP", None),
        ("DirectionalBlurTOP", p("angle", 45.0)),
        ("LumaBlurTOP", None),
        ("RadialBlurTOP", None),
        ("MedianTOP", None),
        ("HighPassTOP", None),
        ("SharpenTOP", p("amount", 1.5)),
    ])

    # Chain 2: Distortion — Noise → Displace → Deform → LensDistort → Spherize → Twirl
    #          → GridWarp → CornerPin → BezierMap → Polar
    b.add_chain([
        ("NoiseTOP", None),
        ("DisplaceTOP", None),
        ("DeformTOP", None),
        ("LensDistortTOP", None),
        ("SpherizeTOP", None),
        ("TwirlTOP", None),
        ("GridWarpTOP", None),
        ("CornerPinTOP", None),
        ("BezierMapTOP", None),
        ("PolarTOP", None),
    ])

    # Chain 3: Color grading — Noise → HSVAdjust → Level → ColorBalance → ColorMap
    #          → ColorSpace → GradientMap → LUTTOP → Mono → Posterize → Dither
    b.add_chain([
        ("NoiseTOP", None),
        ("HSVAdjustTOP", merge_params(p("hue_offset", 30.0), p("saturation", 1.2))),
        ("LevelTOP", None),
        ("ColorBalanceTOP", None),
        ("ColorMapTOP", None),
        ("ColorSpaceTOP", None),
        ("GradientMapTOP", None),
        ("LUTTOP", None),
        ("MonoTOP", None),
        ("PosterizeTOP", p("levels", 8)),
        ("DitherTOP", None),
    ])

    # Chain 4: Compositing — Noise + Constant → Composite → Cross → KeyMix → Matte
    #          → Premultiply → ChannelMix → ZComposite → Glue → Reorder
    b.add_chain([
        ("NoiseTOP", None),
        ("CompositeTOP", p("operation", 0)),
        ("CrossTOP", p("cross", 0.5)),
        ("KeyMixTOP", None),
        ("MatteTOP", None),
        ("PremultiplyTOP", None),
        ("ChannelMixTOP", None),
        ("ZCompositeTOP", None),
        ("GlueTOP", None),
        ("ReorderTOP", None),
    ])

    # Chain 5: Layout + Transform — Noise → Transform → Crop → Fit → Flip → Mirror
    #          → Tile → Layout → Resolution → Limit
    b.add_chain([
        ("NoiseTOP", None),
        ("TransformTOP", merge_params(p("tx", 0.1), p("rotate", 15.0))),
        ("CropTOP", None),
        ("FitTOP", None),
        ("FlipTOP", None),
        ("MirrorTOP", None),
        ("TileTOP", None),
        ("LayoutTOP", None),
        ("ResolutionTOP", pv2i("resolution", 512, 512)),
        ("LimitTOP", None),
    ])

    # Chain 6: Effects — Noise → Bloom → ChromaticAberration → FilmGrain → Glitch
    #          → GodRays → Halftone → LensFlare → Vignette → ASCIIArt
    b.add_chain([
        ("NoiseTOP", None),
        ("BloomTOP", p("threshold", 0.5)),
        ("ChromaticAberrationTOP", None),
        ("FilmGrainTOP", None),
        ("GlitchTOP", None),
        ("GodRaysTOP", None),
        ("HalftoneTOP", None),
        ("LensFlareTOP", None),
        ("VignetteTOP", None),
        ("ASCIIArtTOP", None),
    ])

    # Chain 7: Edge + Emboss + ConvCustom — Noise → Edge → AntiAlias → Emboss → Convolution
    #          → DilateErode → Threshold → ChromaKey → ScanLine
    b.add_chain([
        ("NoiseTOP", None),
        ("EdgeTOP", None),
        ("AntiAliasTOP", None),
        ("EmbossTOP", None),
        ("ConvolutionTOP", None),
        ("DilateErodeTOP", None),
        ("ThresholdTOP", None),
        ("ChromaKeyTOP", None),
        ("ScanLineTOP", None),
    ])

    # Chain 8: Generators — Pattern + Ramp + Constant + Circle + Rectangle + Triangle
    #          + TestCard + CurlNoise + CubeMap + Palette + Voronoi
    b.add_chain([
        ("PatternTOP", p("type", 2)),
        ("RampTOP", None),
        ("ConstantTOP", pcolor("color", 0.5, 0.3, 0.8)),
        ("CircleTOP", None),
        ("RectangleTOP", None),
        ("TriangleTOP", None),
        ("TestCardTOP", None),
        ("CurlNoiseTOP", None),
        ("CubeMapTOP", None),
        ("PaletteTOP", None),
        ("VoronoiTOP", None),
    ])

    # Chain 9: Simulation — ReactionDiffusion → Fluid2D → CellularAutomata → MotionBlur
    #          → FrameDifference → OpticalFlow → FlowVis → TimeMachine → Ripple
    b.add_chain([
        ("ReactionDiffusionTOP", None),
        ("Fluid2DTOP", None),
        ("CellularAutomataTOP", None),
        ("MotionBlurTOP", None),
        ("FrameDifferenceTOP", None),
        ("OpticalFlowTOP", None),
        ("FlowVisTOP", None),
        ("TimeMachineTOP", None),
        ("RippleTOP", None),
    ])

    # Chain 10: Filter + Remap + Lookup + Analyze + Slope + Depth
    b.add_chain([
        ("NoiseTOP", None),
        ("FilterTOP", None),
        ("RemapTOP", None),
        ("LookupTOP", None),
        ("AnalyzeTOP", None),
        ("SlopeTOP", None),
        ("DepthTOP", None),
        ("DepthOfFieldTOP", None),
        ("NormalMapTOP", None),
    ])

    # Chain 11: Stylization — Kuwahara → ToonShade → Pixelate → Stoner → Kaleidoscope → StyleTransfer
    b.add_chain([
        ("NoiseTOP", None),
        ("KuwaharaTOP", None),
        ("ToonShadeTOP", None),
        ("PixelateTOP", None),
        ("StonerTOP", None),
        ("KaleidoscopeTOP", None),
        ("StyleTransferTOP", None),
    ])

    # Chain 12: Projection + Masking — ProjectionTOP + ProjectionMask + ProjectorBlend
    #          + QuadMap + EdgeBlend
    b.add_chain([
        ("NoiseTOP", None),
        ("ProjectionTOP", None),
        ("ProjectionMaskTOP", None),
        ("ProjectorBlendTOP", None),
        ("QuadMapTOP", None),
        ("EdgeBlendTOP", None),
    ])

    # Chain 13: 3D Rendering — RenderTOP + GeometryBuffer + MultiBufferRender + CompositorEffect + DepthEstimate
    b.add_chain([
        ("NoiseTOP", None),
        ("RenderTOP", None),
        ("GeometryBufferTOP", None),
        ("MultiBufferRenderTOP", None),
        ("CompositorEffectTOP", None),
        ("DepthEstimateTOP", None),
        ("SegmentationTOP", None),
    ])

    # Chain 14: Shader — CustomShader + GLSL + ComputeShader + ISF + Shadertoy
    b.add_chain([
        ("NoiseTOP", None),
        ("CustomShaderTOP", None),
        ("GLSLMultiTOP", None),
        ("ComputeShaderTOP", None),
        ("ISFTOP", None),
        ("ShadertoyTOP", None),
    ])

    # Chain 15: I/O sources — MovieFileIn + FFmpegIn + Feedback + Cache + Snapshot + Text + SVG + VectorPath
    b.add_chain([
        ("MovieFileInTOP", None),
        ("FFmpegInTOP", None),
        ("FeedbackTOP", None),
        ("CacheTOP", None),
        ("SnapshotTOP", None),
        ("TextTOP", p("text", "GONODES")),
        ("SVGTOP", None),
        ("VectorPathTOP", None),
    ])

    # Chain 16: Trail + Select + Null + Switch
    b.add_chain([
        ("NoiseTOP", None),
        ("TrailTOP", None),
        ("SelectTOP", None),
        ("NullTOP", None),
        ("SwitchTOP", p("index", 0)),
    ])

    # Chain 17: External I/O — NDI + Spout + Syphon + Blackmagic + Hap + WebRender
    b.add_chain([
        ("NDIInTOP", None),
        ("NDIOutTOP", None),
        ("SpoutInTOP", None),
        ("SpoutOutTOP", None),
        ("SyphonInTOP", None),
        ("SyphonOutTOP", None),
        ("BlackmagicInTOP", None),
        ("BlackmagicOutTOP", None),
        ("HapInTOP", None),
        ("WebRenderTOP", None),
    ])

    # Chain 18: Movie/File output
    b.add_chain([
        ("NoiseTOP", None),
        ("MovieFileOutTOP", merge_params(p("file_path", ""), p("active", False))),
    ])

    # Chain 19: Bridges — CHOPtoTOP + PanelTOP + PointCloudRender + ParticleState
    b.add_chain([
        ("CHOPtoTOP", None),
        ("PanelTOP", None),
        ("PointCloudRenderTOP", None),
        ("ParticleStateTOP", None),
    ])

    # Chain 20: Sensor + Host — DepthSensor + HostIn + HostOut
    b.add_chain([
        ("DepthSensorTOP", None),
        ("HostInTOP", None),
        ("HostOutTOP", None),
    ])

    data = b.finalize()
    write_patch("top", "ALL_CORE_TOPs", data)


# ═══════════════════════════════════════════════════════════════════════════════
# COMP — 26 operators
# ═══════════════════════════════════════════════════════════════════════════════

def build_comp_patch():
    b = PatchBuilder("COMPs")

    # Chain 1: Scene COMPs — GeometryCOMP + Camera + Light + Environment → RenderTOP
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    box = b._uid("box")
    b.add_node(box, "BoxSOP", CHAIN_START_X, chain_y)
    geo = b._uid("geo")
    b.add_node(geo, "GeometryCOMP", CHAIN_START_X + COL_W, chain_y)
    b.connect(box, 0, geo, 0)
    cam = b._uid("cam")
    b.add_node(cam, "CameraCOMP", CHAIN_START_X + COL_W, chain_y + 100)
    light = b._uid("light")
    b.add_node(light, "LightCOMP", CHAIN_START_X + COL_W, chain_y + 200)
    env = b._uid("env")
    b.add_node(env, "EnvironmentCOMP", CHAIN_START_X + COL_W, chain_y + 300)
    render = b._uid("render")
    b.add_node(render, "RenderTOP", CHAIN_START_X + 2 * COL_W, chain_y)
    b.connect(geo, 0, render, 0)
    b.connect(cam, 0, render, 1)
    out1 = f"OUTChain{b.chain_idx}"
    b.add_node(out1, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(render, 0, out1, 0)

    # Chain 2: Instance + LOD + Area + Merge + Select + Switch + Null
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    box2 = b._uid("box")
    b.add_node(box2, "BoxSOP", CHAIN_START_X, chain_y)
    instance = b._uid("instance")
    b.add_node(instance, "InstanceCOMP", CHAIN_START_X + COL_W, chain_y)
    b.connect(box2, 0, instance, 0)
    lod = b._uid("lod")
    b.add_node(lod, "LODCOMP", CHAIN_START_X + 2 * COL_W, chain_y)
    b.connect(instance, 0, lod, 0)
    area = b._uid("area")
    b.add_node(area, "AreaCOMP", CHAIN_START_X + 3 * COL_W, chain_y)
    b.connect(lod, 0, area, 0)
    merge_comp = b._uid("merge")
    b.add_node(merge_comp, "MergeCOMP", CHAIN_START_X + 4 * COL_W, chain_y)
    b.connect(area, 0, merge_comp, 0)
    sel_comp = b._uid("select")
    b.add_node(sel_comp, "SelectCOMP", CHAIN_START_X + 5 * COL_W, chain_y)
    b.connect(merge_comp, 0, sel_comp, 0)
    sw_comp = b._uid("switch")
    b.add_node(sw_comp, "SwitchCOMP", CHAIN_START_X + 6 * COL_W, chain_y, p("index", 0))
    b.connect(sel_comp, 0, sw_comp, 0)
    null_comp = b._uid("null")
    b.add_node(null_comp, "NullCOMP", CHAIN_START_X + 7 * COL_W, chain_y)
    b.connect(sw_comp, 0, null_comp, 0)
    cam2 = b._uid("cam")
    b.add_node(cam2, "CameraCOMP", CHAIN_START_X + 7 * COL_W, chain_y + 100)
    render2 = b._uid("render")
    b.add_node(render2, "RenderTOP", CHAIN_START_X + 8 * COL_W, chain_y)
    b.connect(null_comp, 0, render2, 0)
    b.connect(cam2, 0, render2, 1)
    out2 = f"OUTChain{b.chain_idx}"
    b.add_node(out2, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(render2, 0, out2, 0)

    # Chain 3: Physics — RigidBody + StaticBody + SoftBody + Joint + Constraint + Vehicle
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    sphere = b._uid("sphere")
    b.add_node(sphere, "SphereSOP", CHAIN_START_X, chain_y)
    rigid = b._uid("rigid")
    b.add_node(rigid, "RigidBodyCOMP", CHAIN_START_X + COL_W, chain_y)
    b.connect(sphere, 0, rigid, 0)
    static = b._uid("static")
    b.add_node(static, "StaticBodyCOMP", CHAIN_START_X + 2 * COL_W, chain_y)
    soft = b._uid("soft")
    b.add_node(soft, "SoftBodyCOMP", CHAIN_START_X + 3 * COL_W, chain_y)
    joint = b._uid("joint")
    b.add_node(joint, "JointCOMP", CHAIN_START_X + 4 * COL_W, chain_y)
    constraint = b._uid("constraint")
    b.add_node(constraint, "ConstraintCOMP", CHAIN_START_X + 5 * COL_W, chain_y)
    vehicle = b._uid("vehicle")
    b.add_node(vehicle, "VehicleCOMP", CHAIN_START_X + 6 * COL_W, chain_y)
    cam3 = b._uid("cam")
    b.add_node(cam3, "CameraCOMP", CHAIN_START_X + 7 * COL_W, chain_y + 100)
    render3 = b._uid("render")
    b.add_node(render3, "RenderTOP", CHAIN_START_X + 7 * COL_W, chain_y)
    b.connect(rigid, 0, render3, 0)
    b.connect(cam3, 0, render3, 1)
    out3 = f"OUTChain{b.chain_idx}"
    b.add_node(out3, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(render3, 0, out3, 0)

    # Chain 4: Animation + Bone + Replicator + Navigation + Path
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    anim = b._uid("animation")
    b.add_node(anim, "AnimationCOMP", CHAIN_START_X, chain_y)
    bone = b._uid("bone")
    b.add_node(bone, "BoneCOMP", CHAIN_START_X + COL_W, chain_y)
    replicator = b._uid("replicator")
    b.add_node(replicator, "ReplicatorCOMP", CHAIN_START_X + 2 * COL_W, chain_y)
    nav = b._uid("nav")
    b.add_node(nav, "NavigationCOMP", CHAIN_START_X + 3 * COL_W, chain_y)
    path = b._uid("path")
    b.add_node(path, "PathCOMP", CHAIN_START_X + 4 * COL_W, chain_y)
    cam4 = b._uid("cam")
    b.add_node(cam4, "CameraCOMP", CHAIN_START_X + 5 * COL_W, chain_y + 100)
    render4 = b._uid("render")
    b.add_node(render4, "RenderTOP", CHAIN_START_X + 5 * COL_W, chain_y)
    b.connect(anim, 0, render4, 0)
    b.connect(cam4, 0, render4, 1)
    out4 = f"OUTChain{b.chain_idx}"
    b.add_node(out4, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(render4, 0, out4, 0)

    # Chain 5: SubNetworkNode + InTunnel + OutTunnel + EnginesCOMP
    b.chain_idx += 1
    chain_y = b.chain_idx * ROW_H
    subnet = b._uid("subnet")
    b.add_node(subnet, "SubNetworkNode", CHAIN_START_X, chain_y)
    intunnel = b._uid("intunnel")
    b.add_node(intunnel, "InTunnel", CHAIN_START_X + COL_W, chain_y)
    outtunnel = b._uid("outtunnel")
    b.add_node(outtunnel, "OutTunnel", CHAIN_START_X + 2 * COL_W, chain_y)
    engines = b._uid("engines")
    b.add_node(engines, "EnginesCOMP", CHAIN_START_X + 3 * COL_W, chain_y)
    noise = b._uid("noise")
    b.add_node(noise, "NoiseTOP", CHAIN_START_X + 4 * COL_W, chain_y)
    out5 = f"OUTChain{b.chain_idx}"
    b.add_node(out5, "NullTOP", SWITCH_X + 200, chain_y)
    b.connect(noise, 0, out5, 0)

    data = b.finalize()
    write_patch("comp", "ALL_CORE_COMPs", data)


# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT — 3 operators
# ═══════════════════════════════════════════════════════════════════════════════

def build_script_patch():
    b = PatchBuilder("SCRIPTs")

    # Chain 1: GDScript + Python + Native → CHOPtoTOP
    b.add_chop_vis_chain([
        ("GDScriptSCRIPT", None),
        ("PythonSCRIPT", None),
        ("NativeSCRIPT", None),
    ])

    data = b.finalize()
    write_patch("script", "ALL_CORE_SCRIPTs", data)


# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    print("Generating ALL_CORE comprehensive manual test patches...")
    build_chop_patch()
    build_sop_patch()
    build_dat_patch()
    build_img_patch()
    build_mat_patch()
    build_ui_patch()
    build_pop_patch()
    build_vol_patch()
    build_out_patch()
    build_sdf_patch()
    build_top_patch()
    build_comp_patch()
    build_script_patch()
    print("\nDone! Generated ALL_CORE patches for all families.")


if __name__ == "__main__":
    main()
