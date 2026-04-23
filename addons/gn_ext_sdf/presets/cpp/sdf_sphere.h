/*  sdf_sphere.h — Example UserNative SDF primitive
 *  Generates a sphere SDF tree node.
 *  Connect output to RaymarchSDF → WindowOUT to visualize.
 */
#ifndef SDF_SPHERE_H
#define SDF_SPHERE_H

#include <gn_user_node.h>
#include <gn_user_sdf.h>

using namespace godot;

class SDFSphereNative : public gn::GNUserNode {
	GDCLASS(SDFSphereNative, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "sdf_sphere_native"; }
	String get_node_description() const override {
		return "Generates an SDF sphere primitive with position and radius.";
	}

	Array get_port_definitions() const override {
		Array ports;
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "SDF"; out0["direction"] = "output";
		out0["label"] = "SDF sphere";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::parf("radius", 1.0, 0.01, 100.0, 0.01,
			"Radius", "Sphere radius."));
		params.push_back(gn::make_vector3("position", Vector3(0.0, 0.0, 0.0),
			-100.0, 100.0, 0.01, "Position", "Sphere center offset."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		float radius = parf(params, "radius", 1.0);
		Vector3 pos  = parv3(params, "position", Vector3());

		Dictionary tree = gn::sdf_sphere(radius, pos);
		return gn::make_sdf_result(tree);
	}
};

#endif // SDF_SPHERE_H
