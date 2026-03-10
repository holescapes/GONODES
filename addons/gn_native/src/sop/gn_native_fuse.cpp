#include "gn_native_fuse.h"

#include <godot_cpp/core/class_db.hpp>
#include <unordered_map>
#include <vector>
#include <cmath>

using namespace godot;

void GNNativeFuse::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "normals", "uvs", "indices", "threshold"),
                         &GNNativeFuse::process);
}

Dictionary GNNativeFuse::process(const PackedVector3Array &positions,
                                  const PackedVector3Array &normals,
                                  const PackedVector2Array &uvs,
                                  const PackedInt32Array &indices,
                                  double threshold) {
    float cell_size = (float)fmax(threshold, 0.0001);
    float dist_sq = (float)(threshold * threshold);
    int vcount = positions.size();
    const Vector3 *vp = positions.ptr();

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

    // Remap indices, skip degenerate tris
    PackedInt32Array idx = indices;
    if (idx.is_empty()) {
        idx.resize(vcount);
        int32_t *ip = idx.ptrw();
        for (int i = 0; i < vcount; ++i) ip[i] = i;
    }

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

    Dictionary result;
    result["positions"] = unique_pos;
    result["uvs"] = unique_uvs;
    result["indices"] = new_indices;
    return result;
}
