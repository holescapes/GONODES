// Lava Lamp — smooth metaball blobs
// Original GONODES shader

float blob(vec2 uv, vec2 center, float r) {
    float d = length(uv - center);
    return r / (d * d + 0.001);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv.x *= iResolution.x / iResolution.y;
    float t = iTime * 0.4;

    float f = 0.0;
    f += blob(uv, vec2(0.5 + sin(t) * 0.3, 0.5 + cos(t * 0.9) * 0.3), 0.04);
    f += blob(uv, vec2(0.5 + cos(t * 1.1) * 0.25, 0.5 + sin(t * 1.3) * 0.25), 0.03);
    f += blob(uv, vec2(0.5 + sin(t * 0.7 + 1.0) * 0.35, 0.5 + cos(t * 0.5) * 0.2), 0.035);
    f += blob(uv, vec2(0.5 + cos(t * 1.4) * 0.15, 0.5 + sin(t * 1.7 + 2.0) * 0.3), 0.025);

    f = clamp(f, 0.0, 1.0);

    vec3 warm = vec3(1.0, 0.4, 0.05);
    vec3 cool = vec3(0.05, 0.1, 0.4);
    vec3 col = mix(cool, warm, smoothstep(0.3, 0.7, f));
    col = pow(col, vec3(0.8));

    fragColor = vec4(col, 1.0);
}
