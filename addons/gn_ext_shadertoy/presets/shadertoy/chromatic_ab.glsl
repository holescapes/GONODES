// Chromatic Aberration — radial RGB channel offset
// Original GONODES shader — requires iChannel0 input image

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 dir = uv - 0.5;
    float dist = length(dir);

    float strength = 0.012 * dist;

    vec3 col;
    col.r = texture(iChannel0, uv - dir * strength * 1.0).r;
    col.g = texture(iChannel0, uv - dir * strength * 0.5).g;
    col.b = texture(iChannel0, uv + dir * strength * 0.5).b;

    fragColor = vec4(col, 1.0);
}
