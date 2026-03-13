[remap]
type="RDShaderFile"
path="res://addons/gonodes/shaders/vol/blend_vol.glsl"

[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(r32f, set = 0, binding = 0) uniform restrict readonly image3D vol_a;
layout(r32f, set = 0, binding = 1) uniform restrict readonly image3D vol_b;
layout(r32f, set = 0, binding = 2) uniform restrict writeonly image3D vol_out;

layout(push_constant) uniform PushConstants {
    int   res_x;
    int   res_y;
    int   res_z;
    int   operation;  // 0=add, 1=subtract, 2=multiply, 3=max, 4=min, 5=mix
    float mix_factor; // blend weight for mix operation
    float scale_a;
    float scale_b;
    float pad0;
} pc;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);
    if (gid.x >= pc.res_x || gid.y >= pc.res_y || gid.z >= pc.res_z) return;

    float a = imageLoad(vol_a, gid).r * pc.scale_a;
    float b = imageLoad(vol_b, gid).r * pc.scale_b;
    float result = 0.0;

    switch (pc.operation) {
        case 0: result = a + b; break;
        case 1: result = a - b; break;
        case 2: result = a * b; break;
        case 3: result = max(a, b); break;
        case 4: result = min(a, b); break;
        case 5: result = mix(a, b, pc.mix_factor); break;
    }

    imageStore(vol_out, gid, vec4(result, 0.0, 0.0, 0.0));
}
