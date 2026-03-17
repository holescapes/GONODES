#include "gn_native_blur_vol.h"

#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeBlurVol::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "field", "res_x", "res_y", "res_z",
                                  "channels", "radius", "passes"),
                         &GNNativeBlurVol::process);
}

PackedFloat32Array GNNativeBlurVol::process(const PackedFloat32Array &field,
                                             int res_x, int res_y, int res_z,
                                             int channels, int radius,
                                             int passes) {
    int total = res_x * res_y * res_z * channels;
    if (total == 0 || field.size() < total) return field;

    PackedFloat32Array src;
    src.resize(total);
    memcpy(src.ptrw(), field.ptr(), sizeof(float) * total);

    PackedFloat32Array dst;
    dst.resize(total);

    for (int p = 0; p < passes; ++p) {
        const float *sp = src.ptr();
        float *dp = dst.ptrw();

        for (int z = 0; z < res_z; ++z) {
            for (int y = 0; y < res_y; ++y) {
                for (int x = 0; x < res_x; ++x) {
                    float sum = 0.0f;
                    int count = 0;
                    for (int dz = -radius; dz <= radius; ++dz) {
                        int sz = z + dz;
                        if (sz < 0 || sz >= res_z) continue;
                        for (int dy = -radius; dy <= radius; ++dy) {
                            int sy = y + dy;
                            if (sy < 0 || sy >= res_y) continue;
                            for (int dx = -radius; dx <= radius; ++dx) {
                                int sx = x + dx;
                                if (sx < 0 || sx >= res_x) continue;
                                int si = (sz * res_y * res_x + sy * res_x + sx) * channels;
                                sum += sp[si];
                                ++count;
                            }
                        }
                    }
                    int di = (z * res_y * res_x + y * res_x + x) * channels;
                    dp[di] = (count > 0) ? sum / (float)count : 0.0f;
                }
            }
        }

        // Swap for next pass
        PackedFloat32Array tmp = src;
        src = dst;
        dst = tmp;
    }

    return src;
}

} // namespace godot
