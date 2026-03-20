#include "gn_native_polypatch_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

using namespace godot;

void GNNativePolyPatchSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "c00", "c10", "c01", "c11", "rows", "cols"), &GNNativePolyPatchSop::process);
}

Dictionary GNNativePolyPatchSop::process(const Vector3 &p_c00, const Vector3 &p_c10,
                                           const Vector3 &p_c01, const Vector3 &p_c11,
                                           int p_rows, int p_cols) const {
    Dictionary result;
    PackedVector3Array verts;
    PackedVector3Array normals;
    PackedVector2Array uvs;
    PackedInt32Array indices;

    if (p_rows < 1) p_rows = 1;
    if (p_cols < 1) p_cols = 1;

    int rows1 = p_rows + 1;
    int cols1 = p_cols + 1;
    verts.resize(rows1 * cols1);
    normals.resize(rows1 * cols1);
    uvs.resize(rows1 * cols1);

    Vector3 *v = verts.ptrw();
    Vector3 *n = normals.ptrw();
    Vector2 *uv = uvs.ptrw();

    // Bilinear interpolation
    for (int r = 0; r < rows1; r++) {
        double rv = (double)r / p_rows;
        for (int c = 0; c < cols1; c++) {
            double cu = (double)c / p_cols;
            int idx = r * cols1 + c;

            // Bilinear (Coons patch with linear edges)
            Vector3 pos = p_c00 * (1.0 - cu) * (1.0 - rv)
                        + p_c10 * cu * (1.0 - rv)
                        + p_c01 * (1.0 - cu) * rv
                        + p_c11 * cu * rv;

            v[idx] = pos;
            uv[idx] = Vector2(cu, rv);
        }
    }

    // Compute normals from cross products of adjacent edges
    for (int r = 0; r < rows1; r++) {
        for (int c = 0; c < cols1; c++) {
            int idx = r * cols1 + c;
            // Use central differences
            Vector3 du, dv_vec;
            if (c < p_cols) {
                du = v[r * cols1 + c + 1] - v[idx];
            } else {
                du = v[idx] - v[r * cols1 + c - 1];
            }
            if (r < p_rows) {
                dv_vec = v[(r + 1) * cols1 + c] - v[idx];
            } else {
                dv_vec = v[idx] - v[(r - 1) * cols1 + c];
            }
            Vector3 face_n = du.cross(dv_vec);
            double len = face_n.length();
            n[idx] = (len > 1e-8) ? (face_n / len) : Vector3(0, 1, 0);
        }
    }

    // Build triangle indices
    indices.resize(p_rows * p_cols * 6);
    int *tri = indices.ptrw();
    int ti = 0;
    for (int r = 0; r < p_rows; r++) {
        for (int c = 0; c < p_cols; c++) {
            int a = r * cols1 + c;
            int b = a + 1;
            int d = a + cols1;
            int e = d + 1;
            tri[ti++] = a; tri[ti++] = d; tri[ti++] = b;
            tri[ti++] = b; tri[ti++] = d; tri[ti++] = e;
        }
    }

    result["vertices"] = verts;
    result["normals"] = normals;
    result["uvs"] = uvs;
    result["indices"] = indices;
    return result;
}
