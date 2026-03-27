"""
GONODES Help Patch Definitions — CHOP Family (67 operators)
Each operator gets 3 patches: _basic, _<feature>, _<advanced>
Returns list of (filename, patch_dict) tuples per operator.
"""
from help_patch_engine import *


def get_chop_patches():
    """Return dict of node_type → list of (filename, patch_dict)."""
    patches = {}

    # ── AnalyzeCHOP ──
    patches["analyze"] = [
        ("analyze_basic", build_chop_chain("analyze1",
            node("AnalyzeCHOP", 400, 100, {"function": p(0)}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(2.0)})},
            extra_conns=[conn("lfo1", 0, "analyze1", 0)],
            annotation_text="Analyze CHOP — Basic\n\nComputes running average of an LFO signal.")),
        ("analyze_rms", build_chop_chain("analyze1",
            node("AnalyzeCHOP", 400, 100, {"function": p(2)}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"roughness": p(0.5), "amplitude": p(1.0)})},
            extra_conns=[conn("noise1", 0, "analyze1", 0)],
            annotation_text="Analyze CHOP — RMS\n\nComputes RMS of a noise signal.\nUseful for audio level detection.")),
        ("analyze_peak_hold", build_chop_chain("analyze1",
            node("AnalyzeCHOP", 400, 100, {"function": p(1)}),
            extra_nodes={
                "wave1": node("WaveCHOP", 100, 100, {"waveform": p(0), "frequency": p(3.0), "amplitude": p(1.0)}),
                "math1": node("MathCHOP", 250, 100, {"operation": p(2), "operand": p(0.5)}),
            },
            extra_conns=[conn("wave1", 0, "math1", 0), conn("math1", 0, "analyze1", 0)],
            annotation_text="Analyze CHOP — Peak\n\nTracks peak value of a scaled sine wave.\nUseful for envelope following.")),
    ]

    # ── AudioDynamicsCHOP ──
    patches["audio_dynamics"] = [
        ("audio_dynamics_basic", build_chop_chain("dyn1",
            node("AudioDynamicsCHOP", 400, 100, {"mode": p(0), "threshold": p(-12.0), "ratio": p(4.0)}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"amplitude": p(1.0)})},
            extra_conns=[conn("noise1", 0, "dyn1", 0)],
            annotation_text="Audio Dynamics — Basic Compressor\n\nApplies compression to a noise signal.")),
        ("audio_dynamics_limiter", build_chop_chain("dyn1",
            node("AudioDynamicsCHOP", 400, 100, {"mode": p(1), "threshold": p(-6.0), "ratio": p(20.0)}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0), "amplitude": p(2.0)})},
            extra_conns=[conn("lfo1", 0, "dyn1", 0)],
            annotation_text="Audio Dynamics — Limiter\n\nHard limiting on an LFO signal.\nPrevents signal from exceeding threshold.")),
        ("audio_dynamics_gate", build_chop_chain("dyn1",
            node("AudioDynamicsCHOP", 400, 100, {"mode": p(2), "threshold": p(-24.0), "attack": p(5.0), "release": p(200.0)}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"amplitude": p(0.5), "roughness": p(0.8)})},
            extra_conns=[conn("noise1", 0, "dyn1", 0)],
            annotation_text="Audio Dynamics — Gate\n\nNoise gate silences signal below threshold.\nFast attack, slow release.")),
    ]

    # ── AudioFileInCHOP ──
    patches["audiofilein"] = [
        ("audiofilein_basic", build_chop_chain("afin1",
            node("AudioFileInCHOP", 100, 100, {"play": p(True), "loop": p(True), "volume": p(0.0)}),
            annotation_text="Audio File In — Basic\n\nPlays an audio file in a loop.\nSet file path in parameters.")),
        ("audiofilein_spectrum", build_chop_chain("afin1",
            node("AudioFileInCHOP", 100, 100, {"play": p(True), "loop": p(True)}),
            extra_nodes={"spec1": node("AudioSpectrumCHOP", 400, 100, {})},
            extra_conns=[conn("afin1", 0, "spec1", 0)],
            annotation_text="Audio File In — Spectrum\n\nAudio file piped through spectrum analyzer.\nVisualizes frequency content.")),
        ("audiofilein_dynamics", build_chop_chain("afin1",
            node("AudioFileInCHOP", 100, 100, {"play": p(True), "loop": p(True), "volume": p(-6.0)}),
            extra_nodes={"dyn1": node("AudioDynamicsCHOP", 400, 100, {"threshold": p(-12.0), "ratio": p(3.0)})},
            extra_conns=[conn("afin1", 0, "dyn1", 0)],
            annotation_text="Audio File In — With Dynamics\n\nAudio file with compression applied.\nSmooths out volume peaks.")),
    ]

    # ── AudioInCHOP ──
    patches["audioin"] = [
        ("audioin_basic", build_chop_chain("ain1",
            node("AudioInCHOP", 100, 100, {}),
            annotation_text="Audio In — Basic\n\nCaptures live audio from system input device.\nVisualized as waveform.")),
        ("audioin_spectrum", build_chop_chain("ain1",
            node("AudioInCHOP", 100, 100, {}),
            extra_nodes={"spec1": node("AudioSpectrumCHOP", 400, 100, {})},
            extra_conns=[conn("ain1", 0, "spec1", 0)],
            annotation_text="Audio In — Spectrum Analysis\n\nLive audio input with real-time spectrum.")),
        ("audioin_filtered", build_chop_chain("ain1",
            node("AudioInCHOP", 100, 100, {}),
            extra_nodes={"filter1": node("FilterCHOP", 400, 100, {"filter_width": p(4.0)})},
            extra_conns=[conn("ain1", 0, "filter1", 0)],
            annotation_text="Audio In — Filtered\n\nLive audio smoothed by a filter.\nReduces high-frequency noise.")),
    ]

    # ── AudioSpectrumCHOP ──
    patches["audiospectrum"] = [
        ("audiospectrum_basic", build_chop_chain("spec1",
            node("AudioSpectrumCHOP", 400, 100, {}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"amplitude": p(1.0)})},
            extra_conns=[conn("noise1", 0, "spec1", 0)],
            annotation_text="Audio Spectrum — Basic\n\nSpectrum analysis of a noise signal.")),
        ("audiospectrum_wide", build_chop_chain("spec1",
            node("AudioSpectrumCHOP", 400, 100, {}),
            extra_nodes={"wave1": node("WaveCHOP", 100, 100, {"waveform": p(2), "frequency": p(440.0)})},
            extra_conns=[conn("wave1", 0, "spec1", 0)],
            annotation_text="Audio Spectrum — Pure Tone\n\nSpectrum of a 440 Hz square wave.\nShows fundamental + harmonics.")),
        ("audiospectrum_bands", build_chop_chain("spec1",
            node("AudioSpectrumCHOP", 400, 100, {}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(2.0)}),
                "math1": node("MathCHOP", 250, 100, {"operation": p(2), "operand": p(0.3)}),
            },
            extra_conns=[conn("lfo1", 0, "math1", 0), conn("math1", 0, "spec1", 0)],
            annotation_text="Audio Spectrum — Modulated\n\nSpectrum of an amplitude-modulated LFO.\nShows changing frequency content.")),
    ]

    # ── BeatCHOP ──
    patches["beat"] = [
        ("beat_basic", build_chop_chain("beat1",
            node("BeatCHOP", 100, 100, {"bpm": p(120.0)}),
            annotation_text="Beat CHOP — Basic\n\nGenerates beat pulses at 120 BPM.")),
        ("beat_waltz", build_chop_chain("beat1",
            node("BeatCHOP", 100, 100, {"bpm": p(90.0)}),
            annotation_text="Beat CHOP — Slow Tempo\n\n90 BPM waltz tempo beat generator.")),
        ("beat_fast", build_chop_chain("beat1",
            node("BeatCHOP", 100, 100, {"bpm": p(160.0)}),
            extra_nodes={"trigger1": node("TriggerCHOP", 400, 100, {"attack": p(0.01), "sustain": p(0.05), "release": p(0.1)})},
            extra_conns=[conn("beat1", 0, "trigger1", 0)],
            annotation_text="Beat CHOP — Triggered Envelope\n\nFast beat triggers an attack-sustain-release envelope.")),
    ]

    # ── BlendCHOP ──
    patches["blend"] = [
        ("blend_basic", build_chop_chain("blend1",
            node("BlendCHOP", 400, 100, {"blend": p(0.5)}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 50, {"frequency": p(1.0)}),
                "wave1": node("WaveCHOP", 100, 200, {"waveform": p(2), "frequency": p(3.0)}),
            },
            extra_conns=[conn("lfo1", 0, "blend1", 0), conn("wave1", 0, "blend1", 1)],
            annotation_text="Blend CHOP — Basic\n\n50/50 blend between sine LFO and square wave.")),
        ("blend_crossfade", build_chop_chain("blend1",
            node("BlendCHOP", 400, 100, {"blend": p(0.0)}),
            extra_nodes={
                "const1": node("ConstantCHOP", 100, 50, {"value0": p(1.0)}),
                "noise1": node("NoiseCHOP", 100, 200, {"amplitude": p(0.5)}),
                "lfo_blend": node("LFO_CHOP", 250, 300, {"frequency": p(0.25), "amplitude": p(0.5), "offset": p(0.5)}),
            },
            extra_conns=[
                conn("const1", 0, "blend1", 0), conn("noise1", 0, "blend1", 1),
                conn("lfo_blend", 0, "blend1", 2),
            ],
            annotation_text="Blend CHOP — Animated Crossfade\n\nLFO drives blend weight between constant and noise.\nSmooth back-and-forth crossfade.")),
        ("blend_three_way", build_chop_chain("blend1",
            node("BlendCHOP", 500, 100, {"blend": p(0.33)}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 50, {"frequency": p(1.0)}),
                "wave1": node("WaveCHOP", 100, 200, {"waveform": p(1), "frequency": p(2.0)}),
                "noise1": node("NoiseCHOP", 100, 350, {"amplitude": p(0.5)}),
            },
            extra_conns=[
                conn("lfo1", 0, "blend1", 0), conn("wave1", 0, "blend1", 1),
                conn("noise1", 0, "blend1", 2),
            ],
            annotation_text="Blend CHOP — Three Sources\n\nBlends three different waveforms together.")),
    ]

    # ── ClockCHOP ──
    patches["clock"] = [
        ("clock_basic", build_chop_chain("clock1",
            node("ClockCHOP", 100, 100, {}),
            annotation_text="Clock CHOP — Basic\n\nOutputs current time as channel values.")),
        ("clock_formatted", build_chop_chain("clock1",
            node("ClockCHOP", 100, 100, {}),
            extra_nodes={"trail1": node("TrailCHOP", 400, 100, {"length": p(60.0)})},
            extra_conns=[conn("clock1", 0, "trail1", 0)],
            annotation_text="Clock CHOP — Trailed\n\nClock output visualized over 60 seconds via Trail.")),
        ("clock_triggered", build_chop_chain("clock1",
            node("ClockCHOP", 100, 100, {}),
            extra_nodes={
                "math1": node("MathCHOP", 350, 100, {}),
                "trigger1": node("TriggerCHOP", 550, 100, {"attack": p(0.05), "release": p(0.5)}),
            },
            extra_conns=[conn("clock1", 0, "math1", 0), conn("math1", 0, "trigger1", 0)],
            annotation_text="Clock CHOP — Pulse Generator\n\nClock seconds channel triggers periodic pulses.")),
    ]

    # ── CompositeCHOP ──
    patches["composite"] = [
        ("composite_basic", build_chop_chain("comp1",
            node("CompositeCHOP", 400, 100, {}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 50, {"frequency": p(1.0)}),
                "wave1": node("WaveCHOP", 100, 200, {"waveform": p(1), "frequency": p(2.0)}),
            },
            extra_conns=[conn("lfo1", 0, "comp1", 0), conn("wave1", 0, "comp1", 1)],
            annotation_text="Composite CHOP — Basic\n\nLayers two waveforms using composite operation.")),
        ("composite_add", build_chop_chain("comp1",
            node("CompositeCHOP", 400, 100, {"operation": p(0)}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 50, {"frequency": p(1.0), "amplitude": p(0.5)}),
                "noise1": node("NoiseCHOP", 100, 200, {"amplitude": p(0.3)}),
            },
            extra_conns=[conn("lfo1", 0, "comp1", 0), conn("noise1", 0, "comp1", 1)],
            annotation_text="Composite CHOP — Add\n\nAdds LFO and noise signals together.")),
        ("composite_multiply", build_chop_chain("comp1",
            node("CompositeCHOP", 400, 100, {"operation": p(2)}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 50, {"frequency": p(0.5)}),
                "wave1": node("WaveCHOP", 100, 200, {"waveform": p(0), "frequency": p(8.0), "amplitude": p(1.0)}),
            },
            extra_conns=[conn("lfo1", 0, "comp1", 0), conn("wave1", 0, "comp1", 1)],
            annotation_text="Composite CHOP — Multiply (AM)\n\nMultiplying LFO by fast sine creates amplitude modulation.")),
    ]

    # ── ConstantCHOP ──
    patches["constant"] = [
        ("constant_basic", build_chop_chain("const1",
            node("ConstantCHOP", 100, 100, {"value0": p(0.75)}),
            annotation_text="Constant CHOP — Basic\n\nOutputs a single constant value of 0.75.")),
        ("constant_multi", build_chop_chain("const1",
            node("ConstantCHOP", 100, 100, {"value0": p(1.0), "value1": p(0.5), "value2": p(0.0)}),
            annotation_text="Constant CHOP — Multi-Channel\n\nOutputs three constant channels (1.0, 0.5, 0.0).\nUseful for RGB color values.")),
        ("constant_math", build_chop_chain("const1",
            node("ConstantCHOP", 100, 100, {"value0": p(2.0)}),
            extra_nodes={"math1": node("MathCHOP", 400, 100, {"operation": p(2), "operand": p(3.0)})},
            extra_conns=[conn("const1", 0, "math1", 0)],
            annotation_text="Constant CHOP — Math Chain\n\nConstant 2.0 multiplied by 3.0 = 6.0.\nDemonstrates math processing.")),
    ]

    # ── CopyCHOP ──
    patches["copy"] = [
        ("copy_basic", build_chop_chain("copy1",
            node("CopyCHOP", 400, 100, {}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)})},
            extra_conns=[conn("lfo1", 0, "copy1", 0)],
            annotation_text="Copy CHOP — Basic\n\nDuplicates LFO channels.")),
        ("copy_multi", build_chop_chain("copy1",
            node("CopyCHOP", 400, 100, {"copies": p(4)}),
            extra_nodes={"wave1": node("WaveCHOP", 100, 100, {"frequency": p(2.0)})},
            extra_conns=[conn("wave1", 0, "copy1", 0)],
            annotation_text="Copy CHOP — Multiple Copies\n\nCreates 4 copies of a wave signal.")),
        ("copy_offset", build_chop_chain("copy1",
            node("CopyCHOP", 400, 100, {"copies": p(3)}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(0.5)}),
                "math1": node("MathCHOP", 600, 100, {}),
            },
            extra_conns=[conn("lfo1", 0, "copy1", 0), conn("copy1", 0, "math1", 0)],
            annotation_text="Copy CHOP — Offset Copies\n\n3 copies of LFO passed through Math.\nCreates phase-offset pattern.")),
    ]

    # ── CountCHOP ──
    patches["count"] = [
        ("count_basic", build_chop_chain("count1",
            node("CountCHOP", 400, 100, {}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(2.0)})},
            extra_conns=[conn("lfo1", 0, "count1", 0)],
            annotation_text="Count CHOP — Basic\n\nCounts zero-crossings of an LFO.")),
        ("count_trigger", build_chop_chain("count1",
            node("CountCHOP", 400, 100, {}),
            extra_nodes={"trigger1": node("TriggerCHOP", 100, 100, {"attack": p(0.01), "sustain": p(0.05), "release": p(0.1)})},
            extra_conns=[conn("trigger1", 0, "count1", 0)],
            annotation_text="Count CHOP — Trigger Counter\n\nCounts trigger pulses.\nUseful for event counting.")),
        ("count_reset", build_chop_chain("count1",
            node("CountCHOP", 400, 100, {"reset": p(True)}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)}),
                "timer1": node("TimerCHOP", 100, 250, {"length": p(5.0)}),
            },
            extra_conns=[conn("lfo1", 0, "count1", 0), conn("timer1", 0, "count1", 1)],
            annotation_text="Count CHOP — With Reset\n\nCounts LFO cycles, resets every 5 seconds via timer.")),
    ]

    # ── CrossCHOP ──
    patches["cross"] = [
        ("cross_basic", build_chop_chain("cross1",
            node("CrossCHOP", 400, 100, {"cross": p(0.5)}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 50, {"frequency": p(1.0)}),
                "wave1": node("WaveCHOP", 100, 200, {"waveform": p(2), "frequency": p(3.0)}),
            },
            extra_conns=[conn("lfo1", 0, "cross1", 0), conn("wave1", 0, "cross1", 1)],
            annotation_text="Cross CHOP — Basic\n\n50% crossfade between sine and square wave.")),
        ("cross_animated", build_chop_chain("cross1",
            node("CrossCHOP", 400, 100, {}),
            extra_nodes={
                "const1": node("ConstantCHOP", 100, 50, {"value0": p(1.0)}),
                "noise1": node("NoiseCHOP", 100, 200, {"amplitude": p(1.0)}),
                "lfo_x": node("LFO_CHOP", 250, 300, {"frequency": p(0.2), "amplitude": p(0.5), "offset": p(0.5)}),
            },
            extra_conns=[
                conn("const1", 0, "cross1", 0), conn("noise1", 0, "cross1", 1),
                conn("lfo_x", 0, "cross1", 2),
            ],
            annotation_text="Cross CHOP — Animated\n\nLFO drives crossfade between constant and noise.")),
        ("cross_snap", build_chop_chain("cross1",
            node("CrossCHOP", 400, 100, {"cross": p(0.0)}),
            extra_nodes={
                "wave1": node("WaveCHOP", 100, 50, {"waveform": p(0), "frequency": p(1.0)}),
                "wave2": node("WaveCHOP", 100, 200, {"waveform": p(1), "frequency": p(5.0)}),
            },
            extra_conns=[conn("wave1", 0, "cross1", 0), conn("wave2", 0, "cross1", 1)],
            annotation_text="Cross CHOP — A/B Comparison\n\nCross at 0 = pure input A (sine).\nAdjust cross param to transition to B (triangle).")),
    ]

    # ── DelayCHOP ──
    patches["delay"] = [
        ("delay_basic", build_chop_chain("delay1",
            node("DelayCHOP", 400, 100, {"delay": p(0.5)}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)})},
            extra_conns=[conn("lfo1", 0, "delay1", 0)],
            annotation_text="Delay CHOP — Basic\n\nDelays LFO signal by 0.5 seconds.")),
        ("delay_long", build_chop_chain("delay1",
            node("DelayCHOP", 400, 100, {"delay": p(2.0)}),
            extra_nodes={"trigger1": node("TriggerCHOP", 100, 100, {"attack": p(0.01), "release": p(0.3)})},
            extra_conns=[conn("trigger1", 0, "delay1", 0)],
            annotation_text="Delay CHOP — Long Delay\n\n2-second delay on trigger pulses.\nCreates echo-like effect.")),
        ("delay_chain", build_chop_chain("delay1",
            node("DelayCHOP", 400, 100, {"delay": p(0.25)}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(2.0)}),
                "delay2": node("DelayCHOP", 600, 100, {"delay": p(0.5)}),
                "merge1": node("MergeCHOP", 800, 100, {}),
            },
            extra_conns=[
                conn("lfo1", 0, "delay1", 0),
                conn("delay1", 0, "delay2", 0),
                conn("lfo1", 0, "merge1", 0),
                conn("delay2", 0, "merge1", 1),
            ],
            annotation_text="Delay CHOP — Cascaded\n\nOriginal + double-delayed merged.\nShows progressive delay.")),
    ]

    # ── DeleteCHOP ──
    patches["delete"] = [
        ("delete_basic", build_chop_chain("del1",
            node("DeleteCHOP", 400, 100, {}),
            extra_nodes={"pattern1": node("PatternCHOP", 100, 100, {})},
            extra_conns=[conn("pattern1", 0, "del1", 0)],
            annotation_text="Delete CHOP — Basic\n\nDeletes selected channels from pattern.")),
        ("delete_range", build_chop_chain("del1",
            node("DeleteCHOP", 400, 100, {}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"channels": p(4)})},
            extra_conns=[conn("noise1", 0, "del1", 0)],
            annotation_text="Delete CHOP — Range\n\nRemoves channels from multi-channel noise.")),
        ("delete_condition", build_chop_chain("del1",
            node("DeleteCHOP", 400, 100, {}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)}),
                "merge1": node("MergeCHOP", 250, 100, {}),
                "noise1": node("NoiseCHOP", 100, 250, {"amplitude": p(0.5)}),
            },
            extra_conns=[conn("lfo1", 0, "merge1", 0), conn("noise1", 0, "merge1", 1), conn("merge1", 0, "del1", 0)],
            annotation_text="Delete CHOP — From Merged\n\nMerges LFO + noise, then deletes selected channels.")),
    ]

    # ── EnvelopeCHOP ──
    patches["envelope"] = [
        ("envelope_basic", build_chop_chain("env1",
            node("EnvelopeCHOP", 400, 100, {}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"amplitude": p(1.0), "roughness": p(0.5)})},
            extra_conns=[conn("noise1", 0, "env1", 0)],
            annotation_text="Envelope CHOP — Basic\n\nExtracts amplitude envelope from noise signal.")),
        ("envelope_audio", build_chop_chain("env1",
            node("EnvelopeCHOP", 400, 100, {}),
            extra_nodes={"wave1": node("WaveCHOP", 100, 100, {"waveform": p(0), "frequency": p(440.0), "amplitude": p(1.0)})},
            extra_conns=[conn("wave1", 0, "env1", 0)],
            annotation_text="Envelope CHOP — Audio Rate\n\nEnvelope follower on a 440 Hz tone.\nExtracts amplitude contour.")),
        ("envelope_smooth", build_chop_chain("env1",
            node("EnvelopeCHOP", 400, 100, {}),
            extra_nodes={
                "noise1": node("NoiseCHOP", 100, 100, {"amplitude": p(1.0)}),
                "lag1": node("LagCHOP", 600, 100, {"lag": p(0.2)}),
            },
            extra_conns=[conn("noise1", 0, "env1", 0), conn("env1", 0, "lag1", 0)],
            annotation_text="Envelope CHOP — Smoothed\n\nEnvelope followed by lag for extra smoothing.\nGood for reactive visuals.")),
    ]

    # ── ExpressionCHOP ──
    patches["expression"] = [
        ("expression_basic", build_chop_chain("expr1",
            node("ExpressionCHOP", 100, 100, {"expr0": p("sin(me.time * 3.14)")}),
            annotation_text="Expression CHOP — Basic\n\nGenerates sine wave using expression.\nme.time provides elapsed seconds.")),
        ("expression_multi", build_chop_chain("expr1",
            node("ExpressionCHOP", 100, 100, {"expr0": p("sin(me.time * 2)"), "expr1": p("cos(me.time * 2)")}),
            annotation_text="Expression CHOP — Multi-Channel\n\nSin and cos create a rotating 2D vector.")),
        ("expression_input", build_chop_chain("expr1",
            node("ExpressionCHOP", 400, 100, {"expr0": p("me.input(0) * 2 + 0.5")}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)})},
            extra_conns=[conn("lfo1", 0, "expr1", 0)],
            annotation_text="Expression CHOP — With Input\n\nScales LFO input by 2 and adds 0.5 offset.\nme.input(0) references first input.")),
    ]

    # ── ExtendCHOP ──
    patches["extend"] = [
        ("extend_basic", build_chop_chain("ext1",
            node("ExtendCHOP", 400, 100, {}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)})},
            extra_conns=[conn("lfo1", 0, "ext1", 0)],
            annotation_text="Extend CHOP — Basic\n\nExtends the sample range of an LFO signal.")),
        ("extend_hold", build_chop_chain("ext1",
            node("ExtendCHOP", 400, 100, {"extend_left": p(0), "extend_right": p(0)}),
            extra_nodes={"ramp1": node("RampCHOP", 100, 100, {})},
            extra_conns=[conn("ramp1", 0, "ext1", 0)],
            annotation_text="Extend CHOP — Hold\n\nHolds the last value of a ramp at both ends.")),
        ("extend_cycle", build_chop_chain("ext1",
            node("ExtendCHOP", 400, 100, {"extend_left": p(1), "extend_right": p(1)}),
            extra_nodes={"wave1": node("WaveCHOP", 100, 100, {"frequency": p(2.0)})},
            extra_conns=[conn("wave1", 0, "ext1", 0)],
            annotation_text="Extend CHOP — Cycle\n\nCycles the wave pattern beyond its original range.")),
    ]

    # ── FanCHOP ──
    patches["fan"] = [
        ("fan_basic", build_chop_chain("fan1",
            node("FanCHOP", 400, 100, {}),
            extra_nodes={"merge1": node("MergeCHOP", 250, 100, {}),
                         "lfo1": node("LFO_CHOP", 100, 50, {"frequency": p(1.0)}),
                         "wave1": node("WaveCHOP", 100, 200, {"frequency": p(2.0)})},
            extra_conns=[conn("lfo1", 0, "merge1", 0), conn("wave1", 0, "merge1", 1), conn("merge1", 0, "fan1", 0)],
            annotation_text="Fan CHOP — Basic\n\nFans merged channels into separate outputs.")),
        ("fan_split", build_chop_chain("fan1",
            node("FanCHOP", 400, 100, {}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"channels": p(4)})},
            extra_conns=[conn("noise1", 0, "fan1", 0)],
            annotation_text="Fan CHOP — Split Multi-Channel\n\nSplits 4-channel noise into individual outputs.")),
        ("fan_regroup", build_chop_chain("fan1",
            node("FanCHOP", 400, 100, {}),
            extra_nodes={
                "pattern1": node("PatternCHOP", 100, 100, {}),
                "math1": node("MathCHOP", 600, 100, {}),
            },
            extra_conns=[conn("pattern1", 0, "fan1", 0), conn("fan1", 0, "math1", 0)],
            annotation_text="Fan CHOP — Regrouped\n\nPattern fanned out then processed through Math.")),
    ]

    # ── FeedbackCHOP ──
    patches["feedback"] = [
        ("feedback_basic", build_chop_chain("fb1",
            node("FeedbackCHOP", 400, 100, {}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)})},
            extra_conns=[conn("lfo1", 0, "fb1", 0)],
            annotation_text="Feedback CHOP — Basic\n\nAccesses previous frame's CHOP values.\nCreates temporal recursion.")),
        ("feedback_accumulate", build_chop_chain("fb1",
            node("FeedbackCHOP", 400, 100, {}),
            extra_nodes={
                "const1": node("ConstantCHOP", 100, 100, {"value0": p(0.01)}),
                "math1": node("MathCHOP", 600, 100, {}),
            },
            extra_conns=[conn("const1", 0, "math1", 0), conn("fb1", 0, "math1", 1)],
            annotation_text="Feedback CHOP — Accumulator\n\nAdds constant to previous frame = growing value.\nSimple integrator pattern.")),
        ("feedback_decay", build_chop_chain("fb1",
            node("FeedbackCHOP", 400, 100, {}),
            extra_nodes={
                "trigger1": node("TriggerCHOP", 100, 100, {"attack": p(0.01), "release": p(0.5)}),
                "math1": node("MathCHOP", 600, 100, {"operation": p(2), "operand": p(0.95)}),
            },
            extra_conns=[conn("trigger1", 0, "math1", 0), conn("fb1", 0, "math1", 1)],
            annotation_text="Feedback CHOP — Decay\n\nTrigger impulse decays via 0.95x feedback.\nExponential decay pattern.")),
    ]

    # ── FilterCHOP ──
    patches["filter"] = [
        ("filter_basic", build_chop_chain("filter1",
            node("FilterCHOP", 400, 100, {"filter_width": p(4.0)}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"roughness": p(0.8), "amplitude": p(1.0)})},
            extra_conns=[conn("noise1", 0, "filter1", 0)],
            annotation_text="Filter CHOP — Basic\n\nLow-pass filters a noisy signal.\nWidth controls smoothing amount.")),
        ("filter_narrow", build_chop_chain("filter1",
            node("FilterCHOP", 400, 100, {"filter_width": p(1.0)}),
            extra_nodes={"wave1": node("WaveCHOP", 100, 100, {"waveform": p(2), "frequency": p(5.0)})},
            extra_conns=[conn("wave1", 0, "filter1", 0)],
            annotation_text="Filter CHOP — Narrow\n\nMinimal filtering on square wave.\nShows slight edge rounding.")),
        ("filter_heavy", build_chop_chain("filter1",
            node("FilterCHOP", 400, 100, {"filter_width": p(16.0)}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"roughness": p(1.0), "amplitude": p(1.0)})},
            extra_conns=[conn("noise1", 0, "filter1", 0)],
            annotation_text="Filter CHOP — Heavy Smoothing\n\nAggressive low-pass on rough noise.\nProduces very smooth curves.")),
    ]

    # ── GamepadCHOP ──
    patches["gamepad"] = [
        ("gamepad_basic", build_chop_chain("gp1",
            node("GamepadCHOP", 100, 100, {}),
            annotation_text="Gamepad CHOP — Basic\n\nOutputs gamepad joystick and button values.\nRequires connected controller.")),
        ("gamepad_trail", build_chop_chain("gp1",
            node("GamepadCHOP", 100, 100, {}),
            extra_nodes={"trail1": node("TrailCHOP", 400, 100, {"length": p(5.0)})},
            extra_conns=[conn("gp1", 0, "trail1", 0)],
            annotation_text="Gamepad CHOP — Trailed\n\nGamepad input visualized over time via Trail.")),
        ("gamepad_filtered", build_chop_chain("gp1",
            node("GamepadCHOP", 100, 100, {}),
            extra_nodes={"lag1": node("LagCHOP", 400, 100, {"lag": p(0.1)})},
            extra_conns=[conn("gp1", 0, "lag1", 0)],
            annotation_text="Gamepad CHOP — Smoothed\n\nLag applied to gamepad for smoother response.\nReduces joystick jitter.")),
    ]

    # ── HoldCHOP ──
    patches["hold"] = [
        ("hold_basic", build_chop_chain("hold1",
            node("HoldCHOP", 400, 100, {}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(2.0)})},
            extra_conns=[conn("lfo1", 0, "hold1", 0)],
            annotation_text="Hold CHOP — Basic\n\nSamples and holds LFO value on trigger.")),
        ("hold_triggered", build_chop_chain("hold1",
            node("HoldCHOP", 400, 100, {}),
            extra_nodes={
                "noise1": node("NoiseCHOP", 100, 50, {"amplitude": p(1.0)}),
                "timer1": node("TimerCHOP", 100, 200, {"length": p(1.0)}),
            },
            extra_conns=[conn("noise1", 0, "hold1", 0), conn("timer1", 0, "hold1", 1)],
            annotation_text="Hold CHOP — Timer Triggered\n\nHolds noise value every 1 second.\nCreates stepped random values.")),
        ("hold_beat", build_chop_chain("hold1",
            node("HoldCHOP", 400, 100, {}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 50, {"frequency": p(0.5)}),
                "beat1": node("BeatCHOP", 100, 200, {"bpm": p(120.0)}),
            },
            extra_conns=[conn("lfo1", 0, "hold1", 0), conn("beat1", 0, "hold1", 1)],
            annotation_text="Hold CHOP — Beat Synced\n\nHolds LFO value on each beat.\nQuantizes smooth signal to rhythm.")),
    ]

    # ── IKCHOP ──
    patches["ik"] = [
        ("ik_basic", build_chop_chain("ik1",
            node("IKCHOP", 400, 100, {}),
            extra_nodes={"const1": node("ConstantCHOP", 100, 100, {"value0": p(1.0), "value1": p(0.5)})},
            extra_conns=[conn("const1", 0, "ik1", 0)],
            annotation_text="IK CHOP — Basic\n\nInverse kinematics solver.\nInput target position, outputs joint angles.")),
        ("ik_animated", build_chop_chain("ik1",
            node("IKCHOP", 400, 100, {}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(0.5), "amplitude": p(2.0)})},
            extra_conns=[conn("lfo1", 0, "ik1", 0)],
            annotation_text="IK CHOP — Animated Target\n\nLFO drives IK target position.\nJoint angles follow smoothly.")),
        ("ik_two_joint", build_chop_chain("ik1",
            node("IKCHOP", 400, 100, {}),
            extra_nodes={
                "expr1": node("ExpressionCHOP", 100, 100, {"expr0": p("sin(me.time) * 1.5"), "expr1": p("cos(me.time) * 0.8")}),
            },
            extra_conns=[conn("expr1", 0, "ik1", 0)],
            annotation_text="IK CHOP — Circular Motion\n\nExpression generates circular target path.\nIK solver tracks the motion.")),
    ]

    # ── InterpolateCHOP ──
    patches["interpolate"] = [
        ("interpolate_basic", build_chop_chain("interp1",
            node("InterpolateCHOP", 400, 100, {"interpolate": p(0.5)}),
            extra_nodes={
                "const1": node("ConstantCHOP", 100, 50, {"value0": p(0.0)}),
                "const2": node("ConstantCHOP", 100, 200, {"value0": p(1.0)}),
            },
            extra_conns=[conn("const1", 0, "interp1", 0), conn("const2", 0, "interp1", 1)],
            annotation_text="Interpolate CHOP — Basic\n\nLinear interpolation between 0 and 1 at 50%.")),
        ("interpolate_animated", build_chop_chain("interp1",
            node("InterpolateCHOP", 400, 100, {}),
            extra_nodes={
                "const1": node("ConstantCHOP", 100, 50, {"value0": p(-1.0)}),
                "const2": node("ConstantCHOP", 100, 200, {"value0": p(1.0)}),
                "lfo1": node("LFO_CHOP", 250, 350, {"frequency": p(0.3), "amplitude": p(0.5), "offset": p(0.5)}),
            },
            extra_conns=[
                conn("const1", 0, "interp1", 0), conn("const2", 0, "interp1", 1),
                conn("lfo1", 0, "interp1", 2),
            ],
            annotation_text="Interpolate CHOP — Animated\n\nLFO sweeps interpolation between -1 and 1.")),
        ("interpolate_smooth", build_chop_chain("interp1",
            node("InterpolateCHOP", 400, 100, {}),
            extra_nodes={
                "noise1": node("NoiseCHOP", 100, 50, {"amplitude": p(1.0)}),
                "noise2": node("NoiseCHOP", 100, 200, {"amplitude": p(0.5), "roughness": p(0.8)}),
            },
            extra_conns=[conn("noise1", 0, "interp1", 0), conn("noise2", 0, "interp1", 1)],
            annotation_text="Interpolate CHOP — Noise Blend\n\nInterpolates between two noise signals.\nAdjust blend for different textures.")),
    ]

    # ── JoinCHOP ──
    patches["join"] = [
        ("join_basic", build_chop_chain("join1",
            node("JoinCHOP", 400, 100, {}),
            extra_nodes={
                "ramp1": node("RampCHOP", 100, 50, {}),
                "ramp2": node("RampCHOP", 100, 200, {}),
            },
            extra_conns=[conn("ramp1", 0, "join1", 0), conn("ramp2", 0, "join1", 1)],
            annotation_text="Join CHOP — Basic\n\nJoins two ramp segments end-to-end.")),
        ("join_multi", build_chop_chain("join1",
            node("JoinCHOP", 500, 100, {}),
            extra_nodes={
                "wave1": node("WaveCHOP", 100, 50, {"waveform": p(0), "frequency": p(1.0)}),
                "wave2": node("WaveCHOP", 100, 200, {"waveform": p(1), "frequency": p(2.0)}),
                "wave3": node("WaveCHOP", 100, 350, {"waveform": p(2), "frequency": p(3.0)}),
            },
            extra_conns=[
                conn("wave1", 0, "join1", 0), conn("wave2", 0, "join1", 1),
                conn("wave3", 0, "join1", 2),
            ],
            annotation_text="Join CHOP — Three Segments\n\nSine, triangle, and square waves joined sequentially.")),
        ("join_blended", build_chop_chain("join1",
            node("JoinCHOP", 400, 100, {}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 50, {"frequency": p(0.5)}),
                "noise1": node("NoiseCHOP", 100, 200, {"amplitude": p(0.5)}),
            },
            extra_conns=[conn("lfo1", 0, "join1", 0), conn("noise1", 0, "join1", 1)],
            annotation_text="Join CHOP — LFO + Noise\n\nJoins smooth LFO with choppy noise.\nShows transition between sections.")),
    ]

    # ── KeyboardInCHOP ──
    patches["keyboardin"] = [
        ("keyboardin_basic", build_chop_chain("kb1",
            node("KeyboardInCHOP", 100, 100, {}),
            annotation_text="Keyboard In — Basic\n\nOutputs key press states as channels.\nPress keys to see values change.")),
        ("keyboardin_trail", build_chop_chain("kb1",
            node("KeyboardInCHOP", 100, 100, {}),
            extra_nodes={"trail1": node("TrailCHOP", 400, 100, {"length": p(3.0)})},
            extra_conns=[conn("kb1", 0, "trail1", 0)],
            annotation_text="Keyboard In — Trailed\n\nKey presses shown over time.\nUseful for visualizing input timing.")),
        ("keyboardin_smoothed", build_chop_chain("kb1",
            node("KeyboardInCHOP", 100, 100, {}),
            extra_nodes={"lag1": node("LagCHOP", 400, 100, {"lag": p(0.2)})},
            extra_conns=[conn("kb1", 0, "lag1", 0)],
            annotation_text="Keyboard In — Smoothed\n\nLag smooths binary key states.\nCreates fade-in/fade-out effect.")),
    ]

    # ── LagCHOP ──
    patches["lag"] = [
        ("lag_basic", build_chop_chain("lag1",
            node("LagCHOP", 400, 100, {"lag": p(0.3)}),
            extra_nodes={"wave1": node("WaveCHOP", 100, 100, {"waveform": p(2), "frequency": p(2.0)})},
            extra_conns=[conn("wave1", 0, "lag1", 0)],
            annotation_text="Lag CHOP — Basic\n\nSmooths a square wave with 0.3s lag.\nRounds sharp edges.")),
        ("lag_fast", build_chop_chain("lag1",
            node("LagCHOP", 400, 100, {"lag": p(0.05)}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"roughness": p(1.0), "amplitude": p(1.0)})},
            extra_conns=[conn("noise1", 0, "lag1", 0)],
            annotation_text="Lag CHOP — Fast\n\nLight smoothing on rough noise.\nPreserves most detail.")),
        ("lag_asymmetric", build_chop_chain("lag1",
            node("LagCHOP", 400, 100, {"lag": p(0.1), "overshoot": p(0.3)}),
            extra_nodes={"trigger1": node("TriggerCHOP", 100, 100, {"attack": p(0.01), "release": p(0.2)})},
            extra_conns=[conn("trigger1", 0, "lag1", 0)],
            annotation_text="Lag CHOP — With Overshoot\n\nLag with overshoot on trigger pulses.\nCreates bouncy spring effect.")),
    ]

    # ── LFO_CHOP ──
    patches["lfo"] = [
        ("lfo_basic", build_chop_chain("lfo1",
            node("LFO_CHOP", 100, 100, {"waveform": p(0), "frequency": p(1.0), "amplitude": p(1.0)}),
            annotation_text="LFO — Basic Sine\n\n1 Hz sine wave oscillator.\nFundamental building block for animation.")),
        ("lfo_square", build_chop_chain("lfo1",
            node("LFO_CHOP", 100, 100, {"waveform": p(2), "frequency": p(2.0), "amplitude": p(1.0)}),
            annotation_text="LFO — Square Wave\n\n2 Hz square wave.\nUseful for on/off toggling.")),
        ("lfo_modulated", build_chop_chain("lfo1",
            node("LFO_CHOP", 100, 100, {"waveform": p(0), "frequency": p(0.5), "amplitude": p(1.0)}),
            extra_nodes={
                "lfo2": node("LFO_CHOP", 100, 250, {"waveform": p(0), "frequency": p(8.0), "amplitude": p(0.3)}),
                "math1": node("MathCHOP", 400, 100, {}),
            },
            extra_conns=[conn("lfo1", 0, "math1", 0), conn("lfo2", 0, "math1", 1)],
            annotation_text="LFO — Frequency Modulation\n\nSlow LFO modulated by fast LFO.\nCreates vibrato-like effect.")),
    ]

    # ── LimitCHOP ──
    patches["limit"] = [
        ("limit_basic", build_chop_chain("limit1",
            node("LimitCHOP", 400, 100, {}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"amplitude": p(2.0)})},
            extra_conns=[conn("lfo1", 0, "limit1", 0)],
            annotation_text="Limit CHOP — Basic\n\nClamps LFO to default range.\nPrevents values from exceeding bounds.")),
        ("limit_narrow", build_chop_chain("limit1",
            node("LimitCHOP", 400, 100, {"min_val": p(-0.5), "max_val": p(0.5)}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"amplitude": p(1.0)})},
            extra_conns=[conn("noise1", 0, "limit1", 0)],
            annotation_text="Limit CHOP — Narrow Range\n\nClamps noise to [-0.5, 0.5].\nFlattens peaks that exceed range.")),
        ("limit_quantize", build_chop_chain("limit1",
            node("LimitCHOP", 400, 100, {"quantize": p(0.25)}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(0.5)})},
            extra_conns=[conn("lfo1", 0, "limit1", 0)],
            annotation_text="Limit CHOP — Quantize\n\nQuantizes LFO to 0.25 steps.\nCreates staircase waveform.")),
    ]

    # ── LogicCHOP ──
    patches["logic"] = [
        ("logic_basic", build_chop_chain("logic1",
            node("LogicCHOP", 400, 100, {}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 50, {"frequency": p(1.0)}),
                "lfo2": node("LFO_CHOP", 100, 200, {"frequency": p(1.5)}),
            },
            extra_conns=[conn("lfo1", 0, "logic1", 0), conn("lfo2", 0, "logic1", 1)],
            annotation_text="Logic CHOP — Basic AND\n\nLogical AND of two LFOs.\nOutput is 1 when both inputs > 0.")),
        ("logic_or", build_chop_chain("logic1",
            node("LogicCHOP", 400, 100, {"operation": p(1)}),
            extra_nodes={
                "wave1": node("WaveCHOP", 100, 50, {"waveform": p(2), "frequency": p(1.0)}),
                "wave2": node("WaveCHOP", 100, 200, {"waveform": p(2), "frequency": p(3.0)}),
            },
            extra_conns=[conn("wave1", 0, "logic1", 0), conn("wave2", 0, "logic1", 1)],
            annotation_text="Logic CHOP — OR\n\nLogical OR of two square waves.\nOutput is 1 when either input > 0.")),
        ("logic_not", build_chop_chain("logic1",
            node("LogicCHOP", 400, 100, {"operation": p(2)}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)})},
            extra_conns=[conn("lfo1", 0, "logic1", 0)],
            annotation_text="Logic CHOP — NOT\n\nInverts LFO signal.\n1 becomes 0, 0 becomes 1.")),
    ]

    # ── LookupCHOP ──
    patches["lookup"] = [
        ("lookup_basic", build_chop_chain("lookup1",
            node("LookupCHOP", 400, 100, {}),
            extra_nodes={
                "ramp1": node("RampCHOP", 100, 50, {}),
                "wave1": node("WaveCHOP", 100, 200, {"waveform": p(0), "frequency": p(2.0)}),
            },
            extra_conns=[conn("ramp1", 0, "lookup1", 0), conn("wave1", 0, "lookup1", 1)],
            annotation_text="Lookup CHOP — Basic\n\nUses ramp as index into wave table.\nRemaps input through transfer function.")),
        ("lookup_noise", build_chop_chain("lookup1",
            node("LookupCHOP", 400, 100, {}),
            extra_nodes={
                "noise1": node("NoiseCHOP", 100, 50, {"amplitude": p(1.0)}),
                "lfo1": node("LFO_CHOP", 100, 200, {"frequency": p(0.5)}),
            },
            extra_conns=[conn("noise1", 0, "lookup1", 0), conn("lfo1", 0, "lookup1", 1)],
            annotation_text="Lookup CHOP — Noise Index\n\nNoise values index into LFO.\nCreates chaotic remapping.")),
        ("lookup_stepped", build_chop_chain("lookup1",
            node("LookupCHOP", 400, 100, {}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 50, {"frequency": p(1.0)}),
                "pattern1": node("PatternCHOP", 100, 200, {}),
            },
            extra_conns=[conn("lfo1", 0, "lookup1", 0), conn("pattern1", 0, "lookup1", 1)],
            annotation_text="Lookup CHOP — Pattern Table\n\nLFO indexes into a pattern.\nCreates non-linear mapping.")),
    ]

    # ── MathCHOP ──
    patches["math"] = [
        ("math_basic", build_chop_chain("math1",
            node("MathCHOP", 400, 100, {"operation": p(2), "operand": p(2.0)}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)})},
            extra_conns=[conn("lfo1", 0, "math1", 0)],
            annotation_text="Math CHOP — Basic\n\nMultiplies LFO output by 2x.\nDemonstrates single-operation math processing.")),
        ("math_multiply", build_chop_chain("math1",
            node("MathCHOP", 400, 100, {}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 50, {"frequency": p(1.0)}),
                "noise1": node("NoiseCHOP", 100, 200, {"amplitude": p(0.5)}),
            },
            extra_conns=[conn("lfo1", 0, "math1", 0), conn("noise1", 0, "math1", 1)],
            annotation_text="Math CHOP — Multiply Two Signals\n\nLFO multiplied by noise.\nAmplitude modulation effect.")),
        ("math_normalize", build_chop_chain("math1",
            node("MathCHOP", 400, 100, {"operation": p(0), "operand": p(0.5)}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"amplitude": p(1.0)})},
            extra_conns=[conn("noise1", 0, "math1", 0)],
            annotation_text="Math CHOP — Offset to 0-1\n\nAdds 0.5 to shift [-1,1] noise towards [0,1].\nUseful for driving parameters.")),
    ]

    # ── MergeCHOP ──
    patches["merge"] = [
        ("merge_basic", build_chop_chain("merge1",
            node("MergeCHOP", 400, 100, {}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 50, {"frequency": p(1.0)}),
                "wave1": node("WaveCHOP", 100, 200, {"frequency": p(2.0)}),
            },
            extra_conns=[conn("lfo1", 0, "merge1", 0), conn("wave1", 0, "merge1", 1)],
            annotation_text="Merge CHOP — Basic\n\nCombines LFO and wave into multi-channel output.")),
        ("merge_three", build_chop_chain("merge1",
            node("MergeCHOP", 400, 100, {}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 50, {"frequency": p(1.0)}),
                "noise1": node("NoiseCHOP", 100, 200, {"amplitude": p(0.5)}),
                "const1": node("ConstantCHOP", 100, 350, {"value0": p(0.75)}),
            },
            extra_conns=[
                conn("lfo1", 0, "merge1", 0), conn("noise1", 0, "merge1", 1),
                conn("const1", 0, "merge1", 2),
            ],
            annotation_text="Merge CHOP — Three Sources\n\nMerges LFO, noise, and constant into one stream.")),
        ("merge_renamed", build_chop_chain("merge1",
            node("MergeCHOP", 500, 100, {}),
            extra_nodes={
                "lfo_r": node("LFO_CHOP", 100, 50, {"frequency": p(1.0)}),
                "lfo_g": node("LFO_CHOP", 100, 200, {"frequency": p(1.5)}),
                "lfo_b": node("LFO_CHOP", 100, 350, {"frequency": p(2.0)}),
                "rename_r": node("RenameCHOP", 300, 50, {}),
                "rename_g": node("RenameCHOP", 300, 200, {}),
                "rename_b": node("RenameCHOP", 300, 350, {}),
            },
            extra_conns=[
                conn("lfo_r", 0, "rename_r", 0), conn("lfo_g", 0, "rename_g", 0),
                conn("lfo_b", 0, "rename_b", 0),
                conn("rename_r", 0, "merge1", 0), conn("rename_g", 0, "merge1", 1),
                conn("rename_b", 0, "merge1", 2),
            ],
            annotation_text="Merge CHOP — RGB Channels\n\nThree LFOs renamed to R/G/B and merged.\nUseful for driving color parameters.")),
    ]

    # ── MidiInCHOP ──
    patches["midiin"] = [
        ("midiin_basic", build_chop_chain("midi1",
            node("MidiInCHOP", 100, 100, {}),
            annotation_text="MIDI In — Basic\n\nReceives MIDI from Godot's built-in MIDI.\nShows notes, CC, pitch bend as channels.")),
        ("midiin_filtered", build_chop_chain("midi1",
            node("MidiInCHOP", 100, 100, {}),
            extra_nodes={"lag1": node("LagCHOP", 400, 100, {"lag": p(0.1)})},
            extra_conns=[conn("midi1", 0, "lag1", 0)],
            annotation_text="MIDI In — Smoothed\n\nMIDI input with lag smoothing.\nReduces CC value stepping.")),
        ("midiin_trailed", build_chop_chain("midi1",
            node("MidiInCHOP", 100, 100, {}),
            extra_nodes={"trail1": node("TrailCHOP", 400, 100, {"length": p(5.0)})},
            extra_conns=[conn("midi1", 0, "trail1", 0)],
            annotation_text="MIDI In — Trail View\n\nMIDI input over 5 seconds.\nVisualize note patterns.")),
    ]

    # ── MouseInCHOP ──
    patches["mousein"] = [
        ("mousein_basic", build_chop_chain("mouse1",
            node("MouseInCHOP", 100, 100, {}),
            annotation_text="Mouse In — Basic\n\nOutputs mouse X, Y position and button states.")),
        ("mousein_trail", build_chop_chain("mouse1",
            node("MouseInCHOP", 100, 100, {}),
            extra_nodes={"trail1": node("TrailCHOP", 400, 100, {"length": p(3.0)})},
            extra_conns=[conn("mouse1", 0, "trail1", 0)],
            annotation_text="Mouse In — Trailed\n\nMouse position over 3 seconds.\nShows movement history.")),
        ("mousein_smoothed", build_chop_chain("mouse1",
            node("MouseInCHOP", 100, 100, {}),
            extra_nodes={"smooth1": node("SmoothCHOP", 400, 100, {"width": p(0.2)})},
            extra_conns=[conn("mouse1", 0, "smooth1", 0)],
            annotation_text="Mouse In — Smoothed\n\nSmooth filter on mouse position.\nCreates eased cursor following.")),
    ]

    # ── NoiseCHOP ──
    patches["noise"] = [
        ("noise_basic", build_chop_chain("noise1",
            node("NoiseCHOP", 100, 100, {"amplitude": p(1.0), "roughness": p(0.5)}),
            annotation_text="Noise CHOP — Basic\n\nPerlin noise with medium roughness.\nSmooth evolving random values.")),
        ("noise_rough", build_chop_chain("noise1",
            node("NoiseCHOP", 100, 100, {"amplitude": p(1.0), "roughness": p(1.0)}),
            annotation_text="Noise CHOP — Rough\n\nMaximum roughness noise.\nRapid random fluctuations.")),
        ("noise_multi", build_chop_chain("noise1",
            node("NoiseCHOP", 100, 100, {"amplitude": p(1.0), "channels": p(3)}),
            annotation_text="Noise CHOP — Multi-Channel\n\n3 independent noise channels.\nUseful for XYZ random offsets.")),
    ]

    # ── NullCHOP ──
    patches["null"] = [
        ("null_basic", build_chop_chain("null1",
            node("NullCHOP", 400, 100, {}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)})},
            extra_conns=[conn("lfo1", 0, "null1", 0)],
            annotation_text="Null CHOP — Basic\n\nPass-through node. No processing.\nUseful as reference/anchor point.")),
        ("null_branch", build_chop_chain("null1",
            node("NullCHOP", 400, 100, {}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)}),
                "math1": node("MathCHOP", 600, 250, {"operation": p(2), "operand": p(2.0)}),
            },
            extra_conns=[conn("lfo1", 0, "null1", 0), conn("null1", 0, "math1", 0)],
            annotation_text="Null CHOP — Branch Point\n\nNull as branch point for multiple downstream.\nKeeps network organized.")),
        ("null_label", build_chop_chain("null1",
            node("NullCHOP", 400, 100, {}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"amplitude": p(0.5)})},
            extra_conns=[conn("noise1", 0, "null1", 0)],
            annotation_text="Null CHOP — Named Output\n\nNulls are commonly renamed for clarity.\nExpression references use null name.")),
    ]

    # ── OscInCHOP ──
    patches["oscin"] = [
        ("oscin_basic", build_chop_chain("osc1",
            node("OscInCHOP", 100, 100, {"port": p(9000)}),
            annotation_text="OSC In — Basic\n\nListens for OSC messages on port 9000.\nChannels appear as messages arrive.")),
        ("oscin_filtered", build_chop_chain("osc1",
            node("OscInCHOP", 100, 100, {"port": p(9000)}),
            extra_nodes={"lag1": node("LagCHOP", 400, 100, {"lag": p(0.1)})},
            extra_conns=[conn("osc1", 0, "lag1", 0)],
            annotation_text="OSC In — Smoothed\n\nOSC input with lag smoothing.\nReduces jitter from network latency.")),
        ("oscin_trail", build_chop_chain("osc1",
            node("OscInCHOP", 100, 100, {"port": p(9000)}),
            extra_nodes={"trail1": node("TrailCHOP", 400, 100, {"length": p(10.0)})},
            extra_conns=[conn("osc1", 0, "trail1", 0)],
            annotation_text="OSC In — History\n\nOSC values over 10 seconds.\nVisualize incoming data over time.")),
    ]

    # ── ParameterCHOP ──
    patches["parameter"] = [
        ("parameter_basic", build_chop_chain("param1",
            node("ParameterCHOP", 100, 100, {}),
            annotation_text="Parameter CHOP — Basic\n\nExports node parameters as CHOP channels.\nUseful for parameter visualization.")),
        ("parameter_chained", build_chop_chain("param1",
            node("ParameterCHOP", 100, 100, {}),
            extra_nodes={"math1": node("MathCHOP", 400, 100, {"operation": p(2), "operand": p(2.0)})},
            extra_conns=[conn("param1", 0, "math1", 0)],
            annotation_text="Parameter CHOP — Processed\n\nParameter values scaled by Math.\nDrives downstream effects.")),
        ("parameter_trail", build_chop_chain("param1",
            node("ParameterCHOP", 100, 100, {}),
            extra_nodes={"trail1": node("TrailCHOP", 400, 100, {"length": p(5.0)})},
            extra_conns=[conn("param1", 0, "trail1", 0)],
            annotation_text="Parameter CHOP — Trailed\n\nParameter changes over 5 seconds.\nVisualize parameter animation.")),
    ]

    # ── PatternCHOP ──
    patches["pattern"] = [
        ("pattern_basic", build_chop_chain("pat1",
            node("PatternCHOP", 100, 100, {}),
            annotation_text="Pattern CHOP — Basic\n\nGenerates a repeating pattern.\nUseful for lookup tables.")),
        ("pattern_long", build_chop_chain("pat1",
            node("PatternCHOP", 100, 100, {"length": p(100)}),
            annotation_text="Pattern CHOP — Long\n\n100-sample pattern.\nMore detail in the lookup.")),
        ("pattern_math", build_chop_chain("pat1",
            node("PatternCHOP", 100, 100, {}),
            extra_nodes={"math1": node("MathCHOP", 400, 100, {"operation": p(2), "operand": p(0.5)})},
            extra_conns=[conn("pat1", 0, "math1", 0)],
            annotation_text="Pattern CHOP — Scaled\n\nPattern scaled by 0.5 via Math.\nUseful for attenuating signal range.")),
    ]

    # ── PerformCHOP ──
    patches["perform"] = [
        ("perform_basic", build_chop_chain("perf1",
            node("PerformCHOP", 100, 100, {}),
            annotation_text="Perform CHOP — Basic\n\nOutputs performance metrics.\nFPS, cook time, memory usage.")),
        ("perform_trail", build_chop_chain("perf1",
            node("PerformCHOP", 100, 100, {}),
            extra_nodes={"trail1": node("TrailCHOP", 400, 100, {"length": p(30.0)})},
            extra_conns=[conn("perf1", 0, "trail1", 0)],
            annotation_text="Perform CHOP — History\n\nPerformance over 30 seconds.\nSpot frame rate drops.")),
        ("perform_analyze", build_chop_chain("perf1",
            node("PerformCHOP", 100, 100, {}),
            extra_nodes={"analyze1": node("AnalyzeCHOP", 400, 100, {"function": p(0)})},
            extra_conns=[conn("perf1", 0, "analyze1", 0)],
            annotation_text="Perform CHOP — Average FPS\n\nRunning average of performance metrics.\nSmooths out per-frame noise.")),
    ]

    # ── PhysicsCHOP ──
    patches["physics"] = [
        ("physics_basic", build_chop_chain("phys1",
            node("PhysicsCHOP", 400, 100, {}),
            extra_nodes={"const1": node("ConstantCHOP", 100, 100, {"value0": p(1.0)})},
            extra_conns=[conn("const1", 0, "phys1", 0)],
            annotation_text="Physics CHOP — Basic\n\nPhysics simulation on constant input.\nApplies spring/gravity dynamics.")),
        ("physics_spring", build_chop_chain("phys1",
            node("PhysicsCHOP", 400, 100, {}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(0.5), "amplitude": p(2.0)})},
            extra_conns=[conn("lfo1", 0, "phys1", 0)],
            annotation_text="Physics CHOP — Spring\n\nLFO drives physics with spring dynamics.\nOvershoots and oscillates around target.")),
        ("physics_gravity", build_chop_chain("phys1",
            node("PhysicsCHOP", 400, 100, {}),
            extra_nodes={"trigger1": node("TriggerCHOP", 100, 100, {"attack": p(0.01), "sustain": p(0.1), "release": p(0.01)})},
            extra_conns=[conn("trigger1", 0, "phys1", 0)],
            annotation_text="Physics CHOP — Bounce\n\nTrigger impulse with gravity.\nSimulates bouncing ball.")),
    ]

    # ── RampCHOP ──
    patches["ramp"] = [
        ("ramp_basic", build_chop_chain("ramp1",
            node("RampCHOP", 100, 100, {}),
            annotation_text="Ramp CHOP — Basic\n\nLinear ramp from 0 to 1.\nFundamental for gradients and transitions.")),
        ("ramp_shaped", build_chop_chain("ramp1",
            node("RampCHOP", 100, 100, {}),
            extra_nodes={"math1": node("MathCHOP", 400, 100, {"operation": p(7), "operand": p(2.0)})},
            extra_conns=[conn("ramp1", 0, "math1", 0)],
            annotation_text="Ramp CHOP — Shaped\n\nRamp raised to power 2.\nCreates ease-in curve.")),
        ("ramp_inverted", build_chop_chain("ramp1",
            node("RampCHOP", 100, 100, {}),
            extra_nodes={"math1": node("MathCHOP", 400, 100, {"operation": p(2), "operand": p(-1.0)})},
            extra_conns=[conn("ramp1", 0, "math1", 0)],
            annotation_text="Ramp CHOP — Negated\n\nRamp negated via Multiply by -1.\nUseful for inverting signal direction.")),
    ]

    # ── RenameCHOP ──
    patches["rename"] = [
        ("rename_basic", build_chop_chain("ren1",
            node("RenameCHOP", 400, 100, {}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)})},
            extra_conns=[conn("lfo1", 0, "ren1", 0)],
            annotation_text="Rename CHOP — Basic\n\nRenames channels for clarity.\nSet new names in parameters.")),
        ("rename_rgb", build_chop_chain("ren1",
            node("RenameCHOP", 400, 100, {}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"channels": p(3)})},
            extra_conns=[conn("noise1", 0, "ren1", 0)],
            annotation_text="Rename CHOP — RGB Labels\n\nRenames 3-channel noise to r, g, b.\nMakes channel purpose clear.")),
        ("rename_prefix", build_chop_chain("ren1",
            node("RenameCHOP", 400, 100, {}),
            extra_nodes={"merge1": node("MergeCHOP", 250, 100, {}),
                         "const1": node("ConstantCHOP", 100, 50, {"value0": p(1.0)}),
                         "const2": node("ConstantCHOP", 100, 200, {"value0": p(0.5)})},
            extra_conns=[conn("const1", 0, "merge1", 0), conn("const2", 0, "merge1", 1), conn("merge1", 0, "ren1", 0)],
            annotation_text="Rename CHOP — After Merge\n\nRenames merged constant channels.\nCreates meaningful output names.")),
    ]

    # ── ResampleCHOP ──
    patches["resample"] = [
        ("resample_basic", build_chop_chain("res1",
            node("ResampleCHOP", 400, 100, {}),
            extra_nodes={"wave1": node("WaveCHOP", 100, 100, {"frequency": p(2.0)})},
            extra_conns=[conn("wave1", 0, "res1", 0)],
            annotation_text="Resample CHOP — Basic\n\nResamples wave to different rate.\nChanges temporal resolution.")),
        ("resample_upsample", build_chop_chain("res1",
            node("ResampleCHOP", 400, 100, {"rate": p(120)}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"amplitude": p(1.0)})},
            extra_conns=[conn("noise1", 0, "res1", 0)],
            annotation_text="Resample CHOP — Upsample\n\nIncreases sample rate to 120.\nSmoother interpolation.")),
        ("resample_downsample", build_chop_chain("res1",
            node("ResampleCHOP", 400, 100, {"rate": p(10)}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)})},
            extra_conns=[conn("lfo1", 0, "res1", 0)],
            annotation_text="Resample CHOP — Downsample\n\nReduces to 10 samples/sec.\nCreates aliased/stepped look.")),
    ]

    # ── GDScriptSCRIPT (CHOP template) ──
    patches["script"] = [
        ("script_basic", build_chop_chain("script1",
            node("GDScriptSCRIPT", 100, 100, {}),
            annotation_text="GDScript SCRIPT — Basic\n\nCustom GDScript-driven CHOP.\nEdit script to define output channels.")),
        ("script_input", build_chop_chain("script1",
            node("GDScriptSCRIPT", 400, 100, {}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)})},
            extra_conns=[conn("lfo1", 0, "script1", 0)],
            annotation_text="GDScript SCRIPT — With Input\n\nScript receives LFO input.\nProcess and transform in GDScript.")),
        ("script_multi", build_chop_chain("script1",
            node("GDScriptSCRIPT", 400, 100, {}),
            extra_nodes={
                "noise1": node("NoiseCHOP", 100, 50, {}),
                "lfo1": node("LFO_CHOP", 100, 200, {"frequency": p(2.0)}),
            },
            extra_conns=[conn("noise1", 0, "script1", 0), conn("lfo1", 0, "script1", 1)],
            annotation_text="GDScript SCRIPT — Multi-Input\n\nTwo inputs for custom script processing.\nCombine signals in code.")),
    ]

    # ── SelectCHOP ──
    patches["select"] = [
        ("select_basic", build_chop_chain("sel1",
            node("SelectCHOP", 400, 100, {}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"channels": p(4)})},
            extra_conns=[conn("noise1", 0, "sel1", 0)],
            annotation_text="Select CHOP — Basic\n\nSelects specific channels from multi-channel input.")),
        ("select_first", build_chop_chain("sel1",
            node("SelectCHOP", 400, 100, {}),
            extra_nodes={"merge1": node("MergeCHOP", 250, 100, {}),
                         "lfo1": node("LFO_CHOP", 100, 50, {}),
                         "wave1": node("WaveCHOP", 100, 200, {})},
            extra_conns=[conn("lfo1", 0, "merge1", 0), conn("wave1", 0, "merge1", 1), conn("merge1", 0, "sel1", 0)],
            annotation_text="Select CHOP — From Merged\n\nSelect channels from merged stream.\nPick specific signals.")),
        ("select_range", build_chop_chain("sel1",
            node("SelectCHOP", 400, 100, {}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"channels": p(8)})},
            extra_conns=[conn("noise1", 0, "sel1", 0)],
            annotation_text="Select CHOP — Range\n\nSelect range of channels from 8-channel noise.\nFilters to subset of interest.")),
    ]

    # ── ShuffleCHOP ──
    patches["shuffle"] = [
        ("shuffle_basic", build_chop_chain("shuf1",
            node("ShuffleCHOP", 400, 100, {}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"channels": p(4)})},
            extra_conns=[conn("noise1", 0, "shuf1", 0)],
            annotation_text="Shuffle CHOP — Basic\n\nReorders channels.\nChanges channel arrangement.")),
        ("shuffle_swap", build_chop_chain("shuf1",
            node("ShuffleCHOP", 400, 100, {}),
            extra_nodes={"merge1": node("MergeCHOP", 250, 100, {}),
                         "lfo1": node("LFO_CHOP", 100, 50, {}),
                         "wave1": node("WaveCHOP", 100, 200, {})},
            extra_conns=[conn("lfo1", 0, "merge1", 0), conn("wave1", 0, "merge1", 1), conn("merge1", 0, "shuf1", 0)],
            annotation_text="Shuffle CHOP — Swap Channels\n\nSwaps order of merged LFO and wave.")),
        ("shuffle_reverse", build_chop_chain("shuf1",
            node("ShuffleCHOP", 400, 100, {}),
            extra_nodes={"pattern1": node("PatternCHOP", 100, 100, {})},
            extra_conns=[conn("pattern1", 0, "shuf1", 0)],
            annotation_text="Shuffle CHOP — Reverse\n\nReverses channel order of pattern.\nMirrors the data arrangement.")),
    ]

    # ── SlopeCHOP ──
    patches["slope"] = [
        ("slope_basic", build_chop_chain("slope1",
            node("SlopeCHOP", 400, 100, {}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)})},
            extra_conns=[conn("lfo1", 0, "slope1", 0)],
            annotation_text="Slope CHOP — Basic\n\nComputes rate of change of LFO.\nSine derivative = cosine.")),
        ("slope_noise", build_chop_chain("slope1",
            node("SlopeCHOP", 400, 100, {}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"amplitude": p(1.0), "roughness": p(0.3)})},
            extra_conns=[conn("noise1", 0, "slope1", 0)],
            annotation_text="Slope CHOP — Noise Velocity\n\nRate of change of smooth noise.\nShows velocity of movement.")),
        ("slope_direction", build_chop_chain("slope1",
            node("SlopeCHOP", 400, 100, {}),
            extra_nodes={
                "wave1": node("WaveCHOP", 100, 100, {"waveform": p(1), "frequency": p(0.5)}),
                "logic1": node("LogicCHOP", 600, 100, {}),
            },
            extra_conns=[conn("wave1", 0, "slope1", 0), conn("slope1", 0, "logic1", 0)],
            annotation_text="Slope CHOP — Direction Detect\n\nSlope + Logic detects rising/falling.\n1 = rising, 0 = falling.")),
    ]

    # ── SmoothCHOP ──
    patches["smooth"] = [
        ("smooth_basic", build_chop_chain("smooth1",
            node("SmoothCHOP", 400, 100, {"width": p(0.2)}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"roughness": p(0.8), "amplitude": p(1.0)})},
            extra_conns=[conn("noise1", 0, "smooth1", 0)],
            annotation_text="Smooth CHOP — Basic\n\nGaussian smoothing on noisy signal.\nWidth controls kernel size.")),
        ("smooth_heavy", build_chop_chain("smooth1",
            node("SmoothCHOP", 400, 100, {"width": p(1.0)}),
            extra_nodes={"wave1": node("WaveCHOP", 100, 100, {"waveform": p(2), "frequency": p(5.0)})},
            extra_conns=[conn("wave1", 0, "smooth1", 0)],
            annotation_text="Smooth CHOP — Heavy\n\nHeavy smoothing on square wave.\nAlmost completely rounds the edges.")),
        ("smooth_subtle", build_chop_chain("smooth1",
            node("SmoothCHOP", 400, 100, {"width": p(0.05)}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"roughness": p(1.0)})},
            extra_conns=[conn("noise1", 0, "smooth1", 0)],
            annotation_text="Smooth CHOP — Subtle\n\nMinimal smoothing preserves most detail.\nJust takes the edge off.")),
    ]

    # ── SOPtoCHOP ──
    patches["soptochop"] = [
        ("soptochop_basic", build_chop_chain("s2c1",
            node("SOPtoCHOP", 400, 100, {}),
            extra_nodes={"grid1": node("GridSOP", 100, 100, {"rows": p(4), "cols": p(4)})},
            extra_conns=[conn("grid1", 0, "s2c1", 0)],
            annotation_text="SOP to CHOP — Basic\n\nExtracts point positions from grid as channels.")),
        ("soptochop_sphere", build_chop_chain("s2c1",
            node("SOPtoCHOP", 400, 100, {}),
            extra_nodes={"sphere1": node("SphereSOP", 100, 100, {})},
            extra_conns=[conn("sphere1", 0, "s2c1", 0)],
            annotation_text="SOP to CHOP — Sphere Points\n\nSphere vertex positions as channel data.\nX, Y, Z arrays.")),
        ("soptochop_animated", build_chop_chain("s2c1",
            node("SOPtoCHOP", 400, 100, {}),
            extra_nodes={
                "grid1": node("GridSOP", 100, 100, {}),
                "noise_sop": node("NoiseSOP", 250, 100, {}),
            },
            extra_conns=[conn("grid1", 0, "noise_sop", 0), conn("noise_sop", 0, "s2c1", 0)],
            annotation_text="SOP to CHOP — Animated\n\nNoise-deformed grid converted to channels.\nShows evolving point data.")),
    ]

    # ── SpeedCHOP ──
    patches["speed"] = [
        ("speed_basic", build_chop_chain("speed1",
            node("SpeedCHOP", 400, 100, {}),
            extra_nodes={"const1": node("ConstantCHOP", 100, 100, {"value0": p(0.1)})},
            extra_conns=[conn("const1", 0, "speed1", 0)],
            annotation_text="Speed CHOP — Basic\n\nIntegrates constant velocity.\nPosition increases linearly.")),
        ("speed_variable", build_chop_chain("speed1",
            node("SpeedCHOP", 400, 100, {}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(0.5)})},
            extra_conns=[conn("lfo1", 0, "speed1", 0)],
            annotation_text="Speed CHOP — Variable Speed\n\nLFO drives varying speed.\nPosition curves sinusoidally.")),
        ("speed_reset", build_chop_chain("speed1",
            node("SpeedCHOP", 400, 100, {"reset": p(True)}),
            extra_nodes={
                "const1": node("ConstantCHOP", 100, 100, {"value0": p(0.5)}),
                "timer1": node("TimerCHOP", 100, 250, {"length": p(3.0)}),
            },
            extra_conns=[conn("const1", 0, "speed1", 0), conn("timer1", 0, "speed1", 1)],
            annotation_text="Speed CHOP — With Reset\n\nAccumulates speed, resets every 3 seconds.\nSawtooth position pattern.")),
    ]

    # ── SplitCHOP ──
    patches["split"] = [
        ("split_basic", build_chop_chain("split1",
            node("SplitCHOP", 400, 100, {}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"channels": p(4)})},
            extra_conns=[conn("noise1", 0, "split1", 0)],
            annotation_text="Split CHOP — Basic\n\nSplits multi-channel noise into individual channels.")),
        ("split_merged", build_chop_chain("split1",
            node("SplitCHOP", 400, 100, {}),
            extra_nodes={
                "merge1": node("MergeCHOP", 250, 100, {}),
                "lfo1": node("LFO_CHOP", 100, 50, {}),
                "wave1": node("WaveCHOP", 100, 200, {}),
            },
            extra_conns=[conn("lfo1", 0, "merge1", 0), conn("wave1", 0, "merge1", 1), conn("merge1", 0, "split1", 0)],
            annotation_text="Split CHOP — From Merged\n\nSplits merged signals back into individuals.")),
        ("split_select", build_chop_chain("split1",
            node("SplitCHOP", 400, 100, {}),
            extra_nodes={
                "noise1": node("NoiseCHOP", 100, 100, {"channels": p(6)}),
                "math1": node("MathCHOP", 600, 100, {"operation": p(2), "operand": p(2.0)}),
            },
            extra_conns=[conn("noise1", 0, "split1", 0), conn("split1", 0, "math1", 0)],
            annotation_text="Split CHOP — Process One\n\nSplit 6-channel noise, process one branch.\nSelective channel processing.")),
    ]

    # ── SpringCHOP ──
    patches["spring"] = [
        ("spring_basic", build_chop_chain("spring1",
            node("SpringCHOP", 400, 100, {}),
            extra_nodes={"const1": node("ConstantCHOP", 100, 100, {"value0": p(1.0)})},
            extra_conns=[conn("const1", 0, "spring1", 0)],
            annotation_text="Spring CHOP — Basic\n\nSpring dynamics on constant target.\nOscillates and settles.")),
        ("spring_bouncy", build_chop_chain("spring1",
            node("SpringCHOP", 400, 100, {"stiffness": p(10.0), "damping": p(0.1)}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"waveform": p(2), "frequency": p(0.5)})},
            extra_conns=[conn("lfo1", 0, "spring1", 0)],
            annotation_text="Spring CHOP — Bouncy\n\nLow damping + high stiffness = bouncy.\nSquare wave triggers oscillations.")),
        ("spring_heavy", build_chop_chain("spring1",
            node("SpringCHOP", 400, 100, {"stiffness": p(2.0), "damping": p(5.0)}),
            extra_nodes={"trigger1": node("TriggerCHOP", 100, 100, {"attack": p(0.01), "release": p(0.1)})},
            extra_conns=[conn("trigger1", 0, "spring1", 0)],
            annotation_text="Spring CHOP — Heavily Damped\n\nHigh damping = sluggish response.\nSmooths trigger pulses.")),
    ]

    # ── StretchCHOP ──
    patches["stretch"] = [
        ("stretch_basic", build_chop_chain("str1",
            node("StretchCHOP", 400, 100, {}),
            extra_nodes={"wave1": node("WaveCHOP", 100, 100, {"frequency": p(2.0)})},
            extra_conns=[conn("wave1", 0, "str1", 0)],
            annotation_text="Stretch CHOP — Basic\n\nTime-stretches wave signal.\nChanges duration without pitch.")),
        ("stretch_compress", build_chop_chain("str1",
            node("StretchCHOP", 400, 100, {"length": p(0.5)}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(0.5)})},
            extra_conns=[conn("lfo1", 0, "str1", 0)],
            annotation_text="Stretch CHOP — Compress\n\nCompresses LFO to half length.\nFaster playback.")),
        ("stretch_expand", build_chop_chain("str1",
            node("StretchCHOP", 400, 100, {"length": p(4.0)}),
            extra_nodes={"ramp1": node("RampCHOP", 100, 100, {})},
            extra_conns=[conn("ramp1", 0, "str1", 0)],
            annotation_text="Stretch CHOP — Expand\n\nStretches ramp to 4x original length.\nSlower transition.")),
    ]

    # ── SwitchCHOP ──
    patches["switch"] = [
        ("switch_basic", build_chop_chain("sw1",
            node("SwitchCHOP", 400, 100, {"index": p(0)}),
            extra_nodes={
                "lfo1": node("LFO_CHOP", 100, 50, {"frequency": p(1.0)}),
                "noise1": node("NoiseCHOP", 100, 200, {"amplitude": p(0.5)}),
            },
            extra_conns=[conn("lfo1", 0, "sw1", 0), conn("noise1", 0, "sw1", 1)],
            annotation_text="Switch CHOP — Basic\n\nSwitches between LFO and noise.\nIndex 0 = first input.")),
        ("switch_animated", build_chop_chain("sw1",
            node("SwitchCHOP", 400, 100, {}),
            extra_nodes={
                "wave1": node("WaveCHOP", 100, 50, {"waveform": p(0)}),
                "wave2": node("WaveCHOP", 100, 200, {"waveform": p(2)}),
                "lfo_sw": node("LFO_CHOP", 250, 300, {"frequency": p(0.3), "amplitude": p(0.5), "offset": p(0.5)}),
            },
            extra_conns=[conn("wave1", 0, "sw1", 0), conn("wave2", 0, "sw1", 1), conn("lfo_sw", 0, "sw1", 2)],
            annotation_text="Switch CHOP — Animated\n\nLFO sweeps between sine and square.\nBlended transition.")),
        ("switch_three", build_chop_chain("sw1",
            node("SwitchCHOP", 400, 100, {"index": p(2)}),
            extra_nodes={
                "const1": node("ConstantCHOP", 100, 50, {"value0": p(0.0)}),
                "lfo1": node("LFO_CHOP", 100, 200, {}),
                "noise1": node("NoiseCHOP", 100, 350, {}),
            },
            extra_conns=[conn("const1", 0, "sw1", 0), conn("lfo1", 0, "sw1", 1), conn("noise1", 0, "sw1", 2)],
            annotation_text="Switch CHOP — Three Inputs\n\nThree options: constant, LFO, noise.\nIndex selects active input.")),
    ]

    # ── TimerCHOP ──
    patches["timer"] = [
        ("timer_basic", build_chop_chain("timer1",
            node("TimerCHOP", 100, 100, {"length": p(5.0)}),
            annotation_text="Timer CHOP — Basic\n\n5-second countdown timer.\nOutputs normalized progress.")),
        ("timer_loop", build_chop_chain("timer1",
            node("TimerCHOP", 100, 100, {"length": p(2.0), "loop": p(True)}),
            annotation_text="Timer CHOP — Looping\n\n2-second looping timer.\nRepeats automatically.")),
        ("timer_trigger", build_chop_chain("timer1",
            node("TimerCHOP", 100, 100, {"length": p(3.0)}),
            extra_nodes={"trigger1": node("TriggerCHOP", 400, 100, {"attack": p(0.05), "release": p(0.5)})},
            extra_conns=[conn("timer1", 0, "trigger1", 0)],
            annotation_text="Timer CHOP — Triggers Envelope\n\nTimer completion triggers an envelope.\nUseful for timed events.")),
    ]

    # ── TOPtoCHOP ──
    patches["toptochop"] = [
        ("toptochop_basic", build_chop_chain("t2c1",
            node("TOPtoCHOP", 400, 100, {}),
            extra_nodes={"noise_top": node("NoiseTOP", 100, 100, {"resolution": vec2i(64, 64)})},
            extra_conns=[conn("noise_top", 0, "t2c1", 0)],
            annotation_text="TOP to CHOP — Basic\n\nConverts noise texture to channel data.\nPixel values become samples.")),
        ("toptochop_ramp", build_chop_chain("t2c1",
            node("TOPtoCHOP", 400, 100, {}),
            extra_nodes={"ramp_top": node("RampTOP", 100, 100, {"resolution": vec2i(256, 1)})},
            extra_conns=[conn("ramp_top", 0, "t2c1", 0)],
            annotation_text="TOP to CHOP — Ramp Line\n\n1-pixel-tall ramp texture as data.\nClean gradient in channel form.")),
        ("toptochop_analyze", build_chop_chain("t2c1",
            node("TOPtoCHOP", 400, 100, {}),
            extra_nodes={
                "noise_top": node("NoiseTOP", 100, 100, {"resolution": vec2i(128, 128)}),
                "analyze1": node("AnalyzeCHOP", 600, 100, {}),
            },
            extra_conns=[conn("noise_top", 0, "t2c1", 0), conn("t2c1", 0, "analyze1", 0)],
            annotation_text="TOP to CHOP — Analyzed\n\nTexture converted to channels then analyzed.\nGets average pixel brightness.")),
    ]

    # ── TrailCHOP ──
    patches["trail"] = [
        ("trail_basic", build_chop_chain("trail1",
            node("TrailCHOP", 400, 100, {"length": p(3.0)}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0)})},
            extra_conns=[conn("lfo1", 0, "trail1", 0)],
            annotation_text="Trail CHOP — Basic\n\nShows LFO history over 3 seconds.\nScrolling waveform display.")),
        ("trail_short", build_chop_chain("trail1",
            node("TrailCHOP", 400, 100, {"length": p(0.5)}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"amplitude": p(1.0)})},
            extra_conns=[conn("noise1", 0, "trail1", 0)],
            annotation_text="Trail CHOP — Short Window\n\n0.5 second trail of noise.\nDetailed recent history.")),
        ("trail_long", build_chop_chain("trail1",
            node("TrailCHOP", 400, 100, {"length": p(30.0)}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"roughness": p(0.3)})},
            extra_conns=[conn("noise1", 0, "trail1", 0)],
            annotation_text="Trail CHOP — Long History\n\n30-second trail for trend visualization.\nSees macro patterns.")),
    ]

    # ── TransformCHOP ──
    patches["transform"] = [
        ("transform_basic", build_chop_chain("xform1",
            node("TransformCHOP", 400, 100, {}),
            extra_nodes={"const1": node("ConstantCHOP", 100, 100, {"value0": p(1.0), "value1": p(0.0), "value2": p(0.0)})},
            extra_conns=[conn("const1", 0, "xform1", 0)],
            annotation_text="Transform CHOP — Basic\n\nApplies transform to XYZ channel data.\nTranslate, rotate, scale.")),
        ("transform_rotate", build_chop_chain("xform1",
            node("TransformCHOP", 400, 100, {"ry": p(45.0)}),
            extra_nodes={"const1": node("ConstantCHOP", 100, 100, {"value0": p(1.0), "value1": p(0.0), "value2": p(0.0)})},
            extra_conns=[conn("const1", 0, "xform1", 0)],
            annotation_text="Transform CHOP — Rotate\n\n45-degree Y rotation on position data.\nRotates point in 3D space.")),
        ("transform_animated", build_chop_chain("xform1",
            node("TransformCHOP", 400, 100, {}),
            extra_nodes={
                "const1": node("ConstantCHOP", 100, 100, {"value0": p(1.0), "value1": p(0.5), "value2": p(0.0)}),
                "lfo_rot": node("LFO_CHOP", 250, 300, {"frequency": p(0.25), "amplitude": p(180.0)}),
            },
            extra_conns=[conn("const1", 0, "xform1", 0), conn("lfo_rot", 0, "xform1", 1)],
            annotation_text="Transform CHOP — Animated Rotation\n\nLFO drives rotation angle.\nPoint orbits in 3D.")),
    ]

    # ── TriggerCHOP ──
    patches["trigger"] = [
        ("trigger_basic", build_chop_chain("trig1",
            node("TriggerCHOP", 100, 100, {"attack": p(0.05), "sustain": p(0.1), "release": p(0.3)}),
            annotation_text="Trigger CHOP — Basic\n\nAttack-sustain-release envelope.\nTriggered by input crossing threshold.")),
        ("trigger_fast", build_chop_chain("trig1",
            node("TriggerCHOP", 400, 100, {"attack": p(0.01), "sustain": p(0.0), "release": p(0.05)}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"waveform": p(2), "frequency": p(4.0)})},
            extra_conns=[conn("lfo1", 0, "trig1", 0)],
            annotation_text="Trigger CHOP — Fast Clicks\n\nRapid square wave triggers short pulses.\nClick/percussion effect.")),
        ("trigger_slow", build_chop_chain("trig1",
            node("TriggerCHOP", 400, 100, {"attack": p(0.5), "sustain": p(1.0), "release": p(2.0)}),
            extra_nodes={"beat1": node("BeatCHOP", 100, 100, {"bpm": p(30.0)})},
            extra_conns=[conn("beat1", 0, "trig1", 0)],
            annotation_text="Trigger CHOP — Slow Fade\n\nSlow beat triggers long envelope.\nBreathing/pulsing effect.")),
    ]

    # ── TrimCHOP ──
    patches["trim"] = [
        ("trim_basic", build_chop_chain("trim1",
            node("TrimCHOP", 400, 100, {}),
            extra_nodes={"wave1": node("WaveCHOP", 100, 100, {"frequency": p(1.0)})},
            extra_conns=[conn("wave1", 0, "trim1", 0)],
            annotation_text="Trim CHOP — Basic\n\nTrims signal to shorter time range.")),
        ("trim_start", build_chop_chain("trim1",
            node("TrimCHOP", 400, 100, {}),
            extra_nodes={"ramp1": node("RampCHOP", 100, 100, {})},
            extra_conns=[conn("ramp1", 0, "trim1", 0)],
            annotation_text="Trim CHOP — Cut Start\n\nRemoves beginning of ramp signal.")),
        ("trim_window", build_chop_chain("trim1",
            node("TrimCHOP", 400, 100, {}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"amplitude": p(1.0)})},
            extra_conns=[conn("noise1", 0, "trim1", 0)],
            annotation_text="Trim CHOP — Window\n\nExtracts a portion of noise signal.\nUseful for isolating events.")),
    ]

    # ── WarpCHOP ──
    patches["warp"] = [
        ("warp_basic", build_chop_chain("warp1",
            node("WarpCHOP", 400, 100, {}),
            extra_nodes={"ramp1": node("RampCHOP", 100, 100, {})},
            extra_conns=[conn("ramp1", 0, "warp1", 0)],
            annotation_text="Warp CHOP — Basic\n\nTime-warps ramp signal.\nNon-linear time remapping.")),
        ("warp_sine", build_chop_chain("warp1",
            node("WarpCHOP", 400, 100, {}),
            extra_nodes={
                "wave1": node("WaveCHOP", 100, 50, {"frequency": p(2.0)}),
                "lfo1": node("LFO_CHOP", 100, 200, {"frequency": p(0.5)}),
            },
            extra_conns=[conn("wave1", 0, "warp1", 0), conn("lfo1", 0, "warp1", 1)],
            annotation_text="Warp CHOP — LFO Index\n\nLFO warps wave playback time.\nTime speeds up and slows down.")),
        ("warp_noise", build_chop_chain("warp1",
            node("WarpCHOP", 400, 100, {}),
            extra_nodes={
                "pattern1": node("PatternCHOP", 100, 50, {}),
                "noise1": node("NoiseCHOP", 100, 200, {"amplitude": p(0.3)}),
            },
            extra_conns=[conn("pattern1", 0, "warp1", 0), conn("noise1", 0, "warp1", 1)],
            annotation_text="Warp CHOP — Noise Warp\n\nNoise warps pattern playback.\nOrganic time distortion.")),
    ]

    # ── WaveCHOP ──
    patches["wave"] = [
        ("wave_sine", build_chop_chain("wave1",
            node("WaveCHOP", 100, 100, {"waveform": p(0), "frequency": p(2.0), "amplitude": p(1.0)}),
            annotation_text="Wave CHOP — Sine\n\n2 Hz sine wave.\nSmooth periodic oscillation.")),
        ("wave_triangle", build_chop_chain("wave1",
            node("WaveCHOP", 100, 100, {"waveform": p(1), "frequency": p(1.0), "amplitude": p(1.0)}),
            annotation_text="Wave CHOP — Triangle\n\nTriangle wave at 1 Hz.\nLinear rise and fall.")),
        ("wave_square_pwm", build_chop_chain("wave1",
            node("WaveCHOP", 100, 100, {"waveform": p(2), "frequency": p(3.0), "amplitude": p(1.0)}),
            annotation_text="Wave CHOP — Square\n\n3 Hz square wave.\nSharp on/off switching.")),
    ]

    # ── DATtoCHOP (actually in DAT but registered as CHOP) ── skip, it's in DAT family

    # ── RtMidiInCHOP (extension) ──
    patches["rtmidiin"] = [
        ("rtmidiin_basic", build_chop_chain("rtmidi1",
            node("RtMidiInCHOP", 100, 100, {}),
            annotation_text="RtMidi In — Basic\n\nReceives MIDI via native RtMidi library.\nRequires gn_ext_midi DLL.\nShows notes, CC, pitch bend.")),
        ("rtmidiin_smoothed", build_chop_chain("rtmidi1",
            node("RtMidiInCHOP", 100, 100, {}),
            extra_nodes={"lag1": node("LagCHOP", 400, 100, {"lag": p(0.15)})},
            extra_conns=[conn("rtmidi1", 0, "lag1", 0)],
            annotation_text="RtMidi In — Smoothed\n\nNative MIDI with lag smoothing.\nReduces CC stepping artifacts.")),
        ("rtmidiin_visual", build_chop_chain("rtmidi1",
            node("RtMidiInCHOP", 100, 100, {}),
            extra_nodes={"trail1": node("TrailCHOP", 400, 100, {"length": p(10.0)})},
            extra_conns=[conn("rtmidi1", 0, "trail1", 0)],
            annotation_text="RtMidi In — History\n\nMIDI input over 10 seconds.\nVisualize performance patterns.")),
    ]

    # ── RtMidiOutCHOP (extension) ──
    patches["rtmidiout"] = [
        ("rtmidiout_basic", build_chop_chain("rtmidi_out1",
            node("RtMidiOutCHOP", 400, 100, {}),
            extra_nodes={"lfo1": node("LFO_CHOP", 100, 100, {"frequency": p(1.0), "amplitude": p(64.0), "offset": p(64.0)})},
            extra_conns=[conn("lfo1", 0, "rtmidi_out1", 0)],
            annotation_text="RtMidi Out — Basic\n\nSends LFO as MIDI CC.\nRequires gn_ext_midi DLL.")),
        ("rtmidiout_notes", build_chop_chain("rtmidi_out1",
            node("RtMidiOutCHOP", 400, 100, {}),
            extra_nodes={"beat1": node("BeatCHOP", 100, 100, {"bpm": p(120.0)})},
            extra_conns=[conn("beat1", 0, "rtmidi_out1", 0)],
            annotation_text="RtMidi Out — Beat Notes\n\nBeat triggers MIDI note output.\nCreates rhythmic MIDI sequence.")),
        ("rtmidiout_cc", build_chop_chain("rtmidi_out1",
            node("RtMidiOutCHOP", 400, 100, {}),
            extra_nodes={"noise1": node("NoiseCHOP", 100, 100, {"amplitude": p(64.0), "roughness": p(0.3)})},
            extra_conns=[conn("noise1", 0, "rtmidi_out1", 0)],
            annotation_text="RtMidi Out — Noise CC\n\nSmooth noise drives MIDI CC values.\nOrganic parameter control.")),
    ]

    return patches
