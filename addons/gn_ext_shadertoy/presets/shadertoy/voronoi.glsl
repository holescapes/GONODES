// Voronoi Cells — animated cellular noise
// Original GONODES shader

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.yy * 4.0;
    float t = iTime * 0.3;

    vec2 ip = floor(uv);
    vec2 fp = fract(uv);

    float minDist = 8.0;
    float minDist2 = 8.0;
    vec2 minCell = vec2(0.0);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = hash2(ip + neighbor);
            point = 0.5 + 0.5 * sin(t + 6.2831 * point);
            vec2 diff = neighbor + point - fp;
            float d = length(diff);
            if (d < minDist) {
                minDist2 = minDist;
                minDist = d;
                minCell = ip + neighbor;
            } else if (d < minDist2) {
                minDist2 = d;
            }
        }
    }

    vec3 cellCol = 0.5 + 0.5 * cos(vec3(hash2(minCell).x * 6.28) + vec3(0.0, 2.1, 4.2));
    float edge = smoothstep(0.0, 0.05, minDist2 - minDist);
    vec3 col = cellCol * edge;
    col = pow(max(col, vec3(0.0)), vec3(0.8));

    fragColor = vec4(col, 1.0);
}
