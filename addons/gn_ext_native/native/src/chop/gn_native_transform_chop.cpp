#include "gn_native_transform_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

using namespace godot;

void GNNativeTransformChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "data", "num_samples",
                                   "tx", "ty", "tz",
                                   "rx", "ry", "rz",
                                   "sx", "sy", "sz"), &GNNativeTransformChop::process);
}

PackedFloat32Array GNNativeTransformChop::process(const PackedFloat32Array &p_data,
                                                    int p_num_samples,
                                                    double p_tx, double p_ty, double p_tz,
                                                    double p_rx, double p_ry, double p_rz,
                                                    double p_sx, double p_sy, double p_sz) const {
    // Data layout: 3 channels × num_samples, stored [ch0_s0..ch0_sN, ch1_s0..ch1_sN, ch2_s0..ch2_sN]
    int total = p_data.size();
    PackedFloat32Array out;
    out.resize(total);

    if (total == 0 || p_num_samples <= 0) return out;
    if (total < p_num_samples * 3) {
        memcpy(out.ptrw(), p_data.ptr(), total * sizeof(float));
        return out;
    }

    // Precompute rotation matrix (Euler XYZ)
    double cx = std::cos(p_rx * Math_PI / 180.0), sx = std::sin(p_rx * Math_PI / 180.0);
    double cy = std::cos(p_ry * Math_PI / 180.0), sy = std::sin(p_ry * Math_PI / 180.0);
    double cz = std::cos(p_rz * Math_PI / 180.0), sz = std::sin(p_rz * Math_PI / 180.0);

    // Combined rotation matrix R = Rz * Ry * Rx
    double r00 = cy * cz;
    double r01 = sx * sy * cz - cx * sz;
    double r02 = cx * sy * cz + sx * sz;
    double r10 = cy * sz;
    double r11 = sx * sy * sz + cx * cz;
    double r12 = cx * sy * sz - sx * cz;
    double r20 = -sy;
    double r21 = sx * cy;
    double r22 = cx * cy;

    const float *src = p_data.ptr();
    float *dst = out.ptrw();
    int ns = p_num_samples;

    for (int i = 0; i < ns; i++) {
        double x = src[i];
        double y = src[ns + i];
        double z = src[2 * ns + i];

        // Scale
        x *= p_sx;
        y *= p_sy;
        z *= p_sz;

        // Rotate
        double rx = r00 * x + r01 * y + r02 * z;
        double ry = r10 * x + r11 * y + r12 * z;
        double rz_val = r20 * x + r21 * y + r22 * z;

        // Translate
        dst[i] = (float)(rx + p_tx);
        dst[ns + i] = (float)(ry + p_ty);
        dst[2 * ns + i] = (float)(rz_val + p_tz);
    }

    // Copy remaining channels verbatim (if any beyond xyz)
    if (total > 3 * ns) {
        memcpy(dst + 3 * ns, src + 3 * ns, (total - 3 * ns) * sizeof(float));
    }

    return out;
}
