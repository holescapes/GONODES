#include "gn_native_scatter_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <vector>
#include <algorithm>

namespace godot {

void GNNativeScatterSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "verts", "normals", "uvs", "indices",
                                  "count", "seed", "emit_normals", "emit_uvs"),
                         &GNNativeScatterSop::process);
}

// xorshift64 for fast deterministic RNG
static uint64_t _xorshift64(uint64_t &state) {
    state ^= state << 13;
    state ^= state >> 7;
    state ^= state << 17;
    return state;
}

static double _rand_double(uint64_t &state) {
    return (double)(_xorshift64(state) & 0xFFFFFFFF) / (double)0xFFFFFFFF;
}

Dictionary GNNativeScatterSop::process(const PackedVector3Array &verts,
                                        const PackedVector3Array &normals,
                                        const PackedVector2Array &uvs,
                                        const PackedInt32Array &indices,
                                        int count, int seed,
                                        bool emit_normals, bool emit_uvs) {
    Dictionary result;
    int idx_count = indices.size();
    int tri_count = idx_count / 3;

    if (tri_count == 0 || count <= 0) {
        result["positions"] = PackedVector3Array();
        result["normals"] = PackedVector3Array();
        result["uvs"] = PackedVector2Array();
        return result;
    }

    const Vector3 *v = verts.ptr();
    const Vector3 *n = normals.ptr();
    const Vector2 *u = uvs.ptr();
    const int32_t *idx = indices.ptr();
    int nrm_count = normals.size();
    int uv_count = uvs.size();

    // Build area CDF
    std::vector<double> cdf(tri_count);
    double total_area = 0.0;
    for (int t = 0; t < tri_count; ++t) {
        Vector3 v0 = v[idx[t * 3]];
        Vector3 v1 = v[idx[t * 3 + 1]];
        Vector3 v2 = v[idx[t * 3 + 2]];
        double area = (v1 - v0).cross(v2 - v0).length() * 0.5;
        total_area += area;
        cdf[t] = total_area;
    }
    if (total_area <= 0.0) {
        result["positions"] = PackedVector3Array();
        result["normals"] = PackedVector3Array();
        result["uvs"] = PackedVector2Array();
        return result;
    }
    for (int t = 0; t < tri_count; ++t) cdf[t] /= total_area;

    // Sample points
    PackedVector3Array out_pos;
    out_pos.resize(count);
    PackedVector3Array out_nrm;
    if (emit_normals) out_nrm.resize(count);
    PackedVector2Array out_uvs;
    if (emit_uvs) out_uvs.resize(count);

    Vector3 *op = out_pos.ptrw();
    Vector3 *on = emit_normals ? out_nrm.ptrw() : nullptr;
    Vector2 *ou = emit_uvs ? out_uvs.ptrw() : nullptr;

    uint64_t rng_state = (uint64_t)seed * 6364136223846793005ULL + 1442695040888963407ULL;

    for (int pi = 0; pi < count; ++pi) {
        // Pick triangle via CDF
        double r = _rand_double(rng_state);
        int tri = (int)(std::lower_bound(cdf.begin(), cdf.end(), r) - cdf.begin());
        if (tri >= tri_count) tri = tri_count - 1;

        int i0 = idx[tri * 3];
        int i1 = idx[tri * 3 + 1];
        int i2 = idx[tri * 3 + 2];

        // Random barycentric coordinates
        double s = _rand_double(rng_state);
        double t_val = _rand_double(rng_state);
        if (s + t_val > 1.0) { s = 1.0 - s; t_val = 1.0 - t_val; }
        double w0 = 1.0 - s - t_val, w1 = s, w2 = t_val;

        op[pi] = v[i0] * w0 + v[i1] * w1 + v[i2] * w2;

        if (on && i0 < nrm_count && i1 < nrm_count && i2 < nrm_count) {
            on[pi] = (n[i0] * w0 + n[i1] * w1 + n[i2] * w2).normalized();
        } else if (on) {
            on[pi] = Vector3(0, 1, 0);
        }

        if (ou && i0 < uv_count && i1 < uv_count && i2 < uv_count) {
            ou[pi] = u[i0] * w0 + u[i1] * w1 + u[i2] * w2;
        } else if (ou) {
            ou[pi] = Vector2(0, 0);
        }
    }

    result["positions"] = out_pos;
    result["normals"] = out_nrm;
    result["uvs"] = out_uvs;
    return result;
}

} // namespace godot
