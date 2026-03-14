#include "gn_gpu_encoder.h"
#include <godot_cpp/variant/utility_functions.hpp>

#ifdef __APPLE__

#import <VideoToolbox/VideoToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

struct GpuEncoderImpl {
    AVAssetWriter *writer = nil;
    AVAssetWriterInput *video_input = nil;
    AVAssetWriterInputPixelBufferAdaptor *adaptor = nil;
    int fps = 30;
};

namespace godot {

bool GNGpuEncoder::start(const String &file_path, int width, int height, int fps, int bitrate_kbps) {
    finish();

    CharString path_utf8 = file_path.utf8();
    NSString *ns_path = [NSString stringWithUTF8String:path_utf8.get_data()];
    NSURL *url = [NSURL fileURLWithPath:ns_path];

    // Remove existing file if present
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];

    NSError *error = nil;
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:url
                                                      fileType:AVFileTypeMPEG4
                                                         error:&error];
    if (!writer) return false;

    // Video output settings — H.264 hardware encoding
    NSDictionary *settings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(width),
        AVVideoHeightKey: @(height),
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @(bitrate_kbps * 1000),
            AVVideoExpectedSourceFrameRateKey: @(fps),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        },
    };

    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                  outputSettings:settings];
    input.expectsMediaDataInRealTime = YES;

    // Pixel buffer adaptor for BGRA input
    NSDictionary *pb_attrs = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (NSString *)kCVPixelBufferWidthKey: @(width),
        (NSString *)kCVPixelBufferHeightKey: @(height),
    };

    AVAssetWriterInputPixelBufferAdaptor *adaptor =
        [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input
                                                                        sourcePixelBufferAttributes:pb_attrs];

    if (![writer canAddInput:input]) {
        return false;
    }
    [writer addInput:input];
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];

    auto *impl = new GpuEncoderImpl();
    impl->writer = writer;
    impl->video_input = input;
    impl->adaptor = adaptor;
    impl->fps = fps;

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

    if (!impl->video_input.readyForMoreMediaData) return false;

    // Create pixel buffer
    CVPixelBufferRef pb = NULL;
    CVPixelBufferPoolRef pool = impl->adaptor.pixelBufferPool;
    if (!pool) return false;

    CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, pool, &pb);
    if (status != kCVReturnSuccess || !pb) return false;

    CVPixelBufferLockBaseAddress(pb, 0);
    uint8_t *dst = (uint8_t *)CVPixelBufferGetBaseAddress(pb);
    size_t stride = CVPixelBufferGetBytesPerRow(pb);
    const uint8_t *src = rgba_data.ptr();

    // RGBA → BGRA conversion
    for (int y = 0; y < _height; y++) {
        for (int x = 0; x < _width; x++) {
            int si = (y * _width + x) * 4;
            int di = y * (int)stride + x * 4;
            dst[di + 0] = src[si + 2]; // B
            dst[di + 1] = src[si + 1]; // G
            dst[di + 2] = src[si + 0]; // R
            dst[di + 3] = src[si + 3]; // A
        }
    }
    CVPixelBufferUnlockBaseAddress(pb, 0);

    CMTime time = CMTimeMake(_frame_count, impl->fps);
    BOOL ok = [impl->adaptor appendPixelBuffer:pb withPresentationTime:time];
    CVPixelBufferRelease(pb);

    if (ok) {
        _frame_count++;
        return true;
    }
    return false;
}

void GNGpuEncoder::finish() {
    if (_impl) {
        auto *impl = static_cast<GpuEncoderImpl *>(_impl);
        if (impl->writer && impl->writer.status == AVAssetWriterStatusWriting) {
            [impl->video_input markAsFinished];
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            [impl->writer finishWritingWithCompletionHandler:^{
                dispatch_semaphore_signal(sem);
            }];
            dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
        }
        delete impl;
        _impl = nullptr;
    }
    _encoding = false;
}

} // namespace godot

#endif // __APPLE__
