[remap]
type="RDShaderFile"
path="res://addons/gonodes/shaders/vol/noise_vol.glsl"

[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(r32f, set = 0, binding = 0) uniform restrict writeonly image3D out_volume;

layout(push_constant) uniform PushConstants {
    int   res_x;
    int   res_y;
    int   res_z;
    float frequency;
    float amplitude;
    float offset_x;
    float offset_y;
    float offset_z;
    float time;
    float lacunarity;
    float gain;
    int   octaves;
} pc;

// 3D gradient noise
vec3 hash3(vec3 p) {
    p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
        dot(p, vec3(269.5, 183.3, 246.1)),
        dot(p, vec3(113.5, 271.9, 124.6)));
    return fract(sin(p) * 43758.5453) * 2.0 - 1.0;
}

float gradient_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(mix(dot(hash3(i + vec3(0,0,0)), f - vec3(0,0,0)),
                dot(hash3(i + vec3(1,0,0)), f - vec3(1,0,0)), u.x),
            mix(dot(hash3(i + vec3(0,1,0)), f - vec3(0,1,0)),
                dot(hash3(i + vec3(1,1,0)), f - vec3(1,1,0)), u.x), u.y),
        mix(mix(dot(hash3(i + vec3(0,0,1)), f - vec3(0,0,1)),
                dot(hash3(i + vec3(1,0,1)), f - vec3(1,0,1)), u.x),
            mix(dot(hash3(i + vec3(0,1,1)), f - vec3(0,1,1)),
                dot(hash3(i + vec3(1,1,1)), f - vec3(1,1,1)), u.x), u.y),
        u.z);
}

float fbm(vec3 p) {
    float value = 0.0;
    float amp = pc.amplitude;
    float freq = pc.frequency;
    for (int o = 0; o < pc.octaves; o++) {
        value += gradient_noise(p * freq + vec3(pc.time)) * amp;
        freq *= pc.lacunarity;
        amp *= pc.gain;
    }
    return value;
}

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);
    if (gid.x >= pc.res_x || gid.y >= pc.res_y || gid.z >= pc.res_z) return;

    // Normalize to [0,1] space then apply offset
    vec3 uvw = vec3(gid) / vec3(pc.res_x, pc.res_y, pc.res_z);
    vec3 pos = uvw + vec3(pc.offset_x, pc.offset_y, pc.offset_z);

    float density = fbm(pos);

    imageStore(out_volume, gid, vec4(density, 0.0, 0.0, 0.0));
}
