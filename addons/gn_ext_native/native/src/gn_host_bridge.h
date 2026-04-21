#ifndef GN_HOST_BRIDGE_H
#define GN_HOST_BRIDGE_H

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

namespace godot {

/// Bridge for reading raw memory staged by the libgonodes C API.
///
/// Used by GNEmbeddedHost to read CPU data (IMG pixels, SOP geometry,
/// VOL voxels, POP particles, CHOP samples) that the host app passed
/// as pointers.  Pointer validity is guaranteed by the synchronous
/// gn_bootstrap_iteration() — GDScript runs inside the blocking call.
///
/// Each method does exactly ONE memcpy from the source pointer into
/// the returned Godot type.  No temp files, no double copies.
class GNHostBridge : public Object {
    GDCLASS(GNHostBridge, Object)

protected:
    static void _bind_methods();

public:
    // ── Generic ────────────────────────────────────────────────────────
    static PackedByteArray read_bytes(int64_t address, int64_t size);
    static PackedFloat32Array read_float32(int64_t address, int64_t count);
    static PackedInt32Array read_int32(int64_t address, int64_t count);

    // ── IMG (CPU images) ───────────────────────────────────────────────
    /// Reads width*height pixels from `address` and returns a Godot Image.
    /// `format` maps to Image::Format (e.g. FORMAT_RGBA8 = 5).
    static Ref<Image> read_image(int64_t address, int64_t width, int64_t height, int64_t format);

    // ── SOP (geometry) ─────────────────────────────────────────────────
    /// Reads `count` Vector3 values (3 floats each) from `address`.
    static PackedVector3Array read_vector3(int64_t address, int64_t count);

    /// Reads `count` Vector2 values (2 floats each) from `address`.
    static PackedVector2Array read_vector2(int64_t address, int64_t count);

    // ── POP (particles) ────────────────────────────────────────────────
    /// Reads `count` Color values (4 floats each) from `address`.
    static PackedColorArray read_color(int64_t address, int64_t count);
};

} // namespace godot

#endif // GN_HOST_BRIDGE_H
