#include "gn_native_logic_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
namespace godot {
void GNNativeLogicChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "a", "b", "operation", "threshold"), &GNNativeLogicChop::process);
}
Dictionary GNNativeLogicChop::process(const Dictionary &a, const Dictionary &b,
                                       int operation, double threshold) {
    Dictionary out;
    Array keys = a.keys();
    for (int ki = 0; ki < keys.size(); ++ki) {
        String name = keys[ki];
        PackedFloat32Array da = a[name];
        PackedFloat32Array db = b.has(name) ? (PackedFloat32Array)b[name] : PackedFloat32Array();
        int count = da.size();
        PackedFloat32Array result;
        result.resize(count);
        const float *ap = da.ptr();
        const float *bp = db.ptr();
        int bs = db.size();
        float *rp = result.ptrw();
        float th = (float)threshold;
        for (int i = 0; i < count; ++i) {
            bool va = ap[i] >= th;
            bool vb = (i < bs) ? bp[i] >= th : false;
            bool r;
            switch (operation) {
                case 0: r = va && vb; break;     // AND
                case 1: r = va || vb; break;     // OR
                case 2: r = va != vb; break;     // XOR
                case 3: r = !(va && vb); break;  // NAND
                case 4: r = !(va || vb); break;  // NOR
                case 5: r = !va; break;           // NOT
                default: r = va;
            }
            rp[i] = r ? 1.0f : 0.0f;
        }
        out[name] = result;
    }
    return out;
}
} // namespace godot
