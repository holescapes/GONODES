shader_type canvas_item;
// Visualization shader for Fluid2DTOP.
// Reads the raw simulation buffer (vel in RG, density in B) and renders
// the density field colored by velocity direction.

uniform sampler2D sim_texture : filter_linear;  // The raw fluid buffer
uniform vec3 dye_color_a = vec3(1.0, 0.4, 0.1);
uniform vec3 dye_color_b = vec3(0.1, 0.4, 1.0);
uniform float brightness = 1.5;
uniform bool show_velocity = false;

void fragment() {
    vec4 sim = texture(sim_texture, UV);
    vec2 vel = sim.rg * 2.0 - 1.0;
    float density = sim.b;

    if (show_velocity) {
        // Visualize velocity as color (direction → hue, magnitude → brightness)
        float angle = atan(vel.y, vel.x);
        float mag = length(vel);
        vec3 col = vec3(
            0.5 + 0.5 * cos(angle),
            0.5 + 0.5 * cos(angle + 2.094),
            0.5 + 0.5 * cos(angle + 4.189)
        ) * mag * brightness;
        COLOR = vec4(col, 1.0);
    } else {
        // Density visualization with velocity-derived color blending
        float angle = atan(vel.y, vel.x) * 0.5 + 0.5;
        vec3 col = mix(dye_color_a, dye_color_b, angle) * density * brightness;
        COLOR = vec4(col, 1.0);
    }
}
