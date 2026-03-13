#[compute]
#version 450

// sop_to_vol.glsl — Rasterize point cloud (SSBO positions) into density grid.
// Each point splatted as a sphere with configurable radius.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(set = 0, binding = 0, r32f) uniform image3D u_output;

layout(set = 0, binding = 1, std430) restrict readonly buffer Points {
    vec4 positions[];   // xyz = position, w = weight (1.0 default)
};

layout(push_constant) uniform Params {
    int   res_x;
    int   res_y;
    int   res_z;
    int   point_count;
    float radius;       // Splat radius in world space
    float strength;     // Density multiplier
    // Volume bounds: min(3) + size(3)
    float bounds_min_x, bounds_min_y, bounds_min_z;
    float bounds_size_x, bounds_size_y, bounds_size_z;
} p;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);
    if (gid.x >= p.res_x || gid.y >= p.res_y || gid.z >= p.res_z) return;

    // Voxel center in world space
    vec3 voxel_pos = vec3(
        p.bounds_min_x + (float(gid.x) + 0.5) / float(p.res_x) * p.bounds_size_x,
        p.bounds_min_y + (float(gid.y) + 0.5) / float(p.res_y) * p.bounds_size_y,
        p.bounds_min_z + (float(gid.z) + 0.5) / float(p.res_z) * p.bounds_size_z);

    float density = 0.0;
    float inv_r2 = 1.0 / (p.radius * p.radius);

    for (int i = 0; i < p.point_count; i++) {
        vec3 pt = positions[i].xyz;
        float w = positions[i].w;
        vec3 d = voxel_pos - pt;
        float dist2 = dot(d, d);
        if (dist2 < p.radius * p.radius) {
            // Smooth falloff: 1 - (dist/radius)^2
            float f = 1.0 - dist2 * inv_r2;
            density += f * f * w * p.strength;
        }
    }

    imageStore(u_output, gid, vec4(density, 0.0, 0.0, 0.0));
}
