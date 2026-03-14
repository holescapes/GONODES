#include "gn_native_analyze_vol.h"

#include <godot_cpp/core/class_db.hpp>


namespace godot {

void GNNativeAnalyzeVol::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "field", "do_histogram", "hist_bins"),
                         &GNNativeAnalyzeVol::process);
}

Dictionary GNNativeAnalyzeVol::process(const PackedFloat32Array &field,
                                        bool do_histogram, int hist_bins) {
    Dictionary result;
    int total = field.size();

    if (total == 0) {
        result["min"] = 0.0;
        result["max"] = 0.0;
        result["mean"] = 0.0;
        result["sum"] = 0.0;
        result["nonzero_count"] = 0.0;
        result["total_voxels"] = 0.0;
        return result;
    }

    const float *f = field.ptr();
    float v_min = f[0], v_max = f[0];
    double v_sum = 0.0;
    int nonzero = 0;

    for (int i = 0; i < total; ++i) {
        float v = f[i];
        if (v < v_min) v_min = v;
        if (v > v_max) v_max = v;
        v_sum += v;
        if (fabsf(v) > 1e-7f) ++nonzero;
    }

    result["min"] = (double)v_min;
    result["max"] = (double)v_max;
    result["mean"] = v_sum / (double)total;
    result["sum"] = v_sum;
    result["nonzero_count"] = (double)nonzero;
    result["total_voxels"] = (double)total;

    if (do_histogram && hist_bins > 0) {
        PackedFloat32Array hist;
        hist.resize(hist_bins);
        float *hp = hist.ptrw();
        for (int i = 0; i < hist_bins; ++i) hp[i] = 0.0f;

        float range = v_max - v_min;
        if (range < 1e-10f) range = 1.0f;

        for (int i = 0; i < total; ++i) {
            int idx = (int)((f[i] - v_min) / range * (float)hist_bins);
            if (idx < 0) idx = 0;
            if (idx >= hist_bins) idx = hist_bins - 1;
            hp[idx] += 1.0f;
        }

        result["histogram"] = hist;
    }

    return result;
}

} // namespace godot
