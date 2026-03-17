#include "gn_native_remesh_sop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <vector>

namespace godot {

void GNNativeRemeshSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "indices",
                                  "target_edge", "iterations", "smooth"),
                         &GNNativeRemeshSop::process);
}

static void _compute_normals(const Vector3 *verts, int vert_count,
                              const int *idx, int idx_count,
                              Vector3 *normals) {
    for (int i = 0; i < vert_count; ++i) normals[i] = Vector3(0, 0, 0);
    int tri_count = idx_count / 3;
    for (int t = 0; t < tri_count; ++t) {
        int i0 = idx[t * 3], i1 = idx[t * 3 + 1], i2 = idx[t * 3 + 2];
        Vector3 fn = (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]);
        normals[i0] += fn;
        normals[i1] += fn;
        normals[i2] += fn;
    }
    for (int i = 0; i < vert_count; ++i) normals[i] = normals[i].normalized();
}

Dictionary GNNativeRemeshSop::process(const PackedVector3Array &positions,
                                       const PackedInt32Array &indices,
                                       double target_edge, int iterations,
                                       bool smooth) {
    Dictionary result;
    // Work with dynamic vectors for easy appending
    std::vector<Vector3> verts(positions.ptr(), positions.ptr() + positions.size());
    std::vector<int> idxs(indices.ptr(), indices.ptr() + indices.size());

    if (idxs.empty()) {
        for (int i = 0; i < (int)verts.size(); ++i)
            idxs.push_back(i);
    }

    for (int iter = 0; iter < iterations; ++iter) {
        std::vector<int> new_idx;
        HashMap<int64_t, int> midpoint_cache;
        int tri_count = (int)idxs.size() / 3;

        for (int t = 0; t < tri_count; ++t) {
            int i0 = idxs[t * 3], i1 = idxs[t * 3 + 1], i2 = idxs[t * 3 + 2];
            Vector3 v0 = verts[i0], v1 = verts[i1], v2 = verts[i2];

            bool s01 = v0.distance_to(v1) > target_edge;
            bool s12 = v1.distance_to(v2) > target_edge;
            bool s20 = v2.distance_to(v0) > target_edge;

            if (!s01 && !s12 && !s20) {
                new_idx.push_back(i0);
                new_idx.push_back(i1);
                new_idx.push_back(i2);
                continue;
            }

            auto get_mid = [&](int a, int b) -> int {
                int mn = MIN(a, b), mx = MAX(a, b);
                int64_t key = (int64_t)mn * 1000000 + mx;
                if (midpoint_cache.has(key)) return midpoint_cache[key];
                int mid = (int)verts.size();
                verts.push_back((verts[a] + verts[b]) * 0.5);
                midpoint_cache[key] = mid;
                return mid;
            };

            int m01 = s01 ? get_mid(i0, i1) : -1;
            int m12 = s12 ? get_mid(i1, i2) : -1;
            int m20 = s20 ? get_mid(i2, i0) : -1;

            if (s01 && s12 && s20) {
                int tri[] = { i0, m01, m20, m01, i1, m12, m20, m12, i2, m01, m12, m20 };
                new_idx.insert(new_idx.end(), tri, tri + 12);
            } else if (s01 && s12) {
                int tri[] = { i0, m01, i2, m01, i1, m12, m01, m12, i2 };
                new_idx.insert(new_idx.end(), tri, tri + 9);
            } else if (s12 && s20) {
                int tri[] = { i0, i1, m12, i0, m12, m20, m12, i2, m20 };
                new_idx.insert(new_idx.end(), tri, tri + 9);
            } else if (s01 && s20) {
                int tri[] = { i0, m01, m20, m01, i1, i2, m01, i2, m20 };
                new_idx.insert(new_idx.end(), tri, tri + 9);
            } else if (s01) {
                int tri[] = { i0, m01, i2, m01, i1, i2 };
                new_idx.insert(new_idx.end(), tri, tri + 6);
            } else if (s12) {
                int tri[] = { i0, i1, m12, i0, m12, i2 };
                new_idx.insert(new_idx.end(), tri, tri + 6);
            } else if (s20) {
                int tri[] = { i0, i1, m20, m20, i1, i2 };
                new_idx.insert(new_idx.end(), tri, tri + 6);
            }
        }
        idxs = new_idx;
    }

    // Optional Laplacian smooth pass
    if (smooth) {
        int vc = (int)verts.size();
        int ic = (int)idxs.size();
        int tc = ic / 3;
        std::vector<std::vector<int>> adj(vc);
        for (int t = 0; t < tc; ++t) {
            int tri[3] = { idxs[t * 3], idxs[t * 3 + 1], idxs[t * 3 + 2] };
            for (int e = 0; e < 3; ++e) {
                int a = tri[e], b = tri[(e + 1) % 3];
                bool fa = false, fb = false;
                for (int n : adj[a]) { if (n == b) { fa = true; break; } }
                if (!fa) adj[a].push_back(b);
                for (int n : adj[b]) { if (n == a) { fb = true; break; } }
                if (!fb) adj[b].push_back(a);
            }
        }
        std::vector<Vector3> smoothed(vc);
        double str = 0.3;
        for (int vi = 0; vi < vc; ++vi) {
            if (adj[vi].empty()) { smoothed[vi] = verts[vi]; continue; }
            Vector3 avg(0, 0, 0);
            for (int ni : adj[vi]) avg += verts[ni];
            avg /= (double)adj[vi].size();
            smoothed[vi] = verts[vi].lerp(avg, str);
        }
        verts = smoothed;
    }

    // Pack output
    int vc = (int)verts.size();
    int ic = (int)idxs.size();
    PackedVector3Array out_pos;
    out_pos.resize(vc);
    memcpy(out_pos.ptrw(), verts.data(), sizeof(Vector3) * vc);

    PackedInt32Array out_idx;
    out_idx.resize(ic);
    memcpy(out_idx.ptrw(), idxs.data(), sizeof(int) * ic);

    PackedVector3Array out_nrm;
    out_nrm.resize(vc);
    _compute_normals(out_pos.ptr(), vc, out_idx.ptr(), ic, out_nrm.ptrw());

    result["positions"] = out_pos;
    result["normals"] = out_nrm;
    result["indices"] = out_idx;
    return result;
}

} // namespace godot
