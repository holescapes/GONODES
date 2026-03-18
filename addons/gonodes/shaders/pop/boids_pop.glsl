[compute]
#version 450

layout(local_size_x = 256) in;

// Standard POP particle struct (64 bytes, matches GNPopBase.STANDARD_STRIDE)
struct Particle {
    vec4 pos;      // xyz = position, w = unused
    vec4 vel;      // xyz = velocity, w = unused
    vec4 color;    // rgba
    float age;
    float life;
    float mass;
    float pscale;
};

layout(set = 0, binding = 0, std430) restrict buffer ParticleBuffer {
    Particle particles[];
};

layout(push_constant) uniform PushConstants {
    int   particle_count;
    float dt;
    float perception_radius;  // neighbor search radius
    float separation_weight;
    float alignment_weight;
    float cohesion_weight;
    float max_speed;
    float max_force;          // steering force clamp
    float avoid_radius;       // minimum separation distance
    float bounds_radius;      // spherical boundary radius (0 = no bounds)
    float bounds_force;       // boundary steering strength
    float seed;               // time-based seed for jitter
} pc;

// Clamp vector length
vec3 clamp_mag(vec3 v, float max_len) {
    float len = length(v);
    return len > max_len ? v * (max_len / len) : v;
}

void main() {
    uint gid = gl_GlobalInvocationID.x;
    if (gid >= pc.particle_count) return;

    // Skip dead particles
    if (particles[gid].age >= particles[gid].life) return;

    vec3 my_pos = particles[gid].pos.xyz;
    vec3 my_vel = particles[gid].vel.xyz;

    // Accumulators for Reynolds rules
    vec3 sep_sum = vec3(0.0);   int sep_count = 0;
    vec3 ali_sum = vec3(0.0);   int ali_count = 0;
    vec3 coh_sum = vec3(0.0);   int coh_count = 0;

    float r2 = pc.perception_radius * pc.perception_radius;
    float avoid_r2 = pc.avoid_radius * pc.avoid_radius;

    // Brute-force neighbor search (O(n²) — works well up to ~50k on modern GPUs)
    for (int j = 0; j < pc.particle_count; j++) {
        if (j == int(gid)) continue;
        if (particles[j].age >= particles[j].life) continue;

        vec3 diff = my_pos - particles[j].pos.xyz;
        float d2 = dot(diff, diff);

        if (d2 > r2 || d2 < 0.0001) continue;

        // Separation: steer away from very close neighbors
        if (d2 < avoid_r2) {
            sep_sum += diff / max(d2, 0.0001);
            sep_count++;
        }

        // Alignment: match average velocity of neighbors
        ali_sum += particles[j].vel.xyz;
        ali_count++;

        // Cohesion: steer toward average position of neighbors
        coh_sum += particles[j].pos.xyz;
        coh_count++;
    }

    vec3 steer = vec3(0.0);

    // Separation steering
    if (sep_count > 0) {
        vec3 desired = normalize(sep_sum / float(sep_count)) * pc.max_speed;
        steer += clamp_mag(desired - my_vel, pc.max_force) * pc.separation_weight;
    }

    // Alignment steering
    if (ali_count > 0) {
        vec3 avg_vel = ali_sum / float(ali_count);
        vec3 desired = normalize(avg_vel) * pc.max_speed;
        steer += clamp_mag(desired - my_vel, pc.max_force) * pc.alignment_weight;
    }

    // Cohesion steering
    if (coh_count > 0) {
        vec3 center = coh_sum / float(coh_count);
        vec3 desired = normalize(center - my_pos) * pc.max_speed;
        steer += clamp_mag(desired - my_vel, pc.max_force) * pc.cohesion_weight;
    }

    // Boundary containment (spherical)
    if (pc.bounds_radius > 0.0) {
        float dist = length(my_pos);
        if (dist > pc.bounds_radius * 0.8) {
            vec3 to_center = -normalize(my_pos);
            float urgency = smoothstep(pc.bounds_radius * 0.8, pc.bounds_radius, dist);
            steer += to_center * urgency * pc.bounds_force;
        }
    }

    // Apply steering, clamp speed
    vec3 new_vel = my_vel + steer * pc.dt;
    new_vel = clamp_mag(new_vel, pc.max_speed);

    particles[gid].vel.xyz = new_vel;
    particles[gid].pos.xyz += new_vel * pc.dt;
    particles[gid].age += pc.dt;
}
