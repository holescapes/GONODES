/*  multi_signal_stats.h — Example UserNative multi-output
 *  Generates a sine wave (CHOP) and outputs statistics (DAT).
 *  Demonstrates multi-output: native_cook() returns {"outputs": [...]}.
 *  Load this via: UserNativeSCRIPT → Templates → Examples → Signal Stats
 */
#ifndef MULTI_SIGNAL_STATS_H
#define MULTI_SIGNAL_STATS_H

#include <gn_user_node.h>
#include <gn_user_chop.h>
#include <gn_user_dat.h>
#include <cmath>

using namespace godot;

class MultiSignalStats : public gn::GNUserNode {
	GDCLASS(MultiSignalStats, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "multi_signal_stats"; }
	String get_node_description() const override {
		return "Generates a sine signal (CHOP out 0) and its statistics (DAT out 1).";
	}

	Array get_port_definitions() const override {
		Array ports;
		Dictionary out0;
		out0["name"] = "signal"; out0["family"] = "CHOP"; out0["direction"] = "output";
		out0["label"] = "Generated signal";
		ports.push_back(out0);
		Dictionary out1;
		out1["name"] = "stats"; out1["family"] = "DAT"; out1["direction"] = "output";
		out1["label"] = "Signal statistics";
		ports.push_back(out1);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::parf("frequency", 2.0, 0.01, 100.0, 0.01,
			"Frequency", "Oscillation frequency in Hz."));
		params.push_back(gn::parf("amplitude", 1.0, 0.0, 10.0, 0.01,
			"Amplitude", "Peak amplitude."));
		params.push_back(gn::pari("length", 60, 1, 4096,
			"Length", "Samples per channel."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		float freq    = parf(params, "frequency", 2.0);
		float amp     = parf(params, "amplitude", 1.0);
		int   length  = pari(params, "length", 60);
		float elapsed = parf(context, "elapsed", 0.0);

		// --- Port 0: CHOP signal ---
		PackedFloat32Array samples;
		samples.resize(length);
		float sum = 0.0f, mn = 1e9f, mx = -1e9f;
		for (int s = 0; s < length; s++) {
			float t = elapsed + float(s) / fmax(float(length), 1.0f);
			float val = sinf(t * freq * Math_TAU) * amp;
			samples.write[s] = val;
			sum += val;
			if (val < mn) mn = val;
			if (val > mx) mx = val;
		}

		Dictionary channels;
		channels["signal"] = samples;
		Dictionary chop_result = gn::make_chop_result(channels);

		// --- Port 1: DAT statistics ---
		float avg = length > 0 ? sum / float(length) : 0.0f;
		PackedStringArray headers;
		headers.push_back("metric");
		headers.push_back("value");
		Array rows;
		auto add_row = [&](const String &name, float val) {
			PackedStringArray row;
			row.push_back(name);
			row.push_back(String::num(val, 4));
			rows.push_back(row);
		};
		add_row("min", mn);
		add_row("max", mx);
		add_row("avg", avg);
		add_row("amplitude", amp);
		add_row("frequency", freq);
		add_row("samples", float(length));
		Dictionary dat_result = gn::make_dat_table(headers, rows);

		// --- Return multi-output ---
		Array outputs;
		outputs.push_back(chop_result);
		outputs.push_back(dat_result);
		return gn::make_multi_output(outputs);
	}
};

#endif // MULTI_SIGNAL_STATS_H
