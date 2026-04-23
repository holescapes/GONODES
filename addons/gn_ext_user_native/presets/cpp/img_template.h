/*  IMG Template — Minimal starting point for a UserNativeIMG.
 *  Inverts the input image colors.
 */
#ifndef USER_IMG_TEMPLATE_H
#define USER_IMG_TEMPLATE_H

#include <gn_user_node.h>
#include <gn_user_img.h>

using namespace godot;

class MyUserIMG : public gn::GNUserNode {
	GDCLASS(MyUserIMG, gn::GNUserNode)
protected:
	static void _bind_methods() { gn::GNUserNode::_bind_methods(); }
public:
	String get_node_type() const override { return "my_user_img"; }
	String get_node_description() const override { return "My custom IMG."; }

	Array get_port_definitions() const override {
		Array ports;
		Dictionary in0;
		in0["name"] = "in"; in0["family"] = "IMG"; in0["direction"] = "input";
		in0["required"] = true; in0["label"] = "Input image";
		ports.push_back(in0);
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "IMG"; out0["direction"] = "output";
		out0["label"] = "Output image";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override { return Array(); }

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		Ref<Image> img = gn::get_input_image(inputs, 0);
		if (img.is_null()) return Dictionary();

		Ref<Image> out = gn::create_like(img);
		int w = img->get_width(), h = img->get_height();
		for (int y = 0; y < h; y++) {
			for (int x = 0; x < w; x++) {
				Color c = img->get_pixel(x, y);
				out->set_pixel(x, y, Color(1.0f - c.r, 1.0f - c.g, 1.0f - c.b, c.a));
			}
		}
		return gn::make_img_result(out);
	}
};

#endif
