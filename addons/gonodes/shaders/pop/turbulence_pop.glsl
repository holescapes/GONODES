[compute]
#version 450

layout(local_size_x = 256) in;

struct Particle {
    vec4 pos;
    vec4 vel;
    vec4 color;
    float age;
    float life;
    float mass;
    float pscale;
};

layout(set = 0, binding = 0, std430) restrict buffer ParticleBuffer {
    Particle particles[];
};

layout(push_constant) uniform PushConstants {
    int   particle_count;
    float dt;
    float amplitude;
    float frequency;
    float time_offset;
    float roughness;     // octave gain
    int   octaves;
    float pad0;
} pc;

// Simplex-style 3D noise (hash-based approximation for compute)
vec3 hash3(vec3 p) {
    p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
        dot(p, vec3(269.5, 183.3, 246.1)),
        dot(p, vec3(113.5, 271.9, 124.6)));
    return fract(sin(p) * 43758.5453) * 2.0 - 1.0;
}

float noise3(vec3 p) {
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

// Curl noise for divergence-free turbulence
vec3 curl_noise(vec3 p) {
    float e = 0.01;
    float n1, n2;

    // dz/dy - dy/dz
    n1 = noise3(p + vec3(0, e, 0));
    n2 = noise3(p - vec3(0, e, 0));
    float dx = n1 - n2;
    n1 = noise3(p + vec3(0, 0, e));
    n2 = noise3(p - vec3(0, 0, e));
    float cx = dx - (n1 - n2);

    // dx/dz - dz/dx
    n1 = noise3(p + vec3(0, 0, e));
    n2 = noise3(p - vec3(0, 0, e));
    float dy = n1 - n2;
    n1 = noise3(p + vec3(e, 0, 0));
    n2 = noise3(p - vec3(e, 0, 0));
    float cy = dy - (n1 - n2);

    // dy/dx - dx/dy
    n1 = noise3(p + vec3(e, 0, 0));
    n2 = noise3(p - vec3(e, 0, 0));
    float dz = n1 - n2;
    n1 = noise3(p + vec3(0, e, 0));
    n2 = noise3(p - vec3(0, e, 0));
    float cz = dz - (n1 - n2);

    return vec3(cx, cy, cz) / (2.0 * e);
}

void main() {
    uint gid = gl_GlobalInvocationID.x;
    if (gid >= pc.particle_count) return;

    vec3 pos = particles[gid].pos.xyz;
    vec3 turb = vec3(0.0);
    float amp = pc.amplitude;
    float freq = pc.frequency;

    for (int o = 0; o < pc.octaves; o++) {
        turb += curl_noise(pos * freq + vec3(pc.time_offset)) * amp;
        amp *= pc.roughness;
        freq *= 2.0;
    }

    particles[gid].vel.xyz += turb * pc.dt;
}
