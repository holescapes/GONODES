/*  scatter_sop.h — Example UserNativeSOP
 *  Scatters points in a region around a center position.
 *  Demonstrates: vector3, vector2, enum parameter types.
 *  Load this via: UserNativeSOP → Templates → Examples → Point Scatter
 */
#ifndef SCATTER_SOP_H
#define SCATTER_SOP_H

#include <gn_user_node.h>
#include <gn_user_sop.h>

using namespace godot;

class ScatterSOP : public gn::GNUserNode {
	GDCLASS(ScatterSOP, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "scatter_sop"; }
	String get_node_description() const override {
		return "Scatters points in a volume around a center, with uniform, spherical, or cubic distribution.";
	}

	Array get_port_definitions() const override {
		Array ports;
		Dictionary out0;
		out0["name"] = "pts_out"; out0["family"] = "SOP"; out0["direction"] = "output";
		out0["label"] = "Scattered points";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		// vector3 — the user will see 3 float sliders (center_x, center_y, center_z)
		// but native_cook receives a single Vector3 via parv3("center")
		params.push_back(gn::make_vector3("center", Vector3(0, 0, 0), -50.0, 50.0, 0.1,
			"Center", "Center point of the scatter region."));
		// vector2 — radius range (min, max)
		params.push_back(gn::make_vector2("radius_range", Vector2(0.5, 2.0),
			"Radius Range", "Min/max scatter radius (X=min, Y=max)."));
		// enum — distribution shape
		PackedStringArray modes;
		modes.push_back("Sphere");
		modes.push_back("Cube");
		modes.push_back("Disc (XZ)");
		params.push_back(gn::pare("distribution", modes, 0,
			"Distribution", "Shape of the scatter region."));
		params.push_back(gn::pari("count", 500, 1, 100000,
			"Point Count", "Number of points to scatter."));
		params.push_back(gn::pari("seed", 42, 0, 99999,
			"Seed", "Random seed for reproducibility."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		Vector3 center  = parv3(params, "center", Vector3(0, 0, 0));
		Vector2 rad_rng = params.get("radius_range", Vector2(0.5, 2.0));
		int     mode    = pari(params, "distribution", 0);
		int     count   = pari(params, "count", 500);
		int     seed    = pari(params, "seed", 42);

		float r_min = rad_rng.x;
		float r_max = rad_rng.y;
		if (r_min > r_max) { float tmp = r_min; r_min = r_max; r_max = tmp; }

		PackedVector3Array positions;
		PackedVector3Array normals;
		PackedColorArray   colors;
		positions.resize(count);
		normals.resize(count);
		colors.resize(count);

		// Simple LCG for deterministic results
		uint32_t rng = (uint32_t)seed;
		auto next_f = [&]() -> float {
			rng = rng * 1664525u + 1013904223u;
			return float(rng & 0xFFFFFF) / float(0xFFFFFF);
		};

		for (int i = 0; i < count; i++) {
			float u = next_f();
			float v = next_f();
			float w = next_f();
			// Radius: lerp between min and max
			float r = r_min + (r_max - r_min) * next_f();

			Vector3 offset;
			switch (mode) {
				case 0: { // Sphere — uniform volume sampling
					float theta = u * Math_TAU;
					float phi   = acos(2.0f * v - 1.0f);
					float cr    = r * cbrtf(w); // cube root for uniform volume
					offset = Vector3(
						cr * sin(phi) * cos(theta),
						cr * sin(phi) * sin(theta),
						cr * cos(phi)
					);
					break;
				}
				case 1: { // Cube
					offset = Vector3(
						(u * 2.0f - 1.0f) * r,
						(v * 2.0f - 1.0f) * r,
						(w * 2.0f - 1.0f) * r
					);
					break;
				}
				case 2: { // Disc (XZ plane)
					float angle = u * Math_TAU;
					float dist  = r * sqrtf(v); // sqrt for uniform area
					offset = Vector3(
						dist * cos(angle),
						0.0f,
						dist * sin(angle)
					);
					break;
				}
				default:
					offset = Vector3();
			}

			Vector3 pos = center + offset;
			positions.write[i] = pos;
			normals.write[i]   = offset.length() > 0.001f ? offset.normalized() : Vector3(0, 1, 0);
			// Color by distance from center, normalized to max radius
			float dist_ratio = offset.length() / fmax(r_max, 0.001f);
			colors.write[i] = Color(dist_ratio, 1.0f - dist_ratio, 0.4f, 1.0f);
		}

		Dictionary result;
		result["positions"] = positions;
		result["normals"]   = normals;
		result["colors"]    = colors;
		// Point cloud — no indices, no UVs, primitive = POINTS
		result["primitive"] = 0; // Mesh::PRIMITIVE_POINTS
		return result;
	}
};

#endif // SCATTER_SOP_H
