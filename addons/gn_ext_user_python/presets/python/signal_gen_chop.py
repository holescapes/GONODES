"""
Signal Generator CHOP — Example: Multi-channel oscillator.

Demonstrates:
  - Generating multiple CHOP channels with NumPy
  - Waveform selection via enum parameter
  - Sample rate control
  - Phase offset per channel
"""

from gonodes.chop import make_chop_result
from gonodes.params import output_port, float_param, int_param, enum_param
import numpy as np


def get_port_definitions():
    return {"ports": [
        output_port("out", "CHOP", label="Generated signals"),
    ]}


def get_param_definitions():
    return {"params": [
        enum_param("waveform", ["sine", "square", "sawtooth", "triangle"],
                    0, "Waveform", "Oscillator shape."),
        float_param("frequency", 1.0, 0.01, 100.0, 0.01, "Frequency", "Hz"),
        int_param("num_channels", 3, 1, 64, "Channels"),
        int_param("num_samples", 60, 1, 4096, "Samples", "Samples per channel."),
        float_param("amplitude", 1.0, 0.0, 10.0, 0.01, "Amplitude"),
    ]}


_WAVEFORMS = ["sine", "square", "sawtooth", "triangle"]


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    waveform_idx = int(params.get("waveform", 0))
    waveform = _WAVEFORMS[waveform_idx] if waveform_idx < len(_WAVEFORMS) else "sine"
    freq = params.get("frequency", 1.0)
    num_ch = int(params.get("num_channels", 3))
    num_samp = int(params.get("num_samples", 60))
    amp = params.get("amplitude", 1.0)
    t = context.get("elapsed", 0.0)

    channels = {}
    for i in range(num_ch):
        phase = i / num_ch * 2.0 * np.pi
        x = np.linspace(t, t + 1.0 / freq, num_samp, dtype=np.float32)
        angle = x * freq * 2.0 * np.pi + phase

        if waveform == "sine":
            samples = np.sin(angle)
        elif waveform == "square":
            samples = np.sign(np.sin(angle))
        elif waveform == "sawtooth":
            samples = 2.0 * (angle / (2.0 * np.pi) % 1.0) - 1.0
        elif waveform == "triangle":
            samples = 2.0 * np.abs(2.0 * (angle / (2.0 * np.pi) % 1.0) - 1.0) - 1.0
        else:
            samples = np.sin(angle)

        channels[f"ch{i}"] = (samples * amp).astype(np.float32)

    return make_chop_result(channels, sample_rate=num_samp)
