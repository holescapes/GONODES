[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Apply obstacle mask to velocity and density fields.
// Obstacle volume: R > 0.5 = solid.  At solid boundaries, velocity is
// zeroed and density is blocked from entering.

layout(set = 0, binding = 0) uniform sampler3D obstacle_in;    // obstacle mask
layout(rgba32f, set = 0, binding = 1) uniform restrict image3D velocity_inout;
layout(r32f, set = 0, binding = 2) uniform restrict image3D density_inout;

layout(push_constant) uniform PushConstants {
    int   res_x;
    int   res_y;
    int   res_z;
    float obstacle_velocity_scale;   // 0 = full block, <0 = reflect
} pc;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);
    if (gid.x >= pc.res_x || gid.y >= pc.res_y || gid.z >= pc.res_z) return;

    vec3 res = vec3(pc.res_x, pc.res_y, pc.res_z);
    vec3 uvw = (vec3(gid) + 0.5) / res;

    float obs = texture(obstacle_in, uvw).r;

    if (obs > 0.5) {
        // Inside obstacle — zero velocity, block density
        imageStore(velocity_inout, gid, vec4(0.0));
        imageStore(density_inout, gid, vec4(0.0));
    } else if (obs > 0.1) {
        // Near boundary — apply friction (smooth falloff)
        float factor = smoothstep(0.5, 0.1, obs);
        vec4 vel = imageLoad(velocity_inout, gid);
        vel.xyz *= factor;
        imageStore(velocity_inout, gid, vel);
    }
    // obs < 0.1 — free space, no modification
}
