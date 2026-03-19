[compute]
#version 450

// point_cloud_render.glsl — GPU point-cloud splatting.
// Reads a POP SSBO (64-byte stride particles) and renders
// circular splats to a 2D image with depth testing.
//
// Particle layout (std430, 64 bytes):
//   vec4 pos    @ 0     (xyz = position, w = unused)
//   vec4 vel    @ 16    (xyz = velocity, w = unused)
//   vec4 color  @ 32    (rgba)
//   float age   @ 48
//   float life  @ 52
//   float mass  @ 56
//   float pscale@ 60

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Particle buffer (read-only)
layout(set = 0, binding = 0, std430) restrict readonly buffer Particles {
    float data[];
} particles;

// Output color image
layout(set = 0, binding = 1, rgba8) uniform image2D u_output;

// Depth buffer (R32F — lower = closer)
layout(set = 0, binding = 2, r32f) uniform image2D u_depth;

layout(push_constant) uniform Params {
    int   img_w;
    int   img_h;
    int   num_particles;
    float point_size;       // base splat radius in pixels
    // Camera
    float eye_x, eye_y, eye_z;
    float fwd_x, fwd_y, fwd_z;
    float right_x, right_y, right_z;
    float up_x, up_y, up_z;
    float fov;
    float near_clip;
    float far_clip;
    // Options
    float size_attenuation;  // 0 = constant size, 1 = full perspective
    float alpha;             // global opacity multiplier
    int   use_particle_color; // 0 = use push constant color, 1 = per-particle
    float color_r, color_g, color_b;
} p;

void main() {
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= uint(p.num_particles)) return;

    // Read particle data (64 bytes = 16 floats per particle)
    uint base = idx * 16u;
    vec3 pos = vec3(particles.data[base + 0],
        particles.data[base + 1],
        particles.data[base + 2]);
    vec4 pcol = vec4(particles.data[base + 8],
        particles.data[base + 9],
        particles.data[base + 10],
        particles.data[base + 11]);
    float life   = particles.data[base + 13];
    float pscale = particles.data[base + 15];

    // Skip dead particles
    if (life <= 0.0 && pscale <= 0.0) return;

    // Camera transform: world → view
    vec3 eye   = vec3(p.eye_x, p.eye_y, p.eye_z);
    vec3 fwd   = normalize(vec3(p.fwd_x, p.fwd_y, p.fwd_z));
    vec3 right = normalize(vec3(p.right_x, p.right_y, p.right_z));
    vec3 up    = normalize(vec3(p.up_x, p.up_y, p.up_z));

    vec3 rel = pos - eye;
    float depth = dot(rel, fwd);

    // Clip behind camera and beyond far plane
    if (depth < p.near_clip || depth > p.far_clip) return;

    float sx = dot(rel, right);
    float sy = dot(rel, up);

    // Perspective projection
    float half_fov = tan(p.fov * 0.5);
    float aspect = float(p.img_w) / float(p.img_h);

    float ndc_x = sx / (depth * half_fov * aspect);
    float ndc_y = sy / (depth * half_fov);

    // NDC [-1, 1] → pixel
    float px = (ndc_x * 0.5 + 0.5) * float(p.img_w);
    float py = ((-ndc_y) * 0.5 + 0.5) * float(p.img_h);

    // Splat radius (world-space pscale → screen pixels)
    float base_radius = p.point_size * max(pscale, 0.01);
    float radius = mix(base_radius, base_radius / max(depth, 0.001) * float(p.img_h) * 0.5 / half_fov,
        p.size_attenuation);
    int r = int(ceil(radius));
    if (r < 1) r = 1;

    // Determine color
    vec3 col;
    float a;
    if (p.use_particle_color != 0) {
        col = pcol.rgb;
        a = pcol.a * p.alpha;
    } else {
        col = vec3(p.color_r, p.color_g, p.color_b);
        a = p.alpha;
    }

    // Normalized depth for depth test [0, 1]
    float norm_depth = (depth - p.near_clip) / (p.far_clip - p.near_clip);

    // Splat: write circular disc with depth test
    int cx = int(px);
    int cy = int(py);
    for (int dy = -r; dy <= r; dy++) {
        for (int dx = -r; dx <= r; dx++) {
            int ix = cx + dx;
            int iy = cy + dy;
            if (ix < 0 || ix >= p.img_w || iy < 0 || iy >= p.img_h) continue;

            float dist2 = float(dx * dx + dy * dy);
            float r2 = radius * radius;
            if (dist2 > r2) continue;

            // Soft edge falloff
            float falloff = 1.0 - dist2 / r2;

            // Depth test (atomicMin not available for images, use imageLoad compare)
            float current_depth = imageLoad(u_depth, ivec2(ix, iy)).r;
            if (norm_depth < current_depth) {
                imageStore(u_depth, ivec2(ix, iy), vec4(norm_depth));
                imageStore(u_output, ivec2(ix, iy), vec4(col * falloff, a * falloff));
            }
        }
    }
}
