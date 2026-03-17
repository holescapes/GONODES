shader_type canvas_item;
// Gray-Scott Reaction-Diffusion model with feedback via SCREEN_TEXTURE.
// R = chemical U, G = chemical V, B = unused (or visualization aid).
// Parameters f (feed rate) and k (kill rate) control the pattern type.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D seed_texture : filter_linear;  // Optional seed mask

uniform vec2 resolution = vec2(512.0, 512.0);
uniform float diffusion_u = 1.0;      // Diffusion rate of U
uniform float diffusion_v = 0.5;      // Diffusion rate of V
uniform float feed_rate = 0.055;       // Feed rate (f) — replenishment of U
uniform float kill_rate = 0.062;       // Kill rate (k) — removal of V
uniform float time_step = 1.0;         // Simulation speed multiplier
uniform int steps_per_frame = 4;       // Sub-steps per render (more = faster evolution)
uniform float seed_amount = 0.25;
uniform vec2 seed_pos = vec2(0.5, 0.5);
uniform float seed_radius = 0.05;
uniform bool add_seed = false;
uniform bool use_seed_texture = false;
uniform bool reset = false;

vec2 laplacian(sampler2D tex, vec2 uv, vec2 ts) {
    // 3x3 Laplacian stencil with diagonal weighting
    vec2 center = texture(tex, uv).rg;
    vec2 sum = vec2(0.0);
    sum += texture(tex, uv + vec2(-ts.x, -ts.y)).rg * 0.05;
    sum += texture(tex, uv + vec2( 0.0,  -ts.y)).rg * 0.2;
    sum += texture(tex, uv + vec2( ts.x, -ts.y)).rg * 0.05;
    sum += texture(tex, uv + vec2(-ts.x,  0.0)).rg * 0.2;
    sum += texture(tex, uv + vec2( ts.x,  0.0)).rg * 0.2;
    sum += texture(tex, uv + vec2(-ts.x,  ts.y)).rg * 0.05;
    sum += texture(tex, uv + vec2( 0.0,   ts.y)).rg * 0.2;
    sum += texture(tex, uv + vec2( ts.x,  ts.y)).rg * 0.05;
    return sum - center;
}

void fragment() {
    if (reset) {
        // Initialize: U=1 everywhere, V=0 with a small seed
        float d = length(UV - vec2(0.5));
        float v_init = (d < 0.1) ? 0.25 : 0.0;
        COLOR = vec4(1.0, v_init, 0.0, 1.0);
        return;
    }

    vec2 ts = 1.0 / resolution;
    vec2 uv = UV;

    vec2 state = texture(screen_texture, uv).rg;
    float u = state.r;
    float v = state.g;

    // Multiple sub-steps for faster pattern evolution
    for (int i = 0; i < steps_per_frame; i++) {
        vec2 lap = laplacian(screen_texture, uv, ts);

        float reaction = u * v * v;
        float du = diffusion_u * lap.r - reaction + feed_rate * (1.0 - u);
        float dv = diffusion_v * lap.g + reaction - (feed_rate + kill_rate) * v;

        u += du * time_step;
        v += dv * time_step;

        u = clamp(u, 0.0, 1.0);
        v = clamp(v, 0.0, 1.0);
    }

    // Seed injection (circle)
    if (add_seed) {
        float d = length(uv - seed_pos);
        if (d < seed_radius) {
            v = max(v, seed_amount);
            u = min(u, 1.0 - seed_amount * 0.5);
        }
    }

    // Seed from input texture
    if (use_seed_texture) {
        float seed_val = texture(seed_texture, uv).r;
        if (seed_val > 0.5) {
            v = max(v, seed_amount * seed_val);
        }
    }

    COLOR = vec4(u, v, 0.0, 1.0);
}
