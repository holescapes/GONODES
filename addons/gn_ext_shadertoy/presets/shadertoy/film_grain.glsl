// Film Grain — animated photographic noise overlay
// Original GONODES shader — requires iChannel0 input image
// Uniforms: float grain_amount = 0.08,  float grain_size = 1.5

uniform float grain_amount; // = 0.08
uniform float grain_size;   // = 1.5

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 src = texture(iChannel0, uv);

    // Animated grain — use floor to get per-grain-cell values, iTime for animation
    vec2 gp = floor(fragCoord.xy / max(grain_size, 0.5));
    float frame = floor(iTime * 24.0);
    float noise = hash(gp + vec2(frame * 17.3, frame * 31.7));

    // Luminance-weighted grain: more grain in midtones
    float luma = dot(src.rgb, vec3(0.299, 0.587, 0.114));
    float mask = 4.0 * luma * (1.0 - luma);
    vec3 col = src.rgb + (noise - 0.5) * grain_amount * mask;

    fragColor = vec4(col, src.a);
}
