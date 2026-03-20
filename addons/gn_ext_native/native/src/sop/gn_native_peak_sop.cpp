#include "gn_native_peak_sop.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void GNNativePeakSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "positions", "normals", "distance"), &GNNativePeakSop::process);
}

PackedVector3Array GNNativePeakSop::process(const PackedVector3Array &p_positions,
                                              const PackedVector3Array &p_normals,
                                              double p_distance) const {
    int count = p_positions.size();
    PackedVector3Array out;
    out.resize(count);

    if (count == 0) return out;

    int nrm_count = p_normals.size();
    const Vector3 *pos = p_positions.ptr();
    const Vector3 *nrm = p_normals.ptr();
    Vector3 *dst = out.ptrw();

    for (int i = 0; i < count; i++) {
        if (i < nrm_count) {
            dst[i] = pos[i] + nrm[i] * p_distance;
        } else {
            dst[i] = pos[i];
        }
    }
    return out;
}
