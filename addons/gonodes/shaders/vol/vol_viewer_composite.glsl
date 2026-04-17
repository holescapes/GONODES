[compute]
#version 450

// vol_viewer_composite.glsl — Volume viewer: 2×2 slice composite on GPU.
// Top-left: XY slice, Top-right: XZ slice,
// Bottom-left: YZ slice, Bottom-right: MIP (or black).
// Each quadrant maps its local (u,v) to the 3D volume via a sampler.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler3D u_volume;
layout(set = 0, binding = 1, rgba8) uniform writeonly image2D u_output;

layout(push_constant) uniform Params {
    int   img_w;       // output image width
    int   img_h;       // output image height
    int   vol_x;       // volume resolution X
    int   vol_y;       // volume resolution Y
    int   vol_z;       // volume resolution Z
    float slice_pos;   // normalized slice position [0,1]
    int   show_mip;    // 1 = show MIP in bottom-right, 0 = leave black
    int   mip_steps;   // number of depth samples for MIP
} p;

// Map a raw density value to grayscale RGBA.
vec4 density_to_color(float d) {
    float v = clamp(d, 0.0, 1.0);
    return vec4(v, v, v, 1.0);
}

void main() {
    ivec2 gid = ivec2(gl_GlobalInvocationID.xy);
    if (gid.x >= p.img_w || gid.y >= p.img_h) return;

    int half_w = p.img_w / 2;
    int half_h = p.img_h / 2;

    // Determine which quadrant this pixel is in.
    int qx = gid.x < half_w ? 0 : 1;
    int qy = gid.y < half_h ? 0 : 1;

    // Local coordinates within the quadrant [0,1].
    float lu, lv;
    if (qx == 0) {
        lu = (float(gid.x) + 0.5) / float(half_w);
    } else {
        lu = (float(gid.x - half_w) + 0.5) / float(max(p.img_w - half_w, 1));
    }
    if (qy == 0) {
        lv = (float(gid.y) + 0.5) / float(half_h);
    } else {
        lv = (float(gid.y - half_h) + 0.5) / float(max(p.img_h - half_h, 1));
    }

    vec4 out_color = vec4(0.06, 0.06, 0.08, 1.0); // background

    if (qx == 0 && qy == 0) {
        // Top-left: XY slice at fixed Z = slice_pos.
        vec3 uvw = vec3(lu, lv, p.slice_pos);
        float d = texture(u_volume, uvw).r;
        out_color = density_to_color(d);
    }
    else if (qx == 1 && qy == 0) {
        // Top-right: XZ slice at fixed Y = slice_pos.
        // u → X, v → Z, fixed Y.
        vec3 uvw = vec3(lu, p.slice_pos, lv);
        float d = texture(u_volume, uvw).r;
        out_color = density_to_color(d);
    }
    else if (qx == 0 && qy == 1) {
        // Bottom-left: YZ slice at fixed X = slice_pos.
        // u → Y, v → Z, fixed X.
        vec3 uvw = vec3(p.slice_pos, lu, lv);
        float d = texture(u_volume, uvw).r;
        out_color = density_to_color(d);
    }
    else if (qx == 1 && qy == 1 && p.show_mip != 0) {
        // Bottom-right: Maximum Intensity Projection along Z.
        // For each (u,v) = (x,y), march through all Z slices and take max.
        float max_d = 0.0;
        int steps = max(p.mip_steps, 1);
        for (int i = 0; i < steps; i++) {
            float z = (float(i) + 0.5) / float(steps);
            float d = texture(u_volume, vec3(lu, lv, z)).r;
            max_d = max(max_d, d);
        }
        out_color = density_to_color(max_d);
    }

    imageStore(u_output, gid, out_color);
}
