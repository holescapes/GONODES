shader_type canvas_item;
// Visualization shader for ReactionDiffusionTOP.
// Reads U (R) and V (G) and renders a styled output.

uniform sampler2D sim_texture : filter_linear;
uniform int color_mode = 0;   // 0=Mono, 1=Heat, 2=Custom
uniform vec3 color_a = vec3(0.0, 0.0, 0.0);     // Background color
uniform vec3 color_b = vec3(1.0, 1.0, 1.0);     // Pattern color
uniform float brightness = 1.0;
uniform bool invert = false;

vec3 heat_palette(float t) {
    // Black → Blue → Cyan → Green → Yellow → Red → White
    vec3 col = vec3(0.0);
    col.r = smoothstep(0.4, 0.8, t);
    col.g = smoothstep(0.15, 0.5, t) - smoothstep(0.7, 1.0, t);
    col.b = smoothstep(0.0, 0.3, t) - smoothstep(0.5, 0.8, t);
    col += smoothstep(0.9, 1.0, t);
    return col;
}

void fragment() {
    vec2 state = texture(sim_texture, UV).rg;
    float u = state.r;
    float v = state.g;

    // V channel shows the pattern (higher V = more pattern)
    float pattern = v * brightness;
    if (invert) pattern = 1.0 - pattern;

    vec3 col;
    if (color_mode == 0) {
        // Monochrome
        col = vec3(pattern);
    } else if (color_mode == 1) {
        // Heat map
        col = heat_palette(pattern);
    } else {
        // Custom two-color
        col = mix(color_a, color_b, pattern);
    }

    COLOR = vec4(col, 1.0);
}
