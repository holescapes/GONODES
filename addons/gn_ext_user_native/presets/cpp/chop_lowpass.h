/*  chop_lowpass.h — Example UserNativeCHOP
 *  Stateful IIR lowpass filter: smooths all incoming CHOP channels.
 *  Demonstrates native_setup() for state initialization and CHOP input reading.
 *  Load this via: UserNativeCHOP → Templates → Examples → Lowpass Filter
 */
#ifndef CHOP_LOWPASS_H
#define CHOP_LOWPASS_H

#include <gn_user_node.h>
#include <gn_user_chop.h>
#include <cmath>
#include <map>
#include <vector>

using namespace godot;

class CHOPLowpass : public gn::GNUserNode {
	GDCLASS(CHOPLowpass, gn::GNUserNode)

	// Per-channel state: previous filtered values
	std::map<std::string, std::vector<float>> _prev;

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "chop_lowpass"; }
	String get_node_description() const override {
		return "Stateful IIR lowpass filter: smooths incoming CHOP channels over time.";
	}

	Array get_port_definitions() const override {
		Array ports;
		Dictionary in0;
		in0["name"] = "in";  in0["family"] = "CHOP"; in0["direction"] = "input";
		in0["required"] = true; in0["label"] = "Input channels";
		ports.push_back(in0);
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "CHOP"; out0["direction"] = "output";
		out0["label"] = "Filtered channels";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::parf("cutoff", 5.0, 0.01, 100.0, 0.01,
			"Cutoff", "Cutoff frequency in Hz. Lower = smoother."));
		params.push_back(gn::parb("reset", false,
			"Reset", "Clear filter state."));
		return params;
	}

	void native_setup(const Dictionary &context) override {
		_prev.clear();
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		float cutoff = parf(params, "cutoff", 5.0);
		bool  reset  = parb(params, "reset", false);
		float dt     = parf(context, "dt", 1.0f / 60.0f);

		if (reset) {
			_prev.clear();
		}

		// IIR coefficient: alpha = dt / (RC + dt), RC = 1/(2*PI*cutoff)
		float rc    = 1.0f / (Math_TAU * fmaxf(cutoff, 0.001f));
		float alpha = dt / (rc + dt);

		// Read all channels from input 0
		if (inputs.size() == 0)
			return Dictionary();

		Dictionary in_dict = inputs[0];
		if (!in_dict.has("channels"))
			return Dictionary();

		Dictionary in_channels = in_dict["channels"];
		Dictionary out_channels;
		Array keys = in_channels.keys();

		for (int k = 0; k < keys.size(); k++) {
			String ch_name = keys[k];
			PackedFloat32Array samples = in_channels[ch_name];
			int len = samples.size();

			std::string key(ch_name.utf8().get_data());

			// Initialize state if missing
			if (_prev.find(key) == _prev.end() || (int)_prev[key].size() != len) {
				_prev[key].resize(len);
				for (int s = 0; s < len; s++)
					_prev[key][s] = samples[s];
			}

			PackedFloat32Array filtered;
			filtered.resize(len);

			for (int s = 0; s < len; s++) {
				float y = alpha * samples[s] + (1.0f - alpha) * _prev[key][s];
				filtered.write[s] = y;
				_prev[key][s] = y;
			}

			out_channels[ch_name] = filtered;
		}

		return gn::make_chop_result(out_channels);
	}
};

#endif // CHOP_LOWPASS_H
