[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(set = 0, binding = 0) uniform sampler3D velocity_in;
layout(r32f, set = 0, binding = 1) uniform restrict writeonly image3D divergence_out;

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

    float vR = texture(velocity_in, uvw + vec3(ts.x, 0, 0)).x;
    float vL = texture(velocity_in, uvw - vec3(ts.x, 0, 0)).x;
    float vU = texture(velocity_in, uvw + vec3(0, ts.y, 0)).y;
    float vD = texture(velocity_in, uvw - vec3(0, ts.y, 0)).y;
    float vF = texture(velocity_in, uvw + vec3(0, 0, ts.z)).z;
    float vB = texture(velocity_in, uvw - vec3(0, 0, ts.z)).z;

    float div = -0.5 * ((vR - vL) + (vU - vD) + (vF - vB));

    imageStore(divergence_out, gid, vec4(div, 0.0, 0.0, 0.0));
}
