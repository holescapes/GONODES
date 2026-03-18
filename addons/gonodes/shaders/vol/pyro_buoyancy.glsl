[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Pyro buoyancy: temperature drives upward velocity + cooling/dissipation.

layout(set = 0, binding = 0) uniform sampler3D temp_in;
layout(rgba32f, set = 0, binding = 1) uniform restrict image3D velocity_field;  // read-write

layout(push_constant) uniform PushConstants {
    int   res_x;
    int   res_y;
    int   res_z;
    float dt;
    float buoyancy;        // upward force per unit temperature
    float cooling_rate;    // temperature decay per second
    float pad0;
    float pad1;
} pc;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);
    if (gid.x >= pc.res_x || gid.y >= pc.res_y || gid.z >= pc.res_z) return;

    vec3 res = vec3(pc.res_x, pc.res_y, pc.res_z);
    vec3 uvw = (vec3(gid) + 0.5) / res;

    float temp = texture(temp_in, uvw).r;

    // Read current velocity
    vec4 vel = imageLoad(velocity_field, gid);

    // Buoyancy: hot air rises (positive Y)
    vel.y += temp * pc.buoyancy * pc.dt;

    imageStore(velocity_field, gid, vel);
}
