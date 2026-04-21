#include "gn_native_resample_sop.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <cmath>
#include <vector>
namespace godot {
void GNNativeResampleSop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "points", "mode", "segment_length",
                                  "segment_count", "closed"),
                         &GNNativeResampleSop::process);
}
PackedVector3Array GNNativeResampleSop::process(const PackedVector3Array &points,
        int mode, double segment_length, int segment_count, bool closed) {
    int n = points.size();
    if (n < 2) return points;
    const Vector3 *pts = points.ptr();
    // Calculate cumulative arc lengths
    std::vector<double> arc(n, 0.0);
    for (int i = 1; i < n; ++i) {
        arc[i] = arc[i-1] + (pts[i] - pts[i-1]).length();
    }
    if (closed) {
        arc.push_back(arc[n-1] + (pts[0] - pts[n-1]).length());
    }
    double total_length = closed ? arc[n] : arc[n-1];
    if (total_length < 1e-10) return points;
    // Determine target segment length
    double seg_len;
    int num_segs;
    if (mode == 0) {
        // By segment length
        seg_len = segment_length > 1e-6 ? segment_length : total_length / 10.0;
        num_segs = (int)(total_length / seg_len);
        if (num_segs < 1) num_segs = 1;
    } else {
        // By segment count
        num_segs = segment_count > 0 ? segment_count : 10;
        seg_len = total_length / num_segs;
    }
    PackedVector3Array result;
    int total_pts = closed ? num_segs : num_segs + 1;
    int src_count = closed ? n + 1 : n;
    int seg_idx = 0;
    for (int i = 0; i < total_pts; ++i) {
        double target_len = i * seg_len;
        // Find segment containing target_len
        while (seg_idx < src_count - 1 && arc[seg_idx + 1] < target_len)
            ++seg_idx;
        if (seg_idx >= src_count - 1) seg_idx = src_count - 2;
        double seg_start = arc[seg_idx];
        double seg_end = arc[seg_idx + 1];
        double seg_range = seg_end - seg_start;
        double t = (seg_range > 1e-10) ? (target_len - seg_start) / seg_range : 0.0;
        Vector3 a = pts[seg_idx % n];
        Vector3 b = pts[(seg_idx + 1) % n];
        result.push_back(a + (b - a) * (float)t);
    }
    if (closed && result.size() > 0) result.push_back(result[0]);
    return result;
}
} // namespace godot
