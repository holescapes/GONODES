#ifndef GN_BLACKMAGIC_H
#define GN_BLACKMAGIC_H

// GNBlackmagic — GDExtension wrapper for Blackmagic DeckLink SDK.
//
// Exposes device enumeration, video capture (input), and video output
// to GDScript via ClassDB bindings.
//
// Build dependency: Blackmagic DeckLink SDK headers
//   - Windows: DeckLinkAPI_h.h, DeckLinkAPI_i.c
//   - Linux:   DeckLinkAPI.h, DeckLinkAPIDispatch.cpp
//
// This is a SCAFFOLD — method bodies are stubs that need DeckLink
// SDK implementation.

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class GNBlackmagic : public Node {
    GDCLASS(GNBlackmagic, Node)

public:
    // ─── Device Enumeration ───────────────────────────────────────────

    /// Returns the number of DeckLink devices detected.
    int get_device_count() const;

    /// Returns an array of device display names.
    PackedStringArray get_device_names() const;

    /// Returns device info dict: { "name", "model", "supports_input",
    /// "supports_output", "max_width", "max_height" }
    Dictionary get_device_info(int device_index) const;

    // ─── Input (Capture) ──────────────────────────────────────────────

    /// Opens the input stream on the given device at the specified
    /// resolution and frame rate.  Returns true on success.
    bool open_input(int device_index, int width, int height, float fps);

    /// Closes the input stream.
    void close_input();

    /// Returns true if a new frame is available since last call.
    bool has_new_frame() const;

    /// Returns the latest captured frame as an RGBA8 Image.
    /// The DeckLink callback converts UYVY → RGBA on a worker thread.
    Ref<Image> get_frame() const;

    /// Returns the captured frame as raw RGBA bytes.
    PackedByteArray get_frame_bytes() const;

    // ─── Output (Playback) ────────────────────────────────────────────

    /// Opens the output stream on the given device.
    bool open_output(int device_index, int width, int height, float fps);

    /// Closes the output stream.
    void close_output();

    /// Sends an RGBA8 Image to the output device (converted to UYVY).
    void send_frame(const Ref<Image> &p_image);

    /// Sends raw RGBA bytes to the output device.
    void send_frame_bytes(const PackedByteArray &p_bytes, int width, int height);

    // ─── Status ───────────────────────────────────────────────────────

    /// Returns true if input is currently capturing.
    bool is_input_active() const;

    /// Returns true if output is currently playing.
    bool is_output_active() const;

    /// Returns dropped frame count since last open_input().
    int get_dropped_frames() const;

protected:
    static void _bind_methods();

private:
    // DeckLink COM/interface pointers would go here.
    // Stub fields:
    bool _input_active = false;
    bool _output_active = false;
    int  _dropped_frames = 0;
};

} // namespace godot

#endif // GN_BLACKMAGIC_H
