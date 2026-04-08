#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba8, set = 0, binding = 0) uniform image2D gn_output;
layout(set = 1, binding = 0) uniform sampler2D gn_tex0;

layout(push_constant, std430) uniform PushConstants {
    float gn_time;
    float gn_frame;
    float gn_dt;
    float gn_res_x;
    float gn_res_y;
    float amount;  // Distortion amount (default: 0.02)
    float speed;   // Animation speed (default: 1.0)
} pc;

void main() {
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = ivec2(pc.gn_res_x, pc.gn_res_y);
    if (coords.x >= size.x || coords.y >= size.y) return;

    vec2 uv = vec2(coords) / vec2(size);
    float t = pc.gn_time * pc.speed;

    // Wavey distortion
    vec2 offset = vec2(
        sin(uv.y * 20.0 + t * 3.0) * pc.amount,
        cos(uv.x * 20.0 + t * 2.5) * pc.amount);

    vec4 col = texture(gn_tex0, uv + offset);
    imageStore(gn_output, coords, col);
}
