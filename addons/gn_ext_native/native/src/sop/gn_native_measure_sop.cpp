#include "gn_native_measure_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <cmath>
#include <unordered_set>
namespace godot {
void GNNativeMeasureSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "vertices", "indices"),
                         &GNNativeMeasureSop::process);
}
Dictionary GNNativeMeasureSop::process(const PackedVector3Array &vertices,
                                        const PackedInt32Array &indices) {
    Dictionary result;
    int vert_count = vertices.size();
    int idx_count = indices.size();
    int tri_count = idx_count / 3;
    const Vector3 *verts = vertices.ptr();
    const int *idxs = indices.ptr();
    // Total area via triangle cross products
    double total_area = 0.0;
    for (int t = 0; t < tri_count; ++t) {
        int i0 = idxs[t * 3], i1 = idxs[t * 3 + 1], i2 = idxs[t * 3 + 2];
        if (i0 >= vert_count || i1 >= vert_count || i2 >= vert_count) continue;
        Vector3 e1 = verts[i1] - verts[i0];
        Vector3 e2 = verts[i2] - verts[i0];
        total_area += e1.cross(e2).length() * 0.5;
    }
    // Perimeter via unique edges
    struct EdgeHash {
        size_t operator()(const std::pair<int,int> &e) const {
            return std::hash<int>()(e.first) ^ (std::hash<int>()(e.second) << 16);
        }
    };
    std::unordered_set<std::pair<int,int>, EdgeHash> edges;
    for (int t = 0; t < tri_count; ++t) {
        int i0 = idxs[t*3], i1 = idxs[t*3+1], i2 = idxs[t*3+2];
        auto add_edge = [&](int a, int b) {
            if (a > b) std::swap(a, b);
            edges.insert({a, b});
        };
        add_edge(i0, i1); add_edge(i1, i2); add_edge(i2, i0);
    }
    double total_perimeter = 0.0;
    // Count boundary edges (appear in only 1 triangle)
    // For simplicity, sum all unique edge lengths as total edge length
    for (auto &e : edges) {
        if (e.first < vert_count && e.second < vert_count) {
            total_perimeter += (verts[e.second] - verts[e.first]).length();
        }
    }
    // Per-vertex discrete curvature (angle defect / area)
    PackedFloat32Array curvature;
    curvature.resize(vert_count);
    float *curv = curvature.ptrw();
    // Accumulate angles and areas per vertex
    std::vector<double> angle_sum(vert_count, 0.0);
    std::vector<double> area_sum(vert_count, 0.0);
    for (int t = 0; t < tri_count; ++t) {
        int ids[3] = {idxs[t*3], idxs[t*3+1], idxs[t*3+2]};
        Vector3 v[3];
        for (int k = 0; k < 3; ++k) {
            if (ids[k] < vert_count) v[k] = verts[ids[k]];
        }
        double tri_area = (v[1] - v[0]).cross(v[2] - v[0]).length() * 0.5;
        for (int k = 0; k < 3; ++k) {
            if (ids[k] >= vert_count) continue;
            Vector3 e1n = (v[(k+1)%3] - v[k]).normalized();
            Vector3 e2n = (v[(k+2)%3] - v[k]).normalized();
            double dot = e1n.dot(e2n);
            if (dot > 1.0) dot = 1.0;
            if (dot < -1.0) dot = -1.0;
            angle_sum[ids[k]] += acos(dot);
            area_sum[ids[k]] += tri_area / 3.0;
        }
    }
    for (int i = 0; i < vert_count; ++i) {
        double defect = 2.0 * 3.14159265358979323846 - angle_sum[i];
        curv[i] = (area_sum[i] > 1e-10) ? (float)(defect / area_sum[i]) : 0.0f;
    }
    result["area"] = total_area;
    result["perimeter"] = total_perimeter;
    result["curvature"] = curvature;
    return result;
}
} // namespace godot
