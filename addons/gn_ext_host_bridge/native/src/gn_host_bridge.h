/*
 * gn_host_bridge.h — GDExtension class bridging libgonodes ↔ GNEmbeddedHost.
 *
 * Replaces the per-frame env-var IPC layer.  All methods are static and
 * use direct pointer access to the gonodes_instance_s command queue and
 * per-patch response slots.
 *
 * Two directions:
 *   INBOUND:  drain_commands()    — reads C command queue → GDScript Array
 *   OUTBOUND: set_*_output()      — writes GDScript data → C response slots
 *
 * All access is single-threaded: GDScript runs synchronously inside
 * gn_bootstrap_iteration(), so no locking is needed.
 */

#ifndef GN_HOST_BRIDGE_H
#define GN_HOST_BRIDGE_H

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class GNHostBridge : public Object {
    GDCLASS(GNHostBridge, Object)

protected:
    static void _bind_methods();

public:
    // ── Instance Registration ──────────────────────────────────────────
    /// Set the gonodes_instance_s pointer.  Called once by GNEmbeddedHost
    /// during _ready(), after reading the one-time init env var.
    static void set_instance(int64_t address);

    // ── Inbound: Command Queue → GDScript ──────────────────────────────
    /// Drain all pending commands from the C ring buffer.
    /// Returns an Array of Dictionaries, each with:
    ///   type: int, patch_id: int, key: String, key2: String,
    ///   data: String, ival: Array[int], dval: float, uval: int
    static Array drain_commands();

    // ── Outbound: GDScript → Response Slots ────────────────────────────

    /// Set texture output for a node in a patch.
    static void set_tex_output(int patch_id, const String& node_id,
                               int64_t handle, int width, int height,
                               int format, int channels, int graphics_api);

    /// Set CHOP output (one channel) for a node in a patch.
    static void set_chop_output(int patch_id, const String& node_id,
                                const String& channel_name,
                                const PackedFloat32Array& samples);

    /// Set DAT output (JSON string) for a node in a patch.
    static void set_dat_output(int patch_id, const String& node_id,
                               const String& json_data);

    /// Set parameter value output for a node in a patch.
    static void set_param_output(int patch_id, const String& node_id,
                                 const String& param_name,
                                 const String& value_json);

    /// Set introspection: list of all nodes (JSON).
    static void set_nodes_json(int patch_id, const String& json);

    /// Set introspection: list of all connections (JSON).
    static void set_connections_json(int patch_id, const String& json);

    /// Set introspection: node info (JSON).
    static void set_node_info_json(int patch_id, const String& node_id,
                                   const String& json);

    /// Set introspection: parameters list (JSON).
    static void set_params_json(int patch_id, const String& node_id,
                                const String& json);

    /// Set host I/O manifest (JSON).
    static void set_host_io_json(int patch_id, const String& json);

    /// Set cook stats for a patch.
    static void set_stats(int patch_id, double cook_ms, int node_count);

    /// Set transport time for a patch.
    static void set_transport_time(int patch_id, double time);

    // ── Readback: write output data for C-side consumption ─────────────

    /// Write pixel readback data into the patch's readback slot.
    static void write_pixel_readback(int patch_id, const PackedByteArray& data,
                                     int width, int height);

    /// Write geometry readback data into the patch's geometry cache.
    static void write_geometry_readback(int patch_id,
                                        const PackedVector3Array& positions,
                                        const PackedVector3Array& normals,
                                        const PackedVector2Array& uvs,
                                        const PackedColorArray& colors,
                                        const PackedInt32Array& indices,
                                        int primitive_type);

    // ── Generic Read Helpers (unchanged from v2.0) ─────────────────────
    static PackedByteArray read_bytes(int64_t address, int64_t size);
    static PackedFloat32Array read_float32(int64_t address, int64_t count);
    static PackedInt32Array read_int32(int64_t address, int64_t count);
    static Ref<Image> read_image(int64_t address, int64_t width,
                                 int64_t height, int64_t format);
    static PackedVector3Array read_vector3(int64_t address, int64_t count);
    static PackedVector2Array read_vector2(int64_t address, int64_t count);
    static PackedColorArray read_color(int64_t address, int64_t count);
};

} // namespace godot

#endif // GN_HOST_BRIDGE_H
