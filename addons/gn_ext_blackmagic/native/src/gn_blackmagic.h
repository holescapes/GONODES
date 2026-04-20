#ifndef GN_BLACKMAGIC_H
#define GN_BLACKMAGIC_H

// GNBlackmagic — GDExtension wrapper for Blackmagic DeckLink SDK.
//
// Exposes device enumeration, video capture (input), and video output
// to GDScript via ClassDB bindings.
//
// Build dependency: Blackmagic DeckLink SDK headers
//   - Windows: DeckLinkAPI_h.h, DeckLinkAPI_i.c (generated from IDL via MIDL)

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#ifdef GN_BLACKMAGIC_HAS_DECKLINK
#include <DeckLinkAPI_h.h>
#include <atomic>
#include <mutex>
#include <vector>
#include <string>
#endif

namespace godot {

#ifdef GN_BLACKMAGIC_HAS_DECKLINK

// ── Capture Callback ─────────────────────────────────────────────────────────
// Runs on DeckLink's worker thread. Copies each incoming frame into a
// double-buffered RGBA byte array that the main thread reads via get_frame().

class DeckLinkCaptureCallback : public IDeckLinkInputCallback {
public:
    DeckLinkCaptureCallback(int width, int height);
    virtual ~DeckLinkCaptureCallback() = default;

    // IUnknown
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, LPVOID *ppv) override;
    ULONG   STDMETHODCALLTYPE AddRef() override;
    ULONG   STDMETHODCALLTYPE Release() override;

    // IDeckLinkInputCallback
    HRESULT STDMETHODCALLTYPE VideoInputFormatChanged(
        BMDVideoInputFormatChangedEvents events,
        IDeckLinkDisplayMode *mode,
        BMDDetectedVideoInputFormatFlags flags) override;

    HRESULT STDMETHODCALLTYPE VideoInputFrameArrived(
        IDeckLinkVideoInputFrame *video,
        IDeckLinkAudioInputPacket *audio) override;

    // Thread-safe accessors for main thread
    bool    has_new_frame() const { return _new_frame.load(std::memory_order_acquire); }
    void    consume_frame(std::vector<uint8_t> &out, int &w, int &h);
    int     dropped_frames() const { return _dropped.load(std::memory_order_relaxed); }
    void    get_timecode(int &hours, int &minutes, int &seconds, int &frames) const;

private:
    std::atomic<ULONG> _ref_count{1};
    std::atomic<bool>  _new_frame{false};
    std::atomic<int>   _dropped{0};

    std::mutex         _mutex;
    std::vector<uint8_t> _rgba_buffer;
    int _width, _height;

    // Timecode (updated atomically per frame)
    std::atomic<int> _tc_hours{0}, _tc_minutes{0}, _tc_seconds{0}, _tc_frames{0};

    // UYVY → RGBA conversion
    static void uyvy_to_rgba(const uint8_t *src, uint8_t *dst, int width, int height);
};

// ── Output Frame ─────────────────────────────────────────────────────────────
// Custom video frame for scheduled playback output.

class DeckLinkOutputFrame : public IDeckLinkMutableVideoFrame {
public:
    DeckLinkOutputFrame(int width, int height, BMDPixelFormat format);
    virtual ~DeckLinkOutputFrame();

    // IUnknown
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, LPVOID *ppv) override;
    ULONG   STDMETHODCALLTYPE AddRef() override;
    ULONG   STDMETHODCALLTYPE Release() override;

    // IDeckLinkVideoFrame
    long    STDMETHODCALLTYPE GetWidth() override { return _width; }
    long    STDMETHODCALLTYPE GetHeight() override { return _height; }
    long    STDMETHODCALLTYPE GetRowBytes() override { return _row_bytes; }
    BMDPixelFormat STDMETHODCALLTYPE GetPixelFormat() override { return _format; }
    BMDFrameFlags  STDMETHODCALLTYPE GetFlags() override { return bmdFrameFlagDefault; }
    HRESULT STDMETHODCALLTYPE GetBytes(void **buffer) override;
    HRESULT STDMETHODCALLTYPE GetTimecode(BMDTimecodeFormat, IDeckLinkTimecode **) override { return S_FALSE; }
    HRESULT STDMETHODCALLTYPE GetAncillaryData(IDeckLinkVideoFrameAncillary **) override { return S_FALSE; }

    // IDeckLinkMutableVideoFrame
    HRESULT STDMETHODCALLTYPE SetFlags(BMDFrameFlags) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE SetTimecode(BMDTimecodeFormat, IDeckLinkTimecode *) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE SetTimecodeFromComponents(BMDTimecodeFormat, uint8_t, uint8_t, uint8_t, uint8_t, BMDTimecodeFlags) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE SetAncillaryData(IDeckLinkVideoFrameAncillary *) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE SetTimecodeUserBits(BMDTimecodeFormat, BMDTimecodeUserBits) override { return S_OK; }

    void write_uyvy_from_rgba(const uint8_t *rgba_data, int rgba_width, int rgba_height);

private:
    std::atomic<ULONG> _ref_count{1};
    int _width, _height, _row_bytes;
    BMDPixelFormat _format;
    std::vector<uint8_t> _frame_data;
};

#endif // GN_BLACKMAGIC_HAS_DECKLINK

// ── Godot-Facing Class ───────────────────────────────────────────────────────

class GNBlackmagic : public Node {
    GDCLASS(GNBlackmagic, Node)

public:
    // Device Enumeration
    int get_device_count() const;
    PackedStringArray get_device_names() const;
    Dictionary get_device_info(int device_index) const;

    // Input (Capture)
    bool open_input(int device_index, int width, int height, float fps);
    void close_input();
    bool has_new_frame() const;
    Ref<Image> get_frame() const;
    PackedByteArray get_frame_bytes() const;

    // Output (Playback)
    bool open_output(int device_index, int width, int height, float fps);
    void close_output();
    void send_frame(const Ref<Image> &p_image);
    void send_frame_bytes(const PackedByteArray &p_bytes, int width, int height);

    // Status
    bool is_input_active() const;
    bool is_output_active() const;
    int  get_dropped_frames() const;

    // Timecode
    Dictionary get_timecode() const;

    GNBlackmagic();
    ~GNBlackmagic();

protected:
    static void _bind_methods();

private:
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    // Cached device list (populated by _enumerate_devices)
    struct DeviceEntry {
        IDeckLink *device = nullptr;
        std::wstring display_name;
        bool supports_input = false;
        bool supports_output = false;
    };
    mutable std::vector<DeviceEntry> _devices;
    mutable bool _devices_enumerated = false;
    void _enumerate_devices() const;
    void _release_devices();
    BMDDisplayMode _find_display_mode(IDeckLinkInput *input, int width, int height, float fps) const;
    BMDDisplayMode _find_output_display_mode(IDeckLinkOutput *output, int width, int height, float fps) const;

    // Input state
    IDeckLinkInput *_input = nullptr;
    DeckLinkCaptureCallback *_capture_cb = nullptr;
    int _input_width = 0, _input_height = 0;

    // Output state
    IDeckLinkOutput *_output = nullptr;
    DeckLinkOutputFrame *_out_frame = nullptr;
    int _output_width = 0, _output_height = 0;
    BMDTimeValue _out_frame_duration = 0;
    BMDTimeScale _out_time_scale = 0;
    int64_t _out_frame_count = 0;
#endif

    bool _input_active = false;
    bool _output_active = false;
};

} // namespace godot

#endif // GN_BLACKMAGIC_H
