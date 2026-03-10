#include "gn_native_polyreduce.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cmath>
#include <cstring>

using namespace godot;

void GNNativePolyReduce::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "indices",
                                  "target_percent", "preserve_boundary", "boundary_weight"),
                         &GNNativePolyReduce::process);
}

int GNNativePolyReduce::_resolve(int v, int *remap) {
    int iters = 0;
    while (remap[v] != v && iters < 10000) {
        remap[v] = remap[remap[v]];  // path compression
        v = remap[v];
        ++iters;
    }
    return v;
}

uint64_t GNNativePolyReduce::_edge_key(int a, int b) {
    if (a > b) {
        return (static_cast<uint64_t>(a) << 20) | static_cast<uint64_t>(b);
    }
    return (static_cast<uint64_t>(b) << 20) | static_cast<uint64_t>(a);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Weld non-indexed mesh to indexed
// ═══════════════════════════════════════════════════════════════════════════════

struct WeldResult {
    PackedVector3Array positions;
    PackedInt32Array indices;
};

static WeldResult _weld_vertices(const PackedVector3Array &verts) {
    WeldResult wr;
    HashMap<uint64_t, int> map;
    int count = verts.size();
    const Vector3 *ptr = verts.ptr();

    for (int i = 0; i < count; ++i) {
        // Quantise to ~0.1mm precision
        int64_t qx = static_cast<int64_t>(ptr[i].x * 10000.0);
        int64_t qy = static_cast<int64_t>(ptr[i].y * 10000.0);
        int64_t qz = static_cast<int64_t>(ptr[i].z * 10000.0);
        // Simple hash combine
        uint64_t key = static_cast<uint64_t>(qx * 73856093LL ^ qy * 19349663LL ^ qz * 83492791LL);

        HashMap<uint64_t, int>::Iterator it = map.find(key);
        if (it != map.end()) {
            wr.indices.push_back(it->value);
        } else {
            int ni = wr.positions.size();
            map.insert(key, ni);
            wr.positions.push_back(ptr[i]);
            wr.indices.push_back(ni);
        }
    }
    return wr;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Edge collapse candidate
// ═══════════════════════════════════════════════════════════════════════════════

struct CollapseCandidate {
    double cost;
    Vector3 optimal_pos;
    int va, vb;
};

static CollapseCandidate _compute_collapse(int a, int b,
                                           const Vector3 *pos,
                                           const GNNativePolyReduce::Quadric *quadrics) {
    GNNativePolyReduce::Quadric combined = quadrics[a];
    combined.add(quadrics[b]);

    Vector3 mid = (pos[a] + pos[b]) * 0.5;
    double cost_a   = combined.eval(pos[a]);
    double cost_b   = combined.eval(pos[b]);
    double cost_mid = combined.eval(mid);

    CollapseCandidate cc;
    cc.cost = cost_mid;
    cc.optimal_pos = mid;
    cc.va = a;
    cc.vb = b;
    if (cost_a < cc.cost) { cc.cost = cost_a; cc.optimal_pos = pos[a]; }
    if (cost_b < cc.cost) { cc.cost = cost_b; cc.optimal_pos = pos[b]; }
    return cc;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Main process
// ═══════════════════════════════════════════════════════════════════════════════

Dictionary GNNativePolyReduce::process(const PackedVector3Array &p_positions,
                                        const PackedInt32Array &p_indices,
                                        double target_percent,
                                        bool preserve_boundary,
                                        double boundary_weight) {
    Dictionary result;

    // Prepare indexed data
    PackedVector3Array positions;
    PackedInt32Array triangles;

    if (p_indices.size() >= 3) {
        positions = p_positions;
        triangles = p_indices;
    } else {
        // Non-indexed — weld
        WeldResult wr = _weld_vertices(p_positions);
        positions = wr.positions;
        triangles = wr.indices;
    }

    int vert_count = positions.size();
    int tri_count = triangles.size() / 3;
    if (tri_count == 0 || vert_count < 3) {
        result["positions"] = p_positions;
        result["normals"] = PackedVector3Array();
        result["indices"] = p_indices;
        return result;
    }

    double pct = CLAMP(target_percent, 1.0, 100.0) / 100.0;
    int target_tris = MAX(static_cast<int>(tri_count * pct), 1);
    if (tri_count <= target_tris) {
        result["positions"] = p_positions;
        result["normals"] = PackedVector3Array();
        result["indices"] = p_indices;
        return result;
    }

    Vector3 *pos = positions.ptrw();
    int *tris = triangles.ptrw();

    // ── Compute initial quadrics from face planes ──
    Quadric *quadrics = new Quadric[vert_count]();
    int *remap = new int[vert_count];
    uint8_t *alive = new uint8_t[vert_count];
    memset(alive, 1, vert_count);
    for (int i = 0; i < vert_count; ++i) remap[i] = i;

    for (int ti = 0; ti < tri_count; ++ti) {
        int i0 = tris[ti*3], i1 = tris[ti*3+1], i2 = tris[ti*3+2];
        Vector3 e1 = pos[i1] - pos[i0];
        Vector3 e2 = pos[i2] - pos[i0];
        Vector3 n = e1.cross(e2);
        double len = n.length();
        if (len < 0.00001) continue;
        n /= len;
        double d = -n.dot(pos[i0]);
        Quadric pq = Quadric::from_plane(n.x, n.y, n.z, d);
        quadrics[i0].add(pq);
        quadrics[i1].add(pq);
        quadrics[i2].add(pq);
    }

    // ── Boundary detection + penalty ──
    HashMap<uint64_t, int> edge_face_count;
    for (int ti = 0; ti < tri_count; ++ti) {
        for (int ei = 0; ei < 3; ++ei) {
            int a = tris[ti*3 + ei];
            int b = tris[ti*3 + (ei+1)%3];
            uint64_t key = _edge_key(a, b);
            HashMap<uint64_t, int>::Iterator it = edge_face_count.find(key);
            if (it != edge_face_count.end()) {
                it->value += 1;
            } else {
                edge_face_count.insert(key, 1);
            }
        }
    }

    if (preserve_boundary) {
        int bw = MAX(static_cast<int>(boundary_weight), 1);
        for (auto it = edge_face_count.begin(); it != edge_face_count.end(); ++it) {
            if (it->value != 1) continue;
            int a = static_cast<int>(it->key >> 20);
            int b = static_cast<int>(it->key & 0xFFFFF);
            Vector3 mid = (pos[a] + pos[b]) * 0.5;
            Vector3 edge_dir = (pos[b] - pos[a]).normalized();
            if (edge_dir.length_squared() < 0.0001) continue;

            Vector3 up(0, 1, 0);
            if (fabs(edge_dir.dot(up)) > 0.99) up = Vector3(1, 0, 0);
            Vector3 n1 = edge_dir.cross(up).normalized();
            Vector3 n2 = edge_dir.cross(n1).normalized();
            Quadric bq1 = Quadric::from_plane(n1.x, n1.y, n1.z, -n1.dot(mid));
            Quadric bq2 = Quadric::from_plane(n2.x, n2.y, n2.z, -n2.dot(mid));
            for (int w = 0; w < bw; ++w) {
                quadrics[a].add(bq1); quadrics[a].add(bq2);
                quadrics[b].add(bq1); quadrics[b].add(bq2);
            }
        }
    }

    // ── Build edge collapse candidates ──
    HashMap<uint64_t, CollapseCandidate> edge_set;
    for (int ti = 0; ti < tri_count; ++ti) {
        for (int ei = 0; ei < 3; ++ei) {
            int a = tris[ti*3 + ei];
            int b = tris[ti*3 + (ei+1)%3];
            uint64_t key = _edge_key(a, b);
            if (!edge_set.has(key)) {
                edge_set.insert(key, _compute_collapse(a, b, pos, quadrics));
            }
        }
    }

    // ── Iterative edge collapse ──
    int current_tris = tri_count;

    while (current_tris > target_tris && edge_set.size() > 0) {
        // Find minimum cost edge (linear scan)
        uint64_t best_key = 0;
        double best_cost = 1e30;
        bool found = false;

        for (auto it = edge_set.begin(); it != edge_set.end(); ++it) {
            if (it->value.cost < best_cost) {
                best_cost = it->value.cost;
                best_key = it->key;
                found = true;
            }
        }
        if (!found) break;

        CollapseCandidate cc = edge_set[best_key];
        edge_set.erase(best_key);

        int va = _resolve(cc.va, remap);
        int vb = _resolve(cc.vb, remap);
        if (va == vb) continue;

        // Collapse vb into va
        pos[va] = cc.optimal_pos;
        quadrics[va].add(quadrics[vb]);
        alive[vb] = 0;
        remap[vb] = va;

        // Update triangles, remove degenerates
        int ti = 0;
        while (ti < current_tris) {
            int base = ti * 3;
            for (int ci = 0; ci < 3; ++ci) {
                if (tris[base + ci] == vb) tris[base + ci] = va;
            }
            if (tris[base] == tris[base+1] || tris[base+1] == tris[base+2] ||
                tris[base] == tris[base+2]) {
                int last = (current_tris - 1) * 3;
                tris[base] = tris[last]; tris[base+1] = tris[last+1]; tris[base+2] = tris[last+2];
                --current_tris;
            } else {
                ++ti;
            }
        }

        // Remove stale edges, recompute edges involving va
        // Collect keys first to avoid iterator invalidation
        LocalVector<uint64_t> to_remove;
        LocalVector<uint64_t> to_recompute;

        for (auto it = edge_set.begin(); it != edge_set.end(); ++it) {
            int ea = _resolve(it->value.va, remap);
            int eb = _resolve(it->value.vb, remap);
            if (ea == eb) {
                to_remove.push_back(it->key);
            } else if (ea == va || eb == va) {
                to_recompute.push_back(it->key);
            }
        }
        for (uint32_t i = 0; i < to_remove.size(); ++i) {
            edge_set.erase(to_remove[i]);
        }
        for (uint32_t i = 0; i < to_recompute.size(); ++i) {
            auto it = edge_set.find(to_recompute[i]);
            if (it == edge_set.end()) continue;
            int ea = _resolve(it->value.va, remap);
            int eb = _resolve(it->value.vb, remap);
            edge_set.erase(to_recompute[i]);
            uint64_t new_key = _edge_key(ea, eb);
            edge_set[new_key] = _compute_collapse(ea, eb, pos, quadrics);
        }
    }

    // ── Compact output ──
    HashMap<int, int> compact_remap;
    PackedVector3Array final_verts;
    PackedInt32Array final_indices;

    for (int ti = 0; ti < current_tris; ++ti) {
        for (int ci = 0; ci < 3; ++ci) {
            int vi = _resolve(tris[ti*3 + ci], remap);
            HashMap<int, int>::Iterator it = compact_remap.find(vi);
            if (it == compact_remap.end()) {
                int ni = final_verts.size();
                compact_remap.insert(vi, ni);
                final_verts.push_back(pos[vi]);
                final_indices.push_back(ni);
            } else {
                final_indices.push_back(it->value);
            }
        }
    }

    delete[] quadrics;
    delete[] remap;
    delete[] alive;

    if (final_verts.is_empty()) {
        result["positions"] = p_positions;
        result["normals"] = PackedVector3Array();
        result["indices"] = p_indices;
        return result;
    }

    // ── Recompute smooth normals ──
    PackedVector3Array final_normals;
    int fv_count = final_verts.size();
    final_normals.resize(fv_count);
    Vector3 *fn_ptr = final_normals.ptrw();
    const Vector3 *fv_ptr = final_verts.ptr();
    const int *fi_ptr = final_indices.ptr();
    int fi_tri_count = final_indices.size() / 3;

    for (int i = 0; i < fv_count; ++i) fn_ptr[i] = Vector3(0, 0, 0);

    for (int ti = 0; ti < fi_tri_count; ++ti) {
        int i0 = fi_ptr[ti*3], i1 = fi_ptr[ti*3+1], i2 = fi_ptr[ti*3+2];
        Vector3 e1 = fv_ptr[i1] - fv_ptr[i0];
        Vector3 e2 = fv_ptr[i2] - fv_ptr[i0];
        Vector3 fn = e1.cross(e2);
        fn_ptr[i0] += fn;
        fn_ptr[i1] += fn;
        fn_ptr[i2] += fn;
    }
    for (int i = 0; i < fv_count; ++i) {
        double len = fn_ptr[i].length();
        if (len > 0.0001) {
            fn_ptr[i] /= len;
        } else {
            fn_ptr[i] = Vector3(0, 1, 0);
        }
    }

    result["positions"] = final_verts;
    result["normals"] = final_normals;
    result["indices"] = final_indices;
    return result;
}
