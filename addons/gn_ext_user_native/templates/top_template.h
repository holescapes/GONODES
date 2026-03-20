/*  TOP Template — Minimal starting point for a UserNativeTOP.
 *  Generates a solid colour with animated alpha.
 */
#ifndef USER_TOP_TEMPLATE_H
#define USER_TOP_TEMPLATE_H

#include <gn_user_node.h>
#include <gn_user_top.h>

using namespace godot;

class MyUserTOP : public gn::GNUserNode {
	GDCLASS(MyUserTOP, gn::GNUserNode)
protected:
	static void _bind_methods() { gn::GNUserNode::_bind_methods(); }
public:
	String get_node_type() const override { return "my_user_top"; }
	String get_node_description() const override { return "My custom TOP."; }

	Array get_port_definitions() const override {
		Array ports;
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "TOP"; out0["direction"] = "output";
		out0["label"] = "Output texture";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::parc("color", Color(0.2, 0.6, 1.0, 1.0),
			"Color", "Output color."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		Color color = params.get("color", Color(0.2, 0.6, 1.0, 1.0));
		float elapsed = parf(context, "elapsed", 0.0);

		String shader = R"(
shader_type canvas_item;
uniform vec4 u_color : source_color;
uniform float u_time;
void fragment() {
	COLOR = vec4(u_color.rgb, abs(sin(u_time)));
}
)";
		Dictionary uniforms;
		uniforms["u_color"] = color;
		uniforms["u_time"] = elapsed;
		return gn::make_top_shader_result(shader, uniforms);
	}
};

#endif
