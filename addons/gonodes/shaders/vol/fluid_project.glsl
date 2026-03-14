[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Subtract pressure gradient from velocity to make it divergence-free
layout(set = 0, binding = 0) uniform sampler3D pressure_in;
layout(rgba32f, set = 0, binding = 1) uniform restrict image3D velocity_inout;

layout(push_constant) uniform PushConstants {
    int res_x;
    int res_y;
    int res_z;
    float pad0;
} pc;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);
    if (gid.x >= pc.res_x || gid.y >= pc.res_y || gid.z >= pc.res_z) return;

    vec3 res = vec3(pc.res_x, pc.res_y, pc.res_z);
    vec3 ts = 1.0 / res;
    vec3 uvw = (vec3(gid) + 0.5) / res;

    float pR = texture(pressure_in, uvw + vec3(ts.x, 0, 0)).r;
    float pL = texture(pressure_in, uvw - vec3(ts.x, 0, 0)).r;
    float pU = texture(pressure_in, uvw + vec3(0, ts.y, 0)).r;
    float pD = texture(pressure_in, uvw - vec3(0, ts.y, 0)).r;
    float pF = texture(pressure_in, uvw + vec3(0, 0, ts.z)).r;
    float pB = texture(pressure_in, uvw - vec3(0, 0, ts.z)).r;

    vec3 grad = 0.5 * vec3(pR - pL, pU - pD, pF - pB);

    vec4 vel = imageLoad(velocity_inout, gid);
    vel.xyz -= grad;
    imageStore(velocity_inout, gid, vel);
}
