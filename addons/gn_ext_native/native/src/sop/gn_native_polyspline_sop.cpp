#include "gn_native_polyspline_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <cmath>

using namespace godot;

void GNNativePolySplineSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("eval_spline", "points", "subdivisions", "closed"), &GNNativePolySplineSop::eval_spline);
    ClassDB::bind_method(D_METHOD("build_tube", "spine", "radius", "sides", "closed"), &GNNativePolySplineSop::build_tube);
}

PackedVector3Array GNNativePolySplineSop::eval_spline(const PackedVector3Array &p_points,
                                                        int p_subdivisions, bool p_closed) const {
    PackedVector3Array out;
    int n = p_points.size();
    if (n < 2) return p_points;
    if (p_subdivisions < 1) p_subdivisions = 1;

    const Vector3 *pts = p_points.ptr();
    int segments = p_closed ? n : (n - 1);

    for (int seg = 0; seg < segments; seg++) {
        int i0 = (seg - 1 + n) % n;
        int i1 = seg;
        int i2 = (seg + 1) % n;
        int i3 = (seg + 2) % n;

        if (!p_closed) {
            i0 = (seg - 1 >= 0) ? seg - 1 : 0;
            i1 = seg;
            i2 = (seg + 1 < n) ? seg + 1 : n - 1;
            i3 = (seg + 2 < n) ? seg + 2 : n - 1;
        }

        const Vector3 &p0 = pts[i0];
        const Vector3 &p1 = pts[i1];
        const Vector3 &p2 = pts[i2];
        const Vector3 &p3 = pts[i3];

        for (int j = 0; j < p_subdivisions; j++) {
            double t = (double)j / p_subdivisions;
            double t2 = t * t;
            double t3 = t2 * t;

            // Catmull-Rom coefficients
            Vector3 v;
            v.x = 0.5 * (2.0 * p1.x + (-p0.x + p2.x) * t +
                   (2.0 * p0.x - 5.0 * p1.x + 4.0 * p2.x - p3.x) * t2 +
                   (-p0.x + 3.0 * p1.x - 3.0 * p2.x + p3.x) * t3);
            v.y = 0.5 * (2.0 * p1.y + (-p0.y + p2.y) * t +
                   (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2 +
                   (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3);
            v.z = 0.5 * (2.0 * p1.z + (-p0.z + p2.z) * t +
                   (2.0 * p0.z - 5.0 * p1.z + 4.0 * p2.z - p3.z) * t2 +
                   (-p0.z + 3.0 * p1.z - 3.0 * p2.z + p3.z) * t3);
            out.push_back(v);
        }
    }

    // Add final point if open
    if (!p_closed) {
        out.push_back(pts[n - 1]);
    }
    return out;
}

Dictionary GNNativePolySplineSop::build_tube(const PackedVector3Array &p_spine,
                                               double p_radius, int p_sides, bool p_closed) const {
    Dictionary result;
    PackedVector3Array verts;
    PackedVector3Array normals;
    PackedVector2Array uvs;
    PackedInt32Array indices;

    int spine_count = p_spine.size();
    if (spine_count < 2 || p_sides < 3) {
        result["vertices"] = verts;
        result["normals"] = normals;
        result["uvs"] = uvs;
        result["indices"] = indices;
        return result;
    }

    const Vector3 *spine = p_spine.ptr();

    // Build cross-section rings
    for (int i = 0; i < spine_count; i++) {
        // Compute tangent
        Vector3 tangent;
        if (i == 0) {
            tangent = (spine[1] - spine[0]).normalized();
        } else if (i == spine_count - 1) {
            tangent = (spine[i] - spine[i - 1]).normalized();
        } else {
            tangent = (spine[i + 1] - spine[i - 1]).normalized();
        }

        // Build basis vectors
        Vector3 up = Vector3(0, 1, 0);
        if (std::abs(tangent.dot(up)) > 0.99) {
            up = Vector3(1, 0, 0);
        }
        Vector3 right = tangent.cross(up).normalized();
        Vector3 actual_up = right.cross(tangent).normalized();

        double uv_v = (double)i / (spine_count - 1);

        for (int j = 0; j <= p_sides; j++) {
            double angle = (2.0 * Math_PI * j) / p_sides;
            double ca = std::cos(angle);
            double sa = std::sin(angle);

            Vector3 offset = right * (ca * p_radius) + actual_up * (sa * p_radius);
            verts.push_back(spine[i] + offset);
            normals.push_back(offset.normalized());
            uvs.push_back(Vector2((double)j / p_sides, uv_v));
        }
    }

    // Build triangle indices
    int ring_verts = p_sides + 1;
    for (int i = 0; i < spine_count - 1; i++) {
        for (int j = 0; j < p_sides; j++) {
            int a = i * ring_verts + j;
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

    result["vertices"] = verts;
    result["normals"] = normals;
    result["uvs"] = uvs;
    result["indices"] = indices;
    return result;
}
