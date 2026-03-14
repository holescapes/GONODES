// Star Nest — volumetric space fractal
// Inspired by "Star Nest" by Pablo Roman Andrioli (Kali) — MIT License
// https://www.shadertoy.com/view/XlfGRj

#define ITERATIONS 17
#define FORMUPARAM 0.53

#define VOLSTEPS 10
#define STEPSIZE 0.1

#define ZOOM 0.800
#define TILE 0.850
#define SPEED 0.0005

#define BRIGHTNESS 0.0015
#define DARKMATTER 0.300
#define DISTFADING 0.730
#define SATURATION 0.850

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy - 0.5;
    uv.y *= iResolution.y / iResolution.x;
    vec3 dir = vec3(uv * ZOOM, 1.0);
    float time = iTime * SPEED + 0.25;

    float a1 = 0.5 + iMouse.x / iResolution.x * 2.0;
    float a2 = 0.8 + iMouse.y / iResolution.y * 2.0;
    mat2 rot1 = mat2(vec2(cos(a1), sin(a1)), vec2(-sin(a1), cos(a1)));
    mat2 rot2 = mat2(vec2(cos(a2), sin(a2)), vec2(-sin(a2), cos(a2)));
    dir.xz = dir.xz * rot1;
    dir.xy = dir.xy * rot2;
    vec3 from = vec3(1.0, 0.5, 0.5);
    from += vec3(time * 2.0, time, -2.0);
    from.xz = from.xz * rot1;
    from.xy = from.xy * rot2;

    float s = 0.1, fade = 1.0;
    vec3 v = vec3(0.0);
    for (int r = 0; r < VOLSTEPS; r++) {
        vec3 p = from + s * dir * 0.5;
        p = abs(vec3(TILE) - mod(p, vec3(TILE * 2.0)));
        float pa, a = pa = 0.0;
        for (int i = 0; i < ITERATIONS; i++) {
            p = abs(p) / dot(p, p) - FORMUPARAM;
            a += abs(length(p) - pa);
            pa = length(p);
        }
        float dm = max(0.0, DARKMATTER - a * a * 0.001);
        a *= a * a;
        if (r > 6) fade *= 1.0 - dm;
        v += fade;
        v += vec3(s, s * s, s * s * s * s) * a * BRIGHTNESS * fade;
        fade *= DISTFADING;
        s += STEPSIZE;
    }
    v = mix(vec3(length(v)), v, SATURATION);
    fragColor = vec4(v * 0.01, 1.0);
}
