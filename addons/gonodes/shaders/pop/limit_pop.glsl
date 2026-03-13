[remap]
type="RDShaderFile"
path="res://addons/gonodes/shaders/pop/limit_pop.glsl"

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
    // Bounding box (AABB)
    float bbox_min_x;
    float bbox_min_y;
    float bbox_min_z;
    float bbox_max_x;
    float bbox_max_y;
    float bbox_max_z;
    float max_speed;     // clamp speed (0 = no limit)
    int   kill_outside;  // 1 = kill particles outside bbox
} pc;

void main() {
    uint gid = gl_GlobalInvocationID.x;
    if (gid >= pc.particle_count) return;

    // Age kill
    if (particles[gid].age >= particles[gid].life) {
        return;  // Already dead — handled by compaction
    }

    vec3 pos = particles[gid].pos.xyz;

    // Bounds kill
    if (pc.kill_outside == 1) {
        if (pos.x < pc.bbox_min_x || pos.x > pc.bbox_max_x ||
            pos.y < pc.bbox_min_y || pos.y > pc.bbox_max_y ||
            pos.z < pc.bbox_min_z || pos.z > pc.bbox_max_z) {
            particles[gid].age = particles[gid].life + 1.0;
            return;
        }
    }

    // Speed limit
    if (pc.max_speed > 0.0) {
        float spd = length(particles[gid].vel.xyz);
        if (spd > pc.max_speed) {
            particles[gid].vel.xyz *= pc.max_speed / spd;
        }
    }
}
