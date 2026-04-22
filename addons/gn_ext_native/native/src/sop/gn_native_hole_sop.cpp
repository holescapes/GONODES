#include "gn_native_hole_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <vector>
namespace godot {
void GNNativeHoleSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "mesh_verts", "mesh_indices", "hole_points",
                                  "project_axis", "invert"),
                         &GNNativeHoleSop::process);
}
// 2D point-in-polygon via ray casting
static bool point_in_polygon_2d(double px, double py,
                                 const double *poly_x, const double *poly_y, int count) {
    bool inside = false;
    for (int i = 0, j = count - 1; i < count; j = i++) {
        if (((poly_y[i] > py) != (poly_y[j] > py)) &&
            (px < (poly_x[j] - poly_x[i]) * (py - poly_y[i]) / (poly_y[j] - poly_y[i]) + poly_x[i])) {
            inside = !inside;
        }
    }
    return inside;
}
PackedInt32Array GNNativeHoleSop::process(const PackedVector3Array &mesh_verts,
        const PackedInt32Array &mesh_indices, const PackedVector3Array &hole_points,
        int project_axis, bool invert) {
    int tri_count = mesh_indices.size() / 3;
    int vert_count = mesh_verts.size();
    int hole_count = hole_points.size();
    PackedInt32Array result;
    if (hole_count < 3 || tri_count == 0) {
        result = mesh_indices;
        return result;
    }
    const Vector3 *mv = mesh_verts.ptr();
    const int *mi = mesh_indices.ptr();
    const Vector3 *hp = hole_points.ptr();
    // Project hole to 2D
    std::vector<double> hx(hole_count), hy(hole_count);
    for (int i = 0; i < hole_count; ++i) {
        switch (project_axis) {
            case 0: hx[i] = hp[i].y; hy[i] = hp[i].z; break;
            case 1: hx[i] = hp[i].x; hy[i] = hp[i].z; break;
            default: hx[i] = hp[i].x; hy[i] = hp[i].y; break;
        }
    }
    for (int t = 0; t < tri_count; ++t) {
        int i0 = mi[t*3], i1 = mi[t*3+1], i2 = mi[t*3+2];
        if (i0 >= vert_count || i1 >= vert_count || i2 >= vert_count) continue;
        // Centroid
        Vector3 centroid = (mv[i0] + mv[i1] + mv[i2]) / 3.0f;
        double cx, cy;
        switch (project_axis) {
            case 0: cx = centroid.y; cy = centroid.z; break;
            case 1: cx = centroid.x; cy = centroid.z; break;
            default: cx = centroid.x; cy = centroid.y; break;
        }
        bool inside = point_in_polygon_2d(cx, cy, hx.data(), hy.data(), hole_count);
        bool keep = invert ? inside : !inside;
        if (keep) {
            result.push_back(i0);
            result.push_back(i1);
            result.push_back(i2);
        }
    }
    return result;
}
} // namespace godot
