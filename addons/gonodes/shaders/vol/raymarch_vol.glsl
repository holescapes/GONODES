[compute]
#version 450

// raymarch_vol.glsl — Volume ray-marching → 2D image output.
// Input: 3D density texture. Output: 2D RGBA image.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler3D u_volume;
layout(set = 0, binding = 1, rgba8) uniform writeonly image2D u_output;

layout(push_constant) uniform Params {
    int   img_w;
    int   img_h;
    int   vol_x;
    int   vol_y;
    int   vol_z;
    int   max_steps;
    float step_size;
    float density_scale;
    // Camera: eye(3) + forward(3) + right(3) + up(3) + fov
    float eye_x, eye_y, eye_z;
    float fwd_x, fwd_y, fwd_z;
    float right_x, right_y, right_z;
    float up_x, up_y, up_z;
    float fov;
    float absorption;
} p;

// AABB ray intersection (unit cube centered at origin: -0.5 to 0.5)
bool intersect_aabb(vec3 ro, vec3 rd, out float t_near, out float t_far) {
    vec3 inv_rd = 1.0 / rd;
    vec3 t0 = (-0.5 - ro) * inv_rd;
    vec3 t1 = (0.5 - ro) * inv_rd;
    vec3 tmin = min(t0, t1);
    vec3 tmax = max(t0, t1);
    t_near = max(max(tmin.x, tmin.y), tmin.z);
    t_far  = min(min(tmax.x, tmax.y), tmax.z);
    return t_near < t_far && t_far > 0.0;
}

void main() {
    ivec2 gid = ivec2(gl_GlobalInvocationID.xy);
    if (gid.x >= p.img_w || gid.y >= p.img_h) return;

    // Normalized screen coordinates [-1, 1]
    float aspect = float(p.img_w) / float(p.img_h);
    float u = (float(gid.x) + 0.5) / float(p.img_w) * 2.0 - 1.0;
    float v = (float(gid.y) + 0.5) / float(p.img_h) * 2.0 - 1.0;
    v = -v; // flip Y

    float half_fov = tan(p.fov * 0.5);
    vec3 eye = vec3(p.eye_x, p.eye_y, p.eye_z);
    vec3 fwd = normalize(vec3(p.fwd_x, p.fwd_y, p.fwd_z));
    vec3 right = normalize(vec3(p.right_x, p.right_y, p.right_z));
    vec3 up = normalize(vec3(p.up_x, p.up_y, p.up_z));

    vec3 rd = normalize(fwd + right * u * half_fov * aspect + up * v * half_fov);

    float t_near, t_far;
    if (!intersect_aabb(eye, rd, t_near, t_far)) {
        imageStore(u_output, gid, vec4(0.0));
        return;
    }
    t_near = max(t_near, 0.0);

    // Front-to-back compositing
    vec3 color = vec3(0.0);
    float transmittance = 1.0;
    float dt = p.step_size;

    for (int i = 0; i < p.max_steps; i++) {
        float t = t_near + (float(i) + 0.5) * dt;
        if (t >= t_far || transmittance < 0.01) break;

        vec3 pos = eye + rd * t;
        // Map from [-0.5, 0.5] to [0, 1] for texture sampling
        vec3 uvw = pos + 0.5;

        float density = texture(u_volume, uvw).r * p.density_scale;
        if (density > 0.0) {
            float alpha = 1.0 - exp(-density * dt * p.absorption);
            // Simple emission model: brighter where denser
            vec3 emit = vec3(1.0, 0.85, 0.6) * density;
            color += transmittance * alpha * emit;
            transmittance *= (1.0 - alpha);
        }
    }

    imageStore(u_output, gid, vec4(color, 1.0 - transmittance));
}
