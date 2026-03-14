#include "gn_native_facet.h"

#include <godot_cpp/core/class_db.hpp>
#include <unordered_map>
#include <vector>
#include <cmath>

using namespace godot;

void GNNativeFacet::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "uvs", "indices", "mode", "distance"),
                         &GNNativeFacet::process);
}

Dictionary GNNativeFacet::process(const PackedVector3Array &positions,
                                   const PackedVector2Array &uvs,
                                   const PackedInt32Array &indices,
                                   int mode, double distance) {
    Dictionary result;

    // Build index buffer if empty
    PackedInt32Array idx = indices;
    if (idx.is_empty()) {
        idx.resize(positions.size());
        int32_t *ip = idx.ptrw();
        for (int i = 0; i < (int)positions.size(); ++i) ip[i] = i;
    }

    if (mode == 0) {
        // Make unique: expand indexed triangles to non-indexed triangle soup
        int tri_count = idx.size() / 3;
        PackedVector3Array out_verts;
        PackedVector2Array out_uvs;
        out_verts.resize(tri_count * 3);
        if (!uvs.is_empty()) out_uvs.resize(tri_count * 3);

        const Vector3 *vp = positions.ptr();
        const int32_t *ip = idx.ptr();
        Vector3 *ov = out_verts.ptrw();

        for (int t = 0; t < tri_count; ++t) {
            ov[t * 3]     = vp[ip[t * 3]];
            ov[t * 3 + 1] = vp[ip[t * 3 + 1]];
            ov[t * 3 + 2] = vp[ip[t * 3 + 2]];
            if (!uvs.is_empty()) {
                Vector2 *ouv = out_uvs.ptrw();
                const Vector2 *iuv = uvs.ptr();
                int i0 = ip[t * 3], i1 = ip[t * 3 + 1], i2 = ip[t * 3 + 2];
                ouv[t * 3]     = (i0 < (int)uvs.size()) ? iuv[i0] : Vector2();
                ouv[t * 3 + 1] = (i1 < (int)uvs.size()) ? iuv[i1] : Vector2();
                ouv[t * 3 + 2] = (i2 < (int)uvs.size()) ? iuv[i2] : Vector2();
            }
        }

        // Compute flat normals
        PackedVector3Array out_normals;
        out_normals.resize(tri_count * 3);
        Vector3 *on = out_normals.ptrw();
        for (int t = 0; t < tri_count; ++t) {
            Vector3 face_n = (ov[t * 3 + 1] - ov[t * 3]).cross(ov[t * 3 + 2] - ov[t * 3]).normalized();
            on[t * 3]     = face_n;
            on[t * 3 + 1] = face_n;
            on[t * 3 + 2] = face_n;
        }

        result["positions"] = out_verts;
        result["normals"] = out_normals;
        result["uvs"] = out_uvs;
        result["indices"] = PackedInt32Array(); // non-indexed
    } else {
        // Consolidate: spatial hash merge
        float dist_sq = (float)(distance * distance);
        float cell_size = (float)fmax(distance, 0.0001);
        int vcount = positions.size();

        struct CellKey {
            int x, y, z;
            bool operator==(const CellKey &o) const { return x == o.x && y == o.y && z == o.z; }
        };
        struct CellHash {
            size_t operator()(const CellKey &k) const {
                size_t h = std::hash<int>()(k.x);
                h ^= std::hash<int>()(k.y) + 0x9e3779b9 + (h << 6) + (h >> 2);
                h ^= std::hash<int>()(k.z) + 0x9e3779b9 + (h << 6) + (h >> 2);
                return h;
            }
        };

        std::unordered_map<CellKey, std::vector<int>, CellHash> grid;
        std::vector<int> merge_map(vcount);
        PackedVector3Array unique_pos;
        PackedVector2Array unique_uvs;
        const Vector3 *vp = positions.ptr();

        for (int i = 0; i < vcount; ++i) {
            Vector3 p = vp[i];
            CellKey cell = {(int)std::floor(p.x / cell_size),
                            (int)std::floor(p.y / cell_size),
                            (int)std::floor(p.z / cell_size)};

            int found = -1;
            for (int dx = -1; dx <= 1 && found < 0; ++dx) {
                for (int dy = -1; dy <= 1 && found < 0; ++dy) {
                    for (int dz = -1; dz <= 1 && found < 0; ++dz) {
                        CellKey nc = {cell.x + dx, cell.y + dy, cell.z + dz};
                        auto it = grid.find(nc);
                        if (it != grid.end()) {
                            for (int ui : it->second) {
                                if (unique_pos[ui].distance_squared_to(p) <= dist_sq) {
                                    found = ui;
                                    break;
                                }
                            }
                        }
                    }
                }
            }

            if (found >= 0) {
                merge_map[i] = found;
            } else {
                int new_idx = unique_pos.size();
                merge_map[i] = new_idx;
                unique_pos.push_back(p);
                if (!uvs.is_empty() && i < (int)uvs.size()) {
                    unique_uvs.push_back(uvs[i]);
                }
                grid[cell].push_back(new_idx);
            }
        }

        // Remap indices and skip degenerate triangles
        const int32_t *ip = idx.ptr();
        PackedInt32Array new_indices;
        int tri_count = idx.size() / 3;
        for (int t = 0; t < tri_count; ++t) {
            int i0 = merge_map[ip[t * 3]];
            int i1 = merge_map[ip[t * 3 + 1]];
            int i2 = merge_map[ip[t * 3 + 2]];
            if (i0 == i1 || i1 == i2 || i2 == i0) continue;
            new_indices.push_back(i0);
            new_indices.push_back(i1);
            new_indices.push_back(i2);
        }

        result["positions"] = unique_pos;
        result["normals"] = PackedVector3Array(); // caller should generate normals via SurfaceTool
        result["uvs"] = unique_uvs;
        result["indices"] = new_indices;
    }

    return result;
}
