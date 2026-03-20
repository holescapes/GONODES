/*  life_top.h — Example UserNativeTOP
 *  Conway's Game of Life running on GPU via generated shader code.
 *  Load this via: UserNativeTOP → Templates → Examples → Game of Life
 */
#ifndef LIFE_TOP_H
#define LIFE_TOP_H

#include <gn_user_node.h>
#include <gn_user_top.h>

using namespace godot;

class LifeTOP : public gn::GNUserNode {
	GDCLASS(LifeTOP, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "life_top"; }
	String get_node_description() const override {
		return "Conway's Game of Life as a GPU shader — feed back into itself for evolution.";
	}

	Array get_port_definitions() const override {
		Array ports;
		Dictionary in0;
		in0["name"] = "state"; in0["family"] = "TOP"; in0["direction"] = "input";
		in0["required"] = false; in0["label"] = "Previous state (feedback)";
		ports.push_back(in0);
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "TOP"; out0["direction"] = "output";
		out0["label"] = "Next state";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::parc("alive_color", Color(0.0, 1.0, 0.3, 1.0),
			"Alive Color", "Color of living cells."));
		params.push_back(gn::parc("dead_color", Color(0.05, 0.05, 0.1, 1.0),
			"Dead Color", "Color of dead cells."));
		params.push_back(gn::parf("threshold", 0.5, 0.0, 1.0, 0.01,
			"Threshold", "Luminance threshold to consider a cell alive."));
		params.push_back(gn::parf("seed_density", 0.3, 0.0, 1.0, 0.01,
			"Seed Density", "Random fill density when no input is connected."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		Color alive  = params.get("alive_color", Color(0.0, 1.0, 0.3, 1.0));
		Color dead   = params.get("dead_color", Color(0.05, 0.05, 0.1, 1.0));
		float thresh = parf(params, "threshold", 0.5);
		float seed_d = parf(params, "seed_density", 0.3);
		float frame  = parf(context, "frame", 0.0);

		String shader = R"(
shader_type canvas_item;
uniform sampler2D u_state;    // previous frame (feedback)
uniform vec4 u_alive : source_color;
uniform vec4 u_dead : source_color;
uniform float u_threshold;
uniform float u_seed_density;
uniform float u_frame;

// Simple hash for seeding
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;

	// Count alive neighbours
	int count = 0;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			if (dx == 0 && dy == 0) continue;
			vec4 n = texture(u_state, UV + vec2(float(dx), float(dy)) * px);
			float lum = dot(n.rgb, vec3(0.299, 0.587, 0.114));
			if (lum > u_threshold) count++;
		}
	}

	vec4 cell = texture(u_state, UV);
	float lum = dot(cell.rgb, vec3(0.299, 0.587, 0.114));
	bool alive = lum > u_threshold;

	// First frame: seed randomly
	if (u_frame < 1.5) {
		alive = hash(UV * 1000.0) < u_seed_density;
	} else {
		// Conway rules: B3/S23
		if (alive) {
			alive = (count == 2 || count == 3);
		} else {
			alive = (count == 3);
		}
	}

	COLOR = alive ? u_alive : u_dead;
}
)";

		Dictionary uniforms;
		uniforms["u_alive"]        = alive;
		uniforms["u_dead"]         = dead;
		uniforms["u_threshold"]    = thresh;
		uniforms["u_seed_density"] = seed_d;
		uniforms["u_frame"]        = frame;

		return gn::make_top_shader_result(shader, uniforms);
	}
};

#endif // LIFE_TOP_H
