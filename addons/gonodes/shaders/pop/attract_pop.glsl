[compute]
#version 450

layout(local_size_x = 256) in;

struct Particle {
    vec4 pos;
    vec4 vel;
    vec4 color;
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
    float target_x;
    float target_y;
    float target_z;
    float strength;     // attraction force magnitude
    float radius;       // max influence radius (0 = infinite)
    float pad0;
} pc;

void main() {
    uint gid = gl_GlobalInvocationID.x;
    if (gid >= pc.particle_count) return;

    vec3 pos = particles[gid].pos.xyz;
    vec3 target = vec3(pc.target_x, pc.target_y, pc.target_z);
    vec3 diff = target - pos;
    float dist = length(diff);

    if (dist < 0.001) return;
    if (pc.radius > 0.0 && dist > pc.radius) return;

    vec3 dir = diff / dist;
    // Inverse-square falloff clamped to avoid singularity
    float falloff = 1.0 / max(dist * dist, 0.01);
    vec3 force = dir * pc.strength * falloff;

    float inv_mass = 1.0 / max(particles[gid].mass, 0.001);
    particles[gid].vel.xyz += force * inv_mass * pc.dt;
}
