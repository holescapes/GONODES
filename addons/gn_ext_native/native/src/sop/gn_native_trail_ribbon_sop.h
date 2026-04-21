#ifndef GN_NATIVE_TRAIL_RIBBON_SOP_H
#define GN_NATIVE_TRAIL_RIBBON_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <vector>
namespace godot {
class GNNativeTrailRibbonSop : public RefCounted {
    GDCLASS(GNNativeTrailRibbonSop, RefCounted)
    std::vector<Vector3> _history;
    int _max_frames = 60;
public:
    // Adds a new position to the trail and returns ribbon mesh
    Dictionary process(const Vector3 &current_pos, double width, int max_frames,
                       const Vector3 &up_vector);
    void reset();
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
