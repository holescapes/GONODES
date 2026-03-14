#include "gn_video_capture.h"
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
#include <comdef.h>
#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mf.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "mfuuid.lib")
#pragma comment(lib, "ole32.lib")

struct VideoCaptureImpl {
    IMFSourceReader *reader = nullptr;
    IMFMediaSource *source = nullptr;
    bool mf_initialized = false;
};

#elif defined(__APPLE__)
// AVFoundation handled in gn_video_capture_mac.mm — forward declarations only
struct VideoCaptureImpl;

#elif defined(__linux__)
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <linux/videodev2.h>
#include <dirent.h>
#include <cstring>

struct VideoCaptureImpl {
    int fd = -1;
    void *buffer = nullptr;
    size_t buffer_length = 0;
};
#endif

namespace godot {

// ---------------------------------------------------------------------------
// Bind methods (shared across all platforms)
// ---------------------------------------------------------------------------
void GNVideoCapture::_bind_methods() {
    ClassDB::bind_method(D_METHOD("open_device", "device_index", "width", "height", "fps"), &GNVideoCapture::open_device);
    ClassDB::bind_method(D_METHOD("close_device"), &GNVideoCapture::close_device);
    ClassDB::bind_method(D_METHOD("capture_frame"), &GNVideoCapture::capture_frame);
    ClassDB::bind_method(D_METHOD("is_open"), &GNVideoCapture::is_open);
    ClassDB::bind_method(D_METHOD("get_width"), &GNVideoCapture::get_width);
    ClassDB::bind_method(D_METHOD("get_height"), &GNVideoCapture::get_height);
    ClassDB::bind_static_method("GNVideoCapture", D_METHOD("get_device_list"), &GNVideoCapture::get_device_list);
    ClassDB::bind_static_method("GNVideoCapture", D_METHOD("get_device_count"), &GNVideoCapture::get_device_count);
}

GNVideoCapture::GNVideoCapture() {}

GNVideoCapture::~GNVideoCapture() {
    close_device();
}

bool GNVideoCapture::is_open() const { return _open; }
int GNVideoCapture::get_width() const { return _width; }
int GNVideoCapture::get_height() const { return _height; }

// ==========================================================================
// Windows — Media Foundation
// ==========================================================================
#ifdef _WIN32

static IMFMediaSource *_create_device_source(int index) {
    IMFAttributes *attrs = nullptr;
    HRESULT hr = MFCreateAttributes(&attrs, 1);
    if (FAILED(hr)) return nullptr;

    hr = attrs->SetGUID(MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
                        MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID);
    if (FAILED(hr)) { attrs->Release(); return nullptr; }

    IMFActivate **devices = nullptr;
    UINT32 count = 0;
    hr = MFEnumDeviceSources(attrs, &devices, &count);
    attrs->Release();
    if (FAILED(hr) || (UINT32)index >= count) {
        if (devices) {
            for (UINT32 i = 0; i < count; i++) devices[i]->Release();
            CoTaskMemFree(devices);
        }
        return nullptr;
    }

    IMFMediaSource *source = nullptr;
    hr = devices[index]->ActivateObject(__uuidof(IMFMediaSource), (void **)&source);

    for (UINT32 i = 0; i < count; i++) devices[i]->Release();
    CoTaskMemFree(devices);

    return SUCCEEDED(hr) ? source : nullptr;
}

bool GNVideoCapture::open_device(int device_index, int width, int height, int fps) {
    close_device();

    auto *impl = new VideoCaptureImpl();
    HRESULT hr = MFStartup(MF_VERSION);
    if (FAILED(hr)) { delete impl; return false; }
    impl->mf_initialized = true;

    impl->source = _create_device_source(device_index);
    if (!impl->source) {
        MFShutdown();
        delete impl;
        return false;
    }

    // Create source reader
    IMFAttributes *reader_attrs = nullptr;
    MFCreateAttributes(&reader_attrs, 1);
    hr = MFCreateSourceReaderFromMediaSource(impl->source, reader_attrs, &impl->reader);
    if (reader_attrs) reader_attrs->Release();

    if (FAILED(hr) || !impl->reader) {
        impl->source->Release();
        MFShutdown();
        delete impl;
        return false;
    }

    // Configure output to RGB32
    IMFMediaType *media_type = nullptr;
    MFCreateMediaType(&media_type);
    media_type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    media_type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
    MFSetAttributeSize(media_type, MF_MT_FRAME_SIZE, width, height);
    MFSetAttributeRatio(media_type, MF_MT_FRAME_RATE, fps, 1);

    hr = impl->reader->SetCurrentMediaType(
        (DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM, nullptr, media_type);
    media_type->Release();

    if (FAILED(hr)) {
        // Fallback: accept device default format, get actual dimensions
        IMFMediaType *current = nullptr;
        impl->reader->GetCurrentMediaType(
            (DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM, &current);
        if (current) {
            UINT32 w = 0, h = 0;
            MFGetAttributeSize(current, MF_MT_FRAME_SIZE, &w, &h);
            width = (int)w;
            height = (int)h;
            current->Release();
        }
    }

    _impl = impl;
    _width = width;
    _height = height;
    _open = true;
    return true;
}

void GNVideoCapture::close_device() {
    if (_impl) {
        auto *impl = static_cast<VideoCaptureImpl *>(_impl);
        if (impl->reader) impl->reader->Release();
        if (impl->source) impl->source->Release();
        if (impl->mf_initialized) MFShutdown();
        delete impl;
        _impl = nullptr;
    }
    _open = false;
    _width = 0;
    _height = 0;
}

PackedByteArray GNVideoCapture::capture_frame() {
    PackedByteArray result;
    if (!_open || !_impl) return result;

    auto *impl = static_cast<VideoCaptureImpl *>(_impl);

    DWORD flags = 0;
    IMFSample *sample = nullptr;
    HRESULT hr = impl->reader->ReadSample(
        (DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM,
        0, nullptr, &flags, nullptr, &sample);

    if (FAILED(hr) || !sample) return result;

    IMFMediaBuffer *buffer = nullptr;
    hr = sample->ConvertToContiguousBuffer(&buffer);
    if (FAILED(hr) || !buffer) { sample->Release(); return result; }

    BYTE *data = nullptr;
    DWORD length = 0;
    hr = buffer->Lock(&data, nullptr, &length);
    if (SUCCEEDED(hr) && data) {
        // Media Foundation RGB32 is BGRA — convert to RGBA
        int pixel_count = _width * _height;
        result.resize(pixel_count * 4);
        uint8_t *dst = result.ptrw();
        for (int i = 0; i < pixel_count; i++) {
            int si = i * 4;
            dst[si + 0] = data[si + 2]; // R <- B
            dst[si + 1] = data[si + 1]; // G
            dst[si + 2] = data[si + 0]; // B <- R
            dst[si + 3] = data[si + 3]; // A
        }
        buffer->Unlock();
    }

    buffer->Release();
    sample->Release();
    return result;
}

PackedStringArray GNVideoCapture::get_device_list() {
    PackedStringArray list;

    HRESULT hr = MFStartup(MF_VERSION);
    if (FAILED(hr)) return list;

    IMFAttributes *attrs = nullptr;
    MFCreateAttributes(&attrs, 1);
    attrs->SetGUID(MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,
                   MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID);

    IMFActivate **devices = nullptr;
    UINT32 count = 0;
    hr = MFEnumDeviceSources(attrs, &devices, &count);
    attrs->Release();

    if (SUCCEEDED(hr) && devices) {
        for (UINT32 i = 0; i < count; i++) {
            WCHAR *name = nullptr;
            UINT32 name_len = 0;
            devices[i]->GetAllocatedString(
                MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME, &name, &name_len);
            if (name) {
                list.push_back(String::utf8((const char *)name, name_len));
                CoTaskMemFree(name);
            }
            devices[i]->Release();
        }
        CoTaskMemFree(devices);
    }

    MFShutdown();
    return list;
}

int GNVideoCapture::get_device_count() {
    return get_device_list().size();
}

// ==========================================================================
// Linux — V4L2
// ==========================================================================
#elif defined(__linux__)

bool GNVideoCapture::open_device(int device_index, int width, int height, int fps) {
    close_device();

    char dev_path[32];
    snprintf(dev_path, sizeof(dev_path), "/dev/video%d", device_index);

    int fd = open(dev_path, O_RDWR);
    if (fd < 0) return false;

    // Set format
    struct v4l2_format fmt = {};
    fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    fmt.fmt.pix.width = width;
    fmt.fmt.pix.height = height;
    fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_RGB24;
    fmt.fmt.pix.field = V4L2_FIELD_NONE;

    if (ioctl(fd, VIDIOC_S_FMT, &fmt) < 0) {
        // Fallback: read current format
        ioctl(fd, VIDIOC_G_FMT, &fmt);
    }

    _width = fmt.fmt.pix.width;
    _height = fmt.fmt.pix.height;

    // Set framerate
    struct v4l2_streamparm parm = {};
    parm.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    parm.parm.capture.timeperframe.numerator = 1;
    parm.parm.capture.timeperframe.denominator = fps;
    ioctl(fd, VIDIOC_S_PARM, &parm);

    // Request single mmap buffer
    struct v4l2_requestbuffers req = {};
    req.count = 1;
    req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    req.memory = V4L2_MEMORY_MMAP;
    if (ioctl(fd, VIDIOC_REQBUFS, &req) < 0) {
        ::close(fd);
        return false;
    }

    struct v4l2_buffer buf = {};
    buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    buf.memory = V4L2_MEMORY_MMAP;
    buf.index = 0;
    if (ioctl(fd, VIDIOC_QUERYBUF, &buf) < 0) {
        ::close(fd);
        return false;
    }

    auto *impl = new VideoCaptureImpl();
    impl->fd = fd;
    impl->buffer_length = buf.length;
    impl->buffer = mmap(nullptr, buf.length, PROT_READ | PROT_WRITE,
                         MAP_SHARED, fd, buf.m.offset);

    if (impl->buffer == MAP_FAILED) {
        ::close(fd);
        delete impl;
        return false;
    }

    // Queue buffer and start streaming
    if (ioctl(fd, VIDIOC_QBUF, &buf) < 0) {
        munmap(impl->buffer, impl->buffer_length);
        ::close(fd);
        delete impl;
        return false;
    }

    enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    if (ioctl(fd, VIDIOC_STREAMON, &type) < 0) {
        munmap(impl->buffer, impl->buffer_length);
        ::close(fd);
        delete impl;
        return false;
    }

    _impl = impl;
    _open = true;
    return true;
}

void GNVideoCapture::close_device() {
    if (_impl) {
        auto *impl = static_cast<VideoCaptureImpl *>(_impl);
        if (impl->fd >= 0) {
            enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
            ioctl(impl->fd, VIDIOC_STREAMOFF, &type);
            if (impl->buffer && impl->buffer != MAP_FAILED) {
                munmap(impl->buffer, impl->buffer_length);
            }
            ::close(impl->fd);
        }
        delete impl;
        _impl = nullptr;
    }
    _open = false;
    _width = 0;
    _height = 0;
}

PackedByteArray GNVideoCapture::capture_frame() {
    PackedByteArray result;
    if (!_open || !_impl) return result;

    auto *impl = static_cast<VideoCaptureImpl *>(_impl);

    struct v4l2_buffer buf = {};
    buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    buf.memory = V4L2_MEMORY_MMAP;

    if (ioctl(impl->fd, VIDIOC_DQBUF, &buf) < 0) return result;

    // V4L2 RGB24 → RGBA conversion
    int pixel_count = _width * _height;
    result.resize(pixel_count * 4);
    uint8_t *dst = result.ptrw();
    const uint8_t *src = static_cast<const uint8_t *>(impl->buffer);

    for (int i = 0; i < pixel_count; i++) {
        dst[i * 4 + 0] = src[i * 3 + 0]; // R
        dst[i * 4 + 1] = src[i * 3 + 1]; // G
        dst[i * 4 + 2] = src[i * 3 + 2]; // B
        dst[i * 4 + 3] = 255;             // A
    }

    // Re-queue buffer
    ioctl(impl->fd, VIDIOC_QBUF, &buf);
    return result;
}

PackedStringArray GNVideoCapture::get_device_list() {
    PackedStringArray list;

    for (int i = 0; i < 16; i++) {
        char dev_path[32];
        snprintf(dev_path, sizeof(dev_path), "/dev/video%d", i);

        int fd = open(dev_path, O_RDWR);
        if (fd < 0) continue;

        struct v4l2_capability cap = {};
        if (ioctl(fd, VIDIOC_QUERYCAP, &cap) == 0) {
            if (cap.device_caps & V4L2_CAP_VIDEO_CAPTURE) {
                list.push_back(String::utf8((const char *)cap.card));
            }
        }
        ::close(fd);
    }

    return list;
}

int GNVideoCapture::get_device_count() {
    return get_device_list().size();
}

// ==========================================================================
// macOS — stub (real implementation in gn_video_capture_mac.mm)
// ==========================================================================
#elif defined(__APPLE__)

// Implemented in gn_video_capture_mac.mm

#else

// Unsupported platform stubs
bool GNVideoCapture::open_device(int, int, int, int) { return false; }
void GNVideoCapture::close_device() {}
PackedByteArray GNVideoCapture::capture_frame() { return PackedByteArray(); }
PackedStringArray GNVideoCapture::get_device_list() { return PackedStringArray(); }
int GNVideoCapture::get_device_count() { return 0; }

#endif

} // namespace godot
