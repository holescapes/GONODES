/*  wave_deform_sop.h — Example UserNativeSOP
 *  Applies a travelling sine wave to mesh vertex positions.
 *  Load this via: UserNativeSOP → Templates → Examples → Wave Deform
 */
#ifndef WAVE_DEFORM_SOP_H
#define WAVE_DEFORM_SOP_H

#include <gn_user_node.h>
#include <gn_user_sop.h>

using namespace godot;

class WaveDeformSOP : public gn::GNUserNode {
	GDCLASS(WaveDeformSOP, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "wave_deform_sop"; }
	String get_node_description() const override {
		return "Displaces vertices along their normals using a travelling sine wave.";
	}

	Array get_port_definitions() const override {
		Array ports;
		Dictionary in0;
		in0["name"] = "geo_in"; in0["family"] = "SOP"; in0["direction"] = "input";
		in0["required"] = true; in0["label"] = "Input geometry";
		ports.push_back(in0);
		Dictionary out0;
		out0["name"] = "geo_out"; out0["family"] = "SOP"; out0["direction"] = "output";
		out0["label"] = "Deformed geometry";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::parf("amplitude", 0.2, 0.0, 2.0, 0.01,
			"Amplitude", "Peak displacement distance."));
		params.push_back(gn::parf("frequency", 4.0, 0.1, 50.0, 0.1,
			"Frequency", "Spatial frequency of the wave."));
		params.push_back(gn::parf("speed", 2.0, 0.0, 10.0, 0.1,
			"Speed", "Wave travel speed."));
		params.push_back(gn::pari("axis", 1, 0, 2,
			"Axis", "Axis along which the wave travels (0=X, 1=Y, 2=Z)."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		float amp   = parf(params, "amplitude", 0.2);
		float freq  = parf(params, "frequency", 4.0);
		float speed = parf(params, "speed", 2.0);
		int   axis  = pari(params, "axis", 1);
		float t     = parf(context, "elapsed", 0.0);

		// Read input geometry
		if (inputs.size() == 0 || inputs[0].get_type() == Variant::NIL)
			return Dictionary();

		Dictionary in_geo = inputs[0];
		PackedVector3Array positions = in_geo.get("positions", PackedVector3Array());
		PackedVector3Array normals   = in_geo.get("normals", PackedVector3Array());

		if (positions.is_empty())
			return Dictionary();

		// Generate normals if missing (default to Y-up)
		if (normals.size() != positions.size()) {
			normals.resize(positions.size());
			for (int i = 0; i < normals.size(); i++)
				normals.write[i] = Vector3(0, 1, 0);
		}

		// Deform
		PackedVector3Array out_pos;
		out_pos.resize(positions.size());

		for (int i = 0; i < positions.size(); i++) {
			Vector3 p = positions[i];
			float coord = (axis == 0) ? p.x : (axis == 1) ? p.y : p.z;
			float displacement = amp * sin(coord * freq * Math_TAU - t * speed * Math_TAU);
			out_pos.write[i] = p + normals[i] * displacement;
		}

		Dictionary result;
		result["positions"] = out_pos;
		result["normals"]   = normals;
		// Pass through UVs, colors, indices if present
		if (in_geo.has("uvs"))     result["uvs"]     = in_geo["uvs"];
		if (in_geo.has("colors"))  result["colors"]  = in_geo["colors"];
		if (in_geo.has("indices")) result["indices"] = in_geo["indices"];
		return result;
	}
};

#endif // WAVE_DEFORM_SOP_H
