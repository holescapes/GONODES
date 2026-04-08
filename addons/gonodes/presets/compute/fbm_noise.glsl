#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba8, set = 0, binding = 0) uniform image2D gn_output;

layout(push_constant, std430) uniform PushConstants {
    float gn_time;
    float gn_frame;
    float gn_dt;
    float gn_res_x;
    float gn_res_y;
    float scale;    // Noise scale (default: 8.0)
    float speed;    // Animation speed (default: 0.5)
} pc;

// Simple value noise via hash
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
        f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 6; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void main() {
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = ivec2(pc.gn_res_x, pc.gn_res_y);
    if (coords.x >= size.x || coords.y >= size.y) return;

    vec2 uv = vec2(coords) / vec2(size);
    float t = pc.gn_time * pc.speed;

    float n = fbm(uv * pc.scale + vec2(t, t * 0.7));
    imageStore(gn_output, coords, vec4(vec3(n), 1.0));
}
