#include "gn_native_analyze_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <cmath>
namespace godot {
void GNNativeAnalyzeChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "channels", "function"), &GNNativeAnalyzeChop::process);
}
Dictionary GNNativeAnalyzeChop::process(const Dictionary &channels, int function) {
    Dictionary out;
    Array keys = channels.keys();
    for (int ki = 0; ki < keys.size(); ++ki) {
        String name = keys[ki];
        PackedFloat32Array data = channels[name];
        int count = data.size();
        if (count == 0) { PackedFloat32Array r; r.push_back(0.0f); out[name] = r; continue; }
        const float *p = data.ptr();
        double result = 0.0;
        switch (function) {
            case 0: { // Average
                for (int i = 0; i < count; ++i) result += (double)p[i];
                result /= (double)count;
            } break;
            case 1: { // Min
                result = (double)p[0];
                for (int i = 1; i < count; ++i) result = MIN(result, (double)p[i]);
            } break;
            case 2: { // Max
                result = (double)p[0];
                for (int i = 1; i < count; ++i) result = MAX(result, (double)p[i]);
            } break;
            case 3: { // Sum
                for (int i = 0; i < count; ++i) result += (double)p[i];
            } break;
            case 4: { // RMS
                for (int i = 0; i < count; ++i) result += (double)p[i] * (double)p[i];
                result = sqrt(result / (double)count);
            } break;
            case 5: { // Range
                double mn = (double)p[0], mx = (double)p[0];
                for (int i = 1; i < count; ++i) { mn = MIN(mn, (double)p[i]); mx = MAX(mx, (double)p[i]); }
                result = mx - mn;
            } break;
            case 6: result = (double)count; break; // Count
        }
        PackedFloat32Array r;
        r.push_back((float)result);
        out[name] = r;
    }
    return out;
}
} // namespace godot
