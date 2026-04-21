#include "gn_native_voronoi_shatter_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <cmath>
#include <vector>
#include <algorithm>
namespace godot {
void GNNativeVoronoiShatterSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "mesh_verts", "mesh_indices", "scatter_points", "seed"),
                         &GNNativeVoronoiShatterSop::process);
}
TypedArray<Dictionary> GNNativeVoronoiShatterSop::process(
        const PackedVector3Array &mesh_verts, const PackedInt32Array &mesh_indices,
        const PackedVector3Array &scatter_points, int seed) {
    TypedArray<Dictionary> result;
    int tri_count = mesh_indices.size() / 3;
    int vert_count = mesh_verts.size();
    int scatter_count = scatter_points.size();
    if (scatter_count == 0 || tri_count == 0) {
        Dictionary d;
        d["vertices"] = mesh_verts;
        d["indices"] = mesh_indices;
        result.push_back(d);
        return result;
    }
    const Vector3 *mv = mesh_verts.ptr();
    const int *mi = mesh_indices.ptr();
    const Vector3 *sp = scatter_points.ptr();
    // Assign each triangle to nearest Voronoi site by centroid
    std::vector<std::vector<int>> site_tris(scatter_count);
    for (int t = 0; t < tri_count; ++t) {
        int i0 = mi[t*3], i1 = mi[t*3+1], i2 = mi[t*3+2];
        if (i0 >= vert_count || i1 >= vert_count || i2 >= vert_count) continue;
        Vector3 centroid = (mv[i0] + mv[i1] + mv[i2]) / 3.0f;
        int best = 0;
        float best_d = (centroid - sp[0]).length_squared();
        for (int s = 1; s < scatter_count; ++s) {
            float d = (centroid - sp[s]).length_squared();
            if (d < best_d) { best_d = d; best = s; }
        }
        site_tris[best].push_back(t);
    }
    // Build fragment meshes
    for (int s = 0; s < scatter_count; ++s) {
        if (site_tris[s].empty()) continue;
        // Collect unique vertices and remap indices
        std::vector<int> old_to_new(vert_count, -1);
        PackedVector3Array frag_verts;
        PackedInt32Array frag_indices;
        int new_idx = 0;
        for (int t : site_tris[s]) {
            for (int k = 0; k < 3; ++k) {
                int oi = mi[t*3+k];
                if (old_to_new[oi] < 0) {
                    old_to_new[oi] = new_idx++;
                    frag_verts.push_back(mv[oi]);
                }
                frag_indices.push_back(old_to_new[oi]);
            }
        }
        // Reset mapping
        for (int t : site_tris[s]) {
            for (int k = 0; k < 3; ++k) old_to_new[mi[t*3+k]] = -1;
        }
        Dictionary d;
        d["vertices"] = frag_verts;
        d["indices"] = frag_indices;
        result.push_back(d);
    }
    return result;
}
} // namespace godot
