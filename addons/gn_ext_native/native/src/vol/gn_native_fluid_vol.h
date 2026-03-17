#ifndef GN_NATIVE_FLUID_VOL_H
#define GN_NATIVE_FLUID_VOL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Navier-Stokes fluid simulation on flat arrays (CPU path).
/// Manages velocity + density fields statefully.
class GNNativeFluidVol : public RefCounted {
    GDCLASS(GNNativeFluidVol, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Performs one simulation step.  Returns Dictionary {"density": PF32A, "velocity": PF32A}.
    Dictionary step(const PackedFloat32Array &density_source,
                    int res_x, int res_y, int res_z, double dt,
                    double dissipation, int pressure_iters,
                    double density_add, bool reset);

    void clear_state();

private:
    PackedFloat32Array _velocity;  // RGBA flat (4-channel)
    PackedFloat32Array _density;   // scalar flat
    int _rx = 0, _ry = 0, _rz = 0;

    float _vel_at(int x, int y, int z, int comp) const;
    float _pres_at(const float *p, int x, int y, int z) const;
    float _trilinear(const float *data, double u, double v, double w) const;
};

} // namespace godot

#endif // GN_NATIVE_FLUID_VOL_H
