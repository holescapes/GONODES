[compute]
#version 450

layout(local_size_x = 256) in;

// Standard POP particle struct (64 bytes)
struct Particle {
    vec4 pos;
    vec4 vel;
    vec4 color;
    float age;
    float life;
    float mass;
    float pscale;
};

layout(set = 0, binding = 0, std430) restrict readonly buffer ParticleBuffer {
    Particle particles[];
};

// Trail ring buffer: trail_length positions per particle (vec4 each)
layout(set = 0, binding = 1, std430) restrict buffer TrailBuffer {
    vec4 trail_positions[];  // [particle_idx * trail_length + ring_slot]
};

// Output ribbon vertex buffer: 2 verts per trail point (left + right of ribbon)
// Layout per vertex: pos(vec4) + normal(vec4) + uv(vec4) + color(vec4) = 64 bytes
layout(set = 0, binding = 2, std430) restrict writeonly buffer RibbonVertBuffer {
    float ribbon_verts[];
};

// Output index buffer for triangle strip → triangle list
layout(set = 0, binding = 3, std430) restrict writeonly buffer RibbonIndexBuffer {
    uint ribbon_indices[];
};

layout(push_constant) uniform PushConstants {
    int   particle_count;
    int   trail_length;     // ring buffer depth per particle
    int   write_slot;       // current ring buffer write position
    float ribbon_width;
    float dt;
    int   phase;            // 0 = record positions, 1 = build ribbon geometry
    float taper;            // 0..1 width taper along trail (0 = uniform, 1 = full taper to tip)
    float pad1;
} pc;

// ── Phase 0: Record current particle positions into trail ring buffer ────────
void record_phase() {
    uint gid = gl_GlobalInvocationID.x;
    if (gid >= pc.particle_count) return;

    // Skip dead particles
    if (particles[gid].age >= particles[gid].life) {
        trail_positions[gid * pc.trail_length + pc.write_slot] = vec4(0.0, -99999.0, 0.0, 0.0);
        return;
    }

    trail_positions[gid * pc.trail_length + pc.write_slot] = particles[gid].pos;
}

// ── Phase 1: Build ribbon geometry from trail ring buffer ────────────────────
void build_phase() {
    uint gid = gl_GlobalInvocationID.x;
    if (gid >= pc.particle_count) return;

    // Skip dead particles
    if (particles[gid].age >= particles[gid].life) return;

    uint trail_base = gid * pc.trail_length;
    // Read trail points in chronological order (oldest → newest)
    // write_slot is where we JUST wrote, so oldest = (write_slot + 1) % trail_length

    // Count valid points and determine the chronological sequence
    int valid_count = 0;
    for (int i = 0; i < pc.trail_length; i++) {
        int slot = (pc.write_slot + 1 + i) % pc.trail_length;
        vec4 p = trail_positions[trail_base + slot];
        if (p.y > -99000.0) valid_count++;
    }
    if (valid_count < 2) return;

    // Build ribbon: 2 vertices per valid trail point (left/right offset)
    // Use velocity direction (tangent) to compute perpendicular ribbon axis
    uint vert_base = gid * pc.trail_length * 2;  // 2 verts per trail point
    uint idx_base = gid * (pc.trail_length - 1) * 6;  // 6 indices per quad (2 tris)

    int written = 0;
    for (int i = 0; i < pc.trail_length; i++) {
        int slot = (pc.write_slot + 1 + i) % pc.trail_length;
        vec4 p = trail_positions[trail_base + slot];
        if (p.y < -99000.0) continue;

        // Compute tangent from neighbors
        int prev_slot = (slot - 1 + pc.trail_length) % pc.trail_length;
        int next_slot = (slot + 1) % pc.trail_length;
        vec3 prev_p = trail_positions[trail_base + prev_slot].xyz;
        vec3 next_p = trail_positions[trail_base + next_slot].xyz;

        vec3 tangent;
        if (prev_p.y < -99000.0) tangent = normalize(next_p - p.xyz);
        else if (next_p.y < -99000.0) tangent = normalize(p.xyz - prev_p);
        else tangent = normalize(next_p - prev_p);

        // Perpendicular in camera-agnostic way: cross with up, fallback to right
        vec3 up = vec3(0.0, 1.0, 0.0);
        vec3 side = cross(tangent, up);
        if (length(side) < 0.001) side = cross(tangent, vec3(1.0, 0.0, 0.0));
        side = normalize(side);

        // Taper width along trail (0 = oldest/thinnest, 1 = newest/widest)
        float t = float(written) / float(max(valid_count - 1, 1));
        float width = pc.ribbon_width * mix(1.0 - pc.taper, 1.0, t);

        vec3 normal = normalize(cross(tangent, side));
        vec4 color = particles[gid].color;
        // Fade alpha along trail
        color.a *= t;

        // Left vertex
        uint lv = (vert_base + written * 2) * 16;  // 16 floats per vertex
        vec3 left_pos = p.xyz - side * width;
        ribbon_verts[lv +  0] = left_pos.x;
        ribbon_verts[lv +  1] = left_pos.y;
        ribbon_verts[lv +  2] = left_pos.z;
        ribbon_verts[lv +  3] = 1.0;
        ribbon_verts[lv +  4] = normal.x;
        ribbon_verts[lv +  5] = normal.y;
        ribbon_verts[lv +  6] = normal.z;
        ribbon_verts[lv +  7] = 0.0;
        ribbon_verts[lv +  8] = 0.0;  // u = 0 (left)
        ribbon_verts[lv +  9] = t;    // v = trail position
        ribbon_verts[lv + 10] = 0.0;
        ribbon_verts[lv + 11] = 0.0;
        ribbon_verts[lv + 12] = color.r;
        ribbon_verts[lv + 13] = color.g;
        ribbon_verts[lv + 14] = color.b;
        ribbon_verts[lv + 15] = color.a;

        // Right vertex
        uint rv = (vert_base + written * 2 + 1) * 16;
        vec3 right_pos = p.xyz + side * width;
        ribbon_verts[rv +  0] = right_pos.x;
        ribbon_verts[rv +  1] = right_pos.y;
        ribbon_verts[rv +  2] = right_pos.z;
        ribbon_verts[rv +  3] = 1.0;
        ribbon_verts[rv +  4] = normal.x;
        ribbon_verts[rv +  5] = normal.y;
        ribbon_verts[rv +  6] = normal.z;
        ribbon_verts[rv +  7] = 0.0;
        ribbon_verts[rv +  8] = 1.0;  // u = 1 (right)
        ribbon_verts[rv +  9] = t;
        ribbon_verts[rv + 10] = 0.0;
        ribbon_verts[rv + 11] = 0.0;
        ribbon_verts[rv + 12] = color.r;
        ribbon_verts[rv + 13] = color.g;
        ribbon_verts[rv + 14] = color.b;
        ribbon_verts[rv + 15] = color.a;

        // Emit quad indices (two triangles) connecting this pair to the next
        if (written > 0) {
            uint qi = idx_base + (written - 1) * 6;
            uint prev_l = vert_base + (written - 1) * 2;
            uint prev_r = prev_l + 1;
            uint curr_l = vert_base + written * 2;
            uint curr_r = curr_l + 1;
            ribbon_indices[qi + 0] = prev_l;
            ribbon_indices[qi + 1] = curr_l;
            ribbon_indices[qi + 2] = prev_r;
            ribbon_indices[qi + 3] = prev_r;
            ribbon_indices[qi + 4] = curr_l;
            ribbon_indices[qi + 5] = curr_r;
        }

        written++;
    }
}

void main() {
    if (pc.phase == 0) record_phase();
    else               build_phase();
}
