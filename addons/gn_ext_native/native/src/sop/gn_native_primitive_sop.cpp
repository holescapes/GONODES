#include "gn_native_primitive_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <cmath>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
namespace godot {
void GNNativePrimitiveSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "prim_type", "rows", "columns", "radius",
                                  "size_x", "size_y", "size_z"),
                         &GNNativePrimitiveSop::process);
}
Dictionary GNNativePrimitiveSop::process(int prim_type, int rows, int columns,
        double radius, double size_x, double size_y, double size_z) {
    Dictionary result;
    PackedVector3Array vertices;
    PackedVector3Array normals;
    PackedVector2Array uvs;
    PackedInt32Array indices;
    if (prim_type == 0) {
        // Sphere
        int rings = rows < 3 ? 3 : rows;
        int slices = columns < 3 ? 3 : columns;
        for (int r = 0; r <= rings; ++r) {
            double phi = M_PI * r / rings;
            double y = cos(phi) * radius;
            double ring_r = sin(phi) * radius;
            for (int s = 0; s <= slices; ++s) {
                double theta = 2.0 * M_PI * s / slices;
                double x = cos(theta) * ring_r;
                double z = sin(theta) * ring_r;
                Vector3 v(x, y, z);
                vertices.push_back(v);
                normals.push_back(v.normalized());
                uvs.push_back(Vector2((double)s / slices, (double)r / rings));
            }
        }
        for (int r = 0; r < rings; ++r) {
            for (int s = 0; s < slices; ++s) {
                int i0 = r * (slices + 1) + s;
                int i1 = i0 + 1;
                int i2 = i0 + slices + 1;
                int i3 = i2 + 1;
                indices.push_back(i0); indices.push_back(i2); indices.push_back(i1);
                indices.push_back(i1); indices.push_back(i2); indices.push_back(i3);
            }
        }
    } else if (prim_type == 1) {
        // Box
        double hx = size_x * 0.5, hy = size_y * 0.5, hz = size_z * 0.5;
        // 6 faces, 4 verts each
        Vector3 faces[6][4] = {
            {{Vector3(-hx,-hy, hz)}, {Vector3( hx,-hy, hz)}, {Vector3( hx, hy, hz)}, {Vector3(-hx, hy, hz)}},
            {{Vector3( hx,-hy,-hz)}, {Vector3(-hx,-hy,-hz)}, {Vector3(-hx, hy,-hz)}, {Vector3( hx, hy,-hz)}},
            {{Vector3(-hx, hy, hz)}, {Vector3( hx, hy, hz)}, {Vector3( hx, hy,-hz)}, {Vector3(-hx, hy,-hz)}},
            {{Vector3(-hx,-hy,-hz)}, {Vector3( hx,-hy,-hz)}, {Vector3( hx,-hy, hz)}, {Vector3(-hx,-hy, hz)}},
            {{Vector3( hx,-hy, hz)}, {Vector3( hx,-hy,-hz)}, {Vector3( hx, hy,-hz)}, {Vector3( hx, hy, hz)}},
            {{Vector3(-hx,-hy,-hz)}, {Vector3(-hx,-hy, hz)}, {Vector3(-hx, hy, hz)}, {Vector3(-hx, hy,-hz)}}
        };
        Vector3 face_normals[6] = {
            Vector3(0,0,1), Vector3(0,0,-1), Vector3(0,1,0),
            Vector3(0,-1,0), Vector3(1,0,0), Vector3(-1,0,0)
        };
        for (int f = 0; f < 6; ++f) {
            int base = vertices.size();
            for (int v = 0; v < 4; ++v) {
                vertices.push_back(faces[f][v]);
                normals.push_back(face_normals[f]);
            }
            uvs.push_back(Vector2(0,0)); uvs.push_back(Vector2(1,0));
            uvs.push_back(Vector2(1,1)); uvs.push_back(Vector2(0,1));
            indices.push_back(base); indices.push_back(base+1); indices.push_back(base+2);
            indices.push_back(base); indices.push_back(base+2); indices.push_back(base+3);
        }
    } else if (prim_type == 2) {
        // Plane (grid)
        int r = rows < 2 ? 2 : rows;
        int c = columns < 2 ? 2 : columns;
        double dx = size_x / (c - 1), dz = size_z / (r - 1);
        double ox = -size_x * 0.5, oz = -size_z * 0.5;
        for (int ri = 0; ri < r; ++ri) {
            for (int ci = 0; ci < c; ++ci) {
                vertices.push_back(Vector3(ox + ci * dx, 0, oz + ri * dz));
                normals.push_back(Vector3(0, 1, 0));
                uvs.push_back(Vector2((double)ci / (c-1), (double)ri / (r-1)));
            }
        }
        for (int ri = 0; ri < r - 1; ++ri) {
            for (int ci = 0; ci < c - 1; ++ci) {
                int tl = ri * c + ci;
                indices.push_back(tl); indices.push_back(tl + c); indices.push_back(tl + 1);
                indices.push_back(tl + 1); indices.push_back(tl + c); indices.push_back(tl + c + 1);
            }
        }
    } else if (prim_type == 3) {
        // Torus
        int rings = rows < 3 ? 3 : rows;
        int slices = columns < 3 ? 3 : columns;
        double tube_r = radius * 0.3;
        double ring_r = radius - tube_r;
        for (int r = 0; r <= rings; ++r) {
            double theta = 2.0 * M_PI * r / rings;
            Vector3 center(cos(theta) * ring_r, 0, sin(theta) * ring_r);
            for (int s = 0; s <= slices; ++s) {
                double phi = 2.0 * M_PI * s / slices;
                Vector3 local(cos(phi) * tube_r, sin(phi) * tube_r, 0);
                Vector3 radial(cos(theta), 0, sin(theta));
                Vector3 up(0, 1, 0);
                Vector3 tangent(-sin(theta), 0, cos(theta));
                Vector3 pos = center + radial * (cos(phi) * tube_r) + up * (sin(phi) * tube_r);
                vertices.push_back(pos);
                normals.push_back((pos - center).normalized());
                uvs.push_back(Vector2((double)r / rings, (double)s / slices));
            }
        }
        for (int r = 0; r < rings; ++r) {
            for (int s = 0; s < slices; ++s) {
                int i0 = r * (slices + 1) + s;
                int i1 = i0 + 1;
                int i2 = i0 + slices + 1;
                int i3 = i2 + 1;
                indices.push_back(i0); indices.push_back(i2); indices.push_back(i1);
                indices.push_back(i1); indices.push_back(i2); indices.push_back(i3);
            }
        }
    }
    result["vertices"] = vertices;
    result["normals"] = normals;
    result["uvs"] = uvs;
    result["indices"] = indices;
    return result;
}
} // namespace godot
