shader_type canvas_item;
// 2D Navier-Stokes fluid simulation with feedback via SCREEN_TEXTURE.
// Packs velocity (RG), density (B), pressure (A) into a single RGBA buffer.
// Uses semi-Lagrangian advection + vorticity confinement for visually rich results.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D dye_input : filter_linear;   // Optional dye source texture

uniform vec2 resolution = vec2(512.0, 512.0);
uniform vec2 emitter_pos = vec2(0.5, 0.5);
uniform vec2 emitter_dir = vec2(0.0, -1.0);
uniform float emitter_radius = 0.06;
uniform float emitter_force = 1.0;
uniform float emitter_dye = 1.0;
uniform bool enable_emitter = true;
uniform float velocity_dissipation = 0.995;
uniform float density_dissipation = 0.98;
uniform float vorticity_strength = 0.3;
uniform float pressure_iterations = 16.0;  // drives implicit correction strength
uniform vec3 dye_color = vec3(1.0, 0.4, 0.1);
uniform float time_val = 0.0;
uniform bool use_dye_input = false;
uniform bool reset = false;

void fragment() {
    if (reset) {
        COLOR = vec4(0.0);
    } else {

    vec2 uv = UV;
    vec2 texel = 1.0 / resolution;

    // --- Read previous frame ---
    vec4 prev = texture(screen_texture, uv);
    vec2 vel = prev.rg * 2.0 - 1.0;   // Decode velocity from [0,1] to [-1,1]
    float density = prev.b;

    // --- 1. Semi-Lagrangian self-advection ---
    vec2 back_pos = uv - vel * texel * 1.0;
    vec4 advected = texture(screen_texture, back_pos);
    vel = (advected.rg * 2.0 - 1.0) * velocity_dissipation;
    density = advected.b * density_dissipation;

    // --- 2. Vorticity confinement ---
    // Compute curl (scalar in 2D = dVx/dy - dVy/dx)
    vec2 vel_r = (texture(screen_texture, uv + vec2(texel.x, 0.0)).rg * 2.0 - 1.0);
    vec2 vel_l = (texture(screen_texture, uv - vec2(texel.x, 0.0)).rg * 2.0 - 1.0);
    vec2 vel_u = (texture(screen_texture, uv + vec2(0.0, texel.y)).rg * 2.0 - 1.0);
    vec2 vel_d = (texture(screen_texture, uv - vec2(0.0, texel.y)).rg * 2.0 - 1.0);

    float curl_center = (vel_r.y - vel_l.y) * 0.5 - (vel_u.x - vel_d.x) * 0.5;
    float curl_r = ((texture(screen_texture, uv + vec2(2.0 * texel.x, 0.0)).rg * 2.0 - 1.0).y
                   - vel_r.y) * 0.5 - ((texture(screen_texture, uv + vec2(texel.x, texel.y)).rg * 2.0 - 1.0).x
                   - vel_r.x) * 0.5;
    float curl_l = (vel_l.y
                   - (texture(screen_texture, uv - vec2(2.0 * texel.x, 0.0)).rg * 2.0 - 1.0).y) * 0.5
                   - (vel_l.x
                   - (texture(screen_texture, uv - vec2(texel.x, texel.y)).rg * 2.0 - 1.0).x) * 0.5;
    float curl_u = ((texture(screen_texture, uv + vec2(texel.x, texel.y)).rg * 2.0 - 1.0).y
                   - (texture(screen_texture, uv - vec2(texel.x, texel.y)).rg * 2.0 - 1.0).y) * 0.5
                   - ((texture(screen_texture, uv + vec2(0.0, 2.0 * texel.y)).rg * 2.0 - 1.0).x
                   - vel_u.x) * 0.5;
    float curl_d = ((texture(screen_texture, uv + vec2(texel.x, -texel.y)).rg * 2.0 - 1.0).y
                   - (texture(screen_texture, uv - vec2(texel.x, -texel.y)).rg * 2.0 - 1.0).y) * 0.5
                   - (vel_d.x
                   - (texture(screen_texture, uv - vec2(0.0, 2.0 * texel.y)).rg * 2.0 - 1.0).x) * 0.5;

    // Simplified gradient of |curl| for vorticity direction
    vec2 eta = vec2(abs(curl_r) - abs(curl_l), abs(curl_u) - abs(curl_d));
    float eta_len = length(eta);
    if (eta_len > 1e-5) {
        eta /= eta_len;
        // Force perpendicular to gradient, in direction of curl
        vec2 vort_force = vec2(eta.y, -eta.x) * curl_center * vorticity_strength;
        vel += vort_force * texel;
    }

    // --- 3. Simplified pressure correction (neighborhood averaging) ---
    float pressure_factor = clamp(pressure_iterations / 32.0, 0.0, 1.0);
    vec2 vel_avg = (vel_r + vel_l + vel_u + vel_d) * 0.25;
    float div = ((vel_r.x - vel_l.x) + (vel_u.y - vel_d.y)) * 0.5;
    vel = mix(vel, vel - vec2(div) * 0.5, pressure_factor);

    // --- 4. Emitter ---
    if (enable_emitter) {
        float d = length(uv - emitter_pos);
        float falloff = exp(-d * d / (emitter_radius * emitter_radius + 1e-6));
        vel += normalize(emitter_dir + vec2(1e-6)) * emitter_force * falloff;
        density += emitter_dye * falloff;
    }

    // --- 5. Dye input ---
    if (use_dye_input) {
        float dye_val = texture(dye_input, uv).r;
        density += dye_val * 0.1;
    }

    density = clamp(density, 0.0, 1.0);

    // Encode velocity: [-1,1] → [0,1] for storage
    vec2 vel_encoded = clamp(vel * 0.5 + 0.5, 0.0, 1.0);

    COLOR = vec4(vel_encoded, density, 1.0);
    } // end else (not reset)
}
