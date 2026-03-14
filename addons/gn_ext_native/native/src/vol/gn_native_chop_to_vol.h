#ifndef GN_NATIVE_CHOP_TO_VOL_H
#define GN_NATIVE_CHOP_TO_VOL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

/// Encodes CHOP channel data into a 3D float field (R32F byte array).
class GNNativeChopToVol : public RefCounted {
    GDCLASS(GNNativeChopToVol, RefCounted)

protected:
    static void _bind_methods();

public:
    /// mode: 0=slice, 1=stack, 2=map.  Returns PackedByteArray for GPU upload.
    PackedByteArray process(int mode, const Dictionary &channels,
                            const PackedStringArray &ch_names,
                            const String &channel_name,
                            int res_x, int res_y, int res_z);
};

} // namespace godot

#endif
