#ifndef GN_USER_IMG_H
#define GN_USER_IMG_H

/// GONODES User Native SDK — IMG (CPU Image) Helpers
///
/// # Return Dictionary Format
///
///   Dictionary result;
///   result["image"] = Ref<Image>;  // REQUIRED — the output image
///   return result;
///
/// Input images are passed as Dictionaries with:
///   {"image": Ref<Image>, "resolution": Vector2i, "format": int}

#include "gn_user_node.h"

namespace gn {

/// Helper: build an IMG result from a Godot Image.
inline godot::Dictionary make_img_result(const godot::Ref<godot::Image> &image) {
	godot::Dictionary result;
	result["image"] = image;
	return result;
}

/// Helper: get input Image from the inputs array.
inline godot::Ref<godot::Image> get_input_image(const godot::Array &inputs, int index) {
	if (index >= inputs.size() || inputs[index].get_type() == godot::Variant::NIL)
		return godot::Ref<godot::Image>();
	godot::Dictionary data = inputs[index];
	if (!data.has("image")) return godot::Ref<godot::Image>();
	return data["image"];
}

/// Helper: create an empty image with the same format as input.
inline godot::Ref<godot::Image> create_like(const godot::Ref<godot::Image> &src) {
	if (src.is_null()) return godot::Ref<godot::Image>();
	return godot::Image::create_empty(src->get_width(), src->get_height(), false, src->get_format());
}

} // namespace gn

#endif // GN_USER_IMG_H
