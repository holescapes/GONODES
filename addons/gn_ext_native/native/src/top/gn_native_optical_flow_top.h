#ifndef GN_NATIVE_OPTICAL_FLOW_TOP_H
#define GN_NATIVE_OPTICAL_FLOW_TOP_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/image.hpp>
namespace godot {
/// Horn-Schunck optical flow between two frames.
/// Returns flow vectors encoded as RG channels in an image.
class GNNativeOpticalFlowTop : public RefCounted {
    GDCLASS(GNNativeOpticalFlowTop, RefCounted)
protected:
    static void _bind_methods();
public:
    Ref<Image> process(const Ref<Image> &prev_frame, const Ref<Image> &curr_frame,
                       int iterations, double lambda, double scale);
};
} // namespace godot
#endif
