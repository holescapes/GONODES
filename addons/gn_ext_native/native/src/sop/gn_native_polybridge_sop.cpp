#include "gn_native_polybridge_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <cmath>

using namespace godot;

void GNNativePolyBridgeSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "loop_a", "loop_b", "divisions", "twist_deg"), &GNNativePolyBridgeSop::process);
}

Dictionary GNNativePolyBridgeSop::process(const PackedVector3Array &p_loop_a,
                                            const PackedVector3Array &p_loop_b,
                                            int p_divisions, double p_twist_deg) const {
    Dictionary result;
    PackedVector3Array verts;
    PackedVector3Array normals;
    PackedVector2Array uvs;
    PackedInt32Array indices;

    int n = p_loop_a.size();
    if (n < 3 || p_loop_b.size() != n) {
        result["vertices"] = verts;
        result["normals"] = normals;
        result["uvs"] = uvs;
        result["indices"] = indices;
        return result;
    }
    if (p_divisions < 1) p_divisions = 1;

    const Vector3 *la = p_loop_a.ptr();
    const Vector3 *lb = p_loop_b.ptr();

    int rings = p_divisions + 1;
    double twist_rad = p_twist_deg * Math_PI / 180.0;

    // Compute centers for twist axis
    Vector3 center_a(0, 0, 0), center_b(0, 0, 0);
    for (int i = 0; i < n; i++) {
        center_a += la[i];
        center_b += lb[i];
    }
    center_a /= (double)n;
    center_b /= (double)n;
    Vector3 axis = (center_b - center_a).normalized();

    // Generate interpolated rings
    for (int r = 0; r < rings; r++) {
        double t = (double)r / p_divisions;
        double angle = twist_rad * t;
        double ca = std::cos(angle);
        double sa = std::sin(angle);
        Vector3 center = center_a.lerp(center_b, t);
        double uv_v = t;

        for (int i = 0; i <= n; i++) {
            int idx = i % n;
            Vector3 pa = la[idx];
            Vector3 pb = lb[idx];
            Vector3 interp = pa.lerp(pb, t);

            // Apply twist around the bridge axis
            Vector3 local = interp - center;
            // Rodrigues' rotation
            Vector3 rotated = local * ca + axis.cross(local) * sa + axis * axis.dot(local) * (1.0 - ca);
            Vector3 pos = center + rotated;

            verts.push_back(pos);
            uvs.push_back(Vector2((double)i / n, uv_v));
        }
    }

    // Compute triangle indices
    int ring_verts = n + 1;
    for (int r = 0; r < p_divisions; r++) {
        for (int i = 0; i < n; i++) {
            int a = r * ring_verts + i;
            int b = a + 1;
            int c = a + ring_verts;
            int d = c + 1;
            indices.push_back(a);
            indices.push_back(c);
            indices.push_back(b);
            indices.push_back(b);
            indices.push_back(c);
            indices.push_back(d);
        }
    }

    // Compute normals
    normals.resize(verts.size());
    Vector3 *nrm_ptr = normals.ptrw();
    memset(nrm_ptr, 0, normals.size() * sizeof(Vector3));

    const Vector3 *vp = verts.ptr();
    const int *ip = indices.ptr();
    int tri_count = indices.size() / 3;

    for (int t = 0; t < tri_count; t++) {
        int ia = ip[t * 3];
        int ib = ip[t * 3 + 1];
        int ic = ip[t * 3 + 2];
        Vector3 e1 = vp[ib] - vp[ia];
        Vector3 e2 = vp[ic] - vp[ia];
        Vector3 fn = e1.cross(e2);
        nrm_ptr[ia] += fn;
        nrm_ptr[ib] += fn;
        nrm_ptr[ic] += fn;
    }
    for (int i = 0; i < normals.size(); i++) {
        double len = nrm_ptr[i].length();
        if (len > 1e-8) nrm_ptr[i] /= len;
    }

    result["vertices"] = verts;
    result["normals"] = normals;
    result["uvs"] = uvs;
    result["indices"] = indices;
    return result;
}
