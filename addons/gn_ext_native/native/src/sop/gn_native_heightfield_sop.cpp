#include "gn_native_heightfield_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <cmath>
namespace godot {
void GNNativeHeightfieldSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "heights", "rows", "cols",
                                  "size_x", "size_z", "height_scale"),
                         &GNNativeHeightfieldSop::process);
}
Dictionary GNNativeHeightfieldSop::process(const PackedFloat32Array &heights,
        int rows, int cols, double size_x, double size_z, double height_scale) {
    Dictionary result;
    if (rows < 2) rows = 2;
    if (cols < 2) cols = 2;
    int vert_count = rows * cols;
    int tri_count = (rows - 1) * (cols - 1) * 2;
    PackedVector3Array vertices;
    PackedVector3Array normals;
    PackedVector2Array uvs;
    PackedInt32Array indices;
    vertices.resize(vert_count);
    normals.resize(vert_count);
    uvs.resize(vert_count);
    indices.resize(tri_count * 3);
    Vector3 *vp = vertices.ptrw();
    Vector3 *np = normals.ptrw();
    Vector2 *up = uvs.ptrw();
    int *ip = indices.ptrw();
    const float *hp = heights.ptr();
    int h_size = heights.size();
    double dx = size_x / (cols - 1);
    double dz = size_z / (rows - 1);
    double x_off = -size_x * 0.5;
    double z_off = -size_z * 0.5;
    // Generate vertices
    for (int r = 0; r < rows; ++r) {
        for (int c = 0; c < cols; ++c) {
            int idx = r * cols + c;
            double h = (idx < h_size) ? (double)hp[idx] * height_scale : 0.0;
            vp[idx] = Vector3(x_off + c * dx, h, z_off + r * dz);
            up[idx] = Vector2((double)c / (cols - 1), (double)r / (rows - 1));
        }
    }
    // Generate indices
    int ii = 0;
    for (int r = 0; r < rows - 1; ++r) {
        for (int c = 0; c < cols - 1; ++c) {
            int tl = r * cols + c;
            int tr = tl + 1;
            int bl = tl + cols;
            int br = bl + 1;
            ip[ii++] = tl; ip[ii++] = bl; ip[ii++] = tr;
            ip[ii++] = tr; ip[ii++] = bl; ip[ii++] = br;
        }
    }
    // Calculate normals via cross products
    for (int i = 0; i < vert_count; ++i) np[i] = Vector3(0, 0, 0);
    for (int t = 0; t < tri_count; ++t) {
        int i0 = ip[t*3], i1 = ip[t*3+1], i2 = ip[t*3+2];
        Vector3 e1 = vp[i1] - vp[i0];
        Vector3 e2 = vp[i2] - vp[i0];
        Vector3 n = e1.cross(e2);
        np[i0] += n; np[i1] += n; np[i2] += n;
    }
    for (int i = 0; i < vert_count; ++i) np[i] = np[i].normalized();
    result["vertices"] = vertices;
    result["normals"] = normals;
    result["uvs"] = uvs;
    result["indices"] = indices;
    return result;
}
} // namespace godot
