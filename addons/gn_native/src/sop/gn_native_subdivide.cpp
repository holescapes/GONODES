#include "gn_native_subdivide.h"

#include <godot_cpp/core/class_db.hpp>
#include <unordered_map>
#include <vector>

using namespace godot;

void GNNativeSubdivide::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "uvs", "indices", "iterations"),
                         &GNNativeSubdivide::process);
}

Dictionary GNNativeSubdivide::process(const PackedVector3Array &positions,
                                       const PackedVector2Array &uvs,
                                       const PackedInt32Array &indices,
                                       int iterations) {
    iterations = CLAMP(iterations, 1, 4);

    // Work with local copies that grow each iteration
    std::vector<Vector3> verts(positions.ptr(), positions.ptr() + positions.size());
    std::vector<Vector2> texuvs;
    bool has_uvs = !uvs.is_empty();
    if (has_uvs) {
        texuvs.assign(uvs.ptr(), uvs.ptr() + uvs.size());
    }

    // Build initial index buffer
    std::vector<int> idx;
    if (!indices.is_empty()) {
        idx.assign(indices.ptr(), indices.ptr() + indices.size());
    } else {
        idx.resize(verts.size());
        for (int i = 0; i < (int)verts.size(); ++i) idx[i] = i;
    }

    for (int iter = 0; iter < iterations; ++iter) {
        int tri_count = (int)idx.size() / 3;
        std::vector<Vector3> new_verts;
        std::vector<Vector2> new_uvs;
        new_verts.reserve(tri_count * 12);
        if (has_uvs) new_uvs.reserve(tri_count * 12);

        for (int t = 0; t < tri_count; ++t) {
            int i0 = idx[t * 3];
            int i1 = idx[t * 3 + 1];
            int i2 = idx[t * 3 + 2];

            Vector3 v0 = verts[i0], v1 = verts[i1], v2 = verts[i2];
            Vector3 m01 = (v0 + v1) * 0.5f;
            Vector3 m12 = (v1 + v2) * 0.5f;
            Vector3 m20 = (v2 + v0) * 0.5f;

            // Emit 4 sub-triangles (non-indexed for simplicity, as GDScript does)
            new_verts.push_back(v0); new_verts.push_back(m01); new_verts.push_back(m20);
            new_verts.push_back(m01); new_verts.push_back(v1); new_verts.push_back(m12);
            new_verts.push_back(m20); new_verts.push_back(m12); new_verts.push_back(v2);
            new_verts.push_back(m01); new_verts.push_back(m12); new_verts.push_back(m20);

            if (has_uvs) {
                Vector2 uv0 = (i0 < (int)texuvs.size()) ? texuvs[i0] : Vector2();
                Vector2 uv1 = (i1 < (int)texuvs.size()) ? texuvs[i1] : Vector2();
                Vector2 uv2 = (i2 < (int)texuvs.size()) ? texuvs[i2] : Vector2();
                Vector2 uvm01 = (uv0 + uv1) * 0.5f;
                Vector2 uvm12 = (uv1 + uv2) * 0.5f;
                Vector2 uvm20 = (uv2 + uv0) * 0.5f;

                new_uvs.push_back(uv0); new_uvs.push_back(uvm01); new_uvs.push_back(uvm20);
                new_uvs.push_back(uvm01); new_uvs.push_back(uv1); new_uvs.push_back(uvm12);
                new_uvs.push_back(uvm20); new_uvs.push_back(uvm12); new_uvs.push_back(uv2);
                new_uvs.push_back(uvm01); new_uvs.push_back(uvm12); new_uvs.push_back(uvm20);
            }
        }

        verts = std::move(new_verts);
        if (has_uvs) texuvs = std::move(new_uvs);
        // Non-indexed after first iteration
        idx.resize(verts.size());
        for (int i = 0; i < (int)verts.size(); ++i) idx[i] = i;
    }

    PackedVector3Array out_verts;
    out_verts.resize(verts.size());
    memcpy(out_verts.ptrw(), verts.data(), verts.size() * sizeof(Vector3));

    PackedVector2Array out_uvs;
    if (has_uvs) {
        out_uvs.resize(texuvs.size());
        memcpy(out_uvs.ptrw(), texuvs.data(), texuvs.size() * sizeof(Vector2));
    }

    Dictionary result;
    result["positions"] = out_verts;
    result["uvs"] = out_uvs;
    result["indices"] = PackedInt32Array(); // non-indexed after subdivision
    return result;
}
