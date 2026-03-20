#include "gn_native_texture_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

using namespace godot;

void GNNativeTextureSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("sample_colors", "uvs", "image"), &GNNativeTextureSop::sample_colors);
    ClassDB::bind_method(D_METHOD("displace", "positions", "normals", "uvs", "image", "scale"), &GNNativeTextureSop::displace);
}

PackedColorArray GNNativeTextureSop::sample_colors(const PackedVector2Array &p_uvs,
                                                     const Ref<Image> &p_image) const {
    int count = p_uvs.size();
    PackedColorArray out;
    if (p_image.is_null() || count == 0) {
        out.resize(count);
        return out;
    }

    int w = p_image->get_width();
    int h = p_image->get_height();
    if (w == 0 || h == 0) {
        out.resize(count);
        return out;
    }

    out.resize(count);
    const Vector2 *uv_ptr = p_uvs.ptr();
    Color *out_ptr = out.ptrw();

    for (int i = 0; i < count; i++) {
        double u = uv_ptr[i].x - std::floor(uv_ptr[i].x);
        double v = uv_ptr[i].y - std::floor(uv_ptr[i].y);
        int px = (int)(u * (w - 1));
        int py = (int)(v * (h - 1));
        if (px < 0) px = 0;
        if (px >= w) px = w - 1;
        if (py < 0) py = 0;
        if (py >= h) py = h - 1;
        out_ptr[i] = p_image->get_pixel(px, py);
    }
    return out;
}

PackedVector3Array GNNativeTextureSop::displace(const PackedVector3Array &p_positions,
                                                  const PackedVector3Array &p_normals,
                                                  const PackedVector2Array &p_uvs,
                                                  const Ref<Image> &p_image,
                                                  double p_scale) const {
    int count = p_positions.size();
    PackedVector3Array out;
    out.resize(count);

    if (p_image.is_null() || count == 0 || p_normals.size() != count || p_uvs.size() != count) {
        if (count > 0) {
            memcpy(out.ptrw(), p_positions.ptr(), count * sizeof(Vector3));
        }
        return out;
    }

    int w = p_image->get_width();
    int h = p_image->get_height();
    if (w == 0 || h == 0) {
        memcpy(out.ptrw(), p_positions.ptr(), count * sizeof(Vector3));
        return out;
    }

    const Vector3 *pos = p_positions.ptr();
    const Vector3 *nrm = p_normals.ptr();
    const Vector2 *uv = p_uvs.ptr();
    Vector3 *dst = out.ptrw();

    for (int i = 0; i < count; i++) {
        double u = uv[i].x - std::floor(uv[i].x);
        double v = uv[i].y - std::floor(uv[i].y);
        int px = (int)(u * (w - 1));
        int py = (int)(v * (h - 1));
        if (px < 0) px = 0;
        if (px >= w) px = w - 1;
        if (py < 0) py = 0;
        if (py >= h) py = h - 1;
        Color c = p_image->get_pixel(px, py);
        double lum = c.r * 0.299 + c.g * 0.587 + c.b * 0.114;
        dst[i] = pos[i] + nrm[i] * (lum * p_scale);
    }
    return out;
}
