#include "gn_native_cloth_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <unordered_set>

using namespace godot;

void GNNativeClothSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("init_simulation", "positions", "indices", "pinned"),
                         &GNNativeClothSop::init_simulation);
    ClassDB::bind_method(D_METHOD("step", "dt", "gravity", "damping", "wind", "iterations", "stiffness"),
                         &GNNativeClothSop::step);
    ClassDB::bind_method(D_METHOD("get_positions"), &GNNativeClothSop::get_positions);
    ClassDB::bind_method(D_METHOD("compute_normals"), &GNNativeClothSop::compute_normals);
    ClassDB::bind_method(D_METHOD("reset"), &GNNativeClothSop::reset);
    ClassDB::bind_method(D_METHOD("is_initialized"), &GNNativeClothSop::is_initialized);
}

void GNNativeClothSop::init_simulation(const PackedVector3Array &p_positions,
                                        const PackedInt32Array &p_indices,
                                        const PackedInt32Array &p_pinned) {
    _positions = p_positions;
    _prev_positions = p_positions;
    _indices = p_indices;
    _pinned = p_pinned;

    // Build edge list from triangle indices with deduplication
    _edge_a.clear();
    _edge_b.clear();
    _rest_lengths.clear();

    std::unordered_set<int64_t> edge_set;
    const int *idx_ptr = p_indices.ptr();
    const Vector3 *pos_ptr = p_positions.ptr();
    int tri_count = p_indices.size() / 3;

    auto add_edge = [&](int a, int b) {
        int lo = a < b ? a : b;
        int hi = a < b ? b : a;
        int64_t key = (int64_t)lo * 1000000LL + (int64_t)hi;
        if (edge_set.count(key)) return;
        edge_set.insert(key);
        _edge_a.append(a);
        _edge_b.append(b);
        _rest_lengths.append(pos_ptr[a].distance_to(pos_ptr[b]));
    };

    if (tri_count > 0) {
        for (int i = 0; i < tri_count; i++) {
            int i0 = idx_ptr[i * 3];
            int i1 = idx_ptr[i * 3 + 1];
            int i2 = idx_ptr[i * 3 + 2];
            add_edge(i0, i1);
            add_edge(i1, i2);
            add_edge(i2, i0);
        }
    } else {
        // Non-indexed: consecutive triplets
        int vert_count = p_positions.size();
        for (int i = 0; i + 2 < vert_count; i += 3) {
            add_edge(i, i + 1);
            add_edge(i + 1, i + 2);
            add_edge(i + 2, i);
        }
    }

    _initialized = true;
}

void GNNativeClothSop::step(double p_dt, double p_gravity, double p_damping,
                             const Vector3 &p_wind, int p_iterations, double p_stiffness) {
    if (!_initialized) return;

    int count = _positions.size();
    Vector3 *pos = _positions.ptrw();
    Vector3 *prev = _prev_positions.ptrw();

    // --- Verlet integration ---
    double dt2 = p_dt * p_dt;
    Vector3 grav(0.0, p_gravity * dt2, 0.0);
    Vector3 wind_force = p_wind * dt2;
    float damp = (float)p_damping;

    for (int i = 0; i < count; i++) {
        Vector3 vel = (pos[i] - prev[i]) * damp;
        prev[i] = pos[i];
        pos[i] += vel + grav + wind_force;
    }

    // --- Distance constraints ---
    int edge_count = _edge_a.size();
    const int *ea = _edge_a.ptr();
    const int *eb = _edge_b.ptr();
    const float *rl = _rest_lengths.ptr();
    float stiff = (float)p_stiffness;

    for (int iter = 0; iter < p_iterations; iter++) {
        for (int i = 0; i < edge_count; i++) {
            int a = ea[i];
            int b = eb[i];
            Vector3 delta = pos[b] - pos[a];
            float dist = delta.length();
            if (dist < 1e-8f) continue;
            float diff = (dist - rl[i]) / dist * stiff;
            Vector3 offset = delta * (diff * 0.5f);
            pos[a] += offset;
            pos[b] -= offset;
        }
    }

    // --- Pin enforcement ---
    int pin_count = _pinned.size();
    const int *pins = _pinned.ptr();
    for (int i = 0; i < pin_count; i++) {
        int idx = pins[i];
        pos[idx] = prev[idx];
        prev[idx] = pos[idx];
    }
}

PackedVector3Array GNNativeClothSop::get_positions() const {
    return _positions;
}

PackedVector3Array GNNativeClothSop::compute_normals() const {
    int count = _positions.size();
    PackedVector3Array normals;
    normals.resize(count);
    Vector3 *n = normals.ptrw();
    const Vector3 *v = _positions.ptr();

    // Zero init
    for (int i = 0; i < count; i++) {
        n[i] = Vector3(0, 0, 0);
    }

    // Accumulate face normals
    const int *idx = _indices.ptr();
    int tri_count = _indices.size() / 3;
    if (tri_count > 0) {
        for (int i = 0; i < tri_count; i++) {
            int i0 = idx[i * 3];
            int i1 = idx[i * 3 + 1];
            int i2 = idx[i * 3 + 2];
            Vector3 face_n = (v[i1] - v[i0]).cross(v[i2] - v[i0]);
            n[i0] += face_n;
            n[i1] += face_n;
            n[i2] += face_n;
        }
    } else {
        for (int i = 0; i + 2 < count; i += 3) {
            Vector3 face_n = (v[i + 1] - v[i]).cross(v[i + 2] - v[i]);
            n[i] += face_n;
            n[i + 1] += face_n;
            n[i + 2] += face_n;
        }
    }

    // Normalize
    for (int i = 0; i < count; i++) {
        float len2 = n[i].length_squared();
        n[i] = len2 > 1e-10f ? n[i].normalized() : Vector3(0, 1, 0);
    }

    return normals;
}

void GNNativeClothSop::reset() {
    _positions.clear();
    _prev_positions.clear();
    _indices.clear();
    _edge_a.clear();
    _edge_b.clear();
    _rest_lengths.clear();
    _pinned.clear();
    _initialized = false;
}

bool GNNativeClothSop::is_initialized() const {
    return _initialized;
}
