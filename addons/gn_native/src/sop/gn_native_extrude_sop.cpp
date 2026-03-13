#include "gn_native_extrude_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <vector>

namespace godot {

void GNNativeExtrudeSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "normals", "indices",
                                  "distance", "inset"),
                         &GNNativeExtrudeSop::process);
}

Dictionary GNNativeExtrudeSop::process(const PackedVector3Array &positions,
                                        const PackedVector3Array &normals,
                                        const PackedInt32Array &indices,
                                        double distance, double inset) {
    int vert_count = positions.size();
    int idx_count = indices.size();
    int tri_count = idx_count / 3;

    if (tri_count == 0) {
        Dictionary r;
        r["positions"] = positions;
        r["normals"] = normals;
        r["indices"] = indices;
        return r;
    }

    const Vector3 *verts = positions.ptr();
    const Vector3 *nrms = normals.ptr();
    const int32_t *idx = indices.ptr();
    int nrm_count = normals.size();

    // Compute per-vertex average face normal for extrusion direction
    std::vector<Vector3> avg_normals(vert_count, Vector3(0, 0, 0));
    for (int t = 0; t < tri_count; ++t) {
        int i0 = idx[t * 3], i1 = idx[t * 3 + 1], i2 = idx[t * 3 + 2];
        Vector3 fn = (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]);
        avg_normals[i0] += fn;
        avg_normals[i1] += fn;
        avg_normals[i2] += fn;
    }
    for (int i = 0; i < vert_count; ++i) {
        double len = avg_normals[i].length();
        if (len > 0.0001) avg_normals[i] /= len;
        else if (i < nrm_count) avg_normals[i] = nrms[i];
        else avg_normals[i] = Vector3(0, 1, 0);
    }

    // Create extruded vertices: original + displaced copies
    PackedVector3Array out_pos;
    out_pos.resize(vert_count * 2);
    PackedVector3Array out_nrm;
    out_nrm.resize(vert_count * 2);
    Vector3 *op = out_pos.ptrw();
    Vector3 *on = out_nrm.ptrw();

    for (int i = 0; i < vert_count; ++i) {
        // Bottom (original)
        op[i] = verts[i];
        on[i] = -avg_normals[i];
        // Top (extruded)
        op[vert_count + i] = verts[i] + avg_normals[i] * distance;
        on[vert_count + i] = avg_normals[i];
    }

    // Build indices: top face + side quads
    std::vector<int32_t> new_idx;
    // Top face (same winding as original but offset)
    for (int t = 0; t < idx_count; ++t) {
        new_idx.push_back(idx[t] + vert_count);
    }
    // Bottom face (reversed winding)
    for (int t = 0; t < tri_count; ++t) {
        new_idx.push_back(idx[t * 3]);
        new_idx.push_back(idx[t * 3 + 2]);
        new_idx.push_back(idx[t * 3 + 1]);
    }
    // Side quads: for each edge on the boundary
    // Simple approach: connect each triangle edge bottom→top
    for (int t = 0; t < tri_count; ++t) {
        for (int e = 0; e < 3; ++e) {
            int b0 = idx[t * 3 + e];
            int b1 = idx[t * 3 + (e + 1) % 3];
            int t0 = b0 + vert_count;
            int t1 = b1 + vert_count;
            new_idx.push_back(b0); new_idx.push_back(b1); new_idx.push_back(t1);
            new_idx.push_back(b0); new_idx.push_back(t1); new_idx.push_back(t0);
        }
    }

    PackedInt32Array out_idx;
    out_idx.resize(new_idx.size());
    int32_t *oi = out_idx.ptrw();
    for (size_t i = 0; i < new_idx.size(); ++i) oi[i] = new_idx[i];

    Dictionary result;
    result["positions"] = out_pos;
    result["normals"] = out_nrm;
    result["indices"] = out_idx;
    return result;
}

} // namespace godot
