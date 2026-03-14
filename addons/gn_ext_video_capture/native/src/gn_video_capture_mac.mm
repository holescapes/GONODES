#include "gn_video_capture.h"
#include <godot_cpp/variant/utility_functions.hpp>

#ifdef __APPLE__

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

// ---------------------------------------------------------------------------
// AVFoundation capture delegate — receives frames from the capture session
// ---------------------------------------------------------------------------
@interface GNCaptureDel : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate> {
@public
    CVPixelBufferRef _latestPixelBuffer;
    NSLock *_lock;
}
@end

@implementation GNCaptureDel

- (instancetype)init {
    self = [super init];
    if (self) {
        _latestPixelBuffer = NULL;
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_lock lock];
    if (_latestPixelBuffer) {
        CVPixelBufferRelease(_latestPixelBuffer);
        _latestPixelBuffer = NULL;
    }
    [_lock unlock];
}

- (void)captureOutput:(AVCaptureOutput *)output
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
           fromConnection:(AVCaptureConnection *)connection {
    CVPixelBufferRef pb = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pb) return;

    CVPixelBufferRetain(pb);
    [_lock lock];
    if (_latestPixelBuffer) {
        CVPixelBufferRelease(_latestPixelBuffer);
    }
    _latestPixelBuffer = pb;
    [_lock unlock];
}

- (CVPixelBufferRef)copyLatestPixelBuffer {
    [_lock lock];
    CVPixelBufferRef pb = _latestPixelBuffer;
    if (pb) CVPixelBufferRetain(pb);
    [_lock unlock];
    return pb;
}

@end

// ---------------------------------------------------------------------------
// Platform impl struct
// ---------------------------------------------------------------------------
struct VideoCaptureImpl {
    AVCaptureSession *session = nil;
    AVCaptureDeviceInput *input = nil;
    AVCaptureVideoDataOutput *output = nil;
    GNCaptureDel *delegate = nil;
    dispatch_queue_t queue = nil;
};

namespace godot {

bool GNVideoCapture::open_device(int device_index, int width, int height, int fps) {
    close_device();

    NSArray<AVCaptureDevice *> *devices =
        [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];

    if (device_index < 0 || device_index >= (int)[devices count]) return false;

    AVCaptureDevice *device = devices[device_index];

    NSError *error = nil;
    AVCaptureDeviceInput *dev_input =
        [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!dev_input) return false;

    auto *impl = new VideoCaptureImpl();
    impl->session = [[AVCaptureSession alloc] init];

    if (width * height >= 1920 * 1080) {
        impl->session.sessionPreset = AVCaptureSessionPreset1920x1080;
    } else if (width * height >= 1280 * 720) {
        impl->session.sessionPreset = AVCaptureSessionPreset1280x720;
    } else {
        impl->session.sessionPreset = AVCaptureSessionPreset640x480;
    }

    if (![impl->session canAddInput:dev_input]) {
        delete impl;
        return false;
    }
    [impl->session addInput:dev_input];
    impl->input = dev_input;

    impl->output = [[AVCaptureVideoDataOutput alloc] init];
    impl->output.videoSettings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
    };
    impl->output.alwaysDiscardsLateVideoFrames = YES;

    impl->delegate = [[GNCaptureDel alloc] init];
    impl->queue = dispatch_queue_create("com.gonodes.videocapture", DISPATCH_QUEUE_SERIAL);
    [impl->output setSampleBufferDelegate:impl->delegate queue:impl->queue];

    if (![impl->session canAddOutput:impl->output]) {
        delete impl;
        return false;
    }
    [impl->session addOutput:impl->output];

    // Configure FPS on device
    [device lockForConfiguration:nil];
    device.activeVideoMinFrameDuration = CMTimeMake(1, fps);
    device.activeVideoMaxFrameDuration = CMTimeMake(1, fps);
    [device unlockForConfiguration];

    [impl->session startRunning];

    _impl = impl;
    _width = width;
    _height = height;
    _open = true;
    return true;
}

void GNVideoCapture::close_device() {
    if (_impl) {
        auto *impl = static_cast<VideoCaptureImpl *>(_impl);
        if (impl->session) {
            [impl->session stopRunning];
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
    CVPixelBufferRef pb = [impl->delegate copyLatestPixelBuffer];
    if (!pb) return result;

    CVPixelBufferLockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);

    size_t w = CVPixelBufferGetWidth(pb);
    size_t h = CVPixelBufferGetHeight(pb);
    _width = (int)w;
    _height = (int)h;

    size_t stride = CVPixelBufferGetBytesPerRow(pb);
    uint8_t *base = (uint8_t *)CVPixelBufferGetBaseAddress(pb);

    int pixel_count = _width * _height;
    result.resize(pixel_count * 4);
    uint8_t *dst = result.ptrw();

    // BGRA → RGBA conversion
    for (int y = 0; y < _height; y++) {
        const uint8_t *row = base + y * stride;
        for (int x = 0; x < _width; x++) {
            int di = (y * _width + x) * 4;
            int si = x * 4;
            dst[di + 0] = row[si + 2]; // R <- B
            dst[di + 1] = row[si + 1]; // G
            dst[di + 2] = row[si + 0]; // B <- R
            dst[di + 3] = row[si + 3]; // A
        }
    }

    CVPixelBufferUnlockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferRelease(pb);
    return result;
}

PackedStringArray GNVideoCapture::get_device_list() {
    PackedStringArray list;

    NSArray<AVCaptureDevice *> *devices =
        [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];

    for (AVCaptureDevice *device in devices) {
        list.push_back(String::utf8([device.localizedName UTF8String]));
    }

    return list;
}

int GNVideoCapture::get_device_count() {
    return get_device_list().size();
}

} // namespace godot

#endif // __APPLE__
