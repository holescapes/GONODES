[remap]
type="RDShaderFile"
path="res://addons/gonodes/shaders/pop/collision_pop.glsl"

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
    float ground_y;        // ground plane Y position
    float bounce;          // restitution coefficient (0–1)
    float friction;        // tangential velocity reduction (0–1)
    float kill_below;      // kill particles below this Y (set very low to disable)
    float pad0;
    float pad1;
} pc;

void main() {
    uint gid = gl_GlobalInvocationID.x;
    if (gid >= pc.particle_count) return;

    vec3 pos = particles[gid].pos.xyz;
    vec3 vel = particles[gid].vel.xyz;

    // Ground plane collision
    if (pos.y < pc.ground_y + particles[gid].pscale * 0.5) {
        pos.y = pc.ground_y + particles[gid].pscale * 0.5;
        vel.y = abs(vel.y) * pc.bounce;
        vel.xz *= (1.0 - pc.friction);
        particles[gid].pos.xyz = pos;
        particles[gid].vel.xyz = vel;
    }

    // Kill below threshold
    if (pos.y < pc.kill_below) {
        particles[gid].age = particles[gid].life + 1.0;  // mark dead
    }
}
