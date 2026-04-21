#ifndef GN_NATIVE_AUDIO_MIX_CHOP_H
#define GN_NATIVE_AUDIO_MIX_CHOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>
namespace godot {
class GNNativeAudioMixChop : public RefCounted {
    GDCLASS(GNNativeAudioMixChop, RefCounted)
public:
    PackedFloat32Array process(const TypedArray<PackedFloat32Array> &inputs,
                                const PackedFloat32Array &volumes,
                                const PackedFloat32Array &pans,
                                double master_vol);
protected:
    static void _bind_methods();
};
} // namespace godot
#endif
