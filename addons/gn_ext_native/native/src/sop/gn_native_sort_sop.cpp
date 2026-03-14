#include "gn_native_sort_sop.h"

#include <godot_cpp/core/class_db.hpp>
#include <vector>
#include <algorithm>

namespace godot {

void GNNativeSortSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "verts", "normals", "uvs",
                                  "tangents", "indices", "method",
                                  "ref_point", "seed"),
                         &GNNativeSortSop::process);
}

Dictionary GNNativeSortSop::process(const PackedVector3Array &verts,
                                     const PackedVector3Array &normals,
                                     const PackedVector2Array &uvs,
                                     const PackedFloat32Array &tangents,
                                     const PackedInt32Array &indices,
                                     int method, const Vector3 &ref_point,
                                     int seed) {
    Dictionary result;
    int n = verts.size();
    if (n == 0) {
        result["positions"] = verts;
        result["normals"] = normals;
        result["uvs"] = uvs;
        result["tangents"] = tangents;
        result["indices"] = indices;
        return result;
    }

    const Vector3 *vp = verts.ptr();

    // Build sort order
    std::vector<int> order(n);
    for (int i = 0; i < n; ++i) order[i] = i;

    switch (method) {
        case 0: // X
            std::sort(order.begin(), order.end(), [vp](int a, int b) { return vp[a].x < vp[b].x; });
            break;
        case 1: // Y
            std::sort(order.begin(), order.end(), [vp](int a, int b) { return vp[a].y < vp[b].y; });
            break;
        case 2: // Z
            std::sort(order.begin(), order.end(), [vp](int a, int b) { return vp[a].z < vp[b].z; });
            break;
        case 3: // Distance from point
            std::sort(order.begin(), order.end(), [vp, &ref_point](int a, int b) {
                return vp[a].distance_squared_to(ref_point) < vp[b].distance_squared_to(ref_point);
            });
            break;
        case 4: { // Random (Fisher-Yates)
            srand(seed);
            for (int i = n - 1; i > 0; --i) {
                int j = rand() % (i + 1);
                std::swap(order[i], order[j]);
            }
            break;
        }
        case 5: // Reverse
            std::reverse(order.begin(), order.end());
            break;
    }

    // Build inverse mapping for index rewriting
    std::vector<int> inverse(n);
    for (int i = 0; i < n; ++i) inverse[order[i]] = i;

    // Remap positions
    PackedVector3Array out_verts;
    out_verts.resize(n);
    Vector3 *ov = out_verts.ptrw();
    for (int i = 0; i < n; ++i) ov[i] = vp[order[i]];
    result["positions"] = out_verts;

    // Remap normals
    if ((int)normals.size() == n) {
        const Vector3 *np = normals.ptr();
        PackedVector3Array out_normals;
        out_normals.resize(n);
        Vector3 *on = out_normals.ptrw();
        for (int i = 0; i < n; ++i) on[i] = np[order[i]];
        result["normals"] = out_normals;
    } else {
        result["normals"] = normals;
    }

    // Remap UVs
    if ((int)uvs.size() == n) {
        const Vector2 *up = uvs.ptr();
        PackedVector2Array out_uvs;
        out_uvs.resize(n);
        Vector2 *ou = out_uvs.ptrw();
        for (int i = 0; i < n; ++i) ou[i] = up[order[i]];
        result["uvs"] = out_uvs;
    } else {
        result["uvs"] = uvs;
    }

    // Remap tangents
    if ((int)tangents.size() == n * 4) {
        const float *tp = tangents.ptr();
        PackedFloat32Array out_tan;
        out_tan.resize(n * 4);
        float *ot = out_tan.ptrw();
        for (int i = 0; i < n; ++i) {
            int si = order[i] * 4, di = i * 4;
            ot[di] = tp[si]; ot[di+1] = tp[si+1];
            ot[di+2] = tp[si+2]; ot[di+3] = tp[si+3];
        }
        result["tangents"] = out_tan;
    } else {
        result["tangents"] = tangents;
    }

    // Remap indices
    if (indices.size() > 0) {
        const int *ip = indices.ptr();
        PackedInt32Array out_idx;
        out_idx.resize(indices.size());
        int *oi = out_idx.ptrw();
        for (int i = 0; i < (int)indices.size(); ++i) {
            oi[i] = inverse[ip[i]];
        }
        result["indices"] = out_idx;
    } else {
        result["indices"] = indices;
    }

    return result;
}

} // namespace godot
