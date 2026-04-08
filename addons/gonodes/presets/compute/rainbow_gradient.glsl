#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba8, set = 0, binding = 0) uniform image2D gn_output;

layout(push_constant, std430) uniform PushConstants {
    float gn_time;
    float gn_frame;
    float gn_dt;
    float gn_res_x;
    float gn_res_y;
} pc;

void main() {
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = ivec2(pc.gn_res_x, pc.gn_res_y);
    if (coords.x >= size.x || coords.y >= size.y) return;

    vec2 uv = vec2(coords) / vec2(size);
    float t = pc.gn_time;

    vec3 col = 0.5 + 0.5 * cos(t + uv.xyx + vec3(0.0, 2.0, 4.0));
    imageStore(gn_output, coords, vec4(col, 1.0));
}
