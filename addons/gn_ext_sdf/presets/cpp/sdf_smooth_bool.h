/*  sdf_smooth_bool.h — Example UserNative SDF boolean
 *  Smooth-unions two input SDF trees.
 *  Demonstrates SDF input reading and output building.
 */
#ifndef SDF_SMOOTH_BOOL_H
#define SDF_SMOOTH_BOOL_H

#include <gn_user_node.h>
#include <gn_user_sdf.h>

using namespace godot;

class SDFSmoothBoolNative : public gn::GNUserNode {
	GDCLASS(SDFSmoothBoolNative, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "sdf_smooth_bool_native"; }
	String get_node_description() const override {
		return "Smooth-unions two SDF inputs with configurable blending.";
	}

	Array get_port_definitions() const override {
		Array ports;
		Dictionary in0;
		in0["name"] = "sdf_a"; in0["family"] = "SDF"; in0["direction"] = "input";
		in0["label"] = "First SDF shape";
		ports.push_back(in0);
		Dictionary in1;
		in1["name"] = "sdf_b"; in1["family"] = "SDF"; in1["direction"] = "input";
		in1["label"] = "Second SDF shape";
		ports.push_back(in1);
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "SDF"; out0["direction"] = "output";
		out0["label"] = "Combined SDF";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::parf("smoothness", 0.5, 0.0, 10.0, 0.01,
			"Smoothness", "Blending radius for smooth union."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		float smooth = parf(params, "smoothness", 0.5);

		Dictionary a = gn::get_input_sdf(inputs, 0);
		Dictionary b = gn::get_input_sdf(inputs, 1);

		if (a.is_empty() && b.is_empty())
			return Dictionary();
		if (a.is_empty())
			return gn::make_sdf_result(b);
		if (b.is_empty())
			return gn::make_sdf_result(a);

		Dictionary tree = gn::sdf_smooth_union(a, b, smooth);
		return gn::make_sdf_result(tree);
	}
};

#endif // SDF_SMOOTH_BOOL_H
