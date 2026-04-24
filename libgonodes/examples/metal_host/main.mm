/*
 * GONODES Metal Host Example (macOS)
 *
 * Demonstrates embedding GONODES with a Metal rendering context.
 * The host creates an MTLDevice and MTLCommandQueue, shares them with
 * LibGodot for zero-copy texture access, then renders the output texture
 * to an NSWindow via a CAMetalLayer blit.
 *
 * After loading, the Host I/O manifest is queried via gonodes_get_host_io()
 * to discover the patch's declared inputs, outputs, and exposed parameters.
 *
 * Build (macOS only):
 *   cd libgonodes/build && cmake .. && cmake --build . --target metal_host
 *
 * Run:
 *   ./metal_host path/to/gonodes_project path/to/show.gnpatch
 */

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Cocoa/Cocoa.h>

#include <gonodes_host.h>

#include <cstdio>
#include <cmath>

/* ═══════════════════════════════════════════════════════════════════════════ */
/*  MetalKit View Delegate                                                   */
/* ═══════════════════════════════════════════════════════════════════════════ */

@interface GonodesRenderer : NSObject <MTKViewDelegate> {
    gonodes_instance_t _gn;
    gonodes_patch_t _p;
    id<MTLDevice> _device;
    id<MTLCommandQueue> _cmdQueue;
    double _prevTime;
}
- (instancetype)initWithDevice:(id<MTLDevice>)device
                  commandQueue:(id<MTLCommandQueue>)queue
                      instance:(gonodes_instance_t)gn
                         patch:(gonodes_patch_t)patch;
@end

@implementation GonodesRenderer

- (instancetype)initWithDevice:(id<MTLDevice>)device
                  commandQueue:(id<MTLCommandQueue>)queue
                      instance:(gonodes_instance_t)gn
                         patch:(gonodes_patch_t)patch
{
    self = [super init];
    if (self) {
        _device = device;
        _cmdQueue = queue;
        _gn = gn;
        _p = patch;
        _prevTime = CFAbsoluteTimeGetCurrent();
    }
    return self;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    /* Handle resize if needed. */
}

- (void)drawInMTKView:(MTKView *)view {
    double now = CFAbsoluteTimeGetCurrent();
    double delta = now - _prevTime;
    _prevTime = now;

    /* Inject an animated value. */
    float lfo = (float)(sin(now * 2.0) * 0.5 + 0.5);
    gonodes_set_input_chop(_gn, _p, "host_lfo", "lfo", &lfo, 1);

    /* Cook one frame. */
    gonodes_cook_frame(_gn, delta);

    /* Read the output texture — this is an id<MTLTexture> on the shared device. */
    int tw = 0, th = 0;
    uint64_t tex_handle = gonodes_get_output_texture(_gn, _p, "host_out", &tw, &th);

    /* Render to the drawable. */
    id<CAMetalDrawable> drawable = [view currentDrawable];
    if (!drawable) return;

    id<MTLCommandBuffer> cmdBuf = [_cmdQueue commandBuffer];

    if (tex_handle != 0) {
        /* The handle is an id<MTLTexture> cast to uint64_t. */
        id<MTLTexture> gonodesTexture = (__bridge id<MTLTexture>)(void*)tex_handle;

        /* Blit the GONODES output to the drawable texture. */
        id<MTLBlitCommandEncoder> blit = [cmdBuf blitCommandEncoder];

        MTLSize srcSize = MTLSizeMake(
            MIN(gonodesTexture.width, drawable.texture.width),
            MIN(gonodesTexture.height, drawable.texture.height),
            1
        );

        [blit copyFromTexture:gonodesTexture
                  sourceSlice:0
                  sourceLevel:0
                 sourceOrigin:MTLOriginMake(0, 0, 0)
                   sourceSize:srcSize
                    toTexture:drawable.texture
             destinationSlice:0
             destinationLevel:0
            destinationOrigin:MTLOriginMake(0, 0, 0)];

        [blit endEncoding];
    } else {
        /* No output — clear to dark gray. */
        MTLRenderPassDescriptor* pass = [view currentRenderPassDescriptor];
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0.05, 0.05, 0.05, 1.0);
        pass.colorAttachments[0].loadAction = MTLLoadActionClear;
        id<MTLRenderCommandEncoder> enc = [cmdBuf renderCommandEncoderWithDescriptor:pass];
        [enc endEncoding];
    }

    [cmdBuf presentDrawable:drawable];
    [cmdBuf commit];
}

@end


/* ═══════════════════════════════════════════════════════════════════════════ */
/*  Main                                                                     */
/* ═══════════════════════════════════════════════════════════════════════════ */

int main(int argc, char* argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <project_path> <patch_file.gnpatch>\n", argv[0]);
        return 1;
    }
    const char* project_path = argv[1];
    const char* patch_file   = argv[2];

    @autoreleasepool {
        /* ── Metal Setup ────────────────────────────────────────────── */

        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) {
            fprintf(stderr, "[Metal Host] No Metal device available\n");
            return 1;
        }
        printf("[Metal Host] GPU: %s\n", [[device name] UTF8String]);

        id<MTLCommandQueue> cmdQueue = [device newCommandQueue];

        /* ── GONODES Initialization ─────────────────────────────────── */

        gonodes_gpu_context_t gpu = {};
        gpu.graphics_api       = GONODES_GFX_METAL;
        gpu.metal_device       = (__bridge void*)device;
        gpu.metal_command_queue = (__bridge void*)cmdQueue;

        printf("[Metal Host] Creating GONODES instance...\n");
        gonodes_instance_t gn = gonodes_create(project_path, &gpu);
        if (!gn) {
            fprintf(stderr, "[Metal Host] gonodes_create failed\n");
            return 1;
        }

        printf("[Metal Host] Loading patch: %s\n", patch_file);
        gonodes_patch_t p = gonodes_load_patch(gn, patch_file);
        if (!p) {
            fprintf(stderr, "[Metal Host] Load failed: %s\n", gonodes_get_last_error(gn));
            gonodes_destroy(gn);
            return 1;
        }

        gonodes_set_auto_reload(gn, p, 1, 0.5);

        /* ── Query Host I/O Manifest ────────────────────────────────── */

        const char* host_io = gonodes_get_host_io(gn, p);
        if (host_io && host_io[0] != '\0') {
            printf("[Metal Host] Host I/O Manifest:\n%s\n", host_io);
        } else {
            printf("[Metal Host] No Host I/O manifest in patch.\n");
        }

        /* ── NSApplication + Window + MTKView ───────────────────────── */

        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp activateIgnoringOtherApps:YES];

        NSRect frame = NSMakeRect(100, 100, 1280, 720);
        NSWindow* window = [[NSWindow alloc]
            initWithContentRect:frame
                      styleMask:(NSWindowStyleMaskTitled |
                                 NSWindowStyleMaskClosable |
                                 NSWindowStyleMaskResizable)
                        backing:NSBackingStoreBuffered
                          defer:NO];
        [window setTitle:@"GONODES Metal Host"];

        MTKView* metalView = [[MTKView alloc] initWithFrame:frame device:device];
        metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
        metalView.framebufferOnly = NO;  /* Allow blit to drawable texture. */

        GonodesRenderer* renderer = [[GonodesRenderer alloc]
            initWithDevice:device commandQueue:cmdQueue instance:gn patch:p];
        metalView.delegate = renderer;

        [window setContentView:metalView];
        [window makeKeyAndOrderFront:nil];

        /* ── Run Loop ───────────────────────────────────────────────── */

        [NSApp run];

        /* ── Cleanup ────────────────────────────────────────────────── */

        gonodes_destroy(gn);
        printf("[Metal Host] Clean exit.\n");
    }

    return 0;
}
