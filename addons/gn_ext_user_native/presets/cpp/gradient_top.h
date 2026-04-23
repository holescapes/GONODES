/*  gradient_top.h — Example UserNativeTOP
 *  Generates gradient textures via GPU shader: linear, radial, angular, diamond.
 *  Demonstrates: enum, vector2, color parameter types.
 *  Load this via: UserNativeTOP → Templates → Examples → Gradient Generator
 */
#ifndef GRADIENT_TOP_H
#define GRADIENT_TOP_H

#include <gn_user_node.h>
#include <gn_user_top.h>

using namespace godot;

class GradientTOP : public gn::GNUserNode {
	GDCLASS(GradientTOP, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "gradient_top"; }
	String get_node_description() const override {
		return "Generates linear, radial, angular, or diamond gradients as a GPU shader.";
	}

	Array get_port_definitions() const override {
		Array ports;
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "TOP"; out0["direction"] = "output";
		out0["label"] = "Gradient texture";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		// enum — gradient type
		PackedStringArray types;
		types.push_back("Linear");
		types.push_back("Radial");
		types.push_back("Angular");
		types.push_back("Diamond");
		params.push_back(gn::pare("gradient_type", types, 0,
			"Type", "Gradient shape."));
		// vector2 — center point for radial/angular/diamond
		params.push_back(gn::make_vector2("center", Vector2(0.5, 0.5),
			"Center", "Center point for radial, angular, and diamond modes (0-1 UV space)."));
		// float — rotation for linear gradient
		params.push_back(gn::parf("angle", 0.0, 0.0, 360.0, 1.0,
			"Angle", "Rotation angle for linear gradient (degrees)."));
		// colors
		params.push_back(gn::make_color("color_a", Color(0.0, 0.0, 0.0, 1.0),
			"Color A", "Start color of the gradient."));
		params.push_back(gn::make_color("color_b", Color(1.0, 1.0, 1.0, 1.0),
			"Color B", "End color of the gradient."));
		// float — hardness for shaping the falloff
		params.push_back(gn::parf("hardness", 1.0, 0.1, 10.0, 0.1,
			"Hardness", "Exponent applied to the gradient (1.0 = linear, >1 = sharper)."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		int     type     = pari(params, "gradient_type", 0);
		Vector2 center   = params.get("center", Vector2(0.5, 0.5));
		float   angle    = parf(params, "angle", 0.0);
		Color   color_a  = params.get("color_a", Color(0, 0, 0, 1));
		Color   color_b  = params.get("color_b", Color(1, 1, 1, 1));
		float   hardness = parf(params, "hardness", 1.0);

		// Build a fragment shader that computes the gradient on GPU
		String shader = R"(
shader_type canvas_item;
uniform vec4 u_color_a : source_color;
uniform vec4 u_color_b : source_color;
uniform vec2 u_center;
uniform float u_angle;
uniform float u_hardness;
uniform int u_type; // 0=linear, 1=radial, 2=angular, 3=diamond

void fragment() {
	float t = 0.0;
	vec2 uv = UV;

	if (u_type == 0) {
		// Linear: rotate UV and use x-axis
		float rad = radians(u_angle);
		vec2 d = vec2(cos(rad), sin(rad));
		t = dot(uv - u_center, d) + 0.5;
	} else if (u_type == 1) {
		// Radial: distance from center
		t = length(uv - u_center) * 2.0;
	} else if (u_type == 2) {
		// Angular: angle around center (0-1)
		vec2 delta = uv - u_center;
		t = (atan(delta.y, delta.x) / 6.28318530718) + 0.5;
	} else {
		// Diamond: manhattan distance from center
		vec2 delta = abs(uv - u_center);
		t = (delta.x + delta.y);
	}

	t = clamp(t, 0.0, 1.0);
	t = pow(t, u_hardness);
	COLOR = mix(u_color_a, u_color_b, t);
}
)";

		Dictionary uniforms;
		uniforms["u_color_a"]  = color_a;
		uniforms["u_color_b"]  = color_b;
		uniforms["u_center"]   = center;
		uniforms["u_angle"]    = angle;
		uniforms["u_hardness"] = hardness;
		uniforms["u_type"]     = type;

		return gn::make_top_shader_result(shader, uniforms);
	}
};

#endif // GRADIENT_TOP_H
