// CRT Monitor — barrel distortion, scanlines, vignette
// Original GONODES shader — requires iChannel0 input image

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Barrel distortion
    vec2 cc = uv - 0.5;
    float dist = dot(cc, cc);
    uv = uv + cc * dist * 0.2;

    // Clamp — show black outside bounds
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // RGB channel micro-offset
    vec3 col;
    col.r = texture(iChannel0, uv + vec2(0.002, 0.0)).r;
    col.g = texture(iChannel0, uv).g;
    col.b = texture(iChannel0, uv - vec2(0.002, 0.0)).b;

    // Scanlines
    float scanline = sin(uv.y * iResolution.y * 3.14159) * 0.5 + 0.5;
    scanline = pow(scanline, 0.3);
    col *= 0.7 + 0.3 * scanline;

    // Vignette
    float vignette = 1.0 - dot(cc, cc) * 1.5;
    col *= clamp(vignette, 0.0, 1.0);

    fragColor = vec4(col, 1.0);
}
