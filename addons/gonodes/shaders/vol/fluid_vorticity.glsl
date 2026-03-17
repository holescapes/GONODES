[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Vorticity confinement: compute curl of velocity, then apply a force
// that amplifies existing rotational motion to counteract numerical dissipation.
//
// Two-pass operation packed into one shader:
//   1. Compute curl magnitude at each voxel
//   2. Compute gradient of |curl|, derive confinement force, add to velocity

layout(set = 0, binding = 0) uniform sampler3D velocity_in;
layout(rgba32f, set = 0, binding = 1) uniform restrict image3D velocity_out;

layout(push_constant) uniform PushConstants {
    int   res_x;
    int   res_y;
    int   res_z;
    float vorticity_strength;   // Epsilon — confinement factor
    float dt;
    float pad0;
    float pad1;
    float pad2;
} pc;

// Compute curl (vorticity) at a given UVW position
vec3 compute_curl(vec3 uvw, vec3 ts) {
    // Curl = nabla × v
    float dvz_dy = texture(velocity_in, uvw + vec3(0, ts.y, 0)).z
    - texture(velocity_in, uvw - vec3(0, ts.y, 0)).z;
    float dvy_dz = texture(velocity_in, uvw + vec3(0, 0, ts.z)).y
    - texture(velocity_in, uvw - vec3(0, 0, ts.z)).y;

    float dvx_dz = texture(velocity_in, uvw + vec3(0, 0, ts.z)).x
    - texture(velocity_in, uvw - vec3(0, 0, ts.z)).x;
    float dvz_dx = texture(velocity_in, uvw + vec3(ts.x, 0, 0)).z
    - texture(velocity_in, uvw - vec3(ts.x, 0, 0)).z;

    float dvy_dx = texture(velocity_in, uvw + vec3(ts.x, 0, 0)).y
    - texture(velocity_in, uvw - vec3(ts.x, 0, 0)).y;
    float dvx_dy = texture(velocity_in, uvw + vec3(0, ts.y, 0)).x
    - texture(velocity_in, uvw - vec3(0, ts.y, 0)).x;

    return 0.5 * vec3(dvz_dy - dvy_dz, dvx_dz - dvz_dx, dvy_dx - dvx_dy);
}

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);
    if (gid.x >= pc.res_x || gid.y >= pc.res_y || gid.z >= pc.res_z) return;

    vec3 res = vec3(pc.res_x, pc.res_y, pc.res_z);
    vec3 ts = 1.0 / res;
    vec3 uvw = (vec3(gid) + 0.5) / res;

    // Current velocity
    vec4 vel = texture(velocity_in, uvw);

    // Curl at center
    vec3 curl = compute_curl(uvw, ts);
    float curl_mag = length(curl);

    // Gradient of |curl| — points toward higher vorticity
    float curl_r = length(compute_curl(uvw + vec3(ts.x, 0, 0), ts));
    float curl_l = length(compute_curl(uvw - vec3(ts.x, 0, 0), ts));
    float curl_u = length(compute_curl(uvw + vec3(0, ts.y, 0), ts));
    float curl_d = length(compute_curl(uvw - vec3(0, ts.y, 0), ts));
    float curl_f = length(compute_curl(uvw + vec3(0, 0, ts.z), ts));
    float curl_b = length(compute_curl(uvw - vec3(0, 0, ts.z), ts));

    vec3 eta = vec3(curl_r - curl_l, curl_u - curl_d, curl_f - curl_b);
    float eta_len = length(eta);

    if (eta_len > 1e-5) {
        eta /= eta_len;
        // Confinement force: perpendicular to gradient, aligned with curl
        vec3 force = pc.vorticity_strength * cross(eta, curl) * pc.dt;
        vel.xyz += force;
    }

    imageStore(velocity_out, gid, vel);
}
