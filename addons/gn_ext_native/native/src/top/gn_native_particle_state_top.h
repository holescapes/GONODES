#ifndef GN_NATIVE_PARTICLE_STATE_TOP_H
#define GN_NATIVE_PARTICLE_STATE_TOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

namespace godot {

/// Decodes a POP SSBO into a 2D heatmap Image.
class GNNativeParticleStateTop : public RefCounted {
    GDCLASS(GNNativeParticleStateTop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// attrib_type: "float","vec2","vec3","vec4".
    Ref<Image> process(const PackedByteArray &raw, int count, int stride,
                       int attrib_offset, const String &attrib_type,
                       int width, double scale);
};

} // namespace godot

#endif
