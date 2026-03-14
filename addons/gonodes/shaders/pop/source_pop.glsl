[compute]
#version 450

layout(local_size_x = 256) in;

// Particle struct (std430 — matches GNPopBase.STANDARD_STRIDE = 64 bytes)
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

layout(set = 0, binding = 1, std430) restrict readonly buffer EmitPointBuffer {
    vec4 emit_points[];   // positions to emit from (xyz, w=unused)
};

layout(push_constant) uniform PushConstants {
    int   alive_count;     // current number alive before this emit
    int   emit_count;      // number of particles to emit this frame
    int   emit_point_count;// number of emit points available
    float life_min;
    float life_max;
    float init_speed;
    float pscale_val;
    float seed;            // time-based seed for randomness
} pc;

// Simple hash-based RNG
float hash(uint n) {
    n = (n << 13) ^ n;
    n = n * (n * n * 15731u + 789221u) + 1376312589u;
    return float(n & 0x7fffffffu) / float(0x7fffffff);
}

void main() {
    uint gid = gl_GlobalInvocationID.x;
    if (gid >= pc.emit_count) return;

    uint idx = pc.alive_count + gid;
    uint seed = uint(pc.seed * 1000.0) + gid * 7919u;

    // Pick a random emit point
    uint pt_idx = uint(hash(seed) * float(pc.emit_point_count)) % pc.emit_point_count;
    vec3 emit_pos = emit_points[pt_idx].xyz;

    // Random direction on unit sphere
    float theta = hash(seed + 1u) * 6.2831853;
    float phi = acos(2.0 * hash(seed + 2u) - 1.0);
    vec3 dir = vec3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi));

    particles[idx].pos = vec4(emit_pos, 0.0);
    particles[idx].vel = vec4(dir * pc.init_speed, 0.0);
    particles[idx].color = vec4(1.0);
    particles[idx].age = 0.0;
    particles[idx].life = mix(pc.life_min, pc.life_max, hash(seed + 3u));
    particles[idx].mass = 1.0;
    particles[idx].pscale = pc.pscale_val;
}
