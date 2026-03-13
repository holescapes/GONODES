[remap]
type="RDShaderFile"
path="res://addons/gonodes/shaders/img/edge_detect_img.glsl"

[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(rgba8, set = 0, binding = 0) uniform restrict readonly image2D img_in;
layout(rgba8, set = 0, binding = 1) uniform restrict writeonly image2D img_out;

layout(push_constant) uniform PushConstants {
    int   width;
    int   height;
    float strength;
    int   pad0;
} pc;

float luminance(vec4 c) {
    return dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
    ivec2 gid = ivec2(gl_GlobalInvocationID.xy);
    if (gid.x >= pc.width || gid.y >= pc.height) return;

    // Sobel 3x3 kernels
    float tl = luminance(imageLoad(img_in, clamp(gid + ivec2(-1, -1), ivec2(0), ivec2(pc.width-1, pc.height-1))));
    float tc = luminance(imageLoad(img_in, clamp(gid + ivec2(0, -1), ivec2(0), ivec2(pc.width-1, pc.height-1))));
    float tr = luminance(imageLoad(img_in, clamp(gid + ivec2(1, -1), ivec2(0), ivec2(pc.width-1, pc.height-1))));
    float ml = luminance(imageLoad(img_in, clamp(gid + ivec2(-1,  0), ivec2(0), ivec2(pc.width-1, pc.height-1))));
    float mr = luminance(imageLoad(img_in, clamp(gid + ivec2(1,  0), ivec2(0), ivec2(pc.width-1, pc.height-1))));
    float bl = luminance(imageLoad(img_in, clamp(gid + ivec2(-1,  1), ivec2(0), ivec2(pc.width-1, pc.height-1))));
    float bc = luminance(imageLoad(img_in, clamp(gid + ivec2(0,  1), ivec2(0), ivec2(pc.width-1, pc.height-1))));
    float br = luminance(imageLoad(img_in, clamp(gid + ivec2(1,  1), ivec2(0), ivec2(pc.width-1, pc.height-1))));

    float gx = -tl - 2.0*ml - bl + tr + 2.0*mr + br;
    float gy = -tl - 2.0*tc - tr + bl + 2.0*bc + br;
    float edge = clamp(sqrt(gx*gx + gy*gy) * pc.strength, 0.0, 1.0);

    imageStore(img_out, gid, vec4(edge, edge, edge, 1.0));
}
