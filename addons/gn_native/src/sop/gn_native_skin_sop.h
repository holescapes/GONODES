#ifndef GN_NATIVE_SKIN_SOP_H
#define GN_NATIVE_SKIN_SOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
namespace godot {
/// Skins together cross-section curves into a connected surface.
/// Similar to PolyLoft but with additional UV and normal handling.
class GNNativeSkinSop : public RefCounted {
    GDCLASS(GNNativeSkinSop, RefCounted)
protected:
    static void _bind_methods();
public:
    Dictionary process(const Array &cross_sections, bool close_u, bool close_v);
};
} // namespace godot
#endif
