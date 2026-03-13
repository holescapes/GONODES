[remap]
type="RDShaderFile"
path="res://addons/gonodes/shaders/img/blur_img.glsl"

[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

// Input image (read-only storage image)
layout(rgba8, set = 0, binding = 0) uniform restrict readonly image2D img_in;

// Output image (write-only storage image)
layout(rgba8, set = 0, binding = 1) uniform restrict writeonly image2D img_out;

layout(push_constant) uniform PushConstants {
    int width;
    int height;
    int radius;
    int direction;   // 0 = horizontal, 1 = vertical
} pc;

void main() {
    ivec2 gid = ivec2(gl_GlobalInvocationID.xy);
    if (gid.x >= pc.width || gid.y >= pc.height) return;

    vec4 sum = vec4(0.0);
    float weight_sum = 0.0;
    float sigma = float(pc.radius) * 0.5 + 0.5;
    float inv_two_sigma_sq = 1.0 / (2.0 * sigma * sigma);

    for (int i = -pc.radius; i <= pc.radius; i++) {
        ivec2 coord;
        if (pc.direction == 0) {
            coord = ivec2(clamp(gid.x + i, 0, pc.width - 1), gid.y);
        } else {
            coord = ivec2(gid.x, clamp(gid.y + i, 0, pc.height - 1));
        }
        float w = exp(-float(i * i) * inv_two_sigma_sq);
        sum += imageLoad(img_in, coord) * w;
        weight_sum += w;
    }

    imageStore(img_out, gid, sum / weight_sum);
}
