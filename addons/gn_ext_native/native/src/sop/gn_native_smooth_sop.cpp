#include "gn_native_smooth_sop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <vector>

namespace godot {

void GNNativeSmoothSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "indices",
                                  "iterations", "strength", "pin_borders"),
                         &GNNativeSmoothSop::process);
}

Dictionary GNNativeSmoothSop::process(const PackedVector3Array &positions,
                                       const PackedInt32Array &indices,
                                       int iterations, double strength,
                                       bool pin_borders) {
    Dictionary result;
    int vert_count = positions.size();
    if (vert_count < 3) {
        result["positions"] = positions;
        result["normals"] = PackedVector3Array();
        return result;
    }

    const Vector3 *pos = positions.ptr();
    const int *idx = indices.ptr();
    int idx_count = indices.size();
    int tri_count = idx_count / 3;

    // Build adjacency
    std::vector<std::vector<int>> adj(vert_count);
    for (int t = 0; t < tri_count; ++t) {
        int i0 = idx[t * 3];
        int i1 = idx[t * 3 + 1];
        int i2 = idx[t * 3 + 2];
        auto add_edge = [&](int a, int b) {
            bool found = false;
            for (int n : adj[a]) { if (n == b) { found = true; break; } }
            if (!found) adj[a].push_back(b);
            found = false;
            for (int n : adj[b]) { if (n == a) { found = true; break; } }
            if (!found) adj[b].push_back(a);
        };
        add_edge(i0, i1);
        add_edge(i1, i2);
        add_edge(i2, i0);
    }

    // Detect border vertices (edges shared by only one triangle)
    std::vector<bool> is_border(vert_count, false);
    if (pin_borders) {
        HashMap<int64_t, int> edge_count;
        for (int t = 0; t < tri_count; ++t) {
            int v[3] = { idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2] };
            for (int e = 0; e < 3; ++e) {
                int a = MIN(v[e], v[(e + 1) % 3]);
                int b = MAX(v[e], v[(e + 1) % 3]);
                int64_t key = (int64_t)a * vert_count + b;
                if (edge_count.has(key))
                    edge_count[key]++;
                else
                    edge_count[key] = 1;
            }
        }
        for (auto it = edge_count.begin(); it != edge_count.end(); ++it) {
            if (it->value == 1) {
                int64_t key = it->key;
                int b = (int)(key % vert_count);
                int a = (int)((key - b) / vert_count);
                is_border[a] = true;
                is_border[b] = true;
            }
        }
    }

    // Iterative Laplacian smoothing
    PackedVector3Array curr;
    curr.resize(vert_count);
    memcpy(curr.ptrw(), pos, sizeof(Vector3) * vert_count);

    PackedVector3Array next;
    next.resize(vert_count);

    for (int iter = 0; iter < iterations; ++iter) {
        const Vector3 *c = curr.ptr();
        Vector3 *n = next.ptrw();
        for (int vi = 0; vi < vert_count; ++vi) {
            if (pin_borders && is_border[vi]) {
                n[vi] = c[vi];
                continue;
            }
            const auto &neighbors = adj[vi];
            if (neighbors.empty()) {
                n[vi] = c[vi];
                continue;
            }
            Vector3 avg(0, 0, 0);
            for (int ni : neighbors) {
                avg += c[ni];
            }
            avg /= (double)neighbors.size();
            n[vi] = c[vi].lerp(avg, strength);
        }
        PackedVector3Array tmp = curr;
        curr = next;
        next = tmp;
    }

    // Recompute normals
    PackedVector3Array normals;
    normals.resize(vert_count);
    Vector3 *nrm = normals.ptrw();
    for (int i = 0; i < vert_count; ++i) nrm[i] = Vector3(0, 0, 0);

    const Vector3 *final_pos = curr.ptr();
    for (int t = 0; t < tri_count; ++t) {
        int i0 = idx[t * 3];
        int i1 = idx[t * 3 + 1];
        int i2 = idx[t * 3 + 2];
        Vector3 fn = (final_pos[i1] - final_pos[i0]).cross(final_pos[i2] - final_pos[i0]);
        nrm[i0] += fn;
        nrm[i1] += fn;
        nrm[i2] += fn;
    }
    for (int i = 0; i < vert_count; ++i) {
        nrm[i] = nrm[i].normalized();
    }

    result["positions"] = curr;
    result["normals"] = normals;
    return result;
}

} // namespace godot
