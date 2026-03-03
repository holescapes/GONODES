# Ramp CHOP

Outputs named CHOP channels by sampling user-editable ramp curves.

## Overview

The Ramp CHOP lets you create **1–16 ramp curves** and output each as a
named CHOP channel.  This is the primary way to get an arbitrary number of
ramp parameters into your network — instead of hardcoding ramp params in an
operator's `_init_parameters()`, you wire a Ramp CHOP into the signal chain
and read its output via `chop()` expressions.

## Dynamic Ramp Count

The **Count** parameter controls how many ramp slots exist.  Changing it
at runtime instantly adds or removes the corresponding `nameN` / `rampN`
parameter pairs.  The inspector rebuilds live — no restart needed.

- **Increasing** count: new slots appear with default linear ramps (0→1)
- **Decreasing** count: excess slots are removed (data is lost)
- **Serialization**: the saved count is restored before parameter values,
  so all slots exist when the patch loads

## Samples Parameter

| Samples | Behaviour |
|---------|-----------|
| **1** (default) | Evaluates each ramp at `t = 1.0` and outputs a single float per channel.  This is the scalar mode — ideal for reading via `chop("ramp1", "falloff")`. |
| **N > 1** | Evaluates each ramp at N evenly-spaced points from `t = 0.0` to `t = 1.0`.  Outputs a full multi-sample channel — useful for lookup tables, gradients, or waveform shaping. |

## Typical Workflows

### Scalar ramp values (default)
```
RampCHOP("curves")  →  chop("curves", "falloff") in any expression
```
Keep `samples = 1`.  Each ramp outputs a single float (the end-of-curve value).

### Multi-sample lookup table
```
RampCHOP("lut", samples=256)  →  wire into a LookupTOP or read via chop("lut", "ramp0", index)
```
Set `samples` to your desired resolution.  Each ramp becomes a full curve array.

### Multiple independent curves
```
RampCHOP(count=8, samples=1)  →  8 named scalar channels, each with its own curve shape
```
Name each slot descriptively (`brightness`, `falloff`, `attack`, etc.) and
reference by name from any expression.

## Tips

- Empty channel names are **skipped** — leave a name blank to disable a slot
  without changing the count.
- Ramp data is **per-node** — each Ramp CHOP instance has its own independent curves.
- Ramps use **cubic Hermite interpolation** between keypoints (same as the
  `ramp()` expression function and the RAMP parameter type).
