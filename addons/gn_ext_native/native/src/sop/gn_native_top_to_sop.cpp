#include "gn_native_top_to_sop.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>


namespace godot {

void GNNativeTopToSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "img", "mode", "resolution",
                                  "height_scale", "grid_size", "threshold", "channel"),
                         &GNNativeTopToSop::process);
}

float GNNativeTopToSop::_sample_channel(const Color &c, int channel) {
    switch (channel) {
        case 1: return c.r;
        case 2: return c.g;
        case 3: return c.b;
        case 4: return c.a;
        default: return c.r * 0.299f + c.g * 0.587f + c.b * 0.114f;
    }
}

Dictionary GNNativeTopToSop::process(const Ref<Image> &img, int mode, int resolution,
                                      double height_scale, double grid_size,
                                      double threshold, int channel) {
    Dictionary result;
    if (img.is_null()) return result;

    int img_w = img->get_width();
    int img_h = img->get_height();
    if (img_w == 0 || img_h == 0) return result;

    int res = MIN(resolution, MIN(img_w, img_h));
    if (res < 2) res = 2;

    if (mode == 0) {
        // Heightfield
        float half = (float)grid_size * 0.5f;
        float step = (float)grid_size / (float)(res - 1);

        PackedVector3Array verts;
        PackedVector2Array uvs;
        verts.resize(res * res);
        uvs.resize(res * res);
        Vector3 *vp = verts.ptrw();
        Vector2 *up = uvs.ptrw();

        for (int iz = 0; iz < res; ++iz) {
            for (int ix = 0; ix < res; ++ix) {
                float u = (float)ix / (float)(res - 1);
                float v = (float)iz / (float)(res - 1);
                int px = CLAMP((int)(u * (img_w - 1)), 0, img_w - 1);
                int py = CLAMP((int)(v * (img_h - 1)), 0, img_h - 1);
                Color c = img->get_pixel(px, py);
                float h = _sample_channel(c, channel) * (float)height_scale;
                int idx = iz * res + ix;
                vp[idx] = Vector3(-half + ix * step, h, -half + iz * step);
                up[idx] = Vector2(u, v);
            }
        }

        // Indices
        PackedInt32Array indices;
        indices.resize((res - 1) * (res - 1) * 6);
        int *ip = indices.ptrw();
        int ii = 0;
        for (int iz = 0; iz < res - 1; ++iz) {
            for (int ix = 0; ix < res - 1; ++ix) {
                int tl = iz * res + ix;
                int tr = tl + 1;
                int bl = (iz + 1) * res + ix;
                int br = bl + 1;
                ip[ii++] = tl; ip[ii++] = bl; ip[ii++] = tr;
                ip[ii++] = tr; ip[ii++] = bl; ip[ii++] = br;
            }
        }

        // Normals via face accumulation
        PackedVector3Array normals;
        normals.resize(res * res);
        Vector3 *np = normals.ptrw();
        for (int i = 0; i < res * res; ++i) np[i] = Vector3();

        for (int ti = 0; ti < ii / 3; ++ti) {
            int i0 = ip[ti * 3], i1 = ip[ti * 3 + 1], i2 = ip[ti * 3 + 2];
            Vector3 fn = (vp[i1] - vp[i0]).cross(vp[i2] - vp[i0]);
            np[i0] += fn; np[i1] += fn; np[i2] += fn;
        }
        for (int i = 0; i < res * res; ++i) {
            float len = np[i].length();
            np[i] = len > 0.0001f ? np[i] / len : Vector3(0, 1, 0);
        }

        result["positions"] = verts;
        result["normals"] = normals;
        result["uvs"] = uvs;
        result["indices"] = indices;
        result["primitive"] = 3; // PRIMITIVE_TRIANGLES

    } else if (mode == 1) {
        // Point cloud
        PackedVector3Array verts;
        float half = (float)grid_size * 0.5f;
        int step_x = MAX(img_w / res, 1);
        int step_y = MAX(img_h / res, 1);

        for (int iy = 0; iy < img_h; iy += step_y) {
            for (int ix = 0; ix < img_w; ix += step_x) {
                Color c = img->get_pixel(ix, iy);
                float val = _sample_channel(c, channel);
                if (val < (float)threshold) continue;
                float u = img_w > 1 ? (float)ix / (float)(img_w - 1) : 0.5f;
                float v = img_h > 1 ? (float)iy / (float)(img_h - 1) : 0.5f;
                verts.push_back(Vector3(-half + u * (float)grid_size,
                                        val * (float)height_scale,
                                        -half + v * (float)grid_size));
            }
        }

        result["positions"] = verts;
        result["primitive"] = 0; // PRIMITIVE_POINTS

    } else {
        // Normal map grid — flat with normals from RGB
        float half = (float)grid_size * 0.5f;
        float step = (float)grid_size / (float)(res - 1);

        PackedVector3Array verts;
        PackedVector3Array normals;
        PackedVector2Array uvs;
        PackedInt32Array indices;
        verts.resize(res * res);
        normals.resize(res * res);
        uvs.resize(res * res);

        Vector3 *vp = verts.ptrw();
        Vector3 *np = normals.ptrw();
        Vector2 *up = uvs.ptrw();

        for (int iz = 0; iz < res; ++iz) {
            for (int ix = 0; ix < res; ++ix) {
                float u = (float)ix / (float)(res - 1);
                float v = (float)iz / (float)(res - 1);
                int px = CLAMP((int)(u * (img_w - 1)), 0, img_w - 1);
                int py = CLAMP((int)(v * (img_h - 1)), 0, img_h - 1);
                Color c = img->get_pixel(px, py);
                int idx = iz * res + ix;
                vp[idx] = Vector3(-half + ix * step, 0.0f, -half + iz * step);
                np[idx] = Vector3(c.r * 2.0f - 1.0f, c.b * 2.0f - 1.0f,
                                  c.g * 2.0f - 1.0f).normalized();
                up[idx] = Vector2(u, v);
            }
        }

        indices.resize((res - 1) * (res - 1) * 6);
        int *ip = indices.ptrw();
        int ii = 0;
        for (int iz = 0; iz < res - 1; ++iz) {
            for (int ix = 0; ix < res - 1; ++ix) {
                int tl = iz * res + ix;
                ip[ii++] = tl; ip[ii++] = tl + res; ip[ii++] = tl + 1;
                ip[ii++] = tl + 1; ip[ii++] = tl + res; ip[ii++] = tl + res + 1;
            }
        }

        result["positions"] = verts;
        result["normals"] = normals;
        result["uvs"] = uvs;
        result["indices"] = indices;
        result["primitive"] = 3;
    }

    return result;
}

} // namespace godot
