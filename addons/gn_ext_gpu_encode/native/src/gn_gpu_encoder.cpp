#include "gn_gpu_encoder.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

// ---------------------------------------------------------------------------
// Platform includes
// ---------------------------------------------------------------------------
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <mferror.h>
#include <mftransform.h>
#include <codecapi.h>
#include <propvarutil.h>
#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mf.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "mfuuid.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "propsys.lib")

struct GpuEncoderImpl {
    IMFSinkWriter *writer = nullptr;
    DWORD stream_index = 0;
    LONGLONG frame_duration = 0;
    bool mf_initialized = false;
};

#elif defined(__APPLE__)
// VideoToolbox implementation in gn_gpu_encoder_mac.mm
struct GpuEncoderImpl;
#else
struct GpuEncoderImpl {};
#endif

namespace godot {

void GNGpuEncoder::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start", "file_path", "width", "height", "fps", "bitrate_kbps"), &GNGpuEncoder::start);
    ClassDB::bind_method(D_METHOD("encode_frame", "rgba_data"), &GNGpuEncoder::encode_frame);
    ClassDB::bind_method(D_METHOD("finish"), &GNGpuEncoder::finish);
    ClassDB::bind_method(D_METHOD("is_encoding"), &GNGpuEncoder::is_encoding);
    ClassDB::bind_method(D_METHOD("get_frame_count"), &GNGpuEncoder::get_frame_count);
}

GNGpuEncoder::GNGpuEncoder() {}

GNGpuEncoder::~GNGpuEncoder() {
    finish();
}

bool GNGpuEncoder::is_encoding() const { return _encoding; }
int GNGpuEncoder::get_frame_count() const { return _frame_count; }

// ==========================================================================
// Windows — Media Foundation Sink Writer with H.264 MFT
// ==========================================================================
#ifdef _WIN32

bool GNGpuEncoder::start(const String &file_path, int width, int height, int fps, int bitrate_kbps) {
    finish();

    HRESULT hr = MFStartup(MF_VERSION);
    if (FAILED(hr)) return false;

    auto *impl = new GpuEncoderImpl();
    impl->mf_initialized = true;
    impl->frame_duration = 10000000LL / fps; // 100ns units

    // Convert path to wide string
    CharString path_utf8 = file_path.utf8();
    int wlen = MultiByteToWideChar(CP_UTF8, 0, path_utf8.get_data(), -1, nullptr, 0);
    WCHAR *wpath = new WCHAR[wlen];
    MultiByteToWideChar(CP_UTF8, 0, path_utf8.get_data(), -1, wpath, wlen);

    // Create Sink Writer for MP4 output
    IMFAttributes *writer_attrs = nullptr;
    MFCreateAttributes(&writer_attrs, 2);
    writer_attrs->SetUINT32(MF_READWRITE_ENABLE_HARDWARE_TRANSFORMS, TRUE);
    writer_attrs->SetGUID(MF_TRANSCODE_CONTAINERTYPE, MFTranscodeContainerType_MPEG4);

    hr = MFCreateSinkWriterFromURL(wpath, nullptr, writer_attrs, &impl->writer);
    delete[] wpath;
    if (writer_attrs) writer_attrs->Release();

    if (FAILED(hr) || !impl->writer) {
        if (impl->mf_initialized) MFShutdown();
        delete impl;
        return false;
    }

    // Configure output media type (H.264)
    IMFMediaType *output_type = nullptr;
    MFCreateMediaType(&output_type);
    output_type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    output_type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_H264);
    output_type->SetUINT32(MF_MT_AVG_BITRATE, bitrate_kbps * 1000);
    MFSetAttributeSize(output_type, MF_MT_FRAME_SIZE, width, height);
    MFSetAttributeRatio(output_type, MF_MT_FRAME_RATE, fps, 1);
    MFSetAttributeRatio(output_type, MF_MT_PIXEL_ASPECT_RATIO, 1, 1);
    output_type->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);

    hr = impl->writer->AddStream(output_type, &impl->stream_index);
    output_type->Release();
    if (FAILED(hr)) {
        impl->writer->Release();
        MFShutdown();
        delete impl;
        return false;
    }

    // Configure input media type (RGB32 — we'll convert RGBA to this)
    IMFMediaType *input_type = nullptr;
    MFCreateMediaType(&input_type);
    input_type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    input_type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
    MFSetAttributeSize(input_type, MF_MT_FRAME_SIZE, width, height);
    MFSetAttributeRatio(input_type, MF_MT_FRAME_RATE, fps, 1);
    MFSetAttributeRatio(input_type, MF_MT_PIXEL_ASPECT_RATIO, 1, 1);
    input_type->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);

    hr = impl->writer->SetInputMediaType(impl->stream_index, input_type, nullptr);
    input_type->Release();
    if (FAILED(hr)) {
        impl->writer->Release();
        MFShutdown();
        delete impl;
        return false;
    }

    // Begin writing
    hr = impl->writer->BeginWriting();
    if (FAILED(hr)) {
        impl->writer->Release();
        MFShutdown();
        delete impl;
        return false;
    }

    _impl = impl;
    _width = width;
    _height = height;
    _fps = fps;
    _frame_count = 0;
    _encoding = true;
    return true;
}

bool GNGpuEncoder::encode_frame(const PackedByteArray &rgba_data) {
    if (!_encoding || !_impl) return false;

    auto *impl = static_cast<GpuEncoderImpl *>(_impl);
    int expected = _width * _height * 4;
    if (rgba_data.size() < expected) return false;

    // Create MF buffer and sample
    IMFMediaBuffer *buffer = nullptr;
    DWORD stride = _width * 4;
    DWORD buffer_size = stride * _height;
    HRESULT hr = MFCreateMemoryBuffer(buffer_size, &buffer);
    if (FAILED(hr)) return false;

    BYTE *dst = nullptr;
    hr = buffer->Lock(&dst, nullptr, nullptr);
    if (FAILED(hr)) { buffer->Release(); return false; }

    // RGBA → BGRA conversion (MF_RGB32 is actually BGRA in memory)
    const uint8_t *src = rgba_data.ptr();
    for (int y = 0; y < _height; y++) {
        // MF expects bottom-up for RGB32, so flip vertically
        int src_y = _height - 1 - y;
        for (int x = 0; x < _width; x++) {
            int si = (src_y * _width + x) * 4;
            int di = (y * _width + x) * 4;
            dst[di + 0] = src[si + 2]; // B
            dst[di + 1] = src[si + 1]; // G
            dst[di + 2] = src[si + 0]; // R
            dst[di + 3] = src[si + 3]; // A
        }
    }

    buffer->Unlock();
    buffer->SetCurrentLength(buffer_size);

    IMFSample *sample = nullptr;
    MFCreateSample(&sample);
    sample->AddBuffer(buffer);
    sample->SetSampleTime((LONGLONG)_frame_count * impl->frame_duration);
    sample->SetSampleDuration(impl->frame_duration);

    hr = impl->writer->WriteSample(impl->stream_index, sample);

    sample->Release();
    buffer->Release();

    if (SUCCEEDED(hr)) {
        _frame_count++;
        return true;
    }
    return false;
}

void GNGpuEncoder::finish() {
    if (_impl) {
        auto *impl = static_cast<GpuEncoderImpl *>(_impl);
        if (impl->writer) {
            impl->writer->Finalize();
            impl->writer->Release();
        }
        if (impl->mf_initialized) MFShutdown();
        delete impl;
        _impl = nullptr;
    }
    _encoding = false;
}

// ==========================================================================
// macOS — stub (real implementation in gn_gpu_encoder_mac.mm)
// ==========================================================================
#elif defined(__APPLE__)

// Implemented in gn_gpu_encoder_mac.mm

// ==========================================================================
// Unsupported platform
// ==========================================================================
#else

bool GNGpuEncoder::start(const String &, int, int, int, int) { return false; }
bool GNGpuEncoder::encode_frame(const PackedByteArray &) { return false; }
void GNGpuEncoder::finish() {}

#endif

} // namespace godot
