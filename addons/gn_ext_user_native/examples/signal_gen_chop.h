/*  signal_gen_chop.h — Example UserNativeCHOP
 *  Multi-waveform signal generator: sine, saw, square, triangle, noise.
 *  Load this via: UserNativeCHOP → Templates → Examples → Signal Generator
 */
#ifndef SIGNAL_GEN_CHOP_H
#define SIGNAL_GEN_CHOP_H

#include <gn_user_node.h>
#include <gn_user_chop.h>
#include <cmath>

using namespace godot;

class SignalGenCHOP : public gn::GNUserNode {
	GDCLASS(SignalGenCHOP, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "signal_gen_chop"; }
	String get_node_description() const override {
		return "Generates multi-channel waveforms: sine, saw, square, triangle, noise.";
	}

	Array get_port_definitions() const override {
		Array ports;
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "CHOP"; out0["direction"] = "output";
		out0["label"] = "Generated signal";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::pari("waveform", 0, 0, 4,
			"Waveform", "0=Sine, 1=Saw, 2=Square, 3=Triangle, 4=Noise"));
		params.push_back(gn::parf("frequency", 1.0, 0.01, 100.0, 0.01,
			"Frequency", "Oscillation frequency in Hz."));
		params.push_back(gn::parf("amplitude", 1.0, 0.0, 10.0, 0.01,
			"Amplitude", "Peak amplitude."));
		params.push_back(gn::parf("offset", 0.0, -10.0, 10.0, 0.01,
			"DC Offset", "Constant offset added to signal."));
		params.push_back(gn::pari("channels", 1, 1, 64,
			"Channels", "Number of output channels."));
		params.push_back(gn::parf("phase_spread", 0.0, 0.0, 1.0, 0.01,
			"Phase Spread", "Phase offset between successive channels (0-1 = 0-360°)."));
		params.push_back(gn::pari("length", 1, 1, 44100,
			"Length", "Samples per channel."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		int   wave      = pari(params, "waveform", 0);
		float freq      = parf(params, "frequency", 1.0);
		float amp       = parf(params, "amplitude", 1.0);
		float offset    = parf(params, "offset", 0.0);
		int   num_ch    = pari(params, "channels", 1);
		float spread    = parf(params, "phase_spread", 0.0);
		int   length    = pari(params, "length", 1);
		float elapsed   = parf(context, "elapsed", 0.0);

		Dictionary channels;

		for (int c = 0; c < num_ch; c++) {
			PackedFloat32Array arr;
			arr.resize(length);

			float phase_off = float(c) * spread * Math_TAU;

			for (int s = 0; s < length; s++) {
				// time base: elapsed + sample offset for multi-sample
				float t = elapsed + float(s) / fmax(44100.0f, 1.0f);
				float phase = t * freq * Math_TAU + phase_off;
				float val = 0.0f;

				switch (wave) {
					case 0: // Sine
						val = sinf(phase);
						break;
					case 1: // Saw
						val = 2.0f * (fmodf(phase / Math_TAU, 1.0f)) - 1.0f;
						break;
					case 2: // Square
						val = sinf(phase) >= 0.0f ? 1.0f : -1.0f;
						break;
					case 3: { // Triangle
						float saw = fmodf(phase / Math_TAU + 0.25f, 1.0f);
						val = 4.0f * fabsf(saw - 0.5f) - 1.0f;
						break;
					}
					case 4: { // Noise (deterministic hash-based)
						int seed = int(phase * 10000.0f) ^ (c * 7919);
						seed = (seed ^ 61) ^ (seed >> 16);
						seed *= 9;
						seed = seed ^ (seed >> 4);
						seed *= 0x27d4eb2d;
						seed = seed ^ (seed >> 15);
						val = float(seed % 10000) / 5000.0f - 1.0f;
						break;
					}
				}

				arr.write[s] = val * amp + offset;
			}

			channels[String("ch") + String::num_int64(c)] = arr;
		}

		return gn::make_chop_result(channels);
	}
};

#endif // SIGNAL_GEN_CHOP_H
