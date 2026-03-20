#ifndef GN_NATIVE_TEXTURE_SOP_H
#define GN_NATIVE_TEXTURE_SOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>

namespace godot {

/// Per-vertex texture sampling — vertex color or displacement.
class GNNativeTextureSop : public RefCounted {
    GDCLASS(GNNativeTextureSop, RefCounted)

public:
    /// Sample texture at UVs → vertex colors.
    PackedColorArray sample_colors(const PackedVector2Array &p_uvs,
                                   const Ref<Image> &p_image) const;

    /// Sample texture at UVs → displaced positions along normals.
    PackedVector3Array displace(const PackedVector3Array &p_positions,
                                const PackedVector3Array &p_normals,
                                const PackedVector2Array &p_uvs,
                                const Ref<Image> &p_image,
                                double p_scale) const;

protected:
    static void _bind_methods();
};

} // namespace godot

#endif
