// Compact Colour Field — demoscene-inspired 1KB visual
// Inspired by "Creation" by Danilo Guanabara (Silexars) — CC BY-NC-SA 3.0
// https://www.shadertoy.com/view/XsXXDn

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec3 c;
    float l, z = iTime;
    for (int i = 0; i < 3; i++) {
        vec2 uv, p = fragCoord.xy / iResolution.xy;
        uv = p;
        p -= 0.5;
        p.x *= iResolution.x / iResolution.y;
        z += 0.07;
        l = length(p);
        uv += p / l * (sin(z) + 1.0) * abs(sin(l * 9.0 - z * 2.0));
        c[i] = 0.01 / length(mod(uv, 1.0) - 0.5);
    }
    fragColor = vec4(c / l, 1.0);
}
