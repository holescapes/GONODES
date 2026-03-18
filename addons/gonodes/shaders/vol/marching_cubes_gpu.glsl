[compute]
#version 450

layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;

// ── Input volume (R32F density field) ────────────────────────────────────────
layout(set = 0, binding = 0) uniform sampler3D volume_in;

// ── Output vertex buffer: pos(vec4) + normal(vec4) per vertex ────────────────
// Each triangle = 3 vertices × 2 vec4 = 24 floats = 96 bytes
layout(set = 0, binding = 1, std430) restrict buffer VertexBuffer {
    float verts[];
};

// ── Atomic triangle counter (single uint) ────────────────────────────────────
layout(set = 0, binding = 2, std430) restrict buffer CounterBuffer {
    uint triangle_count;
};

// ── Lookup tables (uploaded from CPU) ────────────────────────────────────────
layout(set = 0, binding = 3, std430) restrict readonly buffer EdgeTableBuf {
    int edge_table[256];
};
layout(set = 0, binding = 4, std430) restrict readonly buffer TriTableBuf {
    int tri_table[256 * 16];  // 256 rows × 16 entries (padded, -1 terminated)
};

layout(push_constant) uniform PushConstants {
    int   res_x;
    int   res_y;
    int   res_z;
    float threshold;
    int   max_triangles;    // safety cap for buffer writes
    float bound_x, bound_y, bound_z;    // AABB origin
    float size_x,  size_y,  size_z;     // AABB size
} pc;

// ── Corner offsets for the 8 vertices of a cube cell ─────────────────────────
const ivec3 CORNER[8] = ivec3[8](
    ivec3(0, 0, 0), ivec3(1, 0, 0), ivec3(1, 1, 0), ivec3(0, 1, 0),
    ivec3(0, 0, 1), ivec3(1, 0, 1), ivec3(1, 1, 1), ivec3(0, 1, 1));

// ── 12 edges as pairs of corner indices ──────────────────────────────────────
const ivec2 EDGE_PAIR[12] = ivec2[12](
    ivec2(0, 1), ivec2(1, 2), ivec2(2, 3), ivec2(3, 0),
    ivec2(4, 5), ivec2(5, 6), ivec2(6, 7), ivec2(7, 4),
    ivec2(0, 4), ivec2(1, 5), ivec2(2, 6), ivec2(3, 7));

// ── Sample volume density at integer grid coordinate ─────────────────────────
float sample_density(ivec3 p) {
    vec3 uvw = (vec3(p) + 0.5) / vec3(pc.res_x, pc.res_y, pc.res_z);
    return texture(volume_in, uvw).r;
}

// ── Grid position to world-space position ────────────────────────────────────
vec3 grid_to_world(ivec3 p) {
    vec3 t = vec3(p) / vec3(pc.res_x - 1, pc.res_y - 1, pc.res_z - 1);
    return vec3(pc.bound_x, pc.bound_y, pc.bound_z) + t * vec3(pc.size_x, pc.size_y, pc.size_z);
}

// ── Central-difference gradient for smooth normals ───────────────────────────
vec3 gradient_normal(ivec3 p) {
    float dx = sample_density(p + ivec3(1,0,0)) - sample_density(p - ivec3(1,0,0));
    float dy = sample_density(p + ivec3(0,1,0)) - sample_density(p - ivec3(0,1,0));
    float dz = sample_density(p + ivec3(0,0,1)) - sample_density(p - ivec3(0,0,1));
    vec3 g = vec3(dx, dy, dz);
    float len = length(g);
    return len > 0.0001 ? -g / len : vec3(0.0, 1.0, 0.0);
}

// ── Interpolate vertex on edge between two corners ───────────────────────────
vec3 interp_vertex(ivec3 p0, ivec3 p1, float v0, float v1) {
    float denom = v1 - v0;
    float t = abs(denom) > 0.0001 ? clamp((pc.threshold - v0) / denom, 0.0, 1.0) : 0.5;
    return grid_to_world(p0) * (1.0 - t) + grid_to_world(p1) * t;
}

// ── Interpolate normal on edge between two corners ───────────────────────────
vec3 interp_normal(ivec3 p0, ivec3 p1, float v0, float v1) {
    float denom = v1 - v0;
    float t = abs(denom) > 0.0001 ? clamp((pc.threshold - v0) / denom, 0.0, 1.0) : 0.5;
    vec3 n0 = gradient_normal(p0);
    vec3 n1 = gradient_normal(p1);
    return normalize(mix(n0, n1, t));
}

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);
    // Each thread processes one cube cell — grid is (res-1) cells
    if (gid.x >= pc.res_x - 1 || gid.y >= pc.res_y - 1 || gid.z >= pc.res_z - 1) return;

    // Sample 8 corners
    float vals[8];
    int cube_idx = 0;
    for (int i = 0; i < 8; i++) {
        ivec3 cp = gid + CORNER[i];
        vals[i] = sample_density(cp);
        if (vals[i] >= pc.threshold) cube_idx |= (1 << i);
    }

    if (cube_idx == 0 || cube_idx == 255) return;

    int edge_flags = edge_table[cube_idx];

    // Compute up to 12 edge vertices
    vec3 edge_verts[12];
    vec3 edge_norms[12];
    for (int e = 0; e < 12; e++) {
        if ((edge_flags & (1 << e)) == 0) continue;
        ivec3 p0 = gid + CORNER[EDGE_PAIR[e].x];
        ivec3 p1 = gid + CORNER[EDGE_PAIR[e].y];
        edge_verts[e] = interp_vertex(p0, p1, vals[EDGE_PAIR[e].x], vals[EDGE_PAIR[e].y]);
        edge_norms[e] = interp_normal(p0, p1, vals[EDGE_PAIR[e].x], vals[EDGE_PAIR[e].y]);
    }

    // Emit triangles from tri-table
    int row_base = cube_idx * 16;
    for (int t = 0; t < 16; t += 3) {
        int e0 = tri_table[row_base + t];
        if (e0 == -1) break;
        int e1 = tri_table[row_base + t + 1];
        int e2 = tri_table[row_base + t + 2];

        // Atomic reserve 1 triangle (3 verts × 2 vec4 = 24 floats)
        uint tri_idx = atomicAdd(triangle_count, 1);
        if (tri_idx >= pc.max_triangles) return;

        uint base_f = tri_idx * 24;  // 24 floats per triangle
        // Vertex 0: pos(vec4) + normal(vec4)
        verts[base_f +  0] = edge_verts[e0].x;
        verts[base_f +  1] = edge_verts[e0].y;
        verts[base_f +  2] = edge_verts[e0].z;
        verts[base_f +  3] = 1.0;
        verts[base_f +  4] = edge_norms[e0].x;
        verts[base_f +  5] = edge_norms[e0].y;
        verts[base_f +  6] = edge_norms[e0].z;
        verts[base_f +  7] = 0.0;
        // Vertex 1
        verts[base_f +  8] = edge_verts[e1].x;
        verts[base_f +  9] = edge_verts[e1].y;
        verts[base_f + 10] = edge_verts[e1].z;
        verts[base_f + 11] = 1.0;
        verts[base_f + 12] = edge_norms[e1].x;
        verts[base_f + 13] = edge_norms[e1].y;
        verts[base_f + 14] = edge_norms[e1].z;
        verts[base_f + 15] = 0.0;
        // Vertex 2
        verts[base_f + 16] = edge_verts[e2].x;
        verts[base_f + 17] = edge_verts[e2].y;
        verts[base_f + 18] = edge_verts[e2].z;
        verts[base_f + 19] = 1.0;
        verts[base_f + 20] = edge_norms[e2].x;
        verts[base_f + 21] = edge_norms[e2].y;
        verts[base_f + 22] = edge_norms[e2].z;
        verts[base_f + 23] = 0.0;
    }
}
