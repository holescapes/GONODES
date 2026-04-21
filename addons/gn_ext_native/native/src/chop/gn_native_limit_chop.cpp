#include "gn_native_limit_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <cmath>
namespace godot {
void GNNativeLimitChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "channels", "type", "lo", "hi"), &GNNativeLimitChop::process);
}
Dictionary GNNativeLimitChop::process(const Dictionary &channels, int type, double lo, double hi) {
    Dictionary out;
    Array keys = channels.keys();
    double range = hi - lo;
    if (range <= 0.0) range = 1.0;
    for (int ki = 0; ki < keys.size(); ++ki) {
        String name = keys[ki];
        PackedFloat32Array data = channels[name];
        int count = data.size();
        PackedFloat32Array result;
        result.resize(count);
        const float *ip = data.ptr();
        float *op = result.ptrw();
        for (int i = 0; i < count; ++i) {
            double v = (double)ip[i];
            switch (type) {
                case 0: // Clamp
                    v = CLAMP(v, lo, hi);
                    break;
                case 1: // Loop
                    v = lo + fmod(v - lo, range);
                    if (v < lo) v += range;
                    break;
                case 2: // Zig-Zag
                    v = fmod(v - lo, 2.0 * range);
                    if (v < 0.0) v += 2.0 * range;
                    v = v <= range ? lo + v : hi - (v - range);
                    break;
                default:
                    v = CLAMP(v, lo, hi);
            }
            op[i] = (float)v;
        }
        out[name] = result;
    }
    return out;
}
} // namespace godot
