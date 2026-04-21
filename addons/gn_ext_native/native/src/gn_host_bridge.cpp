#include "gn_host_bridge.h"
#include <cstring>

namespace godot {

void GNHostBridge::_bind_methods() {
    ClassDB::bind_static_method("GNHostBridge",
        D_METHOD("read_bytes", "address", "size"), &GNHostBridge::read_bytes);
    ClassDB::bind_static_method("GNHostBridge",
        D_METHOD("read_float32", "address", "count"), &GNHostBridge::read_float32);
    ClassDB::bind_static_method("GNHostBridge",
        D_METHOD("read_int32", "address", "count"), &GNHostBridge::read_int32);
    ClassDB::bind_static_method("GNHostBridge",
        D_METHOD("read_image", "address", "width", "height", "format"), &GNHostBridge::read_image);
    ClassDB::bind_static_method("GNHostBridge",
        D_METHOD("read_vector3", "address", "count"), &GNHostBridge::read_vector3);
    ClassDB::bind_static_method("GNHostBridge",
        D_METHOD("read_vector2", "address", "count"), &GNHostBridge::read_vector2);
    ClassDB::bind_static_method("GNHostBridge",
        D_METHOD("read_color", "address", "count"), &GNHostBridge::read_color);
}

// ── Generic ────────────────────────────────────────────────────────────────

PackedByteArray GNHostBridge::read_bytes(int64_t address, int64_t size) {
    PackedByteArray result;
    if (address == 0 || size <= 0) return result;
    result.resize(static_cast<int>(size));
    std::memcpy(result.ptrw(),
                reinterpret_cast<const void*>(static_cast<uintptr_t>(address)),
                static_cast<size_t>(size));
    return result;
}

PackedFloat32Array GNHostBridge::read_float32(int64_t address, int64_t count) {
    PackedFloat32Array result;
    if (address == 0 || count <= 0) return result;
    result.resize(static_cast<int>(count));
    std::memcpy(result.ptrw(),
                reinterpret_cast<const void*>(static_cast<uintptr_t>(address)),
                static_cast<size_t>(count) * sizeof(float));
    return result;
}

PackedInt32Array GNHostBridge::read_int32(int64_t address, int64_t count) {
    PackedInt32Array result;
    if (address == 0 || count <= 0) return result;
    result.resize(static_cast<int>(count));
    std::memcpy(result.ptrw(),
                reinterpret_cast<const void*>(static_cast<uintptr_t>(address)),
                static_cast<size_t>(count) * sizeof(int32_t));
    return result;
}

// ── IMG ────────────────────────────────────────────────────────────────────

Ref<Image> GNHostBridge::read_image(int64_t address, int64_t width, int64_t height, int64_t format) {
    if (address == 0 || width <= 0 || height <= 0) return Ref<Image>();

    // Compute byte size from Godot Image format.
    Image::Format fmt = static_cast<Image::Format>(format);
    // Create a temporary image to query the data size for this format.
    Ref<Image> tmp = Image::create(static_cast<int>(width), static_cast<int>(height), false, fmt);
    if (tmp.is_null()) return Ref<Image>();
    int64_t byte_size = tmp->get_data().size();
    if (byte_size <= 0) return Ref<Image>();

    PackedByteArray data;
    data.resize(static_cast<int>(byte_size));
    std::memcpy(data.ptrw(),
                reinterpret_cast<const void*>(static_cast<uintptr_t>(address)),
                static_cast<size_t>(byte_size));

    return Image::create_from_data(static_cast<int>(width), static_cast<int>(height),
                                   false, fmt, data);
}

// ── SOP / POP geometry ─────────────────────────────────────────────────────

PackedVector3Array GNHostBridge::read_vector3(int64_t address, int64_t count) {
    PackedVector3Array result;
    if (address == 0 || count <= 0) return result;
    result.resize(static_cast<int>(count));
    // Vector3 is 3 floats = 12 bytes, same layout as float[3] per element.
    std::memcpy(result.ptrw(),
                reinterpret_cast<const void*>(static_cast<uintptr_t>(address)),
                static_cast<size_t>(count) * sizeof(float) * 3);
    return result;
}

PackedVector2Array GNHostBridge::read_vector2(int64_t address, int64_t count) {
    PackedVector2Array result;
    if (address == 0 || count <= 0) return result;
    result.resize(static_cast<int>(count));
    std::memcpy(result.ptrw(),
                reinterpret_cast<const void*>(static_cast<uintptr_t>(address)),
                static_cast<size_t>(count) * sizeof(float) * 2);
    return result;
}

PackedColorArray GNHostBridge::read_color(int64_t address, int64_t count) {
    PackedColorArray result;
    if (address == 0 || count <= 0) return result;
    result.resize(static_cast<int>(count));
    // Godot Color is 4 floats (r,g,b,a) = 16 bytes, same layout as float[4].
    std::memcpy(result.ptrw(),
                reinterpret_cast<const void*>(static_cast<uintptr_t>(address)),
                static_cast<size_t>(count) * sizeof(float) * 4);
    return result;
}

} // namespace godot
