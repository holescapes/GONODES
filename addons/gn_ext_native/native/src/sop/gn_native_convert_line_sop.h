#ifndef GN_NATIVE_CONVERT_LINE_SOP_H
#define GN_NATIVE_CONVERT_LINE_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
namespace godot {
class GNNativeConvertLineSop : public RefCounted {
    GDCLASS(GNNativeConvertLineSop, RefCounted)
public:
    // mode: 0=polyline, 1=bezier(Catmull-Rom), 2=subdivision(Chaikin)
    PackedVector3Array process(const PackedVector3Array &points, int mode,
                                int segments, double tension, bool closed);
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
