[compute]
#version 450

// raymarch_vol.glsl — Volume ray-marching → 2D image output.
// Multi-pass lighting: directional light with shadow rays,
// Henyey-Greenstein phase function, ambient occlusion.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler3D u_volume;
layout(set = 0, binding = 1, rgba8) uniform writeonly image2D u_output;

layout(push_constant) uniform Params {
    // Image + volume dimensions
    int   img_w;
    int   img_h;
    int   vol_x;
    int   vol_y;
    int   vol_z;
    int   max_steps;
    float step_size;
    float density_scale;
    // Camera
    float eye_x, eye_y, eye_z;
    float fwd_x, fwd_y, fwd_z;
    float right_x, right_y, right_z;
    float up_x, up_y, up_z;
    float fov;
    float absorption;
    // Lighting (new)
    float light_dir_x, light_dir_y, light_dir_z;
    float light_r, light_g, light_b;
    float light_intensity;
    float hg_g;           // Henyey-Greenstein asymmetry [-1, 1]
    int   shadow_steps;   // secondary march steps (0 = no shadows)
    float ambient;        // ambient light contribution [0, 1]
    float emit_r, emit_g, emit_b;  // emission color
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

// Henyey-Greenstein phase function
float henyey_greenstein(float cos_theta, float g) {
    float g2 = g * g;
    float denom = 1.0 + g2 - 2.0 * g * cos_theta;
    return (1.0 - g2) / (4.0 * 3.14159265 * denom * sqrt(denom));
}

// Shadow ray: march toward the light from 'pos', return transmittance
float shadow_transmittance(vec3 pos, vec3 light_dir) {
    if (p.shadow_steps <= 0) return 1.0;

    // March from 'pos' in 'light_dir' until we leave the volume AABB
    float t_near_s, t_far_s;
    if (!intersect_aabb(pos, light_dir, t_near_s, t_far_s)) return 1.0;
    t_near_s = max(t_near_s, 0.001); // avoid self-sampling

    float shadow_dt = (t_far_s - t_near_s) / float(p.shadow_steps);
    float tau = 0.0;

    for (int j = 0; j < p.shadow_steps; j++) {
        float ts = t_near_s + (float(j) + 0.5) * shadow_dt;
        vec3 sp = pos + light_dir * ts;
        vec3 suvw = sp + 0.5;
        if (any(lessThan(suvw, vec3(0.0))) || any(greaterThan(suvw, vec3(1.0)))) break;
        float sd = texture(u_volume, suvw).r * p.density_scale;
        tau += sd * shadow_dt * p.absorption;
    }
    return exp(-tau);
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
    vec3 up_v = normalize(vec3(p.up_x, p.up_y, p.up_z));

    vec3 rd = normalize(fwd + right * u * half_fov * aspect + up_v * v * half_fov);

    float t_near, t_far;
    if (!intersect_aabb(eye, rd, t_near, t_far)) {
        imageStore(u_output, gid, vec4(0.0));
        return;
    }
    t_near = max(t_near, 0.0);

    // Light setup
    vec3 light_dir = normalize(vec3(p.light_dir_x, p.light_dir_y, p.light_dir_z));
    vec3 light_col = vec3(p.light_r, p.light_g, p.light_b) * p.light_intensity;
    vec3 emit_col  = vec3(p.emit_r, p.emit_g, p.emit_b);

    // Front-to-back compositing with lighting
    vec3 color = vec3(0.0);
    float transmittance = 1.0;
    float dt = p.step_size;

    for (int i = 0; i < p.max_steps; i++) {
        float t = t_near + (float(i) + 0.5) * dt;
        if (t >= t_far || transmittance < 0.01) break;

        vec3 pos = eye + rd * t;
        vec3 uvw = pos + 0.5;

        float density = texture(u_volume, uvw).r * p.density_scale;
        if (density > 0.0) {
            float alpha = 1.0 - exp(-density * dt * p.absorption);

            // Shadow ray: how much light reaches this sample
            float shadow = shadow_transmittance(pos, light_dir);

            // Phase function: angular scattering
            float cos_theta = dot(rd, light_dir);
            float phase = henyey_greenstein(cos_theta, p.hg_g);

            // Scattered light = light_color * shadow * phase
            vec3 scattered = light_col * shadow * phase;

            // Ambient contribution (omnidirectional)
            vec3 ambient_light = light_col * p.ambient;

            // Emission (self-glow proportional to density)
            vec3 emission = emit_col * density;

            // Total radiance at this sample
            vec3 radiance = (scattered + ambient_light) * density + emission;

            color += transmittance * alpha * radiance;
            transmittance *= (1.0 - alpha);
        }
    }

    imageStore(u_output, gid, vec4(color, 1.0 - transmittance));
}
