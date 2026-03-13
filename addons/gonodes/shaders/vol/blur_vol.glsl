[remap]
type="RDShaderFile"
path="res://addons/gonodes/shaders/vol/blur_vol.glsl"

[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(set = 0, binding = 0) uniform sampler3D vol_in;
layout(r32f, set = 0, binding = 1) uniform restrict writeonly image3D vol_out;

layout(push_constant) uniform PushConstants {
    int   res_x;
    int   res_y;
    int   res_z;
    int   radius;      // blur radius in voxels (1–4)
    float pad0;
    float pad1;
    float pad2;
    float pad3;
} pc;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);
    if (gid.x >= pc.res_x || gid.y >= pc.res_y || gid.z >= pc.res_z) return;

    vec3 res = vec3(pc.res_x, pc.res_y, pc.res_z);
    vec3 texel_size = 1.0 / res;
    vec3 center_uvw = (vec3(gid) + 0.5) / res;

    float total = 0.0;
    float weight_sum = 0.0;

    for (int dz = -pc.radius; dz <= pc.radius; dz++) {
        for (int dy = -pc.radius; dy <= pc.radius; dy++) {
            for (int dx = -pc.radius; dx <= pc.radius; dx++) {
                vec3 offset = vec3(dx, dy, dz) * texel_size;
                float dist = length(vec3(dx, dy, dz));
                float w = exp(-dist * dist / float(pc.radius * pc.radius + 1));
                total += texture(vol_in, center_uvw + offset).r * w;
                weight_sum += w;
            }
        }
    }

    imageStore(vol_out, gid, vec4(total / weight_sum, 0.0, 0.0, 0.0));
}
