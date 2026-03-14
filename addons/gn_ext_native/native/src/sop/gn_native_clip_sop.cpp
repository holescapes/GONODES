#include "gn_native_clip_sop.h"

#include <godot_cpp/core/class_db.hpp>


namespace godot {

void GNNativeClipSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "verts", "uvs", "indices",
                                  "normal", "origin"),
                         &GNNativeClipSop::process);
}

Dictionary GNNativeClipSop::process(const PackedVector3Array &verts,
                                     const PackedVector2Array &uvs,
                                     const PackedInt32Array &indices,
                                     const Vector3 &normal, double origin) {
    Dictionary result;
    int tri_count = indices.size() / 3;

    const Vector3 *vp = verts.ptr();
    const Vector2 *up = uvs.size() > 0 ? uvs.ptr() : nullptr;
    const int *ip = indices.ptr();
    bool has_uvs = up != nullptr && (int)uvs.size() >= (int)verts.size();

    PackedVector3Array out_verts;
    PackedVector2Array out_uvs;

    // Pre-allocate with generous estimate
    out_verts.resize(0);
    out_uvs.resize(0);

    for (int tri = 0; tri < tri_count; ++tri) {
        int i0 = ip[tri * 3], i1 = ip[tri * 3 + 1], i2 = ip[tri * 3 + 2];
        Vector3 v[3] = {vp[i0], vp[i1], vp[i2]};
        Vector2 uv[3];
        if (has_uvs) {
            uv[0] = i0 < (int)uvs.size() ? up[i0] : Vector2();
            uv[1] = i1 < (int)uvs.size() ? up[i1] : Vector2();
            uv[2] = i2 < (int)uvs.size() ? up[i2] : Vector2();
        }

        float dist[3];
        int above = 0;
        for (int k = 0; k < 3; ++k) {
            dist[k] = (float)(v[k].dot(normal) - origin);
            if (dist[k] >= 0.0f) ++above;
        }

        if (above == 3) {
            // Keep entire triangle
            for (int k = 0; k < 3; ++k) {
                out_verts.push_back(v[k]);
                if (has_uvs) out_uvs.push_back(uv[k]);
            }
        } else if (above == 0) {
            // Discard
            continue;
        } else {
            // Split — classify above/below
            int above_idx[3], below_idx[3];
            int na = 0, nb = 0;
            for (int k = 0; k < 3; ++k) {
                if (dist[k] >= 0.0f) above_idx[na++] = k;
                else below_idx[nb++] = k;
            }

            if (na == 2) {
                // Two above, one below — quad on above side
                int b = below_idx[0], a0 = above_idx[0], a1 = above_idx[1];
                float t0 = dist[a0] / (dist[a0] - dist[b]);
                float t1 = dist[a1] / (dist[a1] - dist[b]);
                Vector3 clip0 = v[a0].lerp(v[b], t0);
                Vector3 clip1 = v[a1].lerp(v[b], t1);

                // Triangle 1
                out_verts.push_back(v[a0]); out_verts.push_back(v[a1]); out_verts.push_back(clip1);
                // Triangle 2
                out_verts.push_back(v[a0]); out_verts.push_back(clip1); out_verts.push_back(clip0);

                if (has_uvs) {
                    Vector2 uv_c0 = uv[a0].lerp(uv[b], t0);
                    Vector2 uv_c1 = uv[a1].lerp(uv[b], t1);
                    out_uvs.push_back(uv[a0]); out_uvs.push_back(uv[a1]); out_uvs.push_back(uv_c1);
                    out_uvs.push_back(uv[a0]); out_uvs.push_back(uv_c1); out_uvs.push_back(uv_c0);
                }
            } else {
                // One above, two below — single triangle
                int a = above_idx[0], b0 = below_idx[0], b1 = below_idx[1];
                float t0 = dist[a] / (dist[a] - dist[b0]);
                float t1 = dist[a] / (dist[a] - dist[b1]);
                Vector3 clip0 = v[a].lerp(v[b0], t0);
                Vector3 clip1 = v[a].lerp(v[b1], t1);

                out_verts.push_back(v[a]); out_verts.push_back(clip0); out_verts.push_back(clip1);

                if (has_uvs) {
                    Vector2 uv_c0 = uv[a].lerp(uv[b0], t0);
                    Vector2 uv_c1 = uv[a].lerp(uv[b1], t1);
                    out_uvs.push_back(uv[a]); out_uvs.push_back(uv_c0); out_uvs.push_back(uv_c1);
                }
            }
        }
    }

    result["positions"] = out_verts;
    result["uvs"] = out_uvs;
    return result;
}

} // namespace godot
