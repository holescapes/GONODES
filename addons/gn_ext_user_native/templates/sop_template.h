/*  SOP Template — Minimal starting point for a UserNativeSOP.
 *  Generates a flat grid of points.
 */
#ifndef USER_SOP_TEMPLATE_H
#define USER_SOP_TEMPLATE_H

#include <gn_user_node.h>
#include <gn_user_sop.h>

using namespace godot;

class MyUserSOP : public gn::GNUserNode {
	GDCLASS(MyUserSOP, gn::GNUserNode)
protected:
	static void _bind_methods() { gn::GNUserNode::_bind_methods(); }
public:
	String get_node_type() const override { return "my_user_sop"; }
	String get_node_description() const override { return "My custom SOP."; }

	Array get_port_definitions() const override {
		Array ports;
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "SOP"; out0["direction"] = "output";
		out0["label"] = "Output geometry";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::pari("resolution", 10, 2, 256,
			"Resolution", "Grid resolution (NxN)."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		int res = pari(params, "resolution", 10);
		PackedVector3Array positions;
		for (int z = 0; z < res; z++) {
			for (int x = 0; x < res; x++) {
				float fx = float(x) / float(res - 1) - 0.5f;
				float fz = float(z) / float(res - 1) - 0.5f;
				positions.push_back(Vector3(fx, 0.0f, fz));
			}
		}
		return gn::make_point_cloud(positions);
	}
};

#endif
