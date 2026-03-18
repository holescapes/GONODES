[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Pyro combustion step: fuel burns → temperature rises → density (smoke) produced.
// Reads fuel + temperature fields, outputs updated fuel + temperature + density injection.

layout(r32f, set = 0, binding = 0) uniform restrict image3D fuel_field;      // read-write
layout(r32f, set = 0, binding = 1) uniform restrict image3D temp_field;      // read-write
layout(r32f, set = 0, binding = 2) uniform restrict image3D density_field;   // read-write

layout(push_constant) uniform PushConstants {
    int   res_x;
    int   res_y;
    int   res_z;
    float dt;
    float burn_rate;        // fuel consumed per second (0.5 – 5.0)
    float heat_output;      // temperature generated per unit fuel burned
    float smoke_output;     // density generated per unit fuel burned
    float ignition_temp;    // minimum temperature to sustain combustion
} pc;

void main() {
    ivec3 gid = ivec3(gl_GlobalInvocationID);
    if (gid.x >= pc.res_x || gid.y >= pc.res_y || gid.z >= pc.res_z) return;

    float fuel = imageLoad(fuel_field, gid).r;
    float temp = imageLoad(temp_field, gid).r;
    float dens = imageLoad(density_field, gid).r;

    // Combustion: fuel burns when temperature exceeds ignition threshold
    float burn = 0.0;
    if (fuel > 0.001 && temp > pc.ignition_temp) {
        burn = min(fuel, pc.burn_rate * pc.dt);
        fuel -= burn;
        temp += burn * pc.heat_output;
        dens += burn * pc.smoke_output;
    }

    imageStore(fuel_field, gid, vec4(max(fuel, 0.0), 0.0, 0.0, 0.0));
    imageStore(temp_field, gid, vec4(max(temp, 0.0), 0.0, 0.0, 0.0));
    imageStore(density_field, gid, vec4(max(dens, 0.0), 0.0, 0.0, 0.0));
}
