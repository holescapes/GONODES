// Plasma Globe — classic retro plasma effect
// Original GONODES shader

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - iResolution.xy * 0.5) / min(iResolution.x, iResolution.y);
    float t = iTime * 0.5;

    float v = sin(uv.x * 10.0 + t)
    + sin(uv.y * 10.0 + t * 0.7)
    + sin((uv.x + uv.y) * 5.0 + t * 1.3);

    float cx = uv.x + 0.5 * sin(t * 0.33);
    float cy = uv.y + 0.5 * cos(t * 0.5);
    v += sin(sqrt(100.0 * (cx * cx + cy * cy) + 1.0) + t);
    v *= 0.25;

    vec3 col;
    col.r = sin(v * 3.14159);
    col.g = sin(v * 3.14159 + 2.094);
    col.b = sin(v * 3.14159 + 4.189);
    col = col * 0.5 + 0.5;
    col = max(col, vec3(0.0));
    col *= 1.0 - length(uv) * 0.3;

    fragColor = vec4(col, 1.0);
}
