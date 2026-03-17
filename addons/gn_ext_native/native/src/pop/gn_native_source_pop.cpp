#include "gn_native_source_pop.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <cstdlib>

namespace godot {

void GNNativeSourcePop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "velocities",
                                  "ages", "lives", "pscales",
                                  "particle_count", "max_particles",
                                  "emit_points", "emit_count_this_frame",
                                  "life_min", "life_max", "init_speed",
                                  "pscale", "dt", "seed_time"),
                         &GNNativeSourcePop::process);
}

// Simple deterministic hash-based random
static double _hash_rand(int seed) {
    double n = std::sin((double)seed * 78.233 + 43758.5453);
    return n - std::floor(n);
}

Dictionary GNNativeSourcePop::process(const PackedVector3Array &positions,
                                       const PackedVector3Array &velocities,
                                       const PackedFloat32Array &ages,
                                       const PackedFloat32Array &lives,
                                       const PackedFloat32Array &pscales,
                                       int particle_count, int max_particles,
                                       const PackedVector3Array &emit_points,
                                       int emit_count_this_frame,
                                       double life_min, double life_max,
                                       double init_speed, double pscale,
                                       double dt, double seed_time) {
    Dictionary result;
    const Vector3 *pp = positions.ptr();
    const Vector3 *vp = velocities.ptr();
    const float *ap = ages.ptr();
    const float *lp = lives.ptr();
    const float *sp = pscales.ptr();

    // Age existing particles and compact (kill expired)
    PackedVector3Array out_pos, out_vel;
    PackedFloat32Array out_ages, out_lives, out_pscales;
    out_pos.resize(max_particles);
    out_vel.resize(max_particles);
    out_ages.resize(max_particles);
    out_lives.resize(max_particles);
    out_pscales.resize(max_particles);

    Vector3 *op = out_pos.ptrw();
    Vector3 *ov = out_vel.ptrw();
    float *oa = out_ages.ptrw();
    float *ol = out_lives.ptrw();
    float *os = out_pscales.ptrw();

    int write_idx = 0;
    for (int i = 0; i < particle_count; ++i) {
        float new_age = ap[i] + (float)dt;
        if (new_age < lp[i]) {
            op[write_idx] = pp[i];
            ov[write_idx] = vp[i];
            oa[write_idx] = new_age;
            ol[write_idx] = lp[i];
            os[write_idx] = sp[i];
            ++write_idx;
        }
    }

    // Emit new particles
    int emit_pt_count = emit_points.size();
    if (emit_pt_count == 0) emit_pt_count = 1;
    const Vector3 *ep = emit_points.ptr();
    int seed_base = (int)(seed_time * 10000.0);

    for (int i = 0; i < emit_count_this_frame; ++i) {
        int idx = write_idx + i;
        if (idx >= max_particles) break;

        Vector3 emit_pt = (emit_points.size() > 0) ? ep[i % emit_pt_count] : Vector3(0, 0, 0);
        op[idx] = emit_pt;

        // Random direction via hash
        int s = seed_base + i * 3;
        double rx = _hash_rand(s) * 2.0 - 1.0;
        double ry = _hash_rand(s + 1) * 2.0 - 1.0;
        double rz = _hash_rand(s + 2) * 2.0 - 1.0;
        Vector3 dir(rx, ry, rz);
        double len = dir.length();
        if (len > 0.001) dir /= len;
        ov[idx] = dir * init_speed;

        oa[idx] = 0.0f;
        double life_hash = _hash_rand(s + 7);
        ol[idx] = (float)(life_min + life_hash * (life_max - life_min));
        os[idx] = (float)pscale;
    }

    int final_count = MIN(write_idx + emit_count_this_frame, max_particles);
    out_pos.resize(final_count);
    out_vel.resize(final_count);
    out_ages.resize(final_count);
    out_lives.resize(final_count);
    out_pscales.resize(final_count);

    result["positions"] = out_pos;
    result["velocities"] = out_vel;
    result["ages"] = out_ages;
    result["lives"] = out_lives;
    result["pscales"] = out_pscales;
    result["count"] = final_count;
    return result;
}

} // namespace godot
