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
    float t = pc.gn_time * 0.5;

    float v = sin(uv.x * 10.0 + t);
    v += sin(uv.y * 10.0 + t * 0.7);
    v += sin((uv.x + uv.y) * 5.0 + t * 1.3);
    v += sin(length(uv * 10.0 - 5.0) + t);
    v *= 0.25;

    vec3 col = vec3(
        sin(v * 3.14159 + 0.0) * 0.5 + 0.5,
        sin(v * 3.14159 + 2.094) * 0.5 + 0.5,
        sin(v * 3.14159 + 4.189) * 0.5 + 0.5);
    imageStore(gn_output, coords, vec4(col, 1.0));
}
