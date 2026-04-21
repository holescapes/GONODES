#include "gn_native_audio_band_chop.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

namespace godot {

void GNNativeAudioBandChop::_bind_methods() {
    ClassDB::bind_method(D_METHOD("process", "input_bands", "envelopes", "peaks",
                                  "crossovers", "num_bands", "gain", "freq_min", "freq_max",
                                  "att_coeff", "rel_coeff", "peak_decay"),
                         &GNNativeAudioBandChop::process);
}

Dictionary GNNativeAudioBandChop::process(const PackedFloat32Array &input_bands,
                                           const PackedFloat32Array &envelopes,
                                           const PackedFloat32Array &peaks,
                                           const PackedFloat32Array &crossovers,
                                           int num_bands, double gain,
                                           double freq_min, double freq_max,
                                           double att_coeff, double rel_coeff,
                                           double peak_decay) {
    int input_count = input_bands.size();
    const float *in_ptr = input_bands.ptr();

    // Copy envelope/peak state so we can modify
    PackedFloat32Array env_out = envelopes;
    PackedFloat32Array peak_out = peaks;
    env_out.resize(num_bands);
    peak_out.resize(num_bands);
    float *env_w = env_out.ptrw();
    float *peak_w = peak_out.ptrw();

    const float *cross_ptr = crossovers.ptr();
    int cross_count = crossovers.size();

    // Accumulate raw levels per output band from input spectrum
    PackedFloat32Array raw_levels;
    raw_levels.resize(num_bands);
    float *raw_w = raw_levels.ptrw();
    for (int b = 0; b < num_bands; ++b) {
        raw_w[b] = 0.0f;
    }

    if (input_count > 0) {
        double log_min = std::log(freq_min > 1.0 ? freq_min : 1.0);
        double log_max = std::log(freq_max > freq_min + 1.0 ? freq_max : freq_min + 1.0);
        double inv_count = 1.0 / (double)input_count;

        for (int i = 0; i < input_count; ++i) {
            double t = ((double)i + 0.5) * inv_count;
            double center_freq = std::exp(log_min + t * (log_max - log_min));

            for (int b = 0; b < num_bands; ++b) {
                double lo = (b < cross_count) ? (double)cross_ptr[b] : freq_min;
                double hi = ((b + 1) < cross_count) ? (double)cross_ptr[b + 1] : freq_max;
                if (center_freq >= lo && center_freq < hi) {
                    raw_w[b] += in_ptr[i];
                    break;
                }
            }
        }

        float gain_f = (float)gain;
        for (int b = 0; b < num_bands; ++b) {
            raw_w[b] *= gain_f;
            if (raw_w[b] < 0.0f) raw_w[b] = 0.0f;
            if (raw_w[b] > 1.0f) raw_w[b] = 1.0f;
        }
    }

    // Envelope follower + peak hold + normalization
    PackedFloat32Array levels_out;
    levels_out.resize(num_bands);
    float *lev_w = levels_out.ptrw();

    PackedFloat32Array norms_out;
    norms_out.resize(num_bands);
    float *norm_w = norms_out.ptrw();

    double total_energy = 0.0;
    double max_level = 0.0;
    int dominant = 0;

    float att_f = (float)att_coeff;
    float rel_f = (float)rel_coeff;
    float pdec_f = (float)peak_decay;

    for (int b = 0; b < num_bands; ++b) {
        float raw = raw_w[b];

        // Envelope follower
        if (raw > env_w[b]) {
            env_w[b] += (raw - env_w[b]) * att_f;
        } else {
            env_w[b] += (raw - env_w[b]) * rel_f;
        }

        // Peak hold with decay
        if (env_w[b] > peak_w[b]) {
            peak_w[b] = env_w[b];
        } else {
            peak_w[b] *= pdec_f;
        }

        // Normalized against recent peak
        float pk = peak_w[b] > 0.001f ? peak_w[b] : 0.001f;
        float norm = env_w[b] / pk;
        if (norm < 0.0f) norm = 0.0f;
        if (norm > 1.0f) norm = 1.0f;

        lev_w[b] = env_w[b];
        norm_w[b] = norm;

        total_energy += (double)env_w[b];
        if ((double)env_w[b] > max_level) {
            max_level = (double)env_w[b];
            dominant = b;
        }
    }

    float total = (float)(total_energy / (num_bands > 0 ? (double)num_bands : 1.0));
    if (total < 0.0f) total = 0.0f;
    if (total > 1.0f) total = 1.0f;

    Dictionary result;
    result["levels"] = levels_out;
    result["peaks_out"] = peak_out;
    result["norms"] = norms_out;
    result["envelopes"] = env_out;
    result["total"] = total;
    result["dominant"] = dominant;
    return result;
}

} // namespace godot
