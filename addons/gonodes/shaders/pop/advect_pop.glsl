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

// 3D velocity field from a VOL operator (RGBA32F: rgb=velocity, a=density)
layout(set = 0, binding = 1) uniform sampler3D velocity_field;

layout(push_constant) uniform PushConstants {
    int   particle_count;
    float dt;
    float strength;       // velocity field influence scale
    // Volume world-space bounds (AABB)
    float vol_min_x;
    float vol_min_y;
    float vol_min_z;
    float vol_size_x;
    float vol_size_y;
    float vol_size_z;
    int   add_mode;       // 0 = replace vel, 1 = add to vel
} pc;

void main() {
    uint gid = gl_GlobalInvocationID.x;
    if (gid >= pc.particle_count) return;

    vec3 pos = particles[gid].pos.xyz;

    // Map world pos to UVW [0,1] within volume bounds
    vec3 uvw = (pos - vec3(pc.vol_min_x, pc.vol_min_y, pc.vol_min_z))
    / vec3(pc.vol_size_x, pc.vol_size_y, pc.vol_size_z);

    // Skip if particle is outside the volume
    if (any(lessThan(uvw, vec3(0.0))) || any(greaterThan(uvw, vec3(1.0)))) return;

    vec3 field_vel = texture(velocity_field, uvw).xyz;

    if (pc.add_mode == 1) {
        particles[gid].vel.xyz += field_vel * pc.strength * pc.dt;
    } else {
        particles[gid].vel.xyz = field_vel * pc.strength;
    }
}
