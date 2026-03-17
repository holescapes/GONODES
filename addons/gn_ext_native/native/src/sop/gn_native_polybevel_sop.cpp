#include "gn_native_polybevel_sop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <vector>

namespace godot {

void GNNativePolyBevelSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "normals", "indices",
                                  "offset", "divisions", "roundness"),
                         &GNNativePolyBevelSop::process);
}

static double _smooth_step(double t, double roundness) {
    double s = t * t * (3.0 - 2.0 * t);
    return t + roundness * (s - t);
}

Dictionary GNNativePolyBevelSop::process(const PackedVector3Array &positions,
                                          const PackedVector3Array &normals,
                                          const PackedInt32Array &indices,
                                          double offset, int divisions,
                                          double roundness) {
    Dictionary result;
    int vc = positions.size();
    int ic = indices.size();
    int tc = ic / 3;

    if (vc < 3 || normals.size() < vc) {
        result["positions"] = positions;
        result["normals"] = normals;
        result["indices"] = indices;
        return result;
    }

    const Vector3 *pos = positions.ptr();
    const Vector3 *nrm = normals.ptr();
    const int *idx = indices.ptr();

    // Collect unique edges
    struct Edge { int a, b; };
    std::vector<Edge> edges;
    HashMap<int64_t, bool> edge_set;
    for (int t = 0; t < tc; ++t) {
        for (int e = 0; e < 3; ++e) {
            int a = idx[t * 3 + e];
            int b = idx[t * 3 + ((e + 1) % 3)];
            int mn = MIN(a, b), mx = MAX(a, b);
            int64_t key = (int64_t)mn * 1000000 + mx;
            if (!edge_set.has(key)) {
                edge_set[key] = true;
                edges.push_back({ mn, mx });
            }
        }
    }

    // Create inner ring: offset each vertex inward along its normal
    std::vector<Vector3> inner(vc);
    for (int i = 0; i < vc; ++i) {
        inner[i] = pos[i] - nrm[i] * offset;
    }

    std::vector<Vector3> out_verts;
    std::vector<Vector3> out_norms;
    std::vector<int> out_idx;

    if (divisions <= 1) {
        // Original verts + inner verts
        out_verts.reserve(vc * 2);
        out_norms.reserve(vc * 2);
        for (int i = 0; i < vc; ++i) {
            out_verts.push_back(pos[i]);
            out_norms.push_back(nrm[i]);
        }
        for (int i = 0; i < vc; ++i) {
            out_verts.push_back(inner[i]);
            out_norms.push_back(nrm[i]);
        }

        // Inner face uses shifted indices
        for (int i = 0; i < ic; ++i) {
            out_idx.push_back(idx[i] + vc);
        }

        // Connect original to inner along edges
        for (const auto &edge : edges) {
            int a = edge.a, b = edge.b;
            int a2 = a + vc, b2 = b + vc;
            out_idx.push_back(a);  out_idx.push_back(b);  out_idx.push_back(b2);
            out_idx.push_back(a);  out_idx.push_back(b2); out_idx.push_back(a2);
        }
    } else {
        // Multi-division: interpolate rings
        int ring_count = divisions + 1;
        for (int ring = 0; ring < ring_count; ++ring) {
            double t = (double)ring / (double)(ring_count - 1);
            if (roundness > 0.0)
                t = _smooth_step(t, roundness);
            for (int vi = 0; vi < vc; ++vi) {
                out_verts.push_back(pos[vi].lerp(inner[vi], t));
                out_norms.push_back(nrm[vi]);
            }
        }

        // Inner face uses last ring
        int last_ring_offset = (ring_count - 1) * vc;
        for (int i = 0; i < ic; ++i) {
            out_idx.push_back(idx[i] + last_ring_offset);
        }

        // Connect adjacent rings along edges
        for (int ring = 0; ring < ring_count - 1; ++ring) {
            int off_a = ring * vc;
            int off_b = (ring + 1) * vc;
            for (const auto &edge : edges) {
                int a = edge.a + off_a, b = edge.b + off_a;
                int a2 = edge.a + off_b, b2 = edge.b + off_b;
                out_idx.push_back(a);  out_idx.push_back(b);  out_idx.push_back(b2);
                out_idx.push_back(a);  out_idx.push_back(b2); out_idx.push_back(a2);
            }
        }
    }

    // Pack output
    int ovc = (int)out_verts.size();
    int oic = (int)out_idx.size();
    PackedVector3Array out_p, out_n;
    PackedInt32Array out_i;
    out_p.resize(ovc);
    out_n.resize(ovc);
    out_i.resize(oic);
    memcpy(out_p.ptrw(), out_verts.data(), sizeof(Vector3) * ovc);
    memcpy(out_n.ptrw(), out_norms.data(), sizeof(Vector3) * ovc);
    memcpy(out_i.ptrw(), out_idx.data(), sizeof(int) * oic);

    result["positions"] = out_p;
    result["normals"] = out_n;
    result["indices"] = out_i;
    return result;
}

} // namespace godot
