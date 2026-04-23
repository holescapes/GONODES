/*  edge_detect_img.h — Example UserNativeIMG
 *  3×3 Sobel edge detection on CPU images.
 *  Load this via: UserNativeIMG → Templates → Examples → Edge Detect
 */
#ifndef EDGE_DETECT_IMG_H
#define EDGE_DETECT_IMG_H

#include <gn_user_node.h>
#include <gn_user_img.h>
#include <cmath>

using namespace godot;

class EdgeDetectIMG : public gn::GNUserNode {
	GDCLASS(EdgeDetectIMG, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "edge_detect_img"; }
	String get_node_description() const override {
		return "3x3 Sobel edge detection on CPU images.";
	}

	Array get_port_definitions() const override {
		Array ports;
		Dictionary in0;
		in0["name"] = "in"; in0["family"] = "IMG"; in0["direction"] = "input";
		in0["required"] = true; in0["label"] = "Input image";
		ports.push_back(in0);
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "IMG"; out0["direction"] = "output";
		out0["label"] = "Edge image";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::parf("strength", 1.0, 0.1, 10.0, 0.1,
			"Strength", "Edge detection strength multiplier."));
		params.push_back(gn::parb("grayscale", true,
			"Grayscale Input", "Convert to luminance before detecting edges."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		float strength = parf(params, "strength", 1.0);
		bool grayscale = parb(params, "grayscale", true);

		Ref<Image> img = gn::get_input_image(inputs, 0);
		if (img.is_null())
			return Dictionary();

		int w = img->get_width();
		int h = img->get_height();

		Ref<Image> out = gn::create_like(img);

		// Sobel kernels
		//  Gx:            Gy:
		// -1  0  1       -1 -2 -1
		// -2  0  2        0  0  0
		// -1  0  1        1  2  1

		auto lum = [](Color c) -> float {
			return c.r * 0.299f + c.g * 0.587f + c.b * 0.114f;
		};

		auto sample = [&](int x, int y) -> float {
			x = CLAMP(x, 0, w - 1);
			y = CLAMP(y, 0, h - 1);
			Color c = img->get_pixel(x, y);
			if (grayscale) return lum(c);
			return (c.r + c.g + c.b) / 3.0f;
		};

		for (int y = 0; y < h; y++) {
			for (int x = 0; x < w; x++) {
				float tl = sample(x-1, y-1), tc = sample(x, y-1), tr = sample(x+1, y-1);
				float ml = sample(x-1, y),                         mr = sample(x+1, y);
				float bl = sample(x-1, y+1), bc = sample(x, y+1), br = sample(x+1, y+1);

				float gx = (-tl + tr) + (-2.0f*ml + 2.0f*mr) + (-bl + br);
				float gy = (-tl - 2.0f*tc - tr) + (bl + 2.0f*bc + br);

				float edge = sqrtf(gx*gx + gy*gy) * strength;
				edge = CLAMP(edge, 0.0f, 1.0f);

				out->set_pixel(x, y, Color(edge, edge, edge, 1.0f));
			}
		}

		return gn::make_img_result(out);
	}
};

#endif // EDGE_DETECT_IMG_H
