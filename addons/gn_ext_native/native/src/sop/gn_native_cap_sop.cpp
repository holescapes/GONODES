#include "gn_native_cap_sop.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/local_vector.hpp>

namespace godot {

void GNNativeCapSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "all_positions", "all_indices",
                                  "flip_normals"),
                         &GNNativeCapSop::process);
}

// Encodes a directed edge as a single int64
static int64_t edge_key(int a, int b) {
    return ((int64_t)a << 32) | (int64_t)(uint32_t)b;
}

Dictionary GNNativeCapSop::process(const PackedVector3Array &all_positions,
                                    const PackedInt32Array &all_indices,
                                    bool flip_normals) {
    Dictionary result;
    int ni = all_indices.size();
    int tri_count = ni / 3;

    if (tri_count == 0) {
        result["positions"] = PackedVector3Array();
        result["normals"] = PackedVector3Array();
        return result;
    }

    const Vector3 *vp = all_positions.ptr();
    const int *ip = all_indices.ptr();

    // Find boundary (unshared) directed edges
    // An edge A→B is boundary if B→A doesn't exist
    HashMap<int64_t, bool> edge_exists;
    for (int t = 0; t < tri_count; ++t) {
        int i0 = ip[t * 3], i1 = ip[t * 3 + 1], i2 = ip[t * 3 + 2];
        edge_exists[edge_key(i0, i1)] = true;
        edge_exists[edge_key(i1, i2)] = true;
        edge_exists[edge_key(i2, i0)] = true;
    }

    // Collect boundary edges: edge A→B where B→A is not in the map
    HashMap<int, int> boundary_next;
    for (int t = 0; t < tri_count; ++t) {
        int v[3] = {ip[t * 3], ip[t * 3 + 1], ip[t * 3 + 2]};
        for (int e = 0; e < 3; ++e) {
            int a = v[e], b = v[(e + 1) % 3];
            if (!edge_exists.has(edge_key(b, a))) {
                boundary_next[a] = b;
            }
        }
    }

    if (boundary_next.size() == 0) {
        result["positions"] = PackedVector3Array();
        result["normals"] = PackedVector3Array();
        return result;
    }

    // Trace boundary loops and create triangle fan caps
    PackedVector3Array cap_verts;
    PackedVector3Array cap_normals;

    HashMap<int, bool> visited;
    for (const KeyValue<int, int> &kv : boundary_next) {
        int start = kv.key;
        if (visited.has(start)) continue;

        // Trace the loop
        LocalVector<int> loop;
        int cur = start;
        int safety = boundary_next.size() + 1;
        while (safety-- > 0) {
            if (visited.has(cur)) break;
            visited[cur] = true;
            loop.push_back(cur);
            if (!boundary_next.has(cur)) break;
            cur = boundary_next[cur];
            if (cur == start) break;
        }

        if ((int)loop.size() < 3) continue;

        // Compute center
        Vector3 center;
        for (int idx : loop) center += vp[idx];
        center /= (float)loop.size();

        // Triangle fan from center
        int n_loop = (int)loop.size();
        for (int j = 0; j < n_loop; ++j) {
            Vector3 v0 = center;
            Vector3 v1 = vp[loop[j]];
            Vector3 v2 = vp[loop[(j + 1) % n_loop]];

            Vector3 fn = (v1 - v0).cross(v2 - v0).normalized();
            if (flip_normals) fn = -fn;

            cap_verts.push_back(v0);
            cap_verts.push_back(v1);
            cap_verts.push_back(v2);
            cap_normals.push_back(fn);
            cap_normals.push_back(fn);
            cap_normals.push_back(fn);
        }
    }

    result["positions"] = cap_verts;
    result["normals"] = cap_normals;
    return result;
}

} // namespace godot
