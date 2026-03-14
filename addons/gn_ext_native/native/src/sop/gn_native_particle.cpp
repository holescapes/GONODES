#include "gn_native_particle.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <cmath>
#include <algorithm>

using namespace godot;

void GNNativeParticle::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_emitter", "vertices", "normals", "indices"),
                         &GNNativeParticle::set_emitter);
    ClassDB::bind_method(D_METHOD("step", "dt", "rate", "max_particles",
                                  "life", "life_rand", "emit_speed", "speed_rand", "spread",
                                  "gravity", "drag", "turbulence",
                                  "attract_force", "attractor_pos",
                                  "floor_enabled", "floor_y", "bounce", "seed"),
                         &GNNativeParticle::step);
    ClassDB::bind_method(D_METHOD("reset"), &GNNativeParticle::reset);
    ClassDB::bind_method(D_METHOD("get_particle_count"), &GNNativeParticle::get_particle_count);
}

GNNativeParticle::GNNativeParticle()
    : _next_id(0), _emit_accum(0.0), _tri_total_area(0.0), _rng_state(1) {
}

// ---------------------------------------------------------------------------
// RNG
// ---------------------------------------------------------------------------

double GNNativeParticle::_randf() {
    _rng_state ^= _rng_state << 13;
    _rng_state ^= _rng_state >> 7;
    _rng_state ^= _rng_state << 17;
    return static_cast<double>(_rng_state & 0xFFFFFFFF) / 4294967295.0;
}

double GNNativeParticle::_randf_range(double lo, double hi) {
    return lo + _randf() * (hi - lo);
}

// ---------------------------------------------------------------------------
// Emitter setup
// ---------------------------------------------------------------------------

void GNNativeParticle::set_emitter(const PackedVector3Array &p_vertices,
                                    const PackedVector3Array &p_normals,
                                    const PackedInt32Array &p_indices) {
    _triangles.clear();
    _tri_cdf.clear();
    _tri_total_area = 0.0;

    // Build flat list of triangles
    PackedInt32Array indices = p_indices;
    if (indices.is_empty()) {
        // Non-indexed: every 3 vertices = 1 triangle
        indices.resize(p_vertices.size());
        for (int i = 0; i < p_vertices.size(); ++i) {
            indices[i] = i;
        }
    }

    int tri_count = indices.size() / 3;
    _triangles.reserve(tri_count);

    PackedFloat64Array areas;
    areas.resize(tri_count);

    bool has_norms = p_normals.size() >= p_vertices.size();

    for (int t = 0; t < tri_count; ++t) {
        int i0 = indices[t * 3];
        int i1 = indices[t * 3 + 1];
        int i2 = indices[t * 3 + 2];

        Triangle tri;
        tri.v[0] = p_vertices[i0];
        tri.v[1] = p_vertices[i1];
        tri.v[2] = p_vertices[i2];
        tri.has_normals = has_norms;

        if (has_norms) {
            tri.n[0] = p_normals[i0];
            tri.n[1] = p_normals[i1];
            tri.n[2] = p_normals[i2];
        }

        _triangles.push_back(tri);

        Vector3 cross = (tri.v[1] - tri.v[0]).cross(tri.v[2] - tri.v[0]);
        areas[t] = cross.length() * 0.5;
    }

    if (_triangles.empty()) return;

    // Build CDF
    _tri_cdf.resize(tri_count);
    _tri_cdf[0] = areas[0];
    for (int i = 1; i < tri_count; ++i) {
        _tri_cdf[i] = _tri_cdf[i - 1] + areas[i];
    }
    _tri_total_area = _tri_cdf[tri_count - 1];
}

// ---------------------------------------------------------------------------
// Step
// ---------------------------------------------------------------------------

Dictionary GNNativeParticle::step(double p_dt,
                                  double p_rate, int p_max_particles,
                                  double p_life, double p_life_rand,
                                  double p_emit_speed, double p_speed_rand, double p_spread,
                                  double p_gravity, double p_drag, double p_turbulence,
                                  double p_attract_force, const Vector3 &p_attractor_pos,
                                  bool p_floor_enabled, double p_floor_y, double p_bounce,
                                  int p_seed) {
    // Seed RNG on first call (or when seed changes)
    if (_rng_state == 1 || p_seed != 0) {
        _rng_state = static_cast<uint64_t>(p_seed) ^ 0x5DEECE66DULL;
        if (_rng_state == 0) _rng_state = 1;
    }

    if (_triangles.empty()) {
        Dictionary result;
        result["positions"] = PackedVector3Array();
        result["ages"] = PackedFloat32Array();
        result["lives"] = PackedFloat32Array();
        result["age_norm"] = PackedFloat32Array();
        result["count"] = 0;
        return result;
    }

    // ── Emit new particles ──
    _emit_accum += p_rate * p_dt;
    int to_emit = static_cast<int>(_emit_accum);
    _emit_accum -= static_cast<double>(to_emit);

    for (int e = 0; e < to_emit; ++e) {
        if (_positions.size() >= p_max_particles) {
            _remove_particle(0); // Kill oldest
        }
        _spawn_particle(p_life, p_life_rand, p_emit_speed, p_speed_rand, p_spread);
    }

    // ── Simulate ──
    Vector3 grav_vec(0.0, p_gravity, 0.0);
    double drag_factor = MAX(1.0 - p_drag * p_dt, 0.0);
    bool use_attract = p_attract_force != 0.0;

    // Kill list (collect indices, remove in reverse)
    std::vector<int> kill_list;
    int count = _positions.size();

    for (int i = 0; i < count; ++i) {
        _ages[i] += static_cast<float>(p_dt);
        if (_ages[i] >= _lives[i]) {
            kill_list.push_back(i);
            continue;
        }

        Vector3 accel = grav_vec;

        if (use_attract) {
            Vector3 to_target = p_attractor_pos - _positions[i];
            double dist = to_target.length();
            if (dist > 0.01) {
                accel += to_target.normalized() * p_attract_force;
            }
        }

        if (p_turbulence > 0.0) {
            accel += Vector3(
                _randf_range(-1.0, 1.0),
                _randf_range(-1.0, 1.0),
                _randf_range(-1.0, 1.0)) * p_turbulence;
        }

        Vector3 vel = _velocities[i];
        vel += accel * p_dt;
        vel *= drag_factor;
        _velocities[i] = vel;

        Vector3 pos = _positions[i] + vel * p_dt;

        // Floor collision
        if (p_floor_enabled && pos.y < p_floor_y) {
            pos.y = p_floor_y;
            if (p_bounce > 0.0) {
                Vector3 v = _velocities[i];
                v.y = std::abs(v.y) * p_bounce;
                _velocities[i] = v;
            } else {
                _velocities[i] = Vector3();
            }
        }

        _positions[i] = pos;
    }

    // Kill dead particles (reverse order)
    for (int ki = static_cast<int>(kill_list.size()) - 1; ki >= 0; --ki) {
        _remove_particle(kill_list[ki]);
    }

    // ── Build output ──
    count = _positions.size();
    PackedFloat32Array age_norm;
    age_norm.resize(count);
    for (int i = 0; i < count; ++i) {
        age_norm[i] = _ages[i] / MAX(_lives[i], 0.001f);
    }

    Dictionary result;
    result["positions"] = _positions.duplicate();
    result["ages"] = _ages.duplicate();
    result["lives"] = _lives.duplicate();
    result["age_norm"] = age_norm;
    result["count"] = count;
    return result;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void GNNativeParticle::reset() {
    _positions.clear();
    _velocities.clear();
    _ages.clear();
    _lives.clear();
    _next_id = 0;
    _emit_accum = 0.0;
    _rng_state = 1;
}

int GNNativeParticle::get_particle_count() const {
    return _positions.size();
}

void GNNativeParticle::_spawn_particle(double life_base, double life_rand,
                                        double speed, double speed_rand, double spread) {
    if (_triangles.empty() || _tri_total_area <= 0.0) return;

    // Binary search CDF for triangle selection
    double r = _randf() * _tri_total_area;
    int lo = 0, hi = static_cast<int>(_tri_cdf.size()) - 1;
    while (lo < hi) {
        int mid = (lo + hi) / 2;
        if (_tri_cdf[mid] < r) lo = mid + 1;
        else hi = mid;
    }
    int tidx = lo;

    // Random barycentric coordinates
    double u = _randf();
    double v = _randf();
    if (u + v > 1.0) {
        u = 1.0 - u;
        v = 1.0 - v;
    }
    double w = 1.0 - u - v;

    const Triangle &tri = _triangles[tidx];
    Vector3 pos = tri.v[0] * w + tri.v[1] * u + tri.v[2] * v;

    // Normal direction
    Vector3 normal(0.0, 1.0, 0.0);
    if (tri.has_normals) {
        normal = (tri.n[0] * w + tri.n[1] * u + tri.n[2] * v).normalized();
    }

    // Apply spread (cone deviation)
    if (spread > 0.0) {
        double spread_rad = spread * (Math_PI / 180.0);
        Vector3 rand_dir = Vector3(
            _randf_range(-1.0, 1.0),
            _randf_range(-1.0, 1.0),
            _randf_range(-1.0, 1.0)).normalized();
        double t = _randf() * spread_rad / Math_PI;
        normal = normal.slerp(rand_dir, t).normalized();
    }

    // Velocity
    double spd = speed;
    if (speed_rand > 0.0) {
        spd *= (1.0 + _randf_range(-speed_rand, speed_rand));
    }
    Vector3 vel = normal * spd;

    // Life
    double life = life_base;
    if (life_rand > 0.0) {
        life *= (1.0 + _randf_range(-life_rand, life_rand));
    }
    life = MAX(life, 0.01);

    _positions.append(pos);
    _velocities.append(vel);
    _ages.append(0.0f);
    _lives.append(static_cast<float>(life));
    _next_id++;
}

void GNNativeParticle::_remove_particle(int idx) {
    int last = _positions.size() - 1;
    if (idx < last) {
        _positions[idx] = _positions[last];
        _velocities[idx] = _velocities[last];
        _ages[idx] = _ages[last];
        _lives[idx] = _lives[last];
    }
    _positions.resize(last);
    _velocities.resize(last);
    _ages.resize(last);
    _lives.resize(last);
}
