// Pixelate — mosaic / blocky pixelation
// Original GONODES shader — requires iChannel0 input image
// Uniform: float block_size = 8.0  (pixels per block)

uniform float block_size; // = 8.0

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float bs = max(block_size, 1.0);
    vec2 pixelated = floor(fragCoord.xy / bs) * bs + bs * 0.5;
    vec2 uv = pixelated / iResolution.xy;
    fragColor = texture(iChannel0, uv);
}
