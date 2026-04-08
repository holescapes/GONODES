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
    float strength;  // Edge detection strength (default: 1.0)
} pc;

void main() {
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = ivec2(pc.gn_res_x, pc.gn_res_y);
    if (coords.x >= size.x || coords.y >= size.y) return;

    vec2 uv = vec2(coords) / vec2(size);
    vec2 px = 1.0 / vec2(size);

    // Sobel kernel
    float tl = dot(texture(gn_tex0, uv + vec2(-px.x, -px.y)).rgb, vec3(0.299, 0.587, 0.114));
    float tc = dot(texture(gn_tex0, uv + vec2(0.0,  -px.y)).rgb, vec3(0.299, 0.587, 0.114));
    float tr = dot(texture(gn_tex0, uv + vec2(px.x, -px.y)).rgb, vec3(0.299, 0.587, 0.114));
    float ml = dot(texture(gn_tex0, uv + vec2(-px.x,  0.0)).rgb, vec3(0.299, 0.587, 0.114));
    float mr = dot(texture(gn_tex0, uv + vec2(px.x,  0.0)).rgb, vec3(0.299, 0.587, 0.114));
    float bl = dot(texture(gn_tex0, uv + vec2(-px.x,  px.y)).rgb, vec3(0.299, 0.587, 0.114));
    float bc = dot(texture(gn_tex0, uv + vec2(0.0,   px.y)).rgb, vec3(0.299, 0.587, 0.114));
    float br = dot(texture(gn_tex0, uv + vec2(px.x,  px.y)).rgb, vec3(0.299, 0.587, 0.114));

    float gx = -tl - 2.0*ml - bl + tr + 2.0*mr + br;
    float gy = -tl - 2.0*tc - tr + bl + 2.0*bc + br;
    float edge = clamp(sqrt(gx*gx + gy*gy) * pc.strength, 0.0, 1.0);

    imageStore(gn_output, coords, vec4(vec3(edge), 1.0));
}
