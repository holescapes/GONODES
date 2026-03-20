/*  CHOP Template — Minimal starting point for a UserNativeCHOP.
 *  Generates a single sine wave channel.
 */
#ifndef USER_CHOP_TEMPLATE_H
#define USER_CHOP_TEMPLATE_H

#include <gn_user_node.h>
#include <gn_user_chop.h>

using namespace godot;

class MyUserCHOP : public gn::GNUserNode {
	GDCLASS(MyUserCHOP, gn::GNUserNode)
protected:
	static void _bind_methods() { gn::GNUserNode::_bind_methods(); }
public:
	String get_node_type() const override { return "my_user_chop"; }
	String get_node_description() const override { return "My custom CHOP."; }

	Array get_port_definitions() const override {
		Array ports;
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "CHOP"; out0["direction"] = "output";
		out0["label"] = "Output channels";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::parf("frequency", 1.0, 0.01, 100.0, 0.01,
			"Frequency", "Oscillation frequency in Hz."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		float freq = parf(params, "frequency", 1.0);
		float elapsed = parf(context, "elapsed", 0.0);
		PackedFloat32Array arr;
		arr.push_back(sin(elapsed * freq * Math_TAU));
		return gn::make_chop_single("value", arr);
	}
};

#endif
