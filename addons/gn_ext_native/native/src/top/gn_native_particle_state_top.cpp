#include "gn_native_particle_state_top.h"

#include <godot_cpp/core/class_db.hpp>
#include <cstring>


namespace godot {

void GNNativeParticleStateTop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "raw", "count", "stride",
                                  "attrib_offset", "attrib_type",
                                  "width", "scale"),
                         &GNNativeParticleStateTop::process);
}

Ref<Image> GNNativeParticleStateTop::process(const PackedByteArray &raw,
                                              int count, int stride,
                                              int attrib_offset,
                                              const String &attrib_type,
                                              int width, double scale) {
    if (raw.size() == 0 || count <= 0 || width < 1) return Ref<Image>();

    int rows = (count + width - 1) / width;
    Ref<Image> img = Image::create_empty(width, rows, false, Image::FORMAT_RGBA8);
    img->fill(Color(0, 0, 0, 0));

    const uint8_t *ptr = raw.ptr();
    int data_size = raw.size();
    int components = 1;
    if (attrib_type == "vec2") components = 2;
    else if (attrib_type == "vec3") components = 3;
    else if (attrib_type == "vec4") components = 4;

    for (int i = 0; i < count; ++i) {
        int byte_off = i * stride + attrib_offset;
        if (byte_off + components * 4 > data_size) break;

        float vals[4] = {0, 0, 0, 1};
        for (int c = 0; c < components; ++c) {
            memcpy(&vals[c], ptr + byte_off + c * 4, 4);
            vals[c] *= (float)scale;
        }

        float r = fabsf(vals[0]);
        float g = components >= 2 ? fabsf(vals[1]) : r;
        float b = components >= 3 ? fabsf(vals[2]) : r;
        float a = components >= 4 ? CLAMP(vals[3], 0.0f, 1.0f) : 1.0f;

        if (r > 1.0f) r = 1.0f;
        if (g > 1.0f) g = 1.0f;
        if (b > 1.0f) b = 1.0f;

        int px = i % width;
        int py = i / width;
        img->set_pixel(px, py, Color(r, g, b, a));
    }

    return img;
}

} // namespace godot
