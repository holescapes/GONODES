#include "gn_native_lag_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

using namespace godot;

void GNNativeLagChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "data", "attack", "release", "dt"), &GNNativeLagChop::process);
    ClassDB::bind_method(D_METHOD("reset"), &GNNativeLagChop::reset);
}

PackedFloat32Array GNNativeLagChop::process(const PackedFloat32Array &p_data,
                                              double p_attack, double p_release,
                                              double p_dt) {
    int count = p_data.size();
    PackedFloat32Array out;
    out.resize(count);
    if (count == 0) return out;

    // Initialize state if needed
    if (_prev.size() != count) {
        _prev.resize(count);
        memcpy(_prev.ptrw(), p_data.ptr(), count * sizeof(float));
        memcpy(out.ptrw(), p_data.ptr(), count * sizeof(float));
        return out;
    }

    // Compute smoothing factors
    double attack_factor = (p_attack > 1e-6) ? (1.0 - std::exp(-p_dt / p_attack)) : 1.0;
    double release_factor = (p_release > 1e-6) ? (1.0 - std::exp(-p_dt / p_release)) : 1.0;

    const float *src = p_data.ptr();
    float *prev = _prev.ptrw();
    float *dst = out.ptrw();

    for (int i = 0; i < count; i++) {
        double target = src[i];
        double current = prev[i];
        double factor = (target > current) ? attack_factor : release_factor;
        double result = current + (target - current) * factor;
        prev[i] = (float)result;
        dst[i] = (float)result;
    }

    return out;
}

void GNNativeLagChop::reset() {
    _prev.resize(0);
}
