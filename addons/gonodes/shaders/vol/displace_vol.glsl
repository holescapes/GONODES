[remap]
type="RDShaderFile"
path="res://addons/gonodes/shaders/vol/displace_vol.glsl"

[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(set = 0, binding = 0) uniform sampler3D vol_in;         // source density
layout(set = 0, binding = 1) uniform sampler3D velocity_field;  // displacement field (RGBA)
layout(r32f, set = 0, binding = 2) uniform restrict writeonly image3D vol_out;

layout(push_constant) uniform PushConstants {
    int   res_x;
    int   res_y;
    int   res_z;
    float strength;
    float pad0;
    float pad1;
    float pad2;
    float pad3;
} pc;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);
    if (gid.x >= pc.res_x || gid.y >= pc.res_y || gid.z >= pc.res_z) return;

    vec3 res = vec3(pc.res_x, pc.res_y, pc.res_z);
    vec3 uvw = (vec3(gid) + 0.5) / res;

    // Read displacement from velocity field
    vec3 disp = texture(velocity_field, uvw).xyz * pc.strength / res;

    // Sample the source at displaced position
    float val = texture(vol_in, uvw - disp).r;

    imageStore(vol_out, gid, vec4(val, 0.0, 0.0, 0.0));
}
