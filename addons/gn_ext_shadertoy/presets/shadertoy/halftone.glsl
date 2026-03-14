// CMYK Halftone — dot-screen halftone rendering
// Original GONODES shader — requires iChannel0 input image
// Uniforms: float dot_size = 6.0,  float angle_offset = 0.0

uniform float dot_size;     // = 6.0
uniform float angle_offset; // = 0.0

float halftone_channel(sampler2D tex, vec2 uv, vec2 res,
    float angle, float cell) {
    float rad = radians(angle);
    mat2 rot = mat2(cos(rad), -sin(rad), sin(rad), cos(rad));
    vec2 grid = rot * (uv * res / cell);
    vec2 nearest = (floor(grid) + 0.5) / (res / cell);
    nearest = rot * nearest;  // inverse-rotate (transpose = inverse for ortho)
    float sample_val = dot(texture(tex, nearest).rgb, vec3(0.333));
    float radius = sqrt(sample_val) * cell * 0.5;
    vec2 delta = (rot * (uv * res)) - (floor(rot * (uv * res)) + 0.5);
    return step(length(delta), radius / cell);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    float cell = max(dot_size, 2.0);
    float ao = angle_offset;

    // Sample src at actual UV for hue
    vec4 src = texture(iChannel0, uv);
    float c = 1.0 - src.r;
    float m = 1.0 - src.g;
    float y = 1.0 - src.b;
    float k = min(c, min(m, y));

    // Simple CMYK dot pattern — separate angles per channel
    vec2 px = fragCoord.xy;
    float dot_c = halftone_channel(iChannel0, uv, iResolution.xy, 15.0 + ao, cell);
    float dot_m = halftone_channel(iChannel0, uv, iResolution.xy, 75.0 + ao, cell);
    float dot_y = halftone_channel(iChannel0, uv, iResolution.xy, 0.0  + ao, cell);
    float dot_k = halftone_channel(iChannel0, uv, iResolution.xy, 45.0 + ao, cell);

    vec3 col = vec3(1.0);
    col -= vec3(0.0, c * dot_c, c * dot_c);
    col -= vec3(m * dot_m, 0.0, m * dot_m);
    col -= vec3(y * dot_y, y * dot_y, 0.0);
    col -= vec3(k * dot_k);
    col = clamp(col, 0.0, 1.0);

    fragColor = vec4(col, 1.0);
}
