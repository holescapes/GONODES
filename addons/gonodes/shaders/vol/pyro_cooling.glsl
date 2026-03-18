[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Cooling pass: exponentially decay temperature each frame.

layout(r32f, set = 0, binding = 0) uniform restrict image3D temp_field;

layout(push_constant) uniform PushConstants {
    int   res_x;
    int   res_y;
    int   res_z;
    float cooling;  // multiplier per frame (e.g. 0.97 = slow cool, 0.8 = fast cool)
} pc;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);
    if (gid.x >= pc.res_x || gid.y >= pc.res_y || gid.z >= pc.res_z) return;

    float temp = imageLoad(temp_field, gid).r;
    temp *= pc.cooling;
    imageStore(temp_field, gid, vec4(temp, 0.0, 0.0, 0.0));
}
