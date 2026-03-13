[remap]
type="RDShaderFile"
path="res://addons/gonodes/shaders/pop/force_pop.glsl"

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
    float force_x;
    float force_y;
    float force_z;
    float drag;        // velocity damping per second (0 = none, 1 = full stop)
    float pad0;
    float pad1;
} pc;

void main() {
    uint gid = gl_GlobalInvocationID.x;
    if (gid >= pc.particle_count) return;

    float inv_mass = 1.0 / max(particles[gid].mass, 0.001);
    vec3 accel = vec3(pc.force_x, pc.force_y, pc.force_z) * inv_mass;

    particles[gid].vel.xyz += accel * pc.dt;
    particles[gid].vel.xyz *= (1.0 - pc.drag * pc.dt);
    particles[gid].pos.xyz += particles[gid].vel.xyz * pc.dt;
    particles[gid].age += pc.dt;
}
