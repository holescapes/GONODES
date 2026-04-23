/*  sdf_procedural_scene.h — Example UserNative SDF scene
 *  Builds a complete procedural SDF scene: smooth union of twisted sphere + box.
 *  Demonstrates SDF SDK tree construction, booleans, modifiers, and materials.
 *  Connect output to RaymarchSDF → WindowOUT to visualize.
 */
#ifndef SDF_PROCEDURAL_SCENE_H
#define SDF_PROCEDURAL_SCENE_H

#include <gn_user_node.h>
#include <gn_user_sdf.h>

using namespace godot;

class SDFProceduralScene : public gn::GNUserNode {
	GDCLASS(SDFProceduralScene, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "sdf_procedural_scene"; }
	String get_node_description() const override {
		return "Procedural SDF scene: twisted sphere + box with materials.";
	}

	Array get_port_definitions() const override {
		Array ports;
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "SDF"; out0["direction"] = "output";
		out0["label"] = "SDF scene";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::parf("twist_amount", 2.0, 0.0, 20.0, 0.1,
			"Twist Amount", "Twist around Y axis."));
		params.push_back(gn::parf("sphere_radius", 0.8, 0.1, 10.0, 0.01,
			"Sphere Radius", "Radius of the sphere."));
		params.push_back(gn::parf("box_size", 0.6, 0.1, 10.0, 0.01,
			"Box Size", "Box half-size."));
		params.push_back(gn::parf("smoothness", 0.3, 0.0, 5.0, 0.01,
			"Smoothness", "Smooth union blending."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		float twist  = parf(params, "twist_amount", 2.0);
		float sph_r  = parf(params, "sphere_radius", 0.8);
		float box_sz = parf(params, "box_size", 0.6);
		float smooth = parf(params, "smoothness", 0.3);

		// Sphere → Material → Twist
		Dictionary sphere = gn::sdf_sphere(sph_r);
		Dictionary mat_sphere = gn::sdf_material(sphere,
			Color(0.9, 0.2, 0.1), 0.3, 0.0, 0.0);
		Dictionary twisted = gn::sdf_twist(mat_sphere, twist);

		// Box with material
		Dictionary box = gn::sdf_box(
			Vector3(box_sz, box_sz, box_sz),
			Vector3(1.5, 0.0, 0.0));
		Dictionary mat_box = gn::sdf_material(box,
			Color(0.1, 0.3, 0.9), 0.6, 0.8, 0.0);

		// Smooth union
		Dictionary tree = gn::sdf_smooth_union(twisted, mat_box, smooth);
		return gn::make_sdf_result(tree);
	}
};

#endif // SDF_PROCEDURAL_SCENE_H
