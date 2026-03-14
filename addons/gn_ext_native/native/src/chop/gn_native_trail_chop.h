#ifndef GN_NATIVE_TRAIL_CHOP_H
#define GN_NATIVE_TRAIL_CHOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

/// Ring-buffer trail recorder for CHOP channels.
/// Records N frames of input values into a scrolling buffer.
class GNNativeTrailChop : public RefCounted {
    GDCLASS(GNNativeTrailChop, RefCounted)

protected:
    static void _bind_methods();

public:
    /// Push new samples and return the full trail buffer per channel.
    Dictionary process(const Dictionary &channels, int trail_length);
    void reset();

private:
    HashMap<String, PackedFloat32Array> _buffers;
    HashMap<String, int> _write_pos;
    int _current_length = 0;
};

} // namespace godot

#endif // GN_NATIVE_TRAIL_CHOP_H
