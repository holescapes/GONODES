#include "gn_blackmagic.h"
#include <godot_cpp/core/class_db.hpp>

// ====================================================================
// GNBlackmagic — stub implementation for DeckLink SDK integration.
//
// All methods compile and bind cleanly. Each returns a safe default
// until the DeckLink SDK headers/libs are available and the internal
// COM/interface wiring is completed.
//
// Build with GN_BLACKMAGIC_HAS_DECKLINK to enable real SDK calls.
// ====================================================================

using namespace godot;

void GNBlackmagic::_bind_methods() {
    // Device enumeration
    ClassDB::bind_method(D_METHOD("get_device_count"), &GNBlackmagic::get_device_count);
    ClassDB::bind_method(D_METHOD("get_device_names"), &GNBlackmagic::get_device_names);
    ClassDB::bind_method(D_METHOD("get_device_info", "device_index"), &GNBlackmagic::get_device_info);

    // Input (Capture)
    ClassDB::bind_method(D_METHOD("open_input", "device_index", "width", "height", "fps"), &GNBlackmagic::open_input);
    ClassDB::bind_method(D_METHOD("close_input"), &GNBlackmagic::close_input);
    ClassDB::bind_method(D_METHOD("has_new_frame"), &GNBlackmagic::has_new_frame);
    ClassDB::bind_method(D_METHOD("get_frame"), &GNBlackmagic::get_frame);
    ClassDB::bind_method(D_METHOD("get_frame_bytes"), &GNBlackmagic::get_frame_bytes);

    // Output (Playback)
    ClassDB::bind_method(D_METHOD("open_output", "device_index", "width", "height", "fps"), &GNBlackmagic::open_output);
    ClassDB::bind_method(D_METHOD("close_output"), &GNBlackmagic::close_output);
    ClassDB::bind_method(D_METHOD("send_frame", "image"), &GNBlackmagic::send_frame);
    ClassDB::bind_method(D_METHOD("send_frame_bytes", "bytes", "width", "height"), &GNBlackmagic::send_frame_bytes);

    // Status
    ClassDB::bind_method(D_METHOD("is_input_active"), &GNBlackmagic::is_input_active);
    ClassDB::bind_method(D_METHOD("is_output_active"), &GNBlackmagic::is_output_active);
    ClassDB::bind_method(D_METHOD("get_dropped_frames"), &GNBlackmagic::get_dropped_frames);
}

// ─── Device Enumeration ──────────────────────────────────────────────

int GNBlackmagic::get_device_count() const {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    // TODO: Enumerate via IDeckLinkIterator
#endif
    return 0;
}

PackedStringArray GNBlackmagic::get_device_names() const {
    PackedStringArray names;
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    // TODO: Iterate IDeckLink instances, query display name
#endif
    return names;
}

Dictionary GNBlackmagic::get_device_info(int device_index) const {
    Dictionary info;
    info["name"] = "";
    info["model"] = "";
    info["supports_input"] = false;
    info["supports_output"] = false;
    info["max_width"] = 0;
    info["max_height"] = 0;
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    // TODO: Query IDeckLinkAttributes for capabilities
#endif
    return info;
}

// ─── Input (Capture) ─────────────────────────────────────────────────

bool GNBlackmagic::open_input(int device_index, int width, int height, float fps) {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    // TODO: Create IDeckLinkInput, set callback, enable video input
#endif
    _input_active = false;
    return _input_active;
}

void GNBlackmagic::close_input() {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    // TODO: Stop streams, release IDeckLinkInput
#endif
    _input_active = false;
    _dropped_frames = 0;
}

bool GNBlackmagic::has_new_frame() const {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    // TODO: Check atomic flag set by capture callback
#endif
    return false;
}

Ref<Image> GNBlackmagic::get_frame() const {
    Ref<Image> img;
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    // TODO: Lock frame buffer, convert UYVY→RGBA, create Image
#endif
    return img;
}

PackedByteArray GNBlackmagic::get_frame_bytes() const {
    PackedByteArray bytes;
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    // TODO: Return raw RGBA bytes from latest captured frame
#endif
    return bytes;
}

// ─── Output (Playback) ──────────────────────────────────────────────

bool GNBlackmagic::open_output(int device_index, int width, int height, float fps) {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    // TODO: Create IDeckLinkOutput, enable video output, start scheduled playback
#endif
    _output_active = false;
    return _output_active;
}

void GNBlackmagic::close_output() {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    // TODO: Stop scheduled playback, release IDeckLinkOutput
#endif
    _output_active = false;
}

void GNBlackmagic::send_frame(const Ref<Image> &p_image) {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    // TODO: Convert image RGBA→UYVY, schedule output frame
#endif
}

void GNBlackmagic::send_frame_bytes(const PackedByteArray &p_bytes, int width, int height) {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    // TODO: Validate buffer size (width*height*4), convert RGBA→UYVY, schedule
#endif
}

// ─── Status ──────────────────────────────────────────────────────────

bool GNBlackmagic::is_input_active() const {
    return _input_active;
}

bool GNBlackmagic::is_output_active() const {
    return _output_active;
}

int GNBlackmagic::get_dropped_frames() const {
    return _dropped_frames;
}
