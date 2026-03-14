[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Semi-Lagrangian advection: trace back in time through velocity field
layout(set = 0, binding = 0) uniform sampler3D velocity_in;
layout(set = 0, binding = 1) uniform sampler3D quantity_in;   // density or velocity to advect
layout(r32f, set = 0, binding = 2) uniform restrict writeonly image3D quantity_out;

layout(push_constant) uniform PushConstants {
    int   res_x;
    int   res_y;
    int   res_z;
    float dt;
    float dissipation;  // decay factor (0.99 = slow decay, 0.9 = fast)
    float pad0;
    float pad1;
    float pad2;
} pc;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);
    if (gid.x >= pc.res_x || gid.y >= pc.res_y || gid.z >= pc.res_z) return;

    vec3 res = vec3(pc.res_x, pc.res_y, pc.res_z);
    vec3 uvw = (vec3(gid) + 0.5) / res;

    // Read velocity at this voxel
    vec3 vel = texture(velocity_in, uvw).xyz;

    // Trace back in time (semi-Lagrangian)
    vec3 back_pos = uvw - vel * pc.dt / res;

    // Sample the quantity at the backtraced position
    float q = texture(quantity_in, back_pos).r;

    // Apply dissipation
    q *= pc.dissipation;

    imageStore(quantity_out, gid, vec4(q, 0.0, 0.0, 0.0));
}
