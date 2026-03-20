"""
gonodes.chop — CHOP family helpers.

Builds result dicts that the C++ bridge converts back to GNChannelData.
"""

import numpy as np


def make_chop_result(channels, sample_rate=60.0):
    """Build a multi-channel CHOP result.

    Args:
        channels: dict mapping channel_name -> ndarray float32 of samples.
        sample_rate: samples per second.

    Returns:
        dict ready for the C++ bridge.
    """
    result = {"sample_rate": float(sample_rate), "channels": {}}
    for name, data in channels.items():
        result["channels"][str(name)] = np.ascontiguousarray(
            data, dtype=np.float32).ravel()
    return result


def make_chop_single(names, values):
    """Build a CHOP with one sample per channel.

    Args:
        names:  list of channel name strings.
        values: list of float values (same length as names).

    Returns:
        dict ready for the C++ bridge.
    """
    channels = {}
    for name, val in zip(names, values):
        channels[str(name)] = np.array([float(val)], dtype=np.float32)
    return make_chop_result(channels)


def get_input_channel(inputs, index, channel_name, fallback=None):
    """Get a named channel from an input CHOP.

    Returns:
        ndarray float32 of samples, or fallback if not found.
    """
    if index >= len(inputs) or inputs[index] is None:
        return fallback
    ch = inputs[index].get("channels", {})
    if channel_name not in ch:
        return fallback
    return np.asarray(ch[channel_name], dtype=np.float32)


def get_input_value(inputs, index, channel_name, fallback=0.0):
    """Get the first sample of a named channel (scalar shortcut)."""
    arr = get_input_channel(inputs, index, channel_name)
    if arr is None or len(arr) == 0:
        return fallback
    return float(arr[0])
