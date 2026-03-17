#include "gn_native_polystitch_sop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <algorithm>
#include <vector>

namespace godot {

void GNNativePolyStitchSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "pts_a", "pts_b", "max_distance"),
                         &GNNativePolyStitchSop::process);
}

Dictionary GNNativePolyStitchSop::process(const PackedVector3Array &pts_a,
                                           const PackedVector3Array &pts_b,
                                           double max_distance) {
    Dictionary result;
    int na = pts_a.size();
    int nb = pts_b.size();

    if (na == 0 || nb == 0) {
        result["positions"] = PackedVector3Array();
        result["normals"] = PackedVector3Array();
        result["indices"] = PackedInt32Array();
        return result;
    }

    const Vector3 *a = pts_a.ptr();
    const Vector3 *b = pts_b.ptr();

    // Find nearest pairs from A to B
    struct Pair {
        int ia, ib;
        double dist;
    };
    std::vector<Pair> pairs;
    for (int i = 0; i < na; ++i) {
        int best_j = -1;
        double best_d = 1e30;
        for (int j = 0; j < nb; ++j) {
            double d = a[i].distance_to(b[j]);
            if (d < best_d) { best_d = d; best_j = j; }
        }
        if (max_distance <= 0.0 || best_d <= max_distance) {
            pairs.push_back({ i, best_j, best_d });
        }
    }

    if (pairs.size() < 2) {
        result["positions"] = PackedVector3Array();
        result["normals"] = PackedVector3Array();
        result["indices"] = PackedInt32Array();
        return result;
    }

    // Sort by index in A
    std::sort(pairs.begin(), pairs.end(),
              [](const Pair &x, const Pair &y) { return x.ia < y.ia; });

    // Build stitch quad strips
    std::vector<Vector3> verts;
    std::vector<Vector3> norms;
    std::vector<int> idxs;

    for (size_t pi = 0; pi < pairs.size() - 1; ++pi) {
        Vector3 a0 = a[pairs[pi].ia];
        Vector3 b0 = b[pairs[pi].ib];
        Vector3 a1 = a[pairs[pi + 1].ia];
        Vector3 b1 = b[pairs[pi + 1].ib];

        Vector3 n = (b0 - a0).cross(a1 - a0).normalized();
        int base = (int)verts.size();

        verts.push_back(a0); norms.push_back(n);
        verts.push_back(b0); norms.push_back(n);
        verts.push_back(b1); norms.push_back(n);
        verts.push_back(a1); norms.push_back(n);

        // Two triangles for the quad
        idxs.push_back(base);     idxs.push_back(base + 1); idxs.push_back(base + 2);
        idxs.push_back(base);     idxs.push_back(base + 2); idxs.push_back(base + 3);
    }

    int ovc = (int)verts.size();
    int oic = (int)idxs.size();
    PackedVector3Array out_p, out_n;
    PackedInt32Array out_i;
    out_p.resize(ovc); out_n.resize(ovc); out_i.resize(oic);
    memcpy(out_p.ptrw(), verts.data(), sizeof(Vector3) * ovc);
    memcpy(out_n.ptrw(), norms.data(), sizeof(Vector3) * ovc);
    memcpy(out_i.ptrw(), idxs.data(), sizeof(int) * oic);

    result["positions"] = out_p;
    result["normals"] = out_n;
    result["indices"] = out_i;
    return result;
}

} // namespace godot
