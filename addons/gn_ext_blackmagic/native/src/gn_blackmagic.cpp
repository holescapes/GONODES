#include "gn_blackmagic.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#ifdef GN_BLACKMAGIC_HAS_DECKLINK
#include <combaseapi.h>
#include <algorithm>
#include <cstring>
#endif

using namespace godot;

// ════════════════════════════════════════════════════════════════════════
// Bind methods
// ════════════════════════════════════════════════════════════════════════

void GNBlackmagic::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_device_count"), &GNBlackmagic::get_device_count);
    ClassDB::bind_method(D_METHOD("get_device_names"), &GNBlackmagic::get_device_names);
    ClassDB::bind_method(D_METHOD("get_device_info", "device_index"), &GNBlackmagic::get_device_info);

    ClassDB::bind_method(D_METHOD("open_input", "device_index", "width", "height", "fps"), &GNBlackmagic::open_input);
    ClassDB::bind_method(D_METHOD("close_input"), &GNBlackmagic::close_input);
    ClassDB::bind_method(D_METHOD("has_new_frame"), &GNBlackmagic::has_new_frame);
    ClassDB::bind_method(D_METHOD("get_frame"), &GNBlackmagic::get_frame);
    ClassDB::bind_method(D_METHOD("get_frame_bytes"), &GNBlackmagic::get_frame_bytes);

    ClassDB::bind_method(D_METHOD("open_output", "device_index", "width", "height", "fps"), &GNBlackmagic::open_output);
    ClassDB::bind_method(D_METHOD("close_output"), &GNBlackmagic::close_output);
    ClassDB::bind_method(D_METHOD("send_frame", "image"), &GNBlackmagic::send_frame);
    ClassDB::bind_method(D_METHOD("send_frame_bytes", "bytes", "width", "height"), &GNBlackmagic::send_frame_bytes);

    ClassDB::bind_method(D_METHOD("is_input_active"), &GNBlackmagic::is_input_active);
    ClassDB::bind_method(D_METHOD("is_output_active"), &GNBlackmagic::is_output_active);
    ClassDB::bind_method(D_METHOD("get_dropped_frames"), &GNBlackmagic::get_dropped_frames);
    ClassDB::bind_method(D_METHOD("get_timecode"), &GNBlackmagic::get_timecode);
}

// ════════════════════════════════════════════════════════════════════════
// Constructor / Destructor
// ════════════════════════════════════════════════════════════════════════

GNBlackmagic::GNBlackmagic() {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);
#endif
}

GNBlackmagic::~GNBlackmagic() {
    close_input();
    close_output();
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    _release_devices();
    CoUninitialize();
#endif
}

// ════════════════════════════════════════════════════════════════════════
// DeckLink SDK Implementation
// ════════════════════════════════════════════════════════════════════════

#ifdef GN_BLACKMAGIC_HAS_DECKLINK

// ── DeckLinkCaptureCallback ──────────────────────────────────────────

DeckLinkCaptureCallback::DeckLinkCaptureCallback(int width, int height)
    : _width(width), _height(height) {
    _rgba_buffer.resize(static_cast<size_t>(width) * height * 4);
}

HRESULT STDMETHODCALLTYPE DeckLinkCaptureCallback::QueryInterface(REFIID iid, LPVOID *ppv) {
    if (!ppv) return E_POINTER;
    if (iid == IID_IUnknown || iid == IID_IDeckLinkInputCallback) {
        *ppv = static_cast<IDeckLinkInputCallback *>(this);
        AddRef();
        return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
}

ULONG STDMETHODCALLTYPE DeckLinkCaptureCallback::AddRef() {
    return _ref_count.fetch_add(1, std::memory_order_relaxed) + 1;
}

ULONG STDMETHODCALLTYPE DeckLinkCaptureCallback::Release() {
    ULONG count = _ref_count.fetch_sub(1, std::memory_order_acq_rel) - 1;
    if (count == 0) delete this;
    return count;
}

HRESULT STDMETHODCALLTYPE DeckLinkCaptureCallback::VideoInputFormatChanged(
    BMDVideoInputFormatChangedEvents, IDeckLinkDisplayMode *, BMDDetectedVideoInputFormatFlags) {
    // Auto-detect not implemented; we use fixed format from open_input.
    return S_OK;
}

HRESULT STDMETHODCALLTYPE DeckLinkCaptureCallback::VideoInputFrameArrived(
    IDeckLinkVideoInputFrame *video, IDeckLinkAudioInputPacket *) {

    if (!video) return S_OK;

    if (video->GetFlags() & bmdFrameHasNoInputSource) {
        _dropped.fetch_add(1, std::memory_order_relaxed);
        return S_OK;
    }

    // DeckLink SDK 14+: GetBytes moved to IDeckLinkVideoBuffer interface
    IDeckLinkVideoBuffer *vbuf = nullptr;
    if (FAILED(video->QueryInterface(IID_IDeckLinkVideoBuffer, reinterpret_cast<void **>(&vbuf))) || !vbuf)
        return S_OK;
    void *raw = nullptr;
    HRESULT gbhr = vbuf->GetBytes(&raw);
    vbuf->Release();
    if (FAILED(gbhr) || !raw) return S_OK;

    int fw = static_cast<int>(video->GetWidth());
    int fh = static_cast<int>(video->GetHeight());

    // Extract timecode if available
    IDeckLinkTimecode *tc = nullptr;
    if (SUCCEEDED(video->GetTimecode(bmdTimecodeRP188Any, &tc)) && tc) {
        uint8_t h, m, s, f;
        tc->GetComponents(&h, &m, &s, &f);
        _tc_hours.store(h, std::memory_order_relaxed);
        _tc_minutes.store(m, std::memory_order_relaxed);
        _tc_seconds.store(s, std::memory_order_relaxed);
        _tc_frames.store(f, std::memory_order_relaxed);
        tc->Release();
    }

    // Convert UYVY to RGBA under lock
    {
        std::lock_guard<std::mutex> lock(_mutex);
        if (fw != _width || fh != _height) {
            _width = fw;
            _height = fh;
            _rgba_buffer.resize(static_cast<size_t>(fw) * fh * 4);
        }
        uyvy_to_rgba(static_cast<const uint8_t *>(raw), _rgba_buffer.data(), _width, _height);
    }
    _new_frame.store(true, std::memory_order_release);

    return S_OK;
}

void DeckLinkCaptureCallback::consume_frame(std::vector<uint8_t> &out, int &w, int &h) {
    std::lock_guard<std::mutex> lock(_mutex);
    w = _width;
    h = _height;
    out = _rgba_buffer; // copy under lock
    _new_frame.store(false, std::memory_order_release);
}

void DeckLinkCaptureCallback::get_timecode(int &hours, int &minutes, int &seconds, int &frames) const {
    hours   = _tc_hours.load(std::memory_order_relaxed);
    minutes = _tc_minutes.load(std::memory_order_relaxed);
    seconds = _tc_seconds.load(std::memory_order_relaxed);
    frames  = _tc_frames.load(std::memory_order_relaxed);
}

// UYVY (4:2:2) → RGBA conversion
// Each UYVY macro-pixel = 4 bytes encoding 2 pixels: [U Y0 V Y1]
void DeckLinkCaptureCallback::uyvy_to_rgba(const uint8_t *src, uint8_t *dst, int width, int height) {
    int pixel_pairs = (width * height) / 2;
    for (int i = 0; i < pixel_pairs; ++i) {
        int u  = src[0] - 128;
        int y0 = src[1];
        int v  = src[2] - 128;
        int y1 = src[3];
        src += 4;

        // BT.601 YUV → RGB
        auto clamp8 = [](int val) -> uint8_t {
            return static_cast<uint8_t>(val < 0 ? 0 : (val > 255 ? 255 : val));
        };

        dst[0] = clamp8(y0 + ((v * 359) >> 8));
        dst[1] = clamp8(y0 - ((u * 88 + v * 183) >> 8));
        dst[2] = clamp8(y0 + ((u * 454) >> 8));
        dst[3] = 255;

        dst[4] = clamp8(y1 + ((v * 359) >> 8));
        dst[5] = clamp8(y1 - ((u * 88 + v * 183) >> 8));
        dst[6] = clamp8(y1 + ((u * 454) >> 8));
        dst[7] = 255;
        dst += 8;
    }
}

// ── DeckLinkOutputFrame ──────────────────────────────────────────────

DeckLinkOutputFrame::DeckLinkOutputFrame(int width, int height, BMDPixelFormat format)
    : _width(width), _height(height), _format(format) {
    // UYVY = 2 bytes per pixel
    _row_bytes = width * 2;
    _frame_data.resize(static_cast<size_t>(_row_bytes) * height);
}

DeckLinkOutputFrame::~DeckLinkOutputFrame() = default;

HRESULT STDMETHODCALLTYPE DeckLinkOutputFrame::QueryInterface(REFIID iid, LPVOID *ppv) {
    if (!ppv) return E_POINTER;
    if (iid == IID_IUnknown || iid == IID_IDeckLinkVideoFrame) {
        *ppv = static_cast<IDeckLinkVideoFrame *>(this);
        AddRef();
        return S_OK;
    }
    if (iid == IID_IDeckLinkVideoBuffer) {
        *ppv = static_cast<IDeckLinkVideoBuffer *>(this);
        AddRef();
        return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
}

ULONG STDMETHODCALLTYPE DeckLinkOutputFrame::AddRef() {
    return _ref_count.fetch_add(1, std::memory_order_relaxed) + 1;
}

ULONG STDMETHODCALLTYPE DeckLinkOutputFrame::Release() {
    ULONG count = _ref_count.fetch_sub(1, std::memory_order_acq_rel) - 1;
    if (count == 0) delete this;
    return count;
}

HRESULT STDMETHODCALLTYPE DeckLinkOutputFrame::GetBytes(void **buffer) {
    if (!buffer) return E_POINTER;
    *buffer = _frame_data.data();
    return S_OK;
}

HRESULT STDMETHODCALLTYPE DeckLinkOutputFrame::GetSize(ULONGLONG *size) {
    if (!size) return E_POINTER;
    *size = static_cast<ULONGLONG>(_frame_data.size());
    return S_OK;
}

// RGBA → UYVY conversion for output
void DeckLinkOutputFrame::write_uyvy_from_rgba(const uint8_t *rgba_data, int rgba_width, int rgba_height) {
    int w = std::min(rgba_width, _width);
    int h = std::min(rgba_height, _height);
    int pixel_pairs = (w * h) / 2;

    const uint8_t *src = rgba_data;
    uint8_t *dst = _frame_data.data();

    for (int i = 0; i < pixel_pairs; ++i) {
        int r0 = src[0], g0 = src[1], b0 = src[2];
        int r1 = src[4], g1 = src[5], b1 = src[6];
        src += 8;

        // BT.601 RGB → YUV
        int y0 = ((66 * r0 + 129 * g0 + 25 * b0 + 128) >> 8) + 16;
        int y1 = ((66 * r1 + 129 * g1 + 25 * b1 + 128) >> 8) + 16;
        int u  = ((-38 * r0 - 74 * g0 + 112 * b0 + 128) >> 8) + 128;
        int v  = ((112 * r0 - 94 * g0 - 18 * b0 + 128) >> 8) + 128;

        auto clamp8 = [](int val) -> uint8_t {
            return static_cast<uint8_t>(val < 0 ? 0 : (val > 255 ? 255 : val));
        };

        dst[0] = clamp8(u);
        dst[1] = clamp8(y0);
        dst[2] = clamp8(v);
        dst[3] = clamp8(y1);
        dst += 4;
    }
}

// ── GNBlackmagic Private Helpers ─────────────────────────────────────

void GNBlackmagic::_enumerate_devices() const {
    if (_devices_enumerated) return;

    IDeckLinkIterator *iterator = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_CDeckLinkIterator, nullptr, CLSCTX_ALL,
                                  IID_IDeckLinkIterator, reinterpret_cast<void **>(&iterator));
    if (FAILED(hr) || !iterator) {
        UtilityFunctions::printerr("GNBlackmagic: DeckLink drivers not installed or no devices found.");
        _devices_enumerated = true;
        return;
    }

    IDeckLink *device = nullptr;
    while (iterator->Next(&device) == S_OK) {
        DeviceEntry entry;
        entry.device = device;

        BSTR name = nullptr;
        if (SUCCEEDED(device->GetDisplayName(&name)) && name) {
            entry.display_name = std::wstring(name, SysStringLen(name));
            SysFreeString(name);
        }

        // Check input/output support
        IDeckLinkInput *inp = nullptr;
        if (SUCCEEDED(device->QueryInterface(IID_IDeckLinkInput, reinterpret_cast<void **>(&inp))) && inp) {
            entry.supports_input = true;
            inp->Release();
        }

        IDeckLinkOutput *outp = nullptr;
        if (SUCCEEDED(device->QueryInterface(IID_IDeckLinkOutput, reinterpret_cast<void **>(&outp))) && outp) {
            entry.supports_output = true;
            outp->Release();
        }

        _devices.push_back(entry);
    }
    iterator->Release();
    _devices_enumerated = true;
}

void GNBlackmagic::_release_devices() {
    for (auto &entry : _devices) {
        if (entry.device) {
            entry.device->Release();
            entry.device = nullptr;
        }
    }
    _devices.clear();
    _devices_enumerated = false;
}

BMDDisplayMode GNBlackmagic::_find_display_mode(IDeckLinkInput *input, int width, int height, float fps) const {
    IDeckLinkDisplayModeIterator *mode_iter = nullptr;
    if (FAILED(input->GetDisplayModeIterator(&mode_iter)) || !mode_iter)
        return bmdModeHD1080p30; // fallback

    BMDDisplayMode best = bmdModeHD1080p30;
    float best_diff = 1e9f;

    IDeckLinkDisplayMode *mode = nullptr;
    while (mode_iter->Next(&mode) == S_OK) {
        long mw = mode->GetWidth();
        long mh = mode->GetHeight();

        BMDTimeValue dur;
        BMDTimeScale scale;
        mode->GetFrameRate(&dur, &scale);
        float mode_fps = (dur > 0) ? static_cast<float>(scale) / static_cast<float>(dur) : 0.0f;

        if (mw == width && mh == height) {
            float diff = (fps > 0) ? std::abs(mode_fps - fps) : 0.0f;
            if (diff < best_diff) {
                best_diff = diff;
                best = mode->GetDisplayMode();
            }
        }
        mode->Release();
    }
    mode_iter->Release();
    return best;
}

BMDDisplayMode GNBlackmagic::_find_output_display_mode(IDeckLinkOutput *output, int width, int height, float fps) const {
    IDeckLinkDisplayModeIterator *mode_iter = nullptr;
    if (FAILED(output->GetDisplayModeIterator(&mode_iter)) || !mode_iter)
        return bmdModeHD1080p30;

    BMDDisplayMode best = bmdModeHD1080p30;
    float best_diff = 1e9f;

    IDeckLinkDisplayMode *mode = nullptr;
    while (mode_iter->Next(&mode) == S_OK) {
        long mw = mode->GetWidth();
        long mh = mode->GetHeight();

        BMDTimeValue dur;
        BMDTimeScale scale;
        mode->GetFrameRate(&dur, &scale);
        float mode_fps = (dur > 0) ? static_cast<float>(scale) / static_cast<float>(dur) : 0.0f;

        if (mw == width && mh == height) {
            float diff = (fps > 0) ? std::abs(mode_fps - fps) : 0.0f;
            if (diff < best_diff) {
                best_diff = diff;
                best = mode->GetDisplayMode();
            }
        }
        mode->Release();
    }
    mode_iter->Release();
    return best;
}

#endif // GN_BLACKMAGIC_HAS_DECKLINK

// ════════════════════════════════════════════════════════════════════════
// GNBlackmagic Public API
// ════════════════════════════════════════════════════════════════════════

// ── Device Enumeration ───────────────────────────────────────────────

int GNBlackmagic::get_device_count() const {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    _enumerate_devices();
    return static_cast<int>(_devices.size());
#else
    return 0;
#endif
}

PackedStringArray GNBlackmagic::get_device_names() const {
    PackedStringArray names;
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    _enumerate_devices();
    for (const auto &entry : _devices) {
        String gd_name = String(entry.display_name.c_str());
        names.push_back(gd_name);
    }
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
    _enumerate_devices();
    if (device_index < 0 || device_index >= static_cast<int>(_devices.size()))
        return info;

    const auto &entry = _devices[device_index];
    info["name"] = String(entry.display_name.c_str());
    info["model"] = String(entry.display_name.c_str());
    info["supports_input"] = entry.supports_input;
    info["supports_output"] = entry.supports_output;

    // Query max resolution from the device's display modes
    if (entry.device) {
        IDeckLinkOutput *outp = nullptr;
        if (SUCCEEDED(entry.device->QueryInterface(IID_IDeckLinkOutput, reinterpret_cast<void **>(&outp))) && outp) {
            IDeckLinkDisplayModeIterator *mode_iter = nullptr;
            if (SUCCEEDED(outp->GetDisplayModeIterator(&mode_iter)) && mode_iter) {
                int max_w = 0, max_h = 0;
                IDeckLinkDisplayMode *mode = nullptr;
                while (mode_iter->Next(&mode) == S_OK) {
                    int mw = static_cast<int>(mode->GetWidth());
                    int mh = static_cast<int>(mode->GetHeight());
                    if (mw * mh > max_w * max_h) { max_w = mw; max_h = mh; }
                    mode->Release();
                }
                mode_iter->Release();
                info["max_width"] = max_w;
                info["max_height"] = max_h;
            }
            outp->Release();
        }
    }
#endif
    return info;
}

// ── Input (Capture) ──────────────────────────────────────────────────

bool GNBlackmagic::open_input(int device_index, int width, int height, float fps) {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    close_input();
    _enumerate_devices();

    if (device_index < 0 || device_index >= static_cast<int>(_devices.size())) {
        UtilityFunctions::printerr("GNBlackmagic: Invalid device index ", device_index);
        return false;
    }

    const auto &entry = _devices[device_index];
    if (!entry.supports_input) {
        UtilityFunctions::printerr("GNBlackmagic: Device does not support input: ", String(entry.display_name.c_str()));
        return false;
    }

    HRESULT hr = entry.device->QueryInterface(IID_IDeckLinkInput, reinterpret_cast<void **>(&_dk_input));
    if (FAILED(hr) || !_dk_input) {
        UtilityFunctions::printerr("GNBlackmagic: Failed to get IDeckLinkInput interface.");
        return false;
    }

    BMDDisplayMode display_mode = _find_display_mode(_dk_input, width, height, fps);

    BOOL mode_supported = FALSE;
    hr = _dk_input->DoesSupportVideoMode(
        bmdVideoConnectionUnspecified, display_mode,
        bmdFormat8BitYUV, bmdNoVideoInputConversion,
        bmdSupportedVideoModeDefault, nullptr, &mode_supported);

    if (FAILED(hr) || !mode_supported) {
        UtilityFunctions::printerr("GNBlackmagic: Requested video mode not supported.");
        _dk_input->Release();
        _dk_input = nullptr;
        return false;
    }

    _capture_cb = new DeckLinkCaptureCallback(width, height);
    _dk_input->SetCallback(_capture_cb);

    hr = _dk_input->EnableVideoInput(display_mode, bmdFormat8BitYUV, bmdVideoInputFlagDefault);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("GNBlackmagic: EnableVideoInput failed.");
        _dk_input->SetCallback(nullptr);
        _capture_cb->Release();
        _capture_cb = nullptr;
        _dk_input->Release();
        _dk_input = nullptr;
        return false;
    }

    hr = _dk_input->StartStreams();
    if (FAILED(hr)) {
        UtilityFunctions::printerr("GNBlackmagic: StartStreams failed.");
        _dk_input->DisableVideoInput();
        _dk_input->SetCallback(nullptr);
        _capture_cb->Release();
        _capture_cb = nullptr;
        _dk_input->Release();
        _dk_input = nullptr;
        return false;
    }

    _input_width = width;
    _input_height = height;
    _input_active = true;
    return true;
#else
    return false;
#endif
}

void GNBlackmagic::close_input() {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    if (_dk_input) {
        _dk_input->StopStreams();
        _dk_input->DisableVideoInput();
        _dk_input->SetCallback(nullptr);
        _dk_input->Release();
        _dk_input = nullptr;
    }
    if (_capture_cb) {
        _capture_cb->Release();
        _capture_cb = nullptr;
    }
    _input_width = 0;
    _input_height = 0;
#endif
    _input_active = false;
}

bool GNBlackmagic::has_new_frame() const {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    if (_capture_cb) return _capture_cb->has_new_frame();
#endif
    return false;
}

Ref<Image> GNBlackmagic::get_frame() const {
    Ref<Image> img;
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    if (!_capture_cb || !_capture_cb->has_new_frame()) return img;

    std::vector<uint8_t> rgba;
    int w = 0, h = 0;
    _capture_cb->consume_frame(rgba, w, h);
    if (rgba.empty() || w <= 0 || h <= 0) return img;

    PackedByteArray pba;
    pba.resize(static_cast<int64_t>(rgba.size()));
    memcpy(pba.ptrw(), rgba.data(), rgba.size());

    img = Image::create_from_data(w, h, false, Image::FORMAT_RGBA8, pba);
#endif
    return img;
}

PackedByteArray GNBlackmagic::get_frame_bytes() const {
    PackedByteArray bytes;
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    if (!_capture_cb || !_capture_cb->has_new_frame()) return bytes;

    std::vector<uint8_t> rgba;
    int w = 0, h = 0;
    _capture_cb->consume_frame(rgba, w, h);
    if (rgba.empty()) return bytes;

    bytes.resize(static_cast<int64_t>(rgba.size()));
    memcpy(bytes.ptrw(), rgba.data(), rgba.size());
#endif
    return bytes;
}

// ── Output (Playback) ────────────────────────────────────────────────

bool GNBlackmagic::open_output(int device_index, int width, int height, float fps) {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    close_output();
    _enumerate_devices();

    if (device_index < 0 || device_index >= static_cast<int>(_devices.size())) {
        UtilityFunctions::printerr("GNBlackmagic: Invalid device index ", device_index);
        return false;
    }

    const auto &entry = _devices[device_index];
    if (!entry.supports_output) {
        UtilityFunctions::printerr("GNBlackmagic: Device does not support output: ", String(entry.display_name.c_str()));
        return false;
    }

    HRESULT hr = entry.device->QueryInterface(IID_IDeckLinkOutput, reinterpret_cast<void **>(&_output));
    if (FAILED(hr) || !_output) {
        UtilityFunctions::printerr("GNBlackmagic: Failed to get IDeckLinkOutput interface.");
        return false;
    }

    BMDDisplayMode display_mode = _find_output_display_mode(_output, width, height, fps);

    hr = _output->EnableVideoOutput(display_mode, bmdVideoOutputFlagDefault);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("GNBlackmagic: EnableVideoOutput failed.");
        _output->Release();
        _output = nullptr;
        return false;
    }

    // Get frame duration/timescale for scheduled playback
    IDeckLinkDisplayModeIterator *iter = nullptr;
    _output->GetDisplayModeIterator(&iter);
    if (iter) {
        IDeckLinkDisplayMode *mode = nullptr;
        while (iter->Next(&mode) == S_OK) {
            if (mode->GetDisplayMode() == display_mode) {
                mode->GetFrameRate(&_out_frame_duration, &_out_time_scale);
                mode->Release();
                break;
            }
            mode->Release();
        }
        iter->Release();
    }

    _out_frame = new DeckLinkOutputFrame(width, height, bmdFormat8BitYUV);
    _output_width = width;
    _output_height = height;
    _out_frame_count = 0;

    hr = _output->StartScheduledPlayback(0, _out_time_scale, 1.0);
    if (FAILED(hr)) {
        UtilityFunctions::printerr("GNBlackmagic: StartScheduledPlayback failed.");
        _out_frame->Release();
        _out_frame = nullptr;
        _output->DisableVideoOutput();
        _output->Release();
        _output = nullptr;
        return false;
    }

    _output_active = true;
    return true;
#else
    return false;
#endif
}

void GNBlackmagic::close_output() {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    if (_output) {
        _output->StopScheduledPlayback(0, nullptr, 0);
        _output->DisableVideoOutput();
        _output->Release();
        _output = nullptr;
    }
    if (_out_frame) {
        _out_frame->Release();
        _out_frame = nullptr;
    }
    _output_width = 0;
    _output_height = 0;
    _out_frame_count = 0;
#endif
    _output_active = false;
}

void GNBlackmagic::send_frame(const Ref<Image> &p_image) {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    if (!_output || !_out_frame || p_image.is_null()) return;

    Ref<Image> img = p_image;
    if (img->get_format() != Image::FORMAT_RGBA8) {
        img = img->duplicate();
        img->convert(Image::FORMAT_RGBA8);
    }

    _out_frame->write_uyvy_from_rgba(img->get_data().ptr(), img->get_width(), img->get_height());

    BMDTimeValue time = _out_frame_count * _out_frame_duration;
    _output->ScheduleVideoFrame(_out_frame, time, _out_frame_duration, _out_time_scale);
    _out_frame_count++;
#endif
}

void GNBlackmagic::send_frame_bytes(const PackedByteArray &p_bytes, int width, int height) {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    if (!_output || !_out_frame) return;

    int64_t expected = static_cast<int64_t>(width) * height * 4;
    if (p_bytes.size() != expected) {
        UtilityFunctions::printerr("GNBlackmagic: send_frame_bytes size mismatch. Expected ", expected, " got ", p_bytes.size());
        return;
    }

    _out_frame->write_uyvy_from_rgba(p_bytes.ptr(), width, height);

    BMDTimeValue time = _out_frame_count * _out_frame_duration;
    _output->ScheduleVideoFrame(_out_frame, time, _out_frame_duration, _out_time_scale);
    _out_frame_count++;
#endif
}

// ── Status ───────────────────────────────────────────────────────────

bool GNBlackmagic::is_input_active() const {
    return _input_active;
}

bool GNBlackmagic::is_output_active() const {
    return _output_active;
}

int GNBlackmagic::get_dropped_frames() const {
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    if (_capture_cb) return _capture_cb->dropped_frames();
#endif
    return 0;
}

Dictionary GNBlackmagic::get_timecode() const {
    Dictionary tc;
    tc["hours"] = 0;
    tc["minutes"] = 0;
    tc["seconds"] = 0;
    tc["frames"] = 0;
#ifdef GN_BLACKMAGIC_HAS_DECKLINK
    if (_capture_cb) {
        int h, m, s, f;
        _capture_cb->get_timecode(h, m, s, f);
        tc["hours"] = h;
        tc["minutes"] = m;
        tc["seconds"] = s;
        tc["frames"] = f;
    }
#endif
    return tc;
}
