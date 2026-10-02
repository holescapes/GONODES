[compute]
#version 450

// raymarch_vol.glsl — Volume ray-marching → 2D image output.
// One directional light, shadow rays toward that light,
// Henyey-Greenstein scattering, ambient fill, and emission.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler3D u_volume;
layout(set = 0, binding = 1, rgba8) uniform writeonly image2D u_output;

layout(push_constant) uniform Params {
    // 32 scalars, 128 bytes. Godot rejects anything larger.
    int   img_w;
    int   img_h;
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

// One slab of the unit cube [-0.5, 0.5]. A zero direction is inside or a miss,
// never a divide by zero. That case is a camera or a light aimed on an axis.
bool clip_slab(float ro, float rd, inout float t_near, inout float t_far) {
    if (abs(rd) < 1e-8) {
        return ro >= -0.5 && ro <= 0.5;
    }
    float t0 = (-0.5 - ro) / rd;
    float t1 = ( 0.5 - ro) / rd;
    if (t0 > t1) {
        float tmp = t0;
        t0 = t1;
        t1 = tmp;
    }
    t_near = max(t_near, t0);
    t_far = min(t_far, t1);
    return t_near < t_far;
}

// AABB ray intersection (unit cube centered at origin: -0.5 to 0.5)
bool intersect_aabb(vec3 ro, vec3 rd, out float t_near, out float t_far) {
    t_near = -1.0e20;
    t_far = 1.0e20;
    if (!clip_slab(ro.x, rd.x, t_near, t_far)) return false;
    if (!clip_slab(ro.y, rd.y, t_near, t_far)) return false;
    if (!clip_slab(ro.z, rd.z, t_near, t_far)) return false;
    return t_far > 0.0;
}

// Henyey-Greenstein shape. At g = 0 this is 1, so Light Intensity is the
// brightness. g > 0 brightens where the view looks toward the light.
float henyey_greenstein(float cos_theta, float g) {
    float g2 = g * g;
    float denom = max(1.0 + g2 - 2.0 * g * cos_theta, 1e-4);
    return (1.0 - g2) / (denom * sqrt(denom));
}

// Shadow ray: march toward the light from 'pos', return transmittance
float shadow_transmittance(vec3 pos, vec3 light_dir) {
    if (p.shadow_steps <= 0) return 1.0;

    // March from 'pos' toward the light until we leave the volume AABB.
    float t_near_s, t_far_s;
    if (!intersect_aabb(pos, light_dir, t_near_s, t_far_s)) return 1.0;
    t_near_s = max(t_near_s, 0.0);

    float span = t_far_s - t_near_s;
    if (span <= 1e-4) return 1.0;
    float shadow_dt = span / float(p.shadow_steps);
    float tau = 0.0;
    // Skip the first step, or the voxel being shaded darkens its own lit face.
    for (int j = 1; j < p.shadow_steps; j++) {
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

            // alpha already carries density. Multiplying again squares it,
            // which hides the light and the shadow in the thick parts.
            vec3 scattered = light_col * shadow * phase;
            vec3 ambient_light = light_col * p.ambient;
            vec3 radiance = scattered + ambient_light + emit_col;

            color += transmittance * alpha * radiance;
            transmittance *= (1.0 - alpha);
        }
    }

    imageStore(u_output, gid, vec4(color, 1.0 - transmittance));
}
