"""
Signal Stats — Example: Multi-output (CHOP + DAT).

Demonstrates:
  - Multi-output: cook() returns make_multi_output(chop, dat)
  - Port 0: CHOP with sine signal channels
  - Port 1: DAT with signal statistics table
"""

from gonodes import make_multi_output
from gonodes.chop import make_chop_result
from gonodes.dat import make_dat_result
from gonodes.params import output_port, float_param, int_param
import numpy as np


def get_port_definitions():
    return {"ports": [
        output_port("signal", "CHOP", label="Generated signal"),
        output_port("stats", "DAT", label="Signal statistics"),
    ]}


def get_param_definitions():
    return {"params": [
        float_param("frequency", 2.0, 0.01, 100.0, 0.01, "Frequency", "Hz"),
        float_param("amplitude", 1.0, 0.0, 10.0, 0.01, "Amplitude"),
        int_param("length", 60, 1, 4096, "Samples", "Samples per channel."),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    freq = params.get("frequency", 2.0)
    amp = params.get("amplitude", 1.0)
    length = int(params.get("length", 60))
    elapsed = context.get("elapsed", 0.0)

    # --- Port 0: CHOP signal ---
    t = np.linspace(elapsed, elapsed + 1.0, length, dtype=np.float32)
    samples = (np.sin(t * freq * 2.0 * np.pi) * amp).astype(np.float32)

    chop = make_chop_result({"signal": samples}, sample_rate=length)

    # --- Port 1: DAT statistics ---
    dat = make_dat_result(
        header=["metric", "value"],
        rows=[
            ["min", f"{float(samples.min()):.4f}"],
            ["max", f"{float(samples.max()):.4f}"],
            ["avg", f"{float(samples.mean()):.4f}"],
            ["amplitude", f"{amp:.4f}"],
            ["frequency", f"{freq:.4f}"],
            ["samples", str(length)],
        ],
    )

    # --- Return multi-output ---
    return make_multi_output(chop, dat)
