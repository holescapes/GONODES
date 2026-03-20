#ifndef GN_USER_TOP_H
#define GN_USER_TOP_H

/// GONODES User Native SDK — TOP (Texture) Helpers
///
/// NOTE: TOPs are GPU-driven via SubViewport. The C++ cook for TOPs operates
/// on the CPU side — setting shader uniforms, generating CPU data that feeds
/// into a shader, or processing readback data.
///
/// # Return Dictionary Format
///
///   Dictionary result;
///   result["shader_code"] = String("...");           // GLSL fragment shader source
///   result["uniforms"] = Dictionary();               // {"name": value} for shader uniforms
///   result["resolution"] = Vector2i(1024, 1024);     // optional override
///   return result;
///
/// Alternatively, for CPU-generated texture output:
///   result["image"] = Ref<Image>;                    // CPU image → uploaded to texture

#include "gn_user_node.h"

namespace gn {

/// Helper: build a TOP result with shader code and uniforms.
inline godot::Dictionary make_top_shader_result(
		const godot::String &shader_code,
		const godot::Dictionary &uniforms = godot::Dictionary(),
		const godot::Vector2i &resolution = godot::Vector2i(0, 0)) {
	godot::Dictionary result;
	result["shader_code"] = shader_code;
	if (uniforms.size() > 0) result["uniforms"] = uniforms;
	if (resolution.x > 0 && resolution.y > 0) result["resolution"] = resolution;
	return result;
}

/// Helper: build a TOP result from a CPU-generated Image.
inline godot::Dictionary make_top_image_result(const godot::Ref<godot::Image> &image) {
	godot::Dictionary result;
	result["image"] = image;
	return result;
}

} // namespace gn

#endif // GN_USER_TOP_H
